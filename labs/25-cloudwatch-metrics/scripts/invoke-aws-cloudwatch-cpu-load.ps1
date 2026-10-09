[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$CheckStatus
)

. (Join-Path $PSScriptRoot "lab25-common.ps1")

Initialize-Lab25

if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    throw "Inventario nao encontrado: $StatePath"
}

$script:State = Get-Content -LiteralPath $StatePath -Raw |
    ConvertFrom-Json

if (
    $State.AccountId -ne $Settings.ExpectedAccountId -or
    $State.Region -ne $Settings.Region -or
    $State.Completed -ne $false -or
    $State.RunId -notmatch "^[0-9a-fA-F-]{36}$" -or
    $State.Ids.Instance -notmatch "^i-[0-9a-f]{17}$"
) {
    throw "Inventario incompativel ou incompleto."
}

$ReceiptPath = Join-Path (Split-Path -Parent $StatePath) (
    "cpu-load-" + $State.RunId + ".json"
)

function Save-Lab25LoadReceipt {
    param(
        [Parameter(Mandatory = $true)]
        $Receipt
    )

    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $Json = ConvertTo-Json -InputObject $Receipt -Depth 30
    $TemporaryPath = "$ReceiptPath.tmp"

    [IO.File]::WriteAllText($TemporaryPath, $Json, $Utf8)

    Move-Item -LiteralPath $TemporaryPath `
        -Destination $ReceiptPath -Force
}

if ($CheckStatus) {
    if (-not (Test-Path -LiteralPath $ReceiptPath -PathType Leaf)) {
        throw "Registro da carga nao encontrado: $ReceiptPath"
    }

    $Receipt = Get-Content -LiteralPath $ReceiptPath -Raw |
        ConvertFrom-Json

    if (
        $Receipt.AccountId -ne $State.AccountId -or
        $Receipt.Region -ne $State.Region -or
        $Receipt.RunId -ne $State.RunId -or
        $Receipt.InstanceId -ne $State.Ids.Instance
    ) {
        throw "Registro da carga incompativel com o inventario."
    }

    if ([string]::IsNullOrWhiteSpace($Receipt.CommandId)) {
        throw (
            "Envio sem CommandId registrado. Preserve o registro " +
            "e confira os comandos SSM antes de tentar outro envio."
        )
    }

    $Invocation = Invoke-Lab25Aws -Service ssm `
        -Operation get-command-invocation -Request @{
            CommandId = $Receipt.CommandId
            InstanceId = $Receipt.InstanceId
        } -AbsentCodes @("InvocationDoesNotExist")

    if ($null -eq $Invocation) {
        Write-Host (
            "[PENDENTE] A invocacao ainda nao esta disponivel. " +
            "Repita a consulta."
        ) -ForegroundColor Yellow
        return
    }

    $Receipt | Add-Member -MemberType NoteProperty `
        -Name Invocation -Value $Invocation -Force

    Save-Lab25LoadReceipt -Receipt $Receipt

    Write-Host ""
    Write-Host "LAB 25 - Status da carga" -ForegroundColor Cyan

    [pscustomobject]@{
        InstanceId = $Receipt.InstanceId
        CommandId = $Receipt.CommandId
        Status = $Invocation.Status
        ResponseCode = $Invocation.ResponseCode
        ExecutionStart = $Invocation.ExecutionStartDateTime
        ExecutionEnd = $Invocation.ExecutionEndDateTime
        ElapsedTime = $Invocation.ExecutionElapsedTime
        ReceiptPath = $ReceiptPath
    } | Format-List | Out-Host

    if (-not [string]::IsNullOrWhiteSpace(
        $Invocation.StandardOutputContent
    )) {
        Write-Host "Saida do comando:"
        Write-Host $Invocation.StandardOutputContent
    }

    if (-not [string]::IsNullOrWhiteSpace(
        $Invocation.StandardErrorContent
    )) {
        Write-Host "Saida de erro:" -ForegroundColor Yellow
        Write-Host $Invocation.StandardErrorContent
    }

    if ($Invocation.Status -eq "Success") {
        if (
            $Invocation.ResponseCode -ne 0 -or
            $Invocation.StandardOutputContent -notmatch
                "(?m)^LOAD_FINISHED_OK\s*$"
        ) {
            throw "Conclusao da carga nao confirmada pela saida."
        }

        Write-Host "[OK] Carga concluida e encerramento confirmado." `
            -ForegroundColor Green
    }
    elseif ($Invocation.Status -in @(
        "Pending", "InProgress", "Delayed", "Cancelling"
    )) {
        Write-Host (
            "[PENDENTE] Comando ainda nao terminou. Repita CheckStatus."
        ) -ForegroundColor Yellow
    }
    else {
        throw "Carga nao concluida com sucesso: $($Invocation.Status)"
    }

    return
}

if (Test-Path -LiteralPath $ReceiptPath) {
    throw (
        "Ja existe registro desta carga. Use -CheckStatus " +
        "para consultar o comando existente."
    )
}

$Response = Invoke-Lab25Aws -Service ec2 `
    -Operation describe-instances -Request @{
        InstanceIds = @($State.Ids.Instance)
    }

$Instances = @(
    foreach ($Reservation in $Response.Reservations) {
        foreach ($Item in $Reservation.Instances) {
            $Item
        }
    }
)

if ($Instances.Count -ne 1) {
    throw "Instancia nao identificada de forma unica."
}

$Instance = $Instances[0]

Assert-Lab25Ownership -Resource $Instance `
    -Name $Settings.Names.Instance

if (
    $Instance.State.Name -ne "running" -or
    $Instance.InstanceType -ne $Settings.InstanceType -or
    $Instance.VpcId -ne $State.Ids.Vpc -or
    $Instance.SubnetId -ne $State.Ids.Subnet
) {
    throw "Instancia diferente do cenario previsto."
}

$Credits = Invoke-Lab25Aws -Service ec2 `
    -Operation describe-instance-credit-specifications -Request @{
        InstanceIds = @($State.Ids.Instance)
    }

$Specifications = @($Credits.InstanceCreditSpecifications)
if (
    $Specifications.Count -ne 1 -or
    $Specifications[0].CpuCredits -ne "standard"
) {
    throw "Modo de creditos diferente de standard."
}

$Ssm = Invoke-Lab25Aws -Service ssm `
    -Operation describe-instance-information -Request @{
        Filters = @(
            @{
                Key = "InstanceIds"
                Values = @($State.Ids.Instance)
            }
        )
    }

$ManagedInstances = @($Ssm.InstanceInformationList)
if (
    $ManagedInstances.Count -ne 1 -or
    $ManagedInstances[0].PingStatus -ne "Online"
) {
    throw "Instancia nao esta Online no Systems Manager."
}

# Registra o saldo de creditos mais recente publicado.
$CreditEndUtc = [DateTime]::UtcNow
$CreditStartUtc = $CreditEndUtc.AddMinutes(-20)

$CreditResponse = Invoke-Lab25Aws -Service cloudwatch `
    -Operation get-metric-statistics -Request @{
        Namespace = "AWS/EC2"
        MetricName = "CPUCreditBalance"
        Dimensions = @(
            @{
                Name = "InstanceId"
                Value = $State.Ids.Instance
            }
        )
        StartTime = $CreditStartUtc.ToString("yyyy-MM-ddTHH:mm:ss'Z'")
        EndTime = $CreditEndUtc.ToString("yyyy-MM-ddTHH:mm:ss'Z'")
        Period = 300
        Statistics = @("Average")
    }

$CreditPoints = @(
    $CreditResponse.Datapoints | Sort-Object -Property {
        ([DateTimeOffset]$_.Timestamp).UtcDateTime
    }
)

$LatestCreditPoint = $null
if ($CreditPoints.Count -gt 0) {
    $LatestCreditPoint = $CreditPoints[-1]

    Write-Host (
        "Saldo de creditos publicado: {0} | timestamp: {1}" -f `
            $LatestCreditPoint.Average, `
            $LatestCreditPoint.Timestamp
    )
}
else {
    Write-Host (
        "CPUCreditBalance sem pontos recentes; carga permanecera em standard."
    ) -ForegroundColor Yellow
}

# Here-string literal: o PowerShell nao expande variaveis do shell.
$ShellCommand = @'
set -eu

command -v timeout >/dev/null
command -v yes >/dev/null
command -v flock >/dev/null

# Impede duas cargas deste laboratorio ao mesmo tempo.
exec 9>/var/tmp/lab25-cpu-load.lock
if ! flock -n 9; then
    echo "LOAD_ALREADY_RUNNING" >&2
    exit 3
fi

echo "LOAD_BEGIN_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "LOAD_DURATION_SECONDS=600"
echo "LOAD_WORKERS=1"

set +e
timeout --signal=TERM --kill-after=5s 600s yes >/dev/null
load_result=$?
set -e

echo "LOAD_END_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "TIMEOUT_EXIT_CODE=$load_result"

# Codigo 124 confirma o limite de tempo atingido pelo timeout.
if [ "$load_result" -ne 124 ]; then
    echo "LOAD_UNEXPECTED_EXIT" >&2
    exit 1
fi

echo "LOAD_FINISHED_OK"
'@

$Receipt = [ordered]@{
    AccountId = $State.AccountId
    Region = $State.Region
    RunId = $State.RunId
    InstanceId = $State.Ids.Instance
    RequestedAtUtc = [DateTime]::UtcNow.ToString("o")
    DurationSeconds = 600
    Workers = 1
    CpuCreditBalanceBefore = $LatestCreditPoint
    CommandId = ""
    Invocation = $null
}

# Preserva a tentativa antes de enviar, evitando reenvio automatico.
Save-Lab25LoadReceipt -Receipt $Receipt

$Command = Invoke-Lab25Aws -Service ssm `
    -Operation send-command -Request @{
        InstanceIds = @($State.Ids.Instance)
        DocumentName = "AWS-RunShellScript"
        Comment = "LAB25 CPU load - one worker - 600 seconds"
        TimeoutSeconds = 120
        Parameters = @{
            commands = @($ShellCommand)
            executionTimeout = @("660")
        }
        MaxConcurrency = "1"
        MaxErrors = "0"
    }

$Receipt.CommandId = $Command.Command.CommandId
Save-Lab25LoadReceipt -Receipt $Receipt

Write-Host ""
Write-Host "LAB 25 - Carga enviada" -ForegroundColor Cyan

[pscustomobject]@{
    InstanceId = $Receipt.InstanceId
    CommandId = $Receipt.CommandId
    RequestedAtUtc = $Receipt.RequestedAtUtc
    DurationSeconds = $Receipt.DurationSeconds
    Workers = $Receipt.Workers
    ReceiptPath = $ReceiptPath
} | Format-List | Out-Host

Write-Host (
    "[OK] Comando enviado. A conclusao sera conferida com -CheckStatus."
) -ForegroundColor Green
