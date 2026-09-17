# Lab 12 — Disponibilidade da aplicação com Application Load Balancer

## Objetivo

Implementar e validar uma arquitetura de aplicação web distribuída entre duas zonas de disponibilidade na AWS.

O laboratório utilizará duas instâncias Amazon EC2 com Nginx, registradas em um Target Group e acessadas por meio de um Application Load Balancer. Os health checks permitirão que o balanceador encaminhe tráfego somente para os servidores considerados saudáveis.

Uma falha controlada será executada em um dos backends para comprovar que a aplicação permanece disponível pela segunda instância. Após a recuperação do serviço, os dois servidores deverão retornar ao estado saudável.

As instâncias serão administradas pelo AWS Systems Manager, sem chave SSH e sem regra de entrada para a porta TCP `22`.

> **English summary:** Deploy and validate a highly available web application across two AWS Availability Zones using Amazon EC2, Nginx, an Application Load Balancer, Target Group health checks, controlled backend failure, service recovery, independent validation, and controlled cleanup.

---

## Arquitetura

O laboratório reutiliza a VPC e as duas sub-redes públicas criadas no Lab 08.

```
Internet
   |
   v
Application Load Balancer
   |
   v
Listener HTTP :80
   |
   v
Target Group
   |
   ├── EC2 + Nginx
   |      us-east-1a
   |
   └── EC2 + Nginx
          us-east-1b
```

O acesso administrativo seguirá um caminho separado:

```
AWS IAM Identity Center
          |
          v
AWS Systems Manager
          |
          ├── EC2 us-east-1a
          |
          └── EC2 us-east-1b
```

O Application Load Balancer será público e estará associado às duas sub-redes do Lab 08.

As instâncias também utilizarão as sub-redes públicas para acessar os serviços necessários da AWS sem NAT Gateway. Apesar de possuírem conectividade de saída, elas não aceitarão conexões HTTP diretamente da internet.

O Security Group dos backends permitirá tráfego na porta TCP `80` somente quando a origem for o Security Group do Application Load Balancer.

---

## Componentes

|          Componente         |                Configuração               |
| :-------------------------: | :---------------------------------------: |
|            Região           |                `us-east-1`                |
|             VPC             |          `lab08-application-vpc`          |
|          Sub-rede A         |          `lab08-public-subnet-a`          |
|          Sub-rede B         |          `lab08-public-subnet-b`          |
|  Zona de disponibilidade A  |                `us-east-1a`               |
|  Zona de disponibilidade B  |                `us-east-1b`               |
|         Instância A         |      `lab12-availability-instance-a`      |
|         Instância B         |      `lab12-availability-instance-b`      |
|     Tipo das instâncias     |                 `t3.micro`                |
|     Sistema operacional     |             Amazon Linux 2023             |
|         Serviço web         |                   Nginx                   |
|    Security Group do ALB    |               `lab12-alb-sg`              |
| Security Group dos backends |             `lab12-backend-sg`            |
|           IAM Role          |       `lab12-ec2-availability-role`       |
|       Instance Profile      | `lab12-ec2-availability-instance-profile` |
| Política do Systems Manager |       `AmazonSSMManagedInstanceCore`      |
|  Application Load Balancer  |          `lab12-availability-alb`         |
|         Target Group        |          `lab12-availability-tg`          |
|           Listener          |           HTTP na porta TCP `80`          |
|    Protocolo dos backends   |                    HTTP                   |
|      Porta dos backends     |                  TCP `80`                 |
|   Caminho do health check   |                 `/health`                 |
|    Acesso administrativo    |            AWS Systems Manager            |
|           Key Pair          |               Não utilizada               |
|            IMDSv2           |                Obrigatório                |

---

## Estrutura

```
labs/12-aws-application-availability/
├── README.md
├── images/
│   └── .gitkeep
├── policies/
│   └── ec2-ssm-trust-policy.json
└── scripts/
    ├── deploy-aws-application-availability.ps1
    ├── invoke-aws-availability-failure.ps1
    ├── remove-aws-application-availability.ps1
    └── test-aws-application-availability.ps1
```

|                  Arquivo                  | Responsabilidade                                                                                      |
| :---------------------------------------: | ----------------------------------------------------------------------------------------------------- |
| `deploy-aws-application-availability.ps1` | Criar IAM, Security Groups, instâncias EC2, Nginx, Target Group, Application Load Balancer e Listener |
|  `test-aws-application-availability.ps1`  | Validar a arquitetura, os controles de segurança, os targets e a resposta HTTP                        |
|   `invoke-aws-availability-failure.ps1`   | Interromper um backend, validar a continuidade da aplicação e recuperar o serviço                     |
| `remove-aws-application-availability.ps1` | Remover somente os recursos específicos do Lab 12                                                     |
|        `ec2-ssm-trust-policy.json`        | Permitir que o serviço EC2 assuma a IAM Role do laboratório                                           |

---

## Escopo

O laboratório inclui:

* localização da VPC do Lab 08;
* localização das duas sub-redes públicas;
* confirmação de que as sub-redes pertencem a zonas de disponibilidade diferentes;
* descoberta da imagem mais recente do Amazon Linux 2023;
* criação de IAM Role e Instance Profile;
* associação da política `AmazonSSMManagedInstanceCore`;
* criação de Security Group para o Application Load Balancer;
* criação de Security Group dedicado aos backends;
* restrição do acesso HTTP aos backends;
* implantação de duas instâncias EC2;
* distribuição das instâncias entre duas zonas de disponibilidade;
* ausência de Key Pair;
* exigência do IMDSv2;
* utilização de volumes raiz EBS `gp3` criptografados;
* instalação e configuração do Nginx;
* criação de conteúdo que identifica cada backend;
* criação de endpoint de health check;
* criação do Target Group;
* registro das duas instâncias no Target Group;
* criação do Application Load Balancer;
* criação do Listener HTTP;
* encaminhamento de tráfego para o Target Group;
* validação dos health checks;
* validação da distribuição de requisições;
* simulação controlada de falha;
* validação da continuidade da aplicação;
* recuperação do backend;
* validação do retorno ao estado saudável;
* cleanup controlado;
* validação do estado final;
* preservação da rede do Lab 08.

Não serão criados:

* Auto Scaling Group;
* NAT Gateway;
* VPC Endpoints;
* Elastic IP;
* banco de dados;
* domínio DNS;
* certificado TLS;
* Listener HTTPS;
* Key Pair;
* regra de entrada para SSH;
* acesso HTTP direto da internet aos backends.

---

## Fluxo de tráfego

O tráfego normal seguirá este caminho:

```
Cliente HTTP
     |
     v
Application Load Balancer
     |
     v
Listener HTTP :80
     |
     v
Target Group
     |
     ├── backend A saudável
     |
     └── backend B saudável
```

O balanceador distribuirá as requisições entre os dois targets registrados.

Cada backend apresentará uma identificação própria na resposta HTTP. Isso permitirá confirmar que as requisições estão sendo processadas por instâncias diferentes.

O health check consultará:

```
/health
```

Uma resposta HTTP `200` indicará que o backend está saudável e pode receber tráfego.

---

## Teste controlado de disponibilidade

O teste de disponibilidade interromperá o Nginx em somente uma das instâncias por meio do AWS Systems Manager.

O fluxo esperado será:

```
Dois targets saudáveis
          |
          v
interrupção do Nginx em um backend
          |
          v
health check identifica um target indisponível
          |
          v
ALB mantém o tráfego no target saudável
          |
          v
aplicação continua respondendo HTTP 200
          |
          v
Nginx é iniciado novamente
          |
          v
target recuperado retorna ao estado saudável
```

A falha controlada não encerrará a instância, não alterará a infraestrutura de rede e não removerá o target do Target Group.

O script deverá aguardar as transições de estado do Target Group antes de validar a continuidade ou a recuperação.

---

## Controles de segurança

### Separação entre ALB e backends

O Security Group do Application Load Balancer permitirá entrada HTTP pela porta TCP `80`.

O Security Group dos backends permitirá entrada HTTP somente quando a origem for o Security Group do ALB.

As instâncias não aceitarão acesso HTTP direto de qualquer endereço IPv4 público.

### Administração sem SSH

As instâncias não utilizarão Key Pair.

Nenhuma regra de entrada será criada para a porta TCP `22`.

A administração e a execução da falha controlada ocorrerão pelo AWS Systems Manager.

### Proteção das instâncias

As instâncias utilizarão:

* Amazon Linux 2023;
* IMDSv2 obrigatório;
* volumes raiz EBS criptografados;
* tipo de volume `gp3`;
* IAM Role dedicada;
* Instance Profile dedicado;
* Security Group específico;
* tags operacionais;
* ausência de credenciais permanentes no sistema operacional.

### Controle de escopo

Os scripts deverão localizar os recursos por nomes, tags e dependências conhecidas.

Antes de remover ou modificar recursos, os scripts deverão confirmar que eles pertencem ao Lab 12.

A VPC, as sub-redes, o Internet Gateway e a tabela de rotas do Lab 08 não poderão ser alterados pelo cleanup do Lab 12.

---

## Tags

Os recursos deverão receber, quando suportado, as seguintes tags:

|      Tag      |                 Valor                 |
| :-----------: | :-----------------------------------: |
|   `Project`   | `cloud-infrastructure-operations-lab` |
| `Environment` |                 `lab`                 |
|     `Lab`     |                  `12`                 |
|  `ManagedBy`  |               `aws-cli`               |
|    `Owner`    |               `itamarsb`              |
|     `Name`    |       Nome específico do recurso      |

As tags serão utilizadas para identificação operacional e como proteção adicional durante o cleanup.

---

## Critérios de sucesso

O Lab 12 será considerado concluído quando:

1. existir exatamente uma VPC correspondente ao Lab 08;
2. existirem duas sub-redes do Lab 08 em zonas de disponibilidade diferentes;
3. existirem exatamente duas instâncias ativas do Lab 12;
4. cada instância estiver em uma sub-rede e zona diferente;
5. as duas instâncias executarem Amazon Linux 2023;
6. nenhuma Key Pair estiver associada às instâncias;
7. o IMDSv2 estiver configurado como obrigatório;
8. os volumes raiz utilizarem `gp3` e criptografia;
9. as instâncias estiverem registradas no Systems Manager;
10. o Nginx estiver ativo nos dois backends;
11. cada backend apresentar sua própria identificação;
12. existir exatamente um Security Group do ALB;
13. existir exatamente um Security Group dos backends;
14. o Security Group dos backends permitir HTTP somente a partir do Security Group do ALB;
15. nenhuma regra de entrada permitir SSH;
16. existir exatamente um Application Load Balancer do Lab 12;
17. o ALB estiver associado às duas sub-redes;
18. existir exatamente um Target Group do Lab 12;
19. as duas instâncias estiverem registradas no Target Group;
20. os dois targets estiverem inicialmente no estado `healthy`;
21. existir um Listener HTTP na porta TCP `80`;
22. o endereço do ALB responder com HTTP `200`;
23. as respostas HTTP identificarem os dois backends;
24. a falha controlada tornar somente um target indisponível;
25. a aplicação continuar respondendo pelo backend saudável;
26. o backend interrompido for recuperado;
27. os dois targets retornarem ao estado `healthy`;
28. a validação independente terminar com código de saída `0`;
29. o cleanup remover todos os recursos específicos do Lab 12;
30. a rede compartilhada do Lab 08 permanecer disponível.

---

## Pré-requisitos

* Windows PowerShell 5.1 ou PowerShell 7;
* AWS CLI v2;
* Session Manager Plugin;
* perfil `cloud-operations-lab`;
* autenticação pelo AWS IAM Identity Center;
* Lab 08 implantado em `us-east-1`;
* duas sub-redes públicas do Lab 08 disponíveis;
* permissões necessárias para EC2, Elastic Load Balancing, IAM e Systems Manager.

Autenticação prevista:

```
aws sso login --profile cloud-operations-lab
```

---

## Fluxo operacional

### 1. Implantação

A implantação será executada por:

```
$DeployScript = ".\labs\12-aws-application-availability\scripts\deploy-aws-application-availability.ps1"

& $DeployScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -AvailabilityZoneA "us-east-1a" `
    -AvailabilityZoneB "us-east-1b" `
    -InstanceType "t3.micro"
```

O script deverá:

* validar a sessão autenticada;
* localizar a VPC do Lab 08;
* localizar as duas sub-redes públicas;
* confirmar a distribuição entre duas zonas;
* criar os recursos IAM;
* criar os dois Security Groups;
* criar as duas instâncias EC2;
* instalar e configurar o Nginx;
* criar o endpoint de health check;
* criar o Target Group;
* registrar as instâncias;
* criar o Application Load Balancer;
* criar o Listener HTTP;
* aguardar os dois targets ficarem saudáveis;
* validar a resposta HTTP pelo endereço do ALB.

### 2. Validação independente

A validação será executada por:

```
$TestScript = ".\labs\12-aws-application-availability\scripts\test-aws-application-availability.ps1"

& $TestScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1"
```

O validador deverá verificar:

* identidade da sessão;
* VPC e sub-redes utilizadas;
* distribuição das instâncias entre as zonas;
* configurações das instâncias EC2;
* IAM Role e Instance Profile;
* registro no Systems Manager;
* regras dos Security Groups;
* configuração do Application Load Balancer;
* associação das sub-redes;
* Target Group e targets registrados;
* configuração do health check;
* estado dos targets;
* Listener e ação de encaminhamento;
* resposta HTTP pelo endereço do ALB;
* identificação dos dois backends.

O script não deverá criar, alterar ou remover recursos de infraestrutura.

### 3. Falha controlada e recuperação

A falha controlada será executada por:

```
$FailureScript = ".\labs\12-aws-application-availability\scripts\invoke-aws-availability-failure.ps1"

& $FailureScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmFailureTest
```

O script deverá:

* confirmar a existência de dois targets saudáveis;
* selecionar somente um backend;
* confirmar que o recurso pertence ao Lab 12;
* interromper o Nginx pelo Systems Manager;
* aguardar o target ficar indisponível;
* confirmar que o segundo target permanece saudável;
* realizar requisições ao endereço do ALB;
* confirmar que a aplicação continua respondendo com HTTP `200`;
* iniciar novamente o Nginx;
* aguardar a recuperação do target;
* confirmar que os dois targets retornaram ao estado `healthy`.

A execução exigirá autorização explícita por meio do parâmetro `-ConfirmFailureTest`.

### 4. Cleanup

O cleanup será executado por:

```
$RemoveScript = ".\labs\12-aws-application-availability\scripts\remove-aws-application-availability.ps1"

& $RemoveScript `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ConfirmRemoval
```

A remoção deverá respeitar as dependências entre os recursos.

O cleanup removerá:

* Listener;
* Application Load Balancer;
* registros das instâncias no Target Group;
* Target Group;
* instâncias EC2;
* Security Groups;
* associação da IAM Role ao Instance Profile;
* Instance Profile;
* política gerenciada associada;
* IAM Role.

A VPC, as sub-redes, o Internet Gateway e a tabela de rotas do Lab 08 não serão modificados.

---

## Estado atual

* [x] arquitetura definida;
* [x] escopo definido;
* [x] estrutura de diretórios criada;
* [x] nomes dos recursos definidos;
* [x] critérios de sucesso definidos;
* [ ] política de confiança IAM implementada;
* [ ] script de implantação implementado;
* [ ] script de validação independente implementado;
* [ ] script de falha controlada implementado;
* [ ] script de cleanup implementado;
* [ ] validação sintática concluída;
* [ ] implantação executada;
* [ ] infraestrutura validada;
* [ ] distribuição de tráfego confirmada;
* [ ] falha controlada executada;
* [ ] continuidade da aplicação confirmada;
* [ ] backend recuperado;
* [ ] cleanup executado;
* [ ] estado final validado.

---

## Considerações de custo

O Application Load Balancer, as instâncias EC2, os endereços IPv4 públicos, os volumes EBS e a transferência de dados podem gerar cobrança durante a execução.

O laboratório utilizará:

* duas instâncias `t3.micro`;
* dois volumes raiz EBS;
* dois endereços IPv4 públicos;
* um Application Load Balancer;
* um Target Group;
* pequeno volume de tráfego HTTP;
* nenhum NAT Gateway;
* nenhum Elastic IP;
* nenhum domínio DNS.

Os recursos específicos do Lab 12 deverão permanecer ativos somente durante a implantação, as validações, o registro das evidências e o teste de disponibilidade.

Após a conclusão do fluxo, o cleanup deverá ser executado no mesmo período de trabalho.

---

## Resultado esperado

O laboratório deverá demonstrar:

* implantação de uma aplicação web em duas zonas de disponibilidade;
* utilização de um Application Load Balancer;
* distribuição de tráfego entre dois backends;
* configuração de Target Group e health checks;
* isolamento de rede entre o balanceador e as instâncias;
* administração sem SSH;
* detecção automática de backend indisponível;
* continuidade da aplicação durante uma falha parcial;
* recuperação controlada do serviço;
* retorno dos dois targets ao estado saudável;
* validação independente da infraestrutura;
* cleanup dos recursos específicos;
* preservação da infraestrutura compartilhada do Lab 08.

