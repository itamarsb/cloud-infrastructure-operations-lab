[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab"
)

. (Join-Path $PSScriptRoot "lab26-common.ps1")

Initialize-Lab26 -ProfileName $ProfileName

$script:State = Read-Lab26Json -Path $StatePath
$ParsedRunId = [guid]::Empty

if (
    $State.AccountId -ne $Settings.ExpectedAccountId -or
    $State.Region -ne $Settings.Region -or
    -not [guid]::TryParse(
        [string]$State.RunId,
        [ref]$ParsedRunId
    ) -or
    $State.Completed -ne $true
) {
    throw "Inventario incompativel ou provisionamento incompleto."
}

foreach ($Name in $Settings.Names.PSObject.Properties) {
    if ($State.Names.($Name.Name) -cne $Name.Value) {
        throw "Nome no inventario diferente do previsto: $($Name.Name)"
    }
}

if (
    $null -eq $State.PSObject.Properties["CleanupCompleted"] -or
    $State.CleanupCompleted -ne $true
) {
    throw "O inventario nao registra a conclusao do cleanup."
}

if (
    $State.Ids.Instance -notmatch "^i-[0-9a-f]+$" -or
    $State.Ids.LogGroup -cne $Settings.Logs.LogGroupName -or
    [string]::IsNullOrWhiteSpace([string]$State.Ids.RoleId) -or
    [string]::IsNullOrWhiteSpace(
        [string]$State.Ids.InstanceProfileId
    )
) {
    throw "IDs ou grupo de logs ausentes ou invalidos no inventario."
}

$Definitions = @(
    [pscustomobject]@{
        Label      = "Volume raiz"
        Key        = "Volume"
        Pattern    = "^vol-[0-9a-f]+$"
        Operation  = "describe-volumes"
        Parameter  = "VolumeIds"
        Collection = "Volumes"
        AbsentCode = "InvalidVolume.NotFound"
    }
    [pscustomobject]@{
        Label      = "Security group"
        Key        = "SecurityGroup"
        Pattern    = "^sg-[0-9a-f]+$"
        Operation  = "describe-security-groups"
        Parameter  = "GroupIds"
        Collection = "SecurityGroups"
        AbsentCode = "InvalidGroup.NotFound"
    }
    [pscustomobject]@{
        Label      = "Subnet"
        Key        = "Subnet"
        Pattern    = "^subnet-[0-9a-f]+$"
        Operation  = "describe-subnets"
        Parameter  = "SubnetIds"
        Collection = "Subnets"
        AbsentCode = "InvalidSubnetID.NotFound"
    }
    [pscustomobject]@{
        Label      = "Route table"
        Key        = "RouteTable"
        Pattern    = "^rtb-[0-9a-f]+$"
        Operation  = "describe-route-tables"
        Parameter  = "RouteTableIds"
        Collection = "RouteTables"
        AbsentCode = "InvalidRouteTableID.NotFound"
    }
    [pscustomobject]@{
        Label      = "Internet Gateway"
        Key        = "InternetGateway"
        Pattern    = "^igw-[0-9a-f]+$"
        Operation  = "describe-internet-gateways"
        Parameter  = "InternetGatewayIds"
        Collection = "InternetGateways"
        AbsentCode = "InvalidInternetGatewayID.NotFound"
    }
    [pscustomobject]@{
        Label      = "VPC"
        Key        = "Vpc"
        Pattern    = "^vpc-[0-9a-f]+$"
        Operation  = "describe-vpcs"
        Parameter  = "VpcIds"
        Collection = "Vpcs"
        AbsentCode = "InvalidVpcID.NotFound"
    }
)

foreach ($Definition in $Definitions) {
    $Id = [string]$State.Ids.($Definition.Key)

    if ($Id -notmatch $Definition.Pattern) {
        throw "ID ausente ou invalido: $($Definition.Label)"
    }
}

$Results = New-Object "System.Collections.Generic.List[object]"

function Add-Lab26CleanupResult {
    param(
        [string]$Resource,
        [string]$Identifier,
        [bool]$Confirmed,
        [string]$Observed
    )

    $Results.Add(
        [pscustomobject]@{
            Resource   = $Resource
            Identifier = $Identifier
            Confirmed  = $Confirmed
            Observed   = $Observed
        }
    )

    if ($Confirmed) {
        Write-Host "[OK] ${Resource}: $Observed" `
            -ForegroundColor Green
    }
    else {
        Write-Host "[PENDENTE] ${Resource}: $Observed" `
            -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "LAB 26 - Confirmacao independente do cleanup" `
    -ForegroundColor Cyan

$InstanceResponse = Invoke-Lab26Aws `
    -Service "ec2" `
    -Operation "describe-instances" `
    -Request @{
        InstanceIds = @([string]$State.Ids.Instance)
    } `
    -AbsentCodes @("InvalidInstanceID.NotFound")

$Instances = @()

if ($null -ne $InstanceResponse) {
    $Instances = @(
        foreach ($Reservation in $InstanceResponse.Reservations) {
            foreach ($Instance in $Reservation.Instances) {
                $Instance
            }
        }
    )
}

if ($Instances.Count -gt 1) {
    throw "Resposta inesperada ao consultar a instancia."
}

$InstanceObserved = "ausente"
$InstanceConfirmed = $true

if ($Instances.Count -eq 1) {
    Assert-Lab26Ownership `
        -Resource $Instances[0] `
        -Name $Settings.Names.Instance

    $InstanceObserved = [string]$Instances[0].State.Name
    $InstanceConfirmed = ($InstanceObserved -eq "terminated")
}

Add-Lab26CleanupResult `
    -Resource "Instancia EC2" `
    -Identifier $State.Ids.Instance `
    -Confirmed $InstanceConfirmed `
    -Observed $InstanceObserved

foreach ($Definition in $Definitions) {
    $Id = [string]$State.Ids.($Definition.Key)

    $Resource = Get-Lab26Ec2Resource `
        -Operation $Definition.Operation `
        -IdParameter $Definition.Parameter `
        -Id $Id `
        -Collection $Definition.Collection `
        -AbsentCode $Definition.AbsentCode

    $Observed = "ausente"

    if ($null -ne $Resource) {
        $Observed = "ainda presente"
    }

    Add-Lab26CleanupResult `
        -Resource $Definition.Label `
        -Identifier $Id `
        -Confirmed ($null -eq $Resource) `
        -Observed $Observed
}

$Interfaces = Invoke-Lab26Aws `
    -Service "ec2" `
    -Operation "describe-network-interfaces" `
    -Request @{
        Filters = @(
            @{
                Name   = "vpc-id"
                Values = @([string]$State.Ids.Vpc)
            }
        )
    }

$InterfaceCount = @($Interfaces.NetworkInterfaces).Count

Add-Lab26CleanupResult `
    -Resource "Interfaces na VPC exclusiva" `
    -Identifier $State.Ids.Vpc `
    -Confirmed ($InterfaceCount -eq 0) `
    -Observed "$InterfaceCount encontradas"

$RoleResponse = Invoke-Lab26Aws `
    -Service "iam" `
    -Operation "get-role" `
    -Request @{
        RoleName = $Settings.Names.Role
    } `
    -AbsentCodes @("NoSuchEntity")

$RoleObserved = "ausente"

if ($null -ne $RoleResponse) {
    $RoleObserved = "nome ainda presente"
}

Add-Lab26CleanupResult `
    -Resource "IAM role" `
    -Identifier $Settings.Names.Role `
    -Confirmed ($null -eq $RoleResponse) `
    -Observed $RoleObserved

$ProfileResponse = Invoke-Lab26Aws `
    -Service "iam" `
    -Operation "get-instance-profile" `
    -Request @{
        InstanceProfileName = $Settings.Names.InstanceProfile
    } `
    -AbsentCodes @("NoSuchEntity")

$ProfileObserved = "ausente"

if ($null -ne $ProfileResponse) {
    $ProfileObserved = "nome ainda presente"
}

Add-Lab26CleanupResult `
    -Resource "Instance profile" `
    -Identifier $Settings.Names.InstanceProfile `
    -Confirmed ($null -eq $ProfileResponse) `
    -Observed $ProfileObserved

$GroupResponse = Invoke-Lab26Aws `
    -Service "logs" `
    -Operation "describe-log-groups" `
    -Request @{
        logGroupNamePrefix = $Settings.Logs.LogGroupName
    }

$MatchingGroups = @(
    $GroupResponse.logGroups | Where-Object {
        $_.logGroupName -ceq $Settings.Logs.LogGroupName
    }
)

$GroupObserved = "ausente"

if ($MatchingGroups.Count -gt 0) {
    $GroupObserved = "ainda presente"
}

Add-Lab26CleanupResult `
    -Resource "CloudWatch log group" `
    -Identifier $Settings.Logs.LogGroupName `
    -Confirmed ($MatchingGroups.Count -eq 0) `
    -Observed $GroupObserved

$ConfirmedCount = @(
    $Results | Where-Object Confirmed -eq $true
).Count

$AllConfirmed = (
    $Results.Count -eq 11 -and
    $ConfirmedCount -eq 11
)

$CheckedAt = [DateTime]::UtcNow

$Report = [ordered]@{
    SchemaVersion     = 1
    CheckedAtUtc      = $CheckedAt.ToString("o")
    AccountId         = $State.AccountId
    Region            = $State.Region
    RunId             = $State.RunId
    InventoryPath     = $StatePath
    CleanupRecordedAtUtc = $State.CleanupCompletedAtUtc
    ExpectedChecks    = 11
    ConfirmedChecks   = $ConfirmedCount
    CleanupConfirmed  = $AllConfirmed
    Results           = $Results.ToArray()
}

$ReportPath = Join-Path $LocalDirectory (
    "cleanup-validation-{0}-{1}.json" -f
    $State.RunId,
    $CheckedAt.ToString("yyyyMMddTHHmmssfffZ")
)

$Utf8 = New-Object System.Text.UTF8Encoding($false)

[IO.File]::WriteAllText(
    $ReportPath,
    (ConvertTo-Json -InputObject $Report -Depth 30),
    $Utf8
)

Write-Host ""
Write-Host "Verificacoes confirmadas: $ConfirmedCount de 11."
Write-Host "Relatorio local: $ReportPath"

if (-not $AllConfirmed) {
    throw (
        "Cleanup ainda nao confirmado por completo. " +
        "Confira o relatorio antes de qualquer nova remocao."
    )
}

Write-Host (
    "[OK] Cleanup confirmado por consultas independentes."
) -ForegroundColor Green

Write-Host (
    "[OK] Inventario, recibos e relatorios locais preservados."
) -ForegroundColor Green
