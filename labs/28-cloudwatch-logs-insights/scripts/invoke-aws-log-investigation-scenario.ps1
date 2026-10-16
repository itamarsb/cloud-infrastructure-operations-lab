[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab28-common.ps1")

Initialize-Lab28 `
    -ProfileName $ProfileName `
    -RequireState

Assert-Lab28Owner | Out-Null

# Confere o stream antes de preparar os eventos.
$StreamResponse = Invoke-Lab28Aws `
    -Operation "describe-log-streams" `
    -Request @{
        logGroupName        = $State.LogGroupName
        logStreamNamePrefix = $State.StreamName
    }

$Streams = @(
    $StreamResponse.logStreams | Where-Object {
        $_.logStreamName -ceq $State.StreamName
    }
)

if ($Streams.Count -ne 1) {
    throw "O stream esperado nao foi confirmado."
}

$DatasetPath = Join-Path $script:LocalDirectory "dataset.json"

if (Test-Path -LiteralPath $DatasetPath) {
    throw (
        "Ja existe um dataset preparado nesta execucao. " +
        "Preserve o arquivo e confira a ingestao antes de qualquer reenvio."
    )
}

# Posiciona as tres fases em minutos UTC distintos, no passado recente.
$NowSeconds = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$BaseSeconds = [long](
    [Math]::Floor($NowSeconds / 60) * 60 - 180
)

$Phases = @(
    "baseline"
    "incident"
    "recovery"
)

$Events = @()
$Messages = @()

for ($PhaseIndex = 0; $PhaseIndex -lt 3; $PhaseIndex++) {
    $Phase = $Phases[$PhaseIndex]

    for ($Index = 0; $Index -lt 20; $Index++) {
        $Number = $PhaseIndex * 20 + $Index + 1

        $StatusCode = 200
        $Level = "INFO"
        $ErrorFlag = 0
        $Cause = "none"
        $DurationMs = 80 + $Index * 3

        # As primeiras doze requisicoes da fase incident falham.
        if ($Phase -eq "incident" -and $Index -lt 12) {
            $StatusCode = 503
            $Level = "ERROR"
            $ErrorFlag = 1
            $Cause = "dependency_timeout"
            $DurationMs = 900 + $Index * 25
        }

        $Endpoint = "/health"

        if (($Number % 2) -eq 1 -or $ErrorFlag -eq 1) {
            $Endpoint = "/orders"
        }

        $RequestId = "{0}-req-{1:d3}" -f $State.RunId, $Number

        $TimestampMs = [long](
            ($BaseSeconds + $PhaseIndex * 60 + $Index) * 1000
        )

        $Message = [ordered]@{
            runId      = $State.RunId
            phase      = $Phase
            service    = "checkout-api"
            requestId  = $RequestId
            endpoint   = $Endpoint
            statusCode = $StatusCode
            level      = $Level
            durationMs = $DurationMs
            errorFlag  = $ErrorFlag
            cause      = $Cause
            synthetic  = $true
        }

        $Messages += [pscustomobject]$Message

        $Events += [pscustomobject]@{
            timestamp = $TimestampMs
            message   = (
                ConvertTo-Json -InputObject $Message -Compress
            )
        }
    }
}

$Summary = @(
    foreach ($Phase in $Phases) {
        $PhaseMessages = @(
            $Messages | Where-Object {
                $_.phase -ceq $Phase
            }
        )

        $ErrorCount = @(
            $PhaseMessages | Where-Object {
                $_.errorFlag -eq 1
            }
        ).Count

        [pscustomobject]@{
            Phase            = $Phase
            Requests         = $PhaseMessages.Count
            Errors           = $ErrorCount
            ErrorRatePercent = (
                100.0 * $ErrorCount / $PhaseMessages.Count
            )
        }
    }
)

$TotalErrors = @(
    $Messages | Where-Object {
        $_.errorFlag -eq 1
    }
).Count

if ($Events.Count -ne 60 -or $TotalErrors -ne 12) {
    throw "O dataset gerado difere das contagens previstas."
}

$Dataset = [pscustomobject]@{
    RunId          = $State.RunId
    CreatedAtUtc   = [DateTime]::UtcNow.ToString("o")
    StartTime      = $BaseSeconds - 1
    EndTime        = $NowSeconds
    ExpectedCount  = 60
    ExpectedErrors = 12
    Summary        = $Summary
    Events         = $Events
}

Write-Host ""
Write-Host "Grupo: $($State.LogGroupName)"
Write-Host "Stream: $($State.StreamName)"
Write-Host "Eventos preparados: $($Events.Count)"

$Summary | Format-Table -AutoSize

Write-Host "Exemplo do primeiro evento:"
$Events[0].message

Write-Host ""
Write-Host "Exemplo do primeiro erro:"
$Events[20].message

if ($ValidateOnly) {
    Write-Host ""
    Write-Host (
        "Pre-validacao concluida. " +
        "Nenhum evento foi publicado e nenhum dataset foi salvo."
    )

    return
}

# Salva antes da chamada AWS para preservar o lote exato.
Save-Lab28Json -Path $DatasetPath -Value $Dataset

$PublicationResponse = Invoke-Lab28Aws `
    -Operation "put-log-events" `
    -Request @{
        logGroupName  = $State.LogGroupName
        logStreamName = $State.StreamName
        logEvents     = $Events
    }

$Receipt = [pscustomobject]@{
    ObservedAtUtc = [DateTime]::UtcNow.ToString("o")
    RunId         = $State.RunId
    LogGroupName  = $State.LogGroupName
    StreamName    = $State.StreamName
    SubmittedCount = $Events.Count
    Response      = $PublicationResponse
}

$ReceiptPath = Join-Path $script:LocalDirectory (
    "publication-response.json"
)

Save-Lab28Json -Path $ReceiptPath -Value $Receipt

if ($null -ne $PublicationResponse) {
    $RejectedEvents = (
        $PublicationResponse.PSObject.Properties[
            "rejectedLogEventsInfo"
        ]
    )

    if ($null -ne $RejectedEvents) {
        throw (
            "A resposta informa rejeicao de eventos. " +
            "Preserve o dataset e o recibo para investigacao."
        )
    }
}

Write-Host ""
Write-Host "Publicacao concluida sem rejeicao informada."
Write-Host "Dataset: $DatasetPath"
Write-Host "Recibo: $ReceiptPath"
Write-Host "A ingestao ainda precisa ser confirmada por leitura."
