[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [string]$AvailabilityZone = "us-east-1a",
    [string]$InstanceType = "t3.micro"
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
$AmiParameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

function Invoke-Aws {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $previousPreference = $ErrorActionPreference

    try {
        # No Windows PowerShell 5.1, stderr de programas nativos pode
        # gerar erro terminante. Verificamos o código de saída da CLI.
        $ErrorActionPreference = "Continue"

        $response = @(
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
        $response | ForEach-Object {
            if ($null -ne $_) {
                $_.ToString()
            }
        }
    ) -join "`n"

    if ($exitCode -ne 0) {
        throw "AWS CLI falhou: aws $($Arguments -join ' ')`n$output"
    }

    return $output.Trim()
}

function Get-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $json = Invoke-Aws -Arguments (
        $Arguments + @("--output", "json")
    )

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "A AWS CLI não retornou o JSON esperado."
    }

    return ($json | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param(
        [Parameter(Mandatory = $true)]
        $Resource,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedLab
    )

    $tags = @{}

    foreach ($tag in @($Resource.Tags)) {
        $tags[[string]$tag.Key] = [string]$tag.Value
    }

    $expected = @{
        Project     = "cloud-infrastructure-operations-lab"
        Environment = "lab"
        Lab         = $ExpectedLab
        ManagedBy   = "aws-cli"
        Owner       = "itamarsb"
    }

    foreach ($key in $expected.Keys) {
        if ($tags[$key] -ne $expected[$key]) {
            throw "$Description possui tag $key ausente ou incompatível."
        }
    }
}

function Get-Ec2Tags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return @(
        "Key=Name,Value=$Name",
        "Key=Project,Value=cloud-infrastructure-operations-lab",
        "Key=Environment,Value=lab",
        "Key=Lab,Value=16",
        "Key=ManagedBy,Value=aws-cli",
        "Key=Owner,Value=itamarsb"
    )
}

function Get-TagSpecification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $tags = Get-Ec2Tags -Name $Name
    $tagStructures = @(
        $tags | ForEach-Object {
            "{$($_)}"
        }
    )

    return "ResourceType=$ResourceType,Tags=[{0}]" -f (
        $tagStructures -join ","
    )
}

try {
    Write-Host ""
    Write-Host "=== Lab 16: pré-requisitos ===" -ForegroundColor Cyan

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }

    if ($Region -ne "us-east-1") {
        throw "Este laboratório foi definido para a região us-east-1."
    }

    if ($AvailabilityZone -ne "us-east-1a") {
        throw "Este laboratório utiliza a sub-rede do Lab 08 em us-east-1a."
    }

    if ($InstanceType -ne "t3.micro") {
        throw "Este laboratório foi definido para instâncias t3.micro."
    }

    $policyPath = Join-Path `
        (Split-Path -Parent $PSScriptRoot) `
        "policies\ec2-ssm-trust-policy.json"

    if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
        throw "Política de confiança não encontrada: $policyPath"
    }

    $trustPolicy = Get-Content -LiteralPath $policyPath -Raw |
        ConvertFrom-Json -ErrorAction Stop

    if (
        $trustPolicy.Statement[0].Principal.Service -ne
            "ec2.amazonaws.com" -or
        $trustPolicy.Statement[0].Action -ne "sts:AssumeRole"
    ) {
        throw "A política de confiança não corresponde ao serviço EC2."
    }

    $identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ([string]::IsNullOrWhiteSpace($identity.Account)) {
        throw "Não foi possível validar a identidade AWS."
    }

    Write-Host "[OK] Conta AWS: $($identity.Account)"
    Write-Host "[OK] Saída HTTPS: TCP 443 para 0.0.0.0/0"

    Write-Host ""
    Write-Host "=== Rede compartilhada do Lab 08 ===" `
        -ForegroundColor Cyan

    $vpcResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=$VpcName",
        "Name=state,Values=available"
    )

    $vpcs = @($vpcResponse.Vpcs)

    if ($vpcs.Count -ne 1) {
        throw (
            "É necessária exatamente uma VPC disponível chamada " +
            "$VpcName. Se ela foi removida, implante novamente o Lab 08."
        )
    }

    $vpc = $vpcs[0]

    Assert-Tags `
        -Resource $vpc `
        -Description "VPC do Lab 08" `
        -ExpectedLab "08"

    $subnetResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--filters",
        "Name=tag:Name,Values=$SubnetName",
        "Name=vpc-id,Values=$($vpc.VpcId)",
        "Name=state,Values=available"
    )

    $subnets = @($subnetResponse.Subnets)

    if ($subnets.Count -ne 1) {
        throw "É necessária exatamente uma sub-rede disponível chamada $SubnetName."
    }

    $subnet = $subnets[0]

    Assert-Tags `
        -Resource $subnet `
        -Description "Sub-rede do Lab 08" `
        -ExpectedLab "08"

    if ($subnet.AvailabilityZone -ne $AvailabilityZone) {
        throw "A sub-rede está em $($subnet.AvailabilityZone)."
    }

    if (-not $subnet.MapPublicIpOnLaunch) {
        throw "A sub-rede não atribui IPv4 público automaticamente."
    }

    $routeResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-route-tables",
        "--filters",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )

    $explicitRoutes = @(
        $routeResponse.RouteTables | Where-Object {
            @(
                $_.Associations | Where-Object {
                    ($_.PSObject.Properties["SubnetId"] -and $_.SubnetId -eq $subnet.SubnetId)
                }
            ).Count -gt 0
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
            $routeResponse.RouteTables | Where-Object {
                @(
                    $_.Associations | Where-Object {
                        ($_.PSObject.Properties["Main"] -and $_.Main -eq $true)
                    }
                ).Count -gt 0
            }
        )

        if ($mainRoutes.Count -ne 1) {
            throw "Não foi possível identificar a tabela de rotas da sub-rede."
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

    if ($publicRoutes.Count -ne 1) {
        throw "A sub-rede não possui rota padrão ativa para um Internet Gateway."
    }

    $gatewayResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-internet-gateways",
        "--internet-gateway-ids", $publicRoutes[0].GatewayId
    )

    if (
        @($gatewayResponse.InternetGateways).Count -ne 1 -or
        @(
            $gatewayResponse.InternetGateways[0].Attachments |
                Where-Object {
                    $_.VpcId -eq $vpc.VpcId -and
                    $_.State -eq "available"
                }
        ).Count -ne 1
    ) {
        throw "O Internet Gateway não está associado à VPC esperada."
    }

    $aclResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-network-acls",
        "--filters",
        "Name=association.subnet-id,Values=$($subnet.SubnetId)"
    )

    if (@($aclResponse.NetworkAcls).Count -ne 1) {
        throw "Não foi possível identificar a Network ACL da sub-rede."
    }

    Write-Host "[OK] VPC: $($vpc.VpcId)"
    Write-Host "[OK] Sub-rede: $($subnet.SubnetId)"
    Write-Host "[OK] Rota pública: $($routeTable.RouteTableId)"
    Write-Host "[OK] Network ACL: $($aclResponse.NetworkAcls[0].NetworkAclId)"

    Write-Host ""
    Write-Host "=== Verificação de conflitos ===" -ForegroundColor Cyan

    $instancesResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped"
    )

    $existingInstances = @(
        $instancesResponse.Reservations |
            ForEach-Object { $_.Instances }
    )

    if ($existingInstances.Count -gt 0) {
        throw (
            "Já existe uma instância ativa com o nome $InstanceName. " +
            "Nenhuma instância adicional será criada."
        )
    }

    $groupsResponse = Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters",
        "Name=group-name,Values=$GroupName",
        "Name=vpc-id,Values=$($vpc.VpcId)"
    )

    if (@($groupsResponse.SecurityGroups).Count -gt 0) {
        throw (
            "Já existe o Security Group $GroupName. " +
            "Verifique os recursos antes de repetir a implantação."
        )
    }

    $roleNames = Invoke-Aws -Arguments @(
        "iam", "list-roles",
        "--query", "Roles[?RoleName=='$RoleName'].RoleName",
        "--output", "text"
    )

    if (-not [string]::IsNullOrWhiteSpace($roleNames)) {
        throw "A IAM Role $RoleName já existe."
    }

    $profileNames = Invoke-Aws -Arguments @(
        "iam", "list-instance-profiles",
        "--query",
        "InstanceProfiles[?InstanceProfileName=='$ProfileResourceName'].InstanceProfileName",
        "--output", "text"
    )

    if (-not [string]::IsNullOrWhiteSpace($profileNames)) {
        throw "O Instance Profile $ProfileResourceName já existe."
    }

    Write-Host "[OK] Nenhum recurso ativo com os nomes do Lab 16."

    Write-Host ""
    Write-Host "=== Imagem Amazon Linux 2023 ===" `
        -ForegroundColor Cyan

    $imageId = Invoke-Aws -Arguments @(
        "ssm", "get-parameter",
        "--name", $AmiParameter,
        "--query", "Parameter.Value",
        "--output", "text"
    )

    if ($imageId -notmatch "^ami-[a-zA-Z0-9]+$") {
        throw "Não foi possível descobrir a AMI Amazon Linux 2023."
    }

    Write-Host "[OK] AMI: $imageId"

    Write-Host ""
    Write-Host "=== IAM Role e Instance Profile ===" `
        -ForegroundColor Cyan

    $iamTags = Get-Ec2Tags -Name $RoleName

    $resolvedPolicyPath = (
        Resolve-Path -LiteralPath $policyPath
    ).Path

    $null = Invoke-Aws -Arguments (
        @(
            "iam", "create-role",
            "--role-name", $RoleName,
            "--assume-role-policy-document",
            "file://$resolvedPolicyPath",
            "--tags"
        ) + $iamTags
    )

    $null = Invoke-Aws -Arguments @(
        "iam", "attach-role-policy",
        "--role-name", $RoleName,
        "--policy-arn", $SsmPolicyArn
    )

    $profileTags = Get-Ec2Tags -Name $ProfileResourceName

    $null = Invoke-Aws -Arguments (
        @(
            "iam", "create-instance-profile",
            "--instance-profile-name", $ProfileResourceName,
            "--tags"
        ) + $profileTags
    )

    $null = Invoke-Aws -Arguments @(
        "iam", "add-role-to-instance-profile",
        "--instance-profile-name", $ProfileResourceName,
        "--role-name", $RoleName
    )

    Write-Host "[OK] IAM Role e Instance Profile criados."
    Start-Sleep -Seconds 15

    Write-Host ""
    Write-Host "=== Security Group ===" -ForegroundColor Cyan

    $groupId = Invoke-Aws -Arguments @(
        "ec2", "create-security-group",
        "--group-name", $GroupName,
        "--description", "Lab 16 controlled SSM connectivity",
        "--vpc-id", $vpc.VpcId,
        "--query", "GroupId",
        "--output", "text"
    )

    $null = Invoke-Aws -Arguments (
        @(
            "ec2", "create-tags",
            "--resources", $groupId,
            "--tags"
        ) + (Get-Ec2Tags -Name $GroupName)
    )

    # Um Security Group novo recebe saída IPv4 irrestrita por padrão.
    # Revogamos essa regra antes de associar o grupo à instância.
    $initialRules = Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules",
        "--filters", "Name=group-id,Values=$groupId"
    )
    $egress = @(
        $initialRules.SecurityGroupRules | Where-Object { $_.IsEgress }
    )
    $ingress = @(
        $initialRules.SecurityGroupRules | Where-Object { -not $_.IsEgress }
    )
    if ($ingress.Count -ne 0 -or $egress.Count -ne 1 -or
        $egress[0].IpProtocol -ne "-1" -or
        $egress[0].CidrIpv4 -ne "0.0.0.0/0") {
        throw "Regras iniciais inesperadas no Security Group $groupId."
    }
    $null = Invoke-Aws -Arguments @(
        "ec2", "revoke-security-group-egress",
        "--group-id", $groupId,
        "--security-group-rule-ids", $egress[0].SecurityGroupRuleId
    )

    $authorization = Get-AwsJson -Arguments @(
        "ec2", "authorize-security-group-egress",
        "--group-id", $groupId,
        "--protocol", "tcp",
        "--port", "443",
        "--cidr", "0.0.0.0/0"
    )
    $outboundRule = @($authorization.SecurityGroupRules)
    if ($outboundRule.Count -ne 1 -or
        [string]::IsNullOrWhiteSpace($outboundRule[0].SecurityGroupRuleId)) {
        throw "A AWS não retornou o ID da regra HTTPS criada."
    }

    $configuredRules = Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules",
        "--filters", "Name=group-id,Values=$groupId"
    )
    $allRules = @($configuredRules.SecurityGroupRules)
    if ($allRules.Count -ne 1 -or
        -not $allRules[0].IsEgress -or
        $allRules[0].IpProtocol -ne "tcp" -or
        $allRules[0].FromPort -ne 443 -or
        $allRules[0].ToPort -ne 443 -or
        $allRules[0].CidrIpv4 -ne "0.0.0.0/0") {
        throw "O Security Group não contém somente a saída HTTPS esperada."
    }

    Write-Host "[OK] Nenhuma entrada; saída TCP 443: $($allRules[0].SecurityGroupRuleId)"

    Write-Host ""
    Write-Host "=== Instância EC2 ===" -ForegroundColor Cyan

    $instanceResponse = Get-AwsJson -Arguments @(
        "ec2", "run-instances",
        "--image-id", $imageId,
        "--instance-type", $InstanceType,
        "--placement", "AvailabilityZone=$AvailabilityZone",
        "--subnet-id", $subnet.SubnetId,
        "--security-group-ids", $groupId,
        "--iam-instance-profile", "Name=$ProfileResourceName",
        "--associate-public-ip-address",
        "--metadata-options", "HttpTokens=required,HttpEndpoint=enabled",
        "--block-device-mappings",
        "DeviceName=/dev/xvda,Ebs={VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}",
        "--tag-specifications",
        (Get-TagSpecification -ResourceType "instance" -Name $InstanceName),
        (Get-TagSpecification -ResourceType "volume" -Name "$InstanceName-root")
    )
    $launched = @($instanceResponse.Instances)
    if ($launched.Count -ne 1 -or
        [string]::IsNullOrWhiteSpace($launched[0].InstanceId)) {
        throw "A AWS não retornou exatamente uma instância."
    }
    $instanceId = [string]$launched[0].InstanceId
    Write-Host "[OK] Instância solicitada: $instanceId"

    $null = Invoke-Aws -Arguments @(
        "ec2", "wait", "instance-running", "--instance-ids", $instanceId
    )
    $null = Invoke-Aws -Arguments @(
        "ec2", "wait", "instance-status-ok", "--instance-ids", $instanceId
    )
    $description = Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--instance-ids", $instanceId
    )
    $instances = @(
        $description.Reservations | ForEach-Object { $_.Instances }
    )
    if ($instances.Count -ne 1 -or
        -not $instances[0].PSObject.Properties["PublicIpAddress"] -or
        [string]::IsNullOrWhiteSpace($instances[0].PublicIpAddress)) {
        throw "A instância não recebeu IPv4 público."
    }
    if ($instances[0].MetadataOptions.HttpTokens -ne "required" -or
        ($instances[0].PSObject.Properties["KeyName"] -and
            -not [string]::IsNullOrWhiteSpace($instances[0].KeyName))) {
        throw "IMDSv2 ou ausência de Key Pair não confirmados."
    }
    Write-Host "[OK] IPv4 público: $($instances[0].PublicIpAddress)"

    Write-Host ""
    Write-Host "=== Systems Manager ===" -ForegroundColor Cyan
    $ssmOnline = $false
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        $ssmResponse = Get-AwsJson -Arguments @(
            "ssm", "describe-instance-information",
            "--filters", "Key=InstanceIds,Values=$instanceId"
        )
        $matches = @(
            $ssmResponse.InstanceInformationList | Where-Object {
                $_.InstanceId -eq $instanceId -and
                $_.PingStatus -eq "Online"
            }
        )
        if ($matches.Count -eq 1) {
            $ssmOnline = $true
            break
        }
        Start-Sleep -Seconds 10
    }
    if (-not $ssmOnline) {
        throw "A instância não ficou Online no Systems Manager."
    }
    Write-Host "[OK] Systems Manager: Online"
    Write-Host ""
    Write-Host "IMPLANTAÇÃO CONCLUÍDA" -ForegroundColor Green
    Write-Host "VPC:            $($vpc.VpcId)"
    Write-Host "Sub-rede:       $($subnet.SubnetId)"
    Write-Host "Security Group: $groupId"
    Write-Host "Saída HTTPS:    $($allRules[0].SecurityGroupRuleId)"
    Write-Host "Instância:      $instanceId"
}
catch {
    Write-Host ""
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Se algum recurso foi criado, registre os IDs e verifique o estado antes de repetir o deploy." -ForegroundColor Yellow
    exit 1
}
