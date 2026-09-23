[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [string]$AllowedHttpCidr,

    [ValidateSet("Healthy", "Failed", "Any")]
    [string]$ExpectedConnectivityState = "Healthy"
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
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

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
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

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
        [Parameter(Mandatory = $true)]
        [object[]]$Tags,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $actual = @{}

    foreach ($tag in @($Tags)) {
        $actual[[string]$tag.Key] = [string]$tag.Value
    }

    foreach ($key in $ExpectedTags.Keys) {
        if ($actual[$key] -ne $ExpectedTags[$key]) {
            throw "$Description possui tag $key ausente ou incompatível."
        }
    }

    if ($actual["Name"] -ne $Name) {
        throw "$Description possui tag Name incompatível."
    }
}

function Assert-HttpResponse {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address,

        [Parameter(Mandatory = $true)]
        [bool]$ShouldSucceed
    )

    $uri = "http://$Address/health"
    $succeeded = $false

    try {
        $response = Invoke-WebRequest `
            -Uri $uri `
            -UseBasicParsing `
            -TimeoutSec 8 `
            -DisableKeepAlive

        $succeeded = (
            $response.StatusCode -eq 200 -and
            $response.Content.Trim() -eq "healthy"
        )
    }
    catch {
        $succeeded = $false
    }

    if ($ShouldSucceed -and -not $succeeded) {
        throw "O endpoint HTTP externo não respondeu como healthy."
    }

    if (-not $ShouldSucceed -and $succeeded) {
        throw "O endpoint HTTP externo ainda está acessível."
    }

    if ($succeeded) {
        Write-Host "[OK] HTTP externo: healthy."
    }
    else {
        Write-Host "[OK] HTTP externo: indisponível."
    }
}

try {
    Write-Host ""
    Write-Host "=== Lab 15: validação somente leitura ===" `
        -ForegroundColor Cyan

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }

    if ($Region -ne "us-east-1") {
        throw "Este laboratório foi definido para us-east-1."
    }

    $cidrParts = $AllowedHttpCidr -split "/"
    $parsedIp = $null

    if (
        $cidrParts.Count -ne 2 -or
        $cidrParts[1] -ne "32" -or
        -not [System.Net.IPAddress]::TryParse(
            $cidrParts[0],
            [ref]$parsedIp
        ) -or
        $parsedIp.AddressFamily -ne
            [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {
        throw "Informe um endereço IPv4 válido com máscara /32."
    }

    $identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ([string]::IsNullOrWhiteSpace($identity.Account)) {
        throw "Não foi possível validar a identidade AWS."
    }

    Write-Host "[OK] Conta: $($identity.Account)"
    Write-Host "[OK] Estado esperado: $ExpectedConnectivityState"

    Write-Host ""
    Write-Host "=== Rede compartilhada ===" -ForegroundColor Cyan

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

    if ($subnet.AvailabilityZone -ne "us-east-1a") {
        throw "A sub-rede está em outra zona de disponibilidade."
    }

    $routeResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-route-tables",
        "--filters",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )

    $explicit = @(
        $routeResponse.RouteTables | Where-Object {
            @($_.Associations | Where-Object {
                $_.SubnetId -eq $subnet.SubnetId
            }).Count -gt 0
        }
    )

    if ($explicit.Count -gt 1) {
        throw "Mais de uma tabela de rotas associada à sub-rede."
    }

    if ($explicit.Count -eq 1) {
        $routeTable = $explicit[0]
    }
    else {
        $main = @(
            $routeResponse.RouteTables | Where-Object {
                @($_.Associations | Where-Object {
                    $_.Main -eq $true
                }).Count -gt 0
            }
        )

        if ($main.Count -ne 1) {
            throw "Não foi possível identificar a tabela de rotas."
        }

        $routeTable = $main[0]
    }

    $internetRoutes = @(
        $routeTable.Routes | Where-Object {
            $_.DestinationCidrBlock -eq "0.0.0.0/0" -and
            $_.State -eq "active" -and
            $_.GatewayId -match "^igw-"
        }
    )

    if ($internetRoutes.Count -ne 1) {
        throw "A rota pública para o Internet Gateway está ausente."
    }

    $aclResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-network-acls",
        "--filters",
        "Name=association.subnet-id,Values=$($subnet.SubnetId)"
    )

    if (@($aclResponse.NetworkAcls).Count -ne 1) {
        throw "Não foi possível identificar a Network ACL."
    }

    Write-Host "[OK] VPC: $($vpc.VpcId)"
    Write-Host "[OK] Sub-rede: $($subnet.SubnetId)"
    Write-Host "[OK] Rota pública: $($routeTable.RouteTableId)"
    Write-Host "[OK] Network ACL: $($aclResponse.NetworkAcls[0].NetworkAclId)"

    Write-Host ""
    Write-Host "=== Instância e Security Group ===" `
        -ForegroundColor Cyan

    $instancesResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=running"
    )

    $instances = @(
        $instancesResponse.Reservations |
            ForEach-Object { $_.Instances }
    )

    if ($instances.Count -ne 1) {
        throw "É necessária exatamente uma instância running do Lab 15."
    }

    $instance = $instances[0]

    Assert-Tags `
        -Tags @($instance.Tags) `
        -Description "Instância" `
        -Name $InstanceName

    if (
        $instance.VpcId -ne $vpc.VpcId -or
        $instance.SubnetId -ne $subnet.SubnetId
    ) {
        throw "A instância não está na rede compartilhada esperada."
    }

    if ([string]::IsNullOrWhiteSpace($instance.PublicIpAddress)) {
        throw "A instância não possui IPv4 público."
    }

    if (-not [string]::IsNullOrWhiteSpace($instance.KeyName)) {
        throw "A instância possui uma Key Pair inesperada."
    }

    if ($instance.MetadataOptions.HttpTokens -ne "required") {
        throw "IMDSv2 não está obrigatório."
    }

    if (
        $instance.IamInstanceProfile.Arn -notmatch
            "/$([regex]::Escape($ProfileResourceName))$"
    ) {
        throw "A instância não utiliza o Instance Profile esperado."
    }

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
        -Name $GroupName

    $instanceGroupIds = @(
        $instance.SecurityGroups |
            ForEach-Object { $_.GroupId }
    )

    if (
        $instanceGroupIds.Count -ne 1 -or
        $instanceGroupIds[0] -ne $group.GroupId
    ) {
        throw "A instância utiliza Security Groups inesperados."
    }

    $httpRules = @(
        $group.IpPermissions | Where-Object {
            $_.IpProtocol -eq "tcp" -and
            $_.FromPort -eq 80 -and
            $_.ToPort -eq 80
        } | ForEach-Object {
            $_.IpRanges
        } | Where-Object {
            $_.CidrIp -eq $AllowedHttpCidr
        }
    )

    $rulePresent = $httpRules.Count -eq 1

    if ($httpRules.Count -gt 1) {
        throw "Há regras HTTP duplicadas para o CIDR informado."
    }

    $sshRules = @(
        $group.IpPermissions | Where-Object {
            $_.IpProtocol -eq "tcp" -and
            $_.FromPort -le 22 -and
            $_.ToPort -ge 22
        }
    )

    if ($sshRules.Count -gt 0) {
        throw "O Security Group possui uma regra SSH inesperada."
    }

    Write-Host "[OK] Instância: $($instance.InstanceId)"
    Write-Host "[OK] Security Group: $($group.GroupId)"

    Write-Host ""
    Write-Host "=== Systems Manager e serviço local ===" `
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

    # Execute somente comandos de observação na instância.
    $commands = @(
        "systemctl is-active nginx",
        "nginx -t 2>&1",
        "ss -lnt | grep -E '(^|[[:space:]])[^[:space:]]+:80[[:space:]]'",
        "curl --fail --silent --show-error http://127.0.0.1/health"
    )

    $parametersJson = @{
        commands = [string[]]$commands
    } | ConvertTo-Json -Compress -Depth 4

    $sendResponse = Get-AwsJson -Arguments @(
        "ssm", "send-command",
        "--instance-ids", $instance.InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--parameters", $parametersJson,
        "--comment", "Lab 15 read-only local validation"
    )

    $commandId = $sendResponse.Command.CommandId

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

        $invocations = @($result.CommandInvocations)

        if ($invocations.Count -ne 1) {
            continue
        }

        $invocation = $invocations[0]

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
        $status = if ($null -eq $invocation) {
            "sem retorno"
        }
        else {
            $invocation.Status
        }

        throw "Validação local via Systems Manager falhou: $status."
    }

    Write-Host "[OK] Systems Manager: Online."
    Write-Host "[OK] Nginx, configuração, porta 80 e /health local."

    Write-Host ""
    Write-Host "=== Conectividade externa ===" `
        -ForegroundColor Cyan

    switch ($ExpectedConnectivityState) {
        "Healthy" {
            if (-not $rulePresent) {
                throw "A regra TCP 80 esperada está ausente."
            }

            Write-Host "[OK] Regra HTTP presente."
            Assert-HttpResponse `
                -Address $instance.PublicIpAddress `
                -ShouldSucceed $true
        }

        "Failed" {
            if ($rulePresent) {
                throw "A regra TCP 80 ainda está presente."
            }

            Write-Host "[OK] Regra HTTP ausente."
            Assert-HttpResponse `
                -Address $instance.PublicIpAddress `
                -ShouldSucceed $false
        }

        "Any" {
            $state = if ($rulePresent) {
                "regra presente"
            }
            else {
                "regra ausente"
            }

            Write-Host "[INFO] Regra HTTP: $state."
            Write-Host (
                "[INFO] Estado Any: nenhuma conclusão sobre " +
                "o HTTP externo foi exigida."
            )
        }
    }

    Write-Host ""
    Write-Host "VALIDAÇÃO CONCLUÍDA: $ExpectedConnectivityState" `
        -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "[FALHA] $($_.Exception.Message)" `
        -ForegroundColor Red

    exit 1
}
