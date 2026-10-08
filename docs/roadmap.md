# Roadmap — Cloud Infrastructure Operations Lab

## Visão geral

O **Cloud Infrastructure Operations Lab** reúne atividades práticas relacionadas à administração e à operação de ambientes em nuvem.

A trilha integra AWS, Linux, Terraform, GitHub Actions, Docker, CloudWatch e Zabbix em cenários progressivos de provisionamento, monitoramento, manutenção, diagnóstico, recuperação e troubleshooting.

Os laboratórios priorizam:

- execução prática;
- automação reproduzível;
- diagnóstico antes de alterações;
- validação independente;
- verificação automatizada do código;
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

O **Lab 13** reproduziu uma aplicação Nginx indisponível, identificou uma configuração inválida e restaurou o serviço antes do cleanup.

O **Lab 14** reproduziu utilização elevada em um volume EBS dedicado. A utilização chegou a `85%`, com `24` arquivos de pressão e aproximadamente `1,50 GiB` de dados recuperáveis. A utilização de inodes permaneceu em `1%`, e nenhum arquivo removido ainda aberto foi encontrado. A mitigação por compressão e retenção reduziu a utilização para `57%`.

O **Lab 15** revogou a regra HTTP de um Security Group exclusivo. O Nginx permaneceu saudável localmente, enquanto o acesso externo falhou. O diagnóstico identificou a regra ausente, e a recuperação restaurou somente TCP `80` para o CIDR autorizado.

O **Lab 16** investigou a perda de conectividade do Systems Manager após a revogação da saída HTTPS. A primeira tentativa não produziu `ConnectionLost` no prazo e restaurou a regra. A segunda, após ajustar o procedimento para reiniciar somente a instância exclusiva, confirmou SSM `ConnectionLost` com EC2 `running`. A recuperação utilizou a API do EC2.

O **Lab 17** registrou o baseline v1 e o backup de quatro arquivos da aplicação. Uma candidata inválida foi rejeitada por `nginx -t`, mantendo o serviço em v1. O rollback restaurou os hashes do baseline; depois, a candidata v2 foi validada local e externamente e confirmada.

O **Lab 18** criou um backup de quatro arquivos em S3 privado e versionado. A perda de `index.html` e `version` produziu HTTP 404 em `/` e `/version`, mantendo `/health` saudável. A restauração recuperou a versão registrada, verificou SHA-256 e manifesto e restabeleceu os quatro hashes do baseline.

O intervalo observado entre perda e recuperação local no Lab 18 foi de **5 min 56,294 s**, incluindo diagnóstico e espera do operador. Essa medição não estabelece um objetivo de RTO para produção.

Os laboratórios concluíram o cleanup dos recursos exclusivos e preservaram a rede compartilhada do Lab 08.

| Laboratório | Documentação |
|:---:|:---:|
| Lab 13 | [Procedimento e evidências](../labs/13-aws-application-troubleshooting/README.md) |
| Lab 14 | [Procedimento e evidências](../labs/14-aws-disk-utilization/README.md) |
| Lab 15 | [Procedimento e evidências](../labs/15-aws-connectivity-troubleshooting/README.md) |
| Lab 16 | [Procedimento e evidências](../labs/16-aws-systems-manager-troubleshooting/README.md) |
| Lab 17 | [Procedimento e evidências](../labs/17-aws-controlled-update/README.md) |
| Lab 18 | [Procedimento, medições e evidências](../labs/18-aws-application-backup-restore/README.md) |

O módulo de operação e troubleshooting está concluído.

---

## Módulo 04 — Terraform

| Status | Laboratório | Conteúdo |
|---|---|---|
| Concluído | **Lab 19 — Fluxo essencial do Terraform** | Recurso local `terraform_data`, inicialização, formatação, validação, plano salvo, aplicação, estado, outputs e destroy |
| Concluído | **Lab 20 — Infraestrutura AWS como código** | Provider AWS, lock de dependências, IAM, Security Group, regras, EC2 com Nginx, validação independente e cleanup |
| Concluído | **Lab 21 — Estado remoto** | Bootstrap separado, S3 privado e versionado, migração do estado, identidade preservada, bloqueio concorrente e cleanup |
| Concluído | **Lab 22 — Variáveis, outputs e módulos** | Variáveis tipadas, entrada inválida rejeitada, módulo reutilizável, outputs, plano sem mudanças e remoção local |
| Concluído | **Lab 23 — Mudanças e drift** | Mudança intencional, alteração externa, diagnóstico, recuperação, validação de conteúdo e SHA256 e remoção local |
| Concluído | **Lab 24 — Validação automatizada** | GitHub Actions, matriz de jobs, checksums para Windows e Linux, falhas de formatação e configuração e recuperação dos checks |

### Resultados concluídos no módulo

#### Lab 19 — Fluxo essencial do Terraform

O exercício executou o ciclo completo de um recurso local `terraform_data`, utilizando Terraform `1.16.1` e workspace `default`.

A inicialização, a formatação e a validação foram concluídas. O plano inicial propôs um único recurso e foi salvo, inspecionado e aplicado.

Estado e outputs foram conferidos. Um segundo plano confirmou ausência de mudanças, com código de saída `0`.

O destroy deixou o estado vazio e preservou os três arquivos `.tf`.

[Procedimento e evidências do Lab 19](../labs/19-terraform-essential-workflow/README.md).

#### Lab 20 — Infraestrutura AWS como código

O exercício utilizou Terraform `1.16.1`, provider AWS `6.67.0` e estado local.

O arquivo de dependências foi versionado e conferido com `-lockfile=readonly`. A pré-validação verificou identidade AWS, estado, rede compartilhada e conflitos de recursos exclusivos.

O plano criou sete recursos gerenciados:

- IAM Role;
- associação com a política do Systems Manager;
- Instance Profile;
- Security Group;
- regra de entrada HTTP;
- regra de saída HTTPS;
- instância EC2 com Nginx.

A VPC e a sub-rede compartilhadas foram consultadas como fontes de dados.

A validação independente conferiu estado, outputs, EC2, volume root, Security Group, IAM, Systems Manager e aplicação. Os endpoints `/`, `/health` e `/version` responderam HTTP 200 local e externamente.

Um segundo plano confirmou ausência de mudanças. O cleanup removeu os sete recursos gerenciados, e a validação confirmou a ausência dos recursos exclusivos, incluindo o volume root, preservando as condições verificadas da rede compartilhada.

[Procedimento e evidências do Lab 20](../labs/20-terraform-aws-infrastructure/README.md).

#### Lab 21 — Estado remoto

Um bootstrap independente criou seis recursos para um backend S3 privado, versionado e criptografado. O estado do bootstrap permaneceu local.

O exercício criou `terraform_data.lab21` e migrou seu estado para S3, preservando identificador e outputs. A consulta independente confirmou criptografia e identificador de versão do objeto.

O backend utilizou `use_lockfile = true`. O teste de concorrência confirmou a existência de `.tflock` e a recusa da segunda operação com `Error acquiring the state lock` e `PreconditionFailed`.

A operação interativa foi cancelada, liberando o bloqueio. Um novo plano confirmou ausência de mudanças.

O cleanup seguiu esta ordem:

1. Remoção do recurso do exercício pelo backend remoto.
2. Preservação de uma cópia do estado final vazio.
3. Exclusão de oito versões de objetos e seis marcadores de exclusão.
4. Confirmação do bucket vazio.
5. Remoção dos seis recursos do bootstrap.
6. Confirmação independente da ausência do bucket.

[Procedimento e evidências do Lab 21](../labs/21-terraform-remote-state/README.md).

#### Lab 22 — Variáveis, outputs e módulos

O módulo raiz chamou o mesmo módulo filho como `application` e `worker`. Cada chamada gerenciou um recurso local `terraform_data`.

A inicialização, a formatação e a validação foram concluídas. A entrada `replica_count = 0` foi rejeitada, com código de saída `1`, preservando `terraform.tfvars`.

Estado e outputs confirmaram os componentes com parâmetros de réplica `2` e `1`. Esses valores são dados didáticos, sem serviços em execução.

Um segundo plano confirmou ausência de mudanças. A remoção destruiu os dois recursos, deixando o estado vazio e os nove arquivos de configuração presentes.

[Procedimento e evidências do Lab 22](../labs/22-terraform-variables-outputs-modules/README.md).

#### Lab 23 — Mudanças e drift

O exercício utilizou Terraform `1.16.1`, provider `hashicorp/local` `2.9.1`, estado local e workspace `default`.

Um recurso `local_file.application_config` gerenciou um JSON exclusivo. O baseline inicial utilizou `v1 / info / dev`. Conteúdo, SHA256, estado e outputs foram validados, e um segundo plano confirmou ausência de mudanças.

A mudança intencional para `v2` apresentou uma criação e uma remoção. Após a aplicação, o baseline v2 foi registrado e confirmado por um plano sem mudanças.

O drift alterou diretamente `log_level` para `debug`, preservando configuração, parâmetros e estado. O arquivo observado diferiu dos valores registrados e do baseline v2.

O plano de recuperação apresentou uma criação. Sua aplicação restaurou exatamente o conteúdo e o SHA256 do baseline v2. Um novo plano confirmou ausência de mudanças, com código de saída `0`.

O plano de remoção foi revisado e aplicado. A verificação final confirmou:

- zero recursos no estado;
- arquivo gerenciado ausente;
- sete arquivos de configuração e parâmetros preservados;
- quatro registros locais preservados;
- repositório sem alterações locais.

Quatorze capturas documentam a execução.

[Procedimento, comparação dos planos e evidências do Lab 23](../labs/23-terraform-changes-drift/README.md).

#### Lab 24 — Validação automatizada

Um workflow no GitHub Actions verificou as configurações dos Labs 22 e 23, utilizando Terraform `1.16.1` e runner Ubuntu `24.04`.

Uma matriz executou dois jobs independentes. Cada job realizou:

1. Checkout do repositório.
2. Instalação e consulta da versão do Terraform.
3. Verificação de formatação.
4. Inicialização sem configuração do backend.
5. Validação da configuração.

O arquivo de dependências do Lab 23 foi preparado para Windows e Linux, preservando o provider `hashicorp/local` na versão `2.9.1`.

O workflow utilizou lockfile somente leitura no Lab 23 e verificou sua preservação após a inicialização.

Os testes foram executados em branch temporária e pull request:

| Cenário | Resultado |
|:---:|:---:|
| Configurações válidas | Dois jobs aprovados |
| Formatação incorreta no Lab 22 | Falha em `fmt`, código de saída `3` |
| Formatação corrigida | Dois jobs aprovados |
| Variável não declarada no Lab 22 | Falha em `validate`, código de saída `1` |
| Referência inválida removida | Dois jobs aprovados |

O job do Lab 23 foi aprovado durante as falhas controladas do Lab 22.

Após a recuperação final, o pull request #1 foi fechado sem merge e a branch temporária foi excluída. Os arquivos de teste ficaram fora da branch `main`.

A execução não utilizou credenciais AWS nem executou `plan`, `apply` ou `destroy`.

[Workflow de validação](../.github/workflows/lab24-terraform-validation.yml).

[Procedimento, resultados e evidências do Lab 24](../labs/24-terraform-automated-validation/README.md).

O módulo de Terraform está concluído, com os Labs 19 a 24 executados e documentados.

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
- validação automatizada do código;
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
|---|---|
| Preparação e acesso | Concluído |
| Operações Linux | Concluído |
| Infraestrutura AWS | Concluído |
| Operação e troubleshooting | Concluído |
| Terraform | Concluído |
| Monitoramento e logs | Planejado |
| Docker | Planejado |
| Segurança, custos e confiabilidade | Planejado |
| Projeto final | Planejado |

### Resumo numérico

| Indicador | Quantidade |
|---|---|
| Laboratórios concluídos | `25` |
| Laboratórios em desenvolvimento | `0` |
| Laboratórios planejados | `13` |
| Último laboratório concluído | `Lab 24` |
| Próximo laboratório | `Lab 25` |

O total considera os Labs 00 a 37. O projeto final é acompanhado separadamente.

Os módulos de preparação e acesso, operações Linux, infraestrutura AWS, operação e troubleshooting e Terraform estão concluídos.

---

## Próxima etapa

**Lab 25 — Métricas no CloudWatch**

O próximo laboratório iniciará o módulo de monitoramento e logs.

O planejamento deverá definir:

- ambiente e recursos observados;
- perfil AWS, Região e identificação dos recursos;
- métricas, namespaces e dimensões utilizados;
- períodos e estatísticas adequados às consultas;
- coleta e interpretação dos resultados;
- comportamento esperado quando não houver dados;
- organização de um dashboard;
- validação das consultas e do dashboard;
- registro das evidências;
- custos envolvidos e procedimento de cleanup.

O escopo será definido antes da implementação. Recursos removidos nos laboratórios anteriores não serão tratados como ainda disponíveis.

A infraestrutura compartilhada e os recursos de outros projetos permanecerão fora do escopo de alteração e remoção.
