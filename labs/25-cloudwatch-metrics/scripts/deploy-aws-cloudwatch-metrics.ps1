[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [switch]$ValidateOnly
)

. (Join-Path $PSScriptRoot "lab25-common.ps1")

Initialize-Lab25

if (Test-Path -LiteralPath $StatePath) {
    throw "Inventario existente: $StatePath. Confira-o antes de um novo deploy."
}

# Todas as consultas anteriores ao ValidateOnly sao somente de leitura.
$Checks = @(
    @{
        Operation = "describe-vpcs"
        Collection = "Vpcs"
        Filter = "tag:Name"
        Name = $Settings.Names.Vpc
    }
    @{
        Operation = "describe-subnets"
        Collection = "Subnets"
        Filter = "tag:Name"
        Name = $Settings.Names.Subnet
    }
    @{
        Operation = "describe-internet-gateways"
        Collection = "InternetGateways"
        Filter = "tag:Name"
        Name = $Settings.Names.InternetGateway
    }
    @{
        Operation = "describe-route-tables"
        Collection = "RouteTables"
        Filter = "tag:Name"
        Name = $Settings.Names.RouteTable
    }
    @{
        Operation = "describe-security-groups"
        Collection = "SecurityGroups"
        Filter = "group-name"
        Name = $Settings.Names.SecurityGroup
    }
)

foreach ($Check in $Checks) {
    $Response = Invoke-Lab25Aws -Service ec2 `
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

$ExistingInstances = Invoke-Lab25Aws -Service ec2 `
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

$ExistingRole = Invoke-Lab25Aws -Service iam `
    -Operation get-role -Request @{
        RoleName = $Settings.Names.Role
    } -AbsentCodes @("NoSuchEntity")

$ExistingProfile = Invoke-Lab25Aws -Service iam `
    -Operation get-instance-profile -Request @{
        InstanceProfileName = $Settings.Names.InstanceProfile
    } -AbsentCodes @("NoSuchEntity")

if ($null -ne $ExistingRole -or $null -ne $ExistingProfile) {
    throw "Ja existe uma role ou instance profile com o nome previsto."
}

$Dashboards = Invoke-Lab25Aws -Service cloudwatch `
    -Operation list-dashboards -Request @{
        DashboardNamePrefix = $Settings.Names.Dashboard
    }

if (@(
    $Dashboards.DashboardEntries | Where-Object {
        $_.DashboardName -eq $Settings.Names.Dashboard
    }
).Count -ne 0) {
    throw "Ja existe um dashboard com o nome previsto."
}

$Zones = Invoke-Lab25Aws -Service ec2 `
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

$AmiParameter = Invoke-Lab25Aws -Service ssm `
    -Operation get-parameter -Request @{
        Name = $Settings.AmiParameter
    }

$AmiId = [string]$AmiParameter.Parameter.Value

$ImageResponse = Invoke-Lab25Aws -Service ec2 `
    -Operation describe-images -Request @{
        ImageIds = @($AmiId)
        Owners = @("amazon")
    }

if (@($ImageResponse.Images).Count -ne 1) {
    throw "AMI oficial nao identificada."
}

$SelectedImage = $ImageResponse.Images[0]

if (
    $SelectedImage.State -ne "available" -or
    $SelectedImage.Architecture -ne "x86_64" -or
    $SelectedImage.RootDeviceType -ne "ebs"
) {
    throw "AMI incompativel."
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

$TrustPolicy = Get-Content -LiteralPath (
    Join-Path $PSScriptRoot "..\config\ec2-ssm-trust-policy.json"
) -Raw | ConvertFrom-Json

$Statements = @($TrustPolicy.Statement)
if (
    $TrustPolicy.Version -ne "2012-10-17" -or
    $Statements.Count -ne 1 -or
    $Statements[0].Effect -ne "Allow" -or
    $Statements[0].Principal.Service -ne "ec2.amazonaws.com" -or
    $Statements[0].Action -ne "sts:AssumeRole"
) {
    throw "Trust policy diferente da prevista."
}

Write-Host "[OK] Nomes livres, zona, AMI e trust policy validados." `
    -ForegroundColor Green

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
    }
}

Save-Lab25State

try {
    $Vpc = Invoke-Lab25Aws -Service ec2 -Operation create-vpc `
        -Request @{
            CidrBlock = $Settings.VpcCidr
            TagSpecifications = @(
                @{
                    ResourceType = "vpc"
                    Tags = @(Get-Lab25Tags -Name $Settings.Names.Vpc)
                }
            )
        }

    $State.Ids.Vpc = $Vpc.Vpc.VpcId
    Save-Lab25State

    Invoke-Lab25Aws -Service ec2 -Operation modify-vpc-attribute `
        -Request @{
            VpcId = $State.Ids.Vpc
            EnableDnsSupport = @{ Value = $true }
        } | Out-Null

    Invoke-Lab25Aws -Service ec2 -Operation modify-vpc-attribute `
        -Request @{
            VpcId = $State.Ids.Vpc
            EnableDnsHostnames = @{ Value = $true }
        } | Out-Null

    $Subnet = Invoke-Lab25Aws -Service ec2 -Operation create-subnet `
        -Request @{
            VpcId = $State.Ids.Vpc
            CidrBlock = $Settings.SubnetCidr
            AvailabilityZone = $Settings.AvailabilityZone
            TagSpecifications = @(
                @{
                    ResourceType = "subnet"
                    Tags = @(Get-Lab25Tags -Name $Settings.Names.Subnet)
                }
            )
        }

    $State.Ids.Subnet = $Subnet.Subnet.SubnetId
    Save-Lab25State

    $Gateway = Invoke-Lab25Aws -Service ec2 `
        -Operation create-internet-gateway -Request @{
            TagSpecifications = @(
                @{
                    ResourceType = "internet-gateway"
                    Tags = @(
                        Get-Lab25Tags -Name $Settings.Names.InternetGateway
                    )
                }
            )
        }

    $State.Ids.InternetGateway = $Gateway.InternetGateway.InternetGatewayId
    Save-Lab25State

    Invoke-Lab25Aws -Service ec2 -Operation attach-internet-gateway `
        -Request @{
            VpcId = $State.Ids.Vpc
            InternetGatewayId = $State.Ids.InternetGateway
        } | Out-Null

    $RouteTable = Invoke-Lab25Aws -Service ec2 `
        -Operation create-route-table -Request @{
            VpcId = $State.Ids.Vpc
            TagSpecifications = @(
                @{
                    ResourceType = "route-table"
                    Tags = @(Get-Lab25Tags -Name $Settings.Names.RouteTable)
                }
            )
        }

    $State.Ids.RouteTable = $RouteTable.RouteTable.RouteTableId
    Save-Lab25State

    Invoke-Lab25Aws -Service ec2 -Operation create-route -Request @{
        RouteTableId = $State.Ids.RouteTable
        DestinationCidrBlock = "0.0.0.0/0"
        GatewayId = $State.Ids.InternetGateway
    } | Out-Null

    $Association = Invoke-Lab25Aws -Service ec2 `
        -Operation associate-route-table -Request @{
            RouteTableId = $State.Ids.RouteTable
            SubnetId = $State.Ids.Subnet
        }

    $State.Ids.Association = $Association.AssociationId
    Save-Lab25State

    $SecurityGroup = Invoke-Lab25Aws -Service ec2 `
        -Operation create-security-group -Request @{
            VpcId = $State.Ids.Vpc
            GroupName = $Settings.Names.SecurityGroup
            Description = "LAB 25 - SSM access without inbound rules"
            TagSpecifications = @(
                @{
                    ResourceType = "security-group"
                    Tags = @(
                        Get-Lab25Tags -Name $Settings.Names.SecurityGroup
                    )
                }
            )
        }

    $State.Ids.SecurityGroup = $SecurityGroup.GroupId
    Save-Lab25State

    $Role = Invoke-Lab25Aws -Service iam -Operation create-role `
        -Request @{
            RoleName = $Settings.Names.Role
            AssumeRolePolicyDocument = (
                ConvertTo-Json -InputObject $TrustPolicy -Depth 10 -Compress
            )
            Tags = @(Get-Lab25Tags -Name $Settings.Names.Role)
        }

    $State.Ids.RoleId = $Role.Role.RoleId
    Save-Lab25State

    Invoke-Lab25Aws -Service iam -Operation attach-role-policy `
        -Request @{
            RoleName = $Settings.Names.Role
            PolicyArn = $PolicyArn
        } | Out-Null

    $InstanceProfile = Invoke-Lab25Aws -Service iam `
        -Operation create-instance-profile -Request @{
            InstanceProfileName = $Settings.Names.InstanceProfile
            Tags = @(Get-Lab25Tags -Name $Settings.Names.InstanceProfile)
        }

    $State.Ids.InstanceProfileId = (
        $InstanceProfile.InstanceProfile.InstanceProfileId
    )
    Save-Lab25State

    Invoke-Lab25Aws -Service iam `
        -Operation add-role-to-instance-profile -Request @{
            InstanceProfileName = $Settings.Names.InstanceProfile
            RoleName = $Settings.Names.Role
        } | Out-Null

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
                    VolumeType = "gp3"
                    Encrypted = $true
                    DeleteOnTermination = $true
                }
            }
        )
        TagSpecifications = @(
            @{
                ResourceType = "instance"
                Tags = @(Get-Lab25Tags -Name $Settings.Names.Instance)
            }
            @{
                ResourceType = "volume"
                Tags = @(Get-Lab25Tags -Name (
                    $Settings.Names.Instance + "-root"
                ))
            }
        )
    }

    # Espera limitada para propagacao do instance profile no IAM.
    $Launch = $null
    for ($Attempt = 1; $Attempt -le 12; $Attempt++) {
        try {
            $Launch = Invoke-Lab25Aws -Service ec2 `
                -Operation run-instances -Request $LaunchRequest
            break
        }
        catch {
            if (
                $_.Exception.Message -notmatch "Invalid IAM Instance Profile" -or
                $Attempt -eq 12
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
    Save-Lab25State

    Write-Host "Aguardando a instancia: $($State.Ids.Instance)"

    Invoke-Lab25Aws -Service ec2 -Operation "wait" -Request @{} |
        Out-Null
}
catch {
    Write-Host "Deploy interrompido. Inventario preservado:" `
        -ForegroundColor Yellow
    Write-Host $StatePath
    throw
}
