[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [Parameter(Mandatory = $true)]
    [ValidateSet("Baseline", "Breach", "Recovery")]
    [string]$Phase,

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab27-common.ps1")

Initialize-Lab27 -ProfileName $ProfileName

$ValidatorPath = Join-Path $PSScriptRoot (
    "test-aws-cloudwatch-alarms.ps1"
)

$Observation = & $ValidatorPath `
    -ProfileName $ProfileName `
    -PassThru

if ($null -eq $Observation) {
    throw "O validador nao retornou o resultado."
}

$SampleCount = 5

if ($SampleCount -gt $Settings.Stimulus.MaximumSamplesPerPhase) {
    throw "Quantidade de amostras acima do limite configurado."
}

switch ($Phase) {
    "Baseline" {
        $Value = $Settings.Stimulus.BaselineValue
    }
    "Breach" {
        if ($Observation.AlarmState -cne "OK") {
            throw "Confirme o estado OK antes da fase Breach."
        }

        $Value = $Settings.Stimulus.BreachValue
    }
    "Recovery" {
        if ($Observation.AlarmState -cne "ALARM") {
            throw "Confirme o estado ALARM antes da fase Recovery."
        }

        $Value = $Settings.Stimulus.RecoveryValue
    }
}

$script:ScenarioPath = Join-Path $script:LocalDirectory (
    "metric-scenario-$($Observation.RunId)-$Phase.json"
)

if (Test-Path -LiteralPath $script:ScenarioPath) {
    throw (
        "Ja existe recibo desta fase. " +
        "Consulte os resultados antes de qualquer novo envio."
    )
}

Write-Host "[INFO] Fase: $Phase"
Write-Host "[INFO] Valor por ponto: $Value"
Write-Host "[INFO] Amostras: $SampleCount"
Write-Host "[INFO] Intervalo minimo: 60 segundos"

if ($ValidateOnly) {
    Write-Host "[OK] Pre-validacao concluida. Nenhuma metrica publicada." `
        -ForegroundColor Green

    return
}

$script:Scenario = [ordered]@{
    RunId = $Observation.RunId
    Phase = $Phase
    Value = $Value
    SampleCount = $SampleCount
    IntervalSeconds = $Settings.Stimulus.IntervalSeconds
    StartedAtUtc = [DateTime]::UtcNow.ToString("o")
    Status = "Running"
    CompletedAtUtc = $null
    LastError = $null
    Samples = @()
}

function Save-Lab27Scenario {
    $Token = [guid]::NewGuid().ToString("N")

    $TemporaryPath = Join-Path $script:LocalDirectory (
        "metric-scenario-$Token.tmp"
    )

    $BackupPath = Join-Path $script:LocalDirectory (
        "metric-scenario-$Token.bak"
    )

    $Utf8 = New-Object System.Text.UTF8Encoding($false)

    try {
        [IO.File]::WriteAllText(
            $TemporaryPath,
            (ConvertTo-Json -InputObject $script:Scenario -Depth 30),
            $Utf8
        )

        [IO.File]::Replace(
            $TemporaryPath,
            $script:ScenarioPath,
            $BackupPath
        )
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath `
                -Force -ErrorAction SilentlyContinue
        }
    }
}

$Utf8 = New-Object System.Text.UTF8Encoding($false)

$Bytes = $Utf8.GetBytes(
    (ConvertTo-Json -InputObject $script:Scenario -Depth 30)
)

$Stream = [IO.File]::Open(
    $script:ScenarioPath,
    [IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None
)

try {
    $Stream.Write($Bytes, 0, $Bytes.Length)
    $Stream.Flush()
}
finally {
    $Stream.Dispose()
}

try {
    $NextSampleUtc = [DateTime]::UtcNow

    for ($Index = 1; $Index -le $SampleCount; $Index++) {
        while ([DateTime]::UtcNow -lt $NextSampleUtc) {
            Start-Sleep -Milliseconds 500
        }

        $TimestampUtc = [DateTime]::UtcNow

        $Sample = [ordered]@{
            Sequence = $Index
            TimestampUtc = $TimestampUtc.ToString("o")
            Value = $Value
            Status = "Requested"
            AcceptedAtUtc = $null
        }

        $script:Scenario.Samples += $Sample
        Save-Lab27Scenario

        Invoke-Lab27Aws `
            -Service "cloudwatch" `
            -Operation "put-metric-data" `
            -Request @{
                Namespace = $Settings.Metric.Namespace
                MetricData = @(
                    @{
                        MetricName = $Settings.Metric.MetricName
                        Dimensions = $Observation.Dimensions
                        Timestamp = $TimestampUtc.ToString("o")
                        Value = $Value
                        Unit = $Settings.Metric.Unit
                        StorageResolution = $Settings.Metric.StorageResolution
                    }
                )
            } | Out-Null

        $Sample.Status = "Accepted"
        $Sample.AcceptedAtUtc = [DateTime]::UtcNow.ToString("o")
        Save-Lab27Scenario

        Write-Host (
            "[OK] Ponto $Index/$SampleCount aceito: " +
            "$($Sample.TimestampUtc), valor=$Value"
        ) -ForegroundColor Green

        $NextSampleUtc = $TimestampUtc.AddSeconds(
            $Settings.Stimulus.IntervalSeconds
        )
    }

    $script:Scenario.Status = "Published"
    $script:Scenario.CompletedAtUtc = [DateTime]::UtcNow.ToString("o")
    Save-Lab27Scenario

    Write-Host "[OK] Publicacao da fase concluida." `
        -ForegroundColor Green

    Write-Host "[INFO] Recibo: $script:ScenarioPath"
    Write-Host "[INFO] Consulte o validador para verificar ingestao e estado."
}
catch {
    $OriginalError = $_
    $script:Scenario.Status = "FailedOrUnknown"
    $script:Scenario.LastError = $OriginalError.Exception.Message

    try {
        Save-Lab27Scenario
    }
    catch {
        Write-Warning "Nao foi possivel atualizar o recibo da fase."
    }

    Write-Warning (
        "Pode haver pontos publicados. Preserve o recibo e consulte o validador."
    )

    throw $OriginalError
}
