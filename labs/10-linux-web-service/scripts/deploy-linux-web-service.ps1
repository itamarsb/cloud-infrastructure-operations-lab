[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [string]$AvailabilityZone = "us-east-1a",

    [string]$InstanceType = "t3.micro",

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AllowedHttpCidr
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"

$InstanceName = "lab10-linux-web-server"
$SecurityGroupName = "lab10-linux-web-sg"
$RoleName = "lab10-ec2-ssm-role"
$InstanceProfileName = "lab10-ec2-ssm-instance-profile"

$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$AmiParameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

$TrustPolicyPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath "..\policies\ec2-ssm-trust-policy.json"

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

function Write-Info {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $Output = @(
            & aws @Arguments `
                --profile $ProfileName `
                --region $Region `
                --output json `
                --no-cli-pager 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    $Text = (
        $Output |
            ForEach-Object { "$_" }
    ) -join [Environment]::NewLine

    if ($ExitCode -ne 0) {
        throw "AWS CLI failed: aws $($Arguments -join ' ')$([Environment]::NewLine)$Text"
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    return $Text | ConvertFrom-Json
}

function Invoke-AwsCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $Output = @(
            & aws @Arguments `
                --profile $ProfileName `
                --region $Region `
                --no-cli-pager 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($ExitCode -ne 0) {
        $Text = (
            $Output |
                ForEach-Object { "$_" }
        ) -join [Environment]::NewLine

        throw "AWS CLI failed: aws $($Arguments -join ' ')$([Environment]::NewLine)$Text"
    }
}

function Test-AwsResource {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $null = & aws @Arguments `
            --profile $ProfileName `
            --region $Region `
            --no-cli-pager 2>&1

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    return ($ExitCode -eq 0)
}

function Test-AllowedHttpCidr {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Cidr
    )

    if ($Cidr -notmatch "^([^/]+)/32$") {
        return $false
    }

    $IpText = [string]$Matches[1]
    $IpAddress = $null

    if (
        -not [System.Net.IPAddress]::TryParse(
            $IpText,
            [ref]$IpAddress
        )
    ) {
        return $false
    }

    if (
        $IpAddress.AddressFamily -ne
        [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {
        return $false
    }

    if (
        $IpText -eq "0.0.0.0" -or
        $IpText -eq "255.255.255.255"
    ) {
        return $false
    }

    return $true
}

try {
    Write-Host "Lab 10 - Nginx web service on Amazon Linux 2023"

    Write-Step "Prerequisites"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    if (-not (Test-AllowedHttpCidr -Cidr $AllowedHttpCidr)) {
        throw "AllowedHttpCidr must contain one valid public IPv4 address using /32."
    }

    if (-not (Test-Path -LiteralPath $TrustPolicyPath -PathType Leaf)) {
        throw "Trust policy was not found: $TrustPolicyPath"
    }

    $null = Get-Content `
        -LiteralPath $TrustPolicyPath `
        -Raw |
        ConvertFrom-Json

    $null = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    Write-Ok "AWS CLI, trust policy, session, and HTTP CIDR validated."

    Write-Step "Lab 08 network"

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $Vpcs = @($VpcResult.Vpcs)

    if ($Vpcs.Count -ne 1) {
        throw "Exactly one available VPC named $VpcName is required."
    }

    $VpcId = [string]$Vpcs[0].VpcId

    $SubnetResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$SubnetName",
        "Name=availability-zone,Values=$AvailabilityZone",
        "Name=state,Values=available"
    )

    $Subnets = @($SubnetResult.Subnets)

    if ($Subnets.Count -ne 1) {
        throw "Exactly one available subnet named $SubnetName is required."
    }

    $SubnetId = [string]$Subnets[0].SubnetId

    Write-Ok "Lab 08 VPC and subnet located."

    Write-Step "Conflict check"

    $ExistingResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $ExistingInstances = @(
        foreach ($Reservation in @($ExistingResult.Reservations)) {
            @($Reservation.Instances)
        }
    )

    if ($ExistingInstances.Count -gt 0) {
        throw "EC2 instance $InstanceName already exists. Run cleanup first."
    }

    if (
        Test-AwsResource -Arguments @(
            "iam",
            "get-role",
            "--role-name",
            $RoleName
        )
    ) {
        throw "IAM role $RoleName already exists. Run cleanup first."
    }

    if (
        Test-AwsResource -Arguments @(
            "iam",
            "get-instance-profile",
            "--instance-profile-name",
            $InstanceProfileName
        )
    ) {
        throw "Instance Profile $InstanceProfileName already exists. Run cleanup first."
    }

    $ExistingSgResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$SecurityGroupName"
    )

    if (@($ExistingSgResult.SecurityGroups).Count -gt 0) {
        throw "Security Group $SecurityGroupName already exists. Run cleanup first."
    }

    Write-Ok "No conflicting Lab 10 resources found."

    Write-Step "IAM"

    $PolicyFilePath = (
        Resolve-Path -LiteralPath $TrustPolicyPath
    ).Path -replace "\\", "/"

    $PolicyFileArgument = "file://$PolicyFilePath"

    Invoke-AwsCommand -Arguments @(
        "iam",
        "create-role",
        "--role-name",
        $RoleName,
        "--assume-role-policy-document",
        $PolicyFileArgument,
        "--description",
        "Lab 10 EC2 role for AWS Systems Manager",
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=10",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb"
    )

    Invoke-AwsCommand -Arguments @(
        "iam",
        "attach-role-policy",
        "--role-name",
        $RoleName,
        "--policy-arn",
        $PolicyArn
    )

    Invoke-AwsCommand -Arguments @(
        "iam",
        "create-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName,
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=10",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb"
    )

    Invoke-AwsCommand -Arguments @(
        "iam",
        "add-role-to-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName,
        "--role-name",
        $RoleName
    )

    Write-Ok "IAM role and Instance Profile configured."

    Write-Info "Waiting 15 seconds for IAM propagation."
    Start-Sleep -Seconds 15

    Write-Step "Security Group"

    $CreatedSg = Invoke-AwsJson -Arguments @(
        "ec2",
        "create-security-group",
        "--group-name",
        $SecurityGroupName,
        "--description",
        "Lab 10 Nginx HTTP access restricted to one IPv4 address",
        "--vpc-id",
        $VpcId
    )

    $SecurityGroupId = [string]$CreatedSg.GroupId

    Invoke-AwsCommand -Arguments @(
        "ec2",
        "create-tags",
        "--resources",
        $SecurityGroupId,
        "--tags",
        "Key=Name,Value=$SecurityGroupName",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=10",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb"
    )

    Invoke-AwsCommand -Arguments @(
        "ec2",
        "authorize-security-group-ingress",
        "--group-id",
        $SecurityGroupId,
        "--protocol",
        "tcp",
        "--port",
        "80",
        "--cidr",
        $AllowedHttpCidr
    )

    Write-Ok "TCP port 80 authorized only for $AllowedHttpCidr."
    Write-Ok "No SSH ingress rule was created."

    Write-Step "Amazon Linux 2023"

    $AmiResult = Invoke-AwsJson -Arguments @(
        "ssm",
        "get-parameter",
        "--name",
        $AmiParameter
    )

    $ImageId = [string]$AmiResult.Parameter.Value

    if ([string]::IsNullOrWhiteSpace($ImageId)) {
        throw "Amazon Linux 2023 image could not be discovered."
    }

    Write-Ok "Latest Amazon Linux 2023 image discovered."

    Write-Step "EC2 and Nginx"

    $UserData = @'
#!/bin/bash
set -euxo pipefail

dnf install -y nginx

cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Lab 10 - Linux Web Service</title>
    <style>
        body {
            background: #0d1117;
            color: #e6edf3;
            font-family: Arial, sans-serif;
            margin: 0;
        }

        main {
            max-width: 760px;
            margin: 80px auto;
            padding: 32px;
            border: 1px solid #30363d;
            border-radius: 12px;
            background: #161b22;
        }

        h1 {
            color: #58a6ff;
        }

        .status {
            color: #3fb950;
            font-weight: bold;
        }

        code {
            color: #79c0ff;
        }
    </style>
</head>
<body>
    <main>
        <h1>Lab 10 - Serviço web Nginx em Linux</h1>
        <p class="status">HTTP 200 - serviço disponível</p>
        <p>Amazon Linux 2023 com Nginx administrado pelo systemd.</p>
        <p>Acesso administrativo realizado pelo AWS Systems Manager.</p>
        <p>Projeto: <code>cloud-infrastructure-operations-lab</code></p>
    </main>
</body>
</html>
HTML

systemctl enable nginx
systemctl restart nginx

curl --fail --silent http://localhost/ > /dev/null

touch /var/lib/cloud/instance/lab10-nginx-ready
'@

    $TemporaryUserDataPath = Join-Path `
        -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "lab10-user-data.sh"

    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $TemporaryUserDataPath,
        $UserData,
        $Utf8WithoutBom
    )

    $UserDataFilePath = (
        Resolve-Path -LiteralPath $TemporaryUserDataPath
    ).Path -replace "\\", "/"

    $UserDataArgument = "fileb://$UserDataFilePath"

    $BlockDevice = "DeviceName=/dev/xvda,Ebs={VolumeSize=8,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}"

    $InstanceTags = "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName},{Key=Project,Value=cloud-infrastructure-operations-lab},{Key=Environment,Value=lab},{Key=Lab,Value=10},{Key=ManagedBy,Value=aws-cli},{Key=Owner,Value=itamarsb},{Key=Service,Value=nginx}]"

    $VolumeTags = "ResourceType=volume,Tags=[{Key=Name,Value=$InstanceName-root},{Key=Project,Value=cloud-infrastructure-operations-lab},{Key=Environment,Value=lab},{Key=Lab,Value=10},{Key=ManagedBy,Value=aws-cli},{Key=Owner,Value=itamarsb}]"

    try {
        $RunResult = Invoke-AwsJson -Arguments @(
            "ec2",
            "run-instances",
            "--image-id",
            $ImageId,
            "--instance-type",
            $InstanceType,
            "--subnet-id",
            $SubnetId,
            "--security-group-ids",
            $SecurityGroupId,
            "--iam-instance-profile",
            "Name=$InstanceProfileName",
            "--associate-public-ip-address",
            "--metadata-options",
            "HttpTokens=required,HttpEndpoint=enabled,HttpPutResponseHopLimit=1",
            "--block-device-mappings",
            $BlockDevice,
            "--user-data",
            $UserDataArgument,
            "--tag-specifications",
            $InstanceTags,
            $VolumeTags,
            "--count",
            "1"
        )
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryUserDataPath) {
            Remove-Item -LiteralPath $TemporaryUserDataPath -Force
        }
    }

    $InstanceId = [string]$RunResult.Instances[0].InstanceId

    if ([string]::IsNullOrWhiteSpace($InstanceId)) {
        throw "AWS did not return the EC2 instance ID."
    }

    Write-Ok "EC2 creation requested: $InstanceId"

    Invoke-AwsCommand -Arguments @(
        "ec2",
        "wait",
        "instance-status-ok",
        "--instance-ids",
        $InstanceId
    )

    Write-Ok "EC2 instance passed status checks."

    Write-Step "Systems Manager"

    $Online = $false

    for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
        $SsmResult = Invoke-AwsJson -Arguments @(
            "ssm",
            "describe-instance-information",
            "--filters",
            "Key=InstanceIds,Values=$InstanceId"
        )

        $ManagedNodes = @($SsmResult.InstanceInformationList)

        if (
            $ManagedNodes.Count -eq 1 -and
            $ManagedNodes[0].PingStatus -eq "Online"
        ) {
            $Online = $true
            break
        }

        Write-Info "Waiting for Systems Manager: attempt $Attempt/30."
        Start-Sleep -Seconds 10
    }

    if (-not $Online) {
        throw "Instance did not become online in Systems Manager within five minutes."
    }

    Write-Ok "Instance is online in Systems Manager."

    Write-Step "HTTP validation"

    $InstanceResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--instance-ids",
        $InstanceId
    )

    $Instance = $InstanceResult.Reservations[0].Instances[0]
    $PublicDnsName = [string]$Instance.PublicDnsName
    $PublicIpAddress = [string]$Instance.PublicIpAddress

    if ([string]::IsNullOrWhiteSpace($PublicDnsName)) {
        throw "The instance does not have a public DNS name."
    }

    $WebUrl = "http://$PublicDnsName/"
    $HttpReady = $false

    for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
        try {
            $Response = Invoke-WebRequest `
                -Uri $WebUrl `
                -UseBasicParsing `
                -TimeoutSec 10

            if (
                $Response.StatusCode -eq 200 -and
                $Response.Content -match "Lab 10"
            ) {
                $HttpReady = $true
                break
            }
        }
        catch {
            Write-Info "Waiting for Nginx: attempt $Attempt/30."
        }

        Start-Sleep -Seconds 10
    }

    if (-not $HttpReady) {
        throw "Nginx did not return the expected HTTP response within five minutes."
    }

    Write-Ok "Nginx returned HTTP 200 with the expected Lab 10 content."

    Write-Host ""
    Write-Host "DEPLOYMENT COMPLETED" -ForegroundColor Green
    Write-Host "Instance ID:      $InstanceId"
    Write-Host "Public IPv4:      $PublicIpAddress"
    Write-Host "HTTP source CIDR: $AllowedHttpCidr"
    Write-Host "Web URL:          $WebUrl"
    Write-Host "Next step: run test-linux-web-service.ps1"

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "If resources were created, run remove-linux-web-service.ps1 -ConfirmRemoval." `
        -ForegroundColor Yellow

    exit 1
}
