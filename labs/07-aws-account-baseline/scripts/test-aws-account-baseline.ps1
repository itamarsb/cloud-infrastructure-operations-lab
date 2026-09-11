[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ApprovalCount = 0
$script:WarningCount = 0
$script:FailureCount = 0

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host ("=" * 60)
    Write-Host $Title
    Write-Host ("=" * 60)
}

function Write-Check {
    param([string]$Message)

    $script:ApprovalCount++
    Write-Host "[OK]    $Message" -ForegroundColor Green
}

function Write-WarningResult {
    param([string]$Message)

    $script:WarningCount++
    Write-Host "[AVISO] $Message" -ForegroundColor Yellow
}

function Write-Failure {
    param([string]$Message)

    $script:FailureCount++
    Write-Host "[FALHA] $Message" -ForegroundColor Red
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $Output = & aws @Arguments --output json --no-cli-pager 2>&1
    $ExitCode = $LASTEXITCODE
    $Text = ($Output | ForEach-Object { { { "$_" }) -join [Environment]::NewLine

    if ($ExitCode -ne 0) {
        return [pscustomobject]@{
            Success = $false
            Data = $null
            Error = $Text
        }
    }

    try {
        $Data = $Text | ConvertFrom-Json

        return [pscustomobject]@{
            Success = $true
            Data = $Data
            Error = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Data = $null
            Error = "A resposta da AWS CLI não contém JSON válido."
        }
    }
}

function Get-CollectionCount {
    param($Value)

    if ($null -eq $Value) {
        return 0
    }

    return @($Value).Count
}

Write-Host ""
Write-Host "Cloud Infrastructure Operations Lab"
Write-Host "Lab 07 - Baseline operacional da conta AWS"
Write-Host "Modo: somente leitura"
Write-Host ""
Write-Host "Perfil: $ProfileName"
Write-Host "Região: $Region"

Write-Section "1. Ambiente local"

$AwsCommand = Get-Command aws -ErrorAction SilentlyContinue

if ($null -eq $AwsCommand) {
    Write-Failure "AWS CLI não localizada."
}
else {
    Write-Check "AWS CLI localizada."

    $VersionOutput = & aws --version 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "        Versão: $VersionOutput"
    }
    else {
        Write-WarningResult "Não foi possível consultar a versão da AWS CLI."
    }
}

Write-Section "2. Sessão e identidade"

$Identity = Invoke-AwsJson -Arguments @(
    "sts", "get-caller-identity",
    "--profile", $ProfileName
)

$AccountId = $null

if ($Identity.Success) {
    $AccountId = $Identity.Data.Account
    Write-Check "Sessão AWS válida."
    Write-Check "Identidade confirmada pelo AWS STS."
    Write-Host "        Account ID, ARN e UserId confirmados e ocultados."
}
else {
    Write-Failure "Não foi possível confirmar a identidade AWS."
}

$ConfiguredRegion = & aws configure get region --profile $ProfileName 2>$null

if ($LASTEXITCODE -eq 0 -and $ConfiguredRegion -eq $Region) {
    Write-Check "Região padrão confirmada: $Region."
}
elseif ($LASTEXITCODE -eq 0) {
    Write-WarningResult "A Região configurada é diferente da Região esperada."
    Write-Host "        Configurada: $ConfiguredRegion"
    Write-Host "        Esperada:    $Region"
}
else {
    Write-Failure "Não foi possível consultar a Região do perfil."
}

Write-Section "3. Rede"

$VpcResult = Invoke-AwsJson -Arguments @(
    "ec2", "describe-vpcs",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($VpcResult.Success) {
    $VpcCount = Get-CollectionCount $VpcResult.Data.Vpcs
    Write-Check "VPCs acessíveis: $VpcCount"

    $DefaultVpcCount = @(
        $VpcResult.Data.Vpcs |
            Where-Object { $_.IsDefault -eq $true }
    ).Count

    Write-Host "        VPCs padrão: $DefaultVpcCount"
}
else {
    Write-WarningResult "Não foi possível consultar as VPCs."
}

$SubnetResult = Invoke-AwsJson -Arguments @(
    "ec2", "describe-subnets",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($SubnetResult.Success) {
    $SubnetCount = Get-CollectionCount $SubnetResult.Data.Subnets
    Write-Check "Sub-redes acessíveis: $SubnetCount"
}
else {
    Write-WarningResult "Não foi possível consultar as sub-redes."
}

$SecurityGroupResult = Invoke-AwsJson -Arguments @(
    "ec2", "describe-security-groups",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($SecurityGroupResult.Success) {
    $SecurityGroupCount = Get-CollectionCount $SecurityGroupResult.Data.SecurityGroups
    Write-Check "Security Groups acessíveis: $SecurityGroupCount"
}
else {
    Write-WarningResult "Não foi possível consultar os Security Groups."
}

$ElasticIpResult = Invoke-AwsJson -Arguments @(
    "ec2", "describe-addresses",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($ElasticIpResult.Success) {
    $ElasticIpCount = Get-CollectionCount $ElasticIpResult.Data.Addresses
    Write-Check "Endereços IPv4 elásticos existentes: $ElasticIpCount"
}
else {
    Write-WarningResult "Não foi possível consultar os endereços IPv4 elásticos."
}

$NatGatewayResult = Invoke-AwsJson -Arguments @(
    "ec2", "describe-nat-gateways",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($NatGatewayResult.Success) {
    $ActiveNatGateways = @(
        $NatGatewayResult.Data.NatGateways |
            Where-Object {
                $_.State -in @("available", "pending")
            }
    ).Count

    Write-Check "NAT Gateways ativos ou pendentes: $ActiveNatGateways"
}
else {
    Write-WarningResult "Não foi possível consultar os NAT Gateways."
}

Write-Section "4. Computação e armazenamento em bloco"

$InstanceResult = Invoke-AwsJson -Arguments @(
    "ec2", "describe-instances",
    "--profile", $ProfileName,
    "--region", $Region,
    "--filters",
    "Name=instance-state-name,Values=pending,running,stopping,stopped"
)

if ($InstanceResult.Success) {
    $Instances = @(
        $InstanceResult.Data.Reservations |
            ForEach-Object { $_.Instances }
    )

    Write-Check "Instâncias EC2 não terminadas: $($Instances.Count)"

    if ($Instances.Count -gt 0) {
        $Instances |
            Group-Object { $_.State.Name } |
            Sort-Object Name |
            ForEach-Object {
                Write-Host "        Estado $($_.Name): $($_.Count)"
            }

        $StoppedInstances = @(
            $Instances |
                Where-Object { $_.State.Name -eq "stopped" }
        ).Count

        if ($StoppedInstances -gt 0) {
            Write-WarningResult "Existem $StoppedInstances instância(s) EC2 parada(s)."
        }

        $DetailedMonitoringDisabled = @(
            $Instances |
                Where-Object { $_.Monitoring.State -ne "enabled" }
        ).Count

        if ($DetailedMonitoringDisabled -gt 0) {
            Write-WarningResult "Monitoramento detalhado desabilitado em $DetailedMonitoringDisabled instância(s)."
        }
    }
}
else {
    Write-WarningResult "Não foi possível consultar as instâncias EC2."
}

$VolumeResult = Invoke-AwsJson -Arguments @(
    "ec2", "describe-volumes",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($VolumeResult.Success) {
    $Volumes = @($VolumeResult.Data.Volumes)
    Write-Check "Volumes EBS existentes: $($Volumes.Count)"

    $UnencryptedVolumes = @(
        $Volumes |
            Where-Object { $_.Encrypted -ne $true }
    ).Count

    if ($UnencryptedVolumes -gt 0) {
        Write-WarningResult "Existem $UnencryptedVolumes volume(s) EBS sem criptografia."
    }

    $AvailableVolumes = @(
        $Volumes |
            Where-Object { $_.State -eq "available" }
    ).Count

    if ($AvailableVolumes -gt 0) {
        Write-WarningResult "Existem $AvailableVolumes volume(s) EBS sem anexação."
    }

    $TotalVolumeSize = (
        $Volumes |
            Measure-Object -Property Size -Sum
    ).Sum

    if ($null -eq $TotalVolumeSize) {
        $TotalVolumeSize = 0
    }

    Write-Host "        Capacidade provisionada: $TotalVolumeSize GiB"
}
else {
    Write-WarningResult "Não foi possível consultar os volumes EBS."
}

Write-Section "5. Amazon S3"

$BucketResult = Invoke-AwsJson -Arguments @(
    "s3api", "list-buckets",
    "--profile", $ProfileName
)

if ($BucketResult.Success) {
    $Buckets = @($BucketResult.Data.Buckets)
    Write-Check "Buckets S3 acessíveis: $($Buckets.Count)"

    for ($Index = 0; $Index -lt $Buckets.Count; $Index++) {
        $BucketName = $Buckets[$Index].Name
        $BucketLabel = "Bucket-$('{0:D2}' -f ($Index + 1))"

        Write-Host ""
        Write-Host "--- $BucketLabel ---"
        Write-Host "Data de criação: $($Buckets[$Index].CreationDate)"
        Write-Host "Nome: confirmado e ocultado"

        $BucketPublicAccess = Invoke-AwsJson -Arguments @(
            "s3api", "get-public-access-block",
            "--bucket", $BucketName,
            "--profile", $ProfileName
        )

        if ($BucketPublicAccess.Success) {
            $Settings = $BucketPublicAccess.Data.PublicAccessBlockConfiguration

            Write-Host "BlockPublicAcls:       $($Settings.BlockPublicAcls)"
            Write-Host "IgnorePublicAcls:      $($Settings.IgnorePublicAcls)"
            Write-Host "BlockPublicPolicy:     $($Settings.BlockPublicPolicy)"
            Write-Host "RestrictPublicBuckets: $($Settings.RestrictPublicBuckets)"

            if (
                $Settings.BlockPublicAcls -eq $true -and
                $Settings.IgnorePublicAcls -eq $true -and
                $Settings.BlockPublicPolicy -eq $true -and
                $Settings.RestrictPublicBuckets -eq $true
            ) {
                Write-Check "$BucketLabel possui bloqueio integral de acesso público."
            }
            else {
                Write-WarningResult "$BucketLabel não possui bloqueio integral de acesso público."
            }
        }
        else {
            Write-WarningResult "$BucketLabel não possui configuração própria de bloqueio público ou a consulta não foi autorizada."
        }

        $PolicyStatus = Invoke-AwsJson -Arguments @(
            "s3api", "get-bucket-policy-status",
            "--bucket", $BucketName,
            "--profile", $ProfileName
        )

        if ($PolicyStatus.Success) {
            $IsPublic = $PolicyStatus.Data.PolicyStatus.IsPublic
            Write-Host "Política classificada como pública: $IsPublic"

            if ($IsPublic -eq $true) {
                Write-WarningResult "$BucketLabel possui política classificada como pública."
            }
        }
        else {
            Write-Host "Política do bucket: não configurada ou não acessível"
        }

        $AclResult = Invoke-AwsJson -Arguments @(
            "s3api", "get-bucket-acl",
            "--bucket", $BucketName,
            "--profile", $ProfileName
        )

        if ($AclResult.Success) {
            $PublicAclGrant = @(
                $AclResult.Data.Grants |
                    Where-Object {
                        $_.Grantee.URI -match "AllUsers|AuthenticatedUsers"
                    }
            ).Count -gt 0

            Write-Host "ACL com concessão pública: $PublicAclGrant"
            Write-Host "Concessões existentes na ACL: $(@($AclResult.Data.Grants).Count)"

            if ($PublicAclGrant) {
                Write-WarningResult "$BucketLabel possui concessão pública na ACL."
            }
        }
        else {
            Write-WarningResult "A ACL de $BucketLabel não pôde ser consultada."
        }

        $WebsiteResult = Invoke-AwsJson -Arguments @(
            "s3api", "get-bucket-website",
            "--bucket", $BucketName,
            "--profile", $ProfileName
        )

        if ($WebsiteResult.Success) {
            Write-Host "Hospedagem de site: configurada"
        }
        else {
            Write-Host "Hospedagem de site: não configurada"
        }

        $OwnershipResult = Invoke-AwsJson -Arguments @(
            "s3api", "get-bucket-ownership-controls",
            "--bucket", $BucketName,
            "--profile", $ProfileName
        )

        if ($OwnershipResult.Success) {
            $Ownership = $OwnershipResult.Data.OwnershipControls.Rules[0].ObjectOwnership
            Write-Host "Propriedade dos objetos: $Ownership"
        }
        else {
            Write-Host "Propriedade dos objetos: configuração não localizada"
        }

        $EncryptionResult = Invoke-AwsJson -Arguments @(
            "s3api", "get-bucket-encryption",
            "--bucket", $BucketName,
            "--profile", $ProfileName
        )

        if ($EncryptionResult.Success) {
            $EncryptionAlgorithm = $EncryptionResult.Data.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm
            Write-Host "Criptografia padrão: $EncryptionAlgorithm"
        }
        else {
            Write-WarningResult "A criptografia padrão de $BucketLabel não pôde ser confirmada."
        }

        $VersioningResult = Invoke-AwsJson -Arguments @(
            "s3api", "get-bucket-versioning",
            "--bucket", $BucketName,
            "--profile", $ProfileName
        )

        if ($VersioningResult.Success) {
            $VersioningStatus = $VersioningResult.Data.Status

            if ([string]::IsNullOrWhiteSpace([string]$VersioningStatus)) {
                Write-Host "Versionamento: desabilitado"
            }
            else {
                Write-Host "Versionamento: $VersioningStatus"
            }
        }
        else {
            Write-WarningResult "O versionamento de $BucketLabel não pôde ser consultado."
        }

        $ObjectResult = Invoke-AwsJson -Arguments @(
            "s3api", "list-objects-v2",
            "--bucket", $BucketName,
            "--profile", $ProfileName,
            "--max-keys", "1"
        )

        if ($ObjectResult.Success) {
            $ObjectCount = 0

            if ($null -ne $ObjectResult.Data.KeyCount) {
                $ObjectCount = [int]$ObjectResult.Data.KeyCount
            }

            if ($ObjectCount -gt 0) {
                Write-Host "Conteúdo no bucket: existente"
            }
            else {
                Write-Host "Conteúdo no bucket: vazio"
            }
        }
        else {
            Write-WarningResult "O conteúdo de $BucketLabel não pôde ser consultado."
        }
    }
}
else {
    Write-WarningResult "Não foi possível listar os buckets S3."
}

if ($null -ne $AccountId) {
    $AccountPublicAccess = Invoke-AwsJson -Arguments @(
        "s3control", "get-public-access-block",
        "--account-id", $AccountId,
        "--profile", $ProfileName
    )

    Write-Host ""
    Write-Host "--- Proteção do S3 no nível da conta ---"

    if ($AccountPublicAccess.Success) {
        $AccountSettings = $AccountPublicAccess.Data.PublicAccessBlockConfiguration

        Write-Host "BlockPublicAcls:       $($AccountSettings.BlockPublicAcls)"
        Write-Host "IgnorePublicAcls:      $($AccountSettings.IgnorePublicAcls)"
        Write-Host "BlockPublicPolicy:     $($AccountSettings.BlockPublicPolicy)"
        Write-Host "RestrictPublicBuckets: $($AccountSettings.RestrictPublicBuckets)"
    }
    else {
        Write-WarningResult "A configuração de bloqueio público no nível da conta não foi localizada."
    }
}

Write-Section "6. Tags"

$TaggingResult = Invoke-AwsJson -Arguments @(
    "resourcegroupstaggingapi", "get-resources",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($TaggingResult.Success) {
    $TaggedResources = @($TaggingResult.Data.ResourceTagMappingList)
    Write-Check "Recursos retornados pela API de tags: $($TaggedResources.Count)"

    $RequiredTagKeys = @(
        "Name",
        "Environment",
        "Project",
        "Owner",
        "ManagedBy"
    )

    foreach ($TagKey in $RequiredTagKeys) {
        $TaggedCount = @(
            $TaggedResources |
                Where-Object {
                    @($_.Tags.Key) -contains $TagKey
                }
        ).Count

        Write-Host "        ${TagKey}: $TaggedCount de $($TaggedResources.Count)"
    }

    if ($TaggedResources.Count -gt 0) {
        $ResourcesWithoutRequiredTags = @(
            $TaggedResources |
                Where-Object {
                    $ExistingKeys = @($_.Tags.Key)

                    @(
                        $RequiredTagKeys |
                            Where-Object {
                                $ExistingKeys -notcontains $_
                            }
                    ).Count -gt 0
                }
        ).Count

        if ($ResourcesWithoutRequiredTags -gt 0) {
            Write-WarningResult "Existem $ResourcesWithoutRequiredTags recurso(s) sem a cobertura completa das tags definidas."
        }
    }
}
else {
    Write-WarningResult "Não foi possível consultar a API de tags."
}

Write-Section "7. Operação e observabilidade"

$ManagedNodeResult = Invoke-AwsJson -Arguments @(
    "ssm", "describe-instance-information",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($ManagedNodeResult.Success) {
    $ManagedNodeCount = Get-CollectionCount $ManagedNodeResult.Data.InstanceInformationList
    Write-Check "Nós registrados no Systems Manager: $ManagedNodeCount"

    if ($ManagedNodeCount -eq 0) {
        Write-WarningResult "Nenhum nó está registrado no Systems Manager."
    }
}
else {
    Write-WarningResult "Não foi possível consultar os nós do Systems Manager."
}

$LogGroupResult = Invoke-AwsJson -Arguments @(
    "logs", "describe-log-groups",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($LogGroupResult.Success) {
    $LogGroups = @($LogGroupResult.Data.logGroups)
    Write-Check "Grupos de logs do CloudWatch: $($LogGroups.Count)"

    $WithoutRetention = @(
        $LogGroups |
            Where-Object {
                $null -eq $_.retentionInDays
            }
    ).Count

    Write-Host "        Grupos sem retenção definida: $WithoutRetention"

    if ($WithoutRetention -gt 0) {
        Write-WarningResult "Existem grupos de logs sem retenção definida."
    }
}
else {
    Write-WarningResult "Não foi possível consultar os grupos de logs."
}

$AlarmResult = Invoke-AwsJson -Arguments @(
    "cloudwatch", "describe-alarms",
    "--profile", $ProfileName,
    "--region", $Region
)

if ($AlarmResult.Success) {
    $AlarmCount = Get-CollectionCount $AlarmResult.Data.MetricAlarms
    Write-Check "Alarmes métricos do CloudWatch: $AlarmCount"

    if ($AlarmCount -eq 0) {
        Write-WarningResult "Nenhum alarme métrico foi localizado."
    }
}
else {
    Write-WarningResult "Não foi possível consultar os alarmes do CloudWatch."
}

Write-Section "8. Controle orçamentário"

if ($null -ne $AccountId) {
    $BudgetResult = Invoke-AwsJson -Arguments @(
        "budgets", "describe-budgets",
        "--account-id", $AccountId,
        "--profile", $ProfileName,
        "--region", $Region
    )

    if ($BudgetResult.Success) {
        $BudgetCount = Get-CollectionCount $BudgetResult.Data.Budgets
        Write-Check "Orçamentos configurados: $BudgetCount"

        if ($BudgetCount -eq 0) {
            Write-WarningResult "Nenhum orçamento foi localizado."
        }
    }
    else {
        Write-WarningResult "Não foi possível consultar os orçamentos."
    }
}
else {
    Write-WarningResult "Consulta de orçamentos ignorada porque a conta não foi confirmada."
}

Write-Section "Resumo"

Write-Host "Aprovações: $script:ApprovalCount"
Write-Host "Avisos:     $script:WarningCount"
Write-Host "Falhas:     $script:FailureCount"
Write-Host ""

if ($script:FailureCount -gt 0) {
    Write-Host "RESULTADO: BASELINE NÃO CONCLUÍDA" -ForegroundColor Red
    Write-Host "Uma ou mais verificações essenciais falharam."
}
elseif ($script:WarningCount -gt 0) {
    Write-Host "RESULTADO: BASELINE CONCLUÍDA COM PONTOS DE ATENÇÃO" -ForegroundColor Yellow
    Write-Host "Os avisos devem ser avaliados antes de novas implantações."
}
else {
    Write-Host "RESULTADO: BASELINE CONCLUÍDA" -ForegroundColor Green
    Write-Host "Nenhum ponto de atenção foi identificado."
}

Write-Host ""
Write-Host "[OK] Nenhum identificador completo foi exibido."
Write-Host "[OK] Nenhum recurso AWS foi criado, alterado ou removido."

if ($script:FailureCount -gt 0) {
    $global:LASTEXITCODE = 1
}
else {
    $global:LASTEXITCODE = 0
}
