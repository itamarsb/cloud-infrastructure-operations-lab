<#
.SYNOPSIS
Valida a estação de trabalho utilizada no Cloud Infrastructure Operations Lab.

.DESCRIPTION
Verifica o PowerShell, Git, Visual Studio Code, diretório Cloud-Labs,
repositório Git, origem remota e estrutura principal do projeto.

O script executa somente operações de leitura e não altera a estação
de trabalho ou o repositório.

.EXAMPLE
.\labs\00-workstation-preparation\scripts\validate-workstation.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SuccessCount = 0
$WarningCount = 0
$FailureCount = 0

function Write-Section {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}

function Write-Success {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:SuccessCount++
    Write-Host "[OK]    $Message" -ForegroundColor Green
}

function Write-WarningResult {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:WarningCount++
    Write-Host "[AVISO] $Message" -ForegroundColor Yellow
}

function Write-Failure {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:FailureCount++
    Write-Host "[FALHA] $Message" -ForegroundColor Red
}

function Test-CommandAvailable {
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-RepositoryRoot {
    try {
        $Root = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null

        if ($LASTEXITCODE -eq 0 -and $Root) {
            return $Root.Trim()
        }
    }
    catch {
        return $null
    }

    return $null
}

Write-Host ""
Write-Host "Cloud Infrastructure Operations Lab" -ForegroundColor White
Write-Host "Validação da estação de trabalho" -ForegroundColor White
Write-Host "Modo: somente leitura" -ForegroundColor DarkGray

Write-Section "1. Sistema operacional e PowerShell"

$OperatingSystem = [System.Environment]::OSVersion.VersionString

if ($env:OS -eq "Windows_NT") {
    Write-Success "Sistema operacional Windows identificado."
    Write-Host "        Sistema: $OperatingSystem" -ForegroundColor DarkGray
}
else {
    Write-Failure "Este laboratório foi projetado para Windows 10 ou Windows 11."
}

$PowerShellVersion = $PSVersionTable.PSVersion.ToString()

if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Success "PowerShell disponível."
    Write-Host "        Versão: $PowerShellVersion" -ForegroundColor DarkGray
}
else {
    Write-Failure "A versão do PowerShell é inferior à versão 5."
}

Write-Section "2. Ferramentas obrigatórias"

if (Test-CommandAvailable -CommandName "git") {
    try {
        $GitVersion = git --version

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git disponível no PATH."
            Write-Host "        $GitVersion" -ForegroundColor DarkGray
        }
        else {
            Write-Failure "O comando Git foi localizado, mas não respondeu corretamente."
        }
    }
    catch {
        Write-Failure "Não foi possível executar o Git: $($_.Exception.Message)"
    }
}
else {
    Write-Failure "Git não foi localizado no PATH."
}

if (Test-CommandAvailable -CommandName "code") {
    try {
        $CodeVersionOutput = code --version
        $CodeVersion = $CodeVersionOutput | Select-Object -First 1

        if ($LASTEXITCODE -eq 0 -and $CodeVersion) {
            Write-Success "Visual Studio Code disponível no PATH."
            Write-Host "        Versão: $CodeVersion" -ForegroundColor DarkGray
        }
        else {
            Write-Failure "O comando code foi localizado, mas não respondeu corretamente."
        }
    }
    catch {
        Write-Failure "Não foi possível executar o Visual Studio Code: $($_.Exception.Message)"
    }
}
else {
    Write-Failure "O comando code do Visual Studio Code não foi localizado no PATH."
}

Write-Section "3. Diretório dos laboratórios"

$CloudLabsDirectory = Join-Path $HOME "Cloud-Labs"

if (Test-Path -LiteralPath $CloudLabsDirectory -PathType Container) {
    Write-Success "Diretório Cloud-Labs encontrado."
    Write-Host "        Diretório: $CloudLabsDirectory" -ForegroundColor DarkGray
}
else {
    Write-WarningResult "O diretório padrão Cloud-Labs não foi encontrado em $HOME."
    Write-Host "        Isso não impede a validação se o repositório foi armazenado em outro local." `
        -ForegroundColor DarkGray
}

Write-Section "4. Repositório Git"

$RepositoryRoot = $null

if (Test-CommandAvailable -CommandName "git") {
    $RepositoryRoot = Get-RepositoryRoot
}

if ($RepositoryRoot) {
    Write-Success "O script está sendo executado dentro de um repositório Git."
    Write-Host "        Raiz: $RepositoryRoot" -ForegroundColor DarkGray

    $RepositoryName = Split-Path $RepositoryRoot -Leaf

    if ($RepositoryName -eq "cloud-infrastructure-operations-lab") {
        Write-Success "Nome esperado do repositório confirmado."
    }
    else {
        Write-WarningResult "O repositório atual possui o nome '$RepositoryName'."
        Write-Host "        Nome esperado: cloud-infrastructure-operations-lab" `
            -ForegroundColor DarkGray
    }

    try {
        $RemoteUrl = git -C $RepositoryRoot remote get-url origin 2>$null

        if ($LASTEXITCODE -eq 0 -and $RemoteUrl) {
            Write-Success "Repositório remoto origin configurado."
            Write-Host "        Remote: $RemoteUrl" -ForegroundColor DarkGray

            if ($RemoteUrl -match "itamarsb/cloud-infrastructure-operations-lab") {
                Write-Success "Origem remota esperada confirmada."
            }
            else {
                Write-WarningResult "A origem remota não corresponde ao repositório esperado."
            }
        }
        else {
            Write-WarningResult "O remote origin não está configurado."
        }
    }
    catch {
        Write-WarningResult "Não foi possível consultar o remote origin."
    }
}
else {
    Write-Failure "Não foi possível identificar a raiz do repositório Git."
    Write-Host "        Execute o script dentro da cópia local do repositório." `
        -ForegroundColor DarkGray
}

Write-Section "5. Estrutura principal do projeto"

if ($RepositoryRoot) {
    $RequiredDirectories = @(
        "docs",
        "labs",
        "terraform",
        "incident-response",
        "checklists",
        "resources",
        "templates",
        "scripts",
        "images"
    )

    $RequiredFiles = @(
        "README.md",
        "LICENSE",
        ".gitignore"
    )

    foreach ($Directory in $RequiredDirectories) {
        $DirectoryPath = Join-Path $RepositoryRoot $Directory

        if (Test-Path -LiteralPath $DirectoryPath -PathType Container) {
            Write-Success "Diretório encontrado: $Directory/"
        }
        else {
            Write-Failure "Diretório obrigatório ausente: $Directory/"
        }
    }

    foreach ($File in $RequiredFiles) {
        $FilePath = Join-Path $RepositoryRoot $File

        if (Test-Path -LiteralPath $FilePath -PathType Leaf) {
            Write-Success "Arquivo encontrado: $File"
        }
        else {
            Write-Failure "Arquivo obrigatório ausente: $File"
        }
    }
}
else {
    Write-Failure "A estrutura não pôde ser validada porque a raiz do repositório não foi identificada."
}

Write-Section "6. Estado atual do Git"

if ($RepositoryRoot) {
    try {
        $GitStatus = git -C $RepositoryRoot status --short

        if ($LASTEXITCODE -ne 0) {
            Write-Failure "Não foi possível consultar o estado do Git."
        }
        elseif ($GitStatus) {
            Write-WarningResult "O repositório possui alterações locais não confirmadas."
            Write-Host "        Revise o resultado de: git status" -ForegroundColor DarkGray
        }
        else {
            Write-Success "O diretório de trabalho do Git está limpo."
        }
    }
    catch {
        Write-Failure "Falha ao executar git status: $($_.Exception.Message)"
    }
}

Write-Section "Resumo"

Write-Host "Aprovações: $SuccessCount" -ForegroundColor Green
Write-Host "Avisos:     $WarningCount" -ForegroundColor Yellow
Write-Host "Falhas:     $FailureCount" -ForegroundColor Red
Write-Host ""

if ($FailureCount -eq 0) {
    Write-Host "RESULTADO: ESTAÇÃO DE TRABALHO VALIDADA" -ForegroundColor Green
    Write-Host "A estação está preparada para os próximos laboratórios." `
        -ForegroundColor Green
    exit 0
}

Write-Host "RESULTADO: VALIDAÇÃO NÃO CONCLUÍDA" -ForegroundColor Red
Write-Host "Corrija as falhas indicadas e execute o script novamente." `
    -ForegroundColor Red
exit 1
