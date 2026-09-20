[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [ValidateRange(80, 87)]
    [int]$TargetUsagePercent = 82,

    [ValidateRange(81, 88)]
    [int]$SafetyUsageMaximumPercent = 88,

    [ValidateRange(8, 256)]
    [int]$ChunkSizeMiB = 64,

    [switch]$ConfirmDiskPressure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab14-disk-utilization-instance"
$DataVolumeName = "lab14-disk-utilization-data"
$MountPoint = "/var/log/lab14"
$GeneratedDirectory = "$MountPoint/generated"

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

function Write-Success {
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

function Assert-RequiredTags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceDescription,

        [AllowNull()]
        [object[]]$Tags
    )

    foreach ($key in $ExpectedTags.Keys) {
        $actualValue = Get-TagValue -Tags $Tags -Key $key
        $expectedValue = [string]$ExpectedTags[$key]

        if ($actualValue -ne $expectedValue) {
            throw (
                "$ResourceDescription does not have the expected " +
                "tag $key=$expectedValue."
            )
        }
    }
}

function Wait-SsmCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandId,

        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [int]$MaximumAttempts = 120,

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
        [string]$ScriptContent,

        [Parameter(Mandatory = $true)]
        [string]$Comment
    )

    $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes(
        $ScriptContent
    )

    $encodedScript = [Convert]::ToBase64String($scriptBytes)

    $parameters = @{
        commands = @(
            "echo '$encodedScript' | base64 --decode | bash"
        )
    } | ConvertTo-Json -Compress

    $parametersPath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        (
            "lab14-pressure-ssm-{0}.json" -f
            [guid]::NewGuid().ToString("N")
        )

    try {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new(
            $false
        )

        [System.IO.File]::WriteAllText(
            $parametersPath,
            $parameters,
            $utf8WithoutBom
        )

        $parametersFileArgument = "file://$parametersPath"

        $response = ConvertFrom-AwsJson -Arguments @(
            "ssm", "send-command",
            "--instance-ids", $InstanceId,
            "--document-name", "AWS-RunShellScript",
            "--comment", $Comment,
            "--parameters", $parametersFileArgument,
            "--timeout-seconds", "900"
        )
    }
    finally {
        if (
            Test-Path `
                -LiteralPath $parametersPath `
                -PathType Leaf
        ) {
            Remove-Item `
                -LiteralPath $parametersPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    $commandId = [string]$response.Command.CommandId

    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw (
            "Systems Manager did not return a command " +
            "identifier."
        )
    }

    Write-Success "SSM command submitted: $commandId"

    $invocation = Wait-SsmCommand `
        -CommandId $commandId `
        -InstanceId $InstanceId

    $standardOutput = (
        [string]$invocation.StandardOutputContent
    ).Replace("`r", "")

    $standardError = (
        [string]$invocation.StandardErrorContent
    ).Replace("`r", "")

    if (
        -not [string]::IsNullOrWhiteSpace(
            $standardOutput
        )
    ) {
        Write-Host ""
        Write-Host "Standard output:"
        Write-Host $standardOutput
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $standardError
        )
    ) {
        Write-Host ""
        Write-Host "Standard error:"
        Write-Host $standardError
    }

    if ($invocation.Status -ne "Success") {
        throw (
            "SSM command $commandId finished with status " +
            "$($invocation.Status)."
        )
    }

    return [pscustomobject]@{
        CommandId      = $commandId
        StandardOutput = $standardOutput
        StandardError  = $standardError
    }
}

Write-Host "Lab 14 - Controlled disk pressure"

try {
    if (-not $ConfirmDiskPressure.IsPresent) {
        throw (
            "Controlled disk pressure was not confirmed. " +
            "Run the script with -ConfirmDiskPressure."
        )
    }

    if (
        $TargetUsagePercent -ge
        $SafetyUsageMaximumPercent
    ) {
        throw (
            "TargetUsagePercent must be lower than " +
            "SafetyUsageMaximumPercent."
        )
    }

    Write-Step "Prerequisites and identity"

    if (
        -not (
            Get-Command aws `
                -ErrorAction SilentlyContinue
        )
    ) {
        throw "AWS CLI was not found."
    }

    $identity = ConvertFrom-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$identity.Account
        ) -or
        [string]::IsNullOrWhiteSpace(
            [string]$identity.Arn
        )
    ) {
        throw "AWS identity is incomplete."
    }

    Write-Success "AWS session is authenticated."

    Write-Step "Lab 14 EC2 instance"

    $instanceResponse = ConvertFrom-AwsJson `
        -Arguments @(
            "ec2",
            "describe-instances",
            "--filters",
            "Name=tag:Name,Values=$InstanceName",
            "Name=tag:Lab,Values=14",
            (
                "Name=instance-state-name," +
                "Values=pending,running,stopping,stopped"
            )
        )

    $instances = @(
        $instanceResponse.Reservations |
            ForEach-Object {
                $_.Instances
            }
    )

    if ($instances.Count -ne 1) {
        throw (
            "Expected exactly one active Lab 14 EC2 " +
            "instance; found $($instances.Count)."
        )
    }

    $instance = $instances[0]
    $instanceId = [string]$instance.InstanceId

    Assert-RequiredTags `
        -ResourceDescription (
            "EC2 instance $instanceId"
        ) `
        -Tags $instance.Tags

    if ($instance.State.Name -ne "running") {
        throw (
            "EC2 instance $instanceId is not running."
        )
    }

    Write-Success (
        "Ownership validated: EC2 instance $instanceId"
    )

    Write-Success "EC2 instance is running."

    Write-Step "Dedicated EBS volume"

    $volumeResponse = ConvertFrom-AwsJson `
        -Arguments @(
            "ec2",
            "describe-volumes",
            "--filters",
            "Name=tag:Name,Values=$DataVolumeName",
            "Name=tag:Lab,Values=14",
            "Name=status,Values=in-use"
        )

    $volumes = @($volumeResponse.Volumes)

    if ($volumes.Count -ne 1) {
        throw (
            "Expected exactly one attached Lab 14 " +
            "data volume; found $($volumes.Count)."
        )
    }

    $volume = $volumes[0]
    $volumeId = [string]$volume.VolumeId

    Assert-RequiredTags `
        -ResourceDescription (
            "EBS volume $volumeId"
        ) `
        -Tags $volume.Tags

    $attachment = @($volume.Attachments) |
        Where-Object {
            $_.InstanceId -eq $instanceId -and
            $_.State -eq "attached"
        } |
        Select-Object -First 1

    if ($null -eq $attachment) {
        throw (
            "EBS volume $volumeId is not attached to " +
            "EC2 instance $instanceId."
        )
    }

    Write-Success (
        "Ownership validated: EBS volume $volumeId"
    )

    Write-Success (
        "Dedicated EBS volume is attached to the " +
        "Lab 14 instance."
    )

    Write-Step "Systems Manager"

    $managedInstances = ConvertFrom-AwsJson `
        -Arguments @(
            "ssm",
            "describe-instance-information",
            "--filters",
            "Key=InstanceIds,Values=$instanceId"
        )

    $managedInstance = @(
        $managedInstances.InstanceInformationList
    ) |
        Select-Object -First 1

    if (
        $null -eq $managedInstance -or
        $managedInstance.PingStatus -ne "Online"
    ) {
        throw (
            "EC2 instance $instanceId is not online " +
            "in Systems Manager."
        )
    }

    Write-Success (
        "EC2 instance is online in Systems Manager."
    )

    Write-Step "Controlled disk pressure"

    $remoteScript = @'
#!/bin/bash
set -euo pipefail

MOUNT_POINT='__MOUNT_POINT__'
GENERATED_DIR='__GENERATED_DIRECTORY__'
EXPECTED_VOLUME_ID='__VOLUME_ID__'
TARGET_PERCENT=__TARGET_PERCENT__
SAFETY_PERCENT=__SAFETY_PERCENT__
CHUNK_MIB=__CHUNK_MIB__

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

mountpoint -q "$MOUNT_POINT" ||
    fail "$MOUNT_POINT is not mounted."

SOURCE=$(findmnt -rn -o SOURCE --target "$MOUNT_POINT")
FSTYPE=$(findmnt -rn -o FSTYPE --target "$MOUNT_POINT")
ROOT_SOURCE=$(findmnt -rn -o SOURCE --target /)

[ -n "$SOURCE" ] ||
    fail "The mount source was not identified."

[ "$FSTYPE" = "ext4" ] ||
    fail "The data filesystem is not ext4."

[ "$SOURCE" != "$ROOT_SOURCE" ] ||
    fail "The mount point resolves to the root filesystem."

[ -d "$GENERATED_DIR" ] ||
    fail "The controlled generation directory does not exist."

[ -f "$MOUNT_POINT/.lab14-volume" ] ||
    fail "The Lab 14 volume marker does not exist."

MARKER=$(tr -d '[:space:]' < "$MOUNT_POINT/.lab14-volume")

[ "$MARKER" = "$EXPECTED_VOLUME_ID" ] ||
    fail "The volume marker does not match the attached EBS volume."

read -r TOTAL_BYTES USED_BYTES AVAILABLE_BYTES CURRENT_PERCENT <<EOF
$(df -B1 --output=size,used,avail,pcent "$MOUNT_POINT" | awk 'NR==2 {gsub(/%/, "", $4); print $1, $2, $3, $4}')
EOF

for VALUE in \
    "$TOTAL_BYTES" \
    "$USED_BYTES" \
    "$AVAILABLE_BYTES" \
    "$CURRENT_PERCENT"
do
    [[ "$VALUE" =~ ^[0-9]+$ ]] ||
        fail "Filesystem capacity data is invalid."
done

[ "$CURRENT_PERCENT" -lt "$SAFETY_PERCENT" ] ||
    fail "Current utilization is already at or above the safety limit."

TARGET_BYTES=$(( (TOTAL_BYTES * TARGET_PERCENT + 99) / 100 ))
SAFETY_BYTES=$(( (TOTAL_BYTES * SAFETY_PERCENT) / 100 ))
BYTES_REQUIRED=$(( TARGET_BYTES - USED_BYTES ))
SAFETY_MARGIN=$(( SAFETY_BYTES - USED_BYTES ))
CHUNK_BYTES=$(( CHUNK_MIB * 1024 * 1024 ))
MAX_FILE_BYTES=$(( (BYTES_REQUIRED + 2) / 3 ))

echo "BEFORE_PERCENT=$CURRENT_PERCENT"
echo "TOTAL_BYTES=$TOTAL_BYTES"
echo "USED_BYTES_BEFORE=$USED_BYTES"
echo "TARGET_PERCENT=$TARGET_PERCENT"
echo "SAFETY_PERCENT=$SAFETY_PERCENT"
echo "BYTES_REQUIRED=$BYTES_REQUIRED"
echo "SAFETY_MARGIN=$SAFETY_MARGIN"

if [ "$BYTES_REQUIRED" -le 0 ]; then
    echo "[OK] Disk utilization is already at or above the requested target."
    echo "AFTER_PERCENT=$CURRENT_PERCENT"
    echo "FILES_CREATED=0"
    exit 0
fi

[ "$SAFETY_MARGIN" -gt 0 ] ||
    fail "No safety margin is available."

[ "$BYTES_REQUIRED" -lt "$SAFETY_MARGIN" ] ||
    fail "The requested target would reach the safety limit."

RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)
FILE_INDEX=0
FILES_CREATED=0

while [ "$USED_BYTES" -lt "$TARGET_BYTES" ]; do
    REMAINING_TO_TARGET=$(( TARGET_BYTES - USED_BYTES ))
    REMAINING_TO_SAFETY=$(( SAFETY_BYTES - USED_BYTES ))
    WRITE_BYTES=$CHUNK_BYTES

    if [ "$WRITE_BYTES" -gt "$MAX_FILE_BYTES" ]; then
        WRITE_BYTES=$MAX_FILE_BYTES
    fi

    if [ "$WRITE_BYTES" -gt "$REMAINING_TO_TARGET" ]; then
        WRITE_BYTES=$REMAINING_TO_TARGET
    fi

    if [ "$WRITE_BYTES" -ge "$REMAINING_TO_SAFETY" ]; then
        fail "The next controlled write would reach the safety limit."
    fi

    [ "$WRITE_BYTES" -gt 0 ] ||
        break

    FILE_INDEX=$(( FILE_INDEX + 1 ))

    PRESSURE_FILE=$(
        printf \
            '%s/lab14-pressure-%s-%03d.log' \
            "$GENERATED_DIR" \
            "$RUN_ID" \
            "$FILE_INDEX"
    )

    head -c "$WRITE_BYTES" /dev/zero > "$PRESSURE_FILE"
    sync -f "$PRESSURE_FILE"
    chmod 0640 "$PRESSURE_FILE"
    chown root:root "$PRESSURE_FILE"

    FILES_CREATED=$(( FILES_CREATED + 1 ))

    read -r USED_BYTES CURRENT_PERCENT <<EOF
$(df -B1 --output=used,pcent "$MOUNT_POINT" | awk 'NR==2 {gsub(/%/, "", $2); print $1, $2}')
EOF

    [ "$CURRENT_PERCENT" -lt "$SAFETY_PERCENT" ] ||
        fail "The safety limit was reached unexpectedly."
done

read -r USED_BYTES_AFTER AVAILABLE_BYTES_AFTER AFTER_PERCENT <<EOF
$(df -B1 --output=used,avail,pcent "$MOUNT_POINT" | awk 'NR==2 {gsub(/%/, "", $3); print $1, $2, $3}')
EOF

[ "$USED_BYTES_AFTER" -ge "$TARGET_BYTES" ] ||
    fail "The requested utilization target was not reached."

[ "$AFTER_PERCENT" -lt "$SAFETY_PERCENT" ] ||
    fail "Final utilization is not below the safety limit."

[ "$FILES_CREATED" -ge 2 ] ||
    fail "Fewer than two controlled files were created."

sync

echo "AFTER_PERCENT=$AFTER_PERCENT"
echo "USED_BYTES_AFTER=$USED_BYTES_AFTER"
echo "AVAILABLE_BYTES_AFTER=$AVAILABLE_BYTES_AFTER"
echo "FILES_CREATED=$FILES_CREATED"
echo "[OK] Controlled disk pressure completed."

df -hT "$MOUNT_POINT"

ls -lh \
    "$GENERATED_DIR"/lab14-pressure-"$RUN_ID"-*.log
'@

    $remoteScript = $remoteScript.Replace(
        "__MOUNT_POINT__",
        $MountPoint
    ).Replace(
        "__GENERATED_DIRECTORY__",
        $GeneratedDirectory
    ).Replace(
        "__VOLUME_ID__",
        $volumeId
    ).Replace(
        "__TARGET_PERCENT__",
        [string]$TargetUsagePercent
    ).Replace(
        "__SAFETY_PERCENT__",
        [string]$SafetyUsageMaximumPercent
    ).Replace(
        "__CHUNK_MIB__",
        [string]$ChunkSizeMiB
    )

    $pressureResult = Invoke-SsmShellScript `
        -InstanceId $instanceId `
        -ScriptContent $remoteScript `
        -Comment (
            "Lab 14 controlled disk pressure"
        )

    $afterPercentMatch = [regex]::Match(
        $pressureResult.StandardOutput,
        '(?m)^AFTER_PERCENT=([0-9]+)$'
    )

    $filesCreatedMatch = [regex]::Match(
        $pressureResult.StandardOutput,
        '(?m)^FILES_CREATED=([0-9]+)$'
    )

    if (-not $afterPercentMatch.Success) {
        throw (
            "The remote command did not return final " +
            "disk utilization."
        )
    }

    if (-not $filesCreatedMatch.Success) {
        throw (
            "The remote command did not return the number " +
            "of files created."
        )
    }

    $afterPercent = [int](
        $afterPercentMatch.Groups[1].Value
    )

    $filesCreated = [int](
        $filesCreatedMatch.Groups[1].Value
    )

    if (
        $afterPercent -lt
        $TargetUsagePercent
    ) {
        throw (
            "Final utilization $afterPercent% is below " +
            "the requested target " +
            "$TargetUsagePercent%."
        )
    }

    if (
        $afterPercent -ge
        $SafetyUsageMaximumPercent
    ) {
        throw (
            "Final utilization $afterPercent% reached " +
            "or exceeded the safety limit " +
            "$SafetyUsageMaximumPercent%."
        )
    }

    Write-Step "Pressure summary"

    Write-Host (
        "Instance ID:        {0}" -f
        $instanceId
    )

    Write-Host (
        "Data volume ID:     {0}" -f
        $volumeId
    )

    Write-Host (
        "Mount point:        {0}" -f
        $MountPoint
    )

    Write-Host (
        "Target utilization: {0}%" -f
        $TargetUsagePercent
    )

    Write-Host (
        "Safety limit:       {0}%" -f
        $SafetyUsageMaximumPercent
    )

    Write-Host (
        "Final utilization:  {0}%" -f
        $afterPercent
    )

    Write-Host (
        "Files created:      {0}" -f
        $filesCreated
    )

    Write-Host ""
    Write-Host `
        "LAB 14 CONTROLLED DISK PRESSURE COMPLETED" `
        -ForegroundColor Green

    Write-Host (
        "The root filesystem was not intentionally " +
        "modified."
    )
}
catch {
    Write-Host ""
    Write-Host (
        "[FAIL] {0}" -f
        $_.Exception.Message
    ) -ForegroundColor Red

    Write-Host ""
    Write-Host `
        "LAB 14 CONTROLLED DISK PRESSURE FAILED" `
        -ForegroundColor Red

    exit 1
}
