[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [switch]$ConfirmRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectName = "cloud-infrastructure-operations-lab"
$InstanceName = "lab11-storage-instance"
$SecurityGroupName = "lab11-storage-sg"
$DataVolumeName = "lab11-storage-data-volume"
$RoleName = "lab11-ec2-storage-role"
$InstanceProfileName = "lab11-ec2-storage-instance-profile"
$InlinePolicyName = "lab11-s3-storage-access"
$SsmPolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$ObjectKey = "backup/lab11-storage-data.txt"

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
        throw "AWS CLI did not return the expected JSON."
    }

    return $OutputText | ConvertFrom-Json
}

function Assert-LabTags {
    param(
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$ResourceName
    )

    $TagMap = @{}

    foreach ($Tag in @($Tags)) {
        if ($null -ne $Tag) {
            $TagMap[[string]$Tag.Key] = [string]$Tag.Value
        }
    }

    if (
        $TagMap["Project"] -ne $ProjectName -or
        $TagMap["Lab"] -ne "11" -or
        $TagMap["Service"] -ne "storage-recovery"
    ) {
        throw "Unexpected or missing Lab 11 tags on $ResourceName."
    }
}

function Get-BucketContents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BucketName,

        [Parameter(Mandatory = $true)]
        [string]$AccountId
    )

    $VersionResult = Invoke-AwsJson -Arguments @(
        "s3api", "list-object-versions",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--expected-bucket-owner", $AccountId,
        "--output", "json",
        "--no-cli-pager"
    )

    $AllVersions = @(
        foreach ($Version in @($VersionResult.Versions)) {
            if ($null -ne $Version) {
                $Version
            }
        }

        foreach ($Marker in @($VersionResult.DeleteMarkers)) {
            if ($null -ne $Marker) {
                $Marker
            }
        }
    )

    foreach ($Version in $AllVersions) {
        if ([string]$Version.Key -cne $ObjectKey) {
            throw "Unexpected object or version in Lab 11 bucket: $($Version.Key)"
        }

        if ([string]::IsNullOrWhiteSpace([string]$Version.VersionId)) {
            throw "An S3 object version has no Version ID."
        }
    }

    $VisibleObjects = Invoke-AwsJson -Arguments @(
        "s3api", "list-objects-v2",
        "--profile", $ProfileName,
        "--region", $Region,
        "--bucket", $BucketName,
        "--expected-bucket-owner", $AccountId,
        "--output", "json",
        "--no-cli-pager"
    )

    foreach ($Object in @($VisibleObjects.Contents)) {
        if (
            $null -ne $Object -and
            [string]$Object.Key -cne $ObjectKey
        ) {
            throw "Unexpected visible object in Lab 11 bucket: $($Object.Key)"
        }
    }

    if ($AllVersions.Count -gt 20) {
        throw "More than 20 object versions were found; review the bucket manually."
    }

    return ,$AllVersions
}

try {
    Write-Host "Lab 11 - Controlled cleanup"
    Write-Host ""

    if (-not $ConfirmRemoval) {
        throw "Specify -ConfirmRemoval to authorize Lab 11 cleanup."
    }

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
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

    Write-Host "=== Shared Lab 08 network ===" `
        -ForegroundColor Cyan

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=lab08-application-vpc",
        "--output", "json",
        "--no-cli-pager"
    )

    if (@($VpcResult.Vpcs).Count -ne 1) {
        throw "Exactly one Lab 08 VPC must be present."
    }

    $VpcId = [string]$VpcResult.Vpcs[0].VpcId

    $SubnetResult = Invoke-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=lab08-public-subnet-a",
        "--output", "json",
        "--no-cli-pager"
    )

    if (@($SubnetResult.Subnets).Count -ne 1) {
        throw "Exactly one Lab 08 subnet must be present in the Lab 08 VPC."
    }

    Write-Host "[OK] Lab 08 VPC and subnet identified; neither will be removed." `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "=== Lab 11 preflight ===" `
        -ForegroundColor Cyan

    $InstanceResult = Invoke-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped",
        "--output", "json",
        "--no-cli-pager"
    )

    $ActiveInstances = @(
        foreach ($Reservation in @($InstanceResult.Reservations)) {
            if ($null -ne $Reservation) {
                foreach ($Instance in @($Reservation.Instances)) {
                    if ($null -ne $Instance) {
                        $Instance
                    }
                }
            }
        }
    )

    if ($ActiveInstances.Count -gt 1) {
        throw "More than one active Lab 11 instance was found."
    }

    $InstanceId = $null

    if ($ActiveInstances.Count -eq 1) {
        $Instance = $ActiveInstances[0]

        Assert-LabTags `
            -Tags $Instance.Tags `
            -ResourceName $InstanceName

        if ([string]$Instance.SubnetId -ne [string]$SubnetResult.Subnets[0].SubnetId) {
            throw "The Lab 11 instance is not in the expected Lab 08 subnet."
        }

        $InstanceId = [string]$Instance.InstanceId
    }

    $GroupResult = Invoke-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$SecurityGroupName",
        "--output", "json",
        "--no-cli-pager"
    )

    $Groups = @($GroupResult.SecurityGroups)

    if ($Groups.Count -gt 1) {
        throw "More than one Lab 11 Security Group was found."
    }

    $SecurityGroupId = $null

    if ($Groups.Count -eq 1) {
        Assert-LabTags `
            -Tags $Groups[0].Tags `
            -ResourceName $SecurityGroupName

        $SecurityGroupId = [string]$Groups[0].GroupId
    }

    $VolumeResult = Invoke-AwsJson -Arguments @(
        "ec2", "describe-volumes",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=$DataVolumeName",
        "Name=status,Values=creating,available,in-use",
        "--output", "json",
        "--no-cli-pager"
    )

    $Volumes = @($VolumeResult.Volumes)

    if ($Volumes.Count -gt 1) {
        throw "More than one Lab 11 data volume was found."
    }

    $DataVolumeId = $null

    if ($Volumes.Count -eq 1) {
        Assert-LabTags `
            -Tags $Volumes[0].Tags `
            -ResourceName $DataVolumeName

        $DataVolumeId = [string]$Volumes[0].VolumeId

        foreach ($Attachment in @($Volumes[0].Attachments)) {
            if (
                $null -ne $Attachment -and
                (
                    -not $InstanceId -or
                    [string]$Attachment.InstanceId -ne $InstanceId
                )
            ) {
                throw "The Lab 11 data volume is attached to an unexpected instance."
            }
        }
    }

    $RoleList = Invoke-AwsJson -Arguments @(
        "iam", "list-roles",
        "--profile", $ProfileName,
        "--output", "json",
        "--no-cli-pager"
    )

    $MatchingRoles = @(
        $RoleList.Roles |
            Where-Object { $_.RoleName -eq $RoleName }
    )

    if ($MatchingRoles.Count -gt 1) {
        throw "More than one matching Lab 11 IAM Role was found."
    }

    $RoleExists = $MatchingRoles.Count -eq 1

    if ($RoleExists) {
        $RoleDetails = Invoke-AwsJson -Arguments @(
            "iam", "get-role",
            "--profile", $ProfileName,
            "--role-name", $RoleName,
            "--output", "json",
            "--no-cli-pager"
        )

        Assert-LabTags `
            -Tags $RoleDetails.Role.Tags `
            -ResourceName $RoleName

        $AttachedPolicies = Invoke-AwsJson -Arguments @(
            "iam", "list-attached-role-policies",
            "--profile", $ProfileName,
            "--role-name", $RoleName,
            "--output", "json",
            "--no-cli-pager"
        )

        foreach ($Policy in @($AttachedPolicies.AttachedPolicies)) {
            if (
                $null -ne $Policy -and
                [string]$Policy.PolicyArn -ne $SsmPolicyArn
            ) {
                throw "An unexpected managed policy is attached to $RoleName."
            }
        }

        $InlinePolicies = Invoke-AwsJson -Arguments @(
            "iam", "list-role-policies",
            "--profile", $ProfileName,
            "--role-name", $RoleName,
            "--output", "json",
            "--no-cli-pager"
        )

        foreach ($PolicyName in @($InlinePolicies.PolicyNames)) {
            if (
                $null -ne $PolicyName -and
                [string]$PolicyName -ne $InlinePolicyName
            ) {
                throw "An unexpected inline policy is attached to $RoleName."
            }
        }
    }

    $ProfileList = Invoke-AwsJson -Arguments @(
        "iam", "list-instance-profiles",
        "--profile", $ProfileName,
        "--output", "json",
        "--no-cli-pager"
    )

    $MatchingProfiles = @(
        $ProfileList.InstanceProfiles |
            Where-Object {
                $_.InstanceProfileName -eq $InstanceProfileName
            }
    )

    if ($MatchingProfiles.Count -gt 1) {
        throw "More than one matching Lab 11 Instance Profile was found."
    }

    $ProfileExists = $MatchingProfiles.Count -eq 1
    $ProfileHasRole = $false

    if ($ProfileExists) {
        $ProfileDetails = Invoke-AwsJson -Arguments @(
            "iam", "get-instance-profile",
            "--profile", $ProfileName,
            "--instance-profile-name", $InstanceProfileName,
            "--output", "json",
            "--no-cli-pager"
        )

        Assert-LabTags `
            -Tags $ProfileDetails.InstanceProfile.Tags `
            -ResourceName $InstanceProfileName

        foreach ($ProfileRole in @($ProfileDetails.InstanceProfile.Roles)) {
            if ($null -ne $ProfileRole) {
                if ([string]$ProfileRole.RoleName -ne $RoleName) {
                    throw "The Lab 11 Instance Profile contains an unexpected role."
                }

                $ProfileHasRole = $true
            }
        }
    }

    if ($RoleExists) {
        $RoleProfiles = Invoke-AwsJson -Arguments @(
            "iam", "list-instance-profiles-for-role",
            "--profile", $ProfileName,
            "--role-name", $RoleName,
            "--output", "json",
            "--no-cli-pager"
        )

        foreach ($RoleProfile in @($RoleProfiles.InstanceProfiles)) {
            if (
                $null -ne $RoleProfile -and
                [string]$RoleProfile.InstanceProfileName -ne $InstanceProfileName
            ) {
                throw "The Lab 11 role belongs to an unexpected Instance Profile."
            }
        }
    }

    $BucketList = Invoke-AwsJson -Arguments @(
        "s3api", "list-buckets",
        "--profile", $ProfileName,
        "--output", "json",
        "--no-cli-pager"
    )

    $MatchingBuckets = @(
        $BucketList.Buckets |
            Where-Object { $_.Name -eq $BucketName }
    )

    if ($MatchingBuckets.Count -gt 1) {
        throw "More than one matching Lab 11 S3 bucket was found."
    }

    $BucketExists = $MatchingBuckets.Count -eq 1
    $Versions = @()

    if ($BucketExists) {
        $BucketTags = Invoke-AwsJson -Arguments @(
            "s3api", "get-bucket-tagging",
            "--profile", $ProfileName,
            "--region", $Region,
            "--bucket", $BucketName,
            "--expected-bucket-owner", $AccountId,
            "--output", "json",
            "--no-cli-pager"
        )

        Assert-LabTags `
            -Tags $BucketTags.TagSet `
            -ResourceName $BucketName

        $Versions = @(
            Get-BucketContents `
                -BucketName $BucketName `
                -AccountId $AccountId
        )
    }

    Write-Host "Active instance:       $($ActiveInstances.Count)"
    Write-Host "Security Group:        $($Groups.Count)"
    Write-Host "Data volume:           $($Volumes.Count)"
    Write-Host "IAM Role:              $RoleExists"
    Write-Host "Instance Profile:      $ProfileExists"
    Write-Host "S3 bucket:             $BucketExists"
    Write-Host "S3 versions/markers:   $($Versions.Count)"
    Write-Host ""

    Write-Host "[OK] Resource identities and tags verified." `
        -ForegroundColor Green

    if ($InstanceId) {
        Write-Host ""
        Write-Host "=== EC2 instance ===" `
            -ForegroundColor Cyan

        Invoke-AwsText -Arguments @(
            "ec2", "terminate-instances",
            "--profile", $ProfileName,
            "--region", $Region,
            "--instance-ids", $InstanceId,
            "--no-cli-pager"
        ) | Out-Null

        Invoke-AwsText -Arguments @(
            "ec2", "wait", "instance-terminated",
            "--profile", $ProfileName,
            "--region", $Region,
            "--instance-ids", $InstanceId,
            "--no-cli-pager"
        ) | Out-Null

        Write-Host "[OK] Lab 11 instance terminated." `
            -ForegroundColor Green
    }

    if ($DataVolumeId) {
        Write-Host ""
        Write-Host "=== EBS data volume ===" `
            -ForegroundColor Cyan

        Invoke-AwsText -Arguments @(
            "ec2", "wait", "volume-available",
            "--profile", $ProfileName,
            "--region", $Region,
            "--volume-ids", $DataVolumeId,
            "--no-cli-pager"
        ) | Out-Null

        Invoke-AwsText -Arguments @(
            "ec2", "delete-volume",
            "--profile", $ProfileName,
            "--region", $Region,
            "--volume-id", $DataVolumeId,
            "--no-cli-pager"
        ) | Out-Null

        Write-Host "[OK] Lab 11 data volume deleted." `
            -ForegroundColor Green
    }

    if ($SecurityGroupId) {
        Write-Host ""
        Write-Host "=== Security Group ===" `
            -ForegroundColor Cyan

        $GroupDeleted = $false

        for ($Attempt = 1; $Attempt -le 12; $Attempt++) {
            $PreviousPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"

            try {
                $DeleteOutput = & aws ec2 delete-security-group `
                    --profile $ProfileName `
                    --region $Region `
                    --group-id $SecurityGroupId `
                    --no-cli-pager 2>&1

                $DeleteExitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $PreviousPreference
            }

            if ($DeleteExitCode -eq 0) {
                $GroupDeleted = $true
                break
            }

            $DeleteError = ($DeleteOutput | Out-String).Trim()

            if ($DeleteError -notmatch "DependencyViolation") {
                throw "Security Group deletion failed: $DeleteError"
            }

            if ($Attempt -lt 12) {
                Start-Sleep -Seconds 5
            }
        }

        if (-not $GroupDeleted) {
            throw "The Lab 11 Security Group is still in use."
        }

        Write-Host "[OK] Lab 11 Security Group deleted." `
            -ForegroundColor Green
    }

    if ($ProfileExists -or $RoleExists) {
        Write-Host ""
        Write-Host "=== IAM ===" `
            -ForegroundColor Cyan

        if ($ProfileExists -and $ProfileHasRole) {
            Invoke-AwsText -Arguments @(
                "iam", "remove-role-from-instance-profile",
                "--profile", $ProfileName,
                "--instance-profile-name", $InstanceProfileName,
                "--role-name", $RoleName,
                "--no-cli-pager"
            ) | Out-Null
        }

        if ($ProfileExists) {
            Invoke-AwsText -Arguments @(
                "iam", "delete-instance-profile",
                "--profile", $ProfileName,
                "--instance-profile-name", $InstanceProfileName,
                "--no-cli-pager"
            ) | Out-Null
        }

        if ($RoleExists) {
            foreach ($PolicyName in @($InlinePolicies.PolicyNames)) {
                if ($null -ne $PolicyName) {
                    Invoke-AwsText -Arguments @(
                        "iam", "delete-role-policy",
                        "--profile", $ProfileName,
                        "--role-name", $RoleName,
                        "--policy-name", [string]$PolicyName,
                        "--no-cli-pager"
                    ) | Out-Null
                }
            }

            foreach ($Policy in @($AttachedPolicies.AttachedPolicies)) {
                if ($null -ne $Policy) {
                    Invoke-AwsText -Arguments @(
                        "iam", "detach-role-policy",
                        "--profile", $ProfileName,
                        "--role-name", $RoleName,
                        "--policy-arn", [string]$Policy.PolicyArn,
                        "--no-cli-pager"
                    ) | Out-Null
                }
            }

            Invoke-AwsText -Arguments @(
                "iam", "delete-role",
                "--profile", $ProfileName,
                "--role-name", $RoleName,
                "--no-cli-pager"
            ) | Out-Null
        }

        Write-Host "[OK] Lab 11 IAM resources removed." `
            -ForegroundColor Green
    }

    if ($BucketExists) {
        Write-Host ""
        Write-Host "=== S3 bucket ===" `
            -ForegroundColor Cyan

        # Recheck immediately before permanent S3 deletion.
        $Versions = @(
            Get-BucketContents `
                -BucketName $BucketName `
                -AccountId $AccountId
        )

        foreach ($Version in $Versions) {
            Invoke-AwsText -Arguments @(
                "s3api", "delete-object",
                "--profile", $ProfileName,
                "--region", $Region,
                "--bucket", $BucketName,
                "--key", $ObjectKey,
                "--version-id", [string]$Version.VersionId,
                "--expected-bucket-owner", $AccountId,
                "--no-cli-pager"
            ) | Out-Null
        }

        $RemainingVersions = @(
            Get-BucketContents `
                -BucketName $BucketName `
                -AccountId $AccountId
        )

        if ($RemainingVersions.Count -ne 0) {
            throw "S3 object versions remain; the bucket was not deleted."
        }

        Invoke-AwsText -Arguments @(
            "s3api", "delete-bucket",
            "--profile", $ProfileName,
            "--region", $Region,
            "--bucket", $BucketName,
            "--expected-bucket-owner", $AccountId,
            "--no-cli-pager"
        ) | Out-Null

        Write-Host "[OK] Lab 11 bucket and test-object versions deleted." `
            -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "CLEANUP COMPLETED" `
        -ForegroundColor Green

    Write-Host "[OK] Lab 08 VPC and subnet were not modified." `
        -ForegroundColor Green

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host "Review the remaining resources before running cleanup again." `
        -ForegroundColor Yellow

    exit 1
}
