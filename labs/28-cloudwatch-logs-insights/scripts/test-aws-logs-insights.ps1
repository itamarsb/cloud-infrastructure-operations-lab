[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lab28-common.ps1")

Initialize-Lab28 `
    -ProfileName $ProfileName `
    -RequireState

# Consulta o grupo e confere suas tags de propriedade.
$Group = Assert-Lab28Owner

if ($Group.logGroupClass -cne "STANDARD") {
    throw "A classe observada do grupo difere de STANDARD."
}

if ($Group.retentionInDays -ne $Settings.RetentionDays) {
    throw "A retencao observada difere da configuracao."
}

# Consulta os streams e seleciona o nome exato.
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

if ($Streams.Count -ne 1) {
    throw "O stream esperado nao foi confirmado."
}

$Stream = $Streams[0]

# Consulta novamente as tags para preserva-las no relatorio.
$TagsResponse = Invoke-Lab28Aws `
    -Operation "list-tags-log-group" `
    -Request @{
        logGroupName = $State.LogGroupName
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
        Check  = "Grupo exclusivo"
        Result = "PASS"
        Value  = $Group.logGroupName
    }

    [pscustomobject]@{
        Check  = "Tags de propriedade"
        Result = "PASS"
        Value  = "Project, Lab, ManagedBy e RunId"
    }

    [pscustomobject]@{
        Check  = "Classe do grupo"
        Result = "PASS"
        Value  = $Group.logGroupClass
    }

    [pscustomobject]@{
        Check  = "Retencao em dias"
        Result = "PASS"
        Value  = $Group.retentionInDays
    }

    [pscustomobject]@{
        Check  = "Stream"
        Result = "PASS"
        Value  = $Stream.logStreamName
    }
)

$Report = [pscustomobject]@{
    ObservedAtUtc = [DateTime]::UtcNow.ToString("o")
    ProfileName   = $ProfileName
    AccountId     = $State.AccountId
    Region        = $Settings.Region
    RunId         = $State.RunId
    LogGroup      = $Group
    LogStream     = $Stream
    Tags          = $TagsResponse.tags
    Checks        = $Checks
}

$ReportToken = [guid]::NewGuid().ToString("N")

$ReportPath = Join-Path $script:LocalDirectory (
    "infrastructure-validation-$ReportToken.json"
)

Save-Lab28Json -Path $ReportPath -Value $Report

Write-Host ""
$Checks | Format-Table -AutoSize -Wrap

Write-Host "Validacao independente da infraestrutura concluida."
Write-Host "Nenhum recurso AWS foi criado ou alterado."
Write-Host "Relatorio local: $ReportPath"
