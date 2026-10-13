Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Lab27ScriptsPath = $PSScriptRoot

function Read-Lab27Json {
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

function Assert-Lab27Section {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Document,

        [Parameter(Mandatory = $true)]
        [hashtable]$Expected,

        [Parameter(Mandatory = $true)]
        [string]$SectionName
    )

    foreach ($Key in $Expected.Keys) {
        $Property = $Document.PSObject.Properties[$Key]

        if ($null -eq $Property) {
            throw "Configuracao sem o campo: $SectionName.$Key"
        }

        $ActualValue = $Property.Value
        $ExpectedValue = $Expected[$Key]

        if ($ExpectedValue -is [bool]) {
            if (
                $ActualValue -isnot [bool] -or
                $ActualValue -ne $ExpectedValue
            ) {
                throw "Valor diferente do previsto: $SectionName.$Key"
            }
        }
        elseif ($ExpectedValue -is [string]) {
            if (
                $ActualValue -isnot [string] -or
                $ActualValue -cne $ExpectedValue
            ) {
                throw "Valor diferente do previsto: $SectionName.$Key"
            }
        }
        else {
            if (
                $ActualValue -isnot [int] -and
                $ActualValue -isnot [long]
            ) {
                throw "O campo deve ser inteiro: $SectionName.$Key"
            }

            if ($ActualValue -ne $ExpectedValue) {
                throw "Valor diferente do previsto: $SectionName.$Key"
            }
        }
    }
}

function Invoke-Lab27Aws {
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
            $script:Lab27ProfileName
            "--region"
            $script:Settings.Region
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

            if ([string]::IsNullOrWhiteSpace($ErrorText)) {
                $ErrorText = "Codigo de saida: $ExitCode"
            }

            throw "AWS $Service $Operation falhou: $ErrorText"
        }

        $Text = $Output -join [Environment]::NewLine

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

function Initialize-Lab27 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )

    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        throw "Informe o perfil AWS."
    }

    Get-Command aws -CommandType Application -ErrorAction Stop |
        Out-Null

    $script:Lab27ProfileName = $ProfileName

    $ConfigPath = Join-Path $script:Lab27ScriptsPath (
        "..\config\lab27-settings.json"
    )

    $script:Settings = Read-Lab27Json -Path $ConfigPath

    Assert-Lab27Section -Document $Settings `
        -SectionName "Settings" -Expected @{
            ExpectedAccountId = "412381774441"
            Region = "us-east-1"
        }

    $ExpectedSections = @{
        Names = @{
            Topic = "lab27-cloudwatch-alarm-notifications"
            Alarm = "lab27-controlled-application-errors"
        }
        Tags = @{
            Project = "cloud-infrastructure-operations-lab"
            Lab = "27"
            ManagedBy = "lab27-powershell"
        }
        Metric = @{
            Namespace = "Lab27/ControlledApplication"
            MetricName = "ApplicationErrorCount"
            Unit = "Count"
            StorageResolution = 60
            Scenario = "controlled-application-errors"
        }
        Alarm = @{
            Statistic = "Sum"
            PeriodSeconds = 60
            EvaluationPeriods = 3
            DatapointsToAlarm = 2
            Threshold = 3
            ComparisonOperator = "GreaterThanOrEqualToThreshold"
            TreatMissingData = "missing"
            NotifyOnAlarm = $true
            NotifyOnOk = $true
            NotifyOnInsufficientData = $false
        }
        Stimulus = @{
            BaselineValue = 0
            BreachValue = 5
            RecoveryValue = 0
            IntervalSeconds = 60
            MaximumSamplesPerPhase = 10
        }
    }

    foreach ($SectionName in $ExpectedSections.Keys) {
        $SectionProperty = $Settings.PSObject.Properties[$SectionName]

        if (
            $null -eq $SectionProperty -or
            $null -eq $SectionProperty.Value -or
            $SectionProperty.Value -isnot
                [System.Management.Automation.PSCustomObject]
        ) {
            throw "Secao ausente ou invalida: $SectionName"
        }

        Assert-Lab27Section `
            -Document $SectionProperty.Value `
            -Expected $ExpectedSections[$SectionName] `
            -SectionName $SectionName
    }

    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw "LOCALAPPDATA nao definido."
    }

    $script:LocalDirectory = Join-Path $env:LOCALAPPDATA (
        "cloud-infrastructure-operations-lab\lab27"
    )

    $script:StatePath = Join-Path $script:LocalDirectory (
        "deployment.json"
    )

    $Identity = Invoke-Lab27Aws `
        -Service "sts" `
        -Operation "get-caller-identity"

    if (
        $null -eq $Identity -or
        $Identity.Account -cne $Settings.ExpectedAccountId
    ) {
        throw "A identidade AWS nao corresponde a conta do laboratorio."
    }

    $script:Lab27Identity = $Identity

    Write-Host "[OK] Configuracao do LAB 27 conferida." `
        -ForegroundColor Green

    Write-Host "[OK] Conta: $($Identity.Account)" `
        -ForegroundColor Green

    Write-Host "[OK] Perfil: $ProfileName" `
        -ForegroundColor Green

    Write-Host "[OK] Regiao: $($Settings.Region)" `
        -ForegroundColor Green

    Write-Host "[INFO] Inventario previsto: $script:StatePath"
}
