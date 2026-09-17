[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [string]$AvailabilityZoneA = "us-east-1a",

    [string]$AvailabilityZoneB = "us-east-1b",

    [string]$InstanceType = "t3.micro"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetAName = "lab08-public-subnet-a"
$SubnetBName = "lab08-public-subnet-b"

$InstanceAName = "lab12-availability-instance-a"
$InstanceBName = "lab12-availability-instance-b"
$AlbSecurityGroupName = "lab12-alb-sg"
$BackendSecurityGroupName = "lab12-backend-sg"
$RoleName = "lab12-ec2-availability-role"
$InstanceProfileName = "lab12-ec2-availability-instance-profile"
$LoadBalancerName = "lab12-availability-alb"
$TargetGroupName = "lab12-availability-tg"

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

function New-UserDataFile {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("A", "B")]
        [string]$Backend
    )

    $Template = @'
#!/bin/bash
set -euxo pipefail

dnf install -y nginx

cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Lab 12 - Application Availability</title>
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
        <h1>Lab 12 - Disponibilidade da aplica&ccedil;&atilde;o</h1>
        <p class="status">HTTP 200 - servi&ccedil;o dispon&iacute;vel</p>
        <p>Resposta processada pelo backend <strong>__BACKEND__</strong>.</p>
        <p>Distribui&ccedil;&atilde;o realizada pelo Application Load Balancer.</p>
        <p>Projeto: <code>cloud-infrastructure-operations-lab</code></p>
    </main>
</body>
</html>
HTML

printf 'healthy\n' > /usr/share/nginx/html/health

systemctl enable nginx
systemctl restart nginx

curl --fail --silent http://localhost/ > /dev/null
curl --fail --silent http://localhost/health | grep --fixed-strings healthy

touch /var/lib/cloud/instance/lab12-nginx-ready
'@

    $UserData = $Template.Replace("__BACKEND__", $Backend)
    $TemporaryPath = Join-Path `
        -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "lab12-user-data-$($Backend.ToLowerInvariant()).sh"

    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $TemporaryPath,
        $UserData,
        $Utf8WithoutBom
    )

    return $TemporaryPath
}

function Wait-SsmOnline {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$InstanceIds
    )

    foreach ($InstanceId in $InstanceIds) {
        $Online = $false

        for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
            $SsmResult = Invoke-AwsJson -Arguments @(
                "ssm",
                "describe-instance-information",
                "--filters",
                "Key=InstanceIds,Values=$InstanceId"
            )

            $ManagedNodes = @(
                $SsmResult.InstanceInformationList |
                    Where-Object { $null -ne $_ }
            )

            if (
                $ManagedNodes.Count -eq 1 -and
                $ManagedNodes[0].PingStatus -eq "Online"
            ) {
                $Online = $true
                break
            }

            Write-Info "Waiting for $InstanceId in Systems Manager: attempt $Attempt/30."
            Start-Sleep -Seconds 10
        }

        if (-not $Online) {
            throw "$InstanceId did not become online in Systems Manager within five minutes."
        }

        Write-Ok "$InstanceId is online in Systems Manager."
    }
}

function Wait-TargetsHealthy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetGroupArn,

        [Parameter(Mandatory = $true)]
        [string[]]$InstanceIds
    )

    for ($Attempt = 1; $Attempt -le 40; $Attempt++) {
        $HealthResult = Invoke-AwsJson -Arguments @(
            "elbv2",
            "describe-target-health",
            "--target-group-arn",
            $TargetGroupArn
        )

        $Descriptions = @(
            $HealthResult.TargetHealthDescriptions |
                Where-Object { $null -ne $_ }
        )

        $HealthyIds = @(
            $Descriptions |
                Where-Object { $_.TargetHealth.State -eq "healthy" } |
                ForEach-Object { [string]$_.Target.Id }
        )

        $AllHealthy = $Descriptions.Count -eq $InstanceIds.Count

        foreach ($InstanceId in $InstanceIds) {
            if ($HealthyIds -notcontains $InstanceId) {
                $AllHealthy = $false
            }
        }

        if ($AllHealthy) {
            return
        }

        $StateSummary = @(
            $Descriptions |
                ForEach-Object {
                    "$($_.Target.Id)=$($_.TargetHealth.State)"
                }
        ) -join ", "

        if ([string]::IsNullOrWhiteSpace($StateSummary)) {
            $StateSummary = "no target state returned"
        }

        Write-Info "Waiting for healthy targets: attempt $Attempt/40 ($StateSummary)."
        Start-Sleep -Seconds 10
    }

    throw "The two targets did not become healthy within the expected time."
}

try {
    Write-Host "Lab 12 - Application availability with an Application Load Balancer"

    Write-Step "Prerequisites"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    if ($AvailabilityZoneA -eq $AvailabilityZoneB) {
        throw "Two different Availability Zones are required."
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

    foreach ($AvailabilityZone in @($AvailabilityZoneA, $AvailabilityZoneB)) {
        $ZoneResult = Invoke-AwsJson -Arguments @(
            "ec2",
            "describe-availability-zones",
            "--zone-names",
            $AvailabilityZone
        )

        $Zones = @(
            $ZoneResult.AvailabilityZones |
                Where-Object { $null -ne $_ }
        )

        if (
            $Zones.Count -ne 1 -or
            [string]$Zones[0].State -ne "available"
        ) {
            throw "Availability Zone $AvailabilityZone is not available."
        }
    }

    Write-Ok "AWS CLI, trust policy, session, and Availability Zones validated."

    Write-Step "Lab 08 network"

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $Vpcs = @(
        $VpcResult.Vpcs |
            Where-Object { $null -ne $_ }
    )

    if ($Vpcs.Count -ne 1) {
        throw "Exactly one available VPC named $VpcName is required."
    }

    $VpcId = [string]$Vpcs[0].VpcId

    $SubnetAResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$SubnetAName",
        "Name=availability-zone,Values=$AvailabilityZoneA",
        "Name=state,Values=available"
    )

    $SubnetBResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$SubnetBName",
        "Name=availability-zone,Values=$AvailabilityZoneB",
        "Name=state,Values=available"
    )

    $SubnetsA = @(
        $SubnetAResult.Subnets |
            Where-Object { $null -ne $_ }
    )

    $SubnetsB = @(
        $SubnetBResult.Subnets |
            Where-Object { $null -ne $_ }
    )

    if ($SubnetsA.Count -ne 1) {
        throw "Exactly one available subnet named $SubnetAName is required in $AvailabilityZoneA."
    }

    if ($SubnetsB.Count -ne 1) {
        throw "Exactly one available subnet named $SubnetBName is required in $AvailabilityZoneB."
    }

    $SubnetAId = [string]$SubnetsA[0].SubnetId
    $SubnetBId = [string]$SubnetsB[0].SubnetId

    if ($SubnetAId -eq $SubnetBId) {
        throw "Two different subnets are required."
    }

    Write-Ok "Lab 08 VPC and two public subnets located."

    Write-Step "Conflict check"

    $ExistingInstanceResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--filters",
        "Name=tag:Lab,Values=12",
        "Name=tag:Project,Values=cloud-infrastructure-operations-lab",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $ExistingInstances = @(
        foreach ($Reservation in @($ExistingInstanceResult.Reservations)) {
            @(
                $Reservation.Instances |
                    Where-Object { $null -ne $_ }
            )
        }
    )

    if ($ExistingInstances.Count -gt 0) {
        throw "Active Lab 12 EC2 resources already exist. Run cleanup first."
    }

    if (
        Test-AwsResource -Arguments @(
            "iam",
            "get-role",
            "--role-name",
            $RoleName
        )
    ) {
        throw "IAM Role $RoleName already exists. Run cleanup first."
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

    foreach ($SecurityGroupName in @(
        $AlbSecurityGroupName,
        $BackendSecurityGroupName
    )) {
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
    }

    if (
        Test-AwsResource -Arguments @(
            "elbv2",
            "describe-load-balancers",
            "--names",
            $LoadBalancerName
        )
    ) {
        throw "Load Balancer $LoadBalancerName already exists. Run cleanup first."
    }

    if (
        Test-AwsResource -Arguments @(
            "elbv2",
            "describe-target-groups",
            "--names",
            $TargetGroupName
        )
    ) {
        throw "Target Group $TargetGroupName already exists. Run cleanup first."
    }

    Write-Ok "No conflicting Lab 12 resources found."

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
        "Lab 12 EC2 role for AWS Systems Manager",
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=12",
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
        "Key=Lab,Value=12",
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

    Write-Ok "IAM Role and Instance Profile configured."
    Write-Info "Waiting 15 seconds for IAM propagation."
    Start-Sleep -Seconds 15

    Write-Step "Security Groups"

    $CreatedAlbSg = Invoke-AwsJson -Arguments @(
        "ec2",
        "create-security-group",
        "--group-name",
        $AlbSecurityGroupName,
        "--description",
        "Lab 12 public HTTP access to the Application Load Balancer",
        "--vpc-id",
        $VpcId
    )

    $AlbSecurityGroupId = [string]$CreatedAlbSg.GroupId

    $CreatedBackendSg = Invoke-AwsJson -Arguments @(
        "ec2",
        "create-security-group",
        "--group-name",
        $BackendSecurityGroupName,
        "--description",
        "Lab 12 backend HTTP access restricted to the load balancer",
        "--vpc-id",
        $VpcId
    )

    $BackendSecurityGroupId = [string]$CreatedBackendSg.GroupId

    Invoke-AwsCommand -Arguments @(
        "ec2",
        "create-tags",
        "--resources",
        $AlbSecurityGroupId,
        "--tags",
        "Key=Name,Value=$AlbSecurityGroupName",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=12",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb"
    )

    Invoke-AwsCommand -Arguments @(
        "ec2",
        "create-tags",
        "--resources",
        $BackendSecurityGroupId,
        "--tags",
        "Key=Name,Value=$BackendSecurityGroupName",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=12",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb"
    )

    Invoke-AwsCommand -Arguments @(
        "ec2",
        "authorize-security-group-ingress",
        "--group-id",
        $AlbSecurityGroupId,
        "--protocol",
        "tcp",
        "--port",
        "80",
        "--cidr",
        "0.0.0.0/0"
    )

    Invoke-AwsCommand -Arguments @(
        "ec2",
        "authorize-security-group-ingress",
        "--group-id",
        $BackendSecurityGroupId,
        "--protocol",
        "tcp",
        "--port",
        "80",
        "--source-group",
        $AlbSecurityGroupId
    )

    Write-Ok "Public HTTP authorized only on the Application Load Balancer."
    Write-Ok "Backend HTTP authorized only from the ALB Security Group."
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

    Write-Step "EC2 backends and Nginx"

    $UserDataAPath = New-UserDataFile -Backend "A"
    $UserDataBPath = New-UserDataFile -Backend "B"

    $BlockDevice = "DeviceName=/dev/xvda,Ebs={VolumeSize=8,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}"

    $BackendDefinitions = @(
        [pscustomobject]@{
            Name = $InstanceAName
            Backend = "A"
            SubnetId = $SubnetAId
            AvailabilityZone = $AvailabilityZoneA
            UserDataPath = $UserDataAPath
        },
        [pscustomobject]@{
            Name = $InstanceBName
            Backend = "B"
            SubnetId = $SubnetBId
            AvailabilityZone = $AvailabilityZoneB
            UserDataPath = $UserDataBPath
        }
    )

    $CreatedInstances = @()

    try {
        foreach ($BackendDefinition in $BackendDefinitions) {
            $UserDataFilePath = (
                Resolve-Path -LiteralPath $BackendDefinition.UserDataPath
            ).Path -replace "\\", "/"

            $UserDataArgument = "fileb://$UserDataFilePath"
            $InstanceName = [string]$BackendDefinition.Name
            $BackendName = [string]$BackendDefinition.Backend

            $InstanceTags = "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName},{Key=Project,Value=cloud-infrastructure-operations-lab},{Key=Environment,Value=lab},{Key=Lab,Value=12},{Key=ManagedBy,Value=aws-cli},{Key=Owner,Value=itamarsb},{Key=Service,Value=nginx},{Key=Backend,Value=$BackendName}]"
            $VolumeTags = "ResourceType=volume,Tags=[{Key=Name,Value=$InstanceName-root},{Key=Project,Value=cloud-infrastructure-operations-lab},{Key=Environment,Value=lab},{Key=Lab,Value=12},{Key=ManagedBy,Value=aws-cli},{Key=Owner,Value=itamarsb},{Key=Backend,Value=$BackendName}]"

            $RunResult = Invoke-AwsJson -Arguments @(
                "ec2",
                "run-instances",
                "--image-id",
                $ImageId,
                "--instance-type",
                $InstanceType,
                "--subnet-id",
                [string]$BackendDefinition.SubnetId,
                "--security-group-ids",
                $BackendSecurityGroupId,
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

            $InstanceId = [string]$RunResult.Instances[0].InstanceId

            if ([string]::IsNullOrWhiteSpace($InstanceId)) {
                throw "AWS did not return the EC2 instance ID for backend $BackendName."
            }

            $CreatedInstances += [pscustomobject]@{
                InstanceId = $InstanceId
                Name = $InstanceName
                Backend = $BackendName
                AvailabilityZone = [string]$BackendDefinition.AvailabilityZone
            }

            Write-Ok "Backend $BackendName creation requested in $($BackendDefinition.AvailabilityZone): $InstanceId"
        }
    }
    finally {
        foreach ($TemporaryPath in @($UserDataAPath, $UserDataBPath)) {
            if (Test-Path -LiteralPath $TemporaryPath) {
                Remove-Item -LiteralPath $TemporaryPath -Force
            }
        }
    }

    $InstanceIds = @(
        $CreatedInstances |
            ForEach-Object { [string]$_.InstanceId }
    )

    if ($InstanceIds.Count -ne 2) {
        throw "Exactly two EC2 instances must be created."
    }

    Invoke-AwsCommand -Arguments (
        @(
            "ec2",
            "wait",
            "instance-status-ok",
            "--instance-ids"
        ) + $InstanceIds
    )

    Write-Ok "Both EC2 instances passed status checks."

    Write-Step "Systems Manager"

    Wait-SsmOnline -InstanceIds $InstanceIds

    Write-Step "Target Group"

    $TargetGroupResult = Invoke-AwsJson -Arguments @(
        "elbv2",
        "create-target-group",
        "--name",
        $TargetGroupName,
        "--protocol",
        "HTTP",
        "--port",
        "80",
        "--vpc-id",
        $VpcId,
        "--target-type",
        "instance",
        "--health-check-protocol",
        "HTTP",
        "--health-check-port",
        "traffic-port",
        "--health-check-path",
        "/health",
        "--health-check-interval-seconds",
        "15",
        "--health-check-timeout-seconds",
        "5",
        "--healthy-threshold-count",
        "2",
        "--unhealthy-threshold-count",
        "2",
        "--matcher",
        "HttpCode=200",
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=12",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb",
        "Key=Name,Value=$TargetGroupName"
    )

    $TargetGroupArn = [string]$TargetGroupResult.TargetGroups[0].TargetGroupArn

    if ([string]::IsNullOrWhiteSpace($TargetGroupArn)) {
        throw "AWS did not return the Target Group ARN."
    }

    $TargetArguments = @(
        foreach ($InstanceId in $InstanceIds) {
            "Id=$InstanceId,Port=80"
        }
    )

    Invoke-AwsCommand -Arguments (
        @(
            "elbv2",
            "register-targets",
            "--target-group-arn",
            $TargetGroupArn,
            "--targets"
        ) + $TargetArguments
    )

    Write-Ok "Two EC2 instances registered in the Target Group."

    Write-Step "Application Load Balancer"

    $LoadBalancerResult = Invoke-AwsJson -Arguments @(
        "elbv2",
        "create-load-balancer",
        "--name",
        $LoadBalancerName,
        "--subnets",
        $SubnetAId,
        $SubnetBId,
        "--security-groups",
        $AlbSecurityGroupId,
        "--scheme",
        "internet-facing",
        "--type",
        "application",
        "--ip-address-type",
        "ipv4",
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=12",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb",
        "Key=Name,Value=$LoadBalancerName"
    )

    $LoadBalancer = $LoadBalancerResult.LoadBalancers[0]
    $LoadBalancerArn = [string]$LoadBalancer.LoadBalancerArn
    $LoadBalancerDnsName = [string]$LoadBalancer.DNSName

    if (
        [string]::IsNullOrWhiteSpace($LoadBalancerArn) -or
        [string]::IsNullOrWhiteSpace($LoadBalancerDnsName)
    ) {
        throw "AWS did not return the load balancer ARN and DNS name."
    }

    Invoke-AwsCommand -Arguments @(
        "elbv2",
        "wait",
        "load-balancer-available",
        "--load-balancer-arns",
        $LoadBalancerArn
    )

    Write-Ok "Application Load Balancer is available."

    Write-Step "HTTP Listener"

    $ListenerResult = Invoke-AwsJson -Arguments @(
        "elbv2",
        "create-listener",
        "--load-balancer-arn",
        $LoadBalancerArn,
        "--protocol",
        "HTTP",
        "--port",
        "80",
        "--default-actions",
        "Type=forward,TargetGroupArn=$TargetGroupArn",
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=12",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb"
    )

    $ListenerArn = [string]$ListenerResult.Listeners[0].ListenerArn

    if ([string]::IsNullOrWhiteSpace($ListenerArn)) {
        throw "AWS did not return the Listener ARN."
    }

    Write-Ok "HTTP Listener created on TCP port 80."

    Write-Step "Target health"

    Wait-TargetsHealthy `
        -TargetGroupArn $TargetGroupArn `
        -InstanceIds $InstanceIds

    Write-Ok "Both targets are healthy."

    Write-Step "Application validation"

    $ApplicationUrl = "http://$LoadBalancerDnsName/"
    $HttpReady = $false

    for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
        try {
            $Response = Invoke-WebRequest `
                -Uri $ApplicationUrl `
                -UseBasicParsing `
                -TimeoutSec 10

            if (
                $Response.StatusCode -eq 200 -and
                $Response.Content -match "Lab 12" -and
                $Response.Content -match "backend (A|B)"
            ) {
                $HttpReady = $true
                break
            }
        }
        catch {
            Write-Info "Waiting for the application through the ALB: attempt $Attempt/30."
        }

        Start-Sleep -Seconds 10
    }

    if (-not $HttpReady) {
        throw "The Application Load Balancer did not return the expected HTTP response."
    }

    Write-Ok "Application Load Balancer returned HTTP 200 with Lab 12 content."

    Write-Host ""
    Write-Host "DEPLOYMENT COMPLETED" -ForegroundColor Green
    Write-Host "VPC:                $VpcId"
    Write-Host "Subnet A:           $SubnetAId ($AvailabilityZoneA)"
    Write-Host "Subnet B:           $SubnetBId ($AvailabilityZoneB)"
    Write-Host "Backend A:          $($CreatedInstances[0].InstanceId)"
    Write-Host "Backend B:          $($CreatedInstances[1].InstanceId)"
    Write-Host "Target Group ARN:   $TargetGroupArn"
    Write-Host "Load Balancer ARN:  $LoadBalancerArn"
    Write-Host "Listener ARN:       $ListenerArn"
    Write-Host "Application URL:    $ApplicationUrl"
    Write-Host "Next step: run test-aws-application-availability.ps1"

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "If resources were created, run remove-aws-application-availability.ps1 -ConfirmRemoval." `
        -ForegroundColor Yellow

    exit 1
}
