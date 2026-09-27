[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [ValidateSet("FailedCandidate", "ValidCandidate")]
    [string]$ReleaseMode,

    [switch]$ConfirmUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab17-controlled-update-instance"
$GroupName = "lab17-controlled-update-sg"
$ProfileResourceName = "lab17-ec2-controlled-update-instance-profile"

$ExpectedTags = @{
    Project     = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab         = "17"
    ManagedBy   = "aws-cli"
    Owner       = "itamarsb"
}

function Invoke-Aws {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $oldPreference = $ErrorActionPreference

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
        $ErrorActionPreference = $oldPreference
    }

    $output = (
        $lines | ForEach-Object {
            if ($null -ne $_) {
                $_.ToString()
            }
        }
    ) -join "`n"

    if ($exitCode -ne 0) {
        throw "AWS CLI falhou: aws $($Arguments -join ' ')`n$output"
    }

    return $output.Trim()
}

function Get-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $json = Invoke-Aws -Arguments (
        $Arguments + @("--output", "json")
    )

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "A AWS CLI não retornou JSON."
    }

    return ($json | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param(
        $Resource,
        [string]$Name
    )

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
    param(
        [string]$InstanceId,
        [string]$Script
    )

    $parameters = @{
        commands = @($Script)
    } | ConvertTo-Json -Depth 5

    $temporaryFile = Join-Path `
        ([IO.Path]::GetTempPath()) `
        ("lab17-update-{0}.json" -f [guid]::NewGuid().ToString("N"))

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
            "--comment", "Lab 17 controlled update: $ReleaseMode",
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
            if ($attempt -eq 40) {
                throw
            }

            continue
        }

        if ($invocation.Status -eq "Success") {
            Write-Host $invocation.StandardOutputContent
            return
        }

        if ($invocation.Status -in @("Failed", "Cancelled", "TimedOut")) {
            throw (
                "Run Command $commandId terminou em " +
                "$($invocation.Status). " +
                "Saída: $($invocation.StandardOutputContent) " +
                "Erro: $($invocation.StandardErrorContent)"
            )
        }
    }

    throw "Run Command $commandId não concluiu no prazo. Consulte seu CommandId."
}

try {
    if (-not $ConfirmUpdate) {
        throw "Informe -ConfirmUpdate para executar $ReleaseMode."
    }

    if ($Region -ne "us-east-1") {
        throw "Região inesperada."
    }

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }

    $identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ($identity.Account -ne "412381774441") {
        throw "Conta AWS inesperada: $($identity.Account)."
    }

    $response = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=running"
    )

    $instances = @(
        $response.Reservations |
            ForEach-Object { $_.Instances }
    )

    if ($instances.Count -ne 1) {
        throw "É necessária exatamente uma instância running do Lab 17."
    }

    $instance = $instances[0]
    Assert-Tags -Resource $instance -Name $InstanceName

    if (
        $instance.MetadataOptions.HttpTokens -ne "required" -or
        $instance.IamInstanceProfile.Arn -notmatch
            "/$([regex]::Escape($ProfileResourceName))$"
    ) {
        throw "IMDSv2 ou Instance Profile inesperado."
    }

    $groups = @(
        (Get-AwsJson -Arguments @(
            "ec2", "describe-security-groups",
            "--filters",
            "Name=group-name,Values=$GroupName",
            "Name=vpc-id,Values=$($instance.VpcId)"
        )).SecurityGroups
    )

    if ($groups.Count -ne 1) {
        throw "Security Group exclusivo ausente ou ambíguo."
    }

    Assert-Tags -Resource $groups[0] -Name $GroupName

    if (
        @($instance.SecurityGroups).Count -ne 1 -or
        $instance.SecurityGroups[0].GroupId -ne $groups[0].GroupId
    ) {
        throw "A instância utiliza outro Security Group."
    }

    $ssm = Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information",
        "--filters",
        "Key=InstanceIds,Values=$($instance.InstanceId)"
    )

    if (
        @(
            $ssm.InstanceInformationList |
                Where-Object {
                    $_.InstanceId -eq $instance.InstanceId -and
                    $_.PingStatus -eq "Online"
                }
        ).Count -ne 1
    ) {
        throw "A instância não está Online no Systems Manager."
    }

    $failedScript = @'
#!/bin/sh
set -eu

work=/var/lib/lab17
backup="$work/backup-v1"
web=/usr/share/nginx/html
conf=/etc/nginx/conf.d/lab17-release.conf

mkdir -p "$work"

test "$(cat "$web/version")" = v1
test "$(curl --noproxy '*' -fsS http://127.0.0.1/health)" = healthy
systemctl is-active --quiet nginx
nginx -t >/dev/null 2>&1

state=none
if test -f "$work/state"; then
    state=$(cat "$work/state")
fi
test "$state" = none || test "$state" = rolled-back

if test ! -d "$backup"; then
    temp=$(mktemp -d "$work/.backup.XXXXXX")
    cp -p "$web/index.html" "$web/health" "$web/version" "$conf" "$temp/"

    (
        cd "$temp"
        sha256sum index.html health version lab17-release.conf > SHA256SUMS
    )

    mv "$temp" "$backup"
fi

(
    cd "$backup"
    sha256sum -c SHA256SUMS
)

test "$(cat "$backup/version")" = v1

cat > "$conf" <<'CONF'
lab17_invalid_directive on;
CONF

if nginx -t > "$work/failed-candidate.log" 2>&1; then
    echo 'ERRO: candidata inválida foi aceita pelo Nginx' >&2
    exit 1
fi

printf 'candidate-failed\n' > "$work/state"

test "$(cat "$web/version")" = v1
test "$(curl --noproxy '*' -fsS http://127.0.0.1/health)" = healthy
systemctl is-active --quiet nginx

echo 'CANDIDATA INVÁLIDA CONFIRMADA; Nginx ativo em v1; rollback necessário.'
cat "$work/failed-candidate.log"
'@

    $validScript = @'
#!/bin/sh
set -eu

work=/var/lib/lab17
backup="$work/backup-v1"
web=/usr/share/nginx/html
conf=/etc/nginx/conf.d/lab17-release.conf

test -d "$backup"

(
    cd "$backup"
    sha256sum -c SHA256SUMS
)

test "$(cat "$work/state")" = rolled-back
test "$(cat "$web/version")" = v1
test "$(curl --noproxy '*' -fsS http://127.0.0.1/health)" = healthy
systemctl is-active --quiet nginx
nginx -t >/dev/null 2>&1

cat > "$web/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Lab 17 - Controlled Update v2</title>
</head>
<body>
  <h1>Cloud Infrastructure Operations Lab</h1>
  <p>Lab 17 - Controlled Update</p>
  <p>Release: v2</p>
  <p>Status: healthy</p>
</body>
</html>
HTML

printf 'v2\n' > "$web/version"

cat > "$conf" <<'CONF'
map $request_method $lab17_release {
    default "v2";
}
CONF

nginx -t
systemctl reload nginx

test "$(curl --noproxy '*' -fsS http://127.0.0.1/health)" = healthy
test "$(curl --noproxy '*' -fsS http://127.0.0.1/version)" = v2

printf 'updated\n' > "$work/state"
echo 'ATUALIZAÇÃO VÁLIDA APLICADA: v2; confirmação ainda pendente.'

sha256sum \
    "$web/index.html" \
    "$web/health" \
    "$web/version" \
    "$conf"
'@

    $script = if ($ReleaseMode -eq "FailedCandidate") {
        $failedScript
    }
    else {
        $validScript
    }

    Write-Host (
        "[OK] Conta: $($identity.Account); " +
        "instância: $($instance.InstanceId)"
    )

    Write-Host "Aplicando: $ReleaseMode"

    Invoke-SsmScript `
        -InstanceId $instance.InstanceId `
        -Script $script

    Write-Host "APLICAÇÃO CONCLUÍDA: $ReleaseMode" `
        -ForegroundColor Green
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host (
        "Registre o CommandId e diagnostique antes de repetir " +
        "ou iniciar o rollback."
    ) -ForegroundColor Yellow

    exit 1
}
