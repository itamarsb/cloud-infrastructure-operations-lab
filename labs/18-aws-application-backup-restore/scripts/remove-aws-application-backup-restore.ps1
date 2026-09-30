[CmdletBinding()]
param(
    [string]$ProfileName = "cloud-operations-lab",
    [ValidateSet("us-east-1")][string]$Region = "us-east-1",
    [switch]$ConfirmRemoval
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ExpectedAccount = "412381774441"
$InstanceName = "lab18-application-backup-instance"
$GroupName = "lab18-application-backup-sg"
$RoleName = "lab18-ec2-application-backup-role"
$InstanceProfileName = "lab18-ec2-application-backup-instance-profile"
$InlinePolicyName = "lab18-s3-application-backup"
$SsmPolicyArn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
$BucketName = "lab18-app-backup-$ExpectedAccount-$Region"
$tempDirectory = $null
$savedEnvironment = @{}

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $response = @(& aws @Arguments --profile $ProfileName `
            --region $Region --no-cli-pager 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    $output = ($response | ForEach-Object { $_.ToString() }) -join "`n"
    if ($code -ne 0) {
        throw "AWS CLI falhou: aws $($Arguments -join ' ')`n$output"
    }
    return $output.Trim()
}

function Get-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = Invoke-Aws -Arguments ($Arguments + @("--output", "json"))
    if ([string]::IsNullOrWhiteSpace($output)) {
        throw "Resposta JSON vazia da AWS CLI."
    }
    return ($output | ConvertFrom-Json -ErrorAction Stop)
}

function Get-Property {
    param($Object, [string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) {
        return $Object.$Name
    }
    return $null
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $normalized = $Content.Replace("`r`n", "`n").Replace("`r", "`n")
    [IO.File]::WriteAllText(
        $Path, $normalized, (New-Object System.Text.UTF8Encoding($false))
    )
}

function Write-JsonFile {
    param([string]$Path, $Value)
    Write-Utf8File -Path $Path -Content ($Value | ConvertTo-Json -Depth 20)
}

function Get-FileUri {
    param([string]$Path)
    return "file://$($Path.Replace('\', '/'))"
}

function Assert-Tags {
    param($Tags, [string]$Lab, [string]$Name)
    $actual = @{}
    foreach ($tag in @($Tags)) {
        if ($null -ne $tag) { $actual[[string]$tag.Key] = [string]$tag.Value }
    }
    $expected = @{
        Name = $Name; Lab = $Lab; Owner = "itamarsb"
        Project = "cloud-infrastructure-operations-lab"
        Environment = "lab"; ManagedBy = "aws-cli"
    }
    foreach ($key in $expected.Keys) {
        if ($actual[$key] -ne $expected[$key]) {
            throw "Tags incompativeis: $Name; chave=$key."
        }
    }
}

function Get-OptionalJson {
    param([string[]]$Arguments, [string]$MissingCode)
    try { return (Get-AwsJson -Arguments $Arguments) }
    catch {
        if ($_.Exception.Message -match ("\(" + [regex]::Escape($MissingCode) + "\)")) {
            return $null
        }
        throw
    }
}

function Get-LabInstances {
    $result = Get-AwsJson -Arguments @(
        "ec2", "describe-instances", "--filters",
        "Name=tag:Name,Values=$InstanceName",
        "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down"
    )
    return @($result.Reservations | ForEach-Object { $_.Instances })
}

function Get-LabGroups {
    return @((Get-AwsJson -Arguments @(
        "ec2", "describe-security-groups", "--filters",
        "Name=group-name,Values=$GroupName"
    )).SecurityGroups)
}

function Get-BucketVersions {
    $result = Get-AwsJson -Arguments (@("s3api", "list-object-versions") + $ownerArgs)
    $items = @(
        foreach ($property in @("Versions", "DeleteMarkers")) {
            foreach ($item in @(Get-Property $result $property)) {
                if ($null -eq $item) { continue }
                if (-not $item.Key.StartsWith("backups/") -or
                    [string]::IsNullOrWhiteSpace([string]$item.VersionId)) {
                    throw "Objeto fora do escopo de backup: $($item.Key)."
                }
                @{ Key = [string]$item.Key; VersionId = [string]$item.VersionId }
            }
        }
    )
    return $items
}

try {
    if (-not $ConfirmRemoval) { throw "Informe -ConfirmRemoval para autorizar o cleanup." }
    foreach ($name in @("AWS_CLI_FILE_ENCODING", "AWS_CLI_OUTPUT_ENCODING", "PYTHONIOENCODING")) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, "UTF-8", "Process")
    }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { throw "AWS CLI ausente." }
    $identity = Get-AwsJson @("sts", "get-caller-identity")
    if ($identity.Account -ne $ExpectedAccount) { throw "Conta AWS inesperada." }
    Write-Host "=== Cleanup do LAB 18: inventario ==="
    Write-Host "[OK] Conta: $ExpectedAccount; regiao: $Region."
    $vpcs = @((Get-AwsJson @("ec2", "describe-vpcs", "--filters",
        "Name=tag:Name,Values=lab08-application-vpc")).Vpcs)
    if ($vpcs.Count -ne 1) { throw "VPC compartilhada ausente ou ambigua." }
    $vpc = $vpcs[0]
    Assert-Tags $vpc.Tags "08" "lab08-application-vpc"
    $subnets = @((Get-AwsJson @("ec2", "describe-subnets", "--filters",
        "Name=vpc-id,Values=$($vpc.VpcId)",
        "Name=tag:Name,Values=lab08-public-subnet-a")).Subnets)
    if ($subnets.Count -ne 1) { throw "Sub-rede compartilhada ausente ou ambigua." }
    $subnet = $subnets[0]
    Assert-Tags $subnet.Tags "08" "lab08-public-subnet-a"

    $instances = @(Get-LabInstances)
    if ($instances.Count -gt 1) { throw "Mais de uma instancia com o nome do LAB 18." }
    $instance = $null
    $instanceId = ""
    $rootVolumeId = ""
    if ($instances.Count -eq 1) {
        $instance = $instances[0]
        $instanceId = [string]$instance.InstanceId
        Assert-Tags $instance.Tags "18" $InstanceName
        if ($instance.VpcId -ne $vpc.VpcId -or $instance.SubnetId -ne $subnet.SubnetId) {
            throw "Instancia fora da rede esperada."
        }
        $devices = @($instance.BlockDeviceMappings)
        if ($devices.Count -ne 1 -or $devices[0].DeviceName -ne $instance.RootDeviceName -or
            $devices[0].Ebs.DeleteOnTermination -ne $true) {
            throw "Volumes inesperados ou root sem DeleteOnTermination."
        }
        $rootVolumeId = [string]$devices[0].Ebs.VolumeId
        $volume = (Get-AwsJson @("ec2", "describe-volumes", "--volume-ids", $rootVolumeId)).Volumes[0]
        Assert-Tags $volume.Tags "18" "$InstanceName-root"
        if (@($volume.Attachments).Count -ne 1 -or $volume.Attachments[0].InstanceId -ne $instanceId) {
            throw "Volume root com associacao inesperada."
        }
        Write-Host "[OK] Instancia: $instanceId; root: $rootVolumeId."
    }
    $rootVolumes = @((Get-AwsJson @("ec2", "describe-volumes", "--filters",
        "Name=tag:Name,Values=$InstanceName-root")).Volumes)
    foreach ($item in $rootVolumes) {
        Assert-Tags $item.Tags "18" "$InstanceName-root"
        if (-not $rootVolumeId -or $item.VolumeId -ne $rootVolumeId) {
            throw "Volume root fora da associacao esperada: $($item.VolumeId)."
        }
    }
    $groups = @(Get-LabGroups)
    if ($groups.Count -gt 1) { throw "Security Group ambiguo." }
    $groupId = ""
    if ($groups.Count -eq 1) {
        $group = $groups[0]
        Assert-Tags $group.Tags "18" $GroupName
        if ($group.VpcId -ne $vpc.VpcId) { throw "Security Group fora da VPC esperada." }
        $groupId = [string]$group.GroupId
        $interfaces = @((Get-AwsJson @("ec2", "describe-network-interfaces", "--filters",
            "Name=group-id,Values=$groupId")).NetworkInterfaces)
        foreach ($interface in $interfaces) {
            $attachment = Get-Property $interface "Attachment"
            if (-not $instanceId -or (Get-Property $attachment "InstanceId") -ne $instanceId) {
                throw "Security Group utilizado por outra interface: $($interface.NetworkInterfaceId)."
            }
        }
        Write-Host "[OK] Security Group: $groupId."
    }
    if ($null -ne $instance) {
        if (-not $groupId -or @($instance.SecurityGroups).Count -ne 1 -or
            $instance.SecurityGroups[0].GroupId -ne $groupId) {
            throw "Security Groups da instancia divergem do inventario."
        }
    }
    $profileResult = Get-OptionalJson @("iam", "get-instance-profile",
        "--instance-profile-name", $InstanceProfileName) "NoSuchEntity"
    $profile = $null
    if ($null -ne $profileResult) {
        $profile = $profileResult.InstanceProfile
        Assert-Tags $profile.Tags "18" $InstanceProfileName
        foreach ($member in @($profile.Roles)) {
            if ($member.RoleName -ne $RoleName) { throw "Role inesperada no Instance Profile." }
        }
        $consumers = (Get-AwsJson @("ec2", "describe-instances", "--filters",
            "Name=iam-instance-profile.arn,Values=$($profile.Arn)",
            "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down")).Reservations
        foreach ($consumer in @($consumers | ForEach-Object { $_.Instances })) {
            if ($consumer.InstanceId -ne $instanceId) { throw "Instance Profile utilizado por outra EC2." }
        }
        if ($null -ne $instance -and $instance.IamInstanceProfile.Arn -ne $profile.Arn) {
            throw "Instance Profile da EC2 inesperado."
        }
        Write-Host "[OK] Instance Profile: $InstanceProfileName."
    }
    elseif ($null -ne $instance) { throw "EC2 existente sem o Instance Profile esperado." }
    $roleResult = Get-OptionalJson @("iam", "get-role", "--role-name", $RoleName) "NoSuchEntity"
    $role = $null
    $managed = @()
    $inline = @()
    if ($null -ne $roleResult) {
        $role = $roleResult.Role
        Assert-Tags $role.Tags "18" $RoleName
        $related = @((Get-AwsJson @("iam", "list-instance-profiles-for-role",
            "--role-name", $RoleName)).InstanceProfiles)
        foreach ($item in $related) {
            if ($null -eq $profile -or $item.Arn -ne $profile.Arn) {
                throw "Role associada a outro Instance Profile."
            }
        }
        $managed = @((Get-AwsJson @("iam", "list-attached-role-policies",
            "--role-name", $RoleName)).AttachedPolicies)
        $inline = @((Get-AwsJson @("iam", "list-role-policies", "--role-name", $RoleName)).PolicyNames)
        foreach ($policy in $managed) {
            if ($policy.PolicyArn -ne $SsmPolicyArn) { throw "Politica gerenciada inesperada na role." }
        }
        foreach ($policyName in $inline) {
            if ($policyName -ne $InlinePolicyName) { throw "Politica inline inesperada na role." }
        }
        Write-Host "[OK] IAM Role: $RoleName."
    }
    $ownerArgs = @("--bucket", $BucketName, "--expected-bucket-owner", $ExpectedAccount)
    $bucketResult = Get-OptionalJson (@("s3api", "get-bucket-tagging") + $ownerArgs) "NoSuchBucket"
    $bucketExists = $null -ne $bucketResult
    if ($bucketExists) {
        Assert-Tags $bucketResult.TagSet "18" $BucketName
        $location = Get-AwsJson (@("s3api", "get-bucket-location") + $ownerArgs)
        $constraint = Get-Property $location "LocationConstraint"
        if ($constraint -and $constraint -ne $Region) { throw "Bucket fora de us-east-1." }
        $uploads = Get-AwsJson (@("s3api", "list-multipart-uploads") + $ownerArgs)
        if (@(Get-Property $uploads "Uploads" | Where-Object { $null -ne $_ }).Count -gt 0) {
            throw "Uploads multipart inesperados; cleanup interrompido."
        }
        $versions = @(Get-BucketVersions)
        Write-Host "[OK] Bucket: $BucketName; versoes e marcadores: $($versions.Count)."
    }
    Write-Host "[OK] Inventario validado. Iniciando remocoes exclusivas do LAB 18."

    if ($instanceId) {
        Invoke-Aws @("ec2", "terminate-instances", "--instance-ids", $instanceId, "--output", "json") | Out-Null
        $terminated = $false
        for ($attempt = 1; $attempt -le 60; $attempt++) {
            $current = (Get-AwsJson @("ec2", "describe-instances", "--instance-ids", $instanceId)).Reservations[0].Instances[0]
            if ($current.State.Name -eq "terminated") { $terminated = $true; break }
            if ($attempt % 6 -eq 0) { Write-Host "Aguardando encerramento da EC2: $instanceId." }
            Start-Sleep -Seconds 10
        }
        if (-not $terminated) { throw "EC2 ainda nao terminou; cleanup parcial." }
        Write-Host "[OK] EC2 encerrada: $instanceId."
        $volumeRemoved = $false
        for ($attempt = 1; $attempt -le 30; $attempt++) {
            $volumeResult = Get-OptionalJson @("ec2", "describe-volumes",
                "--volume-ids", $rootVolumeId) "InvalidVolume.NotFound"
            if ($null -eq $volumeResult) { $volumeRemoved = $true; break }
            Start-Sleep -Seconds 5
        }
        if (-not $volumeRemoved) { throw "Volume root ainda existe: $rootVolumeId; cleanup parcial." }
        Write-Host "[OK] Volume root removido por DeleteOnTermination."
    }
    if ($groupId) {
        for ($attempt = 1; $attempt -le 30; $attempt++) {
            try {
                Invoke-Aws @("ec2", "delete-security-group", "--group-id", $groupId) | Out-Null
                break
            }
            catch {
                if ($_.Exception.Message -notmatch '\(DependencyViolation\)' -or $attempt -eq 30) { throw }
                Start-Sleep -Seconds 5
            }
        }
        Write-Host "[OK] Security Group removido: $groupId."
    }
    if ($bucketExists) {
        $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("lab18-cleanup-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tempDirectory | Out-Null
        $empty = $false
        for ($pass = 1; $pass -le 10; $pass++) {
            $versions = @(Get-BucketVersions)
            if ($versions.Count -eq 0) { $empty = $true; break }
            for ($offset = 0; $offset -lt $versions.Count; $offset += 1000) {
                $last = [Math]::Min($offset + 999, $versions.Count - 1)
                $batch = @($versions[$offset..$last])
                $deletePath = Join-Path $tempDirectory "delete-versions.json"
                Write-JsonFile $deletePath @{ Objects = $batch; Quiet = $false }
                $deleted = Get-AwsJson (@("s3api", "delete-objects", "--delete",
                    (Get-FileUri $deletePath)) + $ownerArgs)
                $errors = @(Get-Property $deleted "Errors" | Where-Object { $null -ne $_ })
                if ($errors.Count -gt 0) {
                    throw "S3 retornou erros de exclusao: $($errors | ConvertTo-Json -Depth 10 -Compress)"
                }
                Write-Host "[OK] Removidos $($batch.Count) itens versionados do bucket."
            }
        }
        if (-not $empty -and @(Get-BucketVersions).Count -ne 0) {
            throw "Bucket continua recebendo objetos; cleanup parcial."
        }
        Invoke-Aws (@("s3api", "delete-bucket") + $ownerArgs) | Out-Null
        Write-Host "[OK] Bucket removido: $BucketName."
    }
    if ($null -ne $profile) {
        foreach ($member in @($profile.Roles)) {
            Invoke-Aws @("iam", "remove-role-from-instance-profile",
                "--instance-profile-name", $InstanceProfileName, "--role-name", $member.RoleName) | Out-Null
        }
        Invoke-Aws @("iam", "delete-instance-profile", "--instance-profile-name", $InstanceProfileName) | Out-Null
        Write-Host "[OK] Instance Profile removido."
    }
    if ($null -ne $role) {
        foreach ($policyName in $inline) {
            Invoke-Aws @("iam", "delete-role-policy", "--role-name", $RoleName,
                "--policy-name", $policyName) | Out-Null
        }
        foreach ($policy in $managed) {
            Invoke-Aws @("iam", "detach-role-policy", "--role-name", $RoleName,
                "--policy-arn", $policy.PolicyArn) | Out-Null
        }
        Invoke-Aws @("iam", "delete-role", "--role-name", $RoleName) | Out-Null
        Write-Host "[OK] IAM Role removida."
    }
    Write-Host "=== Validacao pos-cleanup ==="
    if (@(Get-LabInstances).Count -ne 0 -or @(Get-LabGroups).Count -ne 0) {
        throw "Recursos EC2 exclusivos ainda existem."
    }
    $remainingVolumes = @((Get-AwsJson @("ec2", "describe-volumes", "--filters",
        "Name=tag:Name,Values=$InstanceName-root")).Volumes)
    if ($remainingVolumes.Count -ne 0) { throw "Volume root residual encontrado; registre os IDs." }
    if ($null -ne (Get-OptionalJson @("iam", "get-instance-profile",
        "--instance-profile-name", $InstanceProfileName) "NoSuchEntity")) {
        throw "Instance Profile ainda existe."
    }
    if ($null -ne (Get-OptionalJson @("iam", "get-role", "--role-name", $RoleName) "NoSuchEntity")) {
        throw "IAM Role ainda existe."
    }
    if ($null -ne (Get-OptionalJson (@("s3api", "get-bucket-tagging") + $ownerArgs) "NoSuchBucket")) {
        throw "Bucket ainda existe."
    }
    $afterVpc = (Get-AwsJson @("ec2", "describe-vpcs", "--vpc-ids", $vpc.VpcId)).Vpcs[0]
    $afterSubnet = (Get-AwsJson @("ec2", "describe-subnets", "--subnet-ids", $subnet.SubnetId)).Subnets[0]
    Assert-Tags $afterVpc.Tags "08" "lab08-application-vpc"
    Assert-Tags $afterSubnet.Tags "08" "lab08-public-subnet-a"
    if ($afterVpc.State -ne "available" -or $afterSubnet.State -ne "available" -or
        $afterSubnet.VpcId -ne $afterVpc.VpcId) { throw "Rede compartilhada indisponivel." }
    Write-Host "[OK] Recursos exclusivos ausentes."
    Write-Host "[OK] VPC: $($vpc.VpcId); sub-rede: $($subnet.SubnetId) preservadas."
    Write-Host "CLEANUP CONCLUIDO"
    $global:LASTEXITCODE = 0
}
catch {
    Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Cleanup nao concluido. Registre a saida e confira o inventario antes de repetir."
    exit 1
}
finally {
    if ($tempDirectory -and (Test-Path -LiteralPath $tempDirectory)) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], "Process")
    }
}
