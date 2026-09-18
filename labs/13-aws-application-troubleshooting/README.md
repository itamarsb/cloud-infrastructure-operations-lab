# Lab 13 — Troubleshooting de aplicação indisponível

## Objetivo

Implantar uma aplicação web inicialmente saudável, introduzir uma falha controlada no Nginx, executar um diagnóstico estruturado e recuperar o serviço.

O laboratório exercita uma investigação operacional baseada em cinco camadas:

1. estado do serviço;
2. existência do processo;
3. porta TCP utilizada pela aplicação;
4. validade da configuração;
5. logs do sistema.

A instância Amazon EC2 será administrada pelo AWS Systems Manager, sem chave SSH e sem regra de entrada para a porta TCP `22`.

A falha será provocada por uma configuração inválida do Nginx. O diagnóstico deverá identificar a causa sem modificar o ambiente. A recuperação será executada separadamente por um script específico.

> **English summary:** Deploy a healthy Nginx web application, introduce a controlled configuration failure, diagnose service, process, port, configuration and logs, recover the application, validate the final state and remove temporary AWS resources.

---

## Cenário

A aplicação será implantada e validada em estado saudável.

Em seguida, o laboratório executará este fluxo:

```text
Aplicação saudável
        |
        v
Configuração inválida introduzida
        |
        v
Restart do Nginx falha
        |
        v
Aplicação fica indisponível
        |
        v
Diagnóstico somente leitura
        |
        v
Causa identificada
        |
        v
Configuração válida restaurada
        |
        v
Nginx recuperado
        |
        v
Aplicação novamente disponível
```

O objetivo não é apenas reiniciar um serviço, mas demonstrar uma sequência de investigação que possa ser aplicada a incidentes reais.

---

## Arquitetura

O laboratório reutiliza a VPC e uma das sub-redes públicas criadas no Lab 08.

```text
Cliente HTTP
     |
     v
Security Group
     |
     v
Amazon EC2
Amazon Linux 2023
Nginx
```

O acesso administrativo utiliza um caminho separado:

```text
AWS IAM Identity Center
          |
          v
AWS Systems Manager
          |
          v
Amazon EC2
```

A instância não utiliza Key Pair e não possui regra de entrada para SSH.

---

## Componentes

| Componente | Configuração |
|:---:|:---:|
| Região | `us-east-1` |
| VPC | `lab08-application-vpc` |
| Sub-rede | `lab08-public-subnet-a` |
| Zona de disponibilidade | `us-east-1a` |
| Instância EC2 | `lab13-troubleshooting-instance` |
| Tipo da instância | `t3.micro` |
| Sistema operacional | Amazon Linux 2023 |
| Serviço web | Nginx |
| Security Group | `lab13-troubleshooting-sg` |
| IAM Role | `lab13-ec2-troubleshooting-role` |
| Instance Profile | `lab13-ec2-troubleshooting-instance-profile` |
| Política do Systems Manager | `AmazonSSMManagedInstanceCore` |
| Porta da aplicação | TCP `80` |
| Endpoint de saúde | `/health` |
| Acesso administrativo | AWS Systems Manager |
| Key Pair | Não utilizada |
| IMDSv2 | Obrigatório |

---

## Estrutura

```text
labs/13-aws-application-troubleshooting/
├── README.md
├── images/
├── policies/
│   └── ec2-ssm-trust-policy.json
└── scripts/
    ├── deploy-aws-application-troubleshooting.ps1
    ├── diagnose-aws-application-failure.ps1
    ├── invoke-aws-application-failure.ps1
    ├── recover-aws-application-service.ps1
    ├── remove-aws-application-troubleshooting.ps1
    └── test-aws-application-troubleshooting.ps1
```

Nenhum nome de imagem é reservado antecipadamente. As evidências serão registradas durante a execução, conforme os resultados efetivamente produzidos.

---

## Responsabilidade dos arquivos

| Arquivo | Responsabilidade |
|---|---|
| `deploy-aws-application-troubleshooting.ps1` | Criar a infraestrutura e implantar o Nginx em estado saudável |
| `invoke-aws-application-failure.ps1` | Introduzir uma configuração inválida e provocar a indisponibilidade |
| `diagnose-aws-application-failure.ps1` | Investigar serviço, processo, porta, configuração e logs sem corrigir a falha |
| `recover-aws-application-service.ps1` | Restaurar a configuração válida e recuperar o Nginx |
| `test-aws-application-troubleshooting.ps1` | Validar independentemente a infraestrutura e o estado saudável da aplicação |
| `remove-aws-application-troubleshooting.ps1` | Remover somente os recursos específicos do Lab 13 |
| `ec2-ssm-trust-policy.json` | Permitir que o serviço EC2 assuma a IAM Role do laboratório |

---

## Escopo

O laboratório inclui:

- localização da VPC do Lab 08;
- localização da sub-rede pública `lab08-public-subnet-a`;
- descoberta da imagem mais recente do Amazon Linux 2023;
- criação de IAM Role e Instance Profile;
- associação da política `AmazonSSMManagedInstanceCore`;
- criação de Security Group específico;
- implantação de uma instância EC2;
- ausência de Key Pair;
- exigência do IMDSv2;
- utilização de volume raiz EBS `gp3` criptografado;
- instalação e configuração do Nginx;
- criação de página web de identificação;
- criação do endpoint `/health`;
- validação inicial da aplicação;
- introdução de uma configuração inválida;
- tentativa controlada de reinicialização do Nginx;
- confirmação da indisponibilidade;
- diagnóstico somente leitura;
- identificação da causa nos logs;
- restauração da configuração válida;
- recuperação do serviço;
- validação independente após a recuperação;
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

## Falha controlada

O script de falha criará uma cópia de segurança da configuração válida antes de qualquer alteração.

Depois disso, será introduzida uma diretiva inválida em um arquivo de configuração do Nginx.

O fluxo esperado será:

```text
Configuração válida
        |
        v
Backup criado
        |
        v
Configuração inválida gravada
        |
        v
nginx -t retorna erro
        |
        v
Restart do serviço falha
        |
        v
Aplicação fica indisponível
```

A falha não deverá:

- encerrar a instância;
- alterar a VPC ou a sub-rede;
- modificar o Security Group;
- remover o Instance Profile;
- alterar a IAM Role;
- instalar ou remover pacotes;
- apagar os arquivos originais sem cópia de segurança.

A execução exigirá autorização explícita pelo parâmetro `-ConfirmFailureInjection`.

---

## Diagnóstico estruturado

O script de diagnóstico não poderá corrigir ou modificar o ambiente.

Ele deverá coletar e interpretar as seguintes informações.

### Serviço

```bash
systemctl is-active nginx
systemctl is-failed nginx
systemctl status nginx --no-pager
```

### Processo

```bash
pgrep -a nginx
```

### Porta

```bash
ss -lntp
```

O diagnóstico deverá confirmar se existe algum processo escutando na porta TCP `80`.

### Configuração

```bash
nginx -t
```

A saída e o código de retorno deverão ser preservados no resultado do diagnóstico.

### Logs

```bash
journalctl -u nginx --no-pager
```

Os registros deverão permitir relacionar a indisponibilidade à configuração inválida.

### Resposta local

```bash
curl --fail --silent --show-error http://127.0.0.1/
curl --fail --silent --show-error http://127.0.0.1/health
```

Durante a falha, as requisições deverão falhar de maneira esperada.

---

## Separação entre diagnóstico e recuperação

O diagnóstico e a recuperação serão executados por scripts diferentes.

Essa separação garante que:

- as evidências do incidente sejam coletadas antes da correção;
- o diagnóstico permaneça somente leitura;
- a causa seja conhecida antes da mudança;
- a recuperação exija uma ação explícita;
- o estado anterior e o estado posterior possam ser comparados.

O script de diagnóstico terminará com sucesso quando identificar corretamente a assinatura esperada da falha. Isso não significa que a aplicação esteja saudável; significa que o diagnóstico encontrou a causa prevista.

---

## Recuperação

O script de recuperação deverá:

1. localizar a instância correta;
2. confirmar que ela pertence ao Lab 13;
3. verificar a existência da cópia de segurança;
4. restaurar a configuração válida;
5. executar `nginx -t`;
6. reiniciar o Nginx;
7. aguardar o serviço ficar ativo;
8. confirmar que a porta TCP `80` voltou a responder;
9. validar `/`;
10. validar `/health`;
11. remover somente os artefatos temporários da falha.

Se a configuração restaurada não passar pelo `nginx -t`, o script não deverá tentar iniciar o serviço.

---

## Controles de segurança

- autenticação temporária pelo AWS IAM Identity Center;
- administração pelo AWS Systems Manager;
- ausência de Key Pair;
- nenhuma regra de entrada para SSH;
- IMDSv2 obrigatório;
- volume raiz EBS criptografado;
- tipo de volume `gp3`;
- IAM Role dedicada;
- Instance Profile dedicado;
- Security Group específico;
- tags operacionais;
- validação de propriedade antes de alterações;
- autorização explícita para falha e cleanup;
- preservação da infraestrutura compartilhada do Lab 08.

---

## Tags

Os recursos compatíveis deverão receber:

| Tag | Valor |
|---|---|
| `Project` | `cloud-infrastructure-operations-lab` |
| `Environment` | `lab` |
| `Lab` | `13` |
| `ManagedBy` | `aws-cli` |
| `Owner` | `itamarsb` |
| `Name` | Nome específico do recurso |

As tags serão utilizadas para identificação operacional e proteção adicional durante as alterações e o cleanup.

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

## Fluxo operacional

### 1. Implantação

```powershell
$DeployScript = ".\labs\13-aws-application-troubleshooting\scripts\deploy-aws-application-troubleshooting.ps1"

& $DeployScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AvailabilityZone "us-east-1a" `
    -InstanceType "t3.micro"
```

### 2. Validação do estado saudável

```powershell
$TestScript = ".\labs\13-aws-application-troubleshooting\scripts\test-aws-application-troubleshooting.ps1"

& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1"
```

### 3. Introdução da falha

```powershell
$FailureScript = ".\labs\13-aws-application-troubleshooting\scripts\invoke-aws-application-failure.ps1"

& $FailureScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmFailureInjection
```

### 4. Diagnóstico

```powershell
$DiagnosisScript = ".\labs\13-aws-application-troubleshooting\scripts\diagnose-aws-application-failure.ps1"

& $DiagnosisScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1"
```

### 5. Recuperação

```powershell
$RecoveryScript = ".\labs\13-aws-application-troubleshooting\scripts\recover-aws-application-service.ps1"

& $RecoveryScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmRecovery
```

### 6. Validação após a recuperação

```powershell
& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1"
```

### 7. Cleanup

```powershell
$RemoveScript = ".\labs\13-aws-application-troubleshooting\scripts\remove-aws-application-troubleshooting.ps1"

& $RemoveScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmRemoval
```

---

## Critérios de sucesso

O Lab 13 será considerado concluído quando:

1. a VPC e a sub-rede do Lab 08 forem localizadas sem alterações;
2. existir exatamente uma instância ativa do Lab 13;
3. a instância executar Amazon Linux 2023;
4. nenhuma Key Pair estiver associada;
5. o IMDSv2 estiver configurado como obrigatório;
6. o volume raiz utilizar `gp3` e criptografia;
7. a instância estiver online no Systems Manager;
8. o Nginx estiver inicialmente ativo;
9. a porta TCP `80` estiver inicialmente aberta pelo serviço;
10. `/` e `/health` responderem corretamente;
11. a falha controlada criar uma cópia de segurança;
12. uma configuração inválida for introduzida;
13. o teste de configuração do Nginx falhar;
14. o restart do Nginx falhar de maneira controlada;
15. a aplicação ficar indisponível;
16. o diagnóstico confirmar o estado do serviço;
17. o diagnóstico confirmar a ausência do processo esperado;
18. o diagnóstico confirmar a ausência de escuta na porta TCP `80`;
19. o diagnóstico registrar a falha do `nginx -t`;
20. o diagnóstico localizar a causa nos logs;
21. nenhuma correção for realizada pelo script de diagnóstico;
22. a configuração válida for restaurada;
23. o `nginx -t` retornar sucesso após a restauração;
24. o Nginx voltar ao estado ativo;
25. a porta TCP `80` voltar a responder;
26. a aplicação voltar a responder corretamente;
27. a validação independente terminar com código de saída `0`;
28. o cleanup remover todos os recursos específicos do Lab 13;
29. a rede compartilhada do Lab 08 permanecer disponível.

---

## Estado atual

- [x] escopo definido;
- [x] arquitetura definida;
- [x] estrutura de diretórios criada;
- [x] nomes dos arquivos definidos;
- [x] fluxo de troubleshooting definido;
- [x] critérios de sucesso definidos;
- [ ] política de confiança IAM implementada;
- [ ] script de implantação implementado;
- [ ] script de falha controlada implementado;
- [ ] script de diagnóstico implementado;
- [ ] script de recuperação implementado;
- [ ] script de validação independente implementado;
- [ ] script de cleanup implementado;
- [ ] validação sintática concluída;
- [ ] implantação executada;
- [ ] estado saudável validado;
- [ ] falha controlada executada;
- [ ] diagnóstico concluído;
- [ ] causa identificada;
- [ ] serviço recuperado;
- [ ] estado final validado;
- [ ] cleanup executado;
- [ ] validação pós-cleanup concluída.

---

## Considerações de custo

Durante a execução, a instância EC2, o endereço IPv4 público e o volume EBS podem gerar cobrança.

O laboratório utilizará:

- uma instância `t3.micro`;
- um volume raiz EBS;
- um endereço IPv4 público;
- nenhum Application Load Balancer;
- nenhum NAT Gateway;
- nenhum Elastic IP;
- nenhum domínio DNS.

Os recursos específicos do Lab 13 deverão permanecer ativos somente durante a implantação, o diagnóstico, a recuperação e as validações.

Após a conclusão do fluxo, o cleanup deverá ser executado no mesmo período de trabalho.

---

## Resultado esperado

O laboratório deverá demonstrar:

- implantação de uma aplicação inicialmente saudável;
- introdução segura de uma falha de configuração;
- indisponibilidade verificável;
- diagnóstico estruturado e somente leitura;
- correlação entre serviço, processo, porta, configuração e logs;
- identificação da causa antes da correção;
- recuperação controlada;
- validação independente após a recuperação;
- cleanup dos recursos temporários;
- preservação da rede compartilhada do Lab 08.
