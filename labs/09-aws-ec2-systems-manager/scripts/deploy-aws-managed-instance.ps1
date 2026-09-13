[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProfileName = "cloud-operations-lab",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Region = "us-east-1",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AvailabilityZone = "us-east-1a",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceType = "t3.micro"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectName = "cloud-infrastructure-operations-lab"
$EnvironmentName = "lab"
$LabNumber = "09"
$ManagedBy = "aws-cli"
$Owner = "itamarsb"

$VpcName = "lab08-application-vpc"
$VpcCidr = "10.20.0.0/16"
$SubnetName = "lab08-public-subnet-a"
$SubnetCidr = "10.20.10.0/24"

$InstanceName = "lab09-managed-instance"
$SecurityGroupName = "lab09-managed-instance-sg"
$RoleName = "lab09-ec2-ssm-role"
$InstanceProfileName = "lab09-ec2-ssm-instance-profile"

$ManagedPolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$AmiParameterName = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

$TrustPolicyPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath "..\policies\ec2-ssm-trust-policy.json"

$CreatedRole = $false
$AttachedManagedPolicy = $false
$CreatedInstanceProfile = $false
$AddedRoleToInstanceProfile = $false
$CreatedSecurityGroup = $false
$CreatedInstance = $false

$VpcId = $null
$SubnetId = $null
$SecurityGroupId = $null
$InstanceId = $null
$RootVolumeId = $null

function Write-Pass {
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

    $CommandArguments = @($Arguments) + @(
        "--profile",
        $ProfileName,
        "--region",
        $Region,
        "--output",
        "json",
        "--no-cli-pager"
    )

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $CommandOutput = @(& aws @CommandArguments 2>&1)
        $CommandExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($CommandExitCode -ne 0) {
        $ErrorText = ($CommandOutput | ForEach-Object { "$_" }) -join [Environment]::NewLine
        throw "AWS CLI command failed: aws $($Arguments -join ' ')$([Environment]::NewLine)$ErrorText"
    }

    $JsonText = ($CommandOutput | ForEach-Object { "$_" }) -join [Environment]::NewLine

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return $null
    }

    return $JsonText | ConvertFrom-Json
}

function Invoke-AwsCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $CommandArguments = @($Arguments) + @(
        "--profile",
        $ProfileName,
        "--region",
        $Region,
        "--no-cli-pager"
    )

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $CommandOutput = @(& aws @CommandArguments 2>&1)
        $CommandExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($CommandExitCode -ne 0) {
        $ErrorText = ($CommandOutput | ForEach-Object { "$_" }) -join [Environment]::NewLine
        throw "AWS CLI command failed: aws $($Arguments -join ' ')$([Environment]::NewLine)$ErrorText"
    }

    return $CommandOutput
}

function Test-AwsResourceExists {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $CommandArguments = @($Arguments) + @(
        "--profile",
        $ProfileName,
        "--region",
        $Region,
        "--output",
        "json",
        "--no-cli-pager"
    )

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $null = @(& aws @CommandArguments 2>&1)
        $CommandExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    return ($CommandExitCode -eq 0)
}

function Get-TagValue {
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $TagCollection = @($Tags)
    $MatchingTag = @(
        $TagCollection |
            Where-Object { $_.Key -eq $Key }
    )

    if ($MatchingTag.Count -eq 1) {
        return [string]$MatchingTag[0].Value
    }

    return $null
}

function Assert-OperationalTags {
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$ResourceDescription,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedLab
    )

    $ExpectedTags = @{
        Project     = $ProjectName
        Environment = $EnvironmentName
        Lab         = $ExpectedLab
        ManagedBy   = $ManagedBy
        Owner       = $Owner
    }

    foreach ($ExpectedTag in $ExpectedTags.GetEnumerator()) {
        $ActualValue = Get-TagValue `
            -Tags $Tags `
            -Key $ExpectedTag.Key

        if ($ActualValue -ne $ExpectedTag.Value) {
            throw "$ResourceDescription does not contain the expected tag $($ExpectedTag.Key)=$($ExpectedTag.Value)."
        }
    }
}

function Remove-PartiallyCreatedResources {
    Write-Host ""
    Write-Host "=== Rollback of resources created during this execution ===" -ForegroundColor Yellow

    if ($CreatedInstance -and -not [string]::IsNullOrWhiteSpace($InstanceId)) {
        try {
            $null = Invoke-AwsCommand -Arguments @(
                "ec2",
                "terminate-instances",
                "--instance-ids",
                $InstanceId
            )

            $null = Invoke-AwsCommand -Arguments @(
                "ec2",
                "wait",
                "instance-terminated",
                "--instance-ids",
                $InstanceId
            )

            Write-Info "Partially created EC2 instance was terminated."
        }
        catch {
            Write-Host "[WARN] The partially created instance could not be terminated automatically." -ForegroundColor Yellow
        }
    }

    if ($CreatedSecurityGroup -and -not [string]::IsNullOrWhiteSpace($SecurityGroupId)) {
        try {
            $null = Invoke-AwsCommand -Arguments @(
                "ec2",
                "delete-security-group",
                "--group-id",
                $SecurityGroupId
            )

            Write-Info "Partially created Security Group was removed."
        }
        catch {
            Write-Host "[WARN] The partially created Security Group could not be removed automatically." -ForegroundColor Yellow
        }
    }

    if ($AddedRoleToInstanceProfile) {
        try {
            $null = Invoke-AwsCommand -Arguments @(
                "iam",
                "remove-role-from-instance-profile",
                "--instance-profile-name",
                $InstanceProfileName,
                "--role-name",
                $RoleName
            )

            Write-Info "Role was removed from the partially created Instance Profile."
        }
        catch {
            Write-Host "[WARN] The role could not be removed from the Instance Profile automatically." -ForegroundColor Yellow
        }
    }

    if ($CreatedInstanceProfile) {
        try {
            $null = Invoke-AwsCommand -Arguments @(
                "iam",
                "delete-instance-profile",
                "--instance-profile-name",
                $InstanceProfileName
            )

            Write-Info "Partially created Instance Profile was removed."
        }
        catch {
            Write-Host "[WARN] The partially created Instance Profile could not be removed automatically." -ForegroundColor Yellow
        }
    }

    if ($AttachedManagedPolicy) {
        try {
            $null = Invoke-AwsCommand -Arguments @(
                "iam",
                "detach-role-policy",
                "--role-name",
                $RoleName,
                "--policy-arn",
                $ManagedPolicyArn
            )

            Write-Info "Managed policy was detached from the partially created IAM role."
        }
        catch {
            Write-Host "[WARN] The managed policy could not be detached automatically." -ForegroundColor Yellow
        }
    }

    if ($CreatedRole) {
        try {
            $null = Invoke-AwsCommand -Arguments @(
                "iam",
                "delete-role",
                "--role-name",
                $RoleName
            )

            Write-Info "Partially created IAM role was removed."
        }
        catch {
            Write-Host "[WARN] The partially created IAM role could not be removed automatically." -ForegroundColor Yellow
        }
    }
}

try {
    Write-Host ""
    Write-Host "Lab 09 - AWS EC2 managed instance deployment"
    Write-Host "Profile:      $ProfileName"
    Write-Host "Region:       $Region"
    Write-Host "Availability: $AvailabilityZone"
    Write-Host "Instance:     $InstanceType"

    Write-Host ""
    Write-Host "=== Prerequisite validation ===" -ForegroundColor Cyan

    $AwsVersionOutput = @(& aws --version 2>&1)

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI is not available."
    }

    Write-Pass "AWS CLI available: $($AwsVersionOutput[0])"

    if (-not (Test-Path -LiteralPath $TrustPolicyPath -PathType Leaf)) {
        throw "Trust policy was not found: $TrustPolicyPath"
    }

    try {
        $TrustPolicy = Get-Content `
            -LiteralPath $TrustPolicyPath `
            -Raw |
            ConvertFrom-Json
    }
    catch {
        throw "Trust policy is not a valid JSON document."
    }

    $TrustStatements = @($TrustPolicy.Statement)

    $TrustPolicyIsValid = (
        $TrustPolicy.Version -eq "2012-10-17" -and
        $TrustStatements.Count -eq 1 -and
        $TrustStatements[0].Effect -eq "Allow" -and
        $TrustStatements[0].Principal.Service -eq "ec2.amazonaws.com" -and
        $TrustStatements[0].Action -eq "sts:AssumeRole"
    )

    if (-not $TrustPolicyIsValid) {
        throw "Trust policy does not match the expected EC2 relationship."
    }

    Write-Pass "EC2 trust policy validated locally."

    $null = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    Write-Pass "AWS session validated without displaying account identifiers."

    $AvailabilityZoneResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-availability-zones",
        "--zone-names",
        $AvailabilityZone
    )

    $AvailabilityZones = @($AvailabilityZoneResult.AvailabilityZones)

    if (
        $AvailabilityZones.Count -ne 1 -or
        $AvailabilityZones[0].State -ne "available" -or
        $AvailabilityZones[0].RegionName -ne $Region
    ) {
        throw "Availability Zone $AvailabilityZone is not available in $Region."
    }

    Write-Pass "Availability Zone $AvailabilityZone is available."

    Write-Host ""
    Write-Host "=== Lab 08 network validation ===" -ForegroundColor Cyan

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=cidr-block,Values=$VpcCidr",
        "Name=state,Values=available"
    )

    $Vpcs = @($VpcResult.Vpcs)

    if ($Vpcs.Count -ne 1) {
        throw "Exactly one available Lab 08 VPC was expected, but $($Vpcs.Count) were found."
    }

    $Vpc = $Vpcs[0]
    $VpcId = [string]$Vpc.VpcId

    Assert-OperationalTags `
        -Tags @($Vpc.Tags) `
        -ResourceDescription "Lab 08 VPC" `
        -ExpectedLab "08"

    Write-Pass "Lab 08 VPC located with the expected CIDR and ownership tags."

    $SubnetResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$SubnetName",
        "Name=cidr-block,Values=$SubnetCidr",
        "Name=availability-zone,Values=$AvailabilityZone",
        "Name=state,Values=available"
    )

    $Subnets = @($SubnetResult.Subnets)

    if ($Subnets.Count -ne 1) {
        throw "Exactly one expected Lab 08 subnet was required, but $($Subnets.Count) were found."
    }

    $Subnet = $Subnets[0]
    $SubnetId = [string]$Subnet.SubnetId

    Assert-OperationalTags `
        -Tags @($Subnet.Tags) `
        -ResourceDescription "Lab 08 public subnet" `
        -ExpectedLab "08"

    if (-not [bool]$Subnet.MapPublicIpOnLaunch) {
        throw "The Lab 08 subnet does not enable automatic public IPv4 assignment."
    }

    Write-Pass "Lab 08 public subnet located in $AvailabilityZone."
    Write-Pass "Automatic public IPv4 assignment is enabled."

    Write-Host ""
    Write-Host "=== Conflict verification ===" -ForegroundColor Cyan

    $ExistingInstanceResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down"
    )

    $ExistingReservations = @($ExistingInstanceResult.Reservations)
    $ExistingInstances = @(
        foreach ($Reservation in $ExistingReservations) {
            @($Reservation.Instances)
        }
    )

    if ($ExistingInstances.Count -ne 0) {
        throw "An active or recoverable EC2 instance named $InstanceName already exists."
    }

    Write-Pass "No conflicting EC2 instance was found."

    if (
        Test-AwsResourceExists -Arguments @(
            "iam",
            "get-role",
            "--role-name",
            $RoleName
        )
    ) {
        throw "An IAM role named $RoleName already exists."
    }

    Write-Pass "No conflicting IAM role was found."

    if (
        Test-AwsResourceExists -Arguments @(
            "iam",
            "get-instance-profile",
            "--instance-profile-name",
            $InstanceProfileName
        )
    ) {
        throw "An Instance Profile named $InstanceProfileName already exists."
    }

    Write-Pass "No conflicting Instance Profile was found."

    $ExistingSecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$SecurityGroupName"
    )

    $ExistingSecurityGroups = @($ExistingSecurityGroupResult.SecurityGroups)

    if ($ExistingSecurityGroups.Count -ne 0) {
        throw "A Security Group named $SecurityGroupName already exists in the target VPC."
    }

    Write-Pass "No conflicting Security Group was found."

    Write-Host ""
    Write-Host "=== Amazon Linux 2023 image discovery ===" -ForegroundColor Cyan

    $AmiParameterResult = Invoke-AwsJson -Arguments @(
        "ssm",
        "get-parameter",
        "--name",
        $AmiParameterName
    )

    $ImageId = [string]$AmiParameterResult.Parameter.Value

    if ($ImageId -notmatch "^ami-[a-zA-Z0-9]+$") {
        throw "The public Systems Manager parameter did not return a valid AMI ID."
    }

    $ImageResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-images",
        "--image-ids",
        $ImageId
    )

    $Images = @($ImageResult.Images)

    if ($Images.Count -ne 1) {
        throw "The Amazon Linux 2023 image could not be validated."
    }

    if ($Images[0].State -ne "available") {
        throw "The selected Amazon Linux 2023 image is not available."
    }

    $RootDeviceName = [string]$Images[0].RootDeviceName

    if ([string]::IsNullOrWhiteSpace($RootDeviceName)) {
        throw "The root device name could not be determined."
    }

    Write-Pass "Latest available Amazon Linux 2023 image discovered dynamically."

    Write-Host ""
    Write-Host "=== IAM role creation ===" -ForegroundColor Cyan

    $ResolvedTrustPolicyPath = (Resolve-Path -LiteralPath $TrustPolicyPath).Path
    $TrustPolicyUri = ([System.Uri]$ResolvedTrustPolicyPath).AbsoluteUri

    $null = Invoke-AwsJson -Arguments @(
        "iam",
        "create-role",
        "--role-name",
        $RoleName,
        "--assume-role-policy-document",
        $TrustPolicyUri,
        "--description",
        "Lab 09 EC2 role for AWS Systems Manager",
        "--tags",
        "Key=Project,Value=$ProjectName",
        "Key=Environment,Value=$EnvironmentName",
        "Key=Lab,Value=$LabNumber",
        "Key=ManagedBy,Value=$ManagedBy",
        "Key=Owner,Value=$Owner"
    )

    $CreatedRole = $true
    Write-Pass "IAM role created with a trust relationship restricted to EC2."

    $null = Invoke-AwsCommand -Arguments @(
        "iam",
        "attach-role-policy",
        "--role-name",
        $RoleName,
        "--policy-arn",
        $ManagedPolicyArn
    )

    $AttachedManagedPolicy = $true
    Write-Pass "AmazonSSMManagedInstanceCore attached to the IAM role."

    Write-Host ""
    Write-Host "=== Instance Profile creation ===" -ForegroundColor Cyan

    $null = Invoke-AwsJson -Arguments @(
        "iam",
        "create-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName,
        "--tags",
        "Key=Project,Value=$ProjectName",
        "Key=Environment,Value=$EnvironmentName",
        "Key=Lab,Value=$LabNumber",
        "Key=ManagedBy,Value=$ManagedBy",
        "Key=Owner,Value=$Owner"
    )

    $CreatedInstanceProfile = $true
    Write-Pass "Instance Profile created."

    $null = Invoke-AwsCommand -Arguments @(
        "iam",
        "add-role-to-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName,
        "--role-name",
        $RoleName
    )

    $AddedRoleToInstanceProfile = $true
    Write-Pass "IAM role associated with the Instance Profile."

    Write-Info "Waiting for IAM resource propagation."
    Start-Sleep -Seconds 15

    Write-Host ""
    Write-Host "=== Security Group creation ===" -ForegroundColor Cyan

    $SecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "create-security-group",
        "--group-name",
        $SecurityGroupName,
        "--description",
        "Lab 09 managed instance without inbound access",
        "--vpc-id",
        $VpcId
    )

    $SecurityGroupId = [string]$SecurityGroupResult.GroupId
    $CreatedSecurityGroup = $true

    $null = Invoke-AwsCommand -Arguments @(
        "ec2",
        "create-tags",
        "--resources",
        $SecurityGroupId,
        "--tags",
        "Key=Name,Value=$SecurityGroupName",
        "Key=Project,Value=$ProjectName",
        "Key=Environment,Value=$EnvironmentName",
        "Key=Lab,Value=$LabNumber",
        "Key=ManagedBy,Value=$ManagedBy",
        "Key=Owner,Value=$Owner"
    )

    $SecurityGroupValidation = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--group-ids",
        $SecurityGroupId
    )

    $SecurityGroups = @($SecurityGroupValidation.SecurityGroups)

    if ($SecurityGroups.Count -ne 1) {
        throw "The newly created Security Group could not be validated."
    }

    if (@($SecurityGroups[0].IpPermissions).Count -ne 0) {
        throw "The Security Group unexpectedly contains ingress rules."
    }

    Write-Pass "Security Group created without ingress rules."

    Write-Host ""
    Write-Host "=== EC2 instance creation ===" -ForegroundColor Cyan

    $BlockDeviceConfiguration = @(
        @{
            DeviceName = $RootDeviceName
            Ebs = @{
                VolumeSize          = 8
                VolumeType          = "gp3"
                Encrypted           = $true
                DeleteOnTermination = $true
            }
        }
    ) | ConvertTo-Json -Depth 5 -Compress

    $InstanceTagSpecification = @(
        @{
            ResourceType = "instance"
            Tags = @(
                @{ Key = "Name";        Value = $InstanceName },
                @{ Key = "Project";     Value = $ProjectName },
                @{ Key = "Environment"; Value = $EnvironmentName },
                @{ Key = "Lab";         Value = $LabNumber },
                @{ Key = "ManagedBy";   Value = $ManagedBy },
                @{ Key = "Owner";       Value = $Owner }
            )
        },
        @{
            ResourceType = "volume"
            Tags = @(
                @{ Key = "Name";        Value = "$InstanceName-root" },
                @{ Key = "Project";     Value = $ProjectName },
                @{ Key = "Environment"; Value = $EnvironmentName },
                @{ Key = "Lab";         Value = $LabNumber },
                @{ Key = "ManagedBy";   Value = $ManagedBy },
                @{ Key = "Owner";       Value = $Owner }
            )
        }
    ) | ConvertTo-Json -Depth 6 -Compress

    $RunInstanceResult = Invoke-AwsJson -Arguments @(
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
        $BlockDeviceConfiguration,
        "--tag-specifications",
        $InstanceTagSpecification,
        "--count",
        "1"
    )

    $CreatedInstances = @($RunInstanceResult.Instances)

    if ($CreatedInstances.Count -ne 1) {
        throw "AWS did not return exactly one newly created EC2 instance."
    }

    $InstanceId = [string]$CreatedInstances[0].InstanceId
    $CreatedInstance = $true

    Write-Pass "EC2 instance creation requested."
    Write-Pass "No Key Pair was associated."
    Write-Pass "IMDSv2 was configured as mandatory."
    Write-Pass "Encrypted gp3 root volume was requested."

    Write-Info "Waiting for the EC2 instance to enter the running state."

    $null = Invoke-AwsCommand -Arguments @(
        "ec2",
        "wait",
        "instance-running",
        "--instance-ids",
        $InstanceId
    )

    Write-Pass "EC2 instance reached the running state."

    $null = Invoke-AwsCommand -Arguments @(
        "ec2",
        "wait",
        "instance-status-ok",
        "--instance-ids",
        $InstanceId
    )

    Write-Pass "EC2 status checks completed successfully."

    Write-Host ""
    Write-Host "=== EC2 security validation ===" -ForegroundColor Cyan

    $InstanceDescription = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--instance-ids",
        $InstanceId
    )

    $Reservations = @($InstanceDescription.Reservations)

    if ($Reservations.Count -ne 1) {
        throw "The deployed instance could not be located."
    }

    $Instances = @($Reservations[0].Instances)

    if ($Instances.Count -ne 1) {
        throw "The deployed instance could not be uniquely identified."
    }

    $Instance = $Instances[0]

    if ($Instance.State.Name -ne "running") {
        throw "The deployed instance is not running."
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Instance.KeyName)) {
        throw "The deployed instance unexpectedly contains a Key Pair."
    }

    if ($Instance.MetadataOptions.HttpTokens -ne "required") {
        throw "IMDSv2 is not mandatory."
    }

    if ($Instance.IamInstanceProfile.Arn -notmatch "/$([regex]::Escape($InstanceProfileName))$") {
        throw "The expected Instance Profile is not associated with the instance."
    }

    if (@($Instance.SecurityGroups).Count -ne 1) {
        throw "The instance does not contain exactly one Security Group."
    }

    if ($Instance.SecurityGroups[0].GroupId -ne $SecurityGroupId) {
        throw "The instance is not associated with the expected Security Group."
    }

    Assert-OperationalTags `
        -Tags @($Instance.Tags) `
        -ResourceDescription "EC2 instance" `
        -ExpectedLab "09"

    $RootBlockDevice = @(
        @($Instance.BlockDeviceMappings) |
            Where-Object { $_.DeviceName -eq $RootDeviceName }
    )

    if ($RootBlockDevice.Count -ne 1) {
        throw "The root volume could not be uniquely identified."
    }

    $RootVolumeId = [string]$RootBlockDevice[0].Ebs.VolumeId

    if (-not [bool]$RootBlockDevice[0].Ebs.DeleteOnTermination) {
        throw "The root volume is not configured for removal on termination."
    }

    $VolumeResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-volumes",
        "--volume-ids",
        $RootVolumeId
    )

    $Volumes = @($VolumeResult.Volumes)

    if ($Volumes.Count -ne 1 -or -not [bool]$Volumes[0].Encrypted) {
        throw "The root volume is not encrypted."
    }

    Write-Pass "Instance is running without a Key Pair."
    Write-Pass "IMDSv2 is mandatory."
    Write-Pass "Expected Instance Profile is associated."
    Write-Pass "Security Group contains no ingress rules."
    Write-Pass "Root volume is encrypted and configured for removal on termination."
    Write-Pass "Instance contains the required operational tags."

    Write-Host ""
    Write-Host "=== Systems Manager registration ===" -ForegroundColor Cyan

    $SsmInstance = $null
    $MaximumAttempts = 30

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        $ManagedInstanceResult = Invoke-AwsJson -Arguments @(
            "ssm",
            "describe-instance-information",
            "--filters",
            "Key=InstanceIds,Values=$InstanceId"
        )

        $ManagedInstances = @($ManagedInstanceResult.InstanceInformationList)

        if (
            $ManagedInstances.Count -eq 1 -and
            $ManagedInstances[0].PingStatus -eq "Online"
        ) {
            $SsmInstance = $ManagedInstances[0]
            break
        }

        Write-Info "Waiting for Systems Manager registration: attempt $Attempt of $MaximumAttempts."
        Start-Sleep -Seconds 10
    }

    if ($null -eq $SsmInstance) {
        throw "The instance did not register as an online Systems Manager managed node within the expected time."
    }

    Write-Pass "Instance registered as an online Systems Manager managed node."

    Write-Host ""
    Write-Host "=== Deployment summary ===" -ForegroundColor Cyan

    Write-Pass "Amazon Linux 2023 instance is running."
    Write-Pass "Instance is located in the expected Lab 08 subnet."
    Write-Pass "IAM role and Instance Profile are configured."
    Write-Pass "AmazonSSMManagedInstanceCore is attached."
    Write-Pass "Security Group contains no ingress rules."
    Write-Pass "No SSH Key Pair is associated."
    Write-Pass "IMDSv2 is mandatory."
    Write-Pass "Root volume is encrypted."
    Write-Pass "Systems Manager reports the instance as online."

    Write-Host ""
    Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "No SSH port, Key Pair, Elastic IP, NAT Gateway, VPC Endpoint, or load balancer was created."
    Write-Host "Run test-aws-managed-instance.ps1 before recording the final validation evidence."

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] Deployment could not be completed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if (
        $CreatedInstance -or
        $CreatedSecurityGroup -or
        $AddedRoleToInstanceProfile -or
        $CreatedInstanceProfile -or
        $AttachedManagedPolicy -or
        $CreatedRole
    ) {
        Remove-PartiallyCreatedResources
    }

    Write-Host ""
    Write-Host "Review the AWS account before running the script again." -ForegroundColor Yellow
    exit 1
}
