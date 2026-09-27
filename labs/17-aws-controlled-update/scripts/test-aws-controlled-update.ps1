[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [string]$AllowedHttpCidr,

    [ValidateSet("Baseline", "CandidateFailed", "RolledBack", "Updated", "Confirmed")]
    [string]$ExpectedReleaseState = "Baseline"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExpectedAccount = "412381774441"
$InstanceName = "lab17-controlled-update-instance"
$GroupName = "lab17-controlled-update-sg"
$RoleName = "lab17-ec2-controlled-update-role"
$ProfileNameAws = "lab17-ec2-controlled-update-instance-profile"
$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& aws @Arguments --profile $ProfileName --region $Region `
            --no-cli-pager 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }

    $output = ($lines | ForEach-Object {
        if ($null -ne $_) { $_.ToString() }
    }) -join "`n"

    if ($exitCode -ne 0) {
        throw "AWS CLI falhou: aws $($Arguments -join ' ')`n$output"
    }
    return $output.Trim()
}

function Get-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $json = Invoke-Aws -Arguments ($Arguments + @("--output", "json"))
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "A AWS CLI não retornou JSON."
    }
    return ($json | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param($Resource, [string]$Name, [string]$Lab)
    $actual = @{}
    foreach ($tag in @($Resource.Tags)) {
        $actual[[string]$tag.Key] = [string]$tag.Value
    }
    $expected = @{
        Name = $Name
        Project = "cloud-infrastructure-operations-lab"
        Environment = "lab"
        Lab = $Lab
        ManagedBy = "aws-cli"
        Owner = "itamarsb"
    }
    foreach ($key in $expected.Keys) {
        if ($actual[$key] -ne $expected[$key]) {
            throw "Tag $key incorreta em $Name."
        }
    }
}

function Get-HttpBody {
    param([string]$Url)
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& curl.exe --noproxy "*" --fail --silent `
            --show-error --max-time 10 $Url 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
    if ($exitCode -ne 0) {
        throw "Falha HTTP em ${Url}: $($lines -join ' ')"
    }
    return (($lines | ForEach-Object { $_.ToString() }) -join "`n").Trim()
}

function Invoke-ReadOnlySsm {
    param([string]$InstanceId)

    $commands = @(
        "printf 'NGINX_ACTIVE='; systemctl is-active nginx || true",
        "printf 'NGINX_CONFIG='; if nginx -t >/dev/null 2>&1; then echo valid; else echo invalid; fi",
        "printf 'LOCAL_HEALTH='; curl --noproxy '*' -fsS --max-time 5 http://127.0.0.1/health || true; echo",
        "printf 'LOCAL_VERSION='; curl --noproxy '*' -fsS --max-time 5 http://127.0.0.1/version || true; echo",
        "printf 'RELEASE_STATE='; if test -f /var/lib/lab17/state; then cat /var/lib/lab17/state; else echo none; fi",
        "printf 'NGINX_PACKAGE='; rpm -q nginx || true",
        "sha256sum /usr/share/nginx/html/index.html /usr/share/nginx/html/health /usr/share/nginx/html/version /etc/nginx/conf.d/lab17-release.conf 2>/dev/null || true"
    )

    $parameters = @{ commands = $commands } | ConvertTo-Json -Depth 5
    $temporaryFile = Join-Path ([IO.Path]::GetTempPath()) `
        ("lab17-readonly-{0}.json" -f [guid]::NewGuid().ToString("N"))

    try {
        [IO.File]::WriteAllText(
            $temporaryFile,
            $parameters,
            (New-Object System.Text.UTF8Encoding($false))
        )
        $uri = "file://$($temporaryFile.Replace('\', '/'))"
        $response = Get-AwsJson -Arguments @(
            "ssm", "send-command",
            "--instance-ids", $InstanceId,
            "--document-name", "AWS-RunShellScript",
            "--comment", "Lab 17 read-only release validation",
            "--parameters", $uri,
            "--timeout-seconds", "90"
        )
    }
    finally {
        if (Test-Path -LiteralPath $temporaryFile -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryFile -Force
        }
    }

    $commandId = [string]$response.Command.CommandId
    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "O Systems Manager não retornou CommandId."
    }

    for ($attempt = 1; $attempt -le 30; $attempt++) {
        Start-Sleep -Seconds 3
        try {
            $invocation = Get-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $commandId,
                "--instance-id", $InstanceId
            )
        }
        catch {
            if ($attempt -eq 30) { throw }
            continue
        }

        if ($invocation.Status -eq "Success") {
            return [string]$invocation.StandardOutputContent
        }
        if ($invocation.Status -in @("Failed", "Cancelled", "TimedOut")) {
            throw "Run Command $commandId terminou em $($invocation.Status): $($invocation.StandardErrorContent)"
        }
    }
    throw "Run Command $commandId não concluiu no prazo."
}

function Get-Field {
    param([string]$Output, [string]$Name)
    $match = [regex]::Match($Output, "(?m)^$([regex]::Escape($Name))=([^`r`n]*)")
    if (-not $match.Success) {
        throw "Campo $Name ausente na resposta do Systems Manager."
    }
    return $match.Groups[1].Value.Trim()
}

try {
    if ($Region -ne "us-east-1") { throw "Região inesperada." }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        throw "curl.exe não encontrado."
    }

    $parts = $AllowedHttpCidr -split "/"
    $parsedIp = $null
    if ($parts.Count -ne 2 -or $parts[1] -ne "32" -or
        -not [Net.IPAddress]::TryParse($parts[0], [ref]$parsedIp) -or
        $parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Informe o IPv4 público atual com máscara /32."
    }

    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    if ($identity.Account -ne $ExpectedAccount) {
        throw "Conta AWS inesperada: $($identity.Account)."
    }

    $vpcs = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs", "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )).Vpcs )
    if ($vpcs.Count -ne 1) { throw "VPC do Lab 08 ausente ou ambígua." }
    $vpc = $vpcs[0]
    Assert-Tags -Resource $vpc -Name $VpcName -Lab "08"

    $subnets = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-subnets", "--filters",
        "Name=tag:Name,Values=$SubnetName",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )).Subnets )
    if ($subnets.Count -ne 1) { throw "Sub-rede do Lab 08 ausente ou ambígua." }
    $subnet = $subnets[0]
    Assert-Tags -Resource $subnet -Name $SubnetName -Lab "08"

    $response = Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=running"
    )
    $instances = @($response.Reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) {
        throw "É necessária exatamente uma instância running do Lab 17."
    }
    $instance = $instances[0]
    Assert-Tags -Resource $instance -Name $InstanceName -Lab "17"
    if ($instance.VpcId -ne $vpc.VpcId -or
        $instance.SubnetId -ne $subnet.SubnetId -or
        $instance.MetadataOptions.HttpTokens -ne "required" -or
        [string]::IsNullOrWhiteSpace($instance.PublicIpAddress)) {
        throw "Instância fora da rede esperada ou sem IMDSv2/IPv4 público."
    }
    if ($instance.PSObject.Properties["KeyName"] -and $instance.KeyName) {
        throw "A instância possui Key Pair inesperado."
    }
    $instanceId = [string]$instance.InstanceId
    $publicIp = [string]$instance.PublicIpAddress

    $groups = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups", "--filters",
        "Name=group-name,Values=$GroupName",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )).SecurityGroups )
    if ($groups.Count -ne 1) { throw "Security Group exclusivo ausente ou ambíguo." }
    $group = $groups[0]
    Assert-Tags -Resource $group -Name $GroupName -Lab "17"
    if (@($instance.SecurityGroups | Where-Object {
        $_.GroupId -eq $group.GroupId
    }).Count -ne 1 -or @($instance.SecurityGroups).Count -ne 1) {
        throw "A instância não usa exclusivamente o Security Group do Lab 17."
    }
    $rules = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules", "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )).SecurityGroupRules )
    $ingress = @($rules | Where-Object { -not $_.IsEgress })
    if ($ingress.Count -ne 1 -or
        $ingress[0].IpProtocol -ne "tcp" -or
        $ingress[0].FromPort -ne 80 -or
        $ingress[0].ToPort -ne 80 -or
        $ingress[0].CidrIpv4 -ne $AllowedHttpCidr) {
        throw "Regras de entrada diferentes de TCP 80 para $AllowedHttpCidr."
    }

    $profiles = @( (Get-AwsJson -Arguments @(
        "iam", "get-instance-profile",
        "--instance-profile-name", $ProfileNameAws
    )).InstanceProfile )
    if ($profiles.Count -ne 1 -or
        $instance.IamInstanceProfile.Arn -ne $profiles[0].Arn -or
        @($profiles[0].Roles).Count -ne 1 -or
        $profiles[0].Roles[0].RoleName -ne $RoleName) {
        throw "Instance Profile ou IAM Role incompatível."
    }
    $attached = @( (Get-AwsJson -Arguments @(
        "iam", "list-attached-role-policies", "--role-name", $RoleName
    )).AttachedPolicies )
    if (@($attached | Where-Object { $_.PolicyArn -eq $PolicyArn }).Count -ne 1) {
        throw "Política AmazonSSMManagedInstanceCore ausente."
    }

    $ssm = Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$instanceId"
    )
    if (@($ssm.InstanceInformationList | Where-Object {
        $_.InstanceId -eq $instanceId -and $_.PingStatus -eq "Online"
    }).Count -ne 1) {
        throw "Instância não está Online no Systems Manager."
    }

    $local = Invoke-ReadOnlySsm -InstanceId $instanceId
    $nginx = Get-Field -Output $local -Name "NGINX_ACTIVE"
    $config = Get-Field -Output $local -Name "NGINX_CONFIG"
    $health = Get-Field -Output $local -Name "LOCAL_HEALTH"
    $version = Get-Field -Output $local -Name "LOCAL_VERSION"
    $state = Get-Field -Output $local -Name "RELEASE_STATE"
    $externalHealth = Get-HttpBody -Url "http://$publicIp/health"
    $externalVersion = Get-HttpBody -Url "http://$publicIp/version"

    $expectations = @{
        Baseline        = @{ Version = "v1"; Config = "valid"; State = "none" }
        CandidateFailed = @{ Version = "v1"; Config = "invalid"; State = "candidate-failed" }
        RolledBack      = @{ Version = "v1"; Config = "valid"; State = "rolled-back" }
        Updated         = @{ Version = "v2"; Config = "valid"; State = "updated" }
        Confirmed       = @{ Version = "v2"; Config = "valid"; State = "confirmed" }
    }
    $expected = $expectations[$ExpectedReleaseState]
    if ($nginx -ne "active" -or $health -ne "healthy" -or
        $externalHealth -ne "healthy" -or
        $config -ne $expected.Config -or
        $version -ne $expected.Version -or
        $externalVersion -ne $expected.Version -or
        $state -ne $expected.State) {
        throw "Estado divergente. Esperado=$ExpectedReleaseState; Nginx=$nginx; Config=$config; Health=$health/$externalHealth; Versão=$version/$externalVersion; Marcador=$state."
    }

    Write-Host "[OK] Conta: $ExpectedAccount; VPC: $($vpc.VpcId); sub-rede: $($subnet.SubnetId)"
    Write-Host "[OK] EC2: $instanceId; SSM: Online; HTTP: $AllowedHttpCidr"
    Write-Host "[OK] Nginx: $nginx; configuração: $config; /health: $health"
    Write-Host "[OK] Versão local e externa: $version; marcador: $state"
    Write-Host "Hashes observados:"
    $local -split "`n" | Where-Object { $_ -match "^[a-fA-F0-9]{64}\s" } |
        ForEach-Object { Write-Host $_ }
    Write-Host "VALIDAÇÃO CONCLUÍDA: $ExpectedReleaseState" -ForegroundColor Green
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
