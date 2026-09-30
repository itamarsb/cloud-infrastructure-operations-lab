[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [ValidateSet("us-east-1")]
    [string]$Region = "us-east-1",
    [Parameter(Mandatory = $true)]
    [string]$AllowedHttpCidr
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExpectedAccount = "412381774441"
$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"
$InstanceName = "lab18-application-backup-instance"
$GroupName = "lab18-application-backup-sg"
$RoleName = "lab18-ec2-application-backup-role"
$InstanceProfileName = "lab18-ec2-application-backup-instance-profile"
$InlinePolicyName = "lab18-s3-application-backup"
$BucketName = "lab18-app-backup-$ExpectedAccount-$Region"
$BucketMarker = "__LAB18_BUCKET_NAME__"
$SsmPolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$AmiParameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
$tempDirectory = $null
$script:lastCommandId = ""
$clientToken = [guid]::NewGuid().ToString("N")
$created = New-Object 'System.Collections.Generic.List[string]'
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

function Get-Tags {
    param([string]$Name)
    return @(
        @{ Key = "Name"; Value = $Name },
        @{ Key = "Project"; Value = "cloud-infrastructure-operations-lab" },
        @{ Key = "Environment"; Value = "lab" },
        @{ Key = "Lab"; Value = "18" },
        @{ Key = "ManagedBy"; Value = "aws-cli" },
        @{ Key = "Owner"; Value = "itamarsb" }
    )
}

function Get-TagArguments {
    param([string]$Name)
    return @(Get-Tags -Name $Name | ForEach-Object {
        "Key=$($_.Key),Value=$($_.Value)"
    })
}

function Get-TagSpecification {
    param([string]$ResourceType, [string]$Name)
    $items = @(Get-TagArguments -Name $Name | ForEach-Object { "{$_}" })
    return "ResourceType=$ResourceType,Tags=[$($items -join ',')]"
}

function Assert-Lab08Tags {
    param($Resource, [string]$Description)
    $tags = @{}
    foreach ($tag in @(Get-Property -Object $Resource -Name "Tags")) {
        if ($null -ne $tag) { $tags[[string]$tag.Key] = [string]$tag.Value }
    }
    $expected = @{
        Project = "cloud-infrastructure-operations-lab"
        Environment = "lab"
        Lab = "08"
        ManagedBy = "aws-cli"
        Owner = "itamarsb"
    }
    foreach ($key in $expected.Keys) {
        if ($tags[$key] -ne $expected[$key]) {
            throw "$Description possui tag $key ausente ou incompativel."
        }
    }
}

function Get-HttpBody {
    param([string]$Url)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& curl.exe --noproxy "*" --fail --silent `
            --show-error --connect-timeout 5 --max-time 10 `
            --write-out '\nHTTP_STATUS=%{http_code}' $Url 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    if ($code -ne 0) { throw "Falha HTTP em ${Url}: $($lines -join ' ')" }
    if ($lines.Count -eq 0 -or $lines[-1].ToString().Trim() -ne "HTTP_STATUS=200") {
        throw "Resposta HTTP diferente de 200 em $Url."
    }
    return (($lines | Select-Object -SkipLast 1 | ForEach-Object { $_.ToString() }) -join "`n").Trim()
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
        "--comment", "Lab 18 deployment baseline validation",
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
        return
    }
    throw "Prazo de observacao SSM excedido. Consulte CommandId=$commandId."
}

try {
    foreach ($name in @("AWS_CLI_FILE_ENCODING", "AWS_CLI_OUTPUT_ENCODING", "PYTHONIOENCODING")) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, "UTF-8", "Process")
    }
    Write-Host "=== Lab 18: pre-requisitos ==="
    foreach ($command in @("aws", "curl.exe")) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Comando obrigatorio ausente: $command."
        }
    }
    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    if ($identity.Account -ne $ExpectedAccount) {
        throw "Conta AWS inesperada: $($identity.Account)."
    }
    $parts = $AllowedHttpCidr -split "/"
    $parsedIp = $null
    if ($parts.Count -ne 2 -or $parts[1] -ne "32" -or
        -not [Net.IPAddress]::TryParse($parts[0], [ref]$parsedIp) -or
        $parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Informe um IPv4 publico com mascara /32."
    }
    $currentIp = Get-HttpBody -Url "https://checkip.amazonaws.com"
    if ("$currentIp/32" -ne $AllowedHttpCidr) {
        throw "O IPv4 publico atual nao corresponde a $AllowedHttpCidr."
    }
    $policyDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) "policies"
    $trustPath = Join-Path $policyDirectory "ec2-ssm-trust-policy.json"
    $templatePath = Join-Path $policyDirectory "s3-application-backup-policy-template.json"
    $trust = Get-Content -LiteralPath $trustPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $templateText = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    $template = $templateText | ConvertFrom-Json
    if ($trust.Version -ne "2012-10-17" -or @($trust.Statement).Count -ne 1 -or
        $trust.Statement[0].Effect -ne "Allow" -or
        $trust.Statement[0].Action -ne "sts:AssumeRole" -or
        $trust.Statement[0].Principal.Service -ne "ec2.amazonaws.com" -or
        @($trust.Statement[0].Principal.PSObject.Properties).Count -ne 1) {
        throw "Politica de confianca EC2 inesperada."
    }
    $bucketArnTemplate = "arn:aws:s3:::$BucketMarker"
    if ($template.Version -ne "2012-10-17" -or @($template.Statement).Count -ne 3 -or
        $template.Statement[0].Effect -ne "Allow" -or
        $template.Statement[0].Action -ne "s3:GetBucketVersioning" -or
        $template.Statement[0].Resource -ne $bucketArnTemplate -or
        $template.Statement[1].Effect -ne "Allow" -or
        (@($template.Statement[1].Action | Sort-Object) -join ",") -ne
            "s3:GetObjectVersion,s3:PutObject" -or
        $template.Statement[1].Resource -ne "$bucketArnTemplate/backups/*" -or
        $template.Statement[2].Effect -ne "Deny" -or
        $template.Statement[2].Action -ne "s3:*" -or
        (@($template.Statement[2].Resource | Sort-Object) -join ",") -ne
            "$bucketArnTemplate,$bucketArnTemplate/*" -or
        [string]$template.Statement[2].Condition.Bool.'aws:SecureTransport' -ne "false") {
        throw "Template S3 diferente da politica definida para o Lab 18."
    }
    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("lab18-deploy-" + $clientToken)
    $null = New-Item -Path $tempDirectory -ItemType Directory
    $resolvedTrustPath = Join-Path $tempDirectory "trust.json"
    $resolvedS3Path = Join-Path $tempDirectory "s3-role-policy.json"
    Write-JsonFile -Path $resolvedTrustPath -Value $trust
    $resolvedS3 = $templateText.Replace($BucketMarker, $BucketName) | ConvertFrom-Json
    Write-JsonFile -Path $resolvedS3Path -Value $resolvedS3
    Write-Host "[OK] Conta: $ExpectedAccount; Regiao: $Region; HTTP: $AllowedHttpCidr"
    Write-Host "[OK] Politicas JSON verificadas."

    Write-Host "=== Rede compartilhada do Lab 08 ==="
    $response = Get-AwsJson -Arguments @("ec2", "describe-vpcs", "--filters",
        "Name=tag:Name,Values=$VpcName", "Name=state,Values=available")
    if (@($response.Vpcs).Count -ne 1) { throw "VPC do Lab 08 ausente ou ambigua." }
    $vpc = $response.Vpcs[0]
    Assert-Lab08Tags -Resource $vpc -Description "VPC"
    $response = Get-AwsJson -Arguments @("ec2", "describe-subnets", "--filters",
        "Name=tag:Name,Values=$SubnetName", "Name=vpc-id,Values=$($vpc.VpcId)",
        "Name=state,Values=available")
    if (@($response.Subnets).Count -ne 1) { throw "Sub-rede do Lab 08 ausente ou ambigua." }
    $subnet = $response.Subnets[0]
    Assert-Lab08Tags -Resource $subnet -Description "Sub-rede"
    if ($subnet.AvailabilityZone -ne "us-east-1a" -or -not $subnet.MapPublicIpOnLaunch) {
        throw "A sub-rede esperada deve estar em us-east-1a e atribuir IPv4 publico."
    }
    $response = Get-AwsJson -Arguments @("ec2", "describe-route-tables", "--filters",
        "Name=vpc-id,Values=$($vpc.VpcId)")
    $explicit = @($response.RouteTables | Where-Object {
        @($_.Associations | Where-Object {
            (Get-Property -Object $_ -Name "SubnetId") -eq $subnet.SubnetId
        }).Count -gt 0
    })
    if ($explicit.Count -gt 1) { throw "Mais de uma tabela de rotas para a sub-rede." }
    if ($explicit.Count -eq 1) { $routeTable = $explicit[0] }
    else {
        $main = @($response.RouteTables | Where-Object {
            @($_.Associations | Where-Object {
                (Get-Property -Object $_ -Name "Main") -eq $true
            }).Count -gt 0
        })
        if ($main.Count -ne 1) { throw "Tabela principal de rotas ausente ou ambigua." }
        $routeTable = $main[0]
    }
    $routes = @($routeTable.Routes | Where-Object {
        (Get-Property -Object $_ -Name "DestinationCidrBlock") -eq "0.0.0.0/0" -and
        $_.State -eq "active" -and
        (Get-Property -Object $_ -Name "GatewayId") -match '^igw-'
    })
    if ($routes.Count -ne 1) { throw "Rota publica ativa ausente ou ambigua." }
    $response = Get-AwsJson -Arguments @("ec2", "describe-internet-gateways",
        "--internet-gateway-ids", $routes[0].GatewayId)
    if (@($response.InternetGateways).Count -ne 1 -or
        @($response.InternetGateways[0].Attachments | Where-Object {
            $_.VpcId -eq $vpc.VpcId -and $_.State -eq "available"
        }).Count -ne 1) { throw "Internet Gateway fora da VPC esperada." }
    $response = Get-AwsJson -Arguments @("ec2", "describe-network-acls", "--filters",
        "Name=association.subnet-id,Values=$($subnet.SubnetId)")
    if (@($response.NetworkAcls).Count -ne 1) { throw "Network ACL ausente ou ambigua." }
    Write-Host "[OK] VPC: $($vpc.VpcId); sub-rede: $($subnet.SubnetId)"
    Write-Host "[OK] Rota: $($routeTable.RouteTableId); ACL: $($response.NetworkAcls[0].NetworkAclId)"

    Write-Host "=== Verificacao de conflitos ==="
    $response = Get-AwsJson -Arguments @("ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down")
    $existing = @($response.Reservations | ForEach-Object { $_.Instances })
    if ($existing.Count -gt 0) { throw "Ja existe uma instancia do Lab 18. Confira o estado antes de repetir." }
    $response = Get-AwsJson -Arguments @("ec2", "describe-security-groups", "--filters",
        "Name=group-name,Values=$GroupName", "Name=vpc-id,Values=$($vpc.VpcId)")
    if (@($response.SecurityGroups).Count -gt 0) { throw "O Security Group $GroupName ja existe." }
    $roles = Invoke-Aws -Arguments @("iam", "list-roles", "--query",
        "Roles[?RoleName=='$RoleName'].RoleName", "--output", "text")
    if ($roles) { throw "A IAM Role $RoleName ja existe." }
    $profiles = Invoke-Aws -Arguments @("iam", "list-instance-profiles", "--query",
        "InstanceProfiles[?InstanceProfileName=='$InstanceProfileName'].InstanceProfileName",
        "--output", "text")
    if ($profiles) { throw "O Instance Profile $InstanceProfileName ja existe." }
    $buckets = Invoke-Aws -Arguments @("s3api", "list-buckets", "--query",
        "Buckets[?Name=='$BucketName'].Name", "--output", "text")
    if ($buckets) { throw "O bucket $BucketName ja existe nesta conta." }
    $imageId = Invoke-Aws -Arguments @("ssm", "get-parameter", "--name", $AmiParameter,
        "--query", "Parameter.Value", "--output", "text")
    if ($imageId -notmatch '^ami-[0-9a-f]+$') { throw "AMI Amazon Linux 2023 invalida." }
    Write-Host "[OK] Nenhum conflito local identificado; AMI: $imageId"

    Write-Host "=== Bucket S3 exclusivo ==="
    $null = Invoke-Aws -Arguments @("s3api", "create-bucket", "--bucket", $BucketName,
        "--object-ownership", "BucketOwnerEnforced")
    $created.Add("Bucket: $BucketName")
    Write-Host "[OK] Bucket criado: $BucketName"
    $taggingPath = Join-Path $tempDirectory "bucket-tags.json"
    Write-JsonFile -Path $taggingPath -Value @{ TagSet = @(Get-Tags -Name $BucketName) }
    $null = Invoke-Aws -Arguments @("s3api", "put-bucket-tagging", "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccount, "--tagging", (Get-FileUri -Path $taggingPath))
    $null = Invoke-Aws -Arguments @("s3api", "put-public-access-block", "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccount, "--public-access-block-configuration",
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true")
    $null = Invoke-Aws -Arguments @("s3api", "put-bucket-encryption", "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccount, "--server-side-encryption-configuration",
        "Rules=[{ApplyServerSideEncryptionByDefault={SSEAlgorithm=AES256}}]")
    $null = Invoke-Aws -Arguments @("s3api", "put-bucket-versioning", "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccount, "--versioning-configuration", "Status=Enabled")
    $backupNotBefore = [DateTimeOffset]::UtcNow.AddMinutes(15)
    $backupNotBeforeEpoch = $backupNotBefore.ToUnixTimeSeconds()
    $versioning = Get-AwsJson -Arguments @("s3api", "get-bucket-versioning", "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccount)
    $encryption = Get-AwsJson -Arguments @("s3api", "get-bucket-encryption", "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccount)
    $publicAccess = Get-AwsJson -Arguments @("s3api", "get-public-access-block", "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccount)
    $ownership = Get-AwsJson -Arguments @("s3api", "get-bucket-ownership-controls", "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccount)
    if ($versioning.Status -ne "Enabled" -or
        $encryption.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm -ne "AES256" -or
        $ownership.OwnershipControls.Rules[0].ObjectOwnership -ne "BucketOwnerEnforced") {
        throw "Configuracao S3 diferente do esperado."
    }
    foreach ($setting in @("BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets")) {
        if ((Get-Property -Object $publicAccess.PublicAccessBlockConfiguration -Name $setting) -ne $true) {
            throw "Bloqueio publico S3 incompleto: $setting."
        }
    }
    Write-Host "[OK] S3 privado, SSE-S3, versionamento e propriedade verificados."

    Write-Host "=== IAM e Security Group ==="
    $null = Invoke-Aws -Arguments (@("iam", "create-role", "--role-name", $RoleName,
        "--assume-role-policy-document", (Get-FileUri -Path $resolvedTrustPath), "--tags") +
        (Get-TagArguments -Name $RoleName))
    $created.Add("IAM Role: $RoleName")
    $null = Invoke-Aws -Arguments @("iam", "attach-role-policy", "--role-name", $RoleName,
        "--policy-arn", $SsmPolicyArn)
    $null = Invoke-Aws -Arguments @("iam", "put-role-policy", "--role-name", $RoleName,
        "--policy-name", $InlinePolicyName, "--policy-document", (Get-FileUri -Path $resolvedS3Path))
    $null = Invoke-Aws -Arguments (@("iam", "create-instance-profile", "--instance-profile-name",
        $InstanceProfileName, "--tags") + (Get-TagArguments -Name $InstanceProfileName))
    $created.Add("Instance Profile: $InstanceProfileName")
    $null = Invoke-Aws -Arguments @("iam", "add-role-to-instance-profile",
        "--instance-profile-name", $InstanceProfileName, "--role-name", $RoleName)
    $groupId = Invoke-Aws -Arguments @("ec2", "create-security-group", "--group-name", $GroupName,
        "--description", "Lab 18 application backup and restore", "--vpc-id", $vpc.VpcId,
        "--tag-specifications", (Get-TagSpecification -ResourceType "security-group" -Name $GroupName),
        "--query", "GroupId", "--output", "text")
    $created.Add("Security Group: $groupId")
    $null = Invoke-Aws -Arguments @("ec2", "authorize-security-group-ingress", "--group-id", $groupId,
        "--protocol", "tcp", "--port", "80", "--cidr", $AllowedHttpCidr)
    Write-Host "[OK] IAM criado; SG: $groupId; entrada TCP 80 para $AllowedHttpCidr"
    Start-Sleep -Seconds 15

    Write-Host "=== EC2 e aplicacao Nginx ==="
    $userData = @'
#!/bin/bash
set -euo pipefail
dnf install -y nginx python3 util-linux tar
for tool in aws curl tar sha256sum python3 flock; do command -v "$tool" >/dev/null; done
install -d -m 0700 /var/lib/lab18
install -d -m 0755 /usr/share/nginx/html
cat > /etc/nginx/nginx.conf <<'MAIN'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    sendfile on;
    include /etc/nginx/conf.d/lab18-app.conf;
}
MAIN
cat > /etc/nginx/conf.d/lab18-app.conf <<'CONF'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    location = / { try_files /index.html =404; }
    location = /health { default_type text/plain; try_files /health =404; }
    location = /version { default_type text/plain; try_files /version =404; }
    location / { return 404; }
}
CONF
cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Lab 18 - Application Backup</title></head>
<body>
<h1>Cloud Infrastructure Operations Lab</h1>
<p>Lab 18 - Application Backup and Restore</p>
<p>Release: v1</p>
</body>
</html>
HTML
printf 'healthy\n' > /usr/share/nginx/html/health
printf 'v1\n' > /usr/share/nginx/html/version
chmod 0644 /usr/share/nginx/html/index.html /usr/share/nginx/html/health \
    /usr/share/nginx/html/version /etc/nginx/conf.d/lab18-app.conf
printf '%s\n' '__BUCKET__' > /var/lib/lab18/bucket-name
printf '%s\n' '__REGION__' > /var/lib/lab18/region
printf '%s\n' '__ACCOUNT__' > /var/lib/lab18/account-id
printf '%s\n' '__READY_EPOCH__' > /var/lib/lab18/backup-not-before-epoch
sha256sum /usr/share/nginx/html/index.html /usr/share/nginx/html/health \
    /usr/share/nginx/html/version /etc/nginx/conf.d/lab18-app.conf \
    > /var/lib/lab18/baseline.sha256
nginx -t
systemctl enable --now nginx
systemctl is-active --quiet nginx
test "$(curl --fail --silent http://127.0.0.1/health)" = healthy
test "$(curl --fail --silent http://127.0.0.1/version)" = v1
printf 'baseline\n' > /var/lib/lab18/state
date -u +%Y-%m-%dT%H:%M:%SZ > /var/lib/lab18/baseline-created-at
touch /var/lib/lab18/bootstrap-complete
'@
    $userData = $userData.Replace("__BUCKET__", $BucketName).Replace("__REGION__", $Region)
    $userData = $userData.Replace("__ACCOUNT__", $ExpectedAccount)
    $userData = $userData.Replace("__READY_EPOCH__", [string]$backupNotBeforeEpoch)
    $userDataPath = Join-Path $tempDirectory "user-data.sh"
    Write-Utf8File -Path $userDataPath -Content $userData
    $runArguments = @("ec2", "run-instances", "--image-id", $imageId,
        "--instance-type", "t3.micro", "--count", "1",
        "--credit-specification", "CpuCredits=standard",
        "--client-token", $clientToken, "--subnet-id", $subnet.SubnetId,
        "--security-group-ids", $groupId, "--iam-instance-profile", "Name=$InstanceProfileName",
        "--metadata-options", "HttpTokens=required,HttpEndpoint=enabled",
        "--block-device-mappings", "DeviceName=/dev/xvda,Ebs={VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}",
        "--user-data", (Get-FileUri -Path $userDataPath), "--tag-specifications",
        (Get-TagSpecification -ResourceType "instance" -Name $InstanceName),
        (Get-TagSpecification -ResourceType "volume" -Name "$InstanceName-root"))
    Write-Host "ClientToken EC2: $clientToken"
    $instanceResponse = $null
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try { $instanceResponse = Get-AwsJson -Arguments $runArguments; break }
        catch {
            if ($attempt -eq 12 -or $_.Exception.Message -notmatch "Invalid IAM Instance Profile|InvalidIamInstanceProfile") { throw }
            Start-Sleep -Seconds 10
        }
    }
    if ($null -eq $instanceResponse -or @($instanceResponse.Instances).Count -ne 1) {
        throw "A criacao EC2 nao retornou exatamente uma instancia."
    }
    $instanceId = $instanceResponse.Instances[0].InstanceId
    $created.Add("Instancia: $instanceId")
    Write-Host "[OK] Instancia solicitada: $instanceId"
    $online = $false
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        $response = Get-AwsJson -Arguments @("ec2", "describe-instances", "--instance-ids", $instanceId)
        $instance = @($response.Reservations | ForEach-Object { $_.Instances })[0]
        if ($instance.State.Name -in @("terminated", "shutting-down", "stopped", "stopping")) {
            throw "A instancia deixou de iniciar: $($instance.State.Name)."
        }
        $ssm = Get-AwsJson -Arguments @("ssm", "describe-instance-information", "--filters",
            "Key=InstanceIds,Values=$instanceId")
        if ($instance.State.Name -eq "running" -and
            @($ssm.InstanceInformationList | Where-Object { $_.PingStatus -eq "Online" }).Count -eq 1) {
            $online = $true; break
        }
        if ($attempt % 6 -eq 0) { Write-Host "Aguardando EC2 e SSM: tentativa $attempt/60." }
        Start-Sleep -Seconds 10
    }
    if (-not $online) { throw "A instancia nao ficou running e SSM Online no prazo."
    }
    $publicIp = Get-Property -Object $instance -Name "PublicIpAddress"
    if ([string]::IsNullOrWhiteSpace($publicIp)) { throw "A instancia nao recebeu IPv4 publico." }
    Write-Host "[OK] SSM Online; IPv4: $publicIp"

    $validationScript = @'
#!/bin/bash
set -euo pipefail
ready=false
for attempt in $(seq 1 60); do
    if test -f /var/lib/lab18/bootstrap-complete; then ready=true; break; fi
    sleep 3
done
test "$ready" = true
test "$(cat /var/lib/lab18/state)" = baseline
test "$(cat /var/lib/lab18/bucket-name)" = '__BUCKET__'
nginx -t
systemctl is-active --quiet nginx
sha256sum -c /var/lib/lab18/baseline.sha256
test "$(curl --fail --silent --max-time 5 http://127.0.0.1/health)" = healthy
test "$(curl --fail --silent --max-time 5 http://127.0.0.1/version)" = v1
curl --fail --silent --max-time 5 http://127.0.0.1/ | grep -F 'Lab 18 - Application Backup and Restore'
for attempt in $(seq 1 8); do
    if status=$(aws s3api get-bucket-versioning --bucket '__BUCKET__' \
        --region '__REGION__' --expected-bucket-owner '__ACCOUNT__' \
        --query Status --output text 2>/dev/null); then
        test "$status" = Enabled
        echo 'INSTANCE_ROLE_S3_VERSIONING=Enabled'
        break
    fi
    if test "$attempt" -eq 8; then echo 'INSTANCE_ROLE_S3_ACCESS_FAILED' >&2; exit 1; fi
    sleep 3
done
echo 'BASELINE=healthy'
cat /var/lib/lab18/baseline.sha256
'@
    $validationScript = $validationScript.Replace("__BUCKET__", $BucketName)
    $validationScript = $validationScript.Replace("__REGION__", $Region).Replace("__ACCOUNT__", $ExpectedAccount)
    Invoke-SsmValidation -InstanceId $instanceId -Script $validationScript
    $healthy = $false
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            $health = Get-HttpBody -Url "http://$publicIp/health"
            $version = Get-HttpBody -Url "http://$publicIp/version"
            $page = Get-HttpBody -Url "http://$publicIp/"
            if ($health -eq "healthy" -and $version -eq "v1" -and
                $page -match "Lab 18 - Application Backup and Restore") {
                $healthy = $true; break
            }
        }
        catch { Write-Host "Aguardando HTTP externo: tentativa $attempt/12." }
        Start-Sleep -Seconds 5
    }
    if (-not $healthy) { throw "O baseline HTTP externo nao foi validado." }
    Write-Host "[OK] Pagina principal, /health e /version validados local e externamente."
    Write-Host "IMPLANTACAO CONCLUIDA: Baseline"
    Write-Host "VPC: $($vpc.VpcId); sub-rede: $($subnet.SubnetId)"
    Write-Host "Instancia: $instanceId; SG: $groupId"
    Write-Host "Bucket: $BucketName"
    Write-Host "URL: http://$publicIp/; origem HTTP: $AllowedHttpCidr"
    Write-Host "Backup permitido a partir de (UTC): $($backupNotBefore.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    Write-Host "Nenhum backup foi criado nesta etapa."
    $global:LASTEXITCODE = 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    foreach ($resource in $created) { Write-Host "Recurso criado: $resource" }
    Write-Host "ClientToken EC2: $clientToken"
    if ($script:lastCommandId) { Write-Host "CommandId: $script:lastCommandId" }
    Write-Host "Registre a saida e confira os recursos do Lab 18 antes de repetir o deploy."
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
