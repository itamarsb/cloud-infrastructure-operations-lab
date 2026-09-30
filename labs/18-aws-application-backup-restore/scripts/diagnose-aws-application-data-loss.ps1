[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [ValidateSet("us-east-1")][string]$Region = "us-east-1"
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

function Invoke-SsmDiagnostic {
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
        "--comment", "Lab 18 read only application diagnosis",
        "--parameters", (Get-FileUri -Path $parametersPath),
        "--timeout-seconds", "120",
        "--query", "Command.CommandId", "--output", "text"
    )
    if ($commandId -notmatch '^[0-9a-fA-F-]{36}$') {
        throw "A AWS CLI nao retornou um CommandId valido."
    }
    $script:lastCommandId = $commandId
    Write-Host "CommandId do diagnostico: $commandId"
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

function Show-ExternalHttp {
    param([string]$Url)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $response = @(& curl.exe --noproxy "*" --silent --show-error `
            --connect-timeout 5 --max-time 15 `
            --write-out "\nHTTP_STATUS=%{http_code}\n" $Url 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    Write-Host "$Url; curl exit=$code"
    Write-Host (($response | ForEach-Object { $_.ToString() }) -join "`n")
}

try {
    foreach ($name in @(
        "AWS_CLI_FILE_ENCODING",
        "AWS_CLI_OUTPUT_ENCODING",
        "PYTHONIOENCODING"
    )) {
        $savedEnvironment[$name] =
            [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, "UTF-8", "Process")
    }
    foreach ($command in @("aws", "curl.exe")) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Comando ausente: $command."
        }
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
    $instance = $instances[0]
    $tags = @{}
    foreach ($tag in @($instance.Tags)) {
        $tags[$tag.Key] = [string]$tag.Value
    }
    $expectedTags = @{
        Name = $InstanceName
        Project = "cloud-infrastructure-operations-lab"
        Environment = "lab"
        Lab = "18"
        ManagedBy = "aws-cli"
        Owner = "itamarsb"
    }
    foreach ($key in $expectedTags.Keys) {
        if ($tags[$key] -ne $expectedTags[$key]) {
            throw "Tag inesperada: $key."
        }
    }
    $instanceId = [string]$instance.InstanceId
    $publicIp = [string]$instance.PublicIpAddress
    if ([string]::IsNullOrWhiteSpace($publicIp)) {
        throw "Instancia sem IPv4 publico."
    }
    Write-Host "Conta: $ExpectedAccount; regiao: $Region"
    Write-Host "EC2: $instanceId; IP: $publicIp"
    Write-Host "VPC: $($instance.VpcId); sub-rede: $($instance.SubnetId)"
    foreach ($group in @($instance.SecurityGroups)) {
        $rules = Invoke-Aws @(
            "ec2", "describe-security-group-rules",
            "--filters", "Name=group-id,Values=$($group.GroupId)",
            "--output", "json"
        )
        Write-Host "Security Group: $($group.GroupId)"
        Write-Host $rules
    }
    $ssm = Get-AwsJson @(
        "ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$instanceId"
    )
    $managed = @($ssm.InstanceInformationList)
    if ($managed.Count -ne 1 -or $managed[0].PingStatus -ne "Online") {
        throw "Instancia indisponivel no Systems Manager."
    }
    Write-Host "SSM: Online"
    Write-Host "=== HTTP EXTERNO ==="
    foreach ($path in @("/", "/health", "/version")) {
        Show-ExternalHttp -Url "http://$publicIp$path"
    }
    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) (
        "lab18-diagnose-" + [guid]::NewGuid().ToString("N")
    )
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    $diagnosticScript = @'
#!/bin/bash
set -euo pipefail
test "$(cat /var/lib/lab18/account-id)" = '412381774441'
test "$(cat /var/lib/lab18/region)" = 'us-east-1'
test "$(cat /var/lib/lab18/bucket-name)" = '__BUCKET__'
python3 - <<'PYTHON'
import hashlib, json, pathlib, re, subprocess
root = pathlib.Path("/var/lib/lab18")
def read_small(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 65536:
        raise ValueError("Missing, unsafe or oversized metadata: " + str(path))
    return path.read_text(encoding="utf-8")
def run(label, args):
    print("=== " + label + " ===", flush=True)
    try:
        result = subprocess.run(args, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=20)
        print(result.stdout[:8000].strip())
        print(result.stderr[:4000].strip())
        print("EXIT_CODE=" + str(result.returncode))
    except (OSError, subprocess.TimeoutExpired) as error:
        print("COLLECTION_ERROR=" + str(error))
print("=== STATE AND OPERATION RECORDS ===")
for name in ("state", "baseline-created-at", "backup-not-before-epoch",
             "data-loss-record.json", "backup-pending.json"):
    path = root / name
    if not path.exists() and not path.is_symlink():
        print(name + ": absent")
        continue
    try:
        print(name + ": " + read_small(path).strip())
    except (OSError, UnicodeError, ValueError) as error:
        print("METADATA_ERROR=" + str(error))
files = (
    "/usr/share/nginx/html/index.html",
    "/usr/share/nginx/html/health",
    "/usr/share/nginx/html/version",
    "/etc/nginx/conf.d/lab18-app.conf",
)
manifest = {}
try:
    for line in read_small(root / "baseline.sha256").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match or match[2] in manifest:
            raise ValueError("Invalid baseline manifest")
        manifest[match[2]] = match[1]
    if set(manifest) != set(files):
        raise ValueError("Unexpected baseline paths")
except (OSError, UnicodeError, ValueError) as error:
    manifest = {}
    print("BASELINE_ERROR=" + str(error))
print("=== PROTECTED FILES ===")
for source in files:
    path = pathlib.Path(source)
    if path.is_symlink():
        print(source + ": symbolic link; not read")
    elif not path.exists():
        print(source + ": absent")
    elif not path.is_file() or path.stat().st_size > 1048576:
        print(source + ": unsafe or oversized; not read")
    else:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        comparison = "unknown" if source not in manifest else (
            "identical" if digest == manifest[source] else "different"
        )
        print(digest + "  " + source + "; baseline=" + comparison)
print("=== BACKUP RECORD ===")
try:
    backup = json.loads(read_small(root / "backup-record.json"))
    if not isinstance(backup, dict):
        raise ValueError("Backup record must be an object")
    if backup.get("Bucket") != read_small(root / "bucket-name").strip():
        raise ValueError("Unexpected bucket")
    if not re.fullmatch(r"backups/application-v1-[A-Za-z0-9._-]+\.tar\.gz", str(backup.get("Key", ""))):
        raise ValueError("Invalid backup key")
    if not re.fullmatch(r"[0-9a-f]{64}", str(backup.get("Sha256", ""))):
        raise ValueError("Invalid package SHA-256")
    version = backup.get("VersionId")
    if not isinstance(version, str) or version in ("", "null", "None"):
        raise ValueError("Invalid VersionId")
    if not backup.get("VerifiedAt") or not backup.get("CreatedAt"):
        raise ValueError("Missing verification timestamps")
    print("BACKUP_RECORD=" + json.dumps(backup, separators=(",", ":"), ensure_ascii=True))
except (OSError, UnicodeError, ValueError) as error:
    print("BACKUP_RECORD_ERROR=" + str(error))
run("NGINX PACKAGE", ["rpm", "-q", "nginx"])
run("NGINX SERVICE", ["systemctl", "is-active", "nginx"])
run("NGINX CONFIGURATION", ["nginx", "-t"])
for endpoint in ("/", "/health", "/version"):
    run("LOCAL HTTP " + endpoint,
        ["curl", "--noproxy", "*", "-sS", "--connect-timeout", "5",
         "--max-time", "10", "-w", "\nHTTP_STATUS=%{http_code}\n",
         "http://127.0.0.1" + endpoint])
run("RECENT NGINX LOGS", ["journalctl", "-u", "nginx", "-n", "20",
                          "--no-pager", "-o", "cat"])
PYTHON
'@
    $diagnosticScript = $diagnosticScript.Replace("__BUCKET__", $BucketName)
    $stdout = Invoke-SsmDiagnostic `
        -InstanceId $instanceId -Script $diagnosticScript
    $records = @(
        $stdout -split "`r?`n" |
            Where-Object { $_.StartsWith("BACKUP_RECORD=") }
    )
    if ($records.Count -eq 1) {
        $record = $records[0].Substring("BACKUP_RECORD=".Length) |
            ConvertFrom-Json
        if ($record.Bucket -ne $BucketName) {
            throw "Bucket do registro inesperado."
        }
        Write-Host "=== METADADOS DA VERSAO S3 REGISTRADA ==="
        try {
            $head = Get-AwsJson @(
                "s3api", "head-object",
                "--bucket", $BucketName,
                "--key", ([string]$record.Key),
                "--version-id", ([string]$record.VersionId),
                "--expected-bucket-owner", $ExpectedAccount
            )
            Write-Host ($head | ConvertTo-Json -Depth 10)
            if ($head.VersionId -ne $record.VersionId -or
                $head.ServerSideEncryption -ne "AES256") {
                Write-Host "[ACHADO] Versao ou criptografia inesperada."
            }
        }
        catch {
            Write-Host "[ACHADO] Consulta S3 falhou: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "[ACHADO] Registro de backup valido ausente; consulte a coleta remota."
    }
    Write-Host "DIAGNOSTICO COLETADO: arquivos, estado e objetos S3 preservados."
    $global:LASTEXITCODE = 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    if ($script:lastCommandId) {
        Write-Host "Consulte CommandId: $script:lastCommandId"
    }
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
