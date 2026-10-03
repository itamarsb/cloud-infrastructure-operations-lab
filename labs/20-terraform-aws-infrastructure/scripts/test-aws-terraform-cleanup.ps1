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
    [ValidatePattern('^i-[0-9a-f]+$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^vol-[0-9a-f]+$')]
    [string]$RootVolumeId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^sg-[0-9a-f]+$')]
    [string]$SecurityGroupId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^vpc-[0-9a-f]+$')]
    [string]$SharedVpcId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^subnet-[0-9a-f]+$')]
    [string]$SharedSubnetId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^rtb-[0-9a-f]+$')]
    [string]$SharedRouteTableId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^igw-[0-9a-f]+$')]
    [string]$SharedInternetGatewayId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^acl-[0-9a-f]+$')]
    [string]$SharedNetworkAclId
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

    $Text = Invoke-NativeText -Command "aws" -Arguments (
        @($Arguments) + @(
            "--profile", $ProfileName,
            "--region", $Region,
            "--no-cli-pager",
            "--output", "json"
        )
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw "Resposta JSON vazia da AWS CLI."
    }

    return ($Text | ConvertFrom-Json)
}

function Assert-SharedTags {
    param(
        $Resource,
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
    Get-Command terraform -ErrorAction Stop | Out-Null

    if ($ProfileName -ne $ProfileName.Trim()) {
        throw "O perfil AWS contem espacos nas extremidades."
    }

    $TerraformPath = (
        Resolve-Path (Join-Path $PSScriptRoot "..\terraform")
    ).Path

    Write-Host "=== Identidade e estado apos cleanup ==="

    $Identity = Get-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ($Identity.Account -ne $ExpectedAccountId) {
        throw "Conta AWS inesperada: $($Identity.Account)."
    }

    $Workspace = (
        Invoke-NativeText -Command "terraform" -Arguments @(
            "-chdir=$TerraformPath", "workspace", "show"
        )
    ).Trim()

    if ($Workspace -ne "default") {
        throw "Workspace inesperado: $Workspace."
    }

    $StatePath = Join-Path $TerraformPath "terraform.tfstate"

    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
        throw "Estado local ausente. Sua exclusao nao comprova cleanup."
    }

    $State = Get-Content -LiteralPath $StatePath -Raw |
        ConvertFrom-Json

    if ($State.version -ne 4) {
        throw "Formato de estado inesperado."
    }

    $ManagedResources = @(
        $State.resources | Where-Object {
            $_.mode -eq "managed" -and
            @($_.instances).Count -gt 0
        }
    )

    if ($ManagedResources.Count -gt 0) {
        throw "Ainda existem recursos gerenciados no estado."
    }

    Write-Host "[OK] Conta: $ExpectedAccountId; regiao: $Region."
    Write-Host "[OK] Estado preservado; nenhum recurso gerenciado restante."

    Write-Host "=== Recursos exclusivos na AWS ==="

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--filters", "Name=instance-id,Values=$InstanceId"
    )

    $Instances = @(
        $Response.Reservations | ForEach-Object {
            $_.Instances
        }
    )

    if ($Instances.Count -gt 1 -or
        @(
            $Instances | Where-Object {
                $_.State.Name -ne "terminated"
            }
        ).Count -gt 0) {
        throw "A instancia registrada ainda nao esta encerrada."
    }

    Write-Host "[OK] EC2 registrada encerrada ou ausente: $InstanceId."

    $LabFilters = @(
        "Name=tag:Project,Values=cloud-infrastructure-operations-lab",
        "Name=tag:Lab,Values=20"
    )

    foreach ($Filters in @(
        @{
            Values = @(
                "Name=tag:Name,Values=lab20-terraform-application-instance"
            )
        },
        @{ Values = $LabFilters }
    )) {
        $Response = Get-AwsJson -Arguments (
            @(
                "ec2", "describe-instances",
                "--filters",
                "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down"
            ) + $Filters.Values
        )

        $RemainingInstances = @(
            $Response.Reservations | ForEach-Object {
                $_.Instances
            }
        )

        if ($RemainingInstances.Count -gt 0) {
            throw "Instancia remanescente do LAB 20 encontrada."
        }
    }

    foreach ($Filters in @(
        @{ Values = @("Name=volume-id,Values=$RootVolumeId") },
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
            throw "Volume remanescente do LAB 20 encontrado."
        }
    }

    foreach ($Filters in @(
        @{ Values = @("Name=group-id,Values=$SecurityGroupId") },
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
            throw "Security Group remanescente do LAB 20 encontrado."
        }
    }

    $Profiles = @(
        Get-AwsJson -Arguments @(
            "iam", "list-instance-profiles",
            "--query",
            "InstanceProfiles[?InstanceProfileName=='lab20-ec2-terraform-instance-profile']"
        )
    )

    if ($Profiles.Count -gt 0) {
        throw "Instance Profile exclusivo ainda existente."
    }

    $Roles = @(
        Get-AwsJson -Arguments @(
            "iam", "list-roles",
            "--query",
            "Roles[?RoleName=='lab20-ec2-terraform-role']"
        )
    )

    if ($Roles.Count -gt 0) {
        throw "IAM Role exclusiva ainda existente."
    }

    Write-Host "[OK] Volume root, Security Group e recursos IAM ausentes."
    Write-Host "[OK] Nenhuma EC2 ativa identificada pelos nomes ou tags do LAB 20."

    Write-Host "=== Rede compartilhada preservada ==="

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-vpcs",
        "--vpc-ids", $SharedVpcId
    )

    if (@($Response.Vpcs).Count -ne 1 -or
        $Response.Vpcs[0].OwnerId -ne $ExpectedAccountId -or
        $Response.Vpcs[0].State -ne "available") {
        throw "VPC compartilhada ausente ou inesperada."
    }

    Assert-SharedTags -Resource $Response.Vpcs[0] `
        -ExpectedName "lab08-application-vpc"

    foreach ($Attribute in @("enableDnsSupport", "enableDnsHostnames")) {
        $Response = Get-AwsJson -Arguments @(
            "ec2", "describe-vpc-attribute",
            "--vpc-id", $SharedVpcId,
            "--attribute", $Attribute
        )

        $PropertyName = if ($Attribute -eq "enableDnsSupport") {
            "EnableDnsSupport"
        }
        else {
            "EnableDnsHostnames"
        }

        if ($Response.$PropertyName.Value -ne $true) {
            throw "Atributo DNS da VPC desabilitado: $Attribute."
        }
    }

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-subnets",
        "--subnet-ids", $SharedSubnetId
    )

    if (@($Response.Subnets).Count -ne 1 -or
        $Response.Subnets[0].OwnerId -ne $ExpectedAccountId -or
        $Response.Subnets[0].VpcId -ne $SharedVpcId -or
        $Response.Subnets[0].State -ne "available" -or
        $Response.Subnets[0].AvailabilityZone -ne "us-east-1a") {
        throw "Sub-rede compartilhada ausente ou inesperada."
    }

    Assert-SharedTags -Resource $Response.Subnets[0] `
        -ExpectedName "lab08-public-subnet-a"

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-route-tables",
        "--filters", "Name=vpc-id,Values=$SharedVpcId"
    )

    $ExplicitTables = @(
        $Response.RouteTables | Where-Object {
            @(
                $_.Associations | Where-Object {
                    $_.SubnetId -eq $SharedSubnetId
                }
            ).Count -gt 0
        }
    )

    if ($ExplicitTables.Count -gt 1) {
        throw "Associacao de tabela de rotas ambigua."
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

    if ($RouteTable.RouteTableId -ne $SharedRouteTableId) {
        throw "A tabela efetiva da sub-rede diverge do registro anterior."
    }

    $PublicRoutes = @(
        $RouteTable.Routes | Where-Object {
            $_.DestinationCidrBlock -eq "0.0.0.0/0" -and
            $_.State -eq "active" -and
            $_.GatewayId -eq $SharedInternetGatewayId
        }
    )

    if ($PublicRoutes.Count -ne 1) {
        throw "Rota publica registrada nao preservada."
    }

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-internet-gateways",
        "--internet-gateway-ids", $SharedInternetGatewayId
    )

    if (@($Response.InternetGateways).Count -ne 1 -or
        @(
            $Response.InternetGateways[0].Attachments |
                Where-Object {
                    $_.VpcId -eq $SharedVpcId -and
                    $_.State -eq "available"
                }
        ).Count -ne 1) {
        throw "Associacao do Internet Gateway nao preservada."
    }

    $Response = Get-AwsJson -Arguments @(
        "ec2", "describe-network-acls",
        "--filters",
        "Name=association.subnet-id,Values=$SharedSubnetId"
    )

    if (@($Response.NetworkAcls).Count -ne 1 -or
        $Response.NetworkAcls[0].NetworkAclId -ne $SharedNetworkAclId -or
        $Response.NetworkAcls[0].VpcId -ne $SharedVpcId) {
        throw "Network ACL registrada ou sua associacao nao preservada."
    }

    $Acl = $Response.NetworkAcls[0]

    foreach ($IsEgress in @($false, $true)) {
        $Rules = @(
            $Acl.Entries | Where-Object {
                $_.Egress -eq $IsEgress -and
                -not [string]::IsNullOrWhiteSpace($_.CidrBlock)
            } | Sort-Object RuleNumber
        )

        if ($Rules.Count -eq 0 -or
            $Rules[0].RuleAction -ne "allow" -or
            [string]$Rules[0].Protocol -ne "-1" -or
            $Rules[0].CidrBlock -ne "0.0.0.0/0") {
            throw "Perfil IPv4 esperado da ACL nao preservado."
        }
    }

    Write-Host "[OK] VPC: $SharedVpcId; sub-rede: $SharedSubnetId."
    Write-Host "[OK] Rota: $SharedRouteTableId; IGW: $SharedInternetGatewayId."
    Write-Host "[OK] ACL: $SharedNetworkAclId; DNS e conectividade configurada preservados."

    Write-Host "=== Arquivos de configuracao ==="

    foreach ($Name in @(
        "versions.tf",
        "variables.tf",
        "providers.tf",
        "data.tf",
        "iam.tf",
        "security.tf",
        "ec2.tf",
        "outputs.tf",
        "user-data.sh.tftpl"
    )) {
        $Path = Join-Path $TerraformPath $Name

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Arquivo de configuracao ausente: $Name."
        }
    }

    Write-Host "[OK] Arquivos de configuracao preservados."
    Write-Host "VALIDACAO POS-CLEANUP CONCLUIDA: LAB 20."
    exit 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    $env:PYTHONIOENCODING = $PreviousPythonEncoding
}
