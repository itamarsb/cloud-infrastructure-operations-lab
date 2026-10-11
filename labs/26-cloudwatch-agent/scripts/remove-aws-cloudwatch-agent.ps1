[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly
)

. (Join-Path $PSScriptRoot "lab26-common.ps1")

Initialize-Lab26 -ProfileName $ProfileName

if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    if ($ValidateOnly) {
        Write-Host (
            "[OK] ValidateOnly sem inventario: inicializacao conferida."
        ) -ForegroundColor Green

        Write-Host (
            "IDs, tags e associacoes serao conferidos apos o deploy."
        )

        Write-Host "[OK] Nenhum recurso AWS removido." `
            -ForegroundColor Green
        return
    }

    throw "Inventario nao encontrado: $StatePath"
}

$script:State = Read-Lab26Json -Path $StatePath

$ParsedRunId = [guid]::Empty

if (
    $State.AccountId -ne $Settings.ExpectedAccountId -or
    $State.Region -ne $Settings.Region -or
    -not [guid]::TryParse([string]$State.RunId, [ref]$ParsedRunId)
) {
    throw "Inventario incompativel com a conta, regiao ou RunId."
}

foreach ($Property in $Settings.Names.PSObject.Properties) {
    if ($State.Names.($Property.Name) -cne $Property.Value) {
        throw "Nome do inventario diferente da configuracao: $($Property.Name)"
    }
}

function Get-Lab26CleanupInstance {
    if ([string]::IsNullOrWhiteSpace($State.Ids.Instance)) {
        return $null
    }

    $Response = Invoke-Lab26Aws -Service ec2 `
        -Operation describe-instances -Request @{
            InstanceIds = @($State.Ids.Instance)
        } -AbsentCodes @("InvalidInstanceID.NotFound")

    if ($null -eq $Response) {
        return $null
    }

    $Instances = @(
        foreach ($Reservation in $Response.Reservations) {
            foreach ($Item in $Reservation.Instances) {
                $Item
            }
        }
    )

    if ($Instances.Count -eq 0) {
        return $null
    }

    if ($Instances.Count -ne 1) {
        throw "Resposta inesperada ao consultar a instancia."
    }

    return $Instances[0]
}

function Invoke-Lab26Removal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Service,

        [Parameter(Mandatory = $true)]
        [string]$Operation,

        [Parameter(Mandatory = $true)]
        [hashtable]$Request,

        [string[]]$AbsentCodes = @(),

        [string[]]$RetryCodes = @()
    )

    for ($Attempt = 1; $Attempt -le 12; $Attempt++) {
        try {
            Invoke-Lab26Aws -Service $Service `
                -Operation $Operation -Request $Request `
                -AbsentCodes $AbsentCodes | Out-Null
            return
        }
        catch {
            $Retry = $false

            foreach ($Code in $RetryCodes) {
                $Pattern = "\(" + [regex]::Escape($Code) + "\)"

                if ($_.Exception.Message -match $Pattern) {
                    $Retry = $true
                    break
                }
            }

            if (-not $Retry -or $Attempt -eq 12) {
                throw
            }

            Write-Host "Aguardando dependencias: $Service $Operation"
            Start-Sleep -Seconds 5
        }
    }
}

$Definitions = @(
    [pscustomobject]@{
        Key = "Vpc"
        Operation = "describe-vpcs"
        IdParameter = "VpcIds"
        Collection = "Vpcs"
        AbsentCode = "InvalidVpcID.NotFound"
    }
    [pscustomobject]@{
        Key = "Subnet"
        Operation = "describe-subnets"
        IdParameter = "SubnetIds"
        Collection = "Subnets"
        AbsentCode = "InvalidSubnetID.NotFound"
    }
    [pscustomobject]@{
        Key = "InternetGateway"
        Operation = "describe-internet-gateways"
        IdParameter = "InternetGatewayIds"
        Collection = "InternetGateways"
        AbsentCode = "InvalidInternetGatewayID.NotFound"
    }
    [pscustomobject]@{
        Key = "RouteTable"
        Operation = "describe-route-tables"
        IdParameter = "RouteTableIds"
        Collection = "RouteTables"
        AbsentCode = "InvalidRouteTableID.NotFound"
    }
    [pscustomobject]@{
        Key = "SecurityGroup"
        Operation = "describe-security-groups"
        IdParameter = "GroupIds"
        Collection = "SecurityGroups"
        AbsentCode = "InvalidGroup.NotFound"
    }
)

$Resources = @{}

# Somente consultas de leitura ate o retorno ValidateOnly.
foreach ($Definition in $Definitions) {
    $Key = $Definition.Key

    $Resource = Get-Lab26Ec2Resource `
        -Operation $Definition.Operation `
        -IdParameter $Definition.IdParameter `
        -Id $State.Ids.$Key `
        -Collection $Definition.Collection `
        -AbsentCode $Definition.AbsentCode

    $Resources[$Key] = $Resource

    if ($null -ne $Resource) {
        Assert-Lab26Ownership -Resource $Resource `
            -Name $Settings.Names.$Key

        if (
            $Key -in @("Subnet", "RouteTable", "SecurityGroup") -and
            $Resource.VpcId -ne $State.Ids.Vpc
        ) {
            throw "Recurso associado a outra VPC: $Key"
        }
    }
}

$Instance = Get-Lab26CleanupInstance

if ($null -ne $Instance) {
    Assert-Lab26Ownership -Resource $Instance `
        -Name $Settings.Names.Instance

    if (
        $Instance.VpcId -ne $State.Ids.Vpc -or
        $Instance.SubnetId -ne $State.Ids.Subnet
    ) {
        throw "Instancia associada a outra rede."
    }

    if ($Instance.State.Name -ne "terminated") {
        $Mappings = @($Instance.BlockDeviceMappings)

        if (
            $Mappings.Count -ne 1 -or
            $Mappings[0].DeviceName -ne $Instance.RootDeviceName -or
            -not $Mappings[0].Ebs.DeleteOnTermination
        ) {
            throw "Mapeamento de volumes diferente do previsto."
        }

        $LiveVolumeId = $Mappings[0].Ebs.VolumeId

        if (
            -not [string]::IsNullOrWhiteSpace($State.Ids.Volume) -and
            $State.Ids.Volume -ne $LiveVolumeId
        ) {
            throw "Volume raiz diferente do inventario."
        }

        # Recupera o ID se o deploy parou antes de registra-lo.
        # Esta alteracao so sera salva fora do ValidateOnly.
        $State.Ids.Volume = $LiveVolumeId

        $Commands = Invoke-Lab26Aws -Service ssm `
            -Operation list-commands -Request @{
                InstanceId = $State.Ids.Instance
            }

        $ActiveCommands = @(
            $Commands.Commands | Where-Object {
                $_.Status -in @(
                    "Pending", "InProgress", "Delayed", "Cancelling"
                )
            }
        )

        if ($ActiveCommands.Count -ne 0) {
            $ActiveCommands |
                Select-Object CommandId, Status, DocumentName |
                Format-Table -AutoSize

            throw "Ha comandos SSM ativos. Aguarde ou confira-os antes do cleanup."
        }
    }
}

$Volume = Get-Lab26Ec2Resource `
    -Operation describe-volumes `
    -IdParameter VolumeIds `
    -Id $State.Ids.Volume `
    -Collection Volumes `
    -AbsentCode "InvalidVolume.NotFound"

if ($null -ne $Volume) {
    Assert-Lab26Ownership -Resource $Volume `
        -Name ($Settings.Names.Instance + "-root")

    foreach ($Attachment in $Volume.Attachments) {
        if ($Attachment.InstanceId -ne $State.Ids.Instance) {
            throw "Volume associado a outra instancia."
        }
    }
}

$Role = $null
$AttachedPolicyArns = @()
$InlinePolicyNames = @()

if (-not [string]::IsNullOrWhiteSpace($State.Ids.RoleId)) {
    $Response = Invoke-Lab26Aws -Service iam `
        -Operation get-role -Request @{
            RoleName = $Settings.Names.Role
        } -AbsentCodes @("NoSuchEntity")

    if ($null -ne $Response) {
        $Role = $Response.Role

        if ($Role.RoleId -ne $State.Ids.RoleId) {
            throw "RoleId diferente do inventario."
        }

        Assert-Lab26Ownership -Resource $Role `
            -Name $Settings.Names.Role

        $Policies = Invoke-Lab26Aws -Service iam `
            -Operation list-attached-role-policies -Request @{
                RoleName = $Settings.Names.Role
            }

        $AttachedPolicyArns = @(
            $Policies.AttachedPolicies |
                ForEach-Object { $_.PolicyArn }
        )

        if (@(
            $AttachedPolicyArns | Where-Object { $_ -ne $PolicyArn }
        ).Count -ne 0) {
            throw "A role possui politicas gerenciadas adicionais."
        }

        $Inline = Invoke-Lab26Aws -Service iam `
            -Operation list-role-policies -Request @{
                RoleName = $Settings.Names.Role
            }

        $InlinePolicyNames = @($Inline.PolicyNames)

        if (@(
            $InlinePolicyNames | Where-Object {
                $_ -ne $Settings.Names.AgentInlinePolicy
            }
        ).Count -ne 0) {
            throw "A role possui politicas inline adicionais."
        }

        $Profiles = Invoke-Lab26Aws -Service iam `
            -Operation list-instance-profiles-for-role -Request @{
                RoleName = $Settings.Names.Role
            }

        foreach ($Profile in $Profiles.InstanceProfiles) {
            if (
                $Profile.InstanceProfileId -ne
                    $State.Ids.InstanceProfileId
            ) {
                throw "A role esta associada a outro instance profile."
            }
        }
    }
}

$InstanceProfile = $null

if (-not [string]::IsNullOrWhiteSpace($State.Ids.InstanceProfileId)) {
    $Response = Invoke-Lab26Aws -Service iam `
        -Operation get-instance-profile -Request @{
            InstanceProfileName = $Settings.Names.InstanceProfile
        } -AbsentCodes @("NoSuchEntity")

    if ($null -ne $Response) {
        $InstanceProfile = $Response.InstanceProfile

        if (
            $InstanceProfile.InstanceProfileId -ne
                $State.Ids.InstanceProfileId
        ) {
            throw "InstanceProfileId diferente do inventario."
        }

        Assert-Lab26Ownership -Resource $InstanceProfile `
            -Name $Settings.Names.InstanceProfile

        foreach ($ProfileRole in $InstanceProfile.Roles) {
            if ($ProfileRole.RoleId -ne $State.Ids.RoleId) {
                throw "O instance profile possui uma role diferente."
            }
        }

        $ProfileInstances = Invoke-Lab26Aws -Service ec2 `
            -Operation describe-instances -Request @{
                Filters = @(
                    @{
                        Name = "iam-instance-profile.arn"
                        Values = @($InstanceProfile.Arn)
                    }
                    @{
                        Name = "instance-state-name"
                        Values = @(
                            "pending", "running", "stopping",
                            "stopped", "shutting-down"
                        )
                    }
                )
            }

        foreach ($Reservation in $ProfileInstances.Reservations) {
            foreach ($Item in $Reservation.Instances) {
                if ($Item.InstanceId -ne $State.Ids.Instance) {
                    throw "Outra instancia utiliza o instance profile."
                }
            }
        }
    }
}

$LogGroup = $null

if (-not [string]::IsNullOrWhiteSpace($State.Ids.LogGroup)) {
    if ($State.Ids.LogGroup -cne $Settings.Logs.LogGroupName) {
        throw "Log group do inventario diferente do previsto."
    }

    $Response = Invoke-Lab26Aws -Service logs `
        -Operation describe-log-groups -Request @{
            logGroupNamePrefix = $State.Ids.LogGroup
        }

    $MatchingGroups = @(
        $Response.logGroups | Where-Object {
            $_.logGroupName -ceq $State.Ids.LogGroup
        }
    )

    if ($MatchingGroups.Count -gt 1) {
        throw "Resposta inesperada ao consultar o log group."
    }

    if ($MatchingGroups.Count -eq 1) {
        $LogGroup = $MatchingGroups[0]

        $LogArn = (
            "arn:aws:logs:{0}:{1}:log-group:{2}" -f
            $Settings.Region,
            $Settings.ExpectedAccountId,
            $State.Ids.LogGroup
        )

        $TagResponse = Invoke-Lab26Aws -Service logs `
            -Operation list-tags-for-resource -Request @{
                resourceArn = $LogArn
            }

        $LogTags = @(
            foreach ($Property in $TagResponse.tags.PSObject.Properties) {
                [pscustomobject]@{
                    Key = $Property.Name
                    Value = $Property.Value
                }
            }
        )

        Assert-Lab26Ownership -Resource (
            [pscustomobject]@{ Tags = $LogTags }
        ) -Name $Settings.Logs.LogGroupName
    }
}

$RouteAssociations = @()

if ($null -ne $Resources.RouteTable) {
    foreach ($Association in $Resources.RouteTable.Associations) {
        if ($Association.Main) {
            throw "A tabela exclusiva foi configurada como principal."
        }

        if (
            $Association.SubnetId -ne $State.Ids.Subnet -or
            $Association.RouteTableAssociationId -ne $State.Ids.Association
        ) {
            throw "Associacao de tabela de rotas diferente do inventario."
        }
    }

    $RouteAssociations = @($Resources.RouteTable.Associations)
}

if ($null -ne $Resources.InternetGateway) {
    foreach ($Attachment in $Resources.InternetGateway.Attachments) {
        if ($Attachment.VpcId -ne $State.Ids.Vpc) {
            throw "Internet Gateway associado a outra VPC."
        }
    }
}

if ($null -ne $Resources.Vpc) {
    $VpcFilter = @(
        @{ Name = "vpc-id"; Values = @($State.Ids.Vpc) }
    )

    $VpcInstances = Invoke-Lab26Aws -Service ec2 `
        -Operation describe-instances -Request @{
            Filters = $VpcFilter
        }

    foreach ($Reservation in $VpcInstances.Reservations) {
        foreach ($Item in $Reservation.Instances) {
            if (
                $Item.State.Name -ne "terminated" -and
                $Item.InstanceId -ne $State.Ids.Instance
            ) {
                throw "Outra instancia foi encontrada na VPC."
            }
        }
    }

    $Subnets = Invoke-Lab26Aws -Service ec2 `
        -Operation describe-subnets -Request @{ Filters = $VpcFilter }

    foreach ($Item in $Subnets.Subnets) {
        if ($Item.SubnetId -ne $State.Ids.Subnet) {
            throw "Outra subnet foi encontrada na VPC."
        }
    }

    $Tables = Invoke-Lab26Aws -Service ec2 `
        -Operation describe-route-tables -Request @{ Filters = $VpcFilter }

    foreach ($Item in $Tables.RouteTables) {
        $IsMain = @(
            $Item.Associations | Where-Object { $_.Main }
        ).Count -ne 0

        if (-not $IsMain -and $Item.RouteTableId -ne $State.Ids.RouteTable) {
            throw "Outra tabela de rotas foi encontrada na VPC."
        }
    }

    $Groups = Invoke-Lab26Aws -Service ec2 `
        -Operation describe-security-groups -Request @{ Filters = $VpcFilter }

    foreach ($Item in $Groups.SecurityGroups) {
        if (
            $Item.GroupName -ne "default" -and
            $Item.GroupId -ne $State.Ids.SecurityGroup
        ) {
            throw "Outro security group foi encontrado na VPC."
        }
    }

    $Interfaces = Invoke-Lab26Aws -Service ec2 `
        -Operation describe-network-interfaces -Request @{
            Filters = $VpcFilter
        }

    foreach ($Item in $Interfaces.NetworkInterfaces) {
        $AttachmentProperty = $Item.PSObject.Properties["Attachment"]

        if (
            $null -eq $AttachmentProperty -or
            $null -eq $AttachmentProperty.Value
        ) {
            throw "Interface de rede sem associacao conhecida na VPC."
        }

        if (
            $null -eq
                $AttachmentProperty.Value.PSObject.Properties["InstanceId"]
        ) {
            throw "Interface de rede nao pertence a uma instancia conhecida."
        }

        if ($Item.Attachment.InstanceId -ne $State.Ids.Instance) {
            throw "Interface de rede de outro recurso encontrada na VPC."
        }
    }
}

Write-Host "[OK] Inventario, IDs e tags de propriedade conferidos." `
    -ForegroundColor Green

Write-Host "[OK] IAM, rede, volumes e log group conferidos." `
    -ForegroundColor Green

if ($ValidateOnly) {
    Write-Host "[OK] ValidateOnly: nenhum recurso AWS removido." `
        -ForegroundColor Green
    return
}

Save-Lab26State

try {
    if ($null -ne $Instance -and $Instance.State.Name -ne "terminated") {
        Invoke-Lab26Removal -Service ec2 `
            -Operation terminate-instances -Request @{
                InstanceIds = @($State.Ids.Instance)
            } -AbsentCodes @("InvalidInstanceID.NotFound")

        $Terminated = $false

        for ($Attempt = 1; $Attempt -le 60; $Attempt++) {
            $Current = Get-Lab26CleanupInstance

            if ($null -eq $Current -or $Current.State.Name -eq "terminated") {
                $Terminated = $true
                break
            }

            if ($Attempt % 6 -eq 1) {
                Write-Host "Aguardando terminacao da instancia..."
            }

            Start-Sleep -Seconds 5
        }

        if (-not $Terminated) {
            throw "Terminacao nao confirmada no prazo."
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($State.Ids.Volume)) {
        $RemainingVolume = $null

        for ($Attempt = 1; $Attempt -le 24; $Attempt++) {
            $RemainingVolume = Get-Lab26Ec2Resource `
                -Operation describe-volumes `
                -IdParameter VolumeIds `
                -Id $State.Ids.Volume `
                -Collection Volumes `
                -AbsentCode "InvalidVolume.NotFound"

            if ($null -eq $RemainingVolume) {
                break
            }

            Start-Sleep -Seconds 5
        }

        # Recuperacao de um volume exclusivo que permaneceu disponivel.
        if ($null -ne $RemainingVolume) {
            Assert-Lab26Ownership -Resource $RemainingVolume `
                -Name ($Settings.Names.Instance + "-root")

            if (
                $RemainingVolume.State -ne "available" -or
                @($RemainingVolume.Attachments).Count -ne 0
            ) {
                throw "Volume ainda associado ou indisponivel para remocao."
            }

            Invoke-Lab26Removal -Service ec2 `
                -Operation delete-volume -Request @{
                    VolumeId = $State.Ids.Volume
                } -AbsentCodes @("InvalidVolume.NotFound")

            $VolumeAbsent = $false

            for ($Attempt = 1; $Attempt -le 24; $Attempt++) {
                $RemainingVolume = Get-Lab26Ec2Resource `
                    -Operation describe-volumes `
                    -IdParameter VolumeIds `
                    -Id $State.Ids.Volume `
                    -Collection Volumes `
                    -AbsentCode "InvalidVolume.NotFound"

                if ($null -eq $RemainingVolume) {
                    $VolumeAbsent = $true
                    break
                }

                Start-Sleep -Seconds 5
            }

            if (-not $VolumeAbsent) {
                throw "Ausencia do volume nao confirmada."
            }
        }
    }

    if ($null -ne $Resources.Vpc) {
        $InterfacesAbsent = $false

        for ($Attempt = 1; $Attempt -le 60; $Attempt++) {
            $Interfaces = Invoke-Lab26Aws -Service ec2 `
                -Operation describe-network-interfaces -Request @{
                    Filters = @(
                        @{ Name = "vpc-id"; Values = @($State.Ids.Vpc) }
                    )
                }

            if (@($Interfaces.NetworkInterfaces).Count -eq 0) {
                $InterfacesAbsent = $true
                break
            }

            if ($Attempt % 6 -eq 1) {
                Write-Host "Aguardando liberacao das interfaces de rede..."
            }

            Start-Sleep -Seconds 5
        }

        if (-not $InterfacesAbsent) {
            throw "Interfaces de rede ainda existem na VPC."
        }
    }

    Write-Host "[OK] Instancia encerrada e armazenamento conferido." `
        -ForegroundColor Green

    if ($null -ne $InstanceProfile) {
        if (@($InstanceProfile.Roles).Count -ne 0) {
            Invoke-Lab26Removal -Service iam `
                -Operation remove-role-from-instance-profile -Request @{
                    InstanceProfileName = $Settings.Names.InstanceProfile
                    RoleName = $Settings.Names.Role
                } -AbsentCodes @("NoSuchEntity")
        }

        Invoke-Lab26Removal -Service iam `
            -Operation delete-instance-profile -Request @{
                InstanceProfileName = $Settings.Names.InstanceProfile
            } -AbsentCodes @("NoSuchEntity") `
            -RetryCodes @("DeleteConflict")
    }

    if ($null -ne $Role) {
        foreach ($Name in $InlinePolicyNames) {
            Invoke-Lab26Removal -Service iam `
                -Operation delete-role-policy -Request @{
                    RoleName = $Settings.Names.Role
                    PolicyName = $Name
                } -AbsentCodes @("NoSuchEntity")
        }

        foreach ($Arn in $AttachedPolicyArns) {
            Invoke-Lab26Removal -Service iam `
                -Operation detach-role-policy -Request @{
                    RoleName = $Settings.Names.Role
                    PolicyArn = $Arn
                } -AbsentCodes @("NoSuchEntity")
        }

        Invoke-Lab26Removal -Service iam `
            -Operation delete-role -Request @{
                RoleName = $Settings.Names.Role
            } -AbsentCodes @("NoSuchEntity") `
            -RetryCodes @("DeleteConflict")
    }

    foreach ($Association in $RouteAssociations) {
        Invoke-Lab26Removal -Service ec2 `
            -Operation disassociate-route-table -Request @{
                AssociationId = $Association.RouteTableAssociationId
            } -AbsentCodes @("InvalidAssociationID.NotFound")
    }

    if ($null -ne $Resources.Subnet) {
        Invoke-Lab26Removal -Service ec2 `
            -Operation delete-subnet -Request @{
                SubnetId = $State.Ids.Subnet
            } -AbsentCodes @("InvalidSubnetID.NotFound") `
            -RetryCodes @("DependencyViolation")
    }

    if ($null -ne $Resources.RouteTable) {
        Invoke-Lab26Removal -Service ec2 `
            -Operation delete-route-table -Request @{
                RouteTableId = $State.Ids.RouteTable
            } -AbsentCodes @("InvalidRouteTableID.NotFound") `
            -RetryCodes @("DependencyViolation")
    }

    if ($null -ne $Resources.SecurityGroup) {
        Invoke-Lab26Removal -Service ec2 `
            -Operation delete-security-group -Request @{
                GroupId = $State.Ids.SecurityGroup
            } -AbsentCodes @("InvalidGroup.NotFound") `
            -RetryCodes @("DependencyViolation")
    }

    if ($null -ne $Resources.InternetGateway) {
        foreach ($Attachment in $Resources.InternetGateway.Attachments) {
            Invoke-Lab26Removal -Service ec2 `
                -Operation detach-internet-gateway -Request @{
                    InternetGatewayId = $State.Ids.InternetGateway
                    VpcId = $State.Ids.Vpc
                } -AbsentCodes @(
                    "InvalidInternetGatewayID.NotFound",
                    "Gateway.NotAttached"
                ) -RetryCodes @("DependencyViolation")
        }

        Invoke-Lab26Removal -Service ec2 `
            -Operation delete-internet-gateway -Request @{
                InternetGatewayId = $State.Ids.InternetGateway
            } -AbsentCodes @("InvalidInternetGatewayID.NotFound") `
            -RetryCodes @("DependencyViolation")
    }

    if ($null -ne $Resources.Vpc) {
        Invoke-Lab26Removal -Service ec2 `
            -Operation delete-vpc -Request @{
                VpcId = $State.Ids.Vpc
            } -AbsentCodes @("InvalidVpcID.NotFound") `
            -RetryCodes @("DependencyViolation")
    }

    # A instancia ja foi encerrada antes de excluir seus logs.
    if ($null -ne $LogGroup) {
        Invoke-Lab26Removal -Service logs `
            -Operation delete-log-group -Request @{
                logGroupName = $State.Ids.LogGroup
            } -AbsentCodes @("ResourceNotFoundException")
    }

    $State | Add-Member -MemberType NoteProperty `
        -Name CleanupCompleted -Value $true -Force

    $State | Add-Member -MemberType NoteProperty `
        -Name CleanupCompletedAtUtc `
        -Value ([DateTime]::UtcNow.ToString("o")) -Force

    Save-Lab26State

    Write-Host "[OK] Comandos de cleanup concluidos." `
        -ForegroundColor Green

    Write-Host "Inventario preservado: $StatePath"
    Write-Host "A verificacao final de ausencia sera executada separadamente."
}
catch {
    Write-Host "Cleanup interrompido. Inventario preservado:" `
        -ForegroundColor Yellow

    Write-Host $StatePath
    throw
}
