[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [switch]$ConfirmRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"

$InstanceName = "lab10-linux-web-server"
$SecurityGroupName = "lab10-linux-web-sg"
$RoleName = "lab10-ec2-ssm-role"
$InstanceProfileName = "lab10-ec2-ssm-instance-profile"

$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

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

function Assert-Lab10Tags {
    param(
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$ResourceName
    )

    $TagMap = @{}

    foreach ($Tag in @($Tags)) {
        $TagMap[[string]$Tag.Key] = [string]$Tag.Value
    }

    if (
        $TagMap["Project"] -ne "cloud-infrastructure-operations-lab" -or
        $TagMap["Environment"] -ne "lab" -or
        $TagMap["Lab"] -ne "10" -or
        $TagMap["ManagedBy"] -ne "aws-cli" -or
        $TagMap["Owner"] -ne "itamarsb"
    ) {
        throw "$ResourceName does not contain the complete expected Lab 10 tags."
    }
}

if (-not $ConfirmRemoval) {
    Write-Host "Removal was not authorized." -ForegroundColor Yellow
    Write-Host "Run this script again with -ConfirmRemoval."

    exit 1
}

try {
    Write-Host "Lab 10 - Controlled cleanup"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    $null = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    Write-Step "EC2 instance"

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
        Assert-Lab10Tags `
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

        Write-Ok "EC2 instance terminated."

        Write-Info "Waiting 5 seconds for network interface release."
        Start-Sleep -Seconds 5
    }
    else {
        Write-Info "EC2 instance was not found."
    }

    Write-Step "Security Group"

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
        Assert-Lab10Tags `
            -Tags @($SecurityGroups[0].Tags) `
            -ResourceName "Security Group"

        Invoke-AwsCommand -Arguments @(
            "ec2",
            "delete-security-group",
            "--group-id",
            $SecurityGroups[0].GroupId
        )

        Write-Ok "Security Group deleted."
    }
    else {
        Write-Info "Security Group was not found."
    }

    Write-Step "IAM"

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

        Assert-Lab10Tags `
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

        Assert-Lab10Tags `
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

    Write-Ok "IAM resources removed or already absent."

    Write-Step "Final validation"

    $RemainingInstanceResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $RemainingInstances = @(
        foreach ($Reservation in @($RemainingInstanceResult.Reservations)) {
            @($Reservation.Instances)
        }
    )

    $RemainingSecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$SecurityGroupName"
    )

    $RemainingSecurityGroups = @(
        $RemainingSecurityGroupResult.SecurityGroups
    )

    $RoleStillExists = Test-AwsResource -Arguments @(
        "iam",
        "get-role",
        "--role-name",
        $RoleName
    )

    $ProfileStillExists = Test-AwsResource -Arguments @(
        "iam",
        "get-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName
    )

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $Vpcs = @($VpcResult.Vpcs)

    $SubnetResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=tag:Name,Values=$SubnetName",
        "Name=state,Values=available"
    )

    $Subnets = @($SubnetResult.Subnets)

    Write-Host "Active Lab 10 instances:       $($RemainingInstances.Count)"
    Write-Host "Lab 10 Security Groups:         $($RemainingSecurityGroups.Count)"
    Write-Host "Lab 10 IAM Role exists:         $RoleStillExists"
    Write-Host "Lab 10 Instance Profile exists: $ProfileStillExists"
    Write-Host "Available Lab 08 VPCs:          $($Vpcs.Count)"
    Write-Host "Available Lab 08 subnets:       $($Subnets.Count)"

    if (
        $RemainingInstances.Count -ne 0 -or
        $RemainingSecurityGroups.Count -ne 0 -or
        $RoleStillExists -or
        $ProfileStillExists
    ) {
        throw "One or more active Lab 10 resources remain in the account."
    }

    if (
        $Vpcs.Count -ne 1 -or
        $Subnets.Count -ne 1
    ) {
        throw "The expected Lab 08 network was not preserved."
    }

    Write-Ok "No active Lab 10 resources remain."
    Write-Ok "Lab 08 VPC and subnet were preserved."

    Write-Host ""
    Write-Host "CLEANUP COMPLETED" -ForegroundColor Green

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red

    exit 1
}
