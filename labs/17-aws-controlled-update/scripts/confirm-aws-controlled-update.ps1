[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [string]$AllowedHttpCidr,

    [switch]$ConfirmUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExpectedAccount = "412381774441"
$InstanceName = "lab17-controlled-update-instance"
$GroupName = "lab17-controlled-update-sg"
$ProfileResourceName = "lab17-ec2-controlled-update-instance-profile"
$ExpectedTags = @{
    Project = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab = "17"
    ManagedBy = "aws-cli"
    Owner = "itamarsb"
}

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
    param($Resource, [string]$Name)
    $actual = @{}
    foreach ($tag in @($Resource.Tags)) {
        $actual[[string]$tag.Key] = [string]$tag.Value
    }
    if ($actual["Name"] -ne $Name) {
        throw "Tag Name incompatível em $Name."
    }
    foreach ($key in $ExpectedTags.Keys) {
        if ($actual[$key] -ne $ExpectedTags[$key]) {
            throw "Tag $key incompatível em $Name."
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

function Invoke-SsmScript {
    param([string]$InstanceId, [string]$Script)
    $parameters = @{ commands = @($Script) } | ConvertTo-Json -Depth 5
    $temporaryFile = Join-Path ([IO.Path]::GetTempPath()) `
        ("lab17-confirm-{0}.json" -f [guid]::NewGuid().ToString("N"))
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
            "--comment", "Lab 17 confirm verified v2 update",
            "--parameters", $uri,
            "--timeout-seconds", "120"
        )
    }
    finally {
        if (Test-Path -LiteralPath $temporaryFile -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryFile -Force
        }
    }

    $commandId = [string]$response.Command.CommandId
    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "Systems Manager não retornou CommandId."
    }
    Write-Host "CommandId: $commandId"

    for ($attempt = 1; $attempt -le 40; $attempt++) {
        Start-Sleep -Seconds 3
        try {
            $invocation = Get-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $commandId,
                "--instance-id", $InstanceId
            )
        }
        catch {
            if ($attempt -eq 40) { throw }
            continue
        }
        if ($invocation.Status -eq "Success") {
            Write-Host $invocation.StandardOutputContent
            return
        }
        if ($invocation.Status -in @("Failed", "Cancelled", "TimedOut")) {
            throw "Run Command $commandId terminou em $($invocation.Status). Saída: $($invocation.StandardOutputContent) Erro: $($invocation.StandardErrorContent)"
        }
    }
    throw "Run Command $commandId não concluiu no prazo. Consulte seu CommandId."
}

try {
    if (-not $ConfirmUpdate) {
        throw "Informe -ConfirmUpdate para confirmar a versão v2."
    }
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
    Assert-Tags -Resource $instance -Name $InstanceName
    if ($instance.MetadataOptions.HttpTokens -ne "required" -or
        $instance.IamInstanceProfile.Arn -notmatch
            "/$([regex]::Escape($ProfileResourceName))$" -or
        [string]::IsNullOrWhiteSpace($instance.PublicIpAddress)) {
        throw "IMDSv2, Instance Profile ou IPv4 público inesperado."
    }

    $groups = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups", "--filters",
        "Name=group-name,Values=$GroupName",
        "Name=vpc-id,Values=$($instance.VpcId)"
    )).SecurityGroups )
    if ($groups.Count -ne 1) {
        throw "Security Group exclusivo ausente ou ambíguo."
    }
    Assert-Tags -Resource $groups[0] -Name $GroupName
    if (@($instance.SecurityGroups).Count -ne 1 -or
        $instance.SecurityGroups[0].GroupId -ne $groups[0].GroupId) {
        throw "A instância utiliza outro Security Group."
    }
    $rules = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules", "--filters",
        "Name=group-id,Values=$($groups[0].GroupId)"
    )).SecurityGroupRules )
    $ingress = @($rules | Where-Object { -not $_.IsEgress })
    if ($ingress.Count -ne 1 -or
        $ingress[0].IpProtocol -ne "tcp" -or
        $ingress[0].FromPort -ne 80 -or
        $ingress[0].ToPort -ne 80 -or
        $ingress[0].CidrIpv4 -ne $AllowedHttpCidr) {
        throw "Regras de entrada diferentes de TCP 80 para $AllowedHttpCidr."
    }

    $ssm = Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$($instance.InstanceId)"
    )
    if (@($ssm.InstanceInformationList | Where-Object {
        $_.InstanceId -eq $instance.InstanceId -and $_.PingStatus -eq "Online"
    }).Count -ne 1) {
        throw "A instância não está Online no Systems Manager."
    }

    $publicIp = [string]$instance.PublicIpAddress
    if ((Get-HttpBody -Url "http://$publicIp/health") -ne "healthy" -or
        (Get-HttpBody -Url "http://$publicIp/version") -ne "v2") {
        throw "A versão v2 não está saudável pelo acesso externo."
    }

    $script = @'
#!/bin/sh
set -eu

work=/var/lib/lab17
backup="$work/backup-v1"
web=/usr/share/nginx/html
conf=/etc/nginx/conf.d/lab17-release.conf

state=$(cat "$work/state")
case "$state" in
    updated|confirmed) ;;
    *) echo "Estado $state não admite confirmação" >&2; exit 1 ;;
esac
test -f "$backup/SHA256SUMS"
(cd "$backup" && sha256sum -c SHA256SUMS)
test "$(cat "$backup/version")" = v1
test "$(cat "$web/version")" = v2
test "$(cat "$web/health")" = healthy
grep -Fq 'Release: v2' "$web/index.html"
grep -Fq 'default "v2";' "$conf"
systemctl is-active --quiet nginx
nginx -t
test "$(curl --noproxy '*' -fsS http://127.0.0.1/health)" = healthy
test "$(curl --noproxy '*' -fsS http://127.0.0.1/version)" = v2

if test "$state" = updated; then
    printf 'confirmed\n' > "$work/state"
fi
test "$(cat "$work/state")" = confirmed
echo 'ATUALIZAÇÃO CONFIRMADA: versão v2 saudável; backup v1 preservado.'
sha256sum "$web/index.html" "$web/health" "$web/version" "$conf"
'@

    Write-Host "[OK] Conta: $($identity.Account); instância: $($instance.InstanceId)"
    Write-Host "[OK] /health externo: healthy; /version externo: v2"
    Invoke-SsmScript -InstanceId $instance.InstanceId -Script $script

    if ((Get-HttpBody -Url "http://$publicIp/health") -ne "healthy" -or
        (Get-HttpBody -Url "http://$publicIp/version") -ne "v2") {
        throw "Falha na verificação externa após a confirmação; examine o CommandId."
    }
    Write-Host "CONFIRMAÇÃO CONCLUÍDA: v2" -ForegroundColor Green
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Registre o CommandId e execute o validador antes de novas alterações." -ForegroundColor Yellow
    exit 1
}
