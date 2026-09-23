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
| ✅ | **Lab 07 — Baseline operacional da conta AWS** | Inventário somente leitura de identidade, rede, recursos, segurança, tags, observabilidade e custos |
| ✅ | **Lab 08 — Rede da aplicação** | VPC, sub-redes, rotas, Internet Gateway, Security Group, validação e cleanup |
| ✅ | **Lab 09 — Instância EC2 administrada pelo Systems Manager** | EC2, IAM Role, Session Manager, validação e cleanup |
| ✅ | **Lab 10 — Serviço web em Linux** | Nginx, `systemd`, acesso HTTP restrito, Systems Manager, validação e cleanup |
| ✅ | **Lab 11 — Armazenamento e recuperação** | EBS, S3, cópia, integridade e restauração |
| ✅ | **Lab 12 — Disponibilidade da aplicação** | Application Load Balancer, health checks, distribuição de tráfego, falha controlada e recuperação |

---

## Módulo 03 — Operação e troubleshooting

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ✅ | **Lab 13 — Aplicação indisponível** | Serviço, processo, porta, configuração, logs, recuperação e cleanup |
| ✅ | **Lab 14 — Utilização de disco** | Volume EBS dedicado, pressão controlada, capacidade, inodes, diagnóstico, mitigação e cleanup |
| ⬜ | **Lab 15 — Falha de conectividade** | DNS, rotas, Security Groups, portas, diagnóstico por camadas e recuperação |
| ⬜ | **Lab 16 — Systems Manager indisponível** | IAM Role, agente, registro, conectividade e recuperação |
| ⬜ | **Lab 17 — Atualização controlada** | Manutenção, validação, rollback e confirmação do serviço |
| ⬜ | **Lab 18 — Backup e restauração** | Recuperação de dados, configurações e validação de integridade |

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

---

## Módulo 04 — Terraform

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| ⬜ | **Lab 19 — Fluxo essencial do Terraform** | `init`, `fmt`, `validate`, `plan`, `apply` e `destroy` |
| ⬜ | **Lab 20 — Infraestrutura AWS como código** | Rede, IAM, segurança e EC2 |
| ⬜ | **Lab 21 — Estado remoto** | Armazenamento, bloqueio e proteção do estado |
| ⬜ | **Lab 22 — Variáveis, outputs e módulos** | Organização, parametrização e reutilização |
| ⬜ | **Lab 23 — Mudanças e drift** | Comparação entre código, estado e ambiente |
| ⬜ | **Lab 24 — Validação automatizada** | Formatação, validação e verificação do código em pipeline |

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
| Operação e troubleshooting | Em desenvolvimento |
| Terraform | Planejado |
| Monitoramento e logs | Planejado |
| Docker | Planejado |
| Segurança, custos e confiabilidade | Planejado |
| Projeto final | Planejado |

### Resumo numérico

| Indicador | Quantidade |
|:---:|:---:|
| Laboratórios concluídos | `15` |
| Laboratórios em desenvolvimento | `0` |
| Laboratórios planejados | `23` |
| Último laboratório concluído | `Lab 14` |
| Próximo laboratório | `Lab 15` |

---

## Próxima etapa

**Lab 15 — Falha de conectividade**

O próximo laboratório deverá implementar um cenário controlado de falha de conectividade e uma investigação operacional por camadas.

O diagnóstico deverá considerar:

1. resolução DNS;
2. endereço de destino;
3. estado da instância ou serviço;
4. processo esperado;
5. porta em escuta;
6. Security Group;
7. Network ACL;
8. tabela de rotas;
9. associação da sub-rede;
10. conectividade observada pelo cliente.

O laboratório deverá manter a separação entre:

- implantação;
- validação saudável;
- introdução controlada da falha;
- diagnóstico somente leitura;
- recuperação autorizada;
- validação independente;
- cleanup.

A recuperação somente deverá ocorrer depois que a causa da falha tiver sido identificada e registrada.

A infraestrutura compartilhada dos laboratórios anteriores deverá ser preservada.
