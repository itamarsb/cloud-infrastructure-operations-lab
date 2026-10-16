Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:LabRoot = Split-Path $PSScriptRoot -Parent
$script:LocalDirectory = Join-Path $script:LabRoot "local-artifacts"
$script:StatePath = Join-Path $script:LocalDirectory "deployment.json"

function Read-Lab28Json {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Arquivo JSON nao encontrado: $Path"
    }

    $Text = Get-Content -LiteralPath $Path -Raw

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw "Arquivo JSON vazio: $Path"
    }

    try {
        $Document = ConvertFrom-Json -InputObject $Text
    }
    catch {
        throw "JSON invalido em ${Path}: $($_.Exception.Message)"
    }

    if (
        $null -eq $Document -or
        $Document -isnot [System.Management.Automation.PSCustomObject]
    ) {
        throw "O JSON deve conter um objeto: $Path"
    }

    return $Document
}

function Save-Lab28Json {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $Json = ConvertTo-Json -InputObject $Value -Depth 40
    $TemporaryPath = "$Path.tmp"
    $Utf8 = New-Object System.Text.UTF8Encoding($false)

    try {
        [IO.File]::WriteAllText(
            $TemporaryPath,
            $Json,
            $Utf8
        )

        Move-Item -LiteralPath $TemporaryPath `
            -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath `
                -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-Lab28Aws {
    param(
        [string]$Service = "logs",

        [Parameter(Mandatory = $true)]
        [string]$Operation,

        [hashtable]$Request = @{}
    )

    $InputPath = [IO.Path]::GetTempFileName()
    $ErrorPath = [IO.Path]::GetTempFileName()
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $PreviousPreference = $ErrorActionPreference

    try {
        $Json = ConvertTo-Json -InputObject $Request -Depth 40

        [IO.File]::WriteAllText(
            $InputPath,
            $Json,
            $Utf8
        )

        $Arguments = @(
            $Service
            $Operation
            "--cli-input-json"
            "file://$InputPath"
            "--profile"
            $script:Lab28ProfileName
            "--region"
            $script:Settings.Region
            "--output"
            "json"
            "--no-cli-pager"
            "--no-cli-auto-prompt"
            "--cli-connect-timeout"
            "10"
            "--cli-read-timeout"
            "30"
        )

        $ErrorActionPreference = "Continue"

        $Output = @(& aws @Arguments 2> $ErrorPath)
        $ExitCode = $LASTEXITCODE

        $ErrorActionPreference = $PreviousPreference

        if ($ExitCode -ne 0) {
            $ErrorText = [IO.File]::ReadAllText($ErrorPath)

            if ([string]::IsNullOrWhiteSpace($ErrorText)) {
                $ErrorText = "Codigo de saida: $ExitCode"
            }

            throw "AWS $Service $Operation falhou: $ErrorText"
        }

        $Text = $Output -join [Environment]::NewLine

        if (-not [string]::IsNullOrWhiteSpace($Text)) {
            return (ConvertFrom-Json -InputObject $Text)
        }
    }
    finally {
        $ErrorActionPreference = $PreviousPreference

        Remove-Item -LiteralPath $InputPath, $ErrorPath `
            -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-Lab28 {
    param(
        [string]$ProfileName = "cloud-operations-lab",

        [switch]$RequireState
    )

    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        throw "Informe o perfil AWS."
    }

    Get-Command aws -CommandType Application -ErrorAction Stop |
        Out-Null

    $script:Lab28ProfileName = $ProfileName
    $script:State = $null

    $ConfigPath = Join-Path $script:LabRoot (
        "config/lab28-settings.json"
    )

    $script:Settings = Read-Lab28Json -Path $ConfigPath

    if (
        $Settings.ExpectedAccountId -cne "412381774441" -or
        $Settings.Region -cne "us-east-1" -or
        $Settings.LogGroupPrefix -cne "/lab28/logs-insights" -or
        $Settings.RetentionDays -ne 1 -or
        $Settings.Tags.Project -cne "cloud-infrastructure-operations-lab" -or
        $Settings.Tags.Lab -cne "28" -or
        $Settings.Tags.ManagedBy -cne "lab28-powershell"
    ) {
        throw "Configuracao diferente do escopo previsto para o LAB 28."
    }

    $Identity = Invoke-Lab28Aws `
        -Service "sts" `
        -Operation "get-caller-identity"

    if ($Identity.Account -cne $Settings.ExpectedAccountId) {
        throw "Conta AWS diferente da esperada."
    }

    Write-Host (
        "Conta: $($Identity.Account) | " +
        "Regiao: $($Settings.Region) | " +
        "Perfil: $ProfileName"
    )

    if ($RequireState) {
        $script:State = Read-Lab28Json -Path $script:StatePath

        $ExpectedGroupName = (
            "$($Settings.LogGroupPrefix)/$($State.RunId)"
        )

        if (
            $State.RunId -cnotmatch "^[a-f0-9]{32}$" -or
            $State.LogGroupName -cne $ExpectedGroupName -or
            $State.StreamName -cne "controlled-application" -or
            $State.AccountId -cne $Settings.ExpectedAccountId -or
            $State.Region -cne $Settings.Region
        ) {
            throw "Inventario fora do escopo do LAB 28."
        }
    }
}

function Get-Lab28Group {
    if ($null -eq $script:State) {
        throw "Carregue ou defina o inventario antes de consultar o grupo."
    }

    $Response = Invoke-Lab28Aws `
        -Operation "describe-log-groups" `
        -Request @{
            logGroupNamePrefix = $State.LogGroupName
        }

    $Groups = @(
        $Response.logGroups | Where-Object {
            $_.logGroupName -ceq $State.LogGroupName
        }
    )

    if ($Groups.Count -gt 1) {
        throw "Resultado inesperado ao consultar o grupo."
    }

    if ($Groups.Count -eq 1) {
        return $Groups[0]
    }

    return $null
}

function Assert-Lab28Owner {
    $Group = Get-Lab28Group

    if ($null -eq $Group) {
        throw "Grupo do LAB 28 ausente."
    }

    $Response = Invoke-Lab28Aws `
        -Operation "list-tags-log-group" `
        -Request @{
            logGroupName = $State.LogGroupName
        }

    $ExpectedTags = @{
        Project   = $Settings.Tags.Project
        Lab       = $Settings.Tags.Lab
        ManagedBy = $Settings.Tags.ManagedBy
        RunId     = $State.RunId
    }

    foreach ($Key in $ExpectedTags.Keys) {
        $Property = $Response.tags.PSObject.Properties[$Key]

        if (
            $null -eq $Property -or
            $Property.Value -cne $ExpectedTags[$Key]
        ) {
            throw "Tag ausente ou diferente da esperada: $Key"
        }
    }

    return $Group
}
