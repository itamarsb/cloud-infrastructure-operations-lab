[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProfileName = "cloud-operations-lab",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Region = "us-east-1",

    [Parameter()]
    [switch]$ConfirmRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$VpcCidr = "10.20.0.0/16"
$SubnetAName = "lab08-public-subnet-a"
$SubnetBName = "lab08-public-subnet-b"
$InternetGatewayName = "lab08-internet-gateway"
$RouteTableName = "lab08-public-route-table"
$SecurityGroupName = "lab08-application-sg"

function Write-Pass {
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

function Invoke-AwsCommand {
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
}

function Get-TagValue {
    param(
        [Parameter(Mandatory = $true)]
        $Tags,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $Matches = @(
        $Tags | Where-Object {
            $_.Key -eq $Key
        }
    )

    if ($Matches.Count -eq 1) {
        return $Matches[0].Value
    }

    return $null
}

function Assert-LabOwnership {
    param(
        [Parameter(Mandatory = $true)]
        $Tags,

        [Parameter(Mandatory = $true)]
        [string]$ResourceLabel
    )

    $ProjectTag = Get-TagValue `
        -Tags $Tags `
        -Key "Project"

    $EnvironmentTag = Get-TagValue `
        -Tags $Tags `
        -Key "Environment"

    $LabTag = Get-TagValue `
        -Tags $Tags `
        -Key "Lab"

    $ManagedByTag = Get-TagValue `
        -Tags $Tags `
        -Key "ManagedBy"

    if (
        $ProjectTag -ne "cloud-infrastructure-operations-lab" -or
        $EnvironmentTag -ne "lab" -or
        $LabTag -ne "08" -or
        $ManagedByTag -ne "aws-cli"
    ) {
        throw "$ResourceLabel does not contain the ownership tags required for safe removal."
    }

    Write-Pass "$ResourceLabel ownership tags validated."
}

try {
    Write-Host ""
    Write-Host "Lab 08 - AWS application network cleanup"
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
    Write-Host "=== Target VPC validation ===" -ForegroundColor Cyan

    $VpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName"
    )

    $Vpcs = @($VpcResult.Vpcs)

    if ($Vpcs.Count -eq 0) {
        Write-Pass "The Lab 08 VPC is already absent."
        Write-Host ""
        Write-Host "CLEANUP ALREADY COMPLETED" -ForegroundColor Green
        Write-Host "No AWS resource was created, altered, or removed."
        exit 0
    }

    if ($Vpcs.Count -ne 1) {
        throw "Expected exactly one VPC named $VpcName; found $($Vpcs.Count)."
    }

    $Vpc = $Vpcs[0]
    $VpcId = $Vpc.VpcId

    if ($Vpc.CidrBlock -ne $VpcCidr) {
        throw "The target VPC CIDR does not match the expected Lab 08 CIDR."
    }

    Write-Pass "Target VPC located with the expected CIDR $VpcCidr."

    Assert-LabOwnership `
        -Tags $Vpc.Tags `
        -ResourceLabel "VPC"

    Write-Host ""
    Write-Host "=== Dependency inspection ===" -ForegroundColor Cyan

    $NetworkInterfaceResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-network-interfaces",
        "--filters",
        "Name=vpc-id,Values=$VpcId"
    )

    $NetworkInterfaces = @($NetworkInterfaceResult.NetworkInterfaces)

    if ($NetworkInterfaces.Count -ne 0) {
        throw "The VPC contains network interfaces. Cleanup was stopped before any resource was removed."
    }

    Write-Pass "No network interfaces were found in the VPC."

    $NatGatewayResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-nat-gateways",
        "--filter",
        "Name=vpc-id,Values=$VpcId"
    )

    $ActiveNatGateways = @(
        $NatGatewayResult.NatGateways | Where-Object {
            $_.State -ne "deleted"
        }
    )

    if ($ActiveNatGateways.Count -ne 0) {
        throw "The VPC contains a NAT Gateway. Cleanup was stopped before any resource was removed."
    }

    Write-Pass "No NAT Gateway was found in the VPC."

    $VpcEndpointResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpc-endpoints",
        "--filters",
        "Name=vpc-id,Values=$VpcId"
    )

    $VpcEndpoints = @($VpcEndpointResult.VpcEndpoints)

    if ($VpcEndpoints.Count -ne 0) {
        throw "The VPC contains VPC endpoints. Cleanup was stopped before any resource was removed."
    }

    Write-Pass "No VPC endpoint was found in the VPC."

    Write-Host ""
    Write-Host "=== Lab resource discovery ===" -ForegroundColor Cyan

    $SecurityGroupResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-security-groups",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=group-name,Values=$SecurityGroupName"
    )

    $SecurityGroups = @($SecurityGroupResult.SecurityGroups)

    if ($SecurityGroups.Count -gt 1) {
        throw "More than one target Security Group was found."
    }

    if ($SecurityGroups.Count -eq 1) {
        Assert-LabOwnership `
            -Tags $SecurityGroups[0].Tags `
            -ResourceLabel "Security Group"
    }
    else {
        Write-InfoMessage "Target Security Group is already absent."
    }

    $RouteTableResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-route-tables",
        "--filters",
        "Name=vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$RouteTableName"
    )

    $RouteTables = @($RouteTableResult.RouteTables)

    if ($RouteTables.Count -gt 1) {
        throw "More than one target public route table was found."
    }

    if ($RouteTables.Count -eq 1) {
        Assert-LabOwnership `
            -Tags $RouteTables[0].Tags `
            -ResourceLabel "Public route table"
    }
    else {
        Write-InfoMessage "Target public route table is already absent."
    }

    $SubnetResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$VpcId"
    )

    $AllVpcSubnets = @($SubnetResult.Subnets)

    $TargetSubnets = @(
        $AllVpcSubnets | Where-Object {
            $SubnetName = Get-TagValue `
                -Tags $_.Tags `
                -Key "Name"

            $SubnetName -eq $SubnetAName -or
            $SubnetName -eq $SubnetBName
        }
    )

    if ($TargetSubnets.Count -gt 2) {
        throw "More target subnets were found than expected."
    }

    foreach ($Subnet in $TargetSubnets) {
        $SubnetName = Get-TagValue `
            -Tags $Subnet.Tags `
            -Key "Name"

        Assert-LabOwnership `
            -Tags $Subnet.Tags `
            -ResourceLabel $SubnetName
    }

    if ($TargetSubnets.Count -eq 0) {
        Write-InfoMessage "Target subnets are already absent."
    }

    $UnexpectedSubnets = @(
        $AllVpcSubnets | Where-Object {
            $SubnetName = Get-TagValue `
                -Tags $_.Tags `
                -Key "Name"

            $SubnetName -ne $SubnetAName -and
            $SubnetName -ne $SubnetBName
        }
    )

    if ($UnexpectedSubnets.Count -ne 0) {
        throw "The VPC contains subnets that do not belong to the expected Lab 08 scope."
    }

    $InternetGatewayResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-internet-gateways",
        "--filters",
        "Name=attachment.vpc-id,Values=$VpcId",
        "Name=tag:Name,Values=$InternetGatewayName"
    )

    $InternetGateways = @(
        $InternetGatewayResult.InternetGateways
    )

    if ($InternetGateways.Count -gt 1) {
        throw "More than one target Internet Gateway was found."
    }

    if ($InternetGateways.Count -eq 1) {
        Assert-LabOwnership `
            -Tags $InternetGateways[0].Tags `
            -ResourceLabel "Internet Gateway"
    }
    else {
        Write-InfoMessage "Target Internet Gateway is already absent."
    }

    Write-Host ""
    Write-Host "=== Removal authorization ===" -ForegroundColor Cyan

    if (-not $ConfirmRemoval) {
        Write-Host "[STOP] Cleanup was not authorized." -ForegroundColor Yellow
        Write-Host "Run this script again with -ConfirmRemoval after reviewing the target resources."
        Write-Host "No AWS resource was created, altered, or removed."
        exit 2
    }

    Write-Pass "Explicit removal authorization received."

    Write-Host ""
    Write-Host "=== Security Group removal ===" -ForegroundColor Cyan

    if ($SecurityGroups.Count -eq 1) {
        Invoke-AwsCommand -Arguments @(
            "ec2",
            "delete-security-group",
            "--group-id",
            $SecurityGroups[0].GroupId
        )

        Write-Pass "Security Group removed."
    }
    else {
        Write-InfoMessage "Security Group removal was not required."
    }

    Write-Host ""
    Write-Host "=== Public route table removal ===" -ForegroundColor Cyan

    if ($RouteTables.Count -eq 1) {
        $RouteTable = $RouteTables[0]

        $ExplicitAssociations = @(
            $RouteTable.Associations | Where-Object {
                -not $_.Main -and
                -not [string]::IsNullOrWhiteSpace(
                    $_.RouteTableAssociationId
                )
            }
        )

        foreach ($Association in $ExplicitAssociations) {
            Invoke-AwsCommand -Arguments @(
                "ec2",
                "disassociate-route-table",
                "--association-id",
                $Association.RouteTableAssociationId
            )
        }

        if ($ExplicitAssociations.Count -gt 0) {
            Write-Pass "Public route table associations removed."
        }
        else {
            Write-InfoMessage "No explicit route table association required removal."
        }

        Invoke-AwsCommand -Arguments @(
            "ec2",
            "delete-route-table",
            "--route-table-id",
            $RouteTable.RouteTableId
        )

        Write-Pass "Public route table removed."
    }
    else {
        Write-InfoMessage "Public route table removal was not required."
    }

    Write-Host ""
    Write-Host "=== Public subnet removal ===" -ForegroundColor Cyan

    foreach ($Subnet in $TargetSubnets) {
        $SubnetName = Get-TagValue `
            -Tags $Subnet.Tags `
            -Key "Name"

        Invoke-AwsCommand -Arguments @(
            "ec2",
            "delete-subnet",
            "--subnet-id",
            $Subnet.SubnetId
        )

        Write-Pass "$SubnetName removed."
    }

    if ($TargetSubnets.Count -eq 0) {
        Write-InfoMessage "Subnet removal was not required."
    }

    Write-Host ""
    Write-Host "=== Internet Gateway removal ===" -ForegroundColor Cyan

    if ($InternetGateways.Count -eq 1) {
        $InternetGateway = $InternetGateways[0]

        $MatchingAttachments = @(
            $InternetGateway.Attachments | Where-Object {
                $_.VpcId -eq $VpcId
            }
        )

        if ($MatchingAttachments.Count -eq 1) {
            Invoke-AwsCommand -Arguments @(
                "ec2",
                "detach-internet-gateway",
                "--internet-gateway-id",
                $InternetGateway.InternetGatewayId,
                "--vpc-id",
                $VpcId
            )

            Write-Pass "Internet Gateway detached from the VPC."
        }

        Invoke-AwsCommand -Arguments @(
            "ec2",
            "delete-internet-gateway",
            "--internet-gateway-id",
            $InternetGateway.InternetGatewayId
        )

        Write-Pass "Internet Gateway removed."
    }
    else {
        Write-InfoMessage "Internet Gateway removal was not required."
    }

    Write-Host ""
    Write-Host "=== VPC removal ===" -ForegroundColor Cyan

    Invoke-AwsCommand -Arguments @(
        "ec2",
        "delete-vpc",
        "--vpc-id",
        $VpcId
    )

    Write-Pass "Lab 08 VPC removed."

    Write-Host ""
    Write-Host "=== Cleanup verification ===" -ForegroundColor Cyan

    $RemainingVpcResult = Invoke-AwsJson -Arguments @(
        "ec2",
        "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName"
    )

    $RemainingVpcs = @($RemainingVpcResult.Vpcs)

    if ($RemainingVpcs.Count -ne 0) {
        throw "The target VPC is still present after the cleanup operation."
    }

    Write-Pass "The target VPC is no longer present."

    Write-Host ""
    Write-Host "CLEANUP COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "All Lab 08 network resources were removed in dependency order."
    Write-Host "No unrelated AWS resource was targeted."
    exit 0
}
catch {
    Write-Host ""
    Write-Host "[FAIL] Cleanup could not be completed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Review the current AWS state before running the script again."
    exit 1
}
