[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [ValidateRange(5, 120)]
    [int]$WindowMinutes = 30
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
    $State.Ids.Instance -notmatch "^i-[0-9a-f]+$" -or
    $State.Completed -ne $true -or
    $State.AgentInstalled -ne $true
) {
    throw "Inventario incompativel ou instalacao nao confirmada."
}

if (
    $null -ne $State.PSObject.Properties["CleanupCompleted"] -and
    $State.CleanupCompleted
) {
    throw "A infraestrutura deste inventario ja foi removida."
}

$InstanceId = [string]$State.Ids.Instance

$ReceiptPath = Join-Path $LocalDirectory (
    "agent-install-{0}.json" -f $State.RunId
)

$Receipt = Read-Lab26Json -Path $ReceiptPath
$ParsedCommandId = [guid]::Empty

if (
    $Receipt.AccountId -ne $State.AccountId -or
    $Receipt.Region -ne $State.Region -or
    $Receipt.RunId -ne $State.RunId -or
    $Receipt.InstanceId -ne $InstanceId -or
    $Receipt.Status -ne "Success" -or
    -not [guid]::TryParse(
        [string]$Receipt.CommandId,
        [ref]$ParsedCommandId
    )
) {
    throw "Recibo de instalacao incompativel."
}

$ExpectedMarker = "LAB26_AGENT_READY_$($State.RunId)"

if ($Receipt.EventMarker -cne $ExpectedMarker) {
    throw "Marcador do recibo diferente do esperado."
}

$ConfigText = Get-Content -LiteralPath $AgentConfigurationPath -Raw
$ConfigText = $ConfigText.Replace("`r`n", "`n").Replace("`r", "`n")
$Hasher = [Security.Cryptography.SHA256]::Create()

try {
    $ConfigHash = (
        [BitConverter]::ToString(
            $Hasher.ComputeHash(
                [Text.Encoding]::UTF8.GetBytes($ConfigText)
            )
        )
    ).Replace("-", "").ToLowerInvariant()
}
finally {
    $Hasher.Dispose()
}

if (
    $Receipt.ConfigSha256 -cne $ConfigHash -or
    $State.AgentConfigSha256 -cne $ConfigHash
) {
    throw "A configuracao local difere da instalacao registrada."
}

# Reutiliza as consultas de propriedade e associacoes.
# ValidateOnly retorna antes de qualquer remocao.
& (Join-Path $PSScriptRoot "remove-aws-cloudwatch-agent.ps1") `
    -ProfileName $ProfileName `
    -ValidateOnly

$InstanceResponse = Invoke-Lab26Aws `
    -Service "ec2" `
    -Operation "describe-instances" `
    -Request @{
        InstanceIds = @($InstanceId)
    }

$Instances = @(
    foreach ($Reservation in $InstanceResponse.Reservations) {
        foreach ($Instance in $Reservation.Instances) {
            $Instance
        }
    }
)

if (
    $Instances.Count -ne 1 -or
    $Instances[0].State.Name -ne "running"
) {
    throw "A instancia do laboratorio nao esta running."
}

$SsmResponse = Invoke-Lab26Aws `
    -Service "ssm" `
    -Operation "describe-instance-information" `
    -Request @{
        Filters = @(
            @{
                Key    = "InstanceIds"
                Values = @($InstanceId)
            }
        )
    }

$ManagedInstances = @($SsmResponse.InstanceInformationList)

if (
    $ManagedInstances.Count -ne 1 -or
    $ManagedInstances[0].PingStatus -ne "Online"
) {
    throw "A instancia nao esta Online no Systems Manager."
}

$Invocation = Invoke-Lab26Aws `
    -Service "ssm" `
    -Operation "get-command-invocation" `
    -Request @{
        CommandId  = $Receipt.CommandId
        InstanceId = $InstanceId
    }

if (
    $Invocation.Status -ne "Success" -or
    $Invocation.ResponseCode -ne 0
) {
    throw "O comando de instalacao nao confirma sucesso."
}

foreach ($Line in @(
    "CONFIG_SHA256=$ConfigHash"
    "AGENT_SERVICE=active"
    "AGENT_STATUS=running"
    "INSTALL_COMPLETE_RUN_ID=$($State.RunId)"
)) {
    $Pattern = "(?m)^" + [regex]::Escape($Line) + "\r?$"

    if ($Invocation.StandardOutputContent -notmatch $Pattern) {
        throw "Confirmacao ausente no resultado da instalacao: $Line"
    }
}

$GroupResponse = Invoke-Lab26Aws `
    -Service "logs" `
    -Operation "describe-log-groups" `
    -Request @{
        logGroupNamePrefix = $Settings.Logs.LogGroupName
    }

$Groups = @(
    $GroupResponse.logGroups | Where-Object {
        $_.logGroupName -ceq $Settings.Logs.LogGroupName
    }
)

if ($Groups.Count -ne 1) {
    throw "O grupo de logs exclusivo nao foi identificado."
}

if (
    $null -eq $Groups[0].PSObject.Properties["retentionInDays"] -or
    $Groups[0].retentionInDays -ne $Settings.Logs.RetentionInDays
) {
    throw "A retencao do grupo de logs difere da prevista."
}

Write-Host (
    "[OK] Instancia running, SSM Online, instalacao e retencao conferidos."
) -ForegroundColor Green

$CollectedAt = [DateTimeOffset]::UtcNow

# Exclui o minuto ainda em andamento da janela de metricas.
$EndUtc = $CollectedAt.AddTicks(
    -($CollectedAt.Ticks % [TimeSpan]::TicksPerMinute)
)
$StartUtc = $EndUtc.AddMinutes(-$WindowMinutes)

$MetricResults = New-Object "System.Collections.Generic.List[object]"
$MetricsWithData = 0

Write-Host ""
Write-Host "LAB 26 - Metricas do agente" -ForegroundColor Cyan

foreach ($MetricName in @(
    "mem_used_percent"
    "disk_used_percent"
)) {
    $Listed = Invoke-Lab26Aws `
        -Service "cloudwatch" `
        -Operation "list-metrics" `
        -Request @{
            Namespace  = $Settings.Metrics.Namespace
            MetricName = $MetricName
            Dimensions = @(
                @{
                    Name  = "InstanceId"
                    Value = $InstanceId
                }
            )
        }

    $Candidates = @(
        $Listed.Metrics | Where-Object {
            $null -ne $_
        }
    )

    if ($MetricName -eq "disk_used_percent") {
        $Candidates = @(
            $Candidates | Where-Object {
                @(
                    $_.Dimensions | Where-Object {
                        $_.Name -ceq "path" -and
                        $_.Value -ceq "/"
                    }
                ).Count -eq 1
            }
        )
    }

    if ($Candidates.Count -gt 1) {
        $Candidates | ConvertTo-Json -Depth 10
        throw "Mais de uma serie encontrada para $MetricName."
    }

    $Dimensions = @()
    $Points = @()
    $MetricStatus = "NotDiscovered"

    if ($Candidates.Count -eq 1) {
        $Dimensions = @(
            foreach ($Dimension in (
                $Candidates[0].Dimensions | Sort-Object Name
            )) {
                @{
                    Name  = [string]$Dimension.Name
                    Value = [string]$Dimension.Value
                }
            }
        )

        $Collected = Invoke-Lab26Aws `
            -Service "cloudwatch" `
            -Operation "get-metric-statistics" `
            -Request @{
                Namespace  = $Settings.Metrics.Namespace
                MetricName = $MetricName
                Dimensions = $Dimensions
                StartTime  = $StartUtc.ToString(
                    "yyyy-MM-ddTHH:mm:ssZ"
                )
                EndTime    = $EndUtc.ToString(
                    "yyyy-MM-ddTHH:mm:ssZ"
                )
                Period     = 60
                Statistics = @("Average", "Maximum")
            }

        $Points = @(
            foreach ($Point in (
                $Collected.Datapoints |
                    Sort-Object { [DateTimeOffset]$_.Timestamp }
            )) {
                if (
                    $Point.Unit -cne "Percent" -or
                    [double]::IsNaN([double]$Point.Average) -or
                    [double]::IsNaN([double]$Point.Maximum) -or
                    $Point.Average -lt 0 -or
                    $Point.Average -gt 100 -or
                    $Point.Maximum -lt $Point.Average -or
                    $Point.Maximum -gt 100
                ) {
                    throw "Unidade ou valores inesperados em $MetricName."
                }

                [pscustomobject]@{
                    TimestampUtc = (
                        [DateTimeOffset]::Parse(
                            [string]$Point.Timestamp
                        )
                    ).UtcDateTime.ToString(
                        "yyyy-MM-ddTHH:mm:ssZ"
                    )
                    Unit    = [string]$Point.Unit
                    Average = [double]$Point.Average
                    Maximum = [double]$Point.Maximum
                }
            }
        )

        $MetricStatus = "NoDatapoints"

        if ($Points.Count -gt 0) {
            $MetricStatus = "DataFound"
            $MetricsWithData++
        }
    }

    $MetricResults.Add(
        [pscustomobject]@{
            MetricName = $MetricName
            Namespace  = $Settings.Metrics.Namespace
            Dimensions = $Dimensions
            PeriodSeconds = 60
            Statistics = @("Average", "Maximum")
            Status     = $MetricStatus
            PointCount = $Points.Count
            Datapoints = $Points
        }
    )

    Write-Host ""
    Write-Host "$MetricName | pontos=$($Points.Count)"

    foreach ($Dimension in $Dimensions) {
        Write-Host (
            "Dimensao: {0}={1}" -f
            $Dimension.Name,
            $Dimension.Value
        )
    }

    if ($Points.Count -gt 0) {
        $Points | Format-Table -AutoSize
    }
    else {
        Write-Host (
            "[PENDENTE] $MetricName : $MetricStatus"
        ) -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "LAB 26 - Evento de log" -ForegroundColor Cyan

$LogStart = (
    [DateTimeOffset]::Parse(
        [string]$Receipt.RequestedAtUtc
    )
).AddMinutes(-1)

if ($LogStart -ge $CollectedAt) {
    throw "Horario do recibo incompativel com a consulta."
}

$LogResponse = Invoke-Lab26Aws `
    -Service "logs" `
    -Operation "filter-log-events" `
    -Request @{
        logGroupName   = $Settings.Logs.LogGroupName
        logStreamNames = @($InstanceId)
        startTime      = $LogStart.ToUnixTimeMilliseconds()
        endTime        = $CollectedAt.ToUnixTimeMilliseconds()
        filterPattern  = ('"{0}"' -f $ExpectedMarker)
    } `
    -AbsentCodes @("ResourceNotFoundException")

$Events = @()

if ($null -ne $LogResponse) {
    $Events = @(
        foreach ($Event in $LogResponse.events) {
            if (
                $Event.logStreamName -ceq $InstanceId -and
                $Event.message.Contains($ExpectedMarker) -and
                $Event.message.Contains("RunId=$($State.RunId)")
            ) {
                [pscustomobject]@{
                    TimestampUtc = (
                        [DateTimeOffset]::FromUnixTimeMilliseconds(
                            [long]$Event.timestamp
                        )
                    ).UtcDateTime.ToString(
                        "yyyy-MM-ddTHH:mm:ssZ"
                    )
                    IngestionTimeUtc = (
                        [DateTimeOffset]::FromUnixTimeMilliseconds(
                            [long]$Event.ingestionTime
                        )
                    ).UtcDateTime.ToString(
                        "yyyy-MM-ddTHH:mm:ssZ"
                    )
                    EventId       = [string]$Event.eventId
                    LogStreamName = [string]$Event.logStreamName
                    Message       = [string]$Event.message
                }
            }
        }
    )
}

$Events | Format-List

$DataConfirmed = (
    $MetricsWithData -eq 2 -and
    $Events.Count -gt 0
)

$Report = [ordered]@{
    SchemaVersion  = 1
    CollectedAtUtc = $CollectedAt.UtcDateTime.ToString("o")
    AccountId      = $State.AccountId
    Region         = $State.Region
    RunId          = $State.RunId
    InstanceId     = $InstanceId
    Ec2Status      = $Instances[0].State.Name
    SsmStatus      = $ManagedInstances[0].PingStatus
    Installation   = [ordered]@{
        CommandId    = $Receipt.CommandId
        Status       = $Invocation.Status
        ResponseCode = $Invocation.ResponseCode
        AgentVersion = $State.AgentVersion
        ConfigSha256 = $ConfigHash
    }
    MetricWindow = [ordered]@{
        StartTimeUtc = $StartUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        EndTimeUtc   = $EndUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        Minutes      = $WindowMinutes
    }
    Metrics = $MetricResults.ToArray()
    Logs = [ordered]@{
        LogGroupName  = $Settings.Logs.LogGroupName
        LogStreamName = $InstanceId
        RetentionDays = $Groups[0].retentionInDays
        Marker        = $ExpectedMarker
        StartTimeUtc  = $LogStart.UtcDateTime.ToString("o")
        EndTimeUtc    = $CollectedAt.UtcDateTime.ToString("o")
        EventCount    = $Events.Count
        Events        = $Events
    }
    Summary = [ordered]@{
        MetricsWithData = $MetricsWithData
        ExpectedMetrics = 2
        MarkerFound     = ($Events.Count -gt 0)
        DataConfirmed   = $DataConfirmed
    }
}

$ReportPath = Join-Path $LocalDirectory (
    "agent-validation-{0}-{1}.json" -f
    $State.RunId,
    $CollectedAt.UtcDateTime.ToString("yyyyMMddTHHmmssfffZ")
)

$Utf8 = New-Object System.Text.UTF8Encoding($false)

[IO.File]::WriteAllText(
    $ReportPath,
    (ConvertTo-Json -InputObject $Report -Depth 30),
    $Utf8
)

Write-Host ""
Write-Host "Metricas com dados: $MetricsWithData de 2."
Write-Host "Eventos com o marcador: $($Events.Count)."
Write-Host "Relatorio local: $ReportPath"

if ($DataConfirmed) {
    Write-Host (
        "[OK] Memoria, disco raiz e entrega do log confirmados."
    ) -ForegroundColor Green
}
else {
    Write-Host (
        "[PENDENTE] Entrega nao confirmada por completo nesta consulta."
    ) -ForegroundColor Yellow

    Write-Host (
        "Confira o relatorio e repita a consulta apos alguns minutos."
    )
}

Write-Host (
    "[OK] Validacao concluida com consultas de leitura a AWS."
) -ForegroundColor Green
