# Cloud Infrastructure Operations Lab

Laboratório progressivo de infraestrutura e operações em nuvem utilizando AWS, Linux, Terraform, Docker, CloudWatch e Zabbix.

O projeto reúne atividades de preparação de ambiente, provisionamento, administração de sistemas, monitoramento, automação e troubleshooting.

---

## Escopo

A trilha está organizada em torno de um ambiente de aplicação que evolui ao longo dos laboratórios.

As atividades incluem:

- acesso seguro à AWS;
- administração de sistemas Linux;
- redes e recursos AWS;
- infraestrutura como código;
- operação de serviços;
- métricas, logs e alertas;
- containers;
- investigação e recuperação de falhas;
- segurança, custos e confiabilidade.

---

## Tecnologias

| Categoria | Tecnologias |
|:---:|:---:|
| Cloud | AWS |
| Sistemas | Linux, WSL |
| Infraestrutura como código | Terraform |
| Containers | Docker |
| Monitoramento | Amazon CloudWatch, Zabbix |
| Automação | Bash, PowerShell |
| Versionamento | Git, GitHub |
| Documentação | Markdown, Mermaid |

---

## Progresso

### Concluído

| Laboratório | Conteúdo |
|---|---|
| [Lab 00 — Preparação da estação de trabalho](labs/00-workstation-preparation/) | Git, VS Code, PowerShell e organização local |
| [Lab 01 — Configuração segura da conta AWS](labs/01-secure-aws-account-configuration/) | Proteção da conta e acesso administrativo |
| [Lab 02 — AWS CLI e autenticação por SSO](labs/02-aws-cli-installation-and-configuration/) | Perfis, sessões temporárias e validação de identidade |
| [Lab 03 — Ferramentas de infraestrutura](labs/03-infrastructure-tools-installation/) | Terraform e Session Manager Plugin |
| [Lab 04 — Arquivos e diretórios Linux](labs/04-linux-file-management/) | Navegação, busca e operações com arquivos |
| [Lab 05 — Usuários, grupos e permissões](labs/05-linux-users-groups-permissions/) | Identidades, permissões e acesso compartilhado |

### Em desenvolvimento

| Laboratório | Conteúdo |
|---|---|
| [Lab 06 — Serviços e logs no Linux](labs/06-linux-processes-services-logs/) | `systemctl`, `journalctl`, diagnóstico e recuperação de serviço |

### Planejado

- infraestrutura AWS para uma aplicação web;
- operação e troubleshooting;
- automação com Terraform;
- métricas e logs com CloudWatch;
- monitoramento com Zabbix;
- aplicações com Docker;
- segurança e controle de custos;
- projeto integrado.

O planejamento completo está disponível em [`docs/roadmap.md`](docs/roadmap.md).

---

## Estrutura

| Diretório | Finalidade |
|:---:|---|
| `labs/` | Laboratórios e arquivos associados |
| `docs/` | Documentação geral e roadmap |
| `terraform/` | Infraestrutura como código |
| `scripts/` | Scripts compartilhados |
| `templates/` | Modelos utilizados pelo projeto |
| `incident-response/` | Registros de troubleshooting e recuperação |
| `resources/` | Materiais de apoio |

---

## Como utilizar

1. Consulte o [roadmap](docs/roadmap.md).
2. Acesse o diretório do laboratório desejado.
3. Leia os pré-requisitos e o escopo antes da execução.
4. Valide o resultado apresentado pelo laboratório.
5. Remova os recursos temporários quando houver procedimento de cleanup.

Recursos AWS que possam gerar cobrança devem ser utilizados somente durante a execução dos respectivos laboratórios.

---

## Características do projeto

- autenticação temporária por AWS IAM Identity Center;
- preferência por acesso administrativo pelo AWS Systems Manager;
- identificação explícita de recursos e ambientes;
- validações antes e depois das alterações;
- scripts restritos ao escopo de cada laboratório;
- infraestrutura reproduzível;
- controle de custos;
- cleanup documentado.

---

## Roadmap

A evolução do projeto está dividida em:

1. preparação e acesso;
2. operações Linux;
3. infraestrutura AWS;
4. operação e troubleshooting;
5. Terraform;
6. monitoramento e logs;
7. Docker;
8. segurança, custos e confiabilidade;
9. projeto final.

Consulte [`docs/roadmap.md`](docs/roadmap.md) para acompanhar o desenvolvimento.

---

## Licença

Este projeto está distribuído sob a [licença MIT](LICENSE).

---

## 📈 Repository Metrics

<p align="center">
    
<a href="https://info.flagcounter.com/g0hL"><img src="https://s01.flagcounter.com/count/g0hL/bg_FFFFFF/txt_000000/border_CCCCCC/columns_8/maxflags_100/viewers_0/labels_1/pageviews_1/flags_0/percent_0/" alt="Flag Counter" border="0"></a>

</p>
