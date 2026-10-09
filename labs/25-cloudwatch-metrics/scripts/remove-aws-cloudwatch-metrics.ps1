[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly
)

. (Join-Path $PSScriptRoot "lab25-common.ps1")

Initialize-Lab25

if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    throw "Inventario nao encontrado: $StatePath"
}

$script:State = Get-Content -LiteralPath $StatePath -Raw |
    ConvertFrom-Json

if (
    $State.AccountId -ne $Settings.ExpectedAccountId -or
    $State.Region -ne $Settings.Region -or
    [string]::IsNullOrWhiteSpace($State.RunId)
) {
    throw "Inventario incompativel com a conta ou Regiao."
}

$Definitions = @(
    @("Vpc", "describe-vpcs", "VpcIds", "Vpcs", "InvalidVpcID.NotFound")
    @(
        "Subnet", "describe-subnets", "SubnetIds",
        "Subnets", "InvalidSubnetID.NotFound"
    )
    @(
        "InternetGateway", "describe-internet-gateways",
        "InternetGatewayIds", "InternetGateways",
        "InvalidInternetGatewayID.NotFound"
    )
    @(
        "RouteTable", "describe-route-tables", "RouteTableIds",
        "RouteTables", "InvalidRouteTableID.NotFound"
    )
    @(
        "SecurityGroup", "describe-security-groups", "GroupIds",
        "SecurityGroups", "InvalidGroup.NotFound"
    )
)

$Resources = @{}

# Validacao de propriedade antes das exclusoes.
foreach ($Definition in $Definitions) {
    $Key = $Definition[0]
    $Resource = Get-Lab25Ec2Resource `
        -Operation $Definition[1] `
        -IdParameter $Definition[2] `
        -Id $State.Ids.$Key `
        -Collection $Definition[3] `
        -AbsentCode $Definition[4]

    $Resources[$Key] = $Resource
    if ($null -ne $Resource) {
        Assert-Lab25Ownership -Resource $Resource `
            -Name $Settings.Names.$Key

        if (
            $Key -in @("Subnet", "RouteTable", "SecurityGroup") -and
            $Resource.VpcId -ne $State.Ids.Vpc
        ) {
            throw "Recurso associado a outra VPC: $Key"
        }
    }
}

$Instance = $null
if (-not [string]::IsNullOrWhiteSpace($State.Ids.Instance)) {
    $Response = Invoke-Lab25Aws -Service ec2 `
        -Operation describe-instances -Request @{
            InstanceIds = @($State.Ids.Instance)
        } -AbsentCodes @("InvalidInstanceID.NotFound")

    if ($null -ne $Response) {
        $Instances = @(
            foreach ($Reservation in $Response.Reservations) {
                foreach ($Item in $Reservation.Instances) {
                    $Item
                }
            }
        )

        if ($Instances.Count -ne 1) {
            throw "Resposta inesperada ao consultar a instancia."
        }

        $Instance = $Instances[0]
        Assert-Lab25Ownership -Resource $Instance `
            -Name $Settings.Names.Instance

        if ($Instance.VpcId -ne $State.Ids.Vpc) {
            throw "Instancia associada a outra VPC."
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

            $State.Ids.Volume = $LiveVolumeId
        }
    }
}

$Volume = Get-Lab25Ec2Resource -Operation describe-volumes `
    -IdParameter VolumeIds -Id $State.Ids.Volume `
    -Collection Volumes -AbsentCode "InvalidVolume.NotFound"

if ($null -ne $Volume) {
    Assert-Lab25Ownership -Resource $Volume `
        -Name ($Settings.Names.Instance + "-root")
}

$Role = $null
if (-not [string]::IsNullOrWhiteSpace($State.Ids.RoleId)) {
    $Response = Invoke-Lab25Aws -Service iam `
        -Operation get-role -Request @{
            RoleName = $Settings.Names.Role
        } -AbsentCodes @("NoSuchEntity")

    if ($null -ne $Response) {
        $Role = $Response.Role
        if ($Role.RoleId -ne $State.Ids.RoleId) {
            throw "RoleId diferente do inventario."
        }

        Assert-Lab25Ownership -Resource $Role `
            -Name $Settings.Names.Role

        $Policies = Invoke-Lab25Aws -Service iam `
            -Operation list-attached-role-policies -Request @{
                RoleName = $Settings.Names.Role
            }

        if (@(
            $Policies.AttachedPolicies | Where-Object {
                $_.PolicyArn -ne $PolicyArn
            }
        ).Count -ne 0) {
            throw "A role possui politicas adicionais."
        }

        $Inline = Invoke-Lab25Aws -Service iam `
            -Operation list-role-policies -Request @{
                RoleName = $Settings.Names.Role
            }

        if (@($Inline.PolicyNames).Count -ne 0) {
            throw "A role possui politicas inline."
        }
    }
}

$InstanceProfile = $null
if (-not [string]::IsNullOrWhiteSpace($State.Ids.InstanceProfileId)) {
    $Response = Invoke-Lab25Aws -Service iam `
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

        Assert-Lab25Ownership -Resource $InstanceProfile `
            -Name $Settings.Names.InstanceProfile

        if (@(
            $InstanceProfile.Roles | Where-Object {
                $_.RoleId -ne $State.Ids.RoleId
            }
        ).Count -ne 0) {
            throw "O instance profile possui uma role diferente."
        }
    }
}

# O dashboard sera criado e removido em uma etapa propria.
$Dashboards = Invoke-Lab25Aws -Service cloudwatch `
    -Operation list-dashboards -Request @{
        DashboardNamePrefix = $Settings.Names.Dashboard
    }

if (@(
    $Dashboards.DashboardEntries | Where-Object {
        $_.DashboardName -eq $Settings.Names.Dashboard
    }
).Count -ne 0) {
    throw "Remova e valide o dashboard antes do cleanup da infraestrutura."
}

if ($null -ne $Resources.Vpc) {
    $VpcInstances = Invoke-Lab25Aws -Service ec2 `
        -Operation describe-instances -Request @{
            Filters = @(
                @{ Name = "vpc-id"; Values = @($State.Ids.Vpc) }
                @{
                    Name = "instance-state-name"
                    Values = @(
                        "pending", "running", "stopping",
                        "stopped", "shutting-down"
                    )
                }
            )
        }

    foreach ($Reservation in $VpcInstances.Reservations) {
        foreach ($Item in $Reservation.Instances) {
            if ($Item.InstanceId -ne $State.Ids.Instance) {
                throw "Outra instancia foi encontrada na VPC."
            }
        }
    }
}

Write-Host "[OK] IDs, tags e propriedade dos recursos conferidos." `
    -ForegroundColor Green

if ($ValidateOnly) {
    Write-Host "[OK] ValidateOnly: nenhum recurso AWS removido." `
        -ForegroundColor Green
    return
}

Save-Lab25State

if (
    $null -ne $Instance -and
    $Instance.State.Name -ne "terminated"
) {
    Invoke-Lab25Aws -Service ec2 -Operation terminate-instances `
        -Request @{
            InstanceIds = @($State.Ids.Instance)
        } | Out-Null

    aws ec2 wait instance-terminated `
        --instance-ids $State.Ids.Instance `
        --profile $ProfileName `
        --region $Settings.Region `
        --no-cli-pager

    if ($LASTEXITCODE -ne 0) {
        throw "Terminacao nao confirmada no prazo."
    }
}

if (-not [string]::IsNullOrWhiteSpace($State.Ids.Volume)) {
    $RemainingVolume = $null

    for ($Attempt = 1; $Attempt -le 24; $Attempt++) {
        $RemainingVolume = Get-Lab25Ec2Resource `
            -Operation describe-volumes `
            -IdParameter VolumeIds -Id $State.Ids.Volume `
            -Collection Volumes -AbsentCode "InvalidVolume.NotFound"

        if ($null -eq $RemainingVolume) {
            break
        }

        Start-Sleep -Seconds 5
    }

    if ($null -ne $RemainingVolume) {
        throw "Volume raiz ainda existe. Cleanup interrompido para diagnostico."
    }
}

if ($null -ne $InstanceProfile) {
    if (@($InstanceProfile.Roles).Count -ne 0) {
        Invoke-Lab25Aws -Service iam `
            -Operation remove-role-from-instance-profile -Request @{
                InstanceProfileName = $Settings.Names.InstanceProfile
                RoleName = $Settings.Names.Role
            } | Out-Null
    }

    Invoke-Lab25Aws -Service iam `
        -Operation delete-instance-profile -Request @{
            InstanceProfileName = $Settings.Names.InstanceProfile
        } | Out-Null
}

if ($null -ne $Role) {
    Invoke-Lab25Aws -Service iam `
        -Operation detach-role-policy -Request @{
            RoleName = $Settings.Names.Role
            PolicyArn = $PolicyArn
        } | Out-Null

    Invoke-Lab25Aws -Service iam -Operation delete-role -Request @{
        RoleName = $Settings.Names.Role
    } | Out-Null
}

if ($null -ne $Resources.Subnet) {
    Invoke-Lab25Aws -Service ec2 -Operation delete-subnet -Request @{
        SubnetId = $State.Ids.Subnet
    } | Out-Null
}

if ($null -ne $Resources.RouteTable) {
    $Associations = @(
        $Resources.RouteTable.Associations | Where-Object {
            -not $_.Main
        }
    )

    foreach ($Association in $Associations) {
        if ($Association.SubnetId -ne $State.Ids.Subnet) {
            throw "Tabela de rotas possui associacao diferente da prevista."
        }

        Invoke-Lab25Aws -Service ec2 `
            -Operation disassociate-route-table -Request @{
                AssociationId = $Association.RouteTableAssociationId
            } -AbsentCodes @("InvalidAssociationID.NotFound") | Out-Null
    }

    Invoke-Lab25Aws -Service ec2 -Operation delete-route-table `
        -Request @{
            RouteTableId = $State.Ids.RouteTable
        } | Out-Null
}

if ($null -ne $Resources.SecurityGroup) {
    Invoke-Lab25Aws -Service ec2 -Operation delete-security-group `
        -Request @{
            GroupId = $State.Ids.SecurityGroup
        } | Out-Null
}

if ($null -ne $Resources.InternetGateway) {
    foreach ($Attachment in $Resources.InternetGateway.Attachments) {
        if ($Attachment.VpcId -ne $State.Ids.Vpc) {
            throw "Internet Gateway associado a outra VPC."
        }

        Invoke-Lab25Aws -Service ec2 `
            -Operation detach-internet-gateway -Request @{
                InternetGatewayId = $State.Ids.InternetGateway
                VpcId = $State.Ids.Vpc
            } | Out-Null
    }

    Invoke-Lab25Aws -Service ec2 `
        -Operation delete-internet-gateway -Request @{
            InternetGatewayId = $State.Ids.InternetGateway
        } | Out-Null
}

if ($null -ne $Resources.Vpc) {
    Invoke-Lab25Aws -Service ec2 -Operation delete-vpc -Request @{
        VpcId = $State.Ids.Vpc
    } | Out-Null
}

$State.Completed = $true
Save-Lab25State

Write-Host "[OK] Comandos de cleanup concluidos." -ForegroundColor Green
Write-Host "Inventario preservado: $StatePath"
Write-Host "A verificacao final de ausencia sera executada separadamente."
