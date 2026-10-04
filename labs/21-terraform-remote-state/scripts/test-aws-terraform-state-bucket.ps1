#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProfileName = "cloud-operations-lab",

    [ValidateSet("us-east-1")]
    [string]$Region = "us-east-1",

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{12}$')]
    [string]$ExpectedAccountId,

    [ValidateNotNullOrEmpty()]
    [string]$Owner = "itamarsb",

    [switch]$RequireEmpty,

    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $NativeArguments = @($Arguments) + @(
        "--profile", $ProfileName,
        "--region", $Region,
        "--output", "json",
        "--no-cli-pager"
    )

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $OutputLines = @(& aws @NativeArguments 2>&1)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    $Text = (
        $OutputLines | ForEach-Object { [string]$_ }
    ) -join "`n"

    if ($ExitCode -ne 0) {
        throw "AWS CLI falhou: $($Arguments -join ' ')`n$Text"
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw "Resposta JSON vazia: $($Arguments -join ' ')"
    }

    try {
        return ($Text | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        throw "Resposta JSON invalida: $($Arguments -join ' ')`n$Text"
    }
}

function Get-BucketConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation
    )

    Invoke-AwsJson -Arguments @(
        "s3api", $Operation,
        "--bucket", $BucketName,
        "--expected-bucket-owner", $ExpectedAccountId
    )
}

try {
    Get-Command aws -ErrorAction Stop | Out-Null

    $BucketName = "lab21-terraform-state-$ExpectedAccountId-$Region"
    $BucketArn = "arn:aws:s3:::$BucketName"

    Write-Host "=== LAB 21: identidade e bucket ==="

    $Identity = Invoke-AwsJson -Arguments @(
        "sts", "get-caller-identity"
    )

    if ([string]$Identity.Account -ne $ExpectedAccountId) {
        throw "Conta AWS inesperada: $($Identity.Account)."
    }

    Write-Host "[OK] Conta: $ExpectedAccountId."
    Write-Host "[OK] Bucket esperado: $BucketName."

    $Location = Get-BucketConfiguration -Operation "get-bucket-location"

    if ($null -eq $Location.LocationConstraint) {
        $BucketRegion = "us-east-1"
    }
    else {
        $BucketRegion = [string]$Location.LocationConstraint
    }

    if ($BucketRegion -ne $Region) {
        throw "Regiao inesperada do bucket: $BucketRegion."
    }

    Write-Host "[OK] Regiao e proprietario conferidos."

    Write-Host "=== Protecoes do bucket ==="

    $PublicAccess = Get-BucketConfiguration `
        -Operation "get-public-access-block"

    foreach ($Name in @(
        "BlockPublicAcls",
        "IgnorePublicAcls",
        "BlockPublicPolicy",
        "RestrictPublicBuckets"
    )) {
        if ($PublicAccess.PublicAccessBlockConfiguration.$Name -ne $true) {
            throw "Protecao de acesso publico ausente: $Name."
        }
    }

    $PolicyStatus = Get-BucketConfiguration `
        -Operation "get-bucket-policy-status"

    if ($PolicyStatus.PolicyStatus.IsPublic -ne $false) {
        throw "O status da politica nao confirma um bucket privado."
    }

    Write-Host "[OK] Quatro bloqueios de acesso publico habilitados."
    Write-Host "[OK] Politica classificada pelo S3 como nao publica."

    $Ownership = Get-BucketConfiguration `
        -Operation "get-bucket-ownership-controls"

    $OwnershipRules = @($Ownership.OwnershipControls.Rules)

    if ($OwnershipRules.Count -ne 1 -or
        $OwnershipRules[0].ObjectOwnership -ne "BucketOwnerEnforced") {
        throw "Propriedade diferente de BucketOwnerEnforced."
    }

    Write-Host "[OK] Propriedade: BucketOwnerEnforced."

    $Versioning = Get-BucketConfiguration `
        -Operation "get-bucket-versioning"

    if ($Versioning.Status -ne "Enabled") {
        throw "Versionamento nao habilitado."
    }

    Write-Host "[OK] Versionamento: Enabled."

    $Encryption = Get-BucketConfiguration `
        -Operation "get-bucket-encryption"

    $EncryptionRules = @(
        $Encryption.ServerSideEncryptionConfiguration.Rules
    )

    if ($EncryptionRules.Count -ne 1 -or
        $EncryptionRules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm `
            -ne "AES256") {
        throw "Criptografia padrao diferente de SSE-S3 AES256."
    }

    Write-Host "[OK] Criptografia padrao: SSE-S3 AES256."

    Write-Host "=== Politica de transporte seguro ==="

    $PolicyResponse = Get-BucketConfiguration `
        -Operation "get-bucket-policy"

    $Policy = $PolicyResponse.Policy |
        ConvertFrom-Json -ErrorAction Stop

    $Statements = @($Policy.Statement)

    if ($Policy.Version -ne "2012-10-17" -or
        $Statements.Count -ne 1) {
        throw "Estrutura inesperada da politica do bucket."
    }

    $Statement = $Statements[0]
    $Actions = @($Statement.Action)
    $Resources = @($Statement.Resource)

    if ($Statement.Sid -ne "DenyInsecureTransport" -or
        $Statement.Effect -ne "Deny" -or
        $Statement.Principal -ne "*" -or
        $Actions.Count -ne 1 -or
        $Actions[0] -ne "s3:*" -or
        $Resources.Count -ne 2 -or
        $Resources -notcontains $BucketArn -or
        $Resources -notcontains "$BucketArn/*" -or
        [string]$Statement.Condition.Bool.'aws:SecureTransport' -ne "false") {
        throw "Politica de negacao de transporte inseguro divergente."
    }

    Write-Host "[OK] DenyInsecureTransport para o bucket e seus objetos."

    Write-Host "=== Tags de propriedade ==="

    $Tagging = Get-BucketConfiguration `
        -Operation "get-bucket-tagging"

    $ExpectedTags = @{
        Project     = "cloud-infrastructure-operations-lab"
        Environment = "lab"
        Lab         = "21"
        ManagedBy   = "terraform"
        Owner       = $Owner
        Name        = $BucketName
        Purpose     = "terraform-remote-state"
    }

    foreach ($Key in $ExpectedTags.Keys) {
        $MatchingTags = @(
            $Tagging.TagSet |
                Where-Object { $_.Key -eq $Key }
        )

        if ($MatchingTags.Count -ne 1 -or
            $MatchingTags[0].Value -ne $ExpectedTags[$Key]) {
            throw "Tag ausente, duplicada ou divergente: $Key."
        }
    }

    Write-Host "[OK] Tags do LAB 21 conferidas."

    if ($RequireEmpty) {
        Write-Host "=== Inventario inicial de objetos ==="

        $Inventory = Get-BucketConfiguration `
            -Operation "list-object-versions"

        $Versions = @(
            $Inventory.Versions |
                Where-Object { $null -ne $_ }
        )

        $DeleteMarkers = @(
            $Inventory.DeleteMarkers |
                Where-Object { $null -ne $_ }
        )

        if ($Versions.Count -ne 0 -or $DeleteMarkers.Count -ne 0) {
            throw (
                "Bucket nao vazio: {0} versoes e {1} marcadores." -f
                $Versions.Count, $DeleteMarkers.Count
            )
        }

        Write-Host "[OK] Nenhuma versao ou marcador de exclusao."
    }

    Write-Host "VALIDACAO CONCLUIDA: protecoes do bucket do LAB 21."

    $global:LASTEXITCODE = 0

    if ($PassThru) {
        [pscustomobject]@{
            AccountId         = $ExpectedAccountId
            Region            = $BucketRegion
            BucketName        = $BucketName
            Versioning        = "Enabled"
            Encryption        = "AES256"
            ObjectOwnership   = "BucketOwnerEnforced"
            PublicAccessBlock = $true
            SecureTransport   = $true
            EmptyChecked      = [bool]$RequireEmpty
        }
    }
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Validacao interrompida; nenhum recurso AWS foi alterado."
    $global:LASTEXITCODE = 1
    exit 1
}
