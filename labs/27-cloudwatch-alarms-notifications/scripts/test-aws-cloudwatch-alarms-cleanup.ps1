[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab27-common.ps1")

Initialize-Lab27 -ProfileName $ProfileName

$Deployment = Read-Lab27Json -Path $script:StatePath

$AccountId = $Settings.ExpectedAccountId
$Region = $Settings.Region

$TopicArn = (
    "arn:aws:sns:${Region}:${AccountId}:$($Settings.Names.Topic)"
)

$AlarmArn = (
    "arn:aws:cloudwatch:${Region}:${AccountId}:" +
    "alarm:$($Settings.Names.Alarm)"
)

Assert-Lab27Section -Document $Deployment `
    -SectionName "Deployment" -Expected @{
        SchemaVersion = 1
        Lab = "27"
        AccountId = $AccountId
        Region = $Region
        TopicName = $Settings.Names.Topic
        TopicArn = $TopicArn
        AlarmName = $Settings.Names.Alarm
        AlarmArn = $AlarmArn
    }

if (
    $Deployment.RunId -isnot [string] -or
    $Deployment.RunId -cnotmatch '^\d{8}T\d{6}Z-[0-9a-f]{8}$'
) {
    throw "RunId invalido no inventario."
}

# A confirmacao depende das consultas AWS,
# e nao do status de cleanup registrado localmente.

$AlarmResult = Invoke-Lab27Aws `
    -Service "cloudwatch" `
    -Operation "describe-alarms" `
    -Request @{
        AlarmNames = @($Settings.Names.Alarm)
        AlarmTypes = @("MetricAlarm", "CompositeAlarm")
    }

$MetricAlarmCount = @($AlarmResult.MetricAlarms).Count
$CompositeAlarmCount = @($AlarmResult.CompositeAlarms).Count

$AlarmAbsent = (
    $MetricAlarmCount -eq 0 -and
    $CompositeAlarmCount -eq 0
)

$TopicResult = Invoke-Lab27Aws `
    -Service "sns" `
    -Operation "get-topic-attributes" `
    -Request @{ TopicArn = $TopicArn } `
    -AbsentCodes @("NotFound")

$TopicAbsent = ($null -eq $TopicResult)

$Checks = @(
    [pscustomobject]@{
        Resource = "CloudWatch alarm"
        Identifier = $AlarmArn
        Absent = $AlarmAbsent
    }
    [pscustomobject]@{
        Resource = "SNS topic"
        Identifier = $TopicArn
        Absent = $TopicAbsent
    }
)

$PassedCount = @(
    $Checks | Where-Object { $_.Absent -eq $true }
).Count

$Report = [ordered]@{
    RunId = $Deployment.RunId
    AccountId = $AccountId
    Region = $Region
    ObservedAtUtc = [DateTime]::UtcNow.ToString("o")
    PassedCount = $PassedCount
    TotalChecks = $Checks.Count
    Checks = $Checks
}

$ReportPath = Join-Path $script:LocalDirectory (
    "cleanup-validation-$($Deployment.RunId)-" +
    [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") +
    "-" + [guid]::NewGuid().ToString("N") + ".json"
)

$Utf8 = New-Object System.Text.UTF8Encoding($false)

[IO.File]::WriteAllText(
    $ReportPath,
    (ConvertTo-Json -InputObject $Report -Depth 20),
    $Utf8
)

foreach ($Check in $Checks) {
    if ($Check.Absent) {
        Write-Host "[OK] Ausente: $($Check.Resource)" `
            -ForegroundColor Green
    }
    else {
        Write-Host "[PENDENTE] Ainda existe: $($Check.Resource)" `
            -ForegroundColor Yellow
    }
}

Write-Host "[INFO] Relatorio: $ReportPath"

if ($PassedCount -ne $Checks.Count) {
    throw (
        "Cleanup ainda nao confirmado: " +
        "$PassedCount de $($Checks.Count) verificacoes."
    )
}

Write-Host "[OK] Cleanup confirmado: 2 de 2 verificacoes." `
    -ForegroundColor Green
