[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [string]$AvailabilityZone = "us-east-1a",
    [string]$InstanceType = "t3.micro"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"
$InstanceName = "lab09-managed-instance"
$SecurityGroupName = "lab09-managed-instance-sg"
$RoleName = "lab09-ec2-ssm-role"
$InstanceProfileName = "lab09-ec2-ssm-instance-profile"

$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$AmiParameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

$TrustPolicyPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath "..\policies\ec2-ssm-trust-policy.json"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)

    Write-Host "[OK] $Message" -ForegroundColor Green
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

try {
    Write-Host "Lab 09 - Secure EC2 managed through AWS Systems Manager"

    Write-Step "Prerequisites"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
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

    Write-Ok "AWS CLI, trust policy, and session validated."

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

    $ExistingSg = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$SecurityGroupName"
    )

    if (@($ExistingSg.SecurityGroups).Count -gt 0) {
        throw "Security Group $SecurityGroupName already exists. Run cleanup first."
    }

    Write-Ok "No conflicting Lab 09 resources found."

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
        "Lab 09 EC2 role for AWS Systems Manager",
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=09",
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
        "Key=Lab,Value=09",
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

    Write-Host "[INFO] Waiting 15 seconds for IAM propagation." -ForegroundColor Cyan
    Start-Sleep -Seconds 15

    Write-Step "Security Group"

    $CreatedSg = Invoke-AwsJson -Arguments @(
        "ec2",
        "create-security-group",
        "--group-name",
        $SecurityGroupName,
        "--description",
        "Lab 09 managed instance without inbound access",
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
        "Key=Lab,Value=09",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb"
    )

    Write-Ok "Security Group created without ingress rules."

    Write-Step "EC2"

    $AmiResult = Invoke-AwsJson -Arguments @(
        "ssm",
        "get-parameter",
        "--name",
        $AmiParameter
    )

    $ImageId = [string]$AmiResult.Parameter.Value

    $BlockDevice = "DeviceName=/dev/xvda,Ebs={VolumeSize=8,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}"

    $InstanceTags = "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName},{Key=Project,Value=cloud-infrastructure-operations-lab},{Key=Environment,Value=lab},{Key=Lab,Value=09},{Key=ManagedBy,Value=aws-cli},{Key=Owner,Value=itamarsb}]"

    $VolumeTags = "ResourceType=volume,Tags=[{Key=Name,Value=$InstanceName-root},{Key=Project,Value=cloud-infrastructure-operations-lab},{Key=Environment,Value=lab},{Key=Lab,Value=09},{Key=ManagedBy,Value=aws-cli},{Key=Owner,Value=itamarsb}]"

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
        "--tag-specifications",
        $InstanceTags,
        $VolumeTags,
        "--count",
        "1"
    )

    $InstanceId = [string]$RunResult.Instances[0].InstanceId

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

        Write-Host "[INFO] Waiting for SSM: attempt $Attempt/30." -ForegroundColor Cyan
        Start-Sleep -Seconds 10
    }

    if (-not $Online) {
        throw "Instance did not become online in Systems Manager within five minutes."
    }

    Write-Ok "Instance is online in Systems Manager."

    Write-Host ""
    Write-Host "DEPLOYMENT COMPLETED" -ForegroundColor Green
    Write-Host "Instance ID: $InstanceId"
    Write-Host "Next step: run test-aws-managed-instance.ps1"

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "If resources were created, run remove-aws-managed-instance.ps1 -ConfirmRemoval." -ForegroundColor Yellow

    exit 1
}
