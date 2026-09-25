[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [switch]$ConfirmFailure
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
$mutationStarted = $false
$confirmed = $false
$groupId = $null
$instanceId = $null

function Invoke-AwsNative {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& aws @Arguments --profile $ProfileName --region $Region --no-cli-pager 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    $output = ($lines | ForEach-Object { if ($null -ne $_) { $_.ToString() } }) -join "`n"
    return [pscustomobject]@{ ExitCode = $exitCode; Output = $output.Trim() }
}

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $result = Invoke-AwsNative -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        throw "Falha na AWS CLI: aws $($Arguments -join ' ')`n$($result.Output)"
    }
    return $result.Output
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
            throw "$Description possui tag $key incompatível. Falha recusada."
        }
    }
    if ($actual.Name -ne $Name) {
        throw "$Description possui tag Name incompatível. Falha recusada."
    }
}

function Get-Rules {
    param([string]$Id)
    $response = Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules", "--filters", "Name=group-id,Values=$Id"
    )
    return @($response.SecurityGroupRules)
}

function Test-HttpsRule {
    param($Rule, [string]$Id)
    return (
        $Rule.GroupId -eq $Id -and $Rule.IsEgress -eq $true -and
        $Rule.IpProtocol -eq "tcp" -and $Rule.FromPort -eq 443 -and
        $Rule.ToPort -eq 443 -and $Rule.CidrIpv4 -eq "0.0.0.0/0" -and
        -not $Rule.PSObject.Properties["CidrIpv6"] -and
        -not $Rule.PSObject.Properties["PrefixListId"] -and
        -not $Rule.PSObject.Properties["ReferencedGroupInfo"]
    )
}

function Get-PingStatus {
    param([string]$Id)
    $list = @( (Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$Id"
    )).InstanceInformationList )
    if ($list.Count -eq 1) { return [string]$list[0].PingStatus }
    if ($list.Count -eq 0) { return "registro ausente" }
    throw "Mais de um registro SSM encontrado para a instância."
}

function Restore-HttpsIfAbsent {
    param([string]$Id)
    $rules = @(Get-Rules -Id $Id)
    if ($rules.Count -eq 1 -and (Test-HttpsRule -Rule $rules[0] -Id $Id)) {
        return "Regra HTTPS já presente: $($rules[0].SecurityGroupRuleId)"
    }
    if ($rules.Count -ne 0) {
        throw "Regras inesperadas no Security Group. Restauração automática recusada."
    }
    $response = Get-AwsJson -Arguments @(
        "ec2", "authorize-security-group-egress", "--group-id", $Id,
        "--ip-permissions",
        "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}]"
    )
    if ($response.Return -ne $true) { throw "AWS não confirmou a restauração HTTPS." }
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        $rules = @(Get-Rules -Id $Id)
        if ($rules.Count -eq 1 -and (Test-HttpsRule -Rule $rules[0] -Id $Id)) {
            return "Regra HTTPS restaurada: $($rules[0].SecurityGroupRuleId)"
        }
        Start-Sleep -Seconds 5
    }
    throw "Regra HTTPS não confirmada após tentativa de restauração."
}

function Assert-SsmCommand {
    param([string]$Id)
    $path = Join-Path ([IO.Path]::GetTempPath()) `
        ("lab16-ssm-{0}.json" -f [guid]::NewGuid().ToString("N"))
    try {
        $json = @{ commands = @("uname -s") } | ConvertTo-Json -Compress
        [IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
        $uri = "file://$($path.Replace('\', '/'))"
        $sent = Get-AwsJson -Arguments @(
            "ssm", "send-command", "--instance-ids", $Id,
            "--document-name", "AWS-RunShellScript",
            "--parameters", $uri,
            "--comment", "Lab 16 read-only preflight"
        )
        $commandId = [string]$sent.Command.CommandId
        if ([string]::IsNullOrWhiteSpace($commandId)) {
            throw "SSM não retornou o Command ID."
        }
        for ($attempt = 1; $attempt -le 18; $attempt++) {
            $result = Invoke-AwsNative -Arguments @(
                "ssm", "get-command-invocation", "--command-id", $commandId,
                "--instance-id", $Id, "--output", "json"
            )
            if ($result.ExitCode -eq 0) {
                $invocation = $result.Output | ConvertFrom-Json -ErrorAction Stop
                if ($invocation.Status -eq "Success") {
                    if ($invocation.StandardOutputContent.Trim() -ne "Linux") {
                        throw "Saída inesperada do comando SSM."
                    }
                    return
                }
                if ($invocation.Status -in @("Failed", "Cancelled", "TimedOut")) {
                    throw "Comando SSM terminou com estado $($invocation.Status)."
                }
            }
            elseif ($result.Output -notmatch "InvocationDoesNotExist") {
                throw "Falha ao consultar comando SSM: $($result.Output)"
            }
            Start-Sleep -Seconds 5
        }
        throw "Comando SSM não concluiu no prazo."
    }
    finally {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

try {
    Write-Host "`n=== Lab 16: falha controlada ===" -ForegroundColor Cyan
    if (-not $ConfirmFailure) { throw "Informe -ConfirmFailure." }
    if ($Region -ne "us-east-1") { throw "Região inesperada." }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { throw "AWS CLI não encontrada." }
    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    if ([string]::IsNullOrWhiteSpace($identity.Account)) { throw "Conta AWS não confirmada." }
    Write-Host "[OK] Conta AWS: $($identity.Account)"

    $vpcs = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs", "--filters",
        "Name=tag:Name,Values=$VpcName", "Name=state,Values=available"
    )).Vpcs )
    if ($vpcs.Count -ne 1) { throw "VPC compartilhada ausente ou duplicada." }
    $vpcId = $vpcs[0].VpcId
    $subnets = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-subnets", "--filters",
        "Name=tag:Name,Values=$SubnetName", "Name=vpc-id,Values=$vpcId"
    )).Subnets )
    if ($subnets.Count -ne 1) { throw "Sub-rede compartilhada ausente ou duplicada." }
    $subnet = $subnets[0]
    if (-not $subnet.MapPublicIpOnLaunch) { throw "Sub-rede sem IPv4 público automático." }

    $routes = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-route-tables", "--filters",
        "Name=association.subnet-id,Values=$($subnet.SubnetId)"
    )).RouteTables )
    if ($routes.Count -ne 1) { throw "Tabela de rotas da sub-rede ausente ou duplicada." }
    $publicRoutes = @($routes[0].Routes | Where-Object {
        $_.PSObject.Properties["DestinationCidrBlock"] -and
        $_.DestinationCidrBlock -eq "0.0.0.0/0" -and $_.State -eq "active" -and
        $_.PSObject.Properties["GatewayId"] -and $_.GatewayId -like "igw-*"
    })
    if ($publicRoutes.Count -ne 1) { throw "Rota pública ativa não confirmada." }
    $igws = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-internet-gateways", "--internet-gateway-ids",
        $publicRoutes[0].GatewayId
    )).InternetGateways )
    if ($igws.Count -ne 1 -or
        @($igws[0].Attachments | Where-Object { $_.VpcId -eq $vpcId }).Count -ne 1) {
        throw "Internet Gateway não associado à VPC."
    }
    $acls = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-network-acls", "--filters",
        "Name=association.subnet-id,Values=$($subnet.SubnetId)"
    )).NetworkAcls )
    if ($acls.Count -ne 1) { throw "Network ACL da sub-rede ausente ou duplicada." }

    $reservations = (Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )).Reservations
    $instances = @($reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) { throw "Instância do Lab 16 ausente ou duplicada." }
    $instance = $instances[0]
    Assert-Tags -Resource $instance -Description "Instância" -Name $InstanceName
    if ($instance.State.Name -ne "running" -or $instance.VpcId -ne $vpcId -or
        $instance.SubnetId -ne $subnet.SubnetId -or
        -not $instance.PSObject.Properties["PublicIpAddress"] -or
        [string]::IsNullOrWhiteSpace($instance.PublicIpAddress) -or
        $instance.MetadataOptions.HttpTokens -ne "required") {
        throw "Estado, rede, IPv4 público ou IMDSv2 da instância incompatível."
    }
    $instanceId = $instance.InstanceId
    if (-not $instance.PSObject.Properties["IamInstanceProfile"] -or
        $instance.IamInstanceProfile.Arn -notmatch
            "/$([regex]::Escape($ProfileResourceName))$") {
        throw "Instance Profile da instância incompatível."
    }
    if ($instance.PSObject.Properties["KeyName"] -and
        -not [string]::IsNullOrWhiteSpace($instance.KeyName)) {
        throw "Instância possui Key Pair inesperada."
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
        $interfaces[0].Attachment.InstanceId -ne $instanceId) {
        throw "Security Group associado a interfaces inesperadas."
    }
    $groupId = $group.GroupId

    $role = (Get-AwsJson -Arguments @(
        "iam", "get-role", "--role-name", $RoleName
    )).Role
    Assert-Tags -Resource $role -Description "IAM Role" -Name $RoleName
    $profile = (Get-AwsJson -Arguments @(
        "iam", "get-instance-profile", "--instance-profile-name", $ProfileResourceName
    )).InstanceProfile
    Assert-Tags -Resource $profile -Description "Instance Profile" -Name $ProfileResourceName
    if (@($profile.Roles).Count -ne 1 -or $profile.Roles[0].RoleName -ne $RoleName) {
        throw "Role vinculada ao Instance Profile incompatível."
    }
    $policies = @( (Get-AwsJson -Arguments @(
        "iam", "list-attached-role-policies", "--role-name", $RoleName
    )).AttachedPolicies )
    if ($policies.Count -ne 1 -or $policies[0].PolicyArn -ne $SsmPolicyArn) {
        throw "Política SSM da IAM Role incompatível."
    }
    $inline = @( (Get-AwsJson -Arguments @(
        "iam", "list-role-policies", "--role-name", $RoleName
    )).PolicyNames )
    if ($inline.Count -ne 0) { throw "IAM Role possui política inline inesperada." }

    $rules = @(Get-Rules -Id $groupId)
    if ($rules.Count -ne 1 -or -not (Test-HttpsRule -Rule $rules[0] -Id $groupId)) {
        throw "O Security Group deve conter apenas a saída TCP 443 esperada."
    }
    $ruleId = $rules[0].SecurityGroupRuleId
    if ([string]::IsNullOrWhiteSpace($ruleId)) { throw "ID da regra não encontrado." }
    $ping = Get-PingStatus -Id $instanceId
    if ($ping -ne "Online") { throw "SSM deve estar Online antes da falha; atual: $ping." }
    Assert-SsmCommand -Id $instanceId
    Write-Host "[OK] Instância $instanceId e Systems Manager Online."
    Write-Host "[OK] Run Command somente leitura concluído."
    Write-Host "[OK] IAM, VPC, rota, ACL e grupo exclusivo conferidos."
    Write-Host "Security Group: $groupId"
    Write-Host "Regra HTTPS: $ruleId"

    Write-Host "`n=== Revogação da regra específica ===" -ForegroundColor Cyan
    $mutationStarted = $true
    $response = Get-AwsJson -Arguments @(
        "ec2", "revoke-security-group-egress", "--group-id", $groupId,
        "--security-group-rule-ids", $ruleId
    )
    if ($response.Return -ne $true) { throw "AWS não confirmou a revogação." }
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        $remaining = @(Get-Rules -Id $groupId)
        if ($remaining.Count -eq 0) { break }
        Start-Sleep -Seconds 5
    }
    if ($remaining.Count -ne 0) { throw "A regra não desapareceu ou outra regra está presente." }
    Write-Host "[OK] Regra removida: $ruleId"

    Write-Host "`n=== Observação limitada do SSM ===" -ForegroundColor Cyan
    for ($attempt = 1; $attempt -le 24; $attempt++) {
        $ping = Get-PingStatus -Id $instanceId
        Write-Host "Verificação $attempt/24`: $ping"
        if ($ping -eq "ConnectionLost") {
            $confirmed = $true
            break
        }
        Start-Sleep -Seconds 15
    }
    if (-not $confirmed) {
        throw "O SSM não apresentou ConnectionLost no prazo; resultado inconclusivo."
    }
    $remaining = @(Get-Rules -Id $groupId)
    if ($remaining.Count -ne 0) { throw "As regras mudaram durante a observação." }
    $current = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--instance-ids", $instanceId
    )).Reservations | ForEach-Object { $_.Instances } )
    if ($current.Count -ne 1 -or $current[0].State.Name -ne "running") {
        throw "Instância não permaneceu running."
    }
    Write-Host "[OK] Instância continua running, regra ausente e SSM ConnectionLost."
    Write-Host "`nFALHA CONTROLADA CONFIRMADA" -ForegroundColor Green
}
catch {
    $reason = $_.Exception.Message
    Write-Host "`n[FALHA] $reason" -ForegroundColor Red
    if ($mutationStarted -and -not $confirmed -and $null -ne $groupId) {
        try {
            $restored = Restore-HttpsIfAbsent -Id $groupId
            Write-Host "[OK] $restored" -ForegroundColor Yellow
        }
        catch {
            Write-Host "[FALHA] Restauração automática: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Use recover-aws-systems-manager.ps1 após conferir o inventário." -ForegroundColor Yellow
        }
    }
    elseif ($mutationStarted) {
        Write-Host "Confira a regra e use recover-aws-systems-manager.ps1 para restaurar." -ForegroundColor Yellow
    }
    exit 1
}
