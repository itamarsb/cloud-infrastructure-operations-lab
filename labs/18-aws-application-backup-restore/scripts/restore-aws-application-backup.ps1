[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [ValidateSet("us-east-1")][string]$Region = "us-east-1",
    [Parameter(Mandatory = $true)][string]$AllowedHttpCidr,
    [switch]$ConfirmRestore
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

function Invoke-SsmRestore {
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
        "--comment", "Lab 18 restore registered backup version",
        "--parameters", (Get-FileUri -Path $parametersPath),
        "--timeout-seconds", "120",
        "--query", "Command.CommandId", "--output", "text"
    )
    if ($commandId -notmatch '^[0-9a-fA-F-]{36}$') {
        throw "A AWS CLI nao retornou um CommandId valido."
    }
    $script:lastCommandId = $commandId
    Write-Host "CommandId da restauracao: $commandId"
    for ($attempt = 1; $attempt -le 80; $attempt++) {
        try {
            $invocation = Get-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $commandId, "--instance-id", $InstanceId
            )
        }
        catch {
            if ($_.Exception.Message -notmatch "InvocationDoesNotExist") {
                throw
            }
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
    if (-not $ConfirmRestore) {
        throw "Use -ConfirmRestore para autorizar a restauracao."
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
        -AllowedHttpCidr $AllowedHttpCidr -ExpectedState DataLoss
    if ($LASTEXITCODE -ne 0) {
        throw "DataLoss nao validado; restauracao interrompida."
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
        "lab18-restore-" + [guid]::NewGuid().ToString("N")
    )
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    $restoreScript = @'
#!/bin/bash
set -euo pipefail
umask 077
export AWS_PAGER=""
export AWS_CLI_FILE_ENCODING=UTF-8
export PYTHONIOENCODING=UTF-8
exec 9>/var/lib/lab18/operation.lock
flock -n 9 || { echo 'Another Lab 18 operation is running'; exit 1; }
test -f /var/lib/lab18/bootstrap-complete
test "$(cat /var/lib/lab18/state)" = data-loss
test "$(cat /var/lib/lab18/bucket-name)" = '__BUCKET__'
test "$(cat /var/lib/lab18/account-id)" = '412381774441'
test "$(cat /var/lib/lab18/region)" = 'us-east-1'
nginx -t
systemctl is-active --quiet nginx
python3 - <<'PYTHON'
import datetime, hashlib, json, os, pathlib, re, shutil
import subprocess, tarfile, tempfile, uuid
root = pathlib.Path("/var/lib/lab18")
started = datetime.datetime.now(datetime.timezone.utc)
pending_path = root / "restore-pending.json"
record_path = root / "restore-record.json"
for name in ("backup-pending.json", "restore-pending.json", "restore-record.json"):
    path = root / name
    if path.exists() or path.is_symlink():
        raise SystemExit("Operation record exists; diagnose before repeating: " + name)
def read_small(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 65536:
        raise ValueError("Invalid metadata: " + str(path))
    return path.read_text(encoding="utf-8")
def timestamp(value):
    parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("Timestamp must include a timezone")
    return parsed.astimezone(datetime.timezone.utc)
def save_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=True, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
files = {
    "index.html": "/usr/share/nginx/html/index.html",
    "health": "/usr/share/nginx/html/health",
    "version": "/usr/share/nginx/html/version",
    "lab18-app.conf": "/etc/nginx/conf.d/lab18-app.conf",
}
manifest = {}
for line in read_small(root / "baseline.sha256").splitlines():
    match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
    if not match or match[2] in manifest:
        raise SystemExit("Invalid baseline manifest")
    manifest[match[2]] = match[1]
if set(manifest) != set(files.values()):
    raise SystemExit("Unexpected protected paths")
def check_active(missing):
    for name, source in files.items():
        path = pathlib.Path(source)
        if missing and name in ("index.html", "version"):
            if path.exists() or path.is_symlink():
                raise SystemExit("Expected missing file: " + source)
        else:
            if path.is_symlink() or not path.is_file() or path.stat().st_size > 1048576:
                raise SystemExit("Invalid active file: " + source)
            if hashlib.sha256(path.read_bytes()).hexdigest() != manifest[source]:
                raise SystemExit("Active file differs from baseline: " + source)
check_active(True)
backup = json.loads(read_small(root / "backup-record.json"))
loss = json.loads(read_small(root / "data-loss-record.json"))
if not isinstance(backup, dict) or not isinstance(loss, dict):
    raise SystemExit("Operation records must be objects")
bucket = read_small(root / "bucket-name").strip()
if backup.get("Bucket") != bucket:
    raise SystemExit("Unexpected backup bucket")
if not re.fullmatch(r"backups/application-v1-[A-Za-z0-9._-]+\.tar\.gz", str(backup.get("Key", ""))):
    raise SystemExit("Invalid backup key")
if not re.fullmatch(r"[0-9a-f]{64}", str(backup.get("Sha256", ""))):
    raise SystemExit("Invalid package SHA-256")
version = backup.get("VersionId")
if not isinstance(version, str) or version in ("", "null", "None"):
    raise SystemExit("Invalid VersionId")
for field in ("Bucket", "Key", "VersionId", "Sha256"):
    if loss.get(field) != backup[field]:
        raise SystemExit("Loss record references another backup: " + field)
if loss.get("RemovedFiles") != [files["index.html"], files["version"]]:
    raise SystemExit("Unexpected removed paths")
if loss.get("BackupCreatedAt") != backup.get("CreatedAt"):
    raise SystemExit("Backup creation timestamp differs")
created = timestamp(backup["CreatedAt"])
verified = timestamp(backup["VerifiedAt"])
loss_started = timestamp(loss["StartedAt"])
deleted = timestamp(loss["DeletionCompletedAt"])
if not created <= verified <= loss_started <= deleted <= started:
    raise SystemExit("Unexpected operation timestamps")
work = pathlib.Path(tempfile.mkdtemp(prefix="restore-work-", dir=root))
package = work / "downloaded.tar.gz"
operation = {
    "StartedAt": started.isoformat(), "WorkDirectory": str(work),
    "Bucket": bucket, "Key": backup["Key"], "VersionId": version,
    "Sha256": backup["Sha256"], "DataLossStartedAt": loss["StartedAt"],
}
save_json(pending_path, operation)
print("RESTORE_WORK=" + str(work), flush=True)
print("RESTORE_VERSION_ID=" + version, flush=True)
command = [
    "aws", "s3api", "get-object", "--bucket", bucket,
    "--key", backup["Key"], "--version-id", version,
    "--expected-bucket-owner", "412381774441", "--region", "us-east-1",
    "--output", "json", "--no-cli-pager", str(package),
]
result = subprocess.run(command, capture_output=True, text=True,
                        encoding="utf-8", timeout=90)
if result.returncode:
    raise RuntimeError(result.stderr.strip() or "S3 download failed")
response = json.loads(result.stdout)
if response.get("VersionId") != version or response.get("ServerSideEncryption") != "AES256":
    raise SystemExit("Downloaded version or encryption differs")
if package.stat().st_size > 8388608:
    raise SystemExit("Backup package exceeds the lab size limit")
if hashlib.sha256(package.read_bytes()).hexdigest() != backup["Sha256"]:
    raise SystemExit("Downloaded package SHA-256 mismatch")
payload = {}
with tarfile.open(package, "r:gz") as archive:
    members = archive.getmembers()
    expected = set(files) | {"manifest.sha256"}
    if len(members) != 5 or {m.name for m in members} != expected:
        raise SystemExit("Unexpected archive members")
    for member in members:
        if not member.isfile() or member.size > 1048576:
            raise SystemExit("Unsafe archive member: " + member.name)
        stream = archive.extractfile(member)
        if stream is None:
            raise SystemExit("Unreadable archive member: " + member.name)
        data = stream.read(1048577)
        if len(data) != member.size:
            raise SystemExit("Archive member size mismatch")
        payload[member.name] = data
expected_manifest = "".join(
    manifest[source] + "  " + name + "\n" for name, source in files.items()
).encode("ascii")
if payload["manifest.sha256"] != expected_manifest:
    raise SystemExit("Archive manifest differs from baseline")
for name, source in files.items():
    if hashlib.sha256(payload[name]).hexdigest() != manifest[source]:
        raise SystemExit("Archive file hash mismatch: " + name)
print("BACKUP_VERIFIED=version_package_hash_and_manifest", flush=True)
# Recheck active files after downloading, before restoring either target.
check_active(True)
staged = {}
for name in ("index.html", "version"):
    target = pathlib.Path(files[name])
    temporary = target.with_name(".lab18-restore-" + uuid.uuid4().hex + ".tmp")
    with temporary.open("xb") as stream:
        stream.write(payload[name])
        stream.flush()
        os.fsync(stream.fileno())
    os.chmod(temporary, 0o644)
    staged[name] = temporary
operation["StagedFiles"] = {name: str(path) for name, path in staged.items()}
save_json(pending_path, operation)
for name in ("index.html", "version"):
    os.replace(staged[name], files[name])
    print("RESTORED=" + files[name], flush=True)
check_active(False)
subprocess.run(["nginx", "-t"], check=True, timeout=20)
subprocess.run(["systemctl", "is-active", "--quiet", "nginx"], check=True, timeout=20)
for endpoint, expected_body in (
    ("/", "Lab 18 - Application Backup and Restore"),
    ("/health", "healthy"), ("/version", "v1"),
):
    reply = subprocess.run(
        ["curl", "--noproxy", "*", "-sS", "--connect-timeout", "5",
         "--max-time", "10", "-w", "\nHTTP_STATUS=%{http_code}",
         "http://127.0.0.1" + endpoint],
        capture_output=True, text=True, encoding="utf-8", timeout=15, check=True,
    ).stdout
    body, separator, status = reply.rpartition("\nHTTP_STATUS=")
    valid_body = expected_body in body if endpoint == "/" else body.strip() == expected_body
    if not separator or status.strip() != "200" or not valid_body:
        raise SystemExit("Local HTTP validation failed: " + endpoint)
    print("LOCAL_HTTP=" + endpoint + ":200")
recovered = datetime.datetime.now(datetime.timezone.utc)
operation.pop("WorkDirectory")
operation.pop("StagedFiles")
operation["LocalRecoveryObservedAt"] = recovered.isoformat()
operation["ObservedRecoverySeconds"] = round((recovered - loss_started).total_seconds(), 3)
operation["RestoreOperationSeconds"] = round((recovered - started).total_seconds(), 3)
operation["BackupAgeSecondsAtLoss"] = round((loss_started - created).total_seconds(), 3)
save_json(record_path, operation)
state_tmp = root / "state.tmp"
state_tmp.write_text("restored\n", encoding="ascii")
os.replace(state_tmp, root / "state")
pending_path.unlink()
shutil.rmtree(work)
for source in files.values():
    print(manifest[source] + "  " + source)
print("RESTORE_RECORD=" + json.dumps(operation, separators=(",", ":"), ensure_ascii=True))
print("STATE=restored")
PYTHON
'@
    $restoreScript = $restoreScript.Replace("__BUCKET__", $BucketName)
    Invoke-SsmRestore -InstanceId $instanceId -Script $restoreScript | Out-Null
    & $testPath -ProfileName $ProfileName -Region $Region `
        -AllowedHttpCidr $AllowedHttpCidr -ExpectedState Restored
    if ($LASTEXITCODE -ne 0) {
        throw "Arquivos recuperados, mas Restored nao foi validado."
    }
    Write-Host "RESTAURACAO CONCLUIDA E VALIDADA: v1"
    $global:LASTEXITCODE = 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    if ($script:lastCommandId) {
        Write-Host "Consulte CommandId: $script:lastCommandId"
    }
    Write-Host "Registre a saida. Nao repita a restauracao; consulte o estado, restore-pending.json e restore-record.json."
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
