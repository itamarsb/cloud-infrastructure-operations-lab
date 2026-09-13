[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab09-managed-instance"
$SecurityGroupName = "lab09-managed-instance-sg"
$RoleName = "lab09-ec2-ssm-role"
$InstanceProfileName = "lab09-ec2-ssm-instance-profile"

$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$Failures = 0

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

    return $Text | ConvertFrom-Json
}

function Assert-Check {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        Write-Host "[OK] $Message" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:Failures++
    }
}

try {
    Write-Host "Lab 09 - Read-only validation"

    $null = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    $Result = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $Instances = @(
        foreach ($Reservation in @($Result.Reservations)) {
            @($Reservation.Instances)
        }
    )

    Assert-Check `
        -Condition ($Instances.Count -eq 1) `
        -Message "Exactly one Lab 09 EC2 instance exists."

    if ($Instances.Count -ne 1) {
        throw "The instance cannot be validated uniquely."
    }

    $Instance = $Instances[0]
    $InstanceId = [string]$Instance.InstanceId

    Assert-Check `
        -Condition ($Instance.State.Name -eq "running") `
        -Message "EC2 instance is running."

    Assert-Check `
        -Condition ([string]::IsNullOrWhiteSpace([string]$Instance.KeyName)) `
        -Message "No SSH Key Pair is associated."

    Assert-Check `
        -Condition ($Instance.MetadataOptions.HttpTokens -eq "required") `
        -Message "IMDSv2 tokens are mandatory."

    Assert-Check `
        -Condition ($Instance.IamInstanceProfile.Arn -match "/$([regex]::Escape($InstanceProfileName))$") `
        -Message "Expected Instance Profile is associated."

    Assert-Check `
        -Condition (@($Instance.SecurityGroups).Count -eq 1) `
        -Message "Exactly one Security Group is associated."

    Assert-Check `
        -Condition ($Instance.SecurityGroups[0].GroupName -eq $SecurityGroupName) `
        -Message "Expected Security Group is associated."

    $SecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--group-ids",
        $Instance.SecurityGroups[0].GroupId
    )

    Assert-Check `
        -Condition (@($SecurityGroupResult.SecurityGroups[0].IpPermissions).Count -eq 0) `
        -Message "Security Group has no ingress rules."

    $RootDevice = [string]$Instance.RootDeviceName

    $RootMappings = @(
        $Instance.BlockDeviceMappings |
            Where-Object { $_.DeviceName -eq $RootDevice }
    )

    Assert-Check `
        -Condition ($RootMappings.Count -eq 1) `
        -Message "Root EBS volume is associated."

    if ($RootMappings.Count -eq 1) {
        $VolumeResult = Invoke-AwsJson -Arguments @(
            "ec2",
            "describe-volumes",
            "--volume-ids",
            $RootMappings[0].Ebs.VolumeId
        )

        Assert-Check `
            -Condition ([bool]$VolumeResult.Volumes[0].Encrypted) `
            -Message "Root EBS volume is encrypted."

        Assert-Check `
            -Condition ($VolumeResult.Volumes[0].VolumeType -eq "gp3") `
            -Message "Root EBS volume uses gp3."

        Assert-Check `
            -Condition ([bool]$RootMappings[0].Ebs.DeleteOnTermination) `
            -Message "Root EBS volume will be deleted with the instance."
    }

    $RoleResult = Invoke-AwsJson -Arguments @(
        "iam",
        "get-role",
        "--role-name",
        $RoleName
    )

    Assert-Check `
        -Condition ($RoleResult.Role.RoleName -eq $RoleName) `
        -Message "IAM role exists."

    $PolicyResult = Invoke-AwsJson -Arguments @(
        "iam",
        "list-attached-role-policies",
        "--role-name",
        $RoleName
    )

    Assert-Check `
        -Condition (@($PolicyResult.AttachedPolicies.PolicyArn) -contains $PolicyArn) `
        -Message "AmazonSSMManagedInstanceCore is attached."

    $ProfileResult = Invoke-AwsJson -Arguments @(
        "iam",
        "get-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName
    )

    Assert-Check `
        -Condition (@($ProfileResult.InstanceProfile.Roles.RoleName) -contains $RoleName) `
        -Message "IAM role belongs to the Instance Profile."

    $SsmResult = Invoke-AwsJson -Arguments @(
        "ssm",
        "describe-instance-information",
        "--filters",
        "Key=InstanceIds,Values=$InstanceId"
    )

    $ManagedNodes = @($SsmResult.InstanceInformationList)

    Assert-Check `
        -Condition ($ManagedNodes.Count -eq 1) `
        -Message "Instance is registered in Systems Manager."

    if ($ManagedNodes.Count -eq 1) {
        Assert-Check `
            -Condition ($ManagedNodes[0].PingStatus -eq "Online") `
            -Message "Systems Manager reports the instance as online."
    }

    Write-Host ""

    if ($Failures -gt 0) {
        Write-Host "VALIDATION FAILED: $Failures check(s) failed." -ForegroundColor Red
        exit 1
    }

    Write-Host "VALIDATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "Instance ID: $InstanceId"

    exit 0
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
