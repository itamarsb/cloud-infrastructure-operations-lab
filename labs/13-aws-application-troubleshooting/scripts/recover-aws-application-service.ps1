[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [switch]$ConfirmRecovery
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab13-troubleshooting-instance"

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

    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$AllowEmpty
    )

    $Output = & aws @Arguments 2>&1 | Out-String
    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {
        $CommandText = "aws " + ($Arguments -join " ")

        throw @"
AWS CLI command failed.

Command:
$CommandText

Output:
$($Output.Trim())
"@
    }

    if ([string]::IsNullOrWhiteSpace($Output)) {
        if ($AllowEmpty) {
            return $null
        }

        throw "AWS CLI returned an empty response."
    }

    try {
        return $Output | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "AWS CLI returned invalid JSON: $($Output.Trim())"
    }
}

function Get-SingleRunningInstance {
    $Response = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=tag:Project,Values=cloud-infrastructure-operations-lab",
        "Name=tag:Environment,Values=lab",
        "Name=tag:Lab,Values=13",
        "Name=tag:ManagedBy,Values=aws-cli",
        "Name=tag:Owner,Values=itamarsb",
        "Name=instance-state-name,Values=running",
        "--output", "json"
    )

    $Instances = @(
        $Response.Reservations |
            ForEach-Object {
                @($_.Instances)
            }
    )

    if ($Instances.Count -ne 1) {
        throw (
            "Expected exactly one running Lab 13 EC2 instance, " +
            "but found $($Instances.Count)."
        )
    }

    return $Instances[0]
}

function Get-SsmInstanceInformation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    $Response = Invoke-AwsJson -Arguments @(
        "ssm",
        "describe-instance-information",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Key=InstanceIds,Values=$InstanceId",
        "--output", "json"
    )

    $Information = @($Response.InstanceInformationList)

    if ($Information.Count -ne 1) {
        throw (
            "EC2 instance $InstanceId is not uniquely registered " +
            "in AWS Systems Manager."
        )
    }

    return $Information[0]
}

function Send-SsmShellCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $true)]
        [string]$Comment,

        [Parameter(Mandatory = $true)]
        [string]$Script
    )

    $Parameters = @{
        commands = @($Script)
    } | ConvertTo-Json -Depth 5 -Compress

    $Response = Invoke-AwsJson -Arguments @(
        "ssm",
        "send-command",
        "--profile", $ProfileName,
        "--region", $Region,
        "--instance-ids", $InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--comment", $Comment,
        "--parameters", $Parameters,
        "--timeout-seconds", "120",
        "--output", "json"
    )

    $CommandId = [string]$Response.Command.CommandId

    if ([string]::IsNullOrWhiteSpace($CommandId)) {
        throw "Systems Manager did not return a Command ID."
    }

    return $CommandId
}

function Wait-SsmCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandId,

        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [int]$MaximumAttempts = 40,

        [int]$DelaySeconds = 3
    )

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        try {
            $Invocation = Invoke-AwsJson -Arguments @(
                "ssm",
                "get-command-invocation",
                "--profile", $ProfileName,
                "--region", $Region,
                "--command-id", $CommandId,
                "--instance-id", $InstanceId,
                "--output", "json"
            )
        }
        catch {
            if ($Attempt -eq $MaximumAttempts) {
                throw
            }

            Write-InfoMessage (
                "Waiting for the Systems Manager command invocation: " +
                "attempt $Attempt/$MaximumAttempts."
            )

            Start-Sleep -Seconds $DelaySeconds
            continue
        }

        $Status = [string]$Invocation.Status

        switch ($Status) {
            "Success" {
                return $Invocation
            }

            "Pending" {
                Write-InfoMessage (
                    "Systems Manager command is pending: " +
                    "attempt $Attempt/$MaximumAttempts."
                )
            }

            "InProgress" {
                Write-InfoMessage (
                    "Systems Manager command is running: " +
                    "attempt $Attempt/$MaximumAttempts."
                )
            }

            "Delayed" {
                Write-InfoMessage (
                    "Systems Manager command is delayed: " +
                    "attempt $Attempt/$MaximumAttempts."
                )
            }

            default {
                $StandardOutput = [string]$Invocation.StandardOutputContent
                $StandardError = [string]$Invocation.StandardErrorContent

                throw @"
Systems Manager recovery command failed.

Status:
$Status

Standard output:
$StandardOutput

Standard error:
$StandardError
"@
            }
        }

        if ($Attempt -lt $MaximumAttempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw (
        "Systems Manager command did not complete after " +
        "$MaximumAttempts attempts."
    )
}

function Get-RemoteValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Output,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $Pattern = "(?m)^" + [regex]::Escape($Name) + "=(.*)$"
    $Match = [regex]::Match($Output, $Pattern)

    if (-not $Match.Success) {
        throw "Recovery result '$Name' was not returned."
    }

    return $Match.Groups[1].Value.Trim()
}

function Wait-PublicApplicationHealthy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublicIpAddress,

        [int]$MaximumAttempts = 20,

        [int]$DelaySeconds = 3
    )

    $ApplicationUri = "http://$PublicIpAddress/"
    $HealthUri = "http://$PublicIpAddress/health"

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        try {
            $ApplicationResponse = Invoke-WebRequest `
                -Uri $ApplicationUri `
                -Method Get `
                -DisableKeepAlive `
                -TimeoutSec 5 `
                -UseBasicParsing

            $HealthResponse = Invoke-WebRequest `
                -Uri $HealthUri `
                -Method Get `
                -DisableKeepAlive `
                -TimeoutSec 5 `
                -UseBasicParsing

            $ApplicationBody = [string]$ApplicationResponse.Content
            $HealthBody = [string]$HealthResponse.Content

            $ApplicationValid = (
                [int]$ApplicationResponse.StatusCode -eq 200 -and
                $ApplicationBody -match "LAB13_STATUS=healthy"
            )

            $HealthValid = (
                [int]$HealthResponse.StatusCode -eq 200 -and
                $HealthBody -match "healthy"
            )

            if ($ApplicationValid -and $HealthValid) {
                return
            }

            Write-InfoMessage (
                "HTTP responded without the expected content: " +
                "attempt $Attempt/$MaximumAttempts."
            )
        }
        catch {
            Write-InfoMessage (
                "Waiting for the recovered public application: " +
                "attempt $Attempt/$MaximumAttempts."
            )
        }

        if ($Attempt -lt $MaximumAttempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw (
        "The public application did not return the expected healthy " +
        "responses after recovery."
    )
}

Write-Host "Lab 13 - Controlled application service recovery"

try {
    Write-Step "Authorization and prerequisites"

    if (-not $ConfirmRecovery) {
        throw (
            "Recovery was not authorized. Run this script with " +
            "-ConfirmRecovery."
        )
    }

    $null = Get-Command aws -ErrorAction Stop

    $Identity = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity",
        "--profile", $ProfileName,
        "--region", $Region,
        "--output", "json"
    )

    if ([string]::IsNullOrWhiteSpace([string]$Identity.Account)) {
        throw "AWS session validation did not return an account identifier."
    }

    Write-Ok (
        "AWS session validated and service recovery explicitly authorized."
    )

    Write-Step "Lab 13 instance discovery"

    $Instance = Get-SingleRunningInstance
    $InstanceId = [string]$Instance.InstanceId
    $PublicIpAddress = [string]$Instance.PublicIpAddress
    $AvailabilityZone = [string]$Instance.Placement.AvailabilityZone

    if ([string]::IsNullOrWhiteSpace($InstanceId)) {
        throw "The Lab 13 instance does not have an instance identifier."
    }

    if ([string]::IsNullOrWhiteSpace($PublicIpAddress)) {
        throw "The Lab 13 instance does not have a public IPv4 address."
    }

    $SsmInformation = Get-SsmInstanceInformation -InstanceId $InstanceId

    if ([string]$SsmInformation.PingStatus -ne "Online") {
        throw (
            "The Lab 13 instance is registered in Systems Manager, " +
            "but its status is $($SsmInformation.PingStatus)."
        )
    }

    Write-Ok (
        "$InstanceId is running in $AvailabilityZone and online " +
        "in AWS Systems Manager."
    )

    Write-Step "Failed-state preflight"

    $PreflightScript = @'
set -u

CONFIG="/etc/nginx/conf.d/lab13.conf"
BACKUP="${CONFIG}.lab13-backup"
MARKER="/var/tmp/lab13-failure-injected"

if ! test -f "$CONFIG"; then
    echo "The active Lab 13 Nginx configuration does not exist."
    exit 31
fi

if ! test -f "$BACKUP"; then
    echo "The valid Lab 13 configuration backup does not exist."
    exit 32
fi

if ! test -f "$MARKER"; then
    echo "The controlled failure marker does not exist."
    exit 33
fi

if ! grep -Eq \
    '^[[:space:]]*lab13_invalid_directive[[:space:]]+on;' \
    "$CONFIG"
then
    echo "The intentionally invalid directive was not found."
    exit 34
fi

if nginx -t >/var/tmp/lab13-recovery-preflight.txt 2>&1; then
    echo "The current Nginx configuration is unexpectedly valid."
    exit 35
fi

if systemctl is-active --quiet nginx; then
    echo "Nginx is unexpectedly active before recovery."
    exit 36
fi

if pgrep -x nginx >/dev/null 2>&1; then
    echo "An Nginx process is unexpectedly running before recovery."
    exit 37
fi

if ss -lntH 2>/dev/null |
    awk '{print $4}' |
    grep -Eq '(^|:|\])80$'
then
    echo "TCP port 80 is unexpectedly listening before recovery."
    exit 38
fi

echo "CONFIGURATION_STATE=invalid"
echo "SERVICE_STATE=inactive"
echo "PROCESS_STATE=absent"
echo "PORT_80_STATE=not-listening"
echo "BACKUP_STATE=present"
echo "FAILURE_MARKER_STATE=present"
echo "RECOVERY_PREFLIGHT=confirmed"

exit 0
'@

    $PreflightCommandId = Send-SsmShellCommand `
        -InstanceId $InstanceId `
        -Comment "Lab 13 recovery preflight" `
        -Script $PreflightScript

    $PreflightResult = Wait-SsmCommand `
        -CommandId $PreflightCommandId `
        -InstanceId $InstanceId

    $PreflightOutput = [string]$PreflightResult.StandardOutputContent

    if ($PreflightOutput -notmatch "(?m)^RECOVERY_PREFLIGHT=confirmed$") {
        throw (
            "The recovery preflight did not return the expected " +
            "failed-state confirmation."
        )
    }

    Write-Ok "The intentionally invalid configuration was confirmed."
    Write-Ok "Nginx is inactive and TCP port 80 is not listening."
    Write-Ok "The valid configuration backup is available."

    Write-Step "Configuration restoration and service recovery"

    $RecoveryScript = @'
set -u

CONFIG="/etc/nginx/conf.d/lab13.conf"
BACKUP="${CONFIG}.lab13-backup"
MARKER="/var/tmp/lab13-failure-injected"
FAILED_COPY="/var/tmp/lab13.conf.failed"
VALIDATION_OUTPUT="/var/tmp/lab13-recovery-nginx-test.txt"

rollback_configuration() {
    if test -f "$FAILED_COPY"; then
        install \
            --owner=root \
            --group=root \
            --mode=0644 \
            "$FAILED_COPY" \
            "$CONFIG"
    fi
}

if ! test -f "$CONFIG"; then
    echo "The active Lab 13 Nginx configuration does not exist."
    exit 41
fi

if ! test -f "$BACKUP"; then
    echo "The valid Lab 13 configuration backup does not exist."
    exit 42
fi

if ! test -f "$MARKER"; then
    echo "The controlled failure marker does not exist."
    exit 43
fi

if ! grep -Eq \
    '^[[:space:]]*lab13_invalid_directive[[:space:]]+on;' \
    "$CONFIG"
then
    echo "The intentionally invalid directive was not found."
    exit 44
fi

cp --preserve=all "$CONFIG" "$FAILED_COPY"

install \
    --owner=root \
    --group=root \
    --mode=0644 \
    "$BACKUP" \
    "$CONFIG"

if ! nginx -t >"$VALIDATION_OUTPUT" 2>&1; then
    rollback_configuration

    echo "The restored Nginx configuration did not pass nginx -t."
    cat "$VALIDATION_OUTPUT"
    exit 45
fi

if ! systemctl restart nginx; then
    rollback_configuration

    echo "Nginx did not restart with the restored configuration."
    exit 46
fi

sleep 3

if ! systemctl is-active --quiet nginx; then
    rollback_configuration

    echo "Nginx is not active after recovery."
    exit 47
fi

if ! pgrep -x nginx >/dev/null 2>&1; then
    rollback_configuration

    echo "No Nginx process was found after recovery."
    exit 48
fi

if ! ss -lntH 2>/dev/null |
    awk '{print $4}' |
    grep -Eq '(^|:|\])80$'
then
    rollback_configuration

    echo "TCP port 80 is not listening after recovery."
    exit 49
fi

if ! curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    http://127.0.0.1/ |
    grep -q 'LAB13_STATUS=healthy'
then
    rollback_configuration

    echo "The local application endpoint did not pass validation."
    exit 50
fi

if ! curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    http://127.0.0.1/health |
    grep -q 'healthy'
then
    rollback_configuration

    echo "The local health endpoint did not pass validation."
    exit 51
fi

rm -f "$BACKUP"
rm -f "$MARKER"
rm -f "$FAILED_COPY"
rm -f "$VALIDATION_OUTPUT"
rm -f "/var/tmp/lab13-recovery-preflight.txt"
rm -f "/var/tmp/lab13-nginx-test-error.txt"
rm -f "/var/tmp/lab13-nginx-restart-error.txt"

SERVICE_STATE="$(systemctl is-active nginx)"

if pgrep -x nginx >/dev/null 2>&1; then
    PROCESS_STATE="present"
    PROCESS_COUNT="$(pgrep -x nginx | wc -l | tr -d ' ')"
else
    PROCESS_STATE="absent"
    PROCESS_COUNT="0"
fi

PORT_80_COUNT="$(
    ss -lntH 2>/dev/null |
    awk '{print $4}' |
    grep -Ec '(^|:|\])80$' ||
    true
)"

if test "$PORT_80_COUNT" -gt 0; then
    PORT_80_STATE="listening"
else
    PORT_80_STATE="not-listening"
fi

echo "CONFIGURATION_STATE=valid"
echo "SERVICE_STATE=$SERVICE_STATE"
echo "PROCESS_STATE=$PROCESS_STATE"
echo "PROCESS_COUNT=$PROCESS_COUNT"
echo "PORT_80_STATE=$PORT_80_STATE"
echo "PORT_80_LISTENER_COUNT=$PORT_80_COUNT"
echo "LOCAL_APPLICATION_STATE=healthy"
echo "LOCAL_HEALTH_STATE=healthy"
echo "BACKUP_STATE=removed"
echo "FAILURE_MARKER_STATE=removed"
echo "RECOVERY_STATUS=confirmed"

exit 0
'@

    $RecoveryCommandId = Send-SsmShellCommand `
        -InstanceId $InstanceId `
        -Comment "Lab 13 controlled Nginx service recovery" `
        -Script $RecoveryScript

    $RecoveryResult = Wait-SsmCommand `
        -CommandId $RecoveryCommandId `
        -InstanceId $InstanceId

    $RecoveryOutput = [string]$RecoveryResult.StandardOutputContent

    if ($RecoveryOutput -notmatch "(?m)^RECOVERY_STATUS=confirmed$") {
        throw (
            "The recovery command did not return the expected " +
            "completion confirmation."
        )
    }

    $ConfigurationState = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "CONFIGURATION_STATE"

    $ServiceState = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "SERVICE_STATE"

    $ProcessState = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "PROCESS_STATE"

    $ProcessCount = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "PROCESS_COUNT"

    $PortState = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "PORT_80_STATE"

    $PortListenerCount = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "PORT_80_LISTENER_COUNT"

    $LocalApplicationState = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "LOCAL_APPLICATION_STATE"

    $LocalHealthState = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "LOCAL_HEALTH_STATE"

    $BackupState = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "BACKUP_STATE"

    $FailureMarkerState = Get-RemoteValue `
        -Output $RecoveryOutput `
        -Name "FAILURE_MARKER_STATE"

    if ($ConfigurationState -ne "valid") {
        throw (
            "The restored Nginx configuration is not valid."
        )
    }

    if ($ServiceState -ne "active") {
        throw (
            "Nginx is not active after recovery. " +
            "Detected state: $ServiceState."
        )
    }

    if ($ProcessState -ne "present") {
        throw "No Nginx process is running after recovery."
    }

    if ([int]$ProcessCount -lt 1) {
        throw (
            "The reported Nginx process count is invalid: $ProcessCount."
        )
    }

    if ($PortState -ne "listening") {
        throw "TCP port 80 is not listening after recovery."
    }

    if ([int]$PortListenerCount -lt 1) {
        throw (
            "The reported TCP port 80 listener count is invalid: " +
            "$PortListenerCount."
        )
    }

    if ($LocalApplicationState -ne "healthy") {
        throw "The local application endpoint is not healthy."
    }

    if ($LocalHealthState -ne "healthy") {
        throw "The local health endpoint is not healthy."
    }

    if ($BackupState -ne "removed") {
        throw "The temporary configuration backup was not removed."
    }

    if ($FailureMarkerState -ne "removed") {
        throw "The controlled failure marker was not removed."
    }

    Write-Ok "The original Nginx configuration was restored."
    Write-Ok "The restored configuration passed nginx -t."
    Write-Ok "Nginx is active and its processes are running."
    Write-Ok "TCP port 80 is listening."
    Write-Ok "Local application and health endpoints are healthy."
    Write-Ok "Temporary failure artifacts were removed."

    Write-Step "External application validation"

    Wait-PublicApplicationHealthy `
        -PublicIpAddress $PublicIpAddress

    Write-Ok "The public application returned HTTP 200."
    Write-Ok "The public application content is healthy."
    Write-Ok "The public health endpoint is healthy."

    Write-Host ""
    Write-Host "APPLICATION RECOVERY COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green
    Write-Host ("Instance:              {0}" -f $InstanceId)
    Write-Host ("Public IPv4 address:   {0}" -f $PublicIpAddress)
    Write-Host (
        "Application URL:       http://{0}/" -f $PublicIpAddress
    )
    Write-Host (
        "Health URL:            http://{0}/health" -f $PublicIpAddress
    )
    Write-Host ("Configuration:         {0}" -f $ConfigurationState)
    Write-Host ("Nginx service:         {0}" -f $ServiceState)
    Write-Host ("Nginx process:         {0}" -f $ProcessState)
    Write-Host ("TCP port 80:           {0}" -f $PortState)
    Write-Host "Local HTTP:            healthy"
    Write-Host "Public HTTP:           healthy"
    Write-Host (
        "Next step: run test-aws-application-troubleshooting.ps1 again"
    )
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host (
        "Review the Systems Manager command output before attempting " +
        "another recovery or cleanup operation."
    ) -ForegroundColor Yellow

    exit 1
}
