[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [string]$Region = "us-east-1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExpectedAccount = "412381774441"
$InstanceName = "lab17-controlled-update-instance"
$GroupName = "lab17-controlled-update-sg"
$ProfileResourceName = "lab17-ec2-controlled-update-instance-profile"
$ExpectedTags = @{
    Project = "cloud-infrastructure-operations-lab"
    Environment = "lab"
    Lab = "17"
    ManagedBy = "aws-cli"
    Owner = "itamarsb"
}

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& aws @Arguments --profile $ProfileName --region $Region `
            --no-cli-pager 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
    $output = ($lines | ForEach-Object {
        if ($null -ne $_) { $_.ToString() }
    }) -join "`n"
    if ($exitCode -ne 0) {
        throw "AWS CLI falhou: aws $($Arguments -join ' ')`n$output"
    }
    return $output.Trim()
}

function Get-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $json = Invoke-Aws -Arguments ($Arguments + @("--output", "json"))
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "A AWS CLI não retornou JSON."
    }
    return ($json | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-Tags {
    param($Resource, [string]$Name)
    $actual = @{}
    foreach ($tag in @($Resource.Tags)) {
        $actual[[string]$tag.Key] = [string]$tag.Value
    }
    if ($actual["Name"] -ne $Name) {
        throw "Tag Name incompatível em $Name."
    }
    foreach ($key in $ExpectedTags.Keys) {
        if ($actual[$key] -ne $ExpectedTags[$key]) {
            throw "Tag $key incompatível em $Name."
        }
    }
}

function Get-HttpProbe {
    param([string]$Url)
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& curl.exe --noproxy "*" --silent --show-error `
            --max-time 8 --write-out "`nHTTP_STATUS=%{http_code}" $Url 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
    $output = ($lines | ForEach-Object {
        if ($null -ne $_) { $_.ToString() }
    }) -join "`n"
    return "${Url}: exit=$exitCode; $($output.Trim())"
}

function Invoke-ReadOnlySsm {
    param([string]$InstanceId)
    $commands = @(
        "echo '=== MARCADOR DA VERSÃO ==='"
        "if test -f /var/lib/lab17/state; then cat /var/lib/lab17/state; else echo none; fi"
        "echo '=== PACOTE E SERVIÇO ==='"
        "rpm -q nginx || true"
        "systemctl is-active nginx || true"
        "systemctl status nginx --no-pager --lines=12 || true"
        "echo '=== TESTE DA CONFIGURAÇÃO NGINX ==='"
        "if nginx -t 2>&1; then echo NGINX_CONFIG=valid; else echo NGINX_CONFIG=invalid; fi"
        "echo '=== REGISTRO DA CANDIDATA INVÁLIDA ==='"
        "if test -f /var/lib/lab17/failed-candidate.log; then head -n 30 /var/lib/lab17/failed-candidate.log; else echo 'Registro ainda não existe.'; fi"
        "echo '=== RESPOSTAS HTTP LOCAIS ==='"
        "printf 'health: '; curl --noproxy '*' -sS --max-time 5 http://127.0.0.1/health || true; echo"
        "printf 'version: '; curl --noproxy '*' -sS --max-time 5 http://127.0.0.1/version || true; echo"
        "echo '=== BACKUP V1 ==='"
        "if test -f /var/lib/lab17/backup-v1/SHA256SUMS; then (cd /var/lib/lab17/backup-v1 && sha256sum -c SHA256SUMS) || true; else echo 'Backup ainda não existe.'; fi"
        "echo '=== ARQUIVOS ATIVOS ==='"
        "sha256sum /usr/share/nginx/html/index.html /usr/share/nginx/html/health /usr/share/nginx/html/version /etc/nginx/conf.d/lab17-release.conf 2>&1 || true"
        "echo '=== COMPARAÇÃO COM BACKUP ==='"
        "if cmp -s /var/lib/lab17/backup-v1/index.html /usr/share/nginx/html/index.html; then echo 'index.html: idêntico'; else echo 'index.html: diferente'; fi"
        "if cmp -s /var/lib/lab17/backup-v1/health /usr/share/nginx/html/health; then echo 'health: idêntico'; else echo 'health: diferente'; fi"
        "if cmp -s /var/lib/lab17/backup-v1/version /usr/share/nginx/html/version; then echo 'version: idêntico'; else echo 'version: diferente'; fi"
        "if cmp -s /var/lib/lab17/backup-v1/lab17-release.conf /etc/nginx/conf.d/lab17-release.conf; then echo 'lab17-release.conf: idêntico'; else echo 'lab17-release.conf: diferente'; fi"
        "echo '=== LOGS RECENTES DO NGINX ==='"
        "journalctl -u nginx --no-pager -n 25 2>&1 || true"
    )

    $parameters = @{ commands = $commands } | ConvertTo-Json -Depth 5
    $temporaryFile = Join-Path ([IO.Path]::GetTempPath()) `
        ("lab17-diagnose-{0}.json" -f [guid]::NewGuid().ToString("N"))
    try {
        [IO.File]::WriteAllText(
            $temporaryFile,
            $parameters,
            (New-Object System.Text.UTF8Encoding($false))
        )
        $uri = "file://$($temporaryFile.Replace('\', '/'))"
        $response = Get-AwsJson -Arguments @(
            "ssm", "send-command",
            "--instance-ids", $InstanceId,
            "--document-name", "AWS-RunShellScript",
            "--comment", "Lab 17 read-only update diagnosis",
            "--parameters", $uri,
            "--timeout-seconds", "90"
        )
    }
    finally {
        if (Test-Path -LiteralPath $temporaryFile -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryFile -Force
        }
    }

    $commandId = [string]$response.Command.CommandId
    if ([string]::IsNullOrWhiteSpace($commandId)) {
        throw "Systems Manager não retornou CommandId."
    }
    Write-Host "CommandId do diagnóstico: $commandId"

    for ($attempt = 1; $attempt -le 30; $attempt++) {
        Start-Sleep -Seconds 3
        try {
            $invocation = Get-AwsJson -Arguments @(
                "ssm", "get-command-invocation",
                "--command-id", $commandId,
                "--instance-id", $InstanceId
            )
        }
        catch {
            if ($attempt -eq 30) { throw }
            continue
        }
        if ($invocation.Status -eq "Success") {
            Write-Host $invocation.StandardOutputContent
            if ($invocation.StandardErrorContent) {
                Write-Host "Saída de erro: $($invocation.StandardErrorContent)"
            }
            return
        }
        if ($invocation.Status -in @("Failed", "Cancelled", "TimedOut")) {
            throw "Run Command $commandId terminou em $($invocation.Status). Saída: $($invocation.StandardOutputContent) Erro: $($invocation.StandardErrorContent)"
        }
    }
    throw "Run Command $commandId não concluiu no prazo."
}

try {
    if ($Region -ne "us-east-1") { throw "Região inesperada." }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada."
    }
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        throw "curl.exe não encontrado."
    }
    $identity = Get-AwsJson -Arguments @("sts", "get-caller-identity")
    if ($identity.Account -ne $ExpectedAccount) {
        throw "Conta AWS inesperada: $($identity.Account)."
    }

    $response = Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=running"
    )
    $instances = @($response.Reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1) {
        throw "É necessária exatamente uma instância running do Lab 17."
    }
    $instance = $instances[0]
    Assert-Tags -Resource $instance -Name $InstanceName
    if ($instance.MetadataOptions.HttpTokens -ne "required" -or
        $instance.IamInstanceProfile.Arn -notmatch
            "/$([regex]::Escape($ProfileResourceName))$") {
        throw "IMDSv2 ou Instance Profile inesperado."
    }

    $groups = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups", "--filters",
        "Name=group-name,Values=$GroupName",
        "Name=vpc-id,Values=$($instance.VpcId)"
    )).SecurityGroups )
    if ($groups.Count -ne 1) {
        throw "Security Group exclusivo ausente ou ambíguo."
    }
    Assert-Tags -Resource $groups[0] -Name $GroupName
    if (@($instance.SecurityGroups).Count -ne 1 -or
        $instance.SecurityGroups[0].GroupId -ne $groups[0].GroupId) {
        throw "A instância utiliza outro Security Group."
    }

    Write-Host "Conta: $($identity.Account); Região: $Region"
    Write-Host "EC2: $($instance.InstanceId); IP: $($instance.PublicIpAddress)"
    Write-Host "VPC: $($instance.VpcId); sub-rede: $($instance.SubnetId); SG: $($groups[0].GroupId)"
    $rules = @( (Get-AwsJson -Arguments @(
        "ec2", "describe-security-group-rules", "--filters",
        "Name=group-id,Values=$($groups[0].GroupId)"
    )).SecurityGroupRules )
    foreach ($rule in $rules) {
        Write-Host "SG rule: egress=$($rule.IsEgress); protocol=$($rule.IpProtocol); ports=$($rule.FromPort)-$($rule.ToPort); IPv4=$($rule.CidrIpv4)"
    }

    $ssm = Get-AwsJson -Arguments @(
        "ssm", "describe-instance-information", "--filters",
        "Key=InstanceIds,Values=$($instance.InstanceId)"
    )
    $managed = @($ssm.InstanceInformationList | Where-Object {
        $_.InstanceId -eq $instance.InstanceId -and $_.PingStatus -eq "Online"
    })
    Write-Host "SSM Online: $($managed.Count -eq 1)"

    if (-not [string]::IsNullOrWhiteSpace($instance.PublicIpAddress)) {
        Write-Host "=== RESPOSTAS HTTP EXTERNAS ==="
        Write-Host (Get-HttpProbe -Url "http://$($instance.PublicIpAddress)/health")
        Write-Host (Get-HttpProbe -Url "http://$($instance.PublicIpAddress)/version")
    }
    if ($managed.Count -ne 1) {
        throw "Instância fora do Systems Manager; diagnóstico local indisponível."
    }
    Invoke-ReadOnlySsm -InstanceId $instance.InstanceId
    Write-Host "DIAGNOSTICO COLETADO: nenhuma alteração na aplicação." -ForegroundColor Green
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
