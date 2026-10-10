[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly
)

. (Join-Path $PSScriptRoot "lab25-common.ps1")
Initialize-Lab25

function ConvertTo-Lab25OrderedJsonValue {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $Result = [ordered]@{}

        foreach (
            $Property in (
                $Value.PSObject.Properties | Sort-Object Name
            )
        ) {
            $Result[$Property.Name] = (
                ConvertTo-Lab25OrderedJsonValue -Value $Property.Value
            )
        }

        return $Result
    }

    if ($Value -is [System.Array]) {
        $Items = New-Object "System.Collections.Generic.List[object]"

        foreach ($Item in $Value) {
            $Items.Add((
                ConvertTo-Lab25OrderedJsonValue -Value $Item
            ))
        }

        return ,($Items.ToArray())
    }

    return $Value
}

function Test-Lab25DashboardBody {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedJson,

        [Parameter(Mandatory = $true)]
        [string]$ActualJson
    )

    $ExpectedObject = $ExpectedJson | ConvertFrom-Json
    $ActualObject = $ActualJson | ConvertFrom-Json

    $ExpectedOrdered = ConvertTo-Lab25OrderedJsonValue `
        -Value $ExpectedObject

    $ActualOrdered = ConvertTo-Lab25OrderedJsonValue `
        -Value $ActualObject

    $ExpectedNormalized = ConvertTo-Json `
        -InputObject $ExpectedOrdered -Depth 30

    $ActualNormalized = ConvertTo-Json `
        -InputObject $ActualOrdered -Depth 30

    return ($ExpectedNormalized -ceq $ActualNormalized)
}

$State = Get-Content -LiteralPath $StatePath -Raw |
    ConvertFrom-Json

if (
    $State.AccountId -ne $Settings.ExpectedAccountId -or
    $State.Region -ne $Settings.Region -or
    $State.RunId -notmatch "^[0-9a-f-]{36}$" -or
    $State.Ids.Instance -notmatch "^i-[0-9a-f]{17}$"
) {
    throw "Inventario diferente do deployment do laboratorio."
}

$LocalDirectory = Split-Path -Parent $StatePath

$ReceiptPath = Join-Path $LocalDirectory (
    "dashboard-receipt-{0}.json" -f $State.RunId
)

$BodyPath = Join-Path $LocalDirectory (
    "dashboard-{0}.json" -f $State.RunId
)

foreach ($RequiredPath in @($ReceiptPath, $BodyPath)) {
    if (-not (Test-Path -LiteralPath $RequiredPath -PathType Leaf)) {
        throw "Arquivo local nao encontrado: $RequiredPath"
    }
}

$Receipt = Get-Content -LiteralPath $ReceiptPath -Raw |
    ConvertFrom-Json

$DashboardName = $Settings.Names.Dashboard

$ExpectedArn = "arn:aws:cloudwatch::{0}:dashboard/{1}" -f `
    $State.AccountId, $DashboardName

if (
    $Receipt.AccountId -ne $State.AccountId -or
    $Receipt.Region -ne $State.Region -or
    $Receipt.RunId -ne $State.RunId -or
    $Receipt.InstanceId -ne $State.Ids.Instance -or
    $Receipt.DashboardName -ne $DashboardName -or
    $Receipt.DashboardArn -ne $ExpectedArn -or
    [string]::IsNullOrWhiteSpace($Receipt.CommandId)
) {
    throw "Recibo do dashboard diferente do deployment."
}

$ExpectedResolvedPath = (Resolve-Path -LiteralPath $BodyPath).Path
$ReceiptResolvedPath = (
    Resolve-Path -LiteralPath $Receipt.BodyPath
).Path

if ($ExpectedResolvedPath -ne $ReceiptResolvedPath) {
    throw "Caminho do corpo JSON diferente do previsto."
}

$ExpectedBody = Get-Content -LiteralPath $BodyPath -Raw
$ExpectedObject = $ExpectedBody | ConvertFrom-Json

if (@($ExpectedObject.widgets).Count -ne 5) {
    throw "Quantidade de widgets diferente da prevista."
}

$TextWidgets = @(
    $ExpectedObject.widgets | Where-Object {
        $_.type -eq "text"
    }
)

if ($TextWidgets.Count -ne 1) {
    throw "Widget de identificacao diferente do previsto."
}

$Markdown = [string]$TextWidgets[0].properties.markdown

foreach ($Marker in @(
    "RunId: $($State.RunId)",
    "CommandId: $($Receipt.CommandId)",
    "Instancia: $($State.Ids.Instance)"
)) {
    if (-not $Markdown.Contains($Marker)) {
        throw "Identificacao do deployment ausente no corpo JSON."
    }
}

$Published = Invoke-Lab25Aws -Service cloudwatch `
    -Operation get-dashboard -Request @{
        DashboardName = $DashboardName
    } -AbsentCodes @("DashboardNotFoundError", "ResourceNotFound")

if ($null -ne $Published) {
    if ($Published.DashboardArn -ne $Receipt.DashboardArn) {
        throw "ARN do dashboard diferente do recibo."
    }

    $Equivalent = Test-Lab25DashboardBody `
        -ExpectedJson $ExpectedBody `
        -ActualJson $Published.DashboardBody

    if (-not $Equivalent) {
        throw "O dashboard foi alterado. Remocao interrompida."
    }

    Write-Host "[OK] Recibo, ARN e conteudo do dashboard conferidos." `
        -ForegroundColor Green
}
else {
    Write-Host "[OK] Dashboard ja ausente." -ForegroundColor Green
}

if ($ValidateOnly) {
    Write-Host "[OK] ValidateOnly: nenhum recurso AWS removido." `
        -ForegroundColor Green
    return
}

$Utf8 = New-Object System.Text.UTF8Encoding($false)
$RemovalRequested = $false

if ($null -ne $Published) {
    $ArchivePath = Join-Path $LocalDirectory (
        "dashboard-before-removal-{0}.json" -f $State.RunId
    )

    [IO.File]::WriteAllText(
        $ArchivePath,
        $Published.DashboardBody,
        $Utf8
    )

    Invoke-Lab25Aws -Service cloudwatch `
        -Operation delete-dashboards -Request @{
            DashboardNames = @($DashboardName)
        } | Out-Null

    $RemovalRequested = $true
}

$Remaining = $null

for ($Attempt = 1; $Attempt -le 6; $Attempt++) {
    $Remaining = Invoke-Lab25Aws -Service cloudwatch `
        -Operation get-dashboard -Request @{
            DashboardName = $DashboardName
        } -AbsentCodes @("DashboardNotFoundError", "ResourceNotFound")

    if ($null -eq $Remaining) {
        break
    }

    if ($Attempt -lt 6) {
        Start-Sleep -Seconds 2
    }
}

if ($null -ne $Remaining) {
    throw "O dashboard ainda existe. Ausencia nao confirmada."
}

$ReportPath = Join-Path $LocalDirectory (
    "dashboard-cleanup-{0}.json" -f $State.RunId
)

$Report = [ordered]@{
    AccountId = $State.AccountId
    Region = $State.Region
    RunId = $State.RunId
    DashboardName = $DashboardName
    DashboardArn = $Receipt.DashboardArn
    RemovalRequested = $RemovalRequested
    AbsenceConfirmed = $true
    VerifiedAtUtc = [DateTime]::UtcNow.ToString("o")
}

$ReportJson = ConvertTo-Json -InputObject $Report -Depth 10
[IO.File]::WriteAllText($ReportPath, $ReportJson, $Utf8)

Write-Host "[OK] Ausencia do dashboard confirmada." `
    -ForegroundColor Green

Write-Host "Relatorio local: $ReportPath"
Write-Host "Inventario, corpo JSON e recibo preservados."
