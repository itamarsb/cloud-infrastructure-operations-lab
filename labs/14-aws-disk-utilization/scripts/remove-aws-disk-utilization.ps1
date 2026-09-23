[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [string]$Region = "us-east-1",

    [switch]$ConfirmRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectName = "cloud-infrastructure-operations-lab"
$EnvironmentName = "lab"
$LabNumber = "14"
$ManagedBy = "aws-cli"
$Owner = "itamarsb"

$InstanceName = "lab14-disk-utilization-instance"
$SecurityGroupName = "lab14-disk-utilization-sg"
$DataVolumeName = "lab14-disk-utilization-data"
$RoleName = "lab14-ec2-disk-utilization-role"
$InstanceProfileName = "lab14-ec2-disk-utilization-instance-profile"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"

$SsmPolicyArn = (
    "arn:aws:iam::aws:policy/" +
    "AmazonSSMManagedInstanceCore"
)

$ExpectedTags = @{
    Project = $ProjectName
    Environment = $EnvironmentName
    Lab = $LabNumber
    ManagedBy = $ManagedBy
    Owner = $Owner
}

function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Write-Ok {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$AllowNotFound
    )

    $CommandArguments = @(
        $Arguments
        "--profile"
        $ProfileName
        "--region"
        $Region
        "--no-cli-pager"
        "--output"
        "json"
    )

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $CommandOutput = @(
            & aws @CommandArguments 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($ExitCode -ne 0) {
        $ErrorText = (
            $CommandOutput |
                ForEach-Object {
                    $_.ToString()
                }
        ) -join [Environment]::NewLine

        if (
            $AllowNotFound.IsPresent -and
            (
                $ErrorText -match "NoSuchEntity" -or
                $ErrorText -match "InvalidInstanceID\.NotFound" -or
                $ErrorText -match "InvalidVolume\.NotFound" -or
                $ErrorText -match "InvalidGroup\.NotFound"
            )
        ) {
            return $null
        }

        throw (
            "Falha ao executar AWS CLI: aws " +
            ($Arguments -join " ") +
            [Environment]::NewLine +
            $ErrorText
        )
    }

    $JsonText = (
        $CommandOutput |
            ForEach-Object {
                $_.ToString()
            }
    ) -join [Environment]::NewLine

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return $null
    }

    return ($JsonText | ConvertFrom-Json)
}

function Invoke-AwsCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $CommandArguments = @(
        $Arguments
        "--profile"
        $ProfileName
        "--region"
        $Region
        "--no-cli-pager"
    )

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $CommandOutput = @(
            & aws @CommandArguments 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($ExitCode -ne 0) {
        $ErrorText = (
            $CommandOutput |
                ForEach-Object {
                    $_.ToString()
                }
        ) -join [Environment]::NewLine

        throw (
            "Falha ao executar AWS CLI: aws " +
            ($Arguments -join " ") +
            [Environment]::NewLine +
            $ErrorText
        )
    }

    return @($CommandOutput)
}

function Get-TagValue {
    param(
        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory)]
        [string]$Key
    )

    $Tag = @(
        $Tags |
            Where-Object {
                $_.Key -eq $Key
            }
    )

    if ($Tag.Count -eq 0) {
        return $null
    }

    if ($Tag.Count -gt 1) {
        throw "A tag '$Key' está duplicada."
    }

    return [string]$Tag[0].Value
}

function Assert-ExpectedTags {
    param(
        [Parameter(Mandatory)]
        [string]$ResourceDescription,

        [AllowNull()]
        [object[]]$Tags,

        [Parameter(Mandatory)]
        [hashtable]$RequiredTags
    )

    foreach ($TagName in $RequiredTags.Keys) {
        $ActualValue = Get-TagValue `
            -Tags $Tags `
            -Key $TagName

        $ExpectedValue = [string]$RequiredTags[$TagName]

        if ($ActualValue -ne $ExpectedValue) {
            throw (
                "{0} não possui a tag esperada {1}={2}. " +
                "Valor encontrado: {3}" -f
                $ResourceDescription,
                $TagName,
                $ExpectedValue,
                $(if ($null -eq $ActualValue) {
                    "<ausente>"
                }
                else {
                    $ActualValue
                })
            )
        }
    }

    Write-Ok "$ResourceDescription possui as tags esperadas."
}

function Get-LabInstance {
    $Response = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-instances"
        "--filters"
        "Name=tag:Name,Values=$InstanceName"
        "Name=tag:Project,Values=$ProjectName"
        "Name=tag:Environment,Values=$EnvironmentName"
        "Name=tag:Lab,Values=$LabNumber"
    )

    $Instances = @(
        $Response.Reservations |
            ForEach-Object {
                $_.Instances
            } |
            Where-Object {
                $_.State.Name -ne "terminated"
            }
    )

    if ($Instances.Count -gt 1) {
        throw (
            "Mais de uma instância EC2 ativa do Lab 14 foi encontrada."
        )
    }

    if ($Instances.Count -eq 0) {
        return $null
    }

    return $Instances[0]
}

function Get-LabDataVolume {
    $Response = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-volumes"
        "--filters"
        "Name=tag:Name,Values=$DataVolumeName"
        "Name=tag:Project,Values=$ProjectName"
        "Name=tag:Environment,Values=$EnvironmentName"
        "Name=tag:Lab,Values=$LabNumber"
    )

    $Volumes = @($Response.Volumes)

    if ($Volumes.Count -gt 1) {
        throw (
            "Mais de um volume EBS dedicado do Lab 14 foi encontrado."
        )
    }

    if ($Volumes.Count -eq 0) {
        return $null
    }

    return $Volumes[0]
}

function Get-LabSecurityGroup {
    $Response = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-security-groups"
        "--filters"
        "Name=group-name,Values=$SecurityGroupName"
        "Name=tag:Project,Values=$ProjectName"
        "Name=tag:Environment,Values=$EnvironmentName"
        "Name=tag:Lab,Values=$LabNumber"
    )

    $SecurityGroups = @($Response.SecurityGroups)

    if ($SecurityGroups.Count -gt 1) {
        throw (
            "Mais de um Security Group do Lab 14 foi encontrado."
        )
    }

    if ($SecurityGroups.Count -eq 0) {
        return $null
    }

    return $SecurityGroups[0]
}

function Get-LabRole {
    $Response = Invoke-AwsJson `
        -Arguments @(
            "iam"
            "get-role"
            "--role-name"
            $RoleName
        ) `
        -AllowNotFound

    if ($null -eq $Response) {
        return $null
    }

    return $Response.Role
}

function Get-LabInstanceProfile {
    $Response = Invoke-AwsJson `
        -Arguments @(
            "iam"
            "get-instance-profile"
            "--instance-profile-name"
            $InstanceProfileName
        ) `
        -AllowNotFound

    if ($null -eq $Response) {
        return $null
    }

    return $Response.InstanceProfile
}

function Remove-SecurityGroupWithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$GroupId,

        [ValidateRange(1, 30)]
        [int]$MaximumAttempts = 20
    )

    for (
        $Attempt = 1;
        $Attempt -le $MaximumAttempts;
        $Attempt++
    ) {
        $PreviousErrorActionPreference = $ErrorActionPreference

        try {
            $ErrorActionPreference = "Continue"

            $Output = @(
                aws ec2 delete-security-group `
                    --group-id $GroupId `
                    --profile $ProfileName `
                    --region $Region `
                    --no-cli-pager 2>&1
            )

            $ExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $PreviousErrorActionPreference
        }

        if ($ExitCode -eq 0) {
            return
        }

        $ErrorText = (
            $Output |
                ForEach-Object {
                    $_.ToString()
                }
        ) -join [Environment]::NewLine

        if (
            $ErrorText -match "InvalidGroup\.NotFound"
        ) {
            return
        }

        if (
            $ErrorText -notmatch "DependencyViolation" -or
            $Attempt -eq $MaximumAttempts
        ) {
            throw (
                "Falha ao excluir o Security Group '$GroupId'." +
                [Environment]::NewLine +
                $ErrorText
            )
        }

        Write-Info (
            "Security Group ainda possui dependências; " +
            "nova tentativa $Attempt/$MaximumAttempts."
        )

        Start-Sleep -Seconds 5
    }
}

if (-not $ConfirmRemoval.IsPresent) {
    throw (
        "Esta operação exclui os recursos AWS do Lab 14. " +
        "Execute novamente com -ConfirmRemoval."
    )
}

Write-Host ""
Write-Host "Lab 14 - Controlled AWS resource cleanup" `
    -ForegroundColor Cyan

Write-Step "Prerequisites and identity"

$Identity = Invoke-AwsJson -Arguments @(
    "sts"
    "get-caller-identity"
)

if (
    $null -eq $Identity -or
    [string]::IsNullOrWhiteSpace(
        [string]$Identity.Account
    )
) {
    throw "Não foi possível validar a identidade AWS."
}

Write-Ok (
    "AWS session is authenticated for account {0}." -f
    $Identity.Account
)

Write-Step "Shared Lab 08 network protection"

$VpcResponse = Invoke-AwsJson -Arguments @(
    "ec2"
    "describe-vpcs"
    "--filters"
    "Name=tag:Name,Values=$VpcName"
    "Name=tag:Project,Values=$ProjectName"
    "Name=tag:Environment,Values=$EnvironmentName"
    "Name=tag:Lab,Values=08"
    "Name=state,Values=available"
)

$Vpcs = @($VpcResponse.Vpcs)

if ($Vpcs.Count -ne 1) {
    throw (
        "Era esperada exatamente uma VPC compartilhada do Lab 08."
    )
}

$VpcId = [string]$Vpcs[0].VpcId

$SubnetResponse = Invoke-AwsJson -Arguments @(
    "ec2"
    "describe-subnets"
    "--filters"
    "Name=tag:Name,Values=$SubnetName"
    "Name=vpc-id,Values=$VpcId"
    "Name=state,Values=available"
)

$Subnets = @($SubnetResponse.Subnets)

if ($Subnets.Count -ne 1) {
    throw (
        "Era esperada exatamente uma subnet compartilhada do Lab 08."
    )
}

$SubnetId = [string]$Subnets[0].SubnetId

Write-Ok "Shared VPC protected: $VpcId."
Write-Ok "Shared subnet protected: $SubnetId."

Write-Step "Lab 14 resource discovery"

$Instance = Get-LabInstance
$DataVolume = Get-LabDataVolume
$SecurityGroup = Get-LabSecurityGroup
$Role = Get-LabRole
$InstanceProfile = Get-LabInstanceProfile

if ($null -ne $Instance) {
    $InstanceId = [string]$Instance.InstanceId

    Assert-ExpectedTags `
        -ResourceDescription "EC2 instance $InstanceId" `
        -Tags @($Instance.Tags) `
        -RequiredTags (
            $ExpectedTags + @{
                Name = $InstanceName
            }
        )

    if ([string]$Instance.SubnetId -ne $SubnetId) {
        throw (
            "A instância do Lab 14 não pertence à subnet " +
            "compartilhada esperada."
        )
    }

    Write-Info (
        "EC2 instance found: {0} ({1})." -f
        $InstanceId,
        $Instance.State.Name
    )
}
else {
    $InstanceId = $null
    Write-Info "Lab 14 EC2 instance is already absent."
}

if ($null -ne $DataVolume) {
    $DataVolumeId = [string]$DataVolume.VolumeId

    Assert-ExpectedTags `
        -ResourceDescription "EBS volume $DataVolumeId" `
        -Tags @($DataVolume.Tags) `
        -RequiredTags (
            $ExpectedTags + @{
                Name = $DataVolumeName
            }
        )

    $Attachments = @($DataVolume.Attachments)

    if (
        $Attachments.Count -gt 0 -and
        $null -eq $Instance
    ) {
        throw (
            "O volume EBS ainda está anexado, mas a instância " +
            "esperada não foi encontrada."
        )
    }

    foreach ($Attachment in $Attachments) {
        if (
            [string]$Attachment.InstanceId -ne
            [string]$InstanceId
        ) {
            throw (
                "O volume EBS está anexado a uma instância " +
                "não pertencente ao Lab 14."
            )
        }
    }

    Write-Info (
        "Dedicated EBS volume found: {0} ({1})." -f
        $DataVolumeId,
        $DataVolume.State
    )
}
else {
    $DataVolumeId = $null
    Write-Info "Lab 14 dedicated EBS volume is already absent."
}

if ($null -ne $SecurityGroup) {
    $SecurityGroupId = [string]$SecurityGroup.GroupId

    Assert-ExpectedTags `
        -ResourceDescription (
            "Security Group $SecurityGroupId"
        ) `
        -Tags @($SecurityGroup.Tags) `
        -RequiredTags (
            $ExpectedTags + @{
                Name = $SecurityGroupName
            }
        )

    if ([string]$SecurityGroup.VpcId -ne $VpcId) {
        throw (
            "O Security Group do Lab 14 não pertence à VPC " +
            "compartilhada esperada."
        )
    }

    Write-Info "Security Group found: $SecurityGroupId."
}
else {
    $SecurityGroupId = $null
    Write-Info "Lab 14 Security Group is already absent."
}

if ($null -ne $Role) {
    Assert-ExpectedTags `
        -ResourceDescription "IAM Role $RoleName" `
        -Tags @($Role.Tags) `
        -RequiredTags $ExpectedTags

    $AttachedPoliciesResponse = Invoke-AwsJson -Arguments @(
        "iam"
        "list-attached-role-policies"
        "--role-name"
        $RoleName
    )

    $AttachedPolicies = @(
        $AttachedPoliciesResponse.AttachedPolicies
    )

    $UnexpectedPolicies = @(
        $AttachedPolicies |
            Where-Object {
                [string]$_.PolicyArn -ne $SsmPolicyArn
            }
    )

    if ($UnexpectedPolicies.Count -gt 0) {
        throw (
            "A IAM Role possui políticas gerenciadas inesperadas. " +
            "O cleanup foi interrompido."
        )
    }

    $InlinePoliciesResponse = Invoke-AwsJson -Arguments @(
        "iam"
        "list-role-policies"
        "--role-name"
        $RoleName
    )

    $InlinePolicies = @(
        $InlinePoliciesResponse.PolicyNames
    )

    if ($InlinePolicies.Count -gt 0) {
        throw (
            "A IAM Role possui políticas inline inesperadas. " +
            "O cleanup foi interrompido."
        )
    }

    Write-Info "IAM Role found: $RoleName."
}
else {
    Write-Info "Lab 14 IAM Role is already absent."
}

if ($null -ne $InstanceProfile) {
    Assert-ExpectedTags `
        -ResourceDescription (
            "Instance Profile $InstanceProfileName"
        ) `
        -Tags @($InstanceProfile.Tags) `
        -RequiredTags $ExpectedTags

    $ProfileRoles = @($InstanceProfile.Roles)

    $UnexpectedRoles = @(
        $ProfileRoles |
            Where-Object {
                [string]$_.RoleName -ne $RoleName
            }
    )

    if ($UnexpectedRoles.Count -gt 0) {
        throw (
            "O Instance Profile contém uma IAM Role inesperada. " +
            "O cleanup foi interrompido."
        )
    }

    Write-Info (
        "Instance Profile found: $InstanceProfileName."
    )
}
else {
    Write-Info (
        "Lab 14 Instance Profile is already absent."
    )
}

if (
    $null -eq $Instance -and
    $null -eq $DataVolume -and
    $null -eq $SecurityGroup -and
    $null -eq $Role -and
    $null -eq $InstanceProfile
) {
    Write-Ok "All Lab 14 AWS resources are already absent."
}
else {
    Write-Step "EC2 instance termination"

    if ($null -ne $Instance) {
        Write-Info "Terminating EC2 instance $InstanceId."

        $null = Invoke-AwsCommand -Arguments @(
            "ec2"
            "terminate-instances"
            "--instance-ids"
            $InstanceId
        )

        $null = Invoke-AwsCommand -Arguments @(
            "ec2"
            "wait"
            "instance-terminated"
            "--instance-ids"
            $InstanceId
        )

        Write-Ok "EC2 instance terminated: $InstanceId."
    }
    else {
        Write-Ok "EC2 instance was already absent."
    }

    Write-Step "Dedicated EBS volume removal"

    if ($null -ne $DataVolume) {
        $null = Invoke-AwsCommand -Arguments @(
            "ec2"
            "wait"
            "volume-available"
            "--volume-ids"
            $DataVolumeId
        )

        $null = Invoke-AwsCommand -Arguments @(
            "ec2"
            "delete-volume"
            "--volume-id"
            $DataVolumeId
        )

        Write-Ok (
            "Dedicated EBS volume deleted: $DataVolumeId."
        )
    }
    else {
        Write-Ok "Dedicated EBS volume was already absent."
    }

    Write-Step "Security Group removal"

    if ($null -ne $SecurityGroup) {
        Remove-SecurityGroupWithRetry `
            -GroupId $SecurityGroupId

        Write-Ok (
            "Security Group deleted: $SecurityGroupId."
        )
    }
    else {
        Write-Ok "Security Group was already absent."
    }

    Write-Step "IAM Instance Profile removal"

    if ($null -ne $InstanceProfile) {
        $ProfileRoles = @($InstanceProfile.Roles)

        if (
            $ProfileRoles.Count -eq 1 -and
            [string]$ProfileRoles[0].RoleName -eq $RoleName
        ) {
            $null = Invoke-AwsCommand -Arguments @(
                "iam"
                "remove-role-from-instance-profile"
                "--instance-profile-name"
                $InstanceProfileName
                "--role-name"
                $RoleName
            )

            Write-Ok (
                "IAM Role removed from the Instance Profile."
            )
        }

        $null = Invoke-AwsCommand -Arguments @(
            "iam"
            "delete-instance-profile"
            "--instance-profile-name"
            $InstanceProfileName
        )

        Write-Ok (
            "Instance Profile deleted: $InstanceProfileName."
        )
    }
    else {
        Write-Ok "Instance Profile was already absent."
    }

    Write-Step "IAM Role removal"

    if ($null -ne $Role) {
        $AttachedPoliciesResponse = Invoke-AwsJson -Arguments @(
            "iam"
            "list-attached-role-policies"
            "--role-name"
            $RoleName
        )

        $AttachedPolicies = @(
            $AttachedPoliciesResponse.AttachedPolicies
        )

        if (
            @(
                $AttachedPolicies |
                    Where-Object {
                        [string]$_.PolicyArn -eq $SsmPolicyArn
                    }
            ).Count -eq 1
        ) {
            $null = Invoke-AwsCommand -Arguments @(
                "iam"
                "detach-role-policy"
                "--role-name"
                $RoleName
                "--policy-arn"
                $SsmPolicyArn
            )

            Write-Ok (
                "AmazonSSMManagedInstanceCore detached."
            )
        }

        $null = Invoke-AwsCommand -Arguments @(
            "iam"
            "delete-role"
            "--role-name"
            $RoleName
        )

        Write-Ok "IAM Role deleted: $RoleName."
    }
    else {
        Write-Ok "IAM Role was already absent."
    }
}

Write-Step "Post-cleanup validation"

$RemainingInstance = Get-LabInstance
$RemainingVolume = Get-LabDataVolume
$RemainingSecurityGroup = Get-LabSecurityGroup
$RemainingRole = Get-LabRole
$RemainingInstanceProfile = Get-LabInstanceProfile

$RemainingResources = @()

if ($null -ne $RemainingInstance) {
    $RemainingResources += (
        "EC2 instance: " +
        [string]$RemainingInstance.InstanceId
    )
}

if ($null -ne $RemainingVolume) {
    $RemainingResources += (
        "EBS volume: " +
        [string]$RemainingVolume.VolumeId
    )
}

if ($null -ne $RemainingSecurityGroup) {
    $RemainingResources += (
        "Security Group: " +
        [string]$RemainingSecurityGroup.GroupId
    )
}

if ($null -ne $RemainingRole) {
    $RemainingResources += "IAM Role: $RoleName"
}

if ($null -ne $RemainingInstanceProfile) {
    $RemainingResources += (
        "Instance Profile: $InstanceProfileName"
    )
}

if ($RemainingResources.Count -gt 0) {
    throw (
        "Os seguintes recursos do Lab 14 ainda existem:" +
        [Environment]::NewLine +
        ($RemainingResources -join [Environment]::NewLine)
    )
}

Write-Ok "No active Lab 14 EC2 instance remains."
Write-Ok "No Lab 14 dedicated EBS volume remains."
Write-Ok "No Lab 14 Security Group remains."
Write-Ok "No Lab 14 IAM Role remains."
Write-Ok "No Lab 14 Instance Profile remains."

Write-Step "Shared Lab 08 network verification"

$ProtectedVpcResponse = Invoke-AwsJson -Arguments @(
    "ec2"
    "describe-vpcs"
    "--vpc-ids"
    $VpcId
)

$ProtectedSubnetResponse = Invoke-AwsJson -Arguments @(
    "ec2"
    "describe-subnets"
    "--subnet-ids"
    $SubnetId
)

if (@($ProtectedVpcResponse.Vpcs).Count -ne 1) {
    throw "A VPC compartilhada do Lab 08 não foi preservada."
}

if (@($ProtectedSubnetResponse.Subnets).Count -ne 1) {
    throw "A subnet compartilhada do Lab 08 não foi preservada."
}

Write-Ok "Shared Lab 08 VPC remains available: $VpcId."
Write-Ok "Shared Lab 08 subnet remains available: $SubnetId."

Write-Host ""
Write-Host "LAB 14 CLEANUP COMPLETED SUCCESSFULLY" `
    -ForegroundColor Green
Write-Host "All Lab 14 AWS resources were removed."
Write-Host "The shared Lab 08 network was preserved."
Write-Host "The cleanup is safe to run again."
