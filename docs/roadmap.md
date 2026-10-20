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
|:---:|---|---|
| Concluído | **Lab 00 — Preparação da estação de trabalho** | Git, VS Code, PowerShell e organização local |
| Concluído | **Lab 01 — Configuração segura da conta AWS** | Proteção da conta e acesso administrativo |
| Concluído | **Lab 02 — AWS CLI e autenticação por SSO** | Perfis, sessões temporárias e validação de identidade |
| Concluído | **Lab 03 — Ferramentas de infraestrutura** | Terraform e Session Manager Plugin |

---

## Módulo 01 — Operações Linux

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| Concluído | **Lab 04 — Arquivos e diretórios** | Navegação, busca, cópia, movimentação e remoção |
| Concluído | **Lab 05 — Usuários, grupos e permissões** | Identidades, permissões e acesso compartilhado |
| Concluído | **Lab 06 — Serviços e logs** | `systemctl`, `journalctl`, diagnóstico e recuperação de serviço |

---

## Módulo 02 — Infraestrutura AWS

| Status | Laboratório | Conteúdo |
|:---:|---|---|
| Concluído | **Lab 07 — Baseline operacional da conta AWS** | Inventário somente leitura de identidade, rede, recursos, segurança, tags, observabilidade e custos |
| Concluído | **Lab 08 — Rede da aplicação** | VPC, sub-redes, rotas, Internet Gateway, Security Group, validação e cleanup |
| Concluído | **Lab 09 — Instância EC2 administrada pelo Systems Manager** | EC2, IAM Role, Session Manager, validação e cleanup |
| Concluído | **Lab 10 — Serviço web em Linux** | Nginx, `systemd`, acesso HTTP restrito, Systems Manager, validação e cleanup |
| Concluído | **Lab 11 — Armazenamento e recuperação** | EBS, S3, cópia, integridade e restauração |
| Concluído | **Lab 12 — Disponibilidade da aplicação** | Application Load Balancer, health checks, distribuição de tráfego, falha controlada e recuperação |

---

## Módulo 03 — Operação e troubleshooting

| Status | Laboratório | Conteúdo |
|:---:|---|---|
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
|:---:|---|---|
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
|:---:|---|---|
| Concluído | **Lab 25 — Métricas no CloudWatch** | Métricas nativas EC2, períodos e estatísticas, carga limitada de CPU, recuperação, créditos, dashboard e cleanup |
| Concluído | **Lab 26 — CloudWatch Agent** | Memória, disco raiz, logs sintéticos, validação de entrega e cleanup |
| Concluído | **Lab 27 — Alarmes e notificações** | Métrica sintética, thresholds, SNS, recuperação, dados ausentes e cleanup |
| Concluído | **Lab 28 — CloudWatch Logs Insights** | Sessenta eventos sintéticos, sete consultas, filtros, agregações, percentis, linha do tempo, requestId e cleanup independente |
| Planejado | **Lab 29 — Monitoramento com Zabbix** | Agente, itens, triggers e disponibilidade |
| Planejado | **Lab 30 — Investigação de alertas** | Correlação entre métricas, logs e estado do sistema |

### Resultados concluídos no módulo

#### Lab 25 — Métricas no CloudWatch

O exercício provisionou uma instância Amazon Linux 2023 `t3.micro`, com créditos `standard`, monitoramento básico e administração pelo Systems Manager.

A infraestrutura utilizou VPC e subnet exclusivas, Internet Gateway, rota pública e security group sem regras de entrada. O volume raiz `gp3` de 8 GiB foi criptografado e configurado para exclusão na terminação.

As consultas utilizaram o namespace `AWS/EC2` e a dimensão `InstanceId`:

| Métrica | Estatística | Período |
|:---:|:---:|:---:|
| `CPUUtilization` | `Average`, `Maximum` | 300 segundos |
| `NetworkIn` | `Sum` | 300 segundos |
| `NetworkOut` | `Sum` | 300 segundos |
| `StatusCheckFailed` | `Maximum` | 60 segundos |
| `CPUCreditBalance` | `Average` | 300 segundos |

A coleta inicial retornou dados para as quatro métricas previstas na configuração. O saldo de créditos foi consultado adicionalmente para interpretar a carga.

Um processo de carga executou durante 600 segundos pelo SSM Run Command. A conclusão foi confirmada por status `Success`, código de resposta `0` e marcadores de início, fim e encerramento.

A janela comparativa, de `20:25` a `21:15` UTC em 9 de outubro de 2026, registrou:

- utilização baixa antes da carga;
- média de CPU de aproximadamente `50,173%` no intervalo completo de carga;
- retorno para aproximadamente `0,23%` a `0,26%` após o encerramento;
- redução do saldo de créditos durante a carga e recuperação posterior;
- cinquenta pontos de `StatusCheckFailed` com valor zero.

Os intervalos com início e fim parciais da carga foram interpretados considerando a agregação de cinco minutos.

O dashboard reuniu cinco widgets, com identificação da execução, CPU, créditos, rede e verificações de status. O conteúdo recuperado pela API foi comparado semanticamente ao corpo local, e os gráficos foram inspecionados no console.

A remoção do dashboard foi confirmada antes da remoção da infraestrutura. A verificação independente do cleanup passou nas onze consultas:

- instância EC2;
- volume EBS;
- subnet;
- tabela de rotas;
- security group;
- Internet Gateway;
- VPC;
- interfaces de rede da VPC;
- role IAM;
- instance profile;
- dashboard.

Os recursos consultados estavam ausentes e nenhuma interface de rede foi encontrada na VPC. Inventário, recibos e relatórios locais foram preservados.

[Procedimento, resultados e evidências do Lab 25](../labs/25-cloudwatch-metrics/README.md).

#### Lab 26 — CloudWatch Agent

O exercício provisionou infraestrutura exclusiva com Amazon Linux 2023, EC2 `t3.micro`, créditos `standard`, volume raiz `gp3` criptografado de 8 GiB, IMDSv2 e administração pelo Systems Manager. O security group não tinha regras de entrada.

O CloudWatch Agent foi instalado e configurado por SSM. O resultado confirmou `Success`, código `0`, versão `1.300071.0`, serviço ativo, agente em execução e SHA-256 da configuração aplicada.

A coleta utilizou intervalo de 60 segundos e namespace `Lab26/CWAgent`:

| Métrica | Dimensões observadas | Resultado da consulta versionada |
|:---:|:---:|:---:|
| `mem_used_percent` | `InstanceId` | 29 pontos; aproximadamente `23,05%` a `23,21%` |
| `disk_used_percent` | `InstanceId`, `path=/`, `fstype=xfs` | 30 pontos; aproximadamente `23,576%` a `23,578%` |

O grupo de logs exclusivo recebeu retenção de um dia. O evento inicial foi encontrado, e um lote de três mensagens INFO, WARN e ERROR foi gravado no arquivo de aplicação, relido localmente e comparado com os eventos recebidos na AWS.

A confirmação do lote passou em três de três eventos. As diferenças observadas entre timestamp e ingestão foram de 6, 5 e 9 segundos, sem estabelecer uma garantia de latência.

As validações registraram dimensões, pontos, marcadores e resultados em relatórios JSON locais. Dezessete capturas documentam a execução.

O cleanup terminou a instância e removeu os recursos exclusivos. Onze consultas independentes confirmaram EC2 `terminated`, volume, security group, subnet, route table, Internet Gateway e VPC ausentes, nenhuma interface na VPC, role e instance profile ausentes e grupo de logs ausente.

Inventário, recibos e relatórios foram preservados.

[Procedimento, resultados e evidências do Lab 26](../labs/26-cloudwatch-agent/README.md).

#### Lab 27 — Alarmes e notificações

Concluído em 14 de outubro de 2026. O cenário publicou uma métrica sintética em `Lab27/ControlledApplication`, com dimensões `Scenario` e `RunId`, unidade `Count` e períodos de 60 segundos.

O alarme avaliou soma maior ou igual a três em dois de três períodos, com dados ausentes tratados como `missing`. A assinatura de e-mail foi confirmada pela AWS CLI.

O ensaio contínuo conferiu quinze períodos: cinco zeros de baseline, cinco valores cinco de estímulo e cinco zeros de recuperação, todos com `SampleCount=1`.

| Transição | Horário de Brasília em 14/10/2026 |
|:---:|:---:|
| `INSUFFICIENT_DATA → OK` | 19:31:29 |
| `OK → ALARM` | 19:37:29 |
| `ALARM → OK` | 19:42:29 |
| `OK → INSUFFICIENT_DATA` | 19:53:29 |

O histórico registrou três ações SNS bem-sucedidas. As capturas documentam o recebimento dos e-mails de baseline, alarme e recuperação. A captura 42 registra a notificação da transição `ALARM → OK`.

O alarme e o tópico foram removidos. Duas consultas independentes confirmaram sua ausência em 14/10/2026 às 23:26:32 UTC. Inventário, recibos, backups locais e histórico experimental foram preservados.

[Procedimento, resultados e evidências do Lab 27](../labs/27-cloudwatch-alarms-notifications/README.md).

#### Lab 28 — CloudWatch Logs Insights

O exercício provisionou um grupo de logs exclusivo, classe `STANDARD`, e o stream `controlled-application`. A configuração final utilizou retenção de sete dias e tags de propriedade vinculadas ao RunId.

Um lote de 60 eventos JSON sintéticos foi publicado. A leitura paginada confirmou timestamps e mensagens idênticos ao dataset preservado antes do envio.

Sete consultas foram concluídas:

| Consulta | Resultado |
|:---:|:---:|
| Eventos da execução | Sessenta linhas |
| Erros HTTP 5xx | Doze linhas |
| Resumo por fase | Vinte requisições em cada fase |
| Erros por endpoint e causa | Doze erros em `/orders`, com `dependency_timeout` |
| Linha do tempo | Erros concentrados no minuto intermediário |
| Requisição específica | `req-021`, HTTP 503 e 900 ms |
| Resumo global | Sessenta requisições, doze erros e taxa de 20% |

A taxa de erro durante o incidente foi de 60%. Baseline e recuperação apresentaram zero erros. As médias de duração foram de 108,5 ms na baseline e recuperação e 673,1 ms no incidente.

Os dados foram gerados pelo PowerShell. A causa registrada e as fases representam um cenário sintético, sem falha ou recuperação de uma aplicação real.

Durante a execução, a retenção foi ampliada de um para sete dias. Os eventos originais voltaram a ser consultados, sem republicação do lote. O teste de ingestão recebeu tratamento para token ausente e passou novamente no fluxo normal.

Cada uma das sete consultas registradas examinou 60 eventos e 17574 bytes em um grupo. A consulta por requestId retornou uma linha, demonstrando a diferença entre quantidade retornada e volume examinado.

O grupo foi removido em 19 de outubro de 2026. Uma nova consulta independente confirmou sua ausência na conta e região verificadas. Inventário, dataset, recibos e relatórios locais foram preservados.

Vinte capturas documentam as etapas da execução.

[Procedimento, resultados e evidências do Lab 28](../labs/28-cloudwatch-logs-insights/README.md).

O módulo de monitoramento e logs possui quatro dos seis laboratórios concluídos. A próxima etapa prevista é o Lab 29 — Monitoramento com Zabbix.

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
|:---:|:---:|
| Preparação e acesso | Concluído |
| Operações Linux | Concluído |
| Infraestrutura AWS | Concluído |
| Operação e troubleshooting | Concluído |
| Terraform | Concluído |
| Monitoramento e logs | Iniciado — 3 de 6 laboratórios concluídos |
| Docker | Planejado |
| Segurança, custos e confiabilidade | Planejado |
| Projeto final | Planejado |

### Resumo numérico

| Indicador | Quantidade |
|:---:|:---:|
| Laboratórios concluídos | `28` |
| Laboratórios em desenvolvimento | `1` |
| Laboratórios planejados | `10` |
| Último laboratório concluído | `Lab 27` |
| Próximo laboratório | `Lab 28` |

O total considera os Labs 00 a 37. O projeto final é acompanhado separadamente.

Os módulos de preparação e acesso, operações Linux, infraestrutura AWS, operação e troubleshooting e Terraform estão concluídos.

O módulo de monitoramento e logs possui três laboratórios concluídos. O Lab 28 permanece planejado.

---

## Próxima etapa

**Lab 28 — CloudWatch Logs Insights**

O próximo laboratório trabalhará consultas e investigação de eventos.

O planejamento deverá definir:

- ambiente e recursos exclusivos, perfil e região;
- grupo de logs, retenção, formato e campos dos eventos de teste;
- filtros, ordenação, agregações e interpretação das consultas;
- janelas temporais e confirmação de ingestão;
- eventos controlados que permitam investigar um problema;
- registro das consultas, resultados e evidências;
- permissões, volume consultado, custos e cleanup.

O escopo será definido antes da implementação. Os recursos exclusivos dos Labs 25, 26 e 27 foram removidos e não serão tratados como disponíveis.

A infraestrutura compartilhada e os recursos de outros projetos permanecerão fora do escopo de alteração e remoção.
