Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Lab26ScriptsPath = $PSScriptRoot

function Read-Lab26Json {
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

function Invoke-Lab26Aws {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Service,

        [Parameter(Mandatory = $true)]
        [string]$Operation,

        [hashtable]$Request = @{},

        [string[]]$AbsentCodes = @()
    )

    $InputPath = [IO.Path]::GetTempFileName()
    $ErrorPath = [IO.Path]::GetTempFileName()
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $PreviousPreference = $ErrorActionPreference

    try {
        $Json = ConvertTo-Json -InputObject $Request -Depth 40
        [IO.File]::WriteAllText($InputPath, $Json, $Utf8)

        $Arguments = @(
            $Service
            $Operation
            "--cli-input-json"
            "file://$InputPath"
            "--profile"
            $script:Lab26ProfileName
            "--region"
            $script:Settings.Region
            "--output"
            "json"
            "--no-cli-pager"
            "--no-cli-auto-prompt"
        )

        # PowerShell 5.1 pode tratar stderr de programas nativos
        # como NativeCommandError. O codigo de saida decide a falha.
        $ErrorActionPreference = "Continue"
        $Output = @(& aws @Arguments 2> $ErrorPath)
        $ExitCode = $LASTEXITCODE
        $ErrorActionPreference = $PreviousPreference

        $ErrorText = [IO.File]::ReadAllText($ErrorPath)

        if ($ExitCode -ne 0) {
            foreach ($Code in $AbsentCodes) {
                $Pattern = "\(" + [regex]::Escape($Code) + "\)"

                if ($ErrorText -match $Pattern) {
                    return $null
                }
            }

            if ([string]::IsNullOrWhiteSpace($ErrorText)) {
                $ErrorText = "Codigo de saida: $ExitCode"
            }

            throw "AWS $Service $Operation falhou: $ErrorText"
        }

        $Text = $Output -join [Environment]::NewLine

        # Algumas operacoes de escrita nao retornam corpo.
        if ([string]::IsNullOrWhiteSpace($Text)) {
            return $null
        }

        return (ConvertFrom-Json -InputObject $Text)
    }
    finally {
        $ErrorActionPreference = $PreviousPreference

        Remove-Item -LiteralPath $InputPath, $ErrorPath `
            -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-Lab26 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )

    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        throw "Informe o perfil AWS."
    }

    Get-Command aws -CommandType Application -ErrorAction Stop |
        Out-Null

    $script:Lab26ProfileName = $ProfileName
    $script:ConfigPath = Join-Path $script:Lab26ScriptsPath "..\config"

    $script:Settings = Read-Lab26Json -Path (
        Join-Path $script:ConfigPath "lab26-settings.json"
    )

    if (
        $Settings.ExpectedAccountId -ne "412381774441" -or
        $Settings.Region -ne "us-east-1" -or
        $Settings.AvailabilityZone -ne "us-east-1a" -or
        $Settings.InstanceType -ne "t3.micro" -or
        $Settings.CpuCredits -ne "standard" -or
        $Settings.RootVolumeSizeGiB -ne 8 -or
        $Settings.RootVolumeType -ne "gp3" -or
        $Settings.VpcCidr -ne "10.26.0.0/16" -or
        $Settings.SubnetCidr -ne "10.26.1.0/24" -or
        $Settings.AmiParameter -ne (
            "/aws/service/ami-amazon-linux-latest/" +
            "al2023-ami-kernel-default-x86_64"
        )
    ) {
        throw "Configuracao diferente do cenario previsto."
    }

    if (
        $Settings.Tags.Project -ne "cloud-infrastructure-operations-lab" -or
        $Settings.Tags.Lab -ne "26" -or
        $Settings.Tags.ManagedBy -ne "lab26-powershell"
    ) {
        throw "Tags diferentes das previstas."
    }

    $ExpectedNames = @{
        Vpc               = "lab26-cloudwatch-agent-vpc"
        Subnet            = "lab26-cloudwatch-agent-public-subnet-a"
        InternetGateway   = "lab26-cloudwatch-agent-igw"
        RouteTable        = "lab26-cloudwatch-agent-public-rt"
        SecurityGroup     = "lab26-cloudwatch-agent-instance-sg"
        Role              = "lab26-cloudwatch-agent-ec2-role"
        InstanceProfile   = "lab26-cloudwatch-agent-ec2-profile"
        Instance          = "lab26-cloudwatch-agent-instance"
        AgentInlinePolicy = "lab26-cloudwatch-agent-publish"
    }

    foreach ($Key in $ExpectedNames.Keys) {
        if ($Settings.Names.$Key -cne $ExpectedNames[$Key]) {
            throw "Nome diferente do previsto: $Key"
        }
    }

    if (
        $Settings.Iam.SsmManagedPolicyArn -ne
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" -or
        $Settings.Iam.TrustPolicyFile -ne
            "ec2-ssm-trust-policy.json" -or
        $Settings.Iam.AgentPolicyFile -ne
            "cloudwatch-agent-publish-policy.json" -or
        $Settings.Agent.ConfigurationFile -ne
            "cloudwatch-agent.json"
    ) {
        throw "Politica SSM ou nomes dos arquivos diferentes dos previstos."
    }

    if (
        $Settings.Agent.RemoteConfigurationPath -ne
            "/opt/aws/amazon-cloudwatch-agent/etc/lab26-cloudwatch-agent.json" -or
        $Settings.Agent.ServiceName -ne "amazon-cloudwatch-agent" -or
        $Settings.Agent.DiagnosticLogPath -ne
            "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
    ) {
        throw "Caminhos ou servico do agente diferentes dos previstos."
    }

    if (
        $Settings.Metrics.Namespace -ne "Lab26/CWAgent" -or
        $Settings.Metrics.CollectionIntervalSeconds -ne 60 -or
        $Settings.Logs.LogGroupName -ne
            "/cloud-infrastructure-operations-lab/lab26/application" -or
        $Settings.Logs.RetentionInDays -ne 1 -or
        $Settings.Logs.ApplicationLogPath -ne
            "/var/log/lab26/application.log" -or
        $Settings.Logs.LogStreamName -ne "{instance_id}" -or
        $Settings.Logs.TimestampFormat -ne "%Y-%m-%dT%H:%M:%SZ" -or
        $Settings.Logs.Timezone -ne "UTC"
    ) {
        throw "Parametros de metricas ou logs diferentes dos previstos."
    }

    $script:TrustPolicyPath = Join-Path $script:ConfigPath (
        $Settings.Iam.TrustPolicyFile
    )

    $script:AgentPolicyPath = Join-Path $script:ConfigPath (
        $Settings.Iam.AgentPolicyFile
    )

    $script:AgentConfigurationPath = Join-Path $script:ConfigPath (
        $Settings.Agent.ConfigurationFile
    )

    $script:TrustPolicy = Read-Lab26Json -Path $script:TrustPolicyPath
    $script:AgentPolicy = Read-Lab26Json -Path $script:AgentPolicyPath
    $script:AgentConfiguration = Read-Lab26Json -Path (
        $script:AgentConfigurationPath
    )

    foreach ($Section in @("agent", "metrics", "logs")) {
        if (
            $null -eq
                $AgentConfiguration.PSObject.Properties[$Section]
        ) {
            throw "Configuracao do agente sem a secao: $Section"
        }
    }

    if (
        $AgentConfiguration.agent.region -ne $Settings.Region -or
        $AgentConfiguration.agent.metrics_collection_interval -ne 60 -or
        $AgentConfiguration.metrics.namespace -ne
            $Settings.Metrics.Namespace -or
        $AgentConfiguration.metrics.append_dimensions.InstanceId -cne
            '${aws:InstanceId}'
    ) {
        throw "Configuracao principal do agente diferente da prevista."
    }

    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw "LOCALAPPDATA nao definido."
    }

    $script:LocalDirectory = Join-Path $env:LOCALAPPDATA (
        "cloud-infrastructure-operations-lab\lab26"
    )

    $script:StatePath = Join-Path $script:LocalDirectory "deployment.json"
    $script:PolicyArn = $Settings.Iam.SsmManagedPolicyArn

    $Identity = Invoke-Lab26Aws -Service sts `
        -Operation get-caller-identity

    if (
        $null -eq $Identity -or
        $Identity.Account -ne $Settings.ExpectedAccountId
    ) {
        throw "A identidade AWS nao corresponde a conta do laboratorio."
    }

    Write-Host "[OK] Conta e configuracao conferidas." `
        -ForegroundColor Green
}

function Save-Lab26State {
    $Directory = Split-Path -Parent $script:StatePath
    [IO.Directory]::CreateDirectory($Directory) | Out-Null

    $TemporaryPath = "$($script:StatePath).tmp"
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $Json = ConvertTo-Json -InputObject $script:State -Depth 40

    [IO.File]::WriteAllText($TemporaryPath, $Json, $Utf8)

    Move-Item -LiteralPath $TemporaryPath `
        -Destination $script:StatePath -Force
}

function Get-Lab26Tags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace([string]$script:State.RunId)) {
        throw "RunId nao definido no inventario."
    }

    return @(
        @{ Key = "Name"; Value = $Name }
        @{ Key = "Project"; Value = $Settings.Tags.Project }
        @{ Key = "Lab"; Value = $Settings.Tags.Lab }
        @{ Key = "ManagedBy"; Value = $Settings.Tags.ManagedBy }
        @{ Key = "RunId"; Value = $script:State.RunId }
    )
}

function Assert-Lab26Ownership {
    param(
        [Parameter(Mandatory = $true)]
        $Resource,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Resource.PSObject.Properties["Tags"]) {
        throw "Recurso sem tags: $Name"
    }

    foreach ($ExpectedTag in @(Get-Lab26Tags -Name $Name)) {
        $MatchingTags = @(
            $Resource.Tags | Where-Object {
                $_.Key -ceq $ExpectedTag.Key -and
                $_.Value -ceq $ExpectedTag.Value
            }
        )

        if ($MatchingTags.Count -ne 1) {
            throw "Propriedade do recurso nao confirmada: $Name"
        }
    }
}

function Get-Lab26Ec2Resource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,

        [Parameter(Mandatory = $true)]
        [string]$IdParameter,

        [AllowEmptyString()]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Collection,

        [string]$AbsentCode = ""
    )

    if ([string]::IsNullOrWhiteSpace($Id)) {
        return $null
    }

    $Request = @{}
    $Request[$IdParameter] = @($Id)

    $Codes = @()

    if (-not [string]::IsNullOrWhiteSpace($AbsentCode)) {
        $Codes = @($AbsentCode)
    }

    $Response = Invoke-Lab26Aws -Service ec2 `
        -Operation $Operation -Request $Request `
        -AbsentCodes $Codes

    if ($null -eq $Response) {
        return $null
    }

    $Resources = @($Response.$Collection)

    if ($Resources.Count -eq 0) {
        return $null
    }

    if ($Resources.Count -ne 1) {
        throw "Resposta inesperada ao consultar $Id."
    }

    return $Resources[0]
}
