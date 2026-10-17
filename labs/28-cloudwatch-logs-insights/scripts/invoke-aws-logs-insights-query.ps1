[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[0-9]{2}-[a-z0-9-]+$")]
    [string]$QueryName,

    [ValidateRange(10, 300)]
    [int]$TimeoutSeconds = 120,

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab28-common.ps1")

Initialize-Lab28 `
    -ProfileName $ProfileName `
    -RequireState

Assert-Lab28Owner | Out-Null

$DatasetPath = Join-Path $script:LocalDirectory "dataset.json"
$Dataset = Read-Lab28Json -Path $DatasetPath

if (
    $Dataset.RunId -cne $State.RunId -or
    $Dataset.ExpectedCount -ne 60 -or
    @($Dataset.Events).Count -ne 60
) {
    throw "O dataset local difere desta execucao."
}

# StartQuery utiliza segundos, conforme registrado no dataset.
$StartTime = [long]$Dataset.StartTime
$EndTime = [long]$Dataset.EndTime

if (
    $StartTime -lt 0 -or
    $EndTime -le $StartTime -or
    ($EndTime - $StartTime) -gt 600
) {
    throw "Janela temporal invalida ou superior a dez minutos."
}

$QueryPath = Join-Path $script:LabRoot (
    "queries/$QueryName.query"
)

if (-not (Test-Path -LiteralPath $QueryPath -PathType Leaf)) {
    throw "Arquivo de consulta nao encontrado: $QueryPath"
}

$Template = Get-Content -LiteralPath $QueryPath -Raw

if ([string]::IsNullOrWhiteSpace($Template)) {
    throw "O arquivo de consulta esta vazio."
}

if (-not $Template.Contains("{{RUN_ID}}")) {
    throw "A consulta deve conter a marcacao {{RUN_ID}}."
}

$QueryText = $Template.Replace(
    "{{RUN_ID}}",
    $State.RunId
)

if ($QueryText.Contains("{{")) {
    throw "Existe uma marcacao nao substituida na consulta."
}

$StartUtc = [DateTimeOffset]::FromUnixTimeSeconds(
    $StartTime
).UtcDateTime.ToString("o")

$EndUtc = [DateTimeOffset]::FromUnixTimeSeconds(
    $EndTime
).UtcDateTime.ToString("o")

Write-Host ""
Write-Host "Consulta: $QueryName"
Write-Host "Grupo: $($State.LogGroupName)"
Write-Host "RunId: $($State.RunId)"
Write-Host "Inicio UTC: $StartUtc"
Write-Host "Fim UTC: $EndUtc"
Write-Host ""
Write-Host "Texto que sera enviado:"
Write-Host $QueryText

$Request = @{
    logGroupName = $State.LogGroupName
    startTime    = $StartTime
    endTime      = $EndTime
    queryString  = $QueryText
    limit        = 100
}

if ($ValidateOnly) {
    Write-Host ""
    Write-Host (
        "Pre-validacao concluida. " +
        "Nenhuma consulta Logs Insights foi iniciada."
    )

    return
}

$AttemptId = [guid]::NewGuid().ToString("N")

$FilePrefix = Join-Path $script:LocalDirectory (
    "$QueryName-$AttemptId"
)

$RequestPath = "$FilePrefix-request.json"
$StartedPath = "$FilePrefix-started.json"
$ResultPath = "$FilePrefix-result.json"

$RequestRecord = [pscustomobject]@{
    PreparedAtUtc = [DateTime]::UtcNow.ToString("o")
    ProfileName   = $ProfileName
    AccountId     = $State.AccountId
    Region        = $Settings.Region
    RunId         = $State.RunId
    QueryName     = $QueryName
    Request       = $Request
}

Save-Lab28Json -Path $RequestPath -Value $RequestRecord

$QueryId = $null
$ShouldStop = $false
$Complete = $false
$LastResult = $null

try {
    $Started = Invoke-Lab28Aws `
        -Operation "start-query" `
        -Request $Request

    $QueryId = [string]$Started.queryId

    if ([string]::IsNullOrWhiteSpace($QueryId)) {
        throw "A resposta nao apresentou o identificador da consulta."
    }

    $ShouldStop = $true

    $StartedRecord = [pscustomobject]@{
        ObservedAtUtc = [DateTime]::UtcNow.ToString("o")
        QueryId       = $QueryId
        RequestPath   = $RequestPath
        Response      = $Started
    }

    Save-Lab28Json -Path $StartedPath -Value $StartedRecord

    Write-Host ""
    Write-Host "Consulta iniciada. QueryId: $QueryId"

    $Clock = [Diagnostics.Stopwatch]::StartNew()

    do {
        $LastResult = Invoke-Lab28Aws `
            -Operation "get-query-results" `
            -Request @{
                queryId = $QueryId
            }

        $Status = [string]$LastResult.status

        Write-Host "Estado observado: $Status"

        if ($Status -ceq "Complete") {
            $Complete = $true
            $ShouldStop = $false
            break
        }

        if ($Status -notin @("Scheduled", "Running")) {
            $TerminalStates = @(
                "Failed"
                "Cancelled"
                "Timeout"
            )

            if ($Status -in $TerminalStates) {
                $ShouldStop = $false
            }

            throw "Consulta encerrada sem sucesso: $Status"
        }

        if ($Clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            break
        }

        Start-Sleep -Seconds 3

    } while ($Clock.Elapsed.TotalSeconds -lt $TimeoutSeconds)

    if (-not $Complete) {
        throw "Tempo de espera esgotado. QueryId: $QueryId"
    }
}
finally {
    if ($ShouldStop) {
        try {
            $StopResponse = Invoke-Lab28Aws `
                -Operation "stop-query" `
                -Request @{
                    queryId = $QueryId
                }

            Save-Lab28Json `
                -Path "$FilePrefix-stop.json" `
                -Value @{
                    QueryId = $QueryId
                    Response = $StopResponse
                    ObservedAtUtc = [DateTime]::UtcNow.ToString("o")
                }

            Write-Host "Solicitacao de parada enviada: $QueryId"
        }
        catch {
            Write-Warning (
                "Nao foi possivel confirmar a parada da consulta " +
                "${QueryId}: $($_.Exception.Message)"
            )
        }
    }

    if ($null -ne $LastResult) {
        Save-Lab28Json -Path $ResultPath -Value @{
            QueryId       = $QueryId
            ObservedAtUtc = [DateTime]::UtcNow.ToString("o")
            Complete      = $Complete
            Response      = $LastResult
        }
    }
}

# O limite deste executor e de 100 resultados.
$NextPageProperty = $LastResult.PSObject.Properties["nextToken"]

if (
    $null -ne $NextPageProperty -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$NextPageProperty.Value
    )
) {
    throw (
        "A resposta indica paginas adicionais. " +
        "O resultado salvo precisa de investigacao antes de prosseguir."
    )
}

# Transforma pares field/value em linhas para exibicao.
$Rows = @(
    foreach ($ResultRow in $LastResult.results) {
        $Record = [ordered]@{}

        foreach ($Cell in $ResultRow) {
            if ($Cell.field -cne "@ptr") {
                $Record[$Cell.field] = $Cell.value
            }
        }

        [pscustomobject]$Record
    }
)

Write-Host ""

if ($Rows.Count -gt 0) {
    $Rows | Format-Table -AutoSize -Wrap
}
else {
    Write-Host "A consulta nao retornou linhas."
}

Write-Host "Estatisticas da consulta:"
$LastResult.statistics | Format-List

Write-Host "Estado final: Complete"
Write-Host "QueryId: $QueryId"
Write-Host "Linhas retornadas: $($Rows.Count)"
Write-Host "Requisicao: $RequestPath"
Write-Host "Resultado: $ResultPath"
