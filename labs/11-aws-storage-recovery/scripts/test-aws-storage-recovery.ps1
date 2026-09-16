[CmdletBinding()]
param([string]$ProfileName = "cloud-operations-lab", [string]$Region = "us-east-1")
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-AwsJson {
    param([string[]]$Arguments)
    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Result = & aws @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $Previous }
    if ($ExitCode -ne 0) { throw "AWS CLI: $(($Result | Out-String).Trim())" }
    return ConvertFrom-Json -InputObject (($Result | Out-String).Trim())
}
function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
    Write-Host "[OK] $Message" -ForegroundColor Green
}

try {
    $Identity = Invoke-AwsJson -Arguments @("sts", "get-caller-identity", "--profile", $ProfileName, "--output", "json", "--no-cli-pager")
    $AccountId = [string]$Identity.Account
    Assert-Condition ($AccountId -match '^\d{12}$') "Valid account ID."
    $BucketName = "lab11-storage-recovery-$AccountId-$Region"

    $Response = Invoke-AwsJson -Arguments @(
        "ec2", "describe-instances", "--profile", $ProfileName, "--region", $Region,
        "--filters", "Name=tag:Name,Values=lab11-storage-instance", "Name=tag:Lab,Values=11",
        "Name=instance-state-name,Values=running", "--output", "json", "--no-cli-pager"
    )
    $Instances = @(
        foreach ($Reservation in @($Response.Reservations)) {
            foreach ($Instance in @($Reservation.Instances)) { $Instance }
        }
    )
    Assert-Condition ($Instances.Count -eq 1) "Exactly one running Lab 11 instance."
    $Instance = $Instances[0]
    $InstanceId = [string]$Instance.InstanceId
    Assert-Condition ($null -eq $Instance.PSObject.Properties["KeyName"]) "No SSH key pair."
    Assert-Condition ($Instance.MetadataOptions.HttpTokens -eq "required") "IMDSv2 required."
    $Groups = @($Instance.SecurityGroups)
    Assert-Condition ($Groups.Count -eq 1) "One security group attached."
    $GroupResult = Invoke-AwsJson -Arguments @(
        "ec2", "describe-security-groups", "--profile", $ProfileName, "--region", $Region,
        "--group-ids", [string]$Groups[0].GroupId, "--output", "json", "--no-cli-pager"
    )
    Assert-Condition ($GroupResult.SecurityGroups[0].GroupName -eq "lab11-storage-sg") "Lab 11 security group."
    Assert-Condition (@($GroupResult.SecurityGroups[0].IpPermissions).Count -eq 0) "No ingress rules."

    $Ssm = Invoke-AwsJson -Arguments @(
        "ssm", "describe-instance-information", "--profile", $ProfileName, "--region", $Region,
        "--filters", "Key=InstanceIds,Values=$InstanceId", "--output", "json", "--no-cli-pager"
    )
    Assert-Condition (@($Ssm.InstanceInformationList | Where-Object { $_.PingStatus -eq "Online" }).Count -eq 1) "Instance online in SSM."

    $Result = Invoke-AwsJson -Arguments @(
        "ec2", "describe-volumes", "--profile", $ProfileName, "--region", $Region,
        "--filters", "Name=tag:Name,Values=lab11-storage-data-volume", "Name=tag:Lab,Values=11",
        "--output", "json", "--no-cli-pager"
    )
    $Volumes = @($Result.Volumes)
    Assert-Condition ($Volumes.Count -eq 1) "One Lab 11 data volume."
    $Volume = $Volumes[0]
    Assert-Condition ($Volume.Encrypted -and $Volume.VolumeType -eq "gp3") "Encrypted gp3 volume."
    Assert-Condition (@($Volume.Attachments | Where-Object { $_.InstanceId -eq $InstanceId -and $_.State -eq "attached" }).Count -eq 1) "Data volume attached."

    $Public = Invoke-AwsJson -Arguments @(
        "s3api", "get-public-access-block", "--profile", $ProfileName, "--bucket", $BucketName,
        "--output", "json", "--no-cli-pager"
    )
    $Block = $Public.PublicAccessBlockConfiguration
    Assert-Condition (
        $Block.BlockPublicAcls -and $Block.IgnorePublicAcls -and
        $Block.BlockPublicPolicy -and $Block.RestrictPublicBuckets
    ) "S3 public access blocked."
    $Encryption = Invoke-AwsJson -Arguments @(
        "s3api", "get-bucket-encryption", "--profile", $ProfileName, "--bucket", $BucketName,
        "--output", "json", "--no-cli-pager"
    )
    Assert-Condition (
        @($Encryption.ServerSideEncryptionConfiguration.Rules)[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm -eq "AES256"
    ) "Default S3 encryption enabled."
    $Versioning = Invoke-AwsJson -Arguments @(
        "s3api", "get-bucket-versioning", "--profile", $ProfileName, "--bucket", $BucketName,
        "--output", "json", "--no-cli-pager"
    )
    Assert-Condition ($Versioning.Status -eq "Enabled") "Bucket versioning enabled."
    $Object = Invoke-AwsJson -Arguments @(
        "s3api", "head-object", "--profile", $ProfileName, "--bucket", $BucketName,
        "--key", "backup/lab11-storage-data.txt", "--output", "json", "--no-cli-pager"
    )
    Assert-Condition ($Object.ContentLength -gt 0 -and $Object.ServerSideEncryption -eq "AES256") "Encrypted backup object present."
    Write-Host "VALIDATION COMPLETED (infrastructure and backup)." -ForegroundColor Green
    Write-Host "Run restore-aws-storage-data.ps1 for SHA-256 comparison."
    exit 0
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

