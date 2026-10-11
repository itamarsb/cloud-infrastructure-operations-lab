[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly,
    [switch]$CheckStatus
)

. (Join-Path $PSScriptRoot "lab26-common.ps1")

if ($ValidateOnly -and $CheckStatus) {
    throw "Use ValidateOnly ou CheckStatus, separadamente."
}

Initialize-Lab26 -ProfileName $ProfileName

$script:State = Read-Lab26Json -Path $StatePath

$ParsedRunId = [guid]::Empty

if (
    $State.AccountId -ne $Settings.ExpectedAccountId -or
    $State.Region -ne $Settings.Region -or
    -not [guid]::TryParse([string]$State.RunId, [ref]$ParsedRunId) -or
    $State.Ids.Instance -notmatch "^i-[0-9a-f]+$" -or
    $State.Completed -ne $true
) {
    throw "Inventario incompativel ou provisionamento incompleto."
}

if (
    $null -ne $State.PSObject.Properties["CleanupCompleted"] -and
    $State.CleanupCompleted
) {
    throw "O inventario pertence a uma infraestrutura removida."
}

$ReceiptPath = Join-Path $LocalDirectory (
    "agent-install-{0}.json" -f $State.RunId
)

$ConfigText = Get-Content -LiteralPath $AgentConfigurationPath -Raw
$ConfigText = $ConfigText.Replace("`r`n", "`n").Replace("`r", "`n")

if ([string]::IsNullOrWhiteSpace($ConfigText)) {
    throw "Configuracao do agente vazia."
}

$ConfigBytes = [Text.Encoding]::UTF8.GetBytes($ConfigText)
$ConfigBase64 = [Convert]::ToBase64String($ConfigBytes)

$Hasher = [Security.Cryptography.SHA256]::Create()

try {
    $ConfigHash = (
        [BitConverter]::ToString($Hasher.ComputeHash($ConfigBytes))
    ).Replace("-", "").ToLowerInvariant()
}
finally {
    $Hasher.Dispose()
}

function Save-Lab26InstallReceipt {
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $TemporaryPath = "$ReceiptPath.tmp"

    [IO.Directory]::CreateDirectory($LocalDirectory) | Out-Null

    [IO.File]::WriteAllText(
        $TemporaryPath,
        (ConvertTo-Json -InputObject $script:Receipt -Depth 30),
        $Utf8
    )

    Move-Item -LiteralPath $TemporaryPath `
        -Destination $ReceiptPath -Force
}

if ($CheckStatus) {
    $script:Receipt = Read-Lab26Json -Path $ReceiptPath

    if (
        $Receipt.AccountId -ne $State.AccountId -or
        $Receipt.Region -ne $State.Region -or
        $Receipt.RunId -ne $State.RunId -or
        $Receipt.InstanceId -ne $State.Ids.Instance -or
        $Receipt.ConfigSha256 -ne $ConfigHash -or
        [string]::IsNullOrWhiteSpace($Receipt.CommandId)
    ) {
        throw "Recibo incompativel, configuracao alterada ou CommandId ausente."
    }

    $Invocation = Invoke-Lab26Aws -Service ssm `
        -Operation get-command-invocation -Request @{
            CommandId = $Receipt.CommandId
            InstanceId = $Receipt.InstanceId
        } -AbsentCodes @("InvocationDoesNotExist")

    if ($null -eq $Invocation) {
        Write-Host "A invocacao ainda nao esta disponivel. Repita CheckStatus."
        return
    }

    $Receipt.Status = $Invocation.Status
    $Receipt.LastCheckedAtUtc = [DateTime]::UtcNow.ToString("o")
    Save-Lab26InstallReceipt

    $ReportPath = Join-Path $LocalDirectory (
        "agent-install-result-{0}-{1}.json" -f
        $State.RunId,
        [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    )

    $Utf8 = New-Object System.Text.UTF8Encoding($false)

    [IO.File]::WriteAllText(
        $ReportPath,
        (ConvertTo-Json -InputObject $Invocation -Depth 30),
        $Utf8
    )

    Write-Host ""
    Write-Host "LAB 26 - Resultado da instalacao" -ForegroundColor Cyan

    [pscustomobject]@{
        InstanceId   = $Receipt.InstanceId
        CommandId    = $Receipt.CommandId
        Status       = $Invocation.Status
        ResponseCode = $Invocation.ResponseCode
        ReportPath   = $ReportPath
    } | Format-List

    if (-not [string]::IsNullOrWhiteSpace(
        $Invocation.StandardOutputContent
    )) {
        Write-Host $Invocation.StandardOutputContent
    }

    if (-not [string]::IsNullOrWhiteSpace(
        $Invocation.StandardErrorContent
    )) {
        Write-Host $Invocation.StandardErrorContent -ForegroundColor Yellow
    }

    if ($Invocation.Status -in @(
        "Pending", "InProgress", "Delayed", "Cancelling"
    )) {
        Write-Host "Comando ainda em andamento. Repita CheckStatus."
        return
    }

    if (
        $Invocation.Status -ne "Success" -or
        $Invocation.ResponseCode -ne 0
    ) {
        throw "A instalacao nao concluiu com sucesso. Recibo preservado."
    }

    $OutputText = $Invocation.StandardOutputContent

    $ExpectedLines = @(
        "CONFIG_SHA256=$ConfigHash"
        "AGENT_SERVICE=active"
        "AGENT_STATUS=running"
        "INSTALL_COMPLETE_RUN_ID=$($State.RunId)"
    )

    foreach ($Line in $ExpectedLines) {
        $Pattern = "(?m)^" + [regex]::Escape($Line) + "\r?$"

        if ($OutputText -notmatch $Pattern) {
            throw "Confirmacao ausente no resultado: $Line"
        }
    }

    if ($OutputText -notmatch "(?m)^AGENT_VERSION=(.+)\r?$") {
        throw "Versao instalada nao identificada."
    }

    $AgentVersion = $Matches[1].Trim()

    $State.AgentInstalled = $true

    $State | Add-Member -MemberType NoteProperty `
        -Name AgentVersion -Value $AgentVersion -Force

    $State | Add-Member -MemberType NoteProperty `
        -Name AgentConfigSha256 -Value $ConfigHash -Force

    $State | Add-Member -MemberType NoteProperty `
        -Name AgentInstalledAtUtc `
        -Value ([DateTime]::UtcNow.ToString("o")) -Force

    Save-Lab26State

    Write-Host "[OK] Instalacao, configuracao e servico conferidos." `
        -ForegroundColor Green

    Write-Host (
        "Proxima etapa: confirmar a chegada das metricas e do evento de log."
    )
    return
}

if (Test-Path -LiteralPath $ReceiptPath) {
    throw "Recibo existente. Use CheckStatus antes de qualquer nova tentativa."
}

if ($State.AgentInstalled) {
    throw "O inventario ja registra o agente instalado."
}

# Reutiliza a conferencia de propriedade e associacoes.
# ValidateOnly nao remove recursos nem grava o inventario.
& (Join-Path $PSScriptRoot "remove-aws-cloudwatch-agent.ps1") `
    -ProfileName $ProfileName -ValidateOnly

$Response = Invoke-Lab26Aws -Service ec2 `
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
    throw "Instancia nao identificada."
}

$Instance = $Instances[0]

Assert-Lab26Ownership -Resource $Instance `
    -Name $Settings.Names.Instance

if (
    $Instance.State.Name -ne "running" -or
    $Instance.VpcId -ne $State.Ids.Vpc -or
    $Instance.SubnetId -ne $State.Ids.Subnet
) {
    throw "Estado ou rede da instancia diferente do previsto."
}

$Ssm = Invoke-Lab26Aws -Service ssm `
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
    throw "A instancia nao esta Online no SSM."
}

Write-Host "[OK] Instancia running, propriedade e SSM Online conferidos." `
    -ForegroundColor Green

if ($ValidateOnly) {
    Write-Host "[OK] ValidateOnly: nenhuma instalacao enviada." `
        -ForegroundColor Green
    return
}

$EventMarker = "LAB26_AGENT_READY_$($State.RunId)"

# Here-string literal: preserva as variaveis e comandos do shell Linux.
$ShellCommand = @'
#!/bin/sh
set -eu
umask 027

RUN_ID='__RUN_ID__'
EXPECTED_INSTANCE_ID='__INSTANCE_ID__'
CONFIG_HASH='__CONFIG_HASH__'
CONFIG_PATH='/opt/aws/amazon-cloudwatch-agent/etc/lab26-cloudwatch-agent.json'
CTL='/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl'
WORK_DIR='/var/lib/lab26'
APP_LOG='/var/log/lab26/application.log'

mkdir -p "$WORK_DIR"

. /etc/os-release
test "$ID" = "amzn"
test "$VERSION_ID" = "2023"
test "$(uname -m)" = "x86_64"

TOKEN=$(curl -fsS --connect-timeout 5 --max-time 10 \
    -X PUT http://169.254.169.254/latest/api/token \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')

INSTANCE_ID=$(curl -fsS --connect-timeout 5 --max-time 10 \
    -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id)

test "$INSTANCE_ID" = "$EXPECTED_INSTANCE_ID"

printf 'INSTALL_BEGIN_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if ! dnf -y install amazon-cloudwatch-agent python3 \
    >"$WORK_DIR/package-install.log" 2>&1; then
    tail -n 40 "$WORK_DIR/package-install.log"
    exit 1
fi

mkdir -p "$(dirname "$CONFIG_PATH")"
printf '%s' '__CONFIG_BASE64__' | base64 --decode >"$CONFIG_PATH.tmp"
install -m 0600 "$CONFIG_PATH.tmp" "$CONFIG_PATH"
rm -f "$CONFIG_PATH.tmp"

ACTUAL_HASH=$(sha256sum "$CONFIG_PATH" | awk '{print $1}')
test "$ACTUAL_HASH" = "$CONFIG_HASH"
printf 'CONFIG_SHA256=%s\n' "$ACTUAL_HASH"

python3 -m json.tool "$CONFIG_PATH" >/dev/null

mkdir -p /var/log/lab26
touch "$APP_LOG"
chmod 0640 "$APP_LOG"

if ! "$CTL" -a fetch-config -m ec2 -s -c "file:$CONFIG_PATH" \
    >"$WORK_DIR/agent-configure.log" 2>&1; then
    tail -n 40 "$WORK_DIR/agent-configure.log"
    if test -f /opt/aws/amazon-cloudwatch-agent/logs/configuration-validation.log; then
        tail -n 40 /opt/aws/amazon-cloudwatch-agent/logs/configuration-validation.log
    fi
    exit 1
fi

systemctl enable amazon-cloudwatch-agent \
    >"$WORK_DIR/agent-enable.log" 2>&1

systemctl is-active --quiet amazon-cloudwatch-agent
printf 'AGENT_SERVICE=active\n'

"$CTL" -m ec2 -a status >"$WORK_DIR/agent-status.json"

python3 - "$WORK_DIR/agent-status.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    status = json.load(source)

if status.get("status") != "running":
    raise SystemExit("CloudWatch Agent nao esta running.")

version = status.get("version")
if not version:
    raise SystemExit("Versao do agente ausente.")

print("AGENT_STATUS=running")
print("AGENT_VERSION=" + str(version))
PY

printf '%s INFO RunId=%s Marker=LAB26_AGENT_READY_%s Message=CloudWatchAgentStarted\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RUN_ID" "$RUN_ID" >>"$APP_LOG"

printf 'INSTALL_END_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'INSTALL_COMPLETE_RUN_ID=%s\n' "$RUN_ID"
'@

$ShellCommand = $ShellCommand.Replace(
    "__RUN_ID__", [string]$State.RunId
).Replace(
    "__INSTANCE_ID__", [string]$State.Ids.Instance
).Replace(
    "__CONFIG_HASH__", $ConfigHash
).Replace(
    "__CONFIG_BASE64__", $ConfigBase64
)

# Evita enviar CRLF do Windows para o shell Linux.
$ShellCommand = $ShellCommand.Replace("`r`n", "`n").Replace("`r", "`n")

$script:Receipt = [ordered]@{
    AccountId = $State.AccountId
    Region = $State.Region
    RunId = $State.RunId
    InstanceId = $State.Ids.Instance
    CommandId = ""
    RequestedAtUtc = [DateTime]::UtcNow.ToString("o")
    ConfigSha256 = $ConfigHash
    EventMarker = $EventMarker
    Status = "Prepared"
    LastCheckedAtUtc = ""
}

# Registra a tentativa antes do envio.
Save-Lab26InstallReceipt

try {
    $Sent = Invoke-Lab26Aws -Service ssm `
        -Operation send-command -Request @{
            InstanceIds = @($State.Ids.Instance)
            DocumentName = "AWS-RunShellScript"
            Comment = "LAB26 install agent RunId=$($State.RunId)"
            TimeoutSeconds = 120
            Parameters = @{
                commands = @($ShellCommand)
                executionTimeout = @("900")
            }
            MaxConcurrency = "1"
            MaxErrors = "0"
        }

    $CommandId = [string]$Sent.Command.CommandId
    $ParsedCommandId = [guid]::Empty

    if (-not [guid]::TryParse($CommandId, [ref]$ParsedCommandId)) {
        throw "A resposta nao retornou um CommandId valido."
    }

    $Receipt.CommandId = $CommandId
    $Receipt.Status = "Submitted"
    Save-Lab26InstallReceipt

    $State | Add-Member -MemberType NoteProperty `
        -Name AgentInstallationCommandId -Value $CommandId -Force

    Save-Lab26State

    Write-Host ""
    Write-Host "LAB 26 - Instalacao enviada" -ForegroundColor Cyan

    [pscustomobject]@{
        InstanceId   = $State.Ids.Instance
        CommandId    = $CommandId
        ConfigSha256 = $ConfigHash
        EventMarker  = $EventMarker
        ReceiptPath  = $ReceiptPath
    } | Format-List

    Write-Host "[OK] Comando enviado. Confira a conclusao com CheckStatus." `
        -ForegroundColor Green
}
catch {
    Write-Host "Tentativa registrada. Recibo preservado:" `
        -ForegroundColor Yellow

    Write-Host $ReceiptPath
    Write-Host "Confira o resultado antes de reenviar a instalacao."
    throw
}
