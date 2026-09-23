[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [ValidateRange(1, 99)]
    [int]$HealthyUsageMaximumPercent = 60,
    [ValidateRange(1, 99)]
    [int]$ElevatedUsageMinimumPercent = 80,
    [ValidateRange(1, 99)]
    [int]$SafetyUsageMaximumPercent = 88,
    [ValidateRange(1, 50)]
    [int]$LargestFileCount = 10
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
        [int]$MaximumAttempts = 60,
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
        Start-Sleep -Seconds $DelaySeconds
    }
    throw "SSM command $CommandId did not finish within the expected time."
}

function Invoke-SsmReadOnlyScript {
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
        ("lab14-diagnose-ssm-{0}.json" -f [guid]::NewGuid().ToString("N"))

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
            "--comment", "Lab 14 read-only disk diagnosis",
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

Write-Host "Lab 14 - Read-only disk utilization diagnosis"

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

    Write-Step "Read-only filesystem diagnosis"
    $remoteScript = @'
#!/usr/bin/env bash
set -euo pipefail

MOUNT_POINT="__MOUNT_POINT__"
GENERATED_DIRECTORY="__GENERATED_DIRECTORY__"
ARCHIVE_DIRECTORY="__ARCHIVE_DIRECTORY__"
EXPECTED_VOLUME_ID="__VOLUME_ID__"
LARGEST_FILE_COUNT=__LARGEST_FILE_COUNT__

if ! mountpoint -q "$MOUNT_POINT"; then
    echo "ERROR=The expected mount point is not mounted."
    exit 20
fi

SOURCE=$(findmnt -n -o SOURCE --target "$MOUNT_POINT")
FSTYPE=$(findmnt -n -o FSTYPE --target "$MOUNT_POINT")
OPTIONS=$(findmnt -n -o OPTIONS --target "$MOUNT_POINT")
UUID=$(findmnt -n -o UUID --target "$MOUNT_POINT")
MARKER=$(cat "$MOUNT_POINT/.lab14-volume" 2>/dev/null || true)

if [[ "$MARKER" != "$EXPECTED_VOLUME_ID" ]]; then
    echo "ERROR=The volume marker does not match the expected EBS volume."
    exit 21
fi

read -r SIZE_KB USED_KB AVAILABLE_KB USAGE_TEXT < <(
    df -Pk "$MOUNT_POINT" | awk 'NR==2 {print $2, $3, $4, $5}'
)

read -r INODES_TOTAL INODES_USED INODES_AVAILABLE INODES_USAGE_TEXT < <(
    df -Pi "$MOUNT_POINT" | awk 'NR==2 {print $2, $3, $4, $5}'
)

USAGE_PERCENT=${USAGE_TEXT%%%}
TOTAL_BYTES=$(( SIZE_KB * 1024 ))
USED_BYTES=$(( USED_KB * 1024 ))
AVAILABLE_BYTES=$(( AVAILABLE_KB * 1024 ))
USABLE_BYTES=$(( USED_BYTES + AVAILABLE_BYTES ))
INODES_USAGE_PERCENT=${INODES_USAGE_TEXT%%%}

if findmnt --verify --tab-file /etc/fstab >/dev/null 2>&1; then
    FSTAB_VERIFY="ok"
else
    FSTAB_VERIFY="failed"
fi

OPEN_DELETED_COUNT=0
while IFS= read -r FD_LINK; do
    LINK_TARGET=$(readlink "$FD_LINK" 2>/dev/null || true)
    if [[ "$LINK_TARGET" == "$MOUNT_POINT"/*" (deleted)" ]]; then
        OPEN_DELETED_COUNT=$(( OPEN_DELETED_COUNT + 1 ))
    fi
done < <(
    find /proc/[0-9]*/fd -type l -lname '* (deleted)' 2>/dev/null || true
)

GENERATED_BYTES=$(du -sB1 "$GENERATED_DIRECTORY" 2>/dev/null | awk '{print $1}')
ARCHIVE_BYTES=$(du -sB1 "$ARCHIVE_DIRECTORY" 2>/dev/null | awk '{print $1}')
GENERATED_BYTES=${GENERATED_BYTES:-0}
ARCHIVE_BYTES=${ARCHIVE_BYTES:-0}

PRESSURE_FILE_COUNT=$(
    find "$GENERATED_DIRECTORY" -xdev -maxdepth 1 -type f \
        -name 'lab14-pressure-*.log' -printf '.' 2>/dev/null | wc -c
)
PRESSURE_FILE_BYTES=$(
    find "$GENERATED_DIRECTORY" -xdev -maxdepth 1 -type f \
        -name 'lab14-pressure-*.log' -printf '%s\n' 2>/dev/null |
        awk '{total += $1} END {print total + 0}'
)

echo "MOUNT_POINT=$MOUNT_POINT"
echo "SOURCE=$SOURCE"
echo "FSTYPE=$FSTYPE"
echo "OPTIONS=$OPTIONS"
echo "UUID=$UUID"
echo "MARKER=$MARKER"
echo "TOTAL_BYTES=$TOTAL_BYTES"
echo "USED_BYTES=$USED_BYTES"
echo "AVAILABLE_BYTES=$AVAILABLE_BYTES"
echo "USABLE_BYTES=$USABLE_BYTES"
echo "USAGE_PERCENT=$USAGE_PERCENT"
echo "INODES_TOTAL=$INODES_TOTAL"
echo "INODES_USED=$INODES_USED"
echo "INODES_AVAILABLE=$INODES_AVAILABLE"
echo "INODES_USAGE_PERCENT=$INODES_USAGE_PERCENT"
echo "FSTAB_VERIFY=$FSTAB_VERIFY"
echo "OPEN_DELETED_COUNT=$OPEN_DELETED_COUNT"
echo "GENERATED_BYTES=$GENERATED_BYTES"
echo "ARCHIVE_BYTES=$ARCHIVE_BYTES"
echo "PRESSURE_FILE_COUNT=$PRESSURE_FILE_COUNT"
echo "PRESSURE_FILE_BYTES=$PRESSURE_FILE_BYTES"
echo "RECOVERABLE_BYTES=$PRESSURE_FILE_BYTES"

echo "LARGEST_FILES_BEGIN"
find "$MOUNT_POINT" -xdev -type f -printf '%s\t%p\n' 2>/dev/null |
    sort -nr | head -n "$LARGEST_FILE_COUNT" || true
echo "LARGEST_FILES_END"

echo "LARGEST_DIRECTORIES_BEGIN"
du -x -B1 --max-depth=2 "$MOUNT_POINT" 2>/dev/null |
    sort -nr | head -n "$LARGEST_FILE_COUNT" || true
echo "LARGEST_DIRECTORIES_END"

echo "OPEN_DELETED_FILES_BEGIN"
while IFS= read -r FD_LINK; do
    LINK_TARGET=$(readlink "$FD_LINK" 2>/dev/null || true)
    if [[ "$LINK_TARGET" == "$MOUNT_POINT"/*" (deleted)" ]]; then
        printf '%s\t%s\n' "$FD_LINK" "$LINK_TARGET"
    fi
done < <(
    find /proc/[0-9]*/fd -type l -lname '* (deleted)' 2>/dev/null || true
)
echo "OPEN_DELETED_FILES_END"

echo "RECENT_JOURNAL_BEGIN"
journalctl --since '-30 minutes' --no-pager -n 40 -o short-iso 2>/dev/null || true
echo "RECENT_JOURNAL_END"
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
        "__LARGEST_FILE_COUNT__", [string]$LargestFileCount
    )

    $diagnosis = Invoke-SsmReadOnlyScript -InstanceId $instanceId `
        -ScriptContent $remoteScript
    Write-InfoMessage "SSM command ID: $($diagnosis.CommandId)."
    if ($diagnosis.Status -ne "Success") {
        throw (
            "Read-only diagnosis failed with status " +
            "$($diagnosis.Status).`n$($diagnosis.StandardError)" +
            $diagnosis.StandardOutput
        )
    }
    Write-Success "Read-only filesystem diagnosis succeeded."

    $values = ConvertTo-RemoteValues -Text $diagnosis.StandardOutput
    $requiredKeys = @(
        "MOUNT_POINT", "SOURCE", "FSTYPE", "UUID", "MARKER",
        "TOTAL_BYTES", "USED_BYTES", "AVAILABLE_BYTES", "USABLE_BYTES",
        "USAGE_PERCENT", "INODES_TOTAL", "INODES_USED",
        "INODES_AVAILABLE", "INODES_USAGE_PERCENT", "FSTAB_VERIFY",
        "OPEN_DELETED_COUNT", "GENERATED_BYTES", "ARCHIVE_BYTES",
        "PRESSURE_FILE_COUNT", "PRESSURE_FILE_BYTES", "RECOVERABLE_BYTES"
    )
    foreach ($key in $requiredKeys) {
        if (-not $values.ContainsKey($key)) {
            throw "The remote diagnosis did not return $key."
        }
    }
    if ($values["MOUNT_POINT"] -ne $MountPoint) {
        throw "The diagnosis inspected an unexpected mount point."
    }
    if ($values["FSTYPE"] -ne "ext4") {
        throw "The Lab 14 data filesystem is not ext4."
    }
    if ($values["MARKER"] -ne $volumeId) {
        throw "The mounted filesystem does not match the Lab 14 EBS volume."
    }
    if ($values["FSTAB_VERIFY"] -ne "ok") {
        throw "The persistent mount configuration did not pass verification."
    }

    $usagePercent = [int]$values["USAGE_PERCENT"]
    $totalBytes = [long]$values["TOTAL_BYTES"]
    $usedBytes = [long]$values["USED_BYTES"]
    $availableBytes = [long]$values["AVAILABLE_BYTES"]
    $usableBytes = [long]$values["USABLE_BYTES"]
    $generatedBytes = [long]$values["GENERATED_BYTES"]
    $archiveBytes = [long]$values["ARCHIVE_BYTES"]
    $pressureFileCount = [int]$values["PRESSURE_FILE_COUNT"]
    $pressureFileBytes = [long]$values["PRESSURE_FILE_BYTES"]
    $recoverableBytes = [long]$values["RECOVERABLE_BYTES"]
    $inodesTotal = [long]$values["INODES_TOTAL"]
    $inodesUsed = [long]$values["INODES_USED"]
    $inodesAvailable = [long]$values["INODES_AVAILABLE"]
    $inodesUsagePercent = [int]$values["INODES_USAGE_PERCENT"]
    $openDeletedCount = [int]$values["OPEN_DELETED_COUNT"]

    if ($usagePercent -ge $SafetyUsageMaximumPercent) {
        $usageState = "SafetyLimit"
    }
    elseif ($usagePercent -ge $ElevatedUsageMinimumPercent) {
        $usageState = "Elevated"
    }
    elseif ($usagePercent -lt $HealthyUsageMaximumPercent) {
        $usageState = "Healthy"
    }
    else {
        $usageState = "Intermediate"
    }

    Write-Step "Capacity analysis"
    Write-Host ("Mount point:          {0}" -f $values["MOUNT_POINT"])
    Write-Host ("Source:               {0}" -f $values["SOURCE"])
    Write-Host ("Filesystem:           {0}" -f $values["FSTYPE"])
    Write-Host ("UUID:                 {0}" -f $values["UUID"])
    Write-Host ("Total ext4 capacity:  {0}" -f (Format-ByteSize $totalBytes))
    Write-Host ("Usable capacity:      {0}" -f (Format-ByteSize $usableBytes))
    Write-Host ("Used:                 {0}" -f (Format-ByteSize $usedBytes))
    Write-Host ("Available:            {0}" -f (Format-ByteSize $availableBytes))
    Write-Host ("Utilization:          {0}%" -f $usagePercent)
    Write-Host ("State:                {0}" -f $usageState)

    if ($usageState -eq "SafetyLimit") {
        Write-Host (
            "[WARN] Utilization reached or exceeded the configured " +
            "safety limit of $SafetyUsageMaximumPercent%."
        ) -ForegroundColor Red
    }
    elseif ($usageState -eq "Elevated") {
        Write-InfoMessage (
            "Controlled elevated utilization was confirmed: $usagePercent%."
        )
    }

    Write-Step "Inode analysis"
    Write-Host ("Total inodes:         {0:N0}" -f $inodesTotal)
    Write-Host ("Used inodes:          {0:N0}" -f $inodesUsed)
    Write-Host ("Available inodes:     {0:N0}" -f $inodesAvailable)
    Write-Host ("Inode utilization:    {0}%" -f $inodesUsagePercent)
    Write-Host ("fstab verification:   {0}" -f $values["FSTAB_VERIFY"])
    Write-Host ("Open deleted files:   {0}" -f $openDeletedCount)

    Write-Step "Lab 14 generated data"
    Write-Host ("Generated directory:  {0}" -f $GeneratedDirectory)
    Write-Host ("Generated size:       {0}" -f (Format-ByteSize $generatedBytes))
    Write-Host ("Archive directory:    {0}" -f $ArchiveDirectory)
    Write-Host ("Archive size:         {0}" -f (Format-ByteSize $archiveBytes))
    Write-Host ("Pressure file count:  {0}" -f $pressureFileCount)
    Write-Host ("Pressure file size:   {0}" -f (Format-ByteSize $pressureFileBytes))
    Write-Host ("Recoverable space:    {0}" -f (Format-ByteSize $recoverableBytes))

    $outputLines = @($diagnosis.StandardOutput -split "`n")
    $largestStart = [array]::IndexOf($outputLines, "LARGEST_FILES_BEGIN")
    $largestEnd = [array]::IndexOf($outputLines, "LARGEST_FILES_END")
    Write-Step "Largest files on the Lab 14 volume"
    if ($largestStart -ge 0 -and $largestEnd -gt ($largestStart + 1)) {
        foreach ($line in $outputLines[($largestStart + 1)..($largestEnd - 1)]) {
            if ($line -match '^(\d+)\t(.+)$') {
                Write-Host (
                    "{0,12}  {1}" -f
                    (Format-ByteSize ([long]$matches[1])), $matches[2]
                )
            }
        }
    }
    else {
        Write-Host "No regular files were found."
    }

    $directoryStart = [array]::IndexOf(
        $outputLines,
        "LARGEST_DIRECTORIES_BEGIN"
    )
    $directoryEnd = [array]::IndexOf(
        $outputLines,
        "LARGEST_DIRECTORIES_END"
    )
    Write-Step "Largest directories on the Lab 14 volume"
    if ($directoryStart -ge 0 -and $directoryEnd -gt ($directoryStart + 1)) {
        foreach (
            $line in $outputLines[($directoryStart + 1)..($directoryEnd - 1)]
        ) {
            if ($line -match '^(\d+)\t(.+)$') {
                Write-Host (
                    "{0,12}  {1}" -f
                    (Format-ByteSize ([long]$matches[1])), $matches[2]
                )
            }
        }
    }
    else {
        Write-Host "No directory consumption data was returned."
    }

    Write-Step "Open deleted files"
    if ($openDeletedCount -eq 0) {
        Write-Success "No deleted files remain open on the Lab 14 volume."
    }
    else {
        $deletedStart = [array]::IndexOf(
            $outputLines,
            "OPEN_DELETED_FILES_BEGIN"
        )
        $deletedEnd = [array]::IndexOf(
            $outputLines,
            "OPEN_DELETED_FILES_END"
        )
        Write-InfoMessage (
            "$openDeletedCount deleted file descriptor(s) remain open."
        )
        if ($deletedStart -ge 0 -and $deletedEnd -gt ($deletedStart + 1)) {
            $outputLines[($deletedStart + 1)..($deletedEnd - 1)] |
                ForEach-Object { Write-Host $_ }
        }
    }

    $journalStart = [array]::IndexOf($outputLines, "RECENT_JOURNAL_BEGIN")
    $journalEnd = [array]::IndexOf($outputLines, "RECENT_JOURNAL_END")
    Write-Step "Recent system journal"
    if ($journalStart -ge 0 -and $journalEnd -gt ($journalStart + 1)) {
        $outputLines[($journalStart + 1)..($journalEnd - 1)] |
            ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "No recent journal entries were returned."
    }

    Write-Step "Diagnostic summary"
    Write-Host ("Instance ID:          {0}" -f $instanceId)
    Write-Host ("Data volume ID:       {0}" -f $volumeId)
    Write-Host ("Disk utilization:     {0}%" -f $usagePercent)
    Write-Host ("Usage state:          {0}" -f $usageState)
    Write-Host ("Pressure files:       {0}" -f $pressureFileCount)
    Write-Host ("Potential recovery:   {0}" -f (Format-ByteSize $recoverableBytes))
    Write-Host ("Inode utilization:    {0}%" -f $inodesUsagePercent)
    Write-Host ("Open deleted files:   {0}" -f $openDeletedCount)

    Write-Host ""
    Write-Host "LAB 14 DIAGNOSIS COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green
    Write-Host "All filesystem operations were read-only."
    Write-Host "No files were created, removed, compressed, or changed."
    Write-Host "No AWS infrastructure was modified."
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "LAB 14 DIAGNOSIS FAILED" -ForegroundColor Red
    exit 1
}
