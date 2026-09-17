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

O planejamento completo está disponível em [`docs/roadmap.md`](docs/roadmap.md).

---

## Resultado mais recente

O **Lab 11** implementou um fluxo completo de armazenamento, proteção e recuperação de dados utilizando Amazon EBS e Amazon S3.

A solução utilizou:

* instância EC2 `t3.micro` com Amazon Linux 2023;
* rede compartilhada criada no Lab 08;
* administração pelo AWS Systems Manager;
* IAM Role e Instance Profile dedicados;
* ausência de Key Pair e acesso SSH;
* IMDSv2 obrigatório;
* Security Group sem regras de entrada;
* volume EBS adicional `gp3`, criptografado e com 1 GiB;
* sistema de arquivos montado em `/mnt/lab11-data`;
* bucket Amazon S3 privado e versionado;
* bloqueio completo de acesso público ao bucket;
* criptografia padrão SSE-S3;
* política IAM limitada ao bucket do laboratório;
* verificação de integridade com hashes SHA-256.

Quatro scripts em PowerShell foram implementados:

|               Script              | Operação                                                                                         |
| :-------------------------------: | ------------------------------------------------------------------------------------------------ |
| `deploy-aws-storage-recovery.ps1` | Criação dos recursos AWS, preparação do volume EBS e armazenamento da cópia no S3                |
|  `test-aws-storage-recovery.ps1`  | Validação independente da infraestrutura, das configurações de segurança e dos dados armazenados |
|   `restore-aws-storage-data.ps1`  | Recuperação do objeto armazenado no S3 e comparação de integridade                               |
| `remove-aws-storage-recovery.ps1` | Remoção protegida e ordenada dos recursos específicos do laboratório                             |

A implantação criou um arquivo de teste no volume EBS, calculou seu hash SHA-256 e armazenou uma cópia no Amazon S3.

O validador independente confirmou:

* existência de uma única instância ativa do Lab 11;
* utilização do Amazon Linux 2023;
* ausência de chave SSH;
* exigência do IMDSv2;
* ausência de regras de entrada no Security Group;
* registro online da instância no Systems Manager;
* existência e associação do volume EBS adicional;
* criptografia e utilização do tipo `gp3`;
* montagem do sistema de arquivos;
* existência do arquivo original;
* bloqueio de acesso público ao bucket;
* criptografia e versionamento do S3;
* existência do objeto de backup;
* aplicação das tags operacionais obrigatórias.

O processo de recuperação baixou o objeto do Amazon S3 para um diretório separado no volume EBS. A comparação entre os hashes SHA-256 do arquivo original e do arquivo restaurado confirmou a integridade dos dados.

Também foram realizados testes locais com respostas simuladas do Amazon S3 para validar:

* tratamento de respostas vazias;
* contagem de versões válidas;
* rejeição de chaves inesperadas;
* limitação do escopo antes de operações destrutivas.

Após as validações e o registro das evidências, o cleanup removeu:

* instância EC2;
* volume EBS adicional;
* versões e marcadores do objeto no S3;
* bucket do Lab 11;
* Security Group;
* política IAM específica;
* Instance Profile;
* IAM Role.

A validação pós-cleanup confirmou que nenhum recurso específico do Lab 11 permaneceu ativo. A VPC e as sub-redes compartilhadas do Lab 08 foram preservadas para os próximos laboratórios.

Consulte o [Lab 11 — Armazenamento e recuperação](labs/11-aws-storage-recovery/) para acessar a documentação completa, os scripts e as evidências.




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

A próxima implementação é o **Lab 12 — Disponibilidade da aplicação**.

O laboratório abordará health checks e distribuição de tráfego, ampliando a arquitetura construída nos laboratórios anteriores.

---

## Licença

Este projeto está distribuído sob a [licença MIT](LICENSE).

---

## 📈 Repository Metrics

<p align="center">

<a href="https://info.flagcounter.com/g0hL"><img src="https://s01.flagcounter.com/count/g0hL/bg_FFFFFF/txt_000000/border_CCCCCC/columns_8/maxflags_100/viewers_0/labels_1/pageviews_1/flags_0/percent_0/" alt="Flag Counter" border="0"></a>

</p>
