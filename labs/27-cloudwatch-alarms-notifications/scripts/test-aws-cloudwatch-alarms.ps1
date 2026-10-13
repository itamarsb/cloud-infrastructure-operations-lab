[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [ValidateRange(5, 120)]
    [int]$WindowMinutes = 30,

    [switch]$PassThru
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
        Status = "Deployed"
        TopicArn = $TopicArn
        AlarmArn = $AlarmArn
        TopicConfirmed = $true
        PolicyConfirmed = $true
        AlarmConfirmed = $true
    }

if (
    $Deployment.RunId -isnot [string] -or
    $Deployment.RunId -cnotmatch '^\d{8}T\d{6}Z-[0-9a-f]{8}$'
) {
    throw "RunId invalido."
}

$CleanupProperty = $Deployment.PSObject.Properties["CleanupStatus"]

if (
    $null -ne $CleanupProperty -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$CleanupProperty.Value
    )
) {
    throw "Existe registro de cleanup. Confira o inventario."
}

$Dimensions = @(
    @{ Name = "Scenario"; Value = $Settings.Metric.Scenario }
    @{ Name = "RunId"; Value = $Deployment.RunId }
)

$Result = Invoke-Lab27Aws `
    -Service "cloudwatch" `
    -Operation "describe-alarms" `
    -Request @{
        AlarmNames = @($Settings.Names.Alarm)
        AlarmTypes = @("MetricAlarm", "CompositeAlarm")
    }

if (
    @($Result.MetricAlarms).Count -ne 1 -or
    @($Result.CompositeAlarms).Count -ne 0
) {
    throw "O alarme esperado nao foi encontrado."
}

$Alarm = $Result.MetricAlarms[0]

Assert-Lab27Section -Document $Alarm `
    -SectionName "Alarm" -Expected @{
        AlarmArn = $AlarmArn
        Namespace = $Settings.Metric.Namespace
        MetricName = $Settings.Metric.MetricName
        Unit = $Settings.Metric.Unit
        Statistic = $Settings.Alarm.Statistic
        Period = $Settings.Alarm.PeriodSeconds
        EvaluationPeriods = $Settings.Alarm.EvaluationPeriods
        DatapointsToAlarm = $Settings.Alarm.DatapointsToAlarm
        ComparisonOperator = $Settings.Alarm.ComparisonOperator
        TreatMissingData = $Settings.Alarm.TreatMissingData
        ActionsEnabled = $true
    }

if ($Alarm.Threshold -ne $Settings.Alarm.Threshold) {
    throw "Threshold diferente do previsto."
}

if (@($Alarm.Dimensions).Count -ne $Dimensions.Count) {
    throw "Quantidade de dimensoes diferente da prevista."
}

foreach ($Dimension in $Dimensions) {
    $Matches = @(
        $Alarm.Dimensions | Where-Object {
            $_.Name -ceq $Dimension.Name -and
            $_.Value -ceq $Dimension.Value
        }
    )

    if ($Matches.Count -ne 1) {
        throw "Dimensao diferente: $($Dimension.Name)"
    }
}

foreach ($ActionName in @("AlarmActions", "OKActions")) {
    $Actions = @($Alarm.$ActionName)

    if ($Actions.Count -ne 1 -or $Actions[0] -cne $TopicArn) {
        throw "Acao diferente do previsto: $ActionName"
    }
}

if (@($Alarm.InsufficientDataActions).Count -ne 0) {
    throw "Acao inesperada para INSUFFICIENT_DATA."
}

foreach ($Resource in @(
    @{ Service = "sns"; Arn = $TopicArn; Name = $Settings.Names.Topic }
    @{ Service = "cloudwatch"; Arn = $AlarmArn; Name = $Settings.Names.Alarm }
)) {
    $Request = @{ ResourceArn = $Resource.Arn }

    if ($Resource.Service -ceq "cloudwatch") {
        $Request = @{ ResourceARN = $Resource.Arn }
    }

    $Tags = Invoke-Lab27Aws `
        -Service $Resource.Service `
        -Operation "list-tags-for-resource" `
        -Request $Request

    $ExpectedTags = @{
        Name = $Resource.Name
        Project = $Settings.Tags.Project
        Lab = $Settings.Tags.Lab
        ManagedBy = $Settings.Tags.ManagedBy
        RunId = $Deployment.RunId
    }

    foreach ($Key in $ExpectedTags.Keys) {
        $Matches = @(
            $Tags.Tags | Where-Object {
                $_.Key -ceq $Key -and
                $_.Value -ceq $ExpectedTags[$Key]
            }
        )

        if ($Matches.Count -ne 1) {
            throw "Tag diferente: $Key em $($Resource.Name)"
        }
    }
}

$Topic = Invoke-Lab27Aws `
    -Service "sns" `
    -Operation "get-topic-attributes" `
    -Request @{ TopicArn = $TopicArn }

if (
    $Topic.Attributes.TopicArn -cne $TopicArn -or
    $Topic.Attributes.Owner -cne $AccountId
) {
    throw "Topico diferente do previsto."
}

$ReceiptPath = Join-Path $script:LocalDirectory (
    "email-subscription-$($Deployment.RunId).json"
)

$Receipt = Read-Lab27Json -Path $ReceiptPath

Assert-Lab27Section -Document $Receipt `
    -SectionName "EmailReceipt" -Expected @{
        SchemaVersion = 1
        RunId = $Deployment.RunId
        AccountId = $AccountId
        TopicArn = $TopicArn
        Protocol = "email"
        Status = "Confirmed"
    }

$Subscription = Invoke-Lab27Aws `
    -Service "sns" `
    -Operation "get-subscription-attributes" `
    -Request @{
        SubscriptionArn = $Receipt.SubscriptionArn
    }

$Attributes = $Subscription.Attributes

if (
    $Attributes.TopicArn -cne $TopicArn -or
    $Attributes.Owner -cne $AccountId -or
    $Attributes.Protocol -cne "email" -or
    $Attributes.Endpoint -ine $Receipt.EmailAddress -or
    $Attributes.PendingConfirmation -cne "false"
) {
    throw "Assinatura ativa nao confirmada."
}

$NowUtc = [DateTime]::UtcNow

$EndUtc = $NowUtc.AddTicks(
    -($NowUtc.Ticks % [TimeSpan]::TicksPerMinute)
)

$StartUtc = $EndUtc.AddMinutes(-$WindowMinutes)

$MetricResult = Invoke-Lab27Aws `
    -Service "cloudwatch" `
    -Operation "get-metric-statistics" `
    -Request @{
        Namespace = $Settings.Metric.Namespace
        MetricName = $Settings.Metric.MetricName
        Dimensions = $Dimensions
        Unit = $Settings.Metric.Unit
        StartTime = $StartUtc.ToString("o")
        EndTime = $EndUtc.ToString("o")
        Period = $Settings.Alarm.PeriodSeconds
        Statistics = @("Sum", "SampleCount")
    }

$Points = @(
    $MetricResult.Datapoints | Sort-Object Timestamp
)

$History = Invoke-Lab27Aws `
    -Service "cloudwatch" `
    -Operation "describe-alarm-history" `
    -Request @{
        AlarmName = $Settings.Names.Alarm
        StartDate = $StartUtc.ToString("o")
        EndDate = $NowUtc.ToString("o")
    }

$Report = [pscustomobject][ordered]@{
    RunId = $Deployment.RunId
    ObservedAtUtc = [DateTime]::UtcNow.ToString("o")
    AlarmName = $Settings.Names.Alarm
    AlarmState = $Alarm.StateValue
    StateUpdatedTimestamp = $Alarm.StateUpdatedTimestamp
    StateReason = $Alarm.StateReason
    ConfigurationChecked = $true
    ResourceTagsChecked = $true
    EmailSubscriptionConfirmed = $true
    Namespace = $Settings.Metric.Namespace
    MetricName = $Settings.Metric.MetricName
    Dimensions = $Dimensions
    StartUtc = $StartUtc.ToString("o")
    EndUtcExclusive = $EndUtc.ToString("o")
    PeriodSeconds = $Settings.Alarm.PeriodSeconds
    Datapoints = $Points
    AlarmHistory = @($History.AlarmHistoryItems)
}

$ReportPath = Join-Path $script:LocalDirectory (
    "alarm-validation-$($Deployment.RunId)-" +
    [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") +
    "-" + [guid]::NewGuid().ToString("N") + ".json"
)

$Utf8 = New-Object System.Text.UTF8Encoding($false)

[IO.File]::WriteAllText(
    $ReportPath,
    (ConvertTo-Json -InputObject $Report -Depth 40),
    $Utf8
)

Write-Host "[OK] Configuracao, dimensoes, acoes e tags conferidas." `
    -ForegroundColor Green

Write-Host "[OK] Assinatura de e-mail continua confirmada." `
    -ForegroundColor Green

Write-Host "[INFO] Estado observado: $($Alarm.StateValue)"
Write-Host "[INFO] Motivo: $($Alarm.StateReason)"
Write-Host "[INFO] Pontos em periodos completos: $($Points.Count)"

if ($Points.Count -gt 0) {
    $Points |
        Select-Object Timestamp, Sum, SampleCount, Unit |
        Format-Table -AutoSize |
        Out-Host
}
else {
    Write-Host "[INFO] Sem pontos na janela; ausencia nao significa zero."
}

Write-Host "[INFO] Relatorio: $ReportPath"

if ($PassThru) {
    return $Report
}
