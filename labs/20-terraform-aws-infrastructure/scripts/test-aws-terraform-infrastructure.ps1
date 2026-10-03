#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProfileName = "cloud-operations-lab",

    [ValidateSet("us-east-1")]
    [string]$Region = "us-east-1",

    [ValidatePattern('^[0-9]{12}$')]
    [string]$ExpectedAccountId = "412381774441",

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AllowedHttpCidr,

    [ValidateRange(60, 1800)]
    [int]$WaitTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"

function Invoke-NativeText {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $Lines = @(& $Command @Arguments 2>&1)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    $Text = ($Lines | ForEach-Object { $_.ToString() }) -join "`n"

    if ($ExitCode -ne 0) {
        throw "$Command falhou, codigo ${ExitCode}:`n$Text"
    }

    return $Text
}

function Get-AwsJson {
    param([string[]]$Arguments)

    $CliArguments = @($Arguments) + @(
        "--profile", $ProfileName,
        "--region", $Region,
        "--no-cli-pager",
        "--output", "json"
    )

    $Text = Invoke-NativeText -Command "aws" `
        -Arguments $CliArguments

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw "Resposta JSON vazia da AWS CLI."
    }

    return ($Text | ConvertFrom-Json)
}

function Get-TerraformText {
    param([string[]]$Arguments)

    return (Invoke-NativeText -Command "terraform" -Arguments (
        @("-chdir=$TerraformPath") + $Arguments
    ))
}

function Assert-Tags {
    param(
        $Resource,
        [string]$ExpectedName,
        [string]$LabNumber = "20"
    )

    $ExpectedTags = @{
        Name    = $ExpectedName
        Project = "cloud-infrastructure-operations-lab"
        Lab     = $LabNumber
    }

    if ($LabNumber -eq "20") {
        $ExpectedTags.Environment = "lab"
        $ExpectedTags.ManagedBy = "terraform"
        $ExpectedTags.Owner = "itamarsb"
    }

    foreach ($Key in $ExpectedTags.Keys) {
        $Matches = @(
            $Resource.Tags | Where-Object {
                $_.Key -eq $Key -and
                $_.Value -eq $ExpectedTags[$Key]
            }
        )

        if ($Matches.Count -ne 1) {
            throw "Tag inesperada em ${ExpectedName}: $Key."
        }
    }
}

function Get-HttpBody {
    param([string]$Url)

    $Text = Invoke-NativeText -Command "curl.exe" -Arguments @(
        "--noproxy", "*",
        "--fail",
        "--silent",
        "--show-error",
        "--connect-timeout", "10",
        "--max-time", "20",
        "--write-out", "\n__LAB20_HTTP_STATUS__%{http_code}",
        $Url
    )

    if ($Text -notmatch '(?s)^(.*)\r?\n__LAB20_HTTP_STATUS__200$') {
        throw "Resposta HTTP inesperada em $Url."
    }

    $Body = $Matches[1].Trim()
    Write-Host "[OK] ${Url}: HTTP 200."
    return $Body
}

$PreviousPythonEncoding = $env:PYTHONIOENCODING
$ParameterPath = $null
$CommandId = $null

try {
    $env:PYTHONIOENCODING = "utf-8"

    foreach ($Command in @("aws", "terraform", "curl.exe")) {
        Get-Command $Command -ErrorAction Stop | Out-Null
    }

    if ($ProfileName -ne $ProfileName.Trim()) {
        throw "O perfil AWS contem espacos nas extremidades."
    }

    $TerraformPath = (
        Resolve-Path (Join-Path $PSScriptRoot "..\terraform")
    ).Path

    Write-Host "=== Identidade e estado Terraform ==="

    $Identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ($Identity.Account -ne $ExpectedAccountId) {
        throw "Conta AWS inesperada: $($Identity.Account)."
    }

    $Workspace = (
        Get-TerraformText -Arguments @("workspace", "show")
    ).Trim()

    if ($Workspace -ne "default") {
        throw "Workspace inesperado: $Workspace."
    }

    $State = (
        Get-TerraformText -Arguments @("show", "-json")
    ) | ConvertFrom-Json

    if ($null -eq $State.values.root_module) {
        throw "Estado Terraform sem recursos provisionados."
    }

    if ($null -ne $State.values.root_module.child_modules -and
        @($State.values.root_module.child_modules).Count -gt 0) {
        throw "Modulos adicionais encontrados no estado."
    }

    $ManagedResources = @(
        $State.values.root_module.resources |
            Where-Object { $_.mode -eq "managed" }
    )

    $ExpectedAddresses = @(
        "aws_iam_role.ec2",
        "aws_iam_role_policy_attachment.ssm",
        "aws_iam_instance_profile.ec2",
        "aws_security_group.application",
        "aws_vpc_security_group_ingress_rule.http",
        "aws_vpc_security_group_egress_rule.https",
        "aws_instance.application"
    )

    if ($ManagedResources.Count -ne $ExpectedAddresses.Count) {
        throw "Quantidade inesperada de recursos gerenciados no estado."
    }

    $ResourceValues = @{}

    foreach ($Address in $ExpectedAddresses) {
        $Matches = @(
            $ManagedResources |
                Where-Object { $_.address -eq $Address }
        )

        if ($Matches.Count -ne 1 -or
            $Matches[0].provider_name -ne
                "registry.terraform.io/hashicorp/aws") {
            throw "Recurso ausente ou inesperado: $Address."
        }

        $ResourceValues[$Address] = $Matches[0].values
    }

    $OutputValues = @{}
    $ExpectedOutputs = @(
        "account_id",
        "aws_region",
        "shared_vpc_id",
        "shared_subnet_id",
        "ami_id",
        "instance_id",
        "instance_public_ip",
        "root_volume_id",
        "security_group_id",
        "iam_role_name",
        "instance_profile_name",
        "allowed_http_cidr",
        "application_url",
        "health_url",
        "version_url"
    )

    foreach ($Name in $ExpectedOutputs) {
        $Property = $State.values.outputs.PSObject.Properties[$Name]

        if ($null -eq $Property -or
            [string]::IsNullOrWhiteSpace(
                [string]$Property.Value.value
            )) {
            throw "Output ausente ou vazio: $Name."
        }

        $OutputValues[$Name] = [string]$Property.Value.value
    }

    if ($OutputValues.account_id -ne $ExpectedAccountId -or
        $OutputValues.aws_region -ne $Region -or
        $OutputValues.allowed_http_cidr -ne $AllowedHttpCidr) {
        throw "Conta, regiao ou origem HTTP divergente dos outputs."
    }

    $InstanceState = $ResourceValues["aws_instance.application"]
    $GroupState = $ResourceValues["aws_security_group.application"]
    $RoleState = $ResourceValues["aws_iam_role.ec2"]
    $ProfileState = $ResourceValues["aws_iam_instance_profile.ec2"]
    $PolicyState = $ResourceValues["aws_iam_role_policy_attachment.ssm"]

    if ($InstanceState.id -ne $OutputValues.instance_id -or
        $InstanceState.ami -ne $OutputValues.ami_id -or
        $InstanceState.subnet_id -ne $OutputValues.shared_subnet_id -or
        $InstanceState.public_ip -ne $OutputValues.instance_public_ip -or
        $InstanceState.root_block_device[0].volume_id -ne
            $OutputValues.root_volume_id -or
        $GroupState.id -ne $OutputValues.security_group_id -or
        $GroupState.vpc_id -ne $OutputValues.shared_vpc_id -or
        $RoleState.name -ne $OutputValues.iam_role_name -or
        $ProfileState.name -ne $OutputValues.instance_profile_name -or
        $ProfileState.role -ne $RoleState.name -or
        $PolicyState.role -ne $RoleState.name -or
        $PolicyState.policy_arn -ne
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore") {
        throw "Outputs ou relacionamentos divergentes do estado."
    }

    if ($RoleState.name -ne "lab20-ec2-terraform-role" -or
        $ProfileState.name -ne "lab20-ec2-terraform-instance-profile") {
        throw "Nomes IAM diferentes dos recursos exclusivos esperados."
    }

    $InstanceId = $OutputValues.instance_id
    $GroupId = $OutputValues.security_group_id
    $PublicIp = $OutputValues.instance_public_ip

    $ParsedIp = $null
    if (-not [Net.IPAddress]::TryParse(
            $PublicIp, [ref]$ParsedIp
        ) -or
        $ParsedIp.AddressFamily -ne
            [Net.Sockets.AddressFamily]::InterNetwork) {
        throw "IPv4 publico da instancia invalido."
    }

    $BaseUrl = "http://$PublicIp"

    if ($OutputValues.application_url -ne "$BaseUrl/" -or
        $OutputValues.health_url -ne "$BaseUrl/health" -or
        $OutputValues.version_url -ne "$BaseUrl/version") {
        throw "URLs dos outputs divergentes do IPv4 da instancia."
    }

    $CurrentIp = (
        Invoke-NativeText -Command "curl.exe" -Arguments @(
            "--noproxy", "*", "-fsS",
            "--connect-timeout", "10",
            "--max-time", "20",
            "https://checkip.amazonaws.com"
        )
    ).Trim()

    if ("$CurrentIp/32" -ne $AllowedHttpCidr) {
        throw "O IPv4 publico atual nao corresponde a origem autorizada."
    }

    Write-Host "[OK] Conta: $ExpectedAccountId; regiao: $Region."
    Write-Host "[OK] Workspace default; sete recursos gerenciados."
    Write-Host "[OK] Outputs e origem HTTP conferidos."

    Write-Host "=== EC2 e volume root ==="

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--instance-ids", $InstanceId
    )

    $Instances = @(
        $Response.Reservations | ForEach-Object {
            $_.Instances
        }
    )

    if ($Instances.Count -ne 1) {
        throw "Instancia ausente ou resposta ambigua."
    }

    $Instance = $Instances[0]

    Assert-Tags -Resource $Instance `
        -ExpectedName "lab20-terraform-application-instance"

    if ($Instance.State.Name -ne "running" -or
        $Instance.InstanceType -ne "t3.micro" -or
        $Instance.ImageId -ne $OutputValues.ami_id -or
        $Instance.VpcId -ne $OutputValues.shared_vpc_id -or
        $Instance.SubnetId -ne $OutputValues.shared_subnet_id -or
        $Instance.PublicIpAddress -ne $PublicIp -or
        @($Instance.SecurityGroups).Count -ne 1 -or
        $Instance.SecurityGroups[0].GroupId -ne $GroupId -or
        -not [string]::IsNullOrWhiteSpace($Instance.KeyName)) {
        throw "Estado, rede, AMI, tipo ou acesso da EC2 inesperado."
    }

    if ($Instance.MetadataOptions.State -ne "applied" -or
        $Instance.MetadataOptions.HttpTokens -ne "required" -or
        $Instance.MetadataOptions.HttpEndpoint -ne "enabled" -or
        $Instance.MetadataOptions.HttpPutResponseHopLimit -ne 1 -or
        $Instance.MetadataOptions.InstanceMetadataTags -ne "disabled") {
        throw "Configuracao IMDSv2 inesperada."
    }

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-instance-credit-specifications",
        "--instance-ids", $InstanceId
    )

    if (@($Response.InstanceCreditSpecifications).Count -ne 1 -or
        $Response.InstanceCreditSpecifications[0].CpuCredits -ne
            "standard") {
        throw "Creditos de CPU fora do modo standard."
    }

    $RootMappings = @(
        $Instance.BlockDeviceMappings | Where-Object {
            $_.DeviceName -eq $Instance.RootDeviceName
        }
    )

    if ($RootMappings.Count -ne 1 -or
        $RootMappings[0].Ebs.VolumeId -ne $OutputValues.root_volume_id -or
        $RootMappings[0].Ebs.DeleteOnTermination -ne $true) {
        throw "Mapeamento ou remocao automatica do volume root inesperado."
    }

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-volumes",
        "--volume-ids", $OutputValues.root_volume_id
    )

    if (@($Response.Volumes).Count -ne 1) {
        throw "Volume root ausente ou resposta ambigua."
    }

    $Volume = $Response.Volumes[0]

    Assert-Tags -Resource $Volume `
        -ExpectedName "lab20-terraform-application-root"

    if ($Volume.Encrypted -ne $true -or
        $Volume.VolumeType -ne "gp3" -or
        $Volume.Size -ne 8 -or
        $Volume.State -ne "in-use" -or
        @($Volume.Attachments).Count -ne 1 -or
        $Volume.Attachments[0].InstanceId -ne $InstanceId -or
        $Volume.Attachments[0].State -ne "attached") {
        throw "Criptografia, tamanho ou associacao do volume inesperada."
    }

    Write-Host "[OK] EC2: $InstanceId; IPv4: $PublicIp."
    Write-Host "[OK] IMDSv2 obrigatorio; CPU standard; volume gp3 criptografado."

    Write-Host "=== Rede compartilhada e Security Group ==="

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--vpc-ids", $OutputValues.shared_vpc_id
    )

    if (@($Response.Vpcs).Count -ne 1 -or
        $Response.Vpcs[0].OwnerId -ne $ExpectedAccountId -or
        $Response.Vpcs[0].State -ne "available") {
        throw "VPC compartilhada indisponivel ou fora da conta."
    }

    Assert-Tags -Resource $Response.Vpcs[0] `
        -ExpectedName "lab08-application-vpc" -LabNumber "08"

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--subnet-ids", $OutputValues.shared_subnet_id
    )

    if (@($Response.Subnets).Count -ne 1 -or
        $Response.Subnets[0].OwnerId -ne $ExpectedAccountId -or
        $Response.Subnets[0].VpcId -ne $OutputValues.shared_vpc_id -or
        $Response.Subnets[0].State -ne "available" -or
        $Response.Subnets[0].AvailabilityZone -ne "us-east-1a") {
        throw "Sub-rede compartilhada inesperada."
    }

    Assert-Tags -Resource $Response.Subnets[0] `
        -ExpectedName "lab08-public-subnet-a" -LabNumber "08"

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--group-ids", $GroupId
    )

    if (@($Response.SecurityGroups).Count -ne 1 -or
        $Response.SecurityGroups[0].VpcId -ne $OutputValues.shared_vpc_id -or
        $Response.SecurityGroups[0].OwnerId -ne $ExpectedAccountId -or
        $Response.SecurityGroups[0].GroupName -ne
            "lab20-terraform-application-sg") {
        throw "Security Group inesperado."
    }

    Assert-Tags -Resource $Response.SecurityGroups[0] `
        -ExpectedName "lab20-terraform-application-sg"

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules",
        "--filters", "Name=group-id,Values=$GroupId"
    )

    $Rules = @($Response.SecurityGroupRules)
    $Ingress = @($Rules | Where-Object { $_.IsEgress -eq $false })
    $Egress = @($Rules | Where-Object { $_.IsEgress -eq $true })

    if ($Rules.Count -ne 2 -or
        $Ingress.Count -ne 1 -or
        $Egress.Count -ne 1) {
        throw "Quantidade inesperada de regras no Security Group."
    }

    if ($Ingress[0].IpProtocol -ne "tcp" -or
        $Ingress[0].FromPort -ne 80 -or
        $Ingress[0].ToPort -ne 80 -or
        $Ingress[0].CidrIpv4 -ne $AllowedHttpCidr -or
        $Egress[0].IpProtocol -ne "tcp" -or
        $Egress[0].FromPort -ne 443 -or
        $Egress[0].ToPort -ne 443 -or
        $Egress[0].CidrIpv4 -ne "0.0.0.0/0") {
        throw "Regras HTTP ou HTTPS divergentes da configuracao."
    }

    if ($Ingress[0].SecurityGroupRuleId -ne
            $ResourceValues["aws_vpc_security_group_ingress_rule.http"].id -or
        $Egress[0].SecurityGroupRuleId -ne
            $ResourceValues["aws_vpc_security_group_egress_rule.https"].id) {
        throw "Identificadores das regras divergentes do estado."
    }

    Assert-Tags -Resource $Ingress[0] `
        -ExpectedName "lab20-http-ingress"

    Assert-Tags -Resource $Egress[0] `
        -ExpectedName "lab20-https-egress"

    Write-Host "[OK] VPC e sub-rede compartilhadas conferidas."
    Write-Host "[OK] HTTP /32; saida HTTPS; nenhuma entrada SSH."

    Write-Host "=== IAM ==="

    $Response = Get-AwsJson -Arguments @(
        "iam", "get-instance-profile",
        "--instance-profile-name", $OutputValues.instance_profile_name
    )

    $Profile = $Response.InstanceProfile

    Assert-Tags -Resource $Profile `
        -ExpectedName "lab20-ec2-terraform-instance-profile"

    if (@($Profile.Roles).Count -ne 1 -or
        $Profile.Roles[0].RoleName -ne $OutputValues.iam_role_name -or
        $Instance.IamInstanceProfile.Arn -ne $Profile.Arn) {
        throw "Instance Profile ou associacao com a EC2 inesperada."
    }

    $Response = Get-AwsJson -Arguments @(
        "iam", "get-role",
        "--role-name", $OutputValues.iam_role_name
    )

    $Role = $Response.Role

    Assert-Tags -Resource $Role `
        -ExpectedName "lab20-ec2-terraform-role"

    $Trust = $Role.AssumeRolePolicyDocument

    if ($Trust -is [string]) {
        $Trust = [Uri]::UnescapeDataString($Trust) | ConvertFrom-Json
    }

    $Statements = @($Trust.Statement)

    if ($Statements.Count -ne 1 -or
        $Statements[0].Effect -ne "Allow" -or
        @($Statements[0].Action).Count -ne 1 -or
        [string]$Statements[0].Action -ne "sts:AssumeRole" -or
        @($Statements[0].Principal.Service).Count -ne 1 -or
        [string]$Statements[0].Principal.Service -ne "ec2.amazonaws.com" -or
        @($Statements[0].Principal.PSObject.Properties).Count -ne 1) {
        throw "Politica de confianca da role inesperada."
    }

    $Response = Get-AwsJson -Arguments @(
        "iam", "list-attached-role-policies",
        "--role-name", $OutputValues.iam_role_name
    )

    if (@($Response.AttachedPolicies).Count -ne 1 -or
        $Response.AttachedPolicies[0].PolicyArn -ne
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore") {
        throw "Politicas associadas a role inesperadas."
    }

    $Response = Get-AwsJson -Arguments @(
        "iam", "list-role-policies",
        "--role-name", $OutputValues.iam_role_name
    )

    if (@($Response.PolicyNames).Count -ne 0) {
        throw "Politicas inline inesperadas na role."
    }

    Write-Host "[OK] Role, confianca EC2, politica SSM e Instance Profile."

    Write-Host "=== Systems Manager e aplicacao local ==="

    $Deadline = [DateTime]::UtcNow.AddSeconds($WaitTimeoutSeconds)

    do {
        $Response = Get-AwsJson -Arguments @(
            "ssm", "describe-instance-information",
            "--filters", "Key=InstanceIds,Values=$InstanceId"
        )

        $Online = @(
            $Response.InstanceInformationList | Where-Object {
                $_.InstanceId -eq $InstanceId -and
                $_.PingStatus -eq "Online"
            }
        )

        if ($Online.Count -eq 1) {
            break
        }

        if ([DateTime]::UtcNow -ge $Deadline) {
            throw "Tempo esgotado aguardando SSM Online."
        }

        Start-Sleep -Seconds 10
    } while ($true)

    $RemoteScript = @'
#!/bin/bash
set -Eeuo pipefail

echo "=== CLOUD-INIT ==="
cloud-init status --wait

echo "=== MARCADOR ==="
test "$(cat /var/lib/lab20/bootstrap-complete)" = "v1"

echo "=== NGINX ==="
systemctl is-active --quiet nginx
systemctl is-enabled --quiet nginx
nginx -t

echo "=== HTTP LOCAL ==="
for endpoint in / /health /version; do
    code=$(curl --noproxy "*" --silent --show-error \
        --connect-timeout 5 --max-time 10 \
        --output /dev/null --write-out '%{http_code}' \
        "http://127.0.0.1$endpoint")
    test "$code" = "200"
    printf 'LOCAL_HTTP=%s:%s\n' "$endpoint" "$code"
done

page=$(curl --noproxy "*" -fsS --max-time 10 http://127.0.0.1/)
health=$(curl --noproxy "*" -fsS --max-time 10 http://127.0.0.1/health)
version=$(curl --noproxy "*" -fsS --max-time 10 http://127.0.0.1/version)

grep -Fq "LAB 20 - Infraestrutura AWS como codigo" <<< "$page"
grep -Fq "cloud-infrastructure-operations-lab" <<< "$page"
test "$health" = "healthy"
test "$version" = "v1"

echo "=== HASHES OBSERVADOS ==="
sha256sum \
    /usr/share/nginx/html/index.html \
    /usr/share/nginx/html/health \
    /usr/share/nginx/html/version \
    /etc/nginx/conf.d/lab20-app.conf

echo "APPLICATION_VALIDATED=v1"
'@

    $RemoteScript = $RemoteScript.Replace("`r`n", "`n")

    $ParameterPath = Join-Path ([IO.Path]::GetTempPath()) (
        "lab20-test-" + [Guid]::NewGuid().ToString("N") + ".json"
    )

    $Parameters = @{
        commands         = @($RemoteScript)
        executionTimeout = @("600")
    } | ConvertTo-Json -Depth 5

    [IO.File]::WriteAllText(
        $ParameterPath,
        $Parameters,
        [Text.UTF8Encoding]::new($false)
    )

    $ParameterUri = "file://" + $ParameterPath.Replace("\", "/")

    $CommandId = [string](Get-AwsJson -Arguments @(
        "ssm", "send-command",
        "--instance-ids", $InstanceId,
        "--document-name", "AWS-RunShellScript",
        "--comment", "Lab 20 read-only infrastructure validation",
        "--parameters", $ParameterUri,
        "--timeout-seconds", "120",
        "--query", "Command.CommandId"
    ))

    if ($CommandId -notmatch '^[0-9a-f-]{36}$') {
        throw "CommandId de validacao invalido."
    }

    Write-Host "CommandId da validacao: $CommandId"

    $Deadline = [DateTime]::UtcNow.AddSeconds($WaitTimeoutSeconds)

    do {
        $Invocation = $null

        try {
            $Invocation = Get-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $CommandId,
                "--instance-id", $InstanceId
            )
        }
        catch {
            if ($_.Exception.Message -notmatch "InvocationDoesNotExist") {
                throw
            }
        }

        if ($null -ne $Invocation) {
            if ($Invocation.Status -eq "Success") {
                break
            }

            if ($Invocation.Status -notin @(
                "Pending", "InProgress", "Delayed"
            )) {
                Write-Host $Invocation.StandardOutputContent
                Write-Host $Invocation.StandardErrorContent
                throw "Validacao SSM terminou com status $($Invocation.Status)."
            }
        }

        if ([DateTime]::UtcNow -ge $Deadline) {
            throw "Tempo esgotado aguardando o comando SSM."
        }

        Start-Sleep -Seconds 5
    } while ($true)

    Write-Host $Invocation.StandardOutputContent

    if (-not [string]::IsNullOrWhiteSpace(
            $Invocation.StandardErrorContent
        )) {
        Write-Host $Invocation.StandardErrorContent
    }

    if ($Invocation.ResponseCode -ne 0 -or
        $Invocation.StandardOutputContent -notmatch
            '(?m)^APPLICATION_VALIDATED=v1\r?$') {
        throw "Resultado da validacao local incompleto."
    }

    Write-Host "[OK] SSM Online; inicializacao concluida; Nginx validado."

    Write-Host "=== HTTP externo ==="

    $Page = Get-HttpBody -Url "$BaseUrl/"
    $Health = Get-HttpBody -Url "$BaseUrl/health"
    $Version = Get-HttpBody -Url "$BaseUrl/version"

    if ($Page -notlike "*LAB 20 - Infraestrutura AWS como codigo*" -or
        $Page -notlike "*cloud-infrastructure-operations-lab*" -or
        $Health -ne "healthy" -or
        $Version -ne "v1") {
        throw "Conteudo HTTP externo inesperado."
    }

    Write-Host "[OK] Pagina do LAB 20; health healthy; versao v1."
    Write-Host "VALIDACAO CONCLUIDA: infraestrutura e aplicacao."
    exit 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red

    if (-not [string]::IsNullOrWhiteSpace($CommandId)) {
        Write-Host "CommandId para diagnostico: $CommandId"
    }

    exit 1
}
finally {
    if ($null -ne $ParameterPath -and
        (Test-Path -LiteralPath $ParameterPath)) {
        Remove-Item -LiteralPath $ParameterPath -Force `
            -ErrorAction SilentlyContinue
    }

    $env:PYTHONIOENCODING = $PreviousPythonEncoding
}
