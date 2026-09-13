[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [switch]$ConfirmRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab09-managed-instance"
$SecurityGroupName = "lab09-managed-instance-sg"
$RoleName = "lab09-ec2-ssm-role"
$InstanceProfileName = "lab09-ec2-ssm-instance-profile"

$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

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

function Invoke-AwsCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$IgnoreNotFound
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $Output = @(
            & aws @Arguments `
                --profile $ProfileName `
                --region $Region `
                --no-cli-pager 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($ExitCode -ne 0) {
        $Text = (
            $Output |
                ForEach-Object { "$_" }
        ) -join [Environment]::NewLine

        if (
            $IgnoreNotFound -and
            $Text -match "NoSuchEntity|InvalidGroup.NotFound"
        ) {
            return
        }

        throw "AWS CLI failed: aws $($Arguments -join ' ')$([Environment]::NewLine)$Text"
    }
}

function Test-AwsResource {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $null = & aws @Arguments `
            --profile $ProfileName `
            --region $Region `
            --no-cli-pager 2>&1

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    return ($ExitCode -eq 0)
}

function Assert-Lab09Tags {
    param(
        [object[]]$Tags,
        [string]$ResourceName
    )

    $TagMap = @{}

    foreach ($Tag in @($Tags)) {
        $TagMap[[string]$Tag.Key] = [string]$Tag.Value
    }

    if (
        $TagMap["Lab"] -ne "09" -or
        $TagMap["Owner"] -ne "itamarsb"
    ) {
        throw "$ResourceName does not contain the expected Lab=09 and Owner=itamarsb tags."
    }
}

if (-not $ConfirmRemoval) {
    Write-Host "Removal was not authorized." -ForegroundColor Yellow
    Write-Host "Run this script again with -ConfirmRemoval."

    exit 1
}

try {
    Write-Host "Lab 09 - Controlled cleanup"

    $null = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    Write-Host ""
    Write-Host "=== EC2 instance ===" -ForegroundColor Cyan

    $InstanceResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $Instances = @(
        foreach ($Reservation in @($InstanceResult.Reservations)) {
            @($Reservation.Instances)
        }
    )

    if ($Instances.Count -gt 1) {
        throw "More than one matching EC2 instance was found."
    }

    if ($Instances.Count -eq 1) {
        Assert-Lab09Tags `
            -Tags @($Instances[0].Tags) `
            -ResourceName "EC2 instance"

        $InstanceId = [string]$Instances[0].InstanceId

        Invoke-AwsCommand -Arguments @(
            "ec2",
            "terminate-instances",
            "--instance-ids",
            $InstanceId
        )

        Invoke-AwsCommand -Arguments @(
            "ec2",
            "wait",
            "instance-terminated",
            "--instance-ids",
            $InstanceId
        )

        Write-Host "[OK] EC2 instance terminated." -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] EC2 instance was not found." -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "=== Security Group ===" -ForegroundColor Cyan

    $SecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$SecurityGroupName"
    )

    $SecurityGroups = @($SecurityGroupResult.SecurityGroups)

    if ($SecurityGroups.Count -gt 1) {
        throw "More than one matching Security Group was found."
    }

    if ($SecurityGroups.Count -eq 1) {
        Assert-Lab09Tags `
            -Tags @($SecurityGroups[0].Tags) `
            -ResourceName "Security Group"

        Invoke-AwsCommand -Arguments @(
            "ec2",
            "delete-security-group",
            "--group-id",
            $SecurityGroups[0].GroupId
        )

        Write-Host "[OK] Security Group deleted." -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Security Group was not found." -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "=== IAM ===" -ForegroundColor Cyan

    $RoleExists = Test-AwsResource -Arguments @(
        "iam",
        "get-role",
        "--role-name",
        $RoleName
    )

    $ProfileExists = Test-AwsResource -Arguments @(
        "iam",
        "get-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName
    )

    if ($RoleExists) {
        $RoleTagResult = Invoke-AwsJson -Arguments @(
            "iam",
            "list-role-tags",
            "--role-name",
            $RoleName
        )

        Assert-Lab09Tags `
            -Tags @($RoleTagResult.Tags) `
            -ResourceName "IAM role"
    }

    if ($ProfileExists) {
        $ProfileTagResult = Invoke-AwsJson -Arguments @(
            "iam",
            "list-instance-profile-tags",
            "--instance-profile-name",
            $InstanceProfileName
        )

        Assert-Lab09Tags `
            -Tags @($ProfileTagResult.Tags) `
            -ResourceName "Instance Profile"
    }

    Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "remove-role-from-instance-profile",
            "--instance-profile-name",
            $InstanceProfileName,
            "--role-name",
            $RoleName
        ) `
        -IgnoreNotFound

    Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "delete-instance-profile",
            "--instance-profile-name",
            $InstanceProfileName
        ) `
        -IgnoreNotFound

    Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "detach-role-policy",
            "--role-name",
            $RoleName,
            "--policy-arn",
            $PolicyArn
        ) `
        -IgnoreNotFound

    Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "delete-role",
            "--role-name",
            $RoleName
        ) `
        -IgnoreNotFound

    Write-Host "[OK] IAM resources removed or already absent." -ForegroundColor Green

    Write-Host ""
    Write-Host "CLEANUP COMPLETED" -ForegroundColor Green
    Write-Host "Lab 08 network resources were not modified."

    exit 0
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
