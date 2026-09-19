[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1"
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
Systems Manager diagnostic command failed.

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

function Get-DiagnosticValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Output,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $Pattern = "(?m)^" + [regex]::Escape($Name) + "=(.*)$"
    $Match = [regex]::Match($Output, $Pattern)

    if (-not $Match.Success) {
        throw "Diagnostic result '$Name' was not returned."
    }

    return $Match.Groups[1].Value.Trim()
}

function Test-PublicApplicationUnavailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublicIpAddress,

        [int]$Attempts = 3
    )

    $Uri = "http://$PublicIpAddress/"

    for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
        try {
            $Response = Invoke-WebRequest `
                -Uri $Uri `
                -Method Get `
                -DisableKeepAlive `
                -TimeoutSec 5 `
                -UseBasicParsing

            Write-InfoMessage (
                "Public HTTP unexpectedly returned status " +
                "$([int]$Response.StatusCode) on attempt " +
                "$Attempt/$Attempts."
            )

            return $false
        }
        catch {
            Write-InfoMessage (
                "Public HTTP request failed as expected: " +
                "attempt $Attempt/$Attempts."
            )
        }

        if ($Attempt -lt $Attempts) {
            Start-Sleep -Seconds 2
        }
    }

    return $true
}

Write-Host "Lab 13 - Read-only application failure diagnosis"

try {
    Write-Step "Prerequisites and instance discovery"

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

    Write-Ok "AWS session is authenticated."

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

    Write-Ok (
        "Lab 13 instance located: $InstanceId in $AvailabilityZone."
    )

    Write-Step "Systems Manager connectivity"

    $SsmInformation = Get-SsmInstanceInformation -InstanceId $InstanceId

    if ([string]$SsmInformation.PingStatus -ne "Online") {
        throw (
            "The Lab 13 instance is registered in Systems Manager, " +
            "but its status is $($SsmInformation.PingStatus)."
        )
    }

    Write-Ok "$InstanceId is online in AWS Systems Manager."

    Write-Step "Read-only operating system investigation"

    $DiagnosticScript = @'
set -u

CONFIG="/etc/nginx/conf.d/lab13.conf"
BACKUP="${CONFIG}.lab13-backup"
MARKER="/var/tmp/lab13-failure-injected"

echo "DIAGNOSTIC_BEGIN=1"

SERVICE_STATE="$(systemctl is-active nginx 2>/dev/null || true)"

if test -z "$SERVICE_STATE"; then
    SERVICE_STATE="unknown"
fi

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

if test -f "$CONFIG"; then
    CONFIG_FILE_STATE="present"
else
    CONFIG_FILE_STATE="absent"
fi

NGINX_TEST_OUTPUT="$(nginx -t 2>&1)"
NGINX_TEST_EXIT_CODE="$?"

if test "$NGINX_TEST_EXIT_CODE" -eq 0; then
    CONFIGURATION_STATE="valid"
else
    CONFIGURATION_STATE="invalid"
fi

if test -f "$CONFIG" &&
    grep -Eq '^[[:space:]]*lab13_invalid_directive[[:space:]]+on;' "$CONFIG"
then
    INVALID_DIRECTIVE_STATE="present"
else
    INVALID_DIRECTIVE_STATE="absent"
fi

if test -f "$BACKUP"; then
    BACKUP_STATE="present"
else
    BACKUP_STATE="absent"
fi

if test -f "$MARKER"; then
    FAILURE_MARKER_STATE="present"
else
    FAILURE_MARKER_STATE="absent"
fi

if curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    http://127.0.0.1/ >/dev/null 2>&1
then
    LOCAL_HTTP_STATE="available"
else
    LOCAL_HTTP_STATE="unavailable"
fi

if journalctl \
    --unit=nginx \
    --no-pager \
    --lines=30 2>/dev/null |
    grep -Eqi \
    'failed|invalid|unknown directive|emerg|configuration file'
then
    RELEVANT_LOG_STATE="present"
else
    RELEVANT_LOG_STATE="absent"
fi

echo "SERVICE_STATE=$SERVICE_STATE"
echo "PROCESS_STATE=$PROCESS_STATE"
echo "PROCESS_COUNT=$PROCESS_COUNT"
echo "PORT_80_STATE=$PORT_80_STATE"
echo "PORT_80_LISTENER_COUNT=$PORT_80_COUNT"
echo "CONFIG_FILE_STATE=$CONFIG_FILE_STATE"
echo "CONFIGURATION_STATE=$CONFIGURATION_STATE"
echo "NGINX_TEST_EXIT_CODE=$NGINX_TEST_EXIT_CODE"
echo "INVALID_DIRECTIVE_STATE=$INVALID_DIRECTIVE_STATE"
echo "BACKUP_STATE=$BACKUP_STATE"
echo "FAILURE_MARKER_STATE=$FAILURE_MARKER_STATE"
echo "LOCAL_HTTP_STATE=$LOCAL_HTTP_STATE"
echo "RELEVANT_LOG_STATE=$RELEVANT_LOG_STATE"

echo "NGINX_TEST_OUTPUT_BEGIN"
printf '%s\n' "$NGINX_TEST_OUTPUT"
echo "NGINX_TEST_OUTPUT_END"

echo "JOURNAL_OUTPUT_BEGIN"
journalctl \
    --unit=nginx \
    --no-pager \
    --lines=20 2>/dev/null ||
    true
echo "JOURNAL_OUTPUT_END"

echo "DIAGNOSTIC_COMPLETE=1"

exit 0
'@

    $CommandId = Send-SsmShellCommand `
        -InstanceId $InstanceId `
        -Comment "Lab 13 read-only application failure diagnosis" `
        -Script $DiagnosticScript

    $DiagnosticResult = Wait-SsmCommand `
        -CommandId $CommandId `
        -InstanceId $InstanceId

    $DiagnosticOutput = [string]$DiagnosticResult.StandardOutputContent

    if ($DiagnosticOutput -notmatch "(?m)^DIAGNOSTIC_COMPLETE=1$") {
        throw (
            "The remote diagnostic command did not return its " +
            "completion marker."
        )
    }

    Write-Ok "Read-only operating system investigation completed."

    Write-Step "Layer 1 - Service state"

    $ServiceState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "SERVICE_STATE"

    if ($ServiceState -notin @("inactive", "failed")) {
        throw (
            "Expected Nginx to be inactive or failed, " +
            "but its state is '$ServiceState'."
        )
    }

    Write-Ok "Nginx service is $ServiceState."

    Write-Step "Layer 2 - Process state"

    $ProcessState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "PROCESS_STATE"

    $ProcessCount = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "PROCESS_COUNT"

    if ($ProcessState -ne "absent" -or $ProcessCount -ne "0") {
        throw (
            "An Nginx process is still present. " +
            "State: $ProcessState; count: $ProcessCount."
        )
    }

    Write-Ok "No Nginx process is running."

    Write-Step "Layer 3 - TCP port"

    $PortState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "PORT_80_STATE"

    $PortListenerCount = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "PORT_80_LISTENER_COUNT"

    if (
        $PortState -ne "not-listening" -or
        $PortListenerCount -ne "0"
    ) {
        throw (
            "TCP port 80 is unexpectedly listening. " +
            "State: $PortState; listeners: $PortListenerCount."
        )
    }

    Write-Ok "TCP port 80 is not listening."

    Write-Step "Layer 4 - Nginx configuration"

    $ConfigFileState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "CONFIG_FILE_STATE"

    $ConfigurationState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "CONFIGURATION_STATE"

    $NginxTestExitCode = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "NGINX_TEST_EXIT_CODE"

    $InvalidDirectiveState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "INVALID_DIRECTIVE_STATE"

    $BackupState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "BACKUP_STATE"

    $FailureMarkerState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "FAILURE_MARKER_STATE"

    if ($ConfigFileState -ne "present") {
        throw "The Lab 13 Nginx configuration file is absent."
    }

    if ($ConfigurationState -ne "invalid") {
        throw (
            "Expected an invalid Nginx configuration, " +
            "but the detected state is '$ConfigurationState'."
        )
    }

    if ($NginxTestExitCode -eq "0") {
        throw "The nginx -t command unexpectedly succeeded."
    }

    if ($InvalidDirectiveState -ne "present") {
        throw (
            "The intentionally invalid Lab 13 directive was not found."
        )
    }

    if ($BackupState -ne "present") {
        throw "The original Nginx configuration backup was not found."
    }

    if ($FailureMarkerState -ne "present") {
        throw "The controlled failure marker was not found."
    }

    Write-Ok "The Nginx configuration file exists but is invalid."
    Write-Ok "The intentionally invalid directive was identified."
    Write-Ok "The valid configuration backup is preserved."
    Write-Ok "The controlled failure marker is present."

    $NginxTestMatch = [regex]::Match(
        $DiagnosticOutput,
        "(?s)NGINX_TEST_OUTPUT_BEGIN\r?\n(.*?)\r?\nNGINX_TEST_OUTPUT_END"
    )

    if ($NginxTestMatch.Success) {
        $NginxTestText = $NginxTestMatch.Groups[1].Value.Trim()

        if (-not [string]::IsNullOrWhiteSpace($NginxTestText)) {
            Write-Host ""
            Write-Host "nginx -t output:" -ForegroundColor Yellow
            Write-Host $NginxTestText
        }
    }

    Write-Step "Layer 5 - Local HTTP and system logs"

    $LocalHttpState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "LOCAL_HTTP_STATE"

    $RelevantLogState = Get-DiagnosticValue `
        -Output $DiagnosticOutput `
        -Name "RELEVANT_LOG_STATE"

    if ($LocalHttpState -ne "unavailable") {
        throw (
            "Local HTTP is unexpectedly available on the instance."
        )
    }

    if ($RelevantLogState -ne "present") {
        throw (
            "The Nginx journal does not contain an identifiable " +
            "configuration or service failure."
        )
    }

    Write-Ok "Local HTTP is unavailable."
    Write-Ok "The system journal contains evidence of the Nginx failure."

    $JournalMatch = [regex]::Match(
        $DiagnosticOutput,
        "(?s)JOURNAL_OUTPUT_BEGIN\r?\n(.*?)\r?\nJOURNAL_OUTPUT_END"
    )

    if ($JournalMatch.Success) {
        $JournalText = $JournalMatch.Groups[1].Value.Trim()

        if (-not [string]::IsNullOrWhiteSpace($JournalText)) {
            Write-Host ""
            Write-Host "Recent Nginx journal entries:" `
                -ForegroundColor Yellow
            Write-Host $JournalText
        }
    }

    Write-Step "External application validation"

    $PublicHttpUnavailable = Test-PublicApplicationUnavailable `
        -PublicIpAddress $PublicIpAddress

    if (-not $PublicHttpUnavailable) {
        throw (
            "The application still returned an external HTTP response."
        )
    }

    Write-Ok "The application is unavailable through public HTTP."

    Write-Step "Root cause"

    Write-Ok (
        "Root cause identified: an intentionally invalid directive " +
        "prevents the Nginx configuration from passing nginx -t."
    )

    Write-Ok (
        "Because Nginx cannot load the configuration, the service " +
        "is inactive, no process is running, TCP port 80 is not " +
        "listening, and HTTP is unavailable."
    )

    Write-Host ""
    Write-Host "DIAGNOSIS COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green
    Write-Host ("Instance:              {0}" -f $InstanceId)
    Write-Host ("Public IPv4 address:   {0}" -f $PublicIpAddress)
    Write-Host ("Service state:         {0}" -f $ServiceState)
    Write-Host ("Nginx process:         {0}" -f $ProcessState)
    Write-Host ("TCP port 80:           {0}" -f $PortState)
    Write-Host ("Configuration:         {0}" -f $ConfigurationState)
    Write-Host (
        "Invalid directive:     {0}" -f $InvalidDirectiveState
    )
    Write-Host ("Local HTTP:            {0}" -f $LocalHttpState)
    Write-Host "Public HTTP:           unavailable"
    Write-Host "Root cause:            Invalid Nginx configuration"
    Write-Host (
        "Next step: run recover-aws-application-service.ps1 " +
        "-ConfirmRecovery"
    )
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host (
        "No recovery or configuration change was performed by this " +
        "diagnostic script."
    ) -ForegroundColor Yellow

    exit 1
}
