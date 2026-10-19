[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",

    [switch]$ValidateOnly
)

. (Join-Path $PSScriptRoot "lab28-common.ps1")

Initialize-Lab28 `
    -ProfileName $ProfileName `
    -RequireState

$Group = Get-Lab28Group

if ($null -ne $Group) {
    $Group = Assert-Lab28Owner
}

Write-Host ""
Write-Host "Alvo da remocao:"
Write-Host "Grupo: $($State.LogGroupName)"
Write-Host "RunId: $($State.RunId)"
Write-Host "Regiao: $($Settings.Region)"

if ($null -eq $Group) {
    Write-Host "Situacao: grupo ja ausente."
}
else {
    Write-Host "Situacao: grupo existente com propriedade confirmada."
    Write-Host "A exclusao removera o grupo, seus streams e eventos."
}

Write-Host "Os arquivos em local-artifacts serao preservados."

if ($ValidateOnly) {
    Write-Host ""
    Write-Host "Pre-validacao concluida."
    Write-Host "Nenhum recurso AWS foi removido."
    return
}

$RemovalId = [guid]::NewGuid().ToString("N")

$RequestPath = Join-Path $script:LocalDirectory (
    "removal-$RemovalId-request.json"
)

$ResultPath = Join-Path $script:LocalDirectory (
    "removal-$RemovalId-result.json"
)

$RemovalRequest = [pscustomobject]@{
    PreparedAtUtc = [DateTime]::UtcNow.ToString("o")
    ProfileName   = $ProfileName
    AccountId     = $State.AccountId
    Region        = $Settings.Region
    RunId         = $State.RunId
    LogGroupName  = $State.LogGroupName
    InitiallyPresent = ($null -ne $Group)
}

Save-Lab28Json `
    -Path $RequestPath `
    -Value $RemovalRequest

$DeleteRequested = $false

if ($null -ne $Group) {
    # Confirma novamente a propriedade imediatamente antes da exclusao.
    Assert-Lab28Owner | Out-Null

    Invoke-Lab28Aws `
        -Operation "delete-log-group" `
        -Request @{
            logGroupName = $State.LogGroupName
        } | Out-Null

    $DeleteRequested = $true

    Write-Host ""
    Write-Host "Solicitacao de exclusao aceita."
}

$AbsenceConfirmed = $false
$ChecksPerformed = 0

for ($Attempt = 1; $Attempt -le 10; $Attempt++) {
    $RemainingGroup = Get-Lab28Group
    $ChecksPerformed++

    if ($null -eq $RemainingGroup) {
        $AbsenceConfirmed = $true
        break
    }

    if ($Attempt -lt 10) {
        Start-Sleep -Seconds 2
    }
}

$RemovalResult = [pscustomobject]@{
    ObservedAtUtc    = [DateTime]::UtcNow.ToString("o")
    ProfileName      = $ProfileName
    AccountId        = $State.AccountId
    Region           = $Settings.Region
    RunId            = $State.RunId
    LogGroupName     = $State.LogGroupName
    DeleteRequested  = $DeleteRequested
    AbsenceConfirmed = $AbsenceConfirmed
    ChecksPerformed  = $ChecksPerformed
    RequestPath      = $RequestPath
}

Save-Lab28Json `
    -Path $ResultPath `
    -Value $RemovalResult

if (-not $AbsenceConfirmed) {
    throw (
        "A ausencia do grupo ainda nao foi confirmada. " +
        "Consulte o relatorio: $ResultPath"
    )
}

Write-Host ""
Write-Host "Ausencia do grupo confirmada."
Write-Host "Inventario, dataset e evidencias locais preservados."
Write-Host "Requisicao: $RequestPath"
Write-Host "Resultado: $ResultPath"
