[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [switch]$ConfirmRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab15-connectivity-troubleshooting-instance"
$GroupName = "lab15-connectivity-troubleshooting-sg"
$RoleName = "lab15-ec2-connectivity-troubleshooting-role"
$ProfileResourceName = "lab15-ec2-connectivity-troubleshooting-instance-profile"
$SsmPolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

$ExpectedTags = @{
    Project     = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab         = "15"
    ManagedBy   = "aws-cli"
    Owner       = "itamarsb"
}

function Invoke-AwsNative {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $previousPreference = $ErrorActionPreference

    try {
        # Compatibilidade com o tratamento de stderr no Windows PowerShell 5.1.
        $ErrorActionPreference = "Continue"

        $lines = @(
            & aws @Arguments `
                --profile $ProfileName `
                --region $Region `
                --no-cli-pager 2>&1
        )

        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    $output = (
        $lines | ForEach-Object {
            if ($null -ne $_) {
                $_.ToString()
            }
        }
    ) -join "`n"

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output.Trim()
    }
}

function Invoke-Aws {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $result = Invoke-AwsNative -Arguments $Arguments

    if ($result.ExitCode -ne 0) {
        throw (
            "Falha na AWS CLI: aws $($Arguments -join ' ')" +
            "`n$($result.Output)"
        )
    }

    return $result.Output
}

function Get-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = Invoke-Aws -Arguments (
        $Arguments + @("--output", "json")
    )

    if ([string]::IsNullOrWhiteSpace($output)) {
        throw "A AWS CLI não retornou o JSON esperado."
    }

    return ($output | ConvertFrom-Json -ErrorAction Stop)
}

function Get-OptionalIamResource {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $result = Invoke-AwsNative -Arguments (
        $Arguments + @("--output", "json")
    )

    if ($result.ExitCode -eq 0) {
        return ($result.Output | ConvertFrom-Json -ErrorAction Stop)
    }

    if ($result.Output -match "NoSuchEntity") {
        return $null
    }

    throw "Falha ao consultar $Description`: $($result.Output)"
}

function Assert-ExpectedTags {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedName
    )

    $actual = @{}

    foreach ($tag in @($Tags)) {
        $actual[[string]$tag.Key] = [string]$tag.Value
    }

    foreach ($key in $ExpectedTags.Keys) {
        if ($actual[$key] -ne $ExpectedTags[$key]) {
            throw (
                "$Description possui tag $key ausente ou incompatível. " +
                "Remoção recusada."
            )
        }
    }

    if ($actual["Name"] -ne $ExpectedName) {
        throw "$Description possui tag Name incompatível. Remoção recusada."
    }
}

try {
    Write-Host ""
    Write-Host "=== Cleanup do Lab 15 ===" -ForegroundColor Cyan

    if (-not $ConfirmRemoval) {
        throw "Informe -ConfirmRemoval para autorizar a remoção."
    }

    if ($Region -ne "us-east-1") {
        throw "Este laboratório foi definido para a região us-east-1."
    }

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }

    $identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ([string]::IsNullOrWhiteSpace($identity.Account)) {
        throw "Não foi possível validar a identidade AWS."
    }

    Write-Host "[OK] Conta AWS: $($identity.Account)"
    Write-Host "[OK] Região: $Region"

    Write-Host ""
    Write-Host "=== Inventário e validação de propriedade ===" `
        -ForegroundColor Cyan

    # A busca por nome não filtra pelas tags de propriedade: assim,
    # um recurso com o nome esperado e tags incorretas bloqueia o cleanup.
    $instanceResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down"
    )

    $instances = @(
        $instanceResponse.Reservations |
            ForEach-Object { $_.Instances }
    )

    if ($instances.Count -gt 1) {
        throw "Mais de uma instância ativa usa o nome $InstanceName."
    }

    $instance = $null

    if ($instances.Count -eq 1) {
        $instance = $instances[0]

        Assert-ExpectedTags `
            -Tags @($instance.Tags) `
            -Description "Instância EC2" `
            -ExpectedName $InstanceName

        Write-Host "[OK] Instância: $($instance.InstanceId)"
    }
    else {
        Write-Host "[INFO] Nenhuma instância ativa do Lab 15."
    }

    $groupResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$GroupName"
    )

    $groups = @($groupResponse.SecurityGroups)

    if ($groups.Count -gt 1) {
        throw "Mais de um Security Group usa o nome $GroupName."
    }

    $group = $null

    if ($groups.Count -eq 1) {
        $group = $groups[0]

        Assert-ExpectedTags `
            -Tags @($group.Tags) `
            -Description "Security Group" `
            -ExpectedName $GroupName

        Write-Host "[OK] Security Group: $($group.GroupId)"
    }
    else {
        Write-Host "[INFO] Security Group do Lab 15 ausente."
    }

    $roleResponse = Get-OptionalIamResource `
        -Arguments @(
            "iam", "get-role",
            "--role-name", $RoleName
        ) `
        -Description "IAM Role"

    $role = $null

    if ($null -ne $roleResponse) {
        $role = $roleResponse.Role

        $roleTags = Get-AwsJson -Arguments @(
            "iam", "list-role-tags",
            "--role-name", $RoleName
        )

        Assert-ExpectedTags `
            -Tags @($roleTags.Tags) `
            -Description "IAM Role" `
            -ExpectedName $RoleName

        Write-Host "[OK] IAM Role: $RoleName"
    }
    else {
        Write-Host "[INFO] IAM Role do Lab 15 ausente."
    }

    $profileResponse = Get-OptionalIamResource `
        -Arguments @(
            "iam", "get-instance-profile",
            "--instance-profile-name", $ProfileResourceName
        ) `
        -Description "Instance Profile"

    $instanceProfile = $null

    if ($null -ne $profileResponse) {
        $instanceProfile = $profileResponse.InstanceProfile

        $profileTags = Get-AwsJson -Arguments @(
            "iam", "list-instance-profile-tags",
            "--instance-profile-name", $ProfileResourceName
        )

        Assert-ExpectedTags `
            -Tags @($profileTags.Tags) `
            -Description "Instance Profile" `
            -ExpectedName $ProfileResourceName

        $profileRoles = @($instanceProfile.Roles)

        if (
            $profileRoles.Count -gt 1 -or
            ($profileRoles.Count -eq 1 -and
                $profileRoles[0].RoleName -ne $RoleName)
        ) {
            throw (
                "O Instance Profile contém uma Role inesperada. " +
                "Remoção recusada."
            )
        }

        Write-Host "[OK] Instance Profile: $ProfileResourceName"
    }
    else {
        Write-Host "[INFO] Instance Profile do Lab 15 ausente."
    }

    if ($null -ne $instance) {
        if ($null -eq $group) {
            throw "A instância existe, mas o Security Group esperado não foi encontrado."
        }

        $instanceGroupIds = @(
            $instance.SecurityGroups |
                ForEach-Object { $_.GroupId }
        )

        if (
            $instanceGroupIds.Count -ne 1 -or
            $instanceGroupIds[0] -ne $group.GroupId
        ) {
            throw (
                "A instância utiliza Security Groups inesperados. " +
                "Remoção recusada."
            )
        }

        if (
            $instance.IamInstanceProfile.Arn -notmatch
                "/$([regex]::Escape($ProfileResourceName))$"
        ) {
            throw (
                "A instância utiliza outro Instance Profile. " +
                "Remoção recusada."
            )
        }

        if ($null -eq $instanceProfile -or $null -eq $role) {
            throw (
                "A instância existe, mas seus recursos IAM esperados " +
                "não foram encontrados."
            )
        }
    }

    if ($null -ne $group) {
        $interfacesResponse = Get-AwsJson -Arguments @(
            "ec2", "describe-network-interfaces",
            "--filters",
            "Name=group-id,Values=$($group.GroupId)"
        )

        $interfaces = @($interfacesResponse.NetworkInterfaces)

        foreach ($networkInterface in $interfaces) {
            if (
                $null -eq $instance -or
                $networkInterface.Attachment.InstanceId -ne
                    $instance.InstanceId
            ) {
                throw (
                    "O Security Group está associado a uma interface " +
                    "que não pertence à instância do Lab 15. " +
                    "Remoção recusada."
                )
            }
        }

        $inboundReferences = Get-AwsJson -Arguments @(
            "ec2", "describe-security-groups",
            "--filters",
            "Name=ip-permission.group-id,Values=$($group.GroupId)"
        )

        $outboundReferences = Get-AwsJson -Arguments @(
            "ec2", "describe-security-groups",
            "--filters",
            "Name=egress.ip-permission.group-id,Values=$($group.GroupId)"
        )

        $externalReferences = @(
            @($inboundReferences.SecurityGroups) +
            @($outboundReferences.SecurityGroups) |
                Where-Object {
                    $_.GroupId -ne $group.GroupId
                }
        )
        if ($externalReferences.Count -gt 0) {
            throw (
                "Outro Security Group referencia o grupo do Lab 15. " +
                "Remoção recusada."
            )
        }
    }

    if ($null -ne $role) {
        $attachedResponse = Get-AwsJson -Arguments @(
            "iam", "list-attached-role-policies",
            "--role-name", $RoleName
        )

        $attachedPolicies = @($attachedResponse.AttachedPolicies)

        foreach ($policy in $attachedPolicies) {
            if ($policy.PolicyArn -ne $SsmPolicyArn) {
                throw (
                    "A IAM Role possui uma política gerenciada " +
                    "inesperada. Remoção recusada."
                )
            }
        }

        $inlineResponse = Get-AwsJson -Arguments @(
            "iam", "list-role-policies",
            "--role-name", $RoleName
        )

        if (@($inlineResponse.PolicyNames).Count -gt 0) {
            throw (
                "A IAM Role possui políticas inline. " +
                "Remoção recusada."
            )
        }

        $profilesForRole = Get-AwsJson -Arguments @(
            "iam", "list-instance-profiles-for-role",
            "--role-name", $RoleName
        )

        $otherProfiles = @(
            $profilesForRole.InstanceProfiles |
                Where-Object {
                    $_.InstanceProfileName -ne $ProfileResourceName
                }
        )

        if ($otherProfiles.Count -gt 0) {
            throw (
                "A IAM Role está vinculada a outro Instance Profile. " +
                "Remoção recusada."
            )
        }
    }

    if (
        $null -eq $instance -and
        $null -eq $group -and
        $null -eq $role -and
        $null -eq $instanceProfile
    ) {
        Write-Host ""
        Write-Host "[OK] Nenhum recurso exclusivo do Lab 15 para remover." `
            -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "=== Remoção da instância ===" -ForegroundColor Cyan

    if ($null -ne $instance) {
        $null = Invoke-Aws -Arguments @(
            "ec2", "terminate-instances",
            "--instance-ids", $instance.InstanceId
        )

        $null = Invoke-Aws -Arguments @(
            "ec2", "wait", "instance-terminated",
            "--instance-ids", $instance.InstanceId
        )

        Write-Host "[OK] Instância encerrada: $($instance.InstanceId)"
    }
    else {
        Write-Host "[INFO] Etapa dispensada."
    }

    Write-Host ""
    Write-Host "=== Remoção do Security Group ===" `
        -ForegroundColor Cyan

    if ($null -ne $group) {
        $groupDeleted = $false

        # A interface de rede da instância pode levar algum tempo para
        # desaparecer depois do estado terminated.
        for ($attempt = 1; $attempt -le 18; $attempt++) {
            $result = Invoke-AwsNative -Arguments @(
                "ec2", "delete-security-group",
                "--group-id", $group.GroupId
            )

            if ($result.ExitCode -eq 0) {
                $groupDeleted = $true
                break
            }

            if ($result.Output -notmatch "DependencyViolation") {
                throw (
                    "Falha ao remover Security Group " +
                    "$($group.GroupId)`: $($result.Output)"
                )
            }

            Start-Sleep -Seconds 10
        }

        if (-not $groupDeleted) {
            throw (
                "O Security Group ainda possui dependências. " +
                "Verifique as interfaces de rede antes de repetir o cleanup."
            )
        }

        Write-Host "[OK] Security Group removido: $($group.GroupId)"
    }
    else {
        Write-Host "[INFO] Etapa dispensada."
    }

    Write-Host ""
    Write-Host "=== Remoção do Instance Profile ===" `
        -ForegroundColor Cyan

    if ($null -ne $instanceProfile) {
        if (@($instanceProfile.Roles).Count -eq 1) {
            $null = Invoke-Aws -Arguments @(
                "iam", "remove-role-from-instance-profile",
                "--instance-profile-name", $ProfileResourceName,
                "--role-name", $RoleName
            )
        }

        $null = Invoke-Aws -Arguments @(
            "iam", "delete-instance-profile",
            "--instance-profile-name", $ProfileResourceName
        )

        Write-Host "[OK] Instance Profile removido."
    }
    else {
        Write-Host "[INFO] Etapa dispensada."
    }

    Write-Host ""
    Write-Host "=== Remoção da IAM Role ===" -ForegroundColor Cyan

    if ($null -ne $role) {
        if (
            @($attachedPolicies | Where-Object {
                $_.PolicyArn -eq $SsmPolicyArn
            }).Count -eq 1
        ) {
            $null = Invoke-Aws -Arguments @(
                "iam", "detach-role-policy",
                "--role-name", $RoleName,
                "--policy-arn", $SsmPolicyArn
            )
        }

        $null = Invoke-Aws -Arguments @(
            "iam", "delete-role",
            "--role-name", $RoleName
        )

        Write-Host "[OK] IAM Role removida."
    }
    else {
        Write-Host "[INFO] Etapa dispensada."
    }

    Write-Host ""
    Write-Host "=== Validação pós-cleanup ===" `
        -ForegroundColor Cyan

    $remainingGroups = Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$GroupName"
    )

    if (@($remainingGroups.SecurityGroups).Count -ne 0) {
        throw "O Security Group do Lab 15 ainda está presente."
    }

    $remainingRole = Get-OptionalIamResource `
        -Arguments @(
            "iam", "get-role",
            "--role-name", $RoleName
        ) `
        -Description "IAM Role"

    if ($null -ne $remainingRole) {
        throw "A IAM Role do Lab 15 ainda está presente."
    }

    $remainingProfile = Get-OptionalIamResource `
        -Arguments @(
            "iam", "get-instance-profile",
            "--instance-profile-name", $ProfileResourceName
        ) `
        -Description "Instance Profile"

    if ($null -ne $remainingProfile) {
        throw "O Instance Profile do Lab 15 ainda está presente."
    }

    Write-Host "[OK] Recursos exclusivos removidos."
    Write-Host "[OK] Nenhuma operação alterou a rede compartilhada do Lab 08."
    Write-Host ""
    Write-Host "CLEANUP CONCLUÍDO" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "[FALHA] $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host (
        "O cleanup pode estar parcial. Confira o inventário " +
        "antes de executar novamente."
    ) -ForegroundColor Yellow

    exit 1
}
