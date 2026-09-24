[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [string]$AllowedHttpCidr
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"
$InstanceName = "lab15-connectivity-troubleshooting-instance"
$GroupName = "lab15-connectivity-troubleshooting-sg"
$ProfileResourceName = "lab15-ec2-connectivity-troubleshooting-instance-profile"

$ExpectedTags = @{
    Project     = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab         = "15"
    ManagedBy   = "aws-cli"
    Owner       = "itamarsb"
}

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $previousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"

        $lines = @(
            & aws @Arguments `
                --profile $ProfileName `
                --region $Region `
                --no-cli-pager 2>&1
        )

        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    $output = (
        $lines | ForEach-Object {
            if ($null -ne $_) {
                $_.ToString()
            }
        }
    ) -join "`n"

    if ($exitCode -ne 0) {
        throw "Falha na AWS CLI: aws $($Arguments -join ' ')`n$output"
    }

    return $output.Trim()
}

function Get-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = Invoke-Aws -Arguments (
        $Arguments + @("--output", "json")
    )

    if ([string]::IsNullOrWhiteSpace($output)) {
        throw "A AWS CLI não retornou o JSON esperado."
    }

    return ($output | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param(
        [Parameter(Mandatory = $true)][object[]]$Tags,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Lab
    )

    $actual = @{}

    foreach ($tag in @($Tags)) {
        $actual[[string]$tag.Key] = [string]$tag.Value
    }

    $expected = @{
        Project     = "cloud-infrastructure-operations-lab"
        Environment = "lab"
        Lab         = $Lab
        ManagedBy   = "aws-cli"
        Owner       = "itamarsb"
        Name        = $Name
    }

    foreach ($key in $expected.Keys) {
        if ($actual[$key] -ne $expected[$key]) {
            throw "$Description possui tag $key ausente ou incompatível."
        }
    }
}

function Test-ExternalHealth {
    param([Parameter(Mandatory = $true)][string]$Address)

    try {
        $response = Invoke-WebRequest `
            -Uri "http://$Address/health" `
            -UseBasicParsing `
            -DisableKeepAlive `
            -TimeoutSec 8

        return (
            $response.StatusCode -eq 200 -and
            $response.Content.Trim() -eq "healthy"
        )
    }
    catch {
        return $false
    }
}

try {
    Write-Host ""
    Write-Host "=== Lab 15: diagnóstico de conectividade ===" `
        -ForegroundColor Cyan

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }

    if ($Region -ne "us-east-1") {
        throw "Este laboratório foi definido para us-east-1."
    }

    $parts = $AllowedHttpCidr -split "/"
    $parsedIp = $null

    if (
        $parts.Count -ne 2 -or
        $parts[1] -ne "32" -or
        -not [System.Net.IPAddress]::TryParse(
            $parts[0],
            [ref]$parsedIp
        ) -or
        $parsedIp.AddressFamily -ne
            [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {
        throw "Informe um endereço IPv4 válido com máscara /32."
    }

    Write-Host ""
    Write-Host "=== 1. Identidade AWS ===" -ForegroundColor Cyan

    $identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ([string]::IsNullOrWhiteSpace($identity.Account)) {
        throw "Não foi possível validar a identidade AWS."
    }

    Write-Host "Perfil: $ProfileName"
    Write-Host "Região: $Region"
    Write-Host "Conta:  $($identity.Account)"
    Write-Host "ARN:    $($identity.Arn)"

    Write-Host ""
    Write-Host "=== 2. VPC e sub-rede ===" -ForegroundColor Cyan

    $vpcResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $vpcs = @($vpcResponse.Vpcs)

    if ($vpcs.Count -ne 1) {
        throw "É necessária exatamente uma VPC disponível chamada $VpcName."
    }

    $vpc = $vpcs[0]

    Assert-Tags `
        -Tags @($vpc.Tags) `
        -Description "VPC" `
        -Name $VpcName `
        -Lab "08"

    $subnetResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--filters",
        "Name=tag:Name,Values=$SubnetName",
        "Name=vpc-id,Values=$($vpc.VpcId)",
        "Name=state,Values=available"
    )

    $subnets = @($subnetResponse.Subnets)

    if ($subnets.Count -ne 1) {
        throw "É necessária exatamente uma sub-rede chamada $SubnetName."
    }

    $subnet = $subnets[0]

    Assert-Tags `
        -Tags @($subnet.Tags) `
        -Description "Sub-rede" `
        -Name $SubnetName `
        -Lab "08"

    Write-Host "VPC:       $($vpc.VpcId)"
    Write-Host "Sub-rede:  $($subnet.SubnetId)"
    Write-Host "Zona:      $($subnet.AvailabilityZone)"
    Write-Host "IPv4 auto: $($subnet.MapPublicIpOnLaunch)"

    Write-Host ""
    Write-Host "=== 3. Instância EC2 ===" -ForegroundColor Cyan

    $instanceResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $instances = @(
        $instanceResponse.Reservations |
            ForEach-Object { $_.Instances }
    )

    if ($instances.Count -ne 1) {
        throw "É necessária exatamente uma instância ativa do Lab 15."
    }

    $instance = $instances[0]

    Assert-Tags `
        -Tags @($instance.Tags) `
        -Description "Instância" `
        -Name $InstanceName `
        -Lab "15"

    if (
        $instance.VpcId -ne $vpc.VpcId -or
        $instance.SubnetId -ne $subnet.SubnetId
    ) {
        throw "A instância não pertence à VPC e sub-rede esperadas."
    }

    Write-Host "Instance ID:     $($instance.InstanceId)"
    Write-Host "Estado:          $($instance.State.Name)"
    Write-Host "IPv4 privado:    $($instance.PrivateIpAddress)"
    Write-Host "IPv4 público:    $($instance.PublicIpAddress)"
    Write-Host "Zona:            $($instance.Placement.AvailabilityZone)"
    Write-Host "Key Pair:        $($instance.KeyName)"
    Write-Host "IMDSv2:          $($instance.MetadataOptions.HttpTokens)"
    Write-Host "Instance Profile: $($instance.IamInstanceProfile.Arn)"

    if ($instance.State.Name -ne "running") {
        throw "A instância não está running; investigue seu estado primeiro."
    }

    if ([string]::IsNullOrWhiteSpace($instance.PublicIpAddress)) {
        throw "A instância não possui IPv4 público."
    }

    if (
        $instance.IamInstanceProfile.Arn -notmatch
            "/$([regex]::Escape($ProfileResourceName))$"
    ) {
        throw "A instância utiliza um Instance Profile inesperado."
    }

    Write-Host ""
    Write-Host "=== 4. Systems Manager e aplicação local ===" `
        -ForegroundColor Cyan

    $ssmResponse = Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information",
        "--filters",
        "Key=InstanceIds,Values=$($instance.InstanceId)"
    )

    $online = @(
        $ssmResponse.InstanceInformationList |
            Where-Object {
                $_.InstanceId -eq $instance.InstanceId -and
                $_.PingStatus -eq "Online"
            }
    )

    if ($online.Count -ne 1) {
        throw "A instância não está Online no Systems Manager."
    }

    Write-Host "Systems Manager: Online"

    $commands = @(
        "printf 'SERVICE='; systemctl is-active nginx",
        "printf 'CONFIG='; nginx -t >/dev/null 2>&1 && echo valid || echo invalid",
        "printf 'LISTEN='; ss -lnt | grep ':80 ' || true",
        "printf 'ROOT='; curl --silent --show-error --max-time 5 http://127.0.0.1/ || true",
        "printf 'HEALTH='; curl --silent --show-error --max-time 5 http://127.0.0.1/health || true"
    )

    $parametersJson = @{
        commands = [string[]]$commands
    } | ConvertTo-Json -Compress -Depth 4

    $sent = Get-AwsJson -Arguments @(
        "ssm", "send-command",
        "--instance-ids", $instance.InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--parameters", $parametersJson,
        "--comment", "Lab 15 read-only layered diagnosis"
    )

    $commandId = $sent.Command.CommandId

    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "Systems Manager não retornou um Command ID."
    }

    $invocation = $null

    for ($attempt = 1; $attempt -le 24; $attempt++) {
        Start-Sleep -Seconds 5

        $result = Get-AwsJson -Arguments @(
            "ssm", "list-command-invocations",
            "--command-id", $commandId,
            "--instance-id", $instance.InstanceId,
            "--details"
        )

        $items = @($result.CommandInvocations)

        if ($items.Count -ne 1) {
            continue
        }

        $invocation = $items[0]

        if (
            $invocation.Status -notin @(
                "Pending", "InProgress", "Delayed"
            )
        ) {
            break
        }
    }

    if (
        $null -eq $invocation -or
        $invocation.Status -ne "Success"
    ) {
        throw "O diagnóstico local via Systems Manager não terminou com sucesso."
    }

    $plugin = @($invocation.CommandPlugins)[0]

    if ($null -eq $plugin) {
        throw "O Systems Manager não retornou a saída dos comandos."
    }

    $localOutput = [string]$plugin.Output
    Write-Host $localOutput

    $serviceHealthy = $localOutput -match "(?m)^SERVICE=active\s*$"
    $configHealthy = $localOutput -match "(?m)^CONFIG=valid\s*$"
    $portListening = $localOutput -match "(?m)^LISTEN=.+:80\s"
    $localHealth = $localOutput -match "(?m)^HEALTH=healthy\s*$"

    Write-Host ""
    Write-Host "=== 5. Tabela de rotas e Internet Gateway ===" `
        -ForegroundColor Cyan

    $routesResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-route-tables",
        "--filters",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )

    $explicitRoutes = @(
        $routesResponse.RouteTables | Where-Object {
            @($_.Associations | Where-Object {
                $_.SubnetId -eq $subnet.SubnetId
            }).Count -gt 0
        }
    )

    if ($explicitRoutes.Count -gt 1) {
        throw "Mais de uma tabela de rotas associada à sub-rede."
    }

    if ($explicitRoutes.Count -eq 1) {
        $routeTable = $explicitRoutes[0]
    }
    else {
        $mainRoutes = @(
            $routesResponse.RouteTables | Where-Object {
                @($_.Associations | Where-Object {
                    $_.Main -eq $true
                }).Count -gt 0
            }
        )

        if ($mainRoutes.Count -ne 1) {
            throw "Não foi possível identificar a tabela de rotas."
        }

        $routeTable = $mainRoutes[0]
    }

    $publicRoutes = @(
        $routeTable.Routes | Where-Object {
            $_.DestinationCidrBlock -eq "0.0.0.0/0" -and
            $_.State -eq "active" -and
            $_.GatewayId -match "^igw-"
        }
    )

    $publicRoutePresent = $publicRoutes.Count -eq 1

    Write-Host "Tabela: $($routeTable.RouteTableId)"
    Write-Host "Rota pública ativa: $publicRoutePresent"

    if ($publicRoutePresent) {
        $gatewayId = $publicRoutes[0].GatewayId

        $gatewayResponse = Get-AwsJson -Arguments @(
            "ec2", "describe-internet-gateways",
            "--internet-gateway-ids", $gatewayId
        )

        $gatewayAttached = (
            @($gatewayResponse.InternetGateways).Count -eq 1 -and
            @($gatewayResponse.InternetGateways[0].Attachments |
                Where-Object {
                    $_.VpcId -eq $vpc.VpcId -and
                    $_.State -eq "available"
                }).Count -eq 1
        )

        Write-Host "Internet Gateway: $gatewayId"
        Write-Host "Associado à VPC:  $gatewayAttached"
    }
    else {
        $gatewayAttached = $false
    }

    Write-Host ""
    Write-Host "=== 6. Network ACL ===" -ForegroundColor Cyan

    $aclResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-network-acls",
        "--filters",
        "Name=association.subnet-id,Values=$($subnet.SubnetId)"
    )

    $acls = @($aclResponse.NetworkAcls)

    if ($acls.Count -ne 1) {
        throw "Não foi possível identificar a Network ACL da sub-rede."
    }

    $acl = $acls[0]

    Write-Host "Network ACL: $($acl.NetworkAclId)"
    Write-Host "Regras em ordem de avaliação:"

    $acl.Entries |
        Sort-Object Egress, RuleNumber |
        ForEach-Object {
            $direction = if ($_.Egress) {
                "saída"
            }
            else {
                "entrada"
            }

            $port = if ($null -ne $_.PortRange) {
                "$($_.PortRange.From)-$($_.PortRange.To)"
            }
            else {
                "todas"
            }

            Write-Host (
                "{0}: regra={1} ação={2} protocolo={3} " +
                "portas={4} origem/destino={5}" -f
                $direction,
                $_.RuleNumber,
                $_.RuleAction,
                $_.Protocol,
                $port,
                $_.CidrBlock
            )
        }

    Write-Host ""
    Write-Host "=== 7. Security Group ===" -ForegroundColor Cyan

    $groupsResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$GroupName",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )

    $groups = @($groupsResponse.SecurityGroups)

    if ($groups.Count -ne 1) {
        throw "É necessário exatamente um Security Group do Lab 15."
    }

    $group = $groups[0]

    Assert-Tags `
        -Tags @($group.Tags) `
        -Description "Security Group" `
        -Name $GroupName `
        -Lab "15"

    $attachedGroups = @(
        $instance.SecurityGroups |
            ForEach-Object { $_.GroupId }
    )

    if (
        $attachedGroups.Count -ne 1 -or
        $attachedGroups[0] -ne $group.GroupId
    ) {
        throw "A instância utiliza Security Groups inesperados."
    }

    $rulesResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules",
        "--filters",
        "Name=group-id,Values=$($group.GroupId)"
    )

    $httpRules = @(
        $rulesResponse.SecurityGroupRules |
            Where-Object {
                $_.IsEgress -eq $false -and
                $_.IpProtocol -eq "tcp" -and
                $_.FromPort -eq 80 -and
                $_.ToPort -eq 80 -and
                $_.CidrIpv4 -eq $AllowedHttpCidr
            }
    )

    Write-Host "Security Group: $($group.GroupId)"
    Write-Host "Regra TCP 80 para $AllowedHttpCidr`: $($httpRules.Count)"

    Write-Host ""
    Write-Host "=== 8. HTTP externo ===" -ForegroundColor Cyan

    $externalHealthy = Test-ExternalHealth `
        -Address $instance.PublicIpAddress

    Write-Host "URL: http://$($instance.PublicIpAddress)/health"
    Write-Host "Resposta healthy: $externalHealthy"

    Write-Host ""
    Write-Host "=== Conclusão ===" -ForegroundColor Cyan

    if (
        $serviceHealthy -and
        $configHealthy -and
        $portListening -and
        $localHealth -and
        $publicRoutePresent -and
        $gatewayAttached -and
        $httpRules.Count -eq 0 -and
        -not $externalHealthy
    ) {
        Write-Host (
            "Evidências compatíveis com a falha planejada: " +
            "aplicação saudável localmente, rota pública ativa, " +
            "regra HTTP do Security Group ausente e acesso externo " +
            "indisponível."
        ) -ForegroundColor Green

        Write-Host (
            "A Network ACL foi exibida acima para inspeção. " +
            "Este script não compara suas regras com uma captura anterior."
        )

        Write-Host ""
        Write-Host "DIAGNÓSTICO CONCLUÍDO" -ForegroundColor Green
    }
    else {
        Write-Host (
            "As evidências não correspondem integralmente à falha " +
            "planejada. Examine os resultados de cada camada acima."
        ) -ForegroundColor Yellow

        throw "Diagnóstico inconclusivo para a falha planejada."
    }
}
catch {
    Write-Host ""
    Write-Host "[FALHA] $($_.Exception.Message)" `
        -ForegroundColor Red

    exit 1
}
