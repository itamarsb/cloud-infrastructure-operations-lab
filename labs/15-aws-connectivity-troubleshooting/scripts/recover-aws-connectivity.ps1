[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [string]$AllowedHttpCidr,

    [switch]$ConfirmRecovery
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab15-connectivity-troubleshooting-instance"
$GroupName = "lab15-connectivity-troubleshooting-sg"

$ExpectedTags = @{
    Project     = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab         = "15"
    ManagedBy   = "aws-cli"
    Owner       = "itamarsb"
}

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $previousPreference = $ErrorActionPreference

    try {
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

    if ($exitCode -ne 0) {
        throw "Falha na AWS CLI: aws $($Arguments -join ' ')`n$output"
    }

    return $output.Trim()
}

function Get-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = Invoke-Aws -Arguments (
        $Arguments + @("--output", "json")
    )

    if ([string]::IsNullOrWhiteSpace($output)) {
        throw "A AWS CLI não retornou o JSON esperado."
    }

    return ($output | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param(
        [Parameter(Mandatory = $true)][object[]]$Tags,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $actual = @{}

    foreach ($tag in @($Tags)) {
        $actual[[string]$tag.Key] = [string]$tag.Value
    }

    foreach ($key in $ExpectedTags.Keys) {
        if ($actual[$key] -ne $ExpectedTags[$key]) {
            throw "$Description possui tag $key ausente ou incompatível."
        }
    }

    if ($actual["Name"] -ne $Name) {
        throw "$Description possui tag Name incompatível."
    }
}

function Test-ExternalHealth {
    param([Parameter(Mandatory = $true)][string]$Address)

    try {
        $response = Invoke-WebRequest `
            -Uri "http://$Address/health" `
            -UseBasicParsing `
            -DisableKeepAlive `
            -TimeoutSec 8

        return (
            $response.StatusCode -eq 200 -and
            $response.Content.Trim() -eq "healthy"
        )
    }
    catch {
        return $false
    }
}

function Assert-LocalHealth {
    param([Parameter(Mandatory = $true)][string]$InstanceId)

    $parametersJson = @{
        commands = @(
            "set -e",
            "test `$(systemctl is-active nginx) = active",
            "nginx -t",
            "ss -lnt | grep ':80 '",
            "test `$(curl --fail --silent --show-error http://127.0.0.1/health) = healthy"
        )
    } | ConvertTo-Json -Compress -Depth 4

    $sent = Get-AwsJson -Arguments @(
        "ssm", "send-command",
        "--instance-ids", $InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--parameters", $parametersJson,
        "--comment", "Lab 15 read-only recovery precheck"
    )

    $commandId = $sent.Command.CommandId

    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "Systems Manager não retornou um Command ID."
    }

    for ($attempt = 1; $attempt -le 24; $attempt++) {
        Start-Sleep -Seconds 5

        $result = Get-AwsJson -Arguments @(
            "ssm", "get-command-invocation",
            "--command-id", $commandId,
            "--instance-id", $InstanceId
        )

        if ($result.Status -in @(
            "Pending", "InProgress", "Delayed"
        )) {
            continue
        }

        if (
            $result.Status -ne "Success" -or
            $result.ResponseCode -ne 0
        ) {
            throw (
                "A aplicação não passou na verificação local: " +
                "$($result.Status). $($result.StandardErrorContent)"
            )
        }

        return
    }

    throw "Tempo esgotado na verificação local via Systems Manager."
}

try {
    Write-Host ""
    Write-Host "=== Lab 15: recuperação da conectividade ===" `
        -ForegroundColor Cyan

    if (-not $ConfirmRecovery) {
        throw "Informe -ConfirmRecovery para autorizar a restauração da regra HTTP."
    }

    if ($Region -ne "us-east-1") {
        throw "Este laboratório foi definido para us-east-1."
    }

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }

    $parts = $AllowedHttpCidr -split "/"
    $parsedIp = $null

    if (
        $parts.Count -ne 2 -or
        $parts[1] -ne "32" -or
        -not [System.Net.IPAddress]::TryParse(
            $parts[0],
            [ref]$parsedIp
        ) -or
        $parsedIp.AddressFamily -ne
            [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {
        throw "Informe um IPv4 válido com máscara /32."
    }

    $identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ([string]::IsNullOrWhiteSpace($identity.Account)) {
        throw "Não foi possível validar a identidade AWS."
    }

    Write-Host "[OK] Conta: $($identity.Account)"

    $instanceResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=running"
    )

    $instances = @(
        $instanceResponse.Reservations |
            ForEach-Object { $_.Instances }
    )

    if ($instances.Count -ne 1) {
        throw "É necessária exatamente uma instância running do Lab 15."
    }

    $instance = $instances[0]

    Assert-Tags `
        -Tags @($instance.Tags) `
        -Description "Instância" `
        -Name $InstanceName

    if ([string]::IsNullOrWhiteSpace($instance.PublicIpAddress)) {
        throw "A instância não possui IPv4 público."
    }

    $groupResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$GroupName",
        "Name=vpc-id,Values=$($instance.VpcId)"
    )

    $groups = @($groupResponse.SecurityGroups)

    if ($groups.Count -ne 1) {
        throw "É necessário exatamente um Security Group do Lab 15."
    }

    $group = $groups[0]

    Assert-Tags `
        -Tags @($group.Tags) `
        -Description "Security Group" `
        -Name $GroupName

    $instanceGroups = @(
        $instance.SecurityGroups |
            ForEach-Object { $_.GroupId }
    )

    if (
        $instanceGroups.Count -ne 1 -or
        $instanceGroups[0] -ne $group.GroupId
    ) {
        throw "A instância utiliza Security Groups inesperados."
    }

    $ssmResponse = Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information",
        "--filters",
        "Key=InstanceIds,Values=$($instance.InstanceId)"
    )

    $online = @(
        $ssmResponse.InstanceInformationList |
            Where-Object {
                $_.InstanceId -eq $instance.InstanceId -and
                $_.PingStatus -eq "Online"
            }
    )

    if ($online.Count -ne 1) {
        throw "A instância não está Online no Systems Manager."
    }

    Assert-LocalHealth -InstanceId $instance.InstanceId

    Write-Host "[OK] Instância, Systems Manager e aplicação local saudáveis."

    $rulesResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules",
        "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )

    $matchingRules = @(
        $rulesResponse.SecurityGroupRules |
            Where-Object {
                $_.IsEgress -eq $false -and
                $_.IpProtocol -eq "tcp" -and
                $_.FromPort -eq 80 -and
                $_.ToPort -eq 80 -and
                $_.CidrIpv4 -eq $AllowedHttpCidr
            }
    )

    if ($matchingRules.Count -gt 1) {
        throw "Há regras TCP 80 duplicadas para o CIDR informado."
    }

    if ($matchingRules.Count -eq 0) {
        Write-Host ""
        Write-Host "=== Restauração da regra HTTP ===" `
            -ForegroundColor Cyan

        $null = Invoke-Aws -Arguments @(
            "ec2", "authorize-security-group-ingress",
            "--group-id", $group.GroupId,
            "--protocol", "tcp",
            "--port", "80",
            "--cidr", $AllowedHttpCidr
        )

        Write-Host "[OK] Regra TCP 80 restaurada para $AllowedHttpCidr."
    }
    else {
        Write-Host "[INFO] Regra TCP 80 já presente; nenhuma regra criada."
    }

    $verifiedRulesResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules",
        "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )

    $verifiedRules = @(
        $verifiedRulesResponse.SecurityGroupRules |
            Where-Object {
                $_.IsEgress -eq $false -and
                $_.IpProtocol -eq "tcp" -and
                $_.FromPort -eq 80 -and
                $_.ToPort -eq 80 -and
                $_.CidrIpv4 -eq $AllowedHttpCidr
            }
    )

    if ($verifiedRules.Count -ne 1) {
        throw "A regra HTTP esperada não foi confirmada após a recuperação."
    }

    $externalHealthy = $false

    for ($attempt = 1; $attempt -le 12; $attempt++) {
        if (Test-ExternalHealth -Address $instance.PublicIpAddress) {
            $externalHealthy = $true
            break
        }

        Start-Sleep -Seconds 5
    }

    if (-not $externalHealthy) {
        throw (
            "A regra HTTP está presente, mas /health ainda não está " +
            "acessível externamente. Verifique a origem da requisição."
        )
    }

    Write-Host ""
    Write-Host "[OK] Regra HTTP presente: $($verifiedRules[0].SecurityGroupRuleId)"
    Write-Host "[OK] Endpoint externo /health: healthy."
    Write-Host "[OK] Endpoint local e Systems Manager permanecem saudáveis."
    Write-Host ""
    Write-Host "CONECTIVIDADE RECUPERADA" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "[FALHA] $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host (
        "Verifique o estado da regra HTTP e do endpoint antes de " +
        "repetir a recuperação."
    ) -ForegroundColor Yellow

    exit 1
}
