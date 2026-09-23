# Lab 15 — Troubleshooting de conectividade na AWS

## Objetivo

Implantar uma aplicação Nginx em uma instância Amazon EC2, validar sua conectividade, introduzir uma falha controlada na camada de rede, executar um diagnóstico somente leitura, identificar a causa e aplicar uma recuperação autorizada.

O laboratório exercitará uma investigação operacional por camadas:

1. identidade e sessão AWS;
2. estado da infraestrutura;
3. estado da instância EC2;
4. registro no AWS Systems Manager;
5. estado do serviço Nginx;
6. processo e porta em escuta;
7. resposta HTTP local;
8. endereço IPv4 público;
9. associação do Security Group;
10. regras de entrada;
11. Network ACL;
12. tabela de rotas;
13. Internet Gateway;
14. resposta HTTP observada externamente.

A falha será provocada pela remoção controlada da regra de entrada HTTP do Security Group.

O Nginx continuará ativo, a porta TCP `80` continuará em escuta e a aplicação continuará respondendo localmente. Entretanto, o acesso HTTP externo deixará de funcionar.

> **English summary:** Deploy an Nginx application on Amazon EC2, validate external HTTP connectivity, introduce a controlled Security Group failure, diagnose the network path layer by layer, identify the missing ingress rule, restore connectivity and safely remove the temporary AWS resources.

---

## Cenário

Uma instância Amazon EC2 executará Nginx em uma sub-rede pública compartilhada do Lab 08.

Inicialmente, o endpoint HTTP ficará acessível somente a partir de um CIDR autorizado.

O fluxo planejado será:

```text
Aplicação saudável
        |
        v
HTTP externo acessível
        |
        v
Remoção controlada da regra TCP 80
        |
        v
HTTP externo indisponível
        |
        v
Nginx permanece ativo
        |
        v
HTTP local permanece saudável
        |
        v
Diagnóstico por camadas
        |
        v
Security Group identificado como causa
        |
        v
Regra TCP 80 restaurada
        |
        v
HTTP externo recuperado
        |
        v
Validação independente
        |
        v
Cleanup dos recursos exclusivos
```

O objetivo não será apenas restaurar a conectividade, mas demonstrar como diferenciar:

- falha da aplicação;
- falha do serviço;
- falha da instância;
- falha do Systems Manager;
- falha de rota;
- falha de Network ACL;
- falha de Security Group;
- falha observada pelo cliente.

---

## Falha controlada

A falha será introduzida exclusivamente pela remoção da seguinte autorização de entrada:

| Protocolo | Porta | Origem |
|:---:|:---:|:---:|
| TCP | `80` | CIDR autorizado pelo operador |

Nenhuma outra camada será modificada durante a introdução da falha.

O script de falha não poderá:

- parar o Nginx;
- encerrar processos;
- alterar arquivos de configuração;
- modificar o conteúdo da aplicação;
- remover o endereço IPv4 público;
- alterar a tabela de rotas;
- alterar a Network ACL;
- remover ou substituir o Internet Gateway;
- alterar as regras de saída;
- remover a IAM Role;
- interromper o agente do Systems Manager;
- encerrar a instância;
- modificar a VPC ou a sub-rede do Lab 08.

A falha deverá ser reversível pela restauração exata da regra removida.

---

## Hipótese operacional

Quando a regra HTTP estiver ausente, os seguintes resultados serão esperados:

| Verificação | Resultado esperado |
|:---:|:---:|
| Instância EC2 | `running` |
| Systems Manager | `Online` |
| Serviço Nginx | `active` |
| Processo Nginx | Presente |
| Porta TCP `80` | Em escuta |
| `nginx -t` | Válido |
| Requisição local para `/` | Sucesso |
| Requisição local para `/health` | Sucesso |
| Rota para Internet Gateway | Presente |
| Network ACL | Sem alteração |
| Regra HTTP no Security Group | Ausente |
| Requisição HTTP externa | Falha ou timeout |

Essa combinação permitirá concluir que a aplicação e a instância continuam saudáveis, mas o tráfego de entrada está sendo bloqueado na camada do Security Group.

---

## Decisão de segurança

A falha permanecerá limitada a uma única regra de entrada do Security Group exclusivo do Lab 15.

O acesso administrativo continuará disponível pelo AWS Systems Manager porque:

- nenhuma Key Pair será utilizada;
- não haverá regra de entrada para SSH;
- a regra de saída continuará disponível;
- a IAM Role permanecerá associada;
- o agente do Systems Manager continuará ativo;
- a instância permanecerá em execução.

O CIDR HTTP será fornecido explicitamente durante a implantação.

Não será permitido utilizar `0.0.0.0/0` como origem HTTP.

---

## Arquitetura

O Lab 15 reutilizará a VPC e a sub-rede pública criadas no Lab 08.

```text
Cliente autorizado
        |
        | HTTP TCP 80
        v
Internet Gateway compartilhado
        |
        v
Tabela de rotas compartilhada
        |
        v
Network ACL compartilhada
        |
        v
Security Group exclusivo do Lab 15
        |
        v
Amazon EC2
Amazon Linux 2023
        |
        v
Nginx
/ e /health
```

O acesso administrativo ocorrerá separadamente:

```text
AWS IAM Identity Center
        |
        v
AWS Systems Manager
        |
        v
SSM Agent
        |
        v
Amazon EC2
```

A falha afetará somente o caminho HTTP externo.

---

## Componentes

| Componente | Configuração planejada |
|:---:|:---:|
| Região | `us-east-1` |
| VPC compartilhada | `lab08-application-vpc` |
| Sub-rede compartilhada | `lab08-public-subnet-a` |
| Zona de disponibilidade | `us-east-1a` |
| Instância EC2 | `lab15-connectivity-troubleshooting-instance` |
| Tipo da instância | `t3.micro` |
| Sistema operacional | Amazon Linux 2023 |
| Aplicação | Nginx |
| Endpoint principal | `/` |
| Endpoint de saúde | `/health` |
| Protocolo externo | HTTP |
| Porta externa | TCP `80` |
| Origem HTTP | CIDR autorizado |
| Security Group | `lab15-connectivity-troubleshooting-sg` |
| IAM Role | `lab15-ec2-connectivity-troubleshooting-role` |
| Instance Profile | `lab15-ec2-connectivity-troubleshooting-instance-profile` |
| Política do Systems Manager | `AmazonSSMManagedInstanceCore` |
| Acesso administrativo | AWS Systems Manager |
| Key Pair | Não utilizada |
| Regra SSH | Não criada |
| IMDSv2 | Obrigatório |
| Volume raiz | EBS `gp3` criptografado |
| Endereço público | IPv4 público dinâmico |

---

## Estrutura

```text
labs/15-aws-connectivity-troubleshooting/
├── README.md
├── images/
│   └── .gitkeep
├── policies/
│   └── ec2-ssm-trust-policy.json
└── scripts/
    ├── deploy-aws-connectivity-troubleshooting.ps1
    ├── diagnose-aws-connectivity-failure.ps1
    ├── invoke-aws-connectivity-failure.ps1
    ├── recover-aws-connectivity.ps1
    ├── remove-aws-connectivity-troubleshooting.ps1
    └── test-aws-connectivity-troubleshooting.ps1
```

Nenhum nome de imagem será reservado antecipadamente.

As evidências serão selecionadas e nomeadas somente depois que os respectivos resultados forem produzidos.

---

## Responsabilidade dos arquivos

| Arquivo | Responsabilidade |
|---|---|
| `deploy-aws-connectivity-troubleshooting.ps1` | Localizar a rede do Lab 08 e criar a infraestrutura exclusiva do Lab 15 |
| `invoke-aws-connectivity-failure.ps1` | Remover somente a regra HTTP autorizada e confirmar a indisponibilidade externa |
| `diagnose-aws-connectivity-failure.ps1` | Investigar a conectividade por camadas sem modificar o ambiente |
| `recover-aws-connectivity.ps1` | Restaurar somente a regra HTTP ausente e confirmar a recuperação |
| `test-aws-connectivity-troubleshooting.ps1` | Validar independentemente a infraestrutura e o estado esperado da conectividade |
| `remove-aws-connectivity-troubleshooting.ps1` | Remover somente os recursos exclusivos do Lab 15 |
| `ec2-ssm-trust-policy.json` | Permitir que o serviço EC2 assuma a IAM Role do laboratório |

---

## Tags

Os recursos compatíveis deverão receber:

| Tag | Valor |
|---|---|
| `Project` | `cloud-infrastructure-operations-lab` |
| `Environment` | `lab` |
| `Lab` | `15` |
| `ManagedBy` | `aws-cli` |
| `Owner` | `itamarsb` |
| `Name` | Nome específico do recurso |

As tags serão utilizadas como mecanismo de identificação e validação de propriedade antes de alterações ou remoções.

---

## Escopo

O laboratório incluirá:

- localização da VPC compartilhada do Lab 08;
- localização da sub-rede pública `lab08-public-subnet-a`;
- confirmação da zona `us-east-1a`;
- validação da tabela de rotas;
- validação do Internet Gateway;
- inspeção da Network ACL;
- descoberta da imagem mais recente do Amazon Linux 2023;
- criação de IAM Role;
- criação de Instance Profile;
- associação da política `AmazonSSMManagedInstanceCore`;
- criação de Security Group exclusivo;
- criação de regra HTTP limitada ao CIDR autorizado;
- implantação de uma instância EC2;
- ausência de Key Pair;
- exigência do IMDSv2;
- volume raiz EBS `gp3` criptografado;
- instalação e configuração do Nginx;
- endpoint principal;
- endpoint de saúde;
- validação HTTP local;
- validação HTTP externa;
- introdução controlada da falha;
- diagnóstico somente leitura;
- recuperação autorizada;
- validação independente;
- cleanup;
- validação pós-cleanup;
- preservação da infraestrutura compartilhada.

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

## Pré-requisitos

- Windows PowerShell 5.1 ou PowerShell 7;
- AWS CLI v2;
- Session Manager Plugin;
- perfil AWS `cloud-operations-lab`;
- autenticação pelo AWS IAM Identity Center;
- região `us-east-1`;
- VPC do Lab 08 disponível;
- sub-rede `lab08-public-subnet-a` disponível;
- rota pública para um Internet Gateway;
- permissões para EC2, IAM e Systems Manager;
- endereço IPv4 público do operador representado como CIDR `/32`;
- árvore de trabalho do Git limpa.

Autenticação:

```powershell
aws sso login --profile cloud-operations-lab
```

Validação da identidade:

```powershell
aws sts get-caller-identity `
    --profile cloud-operations-lab `
    --region us-east-1 `
    --no-cli-pager
```

Exemplo de CIDR autorizado:

```text
203.0.113.10/32
```

O valor acima é apenas documental e deverá ser substituído pelo endereço público real utilizado durante a execução.

---

## Implantação

O script de implantação deverá:

1. validar a sessão AWS;
2. localizar exatamente uma VPC do Lab 08;
3. localizar exatamente uma sub-rede pública do Lab 08;
4. confirmar a zona de disponibilidade;
5. confirmar a rota para o Internet Gateway;
6. validar que o CIDR HTTP não é público para toda a Internet;
7. descobrir a imagem mais recente do Amazon Linux 2023;
8. criar ou localizar a IAM Role do Lab 15;
9. validar a política de confiança;
10. associar `AmazonSSMManagedInstanceCore`;
11. criar ou localizar o Instance Profile;
12. associar a IAM Role;
13. criar ou localizar o Security Group;
14. criar a regra TCP `80` para o CIDR autorizado;
15. iniciar uma instância `t3.micro`;
16. exigir IMDSv2;
17. utilizar volume raiz `gp3` criptografado;
18. não utilizar Key Pair;
19. instalar e configurar o Nginx;
20. criar os endpoints `/` e `/health`;
21. aguardar a instância ficar online no Systems Manager;
22. validar a resposta HTTP local;
23. validar a resposta HTTP externa;
24. exibir um resumo dos recursos.

Execução planejada:

```powershell
$DeployScript = ".\labs\15-aws-connectivity-troubleshooting\scripts\deploy-aws-connectivity-troubleshooting.ps1"

& $DeployScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AvailabilityZone "us-east-1a" `
    -InstanceType "t3.micro" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32"
```

O script deverá ser idempotente e recusar recursos existentes com propriedades ou tags incompatíveis.

---

## Aplicação de teste

O Nginx deverá disponibilizar:

```text
/
```

e:

```text
/health
```

A resposta principal deverá identificar o laboratório sem expor informações sensíveis.

Exemplo:

```text
Cloud Infrastructure Operations Lab
Lab 15 - Connectivity Troubleshooting
Status: healthy
```

O endpoint `/health` deverá retornar:

```text
healthy
```

A validação local será executada pela própria instância:

```bash
curl --fail --silent --show-error http://127.0.0.1/
curl --fail --silent --show-error http://127.0.0.1/health
```

---

## Validação independente

O script `test-aws-connectivity-troubleshooting.ps1` deverá aceitar estados esperados:

```powershell
[ValidateSet(
    "Healthy",
    "Failed",
    "Any"
)]
[string]$ExpectedConnectivityState = "Healthy"
```

### Estado saudável

No estado `Healthy`, o script deverá confirmar:

- infraestrutura correta;
- instância em execução;
- Systems Manager online;
- Nginx ativo;
- configuração válida;
- porta TCP `80` em escuta;
- endpoint local saudável;
- regra HTTP presente;
- rota pública presente;
- resposta HTTP externa bem-sucedida.

Execução planejada:

```powershell
$TestScript = ".\labs\15-aws-connectivity-troubleshooting\scripts\test-aws-connectivity-troubleshooting.ps1"

& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ExpectedConnectivityState "Healthy"
```

### Estado de falha

No estado `Failed`, o script deverá confirmar:

- infraestrutura correta;
- instância em execução;
- Systems Manager online;
- Nginx ativo;
- configuração válida;
- porta TCP `80` em escuta;
- endpoint local saudável;
- regra HTTP ausente;
- rota pública presente;
- falha do acesso HTTP externo.

Execução planejada:

```powershell
& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ExpectedConnectivityState "Failed"
```

O script de teste será somente leitura e não poderá corrigir o estado encontrado.

---

## Introdução controlada da falha

O script `invoke-aws-connectivity-failure.ps1` deverá:

1. exigir `-ConfirmConnectivityFailure`;
2. localizar exatamente uma instância ativa do Lab 15;
3. validar todas as tags;
4. confirmar o Security Group esperado;
5. validar o CIDR autorizado;
6. confirmar que a aplicação está saudável;
7. confirmar que o acesso HTTP externo funciona;
8. localizar exatamente a regra TCP `80` esperada;
9. remover somente essa regra;
10. confirmar que a regra ficou ausente;
11. confirmar que a instância continua em execução;
12. confirmar que o Systems Manager permanece online;
13. confirmar que o Nginx permanece ativo;
14. confirmar que o endpoint local permanece saudável;
15. confirmar a falha do acesso externo;
16. não modificar qualquer outro recurso.

Execução planejada:

```powershell
$FailureScript = ".\labs\15-aws-connectivity-troubleshooting\scripts\invoke-aws-connectivity-failure.ps1"

& $FailureScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ConfirmConnectivityFailure
```

A operação destrutiva autorizada será limitada a:

```text
ec2:RevokeSecurityGroupIngress
```

Nenhuma regra além da autorização TCP `80` para o CIDR informado poderá ser removida.

---

## Diagnóstico somente leitura

O script `diagnose-aws-connectivity-failure.ps1` deverá investigar o ambiente sem realizar correções.

### 1. Identidade AWS

O diagnóstico deverá registrar:

- Account ID;
- ARN da identidade;
- região;
- perfil utilizado.

### 2. Rede compartilhada

Deverá confirmar:

- VPC esperada;
- sub-rede esperada;
- zona de disponibilidade;
- associação da tabela de rotas;
- rota padrão;
- Internet Gateway;
- Network ACL associada.

### 3. Instância EC2

Deverá registrar:

- Instance ID;
- estado;
- endereço IPv4 privado;
- endereço IPv4 público;
- sub-rede;
- VPC;
- zona de disponibilidade;
- IAM Instance Profile;
- Security Groups;
- exigência do IMDSv2;
- ausência de Key Pair.

### 4. Systems Manager

Deverá confirmar:

- registro da instância;
- estado `Online`;
- versão do agente;
- plataforma;
- tempo da última comunicação.

### 5. Serviço e processo

A inspeção remota deverá executar comandos somente leitura equivalentes a:

```bash
systemctl is-active nginx
systemctl status nginx --no-pager
pgrep -a nginx
nginx -t
```

### 6. Porta TCP

Deverá confirmar que a porta TCP `80` continua em escuta:

```bash
ss -lntp
```

### 7. Resposta local

Deverá consultar:

```bash
curl --fail --silent --show-error http://127.0.0.1/
curl --fail --silent --show-error http://127.0.0.1/health
```

### 8. Security Group

Deverá listar e avaliar:

- Security Group associado;
- regras de entrada;
- regras de saída;
- presença ou ausência da regra TCP `80`;
- CIDR esperado;
- descrição da regra, quando disponível.

### 9. Network ACL

Deverá registrar as regras de entrada e saída da Network ACL associada à sub-rede.

A Network ACL será apenas inspecionada.

### 10. Tabela de rotas

Deverá confirmar a existência da rota:

```text
0.0.0.0/0 -> Internet Gateway
```

### 11. Conectividade externa

O diagnóstico deverá tentar consultar:

```text
http://<IP-PUBLICO>/
http://<IP-PUBLICO>/health
```

A falha ou o timeout será esperado durante o incidente.

### 12. Conclusão

O diagnóstico deverá concluir que:

- a instância está saudável;
- o acesso administrativo permanece disponível;
- o Nginx está saudável;
- a aplicação responde localmente;
- a porta esperada está em escuta;
- a rota pública está presente;
- a Network ACL não foi modificada;
- a regra HTTP está ausente;
- o acesso externo está indisponível;
- a causa está no Security Group.

Execução planejada:

```powershell
$DiagnosisScript = ".\labs\15-aws-connectivity-troubleshooting\scripts\diagnose-aws-connectivity-failure.ps1"

& $DiagnosisScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32"
```

O diagnóstico não poderá executar comandos AWS de alteração.

---

## Recuperação

O script `recover-aws-connectivity.ps1` deverá:

1. exigir `-ConfirmConnectivityRecovery`;
2. localizar a instância correta;
3. validar as tags;
4. confirmar que o Systems Manager está online;
5. confirmar que o Nginx está ativo;
6. confirmar que a aplicação responde localmente;
7. confirmar a ausência da regra esperada;
8. confirmar que nenhuma regra ampla será criada;
9. restaurar somente TCP `80` para o CIDR autorizado;
10. confirmar que a regra foi criada;
11. aguardar a propagação;
12. confirmar a resposta HTTP externa;
13. exibir um resumo da recuperação.

Execução planejada:

```powershell
$RecoveryScript = ".\labs\15-aws-connectivity-troubleshooting\scripts\recover-aws-connectivity.ps1"

& $RecoveryScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ConfirmConnectivityRecovery
```

A única operação de recuperação autorizada será:

```text
ec2:AuthorizeSecurityGroupIngress
```

O script deverá aceitar como sucesso idempotente o caso em que a regra exata já esteja presente.

---

## Cleanup

O script `remove-aws-connectivity-troubleshooting.ps1` deverá exigir:

```text
-ConfirmRemoval
```

Antes de remover recursos, deverá confirmar:

- nomes esperados;
- tags de propriedade;
- associação entre a instância e o Security Group;
- associação entre a instância e o Instance Profile;
- associação entre o Instance Profile e a IAM Role;
- escopo exclusivo do Lab 15.

A sequência planejada será:

1. localizar os recursos do Lab 15;
2. validar propriedade e relacionamentos;
3. encerrar a instância EC2;
4. aguardar o estado `terminated`;
5. remover o Security Group;
6. remover a IAM Role do Instance Profile;
7. remover o Instance Profile;
8. desassociar `AmazonSSMManagedInstanceCore`;
9. remover a IAM Role;
10. validar a ausência dos recursos exclusivos;
11. confirmar a permanência da VPC do Lab 08;
12. confirmar a permanência da sub-rede do Lab 08.

Execução planejada:

```powershell
$RemoveScript = ".\labs\15-aws-connectivity-troubleshooting\scripts\remove-aws-connectivity-troubleshooting.ps1"

& $RemoveScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmRemoval
```

O cleanup deverá ser idempotente e seguro para uma nova execução.

---

## Controles de segurança

- autenticação temporária pelo AWS IAM Identity Center;
- perfil AWS informado explicitamente;
- região informada explicitamente;
- acesso administrativo pelo Systems Manager;
- ausência de Key Pair;
- ausência de regra SSH;
- IMDSv2 obrigatório;
- volume raiz EBS criptografado;
- IAM Role exclusiva;
- Instance Profile exclusivo;
- Security Group exclusivo;
- acesso HTTP restrito a um CIDR `/32`;
- rejeição de `0.0.0.0/0`;
- tags de propriedade;
- validação antes de alterações;
- falha limitada a uma regra;
- diagnóstico somente leitura;
- recuperação explícita;
- cleanup explícito;
- scripts idempotentes;
- preservação da VPC e da sub-rede compartilhadas;
- validação da árvore de trabalho do Git.

---

## Fluxo operacional planejado

### 1. Implantação

```powershell
& $DeployScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AvailabilityZone "us-east-1a" `
    -InstanceType "t3.micro" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32"
```

### 2. Validação saudável

```powershell
& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ExpectedConnectivityState "Healthy"
```

### 3. Introdução da falha

```powershell
& $FailureScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ConfirmConnectivityFailure
```

### 4. Validação do estado de falha

```powershell
& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ExpectedConnectivityState "Failed"
```

### 5. Diagnóstico

```powershell
& $DiagnosisScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32"
```

### 6. Recuperação

```powershell
& $RecoveryScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ConfirmConnectivityRecovery
```

### 7. Validação pós-recuperação

```powershell
& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AllowedHttpCidr "<SEU-IP-PUBLICO>/32" `
    -ExpectedConnectivityState "Healthy"
```

### 8. Cleanup

```powershell
& $RemoveScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmRemoval
```

---

## Critérios de sucesso

O Lab 15 será considerado concluído quando:

1. a VPC compartilhada for localizada sem alterações;
2. a sub-rede compartilhada for localizada sem alterações;
3. a rota pública e o Internet Gateway forem confirmados;
4. exatamente uma instância ativa do Lab 15 existir;
5. a instância executar Amazon Linux 2023;
6. nenhuma Key Pair estiver associada;
7. o IMDSv2 estiver configurado como obrigatório;
8. o volume raiz utilizar `gp3` e criptografia;
9. a instância estiver online no Systems Manager;
10. o Security Group não possuir regra SSH;
11. a regra HTTP estiver limitada ao CIDR autorizado;
12. `0.0.0.0/0` não estiver autorizado;
13. o Nginx estiver ativo;
14. a configuração do Nginx for válida;
15. a porta TCP `80` estiver em escuta;
16. os endpoints locais responderem corretamente;
17. o acesso HTTP externo funcionar no estado saudável;
18. a falha remover somente a regra HTTP esperada;
19. o Systems Manager permanecer online durante a falha;
20. o Nginx permanecer ativo durante a falha;
21. os endpoints locais permanecerem saudáveis durante a falha;
22. o acesso HTTP externo falhar no estado controlado;
23. o diagnóstico não modificar o ambiente;
24. o diagnóstico identificar corretamente o Security Group como causa;
25. a recuperação restaurar somente a regra esperada;
26. o acesso HTTP externo voltar a funcionar;
27. a validação independente terminar com sucesso;
28. o cleanup remover todos os recursos exclusivos do Lab 15;
29. a VPC e a sub-rede do Lab 08 permanecerem disponíveis;
30. a árvore de trabalho permanecer limpa.

---

## Estado atual

- [x] escopo definido;
- [x] arquitetura definida;
- [x] cenário de falha definido;
- [x] controles de segurança definidos;
- [x] estrutura de diretórios criada;
- [x] nomes dos arquivos definidos;
- [ ] política de confiança IAM implementada;
- [ ] script de implantação implementado;
- [ ] script de introdução da falha implementado;
- [ ] script de diagnóstico implementado;
- [ ] script de recuperação implementado;
- [ ] script de validação independente implementado;
- [ ] script de cleanup implementado;
- [ ] validação sintática concluída;
- [ ] implantação executada;
- [ ] estado saudável validado;
- [ ] falha controlada executada;
- [ ] estado de falha validado;
- [ ] diagnóstico concluído;
- [ ] causa identificada;
- [ ] recuperação executada;
- [ ] conectividade restaurada;
- [ ] validação pós-recuperação concluída;
- [ ] cleanup executado;
- [ ] validação pós-cleanup concluída;
- [ ] evidências publicadas;
- [ ] laboratório concluído.

---

## Considerações de custo

Durante a execução, poderão gerar cobrança:

- uma instância EC2 `t3.micro`;
- um endereço IPv4 público;
- um volume raiz EBS.

O laboratório não utilizará:

- Application Load Balancer;
- NAT Gateway;
- Elastic IP;
- VPC Endpoint;
- banco de dados gerenciado.

Os recursos exclusivos do Lab 15 deverão permanecer ativos somente durante a execução e ser removidos após a conclusão.

A VPC e a sub-rede do Lab 08 serão preservadas por serem componentes compartilhados.

---

## Competências previstas

O laboratório deverá demonstrar competências relacionadas a:

- troubleshooting de conectividade;
- investigação por camadas;
- Amazon VPC;
- sub-redes públicas;
- tabelas de rotas;
- Internet Gateway;
- Network ACL;
- Security Groups;
- instâncias Amazon EC2;
- endereços IPv4 públicos;
- Nginx;
- portas TCP;
- testes HTTP;
- AWS Systems Manager;
- automação com PowerShell;
- comandos Linux executados remotamente;
- diagnóstico somente leitura;
- recuperação controlada;
- validação independente;
- scripts idempotentes;
- cleanup seguro;
- preservação de infraestrutura compartilhada.

---

## Resultado esperado

O laboratório deverá demonstrar que uma aplicação pode permanecer completamente saudável dentro da instância e, ainda assim, ficar inacessível externamente por causa de uma falha na camada de rede.

O diagnóstico deverá localizar a causa sem modificar o ambiente.

A recuperação deverá restaurar exclusivamente a autorização removida, sem reiniciar a aplicação ou alterar outras camadas.

Ao final:

- a conectividade externa deverá estar restaurada;
- a validação independente deverá confirmar o estado saudável;
- todos os recursos exclusivos do Lab 15 deverão ser removidos;
- a infraestrutura compartilhada do Lab 08 deverá permanecer disponível.
