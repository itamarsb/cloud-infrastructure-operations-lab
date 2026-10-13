[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$EmailAddress,
    [switch]$ValidateOnly,
    [switch]$CheckStatus
)

$ErrorActionPreference = "Stop"

if ($ValidateOnly -and $CheckStatus) {
    throw "Use ValidateOnly ou CheckStatus separadamente."
}

. (Join-Path $PSScriptRoot "lab27-common.ps1")

Initialize-Lab27 -ProfileName $ProfileName

$Deployment = Read-Lab27Json -Path $script:StatePath

$AccountId = $Settings.ExpectedAccountId
$Region = $Settings.Region

$TopicArn = (
    "arn:aws:sns:${Region}:${AccountId}:$($Settings.Names.Topic)"
)

Assert-Lab27Section -Document $Deployment `
    -SectionName "Deployment" -Expected @{
        SchemaVersion = 1
        Lab = "27"
        AccountId = $AccountId
        Region = $Region
        Status = "Deployed"
        TopicArn = $TopicArn
        TopicName = $Settings.Names.Topic
        TopicConfirmed = $true
        PolicyConfirmed = $true
        AlarmConfirmed = $true
    }

if (
    $Deployment.RunId -isnot [string] -or
    $Deployment.RunId -cnotmatch '^\d{8}T\d{6}Z-[0-9a-f]{8}$'
) {
    throw "RunId invalido no inventario."
}

$CleanupProperty = $Deployment.PSObject.Properties["CleanupStatus"]

if (
    $null -ne $CleanupProperty -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$CleanupProperty.Value
    )
) {
    throw "Existe registro de cleanup. Confira os recursos antes de assinar."
}

$Topic = Invoke-Lab27Aws `
    -Service "sns" `
    -Operation "get-topic-attributes" `
    -Request @{ TopicArn = $TopicArn }

if (
    $Topic.Attributes.TopicArn -cne $TopicArn -or
    $Topic.Attributes.Owner -cne $AccountId
) {
    throw "O topico nao corresponde ao inventario."
}

$TagResult = Invoke-Lab27Aws `
    -Service "sns" `
    -Operation "list-tags-for-resource" `
    -Request @{ ResourceArn = $TopicArn }

$ExpectedTags = @{
    Name = $Settings.Names.Topic
    Project = $Settings.Tags.Project
    Lab = $Settings.Tags.Lab
    ManagedBy = $Settings.Tags.ManagedBy
    RunId = $Deployment.RunId
}

foreach ($Key in $ExpectedTags.Keys) {
    $Matches = @(
        $TagResult.Tags | Where-Object {
            $_.Key -ceq $Key -and
            $_.Value -ceq $ExpectedTags[$Key]
        }
    )

    if ($Matches.Count -ne 1) {
        throw "Propriedade do topico nao confirmada: tag $Key."
    }
}

$script:ReceiptPath = Join-Path $script:LocalDirectory (
    "email-subscription-$($Deployment.RunId).json"
)

function Save-Lab27EmailReceipt {
    $Token = [guid]::NewGuid().ToString("N")

    $TemporaryPath = Join-Path $script:LocalDirectory (
        "email-subscription-$Token.tmp"
    )

    $BackupPath = Join-Path $script:LocalDirectory (
        "email-subscription-$Token.bak"
    )

    $Utf8 = New-Object System.Text.UTF8Encoding($false)

    try {
        $Json = ConvertTo-Json -InputObject $script:Receipt -Depth 20
        [IO.File]::WriteAllText($TemporaryPath, $Json, $Utf8)

        [IO.File]::Replace(
            $TemporaryPath,
            $script:ReceiptPath,
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

function Get-Lab27EmailSubscriptions {
    $Result = Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "list-subscriptions-by-topic" `
        -Request @{ TopicArn = $TopicArn }

    return @($Result.Subscriptions)
}

if ($CheckStatus) {
    $script:Receipt = Read-Lab27Json -Path $script:ReceiptPath

    Assert-Lab27Section -Document $script:Receipt `
        -SectionName "Receipt" -Expected @{
            SchemaVersion = 1
            RunId = $Deployment.RunId
            AccountId = $AccountId
            TopicArn = $TopicArn
            Protocol = "email"
        }

    if ([string]::IsNullOrWhiteSpace($script:Receipt.EmailAddress)) {
        throw "Recibo sem endereco de e-mail."
    }

    $Subscriptions = @(Get-Lab27EmailSubscriptions)

    if ($Subscriptions.Count -gt 1) {
        throw "Mais de uma assinatura encontrada. Confira o topico."
    }

    if ($Subscriptions.Count -eq 0) {
        Write-Host (
            "[PENDENTE] Assinatura ainda nao encontrada. " +
            "Repita CheckStatus; nao reenvie a solicitacao."
        ) -ForegroundColor Yellow

        return
    }

    $Subscription = $Subscriptions[0]

    if (
        $Subscription.TopicArn -cne $TopicArn -or
        $Subscription.Owner -cne $AccountId -or
        $Subscription.Protocol -cne "email" -or
        $Subscription.Endpoint -ine $script:Receipt.EmailAddress
    ) {
        throw "A assinatura encontrada difere da registrada."
    }

    if (
        -not ([string]$Subscription.SubscriptionArn).StartsWith(
            $TopicArn + ":",
            [StringComparison]::Ordinal
        )
    ) {
        $script:Receipt.Status = "PendingConfirmation"
        Save-Lab27EmailReceipt

        Write-Host (
            "[PENDENTE] Abra o e-mail do SNS e confirme a assinatura."
        ) -ForegroundColor Yellow

        return
    }

    $Result = Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "get-subscription-attributes" `
        -Request @{
            SubscriptionArn = $Subscription.SubscriptionArn
        }

    $Attributes = $Result.Attributes

    if (
        $Attributes.TopicArn -cne $TopicArn -or
        $Attributes.Owner -cne $AccountId -or
        $Attributes.Protocol -cne "email" -or
        $Attributes.Endpoint -ine $script:Receipt.EmailAddress -or
        $Attributes.SubscriptionArn -cne $Subscription.SubscriptionArn
    ) {
        throw "Atributos da assinatura diferentes dos previstos."
    }

    if ($Attributes.PendingConfirmation -ceq "true") {
        $script:Receipt.Status = "PendingConfirmation"
        Save-Lab27EmailReceipt

        Write-Host "[PENDENTE] Assinatura ainda nao confirmada." `
            -ForegroundColor Yellow

        return
    }

    if ($Attributes.PendingConfirmation -cne "false") {
        throw "Estado de confirmacao inesperado."
    }

    $script:Receipt.Status = "Confirmed"
    $script:Receipt.SubscriptionArn = $Subscription.SubscriptionArn
    $script:Receipt.ConfirmedObservedAtUtc = (
        [DateTime]::UtcNow.ToString("o")
    )

    Save-Lab27EmailReceipt

    Write-Host "[OK] Assinatura de e-mail confirmada na AWS." `
        -ForegroundColor Green

    Write-Host "[INFO] RunId: $($Deployment.RunId)"
    Write-Host "[INFO] Recibo: $script:ReceiptPath"

    return
}

if ([string]::IsNullOrWhiteSpace($EmailAddress)) {
    throw "Informe EmailAddress."
}

$EmailAddress = $EmailAddress.Trim()

try {
    $ParsedEmail = New-Object System.Net.Mail.MailAddress($EmailAddress)
}
catch {
    throw "Endereco de e-mail invalido."
}

if (
    $ParsedEmail.Address -ine $EmailAddress -or
    -not [string]::IsNullOrWhiteSpace($ParsedEmail.DisplayName)
) {
    throw "Informe somente o endereco, sem nome de exibicao."
}

if (Test-Path -LiteralPath $script:ReceiptPath) {
    throw (
        "Ja existe recibo desta execucao. " +
        "Use CheckStatus para evitar reenvio."
    )
}

$Subscriptions = @(Get-Lab27EmailSubscriptions)

if ($Subscriptions.Count -ne 0) {
    throw "O topico ja possui assinatura. Confira antes de prosseguir."
}

Write-Host "[OK] Inventario e propriedade do topico conferidos." `
    -ForegroundColor Green

Write-Host "[OK] Formato do endereco conferido." `
    -ForegroundColor Green

Write-Host "[OK] Nenhuma assinatura preexistente." `
    -ForegroundColor Green

if ($ValidateOnly) {
    Write-Host (
        "[OK] Pre-validacao concluida. " +
        "Nenhuma solicitacao de assinatura foi enviada."
    ) -ForegroundColor Green

    return
}

$script:Receipt = [ordered]@{
    SchemaVersion = 1
    RunId = $Deployment.RunId
    AccountId = $AccountId
    TopicArn = $TopicArn
    Protocol = "email"
    EmailAddress = $EmailAddress
    RequestedAtUtc = [DateTime]::UtcNow.ToString("o")
    Status = "Requesting"
    SubscriptionArn = $null
    ConfirmedObservedAtUtc = $null
    LastError = $null
}

$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Json = ConvertTo-Json -InputObject $script:Receipt -Depth 20
$Bytes = $Utf8.GetBytes($Json)

$Stream = [IO.File]::Open(
    $script:ReceiptPath,
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
    $Response = Invoke-Lab27Aws `
        -Service "sns" `
        -Operation "subscribe" `
        -Request @{
            TopicArn = $TopicArn
            Protocol = "email"
            Endpoint = $EmailAddress
            ReturnSubscriptionArn = $true
        }

    if (
        -not ([string]$Response.SubscriptionArn).StartsWith(
            $TopicArn + ":",
            [StringComparison]::Ordinal
        )
    ) {
        throw "ARN de assinatura inesperado."
    }

    $script:Receipt.SubscriptionArn = $Response.SubscriptionArn
    $script:Receipt.Status = "PendingConfirmation"
    Save-Lab27EmailReceipt

    Write-Host "[OK] Solicitacao de assinatura aceita pelo SNS." `
        -ForegroundColor Green

    Write-Host "[INFO] Abra o e-mail e clique em Confirm subscription."
    Write-Host "[INFO] Depois execute somente CheckStatus."
    Write-Host "[INFO] Recibo: $script:ReceiptPath"
}
catch {
    $OriginalError = $_

    $script:Receipt.Status = "RequestFailedOrUnknown"
    $script:Receipt.LastError = $OriginalError.Exception.Message

    try {
        Save-Lab27EmailReceipt
    }
    catch {
        Write-Warning "Nao foi possivel atualizar o recibo."
    }

    Write-Warning (
        "Preserve o recibo e consulte CheckStatus antes de qualquer reenvio."
    )

    throw $OriginalError
}
