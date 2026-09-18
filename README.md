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

O planejamento completo está disponível em [`docs/roadmap.md`](docs/roadmap.md).

---

## Resultado mais recente

O **Lab 12** implementou uma aplicação web disponível em duas zonas da AWS, utilizando duas instâncias Amazon EC2 com Nginx, um Target Group e um Application Load Balancer.

A solução incluiu:

- backends distribuídos entre `us-east-1a` e `us-east-1b`;
- administração pelo AWS Systems Manager, sem chave SSH;
- IMDSv2 obrigatório e volumes raiz EBS `gp3` criptografados;
- Security Group público somente no ALB;
- acesso HTTP aos backends restrito ao Security Group do ALB;
- health check HTTP no caminho `/health`;
- validação independente da infraestrutura e do tráfego;
- falha controlada e recuperação do serviço;
- cleanup protegido com preservação da rede do Lab 08.

O validador confirmou HTTP `200`, dois targets saudáveis e respostas provenientes dos backends A e B. Durante o teste de falha, o Nginx do backend A foi interrompido pelo Systems Manager e o Target Group o classificou como `unhealthy`. Enquanto isso, vinte requisições consecutivas foram atendidas pelo backend B sem indisponibilidade da aplicação.

Após a recuperação, os dois targets retornaram ao estado `healthy` e uma nova validação confirmou o funcionamento integral da arquitetura.

O cleanup removeu Listener, Application Load Balancer, Target Group, instâncias EC2, Security Groups, Instance Profile e IAM Role. A validação final confirmou que nenhum recurso específico do Lab 12 permaneceu ativo e que a VPC e as duas sub-redes do Lab 08 foram preservadas.

Consulte o [Lab 12 — Disponibilidade da aplicação](labs/12-aws-application-availability/) para acessar a documentação completa, os scripts e as evidências.




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

A próxima implementação é o **Lab 13 — Aplicação indisponível**.

O laboratório iniciará o módulo de operação e troubleshooting, abordando diagnóstico de serviço, processo, porta, configuração e logs.

---

## Licença

Este projeto está distribuído sob a [licença MIT](LICENSE).

---

## 📈 Repository Metrics

<p align="center">

<a href="https://info.flagcounter.com/g0hL"><img src="https://s01.flagcounter.com/count/g0hL/bg_FFFFFF/txt_000000/border_CCCCCC/columns_8/maxflags_100/viewers_0/labels_1/pageviews_1/flags_0/percent_0/" alt="Flag Counter" border="0"></a>

</p>
