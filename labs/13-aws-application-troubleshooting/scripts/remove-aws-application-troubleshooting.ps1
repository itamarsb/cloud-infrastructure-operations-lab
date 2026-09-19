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

$InstanceName = "lab13-troubleshooting-instance"
$SecurityGroupName = "lab13-troubleshooting-sg"
$RoleName = "lab13-ec2-troubleshooting-role"
$InstanceProfileName = "lab13-ec2-troubleshooting-instance-profile"

$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

$ExpectedTags = @{
    Project     = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab         = "13"
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

function Invoke-AwsCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
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

    return $Output.Trim()
}

function Invoke-AwsProbe {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $Output = & aws @Arguments 2>&1 | Out-String

    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = $Output.Trim()
    }
}

function Convert-TagsToHashtable {
    param(
        [AllowNull()]
        [object[]]$Tags
    )

    $TagTable = @{}

    foreach ($Tag in @($Tags)) {
        $Key = [string]$Tag.Key
        $Value = [string]$Tag.Value

        if (-not [string]::IsNullOrWhiteSpace($Key)) {
            $TagTable[$Key] = $Value
        }
    }

    return $TagTable
}

function Assert-ExpectedTags {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ActualTags,

        [Parameter(Mandatory = $true)]
        [string]$ResourceDescription
    )

    foreach ($Key in $ExpectedTags.Keys) {
        if (-not $ActualTags.ContainsKey($Key)) {
            throw (
                "$ResourceDescription does not have the required " +
                "tag '$Key'. Removal was refused."
            )
        }

        if ([string]$ActualTags[$Key] -ne [string]$ExpectedTags[$Key]) {
            throw (
                "$ResourceDescription has unexpected tag $Key=" +
                "$($ActualTags[$Key]). Expected value: " +
                "$($ExpectedTags[$Key]). Removal was refused."
            )
        }
    }
}

function Get-Lab08Vpc {
    $Response = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available",
        "--output", "json"
    )

    $Vpcs = @($Response.Vpcs)

    if ($Vpcs.Count -ne 1) {
        throw (
            "Expected exactly one available Lab 08 VPC named " +
            "$VpcName, but found $($Vpcs.Count)."
        )
    }

    return $Vpcs[0]
}

function Get-Lab08Subnet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VpcId
    )

    $Response = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$SubnetName",
        "Name=state,Values=available",
        "--output", "json"
    )

    $Subnets = @($Response.Subnets)

    if ($Subnets.Count -ne 1) {
        throw (
            "Expected exactly one available Lab 08 subnet named " +
            "$SubnetName, but found $($Subnets.Count)."
        )
    }

    return $Subnets[0]
}

function Get-Lab13Instances {
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
        "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down",
        "--output", "json"
    )

    return @(
        $Response.Reservations |
            ForEach-Object {
                @($_.Instances)
            }
    )
}

function Get-Lab13SecurityGroups {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VpcId
    )

    $Response = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$SecurityGroupName",
        "--output", "json"
    )

    return @($Response.SecurityGroups)
}

function Get-Role {
    $Probe = Invoke-AwsProbe -Arguments @(
        "iam",
        "get-role",
        "--profile", $ProfileName,
        "--role-name", $RoleName,
        "--output", "json"
    )

    if ($Probe.ExitCode -eq 0) {
        return $Probe.Output | ConvertFrom-Json -ErrorAction Stop
    }

    if ($Probe.Output -match "NoSuchEntity") {
        return $null
    }

    throw "Unable to query IAM Role $RoleName. $($Probe.Output)"
}

function Get-InstanceProfile {
    $Probe = Invoke-AwsProbe -Arguments @(
        "iam",
        "get-instance-profile",
        "--profile", $ProfileName,
        "--instance-profile-name", $InstanceProfileName,
        "--output", "json"
    )

    if ($Probe.ExitCode -eq 0) {
        return $Probe.Output | ConvertFrom-Json -ErrorAction Stop
    }

    if ($Probe.Output -match "NoSuchEntity") {
        return $null
    }

    throw (
        "Unable to query Instance Profile $InstanceProfileName. " +
        "$($Probe.Output)"
    )
}

function Get-RoleTags {
    $Response = Invoke-AwsJson -Arguments @(
        "iam",
        "list-role-tags",
        "--profile", $ProfileName,
        "--role-name", $RoleName,
        "--output", "json"
    )

    return Convert-TagsToHashtable -Tags @($Response.Tags)
}

function Get-InstanceProfileTags {
    $Response = Invoke-AwsJson -Arguments @(
        "iam",
        "list-instance-profile-tags",
        "--profile", $ProfileName,
        "--instance-profile-name", $InstanceProfileName,
        "--output", "json"
    )

    return Convert-TagsToHashtable -Tags @($Response.Tags)
}

function Wait-SecurityGroupDeletion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId,

        [int]$MaximumAttempts = 20,

        [int]$DelaySeconds = 3
    )

    for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {
        $Probe = Invoke-AwsProbe -Arguments @(
            "ec2",
            "describe-security-groups",
            "--profile", $ProfileName,
            "--region", $Region,
            "--group-ids", $GroupId,
            "--output", "json"
        )

        if (
            $Probe.ExitCode -ne 0 -and
            $Probe.Output -match "InvalidGroup.NotFound"
        ) {
            return
        }

        if ($Probe.ExitCode -ne 0) {
            throw (
                "Unable to confirm deletion of Security Group " +
                "$GroupId. $($Probe.Output)"
            )
        }

        Write-InfoMessage (
            "Waiting for Security Group $GroupId deletion: " +
            "attempt $Attempt/$MaximumAttempts."
        )

        if ($Attempt -lt $MaximumAttempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw (
        "Security Group $GroupId still exists after " +
        "$MaximumAttempts validation attempts."
    )
}

Write-Host "Lab 13 - Controlled application troubleshooting cleanup"

try {
    Write-Step "Authorization and prerequisites"

    if (-not $ConfirmRemoval) {
        throw (
            "Resource removal was not authorized. Run this script with " +
            "-ConfirmRemoval."
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

    Write-Ok "AWS session validated and cleanup explicitly authorized."

    Write-Step "Shared Lab 08 network"

    $Vpc = Get-Lab08Vpc
    $VpcId = [string]$Vpc.VpcId

    $Subnet = Get-Lab08Subnet -VpcId $VpcId
    $SubnetId = [string]$Subnet.SubnetId

    Write-Ok (
        "Lab 08 VPC and application subnet identified; " +
        "they will not be removed."
    )

    Write-Host ("Preserved VPC:       {0}" -f $VpcId)
    Write-Host ("Preserved subnet:    {0}" -f $SubnetId)

    Write-Step "Resource discovery and ownership validation"

    $Instances = @(Get-Lab13Instances)
    $SecurityGroups = @(Get-Lab13SecurityGroups -VpcId $VpcId)
    $RoleResponse = Get-Role
    $InstanceProfileResponse = Get-InstanceProfile

    if ($Instances.Count -gt 1) {
        throw (
            "Expected at most one active Lab 13 EC2 instance, " +
            "but found $($Instances.Count)."
        )
    }

    if ($SecurityGroups.Count -gt 1) {
        throw (
            "Expected at most one Lab 13 Security Group, " +
            "but found $($SecurityGroups.Count)."
        )
    }

    foreach ($Instance in $Instances) {
        $InstanceTags = Convert-TagsToHashtable -Tags @($Instance.Tags)

        Assert-ExpectedTags `
            -ActualTags $InstanceTags `
            -ResourceDescription (
                "EC2 instance $([string]$Instance.InstanceId)"
            )
    }

    foreach ($SecurityGroup in $SecurityGroups) {
        $SecurityGroupTags = Convert-TagsToHashtable `
            -Tags @($SecurityGroup.Tags)

        Assert-ExpectedTags `
            -ActualTags $SecurityGroupTags `
            -ResourceDescription (
                "Security Group $([string]$SecurityGroup.GroupId)"
            )
    }

    if ($null -ne $RoleResponse) {
        $RoleTags = Get-RoleTags

        Assert-ExpectedTags `
            -ActualTags $RoleTags `
            -ResourceDescription "IAM Role $RoleName"
    }

    if ($null -ne $InstanceProfileResponse) {
        $InstanceProfileTags = Get-InstanceProfileTags

        Assert-ExpectedTags `
            -ActualTags $InstanceProfileTags `
            -ResourceDescription (
                "Instance Profile $InstanceProfileName"
            )
    }

    Write-Host ("Active EC2 instances: {0}" -f $Instances.Count)
    Write-Host ("Security Groups:       {0}" -f $SecurityGroups.Count)
    Write-Host (
        "IAM Role:              {0}" -f ($null -ne $RoleResponse)
    )
    Write-Host (
        "Instance Profile:      {0}" -f (
            $null -ne $InstanceProfileResponse
        )
    )

    Write-Ok (
        "All discovered Lab 13 resources passed ownership validation."
    )

    Write-Step "EC2 removal"

    if ($Instances.Count -eq 1) {
        $InstanceId = [string]$Instances[0].InstanceId
        $InstanceState = [string]$Instances[0].State.Name

        if ($InstanceState -ne "shutting-down") {
            $null = Invoke-AwsCommand -Arguments @(
                "ec2",
                "terminate-instances",
                "--profile", $ProfileName,
                "--region", $Region,
                "--instance-ids", $InstanceId,
                "--output", "json"
            )

            Write-InfoMessage (
                "Termination requested for EC2 instance $InstanceId."
            )
        }
        else {
            Write-InfoMessage (
                "EC2 instance $InstanceId is already shutting down."
            )
        }

        $null = Invoke-AwsCommand -Arguments @(
            "ec2",
            "wait",
            "instance-terminated",
            "--profile", $ProfileName,
            "--region", $Region,
            "--instance-ids", $InstanceId
        )

        Write-Ok "Lab 13 EC2 instance terminated."
    }
    else {
        Write-InfoMessage "No active Lab 13 EC2 instance was found."
    }

    Write-Step "Security Group removal"

    if ($SecurityGroups.Count -eq 1) {
        $GroupId = [string]$SecurityGroups[0].GroupId
        $Deleted = $false

        for ($Attempt = 1; $Attempt -le 20; $Attempt++) {
            $Probe = Invoke-AwsProbe -Arguments @(
                "ec2",
                "delete-security-group",
                "--profile", $ProfileName,
                "--region", $Region,
                "--group-id", $GroupId
            )

            if ($Probe.ExitCode -eq 0) {
                $Deleted = $true
                break
            }

            if ($Probe.Output -match "InvalidGroup.NotFound") {
                $Deleted = $true
                break
            }

            if ($Probe.Output -notmatch "DependencyViolation") {
                throw (
                    "Unable to delete Security Group $GroupId. " +
                    "$($Probe.Output)"
                )
            }

            Write-InfoMessage (
                "Waiting for EC2 network interfaces to release " +
                "Security Group $GroupId: attempt $Attempt/20."
            )

            if ($Attempt -lt 20) {
                Start-Sleep -Seconds 5
            }
        }

        if (-not $Deleted) {
            throw (
                "Security Group $GroupId could not be deleted because " +
                "AWS dependencies remained attached."
            )
        }

        Wait-SecurityGroupDeletion -GroupId $GroupId

        Write-Ok "Security Group removed: $SecurityGroupName."
    }
    else {
        Write-InfoMessage "No Lab 13 Security Group was found."
    }

    Write-Step "IAM removal"

    $InstanceProfileResponse = Get-InstanceProfile

    if ($null -ne $InstanceProfileResponse) {
        $AssociatedRoles = @(
            $InstanceProfileResponse.InstanceProfile.Roles
        )

        foreach ($AssociatedRole in $AssociatedRoles) {
            $AssociatedRoleName = [string]$AssociatedRole.RoleName

            if ($AssociatedRoleName -ne $RoleName) {
                throw (
                    "Instance Profile $InstanceProfileName contains " +
                    "unexpected IAM Role $AssociatedRoleName. " +
                    "Removal was refused."
                )
            }

            $null = Invoke-AwsCommand -Arguments @(
                "iam",
                "remove-role-from-instance-profile",
                "--profile", $ProfileName,
                "--instance-profile-name", $InstanceProfileName,
                "--role-name", $AssociatedRoleName
            )

            Write-Ok "IAM Role removed from the Instance Profile."
        }

        $null = Invoke-AwsCommand -Arguments @(
            "iam",
            "delete-instance-profile",
            "--profile", $ProfileName,
            "--instance-profile-name", $InstanceProfileName
        )

        Write-Ok "Instance Profile removed."
    }
    else {
        Write-InfoMessage "No Lab 13 Instance Profile was found."
    }

    $RoleResponse = Get-Role

    if ($null -ne $RoleResponse) {
        $AttachedPoliciesResponse = Invoke-AwsJson -Arguments @(
            "iam",
            "list-attached-role-policies",
            "--profile", $ProfileName,
            "--role-name", $RoleName,
            "--output", "json"
        )

        $AttachedPolicies = @(
            $AttachedPoliciesResponse.AttachedPolicies
        )

        foreach ($AttachedPolicy in $AttachedPolicies) {
            $AttachedPolicyArn = [string]$AttachedPolicy.PolicyArn

            if ($AttachedPolicyArn -ne $PolicyArn) {
                throw (
                    "IAM Role $RoleName has unexpected managed policy " +
                    "$AttachedPolicyArn. Removal was refused."
                )
            }

            $null = Invoke-AwsCommand -Arguments @(
                "iam",
                "detach-role-policy",
                "--profile", $ProfileName,
                "--role-name", $RoleName,
                "--policy-arn", $AttachedPolicyArn
            )

            Write-Ok "AmazonSSMManagedInstanceCore was detached."
        }

        $InlinePoliciesResponse = Invoke-AwsJson -Arguments @(
            "iam",
            "list-role-policies",
            "--profile", $ProfileName,
            "--role-name", $RoleName,
            "--output", "json"
        )

        $InlinePolicyNames = @($InlinePoliciesResponse.PolicyNames)

        if ($InlinePolicyNames.Count -gt 0) {
            throw (
                "IAM Role $RoleName has unexpected inline policies. " +
                "Removal was refused."
            )
        }

        $null = Invoke-AwsCommand -Arguments @(
            "iam",
            "delete-role",
            "--profile", $ProfileName,
            "--role-name", $RoleName
        )

        Write-Ok "IAM Role removed."
    }
    else {
        Write-InfoMessage "No Lab 13 IAM Role was found."
    }

    Write-Step "Post-cleanup validation"

    $RemainingInstances = @(Get-Lab13Instances)
    $RemainingSecurityGroups = @(
        Get-Lab13SecurityGroups -VpcId $VpcId
    )
    $RemainingRole = Get-Role
    $RemainingInstanceProfile = Get-InstanceProfile

    $PreservedVpc = Get-Lab08Vpc
    $PreservedVpcId = [string]$PreservedVpc.VpcId

    $PreservedSubnet = Get-Lab08Subnet -VpcId $PreservedVpcId
    $PreservedSubnetId = [string]$PreservedSubnet.SubnetId

    Write-Host (
        "Active EC2 instances: {0}" -f $RemainingInstances.Count
    )
    Write-Host (
        "Security Groups:       {0}" -f $RemainingSecurityGroups.Count
    )
    Write-Host (
        "IAM Role:              {0}" -f ($null -ne $RemainingRole)
    )
    Write-Host (
        "Instance Profile:      {0}" -f (
            $null -ne $RemainingInstanceProfile
        )
    )
    Write-Host ("Preserved VPC:         {0}" -f $PreservedVpcId)
    Write-Host ("Preserved subnet:      {0}" -f $PreservedSubnetId)

    if ($RemainingInstances.Count -ne 0) {
        throw (
            "One or more active Lab 13 EC2 instances remain."
        )
    }

    if ($RemainingSecurityGroups.Count -ne 0) {
        throw "The Lab 13 Security Group still exists."
    }

    if ($null -ne $RemainingRole) {
        throw "The Lab 13 IAM Role still exists."
    }

    if ($null -ne $RemainingInstanceProfile) {
        throw "The Lab 13 Instance Profile still exists."
    }

    if ($PreservedVpcId -ne $VpcId) {
        throw "The expected shared Lab 08 VPC was not preserved."
    }

    if ($PreservedSubnetId -ne $SubnetId) {
        throw "The expected shared Lab 08 subnet was not preserved."
    }

    Write-Ok "All exclusive Lab 13 resources were removed."
    Write-Ok "The shared Lab 08 VPC and subnet were preserved."

    Write-Host ""
    Write-Host "CLEANUP COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green
    Write-Host "Removed resources:"
    Write-Host "  EC2 instance"
    Write-Host "  Security Group"
    Write-Host "  IAM Role"
    Write-Host "  Instance Profile"
    Write-Host "Preserved resources:"
    Write-Host ("  VPC:       {0}" -f $PreservedVpcId)
    Write-Host ("  Subnet:    {0}" -f $PreservedSubnetId)
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host (
        "Cleanup stopped to prevent removal of resources with " +
        "unexpected identity, ownership, or dependencies."
    ) -ForegroundColor Yellow

    exit 1
}
