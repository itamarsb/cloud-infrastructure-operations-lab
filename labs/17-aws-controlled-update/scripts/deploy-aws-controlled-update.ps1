
    if ([string]::IsNullOrWhiteSpace($instanceId)) {
        throw "A AWS CLI não retornou o ID da instância."
    }

    Write-Host "[OK] Instância solicitada: $instanceId"

    $null = Invoke-Aws -Arguments @(
        "ec2", "wait", "instance-running",
        "--instance-ids", $instanceId
    )

    $null = Invoke-Aws -Arguments @(
        "ec2", "wait", "instance-status-ok",
        "--instance-ids", $instanceId
    )

    $description = Get-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--instance-ids", $instanceId
    )

    $instance = @(
        $description.Reservations |
            ForEach-Object { $_.Instances }
    )[0]

    $publicIp = $instance.PublicIpAddress

    if ([string]::IsNullOrWhiteSpace($publicIp)) {
        throw "A instância não recebeu endereço IPv4 público."
    }

    Write-Host ""
    Write-Host "=== Systems Manager ===" -ForegroundColor Cyan

    $ssmOnline = $false

    for ($attempt = 1; $attempt -le 30; $attempt++) {
        $ssmResponse = Get-AwsJson -Arguments @(
            "ssm", "describe-instance-information",
            "--filters",
            "Key=InstanceIds,Values=$instanceId"
        )

        $onlineInstances = @(
            $ssmResponse.InstanceInformationList |
                Where-Object {
                    $_.InstanceId -eq $instanceId -and
                    $_.PingStatus -eq "Online"
                }
        )

        if ($onlineInstances.Count -eq 1) {
            $ssmOnline = $true
            break
        }

        Start-Sleep -Seconds 10
    }

    if (-not $ssmOnline) {
        throw "A instância não ficou Online no Systems Manager."
    }

    Write-Host "[OK] Instância Online no Systems Manager."

    Write-Host ""
    Write-Host "=== Validação HTTP externa ===" `
        -ForegroundColor Cyan

    $httpHealthy = $false

    for ($attempt = 1; $attempt -le 24; $attempt++) {
        try {
            $health = Get-HttpBody -Url "http://$publicIp/health"
            if ($health -eq "healthy") {
                $httpHealthy = $true
                break
            }
        }
        catch {
            # Aguarda o user data e a inicialização do Nginx.
        }

        Start-Sleep -Seconds 10
    }

    if (-not $httpHealthy) {
        throw "O endpoint HTTP /health não respondeu como esperado."
    }

    $page = Get-HttpBody -Url "http://$publicIp/"
    if ($page -notmatch "Lab 17 - Controlled Update") {
        throw "A página principal retornou uma resposta inesperada."
    }

    Write-Host "[OK] Página principal: HTTP 200."
    Write-Host "[OK] Endpoint /health: healthy."

    $version = Get-HttpBody -Url "http://$publicIp/version"
    if ($version -ne "v1") {
        throw "A versão inicial /version não retornou v1."
    }
    Write-Host "[OK] Versão inicial: v1."

    Write-Host ""
    Write-Host "IMPLANTAÇÃO CONCLUÍDA" -ForegroundColor Green
    Write-Host "VPC:             $($vpc.VpcId)"
    Write-Host "Sub-rede:        $($subnet.SubnetId)"
    Write-Host "Security Group:  $groupId"
    Write-Host "Instância:       $instanceId"
    Write-Host "IPv4 público:    $publicIp"
    Write-Host "URL:             http://$publicIp/"
    Write-Host "Origem HTTP:     $AllowedHttpCidr"
    Write-Host "Versão inicial:  v1"
}
catch {
    Write-Host ""
    Write-Host "[FALHA] $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host (
        "Se algum recurso foi criado, registre os IDs exibidos e " +
        "não repita o deploy antes de verificar o estado do Lab 17."
    ) -ForegroundColor Yellow

    exit 1
