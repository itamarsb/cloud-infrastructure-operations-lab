# Roadmap — Cloud Infrastructure Operations Lab

## Visão geral

O **Cloud Infrastructure Operations Lab** reúne atividades práticas relacionadas à administração e à operação de ambientes em nuvem.

A trilha integra AWS, Linux, Terraform, Docker, CloudWatch e Zabbix em cenários progressivos de provisionamento, monitoramento, manutenção e troubleshooting.

## Status

| Símbolo | Situação |
|:---:|:---:|
| ✅ | Concluído |
| 🔄 | Em desenvolvimento |
| ⬜ | Planejado |

---

## Módulo 00 — Preparação e acesso

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ✅ | **Lab 00 — Preparação da estação de trabalho** | Git, VS Code, PowerShell e organização local |
| ✅ | **Lab 01 — Configuração segura da conta AWS** | Proteção da conta e acesso administrativo |
| ✅ | **Lab 02 — AWS CLI e autenticação por SSO** | Perfis, sessões temporárias e validação de identidade |
| ✅ | **Lab 03 — Ferramentas de infraestrutura** | Terraform e Session Manager Plugin |

---

## Módulo 01 — Operações Linux

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ✅ | **Lab 04 — Arquivos e diretórios** | Navegação, busca, cópia, movimentação e remoção |
| ✅ | **Lab 05 — Usuários, grupos e permissões** | Identidades, permissões e acesso compartilhado |
| ✅ | **Lab 06 — Serviços e logs** | `systemctl`, `journalctl`, diagnóstico e recuperação de serviço |

---

## Módulo 02 — Infraestrutura AWS

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ⬜ | **Lab 07 — Baseline da conta AWS** | Identidade, Região, tags e controle de custos |
| ⬜ | **Lab 08 — Rede da aplicação** | VPC, subnet, rotas e security groups |
| ⬜ | **Lab 09 — Instância EC2 administrada pelo Systems Manager** | EC2, IAM Role e Session Manager |
| ⬜ | **Lab 10 — Serviço web em Linux** | Nginx, systemd e validação HTTP |
| ⬜ | **Lab 11 — Armazenamento e recuperação** | EBS, S3, cópia e restauração |
| ⬜ | **Lab 12 — Disponibilidade da aplicação** | Health checks e distribuição de tráfego |

---

## Módulo 03 — Operação e troubleshooting

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ⬜ | **Lab 13 — Aplicação indisponível** | Serviço, processo, porta, configuração e logs |
| ⬜ | **Lab 14 — Utilização de disco** | Capacidade, crescimento de logs e mitigação |
| ⬜ | **Lab 15 — Falha de conectividade** | DNS, rotas, security groups e portas |
| ⬜ | **Lab 16 — Systems Manager indisponível** | IAM Role, agente e conectividade |
| ⬜ | **Lab 17 — Atualização controlada** | Manutenção, validação e rollback |
| ⬜ | **Lab 18 — Backup e restauração** | Recuperação de dados e configurações |

---

## Módulo 04 — Terraform

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ⬜ | **Lab 19 — Fluxo essencial do Terraform** | `init`, `fmt`, `validate`, `plan`, `apply` e `destroy` |
| ⬜ | **Lab 20 — Infraestrutura AWS como código** | Rede, IAM, segurança e EC2 |
| ⬜ | **Lab 21 — Estado remoto** | Armazenamento e proteção do estado |
| ⬜ | **Lab 22 — Variáveis, outputs e módulos** | Organização e reutilização |
| ⬜ | **Lab 23 — Mudanças e drift** | Comparação entre código e ambiente |
| ⬜ | **Lab 24 — Validação automatizada** | Verificação do código em pipeline |

---

## Módulo 05 — Monitoramento e logs

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ⬜ | **Lab 25 — Métricas no CloudWatch** | Métricas, consultas e dashboard |
| ⬜ | **Lab 26 — CloudWatch Agent** | Memória, disco e coleta de logs |
| ⬜ | **Lab 27 — Alarmes e notificações** | Thresholds, alarmes e Amazon SNS |
| ⬜ | **Lab 28 — CloudWatch Logs Insights** | Consultas e investigação de eventos |
| ⬜ | **Lab 29 — Monitoramento com Zabbix** | Agente, itens, triggers e disponibilidade |
| ⬜ | **Lab 30 — Investigação de alertas** | Correlação entre métricas, logs e estado do sistema |

---

## Módulo 06 — Docker

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ⬜ | **Lab 31 — Containerização da aplicação** | Imagem, container e publicação |
| ⬜ | **Lab 32 — Configuração e persistência** | Variáveis, volumes e health checks |
| ⬜ | **Lab 33 — Docker Compose** | Administração de serviços relacionados |
| ⬜ | **Lab 34 — Troubleshooting de containers** | Logs, estado, recursos, rede e recuperação |

---

## Módulo 07 — Segurança, custos e confiabilidade

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ⬜ | **Lab 35 — Revisão de segurança** | IAM, credenciais, portas e acesso administrativo |
| ⬜ | **Lab 36 — Custos e recursos ociosos** | Tags, dimensionamento e oportunidades de redução |
| ⬜ | **Lab 37 — Melhoria de confiabilidade** | Análise de falhas e implementação de melhorias |

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
- validação e cleanup do ambiente.

---

## Progresso atual

| Módulo | Situação |
|:---:|:---:|
| Preparação e acesso | Concluído |
| Operações Linux | Concluído |
| Infraestrutura AWS | Planejado |
| Operação e troubleshooting | Planejado |
| Terraform | Planejado |
| Monitoramento e logs | Planejado |
| Docker | Planejado |
| Segurança, custos e confiabilidade | Planejado |
| Projeto final | Planejado |

## Próxima etapa

**Lab 07 — Baseline da conta AWS**
