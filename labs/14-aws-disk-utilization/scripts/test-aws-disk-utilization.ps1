[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [ValidateSet("Healthy", "Elevated", "Any")]
    [string]$ExpectedUsageState = "Healthy",

    [ValidateRange(1, 99)]
    [int]$HealthyUsageMaximumPercent = 60,

    [ValidateRange(1, 99)]
    [int]$ElevatedUsageMinimumPercent = 80,

    [ValidateRange(1, 99)]
    [int]$SafetyUsageMaximumPercent = 88
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"
$AvailabilityZone = "us-east-1a"

$InstanceName = "lab14-disk-utilization-instance"
$SecurityGroupName = "lab14-disk-utilization-sg"
$RoleName = "lab14-ec2-disk-utilization-role"
$InstanceProfileName = "lab14-ec2-disk-utilization-instance-profile"
$DataVolumeName = "lab14-disk-utilization-data"

$MountPoint = "/var/log/lab14"
$DataVolumeSizeGiB = 2
$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

$Failures = 0

$ExpectedTags = @{
    Project     = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab         = "14"
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

function Add-Pass {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Add-Failure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:Failures++
}

function Test-Condition {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$SuccessMessage,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    if ($Condition) {
        Add-Pass $SuccessMessage
    }
    else {
        Add-Failure $FailureMessage
    }
}

function Invoke-AwsCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$AllowEmpty
    )

    $output = @(
        & aws @Arguments `
            --profile $ProfileName `
            --region $Region `
            --no-cli-pager 2>&1
    )

    $exitCode = $LASTEXITCODE
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

function Get-TagValue {
    param(
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $tag = @($Tags) |
        Where-Object { $_.Key -eq $Key } |
        Select-Object -First 1

    if ($null -eq $tag) {
        return $null
    }

    return [string]$tag.Value
}

function Test-RequiredTags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceDescription,

        [AllowNull()]
        [object[]]$Tags
    )

    foreach ($key in $ExpectedTags.Keys) {
        $actualValue = Get-TagValue -Tags $Tags -Key $key
        $expectedValue = $ExpectedTags[$key]

        Test-Condition `
            -Condition ($actualValue -eq $expectedValue) `
            -SuccessMessage (
                "$ResourceDescription has tag $key=$expectedValue."
            ) `
            -FailureMessage (
                "$ResourceDescription does not have the expected " +
                "tag $key=$expectedValue."
            )
    }
}

function ConvertTo-RemoteValues {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    $values = @{}

    foreach ($line in ($Text -split "`n")) {
        if ($line -match '^([A-Z0-9_]+)=(.*)$') {
            $values[$matches[1]] = $matches[2].Trim()
        }
    }

    return $values
}

function Invoke-SsmReadOnlyCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $true)]
        [string[]]$Commands,

        [int]$MaximumAttempts = 30,

        [int]$DelaySeconds = 5
    )

    $parameters = @{
        commands = $Commands
    } | ConvertTo-Json -Compress

    $parametersPath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        ("lab14-test-ssm-{0}.json" -f [guid]::NewGuid().ToString("N"))

    try {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)

        [System.IO.File]::WriteAllText(
            $parametersPath,
            $parameters,
            $utf8WithoutBom
        )

        $parametersFileArgument = "file://$parametersPath"

        $commandResponse = ConvertFrom-AwsJson -Arguments @(
            "ssm", "send-command",
            "--instance-ids", $InstanceId,
            "--document-name", "AWS-RunShellScript",
            "--comment", "Lab 14 read-only validation",
            "--parameters", $parametersFileArgument
        )
    }
    finally {
        if (Test-Path -LiteralPath $parametersPath -PathType Leaf) {
            Remove-Item `
                -LiteralPath $parametersPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    $commandId = $commandResponse.Command.CommandId

    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "Systems Manager did not return a command identifier."
    }

    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        Start-Sleep -Seconds $DelaySeconds

        try {
            $invocation = ConvertFrom-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $commandId,
                "--instance-id", $InstanceId
            )
        }
        catch {
            if ($attempt -eq $MaximumAttempts) {
                throw
            }

            continue
        }

        if ($invocation.Status -eq "Success") {
            return [pscustomobject]@{
                Status         = $invocation.Status
                ResponseCode   = $invocation.ResponseCode
                StandardOutput = (
                    [string]$invocation.StandardOutputContent
                ).Replace("`r", "")
                StandardError  = (
                    [string]$invocation.StandardErrorContent
                ).Replace("`r", "")
            }
        }

        if (
            $invocation.Status -in @(
                "Failed",
                "Cancelled",
                "TimedOut",
                "Cancelling"
            )
        ) {
            return [pscustomobject]@{
                Status         = $invocation.Status
                ResponseCode   = $invocation.ResponseCode
                StandardOutput = (
                    [string]$invocation.StandardOutputContent
                ).Replace("`r", "")
                StandardError  = (
                    [string]$invocation.StandardErrorContent
                ).Replace("`r", "")
            }
        }
    }

    throw "The Systems Manager command did not finish in time."
}

Write-Host "Lab 14 - Independent disk utilization validation"

try {
    if ($HealthyUsageMaximumPercent -ge $ElevatedUsageMinimumPercent) {
        throw (
            "HealthyUsageMaximumPercent must be lower than " +
            "ElevatedUsageMinimumPercent."
        )
    }

    if ($ElevatedUsageMinimumPercent -gt $SafetyUsageMaximumPercent) {
        throw (
            "ElevatedUsageMinimumPercent cannot exceed " +
            "SafetyUsageMaximumPercent."
        )
    }

    Write-Step "Prerequisites and identity"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    $identity = ConvertFrom-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    Test-Condition `
        -Condition (
            -not [string]::IsNullOrWhiteSpace([string]$identity.Account)
        ) `
        -SuccessMessage "AWS session is authenticated." `
        -FailureMessage "AWS identity could not be validated."

    Write-Step "Lab 08 shared network"

    $vpcResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $vpcs = @($vpcResponse.Vpcs)

    Test-Condition `
        -Condition ($vpcs.Count -eq 1) `
        -SuccessMessage "Exactly one available Lab 08 VPC exists." `
        -FailureMessage (
            "Expected one available Lab 08 VPC; found $($vpcs.Count)."
        )

    if ($vpcs.Count -ne 1) {
        throw "The Lab 08 VPC could not be uniquely identified."
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

    Test-Condition `
        -Condition ($subnets.Count -eq 1) `
        -SuccessMessage "Exactly one Lab 08 application subnet exists." `
        -FailureMessage (
            "Expected one application subnet; found $($subnets.Count)."
        )

    if ($subnets.Count -ne 1) {
        throw "The Lab 08 subnet could not be uniquely identified."
    }

    $subnet = $subnets[0]
    $subnetId = $subnet.SubnetId

    Test-Condition `
        -Condition ($subnet.AvailabilityZone -eq $AvailabilityZone) `
        -SuccessMessage "The subnet belongs to $AvailabilityZone." `
        -FailureMessage "The subnet does not belong to $AvailabilityZone."

    Write-Step "Security Group"

    $securityGroupResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$SecurityGroupName",
        "Name=vpc-id,Values=$vpcId"
    )

    $securityGroups = @($securityGroupResponse.SecurityGroups)

    Test-Condition `
        -Condition ($securityGroups.Count -eq 1) `
        -SuccessMessage "Exactly one Lab 14 Security Group exists." `
        -FailureMessage (
            "Expected one Lab 14 Security Group; " +
            "found $($securityGroups.Count)."
        )

    if ($securityGroups.Count -ne 1) {
        throw "The Lab 14 Security Group could not be uniquely identified."
    }

    $securityGroup = $securityGroups[0]
    $securityGroupId = $securityGroup.GroupId

    Test-RequiredTags `
        -ResourceDescription "Security Group" `
        -Tags $securityGroup.Tags

    Test-Condition `
        -Condition (@($securityGroup.IpPermissions).Count -eq 0) `
        -SuccessMessage "Security Group has no ingress rules." `
        -FailureMessage "Security Group has an unexpected ingress rule."

    Write-Step "EC2 instance"

    $instanceResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $instances = @(
        $instanceResponse.Reservations |
            ForEach-Object { $_.Instances }
    )

    Test-Condition `
        -Condition ($instances.Count -eq 1) `
        -SuccessMessage "Exactly one active Lab 14 EC2 instance exists." `
        -FailureMessage (
            "Expected one active Lab 14 instance; " +
            "found $($instances.Count)."
        )

    if ($instances.Count -ne 1) {
        throw "The Lab 14 EC2 instance could not be uniquely identified."
    }

    $instance = $instances[0]
    $instanceId = $instance.InstanceId

    Test-Condition `
        -Condition ($instance.State.Name -eq "running") `
        -SuccessMessage "The EC2 instance is running." `
        -FailureMessage (
            "The EC2 instance state is $($instance.State.Name)."
        )

    Test-Condition `
        -Condition (
            $instance.SubnetId -eq $subnetId -and
            $instance.Placement.AvailabilityZone -eq $AvailabilityZone
        ) `
        -SuccessMessage "The instance uses the expected subnet and zone." `
        -FailureMessage (
            "The instance does not use the expected subnet and zone."
        )

    Test-RequiredTags `
        -ResourceDescription "EC2 instance" `
        -Tags $instance.Tags

    Test-Condition `
        -Condition ($null -eq $instance.KeyName) `
        -SuccessMessage "The instance has no SSH Key Pair." `
        -FailureMessage "The instance has an SSH Key Pair."

    Test-Condition `
        -Condition ($instance.MetadataOptions.HttpTokens -eq "required") `
        -SuccessMessage "The instance requires IMDSv2 tokens." `
        -FailureMessage "The instance does not require IMDSv2 tokens."

    $profileArn = [string]$instance.IamInstanceProfile.Arn

    Test-Condition `
        -Condition (
            $profileArn -match (
                "/{0}$" -f [regex]::Escape($InstanceProfileName)
            )
        ) `
        -SuccessMessage "The expected Instance Profile is attached." `
        -FailureMessage "The expected Instance Profile is not attached."

    $instanceGroups = @($instance.SecurityGroups)

    Test-Condition `
        -Condition (
            $instanceGroups.Count -eq 1 -and
            $instanceGroups[0].GroupId -eq $securityGroupId
        ) `
        -SuccessMessage "The instance uses only the expected Security Group." `
        -FailureMessage (
            "The instance does not use only the expected Security Group."
        )

    $rootMappings = @($instance.BlockDeviceMappings) |
        Where-Object { $_.DeviceName -eq $instance.RootDeviceName }

    Test-Condition `
        -Condition (@($rootMappings).Count -eq 1) `
        -SuccessMessage "The root EBS mapping was identified." `
        -FailureMessage "The root EBS mapping was not uniquely identified."

    if (@($rootMappings).Count -eq 1) {
        $rootVolumeId = $rootMappings[0].Ebs.VolumeId
        $rootResponse = ConvertFrom-AwsJson -Arguments @(
            "ec2", "describe-volumes",
            "--volume-ids", $rootVolumeId
        )
        $rootVolume = @($rootResponse.Volumes)[0]

        Test-Condition `
            -Condition ([bool]$rootVolume.Encrypted) `
            -SuccessMessage "The root EBS volume is encrypted." `
            -FailureMessage "The root EBS volume is not encrypted."

        Test-Condition `
            -Condition ($rootVolume.VolumeType -eq "gp3") `
            -SuccessMessage "The root EBS volume uses gp3." `
            -FailureMessage "The root EBS volume does not use gp3."

        Test-Condition `
            -Condition ([bool]$rootMappings[0].Ebs.DeleteOnTermination) `
            -SuccessMessage "The root volume is deleted with the instance." `
            -FailureMessage "The root volume persists after termination."
    }

    Write-Step "Dedicated EBS data volume"

    $dataVolumeResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-volumes",
        "--filters",
        "Name=tag:Name,Values=$DataVolumeName",
        "Name=status,Values=in-use"
    )

    $dataVolumes = @($dataVolumeResponse.Volumes)

    Test-Condition `
        -Condition ($dataVolumes.Count -eq 1) `
        -SuccessMessage "Exactly one attached Lab 14 data volume exists." `
        -FailureMessage (
            "Expected one attached Lab 14 data volume; " +
            "found $($dataVolumes.Count)."
        )

    if ($dataVolumes.Count -ne 1) {
        throw "The Lab 14 data volume could not be uniquely identified."
    }

    $dataVolume = $dataVolumes[0]
    $dataVolumeId = $dataVolume.VolumeId
    $dataAttachments = @($dataVolume.Attachments)

    Test-RequiredTags `
        -ResourceDescription "EBS data volume" `
        -Tags $dataVolume.Tags

    Test-Condition `
        -Condition ([bool]$dataVolume.Encrypted) `
        -SuccessMessage "The data volume is encrypted." `
        -FailureMessage "The data volume is not encrypted."

    Test-Condition `
        -Condition ($dataVolume.VolumeType -eq "gp3") `
        -SuccessMessage "The data volume uses gp3." `
        -FailureMessage "The data volume does not use gp3."

    Test-Condition `
        -Condition ([int]$dataVolume.Size -eq $DataVolumeSizeGiB) `
        -SuccessMessage "The data volume has the expected size." `
        -FailureMessage (
            "The data volume does not have $DataVolumeSizeGiB GiB."
        )

    Test-Condition `
        -Condition ($dataVolume.AvailabilityZone -eq $AvailabilityZone) `
        -SuccessMessage "The data volume uses the expected zone." `
        -FailureMessage "The data volume uses an unexpected zone."

    Test-Condition `
        -Condition (
            $dataAttachments.Count -eq 1 -and
            $dataAttachments[0].InstanceId -eq $instanceId -and
            $dataAttachments[0].State -eq "attached"
        ) `
        -SuccessMessage "The data volume is attached to the Lab 14 instance." `
        -FailureMessage (
            "The data volume is not attached to the expected instance."
        )

    Write-Step "IAM and Systems Manager"

    $roleResponse = ConvertFrom-AwsJson -Arguments @(
        "iam", "get-role",
        "--role-name", $RoleName
    )

    $role = $roleResponse.Role

    Test-Condition `
        -Condition ($null -ne $role) `
        -SuccessMessage "The Lab 14 IAM Role exists." `
        -FailureMessage "The Lab 14 IAM Role does not exist."

    Test-RequiredTags `
        -ResourceDescription "IAM Role" `
        -Tags $role.Tags

    $attachedPoliciesResponse = ConvertFrom-AwsJson -Arguments @(
        "iam", "list-attached-role-policies",
        "--role-name", $RoleName
    )

    $attachedPolicyArns = @(
        $attachedPoliciesResponse.AttachedPolicies |
            ForEach-Object { $_.PolicyArn }
    )

    Test-Condition `
        -Condition ($PolicyArn -in $attachedPolicyArns) `
        -SuccessMessage "AmazonSSMManagedInstanceCore is attached." `
        -FailureMessage "AmazonSSMManagedInstanceCore is not attached."

    $profileResponse = ConvertFrom-AwsJson -Arguments @(
        "iam", "get-instance-profile",
        "--instance-profile-name", $InstanceProfileName
    )

    $profile = $profileResponse.InstanceProfile
    $profileRoles = @($profile.Roles)

    Test-Condition `
        -Condition (
            $profileRoles.Count -eq 1 -and
            $profileRoles[0].RoleName -eq $RoleName
        ) `
        -SuccessMessage "IAM Role belongs to the expected Instance Profile." `
        -FailureMessage (
            "IAM Role does not belong to the expected Instance Profile."
        )

    Test-RequiredTags `
        -ResourceDescription "Instance Profile" `
        -Tags $profile.Tags

    $ssmResponse = ConvertFrom-AwsJson -Arguments @(
        "ssm", "describe-instance-information",
        "--filters", "Key=InstanceIds,Values=$instanceId"
    )

    $managedInstances = @($ssmResponse.InstanceInformationList)

    Test-Condition `
        -Condition ($managedInstances.Count -eq 1) `
        -SuccessMessage "The instance is registered in Systems Manager." `
        -FailureMessage (
            "The instance is not uniquely registered in Systems Manager."
        )

    if ($managedInstances.Count -ne 1) {
        throw "The instance is not available through Systems Manager."
    }

    Test-Condition `
        -Condition ($managedInstances[0].PingStatus -eq "Online") `
        -SuccessMessage "The instance is online in Systems Manager." `
        -FailureMessage "The instance is not online in Systems Manager."

    Write-Step "Read-only filesystem validation"

    $remoteValidation = Invoke-SsmReadOnlyCommand `
        -InstanceId $instanceId `
        -Commands @(
            'set -o pipefail',
            'source /etc/os-release',
            'echo OS_ID=$ID',
            'echo OS_VERSION=$VERSION_ID',
            'MOUNT_POINT="/var/log/lab14"',
            'echo MOUNTED=$(mountpoint -q "$MOUNT_POINT" && echo yes || echo no)',
            'echo SOURCE=$(findmnt -n -o SOURCE --target "$MOUNT_POINT")',
            'echo FSTYPE=$(findmnt -n -o FSTYPE --target "$MOUNT_POINT")',
            'echo OPTIONS=$(findmnt -n -o OPTIONS --target "$MOUNT_POINT")',
            'echo UUID=$(findmnt -n -o UUID --target "$MOUNT_POINT")',
            'UUID=$(findmnt -n -o UUID --target "$MOUNT_POINT")',
            'echo FSTAB_COUNT=$(grep -Ec "^UUID=$UUID[[:space:]]+$MOUNT_POINT[[:space:]]+ext4[[:space:]]" /etc/fstab)',
            'echo MARKER=$(cat "$MOUNT_POINT/.lab14-volume" 2>/dev/null || true)',
            'echo GENERATED_DIR=$(test -d "$MOUNT_POINT/generated" && echo present || echo absent)',
            'echo ARCHIVE_DIR=$(test -d "$MOUNT_POINT/archive" && echo present || echo absent)',
            'df -P "$MOUNT_POINT" | awk ''NR==2 {print "SIZE_KB="$2; print "USED_KB="$3; print "AVAILABLE_KB="$4; gsub(/%/,"",$5); print "USAGE_PERCENT="$5}'''
        )

    Test-Condition `
        -Condition ($remoteValidation.Status -eq "Success") `
        -SuccessMessage "Read-only filesystem inspection succeeded." `
        -FailureMessage (
            "Read-only filesystem inspection failed: " +
            $remoteValidation.StandardError
        )

    if ($remoteValidation.Status -ne "Success") {
        throw "The remote filesystem inspection did not succeed."
    }

    $remoteValues = ConvertTo-RemoteValues `
        -Text $remoteValidation.StandardOutput

    Test-Condition `
        -Condition (
            $remoteValues.ContainsKey("OS_ID") -and
            $remoteValues["OS_ID"] -eq "amzn" -and
            $remoteValues.ContainsKey("OS_VERSION") -and
            $remoteValues["OS_VERSION"] -match '^2023'
        ) `
        -SuccessMessage "The instance runs Amazon Linux 2023." `
        -FailureMessage "Amazon Linux 2023 was not confirmed."

    Test-Condition `
        -Condition (
            $remoteValues.ContainsKey("MOUNTED") -and
            $remoteValues["MOUNTED"] -eq "yes"
        ) `
        -SuccessMessage "$MountPoint is a mounted filesystem." `
        -FailureMessage "$MountPoint is not a mounted filesystem."

    Test-Condition `
        -Condition (
            $remoteValues.ContainsKey("FSTYPE") -and
            $remoteValues["FSTYPE"] -eq "ext4"
        ) `
        -SuccessMessage "The data filesystem uses ext4." `
        -FailureMessage "The data filesystem does not use ext4."

    Test-Condition `
        -Condition (
            $remoteValues.ContainsKey("UUID") -and
            -not [string]::IsNullOrWhiteSpace($remoteValues["UUID"])
        ) `
        -SuccessMessage "The mounted filesystem has a UUID." `
        -FailureMessage "The mounted filesystem UUID was not found."

    Test-Condition `
        -Condition (
            $remoteValues.ContainsKey("FSTAB_COUNT") -and
            [int]$remoteValues["FSTAB_COUNT"] -eq 1
        ) `
        -SuccessMessage "The mount has exactly one UUID entry in fstab." `
        -FailureMessage "The expected UUID entry was not found in fstab."

    Test-Condition `
        -Condition (
            $remoteValues.ContainsKey("MARKER") -and
            $remoteValues["MARKER"] -eq $dataVolumeId
        ) `
        -SuccessMessage "The volume marker matches the attached EBS volume." `
        -FailureMessage "The volume marker does not match the EBS volume."

    Test-Condition `
        -Condition (
            $remoteValues.ContainsKey("GENERATED_DIR") -and
            $remoteValues["GENERATED_DIR"] -eq "present" -and
            $remoteValues.ContainsKey("ARCHIVE_DIR") -and
            $remoteValues["ARCHIVE_DIR"] -eq "present"
        ) `
        -SuccessMessage "The generated and archive directories exist." `
        -FailureMessage "A required Lab 14 directory is missing."

    $usageAvailable = $remoteValues.ContainsKey("USAGE_PERCENT")

    Test-Condition `
        -Condition $usageAvailable `
        -SuccessMessage "Disk utilization was collected." `
        -FailureMessage "Disk utilization could not be collected."

    if ($usageAvailable) {
        $usagePercent = [int]$remoteValues["USAGE_PERCENT"]

        Test-Condition `
            -Condition ($usagePercent -le $SafetyUsageMaximumPercent) `
            -SuccessMessage (
                "Disk utilization is within the safety limit: " +
                "$usagePercent%."
            ) `
            -FailureMessage (
                "Disk utilization exceeded the safety limit: " +
                "$usagePercent%."
            )

        if ($ExpectedUsageState -eq "Healthy") {
            Test-Condition `
                -Condition ($usagePercent -lt $HealthyUsageMaximumPercent) `
                -SuccessMessage (
                    "Disk utilization is healthy: $usagePercent%."
                ) `
                -FailureMessage (
                    "Expected healthy utilization below " +
                    "$HealthyUsageMaximumPercent%; found $usagePercent%."
                )
        }
        elseif ($ExpectedUsageState -eq "Elevated") {
            Test-Condition `
                -Condition (
                    $usagePercent -ge $ElevatedUsageMinimumPercent -and
                    $usagePercent -le $SafetyUsageMaximumPercent
                ) `
                -SuccessMessage (
                    "Controlled elevated utilization confirmed: " +
                    "$usagePercent%."
                ) `
                -FailureMessage (
                    "Expected utilization from " +
                    "$ElevatedUsageMinimumPercent% through " +
                    "$SafetyUsageMaximumPercent%; found $usagePercent%."
                )
        }
        else {
            Add-Pass (
                "Disk utilization state was accepted without a phase " +
                "expectation: $usagePercent%."
            )
        }
    }

    Write-Step "Validation summary"

    Write-Host ("Instance ID:       {0}" -f $instanceId)
    Write-Host ("Data volume ID:    {0}" -f $dataVolumeId)
    Write-Host ("Mount point:       {0}" -f $MountPoint)
    Write-Host ("Expected state:    {0}" -f $ExpectedUsageState)

    if ($usageAvailable) {
        Write-Host (
            "Disk utilization:  {0}%" -f
            $remoteValues["USAGE_PERCENT"]
        )
    }

    if ($Failures -gt 0) {
        throw "Lab 14 validation completed with $Failures failure(s)."
    }

    Write-Host ""
    Write-Host "LAB 14 VALIDATION COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green
    Write-Host "All checks were read-only."
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "LAB 14 VALIDATION FAILED" -ForegroundColor Red
    exit 1
}
