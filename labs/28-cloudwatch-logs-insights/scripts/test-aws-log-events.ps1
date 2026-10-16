[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab28-common.ps1")

Initialize-Lab28 `
    -ProfileName $ProfileName `
    -RequireState

Assert-Lab28Owner | Out-Null

$DatasetPath = Join-Path $script:LocalDirectory "dataset.json"

$Dataset = Read-Lab28Json -Path $DatasetPath
$ExpectedEvents = @($Dataset.Events)

if (
    $Dataset.RunId -cne $State.RunId -or
    $Dataset.ExpectedCount -ne 60 -or
    $Dataset.ExpectedErrors -ne 12 -or
    $ExpectedEvents.Count -ne 60
) {
    throw "O dataset local difere do escopo desta execucao."
}

$StartTimeMs = [long]$Dataset.StartTime * 1000
$EndTimeMs = [long]$Dataset.EndTime * 1000

if (
    $StartTimeMs -lt 0 -or
    $EndTimeMs -le $StartTimeMs -or
    ($EndTimeMs - $StartTimeMs) -gt 600000
) {
    throw "Janela temporal invalida ou superior a dez minutos."
}

foreach ($Event in $ExpectedEvents) {
    if (
        $Event.timestamp -lt $StartTimeMs -or
        $Event.timestamp -ge $EndTimeMs
    ) {
        throw "Existe evento local fora da janela de leitura."
    }
}

# Percorre as paginas ate a AWS devolver o mesmo token enviado.
$ObservedEvents = @()
$NextToken = $null
$PaginationComplete = $false
$PagesRead = 0

for ($Page = 1; $Page -le 20; $Page++) {
    $Request = @{
        logGroupName  = $State.LogGroupName
        logStreamName = $State.StreamName
        startTime     = $StartTimeMs
        endTime       = $EndTimeMs
        startFromHead = $true
        limit         = 1000
    }

    if (-not [string]::IsNullOrWhiteSpace($NextToken)) {
        $Request["nextToken"] = $NextToken
    }

    $Response = Invoke-Lab28Aws `
        -Operation "get-log-events" `
        -Request $Request

    $ObservedEvents += @($Response.events)
    $PagesRead++

    $ReturnedToken = [string]$Response.nextForwardToken

    if ([string]::IsNullOrWhiteSpace($ReturnedToken)) {
        throw "A resposta nao apresentou o token de paginacao."
    }

    if ($ReturnedToken -ceq $NextToken) {
        $PaginationComplete = $true
        break
    }

    $NextToken = $ReturnedToken
}

# Preserva a leitura antes de avaliar seu resultado.
$ObservationToken = [guid]::NewGuid().ToString("N")

$ObservationPath = Join-Path $script:LocalDirectory (
    "ingestion-observed-$ObservationToken.json"
)

$Observation = [pscustomobject]@{
    ObservedAtUtc      = [DateTime]::UtcNow.ToString("o")
    RunId              = $State.RunId
    LogGroupName       = $State.LogGroupName
    StreamName         = $State.StreamName
    StartTimeMs        = $StartTimeMs
    EndTimeMs          = $EndTimeMs
    PagesRead          = $PagesRead
    PaginationComplete = $PaginationComplete
    ExpectedCount      = $ExpectedEvents.Count
    ObservedCount      = $ObservedEvents.Count
    Events             = $ObservedEvents
}

Save-Lab28Json `
    -Path $ObservationPath `
    -Value $Observation

Write-Host ""
Write-Host "Eventos esperados: $($ExpectedEvents.Count)"
Write-Host "Eventos observados: $($ObservedEvents.Count)"
Write-Host "Paginas consultadas: $PagesRead"
Write-Host "Leitura salva: $ObservationPath"

if (-not $PaginationComplete) {
    throw "A paginacao nao terminou dentro do limite previsto."
}

if ($ObservedEvents.Count -lt $ExpectedEvents.Count) {
    throw (
        "Leitura incompleta. Aguarde 30 segundos e repita " +
        "somente este teste. Nao republique os eventos."
    )
}

if ($ObservedEvents.Count -gt $ExpectedEvents.Count) {
    throw (
        "Foram observados eventos adicionais. " +
        "Preserve os arquivos para investigar possiveis duplicatas."
    )
}

# Compara cada timestamp e mensagem, preservando a contagem de duplicatas.
$ExpectedKeys = @(
    $ExpectedEvents | ForEach-Object {
        "$($_.timestamp)|$($_.message)"
    } | Sort-Object
)

$ObservedKeys = @(
    $ObservedEvents | ForEach-Object {
        "$($_.timestamp)|$($_.message)"
    } | Sort-Object
)

for ($Index = 0; $Index -lt $ExpectedKeys.Count; $Index++) {
    if (
        [string]::CompareOrdinal(
            $ExpectedKeys[$Index],
            $ObservedKeys[$Index]
        ) -ne 0
    ) {
        throw "Os timestamps ou mensagens diferem do dataset local."
    }
}

$Messages = @(
    $ObservedEvents | ForEach-Object {
        ConvertFrom-Json -InputObject $_.message
    }
)

$Summary = @(
    foreach ($Phase in @("baseline", "incident", "recovery")) {
        $PhaseMessages = @(
            $Messages | Where-Object {
                $_.phase -ceq $Phase
            }
        )

        if ($PhaseMessages.Count -ne 20) {
            throw "Contagem inesperada na fase: $Phase"
        }

        $ErrorCount = @(
            $PhaseMessages | Where-Object {
                $_.errorFlag -eq 1
            }
        ).Count

        $ExpectedErrors = 0

        if ($Phase -eq "incident") {
            $ExpectedErrors = 12
        }

        if ($ErrorCount -ne $ExpectedErrors) {
            throw "Quantidade inesperada de erros na fase: $Phase"
        }

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

$ReportPath = Join-Path $script:LocalDirectory (
    "ingestion-validation-$ObservationToken.json"
)

$Report = [pscustomobject]@{
    ObservedAtUtc          = [DateTime]::UtcNow.ToString("o")
    RunId                  = $State.RunId
    ObservationPath        = $ObservationPath
    ExpectedCount          = $ExpectedEvents.Count
    ObservedCount          = $ObservedEvents.Count
    ExactDatasetMatch      = $true
    PhaseExpectationsMatch = $true
    Summary                = $Summary
}

Save-Lab28Json -Path $ReportPath -Value $Report

Write-Host ""
$Summary | Format-Table -AutoSize

Write-Host "Ingestao confirmada: 60 eventos identicos ao dataset."
Write-Host "Contagens por fase e erros confirmados."
Write-Host "Nenhum recurso AWS foi criado ou alterado."
Write-Host "Relatorio de validacao: $ReportPath"
