[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProfileName = "cloud-operations-lab",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Region = "us-east-1",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AvailabilityZoneA = "us-east-1a",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AvailabilityZoneB = "us-east-1b"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$VpcCidr = "10.20.0.0/16"
$SubnetAName = "lab08-public-subnet-a"
$SubnetACidr = "10.20.10.0/24"
$SubnetBName = "lab08-public-subnet-b"
$SubnetBCidr = "10.20.20.0/24"
$InternetGatewayName = "lab08-internet-gateway"
$RouteTableName = "lab08-public-route-table"
$SecurityGroupName = "lab08-application-sg"

$script:FailureCount = 0

function Write-Pass {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Fail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:FailureCount++
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $Output = & aws @Arguments `
        --profile $ProfileName `
        --region $Region `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI command failed: $($Output -join ' ')"
    }

    $Text = $Output -join [Environment]::NewLine

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    return ($Text | ConvertFrom-Json)
}

function Test-ExpectedTags {
    param(
        [Parameter(Mandatory = $true)]
        $Tags,

        [Parameter(Mandatory = $true)]
        [string]$ResourceLabel
    )

    $RequiredTags = @{
        Project     = "cloud-infrastructure-operations-lab"
        Environment = "lab"
        Lab         = "08"
        ManagedBy   = "aws-cli"
        Owner       = "itamarsb"
    }

    $TagMap = @{}

    foreach ($Tag in @($Tags)) {
        $TagMap[$Tag.Key] = $Tag.Value
    }

    $TagsValid = $true

    foreach ($Key in $RequiredTags.Keys) {
        if (
            -not $TagMap.ContainsKey($Key) -or
            $TagMap[$Key] -ne $RequiredTags[$Key]
        ) {
            $TagsValid = $false
        }
    }

    if ($TagsValid) {
        Write-Pass "$ResourceLabel contains the required operational tags."
    }
    else {
        Write-Fail "$ResourceLabel does not contain all required operational tags."
    }
}

try {
    Write-Host ""
    Write-Host "Lab 08 - AWS application network validation"
    Write-Host "Profile: $ProfileName"
    Write-Host "Region:  $Region"

    Write-Host ""
    Write-Host "=== Prerequisite validation ===" -ForegroundColor Cyan

    $AwsVersion = (& aws --version 2>&1) -join " "

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI is not available."
    }

    Write-Pass "AWS CLI available: $AwsVersion"

    $null = Invoke-AwsJson -Arguments @(
        "sts",
        "get-caller-identity"
    )

    Write-Pass "AWS session validated without displaying account identifiers."

    Write-Host ""
    Write-Host "=== VPC validation ===" -ForegroundColor Cyan

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName"
    )

    $Vpcs = @($VpcResult.Vpcs)

    if ($Vpcs.Count -ne 1) {
        throw "Expected exactly one VPC named $VpcName; found $($Vpcs.Count)."
    }

    $Vpc = $Vpcs[0]
    $VpcId = $Vpc.VpcId

    if (
        $Vpc.State -eq "available" -and
        $Vpc.CidrBlock -eq $VpcCidr
    ) {
        Write-Pass "VPC is available with CIDR $VpcCidr."
    }
    else {
        Write-Fail "VPC state or CIDR differs from the expected configuration."
    }

    $DnsSupport = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpc-attribute",
        "--vpc-id",
        $VpcId,
        "--attribute",
        "enableDnsSupport"
    )

    $DnsHostnames = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpc-attribute",
        "--vpc-id",
        $VpcId,
        "--attribute",
        "enableDnsHostnames"
    )

    if (
        $DnsSupport.EnableDnsSupport.Value -and
        $DnsHostnames.EnableDnsHostnames.Value
    ) {
        Write-Pass "DNS support and DNS hostnames are enabled."
    }
    else {
        Write-Fail "DNS support or DNS hostnames are not enabled."
    }

    Test-ExpectedTags `
        -Tags $Vpc.Tags `
        -ResourceLabel "VPC"

    Write-Host ""
    Write-Host "=== Public subnet validation ===" -ForegroundColor Cyan

    $SubnetResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$VpcId"
    )

    $Subnets = @($SubnetResult.Subnets)

    $ExpectedSubnets = @(
        @{
            Name = $SubnetAName
            Cidr = $SubnetACidr
            Zone = $AvailabilityZoneA
        },
        @{
            Name = $SubnetBName
            Cidr = $SubnetBCidr
            Zone = $AvailabilityZoneB
        }
    )

    $ValidatedSubnetIds = @()

    foreach ($ExpectedSubnet in $ExpectedSubnets) {
        $Matches = @(
            $Subnets | Where-Object {
                $MatchingNameTags = @(
                    $_.Tags | Where-Object {
                        $_.Key -eq "Name" -and
                        $_.Value -eq $ExpectedSubnet.Name
                    }
                )

                $MatchingNameTags.Count -eq 1
            }
        )

        if ($Matches.Count -ne 1) {
            Write-Fail "Expected exactly one subnet named $($ExpectedSubnet.Name)."
            continue
        }

        $Subnet = $Matches[0]
        $ValidatedSubnetIds += $Subnet.SubnetId

        if (
            $Subnet.State -eq "available" -and
            $Subnet.CidrBlock -eq $ExpectedSubnet.Cidr -and
            $Subnet.AvailabilityZone -eq $ExpectedSubnet.Zone -and
            $Subnet.MapPublicIpOnLaunch
        ) {
            Write-Pass "$($ExpectedSubnet.Name) is available in $($ExpectedSubnet.Zone) with the expected CIDR and public IPv4 mapping."
        }
        else {
            Write-Fail "$($ExpectedSubnet.Name) differs from the expected network configuration."
        }

        Test-ExpectedTags `
            -Tags $Subnet.Tags `
            -ResourceLabel $ExpectedSubnet.Name
    }

    Write-Host ""
    Write-Host "=== Internet Gateway validation ===" -ForegroundColor Cyan

    $IgwResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-internet-gateways",
        "--filters",
        "Name=attachment.vpc-id,Values=$VpcId"
    )

    $Gateways = @($IgwResult.InternetGateways)

    $NamedGateways = @(
        $Gateways | Where-Object {
            $MatchingNameTags = @(
                $_.Tags | Where-Object {
                    $_.Key -eq "Name" -and
                    $_.Value -eq $InternetGatewayName
                }
            )

            $MatchingNameTags.Count -eq 1
        }
    )

    if ($NamedGateways.Count -ne 1) {
        throw "Expected exactly one attached Internet Gateway named $InternetGatewayName."
    }

    $InternetGateway = $NamedGateways[0]
    $InternetGatewayId = $InternetGateway.InternetGatewayId

    $ExpectedAttachments = @(
        $InternetGateway.Attachments | Where-Object {
            $_.VpcId -eq $VpcId -and
            $_.State -eq "available"
        }
    )

    if ($ExpectedAttachments.Count -eq 1) {
        Write-Pass "Internet Gateway is attached to the VPC."
    }
    else {
        Write-Fail "Internet Gateway attachment differs from the expected configuration."
    }

    Test-ExpectedTags `
        -Tags $InternetGateway.Tags `
        -ResourceLabel "Internet Gateway"

    Write-Host ""
    Write-Host "=== Public route table validation ===" -ForegroundColor Cyan

    $RouteTableResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-route-tables",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$RouteTableName"
    )

    $RouteTables = @($RouteTableResult.RouteTables)

    if ($RouteTables.Count -ne 1) {
        throw "Expected exactly one route table named $RouteTableName."
    }

    $RouteTable = $RouteTables[0]

    $DefaultRoutes = @(
        $RouteTable.Routes | Where-Object {
            $_.DestinationCidrBlock -eq "0.0.0.0/0" -and
            $_.GatewayId -eq $InternetGatewayId -and
            $_.State -eq "active"
        }
    )

    if ($DefaultRoutes.Count -eq 1) {
        Write-Pass "Active default route points to the Internet Gateway."
    }
    else {
        Write-Fail "The expected active default route was not found."
    }

    $AssociatedSubnetIds = @(
        $RouteTable.Associations |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.SubnetId)
            } |
            ForEach-Object {
                $_.SubnetId
            }
    )

    $AssociationsValid = $true

    if ($ValidatedSubnetIds.Count -ne 2) {
        $AssociationsValid = $false
    }

    foreach ($ExpectedSubnetId in $ValidatedSubnetIds) {
        if ($ExpectedSubnetId -notin $AssociatedSubnetIds) {
            $AssociationsValid = $false
        }
    }

    if (
        $AssociationsValid -and
        $AssociatedSubnetIds.Count -eq 2
    ) {
        Write-Pass "Public route table is explicitly associated with both expected subnets."
    }
    else {
        Write-Fail "Public route table associations differ from the expected configuration."
    }

    Test-ExpectedTags `
        -Tags $RouteTable.Tags `
        -ResourceLabel "Public route table"

    Write-Host ""
    Write-Host "=== Security Group validation ===" -ForegroundColor Cyan

    $SecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$SecurityGroupName"
    )

    $SecurityGroups = @($SecurityGroupResult.SecurityGroups)

    if ($SecurityGroups.Count -ne 1) {
        throw "Expected exactly one Security Group named $SecurityGroupName."
    }

    $SecurityGroup = $SecurityGroups[0]
    $IngressRules = @($SecurityGroup.IpPermissions)

    if ($IngressRules.Count -eq 0) {
        Write-Pass "Security Group contains no ingress rules."
    }
    else {
        Write-Fail "Security Group contains unexpected ingress rules."
    }

    Test-ExpectedTags `
        -Tags $SecurityGroup.Tags `
        -ResourceLabel "Security Group"

    Write-Host ""
    Write-Host "=== Validation summary ===" -ForegroundColor Cyan

    if ($script:FailureCount -eq 0) {
        Write-Host ""
        Write-Host "VALIDATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
        Write-Host "All mandatory network components match the expected configuration."
        Write-Host "No AWS resource was created, altered, or removed."
        exit 0
    }

    Write-Host ""
    Write-Host "VALIDATION COMPLETED WITH $script:FailureCount FAILURE(S)" -ForegroundColor Red
    Write-Host "No AWS resource was created, altered, or removed."
    exit 1
}
catch {
    Write-Host ""
    Write-Host "[FAIL] Validation could not be completed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "No AWS resource was created, altered, or removed."
    exit 1
}
