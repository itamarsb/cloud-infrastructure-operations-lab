# Lab 14 — Utilização de disco e crescimento de logs

## Objetivo

Implantar uma instância Amazon EC2 com um volume EBS dedicado para logs, provocar crescimento controlado da utilização desse volume, executar um diagnóstico somente leitura e aplicar uma mitigação segura.

O laboratório exercita uma investigação operacional baseada em seis dimensões:

1. capacidade total, utilizada e disponível;
2. utilização percentual do filesystem;
3. consumo de inodes;
4. diretórios e arquivos que mais ocupam espaço;
5. arquivos removidos que continuam abertos por processos;
6. crescimento e retenção de logs.

A pressão de armazenamento ficará isolada em um volume de dados montado em `/var/log/lab14`. O volume raiz da instância não será preenchido intencionalmente.

> **English summary:** Deploy an Amazon EC2 instance with a dedicated EBS log volume, generate controlled disk pressure, diagnose filesystem capacity, inode usage, large files and open deleted files, mitigate the incident through log rotation and compression, validate recovery and remove temporary AWS resources.

---

## Cenário

Uma aplicação simulada gravará logs em um volume EBS dedicado.

O laboratório executará este fluxo:

```text
Volume de logs saudável
        |
        v
Crescimento controlado de logs
        |
        v
Utilização ultrapassa o limite operacional
        |
        v
Diagnóstico somente leitura
        |
        v
Arquivos responsáveis identificados
        |
        v
Rotação e compressão aplicadas
        |
        v
Utilização retorna ao nível seguro
```

O objetivo não é apenas apagar arquivos, mas demonstrar uma sequência segura de investigação, mitigação e validação aplicável a incidentes reais de capacidade.

---

## Decisão de segurança

O incidente não será provocado no volume raiz.

Será utilizado um volume EBS `gp3` de `2 GiB`, criptografado e dedicado ao laboratório. Ele será formatado com `ext4` e montado em:

```text
/var/log/lab14
```

Essa separação reduz o risco de:

- impedir o funcionamento do sistema operacional;
- interromper o agente do Systems Manager;
- bloquear atualizações ou comandos administrativos;
- comprometer a conexão utilizada para recuperação;
- afetar arquivos que não pertencem ao laboratório.

A geração de logs deverá parar antes de o filesystem atingir `90%` de utilização.

---

## Arquitetura

O Lab 14 reutiliza a VPC e a sub-rede pública `lab08-public-subnet-a` criadas no Lab 08.

```text
AWS IAM Identity Center
          |
          v
AWS Systems Manager
          |
          v
Amazon EC2
Amazon Linux 2023
          |
          v
Volume EBS gp3 criptografado
/var/log/lab14
```

A instância não utilizará Key Pair e não terá regra de entrada para a porta TCP `22`.

---

## Componentes

| Componente | Configuração |
|:---:|:---:|
| Região | `us-east-1` |
| VPC | `lab08-application-vpc` |
| Sub-rede | `lab08-public-subnet-a` |
| Zona de disponibilidade | `us-east-1a` |
| Instância EC2 | `lab14-disk-utilization-instance` |
| Tipo da instância | `t3.micro` |
| Sistema operacional | Amazon Linux 2023 |
| Volume raiz | EBS `gp3` criptografado |
| Volume de logs | EBS `gp3`, `2 GiB`, criptografado |
| Ponto de montagem | `/var/log/lab14` |
| Filesystem | `ext4` |
| IAM Role | `lab14-ec2-disk-utilization-role` |
| Instance Profile | `lab14-ec2-disk-utilization-instance-profile` |
| Security Group | `lab14-disk-utilization-sg` |
| Política do Systems Manager | `AmazonSSMManagedInstanceCore` |
| Acesso administrativo | AWS Systems Manager |
| Key Pair | Não utilizada |
| IMDSv2 | Obrigatório |
| Limite de alerta simulado | `80%` |
| Limite máximo da geração | Inferior a `90%` |

---

## Estrutura planejada

```text
labs/14-aws-disk-utilization/
├── README.md
├── images/
├── policies/
│   └── ec2-ssm-trust-policy.json
└── scripts/
    ├── deploy-aws-disk-utilization.ps1
    ├── diagnose-aws-disk-utilization.ps1
    ├── invoke-aws-disk-pressure.ps1
    ├── mitigate-aws-disk-utilization.ps1
    ├── remove-aws-disk-utilization.ps1
    └── test-aws-disk-utilization.ps1
```

Nenhum nome de imagem será reservado antecipadamente. As evidências serão selecionadas e nomeadas depois que cada resultado for efetivamente produzido.

---

## Responsabilidade dos arquivos

| Arquivo | Responsabilidade |
|:---:|---|
| `deploy-aws-disk-utilization.ps1` | Criar os recursos, anexar o volume de logs, formatá-lo e configurar a montagem persistente |
| `invoke-aws-disk-pressure.ps1` | Gerar logs controlados até ultrapassar o limite operacional, sem atingir o limite máximo de segurança |
| `diagnose-aws-disk-utilization.ps1` | Investigar capacidade, inodes, diretórios, arquivos e descritores abertos sem modificar o ambiente |
| `mitigate-aws-disk-utilization.ps1` | Aplicar rotação e compressão controladas e restaurar a utilização segura |
| `test-aws-disk-utilization.ps1` | Validar independentemente infraestrutura, montagem, estado saudável ou estado pós-mitigação |
| `remove-aws-disk-utilization.ps1` | Remover somente os recursos exclusivos do Lab 14 |
| `ec2-ssm-trust-policy.json` | Permitir que o serviço EC2 assuma a IAM Role do laboratório |

---

## Escopo

O laboratório incluirá:

- localização da VPC e da sub-rede do Lab 08;
- descoberta da imagem mais recente do Amazon Linux 2023;
- criação de IAM Role e Instance Profile dedicados;
- associação da política `AmazonSSMManagedInstanceCore`;
- criação de Security Group sem regras de entrada;
- implantação de uma instância EC2;
- ausência de Key Pair;
- exigência do IMDSv2;
- volume raiz EBS `gp3` criptografado;
- volume de logs EBS `gp3` criptografado e dedicado;
- formatação `ext4` e montagem persistente;
- geração controlada de arquivos de log;
- validação do limite operacional;
- diagnóstico somente leitura;
- identificação dos maiores consumidores de espaço;
- inspeção de utilização de inodes;
- inspeção de arquivos removidos ainda abertos;
- mitigação por rotação e compressão;
- validação pós-mitigação;
- cleanup controlado;
- validação pós-cleanup;
- preservação da rede do Lab 08.

Não serão criados:

- Application Load Balancer;
- Target Group;
- Auto Scaling Group;
- NAT Gateway;
- VPC Endpoint;
- Elastic IP;
- banco de dados;
- domínio DNS;
- certificado TLS;
- Key Pair;
- regra de entrada para SSH.

---

## Pressão controlada de disco

O script de falha criará arquivos de log compressíveis somente dentro de:

```text
/var/log/lab14/generated
```

Antes de gravar dados, o script deverá:

1. confirmar o ponto de montagem esperado;
2. confirmar o dispositivo e o filesystem;
3. confirmar que o volume pertence ao Lab 14;
4. medir a capacidade e a utilização atuais;
5. calcular o volume máximo de dados que pode ser gerado;
6. recusar a execução caso não exista margem de segurança.

A geração deverá:

- exigir o parâmetro `-ConfirmDiskPressure`;
- ultrapassar aproximadamente `80%` de utilização;
- parar antes de `90%`;
- gravar apenas no diretório controlado;
- produzir mais de um arquivo para permitir análise por tamanho e idade;
- preservar o volume raiz;
- registrar a utilização antes e depois da operação.

---

## Diagnóstico estruturado

O diagnóstico será somente leitura e deverá coletar as seguintes informações.

### Filesystems e capacidade

```bash
lsblk -f
findmnt /var/log/lab14
df -hT /var/log/lab14
df -B1 /var/log/lab14
```

### Inodes

```bash
df -i /var/log/lab14
```

### Diretórios e arquivos

```bash
du -x -h --max-depth=2 /var/log/lab14
find /var/log/lab14 -xdev -type f -printf '%s %TY-%Tm-%Td %TH:%TM %p\n'
```

Os resultados deverão ser ordenados para destacar os maiores consumidores.

### Arquivos removidos ainda abertos

```bash
lsof +L1
```

Se não houver arquivos removidos ainda abertos, essa ausência deverá ser registrada como resultado válido.

### Estado da montagem

```bash
mountpoint /var/log/lab14
findmnt --verify
```

### Logs do sistema

```bash
journalctl --since '-30 minutes' --no-pager
```

O diagnóstico deverá terminar com sucesso quando confirmar que o volume correto ultrapassou o limite esperado e identificar os arquivos responsáveis. Isso não significa que o filesystem esteja saudável; significa que a causa foi localizada.

---

## Separação entre diagnóstico e mitigação

O diagnóstico e a mitigação serão executados por scripts diferentes.

Essa separação garante que:

- as evidências sejam coletadas antes da mudança;
- a investigação permaneça somente leitura;
- os arquivos responsáveis sejam conhecidos antes da mitigação;
- a recuperação exija autorização explícita;
- os estados anterior e posterior possam ser comparados.

---

## Mitigação

O script de mitigação deverá:

1. localizar e validar a instância correta;
2. confirmar o volume e o ponto de montagem;
3. medir a utilização inicial;
4. validar que somente arquivos controlados serão alterados;
5. rotacionar os arquivos de log gerados;
6. comprimir os arquivos rotacionados;
7. manter uma quantidade limitada de arquivos para auditoria;
8. sincronizar as gravações pendentes;
9. medir novamente a utilização;
10. confirmar que o volume retornou a um nível inferior a `60%`.

A mitigação exigirá o parâmetro `-ConfirmMitigation`.

O script não poderá:

- apagar arquivos fora de `/var/log/lab14/generated`;
- formatar novamente o volume;
- desmontar o filesystem durante a investigação;
- alterar o volume raiz;
- remover recursos AWS;
- modificar a rede compartilhada.

---

## Controles de segurança

- autenticação temporária pelo AWS IAM Identity Center;
- administração pelo AWS Systems Manager;
- ausência de Key Pair;
- nenhuma regra de entrada para SSH;
- IMDSv2 obrigatório;
- volumes EBS criptografados;
- volume dedicado para o incidente;
- IAM Role e Instance Profile dedicados;
- Security Group específico e sem regras de entrada;
- tags operacionais;
- validação de propriedade antes de alterações;
- limites mínimo e máximo para utilização simulada;
- autorização explícita para pressão de disco, mitigação e cleanup;
- preservação da infraestrutura compartilhada do Lab 08.

---

## Tags

Os recursos compatíveis deverão receber:

| Tag | Valor |
|:---:|:---:|
| `Project` | `cloud-infrastructure-operations-lab` |
| `Environment` | `lab` |
| `Lab` | `14` |
| `ManagedBy` | `aws-cli` |
| `Owner` | `itamarsb` |
| `Name` | Nome específico do recurso |

---

## Pré-requisitos

- Windows PowerShell 5.1 ou PowerShell 7;
- AWS CLI v2;
- Session Manager Plugin;
- perfil `cloud-operations-lab`;
- autenticação pelo AWS IAM Identity Center;
- VPC do Lab 08 disponível em `us-east-1`;
- sub-rede `lab08-public-subnet-a` disponível;
- permissões para EC2, IAM e Systems Manager.

Autenticação:

```powershell
aws sso login --profile cloud-operations-lab
```

---

## Fluxo operacional planejado

### 1. Implantação

```powershell
$DeployScript = ".\labs\14-aws-disk-utilization\scripts\deploy-aws-disk-utilization.ps1"

& $DeployScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AvailabilityZone "us-east-1a" `
    -InstanceType "t3.micro" `
    -DataVolumeSizeGiB 2
```

### 2. Validação do estado saudável

```powershell
$TestScript = ".\labs\14-aws-disk-utilization\scripts\test-aws-disk-utilization.ps1"

& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1"
```

### 3. Pressão controlada

```powershell
$PressureScript = ".\labs\14-aws-disk-utilization\scripts\invoke-aws-disk-pressure.ps1"

& $PressureScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -TargetUsagePercent 82 `
    -MaximumUsagePercent 88 `
    -ConfirmDiskPressure
```

### 4. Diagnóstico

```powershell
$DiagnosisScript = ".\labs\14-aws-disk-utilization\scripts\diagnose-aws-disk-utilization.ps1"

& $DiagnosisScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1"
```

### 5. Mitigação

```powershell
$MitigationScript = ".\labs\14-aws-disk-utilization\scripts\mitigate-aws-disk-utilization.ps1"

& $MitigationScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmMitigation
```

### 6. Validação pós-mitigação

```powershell
& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1"
```

### 7. Cleanup

```powershell
$RemoveScript = ".\labs\14-aws-disk-utilization\scripts\remove-aws-disk-utilization.ps1"

& $RemoveScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmRemoval
```

---

## Critérios de sucesso

O Lab 14 será considerado concluído quando:

1. a VPC e a sub-rede compartilhadas forem localizadas sem alterações;
2. existir exatamente uma instância ativa do Lab 14;
3. a instância executar Amazon Linux 2023;
4. nenhuma Key Pair estiver associada;
5. o IMDSv2 estiver configurado como obrigatório;
6. os volumes EBS utilizarem criptografia;
7. o volume de logs utilizar `gp3` e possuir `2 GiB`;
8. o volume estiver formatado com `ext4`;
9. `/var/log/lab14` estiver montado no volume dedicado;
10. a montagem persistente estiver configurada por UUID;
11. a instância estiver online no Systems Manager;
12. o estado inicial apresentar utilização inferior a `60%`;
13. a pressão controlada ultrapassar `80%`;
14. a utilização permanecer inferior a `90%`;
15. o volume raiz não sofrer pressão intencional;
16. o diagnóstico registrar capacidade e utilização;
17. o diagnóstico registrar o consumo de inodes;
18. o diagnóstico identificar os maiores diretórios e arquivos;
19. o diagnóstico verificar arquivos removidos ainda abertos;
20. nenhuma correção for realizada pelo script de diagnóstico;
21. a mitigação alterar somente arquivos controlados;
22. os logs antigos forem rotacionados e comprimidos;
23. a utilização pós-mitigação ficar abaixo de `60%`;
24. a validação independente terminar com código de saída `0`;
25. o cleanup remover todos os recursos exclusivos do Lab 14;
26. a VPC e a sub-rede do Lab 08 permanecerem disponíveis.

---

## Estado atual

- [x] escopo definido;
- [x] arquitetura definida;
- [x] estrutura de diretórios definida;
- [x] nomes dos arquivos definidos;
- [x] controles de segurança definidos;
- [x] fluxo operacional definido;
- [x] critérios de sucesso definidos;
- [x] estrutura criada no repositório;
- [x] política de confiança IAM implementada;
- [ ] script de implantação implementado;
- [ ] script de pressão controlada implementado;
- [ ] script de diagnóstico implementado;
- [ ] script de mitigação implementado;
- [ ] script de validação independente implementado;
- [ ] script de cleanup implementado;
- [ ] validação sintática concluída;
- [ ] implantação executada;
- [ ] estado saudável validado;
- [ ] pressão controlada executada;
- [ ] diagnóstico concluído;
- [ ] causa identificada;
- [ ] mitigação executada;
- [ ] estado final validado;
- [ ] cleanup executado;
- [ ] validação pós-cleanup concluída.

---

## Considerações de custo

Durante a execução, a instância EC2, o endereço IPv4 público e os volumes EBS poderão gerar cobrança.

O laboratório utilizará:

- uma instância `t3.micro`;
- um volume raiz EBS;
- um volume EBS de dados com `2 GiB`;
- um endereço IPv4 público;
- nenhum Application Load Balancer;
- nenhum NAT Gateway;
- nenhum Elastic IP.

Os recursos exclusivos do Lab 14 deverão permanecer ativos somente durante a execução e ser removidos no mesmo período de trabalho.

---

## Resultado esperado

O laboratório deverá demonstrar:

- criação e montagem persistente de um volume EBS dedicado;
- crescimento controlado de arquivos de log;
- detecção de utilização acima do limite operacional;
- diagnóstico estruturado e somente leitura;
- diferenciação entre capacidade em bytes e consumo de inodes;
- identificação dos principais consumidores de espaço;
- verificação de arquivos removidos ainda abertos;
- mitigação segura por rotação e compressão;
- validação independente após a mitigação;
- cleanup dos recursos temporários;
- preservação da rede compartilhada do Lab 08.

