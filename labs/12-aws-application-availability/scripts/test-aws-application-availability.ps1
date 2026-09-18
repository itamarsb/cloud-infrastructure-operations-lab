[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1"
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
$Failures = 0

function Write-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
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

function Get-OptionalPropertyValue {
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $Property = $InputObject.PSObject.Properties[$PropertyName]

    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
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

function Assert-Check {
    param(
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
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

function Test-RequiredTags {
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
        Assert-Check `
            -Condition (
                (Get-TagValue -Tags $Tags -Key $Entry.Key) -eq
                $Entry.Value
            ) `
            -Message "$ResourceLabel has tag $($Entry.Key)=$($Entry.Value)."
    }
}

function Invoke-SsmReadOnlyCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("A", "B")]
        [string]$Backend
    )

    $RemoteTemplate = @'
set -e
systemctl is-active nginx
systemctl is-enabled nginx
test -f /var/lib/cloud/instance/lab12-nginx-ready
test "$(curl -fsS http://localhost/health)" = "healthy"
curl -fsS http://localhost/ | grep -q 'backend <strong>__BACKEND__</strong>'
printf 'LAB12_BACKEND___BACKEND___OK\n'
'@

    $RemoteCommand = $RemoteTemplate.Replace("__BACKEND__", $Backend).Replace("`r", "")

    $CommandParameters = @{
        commands = @(
            $RemoteCommand
        )
    } | ConvertTo-Json -Depth 3

    $TemporaryParametersPath = Join-Path `
        -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "lab12-read-only-$($Backend.ToLowerInvariant()).json"

    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $TemporaryParametersPath,
        $CommandParameters,
        $Utf8WithoutBom
    )

    $ParametersFilePath = (
        Resolve-Path -LiteralPath $TemporaryParametersPath
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
            "Lab 12 read-only backend $Backend validation",
            "--parameters",
            $ParametersArgument
        )
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryParametersPath) {
            Remove-Item `
                -LiteralPath $TemporaryParametersPath `
                -Force
        }
    }

    $CommandId = [string]$CommandResult.Command.CommandId
    $CommandInvocation = $null

    for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
        Start-Sleep -Seconds 2

        try {
            $CommandInvocation = Invoke-AwsJson -Arguments @(
                "ssm",
                "get-command-invocation",
                "--command-id",
                $CommandId,
                "--instance-id",
                $InstanceId
            )
        }
        catch {
            if (
                $_.Exception.Message -match
                "InvocationDoesNotExist"
            ) {
                continue
            }

            throw
        }

        if ($CommandInvocation.Status -eq "Success") {
            return $CommandInvocation
        }

        if (
            $CommandInvocation.Status -in @(
                "Cancelled",
                "TimedOut",
                "Failed",
                "Cancelling"
            )
        ) {
            break
        }
    }

    return $CommandInvocation
}

try {
    Write-Host "Lab 12 - Independent application availability validation"

    Write-Step "Prerequisites and identity"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    $Identity = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    Assert-Check `
        -Condition (
            -not [string]::IsNullOrWhiteSpace(
                [string]$Identity.Arn
            )
        ) `
        -Message "AWS session is authenticated."

    Write-Step "Lab 08 network"

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

    Assert-Check `
        -Condition ($Vpcs.Count -eq 1) `
        -Message "Exactly one available Lab 08 VPC exists."

    if ($Vpcs.Count -ne 1) {
        throw "The Lab 08 VPC cannot be validated uniquely."
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

    $Subnets = @(
        $SubnetResult.Subnets |
            Where-Object { $null -ne $_ }
    )

    Assert-Check `
        -Condition ($Subnets.Count -eq 2) `
        -Message "Exactly two Lab 08 application subnets exist."

    if ($Subnets.Count -ne 2) {
        throw "The two Lab 08 subnets cannot be validated uniquely."
    }

    $SubnetA = @(
        $Subnets |
            Where-Object {
                (Get-TagValue -Tags @($_.Tags) -Key "Name") -eq
                $SubnetAName
            }
    )

    $SubnetB = @(
        $Subnets |
            Where-Object {
                (Get-TagValue -Tags @($_.Tags) -Key "Name") -eq
                $SubnetBName
            }
    )

    Assert-Check `
        -Condition ($SubnetA.Count -eq 1) `
        -Message "Subnet A is uniquely identified."

    Assert-Check `
        -Condition ($SubnetB.Count -eq 1) `
        -Message "Subnet B is uniquely identified."

    if ($SubnetA.Count -ne 1 -or $SubnetB.Count -ne 1) {
        throw "The expected Lab 08 subnet names were not found."
    }

    $SubnetAId = [string]$SubnetA[0].SubnetId
    $SubnetBId = [string]$SubnetB[0].SubnetId

    Assert-Check `
        -Condition (
            [string]$SubnetA[0].AvailabilityZone -ne
            [string]$SubnetB[0].AvailabilityZone
        ) `
        -Message "Subnets belong to different Availability Zones."

    Assert-Check `
        -Condition (
            [bool]$SubnetA[0].MapPublicIpOnLaunch -and
            [bool]$SubnetB[0].MapPublicIpOnLaunch
        ) `
        -Message "Both subnets automatically assign public IPv4 addresses."

    Write-Step "Security Groups"

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

    Assert-Check `
        -Condition ($SecurityGroups.Count -eq 2) `
        -Message "Exactly two Lab 12 Security Groups exist."

    if ($SecurityGroups.Count -ne 2) {
        throw "The Lab 12 Security Groups cannot be validated uniquely."
    }

    $AlbGroups = @(
        $SecurityGroups |
            Where-Object { $_.GroupName -eq $AlbSecurityGroupName }
    )

    $BackendGroups = @(
        $SecurityGroups |
            Where-Object { $_.GroupName -eq $BackendSecurityGroupName }
    )

    if ($AlbGroups.Count -ne 1 -or $BackendGroups.Count -ne 1) {
        throw "The expected Lab 12 Security Group names were not found."
    }

    $AlbSecurityGroup = $AlbGroups[0]
    $BackendSecurityGroup = $BackendGroups[0]
    $AlbSecurityGroupId = [string]$AlbSecurityGroup.GroupId
    $BackendSecurityGroupId = [string]$BackendSecurityGroup.GroupId

    Test-RequiredTags `
        -Tags @($AlbSecurityGroup.Tags) `
        -ResourceLabel "ALB Security Group"

    Test-RequiredTags `
        -Tags @($BackendSecurityGroup.Tags) `
        -ResourceLabel "backend Security Group"

    $AlbIngress = @(
        $AlbSecurityGroup.IpPermissions |
            Where-Object { $null -ne $_ }
    )

    Assert-Check `
        -Condition ($AlbIngress.Count -eq 1) `
        -Message "ALB Security Group has exactly one ingress rule."

    if ($AlbIngress.Count -eq 1) {
        $AlbHttpRule = $AlbIngress[0]
        $AlbIpv4Ranges = @(
            $AlbHttpRule.IpRanges |
                Where-Object { $null -ne $_ }
        )

        Assert-Check `
            -Condition (
                $AlbHttpRule.IpProtocol -eq "tcp" -and
                [int]$AlbHttpRule.FromPort -eq 80 -and
                [int]$AlbHttpRule.ToPort -eq 80
            ) `
            -Message "ALB ingress permits only TCP port 80."

        Assert-Check `
            -Condition (
                $AlbIpv4Ranges.Count -eq 1 -and
                [string]$AlbIpv4Ranges[0].CidrIp -eq "0.0.0.0/0" -and
                @($AlbHttpRule.Ipv6Ranges).Count -eq 0 -and
                @($AlbHttpRule.UserIdGroupPairs).Count -eq 0 -and
                @($AlbHttpRule.PrefixListIds).Count -eq 0
            ) `
            -Message "ALB HTTP access uses only the expected public IPv4 source."
    }

    $BackendIngress = @(
        $BackendSecurityGroup.IpPermissions |
            Where-Object { $null -ne $_ }
    )

    Assert-Check `
        -Condition ($BackendIngress.Count -eq 1) `
        -Message "Backend Security Group has exactly one ingress rule."

    if ($BackendIngress.Count -eq 1) {
        $BackendHttpRule = $BackendIngress[0]
        $SourceGroups = @(
            $BackendHttpRule.UserIdGroupPairs |
                Where-Object { $null -ne $_ }
        )

        Assert-Check `
            -Condition (
                $BackendHttpRule.IpProtocol -eq "tcp" -and
                [int]$BackendHttpRule.FromPort -eq 80 -and
                [int]$BackendHttpRule.ToPort -eq 80
            ) `
            -Message "Backend ingress permits only TCP port 80."

        Assert-Check `
            -Condition (
                $SourceGroups.Count -eq 1 -and
                [string]$SourceGroups[0].GroupId -eq $AlbSecurityGroupId -and
                @($BackendHttpRule.IpRanges).Count -eq 0 -and
                @($BackendHttpRule.Ipv6Ranges).Count -eq 0 -and
                @($BackendHttpRule.PrefixListIds).Count -eq 0
            ) `
            -Message "Backend HTTP access is restricted to the ALB Security Group."
    }

    $SshRules = @(
        @($AlbIngress + $BackendIngress) |
            Where-Object {
                $_.IpProtocol -eq "-1" -or
                (
                    $_.IpProtocol -eq "tcp" -and
                    [int]$_.FromPort -le 22 -and
                    [int]$_.ToPort -ge 22
                )
            }
    )

    Assert-Check `
        -Condition ($SshRules.Count -eq 0) `
        -Message "No Lab 12 ingress rule permits SSH on TCP port 22."

    Write-Step "EC2 backends"

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

    Assert-Check `
        -Condition ($Instances.Count -eq 2) `
        -Message "Exactly two active Lab 12 EC2 instances exist."

    if ($Instances.Count -ne 2) {
        throw "The Lab 12 EC2 instances cannot be validated uniquely."
    }

    $ExpectedBackends = @(
        [pscustomobject]@{
            Name = $InstanceAName
            Backend = "A"
            SubnetId = $SubnetAId
            AvailabilityZone = [string]$SubnetA[0].AvailabilityZone
        },
        [pscustomobject]@{
            Name = $InstanceBName
            Backend = "B"
            SubnetId = $SubnetBId
            AvailabilityZone = [string]$SubnetB[0].AvailabilityZone
        }
    )

    $ValidatedInstances = @()

    foreach ($ExpectedBackend in $ExpectedBackends) {
        $MatchingInstances = @(
            $Instances |
                Where-Object {
                    (Get-TagValue -Tags @($_.Tags) -Key "Name") -eq
                    $ExpectedBackend.Name
                }
        )

        Assert-Check `
            -Condition ($MatchingInstances.Count -eq 1) `
            -Message "Backend $($ExpectedBackend.Backend) is uniquely identified."

        if ($MatchingInstances.Count -ne 1) {
            continue
        }

        $Instance = $MatchingInstances[0]
        $InstanceId = [string]$Instance.InstanceId

        $ValidatedInstances += [pscustomobject]@{
            Instance = $Instance
            InstanceId = $InstanceId
            Backend = [string]$ExpectedBackend.Backend
        }

        Assert-Check `
            -Condition ($Instance.State.Name -eq "running") `
            -Message "Backend $($ExpectedBackend.Backend) is running."

        Assert-Check `
            -Condition (
                [string]$Instance.SubnetId -eq $ExpectedBackend.SubnetId -and
                [string]$Instance.Placement.AvailabilityZone -eq
                $ExpectedBackend.AvailabilityZone
            ) `
            -Message "Backend $($ExpectedBackend.Backend) is in the expected subnet and Availability Zone."

        Test-RequiredTags `
            -Tags @($Instance.Tags) `
            -ResourceLabel "backend $($ExpectedBackend.Backend)"

        Assert-Check `
            -Condition (
                (Get-TagValue -Tags @($Instance.Tags) -Key "Backend") -eq
                $ExpectedBackend.Backend
            ) `
            -Message "Backend $($ExpectedBackend.Backend) has the expected Backend tag."

        Assert-Check `
            -Condition (
                (Get-TagValue -Tags @($Instance.Tags) -Key "Service") -eq
                "nginx"
            ) `
            -Message "Backend $($ExpectedBackend.Backend) has the nginx service tag."

        $KeyName = Get-OptionalPropertyValue `
            -InputObject $Instance `
            -PropertyName "KeyName"

        Assert-Check `
            -Condition ([string]::IsNullOrWhiteSpace([string]$KeyName)) `
            -Message "Backend $($ExpectedBackend.Backend) has no SSH Key Pair."

        Assert-Check `
            -Condition ($Instance.MetadataOptions.HttpTokens -eq "required") `
            -Message "Backend $($ExpectedBackend.Backend) requires IMDSv2 tokens."

        $ProfileArn = [string]$Instance.IamInstanceProfile.Arn

        Assert-Check `
            -Condition (
                $ProfileArn -match
                "/$([regex]::Escape($InstanceProfileName))$"
            ) `
            -Message "Backend $($ExpectedBackend.Backend) uses the expected Instance Profile."

        Assert-Check `
            -Condition (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$Instance.PublicIpAddress
                )
            ) `
            -Message "Backend $($ExpectedBackend.Backend) has outbound public IPv4 connectivity."

        $AttachedGroups = @(
            $Instance.SecurityGroups |
                Where-Object { $null -ne $_ }
        )

        Assert-Check `
            -Condition (
                $AttachedGroups.Count -eq 1 -and
                [string]$AttachedGroups[0].GroupId -eq
                $BackendSecurityGroupId
            ) `
            -Message "Backend $($ExpectedBackend.Backend) uses only the backend Security Group."

        $RootMappings = @(
            $Instance.BlockDeviceMappings |
                Where-Object {
                    $_.DeviceName -eq $Instance.RootDeviceName
                }
        )

        Assert-Check `
            -Condition ($RootMappings.Count -eq 1) `
            -Message "Backend $($ExpectedBackend.Backend) has one root EBS volume."

        if ($RootMappings.Count -eq 1) {
            $VolumeResult = Invoke-AwsJson -Arguments @(
                "ec2",
                "describe-volumes",
                "--volume-ids",
                [string]$RootMappings[0].Ebs.VolumeId
            )

            Assert-Check `
                -Condition ([bool]$VolumeResult.Volumes[0].Encrypted) `
                -Message "Backend $($ExpectedBackend.Backend) root EBS volume is encrypted."

            Assert-Check `
                -Condition ($VolumeResult.Volumes[0].VolumeType -eq "gp3") `
                -Message "Backend $($ExpectedBackend.Backend) root EBS volume uses gp3."

            Assert-Check `
                -Condition ([bool]$RootMappings[0].Ebs.DeleteOnTermination) `
                -Message "Backend $($ExpectedBackend.Backend) root volume will be deleted with the instance."
        }
    }

    if ($ValidatedInstances.Count -ne 2) {
        throw "Both expected backends must be identified before continuing."
    }

    Write-Step "IAM and Systems Manager"

    $RoleResult = Invoke-AwsJson -Arguments @(
        "iam",
        "get-role",
        "--role-name",
        $RoleName
    )

    Assert-Check `
        -Condition ($RoleResult.Role.RoleName -eq $RoleName) `
        -Message "Lab 12 IAM Role exists."

    Test-RequiredTags `
        -Tags @($RoleResult.Role.Tags) `
        -ResourceLabel "IAM Role"

    $PolicyResult = Invoke-AwsJson -Arguments @(
        "iam",
        "list-attached-role-policies",
        "--role-name",
        $RoleName
    )

    Assert-Check `
        -Condition (
            @($PolicyResult.AttachedPolicies.PolicyArn) -contains
            $PolicyArn
        ) `
        -Message "AmazonSSMManagedInstanceCore is attached."

    $ProfileResult = Invoke-AwsJson -Arguments @(
        "iam",
        "get-instance-profile",
        "--instance-profile-name",
        $InstanceProfileName
    )

    Assert-Check `
        -Condition (
            @($ProfileResult.InstanceProfile.Roles.RoleName) -contains
            $RoleName
        ) `
        -Message "IAM Role belongs to the expected Instance Profile."

    $InstanceIds = @(
        $ValidatedInstances |
            ForEach-Object { [string]$_.InstanceId }
    )

    foreach ($ValidatedInstance in $ValidatedInstances) {
        $SsmResult = Invoke-AwsJson -Arguments @(
            "ssm",
            "describe-instance-information",
            "--filters",
            "Key=InstanceIds,Values=$($ValidatedInstance.InstanceId)"
        )

        $ManagedNodes = @(
            $SsmResult.InstanceInformationList |
                Where-Object { $null -ne $_ }
        )

        Assert-Check `
            -Condition ($ManagedNodes.Count -eq 1) `
            -Message "Backend $($ValidatedInstance.Backend) is registered in Systems Manager."

        if ($ManagedNodes.Count -eq 1) {
            Assert-Check `
                -Condition ($ManagedNodes[0].PingStatus -eq "Online") `
                -Message "Backend $($ValidatedInstance.Backend) is online in Systems Manager."

            Assert-Check `
                -Condition (
                    $ManagedNodes[0].PlatformName -eq "Amazon Linux" -and
                    [string]$ManagedNodes[0].PlatformVersion -match "^2023"
                ) `
                -Message "Backend $($ValidatedInstance.Backend) runs Amazon Linux 2023."

            if ($ManagedNodes[0].PingStatus -eq "Online") {
                $Invocation = Invoke-SsmReadOnlyCheck `
                    -InstanceId $ValidatedInstance.InstanceId `
                    -Backend $ValidatedInstance.Backend

                $CommandSucceeded = (
                    $null -ne $Invocation -and
                    [string]$Invocation.Status -eq "Success"
                )

                Assert-Check `
                    -Condition $CommandSucceeded `
                    -Message "Backend $($ValidatedInstance.Backend) read-only operating system check succeeded."

                if ($CommandSucceeded) {
                    Assert-Check `
                        -Condition (
                            [string]$Invocation.StandardOutputContent -match
                            "LAB12_BACKEND_$($ValidatedInstance.Backend)_OK"
                        ) `
                        -Message "Backend $($ValidatedInstance.Backend) has active Nginx and the expected local content."
                }
                else {
                    $CommandError = Get-OptionalPropertyValue `
                        -InputObject $Invocation `
                        -PropertyName "StandardErrorContent"

                    if (
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$CommandError
                        )
                    ) {
                        Write-Host "[INFO] Backend $($ValidatedInstance.Backend): $CommandError" `
                            -ForegroundColor Yellow
                    }
                }
            }
        }
    }

    Write-Step "Application Load Balancer"

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

    Assert-Check `
        -Condition ($LoadBalancers.Count -eq 1) `
        -Message "Exactly one Lab 12 Application Load Balancer exists."

    if ($LoadBalancers.Count -ne 1) {
        throw "The Application Load Balancer cannot be validated uniquely."
    }

    $LoadBalancer = $LoadBalancers[0]
    $LoadBalancerArn = [string]$LoadBalancer.LoadBalancerArn
    $LoadBalancerDnsName = [string]$LoadBalancer.DNSName
    $AlbSubnetIds = @(
        $LoadBalancer.AvailabilityZones |
            ForEach-Object { [string]$_.SubnetId }
    )

    Assert-Check `
        -Condition ($LoadBalancer.State.Code -eq "active") `
        -Message "Application Load Balancer is active."

    Assert-Check `
        -Condition (
            $LoadBalancer.Type -eq "application" -and
            $LoadBalancer.Scheme -eq "internet-facing" -and
            $LoadBalancer.IpAddressType -eq "ipv4"
        ) `
        -Message "Load balancer type, scheme, and IP address type are correct."

    Assert-Check `
        -Condition ([string]$LoadBalancer.VpcId -eq $VpcId) `
        -Message "Application Load Balancer belongs to the Lab 08 VPC."

    Assert-Check `
        -Condition (
            $AlbSubnetIds.Count -eq 2 -and
            $AlbSubnetIds -contains $SubnetAId -and
            $AlbSubnetIds -contains $SubnetBId
        ) `
        -Message "Application Load Balancer uses both Lab 08 subnets."

    Assert-Check `
        -Condition (
            @($LoadBalancer.SecurityGroups).Count -eq 1 -and
            @($LoadBalancer.SecurityGroups) -contains
            $AlbSecurityGroupId
        ) `
        -Message "Application Load Balancer uses only its expected Security Group."

    $AlbTagResult = Invoke-AwsJson -Arguments @(
        "elbv2",
        "describe-tags",
        "--resource-arns",
        $LoadBalancerArn
    )

    Test-RequiredTags `
        -Tags @($AlbTagResult.TagDescriptions[0].Tags) `
        -ResourceLabel "Application Load Balancer"

    Write-Step "Target Group and health checks"

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

    Assert-Check `
        -Condition ($TargetGroups.Count -eq 1) `
        -Message "Exactly one Lab 12 Target Group exists."

    if ($TargetGroups.Count -ne 1) {
        throw "The Target Group cannot be validated uniquely."
    }

    $TargetGroup = $TargetGroups[0]
    $TargetGroupArn = [string]$TargetGroup.TargetGroupArn

    Assert-Check `
        -Condition (
            [string]$TargetGroup.VpcId -eq $VpcId -and
            $TargetGroup.Protocol -eq "HTTP" -and
            [int]$TargetGroup.Port -eq 80 -and
            $TargetGroup.TargetType -eq "instance"
        ) `
        -Message "Target Group uses HTTP port 80 with EC2 instance targets."

    Assert-Check `
        -Condition (
            $TargetGroup.HealthCheckProtocol -eq "HTTP" -and
            [string]$TargetGroup.HealthCheckPort -eq "traffic-port" -and
            [string]$TargetGroup.HealthCheckPath -eq "/health" -and
            [int]$TargetGroup.HealthCheckIntervalSeconds -eq 15 -and
            [int]$TargetGroup.HealthCheckTimeoutSeconds -eq 5 -and
            [int]$TargetGroup.HealthyThresholdCount -eq 2 -and
            [int]$TargetGroup.UnhealthyThresholdCount -eq 2
        ) `
        -Message "Target Group health check configuration is correct."

    $Matcher = Get-OptionalPropertyValue `
        -InputObject $TargetGroup `
        -PropertyName "Matcher"

    Assert-Check `
        -Condition (
            [string](
                Get-OptionalPropertyValue `
                    -InputObject $Matcher `
                    -PropertyName "HttpCode"
            ) -eq "200"
        ) `
        -Message "Health check accepts only HTTP 200."

    Assert-Check `
        -Condition (
            @($TargetGroup.LoadBalancerArns) -contains
            $LoadBalancerArn
        ) `
        -Message "Target Group is associated with the Lab 12 load balancer."

    $TargetTagResult = Invoke-AwsJson -Arguments @(
        "elbv2",
        "describe-tags",
        "--resource-arns",
        $TargetGroupArn
    )

    Test-RequiredTags `
        -Tags @($TargetTagResult.TagDescriptions[0].Tags) `
        -ResourceLabel "Target Group"

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

    $RegisteredTargetIds = @(
        $TargetDescriptions |
            ForEach-Object { [string]$_.Target.Id }
    )

    Assert-Check `
        -Condition (
            $TargetDescriptions.Count -eq 2 -and
            $RegisteredTargetIds -contains $InstanceIds[0] -and
            $RegisteredTargetIds -contains $InstanceIds[1]
        ) `
        -Message "Exactly the two Lab 12 instances are registered as targets."

    Assert-Check `
        -Condition (
            @(
                $TargetDescriptions |
                    Where-Object {
                        $_.TargetHealth.State -eq "healthy"
                    }
            ).Count -eq 2
        ) `
        -Message "Both registered targets are healthy."

    Write-Step "HTTP Listener"

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

    Assert-Check `
        -Condition ($Listeners.Count -eq 1) `
        -Message "Application Load Balancer has exactly one Listener."

    if ($Listeners.Count -eq 1) {
        $Listener = $Listeners[0]
        $DefaultActions = @(
            $Listener.DefaultActions |
                Where-Object { $null -ne $_ }
        )

        Assert-Check `
            -Condition (
                $Listener.Protocol -eq "HTTP" -and
                [int]$Listener.Port -eq 80
            ) `
            -Message "Listener uses HTTP on TCP port 80."

        Assert-Check `
            -Condition (
                $DefaultActions.Count -eq 1 -and
                $DefaultActions[0].Type -eq "forward" -and
                [string]$DefaultActions[0].TargetGroupArn -eq
                $TargetGroupArn
            ) `
            -Message "Listener forwards traffic only to the Lab 12 Target Group."
    }

    Write-Step "Application traffic"

    Assert-Check `
        -Condition (
            -not [string]::IsNullOrWhiteSpace(
                $LoadBalancerDnsName
            )
        ) `
        -Message "Application Load Balancer has a DNS name."

    $ApplicationUrl = "http://$LoadBalancerDnsName/"
    $ObservedBackends = @{}
    $SuccessfulRequests = 0

    for ($Attempt = 1; $Attempt -le 40; $Attempt++) {
        try {
            $RequestUrl = "$ApplicationUrl`?validation=$Attempt"
            $Response = Invoke-WebRequest `
                -Uri $RequestUrl `
                -UseBasicParsing `
                -TimeoutSec 15 `
                -DisableKeepAlive

            if (
                $Response.StatusCode -eq 200 -and
                $Response.Content -match "Lab 12"
            ) {
                $SuccessfulRequests++

                if ($Response.Content -match "backend <strong>(A|B)</strong>") {
                    $ObservedBackends[[string]$Matches[1]] = $true
                }
            }
        }
        catch {
            Write-Host "[INFO] HTTP attempt $Attempt failed: $($_.Exception.Message)" `
                -ForegroundColor Yellow
        }

        if (
            $ObservedBackends.ContainsKey("A") -and
            $ObservedBackends.ContainsKey("B")
        ) {
            break
        }

        Start-Sleep -Milliseconds 500
    }

    Assert-Check `
        -Condition ($SuccessfulRequests -gt 0) `
        -Message "Application Load Balancer returned HTTP 200."

    Assert-Check `
        -Condition (
            $ObservedBackends.ContainsKey("A") -and
            $ObservedBackends.ContainsKey("B")
        ) `
        -Message "HTTP responses were observed from both backends."

    Write-Host ""

    if ($Failures -gt 0) {
        Write-Host "VALIDATION FAILED: $Failures check(s) failed." `
            -ForegroundColor Red

        exit 1
    }

    Write-Host "VALIDATION COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green

    Write-Host "VPC:                $VpcId"
    Write-Host "Backend A:          $($ValidatedInstances[0].InstanceId)"
    Write-Host "Backend B:          $($ValidatedInstances[1].InstanceId)"
    Write-Host "Target Group ARN:   $TargetGroupArn"
    Write-Host "Load Balancer ARN:  $LoadBalancerArn"
    Write-Host "Application URL:    $ApplicationUrl"
    Write-Host "Observed backends:  $((@($ObservedBackends.Keys) | Sort-Object) -join ', ')"

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red

    exit 1
}
