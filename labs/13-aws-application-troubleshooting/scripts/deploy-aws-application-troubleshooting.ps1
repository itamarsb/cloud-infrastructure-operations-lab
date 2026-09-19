[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [string]$AvailabilityZone = "us-east-1a",

    [string]$InstanceType = "t3.micro",

    [string]$AllowedHttpCidr
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"

$InstanceName = "lab13-troubleshooting-instance"
$SecurityGroupName = "lab13-troubleshooting-sg"
$RoleName = "lab13-ec2-troubleshooting-role"
$InstanceProfileName = "lab13-ec2-troubleshooting-instance-profile"

$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$AmiParameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

$CommonTags = @{
    Project     = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab         = "13"
    ManagedBy   = "aws-cli"
    Owner       = "itamarsb"
}

function Write-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Write-Ok {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-InfoMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Invoke-AwsCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$AllowEmpty
    )

    $previousErrorActionPreference = $ErrorActionPreference

    try {
        # Windows PowerShell 5.1 can convert native stderr output into a
        # terminating RemoteException when ErrorActionPreference is Stop.
        # Capture the AWS CLI response first and evaluate its exit code below.
        $ErrorActionPreference = "Continue"

        $output = @(
            & aws @Arguments `
                --profile $ProfileName `
                --region $Region `
                --no-cli-pager 2>&1
        )

        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"

    if ($exitCode -ne 0) {
        throw "AWS CLI failed: aws $($Arguments -join ' ')`n$text"
    }

    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($text)) {
        throw "AWS CLI returned an empty response: aws $($Arguments -join ' ')"
    }

    return $text.Trim()
}

function ConvertFrom-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $json = Invoke-AwsCli -Arguments ($Arguments + @("--output", "json"))

    try {
        return $json | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "AWS CLI returned invalid JSON.`n$json"
    }
}

function Invoke-Ec2RunInstancesWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [int]$MaximumAttempts = 6,

        [int]$DelaySeconds = 15
    )

    $clientToken = [Guid]::NewGuid().ToString()
    $runArguments = $Arguments + @("--client-token", $clientToken)

    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        try {
            return ConvertFrom-AwsJson -Arguments $runArguments
        }
        catch {
            $errorMessage = $_.Exception.Message
            $isPropagationError = (
                $errorMessage -match "InvalidParameterValue" -or
                $errorMessage -match "IAM Instance Profile" -or
                $errorMessage -match "iamInstanceProfile"
            )

            if (-not $isPropagationError -or $attempt -eq $MaximumAttempts) {
                throw
            }

            Write-InfoMessage (
                "The IAM Instance Profile is not yet available to EC2. " +
                "Retrying instance creation: attempt " +
                "$attempt/$MaximumAttempts."
            )

            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Get-TagSpecification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $tags = @(
        "Key=Name,Value=$Name"
        "Key=Project,Value=$($CommonTags.Project)"
        "Key=Environment,Value=$($CommonTags.Environment)"
        "Key=Lab,Value=$($CommonTags.Lab)"
        "Key=ManagedBy,Value=$($CommonTags.ManagedBy)"
        "Key=Owner,Value=$($CommonTags.Owner)"
    )

    return "ResourceType=$ResourceType,Tags=[{0}]" -f ($tags -join "},{")
}

function Get-IamTags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return @(
        "Key=Name,Value=$Name"
        "Key=Project,Value=$($CommonTags.Project)"
        "Key=Environment,Value=$($CommonTags.Environment)"
        "Key=Lab,Value=$($CommonTags.Lab)"
        "Key=ManagedBy,Value=$($CommonTags.ManagedBy)"
        "Key=Owner,Value=$($CommonTags.Owner)"
    )
}

function Wait-SsmOnline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [int]$MaximumAttempts = 40,

        [int]$DelaySeconds = 15
    )

    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        $information = ConvertFrom-AwsJson -Arguments @(
            "ssm", "describe-instance-information",
            "--filters", "Key=InstanceIds,Values=$InstanceId"
        )

        $managedInstance = @($information.InstanceInformationList) |
            Select-Object -First 1

        if (
            $null -ne $managedInstance -and
            $managedInstance.PingStatus -eq "Online"
        ) {
            return
        }

        Write-InfoMessage (
            "Waiting for $InstanceId to become online in Systems Manager: " +
            "attempt $attempt/$MaximumAttempts."
        )

        Start-Sleep -Seconds $DelaySeconds
    }

    throw "Instance $InstanceId did not become online in Systems Manager."
}

function Wait-HttpHealthy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address,

        [int]$MaximumAttempts = 30,

        [int]$DelaySeconds = 10
    )

    $url = "http://$Address/health"

    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest `
                -Uri $url `
                -UseBasicParsing `
                -DisableKeepAlive `
                -TimeoutSec 10

            if (
                $response.StatusCode -eq 200 -and
                $response.Content.Trim() -eq "healthy"
            ) {
                return
            }

            Write-InfoMessage (
                "HTTP attempt $attempt returned unexpected content."
            )
        }
        catch {
            Write-InfoMessage (
                "Waiting for the application: attempt " +
                "$attempt/$MaximumAttempts."
            )
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    throw "The application did not become healthy at $url."
}

Write-Host "Lab 13 - Application troubleshooting deployment"

try {
    Write-Step "Prerequisites"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    $policyPath = Join-Path `
        (Split-Path -Parent $PSScriptRoot) `
        "policies\ec2-ssm-trust-policy.json"

    if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
        throw "Trust policy not found: $policyPath"
    }

    $null = Get-Content -LiteralPath $policyPath -Raw |
        ConvertFrom-Json -ErrorAction Stop

    $identity = ConvertFrom-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ([string]::IsNullOrWhiteSpace($identity.Account)) {
        throw "The AWS identity could not be validated."
    }

    if ([string]::IsNullOrWhiteSpace($AllowedHttpCidr)) {
        Write-InfoMessage "Discovering the current public IPv4 address."

        try {
            $publicIp = (
                Invoke-RestMethod `
                    -Uri "https://checkip.amazonaws.com" `
                    -TimeoutSec 15
            ).Trim()
        }
        catch {
            throw (
                "The public IPv4 address could not be discovered. " +
                "Provide -AllowedHttpCidr explicitly."
            )
        }

        $parsedAddress = $null

        if (
            -not [System.Net.IPAddress]::TryParse(
                $publicIp,
                [ref]$parsedAddress
            ) -or
            $parsedAddress.AddressFamily -ne
                [System.Net.Sockets.AddressFamily]::InterNetwork
        ) {
            throw "The discovered address is not a valid public IPv4 address."
        }

        $AllowedHttpCidr = "$publicIp/32"
    }

    if ($AllowedHttpCidr -notmatch '^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$') {
        throw "AllowedHttpCidr must be an IPv4 CIDR."
    }

    Write-Ok (
        "AWS CLI, trust policy, session and HTTP source validated. " +
        "Allowed source: $AllowedHttpCidr"
    )

    Write-Step "Lab 08 network"

    $vpcResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $vpcs = @($vpcResponse.Vpcs)

    if ($vpcs.Count -ne 1) {
        throw "Exactly one available VPC named $VpcName is required."
    }

    $vpcId = $vpcs[0].VpcId

    $subnetResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--filters",
        "Name=tag:Name,Values=$SubnetName",
        "Name=vpc-id,Values=$vpcId",
        "Name=state,Values=available"
    )

    $subnets = @($subnetResponse.Subnets)

    if ($subnets.Count -ne 1) {
        throw "Exactly one available subnet named $SubnetName is required."
    }

    $subnet = $subnets[0]

    if ($subnet.AvailabilityZone -ne $AvailabilityZone) {
        throw (
            "Subnet $SubnetName belongs to $($subnet.AvailabilityZone), " +
            "not $AvailabilityZone."
        )
    }

    if (-not $subnet.MapPublicIpOnLaunch) {
        throw "The selected subnet does not automatically assign public IPv4."
    }

    $subnetId = $subnet.SubnetId

    Write-Ok "Lab 08 VPC and public subnet located."

    Write-Step "Conflict check"

    $existingInstancesResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $existingInstances = @(
        $existingInstancesResponse.Reservations |
            ForEach-Object { $_.Instances }
    )

    if ($existingInstances.Count -gt 0) {
        throw "An active instance named $InstanceName already exists."
    }

    $existingGroupsResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$SecurityGroupName",
        "Name=vpc-id,Values=$vpcId"
    )

    if (@($existingGroupsResponse.SecurityGroups).Count -gt 0) {
        throw "Security Group $SecurityGroupName already exists."
    }

    $roleExists = $true

    try {
        $null = Invoke-AwsCli -Arguments @(
            "iam", "get-role",
            "--role-name", $RoleName
        )
    }
    catch {
        $roleExists = $false
    }

    if ($roleExists) {
        throw "IAM Role $RoleName already exists."
    }

    $profileExists = $true

    try {
        $null = Invoke-AwsCli -Arguments @(
            "iam", "get-instance-profile",
            "--instance-profile-name", $InstanceProfileName
        )
    }
    catch {
        $profileExists = $false
    }

    if ($profileExists) {
        throw "Instance Profile $InstanceProfileName already exists."
    }

    Write-Ok "No conflicting Lab 13 resources found."

    Write-Step "IAM"

    $trustPolicy = (Resolve-Path -LiteralPath $policyPath).Path

    $null = Invoke-AwsCli -Arguments (
        @(
            "iam", "create-role",
            "--role-name", $RoleName,
            "--assume-role-policy-document", "file://$trustPolicy",
            "--tags"
        ) + (Get-IamTags -Name $RoleName)
    )

    $null = Invoke-AwsCli -Arguments @(
        "iam", "attach-role-policy",
        "--role-name", $RoleName,
        "--policy-arn", $PolicyArn
    ) -AllowEmpty

    $null = Invoke-AwsCli -Arguments (
        @(
            "iam", "create-instance-profile",
            "--instance-profile-name", $InstanceProfileName,
            "--tags"
        ) + (Get-IamTags -Name $InstanceProfileName)
    )

    $null = Invoke-AwsCli -Arguments @(
        "iam", "add-role-to-instance-profile",
        "--instance-profile-name", $InstanceProfileName,
        "--role-name", $RoleName
    ) -AllowEmpty

    Write-Ok "IAM Role and Instance Profile configured."
    Write-InfoMessage "Waiting 15 seconds before validating IAM propagation."
    Start-Sleep -Seconds 15

    Write-Step "Security Group"

    $groupId = Invoke-AwsCli -Arguments @(
        "ec2", "create-security-group",
        "--group-name", $SecurityGroupName,
        "--description", "Lab 13 controlled HTTP access",
        "--vpc-id", $vpcId,
        "--query", "GroupId",
        "--output", "text"
    )

    $null = Invoke-AwsCli -Arguments @(
        "ec2", "create-tags",
        "--resources", $groupId,
        "--tags",
        "Key=Name,Value=$SecurityGroupName",
        "Key=Project,Value=$($CommonTags.Project)",
        "Key=Environment,Value=$($CommonTags.Environment)",
        "Key=Lab,Value=$($CommonTags.Lab)",
        "Key=ManagedBy,Value=$($CommonTags.ManagedBy)",
        "Key=Owner,Value=$($CommonTags.Owner)"
    ) -AllowEmpty

    $null = Invoke-AwsCli -Arguments @(
        "ec2", "authorize-security-group-ingress",
        "--group-id", $groupId,
        "--protocol", "tcp",
        "--port", "80",
        "--cidr", $AllowedHttpCidr
    ) -AllowEmpty

    Write-Ok "HTTP permitted only from $AllowedHttpCidr."
    Write-Ok "No SSH ingress rule was created."

    Write-Step "Amazon Linux 2023"

    $imageId = Invoke-AwsCli -Arguments @(
        "ssm", "get-parameter",
        "--name", $AmiParameter,
        "--query", "Parameter.Value",
        "--output", "text"
    )

    if ($imageId -notmatch '^ami-[a-zA-Z0-9]+$') {
        throw "The Amazon Linux 2023 AMI could not be resolved."
    }

    Write-Ok "Latest Amazon Linux 2023 image discovered."

    Write-Step "EC2 and Nginx"

    $userData = @'
#!/bin/bash
set -euo pipefail

dnf install -y nginx

cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Lab 13</title>
</head>
<body>
  <h1>Lab 13 - Application Troubleshooting</h1>
  <p>Application status: healthy</p>
</body>
</html>
HTML

printf 'healthy\n' > /usr/share/nginx/html/health

cat > /etc/nginx/conf.d/lab13.conf <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /usr/share/nginx/html;

    location = /health {
        default_type text/plain;
        try_files /health =404;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

rm -f /etc/nginx/conf.d/default.conf
nginx -t
systemctl enable --now nginx
'@

    $encodedUserData = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes($userData)
    )

    $instanceResponse = Invoke-Ec2RunInstancesWithRetry -Arguments @(
        "ec2", "run-instances",
        "--image-id", $imageId,
        "--instance-type", $InstanceType,
        "--subnet-id", $subnetId,
        "--security-group-ids", $groupId,
        "--iam-instance-profile", "Name=$InstanceProfileName",
        "--metadata-options",
        "HttpTokens=required,HttpEndpoint=enabled",
        "--block-device-mappings",
        "DeviceName=/dev/xvda,Ebs={VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}",
        "--user-data", $encodedUserData,
        "--tag-specifications",
        (Get-TagSpecification -ResourceType "instance" -Name $InstanceName),
        (Get-TagSpecification -ResourceType "volume" -Name "$InstanceName-root")
    )

    $instanceId = @($instanceResponse.Instances)[0].InstanceId

    if ([string]::IsNullOrWhiteSpace($instanceId)) {
        throw "The EC2 instance identifier was not returned."
    }

    Write-Ok "Instance creation requested: $instanceId"

    $null = Invoke-AwsCli -Arguments @(
        "ec2", "wait", "instance-running",
        "--instance-ids", $instanceId
    ) -AllowEmpty

    $null = Invoke-AwsCli -Arguments @(
        "ec2", "wait", "instance-status-ok",
        "--instance-ids", $instanceId
    ) -AllowEmpty

    Write-Ok "The EC2 instance passed status checks."

    Write-Step "Systems Manager"

    Wait-SsmOnline -InstanceId $instanceId
    Write-Ok "$instanceId is online in Systems Manager."

    Write-Step "Application validation"

    $instanceDescription = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--instance-ids", $instanceId
    )

    $createdInstance = @(
        $instanceDescription.Reservations |
            ForEach-Object { $_.Instances }
    )[0]

    $publicIpAddress = $createdInstance.PublicIpAddress

    if ([string]::IsNullOrWhiteSpace($publicIpAddress)) {
        throw "The instance does not have a public IPv4 address."
    }

    Wait-HttpHealthy -Address $publicIpAddress

    $pageResponse = Invoke-WebRequest `
        -Uri "http://$publicIpAddress/" `
        -UseBasicParsing `
        -DisableKeepAlive `
        -TimeoutSec 10

    if (
        $pageResponse.StatusCode -ne 200 -or
        $pageResponse.Content -notmatch
            "Lab 13.+Application Troubleshooting"
    ) {
        throw "The application returned an unexpected response."
    }

    Write-Ok "The application returned HTTP 200."
    Write-Ok "The health endpoint returned the expected content."

    Write-Host ""
    Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host ("VPC:              {0}" -f $vpcId)
    Write-Host ("Subnet:           {0}" -f $subnetId)
    Write-Host ("Security Group:   {0}" -f $groupId)
    Write-Host ("Instance:         {0}" -f $instanceId)
    Write-Host ("Public IPv4:      {0}" -f $publicIpAddress)
    Write-Host ("Application URL:  http://{0}/" -f $publicIpAddress)
    Write-Host ("Allowed HTTP:     {0}" -f $AllowedHttpCidr)
    Write-Host (
        "Next step: run test-aws-application-troubleshooting.ps1"
    )
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host (
        "If resources were created, run " +
        "remove-aws-application-troubleshooting.ps1 -ConfirmRemoval."
    ) -ForegroundColor Yellow

    exit 1
}
