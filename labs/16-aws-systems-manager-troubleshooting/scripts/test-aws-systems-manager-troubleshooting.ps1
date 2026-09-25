[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [ValidateSet("Healthy", "Failed")]
    [string]$ExpectedConnectivityState = "Healthy"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$InstanceName = "lab16-systems-manager-troubleshooting-instance"
$GroupName = "lab16-systems-manager-troubleshooting-sg"
$RoleName = "lab16-ec2-systems-manager-troubleshooting-role"
$IamProfileName = "lab16-ec2-systems-manager-troubleshooting-instance-profile"
$PolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$ExpectedTags = @{
    Project = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab = "16"
    ManagedBy = "aws-cli"
    Owner = "itamarsb"
}

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& aws @Arguments --profile $ProfileName --region $Region --no-cli-pager 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $old
    }
    $output = (@($lines | ForEach-Object {
        if ($null -ne $_) { $_.ToString() }
    }) -join [Environment]::NewLine).Trim()
    if ($code -ne 0) {
        throw "AWS CLI falhou: aws $($Arguments -join ' ') $output"
    }
    return $output
}

function Get-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $value = Invoke-Aws -Arguments ($Arguments + @("--output", "json"))
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Resposta JSON vazia."
    }
    return ($value | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param($Resource, [string]$Description, [string]$Lab = "16")
    $tags = @{}
    foreach ($tag in @($Resource.Tags)) {
        $tags[[string]$tag.Key] = [string]$tag.Value
    }
    foreach ($key in $ExpectedTags.Keys) {
        $expected = if ($key -eq "Lab") { $Lab } else { $ExpectedTags[$key] }
        if ($tags[$key] -ne $expected) {
            throw "$Description possui tag $key ausente ou incompatível."
        }
    }
}

try {
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }
    if ($Region -ne "us-east-1") {
        throw "Este laboratório utiliza us-east-1."
    }
    Write-Host "=== Lab 16: validação somente leitura ===" -ForegroundColor Cyan
    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    if ([string]::IsNullOrWhiteSpace($identity.Account)) {
        throw "Conta AWS não identificada."
    }
    Write-Host "[OK] Conta: $($identity.Account)"

    $vpcs = @((Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs", "--filters",
        "Name=tag:Name,Values=lab08-application-vpc",
        "Name=state,Values=available"
    )).Vpcs)
    if ($vpcs.Count -ne 1) { throw "VPC do Lab 08 ausente ou ambígua." }
    $vpc = $vpcs[0]
    Assert-Tags -Resource $vpc -Description "VPC" -Lab "08"

    $subnets = @((Get-AwsJson -Arguments @(
        "ec2", "describe-subnets", "--filters",
        "Name=tag:Name,Values=lab08-public-subnet-a",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )).Subnets)
    if ($subnets.Count -ne 1) { throw "Sub-rede do Lab 08 ausente ou ambígua." }
    $subnet = $subnets[0]
    Assert-Tags -Resource $subnet -Description "Sub-rede" -Lab "08"
    if ($subnet.AvailabilityZone -ne "us-east-1a" -or
        -not $subnet.MapPublicIpOnLaunch) {
        throw "Sub-rede pública ou zona incompatível."
    }

    $tables = @((Get-AwsJson -Arguments @(
        "ec2", "describe-route-tables", "--filters",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )).RouteTables)
    $explicit = @($tables | Where-Object {
        @($_.Associations | Where-Object {
            $_.PSObject.Properties["SubnetId"] -and
            $_.SubnetId -eq $subnet.SubnetId
        }).Count -gt 0
    })
    if ($explicit.Count -gt 1) { throw "Tabela de rotas ambígua." }
    if ($explicit.Count -eq 1) {
        $table = $explicit[0]
    }
    else {
        $main = @($tables | Where-Object {
            @($_.Associations | Where-Object {
                $_.PSObject.Properties["Main"] -and $_.Main
            }).Count -gt 0
        })
        if ($main.Count -ne 1) { throw "Tabela principal não identificada." }
        $table = $main[0]
    }
    $public = @($table.Routes | Where-Object {
        $_.DestinationCidrBlock -eq "0.0.0.0/0" -and
        $_.State -eq "active" -and $_.GatewayId -match "^igw-"
    })
    if ($public.Count -ne 1) { throw "Rota pública não confirmada." }
    $igws = @((Get-AwsJson -Arguments @(
        "ec2", "describe-internet-gateways",
        "--internet-gateway-ids", $public[0].GatewayId
    )).InternetGateways)
    if ($igws.Count -ne 1 -or
        @($igws[0].Attachments | Where-Object {
            $_.VpcId -eq $vpc.VpcId -and $_.State -eq "available"
        }).Count -ne 1) {
        throw "Internet Gateway não confirmado."
    }
    Write-Host "[OK] Rede compartilhada: $($vpc.VpcId) / $($subnet.SubnetId)"

    $reservations = @((Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )).Reservations)
    $instances = @($reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) { throw "Instância ativa ausente ou ambígua." }
    $instance = $instances[0]
    Assert-Tags -Resource $instance -Description "Instância"
    if ($instance.State.Name -ne "running" -or
        $instance.VpcId -ne $vpc.VpcId -or
        $instance.SubnetId -ne $subnet.SubnetId -or
        $instance.Placement.AvailabilityZone -ne "us-east-1a" -or
        $instance.InstanceType -ne "t3.micro" -or
        $instance.MetadataOptions.HttpTokens -ne "required" -or
        -not $instance.PSObject.Properties["PublicIpAddress"] -or
        [string]::IsNullOrWhiteSpace($instance.PublicIpAddress) -or
        ($instance.PSObject.Properties["KeyName"] -and
            -not [string]::IsNullOrWhiteSpace($instance.KeyName))) {
        throw "Configuração EC2 incompatível."
    }
    if (@($instance.SecurityGroups).Count -ne 1) {
        throw "A instância deve usar somente um Security Group."
    }
    if (-not $instance.PSObject.Properties["IamInstanceProfile"] -or
        $instance.IamInstanceProfile.Arn -notmatch
            ("/instance-profile/" + [regex]::Escape($IamProfileName) + "$")) {
        throw "Instance Profile incorreto."
    }
    Write-Host "[OK] Instância: $($instance.InstanceId)"

    $groups = @((Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups", "--group-ids",
        $instance.SecurityGroups[0].GroupId
    )).SecurityGroups)
    if ($groups.Count -ne 1 -or
        $groups[0].GroupName -ne $GroupName -or
        $groups[0].VpcId -ne $vpc.VpcId) {
        throw "Security Group inesperado."
    }
    $group = $groups[0]
    Assert-Tags -Resource $group -Description "Security Group"
    $interfaces = @((Get-AwsJson -Arguments @(
        "ec2", "describe-network-interfaces", "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )).NetworkInterfaces)
    if ($interfaces.Count -ne 1 -or
        -not $interfaces[0].PSObject.Properties["Attachment"] -or
        $interfaces[0].Attachment.InstanceId -ne $instance.InstanceId) {
        throw "Security Group associado a outra interface ou instância."
    }
    $rules = @((Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules", "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )).SecurityGroupRules)
    $ingress = @($rules | Where-Object { -not $_.IsEgress })
    $egress = @($rules | Where-Object { $_.IsEgress })
    if ($ingress.Count -ne 0 -or $egress.Count -gt 1) {
        throw "Regras extras no Security Group."
    }
    if ($egress.Count -eq 1 -and
        ($egress[0].IpProtocol -ne "tcp" -or
         $egress[0].FromPort -ne 443 -or
         $egress[0].ToPort -ne 443 -or
         $egress[0].CidrIpv4 -ne "0.0.0.0/0")) {
        throw "Regra de saída incompatível."
    }
    Write-Host "[OK] Security Group: $($group.GroupId)"

    $profile = Get-AwsJson -Arguments @(
        "iam", "get-instance-profile",
        "--instance-profile-name", $IamProfileName
    )
    Assert-Tags -Resource $profile.InstanceProfile -Description "Instance Profile"
    $roles = @($profile.InstanceProfile.Roles)
    if ($roles.Count -ne 1 -or $roles[0].RoleName -ne $RoleName) {
        throw "Role do Instance Profile incorreta."
    }
    $role = Get-AwsJson -Arguments @(
        "iam", "get-role", "--role-name", $RoleName
    )
    Assert-Tags -Resource $role.Role -Description "IAM Role"
    $policies = @((Get-AwsJson -Arguments @(
        "iam", "list-attached-role-policies", "--role-name", $RoleName
    )).AttachedPolicies)
    if (@($policies | Where-Object { $_.PolicyArn -eq $PolicyArn }).Count -ne 1) {
        throw "Política SSM ausente."
    }
    Write-Host "[OK] Role e política SSM."

    $managed = @((Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$($instance.InstanceId)"
    )).InstanceInformationList)
    if ($managed.Count -gt 1) { throw "Registro SSM ambíguo." }
    $online = $managed.Count -eq 1 -and $managed[0].PingStatus -eq "Online"

    if ($ExpectedConnectivityState -eq "Healthy") {
        if ($egress.Count -ne 1 -or -not $online) {
            throw "Estado Healthy não confirmado."
        }
        Write-Host "[OK] Saída HTTPS: $($egress[0].SecurityGroupRuleId)"
        Write-Host "[OK] Systems Manager: Online"
    }
    else {
        if ($egress.Count -ne 0 -or $managed.Count -ne 1 -or
            $managed[0].PingStatus -ne "ConnectionLost") {
            throw "Estado Failed não confirmado: exige regra ausente e ConnectionLost."
        }
        Write-Host "[OK] Saída HTTPS ausente."
        Write-Host "[OK] Systems Manager: ConnectionLost"
    }
    Write-Host "VALIDAÇÃO CONCLUÍDA: $ExpectedConnectivityState" -ForegroundColor Green
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
