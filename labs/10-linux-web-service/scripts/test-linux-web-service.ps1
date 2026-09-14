[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AllowedHttpCidr
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab10-linux-web-server"
$SecurityGroupName = "lab10-linux-web-sg"
$RoleName = "lab10-ec2-ssm-role"
$InstanceProfileName = "lab10-ec2-ssm-instance-profile"

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
            Where-Object { $_.Key -eq $Key }
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

function Test-AllowedHttpCidr {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Cidr
    )

    if ($Cidr -notmatch "^([^/]+)/32$") {
        return $false
    }

    $IpText = [string]$Matches[1]
    $IpAddress = $null

    if (
        -not [System.Net.IPAddress]::TryParse(
            $IpText,
            [ref]$IpAddress
        )
    ) {
        return $false
    }

    if (
        $IpAddress.AddressFamily -ne
        [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {
        return $false
    }

    if (
        $IpText -eq "0.0.0.0" -or
        $IpText -eq "255.255.255.255"
    ) {
        return $false
    }

    return $true
}

try {
    Write-Host "Lab 10 - Independent web service validation"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI was not found."
    }

    if (-not (Test-AllowedHttpCidr -Cidr $AllowedHttpCidr)) {
        throw "AllowedHttpCidr must contain one valid public IPv4 address using /32."
    }

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
        -Message "Exactly one Lab 10 EC2 instance exists."

    if ($Instances.Count -ne 1) {
        throw "The Lab 10 instance cannot be validated uniquely."
    }

    $Instance = $Instances[0]
    $InstanceId = [string]$Instance.InstanceId

    Assert-Check `
        -Condition ($Instance.State.Name -eq "running") `
        -Message "EC2 instance is running."

    Assert-Check `
        -Condition (
            (Get-TagValue -Tags @($Instance.Tags) -Key "Project") -eq
            "cloud-infrastructure-operations-lab"
        ) `
        -Message "Expected Project tag is present."

    Assert-Check `
        -Condition (
            (Get-TagValue -Tags @($Instance.Tags) -Key "Lab") -eq "10"
        ) `
        -Message "Expected Lab tag is present."

    Assert-Check `
        -Condition (
            (Get-TagValue -Tags @($Instance.Tags) -Key "Service") -eq "nginx"
        ) `
        -Message "Expected Service tag is present."

    $KeyName = Get-OptionalPropertyValue `
        -InputObject $Instance `
        -PropertyName "KeyName"

    Assert-Check `
        -Condition ([string]::IsNullOrWhiteSpace([string]$KeyName)) `
        -Message "No SSH Key Pair is associated."

    $MetadataOptions = Get-OptionalPropertyValue `
        -InputObject $Instance `
        -PropertyName "MetadataOptions"

    $HttpTokens = Get-OptionalPropertyValue `
        -InputObject $MetadataOptions `
        -PropertyName "HttpTokens"

    Assert-Check `
        -Condition ($HttpTokens -eq "required") `
        -Message "IMDSv2 tokens are mandatory."

    $IamInstanceProfile = Get-OptionalPropertyValue `
        -InputObject $Instance `
        -PropertyName "IamInstanceProfile"

    $IamInstanceProfileArn = Get-OptionalPropertyValue `
        -InputObject $IamInstanceProfile `
        -PropertyName "Arn"

    Assert-Check `
        -Condition (
            [string]$IamInstanceProfileArn -match
            "/$([regex]::Escape($InstanceProfileName))$"
        ) `
        -Message "Expected Instance Profile is associated."

    $PublicIpAddress = Get-OptionalPropertyValue `
        -InputObject $Instance `
        -PropertyName "PublicIpAddress"

    Assert-Check `
        -Condition (
            -not [string]::IsNullOrWhiteSpace(
                [string]$PublicIpAddress
            )
        ) `
        -Message "Instance has a public IPv4 address."

    $SecurityGroups = @($Instance.SecurityGroups)

    Assert-Check `
        -Condition ($SecurityGroups.Count -eq 1) `
        -Message "Exactly one Security Group is associated."

    if ($SecurityGroups.Count -eq 1) {
        Assert-Check `
            -Condition ($SecurityGroups[0].GroupName -eq $SecurityGroupName) `
            -Message "Expected Security Group is associated."

        $SecurityGroupResult = Invoke-AwsJson -Arguments @(
            "ec2",
            "describe-security-groups",
            "--group-ids",
            $SecurityGroups[0].GroupId
        )

        $SecurityGroup = $SecurityGroupResult.SecurityGroups[0]
        $IngressRules = @($SecurityGroup.IpPermissions)

        Assert-Check `
            -Condition ($IngressRules.Count -eq 1) `
            -Message "Security Group has exactly one ingress rule."

        if ($IngressRules.Count -eq 1) {
            $HttpRule = $IngressRules[0]

            Assert-Check `
                -Condition (
                    $HttpRule.IpProtocol -eq "tcp" -and
                    [int]$HttpRule.FromPort -eq 80 -and
                    [int]$HttpRule.ToPort -eq 80
                ) `
                -Message "The only ingress rule permits TCP port 80."

            $Ipv4Ranges = @(
                Get-OptionalPropertyValue `
                    -InputObject $HttpRule `
                    -PropertyName "IpRanges"
            )

            $Ipv6Ranges = @(
                Get-OptionalPropertyValue `
                    -InputObject $HttpRule `
                    -PropertyName "Ipv6Ranges"
            )

            $PrefixListIds = @(
                Get-OptionalPropertyValue `
                    -InputObject $HttpRule `
                    -PropertyName "PrefixListIds"
            )

            $UserIdGroupPairs = @(
                Get-OptionalPropertyValue `
                    -InputObject $HttpRule `
                    -PropertyName "UserIdGroupPairs"
            )

            Assert-Check `
                -Condition (
                    $Ipv4Ranges.Count -eq 1 -and
                    $Ipv4Ranges[0].CidrIp -eq $AllowedHttpCidr
                ) `
                -Message "HTTP access is restricted to $AllowedHttpCidr."

            Assert-Check `
                -Condition (
                    $Ipv6Ranges.Count -eq 0 -and
                    $PrefixListIds.Count -eq 0 -and
                    $UserIdGroupPairs.Count -eq 0
                ) `
                -Message "No additional ingress source is authorized."
        }

        $SshRules = @(
            $IngressRules |
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
            -Message "No ingress rule permits SSH on TCP port 22."
    }

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
        -Condition (
            @($PolicyResult.AttachedPolicies.PolicyArn) -contains $PolicyArn
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
            @($ProfileResult.InstanceProfile.Roles.RoleName) -contains $RoleName
        ) `
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
        $ManagedNode = $ManagedNodes[0]

        Assert-Check `
            -Condition ($ManagedNode.PingStatus -eq "Online") `
            -Message "Systems Manager reports the instance as online."

        Assert-Check `
            -Condition (
                $ManagedNode.PlatformName -eq "Amazon Linux" -and
                [string]$ManagedNode.PlatformVersion -match "^2023"
            ) `
            -Message "Operating system is Amazon Linux 2023."
    }

    if (
        $ManagedNodes.Count -eq 1 -and
        $ManagedNodes[0].PingStatus -eq "Online"
    ) {
        $RemoteCommand = "set -e; systemctl is-active nginx; systemctl is-enabled nginx; test -f /var/lib/cloud/instance/lab10-nginx-ready; curl -fsS http://localhost/ | grep -q 'Lab 10'; printf 'LAB10_SYSTEMD_OK\n'"

        $CommandResult = Invoke-AwsJson -Arguments @(
            "ssm",
            "send-command",
            "--instance-ids",
            $InstanceId,
            "--document-name",
            "AWS-RunShellScript",
            "--comment",
            "Lab 10 read-only Nginx validation",
            "--parameters",
            "commands=$RemoteCommand"
        )

        $CommandId = [string]$CommandResult.Command.CommandId
        $CommandCompleted = $false
        $CommandInvocation = $null

        for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
            Start-Sleep -Seconds 2

            $CommandInvocation = Invoke-AwsJson -Arguments @(
                "ssm",
                "get-command-invocation",
                "--command-id",
                $CommandId,
                "--instance-id",
                $InstanceId
            )

            if ($CommandInvocation.Status -eq "Success") {
                $CommandCompleted = $true
                break
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

        Assert-Check `
            -Condition ($CommandCompleted) `
            -Message "Read-only Systems Manager command completed successfully."

        if ($CommandCompleted) {
            Assert-Check `
                -Condition (
                    [string]$CommandInvocation.StandardOutputContent -match
                    "active"
                ) `
                -Message "Nginx is active in systemd."

            Assert-Check `
                -Condition (
                    [string]$CommandInvocation.StandardOutputContent -match
                    "enabled"
                ) `
                -Message "Nginx is enabled in systemd."

            Assert-Check `
                -Condition (
                    [string]$CommandInvocation.StandardOutputContent -match
                    "LAB10_SYSTEMD_OK"
                ) `
                -Message "Local HTTP validation returned the expected content."
        }
        else {
            $CommandError = Get-OptionalPropertyValue `
                -InputObject $CommandInvocation `
                -PropertyName "StandardErrorContent"

            if (-not [string]::IsNullOrWhiteSpace([string]$CommandError)) {
                Write-Host "[INFO] Remote command error: $CommandError" `
                    -ForegroundColor Yellow
            }
        }
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$PublicIpAddress
        )
    ) {
        $WebUrl = "http://$PublicIpAddress/"

        try {
            $Response = Invoke-WebRequest `
                -Uri $WebUrl `
                -UseBasicParsing `
                -TimeoutSec 15

            Assert-Check `
                -Condition ($Response.StatusCode -eq 200) `
                -Message "External web request returned HTTP 200."

            Assert-Check `
                -Condition ($Response.Content -match "Lab 10") `
                -Message "External web page contains the expected Lab 10 content."
        }
        catch {
            Assert-Check `
                -Condition $false `
                -Message "External HTTP validation failed."

            Write-Host "[INFO] $($_.Exception.Message)" `
                -ForegroundColor Yellow
        }
    }

    Write-Host ""

    if ($Failures -gt 0) {
        Write-Host "VALIDATION FAILED: $Failures check(s) failed." `
            -ForegroundColor Red

        exit 1
    }

    Write-Host "VALIDATION COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green

    Write-Host "Instance ID:      $InstanceId"
    Write-Host "Public IPv4:      $PublicIpAddress"
    Write-Host "HTTP source CIDR: $AllowedHttpCidr"

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red

    exit 1
}
