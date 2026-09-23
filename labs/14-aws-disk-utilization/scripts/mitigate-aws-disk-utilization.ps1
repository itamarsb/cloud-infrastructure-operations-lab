[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [ValidateRange(1, 79)]
    [int]$HealthyUsageMaximumPercent = 60,
    [ValidateRange(81, 99)]
    [int]$SafetyUsageMaximumPercent = 88,
    [ValidateRange(1, 20)]
    [int]$RetainedArchiveCount = 5,
    [switch]$ConfirmMitigation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab14-disk-utilization-instance"
$DataVolumeName = "lab14-disk-utilization-data"
$MountPoint = "/var/log/lab14"
$GeneratedDirectory = "$MountPoint/generated"
$ArchiveDirectory = "$MountPoint/archive"

$ExpectedTags = @{
    Project     = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab         = "14"
    ManagedBy   = "aws-cli"
    Owner       = "itamarsb"
}

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Write-Success {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-InfoMessage {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Invoke-AwsCli {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowEmpty
    )

    $output = @(
        & aws @Arguments --profile $ProfileName --region $Region `
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
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
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
        [AllowNull()][object[]]$Tags,
        [Parameter(Mandatory = $true)][string]$Key
    )
    $tag = @($Tags) | Where-Object { $_.Key -eq $Key } |
        Select-Object -First 1
    if ($null -eq $tag) { return $null }
    return [string]$tag.Value
}

function Assert-RequiredTags {
    param(
        [Parameter(Mandatory = $true)][string]$ResourceDescription,
        [AllowNull()][object[]]$Tags
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

function ConvertTo-RemoteValues {
    param([AllowEmptyString()][string]$Text)
    $values = @{}
    foreach ($line in ($Text -split "`n")) {
        if ($line -match '^([A-Z0-9_]+)=(.*)$') {
            $values[$matches[1]] = $matches[2].Trim()
        }
    }
    return $values
}

function Format-ByteSize {
    param([Parameter(Mandatory = $true)][long]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GiB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MiB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KiB" -f ($Bytes / 1KB)) }
    return "$Bytes bytes"
}

function Wait-SsmCommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandId,
        [Parameter(Mandatory = $true)][string]$InstanceId,
        [int]$MaximumAttempts = 120,
        [int]$DelaySeconds = 5
    )

    $terminalStatuses = @(
        "Success", "Cancelled", "TimedOut", "Failed", "Cancelling"
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
            "attempt $attempt/$MaximumAttempts; status $($invocation.Status)."
        )
        Start-Sleep -Seconds $DelaySeconds
    }
    throw "SSM command $CommandId did not finish within the expected time."
}

function Invoke-SsmMitigation {
    param(
        [Parameter(Mandatory = $true)][string]$InstanceId,
        [Parameter(Mandatory = $true)][string]$ScriptContent
    )

    $normalizedScriptContent = $ScriptContent.Replace("`r`n", "`n")
    $normalizedScriptContent = $normalizedScriptContent.Replace("`r", "`n")
    $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes(
        $normalizedScriptContent
    )
    $encodedScript = [Convert]::ToBase64String($scriptBytes)
    $parameters = @{
        commands = @("echo '$encodedScript' | base64 --decode | bash")
    } | ConvertTo-Json -Depth 4 -Compress

    $parametersPath = Join-Path ([System.IO.Path]::GetTempPath()) `
        ("lab14-mitigation-ssm-{0}.json" -f [guid]::NewGuid().ToString("N"))

    try {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText(
            $parametersPath, $parameters, $utf8WithoutBom
        )
        $parametersFileArgument = "file://$parametersPath"
        $commandResponse = ConvertFrom-AwsJson -Arguments @(
            "ssm", "send-command",
            "--instance-ids", $InstanceId,
            "--document-name", "AWS-RunShellScript",
            "--comment", "Lab 14 controlled disk mitigation",
            "--parameters", $parametersFileArgument
        )
    }
    finally {
        if (Test-Path -LiteralPath $parametersPath -PathType Leaf) {
            Remove-Item -LiteralPath $parametersPath -Force `
                -ErrorAction SilentlyContinue
        }
    }

    $commandId = [string]$commandResponse.Command.CommandId
    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "Systems Manager did not return a command identifier."
    }
    $invocation = Wait-SsmCommand -CommandId $commandId `
        -InstanceId $InstanceId
    return [pscustomobject]@{
        CommandId      = $commandId
        Status         = [string]$invocation.Status
        ResponseCode   = [int]$invocation.ResponseCode
        StandardOutput = ([string]$invocation.StandardOutputContent).Replace(
            "`r", ""
        )
        StandardError  = ([string]$invocation.StandardErrorContent).Replace(
            "`r", ""
        )
    }
}

Write-Host "Lab 14 - Controlled disk utilization mitigation"

try {
    if (-not $ConfirmMitigation.IsPresent) {
        throw (
            "Mitigation requires explicit confirmation. " +
            "Run the script with -ConfirmMitigation."
        )
    }
    if ($HealthyUsageMaximumPercent -ge $SafetyUsageMaximumPercent) {
        throw (
            "HealthyUsageMaximumPercent must be lower than " +
            "SafetyUsageMaximumPercent."
        )
    }

    Write-Step "Prerequisites and identity"
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }
    $identity = ConvertFrom-AwsJson -Arguments @("sts", "get-caller-identity")
    if ([string]::IsNullOrWhiteSpace([string]$identity.Account)) {
        throw "AWS identity could not be validated."
    }
    Write-Success "AWS session is authenticated."

    Write-Step "Lab 14 resource ownership"
    $instanceResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=running"
    )
    $instances = @(
        $instanceResponse.Reservations | ForEach-Object { $_.Instances }
    )
    if ($instances.Count -ne 1) {
        throw (
            "Expected one running Lab 14 instance; " +
            "found $($instances.Count)."
        )
    }
    $instance = $instances[0]
    $instanceId = [string]$instance.InstanceId
    Assert-RequiredTags -ResourceDescription "EC2 instance" `
        -Tags $instance.Tags
    Write-Success "EC2 ownership validated: $instanceId."

    $volumeResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-volumes", "--filters",
        "Name=tag:Name,Values=$DataVolumeName", "Name=status,Values=in-use"
    )
    $volumes = @($volumeResponse.Volumes)
    if ($volumes.Count -ne 1) {
        throw (
            "Expected one attached Lab 14 data volume; " +
            "found $($volumes.Count)."
        )
    }
    $volume = $volumes[0]
    $volumeId = [string]$volume.VolumeId
    $attachments = @($volume.Attachments)
    Assert-RequiredTags -ResourceDescription "EBS data volume" `
        -Tags $volume.Tags
    if (
        $attachments.Count -ne 1 -or
        $attachments[0].InstanceId -ne $instanceId -or
        $attachments[0].State -ne "attached"
    ) {
        throw "The Lab 14 data volume is not attached to the expected instance."
    }
    Write-Success "EBS ownership and attachment validated: $volumeId."

    Write-Step "Systems Manager availability"
    $ssmResponse = ConvertFrom-AwsJson -Arguments @(
        "ssm", "describe-instance-information",
        "--filters", "Key=InstanceIds,Values=$instanceId"
    )
    $managedInstances = @($ssmResponse.InstanceInformationList)
    if (
        $managedInstances.Count -ne 1 -or
        $managedInstances[0].PingStatus -ne "Online"
    ) {
        throw "The Lab 14 instance is not online in Systems Manager."
    }
    Write-Success "EC2 instance is online in Systems Manager."

    Write-Step "Controlled log rotation and compression"
    Write-InfoMessage (
        "Only lab14-pressure-*.log files inside $GeneratedDirectory " +
        "will be processed."
    )

    $remoteScript = @'
#!/usr/bin/env bash
set -euo pipefail

MOUNT_POINT="__MOUNT_POINT__"
GENERATED_DIRECTORY="__GENERATED_DIRECTORY__"
ARCHIVE_DIRECTORY="__ARCHIVE_DIRECTORY__"
EXPECTED_VOLUME_ID="__VOLUME_ID__"
HEALTHY_MAXIMUM=__HEALTHY_MAXIMUM__
SAFETY_MAXIMUM=__SAFETY_MAXIMUM__
RETAINED_ARCHIVES=__RETAINED_ARCHIVES__

usage_percent() {
    df -Pk "$MOUNT_POINT" | awk 'NR==2 {gsub(/%/, "", $5); print $5}'
}

used_bytes() {
    df -Pk "$MOUNT_POINT" | awk 'NR==2 {printf "%.0f\n", $3 * 1024}'
}

fail() {
    echo "ERROR=$1"
    exit "$2"
}

mountpoint -q "$MOUNT_POINT" || fail "Expected mount point is absent." 20
[[ "$(findmnt -n -o FSTYPE --target "$MOUNT_POINT")" == "ext4" ]] ||
    fail "Expected ext4 filesystem was not found." 21

MARKER=$(cat "$MOUNT_POINT/.lab14-volume" 2>/dev/null || true)
[[ "$MARKER" == "$EXPECTED_VOLUME_ID" ]] ||
    fail "Volume marker does not match the expected EBS volume." 22

[[ -d "$GENERATED_DIRECTORY" ]] || fail "Generated directory is absent." 23
[[ -d "$ARCHIVE_DIRECTORY" ]] || fail "Archive directory is absent." 24

GENERATED_REAL=$(realpath -e "$GENERATED_DIRECTORY")
ARCHIVE_REAL=$(realpath -e "$ARCHIVE_DIRECTORY")
[[ "$GENERATED_REAL" == "$MOUNT_POINT/generated" ]] ||
    fail "Generated directory resolved outside the allowed location." 25
[[ "$ARCHIVE_REAL" == "$MOUNT_POINT/archive" ]] ||
    fail "Archive directory resolved outside the allowed location." 26

INITIAL_USAGE=$(usage_percent)
INITIAL_USED_BYTES=$(used_bytes)

echo "INITIAL_USAGE_PERCENT=$INITIAL_USAGE"
echo "INITIAL_USED_BYTES=$INITIAL_USED_BYTES"

if (( INITIAL_USAGE >= SAFETY_MAXIMUM )); then
    fail "Utilization is at or above the configured safety limit." 27
fi

if (( INITIAL_USAGE < HEALTHY_MAXIMUM )); then
    echo "FILES_PROCESSED=0"
    echo "ARCHIVES_PRUNED=0"
    echo "FINAL_USAGE_PERCENT=$INITIAL_USAGE"
    echo "FINAL_USED_BYTES=$INITIAL_USED_BYTES"
    echo "RECLAIMED_BYTES=0"
    echo "ALREADY_HEALTHY=yes"
    exit 0
fi

mapfile -t PRESSURE_FILES < <(
    find "$GENERATED_DIRECTORY" -xdev -maxdepth 1 -type f \
        -name 'lab14-pressure-*.log' -print0 |
        sort -z |
        xargs -0 -r -n1 printf '%s\n'
)

(( ${#PRESSURE_FILES[@]} > 0 )) ||
    fail "No controlled pressure files are available for mitigation." 28

FILES_PROCESSED=0

for SOURCE_FILE in "${PRESSURE_FILES[@]}"; do
    SOURCE_REAL=$(realpath -e "$SOURCE_FILE")
    [[ "$SOURCE_REAL" == "$GENERATED_REAL"/lab14-pressure-*.log ]] ||
        fail "A candidate file resolved outside the controlled pattern." 29

    BASE_NAME=$(basename "$SOURCE_REAL")
    ARCHIVE_FILE="$ARCHIVE_REAL/${BASE_NAME}.gz"
    TEMP_FILE="$ARCHIVE_FILE.part.$$"

    if [[ -e "$ARCHIVE_FILE" ]]; then
        gzip -t "$ARCHIVE_FILE" || fail "Existing archive is invalid." 30
        gzip -cd "$ARCHIVE_FILE" | cmp -s - "$SOURCE_REAL" ||
            fail "Existing archive does not match its source file." 31
    else
        trap 'rm -f "$TEMP_FILE"' EXIT
        gzip -c "$SOURCE_REAL" > "$TEMP_FILE"
        gzip -t "$TEMP_FILE"
        gzip -cd "$TEMP_FILE" | cmp -s - "$SOURCE_REAL" ||
            fail "Compressed data did not match its source file." 32
        mv "$TEMP_FILE" "$ARCHIVE_FILE"
        trap - EXIT
        sync "$ARCHIVE_FILE"
    fi

    rm -f -- "$SOURCE_REAL"
    sync "$GENERATED_REAL" "$ARCHIVE_REAL"
    FILES_PROCESSED=$(( FILES_PROCESSED + 1 ))

    CURRENT_USAGE=$(usage_percent)
    echo "PROCESSED_FILE=$BASE_NAME"
    echo "CURRENT_USAGE_PERCENT=$CURRENT_USAGE"

    if (( CURRENT_USAGE < HEALTHY_MAXIMUM )); then
        break
    fi
done

FINAL_USAGE=$(usage_percent)
if (( FINAL_USAGE >= HEALTHY_MAXIMUM )); then
    fail "Controlled files were exhausted before healthy usage was restored." 33
fi

mapfile -t ARCHIVES < <(
    find "$ARCHIVE_DIRECTORY" -xdev -maxdepth 1 -type f \
        -name 'lab14-pressure-*.log.gz' -printf '%T@\t%p\n' |
        sort -nr |
        cut -f2-
)

ARCHIVES_PRUNED=0
if (( ${#ARCHIVES[@]} > RETAINED_ARCHIVES )); then
    for (( INDEX=RETAINED_ARCHIVES; INDEX<${#ARCHIVES[@]}; INDEX++ )); do
        ARCHIVE_TO_REMOVE=$(realpath -e "${ARCHIVES[$INDEX]}")
        [[ "$ARCHIVE_TO_REMOVE" == "$ARCHIVE_REAL"/lab14-pressure-*.log.gz ]] ||
            fail "An archive resolved outside the controlled pattern." 34
        gzip -t "$ARCHIVE_TO_REMOVE" || fail "Archive pruning found invalid data." 35
        rm -f -- "$ARCHIVE_TO_REMOVE"
        ARCHIVES_PRUNED=$(( ARCHIVES_PRUNED + 1 ))
    done
    sync "$ARCHIVE_REAL"
fi

FINAL_USED_BYTES=$(used_bytes)
RECLAIMED_BYTES=$(( INITIAL_USED_BYTES - FINAL_USED_BYTES ))

echo "FILES_PROCESSED=$FILES_PROCESSED"
echo "ARCHIVES_PRUNED=$ARCHIVES_PRUNED"
echo "FINAL_USAGE_PERCENT=$FINAL_USAGE"
echo "FINAL_USED_BYTES=$FINAL_USED_BYTES"
echo "RECLAIMED_BYTES=$RECLAIMED_BYTES"
echo "ALREADY_HEALTHY=no"
'@

    $remoteScript = $remoteScript.Replace(
        "__MOUNT_POINT__", $MountPoint
    ).Replace(
        "__GENERATED_DIRECTORY__", $GeneratedDirectory
    ).Replace(
        "__ARCHIVE_DIRECTORY__", $ArchiveDirectory
    ).Replace(
        "__VOLUME_ID__", $volumeId
    ).Replace(
        "__HEALTHY_MAXIMUM__", [string]$HealthyUsageMaximumPercent
    ).Replace(
        "__SAFETY_MAXIMUM__", [string]$SafetyUsageMaximumPercent
    ).Replace(
        "__RETAINED_ARCHIVES__", [string]$RetainedArchiveCount
    )

    $mitigation = Invoke-SsmMitigation -InstanceId $instanceId `
        -ScriptContent $remoteScript
    Write-InfoMessage "SSM command ID: $($mitigation.CommandId)."
    if ($mitigation.Status -ne "Success") {
        throw (
            "Mitigation failed with status $($mitigation.Status).`n" +
            $mitigation.StandardError + $mitigation.StandardOutput
        )
    }

    $values = ConvertTo-RemoteValues -Text $mitigation.StandardOutput
    $requiredKeys = @(
        "INITIAL_USAGE_PERCENT", "INITIAL_USED_BYTES", "FILES_PROCESSED",
        "ARCHIVES_PRUNED", "FINAL_USAGE_PERCENT", "FINAL_USED_BYTES",
        "RECLAIMED_BYTES", "ALREADY_HEALTHY"
    )
    foreach ($key in $requiredKeys) {
        if (-not $values.ContainsKey($key)) {
            throw "The remote mitigation did not return $key."
        }
    }

    $initialUsage = [int]$values["INITIAL_USAGE_PERCENT"]
    $finalUsage = [int]$values["FINAL_USAGE_PERCENT"]
    $filesProcessed = [int]$values["FILES_PROCESSED"]
    $archivesPruned = [int]$values["ARCHIVES_PRUNED"]
    $reclaimedBytes = [long]$values["RECLAIMED_BYTES"]

    if ($finalUsage -ge $HealthyUsageMaximumPercent) {
        throw (
            "Mitigation finished at $finalUsage%; expected less than " +
            "$HealthyUsageMaximumPercent%."
        )
    }

    Write-Step "Mitigation summary"
    Write-Host ("Instance ID:          {0}" -f $instanceId)
    Write-Host ("Data volume ID:       {0}" -f $volumeId)
    Write-Host ("Initial utilization:  {0}%" -f $initialUsage)
    Write-Host ("Final utilization:    {0}%" -f $finalUsage)
    Write-Host ("Files processed:      {0}" -f $filesProcessed)
    Write-Host ("Archives pruned:      {0}" -f $archivesPruned)
    Write-Host ("Space reclaimed:      {0}" -f (Format-ByteSize $reclaimedBytes))
    Write-Host ("Already healthy:      {0}" -f $values["ALREADY_HEALTHY"])

    Write-Host ""
    Write-Host "LAB 14 MITIGATION COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green
    Write-Host "Only controlled Lab 14 pressure files were processed."
    Write-Host "Every new archive was validated before its source was removed."
    Write-Host "AWS infrastructure was not modified."
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "LAB 14 MITIGATION FAILED" -ForegroundColor Red
    exit 1
}
