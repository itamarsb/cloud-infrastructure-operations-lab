[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [switch]$ConfirmRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetAName = "lab08-public-subnet-a"
$SubnetBName = "lab08-public-subnet-b"

$InstanceAName = "lab12-availability-instance-a"
$InstanceBName = "lab12-availability-instance-b"
$AlbSecurityGroupName = "lab12-alb-sg"
$BackendSecurityGroupName = "lab12-backend-sg"
$RoleName = "lab12-ec2-availability-role"
$InstanceProfileName = "lab12-ec2-availability-instance-profile"
$LoadBalancerName = "lab12-availability-alb"
$TargetGroupName = "lab12-availability-tg"

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
        [string[]]$Arguments
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

function Get-TagValue {
    param(
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $MatchingTags = @(
        $Tags |
            Where-Object {
                $null -ne $_ -and
                [string]$_.Key -eq $Key
            }
    )

    if ($MatchingTags.Count -ne 1) {
        return $null
    }

    return [string]$MatchingTags[0].Value
}

function Assert-LabTags {
    param(
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$ResourceLabel
    )

    $RequiredTags = [ordered]@{
        Project = "cloud-infrastructure-operations-lab"
        Environment = "lab"
        Lab = "12"
        ManagedBy = "aws-cli"
        Owner = "itamarsb"
    }

    foreach ($Entry in $RequiredTags.GetEnumerator()) {
        $ActualValue = Get-TagValue -Tags $Tags -Key $Entry.Key

        if ($ActualValue -ne $Entry.Value) {
            throw "$ResourceLabel does not have the expected tag $($Entry.Key)=$($Entry.Value)."
        }
    }
}

function Remove-SecurityGroupWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId,

        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )

    for ($Attempt = 1; $Attempt -le 18; $Attempt++) {
        try {
            Invoke-AwsCommand -Arguments @(
                "ec2",
                "delete-security-group",
                "--group-id",
                $GroupId
            )

            Write-Ok "Security Group removed: $GroupName"
            return
        }
        catch {
            if (
                $_.Exception.Message -match
                "DependencyViolation|resource .* has a dependent object"
            ) {
                Write-Info "Waiting to remove $GroupName`: attempt $Attempt/18."
                Start-Sleep -Seconds 10
                continue
            }

            throw
        }
    }

    throw "Security Group $GroupName could not be removed after dependency retries."
}

try {
    Write-Host "Lab 12 - Controlled application availability cleanup"

    Write-Step "Prerequisites and shared network"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    $null = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $Vpcs = @(
        $VpcResult.Vpcs |
            Where-Object { $null -ne $_ }
    )

    if ($Vpcs.Count -ne 1) {
        throw "Exactly one available Lab 08 VPC is required."
    }

    $VpcId = [string]$Vpcs[0].VpcId

    $SubnetResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$SubnetAName,$SubnetBName",
        "Name=state,Values=available"
    )

    $SharedSubnets = @(
        $SubnetResult.Subnets |
            Where-Object { $null -ne $_ }
    )

    if ($SharedSubnets.Count -ne 2) {
        throw "Exactly two Lab 08 application subnets are required."
    }

    Write-Ok "Lab 08 VPC and two subnets identified; they will not be removed."

    Write-Step "Resource discovery and ownership validation"

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

    if ($Instances.Count -gt 2) {
        throw "More than two active Lab 12 instances were found."
    }

    $AllowedInstanceNames = @($InstanceAName, $InstanceBName)

    foreach ($Instance in $Instances) {
        $InstanceName = Get-TagValue -Tags @($Instance.Tags) -Key "Name"

        if ($AllowedInstanceNames -notcontains $InstanceName) {
            throw "Unexpected Lab 12 instance found: $InstanceName"
        }

        Assert-LabTags `
            -Tags @($Instance.Tags) `
            -ResourceLabel "EC2 instance $InstanceName"

        if (
            [string]$Instance.VpcId -ne $VpcId -or
            @($SharedSubnets.SubnetId) -notcontains
            [string]$Instance.SubnetId
        ) {
            throw "EC2 instance $InstanceName is outside the expected Lab 08 network."
        }
    }

    $SecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$AlbSecurityGroupName,$BackendSecurityGroupName"
    )

    $SecurityGroups = @(
        $SecurityGroupResult.SecurityGroups |
            Where-Object { $null -ne $_ }
    )

    if ($SecurityGroups.Count -gt 2) {
        throw "More than two Lab 12 Security Groups were found."
    }

    foreach ($SecurityGroup in $SecurityGroups) {
        if (
            @($AlbSecurityGroupName, $BackendSecurityGroupName) -notcontains
            [string]$SecurityGroup.GroupName
        ) {
            throw "Unexpected Security Group found: $($SecurityGroup.GroupName)"
        }

        Assert-LabTags `
            -Tags @($SecurityGroup.Tags) `
            -ResourceLabel "Security Group $($SecurityGroup.GroupName)"
    }

    $LoadBalancerExists = Test-AwsResource -Arguments @(
        "elbv2",
        "describe-load-balancers",
        "--names",
        $LoadBalancerName
    )

    $LoadBalancer = $null
    $LoadBalancerArn = $null
    $Listeners = @()

    if ($LoadBalancerExists) {
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

        if ($LoadBalancers.Count -ne 1) {
            throw "The Lab 12 load balancer cannot be identified uniquely."
        }

        $LoadBalancer = $LoadBalancers[0]
        $LoadBalancerArn = [string]$LoadBalancer.LoadBalancerArn

        if (
            [string]$LoadBalancer.LoadBalancerName -ne $LoadBalancerName -or
            [string]$LoadBalancer.VpcId -ne $VpcId
        ) {
            throw "The load balancer does not match the expected Lab 12 identity."
        }

        $AlbTags = Invoke-AwsJson -Arguments @(
            "elbv2",
            "describe-tags",
            "--resource-arns",
            $LoadBalancerArn
        )

        Assert-LabTags `
            -Tags @($AlbTags.TagDescriptions[0].Tags) `
            -ResourceLabel "Application Load Balancer"

        $ListenerResult = Invoke-AwsJson -Arguments @(
            "elbv2",
            "describe-listeners",
            "--load-balancer-arn",
            $LoadBalancerArn
        )

        $Listeners = @(
            $ListenerResult.Listeners |
                Where-Object { $null -ne $_ }
        )

        if ($Listeners.Count -gt 1) {
            throw "More than one listener was found on the Lab 12 load balancer."
        }

        foreach ($Listener in $Listeners) {
            if (
                $Listener.Protocol -ne "HTTP" -or
                [int]$Listener.Port -ne 80
            ) {
                throw "An unexpected listener was found on the Lab 12 load balancer."
            }

            $ListenerTags = Invoke-AwsJson -Arguments @(
                "elbv2",
                "describe-tags",
                "--resource-arns",
                [string]$Listener.ListenerArn
            )

            Assert-LabTags `
                -Tags @($ListenerTags.TagDescriptions[0].Tags) `
                -ResourceLabel "HTTP Listener"
        }
    }

    $TargetGroupExists = Test-AwsResource -Arguments @(
        "elbv2",
        "describe-target-groups",
        "--names",
        $TargetGroupName
    )

    $TargetGroup = $null
    $TargetGroupArn = $null
    $RegisteredTargets = @()

    if ($TargetGroupExists) {
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
            throw "The Lab 12 Target Group cannot be identified uniquely."
        }

        $TargetGroup = $TargetGroups[0]
        $TargetGroupArn = [string]$TargetGroup.TargetGroupArn

        if (
            [string]$TargetGroup.TargetGroupName -ne $TargetGroupName -or
            [string]$TargetGroup.VpcId -ne $VpcId -or
            [string]$TargetGroup.TargetType -ne "instance"
        ) {
            throw "The Target Group does not match the expected Lab 12 identity."
        }

        $TargetTags = Invoke-AwsJson -Arguments @(
            "elbv2",
            "describe-tags",
            "--resource-arns",
            $TargetGroupArn
        )

        Assert-LabTags `
            -Tags @($TargetTags.TagDescriptions[0].Tags) `
            -ResourceLabel "Target Group"

        $TargetHealthResult = Invoke-AwsJson -Arguments @(
            "elbv2",
            "describe-target-health",
            "--target-group-arn",
            $TargetGroupArn
        )

        $RegisteredTargets = @(
            $TargetHealthResult.TargetHealthDescriptions |
                Where-Object { $null -ne $_ } |
                ForEach-Object {
                    "Id=$([string]$_.Target.Id),Port=$([int]$_.Target.Port)"
                }
        )

        if ($RegisteredTargets.Count -gt 2) {
            throw "More than two registered targets were found."
        }

        $ActiveInstanceIds = @(
            $Instances |
                ForEach-Object { [string]$_.InstanceId }
        )

        foreach ($TargetDescription in @($TargetHealthResult.TargetHealthDescriptions)) {
            if (
                $null -ne $TargetDescription -and
                $ActiveInstanceIds -notcontains
                [string]$TargetDescription.Target.Id
            ) {
                throw "Target Group contains an instance outside the active Lab 12 set."
            }
        }
    }

    $RoleExists = Test-AwsResource -Arguments @(
        "iam",
        "get-role",
        "--role-name",
        $RoleName
    )

    $AttachedPolicies = @()
    $InlinePolicyNames = @()

    if ($RoleExists) {
        $RoleResult = Invoke-AwsJson -Arguments @(
            "iam",
            "get-role",
            "--role-name",
            $RoleName
        )

        Assert-LabTags `
            -Tags @($RoleResult.Role.Tags) `
            -ResourceLabel "IAM Role"

        $AttachedPolicyResult = Invoke-AwsJson -Arguments @(
            "iam",
            "list-attached-role-policies",
            "--role-name",
            $RoleName
        )

        $AttachedPolicies = @(
            $AttachedPolicyResult.AttachedPolicies |
                Where-Object { $null -ne $_ }
        )

        foreach ($Policy in $AttachedPolicies) {
            if ([string]$Policy.PolicyArn -ne $PolicyArn) {
                throw "Unexpected managed policy is attached to the Lab 12 IAM Role."
            }
        }

        $InlinePolicyResult = Invoke-AwsJson -Arguments @(
            "iam",
            "list-role-policies",
            "--role-name",
            $RoleName
        )

        $InlinePolicyNames = @(
            $InlinePolicyResult.PolicyNames |
                Where-Object { $null -ne $_ }
        )

        if ($InlinePolicyNames.Count -gt 0) {
            throw "Unexpected inline policy is attached to the Lab 12 IAM Role."
        }
    }

    $ProfileExists = Test-AwsResource -Arguments @(
        "iam",
        "get-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName
    )

    $ProfileHasRole = $false

    if ($ProfileExists) {
        $ProfileResult = Invoke-AwsJson -Arguments @(
            "iam",
            "get-instance-profile",
            "--instance-profile-name",
            $InstanceProfileName
        )

        Assert-LabTags `
            -Tags @($ProfileResult.InstanceProfile.Tags) `
            -ResourceLabel "Instance Profile"

        $ProfileRoles = @(
            $ProfileResult.InstanceProfile.Roles |
                Where-Object { $null -ne $_ }
        )

        if ($ProfileRoles.Count -gt 1) {
            throw "More than one role belongs to the Lab 12 Instance Profile."
        }

        if ($ProfileRoles.Count -eq 1) {
            if ([string]$ProfileRoles[0].RoleName -ne $RoleName) {
                throw "Unexpected role belongs to the Lab 12 Instance Profile."
            }

            $ProfileHasRole = $true
        }
    }

    Write-Host "Active EC2 instances:  $($Instances.Count)"
    Write-Host "Security Groups:        $($SecurityGroups.Count)"
    Write-Host "Load Balancer:          $LoadBalancerExists"
    Write-Host "Listeners:              $($Listeners.Count)"
    Write-Host "Target Group:           $TargetGroupExists"
    Write-Host "Registered targets:     $($RegisteredTargets.Count)"
    Write-Host "IAM Role:               $RoleExists"
    Write-Host "Instance Profile:       $ProfileExists"

    if (-not $ConfirmRemoval) {
        throw "Removal was not authorized. Review the inventory and run again with -ConfirmRemoval."
    }

    Write-Step "Listener removal"

    foreach ($Listener in $Listeners) {
        Invoke-AwsCommand -Arguments @(
            "elbv2",
            "delete-listener",
            "--listener-arn",
            [string]$Listener.ListenerArn
        )

        Write-Ok "HTTP Listener removed."
    }

    Write-Step "Application Load Balancer removal"

    if ($LoadBalancerExists) {
        Invoke-AwsCommand -Arguments @(
            "elbv2",
            "delete-load-balancer",
            "--load-balancer-arn",
            $LoadBalancerArn
        )

        Invoke-AwsCommand -Arguments @(
            "elbv2",
            "wait",
            "load-balancers-deleted",
            "--load-balancer-arns",
            $LoadBalancerArn
        )

        Write-Ok "Application Load Balancer removed."
    }

    Write-Step "Target Group removal"

    if ($TargetGroupExists) {
        if ($RegisteredTargets.Count -gt 0) {
            Invoke-AwsCommand -Arguments (
                @(
                    "elbv2",
                    "deregister-targets",
                    "--target-group-arn",
                    $TargetGroupArn,
                    "--targets"
                ) + $RegisteredTargets
            )

            Write-Ok "EC2 instances deregistered from the Target Group."
        }

        Invoke-AwsCommand -Arguments @(
            "elbv2",
            "delete-target-group",
            "--target-group-arn",
            $TargetGroupArn
        )

        Write-Ok "Target Group removed."
    }

    Write-Step "EC2 removal"

    $InstanceIds = @(
        $Instances |
            ForEach-Object { [string]$_.InstanceId }
    )

    if ($InstanceIds.Count -gt 0) {
        Invoke-AwsCommand -Arguments (
            @(
                "ec2",
                "terminate-instances",
                "--instance-ids"
            ) + $InstanceIds
        )

        Invoke-AwsCommand -Arguments (
            @(
                "ec2",
                "wait",
                "instance-terminated",
                "--instance-ids"
            ) + $InstanceIds
        )

        Write-Ok "Lab 12 EC2 instances terminated."
    }

    Write-Step "Security Group removal"

    $BackendGroups = @(
        $SecurityGroups |
            Where-Object {
                $_.GroupName -eq $BackendSecurityGroupName
            }
    )

    $AlbGroups = @(
        $SecurityGroups |
            Where-Object {
                $_.GroupName -eq $AlbSecurityGroupName
            }
    )

    foreach ($SecurityGroup in @($BackendGroups + $AlbGroups)) {
        Remove-SecurityGroupWithRetry `
            -GroupId ([string]$SecurityGroup.GroupId) `
            -GroupName ([string]$SecurityGroup.GroupName)
    }

    Write-Step "IAM removal"

    if ($ProfileExists -and $ProfileHasRole) {
        Invoke-AwsCommand -Arguments @(
            "iam",
            "remove-role-from-instance-profile",
            "--instance-profile-name",
            $InstanceProfileName,
            "--role-name",
            $RoleName
        )

        Write-Ok "IAM Role removed from the Instance Profile."
    }

    if ($ProfileExists) {
        Invoke-AwsCommand -Arguments @(
            "iam",
            "delete-instance-profile",
            "--instance-profile-name",
            $InstanceProfileName
        )

        Write-Ok "Instance Profile removed."
    }

    if ($RoleExists) {
        foreach ($Policy in $AttachedPolicies) {
            Invoke-AwsCommand -Arguments @(
                "iam",
                "detach-role-policy",
                "--role-name",
                $RoleName,
                "--policy-arn",
                [string]$Policy.PolicyArn
            )
        }

        Invoke-AwsCommand -Arguments @(
            "iam",
            "delete-role",
            "--role-name",
            $RoleName
        )

        Write-Ok "IAM Role removed."
    }

    Write-Step "Post-cleanup validation"

    $FinalInstanceResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-instances",
        "--filters",
        "Name=tag:Project,Values=cloud-infrastructure-operations-lab",
        "Name=tag:Lab,Values=12",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $FinalInstances = @(
        foreach ($Reservation in @($FinalInstanceResult.Reservations)) {
            @(
                $Reservation.Instances |
                    Where-Object { $null -ne $_ }
            )
        }
    )

    $FinalSgResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$AlbSecurityGroupName,$BackendSecurityGroupName"
    )

    $FinalSecurityGroups = @(
        $FinalSgResult.SecurityGroups |
            Where-Object { $null -ne $_ }
    )

    $FinalLoadBalancerExists = Test-AwsResource -Arguments @(
        "elbv2",
        "describe-load-balancers",
        "--names",
        $LoadBalancerName
    )

    $FinalTargetGroupExists = Test-AwsResource -Arguments @(
        "elbv2",
        "describe-target-groups",
        "--names",
        $TargetGroupName
    )

    $FinalRoleExists = Test-AwsResource -Arguments @(
        "iam",
        "get-role",
        "--role-name",
        $RoleName
    )

    $FinalProfileExists = Test-AwsResource -Arguments @(
        "iam",
        "get-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName
    )

    $FinalVpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--vpc-ids",
        $VpcId
    )

    $FinalSubnetResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$SubnetAName,$SubnetBName",
        "Name=state,Values=available"
    )

    $FinalSubnets = @(
        $FinalSubnetResult.Subnets |
            Where-Object { $null -ne $_ }
    )

    Write-Host "Active EC2 instances:  $($FinalInstances.Count)"
    Write-Host "Security Groups:        $($FinalSecurityGroups.Count)"
    Write-Host "Load Balancer:          $FinalLoadBalancerExists"
    Write-Host "Target Group:           $FinalTargetGroupExists"
    Write-Host "IAM Role:               $FinalRoleExists"
    Write-Host "Instance Profile:       $FinalProfileExists"
    Write-Host "Preserved Lab 08 VPC:   $(@($FinalVpcResult.Vpcs).Count)"
    Write-Host "Preserved subnets:      $($FinalSubnets.Count)"

    if (
        $FinalInstances.Count -ne 0 -or
        $FinalSecurityGroups.Count -ne 0 -or
        $FinalLoadBalancerExists -or
        $FinalTargetGroupExists -or
        $FinalRoleExists -or
        $FinalProfileExists -or
        @($FinalVpcResult.Vpcs).Count -ne 1 -or
        $FinalSubnets.Count -ne 2
    ) {
        throw "Post-cleanup validation found an unexpected final state."
    }

    Write-Ok "All Lab 12 resources were removed."
    Write-Ok "Lab 08 VPC and two application subnets were preserved."

    Write-Host ""
    Write-Host "CLEANUP COMPLETED SUCCESSFULLY" -ForegroundColor Green

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Review the remaining Lab 12 resources before running cleanup again." `
        -ForegroundColor Yellow

    exit 1
}

