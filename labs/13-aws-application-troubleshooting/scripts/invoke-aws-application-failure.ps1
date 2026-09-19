[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [switch]$ConfirmFailureInjection
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
Systems Manager command failed.

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

function Test-PublicApplicationHealthy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublicIpAddress
    )

    $Uri = "http://$PublicIpAddress/"

    try {
        $Response = Invoke-WebRequest `
            -Uri $Uri `
            -Method Get `
            -DisableKeepAlive `
            -TimeoutSec 10 `
            -UseBasicParsing

        $Body = [string]$Response.Content

        return (
            [int]$Response.StatusCode -eq 200 -and
            $Body -match "LAB13_STATUS=healthy"
        )
    }
    catch {
        return $false
    }
}

function Wait-PublicApplicationUnavailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublicIpAddress,

        [int]$MaximumAttempts = 12,

        [int]$DelaySeconds = 5
    )

    $Uri = "http://$PublicIpAddress/"
    $ConsecutiveFailures = 0

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        try {
            $Response = Invoke-WebRequest `
                -Uri $Uri `
                -Method Get `
                -DisableKeepAlive `
                -TimeoutSec 5 `
                -UseBasicParsing

            $ConsecutiveFailures = 0

            Write-InfoMessage (
                "The application still returned HTTP " +
                "$([int]$Response.StatusCode): " +
                "attempt $Attempt/$MaximumAttempts."
            )
        }
        catch {
            $ConsecutiveFailures++

            Write-InfoMessage (
                "Public HTTP request failed as expected: " +
                "attempt $Attempt/$MaximumAttempts, " +
                "consecutive failures $ConsecutiveFailures/3."
            )

            if ($ConsecutiveFailures -ge 3) {
                return
            }
        }

        if ($Attempt -lt $MaximumAttempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw (
        "The public application did not become consistently unavailable " +
        "after the controlled failure."
    )
}

Write-Host "Lab 13 - Controlled application failure injection"

try {
    Write-Step "Authorization and prerequisites"

    if (-not $ConfirmFailureInjection) {
        throw (
            "Failure injection was not authorized. Run this script with " +
            "-ConfirmFailureInjection."
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
        "AWS session validated and controlled failure explicitly authorized."
    )

    Write-Step "Lab 13 instance discovery"

    $Instance = Get-SingleRunningInstance
    $InstanceId = [string]$Instance.InstanceId
    $PublicIpAddress = [string]$Instance.PublicIpAddress

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
        "$InstanceId is running and online in AWS Systems Manager."
    )

    Write-Step "Healthy-state preflight"

    $PreflightScript = @'
set -euo pipefail

CONFIG="/etc/nginx/conf.d/lab13.conf"
BACKUP="${CONFIG}.lab13-backup"
MARKER="/var/tmp/lab13-failure-injected"

test -f "$CONFIG"

if test -e "$BACKUP"; then
    echo "A Lab 13 configuration backup already exists."
    exit 31
fi

if test -e "$MARKER"; then
    echo "The controlled failure marker already exists."
    exit 32
fi

systemctl is-active --quiet nginx
pgrep -x nginx >/dev/null
nginx -t

ss -lnt | awk '{print $4}' | grep -Eq '(^|:|\])80$'

curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    http://127.0.0.1/ |
    grep -q 'LAB13_STATUS=healthy'

curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    http://127.0.0.1/health |
    grep -q 'healthy'

echo "PREFLIGHT_STATUS=healthy"
'@

    $PreflightCommandId = Send-SsmShellCommand `
        -InstanceId $InstanceId `
        -Comment "Lab 13 healthy-state preflight" `
        -Script $PreflightScript

    $PreflightResult = Wait-SsmCommand `
        -CommandId $PreflightCommandId `
        -InstanceId $InstanceId

    if (
        [string]$PreflightResult.StandardOutputContent -notmatch
        "PREFLIGHT_STATUS=healthy"
    ) {
        throw (
            "The remote preflight command completed without returning " +
            "the expected healthy-state confirmation."
        )
    }

    if (-not (Test-PublicApplicationHealthy -PublicIpAddress $PublicIpAddress)) {
        throw (
            "The public application was not healthy before failure injection."
        )
    }

    Write-Ok "Nginx configuration, service, port, and local HTTP are healthy."
    Write-Ok "The public application is healthy before failure injection."

    Write-Step "Controlled Nginx configuration failure"

    $FailureScript = @'
set -euo pipefail

CONFIG="/etc/nginx/conf.d/lab13.conf"
BACKUP="${CONFIG}.lab13-backup"
TEMP_CONFIG="/var/tmp/lab13.conf.invalid"
MARKER="/var/tmp/lab13-failure-injected"
NGINX_TEST_OUTPUT="/var/tmp/lab13-nginx-test-error.txt"
RESTART_OUTPUT="/var/tmp/lab13-nginx-restart-error.txt"

test -f "$CONFIG"
test ! -e "$BACKUP"
test ! -e "$MARKER"

systemctl is-active --quiet nginx
nginx -t

cp --preserve=all "$CONFIG" "$BACKUP"
cp --preserve=all "$CONFIG" "$TEMP_CONFIG"

printf '\n# Lab 13 controlled failure\n' >> "$TEMP_CONFIG"
printf 'lab13_invalid_directive on;\n' >> "$TEMP_CONFIG"

install \
    --owner=root \
    --group=root \
    --mode=0644 \
    "$TEMP_CONFIG" \
    "$CONFIG"

rm -f "$TEMP_CONFIG"
touch "$MARKER"

if nginx -t >"$NGINX_TEST_OUTPUT" 2>&1; then
    cp --preserve=all "$BACKUP" "$CONFIG"
    rm -f "$BACKUP" "$MARKER"
    systemctl restart nginx

    echo "The intentionally invalid configuration passed nginx -t."
    exit 41
fi

if systemctl restart nginx >"$RESTART_OUTPUT" 2>&1; then
    cp --preserve=all "$BACKUP" "$CONFIG"
    rm -f "$BACKUP" "$MARKER"
    systemctl restart nginx

    echo "Nginx restarted despite the intentionally invalid configuration."
    exit 42
fi

sleep 3

if systemctl is-active --quiet nginx; then
    echo "Nginx remained active after the controlled failure."
    exit 43
fi

if pgrep -x nginx >/dev/null; then
    echo "An Nginx process remained active after the controlled failure."
    exit 44
fi

if ss -lnt | awk '{print $4}' | grep -Eq '(^|:|\])80$'; then
    echo "TCP port 80 remained in the listening state."
    exit 45
fi

if curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    http://127.0.0.1/ >/dev/null 2>&1
then
    echo "Local HTTP remained available after the controlled failure."
    exit 46
fi

echo "FAILURE_TYPE=invalid-nginx-configuration"
echo "FAILURE_MARKER=$MARKER"
echo "CONFIGURATION_BACKUP=$BACKUP"
echo "NGINX_SERVICE=inactive"
echo "NGINX_PROCESS=absent"
echo "TCP_PORT_80=not-listening"
echo "LOCAL_HTTP=unavailable"
echo "FAILURE_INJECTION=confirmed"
'@

    $FailureCommandId = Send-SsmShellCommand `
        -InstanceId $InstanceId `
        -Comment "Lab 13 controlled Nginx configuration failure" `
        -Script $FailureScript

    $FailureResult = Wait-SsmCommand `
        -CommandId $FailureCommandId `
        -InstanceId $InstanceId

    $FailureOutput = [string]$FailureResult.StandardOutputContent

    if ($FailureOutput -notmatch "FAILURE_INJECTION=confirmed") {
        throw (
            "The failure injection command completed without returning " +
            "the expected confirmation."
        )
    }

    Write-Ok "An invalid Nginx directive was introduced intentionally."
    Write-Ok "Nginx rejected the configuration and could not restart."
    Write-Ok "Nginx process and TCP port 80 are unavailable."

    Write-Step "External failure confirmation"

    Wait-PublicApplicationUnavailable `
        -PublicIpAddress $PublicIpAddress

    Write-Ok (
        "The application is consistently unavailable through public HTTP."
    )

    Write-Host ""
    Write-Host "CONTROLLED FAILURE INJECTION COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green
    Write-Host ("Instance:             {0}" -f $InstanceId)
    Write-Host ("Public IPv4 address:  {0}" -f $PublicIpAddress)
    Write-Host (
        "Application URL:      http://{0}/" -f $PublicIpAddress
    )
    Write-Host "Failure type:         Invalid Nginx configuration"
    Write-Host "Nginx service:        Inactive"
    Write-Host "TCP port 80:          Not listening"
    Write-Host "Public HTTP:          Unavailable"
    Write-Host (
        "Next step: run diagnose-aws-application-failure.ps1"
    )
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red

    Write-Host (
        "The script does not perform automatic recovery. " +
        "If the failure was introduced, run " +
        "recover-aws-application-service.ps1 -ConfirmRecovery."
    ) -ForegroundColor Yellow

    exit 1
}
