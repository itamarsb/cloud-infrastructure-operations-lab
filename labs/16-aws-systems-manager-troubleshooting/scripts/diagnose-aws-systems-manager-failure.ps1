[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"
$InstanceName = "lab16-systems-manager-troubleshooting-instance"
$GroupName = "lab16-systems-manager-troubleshooting-sg"
$RoleName = "lab16-ec2-systems-manager-troubleshooting-role"
$ProfileResourceName = "lab16-ec2-systems-manager-troubleshooting-instance-profile"
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
    if ([string]::IsNullOrWhiteSpace($output)) { throw "AWS CLI não retornou JSON." }
    return ($output | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param($Resource, [string]$Description, [string]$Name)
    $actual = @{}
    foreach ($tag in @($Resource.Tags)) { $actual[[string]$tag.Key] = [string]$tag.Value }
    foreach ($key in $ExpectedTags.Keys) {
        if ($actual[$key] -ne $ExpectedTags[$key]) {
            throw "$Description possui tag $key incompatível."
        }
    }
    if ($actual.Name -ne $Name) { throw "$Description possui tag Name incompatível." }
}

try {
    Write-Host "`n=== Lab 16: diagnóstico somente leitura ===" -ForegroundColor Cyan
    if ($Region -ne "us-east-1") { throw "Região inesperada." }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { throw "AWS CLI não encontrada." }

    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    Write-Host "Conta: $($identity.Account)"
    Write-Host "ARN: $($identity.Arn)"
    Write-Host "Região: $Region"

    $vpcs = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs", "--filters",
        "Name=tag:Name,Values=$VpcName", "Name=state,Values=available"
    )).Vpcs )
    if ($vpcs.Count -ne 1) { throw "VPC compartilhada ausente ou duplicada." }
    $vpc = $vpcs[0]

    $subnets = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-subnets", "--filters",
        "Name=tag:Name,Values=$SubnetName", "Name=vpc-id,Values=$($vpc.VpcId)"
    )).Subnets )
    if ($subnets.Count -ne 1) { throw "Sub-rede compartilhada ausente ou duplicada." }
    $subnet = $subnets[0]
    Write-Host "`n=== Rede compartilhada ===" -ForegroundColor Cyan
    Write-Host "VPC: $($vpc.VpcId)"
    Write-Host "Sub-rede: $($subnet.SubnetId)"
    Write-Host "IPv4 público automático: $($subnet.MapPublicIpOnLaunch)"

    $routes = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-route-tables", "--filters",
        "Name=association.subnet-id,Values=$($subnet.SubnetId)"
    )).RouteTables )
    if ($routes.Count -ne 1) { throw "Tabela de rotas explícita ausente ou duplicada." }
    $publicRoutes = @($routes[0].Routes | Where-Object {
        $_.PSObject.Properties["DestinationCidrBlock"] -and
        $_.DestinationCidrBlock -eq "0.0.0.0/0" -and
        $_.State -eq "active" -and
        $_.PSObject.Properties["GatewayId"] -and
        $_.GatewayId -like "igw-*"
    })
    Write-Host "Tabela de rotas: $($routes[0].RouteTableId)"
    Write-Host "Rota pública ativa: $($publicRoutes.Count -eq 1)"
    if ($publicRoutes.Count -eq 1) {
        $igws = @( (Get-AwsJson -Arguments @(
            "ec2", "describe-internet-gateways", "--internet-gateway-ids",
            $publicRoutes[0].GatewayId
        )).InternetGateways )
        $attached = @($igws | Where-Object {
            @($_.Attachments | Where-Object { $_.VpcId -eq $vpc.VpcId }).Count -gt 0
        })
        Write-Host "Internet Gateway associado: $($attached.Count -eq 1)"
    }

    $acls = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-network-acls", "--filters",
        "Name=association.subnet-id,Values=$($subnet.SubnetId)"
    )).NetworkAcls )
    if ($acls.Count -ne 1) { throw "Network ACL da sub-rede ausente ou duplicada." }
    Write-Host "Network ACL: $($acls[0].NetworkAclId)"
    foreach ($entry in @($acls[0].Entries | Sort-Object RuleNumber, Egress)) {
        $direction = if ($entry.Egress) { "saída" } else { "entrada" }
        $cidr = if ($entry.PSObject.Properties["CidrBlock"]) { $entry.CidrBlock } else { "IPv6" }
        $ports = if ($entry.PSObject.Properties["PortRange"] -and
            $null -ne $entry.PortRange) {
            "$($entry.PortRange.From)-$($entry.PortRange.To)"
        } else { "todas" }

        $values = @(
            $direction
            $entry.RuleNumber
            $entry.RuleAction
            $entry.Protocol
            $ports
            $cidr
        )
        $line = [string]::Format(
            "{0}: regra={1} ação={2} protocolo={3} portas={4} CIDR={5}",
            $values
        )
        Write-Host $line
    }

    $reservations = (Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )).Reservations
    $instances = @($reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) { throw "Instância do Lab 16 ausente ou duplicada." }
    $instance = $instances[0]
    Assert-Tags -Resource $instance -Description "Instância" -Name $InstanceName
    if ($instance.SubnetId -ne $subnet.SubnetId -or $instance.VpcId -ne $vpc.VpcId) {
        throw "Instância em rede inesperada."
    }
    Write-Host "`n=== Instância EC2 ===" -ForegroundColor Cyan
    Write-Host "ID: $($instance.InstanceId)"
    Write-Host "Estado: $($instance.State.Name)"
    Write-Host "IPv4 privado: $($instance.PrivateIpAddress)"
    $publicIp = if ($instance.PSObject.Properties["PublicIpAddress"]) {
        $instance.PublicIpAddress
    } else { "ausente" }
    Write-Host "IPv4 público: $publicIp"
    Write-Host "IMDSv2: $($instance.MetadataOptions.HttpTokens)"
    $profileArn = if ($instance.PSObject.Properties["IamInstanceProfile"]) {
        $instance.IamInstanceProfile.Arn
    } else { "ausente" }
    Write-Host "Instance Profile: $profileArn"

    $groups = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups", "--filters",
        "Name=group-name,Values=$GroupName", "Name=vpc-id,Values=$($vpc.VpcId)"
    )).SecurityGroups )
    if ($groups.Count -ne 1) { throw "Security Group do Lab 16 ausente ou duplicado." }
    $group = $groups[0]
    Assert-Tags -Resource $group -Description "Security Group" -Name $GroupName
    $instanceGroups = @($instance.SecurityGroups | ForEach-Object { $_.GroupId })
    $interfaces = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-network-interfaces", "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )).NetworkInterfaces )
    $exclusive = (
        $instanceGroups.Count -eq 1 -and
        $instanceGroups[0] -eq $group.GroupId -and
        $interfaces.Count -eq 1 -and
        $interfaces[0].PSObject.Properties["Attachment"] -and
        $interfaces[0].Attachment.InstanceId -eq $instance.InstanceId
    )

    $rules = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules", "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )).SecurityGroupRules )
    $inbound = @($rules | Where-Object { -not $_.IsEgress })
    $outbound = @($rules | Where-Object { $_.IsEgress })
    $https = @($outbound | Where-Object {
        $_.IpProtocol -eq "tcp" -and
        $_.PSObject.Properties["FromPort"] -and $_.FromPort -eq 443 -and
        $_.PSObject.Properties["ToPort"] -and $_.ToPort -eq 443 -and
        $_.PSObject.Properties["CidrIpv4"] -and $_.CidrIpv4 -eq "0.0.0.0/0"
    })
    Write-Host "`n=== Security Group ===" -ForegroundColor Cyan
    Write-Host "ID: $($group.GroupId)"
    Write-Host "Uso exclusivo: $exclusive"
    Write-Host "Regras de entrada: $($inbound.Count)"
    Write-Host "Regras de saída: $($outbound.Count)"
    foreach ($rule in $rules) {
        if ($rule.PSObject.Properties["CidrIpv4"]) {
            $target = $rule.CidrIpv4
        }
        elseif ($rule.PSObject.Properties["CidrIpv6"]) {
            $target = $rule.CidrIpv6
        }
        else {
            $target = "outro destino"
        }

        $fromPort = if ($rule.PSObject.Properties["FromPort"]) {
            $rule.FromPort
        } else { "*" }
        $toPort = if ($rule.PSObject.Properties["ToPort"]) {
            $rule.ToPort
        } else { "*" }

        $values = @(
            $rule.SecurityGroupRuleId
            $rule.IsEgress
            $rule.IpProtocol
            $fromPort
            $toPort
            $target
        )
        $line = [string]::Format(
            "ID={0} saída={1} protocolo={2} portas={3}-{4} destino={5}",
            $values
        )
        Write-Host $line
    }

    $role = (Get-AwsJson -Arguments @(
        "iam", "get-role", "--role-name", $RoleName
    )).Role
    Assert-Tags -Resource $role -Description "IAM Role" -Name $RoleName
    $profile = (Get-AwsJson -Arguments @(
        "iam", "get-instance-profile", "--instance-profile-name", $ProfileResourceName
    )).InstanceProfile
    Assert-Tags -Resource $profile -Description "Instance Profile" -Name $ProfileResourceName
    $policies = @( (Get-AwsJson -Arguments @(
        "iam", "list-attached-role-policies", "--role-name", $RoleName
    )).AttachedPolicies )
    $policyPresent = @($policies | Where-Object { $_.PolicyArn -eq $SsmPolicyArn }).Count -eq 1
    $profileLinked = @($profile.Roles | Where-Object { $_.RoleName -eq $RoleName }).Count -eq 1
    Write-Host "`n=== IAM e Systems Manager ===" -ForegroundColor Cyan
    Write-Host "Role: $RoleName"
    Write-Host "Role no Instance Profile: $profileLinked"
    Write-Host "Política SSM anexada: $policyPresent"

    $managed = @( (Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$($instance.InstanceId)"
    )).InstanceInformationList )
    $pingStatus = if ($managed.Count -eq 1) { $managed[0].PingStatus } else { "registro ausente" }
    Write-Host "PingStatus: $pingStatus"
    if ($managed.Count -eq 1 -and $managed[0].PSObject.Properties["LastPingDateTime"]) {
        Write-Host "Último contato: $($managed[0].LastPingDateTime)"
    }

    Write-Host "`n=== Conclusão ===" -ForegroundColor Cyan
    if ($instance.State.Name -eq "running" -and $exclusive -and
        $profileLinked -and $policyPresent -and
        $publicRoutes.Count -eq 1 -and $inbound.Count -eq 0 -and
        $outbound.Count -eq 0 -and $pingStatus -ne "Online") {
        Write-Host "Evidências compatíveis com a falha planejada: saída HTTPS ausente e SSM não Online."
        Write-Host "A Network ACL foi exibida para inspeção, sem comparação com captura anterior."
    }
    elseif ($https.Count -eq 1 -and $pingStatus -eq "Online") {
        Write-Host "Saída HTTPS presente e agente Online; falha planejada não observada."
    }
    else {
        Write-Host "Resultado inconclusivo. Examine os campos acima antes de atribuir a causa."
    }
    Write-Host "DIAGNÓSTICO CONCLUÍDO" -ForegroundColor Green
}
catch {
    Write-Host "`n[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
