[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly
)

. (Join-Path $PSScriptRoot "lab26-common.ps1")

Initialize-Lab26 -ProfileName $ProfileName

if (Test-Path -LiteralPath $StatePath) {
    throw "Inventario existente: $StatePath. Confira-o antes de um novo deploy."
}

# Validacao das configuracoes antes de qualquer escrita na AWS.
$Statements = @($TrustPolicy.Statement)

if (
    $TrustPolicy.Version -ne "2012-10-17" -or
    $Statements.Count -ne 1
) {
    throw "Estrutura da trust policy diferente da prevista."
}

if (
    $Statements[0].Effect -ne "Allow" -or
    $Statements[0].Principal.Service -ne "ec2.amazonaws.com" -or
    $Statements[0].Action -ne "sts:AssumeRole"
) {
    throw "Trust policy diferente da prevista."
}

$Collectors = @(
    $AgentConfiguration.metrics.metrics_collected.PSObject.Properties.Name |
        Sort-Object
)

if (($Collectors -join ",") -ne "disk,mem") {
    throw "Devem existir apenas os coletores disk e mem."
}

$Memory = $AgentConfiguration.metrics.metrics_collected.mem
$Disk = $AgentConfiguration.metrics.metrics_collected.disk

if (
    (@($Memory.measurement) -join ",") -ne "used_percent" -or
    (@($Disk.measurement) -join ",") -ne "used_percent" -or
    (@($Disk.resources) -join ",") -ne "/" -or
    $Memory.metrics_collection_interval -ne 60 -or
    $Disk.metrics_collection_interval -ne 60 -or
    $Disk.drop_device -ne $true -or
    $AgentConfiguration.agent.omit_hostname -ne $true -or
    $AgentConfiguration.agent.usage_data -ne $false
) {
    throw "Coleta de metricas diferente da prevista."
}

if (
    $null -ne
        $AgentConfiguration.metrics.PSObject.Properties["aggregation_dimensions"]
) {
    throw "Agregacoes adicionais nao fazem parte deste cenario."
}

$LogEntries = @(
    $AgentConfiguration.logs.logs_collected.files.collect_list
)

if ($LogEntries.Count -ne 1) {
    throw "Deve existir um unico arquivo de log configurado."
}

$LogEntry = $LogEntries[0]

if (
    $LogEntry.file_path -ne $Settings.Logs.ApplicationLogPath -or
    $LogEntry.log_group_name -ne $Settings.Logs.LogGroupName -or
    $LogEntry.log_stream_name -ne $Settings.Logs.LogStreamName -or
    $LogEntry.timestamp_format -ne $Settings.Logs.TimestampFormat -or
    $LogEntry.timezone -ne "UTC" -or
    $LogEntry.encoding -ne "utf-8"
) {
    throw "Configuracao de logs diferente da prevista."
}

if ($null -ne $LogEntry.PSObject.Properties["retention_in_days"]) {
    throw "A retencao deve ser aplicada pelo provisionamento."
}

$ExpectedQueries = @(
    "mem_used_percent|60|Average,Maximum"
    "disk_used_percent|60|Average,Maximum"
)

$ActualQueries = @(
    foreach ($Query in $Settings.Metrics.Queries) {
        "{0}|{1}|{2}" -f `
            $Query.MetricName, `
            $Query.PeriodSeconds, `
            (@($Query.Statistics) -join ",")
    }
)

if (@(
    Compare-Object -ReferenceObject $ExpectedQueries `
        -DifferenceObject $ActualQueries
).Count -ne 0) {
    throw "Consultas de metricas diferentes das previstas."
}

$LogGroupArn = (
    "arn:aws:logs:{0}:{1}:log-group:{2}" -f
    $Settings.Region,
    $Settings.ExpectedAccountId,
    $Settings.Logs.LogGroupName
)

$ExpectedPolicyStatements = @(
    [pscustomobject]@{
        Sid = "PublishLab26Metrics"
        Actions = @("cloudwatch:PutMetricData")
        Resource = "*"
    }
    [pscustomobject]@{
        Sid = "DescribeLogGroups"
        Actions = @("logs:DescribeLogGroups")
        Resource = "*"
    }
    [pscustomobject]@{
        Sid = "DescribeLab26LogStreams"
        Actions = @("logs:DescribeLogStreams")
        Resource = "${LogGroupArn}:*"
    }
    [pscustomobject]@{
        Sid = "PublishLab26LogEvents"
        Actions = @("logs:CreateLogStream", "logs:PutLogEvents")
        Resource = "${LogGroupArn}:log-stream:*"
    }
)

if (
    $AgentPolicy.Version -ne "2012-10-17" -or
    @($AgentPolicy.Statement).Count -ne 4
) {
    throw "Estrutura da politica de publicacao diferente da prevista."
}

foreach ($Expected in $ExpectedPolicyStatements) {
    $Found = @(
        $AgentPolicy.Statement |
            Where-Object Sid -eq $Expected.Sid
    )

    if ($Found.Count -ne 1) {
        throw "Declaracao IAM ausente ou duplicada: $($Expected.Sid)"
    }

    $Statement = $Found[0]

    if (
        $Statement.Effect -ne "Allow" -or
        @($Statement.Resource).Count -ne 1 -or
        $Statement.Resource -cne $Expected.Resource -or
        @(
            Compare-Object -ReferenceObject $Expected.Actions `
                -DifferenceObject @($Statement.Action)
        ).Count -ne 0
    ) {
        throw "Permissoes diferentes das previstas: $($Expected.Sid)"
    }

    if ($Expected.Sid -eq "PublishLab26Metrics") {
        if (
            $Statement.Condition.StringEquals.'cloudwatch:namespace' -cne
                $Settings.Metrics.Namespace
        ) {
            throw "Condicao de namespace diferente da prevista."
        }
    }
    elseif ($null -ne $Statement.PSObject.Properties["Condition"]) {
        throw "Condicao IAM inesperada: $($Expected.Sid)"
    }
}

Write-Host "[OK] Trust policy, coleta e politica de publicacao conferidas." `
    -ForegroundColor Green

# Todas as operacoes ate o retorno ValidateOnly sao de leitura.
$Checks = @(
    [pscustomobject]@{
        Operation = "describe-vpcs"
        Collection = "Vpcs"
        Filter = "tag:Name"
        Name = $Settings.Names.Vpc
    }
    [pscustomobject]@{
        Operation = "describe-subnets"
        Collection = "Subnets"
        Filter = "tag:Name"
        Name = $Settings.Names.Subnet
    }
    [pscustomobject]@{
        Operation = "describe-internet-gateways"
        Collection = "InternetGateways"
        Filter = "tag:Name"
        Name = $Settings.Names.InternetGateway
    }
    [pscustomobject]@{
        Operation = "describe-route-tables"
        Collection = "RouteTables"
        Filter = "tag:Name"
        Name = $Settings.Names.RouteTable
    }
    [pscustomobject]@{
        Operation = "describe-security-groups"
        Collection = "SecurityGroups"
        Filter = "group-name"
        Name = $Settings.Names.SecurityGroup
    }
)

foreach ($Check in $Checks) {
    $Response = Invoke-Lab26Aws -Service ec2 `
        -Operation $Check.Operation -Request @{
            Filters = @(
                @{
                    Name = $Check.Filter
                    Values = @($Check.Name)
                }
            )
        }

    if (@($Response.($Check.Collection)).Count -ne 0) {
        throw "Conflito de nome: $($Check.Name)"
    }
}

$ExistingInstances = Invoke-Lab26Aws -Service ec2 `
    -Operation describe-instances -Request @{
        Filters = @(
            @{
                Name = "tag:Name"
                Values = @($Settings.Names.Instance)
            }
            @{
                Name = "instance-state-name"
                Values = @(
                    "pending", "running", "stopping",
                    "stopped", "shutting-down"
                )
            }
        )
    }

if (@($ExistingInstances.Reservations).Count -ne 0) {
    throw "Ja existe uma instancia ativa com o nome do laboratorio."
}

$ExistingRole = Invoke-Lab26Aws -Service iam `
    -Operation get-role -Request @{
        RoleName = $Settings.Names.Role
    } -AbsentCodes @("NoSuchEntity")

$ExistingProfile = Invoke-Lab26Aws -Service iam `
    -Operation get-instance-profile -Request @{
        InstanceProfileName = $Settings.Names.InstanceProfile
    } -AbsentCodes @("NoSuchEntity")

if ($null -ne $ExistingRole -or $null -ne $ExistingProfile) {
    throw "Ja existe uma role ou instance profile com o nome previsto."
}

$Groups = Invoke-Lab26Aws -Service logs `
    -Operation describe-log-groups -Request @{
        logGroupNamePrefix = $Settings.Logs.LogGroupName
    }

if (@(
    $Groups.logGroups | Where-Object {
        $_.logGroupName -ceq $Settings.Logs.LogGroupName
    }
).Count -ne 0) {
    throw "Ja existe o log group previsto."
}

$Zones = Invoke-Lab26Aws -Service ec2 `
    -Operation describe-availability-zones -Request @{
        ZoneNames = @($Settings.AvailabilityZone)
    }

if (
    @($Zones.AvailabilityZones).Count -ne 1 -or
    $Zones.AvailabilityZones[0].State -ne "available" -or
    $Zones.AvailabilityZones[0].RegionName -ne $Settings.Region
) {
    throw "Zona de disponibilidade nao validada."
}

$Parameter = Invoke-Lab26Aws -Service ssm `
    -Operation get-parameter -Request @{
        Name = $Settings.AmiParameter
    }

$AmiId = [string]$Parameter.Parameter.Value

if ($AmiId -notmatch "^ami-[0-9a-f]+$") {
    throw "O parametro nao retornou um ID de AMI valido."
}

$ImageResponse = Invoke-Lab26Aws -Service ec2 `
    -Operation describe-images -Request @{
        ImageIds = @($AmiId)
        Owners = @("amazon")
    }

if (@($ImageResponse.Images).Count -ne 1) {
    throw "AMI oficial da Amazon nao identificada."
}

$SelectedImage = $ImageResponse.Images[0]

if (
    $SelectedImage.State -ne "available" -or
    $SelectedImage.Architecture -ne "x86_64" -or
    $SelectedImage.RootDeviceType -ne "ebs"
) {
    throw "AMI incompativel com o laboratorio."
}

$RootMappings = @(
    $SelectedImage.BlockDeviceMappings | Where-Object {
        $_.DeviceName -eq $SelectedImage.RootDeviceName
    }
)

if (
    $RootMappings.Count -ne 1 -or
    $RootMappings[0].Ebs.VolumeSize -gt $Settings.RootVolumeSizeGiB
) {
    throw "Volume raiz da AMI incompativel com os 8 GiB previstos."
}

Write-Host "[OK] Nomes livres, zona e AMI conferidos." `
    -ForegroundColor Green

[pscustomobject]@{
    AccountId        = $Settings.ExpectedAccountId
    Region           = $Settings.Region
    AvailabilityZone = $Settings.AvailabilityZone
    AmiId            = $AmiId
    AmiName          = $SelectedImage.Name
    InstanceType     = $Settings.InstanceType
    Namespace        = $Settings.Metrics.Namespace
    LogGroup         = $Settings.Logs.LogGroupName
    RetentionDays    = $Settings.Logs.RetentionInDays
} | Format-List

if ($ValidateOnly) {
    Write-Host "[OK] ValidateOnly: nenhum recurso AWS criado." `
        -ForegroundColor Green
    return
}

$script:State = [ordered]@{
    AccountId = $Settings.ExpectedAccountId
    Region = $Settings.Region
    RunId = [guid]::NewGuid().ToString()
    CreatedAtUtc = [DateTime]::UtcNow.ToString("o")
    Completed = $false
    CompletedAtUtc = ""
    AmiId = $AmiId
    Names = $Settings.Names
    AgentInstalled = $false
    Ids = [ordered]@{
        Vpc = ""
        Subnet = ""
        InternetGateway = ""
        RouteTable = ""
        Association = ""
        SecurityGroup = ""
        RoleId = ""
        InstanceProfileId = ""
        Instance = ""
        Volume = ""
        LogGroup = ""
    }
}

Save-Lab26State

try {
    $Vpc = Invoke-Lab26Aws -Service ec2 -Operation create-vpc `
        -Request @{
            CidrBlock = $Settings.VpcCidr
            TagSpecifications = @(
                @{
                    ResourceType = "vpc"
                    Tags = @(Get-Lab26Tags -Name $Settings.Names.Vpc)
                }
            )
        }

    $State.Ids.Vpc = $Vpc.Vpc.VpcId
    Save-Lab26State

    foreach ($Attribute in @("EnableDnsSupport", "EnableDnsHostnames")) {
        $Request = @{ VpcId = $State.Ids.Vpc }
        $Request[$Attribute] = @{ Value = $true }

        Invoke-Lab26Aws -Service ec2 `
            -Operation modify-vpc-attribute -Request $Request |
            Out-Null
    }

    $Subnet = Invoke-Lab26Aws -Service ec2 -Operation create-subnet `
        -Request @{
            VpcId = $State.Ids.Vpc
            CidrBlock = $Settings.SubnetCidr
            AvailabilityZone = $Settings.AvailabilityZone
            TagSpecifications = @(
                @{
                    ResourceType = "subnet"
                    Tags = @(Get-Lab26Tags -Name $Settings.Names.Subnet)
                }
            )
        }

    $State.Ids.Subnet = $Subnet.Subnet.SubnetId
    Save-Lab26State

    Invoke-Lab26Aws -Service ec2 `
        -Operation modify-subnet-attribute -Request @{
            SubnetId = $State.Ids.Subnet
            MapPublicIpOnLaunch = @{ Value = $true }
        } | Out-Null

    $Gateway = Invoke-Lab26Aws -Service ec2 `
        -Operation create-internet-gateway -Request @{
            TagSpecifications = @(
                @{
                    ResourceType = "internet-gateway"
                    Tags = @(
                        Get-Lab26Tags -Name $Settings.Names.InternetGateway
                    )
                }
            )
        }

    $State.Ids.InternetGateway = $Gateway.InternetGateway.InternetGatewayId
    Save-Lab26State

    Invoke-Lab26Aws -Service ec2 `
        -Operation attach-internet-gateway -Request @{
            VpcId = $State.Ids.Vpc
            InternetGatewayId = $State.Ids.InternetGateway
        } | Out-Null

    $RouteTable = Invoke-Lab26Aws -Service ec2 `
        -Operation create-route-table -Request @{
            VpcId = $State.Ids.Vpc
            TagSpecifications = @(
                @{
                    ResourceType = "route-table"
                    Tags = @(Get-Lab26Tags -Name $Settings.Names.RouteTable)
                }
            )
        }

    $State.Ids.RouteTable = $RouteTable.RouteTable.RouteTableId
    Save-Lab26State

    Invoke-Lab26Aws -Service ec2 -Operation create-route -Request @{
        RouteTableId = $State.Ids.RouteTable
        DestinationCidrBlock = "0.0.0.0/0"
        GatewayId = $State.Ids.InternetGateway
    } | Out-Null

    $Association = Invoke-Lab26Aws -Service ec2 `
        -Operation associate-route-table -Request @{
            RouteTableId = $State.Ids.RouteTable
            SubnetId = $State.Ids.Subnet
        }

    $State.Ids.Association = $Association.AssociationId
    Save-Lab26State

    $SecurityGroup = Invoke-Lab26Aws -Service ec2 `
        -Operation create-security-group -Request @{
            VpcId = $State.Ids.Vpc
            GroupName = $Settings.Names.SecurityGroup
            Description = "LAB 26 - SSM access without inbound rules"
            TagSpecifications = @(
                @{
                    ResourceType = "security-group"
                    Tags = @(
                        Get-Lab26Tags -Name $Settings.Names.SecurityGroup
                    )
                }
            )
        }

    $State.Ids.SecurityGroup = $SecurityGroup.GroupId
    Save-Lab26State

    Write-Host "[OK] Rede exclusiva criada; nenhuma entrada liberada." `
        -ForegroundColor Green

    $Role = Invoke-Lab26Aws -Service iam -Operation create-role `
        -Request @{
            RoleName = $Settings.Names.Role
            AssumeRolePolicyDocument = (
                ConvertTo-Json -InputObject $TrustPolicy `
                    -Depth 20 -Compress
            )
            Tags = @(Get-Lab26Tags -Name $Settings.Names.Role)
        }

    $State.Ids.RoleId = $Role.Role.RoleId
    Save-Lab26State

    Invoke-Lab26Aws -Service iam -Operation attach-role-policy `
        -Request @{
            RoleName = $Settings.Names.Role
            PolicyArn = $PolicyArn
        } | Out-Null

    Invoke-Lab26Aws -Service iam -Operation put-role-policy `
        -Request @{
            RoleName = $Settings.Names.Role
            PolicyName = $Settings.Names.AgentInlinePolicy
            PolicyDocument = (
                ConvertTo-Json -InputObject $AgentPolicy `
                    -Depth 30 -Compress
            )
        } | Out-Null

    $InstanceProfile = Invoke-Lab26Aws -Service iam `
        -Operation create-instance-profile -Request @{
            InstanceProfileName = $Settings.Names.InstanceProfile
            Tags = @(Get-Lab26Tags -Name $Settings.Names.InstanceProfile)
        }

    $State.Ids.InstanceProfileId = (
        $InstanceProfile.InstanceProfile.InstanceProfileId
    )
    Save-Lab26State

    Invoke-Lab26Aws -Service iam `
        -Operation add-role-to-instance-profile -Request @{
            InstanceProfileName = $Settings.Names.InstanceProfile
            RoleName = $Settings.Names.Role
        } | Out-Null

    Write-Host "[OK] Role e instance profile exclusivos criados." `
        -ForegroundColor Green

    $LogTags = @{}

    foreach ($Tag in @(
        Get-Lab26Tags -Name $Settings.Logs.LogGroupName
    )) {
        $LogTags[$Tag.Key] = [string]$Tag.Value
    }

    Invoke-Lab26Aws -Service logs -Operation create-log-group `
        -Request @{
            logGroupName = $Settings.Logs.LogGroupName
            logGroupClass = "STANDARD"
            tags = $LogTags
        } | Out-Null

    $State.Ids.LogGroup = $Settings.Logs.LogGroupName
    Save-Lab26State

    Invoke-Lab26Aws -Service logs -Operation put-retention-policy `
        -Request @{
            logGroupName = $Settings.Logs.LogGroupName
            retentionInDays = $Settings.Logs.RetentionInDays
        } | Out-Null

    Write-Host "[OK] Log group criado com retencao de um dia." `
        -ForegroundColor Green

    $LaunchRequest = @{
        ImageId = $AmiId
        InstanceType = $Settings.InstanceType
        MinCount = 1
        MaxCount = 1
        ClientToken = $State.RunId
        Monitoring = @{ Enabled = $false }
        CreditSpecification = @{ CpuCredits = $Settings.CpuCredits }
        IamInstanceProfile = @{
            Arn = $InstanceProfile.InstanceProfile.Arn
        }
        MetadataOptions = @{
            HttpTokens = "required"
            HttpEndpoint = "enabled"
            HttpPutResponseHopLimit = 1
        }
        NetworkInterfaces = @(
            @{
                DeviceIndex = 0
                SubnetId = $State.Ids.Subnet
                Groups = @($State.Ids.SecurityGroup)
                AssociatePublicIpAddress = $true
                DeleteOnTermination = $true
            }
        )
        BlockDeviceMappings = @(
            @{
                DeviceName = $SelectedImage.RootDeviceName
                Ebs = @{
                    VolumeSize = $Settings.RootVolumeSizeGiB
                    VolumeType = $Settings.RootVolumeType
                    Encrypted = $true
                    DeleteOnTermination = $true
                }
            }
        )
        TagSpecifications = @(
            @{
                ResourceType = "instance"
                Tags = @(Get-Lab26Tags -Name $Settings.Names.Instance)
            }
            @{
                ResourceType = "volume"
                Tags = @(Get-Lab26Tags -Name (
                    $Settings.Names.Instance + "-root"
                ))
            }
        )
    }

    # ClientToken mantido entre tentativas para evitar duplicacao.
    $Launch = $null

    for ($Attempt = 1; $Attempt -le 24; $Attempt++) {
        try {
            $Launch = Invoke-Lab26Aws -Service ec2 `
                -Operation run-instances -Request $LaunchRequest
            break
        }
        catch {
            if (
                $_.Exception.Message -notmatch
                    "Invalid IAM Instance Profile" -or
                $Attempt -eq 24
            ) {
                throw
            }

            Write-Host "Aguardando propagacao do instance profile..."
            Start-Sleep -Seconds 5
        }
    }

    if ($null -eq $Launch -or @($Launch.Instances).Count -ne 1) {
        throw "Resposta de criacao da instancia inesperada."
    }

    $State.Ids.Instance = $Launch.Instances[0].InstanceId
    Save-Lab26State

    $Running = $false
    $Instance = $null

    for ($Attempt = 1; $Attempt -le 60; $Attempt++) {
        $Response = Invoke-Lab26Aws -Service ec2 `
            -Operation describe-instances -Request @{
                InstanceIds = @($State.Ids.Instance)
            } -AbsentCodes @("InvalidInstanceID.NotFound")

        if ($null -ne $Response) {
            $Instances = @(
                foreach ($Reservation in $Response.Reservations) {
                    foreach ($Item in $Reservation.Instances) {
                        $Item
                    }
                }
            )

            if ($Instances.Count -ne 1) {
                throw "Resposta inesperada ao consultar a instancia."
            }

            $Instance = $Instances[0]

            if ($Instance.State.Name -eq "running") {
                $Running = $true
                break
            }

            if ($Instance.State.Name -in @(
                "shutting-down", "terminated", "stopping", "stopped"
            )) {
                throw "Estado inesperado: $($Instance.State.Name)"
            }
        }

        if ($Attempt % 6 -eq 1) {
            Write-Host "Aguardando EC2 running: $($State.Ids.Instance)"
        }

        Start-Sleep -Seconds 5
    }

    if (-not $Running) {
        throw "A instancia nao atingiu running no prazo."
    }

    $RootVolumes = @(
        $Instance.BlockDeviceMappings | Where-Object {
            $_.DeviceName -eq $Instance.RootDeviceName
        }
    )

    if ($RootVolumes.Count -ne 1) {
        throw "Volume raiz nao identificado."
    }

    $State.Ids.Volume = $RootVolumes[0].Ebs.VolumeId
    Save-Lab26State

    $Online = $false

    for ($Attempt = 1; $Attempt -le 60; $Attempt++) {
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
            $ManagedInstances.Count -eq 1 -and
            $ManagedInstances[0].PingStatus -eq "Online"
        ) {
            $Online = $true
            break
        }

        if ($Attempt % 6 -eq 1) {
            Write-Host "Aguardando gerenciamento SSM Online..."
        }

        Start-Sleep -Seconds 5
    }

    if (-not $Online) {
        throw "Instancia criada, mas SSM ainda nao esta Online."
    }

    $State.Completed = $true
    $State.CompletedAtUtc = [DateTime]::UtcNow.ToString("o")
    Save-Lab26State

    Write-Host ""
    Write-Host "LAB 26 - Infraestrutura provisionada" `
        -ForegroundColor Cyan

    [pscustomobject]@{
        AccountId      = $State.AccountId
        Region         = $State.Region
        RunId          = $State.RunId
        InstanceId     = $State.Ids.Instance
        VolumeId       = $State.Ids.Volume
        VpcId          = $State.Ids.Vpc
        SubnetId       = $State.Ids.Subnet
        LogGroup       = $State.Ids.LogGroup
        RetentionDays  = $Settings.Logs.RetentionInDays
        SsmStatus      = "Online"
        AgentInstalled = $State.AgentInstalled
        InventoryPath  = $StatePath
    } | Format-List

    Write-Host "[OK] Infraestrutura criada e SSM Online." `
        -ForegroundColor Green

    Write-Host "Proxima etapa: instalacao do CloudWatch Agent."
}
catch {
    Write-Host "Deploy interrompido. Inventario preservado:" `
        -ForegroundColor Yellow

    Write-Host $StatePath
    throw
}
