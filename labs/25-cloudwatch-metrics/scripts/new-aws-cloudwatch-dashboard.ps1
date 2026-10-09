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
    $State.Completed -ne $false -or
    $State.RunId -notmatch "^[0-9a-f-]{36}$" -or
    $State.Ids.Instance -notmatch "^i-[0-9a-f]{17}$"
) {
    throw "Inventario diferente do deployment ativo do laboratorio."
}

$LocalDirectory = Split-Path -Parent $StatePath
$ReceiptPath = Join-Path $LocalDirectory (
    "cpu-load-{0}.json" -f $State.RunId
)

$Receipt = Get-Content -LiteralPath $ReceiptPath -Raw |
    ConvertFrom-Json

if (
    $Receipt.AccountId -ne $State.AccountId -or
    $Receipt.Region -ne $State.Region -or
    $Receipt.RunId -ne $State.RunId -or
    $Receipt.InstanceId -ne $State.Ids.Instance -or
    $Receipt.DurationSeconds -ne 600 -or
    $Receipt.Workers -ne 1 -or
    [string]::IsNullOrWhiteSpace($Receipt.CommandId)
) {
    throw "Recibo da carga diferente do deployment ativo."
}

$InstanceResponse = Invoke-Lab25Aws -Service ec2 `
    -Operation describe-instances -Request @{
        InstanceIds = @($State.Ids.Instance)
    }

$Instances = @(
    foreach ($Reservation in $InstanceResponse.Reservations) {
        foreach ($Item in $Reservation.Instances) {
            $Item
        }
    }
)

if ($Instances.Count -ne 1) {
    throw "A instancia do laboratorio nao foi identificada."
}

$Instance = $Instances[0]
Assert-Lab25Ownership -Resource $Instance `
    -Name $Settings.Names.Instance

if (
    $Instance.State.Name -ne "running" -or
    $Instance.InstanceType -ne $Settings.InstanceType -or
    $Instance.VpcId -ne $State.Ids.Vpc -or
    $Instance.SubnetId -ne $State.Ids.Subnet
) {
    throw "A instancia difere do cenario esperado."
}

$Invocation = Invoke-Lab25Aws -Service ssm `
    -Operation get-command-invocation -Request @{
        CommandId = $Receipt.CommandId
        InstanceId = $State.Ids.Instance
    }

if (
    $Invocation.Status -ne "Success" -or
    $Invocation.ResponseCode -ne 0 -or
    $Invocation.StandardOutputContent -notmatch "LOAD_FINISHED_OK"
) {
    throw "A conclusao da carga nao foi confirmada."
}

$OutputText = [string]$Invocation.StandardOutputContent

$BeginMatch = [regex]::Match(
    $OutputText,
    "(?m)^LOAD_BEGIN_UTC=(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\r?$"
)

$EndMatch = [regex]::Match(
    $OutputText,
    "(?m)^LOAD_END_UTC=(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\r?$"
)

if (-not $BeginMatch.Success -or -not $EndMatch.Success) {
    throw "Os horarios de inicio e termino nao foram identificados."
}

$Culture = [Globalization.CultureInfo]::InvariantCulture

$LoadBegin = [DateTimeOffset]::Parse(
    $BeginMatch.Groups[1].Value,
    $Culture
).UtcDateTime

$LoadEnd = [DateTimeOffset]::Parse(
    $EndMatch.Groups[1].Value,
    $Culture
).UtcDateTime

$ActualDuration = ($LoadEnd - $LoadBegin).TotalSeconds

if ($ActualDuration -lt 600 -or $ActualDuration -gt 610) {
    throw "Duracao da carga diferente da prevista."
}

# Alinha a janela a multiplos de cinco minutos.
$IntervalTicks = [TimeSpan]::FromMinutes(5).Ticks

$StartCandidate = $LoadBegin.AddMinutes(-15)
$StartTicks = $StartCandidate.Ticks -
    ($StartCandidate.Ticks % $IntervalTicks)

$EndCandidate = $LoadEnd.AddMinutes(20)
$EndTicks = $EndCandidate.Ticks
$EndRemainder = $EndTicks % $IntervalTicks

if ($EndRemainder -ne 0) {
    $EndTicks += $IntervalTicks - $EndRemainder
}

$StartUtc = [DateTime]::new(
    $StartTicks,
    [DateTimeKind]::Utc
).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

$EndUtc = [DateTime]::new(
    $EndTicks,
    [DateTimeKind]::Utc
).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

$LoadBeginUtc = $LoadBegin.ToString("yyyy-MM-ddTHH:mm:ssZ")
$LoadEndUtc = $LoadEnd.ToString("yyyy-MM-ddTHH:mm:ssZ")

function New-Lab25MetricWidget {
    param(
        [string]$Title,
        [string[]]$MetricNames,
        [string[]]$Statistics,
        [int]$Period,
        [int]$X,
        [int]$Y
    )

    if ($MetricNames.Count -ne $Statistics.Count) {
        throw "Quantidade de metricas e estatisticas diferente."
    }

    $Rows = New-Object "System.Collections.Generic.List[object]"

    for ($Index = 0; $Index -lt $MetricNames.Count; $Index++) {
        $Rows.Add(@(
            "AWS/EC2",
            $MetricNames[$Index],
            "InstanceId",
            $State.Ids.Instance,
            @{
                stat = $Statistics[$Index]
                label = (
                    "{0} ({1})" -f
                    $MetricNames[$Index],
                    $Statistics[$Index]
                )
            }
        ))
    }

    return @{
        type = "metric"
        x = $X
        y = $Y
        width = 12
        height = 6
        properties = @{
            title = $Title
            region = $Settings.Region
            view = "timeSeries"
            stacked = $false
            liveData = $false
            period = $Period
            metrics = $Rows.ToArray()
            legend = @{
                position = "bottom"
            }
            yAxis = @{
                left = @{
                    min = 0
                }
            }
            annotations = @{
                vertical = @(
                    @{
                        label = "Inicio da carga"
                        value = $LoadBeginUtc
                        color = "#d62728"
                    }
                    @{
                        label = "Fim da carga"
                        value = $LoadEndUtc
                        color = "#2ca02c"
                    }
                )
            }
        }
    }
}

$Markdown = @(
    "# LAB 25 - Metricas no CloudWatch"
    ""
    "Instancia: $($State.Ids.Instance) | Regiao: $($Settings.Region)"
    ""
    "Carga: $LoadBeginUtc a $LoadEndUtc | 600 segundos | 1 processo"
    ""
    "RunId: $($State.RunId) | CommandId: $($Receipt.CommandId)"
    ""
    "Dashboard gerenciado pelo script do laboratorio."
) -join "`n"

$Widgets = New-Object "System.Collections.Generic.List[object]"

$Widgets.Add(@{
    type = "text"
    x = 0
    y = 0
    width = 24
    height = 4
    properties = @{
        markdown = $Markdown
    }
})

$Widgets.Add((New-Lab25MetricWidget `
    -Title "CPU - percentual da instancia" `
    -MetricNames @("CPUUtilization", "CPUUtilization") `
    -Statistics @("Average", "Maximum") `
    -Period 300 -X 0 -Y 4))

$Widgets.Add((New-Lab25MetricWidget `
    -Title "Saldo de creditos de CPU" `
    -MetricNames @("CPUCreditBalance") `
    -Statistics @("Average") `
    -Period 300 -X 12 -Y 4))

$Widgets.Add((New-Lab25MetricWidget `
    -Title "Rede - bytes por intervalo de 5 minutos" `
    -MetricNames @("NetworkIn", "NetworkOut") `
    -Statistics @("Sum", "Sum") `
    -Period 300 -X 0 -Y 10))

$Widgets.Add((New-Lab25MetricWidget `
    -Title "Falhas nas verificacoes EC2 - maximo por minuto" `
    -MetricNames @("StatusCheckFailed") `
    -Statistics @("Maximum") `
    -Period 60 -X 12 -Y 10))

$Body = [ordered]@{
    start = $StartUtc
    end = $EndUtc
    periodOverride = "inherit"
    widgets = $Widgets.ToArray()
}

$BodyJson = ConvertTo-Json -InputObject $Body -Depth 30
$DashboardName = $Settings.Names.Dashboard

$Existing = Invoke-Lab25Aws -Service cloudwatch `
    -Operation get-dashboard -Request @{
        DashboardName = $DashboardName
    } -AbsentCodes @("DashboardNotFoundError", "ResourceNotFound")

# Aceita repeticao somente quando o conteudo JSON for equivalente.
if ($null -ne $Existing) {
    $Equivalent = Test-Lab25DashboardBody `
        -ExpectedJson $BodyJson `
        -ActualJson $Existing.DashboardBody

    if (-not $Equivalent) {
        throw "Ja existe um dashboard com esse nome e outro conteudo."
    }
}

Write-Host ""
Write-Host "LAB 25 - Dashboard" -ForegroundColor Cyan

[pscustomobject]@{
    Dashboard = $DashboardName
    InstanceId = $State.Ids.Instance
    StartTimeUtc = $StartUtc
    EndTimeUtc = $EndUtc
    LoadBeginUtc = $LoadBeginUtc
    LoadEndUtc = $LoadEndUtc
    Widgets = $Widgets.Count
} | Format-List | Out-Host

if ($ValidateOnly) {
    Write-Host (
        "[OK] Pre-requisitos e corpo do dashboard preparados."
    ) -ForegroundColor Green

    Write-Host (
        "[OK] ValidateOnly: nenhuma alteracao realizada na AWS."
    ) -ForegroundColor Green

    return
}

$BodyPath = Join-Path $LocalDirectory (
    "dashboard-{0}.json" -f $State.RunId
)

$Utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($BodyPath, $BodyJson, $Utf8)

if ($null -eq $Existing) {
    $PutResult = Invoke-Lab25Aws -Service cloudwatch `
        -Operation put-dashboard -Request @{
            DashboardName = $DashboardName
            DashboardBody = $BodyJson
        }

    if (@($PutResult.DashboardValidationMessages).Count -ne 0) {
        $PutResult.DashboardValidationMessages |
            Format-List | Out-Host

        throw (
            "CloudWatch retornou mensagens de validacao. " +
            "Confira o dashboard antes de prosseguir."
        )
    }
}

$Published = Invoke-Lab25Aws -Service cloudwatch `
    -Operation get-dashboard -Request @{
        DashboardName = $DashboardName
    }

$Equivalent = Test-Lab25DashboardBody `
    -ExpectedJson $BodyJson `
    -ActualJson $Published.DashboardBody

if (-not $Equivalent) {
    throw "O conteudo publicado difere do corpo preparado."
}

$PublishedBody = $Published.DashboardBody | ConvertFrom-Json

if (@($PublishedBody.widgets).Count -ne 5) {
    throw "Quantidade de widgets diferente da prevista."
}

$DashboardReceiptPath = Join-Path $LocalDirectory (
    "dashboard-receipt-{0}.json" -f $State.RunId
)

$DashboardReceipt = [ordered]@{
    AccountId = $State.AccountId
    Region = $State.Region
    RunId = $State.RunId
    InstanceId = $State.Ids.Instance
    CommandId = $Receipt.CommandId
    DashboardName = $DashboardName
    DashboardArn = $Published.DashboardArn
    BodyPath = $BodyPath
    VerifiedAtUtc = [DateTime]::UtcNow.ToString("o")
}

$ReceiptJson = ConvertTo-Json -InputObject $DashboardReceipt -Depth 10
[IO.File]::WriteAllText(
    $DashboardReceiptPath,
    $ReceiptJson,
    $Utf8
)

$DashboardUrl = (
    "https://console.aws.amazon.com/cloudwatch/home?region=" +
    $Settings.Region +
    "#dashboards:name=" +
    $DashboardName
)

Write-Host "[OK] Dashboard publicado e conteudo conferido." `
    -ForegroundColor Green

Write-Host "Corpo local: $BodyPath"
Write-Host "Recibo local: $DashboardReceiptPath"
Write-Host "Dashboard: $DashboardUrl"
