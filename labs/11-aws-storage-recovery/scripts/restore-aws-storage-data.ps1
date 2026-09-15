[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab11-storage-instance"
$BucketPrefix = "lab11-storage-recovery"
$ObjectKey = "backup/lab11-storage-data.txt"

function Invoke-AwsJson {
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
        throw "AWS CLI failed: $OutputText"
    }

    if ([string]::IsNullOrWhiteSpace($OutputText)) {
        throw "AWS CLI did not return the expected JSON."
    }

    return $OutputText | ConvertFrom-Json
}

$ParametersPath = $null

try {
    Write-Host "Lab 11 - Restore data from Amazon S3"
    Write-Host ""

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
        "$BucketPrefix-$AccountId-$Region"
    ).ToLowerInvariant()

    $Instances = Invoke-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=tag:Lab,Values=11",
        "Name=instance-state-name,Values=running",
        "--output", "json",
        "--no-cli-pager"
    )

    $RunningInstances = @(
        foreach ($Reservation in $Instances.Reservations) {
            foreach ($Instance in $Reservation.Instances) {
                $Instance
            }
        }
    )

    if ($RunningInstances.Count -ne 1) {
        throw "Exactly one running Lab 11 instance is required."
    }

    $InstanceId = [string]$RunningInstances[0].InstanceId

    $SsmInformation = Invoke-AwsJson -Arguments @(
        "ssm", "describe-instance-information",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters", "Key=InstanceIds,Values=$InstanceId",
        "--output", "json",
        "--no-cli-pager"
    )

    if (
        $SsmInformation.InstanceInformationList.Count -ne 1 -or
        $SsmInformation.InstanceInformationList[0].PingStatus -ne "Online"
    ) {
        throw "The Lab 11 instance is not online in Systems Manager."
    }

    Write-Host "[OK] Lab 11 instance located and online: $InstanceId" `
        -ForegroundColor Green

    $RestoreCommands = @'
set -euo pipefail

MOUNT_POINT="/mnt/lab11-data"
SOURCE_FILE="$MOUNT_POINT/source/lab11-storage-data.txt"
SOURCE_HASH_FILE="$MOUNT_POINT/source/lab11-storage-data.sha256"
RESTORED_DIR="$MOUNT_POINT/restored"
RESTORED_FILE="$RESTORED_DIR/lab11-storage-data.txt"

mountpoint -q "$MOUNT_POINT"
test -f "$SOURCE_FILE"
test -f "$SOURCE_HASH_FILE"
test -f /var/lib/cloud/instance/lab11-storage-ready
test -d "$RESTORED_DIR"

if [ -e "$RESTORED_FILE" ]; then
    echo "The restored file already exists; it will not be overwritten." >&2
    exit 1
fi

EXPECTED_HASH="$(awk 'NR == 1 {print $1}' "$SOURCE_HASH_FILE")"

if ! [[ "$EXPECTED_HASH" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "The source SHA-256 record is invalid." >&2
    exit 1
fi

CURRENT_SOURCE_HASH="$(sha256sum "$SOURCE_FILE" | awk '{print $1}')"

if [ "$CURRENT_SOURCE_HASH" != "$EXPECTED_HASH" ]; then
    echo "The original EBS file no longer matches its recorded hash." >&2
    exit 1
fi

TEMP_FILE="$(mktemp "$RESTORED_DIR/.lab11-restore-XXXXXXXX")"
trap 'rm -f "$TEMP_FILE"' EXIT

aws s3 cp \
    "s3://BUCKET_NAME/backup/lab11-storage-data.txt" \
    "$TEMP_FILE" \
    --region AWS_REGION \
    --only-show-errors

RESTORED_HASH="$(sha256sum "$TEMP_FILE" | awk '{print $1}')"

if [ "$RESTORED_HASH" != "$EXPECTED_HASH" ]; then
    echo "The S3 copy does not match the original SHA-256 hash." >&2
    exit 1
fi

mv -n "$TEMP_FILE" "$RESTORED_FILE"
test -f "$RESTORED_FILE"

FINAL_HASH="$(sha256sum "$RESTORED_FILE" | awk '{print $1}')"
test "$FINAL_HASH" = "$EXPECTED_HASH"

echo "LAB11_RESTORE_OK"
echo "Source: $SOURCE_FILE"
echo "Restored: $RESTORED_FILE"
echo "S3 object: s3://BUCKET_NAME/backup/lab11-storage-data.txt"
echo "SHA-256: $FINAL_HASH"
'@

    $RestoreCommands = $RestoreCommands.Replace(
        "BUCKET_NAME",
        $BucketName
    ).Replace(
        "AWS_REGION",
        $Region
    )

    $Parameters = @{
        commands = @($RestoreCommands)
        executionTimeout = @("300")
    }

    $ParametersPath = Join-Path `
        -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "lab11-restore-$([guid]::NewGuid().ToString('N')).json"

    $ParametersJson = $Parameters |
        ConvertTo-Json -Depth 5

    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $ParametersPath,
        $ParametersJson,
        $Utf8WithoutBom
    )

    $SendResult = Invoke-AwsJson -Arguments @(
        "ssm", "send-command",
        "--profile", $ProfileName,
        "--region", $Region,
        "--instance-ids", $InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--comment", "Lab 11 restore and SHA-256 verification",
        "--parameters", "file://$ParametersPath",
        "--timeout-seconds", "300",
        "--output", "json",
        "--no-cli-pager"
    )

    $CommandId = [string]$SendResult.Command.CommandId

    if ([string]::IsNullOrWhiteSpace($CommandId)) {
        throw "Systems Manager did not return a Command ID."
    }

    Write-Host "[INFO] Restore requested through Systems Manager." `
        -ForegroundColor Yellow

    $Completed = $false

    for ($Attempt = 1; $Attempt -le 60; $Attempt++) {
        Start-Sleep -Seconds 5

        try {
            $Invocation = Invoke-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--profile", $ProfileName,
                "--region", $Region,
                "--command-id", $CommandId,
                "--instance-id", $InstanceId,
                "--output", "json",
                "--no-cli-pager"
            )
        }
        catch {
            if (
                $Attempt -le 3 -and
                $_.Exception.Message -match "InvocationDoesNotExist"
            ) {
                continue
            }

            throw
        }

        if ($Invocation.Status -eq "Success") {
            $CommandOutput = [string]$Invocation.StandardOutputContent

            if ($CommandOutput -notmatch "LAB11_RESTORE_OK") {
                throw "The restore command did not return its success marker."
            }

            Write-Host $CommandOutput.Trim()
            $Completed = $true
            break
        }

        if ($Invocation.Status -in @(
            "Failed",
            "Cancelled",
            "TimedOut",
            "Cancelling"
        )) {
            throw @"
The restore command failed.

Status: $($Invocation.Status)
Output: $($Invocation.StandardOutputContent)
Error: $($Invocation.StandardErrorContent)
"@
        }
    }

    if (-not $Completed) {
        throw "The restore command did not finish within five minutes."
    }

    Write-Host ""
    Write-Host "RESTORE COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green

    Write-Host "Instance ID: $InstanceId"
    Write-Host "S3 bucket:   $BucketName"
    Write-Host "Next step: run test-aws-storage-recovery.ps1"

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" `
        -ForegroundColor Red

    exit 1
}
finally {
    if (
        $ParametersPath -and
        (Test-Path -LiteralPath $ParametersPath -PathType Leaf)
    ) {
        Remove-Item `
            -LiteralPath $ParametersPath `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
