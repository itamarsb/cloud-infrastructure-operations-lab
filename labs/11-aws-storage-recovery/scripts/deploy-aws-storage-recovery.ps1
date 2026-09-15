[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [string]$AvailabilityZone = "us-east-1a",

    [string]$InstanceType = "t3.micro",

    [ValidateRange(1, 16)]
    [int]$DataVolumeSizeGiB = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"

$InstanceName = "lab11-storage-instance"
$SecurityGroupName = "lab11-storage-sg"
$RoleName = "lab11-ec2-storage-role"
$InstanceProfileName = "lab11-ec2-storage-instance-profile"
$InlinePolicyName = "lab11-s3-storage-access"
$DataVolumeName = "lab11-storage-data-volume"

$SsmPolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$ObjectKey = "backup/lab11-storage-data.txt"

$LabPath = Split-Path -Parent $PSScriptRoot

$TrustPolicyPath = Join-Path `
    -Path $LabPath `
    -ChildPath "policies\ec2-ssm-trust-policy.json"

$S3PolicyTemplatePath = Join-Path `
    -Path $LabPath `
    -ChildPath "policies\s3-storage-policy-template.json"

$TemporaryFiles = [System.Collections.Generic.List[string]]::new()

function Write-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Invoke-AwsText {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $Output = & aws @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    $OutputText = ($Output | Out-String).Trim()

    if ($ExitCode -ne 0) {
        throw @"
AWS CLI failed: aws $($Arguments -join " ")
$OutputText
"@
    }

    return $OutputText
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $OutputText = Invoke-AwsText -Arguments $Arguments

    if ([string]::IsNullOrWhiteSpace($OutputText)) {
        return $null
    }

    try {
        return $OutputText | ConvertFrom-Json
    }
    catch {
        throw @"
AWS CLI returned invalid JSON.

Command:
aws $($Arguments -join " ")

Output:
$OutputText
"@
    }
}

function New-TemporaryJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,

        [ValidateRange(2, 100)]
        [int]$Depth = 20
    )

    $Path = Join-Path `
        -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "lab11-$([guid]::NewGuid().ToString('N')).json"

    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

    $Json = $Value |
        ConvertTo-Json -Depth $Depth

    [System.IO.File]::WriteAllText(
        $Path,
        $Json,
        $Utf8WithoutBom
    )

    $TemporaryFiles.Add($Path)
    return $Path
}

function Wait-SsmOnline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [ValidateRange(1, 120)]
        [int]$MaximumAttempts = 60
    )

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        $PingStatus = Invoke-AwsText -Arguments @(
            "ssm", "describe-instance-information",
            "--profile", $ProfileName,
            "--region", $Region,
            "--filters", "Key=InstanceIds,Values=$InstanceId",
            "--query", "InstanceInformationList[0].PingStatus",
            "--output", "text",
            "--no-cli-pager"
        )

        if ($PingStatus -eq "Online") {
            return
        }

        if ($Attempt -eq $MaximumAttempts) {
            throw "The EC2 instance did not become online in Systems Manager."
        }

        Start-Sleep -Seconds 10
    }
}

function Wait-SsmCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandId,

        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [ValidateRange(1, 120)]
        [int]$MaximumAttempts = 60
    )

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        Start-Sleep -Seconds 5

        $Invocation = Invoke-AwsJson -Arguments @(
            "ssm", "get-command-invocation",
            "--profile", $ProfileName,
            "--region", $Region,
            "--command-id", $CommandId,
            "--instance-id", $InstanceId,
            "--output", "json",
            "--no-cli-pager"
        )

        if ($Invocation.Status -eq "Success") {
            if (-not [string]::IsNullOrWhiteSpace($Invocation.StandardOutputContent)) {
                Write-Host $Invocation.StandardOutputContent.Trim()
            }

            return
        }

        if ($Invocation.Status -in @(
            "Cancelled",
            "TimedOut",
            "Failed",
            "Cancelling"
        )) {
            throw @"
The Systems Manager configuration command failed.

Status:
$($Invocation.Status)

Standard output:
$($Invocation.StandardOutputContent)

Standard error:
$($Invocation.StandardErrorContent)
"@
        }

        if ($Attempt -eq $MaximumAttempts) {
            throw "The Systems Manager configuration command timed out."
        }
    }
}

try {
    Write-Host "Lab 11 - AWS storage and recovery"
    Write-Host ""

    Write-Step -Message "Prerequisites"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    foreach ($RequiredFile in @(
        $TrustPolicyPath,
        $S3PolicyTemplatePath
    )) {
        if (-not (Test-Path -LiteralPath $RequiredFile -PathType Leaf)) {
            throw "Required file was not found: $RequiredFile"
        }
    }

    try {
        Get-Content -LiteralPath $TrustPolicyPath -Raw |
            ConvertFrom-Json |
            Out-Null

        $S3PolicyTemplate = Get-Content `
            -LiteralPath $S3PolicyTemplatePath `
            -Raw

        $S3PolicyTemplate |
            ConvertFrom-Json |
            Out-Null
    }
    catch {
        throw "One or more Lab 11 policy files contain invalid JSON."
    }

    if ($S3PolicyTemplate -notmatch "BUCKET_NAME") {
        throw "The S3 policy template does not contain BUCKET_NAME."
    }

    $Identity = Invoke-AwsJson -Arguments @(
        "sts", "get-caller-identity",
        "--profile", $ProfileName,
        "--output", "json",
        "--no-cli-pager"
    )

    $AccountId = [string]$Identity.Account

    if ($AccountId -notmatch "^\d{12}$") {
        throw "A valid AWS account ID was not returned."
    }

    $BucketName = (
        "lab11-storage-recovery-$AccountId-$Region"
    ).ToLowerInvariant()

    Write-Host "[OK] AWS CLI, session, and policy files validated." `
        -ForegroundColor Green

    Write-Step -Message "Lab 08 network"

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters", "Name=tag:Name,Values=$VpcName",
        "--output", "json",
        "--no-cli-pager"
    )

    if ($VpcResult.Vpcs.Count -ne 1) {
        throw "Exactly one Lab 08 VPC named $VpcName is required."
    }

    $VpcId = [string]$VpcResult.Vpcs[0].VpcId

    $SubnetResult = Invoke-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=availability-zone,Values=$AvailabilityZone",
        "Name=tag:Name,Values=$SubnetName",
        "--output", "json",
        "--no-cli-pager"
    )

    if ($SubnetResult.Subnets.Count -ne 1) {
        throw @"
Exactly one Lab 08 subnet named $SubnetName is required in
$AvailabilityZone.
"@
    }

    $SubnetId = [string]$SubnetResult.Subnets[0].SubnetId

    Write-Host "[OK] Lab 08 VPC and subnet located." `
        -ForegroundColor Green

    Write-Step -Message "Conflict check"

    $ActiveInstanceCount = [int](Invoke-AwsText -Arguments @(
        "ec2", "describe-instances",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped",
        "--query", "length(Reservations[].Instances[])",
        "--output", "text",
        "--no-cli-pager"
    ))

    $SecurityGroupCount = [int](Invoke-AwsText -Arguments @(
        "ec2", "describe-security-groups",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$SecurityGroupName",
        "--query", "length(SecurityGroups)",
        "--output", "text",
        "--no-cli-pager"
    ))

    $RoleCount = [int](Invoke-AwsText -Arguments @(
        "iam", "list-roles",
        "--profile", $ProfileName,
        "--query", "length(Roles[?RoleName=='$RoleName'])",
        "--output", "text",
        "--no-cli-pager"
    ))

    $InstanceProfileCount = [int](Invoke-AwsText -Arguments @(
        "iam", "list-instance-profiles",
        "--profile", $ProfileName,
        "--query",
        "length(InstanceProfiles[?InstanceProfileName=='$InstanceProfileName'])",
        "--output", "text",
        "--no-cli-pager"
    ))

    $DataVolumeCount = [int](Invoke-AwsText -Arguments @(
        "ec2", "describe-volumes",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=$DataVolumeName",
        "Name=status,Values=creating,available,in-use",
        "--query", "length(Volumes)",
        "--output", "text",
        "--no-cli-pager"
    ))

    $BucketCount = [int](Invoke-AwsText -Arguments @(
        "s3api", "list-buckets",
        "--profile", $ProfileName,
        "--query", "length(Buckets[?Name=='$BucketName'])",
        "--output", "text",
        "--no-cli-pager"
    ))

    if (
        $ActiveInstanceCount -ne 0 -or
        $SecurityGroupCount -ne 0 -or
        $RoleCount -ne 0 -or
        $InstanceProfileCount -ne 0 -or
        $DataVolumeCount -ne 0 -or
        $BucketCount -ne 0
    ) {
        throw @"
One or more conflicting Lab 11 resources already exist.

Active instances:  $ActiveInstanceCount
Security Groups:   $SecurityGroupCount
IAM Roles:         $RoleCount
Instance Profiles: $InstanceProfileCount
Data volumes:      $DataVolumeCount
S3 buckets:        $BucketCount
"@
    }

    Write-Host "[OK] No conflicting Lab 11 resources found." `
        -ForegroundColor Green

    Write-Step -Message "S3 storage"

    $CreateBucketArguments = @(
        "s3api", "create-bucket",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--no-cli-pager"
    )

    if ($Region -ne "us-east-1") {
        $CreateBucketArguments += @(
            "--create-bucket-configuration",
            "LocationConstraint=$Region"
        )
    }

    Invoke-AwsText -Arguments $CreateBucketArguments |
        Out-Null

    $PublicAccessConfiguration = @{
        BlockPublicAcls = $true
        IgnorePublicAcls = $true
        BlockPublicPolicy = $true
        RestrictPublicBuckets = $true
    }

    $PublicAccessPath = New-TemporaryJsonFile `
        -Value $PublicAccessConfiguration

    Invoke-AwsText -Arguments @(
        "s3api", "put-public-access-block",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--public-access-block-configuration",
        "file://$PublicAccessPath",
        "--no-cli-pager"
    ) | Out-Null

    $EncryptionConfiguration = @{
        Rules = @(
            @{
                ApplyServerSideEncryptionByDefault = @{
                    SSEAlgorithm = "AES256"
                }
                BucketKeyEnabled = $false
            }
        )
    }

    $EncryptionPath = New-TemporaryJsonFile `
        -Value $EncryptionConfiguration

    Invoke-AwsText -Arguments @(
        "s3api", "put-bucket-encryption",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--server-side-encryption-configuration",
        "file://$EncryptionPath",
        "--no-cli-pager"
    ) | Out-Null

    $VersioningConfiguration = @{
        Status = "Enabled"
    }

    $VersioningPath = New-TemporaryJsonFile `
        -Value $VersioningConfiguration

    Invoke-AwsText -Arguments @(
        "s3api", "put-bucket-versioning",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--versioning-configuration",
        "file://$VersioningPath",
        "--no-cli-pager"
    ) | Out-Null

    $BucketTags = @{
        TagSet = @(
            @{
                Key = "Project"
                Value = "cloud-infrastructure-operations-lab"
            },
            @{
                Key = "Lab"
                Value = "11"
            },
            @{
                Key = "Service"
                Value = "storage-recovery"
            }
        )
    }

    $BucketTagsPath = New-TemporaryJsonFile -Value $BucketTags

    Invoke-AwsText -Arguments @(
        "s3api", "put-bucket-tagging",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--tagging",
        "file://$BucketTagsPath",
        "--no-cli-pager"
    ) | Out-Null

    Write-Host "[OK] Private, encrypted, and versioned S3 bucket created." `
        -ForegroundColor Green

    Write-Step -Message "IAM"

    Invoke-AwsText -Arguments @(
        "iam", "create-role",
        "--profile", $ProfileName,
        "--role-name", $RoleName,
        "--assume-role-policy-document",
        "file://$TrustPolicyPath",
        "--description",
        "Lab 11 EC2 role for Systems Manager and restricted S3 access",
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Lab,Value=11",
        "Key=Service,Value=storage-recovery",
        "--no-cli-pager"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "iam", "attach-role-policy",
        "--profile", $ProfileName,
        "--role-name", $RoleName,
        "--policy-arn", $SsmPolicyArn,
        "--no-cli-pager"
    ) | Out-Null

    $S3Policy = $S3PolicyTemplate.Replace(
        "BUCKET_NAME",
        $BucketName
    )

    $S3Policy |
        ConvertFrom-Json |
        Out-Null

    $S3PolicyPath = Join-Path `
        -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "lab11-$([guid]::NewGuid().ToString('N')).json"

    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $S3PolicyPath,
        $S3Policy,
        $Utf8WithoutBom
    )

    $TemporaryFiles.Add($S3PolicyPath)

    Invoke-AwsText -Arguments @(
        "iam", "put-role-policy",
        "--profile", $ProfileName,
        "--role-name", $RoleName,
        "--policy-name", $InlinePolicyName,
        "--policy-document", "file://$S3PolicyPath",
        "--no-cli-pager"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "iam", "create-instance-profile",
        "--profile", $ProfileName,
        "--instance-profile-name", $InstanceProfileName,
        "--tags",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Lab,Value=11",
        "Key=Service,Value=storage-recovery",
        "--no-cli-pager"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "iam", "add-role-to-instance-profile",
        "--profile", $ProfileName,
        "--instance-profile-name", $InstanceProfileName,
        "--role-name", $RoleName,
        "--no-cli-pager"
    ) | Out-Null

    Write-Host "[OK] IAM role and Instance Profile configured." `
        -ForegroundColor Green

    Write-Host "[INFO] Waiting 15 seconds for IAM propagation." `
        -ForegroundColor Yellow

    Start-Sleep -Seconds 15

    Write-Step -Message "Security Group"

    $SecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2", "create-security-group",
        "--profile", $ProfileName,
        "--region", $Region,
        "--group-name", $SecurityGroupName,
        "--description",
        "Lab 11 storage instance without inbound network access",
        "--vpc-id", $VpcId,
        "--tag-specifications",
        "ResourceType=security-group,Tags=[{Key=Name,Value=$SecurityGroupName},{Key=Project,Value=cloud-infrastructure-operations-lab},{Key=Lab,Value=11},{Key=Service,Value=storage-recovery}]",
        "--output", "json",
        "--no-cli-pager"
    )

    $SecurityGroupId = [string]$SecurityGroupResult.GroupId

    Write-Host "[OK] Security Group created without ingress rules." `
        -ForegroundColor Green

    Write-Step -Message "Amazon Linux 2023"

    $ImageId = Invoke-AwsText -Arguments @(
        "ssm", "get-parameter",
        "--profile", $ProfileName,
        "--region", $Region,
        "--name",
        "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64",
        "--query", "Parameter.Value",
        "--output", "text",
        "--no-cli-pager"
    )

    if ($ImageId -notmatch "^ami-[a-f0-9]+$") {
        throw "A valid Amazon Linux 2023 image ID was not returned."
    }

    Write-Host "[OK] Latest Amazon Linux 2023 image discovered." `
        -ForegroundColor Green

    Write-Step -Message "EC2 instance"

    $RootBlockDeviceMapping = @(
        @{
            DeviceName = "/dev/xvda"
            Ebs = @{
                VolumeSize = 8
                VolumeType = "gp3"
                Encrypted = $true
                DeleteOnTermination = $true
            }
        }
    )

    $RootBlockDevicePath = New-TemporaryJsonFile `
        -Value $RootBlockDeviceMapping

    $InstanceTags = @(
        @{
            ResourceType = "instance"
            Tags = @(
                @{
                    Key = "Name"
                    Value = $InstanceName
                },
                @{
                    Key = "Project"
                    Value = "cloud-infrastructure-operations-lab"
                },
                @{
                    Key = "Lab"
                    Value = "11"
                },
                @{
                    Key = "Service"
                    Value = "storage-recovery"
                }
            )
        },
        @{
            ResourceType = "volume"
            Tags = @(
                @{
                    Key = "Name"
                    Value = "lab11-storage-root-volume"
                },
                @{
                    Key = "Project"
                    Value = "cloud-infrastructure-operations-lab"
                },
                @{
                    Key = "Lab"
                    Value = "11"
                },
                @{
                    Key = "Service"
                    Value = "storage-recovery"
                }
            )
        }
    )

    $InstanceTagsPath = New-TemporaryJsonFile -Value $InstanceTags

    $InstanceResult = Invoke-AwsJson -Arguments @(
        "ec2", "run-instances",
        "--profile", $ProfileName,
        "--region", $Region,
        "--image-id", $ImageId,
        "--instance-type", $InstanceType,
        "--subnet-id", $SubnetId,
        "--security-group-ids", $SecurityGroupId,
        "--iam-instance-profile",
        "Name=$InstanceProfileName",
        "--metadata-options",
        "HttpTokens=required,HttpEndpoint=enabled",
        "--block-device-mappings",
        "file://$RootBlockDevicePath",
        "--tag-specifications",
        "file://$InstanceTagsPath",
        "--count", "1",
        "--output", "json",
        "--no-cli-pager"
    )

    $InstanceId = [string]$InstanceResult.Instances[0].InstanceId

    Write-Host "[OK] EC2 creation requested: $InstanceId" `
        -ForegroundColor Green

    Invoke-AwsText -Arguments @(
        "ec2", "wait", "instance-running",
        "--profile", $ProfileName,
        "--region", $Region,
        "--instance-ids", $InstanceId,
        "--no-cli-pager"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "ec2", "wait", "instance-status-ok",
        "--profile", $ProfileName,
        "--region", $Region,
        "--instance-ids", $InstanceId,
        "--no-cli-pager"
    ) | Out-Null

    Write-Host "[OK] EC2 instance passed status checks." `
        -ForegroundColor Green

    Write-Step -Message "Encrypted EBS data volume"

    $DataVolumeResult = Invoke-AwsJson -Arguments @(
        "ec2", "create-volume",
        "--profile", $ProfileName,
        "--region", $Region,
        "--availability-zone", $AvailabilityZone,
        "--size", $DataVolumeSizeGiB.ToString(),
        "--volume-type", "gp3",
        "--encrypted",
        "--tag-specifications",
        "ResourceType=volume,Tags=[{Key=Name,Value=$DataVolumeName},{Key=Project,Value=cloud-infrastructure-operations-lab},{Key=Lab,Value=11},{Key=Service,Value=storage-recovery}]",
        "--output", "json",
        "--no-cli-pager"
    )

    $DataVolumeId = [string]$DataVolumeResult.VolumeId

    Invoke-AwsText -Arguments @(
        "ec2", "wait", "volume-available",
        "--profile", $ProfileName,
        "--region", $Region,
        "--volume-ids", $DataVolumeId,
        "--no-cli-pager"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "ec2", "attach-volume",
        "--profile", $ProfileName,
        "--region", $Region,
        "--volume-id", $DataVolumeId,
        "--instance-id", $InstanceId,
        "--device", "/dev/sdf",
        "--no-cli-pager"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "ec2", "wait", "volume-in-use",
        "--profile", $ProfileName,
        "--region", $Region,
        "--volume-ids", $DataVolumeId,
        "--no-cli-pager"
    ) | Out-Null

    Write-Host "[OK] Encrypted gp3 data volume attached: $DataVolumeId" `
        -ForegroundColor Green

    Write-Step -Message "Systems Manager"

    Wait-SsmOnline -InstanceId $InstanceId

    Write-Host "[OK] Instance is online in Systems Manager." `
        -ForegroundColor Green

    $LinuxConfiguration = @'
set -euo pipefail

ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
ROOT_PARENT="$(lsblk -ndo PKNAME "$ROOT_SOURCE" | head -n 1)"

if [ -n "$ROOT_PARENT" ]; then
    ROOT_DISK="/dev/$ROOT_PARENT"
else
    ROOT_DISK="$ROOT_SOURCE"
fi

DATA_DEVICE="$(lsblk -dpno NAME,TYPE | awk '$2 == "disk" {print $1}' | grep -Fvx "$ROOT_DISK" | head -n 1)"

if [ -z "$DATA_DEVICE" ]; then
    echo "No additional EBS data device was found." >&2
    exit 1
fi

if blkid "$DATA_DEVICE" >/dev/null 2>&1; then
    echo "The data device already contains a filesystem." >&2
    exit 1
fi

mkfs.ext4 -F "$DATA_DEVICE"

DATA_UUID="$(blkid -s UUID -o value "$DATA_DEVICE")"

mkdir -p /mnt/lab11-data
mkdir -p /mnt/lab11-data/source
mkdir -p /mnt/lab11-data/restored

if ! grep -q "UUID=$DATA_UUID" /etc/fstab; then
    printf 'UUID=%s /mnt/lab11-data ext4 defaults,nofail 0 2\n' "$DATA_UUID" >> /etc/fstab
fi

mount /mnt/lab11-data

SOURCE_FILE="/mnt/lab11-data/source/lab11-storage-data.txt"
SOURCE_HASH_FILE="/mnt/lab11-data/source/lab11-storage-data.sha256"

printf '%s\n' \
    'Lab 11 - AWS storage and recovery' \
    'Persistent data stored on an encrypted EBS volume.' \
    'Backup destination: private and versioned Amazon S3 bucket.' \
    "Created at UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    > "$SOURCE_FILE"

sha256sum "$SOURCE_FILE" > "$SOURCE_HASH_FILE"

aws s3 cp \
    "$SOURCE_FILE" \
    "s3://BUCKET_NAME/backup/lab11-storage-data.txt" \
    --region AWS_REGION \
    --sse AES256 \
    --only-show-errors

aws s3api head-object \
    --bucket BUCKET_NAME \
    --key backup/lab11-storage-data.txt \
    --region AWS_REGION \
    >/dev/null

touch /var/lib/cloud/instance/lab11-storage-ready

echo "LAB11_STORAGE_CONFIGURATION_OK"
echo "Data device: $DATA_DEVICE"
echo "Mount point: /mnt/lab11-data"
echo "Bucket: BUCKET_NAME"
echo "Object key: backup/lab11-storage-data.txt"
sha256sum "$SOURCE_FILE"
'@

    $LinuxConfiguration = $LinuxConfiguration.Replace(
        "BUCKET_NAME",
        $BucketName
    ).Replace(
        "AWS_REGION",
        $Region
    )

    $CommandParameters = @{
        commands = @($LinuxConfiguration)
        executionTimeout = @("900")
    }

    $CommandParametersPath = New-TemporaryJsonFile `
        -Value $CommandParameters

    $CommandResult = Invoke-AwsJson -Arguments @(
        "ssm", "send-command",
        "--profile", $ProfileName,
        "--region", $Region,
        "--instance-ids", $InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--comment",
        "Lab 11 EBS and S3 storage configuration",
        "--parameters",
        "file://$CommandParametersPath",
        "--timeout-seconds", "900",
        "--output", "json",
        "--no-cli-pager"
    )

    $CommandId = [string]$CommandResult.Command.CommandId

    Wait-SsmCommand `
        -CommandId $CommandId `
        -InstanceId $InstanceId

    Write-Host "[OK] EBS filesystem and S3 backup configured." `
        -ForegroundColor Green

    Write-Step -Message "Initial validation"

    $InstanceDetails = Invoke-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--profile", $ProfileName,
        "--region", $Region,
        "--instance-ids", $InstanceId,
        "--output", "json",
        "--no-cli-pager"
    )

    $PrivateIpAddress = [string](
        $InstanceDetails.Reservations[0].Instances[0].PrivateIpAddress
    )

    $ObjectDetails = Invoke-AwsJson -Arguments @(
        "s3api", "head-object",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--key", $ObjectKey,
        "--output", "json",
        "--no-cli-pager"
    )

    if ([string]$ObjectDetails.ServerSideEncryption -ne "AES256") {
        throw "The S3 object does not report SSE-S3 encryption."
    }

    $VersioningStatus = Invoke-AwsText -Arguments @(
        "s3api", "get-bucket-versioning",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--query", "Status",
        "--output", "text",
        "--no-cli-pager"
    )

    if ($VersioningStatus -ne "Enabled") {
        throw "S3 bucket versioning is not enabled."
    }

    Write-Host "[OK] Encrypted backup object is available in versioned S3." `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "DEPLOYMENT COMPLETED" -ForegroundColor Green
    Write-Host "Instance ID:       $InstanceId"
    Write-Host "Private IPv4:      $PrivateIpAddress"
    Write-Host "Data volume ID:    $DataVolumeId"
    Write-Host "EBS mount point:   /mnt/lab11-data"
    Write-Host "S3 bucket:         $BucketName"
    Write-Host "S3 object:         s3://$BucketName/$ObjectKey"
    Write-Host "Next step: run restore-aws-storage-data.ps1"

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Run remove-aws-storage-recovery.ps1 if AWS resources were partially created." `
        -ForegroundColor Yellow

    exit 1
}
finally {
    foreach ($TemporaryFile in $TemporaryFiles) {
        if (Test-Path -LiteralPath $TemporaryFile) {
            Remove-Item `
                -LiteralPath $TemporaryFile `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}
