[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab27-common.ps1")

Initialize-Lab27 -ProfileName $ProfileName

function Save-Lab27Deployment {
    $TemporaryPath = Join-Path $script:LocalDirectory (
        "deployment-" + [guid]::NewGuid().ToString("N") + ".tmp"
    )

    $Utf8 = New-Object System.Text.UTF8Encoding($false)

    try {
        $Json = ConvertTo-Json -InputObject $script:Deployment -Depth 40
        [IO.File]::WriteAllText($TemporaryPath, $Json, $Utf8)

        [IO.File]::Replace(
            $TemporaryPath,
            $script:StatePath,
            $null
        )
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
    }
}

function Get-Lab27DeploymentTags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return @(
        @{ Key = "Name"; Value = $Name }
        @{ Key = "Project"; Value = $Settings.Tags.Project }
        @{ Key = "Lab"; Value = $Settings.Tags.Lab }
        @{ Key = "ManagedBy"; Value = $Settings.Tags.ManagedBy }
        @{ Key = "RunId"; Value = $script:Deployment.RunId }
    )
}

function Assert-Lab27DeploymentTags {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ActualTags,

        [Parameter(Mandatory = $true)]
        [object[]]$ExpectedTags
    )

    foreach ($ExpectedTag in $ExpectedTags) {
        $Matches = @(
            $ActualTags | Where-Object {
                $_.Key -ceq $ExpectedTag.Key -and
                $_.Value -ceq $ExpectedTag.Value
            }
        )

        if ($Matches.Count -ne 1) {
            throw "Tag ausente ou diferente: $($ExpectedTag.Key)"
        }
    }
}

$AccountId = $Settings.ExpectedAccountId
$Region = $Settings.Region

$TopicArn = "arn:aws:sns:${Region}:${AccountId}:$($Settings.Names.Topic)"
$AlarmArn = (
    "arn:aws:cloudwatch:${Region}:${AccountId}:" +
    "alarm:$($Settings.Names.Alarm)"
)

if (Test-Path -LiteralPath $script:StatePath) {
    throw (
        "Inventario existente: $script:StatePath. " +
        "Preserve-o e confira a execucao anterior."
    )
}

$ExistingTopic = Invoke-Lab27Aws `
    -Service "sns" `
    -Operation "get-topic-attributes" `
    -Request @{ TopicArn = $TopicArn } `
    -AbsentCodes @("NotFound")

if ($null -ne $ExistingTopic) {
    throw "O topico previsto ja existe. Deploy interrompido."
}

$ExistingAlarms = Invoke-Lab27Aws `
    -Service "cloudwatch" `
    -Operation "describe-alarms" `
    -Request @{
        AlarmNames = @($Settings.Names.Alarm)
        AlarmTypes = @("MetricAlarm", "CompositeAlarm")
    }

if (
    @($ExistingAlarms.MetricAlarms).Count -ne 0 -or
    @($ExistingAlarms.CompositeAlarms).Count -ne 0
) {
    throw "O nome do alarme ja esta ocupado. Deploy interrompido."
}

Write-Host "[OK] Inventario local ausente." -ForegroundColor Green
Write-Host "[OK] Nome do topico disponivel." -ForegroundColor Green
Write-Host "[OK] Nome do alarme disponivel." -ForegroundColor Green
Write-Host "[INFO] Topico previsto: $TopicArn"
Write-Host "[INFO] Alarme previsto: $AlarmArn"

if ($ValidateOnly) {
    Write-Host (
        "[OK] Pre-validacao concluida. " +
        "Nenhum recurso AWS foi criado."
    ) -ForegroundColor Green

    return
}

$RunId = (
    [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") +
    "-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
)

$script:Deployment = [ordered]@{
    SchemaVersion = 1
    Lab = "27"
    AccountId = $AccountId
    Region = $Region
    ProfileName = $ProfileName
    RunId = $RunId
    CreatedAtUtc = [DateTime]::UtcNow.ToString("o")
    Status = "Prepared"
    TopicName = $Settings.Names.Topic
    TopicArn = $TopicArn
    AlarmName = $Settings.Names.Alarm
    AlarmArn = $AlarmArn
    Namespace = $Settings.Metric.Namespace
    MetricName = $Settings.Metric.MetricName
    Dimensions = @(
        @{ Name = "Scenario"; Value = $Settings.Metric.Scenario }
        @{ Name = "RunId"; Value = $RunId }
    )
    TopicRequested = $false
    TopicConfirmed = $false
    PolicyConfirmed = $false
    AlarmRequested = $false
    AlarmConfirmed = $false
    CompletedAtUtc = $null
    LastError = $null
}

[IO.Directory]::CreateDirectory($script:LocalDirectory) | Out-Null

$Utf8 = New-Object System.Text.UTF8Encoding($false)
$InitialJson = ConvertTo-Json -InputObject $script:Deployment -Depth 40
$InitialBytes = $Utf8.GetBytes($InitialJson)

$Stream = [IO.File]::Open(
    $script:StatePath,
    [IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None
)

try {
    $Stream.Write($InitialBytes, 0, $InitialBytes.Length)
    $Stream.Flush()
}
finally {
    $Stream.Dispose()
}

try {
    $TopicTags = @(Get-Lab27DeploymentTags -Name $Settings.Names.Topic)

    $script:Deployment.Status = "CreatingTopic"
    $script:Deployment.TopicRequested = $true
    Save-Lab27Deployment

    $CreatedTopic = Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "create-topic" `
        -Request @{
            Name = $Settings.Names.Topic
            Tags = $TopicTags
        }

    if ($CreatedTopic.TopicArn -cne $TopicArn) {
        throw "O ARN retornado para o topico difere do previsto."
    }

    $TopicTagResult = Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "list-tags-for-resource" `
        -Request @{ ResourceArn = $TopicArn }

    Assert-Lab27DeploymentTags `
        -ActualTags @($TopicTagResult.Tags) `
        -ExpectedTags $TopicTags

    $script:Deployment.TopicConfirmed = $true
    Save-Lab27Deployment

    $TopicPolicy = @{
        Version = "2012-10-17"
        Statement = @(
            @{
                Sid = "AllowLab27AlarmPublish"
                Effect = "Allow"
                Principal = @{
                    Service = "cloudwatch.amazonaws.com"
                }
                Action = "sns:Publish"
                Resource = $TopicArn
                Condition = @{
                    StringEquals = @{
                        "aws:SourceAccount" = $AccountId
                    }
                    ArnEquals = @{
                        "aws:SourceArn" = $AlarmArn
                    }
                }
            }
        )
    }

    $PolicyJson = ConvertTo-Json -InputObject $TopicPolicy -Depth 20

    Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "set-topic-attributes" `
        -Request @{
            TopicArn = $TopicArn
            AttributeName = "Policy"
            AttributeValue = $PolicyJson
        } | Out-Null

    $TopicAttributes = Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "get-topic-attributes" `
        -Request @{ TopicArn = $TopicArn }

    $AppliedPolicy = ConvertFrom-Json -InputObject (
        $TopicAttributes.Attributes.Policy
    )

    $Statements = @($AppliedPolicy.Statement)

    if ($Statements.Count -ne 1) {
        throw "Quantidade inesperada de statements na politica SNS."
    }

    $Statement = $Statements[0]

    if (
        $AppliedPolicy.Version -cne "2012-10-17" -or
        $Statement.Effect -cne "Allow" -or
        $Statement.Principal.Service -cne "cloudwatch.amazonaws.com" -or
        $Statement.Action -cne "sns:Publish" -or
        $Statement.Resource -cne $TopicArn -or
        $Statement.Condition.StringEquals.'aws:SourceAccount' -cne
            $AccountId -or
        $Statement.Condition.ArnEquals.'aws:SourceArn' -cne
            $AlarmArn
    ) {
        throw "A politica SNS aplicada difere da prevista."
    }

    $script:Deployment.PolicyConfirmed = $true
    Save-Lab27Deployment

    $AlarmCheck = Invoke-Lab27Aws `
        -Service "cloudwatch" `
        -Operation "describe-alarms" `
        -Request @{
            AlarmNames = @($Settings.Names.Alarm)
            AlarmTypes = @("MetricAlarm", "CompositeAlarm")
        }

    if (
        @($AlarmCheck.MetricAlarms).Count -ne 0 -or
        @($AlarmCheck.CompositeAlarms).Count -ne 0
    ) {
        throw "O nome do alarme foi ocupado durante o deploy."
    }

    $AlarmTags = @(Get-Lab27DeploymentTags -Name $Settings.Names.Alarm)

    $AlarmRequest = @{
        AlarmName = $Settings.Names.Alarm
        AlarmDescription = (
            "LAB 27: erros sinteticos; 2 de 3 periodos; RunId=$RunId"
        )
        ActionsEnabled = $true
        AlarmActions = @($TopicArn)
        OKActions = @($TopicArn)
        InsufficientDataActions = @()
        Namespace = $Settings.Metric.Namespace
        MetricName = $Settings.Metric.MetricName
        Dimensions = $script:Deployment.Dimensions
        Unit = $Settings.Metric.Unit
        Statistic = $Settings.Alarm.Statistic
        Period = $Settings.Alarm.PeriodSeconds
        EvaluationPeriods = $Settings.Alarm.EvaluationPeriods
        DatapointsToAlarm = $Settings.Alarm.DatapointsToAlarm
        Threshold = $Settings.Alarm.Threshold
        ComparisonOperator = $Settings.Alarm.ComparisonOperator
        TreatMissingData = $Settings.Alarm.TreatMissingData
        Tags = $AlarmTags
    }

    $script:Deployment.Status = "CreatingAlarm"
    $script:Deployment.AlarmRequested = $true
    Save-Lab27Deployment

    Invoke-Lab27Aws `
        -Service "cloudwatch" `
        -Operation "put-metric-alarm" `
        -Request $AlarmRequest | Out-Null

    $AlarmTagResult = Invoke-Lab27Aws `
        -Service "cloudwatch" `
        -Operation "list-tags-for-resource" `
        -Request @{ ResourceARN = $AlarmArn }

    Assert-Lab27DeploymentTags `
        -ActualTags @($AlarmTagResult.Tags) `
        -ExpectedTags $AlarmTags

    $AlarmResult = Invoke-Lab27Aws `
        -Service "cloudwatch" `
        -Operation "describe-alarms" `
        -Request @{
            AlarmNames = @($Settings.Names.Alarm)
            AlarmTypes = @("MetricAlarm")
        }

    $Alarms = @($AlarmResult.MetricAlarms)

    if ($Alarms.Count -ne 1) {
        throw "O alarme nao foi encontrado apos sua criacao."
    }

    $Alarm = $Alarms[0]

    if (
        $Alarm.AlarmArn -cne $AlarmArn -or
        $Alarm.Namespace -cne $Settings.Metric.Namespace -or
        $Alarm.MetricName -cne $Settings.Metric.MetricName -or
        $Alarm.Unit -cne $Settings.Metric.Unit -or
        $Alarm.Statistic -cne $Settings.Alarm.Statistic -or
        $Alarm.Period -ne $Settings.Alarm.PeriodSeconds -or
        $Alarm.EvaluationPeriods -ne $Settings.Alarm.EvaluationPeriods -or
        $Alarm.DatapointsToAlarm -ne $Settings.Alarm.DatapointsToAlarm -or
        $Alarm.Threshold -ne $Settings.Alarm.Threshold -or
        $Alarm.ComparisonOperator -cne
            $Settings.Alarm.ComparisonOperator -or
        $Alarm.TreatMissingData -cne $Settings.Alarm.TreatMissingData -or
        $Alarm.ActionsEnabled -ne $true
    ) {
        throw "A configuracao aplicada ao alarme difere da prevista."
    }

    if (
        @($Alarm.Dimensions).Count -ne 2 -or
        @($Alarm.AlarmActions).Count -ne 1 -or
        $Alarm.AlarmActions[0] -cne $TopicArn -or
        @($Alarm.OKActions).Count -ne 1 -or
        $Alarm.OKActions[0] -cne $TopicArn -or
        @($Alarm.InsufficientDataActions).Count -ne 0
    ) {
        throw "Dimensoes ou acoes do alarme diferentes das previstas."
    }

    foreach ($ExpectedDimension in $script:Deployment.Dimensions) {
        $Matches = @(
            $Alarm.Dimensions | Where-Object {
                $_.Name -ceq $ExpectedDimension.Name -and
                $_.Value -ceq $ExpectedDimension.Value
            }
        )

        if ($Matches.Count -ne 1) {
            throw "Dimensao diferente: $($ExpectedDimension.Name)"
        }
    }

    $script:Deployment.AlarmConfirmed = $true
    $script:Deployment.Status = "Deployed"
    $script:Deployment.CompletedAtUtc = [DateTime]::UtcNow.ToString("o")
    Save-Lab27Deployment

    Write-Host "[OK] Topico e tags conferidos." -ForegroundColor Green
    Write-Host "[OK] Politica SNS conferida." -ForegroundColor Green
    Write-Host "[OK] Alarme, dimensoes e acoes conferidos." `
        -ForegroundColor Green
    Write-Host "[INFO] RunId: $RunId"
    Write-Host "[INFO] Inventario: $script:StatePath"
    Write-Host "[INFO] Assinatura de e-mail ainda pendente."
}
catch {
    $OriginalError = $_
    $script:Deployment.Status = "Failed"
    $script:Deployment.LastError = $OriginalError.Exception.Message

    try {
        Save-Lab27Deployment
    }
    catch {
        Write-Warning "Nao foi possivel atualizar o inventario da falha."
    }

    Write-Warning (
        "Preserve o inventario. Pode haver recursos parcialmente criados."
    )

    throw $OriginalError
}
