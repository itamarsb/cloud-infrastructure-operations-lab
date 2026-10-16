[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab28-common.ps1")

$HasState = Test-Path -LiteralPath $script:StatePath

Initialize-Lab28 `
    -ProfileName $ProfileName `
    -RequireState:$HasState

if ($HasState) {
    Write-Host "Inventario existente carregado."
}
else {
    $RunId = [guid]::NewGuid().ToString("N")

    $script:State = [pscustomobject]@{
        RunId        = $RunId
        AccountId    = $Settings.ExpectedAccountId
        Region       = $Settings.Region
        LogGroupName = "$($Settings.LogGroupPrefix)/$RunId"
        StreamName   = "controlled-application"
        CreatedAtUtc = [DateTime]::UtcNow.ToString("o")
    }
}

$Group = Get-Lab28Group

if ($null -ne $Group) {
    if (-not $HasState) {
        throw (
            "O nome proposto ja existe na AWS. " +
            "Nenhum recurso existente sera adotado."
        )
    }

    Assert-Lab28Owner | Out-Null

    Write-Host "Grupo existente com propriedade confirmada."
}

Write-Host ""
Write-Host "Configuracao prevista:"
Write-Host "Grupo: $($State.LogGroupName)"
Write-Host "Stream: $($State.StreamName)"
Write-Host "Classe: STANDARD"
Write-Host "Retencao: $($Settings.RetentionDays) dia"
Write-Host "RunId: $($State.RunId)"
Write-Host ""

if ($ValidateOnly) {
    Write-Host (
        "Pre-validacao concluida. " +
        "Nenhum recurso AWS foi criado ou alterado."
    )

    return
}

if (-not $HasState) {
    New-Item -ItemType Directory `
        -Path $script:LocalDirectory `
        -Force |
        Out-Null

    Save-Lab28Json `
        -Path $script:StatePath `
        -Value $State

    Write-Host "Inventario local salvo antes do provisionamento."
}

if ($null -eq $Group) {
    Invoke-Lab28Aws `
        -Operation "create-log-group" `
        -Request @{
            logGroupName  = $State.LogGroupName
            logGroupClass = "STANDARD"
            tags          = @{
                Project   = $Settings.Tags.Project
                Lab       = $Settings.Tags.Lab
                ManagedBy = $Settings.Tags.ManagedBy
                RunId     = $State.RunId
            }
        } |
        Out-Null

    Write-Host "Grupo de logs criado."
}

Assert-Lab28Owner | Out-Null

Invoke-Lab28Aws `
    -Operation "put-retention-policy" `
    -Request @{
        logGroupName    = $State.LogGroupName
        retentionInDays = $Settings.RetentionDays
    } |
    Out-Null

Write-Host "Politica de retencao aplicada."

$Response = Invoke-Lab28Aws `
    -Operation "describe-log-streams" `
    -Request @{
        logGroupName        = $State.LogGroupName
        logStreamNamePrefix = $State.StreamName
    }

$Streams = @(
    $Response.logStreams | Where-Object {
        $_.logStreamName -ceq $State.StreamName
    }
)

if ($Streams.Count -gt 1) {
    throw "Resultado inesperado ao consultar o stream."
}

if ($Streams.Count -eq 0) {
    Invoke-Lab28Aws `
        -Operation "create-log-stream" `
        -Request @{
            logGroupName  = $State.LogGroupName
            logStreamName = $State.StreamName
        } |
        Out-Null

    Write-Host "Stream criado."
}
else {
    Write-Host "Stream existente localizado."
}

$VerifiedGroup = Assert-Lab28Owner

if ($VerifiedGroup.retentionInDays -ne $Settings.RetentionDays) {
    throw "A retencao observada difere da configuracao."
}

$VerifiedResponse = Invoke-Lab28Aws `
    -Operation "describe-log-streams" `
    -Request @{
        logGroupName        = $State.LogGroupName
        logStreamNamePrefix = $State.StreamName
    }

$VerifiedStreams = @(
    $VerifiedResponse.logStreams | Where-Object {
        $_.logStreamName -ceq $State.StreamName
    }
)

if ($VerifiedStreams.Count -ne 1) {
    throw "O stream esperado nao foi confirmado."
}

Write-Host ""
Write-Host "Provisionamento concluido."
Write-Host "Grupo: $($State.LogGroupName)"
Write-Host "Stream: $($State.StreamName)"
Write-Host "Retencao confirmada: $($VerifiedGroup.retentionInDays) dia"
Write-Host "Inventario: $script:StatePath"
