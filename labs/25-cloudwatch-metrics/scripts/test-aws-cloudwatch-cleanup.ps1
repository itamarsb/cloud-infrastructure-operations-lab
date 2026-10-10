[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab"
)

. (Join-Path $PSScriptRoot "lab25-common.ps1")

Initialize-Lab25

if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    throw "Inventario nao encontrado: $StatePath"
}

$script:State = Get-Content -LiteralPath $StatePath -Raw |
    ConvertFrom-Json

if (
    $State.AccountId -ne $Settings.ExpectedAccountId -or
    $State.Region -ne $Settings.Region -or
    [string]::IsNullOrWhiteSpace($State.RunId)
) {
    throw "Inventario incompativel com a conta ou Regiao."
}

$RequiredIds = @(
    "Instance"
    "Volume"
    "Vpc"
    "Subnet"
    "InternetGateway"
    "RouteTable"
    "SecurityGroup"
    "RoleId"
    "InstanceProfileId"
)

foreach ($Key in $RequiredIds) {
    $Property = $State.Ids.PSObject.Properties[$Key]

    if (
        $null -eq $Property -or
        [string]::IsNullOrWhiteSpace([string]$Property.Value)
    ) {
        throw "ID obrigatorio ausente no inventario: $Key"
    }
}

$Results = New-Object "System.Collections.Generic.List[object]"

function Add-Lab25CleanupResult {
    param(
        [string]$Resource,
        [string]$Identifier,
        [bool]$Passed,
        [string]$Observed
    )

    $Results.Add([pscustomobject]@{
        Resource   = $Resource
        Identifier = $Identifier
        Passed     = $Passed
        Observed   = $Observed
    }) | Out-Null

    if ($Passed) {
        Write-Host (
            "[OK] {0}: {1}" -f $Resource, $Observed
        ) -ForegroundColor Green
    }
    else {
        Write-Host (
            "[FALHA] {0}: {1}" -f $Resource, $Observed
        ) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "LAB 25 - Verificacao final do cleanup" `
    -ForegroundColor Cyan

# A instancia pode continuar aparecendo como terminated.
$Response = Invoke-Lab25Aws `
    -Service ec2 `
    -Operation describe-instances `
    -Request @{
        InstanceIds = @($State.Ids.Instance)
    } `
    -AbsentCodes @("InvalidInstanceID.NotFound")

$Instances = @(
    if ($null -ne $Response) {
        foreach ($Reservation in $Response.Reservations) {
            foreach ($Item in $Reservation.Instances) {
                $Item
            }
        }
    }
)

if ($Instances.Count -eq 0) {
    Add-Lab25CleanupResult `
        -Resource "EC2" `
        -Identifier $State.Ids.Instance `
        -Passed $true `
        -Observed "ausente"
}
elseif ($Instances.Count -eq 1) {
    if ($Instances[0].InstanceId -ne $State.Ids.Instance) {
        throw "A consulta retornou uma instancia diferente do inventario."
    }

    $InstanceState = [string]$Instances[0].State.Name

    Add-Lab25CleanupResult `
        -Resource "EC2" `
        -Identifier $State.Ids.Instance `
        -Passed ($InstanceState -eq "terminated") `
        -Observed $InstanceState
}
else {
    throw "Resposta inesperada ao consultar a instancia."
}

$Definitions = @(
    [pscustomobject]@{
        Key         = "Volume"
        Label       = "Volume EBS"
        Operation   = "describe-volumes"
        IdParameter = "VolumeIds"
        Collection  = "Volumes"
        AbsentCode  = "InvalidVolume.NotFound"
    }
    [pscustomobject]@{
        Key         = "Subnet"
        Label       = "Subnet"
        Operation   = "describe-subnets"
        IdParameter = "SubnetIds"
        Collection  = "Subnets"
        AbsentCode  = "InvalidSubnetID.NotFound"
    }
    [pscustomobject]@{
        Key         = "RouteTable"
        Label       = "Tabela de rotas"
        Operation   = "describe-route-tables"
        IdParameter = "RouteTableIds"
        Collection  = "RouteTables"
        AbsentCode  = "InvalidRouteTableID.NotFound"
    }
    [pscustomobject]@{
        Key         = "SecurityGroup"
        Label       = "Security group"
        Operation   = "describe-security-groups"
        IdParameter = "GroupIds"
        Collection  = "SecurityGroups"
        AbsentCode  = "InvalidGroup.NotFound"
    }
    [pscustomobject]@{
        Key         = "InternetGateway"
        Label       = "Internet Gateway"
        Operation   = "describe-internet-gateways"
        IdParameter = "InternetGatewayIds"
        Collection  = "InternetGateways"
        AbsentCode  = "InvalidInternetGatewayID.NotFound"
    }
    [pscustomobject]@{
        Key         = "Vpc"
        Label       = "VPC"
        Operation   = "describe-vpcs"
        IdParameter = "VpcIds"
        Collection  = "Vpcs"
        AbsentCode  = "InvalidVpcID.NotFound"
    }
)

foreach ($Definition in $Definitions) {
    $Key = $Definition.Key
    $Id = [string]$State.Ids.$Key

    $Resource = Get-Lab25Ec2Resource `
        -Operation $Definition.Operation `
        -IdParameter $Definition.IdParameter `
        -Id $Id `
        -Collection $Definition.Collection `
        -AbsentCode $Definition.AbsentCode

    $Absent = $null -eq $Resource

    $Observed = "ainda existe"
    if ($Absent) {
        $Observed = "ausente"
    }

    Add-Lab25CleanupResult `
        -Resource $Definition.Label `
        -Identifier $Id `
        -Passed $Absent `
        -Observed $Observed
}

# Consulta adicional das interfaces de rede da VPC inventariada.
$NetworkResponse = Invoke-Lab25Aws `
    -Service ec2 `
    -Operation describe-network-interfaces `
    -Request @{
        Filters = @(
            @{
                Name   = "vpc-id"
                Values = @($State.Ids.Vpc)
            }
        )
    }

$Interfaces = @($NetworkResponse.NetworkInterfaces)

Add-Lab25CleanupResult `
    -Resource "Interfaces de rede da VPC" `
    -Identifier $State.Ids.Vpc `
    -Passed ($Interfaces.Count -eq 0) `
    -Observed ("{0} encontradas" -f $Interfaces.Count)

$RoleResponse = Invoke-Lab25Aws `
    -Service iam `
    -Operation get-role `
    -Request @{
        RoleName = $Settings.Names.Role
    } `
    -AbsentCodes @("NoSuchEntity")

$RoleAbsent = $null -eq $RoleResponse
$RoleObserved = "ainda existe"

if ($RoleAbsent) {
    $RoleObserved = "ausente"
}

Add-Lab25CleanupResult `
    -Resource "Role IAM" `
    -Identifier $Settings.Names.Role `
    -Passed $RoleAbsent `
    -Observed $RoleObserved

$ProfileResponse = Invoke-Lab25Aws `
    -Service iam `
    -Operation get-instance-profile `
    -Request @{
        InstanceProfileName = $Settings.Names.InstanceProfile
    } `
    -AbsentCodes @("NoSuchEntity")

$ProfileAbsent = $null -eq $ProfileResponse
$ProfileObserved = "ainda existe"

if ($ProfileAbsent) {
    $ProfileObserved = "ausente"
}

Add-Lab25CleanupResult `
    -Resource "Instance profile" `
    -Identifier $Settings.Names.InstanceProfile `
    -Passed $ProfileAbsent `
    -Observed $ProfileObserved

$DashboardResponse = Invoke-Lab25Aws `
    -Service cloudwatch `
    -Operation get-dashboard `
    -Request @{
        DashboardName = $Settings.Names.Dashboard
    } `
    -AbsentCodes @("DashboardNotFoundError", "ResourceNotFound")

$DashboardAbsent = $null -eq $DashboardResponse
$DashboardObserved = "ainda existe"

if ($DashboardAbsent) {
    $DashboardObserved = "ausente"
}

Add-Lab25CleanupResult `
    -Resource "Dashboard CloudWatch" `
    -Identifier $Settings.Names.Dashboard `
    -Passed $DashboardAbsent `
    -Observed $DashboardObserved

$Checks = @($Results.ToArray())
$Failures = @($Checks | Where-Object { -not $_.Passed })
$AllPassed = $Failures.Count -eq 0

$VerifiedAt = [DateTime]::UtcNow
$LocalDirectory = Split-Path -Parent $StatePath

$ReportPath = Join-Path $LocalDirectory (
    "cleanup-verification-{0}.json" -f
    $VerifiedAt.ToString("yyyyMMddTHHmmssfffZ")
)

$Report = [pscustomobject]@{
    AccountId     = $State.AccountId
    Region        = $State.Region
    RunId         = $State.RunId
    VerifiedAtUtc = $VerifiedAt.ToString("o")
    Scope         = "Recursos inventariados, nomes IAM/dashboard e ENIs da VPC"
    AllPassed     = $AllPassed
    Checks        = $Checks
}

$Utf8 = New-Object System.Text.UTF8Encoding($false)
$ReportJson = ConvertTo-Json -InputObject $Report -Depth 20

[IO.File]::WriteAllText($ReportPath, $ReportJson, $Utf8)

Write-Host ""
Write-Host "Relatorio local: $ReportPath"
Write-Host "Inventario preservado: $StatePath"

if (-not $AllPassed) {
    throw (
        "Cleanup nao confirmado: {0} verificacao(oes) falharam." -f
        $Failures.Count
    )
}

Write-Host (
    "[OK] Cleanup confirmado por consultas de leitura: {0} verificacoes." -f
    $Checks.Count
) -ForegroundColor Green
