[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [ValidateSet("us-east-1")][string]$Region = "us-east-1",
    [Parameter(Mandatory = $true)][string]$AllowedHttpCidr,
    [switch]$ConfirmDataLoss
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ExpectedAccount = "412381774441"
$InstanceName = "lab18-application-backup-instance"
$BucketName = "lab18-app-backup-$ExpectedAccount-$Region"
$tempDirectory = $null
$script:lastCommandId = ""
$savedEnvironment = @{}

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $response = @(& aws @Arguments --profile $ProfileName `
            --region $Region --no-cli-pager 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    $output = ($response | ForEach-Object { $_.ToString() }) -join "`n"
    if ($code -ne 0) {
        throw "AWS CLI falhou: aws $($Arguments -join ' ')`n$output"
    }
    return $output.Trim()
}

function Get-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = Invoke-Aws -Arguments ($Arguments + @("--output", "json"))
    if ([string]::IsNullOrWhiteSpace($output)) {
        throw "Resposta JSON vazia da AWS CLI."
    }
    return ($output | ConvertFrom-Json -ErrorAction Stop)
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $normalized = $Content.Replace("`r`n", "`n").Replace("`r", "`n")
    [IO.File]::WriteAllText(
        $Path, $normalized, (New-Object System.Text.UTF8Encoding($false))
    )
}

function Write-JsonFile {
    param([string]$Path, $Value)
    Write-Utf8File -Path $Path -Content ($Value | ConvertTo-Json -Depth 20)
}

function Get-FileUri {
    param([string]$Path)
    return "file://$($Path.Replace('\', '/'))"
}

function Invoke-SsmDataLoss {
    param([string]$InstanceId, [string]$Script)
    $normalizedScript = $Script.Replace("`r`n", "`n").Replace("`r", "`n")
    $parametersPath = Join-Path $tempDirectory "ssm-validation.json"
    Write-JsonFile -Path $parametersPath -Value @{
        commands = @($normalizedScript)
        executionTimeout = @("300")
    }
    $commandId = Invoke-Aws -Arguments @(
        "ssm", "send-command", "--instance-ids", $InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--comment", "Lab 18 controlled application data loss",
        "--parameters", (Get-FileUri -Path $parametersPath),
        "--timeout-seconds", "120",
        "--query", "Command.CommandId", "--output", "text"
    )
    if ($commandId -notmatch '^[0-9a-fA-F-]{36}$') {
        throw "A AWS CLI nao retornou um CommandId valido."
    }
    $script:lastCommandId = $commandId
    Write-Host "CommandId da perda controlada: $commandId"
    for ($attempt = 1; $attempt -le 80; $attempt++) {
        try {
            $invocation = Get-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $commandId, "--instance-id", $InstanceId
            )
        }
        catch {
            if ($_.Exception.Message -notmatch "InvocationDoesNotExist") { throw }
            Start-Sleep -Seconds 5
            continue
        }
        if ($invocation.Status -in @("Pending", "InProgress", "Delayed")) {
            if ($attempt % 12 -eq 0) {
                Write-Host "Aguardando validacao SSM: $($invocation.Status)."
            }
            Start-Sleep -Seconds 5
            continue
        }
        if ($invocation.StandardOutputContent) {
            Write-Host $invocation.StandardOutputContent.Trim()
        }
        if ($invocation.StandardErrorContent) {
            Write-Host $invocation.StandardErrorContent.Trim()
        }
        if ($invocation.Status -ne "Success" -or $invocation.ResponseCode -ne 0) {
            throw "Validacao SSM falhou: $($invocation.Status); CommandId=$commandId."
        }
        return [string]$invocation.StandardOutputContent
    }
    throw "Prazo de observacao SSM excedido. Consulte CommandId=$commandId."
}

try {
    if (-not $ConfirmDataLoss) {
        throw "Use -ConfirmDataLoss para autorizar a perda controlada."
    }
    foreach ($name in @(
        "AWS_CLI_FILE_ENCODING",
        "AWS_CLI_OUTPUT_ENCODING",
        "PYTHONIOENCODING"
    )) {
        $savedEnvironment[$name] =
            [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, "UTF-8", "Process")
    }
    $testPath = Join-Path $PSScriptRoot "test-aws-application-backup-restore.ps1"
    if (-not (Test-Path -LiteralPath $testPath)) {
        throw "Script de validacao ausente."
    }
    & $testPath -ProfileName $ProfileName -Region $Region `
        -AllowedHttpCidr $AllowedHttpCidr -ExpectedState BackedUp
    if ($LASTEXITCODE -ne 0) {
        throw "BackedUp nao validado; perda interrompida."
    }
    $identity = Get-AwsJson @("sts", "get-caller-identity")
    if ($identity.Account -ne $ExpectedAccount) {
        throw "Conta AWS inesperada."
    }
    $result = Get-AwsJson @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=running"
    )
    $instances = @($result.Reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) {
        throw "Instancia running ausente ou ambigua."
    }
    $instanceId = [string]$instances[0].InstanceId
    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) (
        "lab18-data-loss-" + [guid]::NewGuid().ToString("N")
    )
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    $lossScript = @'
#!/bin/bash
set -euo pipefail
umask 077
exec 9>/var/lib/lab18/operation.lock
flock -n 9 || { echo 'Another Lab 18 operation is running'; exit 1; }
test -f /var/lib/lab18/bootstrap-complete
test "$(cat /var/lib/lab18/state)" = backed-up
test "$(cat /var/lib/lab18/bucket-name)" = '__BUCKET__'
test "$(cat /var/lib/lab18/account-id)" = '412381774441'
test "$(cat /var/lib/lab18/region)" = 'us-east-1'
nginx -t
systemctl is-active --quiet nginx
python3 - <<'PYTHON'
import datetime, hashlib, json, os, pathlib, re
root = pathlib.Path("/var/lib/lab18")
loss_path = root / "data-loss-record.json"
if loss_path.exists() or root.joinpath("backup-pending.json").exists():
    raise SystemExit("An operation record exists; diagnose before repeating")
files = {
    "index.html": "/usr/share/nginx/html/index.html",
    "health": "/usr/share/nginx/html/health",
    "version": "/usr/share/nginx/html/version",
    "lab18-app.conf": "/etc/nginx/conf.d/lab18-app.conf",
}
manifest = {}
for line in root.joinpath("baseline.sha256").read_text().splitlines():
    match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
    if not match or match[2] in manifest:
        raise SystemExit("Invalid baseline manifest")
    manifest[match[2]] = match[1]
if set(manifest) != set(files.values()):
    raise SystemExit("Unexpected protected paths")
for source in files.values():
    path = pathlib.Path(source)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 1048576:
        raise SystemExit("Invalid protected file: " + source)
    if hashlib.sha256(path.read_bytes()).hexdigest() != manifest[source]:
        raise SystemExit("Active file differs from baseline: " + source)
backup = json.loads(root.joinpath("backup-record.json").read_text())
if backup.get("Bucket") != root.joinpath("bucket-name").read_text().strip():
    raise SystemExit("Unexpected backup bucket")
if not re.fullmatch(r"backups/application-v1-[A-Za-z0-9._-]+\.tar\.gz", str(backup.get("Key", ""))):
    raise SystemExit("Invalid backup key")
if not re.fullmatch(r"[0-9a-f]{64}", str(backup.get("Sha256", ""))):
    raise SystemExit("Invalid package SHA-256")
version = backup.get("VersionId")
if not isinstance(version, str) or version in ("", "null", "None"):
    raise SystemExit("Invalid backup VersionId")
def timestamp(value):
    parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("Timestamp must include a timezone")
    return parsed.astimezone(datetime.timezone.utc)
created = timestamp(backup["CreatedAt"])
verified = timestamp(backup["VerifiedAt"])
started = datetime.datetime.now(datetime.timezone.utc)
if not created <= verified <= started:
    raise SystemExit("Unexpected backup timestamps")
def save_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=True, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
loss = {
    "StartedAt": started.isoformat(),
    "BackupCreatedAt": backup["CreatedAt"],
    "BackupAgeSeconds": round((started - created).total_seconds(), 3),
    "Bucket": backup["Bucket"], "Key": backup["Key"],
    "VersionId": version, "Sha256": backup["Sha256"],
    "RemovedFiles": [files["index.html"], files["version"]],
}
# Persist the start before deleting; a partial failure must be diagnosed.
save_json(loss_path, loss)
print("DATA_LOSS_STARTED_AT=" + loss["StartedAt"], flush=True)
for name in ("index.html", "version"):
    pathlib.Path(files[name]).unlink()
    print("REMOVED=" + files[name], flush=True)
for name in ("health", "lab18-app.conf"):
    path = pathlib.Path(files[name])
    if path.is_symlink() or not path.is_file():
        raise SystemExit("Preserved file is invalid: " + str(path))
    if hashlib.sha256(path.read_bytes()).hexdigest() != manifest[str(path)]:
        raise SystemExit("Preserved file changed: " + str(path))
loss["DeletionCompletedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
save_json(loss_path, loss)
state_tmp = root / "state.tmp"
state_tmp.write_text("data-loss\n", encoding="ascii")
os.replace(state_tmp, root / "state")
print("DATA_LOSS_RECORD=" + json.dumps(loss, separators=(",", ":"), ensure_ascii=True))
print("STATE=data-loss")
PYTHON
nginx -t
systemctl is-active --quiet nginx
'@
    $lossScript = $lossScript.Replace("__BUCKET__", $BucketName)
    Invoke-SsmDataLoss -InstanceId $instanceId -Script $lossScript | Out-Null
    & $testPath -ProfileName $ProfileName -Region $Region `
        -AllowedHttpCidr $AllowedHttpCidr -ExpectedState DataLoss
    if ($LASTEXITCODE -ne 0) {
        throw "Perda aplicada, mas DataLoss nao foi validado."
    }
    Write-Host "PERDA CONTROLADA APLICADA E VALIDADA"
    $global:LASTEXITCODE = 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    if ($script:lastCommandId) {
        Write-Host "Consulte CommandId: $script:lastCommandId"
    }
    Write-Host "Registre a saida. Nao repita a perda; consulte o estado e data-loss-record.json."
    exit 1
}
finally {
    if ($tempDirectory -and (Test-Path -LiteralPath $tempDirectory)) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable(
            $name, $savedEnvironment[$name], "Process"
        )
    }
}
