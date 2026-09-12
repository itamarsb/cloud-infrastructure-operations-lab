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

$ProjectName = "cloud-infrastructure-operations-lab"
$EnvironmentName = "lab"
$LabNumber = "08"
$ManagedBy = "aws-cli"
$Owner = "itamarsb"

$VpcName = "lab08-application-vpc"
$VpcCidr = "10.20.0.0/16"

$SubnetAName = "lab08-public-subnet-a"
$SubnetACidr = "10.20.10.0/24"

$SubnetBName = "lab08-public-subnet-b"
$SubnetBCidr = "10.20.20.0/24"

$InternetGatewayName = "lab08-internet-gateway"
$RouteTableName = "lab08-public-route-table"
$SecurityGroupName = "lab08-application-sg"
$SecurityGroupDescription = "Lab 08 application network security group"

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

function Invoke-AwsText {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $CommandOutput = & aws @Arguments 2>&1
    $CommandExitCode = $LASTEXITCODE

    $CommandText = (
        $CommandOutput |
        ForEach-Object {
            $_.ToString()
        }
    ) -join [Environment]::NewLine

    if ($CommandExitCode -ne 0) {
        throw "AWS CLI command failed with exit code $CommandExitCode.`n$CommandText"
    }

    return $CommandText.Trim()
}

function New-TagSpecification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,

        [Parameter(Mandatory = $true)]
        [string]$ResourceName
    )

    return (
        "ResourceType=$ResourceType," +
        "Tags=[" +
        "{Key=Name,Value=$ResourceName}," +
        "{Key=Project,Value=$ProjectName}," +
        "{Key=Environment,Value=$EnvironmentName}," +
        "{Key=Lab,Value=$LabNumber}," +
        "{Key=ManagedBy,Value=$ManagedBy}," +
        "{Key=Owner,Value=$Owner}" +
        "]"
    )
}

try {
    Write-Host ""
    Write-Host "Lab 08 - AWS application network deployment" `
        -ForegroundColor White

    Write-Host "Profile: $ProfileName"
    Write-Host "Region:  $Region"
    Write-Host "VPC CIDR: $VpcCidr"

    Write-Step "Prerequisite validation"

    $AwsVersion = & aws --version 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI was not found or could not be executed."
    }

    Write-Ok "AWS CLI available: $AwsVersion"

    Invoke-AwsText -Arguments @(
        "sts",
        "get-caller-identity",
        "--profile", $ProfileName,
        "--query", "Account",
        "--output", "text"
    ) | Out-Null

    Write-Ok "AWS session validated without displaying account identifiers."

    if ($AvailabilityZoneA -eq $AvailabilityZoneB) {
        throw "Two different Availability Zones are required."
    }

    foreach ($AvailabilityZone in @(
        $AvailabilityZoneA,
        $AvailabilityZoneB
    )) {
        $ZoneState = Invoke-AwsText -Arguments @(
            "ec2",
            "describe-availability-zones",
            "--profile", $ProfileName,
            "--region", $Region,
            "--zone-names", $AvailabilityZone,
            "--query", "AvailabilityZones[0].State",
            "--output", "text"
        )

        if ($ZoneState -ne "available") {
            throw (
                "Availability Zone $AvailabilityZone is not available " +
                "in the selected account and Region."
            )
        }

        Write-Ok "Availability Zone $AvailabilityZone is available."
    }

    Write-Step "Conflict verification"

    $ExistingVpcByCidr = Invoke-AwsText -Arguments @(
        "ec2",
        "describe-vpcs",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=cidr,Values=$VpcCidr",
        "--query", "Vpcs[].VpcId",
        "--output", "text"
    )

    if (
        -not [string]::IsNullOrWhiteSpace($ExistingVpcByCidr) -and
        $ExistingVpcByCidr -ne "None"
    ) {
        throw (
            "CIDR $VpcCidr is already associated with an existing VPC. " +
            "No resource was created."
        )
    }

    $ExistingLabVpc = Invoke-AwsText -Arguments @(
        "ec2",
        "describe-vpcs",
        "--profile", $ProfileName,
        "--region", $Region,
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=tag:Project,Values=$ProjectName",
        "Name=tag:Lab,Values=$LabNumber",
        "--query", "Vpcs[].VpcId",
        "--output", "text"
    )

    if (
        -not [string]::IsNullOrWhiteSpace($ExistingLabVpc) -and
        $ExistingLabVpc -ne "None"
    ) {
        throw (
            "A VPC identified as belonging to Lab 08 already exists. " +
            "Run the validation script instead of creating another network."
        )
    }

    Write-Ok "No conflicting VPC was found."
    Write-Ok "CIDR $VpcCidr is available."

    Write-Step "VPC creation"

    $VpcTags = New-TagSpecification `
        -ResourceType "vpc" `
        -ResourceName $VpcName

    $VpcId = Invoke-AwsText -Arguments @(
        "ec2",
        "create-vpc",
        "--profile", $ProfileName,
        "--region", $Region,
        "--cidr-block", $VpcCidr,
        "--instance-tenancy", "default",
        "--tag-specifications", $VpcTags,
        "--query", "Vpc.VpcId",
        "--output", "text"
    )

    if ([string]::IsNullOrWhiteSpace($VpcId)) {
        throw "AWS did not return the identifier of the created VPC."
    }

    Invoke-AwsText -Arguments @(
        "ec2",
        "wait",
        "vpc-available",
        "--profile", $ProfileName,
        "--region", $Region,
        "--vpc-ids", $VpcId
    ) | Out-Null

    Write-Ok "VPC created and available with CIDR $VpcCidr."

    Invoke-AwsText -Arguments @(
        "ec2",
        "modify-vpc-attribute",
        "--profile", $ProfileName,
        "--region", $Region,
        "--vpc-id", $VpcId,
        "--enable-dns-support", "Value=true"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "ec2",
        "modify-vpc-attribute",
        "--profile", $ProfileName,
        "--region", $Region,
        "--vpc-id", $VpcId,
        "--enable-dns-hostnames", "Value=true"
    ) | Out-Null

    Write-Ok "DNS support and DNS hostnames enabled."

    Write-Step "Public subnet creation"

    $SubnetATags = New-TagSpecification `
        -ResourceType "subnet" `
        -ResourceName $SubnetAName

    $SubnetAId = Invoke-AwsText -Arguments @(
        "ec2",
        "create-subnet",
        "--profile", $ProfileName,
        "--region", $Region,
        "--vpc-id", $VpcId,
        "--cidr-block", $SubnetACidr,
        "--availability-zone", $AvailabilityZoneA,
        "--tag-specifications", $SubnetATags,
        "--query", "Subnet.SubnetId",
        "--output", "text"
    )

    $SubnetBTags = New-TagSpecification `
        -ResourceType "subnet" `
        -ResourceName $SubnetBName

    $SubnetBId = Invoke-AwsText -Arguments @(
        "ec2",
        "create-subnet",
        "--profile", $ProfileName,
        "--region", $Region,
        "--vpc-id", $VpcId,
        "--cidr-block", $SubnetBCidr,
        "--availability-zone", $AvailabilityZoneB,
        "--tag-specifications", $SubnetBTags,
        "--query", "Subnet.SubnetId",
        "--output", "text"
    )

    Invoke-AwsText -Arguments @(
        "ec2",
        "wait",
        "subnet-available",
        "--profile", $ProfileName,
        "--region", $Region,
        "--subnet-ids", $SubnetAId, $SubnetBId
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "ec2",
        "modify-subnet-attribute",
        "--profile", $ProfileName,
        "--region", $Region,
        "--subnet-id", $SubnetAId,
        "--map-public-ip-on-launch", "Value=true"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "ec2",
        "modify-subnet-attribute",
        "--profile", $ProfileName,
        "--region", $Region,
        "--subnet-id", $SubnetBId,
        "--map-public-ip-on-launch", "Value=true"
    ) | Out-Null

    Write-Ok (
        "$SubnetAName created in $AvailabilityZoneA " +
        "with CIDR $SubnetACidr."
    )

    Write-Ok (
        "$SubnetBName created in $AvailabilityZoneB " +
        "with CIDR $SubnetBCidr."
    )

    Write-Ok "Automatic public IPv4 assignment enabled on both subnets."

    Write-Step "Internet Gateway creation"

    $InternetGatewayTags = New-TagSpecification `
        -ResourceType "internet-gateway" `
        -ResourceName $InternetGatewayName

    $InternetGatewayId = Invoke-AwsText -Arguments @(
        "ec2",
        "create-internet-gateway",
        "--profile", $ProfileName,
        "--region", $Region,
        "--tag-specifications", $InternetGatewayTags,
        "--query", "InternetGateway.InternetGatewayId",
        "--output", "text"
    )

    Invoke-AwsText -Arguments @(
        "ec2",
        "attach-internet-gateway",
        "--profile", $ProfileName,
        "--region", $Region,
        "--internet-gateway-id", $InternetGatewayId,
        "--vpc-id", $VpcId
    ) | Out-Null

    Write-Ok "Internet Gateway created and attached to the VPC."

    Write-Step "Public route table creation"

    $RouteTableTags = New-TagSpecification `
        -ResourceType "route-table" `
        -ResourceName $RouteTableName

    $RouteTableId = Invoke-AwsText -Arguments @(
        "ec2",
        "create-route-table",
        "--profile", $ProfileName,
        "--region", $Region,
        "--vpc-id", $VpcId,
        "--tag-specifications", $RouteTableTags,
        "--query", "RouteTable.RouteTableId",
        "--output", "text"
    )

    $RouteCreated = Invoke-AwsText -Arguments @(
        "ec2",
        "create-route",
        "--profile", $ProfileName,
        "--region", $Region,
        "--route-table-id", $RouteTableId,
        "--destination-cidr-block", "0.0.0.0/0",
        "--gateway-id", $InternetGatewayId,
        "--query", "Return",
        "--output", "text"
    )

    if ($RouteCreated -ne "True") {
        throw "AWS did not confirm creation of the default route."
    }

    Invoke-AwsText -Arguments @(
        "ec2",
        "associate-route-table",
        "--profile", $ProfileName,
        "--region", $Region,
        "--route-table-id", $RouteTableId,
        "--subnet-id", $SubnetAId,
        "--query", "AssociationId",
        "--output", "text"
    ) | Out-Null

    Invoke-AwsText -Arguments @(
        "ec2",
        "associate-route-table",
        "--profile", $ProfileName,
        "--region", $Region,
        "--route-table-id", $RouteTableId,
        "--subnet-id", $SubnetBId,
        "--query", "AssociationId",
        "--output", "text"
    ) | Out-Null

    Write-Ok "Default route created through the Internet Gateway."
    Write-Ok "Public route table associated with both subnets."

    Write-Step "Security Group creation"

    $SecurityGroupTags = New-TagSpecification `
        -ResourceType "security-group" `
        -ResourceName $SecurityGroupName

    $SecurityGroupId = Invoke-AwsText -Arguments @(
        "ec2",
        "create-security-group",
        "--profile", $ProfileName,
        "--region", $Region,
        "--group-name", $SecurityGroupName,
        "--description", $SecurityGroupDescription,
        "--vpc-id", $VpcId,
        "--tag-specifications", $SecurityGroupTags,
        "--query", "GroupId",
        "--output", "text"
    )

    $IngressRuleCount = Invoke-AwsText -Arguments @(
        "ec2",
        "describe-security-groups",
        "--profile", $ProfileName,
        "--region", $Region,
        "--group-ids", $SecurityGroupId,
        "--query", "length(SecurityGroups[0].IpPermissions)",
        "--output", "text"
    )

    if ($IngressRuleCount -ne "0") {
        throw (
            "The Security Group contains ingress rules. " +
            "No rules were removed automatically."
        )
    }

    Write-Ok "Security Group created without ingress rules."

    Write-Step "Deployment summary"

    Write-Ok "VPC available with CIDR $VpcCidr."

    Write-Ok (
        "$SubnetAName available in $AvailabilityZoneA " +
        "with CIDR $SubnetACidr."
    )

    Write-Ok (
        "$SubnetBName available in $AvailabilityZoneB " +
        "with CIDR $SubnetBCidr."
    )

    Write-Ok "Internet Gateway attached."
    Write-Ok "Public route and subnet associations configured."
    Write-Ok "Security Group contains no ingress rules."

    Write-Host ""
    Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green

    Write-Host (
        "No EC2 instance, NAT Gateway, Elastic IP, " +
        "or load balancer was created."
    )

    Write-Host (
        "Run test-aws-application-network.ps1 " +
        "before recording evidence."
    )

    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] Lab 08 deployment was not completed." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host (
        "No automatic cleanup was performed. " +
        "Review the created resources before retrying."
    )

    exit 1
}
