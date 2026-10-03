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

    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Get-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $CliArguments = @($Arguments) + @(
        "--profile", $ProfileName,
        "--region", $Region,
        "--no-cli-pager",
        "--output", "json"
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $Lines = @(& aws @CliArguments 2>&1)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    $Text = ($Lines | ForEach-Object { $_.ToString() }) -join "`n"

    if ($ExitCode -ne 0) {
        throw "AWS CLI falhou: $($Arguments -join ' ')`n$Text"
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw "Resposta JSON vazia: $($Arguments -join ' ')"
    }

    return ($Text | ConvertFrom-Json)
}

function Assert-SharedTags {
    param(
        [Parameter(Mandatory = $true)]
        $Resource,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedName
    )

    $ExpectedTags = @{
        Name    = $ExpectedName
        Project = "cloud-infrastructure-operations-lab"
        Lab     = "08"
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

$PreviousPythonEncoding = $env:PYTHONIOENCODING

try {
    $env:PYTHONIOENCODING = "utf-8"

    Get-Command aws -ErrorAction Stop | Out-Null
    Get-Command curl.exe -ErrorAction Stop | Out-Null

    if ($ProfileName -ne $ProfileName.Trim()) {
        throw "O perfil AWS contem espacos nas extremidades."
    }

    Write-Host "=== LAB 20: identidade e origem HTTP ==="

    $Identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ($Identity.Account -ne $ExpectedAccountId) {
        throw "Conta AWS inesperada: $($Identity.Account)."
    }

    if ($AllowedHttpCidr -notmatch '^([^/]+)/32$') {
        throw "Informe um IPv4 com mascara /32."
    }

    $AllowedIp = $Matches[1]
    $ParsedIp = $null

    if (-not [Net.IPAddress]::TryParse(
            $AllowedIp, [ref]$ParsedIp
        ) -or
        $ParsedIp.AddressFamily -ne
            [Net.Sockets.AddressFamily]::InterNetwork -or
        $ParsedIp.ToString() -ne $AllowedIp) {
        throw "Origem HTTP invalida: $AllowedHttpCidr."
    }

    $IpLines = @(
        & curl.exe --noproxy "*" -fsS `
            --connect-timeout 10 --max-time 20 `
            https://checkip.amazonaws.com
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Nao foi possivel consultar o IPv4 publico atual."
    }

    $CurrentIp = ($IpLines -join "").Trim()

    if ($CurrentIp -ne $AllowedIp) {
        throw "IPv4 atual: $CurrentIp; origem informada: $AllowedHttpCidr."
    }

    Write-Host "[OK] Conta: $($Identity.Account); regiao: $Region."
    Write-Host "[OK] Origem HTTP: $AllowedHttpCidr."

    Write-Host "=== Estado local ==="

    $TerraformPath = Join-Path $PSScriptRoot "..\terraform"
    $TerraformPath = (Resolve-Path $TerraformPath).Path
    $StatePath = Join-Path $TerraformPath "terraform.tfstate"

    if (Test-Path -LiteralPath $StatePath -PathType Leaf) {
        $State = Get-Content -LiteralPath $StatePath -Raw |
            ConvertFrom-Json

        if ($State.version -ne 4) {
            throw "Formato de estado inesperado. Confira o arquivo antes de continuar."
        }

        $ManagedResources = @(
            $State.resources | Where-Object {
                $_.mode -eq "managed" -and
                @($_.instances).Count -gt 0
            }
        )

        if ($ManagedResources.Count -gt 0) {
            throw "Ha recursos no estado local. Confira estado e inventario antes de continuar."
        }
    }

    Write-Host "[OK] Nenhum recurso gerenciado no estado local default."

    Write-Host "=== Rede compartilhada do LAB 08 ==="

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--filters",
        "Name=tag:Name,Values=lab08-application-vpc",
        "Name=tag:Project,Values=cloud-infrastructure-operations-lab",
        "Name=tag:Lab,Values=08",
        "Name=state,Values=available"
    )

    if (@($Response.Vpcs).Count -ne 1) {
        throw "VPC compartilhada ausente ou ambigua."
    }

    $Vpc = $Response.Vpcs[0]
    Assert-SharedTags -Resource $Vpc `
        -ExpectedName "lab08-application-vpc"

    if ($Vpc.OwnerId -ne $ExpectedAccountId) {
        throw "A VPC nao pertence a conta esperada."
    }

    foreach ($Attribute in @("enableDnsSupport", "enableDnsHostnames")) {
        $Response = Get-AwsJson -Arguments @(
            "ec2", "describe-vpc-attribute",
            "--vpc-id", $Vpc.VpcId,
            "--attribute", $Attribute
        )

        $PropertyName = if ($Attribute -eq "enableDnsSupport") {
            "EnableDnsSupport"
        }
        else {
            "EnableDnsHostnames"
        }

        if ($Response.$PropertyName.Value -ne $true) {
            throw "Atributo DNS desabilitado na VPC: $Attribute."
        }
    }

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--filters",
        "Name=vpc-id,Values=$($Vpc.VpcId)",
        "Name=tag:Name,Values=lab08-public-subnet-a",
        "Name=tag:Project,Values=cloud-infrastructure-operations-lab",
        "Name=tag:Lab,Values=08",
        "Name=state,Values=available"
    )

    if (@($Response.Subnets).Count -ne 1) {
        throw "Sub-rede compartilhada ausente ou ambigua."
    }

    $Subnet = $Response.Subnets[0]
    Assert-SharedTags -Resource $Subnet `
        -ExpectedName "lab08-public-subnet-a"

    if ($Subnet.OwnerId -ne $ExpectedAccountId -or
        $Subnet.VpcId -ne $Vpc.VpcId -or
        $Subnet.AvailabilityZone -ne "us-east-1a" -or
        $Subnet.AvailableIpAddressCount -lt 1) {
        throw "Propriedade, zona ou disponibilidade da sub-rede inesperada."
    }

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-route-tables",
        "--filters", "Name=vpc-id,Values=$($Vpc.VpcId)"
    )

    $ExplicitTables = @(
        $Response.RouteTables | Where-Object {
            @(
                $_.Associations | Where-Object {
                    $_.SubnetId -eq $Subnet.SubnetId
                }
            ).Count -gt 0
        }
    )

    if ($ExplicitTables.Count -gt 1) {
        throw "Mais de uma tabela de rotas associada a sub-rede."
    }

    if ($ExplicitTables.Count -eq 1) {
        $RouteTable = $ExplicitTables[0]
    }
    else {
        $MainTables = @(
            $Response.RouteTables | Where-Object {
                @(
                    $_.Associations | Where-Object {
                        $_.Main -eq $true
                    }
                ).Count -gt 0
            }
        )

        if ($MainTables.Count -ne 1) {
            throw "Tabela principal de rotas ausente ou ambigua."
        }

        $RouteTable = $MainTables[0]
    }

    $PublicRoutes = @(
        $RouteTable.Routes | Where-Object {
            $_.DestinationCidrBlock -eq "0.0.0.0/0" -and
            $_.State -eq "active" -and
            $_.GatewayId -match '^igw-'
        }
    )

    if ($PublicRoutes.Count -ne 1) {
        throw "Rota publica ativa para Internet Gateway ausente."
    }

    $GatewayId = $PublicRoutes[0].GatewayId

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-internet-gateways",
        "--internet-gateway-ids", $GatewayId
    )

    if (@($Response.InternetGateways).Count -ne 1 -or
        @(
            $Response.InternetGateways[0].Attachments |
                Where-Object {
                    $_.VpcId -eq $Vpc.VpcId -and
                    $_.State -eq "available"
                }
        ).Count -ne 1) {
        throw "Internet Gateway sem associacao valida com a VPC."
    }

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-network-acls",
        "--filters",
        "Name=association.subnet-id,Values=$($Subnet.SubnetId)"
    )

    if (@($Response.NetworkAcls).Count -ne 1) {
        throw "Network ACL da sub-rede ausente ou ambigua."
    }

    $Acl = $Response.NetworkAcls[0]

    if ($Acl.VpcId -ne $Vpc.VpcId) {
        throw "Network ACL fora da VPC esperada."
    }

    foreach ($IsEgress in @($false, $true)) {
        $Ipv4Rules = @(
            $Acl.Entries | Where-Object {
                $_.Egress -eq $IsEgress -and
                -not [string]::IsNullOrWhiteSpace($_.CidrBlock)
            } | Sort-Object RuleNumber
        )

        if ($Ipv4Rules.Count -eq 0 -or
            $Ipv4Rules[0].RuleAction -ne "allow" -or
            [string]$Ipv4Rules[0].Protocol -ne "-1" -or
            $Ipv4Rules[0].CidrBlock -ne "0.0.0.0/0") {
            $Direction = if ($IsEgress) { "saida" } else { "entrada" }
            throw "ACL sem o perfil IPv4 permissivo esperado na $Direction. Confira as regras."
        }
    }

    Write-Host "[OK] VPC: $($Vpc.VpcId); sub-rede: $($Subnet.SubnetId)."
    Write-Host "[OK] DNS habilitado; zona: $($Subnet.AvailabilityZone)."
    Write-Host "[OK] Rota: $($RouteTable.RouteTableId); IGW: $GatewayId."
    Write-Host "[OK] ACL: $($Acl.NetworkAclId); perfil IPv4 conferido."

    Write-Host "=== Conflitos de recursos exclusivos ==="

    $InstanceFilters = @(
        "Name=tag:Name,Values=lab20-terraform-application-instance"
    )

    $LabFilters = @(
        "Name=tag:Project,Values=cloud-infrastructure-operations-lab",
        "Name=tag:Lab,Values=20"
    )

    foreach ($Filters in @(
        @{ Values = $InstanceFilters },
        @{ Values = $LabFilters }
    )) {
        $Arguments = @(
            "ec2", "describe-instances",
            "--filters",
            "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down"
        ) + $Filters.Values

        $Response = Get-AwsJson -Arguments $Arguments
        $Instances = @(
            $Response.Reservations | ForEach-Object {
                $_.Instances
            }
        )

        if ($Instances.Count -gt 0) {
            throw "EC2 do LAB 20 encontrada. Confira inventario e estado."
        }
    }

    foreach ($Filters in @(
        @{
            Values = @(
                "Name=group-name,Values=lab20-terraform-application-sg"
            )
        },
        @{ Values = $LabFilters }
    )) {
        $Response = Get-AwsJson -Arguments (
            @("ec2", "describe-security-groups", "--filters") +
            $Filters.Values
        )

        if (@($Response.SecurityGroups).Count -gt 0) {
            throw "Security Group do LAB 20 encontrado."
        }
    }

    foreach ($Filters in @(
        @{
            Values = @(
                "Name=tag:Name,Values=lab20-terraform-application-root"
            )
        },
        @{ Values = $LabFilters }
    )) {
        $Response = Get-AwsJson -Arguments (
            @("ec2", "describe-volumes", "--filters") +
            $Filters.Values
        )

        if (@($Response.Volumes).Count -gt 0) {
            throw "Volume do LAB 20 encontrado. Confira possivel recurso remanescente."
        }
    }

    $Roles = @(
        Get-AwsJson -Arguments @(
            "iam", "list-roles",
            "--query",
            "Roles[?RoleName=='lab20-ec2-terraform-role']"
        )
    )

    if ($Roles.Count -gt 0) {
        throw "A IAM Role exclusiva do LAB 20 ja existe."
    }

    $Profiles = @(
        Get-AwsJson -Arguments @(
            "iam", "list-instance-profiles",
            "--query",
            "InstanceProfiles[?InstanceProfileName=='lab20-ec2-terraform-instance-profile']"
        )
    )

    if ($Profiles.Count -gt 0) {
        throw "O Instance Profile exclusivo do LAB 20 ja existe."
    }

    Write-Host "[OK] Nenhum conflito identificado no inventario consultado."
    Write-Host "PRE-VALIDACAO CONCLUIDA: nenhum recurso AWS alterado."

    if ($PassThru) {
        [PSCustomObject]@{
            ProfileName     = $ProfileName
            Region          = $Region
            AccountId       = $Identity.Account
            SharedVpcId     = $Vpc.VpcId
            SharedSubnetId  = $Subnet.SubnetId
            AllowedHttpCidr = $AllowedHttpCidr
            RouteTableId    = $RouteTable.RouteTableId
            InternetGateway = $GatewayId
            NetworkAclId    = $Acl.NetworkAclId
        }
    }

    exit 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    $env:PYTHONIOENCODING = $PreviousPythonEncoding
}
