[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [switch]$ConfirmRecovery
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstanceName = "lab16-systems-manager-troubleshooting-instance"
$GroupName = "lab16-systems-manager-troubleshooting-sg"
$RoleName = "lab16-ec2-systems-manager-troubleshooting-role"
$ProfileResourceName = "lab16-ec2-systems-manager-troubleshooting-instance-profile"
$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"
$SsmPolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$ExpectedTags = @{
    Project = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab = "16"
    ManagedBy = "aws-cli"
    Owner = "itamarsb"
}

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& aws @Arguments --profile $ProfileName --region $Region --no-cli-pager 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    $output = ($lines | ForEach-Object { if ($null -ne $_) { $_.ToString() } }) -join "`n"
    if ($exitCode -ne 0) {
        throw "Falha na AWS CLI: aws $($Arguments -join ' ')`n$output"
    }
    return $output.Trim()
}

function Get-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = Invoke-Aws -Arguments ($Arguments + @("--output", "json"))
    if ([string]::IsNullOrWhiteSpace($output)) {
        throw "A AWS CLI não retornou JSON."
    }
    return ($output | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param($Resource, [string]$Description, [string]$Name)
    $actual = @{}
    foreach ($tag in @($Resource.Tags)) {
        $actual[[string]$tag.Key] = [string]$tag.Value
    }
    foreach ($key in $ExpectedTags.Keys) {
        if ($actual[$key] -ne $ExpectedTags[$key]) {
            throw "$Description possui tag $key incompatível. Recuperação recusada."
        }
    }
    if ($actual.Name -ne $Name) {
        throw "$Description possui tag Name incompatível. Recuperação recusada."
    }
}

function Get-Rules {
    param([string]$GroupId)
    $response = Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules", "--filters",
        "Name=group-id,Values=$GroupId"
    )
    return @($response.SecurityGroupRules)
}

function Test-HttpsRule {
    param($Rule, [string]$GroupId)
    return (
        $Rule.GroupId -eq $GroupId -and
        $Rule.IsEgress -eq $true -and
        $Rule.IpProtocol -eq "tcp" -and
        $Rule.FromPort -eq 443 -and
        $Rule.ToPort -eq 443 -and
        $Rule.CidrIpv4 -eq "0.0.0.0/0" -and
        -not $Rule.PSObject.Properties["CidrIpv6"] -and
        -not $Rule.PSObject.Properties["PrefixListId"] -and
        -not $Rule.PSObject.Properties["ReferencedGroupInfo"]
    )
}

try {
    Write-Host "`n=== Lab 16: recuperação do Systems Manager ===" -ForegroundColor Cyan
    if (-not $ConfirmRecovery) { throw "Informe -ConfirmRecovery." }
    if ($Region -ne "us-east-1") { throw "Região inesperada." }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }

    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    if ([string]::IsNullOrWhiteSpace($identity.Account)) {
        throw "Identidade AWS não confirmada."
    }
    Write-Host "[OK] Conta AWS: $($identity.Account)"

    $vpcs = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs", "--filters",
        "Name=tag:Name,Values=$VpcName", "Name=state,Values=available"
    )).Vpcs )
    if ($vpcs.Count -ne 1) { throw "VPC compartilhada não identificada de forma única." }
    $vpcId = $vpcs[0].VpcId

    $subnets = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-subnets", "--filters",
        "Name=tag:Name,Values=$SubnetName", "Name=vpc-id,Values=$vpcId"
    )).Subnets )
    if ($subnets.Count -ne 1) { throw "Sub-rede compartilhada não identificada de forma única." }
    $subnetId = $subnets[0].SubnetId

    $reservations = (Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )).Reservations
    $instances = @($reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) { throw "Instância do Lab 16 ausente ou duplicada." }
    $instance = $instances[0]
    Assert-Tags -Resource $instance -Description "Instância" -Name $InstanceName
    if ($instance.State.Name -ne "running" -or $instance.SubnetId -ne $subnetId -or
        $instance.VpcId -ne $vpcId) {
        throw "Estado ou rede da instância incompatível."
    }
    if (-not $instance.PSObject.Properties["IamInstanceProfile"] -or
        $instance.IamInstanceProfile.Arn -notmatch
            "/$([regex]::Escape($ProfileResourceName))$") {
        throw "Instance Profile da instância incompatível."
    }

    $groups = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups", "--filters",
        "Name=group-name,Values=$GroupName", "Name=vpc-id,Values=$vpcId"
    )).SecurityGroups )
    if ($groups.Count -ne 1) { throw "Security Group exclusivo ausente ou duplicado." }
    $group = $groups[0]
    Assert-Tags -Resource $group -Description "Security Group" -Name $GroupName
    $groupIds = @($instance.SecurityGroups | ForEach-Object { $_.GroupId })
    if ($groupIds.Count -ne 1 -or $groupIds[0] -ne $group.GroupId) {
        throw "Security Groups da instância incompatíveis."
    }
    $interfaces = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-network-interfaces", "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )).NetworkInterfaces )
    if ($interfaces.Count -ne 1 -or
        -not $interfaces[0].PSObject.Properties["Attachment"] -or
        $interfaces[0].Attachment.InstanceId -ne $instance.InstanceId) {
        throw "Security Group associado a interfaces inesperadas."
    }

    $role = (Get-AwsJson -Arguments @(
        "iam", "get-role", "--role-name", $RoleName
    )).Role
    Assert-Tags -Resource $role -Description "IAM Role" -Name $RoleName
    $profile = (Get-AwsJson -Arguments @(
        "iam", "get-instance-profile", "--instance-profile-name", $ProfileResourceName
    )).InstanceProfile
    Assert-Tags -Resource $profile -Description "Instance Profile" -Name $ProfileResourceName
    if (@($profile.Roles).Count -ne 1 -or $profile.Roles[0].RoleName -ne $RoleName) {
        throw "Role do Instance Profile incompatível."
    }
    $policies = @( (Get-AwsJson -Arguments @(
        "iam", "list-attached-role-policies", "--role-name", $RoleName
    )).AttachedPolicies )
    if ($policies.Count -ne 1 -or $policies[0].PolicyArn -ne $SsmPolicyArn) {
        throw "Política gerenciada da IAM Role incompatível."
    }
    $inline = @( (Get-AwsJson -Arguments @(
        "iam", "list-role-policies", "--role-name", $RoleName
    )).PolicyNames )
    if ($inline.Count -ne 0) { throw "IAM Role possui políticas inline inesperadas." }
    Write-Host "[OK] Instância, rede, Security Group e IAM confirmados."

    $rules = @(Get-Rules -GroupId $group.GroupId)
    $ingress = @($rules | Where-Object { -not $_.IsEgress })
    $egress = @($rules | Where-Object { $_.IsEgress })
    if ($ingress.Count -ne 0 -or $egress.Count -gt 1) {
        throw "Regras adicionais no Security Group. Recuperação recusada."
    }
    if ($egress.Count -eq 1 -and
        -not (Test-HttpsRule -Rule $egress[0] -GroupId $group.GroupId)) {
        throw "Regra de saída inesperada. Recuperação recusada."
    }

    if ($egress.Count -eq 0) {
        Write-Host "`n=== Restauração da saída HTTPS ===" -ForegroundColor Cyan
        $response = Get-AwsJson -Arguments @(
            "ec2", "authorize-security-group-egress",
            "--group-id", $group.GroupId,
            "--ip-permissions",
            "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}]"
        )
        if ($response.Return -ne $true) { throw "AWS não confirmou a restauração." }
    }
    else {
        Write-Host "[OK] Regra HTTPS já presente; nenhuma duplicata criada."
    }

    $verified = $false
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        $rules = @(Get-Rules -GroupId $group.GroupId)
        if ($rules.Count -eq 1 -and
            (Test-HttpsRule -Rule $rules[0] -GroupId $group.GroupId)) {
            $verified = $true
            Write-Host "[OK] Regra HTTPS: $($rules[0].SecurityGroupRuleId)"
            break
        }
        Start-Sleep -Seconds 5
    }
    if (-not $verified) { throw "A regra restaurada não foi confirmada." }

    Write-Host "`n=== Retorno do Systems Manager ===" -ForegroundColor Cyan
    $online = $false
    for ($attempt = 1; $attempt -le 24; $attempt++) {
        $managed = @( (Get-AwsJson -Arguments @(
            "ssm", "describe-instance-information", "--filters",
            "Key=InstanceIds,Values=$($instance.InstanceId)"
        )).InstanceInformationList )
        if ($managed.Count -eq 1 -and $managed[0].PingStatus -eq "Online") {
            $online = $true
            break
        }
        Start-Sleep -Seconds 15
    }
    if (-not $online) {
        throw "Regra HTTPS restaurada, mas o Systems Manager não voltou a Online no prazo."
    }
    Write-Host "[OK] Systems Manager: Online."
    Write-Host "`nCONECTIVIDADE SSM RECUPERADA" -ForegroundColor Green
}
catch {
    Write-Host "`n[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Confira o estado da regra e da instância antes de repetir." -ForegroundColor Yellow
    exit 1
}
