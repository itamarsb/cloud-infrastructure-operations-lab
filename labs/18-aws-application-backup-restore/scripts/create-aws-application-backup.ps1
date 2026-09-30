[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [ValidateSet("us-east-1")][string]$Region = "us-east-1",
    [Parameter(Mandatory = $true)][string]$AllowedHttpCidr
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

function Get-Property {
    param($Object, [string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) {
        return $Object.$Name
    }
    return $null
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

function Invoke-SsmBackup {
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
        "--comment", "Lab 18 create verified application backup",
        "--parameters", (Get-FileUri -Path $parametersPath),
        "--timeout-seconds", "120",
        "--query", "Command.CommandId", "--output", "text"
    )
    if ($commandId -notmatch '^[0-9a-fA-F-]{36}$') {
        throw "A AWS CLI nao retornou um CommandId valido."
    }
    $script:lastCommandId = $commandId
    Write-Host "CommandId da validacao: $commandId"
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
            if ($attempt % 12 -eq 0) { Write-Host "Aguardando validacao SSM: $($invocation.Status)." }
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
    foreach ($name in @("AWS_CLI_FILE_ENCODING", "AWS_CLI_OUTPUT_ENCODING", "PYTHONIOENCODING")) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, "UTF-8", "Process")
    }
    $testPath = Join-Path $PSScriptRoot "test-aws-application-backup-restore.ps1"
    if (-not (Test-Path -LiteralPath $testPath)) { throw "Script de validacao ausente." }
    & $testPath -ProfileName $ProfileName -Region $Region `
        -AllowedHttpCidr $AllowedHttpCidr -ExpectedState Baseline
    if ($LASTEXITCODE -ne 0) { throw "Baseline nao validado; backup interrompido." }
    $identity = Get-AwsJson @("sts", "get-caller-identity")
    if ($identity.Account -ne $ExpectedAccount) { throw "Conta AWS inesperada." }
    $result = Get-AwsJson @("ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName", "Name=instance-state-name,Values=running")
    $instances = @($result.Reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) { throw "Instancia running ausente ou ambigua." }
    $instanceId = [string]$instances[0].InstanceId
    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("lab18-backup-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    $backupScript = @'
#!/bin/bash
set -euo pipefail
umask 077
export AWS_PAGER=""
export AWS_CLI_FILE_ENCODING=UTF-8
export PYTHONIOENCODING=UTF-8
exec 9>/var/lib/lab18/operation.lock
flock -n 9 || { echo 'Another Lab 18 operation is running'; exit 1; }
test -f /var/lib/lab18/bootstrap-complete
test "$(cat /var/lib/lab18/state)" = baseline
test "$(cat /var/lib/lab18/bucket-name)" = '__BUCKET__'
test "$(cat /var/lib/lab18/account-id)" = '412381774441'
test "$(cat /var/lib/lab18/region)" = 'us-east-1'
nginx -t
systemctl is-active --quiet nginx
python3 - <<'PYTHON'
import datetime, hashlib, io, json, os, pathlib, re, shutil
import subprocess, tarfile, tempfile, time, uuid
root = pathlib.Path("/var/lib/lab18")
bucket = root.joinpath("bucket-name").read_text().strip()
region = "us-east-1"
account = "412381774441"
record_path = root / "backup-record.json"
pending_path = root / "backup-pending.json"
if record_path.exists() or pending_path.exists():
    raise SystemExit("A backup record already exists; diagnose before repeating")
ready = int(root.joinpath("backup-not-before-epoch").read_text().strip())
if time.time() < ready:
    when = datetime.datetime.fromtimestamp(ready, datetime.timezone.utc).isoformat()
    raise SystemExit("Versioning propagation window: retry only after " + when)
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
def aws(*args):
    command = ["aws", "s3api", *args, "--region", region,
               "--expected-bucket-owner", account, "--output", "json", "--no-cli-pager"]
    result = subprocess.run(command, capture_output=True, text=True,
                            encoding="utf-8", timeout=90)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "AWS CLI failed")
    return json.loads(result.stdout)
def save_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=True, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
if aws("get-bucket-versioning", "--bucket", bucket).get("Status") != "Enabled":
    raise SystemExit("S3 versioning is not Enabled")
created = datetime.datetime.now(datetime.timezone.utc)
key = "backups/application-v1-" + created.strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex + ".tar.gz"
work = pathlib.Path(tempfile.mkdtemp(prefix="backup-work-", dir=root))
package = work / "application.tar.gz"
print("BACKUP_WORK=" + str(work), flush=True)
snapshot = {}
for name, source in files.items():
    path = pathlib.Path(source)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 1048576:
        raise SystemExit("Invalid protected file: " + source)
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != manifest[source]:
        raise SystemExit("Active file differs from baseline: " + source)
    snapshot[name] = data
manifest_text = "".join(manifest[source] + "  " + name + "\n" for name, source in files.items())
snapshot["manifest.sha256"] = manifest_text.encode("ascii")
with tarfile.open(package, "w:gz", format=tarfile.USTAR_FORMAT) as archive:
    for name, data in snapshot.items():
        info = tarfile.TarInfo(name)
        info.size = len(data)
        info.mode = 0o644
        info.mtime = int(created.timestamp())
        archive.addfile(info, io.BytesIO(data))
digest = hashlib.sha256(package.read_bytes()).hexdigest()
record = {"Bucket": bucket, "Key": key, "Sha256": digest,
          "CreatedAt": created.isoformat(), "WorkDirectory": str(work)}
# Persist the chosen key before sending PUT, even if the response is lost.
save_json(pending_path, record)
print("BACKUP_KEY=" + key, flush=True)
response = aws("put-object", "--bucket", bucket, "--key", key,
               "--body", str(package), "--server-side-encryption", "AES256")
version = response.get("VersionId")
if not isinstance(version, str) or version in ("", "null", "None"):
    raise SystemExit("Upload did not return a valid VersionId; inspect pending record")
record["VersionId"] = version
save_json(pending_path, record)
print("BACKUP_VERSION_ID=" + version, flush=True)
downloaded = work / "downloaded.tar.gz"
retrieved = aws("get-object", "--bucket", bucket, "--key", key,
                "--version-id", version, str(downloaded))
if retrieved.get("VersionId") != version or retrieved.get("ServerSideEncryption") != "AES256":
    raise SystemExit("Downloaded version or encryption differs")
if hashlib.sha256(downloaded.read_bytes()).hexdigest() != digest:
    raise SystemExit("Downloaded package SHA-256 mismatch")
with tarfile.open(downloaded, "r:gz") as archive:
    members = archive.getmembers()
    if len(members) != len(snapshot) or {m.name for m in members} != set(snapshot):
        raise SystemExit("Unexpected archive members")
    for member in members:
        if not member.isfile() or member.size > 1048576:
            raise SystemExit("Unsafe archive member: " + member.name)
        stream = archive.extractfile(member)
        if stream is None or stream.read() != snapshot[member.name]:
            raise SystemExit("Archive content mismatch: " + member.name)
# Recheck live files before recording the BackedUp state.
for name, source in files.items():
    path = pathlib.Path(source)
    if path.is_symlink() or not path.is_file() or path.read_bytes() != snapshot[name]:
        raise SystemExit("Active file changed during backup: " + source)
record["VerifiedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
record.pop("WorkDirectory")
save_json(record_path, record)
pending_path.unlink()
state_tmp = root / "state.tmp"
state_tmp.write_text("backed-up\n", encoding="ascii")
os.replace(state_tmp, root / "state")
shutil.rmtree(work)
print("BACKUP_RECORD=" + json.dumps(record, separators=(",", ":"), ensure_ascii=True))
print("BACKUP_VERIFIED=package_hash_and_manifest")
print("STATE=backed-up")
PYTHON
'@
    $backupScript = $backupScript.Replace("__BUCKET__", $BucketName)
    Invoke-SsmBackup -InstanceId $instanceId -Script $backupScript | Out-Null
    & $testPath -ProfileName $ProfileName -Region $Region `
        -AllowedHttpCidr $AllowedHttpCidr -ExpectedState BackedUp
    if ($LASTEXITCODE -ne 0) { throw "Backup criado, mas BackedUp nao foi validado." }
    Write-Host "BACKUP CONCLUIDO E VALIDADO"
    $global:LASTEXITCODE = 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    if ($script:lastCommandId) { Write-Host "Consulte CommandId: $script:lastCommandId" }
    Write-Host "Registre a saida. Nao repita um upload sem conferir o estado e backup-pending.json."
    exit 1
}
finally {
    if ($tempDirectory -and (Test-Path -LiteralPath $tempDirectory)) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], "Process")
    }
}
