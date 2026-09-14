# Lab 10 — Serviço web Nginx em Linux

## Objetivo

Implantar e operar um serviço web Nginx em uma instância Amazon Linux 2023, utilizando `systemd`, validação HTTP e acesso administrativo seguro pelo AWS Systems Manager Session Manager.

O laboratório reutiliza temporariamente a rede criada no Lab 08 e aplica controles de segurança como ausência de chave SSH, bloqueio da porta TCP `22`, IMDSv2 obrigatório, volume EBS criptografado e acesso HTTP limitado ao endereço IPv4 público do operador.

> **English summary:** Deploy and operate an Nginx web service on Amazon Linux 2023 using systemd, restricted HTTP access, independent validation, AWS Systems Manager administration, and controlled cleanup.

---

## Arquitetura

O Lab 10 utiliza uma instância EC2 na sub-rede pública do Lab 08.

    Navegador do operador
        |
        | HTTP TCP 80
        | origem autorizada: IPv4 público /32
        v
    Security Group do Lab 10
        |
        v
    EC2 Amazon Linux 2023
        |
        ├── Nginx
        ├── systemd
        └── AWS Systems Manager Agent

O acesso administrativo ocorre exclusivamente pelo Systems Manager Session Manager:

    Operador autenticado pelo AWS IAM Identity Center
                         |
                         v
             AWS Systems Manager
                         |
                         v
              EC2 do Lab 10

| Componente | Configuração |
|:---:|:---:|
| Região | `us-east-1` |
| Zona de disponibilidade | `us-east-1a` |
| VPC | `lab08-application-vpc` |
| Sub-rede | `lab08-public-subnet-a` |
| Instância | `lab10-linux-web-server` |
| Tipo | `t3.micro` |
| Sistema operacional | Amazon Linux 2023 |
| Serviço web | Nginx |
| Gerenciamento do serviço | `systemd` |
| Porta HTTP | TCP `80` |
| Origem HTTP | IPv4 público autorizado com máscara `/32` |
| Acesso administrativo | AWS Systems Manager Session Manager |
| Porta SSH | Não permitida |
| Key Pair | Não utilizada |
| Security Group | `lab10-linux-web-sg` |
| IAM Role | `lab10-ec2-ssm-role` |
| Instance Profile | `lab10-ec2-ssm-instance-profile` |
| Política IAM | `AmazonSSMManagedInstanceCore` |
| IMDS | IMDSv2 obrigatório |
| Volume raiz | EBS `gp3`, 8 GiB e criptografado |

---

## Escopo

O laboratório inclui:

- descoberta dinâmica da imagem mais recente do Amazon Linux 2023;
- criação de IAM Role e Instance Profile para o Systems Manager;
- criação de Security Group específico para o Lab 10;
- liberação temporária da porta TCP `80` para apenas um endereço IPv4 `/32`;
- ausência de regra de entrada para a porta TCP `22`;
- implantação de uma instância EC2 sem Key Pair;
- instalação do Nginx;
- criação de uma página web estática identificando o laboratório;
- inicialização e habilitação do Nginx pelo `systemd`;
- validação HTTP do serviço;
- validação independente e somente leitura da infraestrutura;
- acesso administrativo pelo Session Manager;
- cleanup controlado por nomes e tags;
- preservação da rede criada no Lab 08.

Não serão criados:

- NAT Gateway;
- VPC Endpoints;
- Elastic IP;
- Load Balancer;
- Auto Scaling Group;
- certificado TLS;
- domínio DNS;
- banco de dados;
- Key Pair;
- regra de entrada para SSH.

Esses componentes não são necessários para demonstrar o objetivo operacional deste laboratório.

---

## Princípio de segurança

A porta TCP `80` não será liberada para toda a Internet.

O script de implantação receberá o endereço IPv4 público autorizado no formato CIDR:

    203.0.113.10/32

A máscara `/32` permite acesso somente a um endereço IPv4.

O laboratório não utiliza chave SSH nem permite conexões pela porta TCP `22`. A administração da instância será realizada pelo Systems Manager Session Manager.

> O endereço `203.0.113.10/32` é apenas um exemplo documental e não deve ser utilizado na implantação.

---

## Estrutura planejada

    labs/10-linux-web-service/
    ├── README.md
    ├── images/
    │   ├── lab10-deployment-success.png
    │   ├── lab10-http-validation.png
    │   ├── lab10-systemd-validation.png
    │   └── lab10-cleanup-success.png
    ├── policies/
    │   └── ec2-ssm-trust-policy.json
    └── scripts/
        ├── deploy-linux-web-service.ps1
        ├── test-linux-web-service.ps1
        └── remove-linux-web-service.ps1

| Arquivo | Responsabilidade |
|:---:|---|
| `deploy-linux-web-service.ps1` | Criar IAM, Security Group, EC2 e configurar o Nginx |
| `test-linux-web-service.ps1` | Validar infraestrutura, segurança, `systemd` e resposta HTTP |
| `remove-linux-web-service.ps1` | Remover somente os recursos pertencentes ao Lab 10 |
| `ec2-ssm-trust-policy.json` | Permitir que o serviço EC2 assuma a IAM Role |

---

## Critérios de sucesso

O Lab 10 será considerado concluído quando:

1. existir exatamente uma instância EC2 ativa com as tags esperadas;
2. a instância estiver executando Amazon Linux 2023;
3. nenhum Key Pair estiver associado;
4. o IMDSv2 estiver configurado como obrigatório;
5. o volume raiz EBS estiver criptografado e utilizar `gp3`;
6. a IAM Role estiver associada ao Instance Profile;
7. a política `AmazonSSMManagedInstanceCore` estiver anexada;
8. a instância estiver online no Systems Manager;
9. não existir regra de entrada para a porta TCP `22`;
10. a porta TCP `80` aceitar somente o endereço IPv4 autorizado;
11. o Nginx estiver ativo e habilitado no `systemd`;
12. a página do laboratório responder com HTTP `200`;
13. o conteúdo retornado identificar o Lab 10;
14. o cleanup remover os recursos do Lab 10;
15. a VPC e a sub-rede do Lab 08 permanecerem disponíveis.

---

## Pré-requisitos

- Windows PowerShell 5.1 ou PowerShell 7;
- AWS CLI v2;
- Session Manager Plugin;
- perfil `cloud-operations-lab` configurado pelo IAM Identity Center;
- Lab 08 implantado em `us-east-1`;
- acesso à Internet pela instância;
- endereço IPv4 público do operador;
- permissões necessárias para EC2, IAM e Systems Manager.

Autenticação:

    aws sso login --profile cloud-operations-lab

---

## Fluxo operacional planejado

### 1. Implantação

O script de implantação receberá:

- perfil AWS;
- região;
- zona de disponibilidade;
- tipo da instância;
- endereço IPv4 autorizado no formato CIDR `/32`.

Exemplo planejado:

    $DeployScript = ".\labs\10-linux-web-service\scripts\deploy-linux-web-service.ps1"

    & $DeployScript `
        -ProfileName "cloud-operations-lab" `
        -Region "us-east-1" `
        -AvailabilityZone "us-east-1a" `
        -InstanceType "t3.micro" `
        -AllowedHttpCidr "SEU_IPV4_PUBLICO/32"

O endereço real será informado somente no terminal e não deverá ser gravado permanentemente no repositório.

### 2. Validação independente

O validador realizará consultas à AWS, verificará a configuração de segurança e confirmará o funcionamento do serviço web.

Exemplo planejado:

    $TestScript = ".\labs\10-linux-web-service\scripts\test-linux-web-service.ps1"

    & $TestScript `
        -ProfileName "cloud-operations-lab" `
        -Region "us-east-1" `
        -AllowedHttpCidr "SEU_IPV4_PUBLICO/32"

### 3. Acesso administrativo

O acesso à instância será realizado pelo Systems Manager Session Manager, sem SSH:

    aws ssm start-session `
        --target ID_DA_INSTANCIA `
        --profile cloud-operations-lab `
        --region us-east-1

Durante a sessão serão verificados:

    sudo systemctl status nginx
    sudo systemctl is-enabled nginx
    curl http://localhost
    exit

### 4. Cleanup

A remoção exigirá confirmação explícita:

    $RemoveScript = ".\labs\10-linux-web-service\scripts\remove-linux-web-service.ps1"

    & $RemoveScript `
        -ProfileName "cloud-operations-lab" `
        -Region "us-east-1" `
        -ConfirmRemoval

O cleanup deverá remover:

- instância EC2 do Lab 10;
- Security Group do Lab 10;
- Instance Profile do Lab 10;
- IAM Role do Lab 10.

A rede do Lab 08 não será modificada.

---

## Evidências planejadas

As capturas serão registradas somente depois das execuções reais.

| Evidência | Conteúdo esperado |
|:---:|:---:|
| `lab10-deployment-success.png` | Implantação concluída e instância online no Systems Manager |
| `lab10-http-validation.png` | Resposta HTTP `200` e conteúdo da página do Lab 10 |
| `lab10-systemd-validation.png` | Nginx ativo e habilitado no `systemd` |
| `lab10-cleanup-success.png` | Recursos do Lab 10 removidos e rede do Lab 08 preservada |

As imagens não devem ser criadas antecipadamente nem substituídas por resultados simulados.

---

## Estado atual

- [x] arquitetura definida;
- [x] escopo definido;
- [x] nomes dos recursos definidos;
- [x] critérios de sucesso definidos;
- [ ] política de confiança criada;
- [ ] script de implantação criado;
- [ ] script de validação criado;
- [ ] script de remoção criado;
- [ ] validação sintática concluída;
- [ ] implantação executada;
- [ ] serviço web validado;
- [ ] acesso pelo Session Manager comprovado;
- [ ] evidências registradas;
- [ ] cleanup executado;
- [ ] estado final validado.

---

## Considerações de custo

A instância EC2, o volume EBS e o endereço IPv4 público podem gerar cobrança enquanto estiverem em uso.

O laboratório utilizará uma única instância `t3.micro`, não criará NAT Gateway e prevê a remoção dos recursos imediatamente após o registro das evidências.

O Security Group, a IAM Role e o Instance Profile não possuem cobrança direta, mas devem ser removidos para manter a conta organizada.

---

## Resultado esperado

Ao final do laboratório, o repositório deverá demonstrar:

- implantação segura de uma instância Linux;
- instalação e operação do Nginx;
- gerenciamento de serviço com `systemd`;
- validação HTTP externa e local;
- controle de acesso por Security Group;
- administração sem SSH;
- validação independente;
- remoção segura dos recursos;
- preservação da infraestrutura compartilhada do Lab 08.
