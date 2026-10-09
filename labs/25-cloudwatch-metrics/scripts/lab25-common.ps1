Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Lab25Aws {
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
        $Json = ConvertTo-Json -InputObject $Request -Depth 30
        [IO.File]::WriteAllText($InputPath, $Json, $Utf8)

        $Arguments = @(
            $Service
            $Operation
            "--cli-input-json"
            "file://$InputPath"
            "--profile"
            $ProfileName
            "--region"
            $Settings.Region
            "--output"
            "json"
            "--no-cli-pager"
            "--no-cli-auto-prompt"
        )

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

            throw "AWS $Service $Operation falhou: $ErrorText"
        }

        $Text = $Output -join [Environment]::NewLine
        if (-not [string]::IsNullOrWhiteSpace($Text)) {
            return ($Text | ConvertFrom-Json)
        }
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
        Remove-Item -LiteralPath $InputPath, $ErrorPath `
            -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-Lab25 {
    $script:Settings = Get-Content -LiteralPath (
        Join-Path $PSScriptRoot "..\config\lab25-settings.json"
    ) -Raw | ConvertFrom-Json

    if (
        $Settings.ExpectedAccountId -ne "412381774441" -or
        $Settings.Region -ne "us-east-1" -or
        $Settings.AvailabilityZone -ne "us-east-1a" -or
        $Settings.InstanceType -ne "t3.micro" -or
        $Settings.CpuCredits -ne "standard" -or
        $Settings.RootVolumeSizeGiB -ne 8 -or
        $Settings.VpcCidr -ne "10.25.0.0/16" -or
        $Settings.SubnetCidr -ne "10.25.1.0/24"
    ) {
        throw "Configuracao diferente do cenario aprovado."
    }

    if (
        $Settings.Tags.Project -ne "cloud-infrastructure-operations-lab" -or
        $Settings.Tags.Lab -ne "25" -or
        $Settings.Tags.ManagedBy -ne "lab25-powershell"
    ) {
        throw "Tags diferentes das previstas."
    }

    $ExpectedNames = @{
        Vpc             = "lab25-cloudwatch-vpc"
        Subnet          = "lab25-cloudwatch-public-subnet-a"
        InternetGateway = "lab25-cloudwatch-igw"
        RouteTable      = "lab25-cloudwatch-public-rt"
        SecurityGroup   = "lab25-cloudwatch-instance-sg"
        Role            = "lab25-cloudwatch-ec2-role"
        InstanceProfile = "lab25-cloudwatch-ec2-profile"
        Instance        = "lab25-cloudwatch-instance"
        Dashboard       = "lab25-cloudwatch-metrics"
    }

    foreach ($Key in $ExpectedNames.Keys) {
        if ($Settings.Names.$Key -ne $ExpectedNames[$Key]) {
            throw "Nome diferente do previsto: $Key"
        }
    }

    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw "LOCALAPPDATA nao definido."
    }

    $script:StatePath = Join-Path $env:LOCALAPPDATA (
        "cloud-infrastructure-operations-lab\lab25\deployment.json"
    )

    $script:PolicyArn = (
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    )

    $Identity = Invoke-Lab25Aws -Service sts `
        -Operation get-caller-identity

    if ($Identity.Account -ne $Settings.ExpectedAccountId) {
        throw "A sessao AWS pertence a outra conta."
    }

    Write-Host "[OK] Conta e configuracao conferidas." `
        -ForegroundColor Green
}

function Save-Lab25State {
    $Directory = Split-Path -Parent $StatePath
    [IO.Directory]::CreateDirectory($Directory) | Out-Null

    $TemporaryPath = "$StatePath.tmp"
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $Json = ConvertTo-Json -InputObject $State -Depth 30

    [IO.File]::WriteAllText($TemporaryPath, $Json, $Utf8)
    Move-Item -LiteralPath $TemporaryPath `
        -Destination $StatePath -Force
}

function Get-Lab25Tags {
    param([string]$Name)

    return @(
        @{ Key = "Name"; Value = $Name }
        @{ Key = "Project"; Value = $Settings.Tags.Project }
        @{ Key = "Lab"; Value = $Settings.Tags.Lab }
        @{ Key = "ManagedBy"; Value = $Settings.Tags.ManagedBy }
        @{ Key = "RunId"; Value = $State.RunId }
    )
}

function Assert-Lab25Ownership {
    param(
        [Parameter(Mandatory = $true)]
        $Resource,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not $Resource.PSObject.Properties["Tags"]) {
        throw "Recurso sem tags: $Name"
    }

    foreach ($ExpectedTag in @(Get-Lab25Tags -Name $Name)) {
        $Matches = @(
            $Resource.Tags | Where-Object {
                $_.Key -eq $ExpectedTag.Key -and
                $_.Value -eq $ExpectedTag.Value
            }
        )

        if ($Matches.Count -ne 1) {
            throw "Identidade do recurso nao confirmada: $Name"
        }
    }
}

function Get-Lab25Ec2Resource {
    param(
        [string]$Operation,
        [string]$IdParameter,
        [string]$Id,
        [string]$Collection,
        [string]$AbsentCode
    )

    if ([string]::IsNullOrWhiteSpace($Id)) {
        return $null
    }

    $Request = @{}
    $Request[$IdParameter] = @($Id)

    $Response = Invoke-Lab25Aws -Service ec2 `
        -Operation $Operation -Request $Request `
        -AbsentCodes @($AbsentCode)

    if ($null -eq $Response) {
        return $null
    }

    $Resources = @($Response.$Collection)
    if ($Resources.Count -ne 1) {
        throw "Resposta inesperada ao consultar $Id."
    }

    return $Resources[0]
}
