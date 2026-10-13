[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab27-common.ps1")

Initialize-Lab27 -ProfileName $ProfileName

$script:Inventory = Read-Lab27Json -Path $script:StatePath

$AccountId = $Settings.ExpectedAccountId
$Region = $Settings.Region

$ExpectedTopicArn = (
    "arn:aws:sns:${Region}:${AccountId}:$($Settings.Names.Topic)"
)

$ExpectedAlarmArn = (
    "arn:aws:cloudwatch:${Region}:${AccountId}:" +
    "alarm:$($Settings.Names.Alarm)"
)

Assert-Lab27Section -Document $script:Inventory `
    -SectionName "Inventory" -Expected @{
        SchemaVersion = 1
        Lab = "27"
        AccountId = $AccountId
        Region = $Region
        TopicName = $Settings.Names.Topic
        TopicArn = $ExpectedTopicArn
        AlarmName = $Settings.Names.Alarm
        AlarmArn = $ExpectedAlarmArn
        Namespace = $Settings.Metric.Namespace
        MetricName = $Settings.Metric.MetricName
    }

if (
    $script:Inventory.RunId -isnot [string] -or
    $script:Inventory.RunId -cnotmatch
        '^\d{8}T\d{6}Z-[0-9a-f]{8}$'
) {
    throw "RunId ausente ou invalido no inventario."
}

foreach ($Field in @("TopicRequested", "AlarmRequested")) {
    $Property = $script:Inventory.PSObject.Properties[$Field]

    if (
        $null -eq $Property -or
        $Property.Value -isnot [bool]
    ) {
        throw "Campo invalido no inventario: $Field"
    }
}

function Get-Lab27CleanupAlarm {
    $Result = Invoke-Lab27Aws `
        -Service "cloudwatch" `
        -Operation "describe-alarms" `
        -Request @{
            AlarmNames = @($Settings.Names.Alarm)
            AlarmTypes = @("MetricAlarm", "CompositeAlarm")
        }

    if (@($Result.CompositeAlarms).Count -ne 0) {
        throw "O nome previsto pertence a um alarme composto."
    }

    $MetricAlarms = @($Result.MetricAlarms)

    if ($MetricAlarms.Count -gt 1) {
        throw "Quantidade inesperada de alarmes."
    }

    if ($MetricAlarms.Count -eq 0) {
        return $null
    }

    return $MetricAlarms[0]
}

function Get-Lab27CleanupTopic {
    return (Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "get-topic-attributes" `
        -Request @{ TopicArn = $ExpectedTopicArn } `
        -AbsentCodes @("NotFound"))
}

function Assert-Lab27CleanupTags {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ActualTags,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $ExpectedTags = @{
        Name = $Name
        Project = $Settings.Tags.Project
        Lab = $Settings.Tags.Lab
        ManagedBy = $Settings.Tags.ManagedBy
        RunId = $script:Inventory.RunId
    }

    foreach ($Key in $ExpectedTags.Keys) {
        $Matches = @(
            $ActualTags | Where-Object {
                $_.Key -ceq $Key -and
                $_.Value -ceq $ExpectedTags[$Key]
            }
        )

        if ($Matches.Count -ne 1) {
            throw "Propriedade nao confirmada: tag $Key em $Name."
        }
    }
}

function Assert-Lab27AlarmOwnership {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Alarm
    )

    if (
        $script:Inventory.AlarmRequested -ne $true -or
        $Alarm.AlarmArn -cne $ExpectedAlarmArn
    ) {
        throw "O alarme nao corresponde ao recurso registrado."
    }

    $Tags = Invoke-Lab27Aws `
        -Service "cloudwatch" `
        -Operation "list-tags-for-resource" `
        -Request @{ ResourceARN = $ExpectedAlarmArn }

    Assert-Lab27CleanupTags `
        -ActualTags @($Tags.Tags) `
        -Name $Settings.Names.Alarm

    $Parents = Invoke-Lab27Aws `
        -Service "cloudwatch" `
        -Operation "describe-alarms" `
        -Request @{
            ParentsOfAlarmName = $Settings.Names.Alarm
        }

    if (@($Parents.CompositeAlarms).Count -ne 0) {
        throw "Existem alarmes compostos que dependem deste alarme."
    }
}

function Assert-Lab27TopicOwnership {
    if ($script:Inventory.TopicRequested -ne $true) {
        throw "O inventario nao registra solicitacao deste topico."
    }

    $Tags = Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "list-tags-for-resource" `
        -Request @{ ResourceArn = $ExpectedTopicArn }

    Assert-Lab27CleanupTags `
        -ActualTags @($Tags.Tags) `
        -Name $Settings.Names.Topic

    $Subscriptions = Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "list-subscriptions-by-topic" `
        -Request @{ TopicArn = $ExpectedTopicArn }

    $Items = @($Subscriptions.Subscriptions)

    if ($Items.Count -gt 1) {
        throw "Mais de uma assinatura encontrada. Revise antes do cleanup."
    }

    foreach ($Subscription in $Items) {
        if (
            $Subscription.TopicArn -cne $ExpectedTopicArn -or
            $Subscription.Owner -cne $AccountId -or
            $Subscription.Protocol -cne "email"
        ) {
            throw "Assinatura fora do cenario previsto."
        }
    }

    $AllAlarms = Invoke-Lab27Aws `
        -Service "cloudwatch" `
        -Operation "describe-alarms" `
        -Request @{
            AlarmTypes = @("MetricAlarm", "CompositeAlarm")
        }

    $Candidates = @($AllAlarms.MetricAlarms) +
        @($AllAlarms.CompositeAlarms)

    foreach ($Candidate in $Candidates) {
        if ($Candidate.AlarmArn -ceq $ExpectedAlarmArn) {
            continue
        }

        foreach ($ActionField in @(
            "AlarmActions",
            "OKActions",
            "InsufficientDataActions"
        )) {
            $Property = $Candidate.PSObject.Properties[$ActionField]

            if (
                $null -ne $Property -and
                @($Property.Value) -ccontains $ExpectedTopicArn
            ) {
                throw (
                    "Outro alarme utiliza o topico: " +
                    $Candidate.AlarmName
                )
            }
        }
    }

    Write-Host "[OK] Assinaturas e referencias CloudWatch conferidas." `
        -ForegroundColor Green
}

function Save-Lab27CleanupState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status,

        [string]$ErrorMessage = ""
    )

    $script:Inventory | Add-Member `
        -NotePropertyName "CleanupStatus" `
        -NotePropertyValue $Status -Force

    $script:Inventory | Add-Member `
        -NotePropertyName "CleanupUpdatedAtUtc" `
        -NotePropertyValue ([DateTime]::UtcNow.ToString("o")) -Force

    $script:Inventory | Add-Member `
        -NotePropertyName "LastCleanupError" `
        -NotePropertyValue $ErrorMessage -Force

    $Token = [guid]::NewGuid().ToString("N")

    $TemporaryPath = Join-Path $script:LocalDirectory (
        "cleanup-$Token.tmp"
    )

    $BackupPath = Join-Path $script:LocalDirectory (
        "cleanup-$Token.bak"
    )

    $Utf8 = New-Object System.Text.UTF8Encoding($false)

    try {
        $Json = ConvertTo-Json -InputObject $script:Inventory -Depth 40

        [IO.File]::WriteAllText(
            $TemporaryPath,
            $Json,
            $Utf8
        )

        [IO.File]::Replace(
            $TemporaryPath,
            $script:StatePath,
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

$Alarm = Get-Lab27CleanupAlarm
$Topic = Get-Lab27CleanupTopic

if ($null -ne $Alarm) {
    Assert-Lab27AlarmOwnership -Alarm $Alarm
    Write-Host "[OK] Propriedade e dependencias do alarme conferidas." `
        -ForegroundColor Green
}
else {
    Write-Host "[OK] Alarme ja ausente." -ForegroundColor Green
}

if ($null -ne $Topic) {
    Assert-Lab27TopicOwnership
    Write-Host "[OK] Propriedade do topico conferida." `
        -ForegroundColor Green
}
else {
    Write-Host "[OK] Topico ja ausente." -ForegroundColor Green
}

Write-Host "[INFO] RunId: $($script:Inventory.RunId)"
Write-Host "[INFO] Alarme: $ExpectedAlarmArn"
Write-Host "[INFO] Topico: $ExpectedTopicArn"

if ($ValidateOnly) {
    Write-Host (
        "[OK] Pre-validacao do cleanup concluida. " +
        "Nenhum recurso foi removido."
    ) -ForegroundColor Green

    return
}

try {
    Save-Lab27CleanupState -Status "Removing"

    $Alarm = Get-Lab27CleanupAlarm

    if ($null -ne $Alarm) {
        Assert-Lab27AlarmOwnership -Alarm $Alarm

        Invoke-Lab27Aws `
            -Service "cloudwatch" `
            -Operation "delete-alarms" `
            -Request @{
                AlarmNames = @($Settings.Names.Alarm)
            } | Out-Null
    }

    $AlarmAbsent = $false

    for ($Attempt = 1; $Attempt -le 6; $Attempt++) {
        if ($null -eq (Get-Lab27CleanupAlarm)) {
            $AlarmAbsent = $true
            break
        }

        if ($Attempt -lt 6) {
            Start-Sleep -Seconds 2
        }
    }

    if (-not $AlarmAbsent) {
        throw "Exclusao do alarme ainda nao confirmada."
    }

    Write-Host "[OK] Ausencia do alarme confirmada." `
        -ForegroundColor Green

    Save-Lab27CleanupState -Status "AlarmAbsent"

    $Topic = Get-Lab27CleanupTopic

    if ($null -ne $Topic) {
        Assert-Lab27TopicOwnership

        Invoke-Lab27Aws `
            -Service "sns" `
            -Operation "delete-topic" `
            -Request @{
                TopicArn = $ExpectedTopicArn
            } | Out-Null
    }

    $TopicAbsent = $false

    for ($Attempt = 1; $Attempt -le 6; $Attempt++) {
        if ($null -eq (Get-Lab27CleanupTopic)) {
            $TopicAbsent = $true
            break
        }

        if ($Attempt -lt 6) {
            Start-Sleep -Seconds 2
        }
    }

    if (-not $TopicAbsent) {
        throw "Exclusao do topico ainda nao confirmada."
    }

    if ($null -ne (Get-Lab27CleanupAlarm)) {
        throw "O alarme voltou a existir durante o cleanup."
    }

    Save-Lab27CleanupState -Status "Removed"

    Write-Host "[OK] Ausencia do topico confirmada." `
        -ForegroundColor Green

    Write-Host "[OK] Cleanup concluido; inventario preservado." `
        -ForegroundColor Green
}
catch {
    $OriginalError = $_

    try {
        Save-Lab27CleanupState `
            -Status "Failed" `
            -ErrorMessage $OriginalError.Exception.Message
    }
    catch {
        Write-Warning "Nao foi possivel atualizar o registro do cleanup."
    }

    Write-Warning "Preserve o inventario para investigar ou retomar."
    throw $OriginalError
}
