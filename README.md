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
| 🔄 | **Lab 10 — Serviço web em Linux** | Nginx, systemd e validação HTTP |

O planejamento completo está disponível em [`docs/roadmap.md`](docs/roadmap.md).

---

## Resultado mais recente

O **Lab 09** implementou o ciclo operacional completo de uma instância Amazon EC2 administrada pelo AWS Systems Manager.

A solução utilizou:

- Amazon Linux 2023;
- instância `t3.micro`;
- rede criada no Lab 08;
- IAM Role dedicada;
- Instance Profile associado à EC2;
- política gerenciada `AmazonSSMManagedInstanceCore`;
- Security Group sem regras de entrada;
- ausência de Key Pair;
- IMDSv2 obrigatório;
- volume EBS `gp3` criptografado;
- administração remota pelo Session Manager.

Três scripts em PowerShell foram implementados:

| Script | Operação |
|:---:|---|
| `deploy-aws-managed-instance.ps1` | Implantação controlada da IAM Role, do Security Group e da EC2 |
| `test-aws-managed-instance.ps1` | Validação independente e somente leitura |
| `remove-aws-managed-instance.ps1` | Remoção protegida e ordenada dos recursos |

A implantação foi concluída com código de saída `0`, e a instância passou nas verificações de integridade da EC2 antes de ficar online no Systems Manager.

O validador confirmou:

- instância em execução;
- ausência de chave SSH;
- exigência do IMDSv2;
- Instance Profile correto;
- somente um Security Group associado;
- ausência de regras de entrada;
- volume raiz criptografado e do tipo `gp3`;
- política `AmazonSSMManagedInstanceCore` associada;
- registro online no Systems Manager.

Uma sessão administrativa foi realizada como `ssm-user`, sem abertura da porta TCP `22` e sem exposição de um serviço administrativo à Internet.

O cleanup removeu a instância, o Security Group e os componentes IAM do Lab 09. A verificação final confirmou que nenhum recurso ativo do laboratório permaneceu na conta e que a VPC e a sub-rede do Lab 08 foram preservadas.

Consulte o [Lab 09 — Instância EC2 administrada pelo Systems Manager](labs/09-aws-ec2-systems-manager/) para acessar a documentação, os scripts e as evidências.

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
- scripts limitados ao escopo declarado;
- proteção de credenciais e identificadores sensíveis;
- tratamento de respostas vazias e falhas esperadas;
- infraestrutura reproduzível e mudanças rastreáveis;
- controle de custos e cleanup documentado.

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

A próxima implementação prevista é o **Lab 10 — Serviço web em Linux**, que utilizará uma instância Amazon Linux administrada pelo Systems Manager para implantar e operar um serviço Nginx com `systemd` e validação HTTP.

---

## Licença

Este projeto está distribuído sob a [licença MIT](LICENSE).

---

## 📈 Repository Metrics

<p align="center">

<a href="https://info.flagcounter.com/g0hL"><img src="https://s01.flagcounter.com/count/g0hL/bg_FFFFFF/txt_000000/border_CCCCCC/columns_8/maxflags_100/viewers_0/labels_1/pageviews_1/flags_0/percent_0/" alt="Flag Counter" border="0"></a>

</p>
