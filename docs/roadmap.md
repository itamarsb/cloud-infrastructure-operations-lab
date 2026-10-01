# Roadmap — Cloud Infrastructure Operations Lab

## Visão geral

O **Cloud Infrastructure Operations Lab** reúne atividades práticas relacionadas à administração e à operação de ambientes em nuvem.

A trilha integra AWS, Linux, Terraform, Docker, CloudWatch e Zabbix em cenários progressivos de provisionamento, monitoramento, manutenção, diagnóstico, recuperação e troubleshooting.

Os laboratórios priorizam:

- execução prática;
- automação reproduzível;
- diagnóstico antes de alterações;
- validação independente;
- evidências de execução;
- proteção de recursos compartilhados;
- controle de custos;
- cleanup seguro e idempotente.

## Status

- **Concluído:** execução, validações e evidências registradas; cleanup realizado quando aplicável.
- **Em desenvolvimento:** implementação ou execução em andamento.
- **Planejado:** etapa prevista, ainda não iniciada.

---

## Módulo 00 — Preparação e acesso

| Status | Laboratório | Conteúdo |
|---|---|---|
| Concluído | **Lab 00 — Preparação da estação de trabalho** | Git, VS Code, PowerShell e organização local |
| Concluído | **Lab 01 — Configuração segura da conta AWS** | Proteção da conta e acesso administrativo |
| Concluído | **Lab 02 — AWS CLI e autenticação por SSO** | Perfis, sessões temporárias e validação de identidade |
| Concluído | **Lab 03 — Ferramentas de infraestrutura** | Terraform e Session Manager Plugin |

---

## Módulo 01 — Operações Linux

| Status | Laboratório | Conteúdo |
|---|---|---|
| Concluído | **Lab 04 — Arquivos e diretórios** | Navegação, busca, cópia, movimentação e remoção |
| Concluído | **Lab 05 — Usuários, grupos e permissões** | Identidades, permissões e acesso compartilhado |
| Concluído | **Lab 06 — Serviços e logs** | `systemctl`, `journalctl`, diagnóstico e recuperação de serviço |

---

## Módulo 02 — Infraestrutura AWS

| Status | Laboratório | Conteúdo |
|---|---|---|
| Concluído | **Lab 07 — Baseline operacional da conta AWS** | Inventário somente leitura de identidade, rede, recursos, segurança, tags, observabilidade e custos |
| Concluído | **Lab 08 — Rede da aplicação** | VPC, sub-redes, rotas, Internet Gateway, Security Group, validação e cleanup |
| Concluído | **Lab 09 — Instância EC2 administrada pelo Systems Manager** | EC2, IAM Role, Session Manager, validação e cleanup |
| Concluído | **Lab 10 — Serviço web em Linux** | Nginx, `systemd`, acesso HTTP restrito, Systems Manager, validação e cleanup |
| Concluído | **Lab 11 — Armazenamento e recuperação** | EBS, S3, cópia, integridade e restauração |
| Concluído | **Lab 12 — Disponibilidade da aplicação** | Application Load Balancer, health checks, distribuição de tráfego, falha controlada e recuperação |

---

## Módulo 03 — Operação e troubleshooting

| Status | Laboratório | Conteúdo |
|---|---|---|
| Concluído | **Lab 13 — Aplicação indisponível** | Serviço, processo, porta, configuração, logs, recuperação e cleanup |
| Concluído | **Lab 14 — Utilização de disco** | Volume EBS dedicado, pressão controlada, capacidade, inodes, diagnóstico, mitigação e cleanup |
| Concluído | **Lab 15 — Falha de conectividade** | Security Group, rota, Network ACL, serviço local, diagnóstico por camadas, recuperação e cleanup |
| Concluído | **Lab 16 — Systems Manager indisponível** | IAM Role, falha de saída HTTPS, diagnóstico, recuperação e cleanup |
| Concluído | **Lab 17 — Atualização controlada** | Baseline v1, falha de configuração, diagnóstico, rollback, atualização v2, confirmação e cleanup |
| Concluído | **Lab 18 — Backup e restauração de aplicação** | S3 versionado, SHA-256, perda controlada, diagnóstico, restauração por VersionId e cleanup |

### Resultados concluídos no módulo

O **Lab 13** reproduziu uma aplicação Nginx indisponível, separou diagnóstico e recuperação, identificou uma configuração inválida e restaurou o serviço antes do cleanup.

O **Lab 14** reproduziu utilização elevada em um volume EBS dedicado, identificou os arquivos responsáveis, analisou capacidade e inodes, aplicou rotação e compressão controladas e restaurou a utilização saudável.

No Lab 14:

- a utilização elevada chegou a `85%`;
- `24` arquivos de pressão foram identificados;
- aproximadamente `1,50 GiB` de espaço recuperável foi localizado;
- a utilização de inodes permaneceu em `1%`;
- nenhum arquivo removido ainda aberto foi encontrado;
- a mitigação reduziu a utilização para `57%`;
- todos os recursos exclusivos foram removidos;
- a rede compartilhada do Lab 08 foi preservada.

O **Lab 15** revogou de forma controlada a regra HTTP de um Security Group exclusivo. O Nginx e o endpoint local permaneceram saudáveis, enquanto o acesso externo falhou. O diagnóstico identificou a regra ausente, a recuperação restaurou somente TCP `80` para o CIDR autorizado, e a validação independente confirmou novamente `Healthy`. O cleanup removeu os recursos exclusivos e preservou a VPC e a sub-rede do Lab 08.

O **Lab 16** revogou a saída HTTPS de um Security Group exclusivo. A primeira tentativa não produziu `ConnectionLost` no prazo e restaurou a regra. Após ajustar o procedimento para reiniciar somente a instância do laboratório, a segunda tentativa confirmou SSM `ConnectionLost` com EC2 `running`. O diagnóstico verificou rede e IAM, a recuperação restaurou a saída pela API do EC2, e a validação voltou a `Healthy`. O cleanup removeu os recursos exclusivos e preservou a rede compartilhada do Lab 08.

O **Lab 17** registrou o baseline v1 e o backup de quatro arquivos da aplicação Nginx. Uma candidata com diretiva inválida foi rejeitada por `nginx -t`, enquanto o serviço continuou respondendo em v1. O diagnóstico identificou o arquivo de configuração divergente. O rollback restaurou os hashes do baseline; depois, a candidata v2 foi validada local e externamente e confirmada. O cleanup removeu somente a instância, o Security Group, o Instance Profile e a IAM Role exclusivos, preservando a rede compartilhada do Lab 08. As etapas e evidências estão no [README do Lab 17](../labs/17-aws-controlled-update/README.md).

O **Lab 18** criou um backup de quatro arquivos da aplicação Nginx em um bucket S3 privado e versionado. A perda controlada removeu `index.html` e `version`, produzindo HTTP 404 em `/` e `/version`, enquanto `/health` permaneceu saudável. O diagnóstico identificou os arquivos ausentes. A restauração recuperou a versão S3 registrada, verificou SHA-256 e manifesto e restabeleceu os quatro hashes do baseline, com HTTP 200 local e externo.

O intervalo entre a perda e a recuperação observada localmente foi de **5 min 56,294 s**, incluindo diagnóstico e espera do operador. Essa medição não estabelece um objetivo de RTO para produção. O cleanup removeu EC2, volume root, Security Group, bucket, Instance Profile e IAM Role exclusivos, preservando a rede compartilhada do Lab 08. Os resultados e os limites das medições estão no [README do Lab 18](../labs/18-aws-application-backup-restore/README.md).

O módulo de operação e troubleshooting está concluído.

---

## Módulo 04 — Terraform

| Status | Laboratório | Conteúdo |
|---|---|---|
| Planejado | **Lab 19 — Fluxo essencial do Terraform** | `init`, `fmt`, `validate`, `plan`, `apply` e `destroy` |
| Planejado | **Lab 20 — Infraestrutura AWS como código** | Rede, IAM, segurança e EC2 |
| Planejado | **Lab 21 — Estado remoto** | Armazenamento, bloqueio e proteção do estado |
| Planejado | **Lab 22 — Variáveis, outputs e módulos** | Organização, parametrização e reutilização |
| Planejado | **Lab 23 — Mudanças e drift** | Comparação entre código, estado e ambiente |
| Planejado | **Lab 24 — Validação automatizada** | Formatação, validação e verificação do código em pipeline |

---

## Módulo 05 — Monitoramento e logs

| Status | Laboratório | Conteúdo |
|---|---|---|
| Planejado | **Lab 25 — Métricas no CloudWatch** | Métricas, consultas e dashboard |
| Planejado | **Lab 26 — CloudWatch Agent** | Memória, disco e coleta de logs |
| Planejado | **Lab 27 — Alarmes e notificações** | Thresholds, alarmes e Amazon SNS |
| Planejado | **Lab 28 — CloudWatch Logs Insights** | Consultas e investigação de eventos |
| Planejado | **Lab 29 — Monitoramento com Zabbix** | Agente, itens, triggers e disponibilidade |
| Planejado | **Lab 30 — Investigação de alertas** | Correlação entre métricas, logs e estado do sistema |

---

## Módulo 06 — Docker

| Status | Laboratório | Conteúdo |
|---|---|---|
| Planejado | **Lab 31 — Containerização da aplicação** | Imagem, container e publicação |
| Planejado | **Lab 32 — Configuração e persistência** | Variáveis, volumes e health checks |
| Planejado | **Lab 33 — Docker Compose** | Administração de serviços relacionados |
| Planejado | **Lab 34 — Troubleshooting de containers** | Logs, estado, recursos, rede e recuperação |

---

## Módulo 07 — Segurança, custos e confiabilidade

| Status | Laboratório | Conteúdo |
|---|---|---|
| Planejado | **Lab 35 — Revisão de segurança** | IAM, credenciais, portas e acesso administrativo |
| Planejado | **Lab 36 — Custos e recursos ociosos** | Tags, dimensionamento e oportunidades de redução |
| Planejado | **Lab 37 — Melhoria de confiabilidade** | Análise de falhas e implementação de melhorias |

---

## Projeto final — Ambiente operacional de uma aplicação web

O projeto final reunirá os principais componentes desenvolvidos durante a trilha:

- infraestrutura AWS provisionada com Terraform;
- aplicação web executada em Linux ou Docker;
- acesso administrativo pelo Systems Manager;
- armazenamento e recuperação;
- métricas e logs no CloudWatch;
- alarmes e notificações;
- monitoramento com Zabbix;
- troubleshooting de falhas controladas;
- validação independente;
- preservação de recursos compartilhados;
- cleanup do ambiente.

---

## Progresso atual

| Módulo | Situação |
|:---:|:---:|
| Preparação e acesso | Concluído |
| Operações Linux | Concluído |
| Infraestrutura AWS | Concluído |
| Operação e troubleshooting | Concluído |
| Terraform | Planejado |
| Monitoramento e logs | Planejado |
| Docker | Planejado |
| Segurança, custos e confiabilidade | Planejado |
| Projeto final | Planejado |

### Resumo numérico

| Indicador | Quantidade |
|:---:|:---:|
| Laboratórios concluídos | `19` |
| Laboratórios em desenvolvimento | `0` |
| Laboratórios planejados | `19` |
| Último laboratório concluído | `Lab 18` |
| Próximo laboratório | `Lab 19` |

O total considera os Labs 00 a 37. O projeto final é acompanhado separadamente.

---

## Próxima etapa

**Lab 19 — Fluxo essencial do Terraform**

O próximo laboratório inicia o módulo de infraestrutura como código. O objetivo é executar e compreender o fluxo `init`, `fmt`, `validate`, `plan`, `apply` e `destroy` em um exercício com escopo definido.

O procedimento deverá incluir:

- conferência do ambiente e dos pré-requisitos;
- inicialização e validação da configuração;
- análise do plano antes de aplicar mudanças;
- verificação do resultado e dos outputs;
- compreensão do papel do estado local;
- proteção do estado e dos arquivos gerados;
- remoção somente dos recursos do exercício;
- registro das evidências.

A infraestrutura compartilhada e os recursos de outros projetos permanecerão fora do escopo de remoção.
