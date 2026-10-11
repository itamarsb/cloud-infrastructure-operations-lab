[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly,
    [switch]$CheckStatus
)

. (Join-Path $PSScriptRoot "lab26-common.ps1")

if ($ValidateOnly -and $CheckStatus) {
    throw "Use ValidateOnly ou CheckStatus, separadamente."
}

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
    throw "Inventario incompativel ou agente nao instalado."
}

if (
    $null -ne $State.PSObject.Properties["CleanupCompleted"] -and
    $State.CleanupCompleted
) {
    throw "A infraestrutura deste inventario ja foi removida."
}

$InstanceId = [string]$State.Ids.Instance

$ReceiptPath = Join-Path $LocalDirectory (
    "log-events-{0}.json" -f $State.RunId
)

function Save-Lab26LogReceipt {
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $TemporaryPath = "$ReceiptPath.tmp"

    [IO.File]::WriteAllText(
        $TemporaryPath,
        (ConvertTo-Json -InputObject $script:Receipt -Depth 30),
        $Utf8
    )

    Move-Item -LiteralPath $TemporaryPath `
        -Destination $ReceiptPath -Force
}

if ($CheckStatus) {
    $script:Receipt = Read-Lab26Json -Path $ReceiptPath
    $ParsedBatchId = [guid]::Empty
    $ParsedCommandId = [guid]::Empty

    if (
        $Receipt.AccountId -ne $State.AccountId -or
        $Receipt.Region -ne $State.Region -or
        $Receipt.RunId -ne $State.RunId -or
        $Receipt.InstanceId -ne $InstanceId -or
        $Receipt.LogGroupName -cne $Settings.Logs.LogGroupName -or
        $Receipt.ExpectedCount -ne 3 -or
        -not [guid]::TryParse(
            [string]$Receipt.BatchId,
            [ref]$ParsedBatchId
        ) -or
        -not [guid]::TryParse(
            [string]$Receipt.CommandId,
            [ref]$ParsedCommandId
        )
    ) {
        throw "Recibo incompativel ou CommandId ausente."
    }

    if (
        $Receipt.Marker -cne "LAB26_LOG_TEST_$($Receipt.BatchId)"
    ) {
        throw "Marcador do recibo diferente do esperado."
    }

    $Invocation = Invoke-Lab26Aws `
        -Service "ssm" `
        -Operation "get-command-invocation" `
        -Request @{
            CommandId  = $Receipt.CommandId
            InstanceId = $InstanceId
        } `
        -AbsentCodes @("InvocationDoesNotExist")

    if ($null -eq $Invocation) {
        Write-Host (
            "Invocacao ainda indisponivel. Repita apenas CheckStatus."
        )
        return
    }

    $Receipt.CommandStatus = $Invocation.Status
    $Receipt.LastCheckedAtUtc = [DateTime]::UtcNow.ToString("o")
    Save-Lab26LogReceipt

    Write-Host ""
    Write-Host "LAB 26 - Eventos sinteticos" -ForegroundColor Cyan

    [pscustomobject]@{
        InstanceId   = $InstanceId
        BatchId      = $Receipt.BatchId
        CommandId    = $Receipt.CommandId
        Status       = $Invocation.Status
        ResponseCode = $Invocation.ResponseCode
    } | Format-List

    if ($Invocation.Status -in @(
        "Pending", "InProgress", "Delayed", "Cancelling"
    )) {
        Write-Host (
            "Comando em andamento. Repita apenas CheckStatus."
        )
        return
    }

    if (
        $Invocation.Status -ne "Success" -or
        $Invocation.ResponseCode -ne 0
    ) {
        Write-Host $Invocation.StandardOutputContent
        Write-Host $Invocation.StandardErrorContent `
            -ForegroundColor Yellow

        throw "O comando falhou. Recibo preservado; nao reenvie."
    }

    $OutputText = [string]$Invocation.StandardOutputContent

    foreach ($Line in @(
        "LOCAL_EVENTS=3"
        "LOG_BATCH_COMPLETE=$($Receipt.BatchId)"
    )) {
        $Pattern = "(?m)^" + [regex]::Escape($Line) + "\r?$"

        if ($OutputText -notmatch $Pattern) {
            throw "Confirmacao local ausente: $Line"
        }
    }

    $LocalLines = @(
        foreach ($Line in ($OutputText -split "\r?\n")) {
            if ($Line.StartsWith("LOCAL_EVENT=")) {
                $Line.Substring("LOCAL_EVENT=".Length)
            }
        }
    )

    if ($LocalLines.Count -ne 3) {
        throw "O comando nao retornou as tres linhas locais."
    }

    $Levels = @("INFO", "WARN", "ERROR")

    for ($Index = 0; $Index -lt 3; $Index++) {
        $Sequence = $Index + 1
        $ExpectedSuffix = (
            " {0} RunId={1} BatchId={2} Marker={3} " +
            "Sequence={4} Message=Synthetic{0}"
        ) -f (
            $Levels[$Index],
            $State.RunId,
            $Receipt.BatchId,
            $Receipt.Marker,
            $Sequence
        )

        $Pattern = (
            "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z" +
            [regex]::Escape($ExpectedSuffix) +
            "$"
        )

        if ($LocalLines[$Index] -cnotmatch $Pattern) {
            throw "Conteudo local inesperado na sequencia $Sequence."
        }
    }

    $CheckedAt = [DateTimeOffset]::UtcNow
    $LogStart = (
        [DateTimeOffset]::Parse(
            [string]$Receipt.RequestedAtUtc
        )
    ).AddMinutes(-1)

    if ($LogStart -ge $CheckedAt) {
        throw "Horario do recibo incompativel."
    }

    $LogResponse = Invoke-Lab26Aws `
        -Service "logs" `
        -Operation "filter-log-events" `
        -Request @{
            logGroupName   = $Settings.Logs.LogGroupName
            logStreamNames = @($InstanceId)
            startTime      = $LogStart.ToUnixTimeMilliseconds()
            endTime        = $CheckedAt.ToUnixTimeMilliseconds()
            filterPattern  = ('"{0}"' -f $Receipt.Marker)
        } `
        -AbsentCodes @("ResourceNotFoundException")

    $CloudEvents = @()

    if ($null -ne $LogResponse) {
        $CloudEvents = @(
            $LogResponse.events | Where-Object {
                $_.logStreamName -ceq $InstanceId -and
                $_.message.Contains([string]$Receipt.Marker)
            }
        )
    }

    $Results = @(
        for ($Index = 0; $Index -lt 3; $Index++) {
            $ExpectedLine = $LocalLines[$Index]

            $MatchesInCloud = @(
                $CloudEvents | Where-Object {
                    $_.message.TrimEnd([char[]]"`r`n") -ceq
                        $ExpectedLine
                }
            )

            if ($MatchesInCloud.Count -gt 1) {
                throw "Evento duplicado na sequencia $($Index + 1)."
            }

            $EventTime = ""
            $IngestionTime = ""

            if ($MatchesInCloud.Count -eq 1) {
                $EventTime = (
                    [DateTimeOffset]::FromUnixTimeMilliseconds(
                        [long]$MatchesInCloud[0].timestamp
                    )
                ).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ")

                $IngestionTime = (
                    [DateTimeOffset]::FromUnixTimeMilliseconds(
                        [long]$MatchesInCloud[0].ingestionTime
                    )
                ).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            }

            [pscustomobject]@{
                Sequence         = $Index + 1
                Level            = $Levels[$Index]
                LocalConfirmed   = $true
                CloudConfirmed   = ($MatchesInCloud.Count -eq 1)
                TimestampUtc     = $EventTime
                IngestionTimeUtc = $IngestionTime
                Message          = $ExpectedLine
            }
        }
    )

    $ConfirmedCount = @(
        $Results | Where-Object CloudConfirmed -eq $true
    ).Count

    if ($CloudEvents.Count -gt $ConfirmedCount) {
        throw "Foram encontrados eventos adicionais com o mesmo marcador."
    }

    $Receipt.LocalEvents = $LocalLines
    $Receipt.CloudConfirmed = ($ConfirmedCount -eq 3)
    Save-Lab26LogReceipt

    $ReportPath = Join-Path $LocalDirectory (
        "log-events-result-{0}-{1}.json" -f
        $Receipt.BatchId,
        $CheckedAt.UtcDateTime.ToString("yyyyMMddTHHmmssfffZ")
    )

    $Report = [ordered]@{
        AccountId        = $State.AccountId
        Region           = $State.Region
        RunId            = $State.RunId
        InstanceId       = $InstanceId
        BatchId          = $Receipt.BatchId
        Marker           = $Receipt.Marker
        CheckedAtUtc     = $CheckedAt.UtcDateTime.ToString("o")
        LogGroupName     = $Settings.Logs.LogGroupName
        LogStreamName    = $InstanceId
        ExpectedCount    = 3
        ConfirmedCount   = $ConfirmedCount
        CloudConfirmed   = $Receipt.CloudConfirmed
        Events           = $Results
        CommandInvocation = $Invocation
    }

    $Utf8 = New-Object System.Text.UTF8Encoding($false)

    [IO.File]::WriteAllText(
        $ReportPath,
        (ConvertTo-Json -InputObject $Report -Depth 30),
        $Utf8
    )

    $Results |
        Select-Object Sequence, Level, LocalConfirmed,
            CloudConfirmed, TimestampUtc, IngestionTimeUtc |
        Format-Table -AutoSize

    $Results | Select-Object Sequence, Message | Format-List

    Write-Host "Eventos confirmados na AWS: $ConfirmedCount de 3."
    Write-Host "Relatorio local: $ReportPath"

    if ($Receipt.CloudConfirmed) {
        Write-Host (
            "[OK] As tres linhas locais chegaram ao CloudWatch Logs."
        ) -ForegroundColor Green
    }
    else {
        Write-Host (
            "[PENDENTE] Repita apenas CheckStatus apos alguns segundos."
        ) -ForegroundColor Yellow
    }

    return
}

if (Test-Path -LiteralPath $ReceiptPath -PathType Leaf) {
    throw "Ja existe um recibo deste lote. Use CheckStatus."
}

& (Join-Path $PSScriptRoot "remove-aws-cloudwatch-agent.ps1") `
    -ProfileName $ProfileName `
    -ValidateOnly

$Response = Invoke-Lab26Aws `
    -Service "ec2" `
    -Operation "describe-instances" `
    -Request @{ InstanceIds = @($InstanceId) }

$Instances = @(
    foreach ($Reservation in $Response.Reservations) {
        foreach ($Instance in $Reservation.Instances) {
            $Instance
        }
    }
)

if (
    $Instances.Count -ne 1 -or
    $Instances[0].State.Name -ne "running"
) {
    throw "A instancia nao esta running."
}

$Ssm = Invoke-Lab26Aws `
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

$Managed = @($Ssm.InstanceInformationList)

if (
    $Managed.Count -ne 1 -or
    $Managed[0].PingStatus -ne "Online"
) {
    throw "A instancia nao esta Online no SSM."
}

if ($ValidateOnly) {
    Write-Host (
        "[OK] Inventario, propriedade, EC2 e SSM conferidos."
    ) -ForegroundColor Green

    Write-Host (
        "[OK] ValidateOnly: nenhum evento enviado."
    ) -ForegroundColor Green

    return
}

$BatchId = [guid]::NewGuid().ToString()
$Marker = "LAB26_LOG_TEST_$BatchId"

$ShellCommand = @'
#!/bin/sh
set -eu
systemctl is-active --quiet amazon-cloudwatch-agent
test -f /var/log/lab26/application.log
python3 - <<'PY'
import datetime
import pathlib
import time

run_id = "__RUN_ID__"
batch_id = "__BATCH_ID__"
marker = "__MARKER__"
path = pathlib.Path("/var/log/lab26/application.log")

with path.open("r", encoding="utf-8") as stream:
    if marker in stream.read():
        raise SystemExit("Marker already present; batch not repeated")

expected = []
with path.open("a", encoding="utf-8") as stream:
    for sequence, level in enumerate(("INFO", "WARN", "ERROR"), 1):
        timestamp = datetime.datetime.now(
            datetime.timezone.utc
        ).strftime("%Y-%m-%dT%H:%M:%SZ")
        line = (
            f"{timestamp} {level} RunId={run_id} "
            f"BatchId={batch_id} Marker={marker} "
            f"Sequence={sequence} Message=Synthetic{level}"
        )
        stream.write(line + "\n")
        stream.flush()
        expected.append(line)
        time.sleep(1)

with path.open("r", encoding="utf-8") as stream:
    actual = [
        line.rstrip("\r\n")
        for line in stream
        if marker in line
    ]

if actual != expected:
    raise SystemExit("Local event verification failed")

for line in actual:
    print("LOCAL_EVENT=" + line)

print("LOCAL_EVENTS=3")
print("LOG_BATCH_COMPLETE=" + batch_id)
PY
'@

$ShellCommand = $ShellCommand.Replace(
    "__RUN_ID__", [string]$State.RunId
).Replace(
    "__BATCH_ID__", $BatchId
).Replace(
    "__MARKER__", $Marker
)

$ShellCommand = $ShellCommand.Replace("`r`n", "`n").Replace("`r", "`n")

$script:Receipt = [pscustomobject][ordered]@{
    AccountId        = $State.AccountId
    Region           = $State.Region
    RunId            = $State.RunId
    InstanceId       = $InstanceId
    LogGroupName     = $Settings.Logs.LogGroupName
    BatchId          = $BatchId
    Marker           = $Marker
    ExpectedCount    = 3
    CommandId        = ""
    RequestedAtUtc   = [DateTime]::UtcNow.ToString("o")
    CommandStatus    = "Prepared"
    LastCheckedAtUtc = ""
    LocalEvents      = @()
    CloudConfirmed   = $false
}

# Preserva a tentativa antes de enviar o comando.
Save-Lab26LogReceipt

try {
    $Sent = Invoke-Lab26Aws `
        -Service "ssm" `
        -Operation "send-command" `
        -Request @{
            DocumentName   = "AWS-RunShellScript"
            InstanceIds    = @($InstanceId)
            Comment        = "LAB26 synthetic logs $BatchId"
            TimeoutSeconds = 120
            MaxConcurrency = "1"
            MaxErrors      = "0"
            Parameters     = @{
                commands         = @($ShellCommand)
                executionTimeout = @("120")
            }
        }

    $ParsedCommandId = [guid]::Empty

    if (
        -not [guid]::TryParse(
            [string]$Sent.Command.CommandId,
            [ref]$ParsedCommandId
        )
    ) {
        throw "O envio nao retornou um CommandId valido."
    }

    $Receipt.CommandId = [string]$Sent.Command.CommandId
    $Receipt.CommandStatus = "Submitted"
    Save-Lab26LogReceipt

    Write-Host ""
    Write-Host "LAB 26 - Lote enviado" -ForegroundColor Cyan

    [pscustomobject]@{
        InstanceId = $InstanceId
        CommandId  = $Receipt.CommandId
        BatchId    = $BatchId
        Marker     = $Marker
        Events     = 3
        ReceiptPath = $ReceiptPath
    } | Format-List

    Write-Host (
        "[OK] Comando enviado. Confira com CheckStatus."
    ) -ForegroundColor Green
}
catch {
    Write-Host (
        "Recibo preservado: $ReceiptPath"
    ) -ForegroundColor Yellow

    Write-Host (
        "Nao reenvie antes de conferir o resultado desta tentativa."
    ) -ForegroundColor Yellow

    throw
}
