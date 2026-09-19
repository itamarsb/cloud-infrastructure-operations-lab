[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1"
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

$Failures = 0

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

function Add-Pass {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Add-Failure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:Failures++
}

function Test-Condition {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$SuccessMessage,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    if ($Condition) {
        Add-Pass $SuccessMessage
    }
    else {
        Add-Failure $FailureMessage
    }
}

function Invoke-AwsCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$AllowEmpty
    )

    $output = @(
        & aws @Arguments `
            --profile $ProfileName `
            --region $Region `
            --no-cli-pager 2>&1
    )

    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"

    if ($exitCode -ne 0) {
        throw "AWS CLI failed: aws $($Arguments -join ' ')`n$text"
    }

    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($text)) {
        throw "AWS CLI returned an empty response: aws $($Arguments -join ' ')"
    }

    return $text.Trim()
}

function ConvertFrom-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $json = Invoke-AwsCli -Arguments ($Arguments + @("--output", "json"))

    try {
        return $json | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "AWS CLI returned invalid JSON.`n$json"
    }
}

function Get-TagValue {
    param(
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $tag = @($Tags) |
        Where-Object { $_.Key -eq $Key } |
        Select-Object -First 1

    if ($null -eq $tag) {
        return $null
    }

    return [string]$tag.Value
}

function Test-RequiredTags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceDescription,

        [AllowNull()]
        [object[]]$Tags
    )

    foreach ($key in $ExpectedTags.Keys) {
        $actualValue = Get-TagValue -Tags $Tags -Key $key
        $expectedValue = $ExpectedTags[$key]

        Test-Condition `
            -Condition ($actualValue -eq $expectedValue) `
            -SuccessMessage (
                "$ResourceDescription has tag $key=$expectedValue."
            ) `
            -FailureMessage (
                "$ResourceDescription does not have the expected " +
                "tag $key=$expectedValue."
            )
    }
}

function Invoke-SsmReadOnlyCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $true)]
        [string[]]$Commands,

        [int]$MaximumAttempts = 30,

        [int]$DelaySeconds = 5
    )

    $parameters = @{
        commands = $Commands
    } | ConvertTo-Json -Compress

    $commandResponse = ConvertFrom-AwsJson -Arguments @(
        "ssm", "send-command",
        "--instance-ids", $InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--comment", "Lab 13 read-only validation",
        "--parameters", $parameters
    )

    $commandId = $commandResponse.Command.CommandId

    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "Systems Manager did not return a command identifier."
    }

    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        Start-Sleep -Seconds $DelaySeconds

        try {
            $invocation = ConvertFrom-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $commandId,
                "--instance-id", $InstanceId
            )
        }
        catch {
            if ($attempt -eq $MaximumAttempts) {
                throw
            }

            continue
        }

        if ($invocation.Status -eq "Success") {
            return [pscustomobject]@{
                Status         = $invocation.Status
                ResponseCode   = $invocation.ResponseCode
                StandardOutput = (
                    [string]$invocation.StandardOutputContent
                ).Replace("`r", "")
                StandardError  = (
                    [string]$invocation.StandardErrorContent
                ).Replace("`r", "")
            }
        }

        if (
            $invocation.Status -in @(
                "Failed",
                "Cancelled",
                "TimedOut",
                "Cancelling"
            )
        ) {
            return [pscustomobject]@{
                Status         = $invocation.Status
                ResponseCode   = $invocation.ResponseCode
                StandardOutput = (
                    [string]$invocation.StandardOutputContent
                ).Replace("`r", "")
                StandardError  = (
                    [string]$invocation.StandardErrorContent
                ).Replace("`r", "")
            }
        }
    }

    throw "The Systems Manager command did not finish in time."
}

Write-Host "Lab 13 - Independent application troubleshooting validation"

try {
    Write-Step "Prerequisites and identity"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    $identity = ConvertFrom-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    Test-Condition `
        -Condition (
            -not [string]::IsNullOrWhiteSpace([string]$identity.Account)
        ) `
        -SuccessMessage "AWS session is authenticated." `
        -FailureMessage "AWS identity could not be validated."

    Write-Step "Lab 08 network"

    $vpcResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $vpcs = @($vpcResponse.Vpcs)

    Test-Condition `
        -Condition ($vpcs.Count -eq 1) `
        -SuccessMessage "Exactly one available Lab 08 VPC exists." `
        -FailureMessage (
            "Expected one available Lab 08 VPC; found $($vpcs.Count)."
        )

    if ($vpcs.Count -ne 1) {
        throw "The Lab 08 VPC could not be uniquely identified."
    }

    $vpcId = $vpcs[0].VpcId

    $subnetResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--filters",
        "Name=tag:Name,Values=$SubnetName",
        "Name=vpc-id,Values=$vpcId",
        "Name=state,Values=available"
    )

    $subnets = @($subnetResponse.Subnets)

    Test-Condition `
        -Condition ($subnets.Count -eq 1) `
        -SuccessMessage "Exactly one Lab 08 application subnet exists." `
        -FailureMessage (
            "Expected one application subnet; found $($subnets.Count)."
        )

    if ($subnets.Count -ne 1) {
        throw "The Lab 08 subnet could not be uniquely identified."
    }

    $subnet = $subnets[0]
    $subnetId = $subnet.SubnetId

    Test-Condition `
        -Condition ($subnet.AvailabilityZone -eq "us-east-1a") `
        -SuccessMessage "The subnet belongs to us-east-1a." `
        -FailureMessage "The subnet does not belong to us-east-1a."

    Test-Condition `
        -Condition ([bool]$subnet.MapPublicIpOnLaunch) `
        -SuccessMessage "The subnet automatically assigns public IPv4." `
        -FailureMessage "The subnet does not automatically assign public IPv4."

    Write-Step "Security Group"

    $securityGroupResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$SecurityGroupName",
        "Name=vpc-id,Values=$vpcId"
    )

    $securityGroups = @($securityGroupResponse.SecurityGroups)

    Test-Condition `
        -Condition ($securityGroups.Count -eq 1) `
        -SuccessMessage "Exactly one Lab 13 Security Group exists." `
        -FailureMessage (
            "Expected one Lab 13 Security Group; " +
            "found $($securityGroups.Count)."
        )

    if ($securityGroups.Count -ne 1) {
        throw "The Lab 13 Security Group could not be uniquely identified."
    }

    $securityGroup = $securityGroups[0]
    $securityGroupId = $securityGroup.GroupId

    Test-RequiredTags `
        -ResourceDescription "Security Group" `
        -Tags $securityGroup.Tags

    $ingressPermissions = @($securityGroup.IpPermissions)

    Test-Condition `
        -Condition ($ingressPermissions.Count -eq 1) `
        -SuccessMessage "Security Group has exactly one ingress rule." `
        -FailureMessage (
            "Security Group does not have exactly one ingress rule."
        )

    $httpPermission = $ingressPermissions |
        Where-Object {
            $_.IpProtocol -eq "tcp" -and
            $_.FromPort -eq 80 -and
            $_.ToPort -eq 80
        } |
        Select-Object -First 1

    Test-Condition `
        -Condition ($null -ne $httpPermission) `
        -SuccessMessage "Ingress permits only TCP port 80." `
        -FailureMessage "The expected TCP port 80 rule was not found."

    if ($null -ne $httpPermission) {
        $ipv4Ranges = @($httpPermission.IpRanges)
        $ipv6Ranges = @($httpPermission.Ipv6Ranges)
        $prefixLists = @($httpPermission.PrefixListIds)
        $sourceGroups = @($httpPermission.UserIdGroupPairs)

        $isSingleIpv4Source = (
            $ipv4Ranges.Count -eq 1 -and
            $ipv4Ranges[0].CidrIp -match '/32$' -and
            $ipv6Ranges.Count -eq 0 -and
            $prefixLists.Count -eq 0 -and
            $sourceGroups.Count -eq 0
        )

        Test-Condition `
            -Condition $isSingleIpv4Source `
            -SuccessMessage (
                "HTTP access is restricted to one public IPv4 address."
            ) `
            -FailureMessage (
                "HTTP access is not restricted to one IPv4 /32 source."
            )
    }

    $sshPermission = $ingressPermissions |
        Where-Object {
            $_.IpProtocol -eq "-1" -or
            (
                $_.IpProtocol -eq "tcp" -and
                $_.FromPort -le 22 -and
                $_.ToPort -ge 22
            )
        }

    Test-Condition `
        -Condition (@($sshPermission).Count -eq 0) `
        -SuccessMessage "No ingress rule permits SSH on TCP port 22." `
        -FailureMessage "An ingress rule permits SSH on TCP port 22."

    Write-Step "EC2 instance"

    $instanceResponse = ConvertFrom-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $instances = @(
        $instanceResponse.Reservations |
            ForEach-Object { $_.Instances }
    )

    Test-Condition `
        -Condition ($instances.Count -eq 1) `
        -SuccessMessage "Exactly one active Lab 13 EC2 instance exists." `
        -FailureMessage (
            "Expected one active Lab 13 instance; found $($instances.Count)."
        )

    if ($instances.Count -ne 1) {
        throw "The Lab 13 EC2 instance could not be uniquely identified."
    }

    $instance = $instances[0]
    $instanceId = $instance.InstanceId
    $publicIpAddress = [string]$instance.PublicIpAddress

    Test-Condition `
        -Condition ($instance.State.Name -eq "running") `
        -SuccessMessage "The EC2 instance is running." `
        -FailureMessage (
            "The EC2 instance state is $($instance.State.Name)."
        )

    Test-Condition `
        -Condition (
            $instance.SubnetId -eq $subnetId -and
            $instance.Placement.AvailabilityZone -eq "us-east-1a"
        ) `
        -SuccessMessage "The instance uses the expected subnet and zone." `
        -FailureMessage (
            "The instance does not use the expected subnet and zone."
        )

    Test-RequiredTags `
        -ResourceDescription "EC2 instance" `
        -Tags $instance.Tags

    Test-Condition `
        -Condition ($null -eq $instance.KeyName) `
        -SuccessMessage "The instance has no SSH Key Pair." `
        -FailureMessage "The instance has an SSH Key Pair."

    Test-Condition `
        -Condition ($instance.MetadataOptions.HttpTokens -eq "required") `
        -SuccessMessage "The instance requires IMDSv2 tokens." `
        -FailureMessage "The instance does not require IMDSv2 tokens."

    $profileArn = [string]$instance.IamInstanceProfile.Arn

    Test-Condition `
        -Condition (
            $profileArn -match (
                "/{0}$" -f [regex]::Escape($InstanceProfileName)
            )
        ) `
        -SuccessMessage "The expected Instance Profile is attached." `
        -FailureMessage "The expected Instance Profile is not attached."

    Test-Condition `
        -Condition (
            -not [string]::IsNullOrWhiteSpace($publicIpAddress)
        ) `
        -SuccessMessage "The instance has a public IPv4 address." `
        -FailureMessage "The instance does not have a public IPv4 address."

    $instanceGroups = @($instance.SecurityGroups)

    Test-Condition `
        -Condition (
            $instanceGroups.Count -eq 1 -and
            $instanceGroups[0].GroupId -eq $securityGroupId
        ) `
        -SuccessMessage "The instance uses only the expected Security Group." `
        -FailureMessage (
            "The instance does not use only the expected Security Group."
        )

    $blockDevices = @($instance.BlockDeviceMappings)

    Test-Condition `
        -Condition ($blockDevices.Count -eq 1) `
        -SuccessMessage "The instance has one root EBS volume." `
        -FailureMessage "The instance does not have exactly one EBS volume."

    if ($blockDevices.Count -eq 1) {
        $volumeId = $blockDevices[0].Ebs.VolumeId

        $volumeResponse = ConvertFrom-AwsJson -Arguments @(
            "ec2", "describe-volumes",
            "--volume-ids", $volumeId
        )

        $volume = @($volumeResponse.Volumes)[0]

        Test-Condition `
            -Condition ([bool]$volume.Encrypted) `
            -SuccessMessage "The root EBS volume is encrypted." `
            -FailureMessage "The root EBS volume is not encrypted."

        Test-Condition `
            -Condition ($volume.VolumeType -eq "gp3") `
            -SuccessMessage "The root EBS volume uses gp3." `
            -FailureMessage "The root EBS volume does not use gp3."

        Test-Condition `
            -Condition (
                [bool]$blockDevices[0].Ebs.DeleteOnTermination
            ) `
            -SuccessMessage (
                "The root volume will be deleted with the instance."
            ) `
            -FailureMessage (
                "The root volume will not be deleted with the instance."
            )
    }

    Write-Step "IAM and Systems Manager"

    $roleResponse = ConvertFrom-AwsJson -Arguments @(
        "iam", "get-role",
        "--role-name", $RoleName
    )

    $role = $roleResponse.Role

    Test-Condition `
        -Condition ($null -ne $role) `
        -SuccessMessage "The Lab 13 IAM Role exists." `
        -FailureMessage "The Lab 13 IAM Role does not exist."

    Test-RequiredTags `
        -ResourceDescription "IAM Role" `
        -Tags $role.Tags

    $attachedPoliciesResponse = ConvertFrom-AwsJson -Arguments @(
        "iam", "list-attached-role-policies",
        "--role-name", $RoleName
    )

    $attachedPolicyArns = @(
        $attachedPoliciesResponse.AttachedPolicies |
            ForEach-Object { $_.PolicyArn }
    )

    Test-Condition `
        -Condition ($PolicyArn -in $attachedPolicyArns) `
        -SuccessMessage "AmazonSSMManagedInstanceCore is attached." `
        -FailureMessage "AmazonSSMManagedInstanceCore is not attached."

    $profileResponse = ConvertFrom-AwsJson -Arguments @(
        "iam", "get-instance-profile",
        "--instance-profile-name", $InstanceProfileName
    )

    $profileRoles = @($profileResponse.InstanceProfile.Roles)

    Test-Condition `
        -Condition (
            $profileRoles.Count -eq 1 -and
            $profileRoles[0].RoleName -eq $RoleName
        ) `
        -SuccessMessage (
            "IAM Role belongs to the expected Instance Profile."
        ) `
        -FailureMessage (
            "IAM Role does not belong to the expected Instance Profile."
        )

    $ssmResponse = ConvertFrom-AwsJson -Arguments @(
        "ssm", "describe-instance-information",
        "--filters", "Key=InstanceIds,Values=$instanceId"
    )

    $managedInstances = @($ssmResponse.InstanceInformationList)

    Test-Condition `
        -Condition ($managedInstances.Count -eq 1) `
        -SuccessMessage "The instance is registered in Systems Manager." `
        -FailureMessage (
            "The instance is not uniquely registered in Systems Manager."
        )

    if ($managedInstances.Count -eq 1) {
        $managedInstance = $managedInstances[0]

        Test-Condition `
            -Condition ($managedInstance.PingStatus -eq "Online") `
            -SuccessMessage "The instance is online in Systems Manager." `
            -FailureMessage "The instance is not online in Systems Manager."

        Test-Condition `
            -Condition (
                $managedInstance.PlatformName -match "Amazon Linux"
            ) `
            -SuccessMessage "The instance runs Amazon Linux." `
            -FailureMessage "The instance does not report Amazon Linux."
    }

    Write-Step "Operating system and Nginx"

    $remoteValidation = Invoke-SsmReadOnlyCommand `
        -InstanceId $instanceId `
        -Commands @(
            "set -o pipefail",
            "source /etc/os-release",
            "echo OS_ID=`$ID",
            "echo OS_VERSION=`$VERSION_ID",
            "echo NGINX_STATE=`$(systemctl is-active nginx)",
            "if pgrep -x nginx >/dev/null; then echo NGINX_PROCESS=present; else echo NGINX_PROCESS=absent; fi",
            "if ss -lnt | grep -Eq ':[[:space:]]*80[[:space:]]|:80[[:space:]]'; then echo PORT_80=listening; else echo PORT_80=closed; fi",
            "nginx -t >/tmp/lab13-nginx-test.txt 2>&1",
            "echo NGINX_TEST=`$?",
            "cat /tmp/lab13-nginx-test.txt",
            "echo ROOT_RESPONSE=`$(curl --fail --silent --show-error http://127.0.0.1/ | tr -d '\r\n')",
            "echo HEALTH_RESPONSE=`$(curl --fail --silent --show-error http://127.0.0.1/health | tr -d '\r\n')"
        )

    Test-Condition `
        -Condition ($remoteValidation.Status -eq "Success") `
        -SuccessMessage "Read-only operating system check succeeded." `
        -FailureMessage (
            "Read-only operating system check failed: " +
            $remoteValidation.StandardError
        )

    $remoteOutput = $remoteValidation.StandardOutput

    Test-Condition `
        -Condition (
            $remoteOutput -match "(?m)^OS_ID=amzn$" -and
            $remoteOutput -match "(?m)^OS_VERSION=2023"
        ) `
        -SuccessMessage "The instance runs Amazon Linux 2023." `
        -FailureMessage "Amazon Linux 2023 was not confirmed."

    Test-Condition `
        -Condition (
            $remoteOutput -match "(?m)^NGINX_STATE=active$"
        ) `
        -SuccessMessage "The Nginx service is active." `
        -FailureMessage "The Nginx service is not active."

    Test-Condition `
        -Condition (
            $remoteOutput -match "(?m)^NGINX_PROCESS=present$"
        ) `
        -SuccessMessage "The Nginx process exists." `
        -FailureMessage "The Nginx process was not found."

    Test-Condition `
        -Condition (
            $remoteOutput -match "(?m)^PORT_80=listening$"
        ) `
        -SuccessMessage "Nginx is listening on TCP port 80." `
        -FailureMessage "TCP port 80 is not listening."

    Test-Condition `
        -Condition (
            $remoteOutput -match "(?m)^NGINX_TEST=0$"
        ) `
        -SuccessMessage "The Nginx configuration is valid." `
        -FailureMessage "The Nginx configuration test failed."

    Test-Condition `
        -Condition (
            $remoteOutput -match
                "ROOT_RESPONSE=.*Lab 13.+Application Troubleshooting"
        ) `
        -SuccessMessage "The local application content is correct." `
        -FailureMessage "The local application content is unexpected."

    Test-Condition `
        -Condition (
            $remoteOutput -match "(?m)^HEALTH_RESPONSE=healthy$"
        ) `
        -SuccessMessage "The local health endpoint is healthy." `
        -FailureMessage "The local health endpoint is unexpected."

    Write-Step "Public HTTP validation"

    if (-not [string]::IsNullOrWhiteSpace($publicIpAddress)) {
        try {
            $pageResponse = Invoke-WebRequest `
                -Uri "http://$publicIpAddress/" `
                -UseBasicParsing `
                -DisableKeepAlive `
                -TimeoutSec 15

            Test-Condition `
                -Condition (
                    $pageResponse.StatusCode -eq 200 -and
                    $pageResponse.Content -match
                        "Lab 13.+Application Troubleshooting"
                ) `
                -SuccessMessage (
                    "The application returned the expected HTTP response."
                ) `
                -FailureMessage (
                    "The application returned unexpected HTTP content."
                )
        }
        catch {
            Add-Failure (
                "The application could not be reached over HTTP: " +
                $_.Exception.Message
            )
        }

        try {
            $healthResponse = Invoke-WebRequest `
                -Uri "http://$publicIpAddress/health" `
                -UseBasicParsing `
                -DisableKeepAlive `
                -TimeoutSec 15

            Test-Condition `
                -Condition (
                    $healthResponse.StatusCode -eq 200 -and
                    $healthResponse.Content.Trim() -eq "healthy"
                ) `
                -SuccessMessage (
                    "The public health endpoint returned HTTP 200."
                ) `
                -FailureMessage (
                    "The public health endpoint returned unexpected content."
                )
        }
        catch {
            Add-Failure (
                "The public health endpoint could not be reached: " +
                $_.Exception.Message
            )
        }
    }
    else {
        Add-Failure "Public HTTP validation could not be performed."
    }

    Write-Host ""

    if ($Failures -gt 0) {
        Write-Host (
            "VALIDATION FAILED: $Failures check(s) failed."
        ) -ForegroundColor Red

        exit 1
    }

    Write-Host "VALIDATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host ("VPC:               {0}" -f $vpcId)
    Write-Host ("Subnet:            {0}" -f $subnetId)
    Write-Host ("Security Group:    {0}" -f $securityGroupId)
    Write-Host ("Instance:          {0}" -f $instanceId)
    Write-Host ("Public IPv4:       {0}" -f $publicIpAddress)
    Write-Host ("Application URL:   http://{0}/" -f $publicIpAddress)
    Write-Host ("Health URL:        http://{0}/health" -f $publicIpAddress)
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host (
        "VALIDATION FAILED: $Failures recorded check(s) plus a fatal error."
    ) -ForegroundColor Red

    exit 1
}
