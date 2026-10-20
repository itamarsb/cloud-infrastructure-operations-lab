[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab"
)

. (Join-Path $PSScriptRoot "lab28-common.ps1")

Initialize-Lab28 `
    -ProfileName $ProfileName `
    -RequireState

# Consulta a AWS novamente, sem depender do relatorio de remocao.
$Response = Invoke-Lab28Aws `
    -Operation "describe-log-groups" `
    -Request @{
        logGroupNamePrefix = $State.LogGroupName
    }

if ($null -eq $Response) {
    throw "A AWS nao retornou uma resposta para a consulta."
}

$GroupsProperty = $Response.PSObject.Properties["logGroups"]

if ($null -eq $GroupsProperty) {
    throw "A resposta nao apresentou a propriedade logGroups."
}

# O prefixo reduz a busca; a comparacao exata identifica o alvo.
$MatchingGroups = @(
    $GroupsProperty.Value | Where-Object {
        $_.logGroupName -ceq $State.LogGroupName
    }
)

$AbsenceConfirmed = ($MatchingGroups.Count -eq 0)

$GroupResult = "FAIL"

if ($AbsenceConfirmed) {
    $GroupResult = "PASS"
}

$Checks = @(
    [pscustomobject]@{
        Check  = "Conta AWS"
        Result = "PASS"
        Value  = $State.AccountId
    }
    [pscustomobject]@{
        Check  = "Regiao consultada"
        Result = "PASS"
        Value  = $Settings.Region
    }
    [pscustomobject]@{
        Check  = "Grupo ausente"
        Result = $GroupResult
        Value  = $State.LogGroupName
    }
)

$ValidationId = [guid]::NewGuid().ToString("N")

$ReportPath = Join-Path $script:LocalDirectory (
    "cleanup-validation-$ValidationId.json"
)

$Report = [pscustomobject]@{
    ObservedAtUtc    = [DateTime]::UtcNow.ToString("o")
    ProfileName      = $ProfileName
    AccountId        = $State.AccountId
    Region           = $Settings.Region
    RunId            = $State.RunId
    LogGroupName     = $State.LogGroupName
    MatchingGroups   = $MatchingGroups.Count
    AbsenceConfirmed = $AbsenceConfirmed
    Checks           = $Checks
    Response         = $Response
}

Save-Lab28Json `
    -Path $ReportPath `
    -Value $Report

Write-Host ""
$Checks | Format-Table -AutoSize -Wrap

Write-Host "Relatorio local: $ReportPath"

if (-not $AbsenceConfirmed) {
    throw "O grupo do inventario ainda existe na regiao consultada."
}

Write-Host ""
Write-Host "Validacao independente da limpeza concluida."
Write-Host "Grupo do inventario ausente na regiao consultada."
Write-Host "Nenhum recurso AWS foi criado ou alterado."
