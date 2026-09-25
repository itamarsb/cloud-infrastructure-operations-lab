# Cloud Infrastructure Operations Lab

Laboratório progressivo de infraestrutura e operações em nuvem, com atividades práticas em **AWS, Linux, Terraform, Docker, CloudWatch, Zabbix, Bash e PowerShell**.

O projeto documenta a construção e a operação de um ambiente de aplicação ao longo de uma trilha evolutiva: preparação da estação de trabalho, acesso seguro à nuvem, administração Linux, infraestrutura AWS, automação, observabilidade, troubleshooting, segurança, custos e confiabilidade.

Cada laboratório apresenta contexto, procedimentos, validações, evidências e, quando aplicável, scripts reutilizáveis e etapas de cleanup.

> **English summary:** Hands-on cloud infrastructure and operations portfolio focused on AWS, Linux administration, automation, observability, troubleshooting, security and operational reliability. Each lab includes documented procedures, validation results and execution evidence.

---

## Objetivo

Demonstrar competências práticas relacionadas às atividades de **Cloud Operations, Infrastructure Operations, DevOps e SRE**, por meio de cenários progressivos e reproduzíveis.

O repositório prioriza:

- execução prática e evidências verificáveis;
- segurança de acesso e proteção de informações sensíveis;
- diagnóstico antes de alterações;
- automação com escopo controlado;
- infraestrutura reproduzível;
- monitoramento, logs e resposta a falhas;
- controle de custos e remoção de recursos temporários;
- documentação técnica clara e rastreável.

---

## Tecnologias

| Categoria | Tecnologias e práticas |
|:---:|:---:|
| Cloud | AWS |
| Sistemas | Linux, Windows 11 e WSL |
| Infraestrutura como código | Terraform |
| Containers | Docker e Docker Compose |
| Observabilidade | Amazon CloudWatch e Zabbix |
| Automação | Bash e PowerShell |
| Acesso e identidade | AWS IAM Identity Center e AWS Systems Manager |
| Versionamento | Git e GitHub |
| Documentação | Markdown e Mermaid |

---

## Progresso atual

| Status | Laboratório | Conteúdo principal |
|:---:|---|---|
| ✅ | [Lab 00 — Preparação da estação de trabalho](labs/00-workstation-preparation/) | Git, VS Code, PowerShell e organização local |
| ✅ | [Lab 01 — Configuração segura da conta AWS](labs/01-secure-aws-account-configuration/) | Proteção da conta e acesso administrativo |
| ✅ | [Lab 02 — AWS CLI e autenticação por SSO](labs/02-aws-cli-installation-and-configuration/) | Perfis, sessões temporárias e validação de identidade |
| ✅ | [Lab 03 — Ferramentas de infraestrutura](labs/03-infrastructure-tools-installation/) | Terraform e Session Manager Plugin |
| ✅ | [Lab 04 — Arquivos e diretórios Linux](labs/04-linux-file-management/) | Navegação, busca e operações com arquivos |
| ✅ | [Lab 05 — Usuários, grupos e permissões](labs/05-linux-users-groups-permissions/) | Identidades, permissões e acesso compartilhado |
| ✅ | [Lab 06 — Serviços e logs no Linux](labs/06-linux-processes-services-logs/) | `systemctl`, `journalctl`, diagnóstico e recuperação de serviço |
| ✅ | [Lab 07 — Baseline operacional da conta AWS](labs/07-aws-account-baseline/) | Inventário somente leitura, segurança, tags, observabilidade e custos |
| ✅ | [Lab 08 — Rede da aplicação na AWS](labs/08-aws-application-network/) | VPC, sub-redes, rotas, Internet Gateway, Security Group e cleanup |
| ✅ | [Lab 09 — EC2 administrada pelo Systems Manager](labs/09-aws-ec2-systems-manager/) | EC2, IAM Role, Session Manager, validação e cleanup |
| ✅ | [Lab 10 — Serviço web Nginx em Linux](labs/10-linux-web-service/) | Nginx, `systemd`, acesso HTTP restrito, Systems Manager, validação e cleanup |
| ✅ | [Lab 11 — Armazenamento e recuperação](labs/11-aws-storage-recovery/) | EBS, Amazon S3, integridade, cópia e restauração |
| ✅ | [Lab 12 — Disponibilidade da aplicação](labs/12-aws-application-availability/) | Application Load Balancer, health checks, distribuição de tráfego e recuperação |
| ✅ | [Lab 13 — Troubleshooting de aplicação indisponível](labs/13-aws-application-troubleshooting/) | Nginx, falha controlada, diagnóstico estruturado, recuperação e cleanup |
| ✅ | [Lab 14 — Utilização de disco](labs/14-aws-disk-utilization/) | Volume EBS dedicado, pressão controlada, diagnóstico, mitigação e cleanup |
| ✅ | [Lab 15 — Troubleshooting de conectividade](labs/15-aws-connectivity-troubleshooting/) | Falha controlada no Security Group, diagnóstico por camadas, recuperação e cleanup |

O planejamento completo está disponível em [`docs/roadmap.md`](docs/roadmap.md).

---

## Resultado mais recente

O **Lab 15 — Troubleshooting de conectividade na AWS** confirmou que uma aplicação Nginx pode permanecer saudável localmente enquanto uma regra de entrada ausente no Security Group impede o acesso HTTP externo. Após validar o estado `Healthy`, a regra TCP `80` restrita ao IPv4 do operador foi removida de forma controlada. A validação independente confirmou `Failed`, com Systems Manager e Nginx saudáveis. O diagnóstico somente leitura identificou a regra ausente; a recuperação restaurou apenas essa autorização e a validação voltou a `Healthy`. Por fim, o cleanup removeu os recursos exclusivos do Lab 15 e preservou a VPC e a sub-rede compartilhadas do Lab 08.

Consulte o [Lab 15](labs/15-aws-connectivity-troubleshooting/) para os comandos, resultados, scripts e evidências.

---

## Resultado anterior

O **Lab 14 — Utilização de disco e crescimento de logs** implementou um cenário completo de investigação e mitigação de utilização elevada de disco em uma instância Amazon EC2 administrada pelo AWS Systems Manager.

O laboratório incluiu:

- implantação de uma instância Amazon EC2 com Amazon Linux 2023;
- criação de um volume EBS `gp3` criptografado e dedicado aos logs;
- formatação do volume com `ext4`;
- montagem persistente por UUID em `/var/log/lab14`;
- administração pelo Systems Manager, sem Key Pair e sem regra de entrada para SSH;
- IMDSv2 obrigatório;
- geração controlada de arquivos de log;
- proteção por limite máximo de utilização;
- diagnóstico estruturado e somente leitura;
- análise de capacidade em bytes e consumo de inodes;
- identificação dos maiores diretórios e arquivos;
- inspeção de arquivos removidos ainda abertos;
- coleta de eventos recentes do sistema;
- mitigação por rotação, compressão e retenção;
- validação de integridade antes da remoção dos arquivos originais;
- validação independente após a mitigação;
- cleanup protegido e idempotente;
- preservação da rede compartilhada do Lab 08.

Durante o incidente controlado, a utilização do volume dedicado chegou a `85%`, ultrapassando o limite operacional de `80%` e permanecendo abaixo do limite máximo de segurança de `88%`.

O diagnóstico identificou:

- `24` arquivos de pressão;
- aproximadamente `1,50 GiB` de dados recuperáveis;
- arquivos de aproximadamente `64 MiB`;
- utilização de inodes de apenas `1%`;
- nenhum arquivo removido ainda aberto por processos;
- concentração do consumo no diretório controlado `/var/log/lab14/generated`.

A investigação confirmou que o incidente estava relacionado ao consumo da capacidade em bytes e não ao esgotamento de inodes.

A mitigação processou somente os arquivos controlados, realizou compressão temporária, validou a integridade do conteúdo e removeu os arquivos originais somente após a confirmação de sucesso.

Após a mitigação, a utilização foi reduzida de `85%` para `57%`. A validação independente confirmou o retorno ao estado `Healthy`.

O cleanup removeu:

- a instância EC2 do Lab 14;
- o volume EBS dedicado;
- o Security Group;
- o Instance Profile;
- a IAM Role e sua associação com a política do Systems Manager.

A validação pós-cleanup confirmou que nenhum recurso exclusivo do Lab 14 permaneceu ativo. A VPC e a sub-rede compartilhadas do Lab 08 foram preservadas.

Consulte o [Lab 14 — Utilização de disco e crescimento de logs](labs/14-aws-disk-utilization/) para acessar a documentação completa, os scripts e as evidências.

---

## Estrutura do repositório

| Diretório | Finalidade |
|:---:|---|
| `labs/` | Laboratórios, scripts e evidências de execução |
| `docs/` | Roadmap e documentação geral |
| `terraform/` | Infraestrutura como código |
| `scripts/` | Scripts compartilhados entre laboratórios |
| `templates/` | Modelos de laboratório, checklist, incidente e runbook |
| `incident-response/` | Registros de troubleshooting e recuperação |
| `resources/` | Comandos, referências e materiais de apoio |

---

## Como utilizar

1. Consulte o [`roadmap`](docs/roadmap.md) para conhecer a sequência da trilha.
2. Acesse o diretório do laboratório desejado.
3. Leia o objetivo, os pré-requisitos e as proteções antes da execução.
4. Execute o procedimento no ambiente indicado.
5. Confirme as validações e compare os resultados com as evidências documentadas.
6. Remova os recursos temporários quando houver procedimento de cleanup.

> Recursos AWS que possam gerar cobrança devem permanecer ativos somente durante a execução dos respectivos laboratórios.

---

## Princípios operacionais

- autenticação temporária por AWS IAM Identity Center;
- preferência por acesso administrativo pelo AWS Systems Manager;
- princípio do menor privilégio conforme a evolução da trilha;
- identificação explícita de perfil, Região, ambiente e recursos;
- validações antes e depois das alterações;
- diagnóstico antes da mitigação;
- scripts limitados ao escopo declarado;
- autorização explícita para operações destrutivas;
- proteção de credenciais e identificadores sensíveis;
- tratamento de respostas vazias e falhas esperadas;
- infraestrutura reproduzível e mudanças rastreáveis;
- preservação de recursos compartilhados;
- scripts de cleanup idempotentes;
- controle de custos e cleanup documentado.

---

## Práticas demonstradas

Os laboratórios concluídos até esta etapa demonstram:

- preparação e validação de uma estação de trabalho;
- autenticação temporária na AWS por SSO;
- administração de sistemas Linux;
- usuários, grupos e permissões;
- serviços e logs com `systemd` e `journalctl`;
- inventário operacional de uma conta AWS;
- redes VPC, sub-redes, rotas e Internet Gateway;
- instâncias EC2 administradas pelo Systems Manager;
- IAM Roles e Instance Profiles;
- Security Groups com escopo controlado;
- armazenamento com Amazon EBS e Amazon S3;
- validação de integridade e recuperação de dados;
- disponibilidade com Application Load Balancer;
- health checks e distribuição de tráfego;
- introdução controlada de falhas;
- diagnóstico estruturado antes da recuperação;
- investigação de utilização elevada de disco;
- análise de capacidade e inodes;
- rotação, compressão e retenção de logs;
- automação com PowerShell e Bash;
- validação independente;
- cleanup seguro e preservação de infraestrutura compartilhada.

---

## Evolução planejada

A trilha está dividida em nove etapas:

1. preparação e acesso;
2. operações Linux;
3. infraestrutura AWS;
4. operação e troubleshooting;
5. Terraform;
6. monitoramento e logs;
7. Docker;
8. segurança, custos e confiabilidade;
9. projeto integrado de uma aplicação web.

Os laboratórios de preparação, operações Linux e infraestrutura AWS foram concluídos.

O módulo de operação e troubleshooting está em desenvolvimento. Os Labs 13, 14 e 15 concluíram, respectivamente, os cenários de aplicação indisponível, utilização elevada de disco e falha de conectividade.

A próxima etapa será o **Lab 16 — Systems Manager indisponível**, com foco em:

- IAM Role e Instance Profile;
- agente SSM, registro e estado `Online`;
- conectividade necessária ao serviço;
- diagnóstico antes da recuperação;
- validação independente e cleanup.

---

## Licença

Este projeto está distribuído sob a [licença MIT](LICENSE).

---

## 📈 Repository Metrics

<p align="center">

<a href="https://info.flagcounter.com/g0hL"><img src="https://s01.flagcounter.com/count/g0hL/bg_FFFFFF/txt_000000/border_CCCCCC/columns_8/maxflags_100/viewers_0/labels_1/pageviews_1/flags_0/percent_0/" alt="Flag Counter" border="0"></a>

</p>
