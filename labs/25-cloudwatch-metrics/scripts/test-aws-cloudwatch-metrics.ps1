[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab"
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
    [string]::IsNullOrWhiteSpace($State.RunId)
) {
    throw "Inventario incompativel ou cleanup ja registrado."
}

foreach ($Key in @(
    "Vpc", "Subnet", "InternetGateway", "RouteTable",
    "SecurityGroup", "RoleId", "InstanceProfileId",
    "Instance", "Volume"
)) {
    if ([string]::IsNullOrWhiteSpace($State.Ids.$Key)) {
        throw "ID ausente no inventario: $Key"
    }
}

function Write-Lab25Ok {
    param([string]$Message)

    Write-Host "[OK] $Message" -ForegroundColor Green
}

Write-Host ""
Write-Host "LAB 25 - Validacao da infraestrutura" -ForegroundColor Cyan

$Vpc = Get-Lab25Ec2Resource -Operation describe-vpcs `
    -IdParameter VpcIds -Id $State.Ids.Vpc `
    -Collection Vpcs -AbsentCode "InvalidVpcID.NotFound"

if ($null -eq $Vpc) {
    throw "VPC nao encontrada."
}

Assert-Lab25Ownership -Resource $Vpc -Name $Settings.Names.Vpc

if (
    $Vpc.State -ne "available" -or
    $Vpc.CidrBlock -ne $Settings.VpcCidr
) {
    throw "Estado ou CIDR da VPC diferente do previsto."
}

$Subnet = Get-Lab25Ec2Resource -Operation describe-subnets `
    -IdParameter SubnetIds -Id $State.Ids.Subnet `
    -Collection Subnets -AbsentCode "InvalidSubnetID.NotFound"

if ($null -eq $Subnet) {
    throw "Subnet nao encontrada."
}

Assert-Lab25Ownership -Resource $Subnet -Name $Settings.Names.Subnet

if (
    $Subnet.VpcId -ne $State.Ids.Vpc -or
    $Subnet.CidrBlock -ne $Settings.SubnetCidr -or
    $Subnet.AvailabilityZone -ne $Settings.AvailabilityZone -or
    $Subnet.State -ne "available"
) {
    throw "Subnet diferente da prevista."
}

$Gateway = Get-Lab25Ec2Resource `
    -Operation describe-internet-gateways `
    -IdParameter InternetGatewayIds -Id $State.Ids.InternetGateway `
    -Collection InternetGateways `
    -AbsentCode "InvalidInternetGatewayID.NotFound"

if ($null -eq $Gateway) {
    throw "Internet Gateway nao encontrado."
}

Assert-Lab25Ownership -Resource $Gateway `
    -Name $Settings.Names.InternetGateway

$Attachments = @($Gateway.Attachments)
if (
    $Attachments.Count -ne 1 -or
    $Attachments[0].VpcId -ne $State.Ids.Vpc -or
    $Attachments[0].State -ne "available"
) {
    throw "Internet Gateway nao associado corretamente."
}

$RouteTable = Get-Lab25Ec2Resource `
    -Operation describe-route-tables `
    -IdParameter RouteTableIds -Id $State.Ids.RouteTable `
    -Collection RouteTables -AbsentCode "InvalidRouteTableID.NotFound"

if ($null -eq $RouteTable) {
    throw "Tabela de rotas nao encontrada."
}

Assert-Lab25Ownership -Resource $RouteTable `
    -Name $Settings.Names.RouteTable

if ($RouteTable.VpcId -ne $State.Ids.Vpc) {
    throw "Tabela de rotas associada a outra VPC."
}

$SubnetAssociations = @(
    $RouteTable.Associations | Where-Object {
        $_.PSObject.Properties["SubnetId"] -and
        $_.SubnetId -eq $State.Ids.Subnet
    }
)

$DefaultRoutes = @(
    $RouteTable.Routes | Where-Object {
        $_.PSObject.Properties["DestinationCidrBlock"] -and
        $_.DestinationCidrBlock -eq "0.0.0.0/0"
    }
)

if (
    $SubnetAssociations.Count -ne 1 -or
    $SubnetAssociations[0].RouteTableAssociationId -ne
        $State.Ids.Association -or
    $DefaultRoutes.Count -ne 1 -or
    $DefaultRoutes[0].GatewayId -ne $State.Ids.InternetGateway -or
    $DefaultRoutes[0].State -ne "active"
) {
    throw "Associacao ou rota publica diferente da prevista."
}

Write-Lab25Ok "VPC, subnet, Internet Gateway e rota publica."

$SecurityGroup = Get-Lab25Ec2Resource `
    -Operation describe-security-groups `
    -IdParameter GroupIds -Id $State.Ids.SecurityGroup `
    -Collection SecurityGroups -AbsentCode "InvalidGroup.NotFound"

if ($null -eq $SecurityGroup) {
    throw "Security group nao encontrado."
}

Assert-Lab25Ownership -Resource $SecurityGroup `
    -Name $Settings.Names.SecurityGroup

if (
    $SecurityGroup.VpcId -ne $State.Ids.Vpc -or
    @($SecurityGroup.IpPermissions).Count -ne 0
) {
    throw "Security group diferente do previsto ou com regras de entrada."
}

Write-Lab25Ok "Security group exclusivo sem regras de entrada."

$InstanceResponse = Invoke-Lab25Aws -Service ec2 `
    -Operation describe-instances -Request @{
        InstanceIds = @($State.Ids.Instance)
    }

$Instances = @(
    foreach ($Reservation in $InstanceResponse.Reservations) {
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

$InstanceGroups = @($Instance.SecurityGroups)

if (
    $Instance.State.Name -ne "running" -or
    $Instance.InstanceType -ne $Settings.InstanceType -or
    $Instance.VpcId -ne $State.Ids.Vpc -or
    $Instance.SubnetId -ne $State.Ids.Subnet -or
    $Instance.Placement.AvailabilityZone -ne
        $Settings.AvailabilityZone -or
    $InstanceGroups.Count -ne 1 -or
    $InstanceGroups[0].GroupId -ne $State.Ids.SecurityGroup -or
    $Instance.Monitoring.State -ne "disabled" -or
    $Instance.MetadataOptions.HttpTokens -ne "required"
) {
    throw "Configuracao da instancia diferente da prevista."
}

if (
    -not $Instance.PSObject.Properties["PublicIpAddress"] -or
    [string]::IsNullOrWhiteSpace($Instance.PublicIpAddress)
) {
    throw "IPv4 publico nao identificado."
}

$Mappings = @($Instance.BlockDeviceMappings)
if (
    $Mappings.Count -ne 1 -or
    $Mappings[0].DeviceName -ne $Instance.RootDeviceName -or
    $Mappings[0].Ebs.VolumeId -ne $State.Ids.Volume -or
    -not $Mappings[0].Ebs.DeleteOnTermination
) {
    throw "Mapeamento do volume raiz diferente do previsto."
}

$CreditsResponse = Invoke-Lab25Aws -Service ec2 `
    -Operation describe-instance-credit-specifications -Request @{
        InstanceIds = @($State.Ids.Instance)
    }

$Credits = @($CreditsResponse.InstanceCreditSpecifications)
if (
    $Credits.Count -ne 1 -or
    $Credits[0].CpuCredits -ne "standard"
) {
    throw "Modo de creditos diferente de standard."
}

$Volume = Get-Lab25Ec2Resource -Operation describe-volumes `
    -IdParameter VolumeIds -Id $State.Ids.Volume `
    -Collection Volumes -AbsentCode "InvalidVolume.NotFound"

if ($null -eq $Volume) {
    throw "Volume raiz nao encontrado."
}

Assert-Lab25Ownership -Resource $Volume `
    -Name ($Settings.Names.Instance + "-root")

$VolumeAttachments = @($Volume.Attachments)
if (
    $Volume.VolumeType -ne "gp3" -or
    $Volume.Size -ne $Settings.RootVolumeSizeGiB -or
    -not $Volume.Encrypted -or
    $Volume.State -ne "in-use" -or
    $VolumeAttachments.Count -ne 1 -or
    $VolumeAttachments[0].InstanceId -ne $State.Ids.Instance
) {
    throw "Volume raiz diferente do previsto."
}

Write-Lab25Ok "EC2 running, IMDSv2, monitoramento basico e creditos standard."
Write-Lab25Ok "Volume gp3 criptografado com exclusao na terminacao."

$RoleResponse = Invoke-Lab25Aws -Service iam `
    -Operation get-role -Request @{
        RoleName = $Settings.Names.Role
    }

$Role = $RoleResponse.Role
Assert-Lab25Ownership -Resource $Role -Name $Settings.Names.Role

if ($Role.RoleId -ne $State.Ids.RoleId) {
    throw "RoleId diferente do inventario."
}

$ProfileResponse = Invoke-Lab25Aws -Service iam `
    -Operation get-instance-profile -Request @{
        InstanceProfileName = $Settings.Names.InstanceProfile
    }

$InstanceProfile = $ProfileResponse.InstanceProfile
Assert-Lab25Ownership -Resource $InstanceProfile `
    -Name $Settings.Names.InstanceProfile

$ProfileRoles = @($InstanceProfile.Roles)

if (
    $InstanceProfile.InstanceProfileId -ne $State.Ids.InstanceProfileId -or
    $ProfileRoles.Count -ne 1 -or
    $ProfileRoles[0].RoleId -ne $State.Ids.RoleId -or
    $Instance.IamInstanceProfile.Arn -ne $InstanceProfile.Arn
) {
    throw "Instance profile diferente do previsto."
}

$Policies = Invoke-Lab25Aws -Service iam `
    -Operation list-attached-role-policies -Request @{
        RoleName = $Settings.Names.Role
    }

$AttachedPolicies = @($Policies.AttachedPolicies)
if (
    $AttachedPolicies.Count -ne 1 -or
    $AttachedPolicies[0].PolicyArn -ne $PolicyArn
) {
    throw "Politicas anexadas a role diferentes das previstas."
}

$InlinePolicies = Invoke-Lab25Aws -Service iam `
    -Operation list-role-policies -Request @{
        RoleName = $Settings.Names.Role
    }

if (@($InlinePolicies.PolicyNames).Count -ne 0) {
    throw "A role possui politicas inline nao previstas."
}

$SsmResponse = Invoke-Lab25Aws -Service ssm `
    -Operation describe-instance-information -Request @{
        Filters = @(
            @{
                Key = "InstanceIds"
                Values = @($State.Ids.Instance)
            }
        )
    }

$ManagedInstances = @($SsmResponse.InstanceInformationList)
if (
    $ManagedInstances.Count -ne 1 -or
    $ManagedInstances[0].PingStatus -ne "Online"
) {
    throw "Instancia nao esta Online no Systems Manager."
}

$StatusResponse = Invoke-Lab25Aws -Service ec2 `
    -Operation describe-instance-status -Request @{
        InstanceIds = @($State.Ids.Instance)
        IncludeAllInstances = $true
    }

$Statuses = @($StatusResponse.InstanceStatuses)
if (
    $Statuses.Count -ne 1 -or
    $Statuses[0].InstanceStatus.Status -ne "ok" -or
    $Statuses[0].SystemStatus.Status -ne "ok"
) {
    throw "As verificacoes de status da EC2 ainda nao estao ambas em ok."
}

Write-Lab25Ok "Role, instance profile, politica SSM e gerenciamento Online."
Write-Lab25Ok "Verificacoes de instancia e sistema em ok."

# Validacao das consultas antes de executa-las.
$ExpectedQueries = @(
    "CPUUtilization|300|Average,Maximum"
    "NetworkIn|300|Sum"
    "NetworkOut|300|Sum"
    "StatusCheckFailed|60|Maximum"
)

$ActualQueries = @(
    foreach ($Query in $Settings.Metrics.Queries) {
        "{0}|{1}|{2}" -f `
            $Query.MetricName, `
            $Query.PeriodSeconds, `
            (@($Query.Statistics) -join ",")
    }
)

if (
    $Settings.Metrics.Namespace -ne "AWS/EC2" -or
    $Settings.Metrics.DimensionName -ne "InstanceId" -or
    $Settings.Metrics.LookbackMinutes -ne 60
) {
    throw "Configuracao das consultas diferente da prevista."
}

$Differences = @(
    Compare-Object -ReferenceObject $ExpectedQueries `
        -DifferenceObject $ActualQueries
)

if ($Differences.Count -ne 0) {
    throw "Metricas, periodos ou estatisticas diferentes dos previstos."
}

# Janela comum alinhada a cinco minutos, em UTC.
$NowUtc = [DateTime]::UtcNow
$EndUtc = $NowUtc.Date.AddHours($NowUtc.Hour).AddMinutes(
    [math]::Floor($NowUtc.Minute / 5) * 5
)
$StartUtc = $EndUtc.AddMinutes(-60)

$StartText = $StartUtc.ToString("yyyy-MM-ddTHH:mm:ss'Z'")
$EndText = $EndUtc.ToString("yyyy-MM-ddTHH:mm:ss'Z'")

Write-Host ""
Write-Host "LAB 25 - Primeira coleta em repouso" -ForegroundColor Cyan

[pscustomobject]@{
    InstanceId = $State.Ids.Instance
    Namespace = $Settings.Metrics.Namespace
    Dimension = "InstanceId"
    StartTimeUtc = $StartText
    EndTimeUtc = $EndText
    Ec2Status = "ok"
    SsmStatus = "Online"
} | Format-List | Out-Host

$Results = @()
$MetricsWithData = 0

foreach ($Query in $Settings.Metrics.Queries) {
    $Response = Invoke-Lab25Aws -Service cloudwatch `
        -Operation get-metric-statistics -Request @{
            Namespace = $Settings.Metrics.Namespace
            MetricName = $Query.MetricName
            Dimensions = @(
                @{
                    Name = $Settings.Metrics.DimensionName
                    Value = $State.Ids.Instance
                }
            )
            StartTime = $StartText
            EndTime = $EndText
            Period = [int]$Query.PeriodSeconds
            Statistics = @($Query.Statistics)
        }

    $Points = @(
        $Response.Datapoints | Sort-Object -Property {
            ([DateTimeOffset]$_.Timestamp).UtcDateTime
        }
    )

    $Results += [pscustomobject]@{
        MetricName = $Query.MetricName
        PeriodSeconds = $Query.PeriodSeconds
        Statistics = @($Query.Statistics)
        PointCount = $Points.Count
        Datapoints = $Points
    }

    Write-Host ""
    Write-Host (
        "{0} | periodo={1}s | estatisticas={2} | pontos={3}" -f `
            $Query.MetricName, `
            $Query.PeriodSeconds, `
            (@($Query.Statistics) -join ","), `
            $Points.Count
    ) -ForegroundColor Cyan

    if ($Points.Count -eq 0) {
        Write-Host (
            "[SEM DADOS] Nenhum ponto nesta janela. Nao equivale a zero."
        ) -ForegroundColor Yellow
        continue
    }

    $MetricsWithData++

    $Rows = @(
        foreach ($Point in $Points) {
            $Row = [ordered]@{
                TimestampUtc = (
                    [DateTimeOffset]$Point.Timestamp
                ).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss'Z'")
                Unit = $Point.Unit
            }

            foreach ($Statistic in $Query.Statistics) {
                $Row[$Statistic] = $Point.$Statistic
            }

            [pscustomobject]$Row
        }
    )

    # A tela mostra os 12 pontos mais recentes.
    # O relatorio preserva todos os pontos retornados.
    $Rows | Select-Object -Last 12 |
        Format-Table -AutoSize | Out-Host
}

$Report = [ordered]@{
    CollectedAtUtc = [DateTime]::UtcNow.ToString("o")
    Phase = "InitialBaseline"
    AccountId = $State.AccountId
    Region = $State.Region
    RunId = $State.RunId
    InstanceId = $State.Ids.Instance
    Namespace = $Settings.Metrics.Namespace
    Dimensions = @(
        @{
            Name = "InstanceId"
            Value = $State.Ids.Instance
        }
    )
    StartTimeUtc = $StartText
    EndTimeUtc = $EndText
    InfrastructureValidated = $true
    MetricsWithData = $MetricsWithData
    Results = $Results
}

$ReportName = "metrics-baseline-{0}.json" -f (
    [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfff'Z'")
)

$ReportPath = Join-Path (Split-Path -Parent $StatePath) $ReportName
$Utf8 = New-Object System.Text.UTF8Encoding($false)

[IO.File]::WriteAllText(
    $ReportPath,
    (ConvertTo-Json -InputObject $Report -Depth 30),
    $Utf8
)

Write-Host ""
Write-Lab25Ok "Infraestrutura validada por consultas de leitura."
Write-Host "Metricas com dados: $MetricsWithData de 4."
Write-Host "Relatorio local: $ReportPath"

if ($MetricsWithData -lt 4) {
    Write-Host (
        "[PENDENTE] Coleta incompleta. Repetir apos novos pontos serem publicados."
    ) -ForegroundColor Yellow
}
else {
    Write-Lab25Ok "As quatro metricas retornaram pontos na janela consultada."
}
