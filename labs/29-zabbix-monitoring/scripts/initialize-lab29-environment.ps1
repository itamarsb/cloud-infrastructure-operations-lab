#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LabDirectory = Split-Path -Parent $PSScriptRoot
$SettingsPath = Join-Path $LabDirectory "config\lab29-settings.json"
$LocalDirectory = Join-Path $LabDirectory "local-artifacts"
$EnvironmentPath = Join-Path $LocalDirectory "lab29.env"

# 1. Le os parametros versionados.
$Settings = Get-Content -LiteralPath $SettingsPath -Raw |
    ConvertFrom-Json

if ($Settings.ProjectName -cne "cloud-operations-lab29") {
    throw "Nome de projeto diferente do previsto para o LAB 29."
}

if ($Settings.Web.BindAddress -cne "127.0.0.1") {
    throw "A interface web deve utilizar o endereco local 127.0.0.1."
}

$WebPort = 0

if (-not [int]::TryParse(
    [string]$Settings.Web.Port,
    [ref]$WebPort
)) {
    throw "A porta web deve ser um numero inteiro."
}

if ($WebPort -lt 1024 -or $WebPort -gt 65535) {
    throw "A porta web deve estar entre 1024 e 65535."
}

$HostName = [string]$Settings.Monitoring.HostName

if ($HostName -cnotmatch '^[a-z0-9][a-z0-9-]{0,62}$') {
    throw "Nome do alvo invalido. Use letras minusculas, numeros e hifen."
}

# 2. Confirma a exclusao do arquivo local pelo Git.
& git -C $LabDirectory check-ignore --quiet -- `
    "local-artifacts/lab29.env"

if ($LASTEXITCODE -ne 0) {
    throw "O arquivo local de parametros nao esta sendo ignorado pelo Git."
}

# 3. Preserva uma preparacao anterior.
if (Test-Path -LiteralPath $EnvironmentPath) {
    Write-Host "Arquivo de parametros ja existente."
    Write-Host "Nenhuma senha ou configuracao foi substituida."
    Write-Host "Arquivo: $EnvironmentPath"
    Write-Host "A validacao do arquivo existente sera feita antes da implantacao."
    return
}

# 4. Evita gerar outra senha para um banco ja existente.
$ExistingVolumes = @(
    & docker volume ls --quiet --filter (
        "label=com.docker.compose.project=" + $Settings.ProjectName
    )
)

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao consultar os volumes. Confira se o Docker Desktop esta aberto."
}

if ($ExistingVolumes.Count -ne 0) {
    throw (
        "Existem volumes do LAB 29, mas o arquivo lab29.env esta ausente. " +
        "Preserve os volumes e envie o retorno."
    )
}

# 5. Gera a senha automaticamente, sem exibi-la.
$RandomBytes = New-Object byte[] 24
$Generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()

try {
    $Generator.GetBytes($RandomBytes)
}
finally {
    $Generator.Dispose()
}

$DatabasePassword = [BitConverter]::ToString($RandomBytes).Replace("-", "")

$EnvironmentLines = @(
    "LAB29_PROJECT_NAME=$($Settings.ProjectName)"
    "LAB29_WEB_BIND_ADDRESS=$($Settings.Web.BindAddress)"
    "LAB29_WEB_PORT=$WebPort"
    "LAB29_HOST_NAME=$HostName"
    "LAB29_DB_PASSWORD=$DatabasePassword"
)

# 6. Salva os parametros em UTF-8 sem BOM.
[System.IO.Directory]::CreateDirectory($LocalDirectory) | Out-Null

$Encoding = New-Object System.Text.UTF8Encoding($false)
$Content = ($EnvironmentLines -join "`n") + "`n"
$FileBytes = $Encoding.GetBytes($Content)

$Stream = [System.IO.File]::Open(
    $EnvironmentPath,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
)

try {
    $Stream.Write($FileBytes, 0, $FileBytes.Length)
}
finally {
    $Stream.Dispose()
}

Write-Host ""
Write-Host "Preparacao local concluida."
Write-Host "Projeto: $($Settings.ProjectName)"
Write-Host "Alvo: $HostName"
Write-Host "Interface prevista: http://127.0.0.1:$WebPort"
Write-Host "Arquivo: $EnvironmentPath"
Write-Host "Senha gerada e salva localmente, sem exibicao."
Write-Host "Nenhum container ou volume foi criado ou alterado."
