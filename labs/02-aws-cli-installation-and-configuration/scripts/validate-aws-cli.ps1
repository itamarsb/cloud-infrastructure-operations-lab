<#
.SYNOPSIS
Valida a instalação e a configuração da AWS CLI.

.DESCRIPTION
Verifica a AWS CLI v2, o perfil nomeado, a Região padrão e a identidade
autenticada pelo AWS IAM Identity Center.

O script executa somente comandos de consulta. Ele não cria, altera ou
remove recursos AWS e não exibe Account ID, UserId ou ARN.

.PARAMETER ProfileName
Nome do perfil AWS CLI que será validado.

.PARAMETER ExpectedRegion
Região AWS esperada no perfil.

.EXAMPLE
.\labs\02-aws-cli-installation-and-configuration\scripts\validate-aws-cli.ps1

.EXAMPLE
.\validate-aws-cli.ps1 -ProfileName "cloud-operations-lab" -ExpectedRegion "us-east-1"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProfileName = "cloud-operations-lab",

    [Parameter()]
    [ValidatePattern("^[a-z]{2}(-gov)?-[a-z]+-\d$")]
    [string]$ExpectedRegion = "us-east-1"
)

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

Write-Host ""
Write-Host "Cloud Infrastructure Operations Lab" -ForegroundColor White
Write-Host "Validação da AWS CLI" -ForegroundColor White
Write-Host "Modo: somente leitura" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Perfil esperado: $ProfileName" -ForegroundColor DarkGray
Write-Host "Região esperada: $ExpectedRegion" -ForegroundColor DarkGray

Write-Section "1. Instalação da AWS CLI"

if (-not (Test-CommandAvailable -CommandName "aws")) {
    Write-Failure "O comando aws não foi localizado no PATH."

    Write-Section "Resumo"
    Write-Host "Aprovações: $SuccessCount" -ForegroundColor Green
    Write-Host "Avisos:     $WarningCount" -ForegroundColor Yellow
    Write-Host "Falhas:     $FailureCount" -ForegroundColor Red
    Write-Host ""
    Write-Host "RESULTADO: AWS CLI NÃO VALIDADA" -ForegroundColor Red
    exit 1
}

try {
    $AwsCommand = Get-Command aws
    $AwsVersion = aws --version 2>&1 | Out-String
    $AwsVersion = $AwsVersion.Trim()

    Write-Success "Comando aws localizado."
    Write-Host "        Executável: $($AwsCommand.Source)" -ForegroundColor DarkGray
    Write-Host "        Versão: $AwsVersion" -ForegroundColor DarkGray

    if ($AwsVersion -match "^aws-cli/2\.") {
        Write-Success "AWS CLI versão principal 2 confirmada."
    }
    else {
        Write-Failure "A instalação localizada não corresponde à AWS CLI v2."
    }
}
catch {
    Write-Failure "Não foi possível executar aws --version: $($_.Exception.Message)"
}

Write-Section "2. Perfil nomeado"

try {
    $ConfiguredProfiles = @(aws configure list-profiles 2>$null)

    if ($LASTEXITCODE -ne 0) {
        Write-Failure "Não foi possível listar os perfis da AWS CLI."
    }
    elseif ($ConfiguredProfiles -contains $ProfileName) {
        Write-Success "Perfil '$ProfileName' encontrado."
    }
    else {
        Write-Failure "Perfil '$ProfileName' não foi encontrado."
        Write-Host "        Execute: aws configure sso" -ForegroundColor DarkGray
    }
}
catch {
    Write-Failure "Falha ao consultar os perfis: $($_.Exception.Message)"
}

Write-Section "3. Região padrão"

try {
    $ConfiguredRegion = aws configure get region --profile $ProfileName 2>$null

    if ($LASTEXITCODE -ne 0 -or -not $ConfiguredRegion) {
        Write-Failure "Não foi possível obter a Região configurada para o perfil."
    }
    elseif ($ConfiguredRegion.Trim() -eq $ExpectedRegion) {
        Write-Success "Região padrão confirmada: $ExpectedRegion."
    }
    else {
        Write-Failure "A Região configurada não corresponde à Região esperada."
        Write-Host "        Configurada: $($ConfiguredRegion.Trim())" `
            -ForegroundColor DarkGray
        Write-Host "        Esperada:    $ExpectedRegion" `
            -ForegroundColor DarkGray
    }
}
catch {
    Write-Failure "Falha ao consultar a Região do perfil: $($_.Exception.Message)"
}

Write-Section "4. Configuração efetiva"

try {
    $ConfigurationOutput = aws configure list --profile $ProfileName 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Success "A configuração efetiva do perfil pôde ser consultada."
        Write-Host ""
        $ConfigurationOutput | ForEach-Object {
            Write-Host "        $_" -ForegroundColor DarkGray
        }
    }
    else {
        Write-Failure "Não foi possível consultar a configuração efetiva do perfil."
    }
}
catch {
    Write-Failure "Falha ao executar aws configure list: $($_.Exception.Message)"
}

Write-Section "5. Sessão e identidade AWS"

try {
    $IdentityOutput = aws sts get-caller-identity `
        --profile $ProfileName `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {
        $Identity = $IdentityOutput | Out-String | ConvertFrom-Json

        if ($Identity.Account -and $Identity.Arn -and $Identity.UserId) {
            Write-Success "A sessão AWS está válida."
            Write-Success "A identidade foi confirmada pelo AWS STS."
            Write-Host "        Account ID: confirmado e ocultado" `
                -ForegroundColor DarkGray
            Write-Host "        ARN: confirmado e ocultado" `
                -ForegroundColor DarkGray
            Write-Host "        UserId: confirmado e ocultado" `
                -ForegroundColor DarkGray

            if ($Identity.Arn -match ":root$") {
                Write-Failure "A identidade retornada corresponde ao usuário root."
            }
            elseif ($Identity.Arn -match ":assumed-role/") {
                Write-Success "A identidade utiliza uma sessão de role temporária."
            }
            else {
                Write-WarningResult "A identidade não parece ser uma assumed role."
                Write-Host "        Confirme se o perfil utiliza IAM Identity Center." `
                    -ForegroundColor DarkGray
            }
        }
        else {
            Write-Failure "O AWS STS não retornou todos os campos esperados."
        }
    }
    else {
        $IdentityError = $IdentityOutput | Out-String

        Write-Failure "Não foi possível validar a identidade AWS."

        if (
            $IdentityError -match "expired" -or
            $IdentityError -match "Token has expired" -or
            $IdentityError -match "Error loading SSO Token" -or
            $IdentityError -match "The SSO session associated with this profile"
        ) {
            Write-Host "        A sessão SSO pode ter expirado." `
                -ForegroundColor DarkGray
            Write-Host "        Execute:" -ForegroundColor DarkGray
            Write-Host "        aws sso login --profile $ProfileName" `
                -ForegroundColor Yellow
        }
        elseif ($IdentityError -match "Unable to locate credentials") {
            Write-Host "        Não foram encontradas credenciais para o perfil." `
                -ForegroundColor DarkGray
            Write-Host "        Revise a configuração com: aws configure sso" `
                -ForegroundColor Yellow
        }
        else {
            Write-Host "        Revise o login SSO, a rede e a configuração do perfil." `
                -ForegroundColor DarkGray
        }
    }
}
catch {
    Write-Failure "Falha inesperada durante a validação do AWS STS."
    Write-Host "        $($_.Exception.Message)" -ForegroundColor DarkGray
}

Write-Section "6. Consulta segura da Região"

try {
    $RegionOutput = aws ec2 describe-regions `
        --region $ExpectedRegion `
        --profile $ProfileName `
        --query "Regions[?RegionName=='$ExpectedRegion'].RegionName" `
        --output text 2>&1

    if ($LASTEXITCODE -eq 0 -and $RegionOutput.Trim() -eq $ExpectedRegion) {
        Write-Success "Consulta somente leitura executada em $ExpectedRegion."
    }
    elseif ($LASTEXITCODE -ne 0) {
        Write-WarningResult "A consulta EC2 não foi autorizada ou não pôde ser concluída."
        Write-Host "        Isso não invalida a autenticação confirmada pelo AWS STS." `
            -ForegroundColor DarkGray
        Write-Host "        O permission set pode não permitir ec2:DescribeRegions." `
            -ForegroundColor DarkGray
    }
    else {
        Write-WarningResult "A consulta EC2 não retornou a Região esperada."
    }
}
catch {
    Write-WarningResult "Não foi possível concluir a consulta EC2."
    Write-Host "        Isso não invalida uma autenticação confirmada pelo AWS STS." `
        -ForegroundColor DarkGray
}

Write-Section "Resumo"

Write-Host "Aprovações: $SuccessCount" -ForegroundColor Green
Write-Host "Avisos:     $WarningCount" -ForegroundColor Yellow
Write-Host "Falhas:     $FailureCount" -ForegroundColor Red
Write-Host ""

if ($FailureCount -eq 0) {
    Write-Host "RESULTADO: AWS CLI VALIDADA" -ForegroundColor Green
    Write-Host "Perfil, Região e autenticação estão preparados para os próximos laboratórios." `
        -ForegroundColor Green
    exit 0
}

Write-Host "RESULTADO: VALIDAÇÃO NÃO CONCLUÍDA" -ForegroundColor Red
Write-Host "Corrija as falhas indicadas e execute o script novamente." `
    -ForegroundColor Red
exit 1
