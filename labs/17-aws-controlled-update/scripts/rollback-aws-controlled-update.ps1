[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [switch]$ConfirmRollback
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

function Invoke-SsmScript {
    param([string]$InstanceId, [string]$Script)
    $parameters = @{ commands = @($Script) } | ConvertTo-Json -Depth 5
    $temporaryFile = Join-Path ([IO.Path]::GetTempPath()) `
        ("lab17-rollback-{0}.json" -f [guid]::NewGuid().ToString("N"))
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
            "--comment", "Lab 17 restore verified v1 backup",
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
    if (-not $ConfirmRollback) {
        throw "Informe -ConfirmRollback para restaurar a versão v1."
    }
    if ($Region -ne "us-east-1") {
        throw "Região inesperada."
    }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }
    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    if ($identity.Account -ne "412381774441") {
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
            "/$([regex]::Escape($ProfileResourceName))$") {
        throw "IMDSv2 ou Instance Profile inesperado."
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

    $ssm = Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$($instance.InstanceId)"
    )
    if (@($ssm.InstanceInformationList | Where-Object {
        $_.InstanceId -eq $instance.InstanceId -and $_.PingStatus -eq "Online"
    }).Count -ne 1) {
        throw "A instância não está Online no Systems Manager."
    }

    $script = @'
#!/bin/sh
set -eu

work=/var/lib/lab17
backup="$work/backup-v1"
web=/usr/share/nginx/html
conf=/etc/nginx/conf.d/lab17-release.conf

test -d "$backup"
test -f "$backup/SHA256SUMS"
(cd "$backup" && sha256sum -c SHA256SUMS)
test "$(cat "$backup/version")" = v1

state=none
if test -f "$work/state"; then state=$(cat "$work/state"); fi
case "$state" in
    candidate-failed|updated|rolled-back) ;;
    *) echo "Estado $state não admite rollback" >&2; exit 1 ;;
esac

cp -p "$backup/index.html" "$web/index.html"
cp -p "$backup/health" "$web/health"
cp -p "$backup/version" "$web/version"
cp -p "$backup/lab17-release.conf" "$conf"

nginx -t
if systemctl is-active --quiet nginx; then
    systemctl reload nginx
else
    systemctl start nginx
fi
test "$(curl --noproxy '*' -fsS http://127.0.0.1/health)" = healthy
test "$(curl --noproxy '*' -fsS http://127.0.0.1/version)" = v1
test "$(cat "$web/version")" = v1

cmp -s "$backup/index.html" "$web/index.html"
cmp -s "$backup/health" "$web/health"
cmp -s "$backup/version" "$web/version"
cmp -s "$backup/lab17-release.conf" "$conf"
printf 'rolled-back\n' > "$work/state"
echo 'ROLLBACK CONCLUÍDO: arquivos idênticos ao backup, Nginx saudável em v1.'
sha256sum "$web/index.html" "$web/health" "$web/version" "$conf"
'@

    Write-Host "[OK] Conta: $($identity.Account); instância: $($instance.InstanceId)"
    Invoke-SsmScript -InstanceId $instance.InstanceId -Script $script
    Write-Host "ROLLBACK CONCLUÍDO: v1" -ForegroundColor Green
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Conserve o backup e registre o CommandId antes de novas alterações." -ForegroundColor Yellow
    exit 1
}
