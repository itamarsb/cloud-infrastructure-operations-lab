<#
.SYNOPSIS
Valida as ferramentas de infraestrutura utilizadas no Lab 03.

.DESCRIPTION
Verifica Windows, PowerShell, Git, Terraform, AWS CLI,
AWS Session Manager Plugin, WinGet e Visual Studio Code.

O script executa somente operações de leitura e não altera
programas, configurações, credenciais ou recursos AWS.

.EXAMPLE
.\labs\03-infrastructure-tools-installation\scripts\validate-infrastructure-tools.ps1
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

function Test-Tool {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$DisplayName,

        [string[]]$Arguments = @(),

        [string]$ExpectedPattern
    )

    $Command = Get-Command $Name -ErrorAction SilentlyContinue

    if (-not $Command) {
        Write-Failure "$DisplayName não foi localizado no PATH."
        return
    }

    try {
        $Output = @(& $Name @Arguments 2>&1)
        $ExitCode = $LASTEXITCODE
        $OutputText = ($Output | Out-String).Trim()

        if ($ExitCode -ne 0) {
            Write-Failure "$DisplayName foi localizado, mas retornou o código $ExitCode."
            return
        }

        if ($ExpectedPattern -and $OutputText -notmatch $ExpectedPattern) {
            Write-WarningResult "$DisplayName respondeu, mas o resultado não corresponde ao padrão esperado."
        }
        else {
            Write-Success "$DisplayName disponível."
        }

        Write-Host "        Executável: $($Command.Source)" -ForegroundColor DarkGray

        foreach ($Line in $Output) {
            if (-not [string]::IsNullOrWhiteSpace($Line)) {
                Write-Host "        $Line" -ForegroundColor DarkGray
            }
        }
    }
    catch {
        Write-Failure "Não foi possível executar ${DisplayName}: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Cloud Infrastructure Operations Lab" -ForegroundColor White
Write-Host "Lab 03 — Validação das ferramentas de infraestrutura" -ForegroundColor White
Write-Host "Modo: somente leitura" -ForegroundColor DarkGray

Write-Section "1. Sistema operacional e PowerShell"

if ($env:OS -eq "Windows_NT") {
    Write-Success "Sistema operacional Windows identificado."
    Write-Host "        $([System.Environment]::OSVersion.VersionString)" -ForegroundColor DarkGray
}
else {
    Write-Failure "Este laboratório foi projetado para Windows 10 ou Windows 11."
}

if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Success "PowerShell compatível."
    Write-Host (
        "        Versão: {0}" -f $PSVersionTable.PSVersion.ToString()
    ) -ForegroundColor DarkGray
}
else {
    Write-Failure "A versão do PowerShell é inferior à versão 5."
}

Write-Section "2. Ferramentas de desenvolvimento"

Test-Tool `
    -Name "git" `
    -DisplayName "Git" `
    -Arguments @("--version") `
    -ExpectedPattern "^git version"

Test-Tool `
    -Name "code" `
    -DisplayName "Visual Studio Code" `
    -Arguments @("--version") `
    -ExpectedPattern "\d+\.\d+\.\d+"

Write-Section "3. Ferramentas de infraestrutura"

Test-Tool `
    -Name "terraform" `
    -DisplayName "Terraform" `
    -Arguments @("version") `
    -ExpectedPattern "Terraform v1\.16\.1"

Test-Tool `
    -Name "aws" `
    -DisplayName "AWS CLI v2" `
    -Arguments @("--version") `
    -ExpectedPattern "aws-cli/2\."

Test-Tool `
    -Name "session-manager-plugin" `
    -DisplayName "AWS Session Manager Plugin" `
    -ExpectedPattern "installed successfully"

Test-Tool `
    -Name "winget" `
    -DisplayName "Windows Package Manager — WinGet" `
    -Arguments @("--version") `
    -ExpectedPattern "^v\d+"

Write-Section "4. Resumo"

Write-Host "[OK]     $SuccessCount" -ForegroundColor Green
Write-Host "[AVISO]  $WarningCount" -ForegroundColor Yellow
Write-Host "[FALHA]  $FailureCount" -ForegroundColor Red

if ($FailureCount -gt 0) {
    Write-Host ""
    Write-Host "Resultado: validação reprovada." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Resultado: ferramentas obrigatórias validadas." -ForegroundColor Green
exit 0
