[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1",
    [string]$AvailabilityZone = "us-east-1a",
    [string]$InstanceType = "t3.micro",

    [Parameter(Mandatory = $true)]
    [string]$AllowedHttpCidr
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VpcName = "lab08-application-vpc"
$SubnetName = "lab08-public-subnet-a"

$InstanceName = "lab17-controlled-update-instance"
$GroupName = "lab17-controlled-update-sg"
$RoleName = "lab17-ec2-controlled-update-role"
$ProfileResourceName = "lab17-ec2-controlled-update-instance-profile"

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

function Get-HttpBody {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $previousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $lines = @(
            & curl.exe --noproxy "*" --fail --silent `
                --show-error --max-time 8 $Url 2>&1
        )
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0) {
        throw "Falha HTTP em ${Url}: $($lines -join ' ')"
    }

    return (($lines | ForEach-Object { $_.ToString() }) -join "`n").Trim()
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
        "Key=Lab,Value=17",
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
    Write-Host "=== Lab 17: pré-requisitos ===" -ForegroundColor Cyan

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }

    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        throw "curl.exe não encontrado."
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

    $cidrParts = $AllowedHttpCidr -split "/"

    if ($cidrParts.Count -ne 2 -or $cidrParts[1] -ne "32") {
        throw "Informe um único endereço IPv4 com máscara /32."
    }

    $parsedIp = $null

    if (
        -not [System.Net.IPAddress]::TryParse(
            $cidrParts[0],
            [ref]$parsedIp
        ) -or
        $parsedIp.AddressFamily -ne
            [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {
        throw "AllowedHttpCidr deve conter um endereço IPv4 válido."
    }

    $ipBytes = $parsedIp.GetAddressBytes()

    if (
        $ipBytes[0] -eq 0 -or
        $ipBytes[0] -eq 10 -or
        $ipBytes[0] -eq 127 -or
        $ipBytes[0] -ge 224 -or
        ($ipBytes[0] -eq 169 -and $ipBytes[1] -eq 254) -or
        ($ipBytes[0] -eq 172 -and $ipBytes[1] -ge 16 -and
            $ipBytes[1] -le 31) -or
        ($ipBytes[0] -eq 192 -and $ipBytes[1] -eq 168)
    ) {
        throw "Informe um endereço IPv4 público válido."
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

    if ($identity.Account -ne "412381774441") {
        throw "Conta AWS inesperada: $($identity.Account)."
    }

    Write-Host "[OK] Conta AWS: $($identity.Account)"
    Write-Host "[OK] Origem HTTP: $AllowedHttpCidr"

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
                    (
                        $_.PSObject.Properties["SubnetId"] -and
                        $_.SubnetId -eq $subnet.SubnetId
                    )
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
                        (
                            $_.PSObject.Properties["Main"] -and
                            $_.Main -eq $true
                        )
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

    Write-Host "[OK] Nenhum recurso ativo com os nomes do Lab 17."

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
        "--description", "Lab 17 controlled application update",
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

    $null = Invoke-Aws -Arguments @(
        "ec2", "authorize-security-group-ingress",
        "--group-id", $groupId,
        "--protocol", "tcp",
        "--port", "80",
        "--cidr", $AllowedHttpCidr
    )

    Write-Host "[OK] HTTP TCP 80 autorizado somente para $AllowedHttpCidr."
    Write-Host "[OK] Nenhuma regra SSH foi criada."

    Write-Host ""
    Write-Host "=== Instância EC2 e Nginx ===" -ForegroundColor Cyan

    $userData = @'
#!/bin/bash
set -euo pipefail

dnf install -y nginx

cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Lab 17 - Controlled Update</title>
</head>
<body>
  <h1>Cloud Infrastructure Operations Lab</h1>
  <p>Lab 17 - Controlled Update</p>
  <p>Status: healthy</p>
</body>
</html>
HTML

printf 'healthy\n' > /usr/share/nginx/html/health
printf 'v1\n' > /usr/share/nginx/html/version

cat > /etc/nginx/conf.d/lab17-release.conf <<'CONF'
map $request_method $lab17_release {
    default "v1";
}
CONF

nginx -t
systemctl enable --now nginx
'@

    # UTF-8 sem BOM preserva o script Linux enviado como user data.
    $userDataPath = Join-Path `
        ([IO.Path]::GetTempPath()) `
        ("lab17-user-data-{0}.sh" -f [guid]::NewGuid().ToString("N"))

    try {
        [IO.File]::WriteAllText(
            $userDataPath,
            $userData,
            (New-Object System.Text.UTF8Encoding($false))
        )

        $userDataUri = "file://$($userDataPath.Replace('\', '/'))"

        $instanceResponse = Get-AwsJson -Arguments @(
            "ec2", "run-instances",
            "--image-id", $imageId,
            "--instance-type", $InstanceType,
            "--subnet-id", $subnet.SubnetId,
            "--security-group-ids", $groupId,
            "--iam-instance-profile", "Name=$ProfileResourceName",
            "--metadata-options",
            "HttpTokens=required,HttpEndpoint=enabled",
            "--block-device-mappings",
            "DeviceName=/dev/xvda,Ebs={VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}",
            "--user-data", $userDataUri,
            "--tag-specifications",
            (Get-TagSpecification `
                -ResourceType "instance" `
                -Name $InstanceName),
            (Get-TagSpecification `
                -ResourceType "volume" `
                -Name "$InstanceName-root")
        )
    }
    finally {
        if (Test-Path -LiteralPath $userDataPath -PathType Leaf) {
            Remove-Item -LiteralPath $userDataPath -Force
        }
    }

    $instanceId = @($instanceResponse.Instances)[0].InstanceId

    if ([string]::IsNullOrWhiteSpace($instanceId)) {
        throw "A AWS CLI não retornou o ID da instância."
    }

    Write-Host "[OK] Instância solicitada: $instanceId"

    $null = Invoke-Aws -Arguments @(
        "ec2", "wait", "instance-running",
        "--instance-ids", $instanceId
    )

    $null = Invoke-Aws -Arguments @(
        "ec2", "wait", "instance-status-ok",
        "--instance-ids", $instanceId
    )

    $description = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--instance-ids", $instanceId
    )

    $instance = @(
        $description.Reservations |
            ForEach-Object { $_.Instances }
    )[0]

    $publicIp = $instance.PublicIpAddress

    if ([string]::IsNullOrWhiteSpace($publicIp)) {
        throw "A instância não recebeu endereço IPv4 público."
    }

    Write-Host ""
    Write-Host "=== Systems Manager ===" -ForegroundColor Cyan

    $ssmOnline = $false

    for ($attempt = 1; $attempt -le 30; $attempt++) {
        $ssmResponse = Get-AwsJson -Arguments @(
            "ssm", "describe-instance-information",
            "--filters",
            "Key=InstanceIds,Values=$instanceId"
        )

        $onlineInstances = @(
            $ssmResponse.InstanceInformationList |
                Where-Object {
                    $_.InstanceId -eq $instanceId -and
                    $_.PingStatus -eq "Online"
                }
        )

        if ($onlineInstances.Count -eq 1) {
            $ssmOnline = $true
            break
        }

        Start-Sleep -Seconds 10
    }

    if (-not $ssmOnline) {
        throw "A instância não ficou Online no Systems Manager."
    }

    Write-Host "[OK] Instância Online no Systems Manager."

    Write-Host ""
    Write-Host "=== Validação HTTP externa ===" -ForegroundColor Cyan

    $httpHealthy = $false

    for ($attempt = 1; $attempt -le 24; $attempt++) {
        try {
            $health = Get-HttpBody -Url "http://$publicIp/health"

            if ($health -eq "healthy") {
                $httpHealthy = $true
                break
            }
        }
        catch {
            # Aguarda o user data e a inicialização do Nginx.
        }

        Start-Sleep -Seconds 10
    }

    if (-not $httpHealthy) {
        throw "O endpoint HTTP /health não respondeu como esperado."
    }

    $page = Get-HttpBody -Url "http://$publicIp/"

    if ($page -notmatch "Lab 17 - Controlled Update") {
        throw "A página principal retornou uma resposta inesperada."
    }

    Write-Host "[OK] Página principal: HTTP 200."
    Write-Host "[OK] Endpoint /health: healthy."

    $version = Get-HttpBody -Url "http://$publicIp/version"

    if ($version -ne "v1") {
        throw "A versão inicial /version não retornou v1."
    }

    Write-Host "[OK] Versão inicial: v1."

    Write-Host ""
    Write-Host "IMPLANTAÇÃO CONCLUÍDA" -ForegroundColor Green
    Write-Host "VPC:             $($vpc.VpcId)"
    Write-Host "Sub-rede:        $($subnet.SubnetId)"
    Write-Host "Security Group:  $groupId"
    Write-Host "Instância:       $instanceId"
    Write-Host "IPv4 público:    $publicIp"
    Write-Host "URL:             http://$publicIp/"
    Write-Host "Origem HTTP:     $AllowedHttpCidr"
    Write-Host "Versão inicial:  v1"
}
catch {
    Write-Host ""
    Write-Host "[FALHA] $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host (
        "Se algum recurso foi criado, registre os IDs exibidos e " +
        "não repita o deploy antes de verificar o estado do Lab 17."
    ) -ForegroundColor Yellow

    exit 1
}
