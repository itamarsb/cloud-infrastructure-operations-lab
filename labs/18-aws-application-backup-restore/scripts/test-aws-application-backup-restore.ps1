[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [ValidateSet("us-east-1")][string]$Region = "us-east-1",
    [Parameter(Mandatory = $true)][string]$AllowedHttpCidr,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Baseline", "BackedUp", "DataLoss", "Restored")]
    [string]$ExpectedState
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ExpectedAccount = "412381774441"
$InstanceName = "lab18-application-backup-instance"
$GroupName = "lab18-application-backup-sg"
$RoleName = "lab18-ec2-application-backup-role"
$InstanceProfileName = "lab18-ec2-application-backup-instance-profile"
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

function Assert-Tags {
    param($Tags, [string]$Lab, [string]$Name)
    $actual = @{}
    foreach ($tag in @($Tags)) {
        if ($null -ne $tag) { $actual[[string]$tag.Key] = [string]$tag.Value }
    }
    $expected = @{
        Name = $Name; Lab = $Lab; Owner = "itamarsb"
        Project = "cloud-infrastructure-operations-lab"
        Environment = "lab"; ManagedBy = "aws-cli"
    }
    foreach ($key in $expected.Keys) {
        if ($actual[$key] -ne $expected[$key]) {
            throw "Tags incompativeis: $Name; chave=$key."
        }
    }
}

function Test-Http {
    param([string]$Url, [int]$Status, [string]$Body, [switch]$Contains)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& curl.exe --noproxy "*" --silent --show-error `
            --connect-timeout 5 --max-time 10 `
            --write-out '\nHTTP_STATUS=%{http_code}' $Url 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    if ($code -ne 0 -or $lines.Count -eq 0) { throw "Falha de transporte HTTP: $Url." }
    if ($lines[-1].ToString().Trim() -ne "HTTP_STATUS=$Status") {
        throw "HTTP inesperado: ${Url}; $($lines[-1])."
    }
    $content = (($lines | Select-Object -SkipLast 1 | ForEach-Object {
        $_.ToString()
    }) -join "`n").Trim()
    if ($Status -eq 200) {
        if ($Contains) {
            if (-not $content.Contains($Body)) { throw "Conteudo HTTP inesperado: $Url." }
        }
        elseif ($content -ne $Body) { throw "Conteudo HTTP inesperado: $Url." }
    }
    Write-Host "[OK] ${Url}: HTTP $Status."
}

function Invoke-SsmValidation {
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
        "--comment", "Lab 18 read-only state validation",
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
    foreach ($command in @("aws", "curl.exe")) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Comando obrigatorio ausente: $command."
        }
    }
    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    if ($identity.Account -ne $ExpectedAccount) { throw "Conta AWS inesperada." }
    if ($AllowedHttpCidr -notmatch '^([0-9.]+)/32$') { throw "Informe um IPv4 /32." }
    $parsedIp = $null
    if (-not [Net.IPAddress]::TryParse($Matches[1], [ref]$parsedIp) -or
        $parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
        throw "IPv4 invalido."
    }
    $ip = @(& curl.exe --noproxy "*" -fsS https://checkip.amazonaws.com)
    if ($LASTEXITCODE -ne 0 -or (($ip -join "").Trim() + "/32") -ne $AllowedHttpCidr) {
        throw "IPv4 publico diferente da origem autorizada."
    }
    $result = Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down"
    )
    $instances = @($result.Reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) { throw "Esperada exatamente uma instancia do LAB 18." }
    $instance = $instances[0]
    Assert-Tags $instance.Tags "18" $InstanceName
    if ($instance.State.Name -ne "running") { throw "EC2 nao esta running." }
    $instanceId = [string]$instance.InstanceId
    $publicIp = [string](Get-Property $instance "PublicIpAddress")
    $address = $null
    if (-not [Net.IPAddress]::TryParse($publicIp, [ref]$address) -or
        $address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
        throw "EC2 sem IPv4 publico valido."
    }
    $vpc = (Get-AwsJson @("ec2", "describe-vpcs", "--vpc-ids", $instance.VpcId)).Vpcs[0]
    $subnet = (Get-AwsJson @("ec2", "describe-subnets", "--subnet-ids", $instance.SubnetId)).Subnets[0]
    Assert-Tags $vpc.Tags "08" "lab08-application-vpc"
    Assert-Tags $subnet.Tags "08" "lab08-public-subnet-a"
    if ($subnet.VpcId -ne $vpc.VpcId) { throw "Rede compartilhada inconsistente." }
    if (@($instance.SecurityGroups).Count -ne 1) { throw "EC2 com grupos inesperados." }
    $groupId = $instance.SecurityGroups[0].GroupId
    $group = (Get-AwsJson @("ec2", "describe-security-groups", "--group-ids", $groupId)).SecurityGroups[0]
    Assert-Tags $group.Tags "18" $GroupName
    if ($group.GroupName -ne $GroupName -or $group.VpcId -ne $vpc.VpcId) {
        throw "Security Group inesperado."
    }
    $rules = @((Get-AwsJson @("ec2", "describe-security-group-rules", "--filters",
        "Name=group-id,Values=$groupId")).SecurityGroupRules | Where-Object { -not $_.IsEgress })
    if ($rules.Count -ne 1 -or $rules[0].IpProtocol -ne "tcp" -or
        $rules[0].FromPort -ne 80 -or $rules[0].ToPort -ne 80 -or
        (Get-Property $rules[0] "CidrIpv4") -ne $AllowedHttpCidr) {
        throw "Entrada HTTP diferente do escopo esperado."
    }
    $profile = (Get-AwsJson @("iam", "get-instance-profile", "--instance-profile-name",
        $InstanceProfileName)).InstanceProfile
    Assert-Tags $profile.Tags "18" $InstanceProfileName
    if ($instance.IamInstanceProfile.Arn -ne $profile.Arn -or
        @($profile.Roles).Count -ne 1 -or $profile.Roles[0].RoleName -ne $RoleName) {
        throw "Instance Profile ou role inesperados."
    }
    $role = (Get-AwsJson @("iam", "get-role", "--role-name", $RoleName)).Role
    Assert-Tags $role.Tags "18" $RoleName
    $ssm = @((Get-AwsJson @("ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$instanceId")).InstanceInformationList)
    if ($ssm.Count -ne 1 -or $ssm[0].PingStatus -ne "Online") { throw "SSM nao esta Online." }

    $ownerArgs = @("--bucket", $BucketName, "--expected-bucket-owner", $ExpectedAccount)
    $tags = (Get-AwsJson (@("s3api", "get-bucket-tagging") + $ownerArgs)).TagSet
    Assert-Tags $tags "18" $BucketName
    $versioning = Get-AwsJson (@("s3api", "get-bucket-versioning") + $ownerArgs)
    if ($versioning.Status -ne "Enabled") { throw "Versionamento S3 nao esta Enabled." }
    $block = (Get-AwsJson (@("s3api", "get-public-access-block") + $ownerArgs)).PublicAccessBlockConfiguration
    foreach ($key in @("BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets")) {
        if ((Get-Property $block $key) -ne $true) { throw "Bloqueio publico incompleto: $key." }
    }
    $ownership = (Get-AwsJson (@("s3api", "get-bucket-ownership-controls") + $ownerArgs)).OwnershipControls.Rules
    if (@($ownership).Count -ne 1 -or $ownership[0].ObjectOwnership -ne "BucketOwnerEnforced") {
        throw "Propriedade S3 inesperada."
    }
    $encryption = (Get-AwsJson (@("s3api", "get-bucket-encryption") + $ownerArgs)).ServerSideEncryptionConfiguration.Rules
    if (@($encryption).Count -ne 1 -or
        $encryption[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm -ne "AES256") {
        throw "Criptografia S3 diferente de SSE-S3."
    }
    Write-Host "[OK] Conta: $ExpectedAccount; EC2: $instanceId; SSM: Online."
    Write-Host "[OK] Rede, IAM, HTTP /32 e protecoes do bucket validados."
    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("lab18-test-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    $stateMarker = @{
        Baseline = "baseline"; BackedUp = "backed-up"
        DataLoss = "data-loss"; Restored = "restored"
    }[$ExpectedState]
    $validationScript = @'
#!/bin/bash
set -euo pipefail
export AWS_PAGER=""
expected="__STATE__"
bucket="__BUCKET__"
test -f /var/lib/lab18/bootstrap-complete
test "$(cat /var/lib/lab18/state)" = "$expected"
test "$(cat /var/lib/lab18/bucket-name)" = "$bucket"
test "$(cat /var/lib/lab18/account-id)" = "412381774441"
test "$(cat /var/lib/lab18/region)" = "us-east-1"
nginx -t
systemctl is-active --quiet nginx
python3 - "$expected" <<'PYTHON'
import hashlib, json, pathlib, re, sys
state = sys.argv[1]
paths = ["/usr/share/nginx/html/index.html", "/usr/share/nginx/html/health",
         "/usr/share/nginx/html/version", "/etc/nginx/conf.d/lab18-app.conf"]
lines = pathlib.Path("/var/lib/lab18/baseline.sha256").read_text().splitlines()
if len(lines) != 4:
    raise SystemExit("Baseline manifest must contain exactly four entries")
manifest = {}
for line in lines:
    match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
    if not match or match[2] in manifest:
        raise SystemExit("Invalid baseline manifest")
    manifest[match[2]] = match[1]
if set(manifest) != set(paths):
    raise SystemExit("Unexpected baseline paths")
for name in paths:
    path = pathlib.Path(name)
    if state == "data-loss" and name in (paths[0], paths[2]):
        if path.exists() or path.is_symlink():
            raise SystemExit("Expected missing file: " + name)
        print("MISSING=" + name)
    else:
        if path.is_symlink() or not path.is_file():
            raise SystemExit("Invalid active file: " + name)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != manifest[name]:
            raise SystemExit("Hash mismatch: " + name)
        print(digest + "  " + name)
record_path = pathlib.Path("/var/lib/lab18/backup-record.json")
if state == "baseline":
    if record_path.exists():
        raise SystemExit("Unexpected backup record in Baseline")
else:
    record = json.loads(record_path.read_text())
    expected_bucket = pathlib.Path("/var/lib/lab18/bucket-name").read_text().strip()
    if record.get("Bucket") != expected_bucket:
        raise SystemExit("Unexpected backup bucket")
    if not re.fullmatch(r"backups/[A-Za-z0-9._/-]+\.tar\.gz", record.get("Key", "")):
        raise SystemExit("Invalid backup key")
    if not isinstance(record.get("VersionId"), str) or record["VersionId"] in ("", "null", "None"):
        raise SystemExit("Invalid VersionId")
    if not re.fullmatch(r"[0-9a-f]{64}", record.get("Sha256", "")):
        raise SystemExit("Invalid backup hash")
    print("BACKUP_RECORD=" + json.dumps(record, separators=(",", ":"), ensure_ascii=True))
PYTHON
check_http() {
    local path="$1" expected_code="$2" expected_body="$3" reply code body
    reply=$(curl --noproxy '*' -sS --connect-timeout 5 --max-time 10 \
        -w '\nHTTP_STATUS=%{http_code}' "http://127.0.0.1$path")
    code="${reply##*$'\n'HTTP_STATUS=}"
    body=$(printf '%s' "${reply%$'\n'HTTP_STATUS=*}")
    test "$code" = "$expected_code"
    if [ "$expected_code" = 200 ]; then
        if [ "$path" = / ]; then
            [[ "$body" == *"$expected_body"* ]]
        else
            test "$body" = "$expected_body"
        fi
    fi
    echo "LOCAL_HTTP=$path:$code"
}
check_http /health 200 healthy
if [ "$expected" = data-loss ]; then
    check_http / 404 ''
    check_http /version 404 ''
else
    check_http / 200 'Lab 18 - Application Backup and Restore'
    check_http /version 200 v1
fi
echo "STATE_VALIDATED=$expected"
'@
    $validationScript = $validationScript.Replace("__STATE__", $stateMarker).Replace("__BUCKET__", $BucketName)
    $output = Invoke-SsmValidation -InstanceId $instanceId -Script $validationScript
    if ($ExpectedState -ne "Baseline") {
        $recordLines = @($output -split "`n" | Where-Object { $_.StartsWith("BACKUP_RECORD=") })
        if ($recordLines.Count -ne 1) { throw "Registro de backup ausente ou ambiguo." }
        $record = $recordLines[0].Substring(14) | ConvertFrom-Json
        $packagePath = Join-Path $tempDirectory "backup.tar.gz"
        $download = Get-AwsJson -Arguments @(
            "s3api", "get-object", "--bucket", $BucketName,
            "--key", $record.Key, "--version-id", $record.VersionId,
            "--expected-bucket-owner", $ExpectedAccount, $packagePath
        )
        if ($download.VersionId -ne $record.VersionId -or
            $download.ServerSideEncryption -ne "AES256" -or
            (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $record.Sha256) {
            throw "Versao, criptografia ou SHA-256 do backup nao conferem."
        }
        Write-Host "[OK] Backup recuperavel: $($record.Key); VersionId=$($record.VersionId)."
        Write-Host "[OK] SHA-256 do pacote: $($record.Sha256)."
    }
    Test-Http "http://$publicIp/health" 200 "healthy"
    if ($ExpectedState -eq "DataLoss") {
        Test-Http "http://$publicIp/" 404 ""
        Test-Http "http://$publicIp/version" 404 ""
    }
    else {
        Test-Http "http://$publicIp/" 200 "Lab 18 - Application Backup and Restore" -Contains
        Test-Http "http://$publicIp/version" 200 "v1"
    }
    Write-Host "VALIDACAO CONCLUIDA: $ExpectedState"
    $global:LASTEXITCODE = 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    if ($script:lastCommandId) { Write-Host "Consulte CommandId: $script:lastCommandId" }
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
