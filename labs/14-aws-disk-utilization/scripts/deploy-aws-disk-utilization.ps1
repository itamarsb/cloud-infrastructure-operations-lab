[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [string]$AvailabilityZone = "us-east-1a",

    [string]$InstanceType = "t3.micro",

    [ValidateRange(1, 16)]
    [int]$DataVolumeSizeGiB = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"

$InstanceName = "lab14-disk-utilization-instance"
$SecurityGroupName = "lab14-disk-utilization-sg"
$RoleName = "lab14-ec2-disk-utilization-role"
$InstanceProfileName = "lab14-ec2-disk-utilization-instance-profile"
$DataVolumeName = "lab14-disk-utilization-data"

$MountPoint = "/var/log/lab14"
$RequestedDeviceName = "/dev/sdf"

$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$AmiParameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

$CommonTags = @{
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

    return "ResourceType=$ResourceType,Tags=[{0}]" -f (
        $tags -join "},{"
    )
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

function Wait-SsmCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandId,

        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [int]$MaximumAttempts = 60,

        [int]$DelaySeconds = 5
    )

    $terminalStatuses = @(
        "Success",
        "Cancelled",
        "TimedOut",
        "Failed",
        "Cancelling"
    )

    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        try {
            $invocation = ConvertFrom-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $CommandId,
                "--instance-id", $InstanceId
            )
        }
        catch {
            if (
                $_.Exception.Message -match "InvocationDoesNotExist" -and
                $attempt -lt $MaximumAttempts
            ) {
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            throw
        }

        if ($terminalStatuses -contains [string]$invocation.Status) {
            if ($invocation.Status -ne "Success") {
                throw (
                    "SSM command $CommandId finished with status " +
                    "$($invocation.Status).`n" +
                    "Standard output:`n$($invocation.StandardOutputContent)`n" +
                    "Standard error:`n$($invocation.StandardErrorContent)"
                )
            }

            return $invocation
        }

        Write-InfoMessage (
            "Waiting for SSM command ${CommandId}: " +
            "attempt $attempt/$MaximumAttempts; " +
            "status $($invocation.Status)."
        )

        Start-Sleep -Seconds $DelaySeconds
    }

    throw "SSM command $CommandId did not finish within the expected time."
}

function Invoke-SsmShellScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $true)]
        [string[]]$Commands,

        [Parameter(Mandatory = $true)]
        [string]$Comment
    )

    $parameters = @{
        commands = $Commands
    } | ConvertTo-Json -Compress

    $response = ConvertFrom-AwsJson -Arguments @(
        "ssm", "send-command",
        "--instance-ids", $InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--comment", $Comment,
        "--parameters", $parameters,
        "--timeout-seconds", "600"
    )

    $commandId = [string]$response.Command.CommandId

    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "Systems Manager did not return a command identifier."
    }

    return Wait-SsmCommand `
        -CommandId $commandId `
        -InstanceId $InstanceId
}

Write-Host "Lab 14 - Disk utilization deployment"

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

    if ([string]::IsNullOrWhiteSpace([string]$identity.Account)) {
        throw "The AWS identity could not be validated."
    }

    Write-Ok "AWS CLI, trust policy and AWS session validated."

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

    $vpcId = [string]$vpcs[0].VpcId

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

    if ([string]$subnet.AvailabilityZone -ne $AvailabilityZone) {
        throw (
            "Subnet $SubnetName belongs to " +
            "$($subnet.AvailabilityZone), not $AvailabilityZone."
        )
    }

    if (-not $subnet.MapPublicIpOnLaunch) {
        throw "The selected subnet does not automatically assign public IPv4."
    }

    $subnetId = [string]$subnet.SubnetId

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

    $existingVolumesResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-volumes",
        "--filters",
        "Name=tag:Name,Values=$DataVolumeName",
        "Name=status,Values=creating,available,in-use,error"
    )

    if (@($existingVolumesResponse.Volumes).Count -gt 0) {
        throw "An EBS volume named $DataVolumeName already exists."
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

    Write-Ok "No conflicting Lab 14 resources found."

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
    Write-InfoMessage "Waiting 15 seconds for IAM propagation."
    Start-Sleep -Seconds 15

    Write-Step "Security Group"

    $groupId = Invoke-AwsCli -Arguments @(
        "ec2", "create-security-group",
        "--group-name", $SecurityGroupName,
        "--description", "Lab 14 Systems Manager only",
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

    Write-Ok "Security Group created without ingress rules."

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

    Write-Step "EC2 instance"

    $userData = @'
#!/bin/bash
set -euo pipefail

systemctl enable --now amazon-ssm-agent
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

    $instanceId = [string]@($instanceResponse.Instances)[0].InstanceId

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

    Write-Step "Dedicated EBS log volume"

    $volumeResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "create-volume",
        "--availability-zone", $AvailabilityZone,
        "--size", $DataVolumeSizeGiB.ToString(),
        "--volume-type", "gp3",
        "--encrypted",
        "--tag-specifications",
        (Get-TagSpecification -ResourceType "volume" -Name $DataVolumeName)
    )

    $volumeId = [string]$volumeResponse.VolumeId

    if ([string]::IsNullOrWhiteSpace($volumeId)) {
        throw "The EBS volume identifier was not returned."
    }

    Write-Ok "Dedicated EBS volume creation requested: $volumeId"

    $null = Invoke-AwsCli -Arguments @(
        "ec2", "wait", "volume-available",
        "--volume-ids", $volumeId
    ) -AllowEmpty

    $null = Invoke-AwsCli -Arguments @(
        "ec2", "attach-volume",
        "--volume-id", $volumeId,
        "--instance-id", $instanceId,
        "--device", $RequestedDeviceName
    )

    $null = Invoke-AwsCli -Arguments @(
        "ec2", "wait", "volume-in-use",
        "--volume-ids", $volumeId
    ) -AllowEmpty

    Write-Ok "Dedicated EBS volume attached to $instanceId."

    Write-Step "Filesystem preparation"

    $normalizedVolumeId = $volumeId.Replace("-", "")

    $prepareCommands = @(
        "set -euo pipefail",
        "cloud-init status --wait",
        "VOLUME_ID='$volumeId'",
        "NORMALIZED_VOLUME_ID='$normalizedVolumeId'",
        "MOUNT_POINT='$MountPoint'",
        "DEVICE=''",
        "for CANDIDATE in /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${volumeId} /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${normalizedVolumeId} /dev/sdf /dev/xvdf; do if [ -e `"`$CANDIDATE`" ]; then DEVICE=`$(readlink -f `"`$CANDIDATE`" ); break; fi; done",
        "if [ -z `"`$DEVICE`" ] || [ ! -b `"`$DEVICE`" ]; then echo 'Dedicated EBS device was not found.' >&2; lsblk -f; exit 1; fi",
        "if findmnt -rn -S `"`$DEVICE`" >/dev/null 2>&1; then echo 'The dedicated device is already mounted.' >&2; exit 1; fi",
        "if [ -n `"`$(blkid -o value -s TYPE `"`$DEVICE`" 2>/dev/null || true)`" ]; then echo 'The dedicated device already contains a filesystem.' >&2; exit 1; fi",
        "mkfs.ext4 -F -L LAB14LOGS `"`$DEVICE`"",
        "UUID=`$(blkid -s UUID -o value `"`$DEVICE`" )",
        "if [ -z `"`$UUID`" ]; then echo 'Filesystem UUID was not returned.' >&2; exit 1; fi",
        "mkdir -p `"`$MOUNT_POINT`"",
        "FSTAB_ENTRY=`"UUID=`$UUID `$MOUNT_POINT ext4 defaults,nofail 0 2`"",
        "if ! grep -Fqx `"`$FSTAB_ENTRY`" /etc/fstab; then printf '%s\n' `"`$FSTAB_ENTRY`" >> /etc/fstab; fi",
        "mount `"`$MOUNT_POINT`"",
        "mountpoint -q `"`$MOUNT_POINT`"",
        "mkdir -p `"`$MOUNT_POINT/generated`" `"`$MOUNT_POINT/archive`"",
        "printf '%s\n' `"`$VOLUME_ID`" > `"`$MOUNT_POINT/.lab14-volume`"",
        "chown -R root:root `"`$MOUNT_POINT`"",
        "chmod 0750 `"`$MOUNT_POINT`" `"`$MOUNT_POINT/generated`" `"`$MOUNT_POINT/archive`"",
        "findmnt `"`$MOUNT_POINT`"",
        "df -hT `"`$MOUNT_POINT`"",
        "df -i `"`$MOUNT_POINT`""
    )

    $preparationResult = Invoke-SsmShellScript `
        -InstanceId $instanceId `
        -Commands $prepareCommands `
        -Comment "Lab 14 dedicated EBS filesystem preparation"

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$preparationResult.StandardOutputContent
        )
    ) {
        Write-Host $preparationResult.StandardOutputContent.Trim()
    }

    Write-Ok "The dedicated filesystem was created and mounted."

    Write-Step "Deployment validation"

    $validationCommands = @(
        "set -euo pipefail",
        "MOUNT_POINT='$MountPoint'",
        "EXPECTED_VOLUME_ID='$volumeId'",
        "mountpoint -q `"`$MOUNT_POINT`"",
        "test -f `"`$MOUNT_POINT/.lab14-volume`"",
        "ACTUAL_VOLUME_ID=`$(cat `"`$MOUNT_POINT/.lab14-volume`" )",
        "test `"`$ACTUAL_VOLUME_ID`" = `"`$EXPECTED_VOLUME_ID`"",
        "FILESYSTEM_TYPE=`$(findmnt -n -o FSTYPE --target `"`$MOUNT_POINT`" )",
        "test `"`$FILESYSTEM_TYPE`" = 'ext4'",
        "test -d `"`$MOUNT_POINT/generated`"",
        "test -d `"`$MOUNT_POINT/archive`"",
        "grep -Eq '^UUID=[^[:space:]]+[[:space:]]+/var/log/lab14[[:space:]]+ext4[[:space:]]' /etc/fstab",
        "USAGE_PERCENT=`$(df -P `"`$MOUNT_POINT`" | awk 'NR==2 {gsub(/%/, `"`", `$5); print `$5}')",
        "if [ `"`$USAGE_PERCENT`" -ge 60 ]; then echo `"Initial usage is unexpectedly high: `$USAGE_PERCENT%`" >&2; exit 1; fi",
        "echo `"Volume: `$ACTUAL_VOLUME_ID`"",
        "echo `"Filesystem: `$FILESYSTEM_TYPE`"",
        "echo `"Initial usage: `$USAGE_PERCENT%`"",
        "findmnt `"`$MOUNT_POINT`"",
        "df -hT `"`$MOUNT_POINT`""
    )

    $validationResult = Invoke-SsmShellScript `
        -InstanceId $instanceId `
        -Commands $validationCommands `
        -Comment "Lab 14 initial deployment validation"

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$validationResult.StandardOutputContent
        )
    ) {
        Write-Host $validationResult.StandardOutputContent.Trim()
    }

    $instanceDescription = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--instance-ids", $instanceId
    )

    $createdInstance = @(
        $instanceDescription.Reservations |
            ForEach-Object { $_.Instances }
    )[0]

    $publicIpAddress = [string]$createdInstance.PublicIpAddress

    if ([string]::IsNullOrWhiteSpace($publicIpAddress)) {
        throw "The instance does not have a public IPv4 address."
    }

    $createdVolumeResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-volumes",
        "--volume-ids", $volumeId
    )

    $createdVolume = @($createdVolumeResponse.Volumes)[0]

    if (
        [string]$createdVolume.State -ne "in-use" -or
        -not [bool]$createdVolume.Encrypted -or
        [string]$createdVolume.VolumeType -ne "gp3" -or
        [int]$createdVolume.Size -ne $DataVolumeSizeGiB
    ) {
        throw "The dedicated EBS volume does not match the expected state."
    }

    Write-Ok "The Lab 14 infrastructure passed initial validation."

    Write-Host ""
    Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host ("VPC:              {0}" -f $vpcId)
    Write-Host ("Subnet:           {0}" -f $subnetId)
    Write-Host ("Security Group:   {0}" -f $groupId)
    Write-Host ("Instance:         {0}" -f $instanceId)
    Write-Host ("Public IPv4:      {0}" -f $publicIpAddress)
    Write-Host ("Data volume:      {0}" -f $volumeId)
    Write-Host ("Volume size:      {0} GiB" -f $DataVolumeSizeGiB)
    Write-Host ("Mount point:      {0}" -f $MountPoint)
    Write-Host "Ingress rules:    none"
    Write-Host "Next step: run test-aws-disk-utilization.ps1"
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host (
        "If resources were created, run " +
        "remove-aws-disk-utilization.ps1 -ConfirmRemoval."
    ) -ForegroundColor Yellow

    exit 1
}

