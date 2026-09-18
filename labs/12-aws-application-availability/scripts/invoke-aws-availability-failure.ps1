[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [switch]$ConfirmFailureTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceAName = "lab12-availability-instance-a"
$InstanceBName = "lab12-availability-instance-b"
$LoadBalancerName = "lab12-availability-alb"
$TargetGroupName = "lab12-availability-tg"

$FailureIntroduced = $false
$RecoveryInstanceId = $null
$RecoveryTargetGroupArn = $null
$ScriptSucceeded = $false
$FailureMessage = $null

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

function Write-Info {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $Output = @(
            & aws @Arguments `
                --profile $ProfileName `
                --region $Region `
                --output json `
                --no-cli-pager 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    $Text = (
        $Output |
            ForEach-Object { "$_" }
    ) -join [Environment]::NewLine

    if ($ExitCode -ne 0) {
        throw "AWS CLI failed: aws $($Arguments -join ' ')$([Environment]::NewLine)$Text"
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    return $Text | ConvertFrom-Json
}

function Get-TagValue {
    param(
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $Matches = @(
        $Tags |
            Where-Object {
                $null -ne $_ -and
                [string]$_.Key -eq $Key
            }
    )

    if ($Matches.Count -ne 1) {
        return $null
    }

    return [string]$Matches[0].Value
}

function Invoke-SsmShellCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string]$Comment,

        [Parameter(Mandatory = $true)]
        [string]$OperationName
    )

    $Parameters = @{
        commands = @(
            $Command
        )
    } | ConvertTo-Json -Depth 3

    $SafeOperationName = $OperationName -replace "[^a-zA-Z0-9-]", "-"
    $TemporaryPath = Join-Path `
        -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "lab12-$SafeOperationName-parameters.json"

    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $TemporaryPath,
        $Parameters,
        $Utf8WithoutBom
    )

    $ParametersFilePath = (
        Resolve-Path -LiteralPath $TemporaryPath
    ).Path -replace "\\", "/"

    $ParametersArgument = "file://$ParametersFilePath"

    try {
        $CommandResult = Invoke-AwsJson -Arguments @(
            "ssm",
            "send-command",
            "--instance-ids",
            $InstanceId,
            "--document-name",
            "AWS-RunShellScript",
            "--comment",
            $Comment,
            "--parameters",
            $ParametersArgument
        )
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
    }

    $CommandId = [string]$CommandResult.Command.CommandId
    $Invocation = $null

    if ([string]::IsNullOrWhiteSpace($CommandId)) {
        throw "Systems Manager did not return a command ID for $OperationName."
    }

    for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
        Start-Sleep -Seconds 2

        try {
            $Invocation = Invoke-AwsJson -Arguments @(
                "ssm",
                "get-command-invocation",
                "--command-id",
                $CommandId,
                "--instance-id",
                $InstanceId
            )
        }
        catch {
            if ($_.Exception.Message -match "InvocationDoesNotExist") {
                continue
            }

            throw
        }

        if ($Invocation.Status -eq "Success") {
            return $Invocation
        }

        if (
            $Invocation.Status -in @(
                "Cancelled",
                "TimedOut",
                "Failed",
                "Cancelling"
            )
        ) {
            $ErrorText = [string]$Invocation.StandardErrorContent
            throw "Systems Manager operation $OperationName failed with status $($Invocation.Status). $ErrorText"
        }
    }

    throw "Systems Manager operation $OperationName did not complete in time."
}

function Get-TargetHealthState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetGroupArn,

        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    $Result = Invoke-AwsJson -Arguments @(
        "elbv2",
        "describe-target-health",
        "--target-group-arn",
        $TargetGroupArn,
        "--targets",
        "Id=$InstanceId,Port=80"
    )

    $Descriptions = @(
        $Result.TargetHealthDescriptions |
            Where-Object { $null -ne $_ }
    )

    if ($Descriptions.Count -ne 1) {
        return "missing"
    }

    return [string]$Descriptions[0].TargetHealth.State
}

function Wait-TargetState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetGroupArn,

        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("healthy", "unhealthy")]
        [string]$ExpectedState,

        [int]$MaximumAttempts = 40
    )

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        $State = Get-TargetHealthState `
            -TargetGroupArn $TargetGroupArn `
            -InstanceId $InstanceId

        if ($State -eq $ExpectedState) {
            return
        }

        Write-Info "Waiting for target $InstanceId to become $ExpectedState`: attempt $Attempt/$MaximumAttempts (current: $State)."
        Start-Sleep -Seconds 10
    }

    throw "Target $InstanceId did not become $ExpectedState within the expected time."
}

function Test-ApplicationContinuity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationUrl,

        [Parameter(Mandatory = $true)]
        [ValidateSet("A", "B")]
        [string]$ExpectedBackend,

        [int]$RequestCount = 20
    )

    $SuccessfulRequests = 0
    $UnexpectedBackends = @()

    for ($Attempt = 1; $Attempt -le $RequestCount; $Attempt++) {
        $RequestUrl = "$ApplicationUrl`?failure-test=$Attempt"

        try {
            $Response = Invoke-WebRequest `
                -Uri $RequestUrl `
                -UseBasicParsing `
                -TimeoutSec 15 `
                -DisableKeepAlive

            if (
                $Response.StatusCode -ne 200 -or
                $Response.Content -notmatch "Lab 12"
            ) {
                throw "Unexpected HTTP response."
            }

            if (
                $Response.Content -notmatch
                "backend <strong>(A|B)</strong>"
            ) {
                throw "Backend identifier was not found in the response."
            }

            $ObservedBackend = [string]$Matches[1]

            if ($ObservedBackend -ne $ExpectedBackend) {
                $UnexpectedBackends += $ObservedBackend
            }

            $SuccessfulRequests++
        }
        catch {
            throw "Application continuity request $Attempt failed: $($_.Exception.Message)"
        }

        Start-Sleep -Milliseconds 500
    }

    if ($SuccessfulRequests -ne $RequestCount) {
        throw "Not all application continuity requests succeeded."
    }

    if ($UnexpectedBackends.Count -gt 0) {
        throw "Traffic reached an unexpected backend while one target was unhealthy."
    }

    return $SuccessfulRequests
}

try {
    Write-Host "Lab 12 - Controlled backend failure and recovery"

    Write-Step "Authorization and prerequisites"

    if (-not $ConfirmFailureTest) {
        throw "Controlled failure was not authorized. Use -ConfirmFailureTest."
    }

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    $null = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    Write-Ok "AWS session validated and controlled failure explicitly authorized."

    Write-Step "Lab 12 resources"

    $InstanceResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--filters",
        "Name=tag:Project,Values=cloud-infrastructure-operations-lab",
        "Name=tag:Lab,Values=12",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $Instances = @(
        foreach ($Reservation in @($InstanceResult.Reservations)) {
            @(
                $Reservation.Instances |
                    Where-Object { $null -ne $_ }
            )
        }
    )

    if ($Instances.Count -ne 2) {
        throw "Exactly two active Lab 12 instances are required."
    }

    $BackendAInstances = @(
        $Instances |
            Where-Object {
                (Get-TagValue -Tags @($_.Tags) -Key "Name") -eq
                $InstanceAName -and
                (Get-TagValue -Tags @($_.Tags) -Key "Backend") -eq
                "A"
            }
    )

    $BackendBInstances = @(
        $Instances |
            Where-Object {
                (Get-TagValue -Tags @($_.Tags) -Key "Name") -eq
                $InstanceBName -and
                (Get-TagValue -Tags @($_.Tags) -Key "Backend") -eq
                "B"
            }
    )

    if (
        $BackendAInstances.Count -ne 1 -or
        $BackendBInstances.Count -ne 1
    ) {
        throw "Backends A and B cannot be identified uniquely."
    }

    $BackendA = $BackendAInstances[0]
    $BackendB = $BackendBInstances[0]
    $BackendAId = [string]$BackendA.InstanceId
    $BackendBId = [string]$BackendB.InstanceId

    if (
        $BackendA.State.Name -ne "running" -or
        $BackendB.State.Name -ne "running"
    ) {
        throw "Both Lab 12 instances must be running."
    }

    $TargetGroupResult = Invoke-AwsJson -Arguments @(
        "elbv2",
        "describe-target-groups",
        "--names",
        $TargetGroupName
    )

    $TargetGroups = @(
        $TargetGroupResult.TargetGroups |
            Where-Object { $null -ne $_ }
    )

    if ($TargetGroups.Count -ne 1) {
        throw "Exactly one Lab 12 Target Group is required."
    }

    $TargetGroupArn = [string]$TargetGroups[0].TargetGroupArn

    $LoadBalancerResult = Invoke-AwsJson -Arguments @(
        "elbv2",
        "describe-load-balancers",
        "--names",
        $LoadBalancerName
    )

    $LoadBalancers = @(
        $LoadBalancerResult.LoadBalancers |
            Where-Object { $null -ne $_ }
    )

    if (
        $LoadBalancers.Count -ne 1 -or
        $LoadBalancers[0].State.Code -ne "active"
    ) {
        throw "The Lab 12 Application Load Balancer must exist and be active."
    }

    $ApplicationUrl = "http://$([string]$LoadBalancers[0].DNSName)/"

    $HealthResult = Invoke-AwsJson -Arguments @(
        "elbv2",
        "describe-target-health",
        "--target-group-arn",
        $TargetGroupArn
    )

    $TargetDescriptions = @(
        $HealthResult.TargetHealthDescriptions |
            Where-Object { $null -ne $_ }
    )

    $HealthyIds = @(
        $TargetDescriptions |
            Where-Object { $_.TargetHealth.State -eq "healthy" } |
            ForEach-Object { [string]$_.Target.Id }
    )

    if (
        $TargetDescriptions.Count -ne 2 -or
        $HealthyIds -notcontains $BackendAId -or
        $HealthyIds -notcontains $BackendBId
    ) {
        throw "Both Lab 12 targets must be healthy before the failure test."
    }

    foreach ($InstanceId in @($BackendAId, $BackendBId)) {
        $SsmResult = Invoke-AwsJson -Arguments @(
            "ssm",
            "describe-instance-information",
            "--filters",
            "Key=InstanceIds,Values=$InstanceId"
        )

        $ManagedNodes = @(
            $SsmResult.InstanceInformationList |
                Where-Object { $null -ne $_ }
        )

        if (
            $ManagedNodes.Count -ne 1 -or
            $ManagedNodes[0].PingStatus -ne "Online"
        ) {
            throw "Instance $InstanceId must be online in Systems Manager."
        }
    }

    Write-Ok "Backends A and B are running, managed, and healthy."
    Write-Ok "Application Load Balancer and Target Group are ready."

    Write-Step "Controlled failure"

    $RecoveryInstanceId = $BackendAId
    $RecoveryTargetGroupArn = $TargetGroupArn
    $FailureIntroduced = $true

    $StopInvocation = Invoke-SsmShellCommand `
        -InstanceId $BackendAId `
        -Command "set -e; systemctl stop nginx; if systemctl is-active --quiet nginx; then exit 1; fi; printf 'LAB12_NGINX_STOPPED\n'" `
        -Comment "Lab 12 controlled Nginx failure on backend A" `
        -OperationName "stop-backend-a"

    if (
        [string]$StopInvocation.StandardOutputContent -notmatch
        "LAB12_NGINX_STOPPED"
    ) {
        throw "The controlled Nginx stop was not confirmed."
    }

    Write-Ok "Nginx was stopped on backend A through Systems Manager."

    Write-Step "Degraded target state"

    Wait-TargetState `
        -TargetGroupArn $TargetGroupArn `
        -InstanceId $BackendAId `
        -ExpectedState "unhealthy"

    $BackendBState = Get-TargetHealthState `
        -TargetGroupArn $TargetGroupArn `
        -InstanceId $BackendBId

    if ($BackendBState -ne "healthy") {
        throw "Backend B is not healthy during the controlled failure."
    }

    Write-Ok "Backend A is unhealthy and backend B remains healthy."

    Write-Step "Application continuity"

    $SuccessfulRequests = Test-ApplicationContinuity `
        -ApplicationUrl $ApplicationUrl `
        -ExpectedBackend "B" `
        -RequestCount 20

    Write-Ok "$SuccessfulRequests HTTP requests succeeded through backend B."
    Write-Ok "Application remained available during the backend A failure."

    Write-Step "Backend recovery"

    $StartInvocation = Invoke-SsmShellCommand `
        -InstanceId $BackendAId `
        -Command "set -e; systemctl start nginx; systemctl is-active nginx; curl -fsS http://localhost/health | grep -q healthy; printf 'LAB12_NGINX_RECOVERED\n'" `
        -Comment "Lab 12 Nginx recovery on backend A" `
        -OperationName "recover-backend-a"

    if (
        [string]$StartInvocation.StandardOutputContent -notmatch
        "LAB12_NGINX_RECOVERED"
    ) {
        throw "The Nginx recovery was not confirmed."
    }

    Wait-TargetState `
        -TargetGroupArn $TargetGroupArn `
        -InstanceId $BackendAId `
        -ExpectedState "healthy"

    $BackendBState = Get-TargetHealthState `
        -TargetGroupArn $TargetGroupArn `
        -InstanceId $BackendBId

    if ($BackendBState -ne "healthy") {
        throw "Backend B is not healthy after backend A recovery."
    }

    $FailureIntroduced = $false

    Write-Ok "Backend A returned to the healthy state."
    Write-Ok "Both targets are healthy after recovery."

    $ScriptSucceeded = $true
}
catch {
    $FailureMessage = $_.Exception.Message
}
finally {
    if (
        $FailureIntroduced -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$RecoveryInstanceId
        )
    ) {
        Write-Step "Mandatory recovery attempt"

        try {
            $null = Invoke-SsmShellCommand `
                -InstanceId $RecoveryInstanceId `
                -Command "set -e; systemctl start nginx; systemctl is-active nginx; curl -fsS http://localhost/health | grep -q healthy; printf 'LAB12_EMERGENCY_RECOVERY_OK\n'" `
                -Comment "Lab 12 mandatory recovery after failure test error" `
                -OperationName "mandatory-recovery"

            Write-Ok "Nginx was started during the mandatory recovery attempt."

            if (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$RecoveryTargetGroupArn
                )
            ) {
                Wait-TargetState `
                    -TargetGroupArn $RecoveryTargetGroupArn `
                    -InstanceId $RecoveryInstanceId `
                    -ExpectedState "healthy"

                Write-Ok "Backend A returned to healthy during mandatory recovery."
            }

            $FailureIntroduced = $false
        }
        catch {
            Write-Host "[FAIL] Mandatory recovery failed: $($_.Exception.Message)" `
                -ForegroundColor Red

            Write-Host "Start Nginx manually on $RecoveryInstanceId before continuing." `
                -ForegroundColor Yellow
        }
    }
}

if (-not $ScriptSucceeded) {
    Write-Host ""
    Write-Host "[FAIL] $FailureMessage" -ForegroundColor Red

    if ($FailureIntroduced) {
        Write-Host "Backend A may still be unavailable. Manual recovery is required." `
            -ForegroundColor Yellow
    }

    exit 1
}

Write-Host ""
Write-Host "CONTROLLED FAILURE TEST COMPLETED SUCCESSFULLY" `
    -ForegroundColor Green

Write-Host "Failed backend:      $BackendAId"
Write-Host "Healthy backend:     $BackendBId"
Write-Host "Application URL:     $ApplicationUrl"
Write-Host "Continuity requests: $SuccessfulRequests"
Write-Host "Final backend A:     healthy"
Write-Host "Final backend B:     healthy"
Write-Host "Next step: run test-aws-application-availability.ps1 again"

exit 0
