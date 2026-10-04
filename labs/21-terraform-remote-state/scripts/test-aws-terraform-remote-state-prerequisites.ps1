#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProfileName = "cloud-operations-lab",

    [ValidateSet("us-east-1")]
    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[0-9]{12}$")]
    [string]$ExpectedAccountId,

    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Invoke-NativeText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $Lines = @(& $Command @Arguments 2>&1)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    $Text = ($Lines | ForEach-Object { [string]$_ }) -join "`n"

    if ($ExitCode -ne 0) {
        throw "$Command falhou (codigo $ExitCode).`n$Text"
    }

    return $Text
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $AllArguments = $Arguments + @(
        "--profile", $ProfileName,
        "--region", $Region,
        "--output", "json",
        "--no-cli-pager"
    )

    $Text = Invoke-NativeText -Command "aws" -Arguments $AllArguments

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw "Resposta JSON vazia da AWS CLI."
    }

    return ($Text | ConvertFrom-Json)
}

try {
    Write-Host "=== LAB 21: ferramentas e repositorio ==="

    foreach ($Command in @("git", "terraform", "aws")) {
        Get-Command $Command -ErrorAction Stop | Out-Null
    }

    $LabPath = Split-Path -Parent $PSScriptRoot
    $RepositoryPath = Split-Path -Parent (
        Split-Path -Parent $LabPath
    )

    $GitRoot = Invoke-NativeText -Command "git" -Arguments @(
        "-C", $RepositoryPath,
        "rev-parse", "--show-toplevel"
    )

    $ResolvedGitRoot = (Resolve-Path $GitRoot.Trim()).Path
    $ResolvedRepository = (Resolve-Path $RepositoryPath).Path

    if ($ResolvedGitRoot -ne $ResolvedRepository) {
        throw "A estrutura do laboratorio diverge da raiz do repositorio."
    }

    $GitStatus = Invoke-NativeText -Command "git" -Arguments @(
        "-C", $RepositoryPath,
        "status", "--porcelain"
    )

    if (-not [string]::IsNullOrWhiteSpace($GitStatus)) {
        throw "Ha alteracoes locais no repositorio.`n$GitStatus"
    }

    $VersionText = Invoke-NativeText -Command "terraform" -Arguments @(
        "version", "-json"
    )

    $VersionInfo = $VersionText | ConvertFrom-Json
    $TerraformVersion = [version]$VersionInfo.terraform_version

    if ($TerraformVersion -lt [version]"1.16.1" -or
        $TerraformVersion -ge [version]"1.17.0") {
        throw "Versao Terraform fora do intervalo >= 1.16.1 e < 1.17.0."
    }

    $AwsVersion = Invoke-NativeText -Command "aws" -Arguments @("--version")

    if ($AwsVersion -notmatch "^aws-cli/2\.") {
        throw "Este laboratorio exige AWS CLI v2."
    }

    Write-Host "[OK] Git limpo; Terraform $TerraformVersion; AWS CLI v2."

    Write-Host "=== Arquivos de configuracao ==="

    $RequiredFiles = @(
        "bootstrap/versions.tf",
        "bootstrap/variables.tf",
        "bootstrap/providers.tf",
        "bootstrap/main.tf",
        "bootstrap/outputs.tf",
        "terraform/versions.tf",
        "terraform/main.tf",
        "terraform/outputs.tf"
    )

    foreach ($RelativePath in $RequiredFiles) {
        $Path = Join-Path $LabPath $RelativePath

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Arquivo ausente: $RelativePath."
        }

        if ([string]::IsNullOrWhiteSpace(
            [IO.File]::ReadAllText($Path)
        )) {
            throw "Arquivo vazio: $RelativePath."
        }
    }

    Write-Host "[OK] Arquivos do bootstrap e do exercicio presentes."

    Write-Host "=== Protecoes do Git ==="

    $LabRelativePath = "labs/21-terraform-remote-state"

    $IgnoredPaths = @(
        "$LabRelativePath/bootstrap/.terraform/probe",
        "$LabRelativePath/bootstrap/terraform.tfstate",
        "$LabRelativePath/bootstrap/terraform.tfstate.backup",
        "$LabRelativePath/bootstrap/lab21.tfvars.json",
        "$LabRelativePath/bootstrap/lab21-create.tfplan",
        "$LabRelativePath/terraform/.terraform/probe",
        "$LabRelativePath/terraform/terraform.tfstate",
        "$LabRelativePath/terraform/.terraform.tfstate.lock.info",
        "$LabRelativePath/terraform/lab21.s3.tfbackend",
        "$LabRelativePath/terraform/lab21.s3.tfbackend.json",
        "$LabRelativePath/terraform/lab21-create.tfplan",
        "$LabRelativePath/local-artifacts/probe.json"
    )

    foreach ($RelativePath in $IgnoredPaths) {
        $null = Invoke-NativeText -Command "git" -Arguments @(
            "-C", $RepositoryPath,
            "check-ignore", "--no-index", "--", $RelativePath
        )
    }

    $TrackedIgnored = Invoke-NativeText -Command "git" -Arguments @(
        "-C", $RepositoryPath,
        "ls-files", "-ci", "--exclude-standard",
        "--", $LabRelativePath
    )

    if (-not [string]::IsNullOrWhiteSpace($TrackedIgnored)) {
        throw "Arquivos locais ja rastreados pelo Git.`n$TrackedIgnored"
    }

    Write-Host "[OK] Estados, planos, parametros e copias locais ignorados."

    Write-Host "=== Estado local inicial ==="

    foreach ($Name in @("TF_DATA_DIR", "TF_CLI_ARGS",
        "TF_CLI_ARGS_init", "TF_CLI_ARGS_plan",
        "TF_CLI_ARGS_apply")) {
        if (-not [string]::IsNullOrWhiteSpace(
            [Environment]::GetEnvironmentVariable($Name)
        )) {
            throw "Variavel $Name definida. Confira antes de iniciar o laboratorio."
        }
    }

    $SelectedWorkspace = [Environment]::GetEnvironmentVariable("TF_WORKSPACE")

    if (-not [string]::IsNullOrWhiteSpace($SelectedWorkspace) -and
        $SelectedWorkspace -ne "default") {
        throw "TF_WORKSPACE diferente de default."
    }

    foreach ($DirectoryName in @("bootstrap", "terraform")) {
        $DirectoryPath = Join-Path $LabPath $DirectoryName

        foreach ($Name in @(
            "terraform.tfstate",
            "terraform.tfstate.backup",
            ".terraform.tfstate.lock.info",
            "terraform.tfstate.d"
        )) {
            if (Test-Path -LiteralPath (Join-Path $DirectoryPath $Name)) {
                throw "Estado ou bloqueio anterior encontrado em $DirectoryName/$Name."
            }
        }

        $WorkspacePath = Join-Path $DirectoryPath ".terraform/environment"

        if (Test-Path -LiteralPath $WorkspacePath -PathType Leaf) {
            $Workspace = [IO.File]::ReadAllText($WorkspacePath).Trim()

            if ($Workspace -ne "default") {
                throw "Workspace diferente de default em $DirectoryName."
            }
        }

        $BackendPath = Join-Path $DirectoryPath ".terraform/terraform.tfstate"

        if (Test-Path -LiteralPath $BackendPath -PathType Leaf) {
            $BackendMetadata = (
                [IO.File]::ReadAllText($BackendPath) | ConvertFrom-Json
            )

            if ($BackendMetadata.backend.type -ne "local") {
                throw "Backend ja inicializado diferente de local em $DirectoryName."
            }
        }
    }

    Write-Host "[OK] Nenhum estado anterior; selecao de workspace conferida."

    Write-Host "=== Identidade AWS e conflito do bucket ==="

    $Identity = Invoke-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ([string]$Identity.Account -ne $ExpectedAccountId) {
        throw "A conta autenticada difere da conta autorizada."
    }

    $BucketName = "lab21-terraform-state-$ExpectedAccountId-$Region"

    $BucketInventory = Invoke-AwsJson -Arguments @(
        "s3api", "list-buckets"
    )

    $Conflicts = @(
        $BucketInventory.Buckets |
            Where-Object { $_.Name -eq $BucketName }
    )

    if ($Conflicts.Count -gt 0) {
        throw "O bucket $BucketName ja existe na conta. Confira o inventario e o estado."
    }

    Write-Host "[OK] Conta: $ExpectedAccountId; regiao: $Region."
    Write-Host "[OK] Bucket do laboratorio ausente no inventario da conta."

    $Result = [PSCustomObject]@{
        ProfileName       = $ProfileName
        Region            = $Region
        AccountId         = $ExpectedAccountId
        BucketName        = $BucketName
        StateKey          = "lab21/exercise/terraform.tfstate"
        LockKey           = "lab21/exercise/terraform.tfstate.tflock"
        BootstrapPath     = Join-Path $LabPath "bootstrap"
        ExercisePath      = Join-Path $LabPath "terraform"
        LocalArtifactsPath = Join-Path $LabPath "local-artifacts"
    }

    Write-Host "PRE-VALIDACAO CONCLUIDA: nenhum recurso AWS alterado."

    $global:LASTEXITCODE = 0

    if ($PassThru) {
        $Result
    }
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    $global:LASTEXITCODE = 1
    exit 1
}
