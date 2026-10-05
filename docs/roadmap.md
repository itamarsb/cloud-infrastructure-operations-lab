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
| Concluído | **Lab 19 — Fluxo essencial do Terraform** | Recurso local `terraform_data`, inicialização, formatação, validação, plano salvo, aplicação, estado, outputs e destroy |
| Concluído | **Lab 20 — Infraestrutura AWS como código** | Provider AWS, lock de dependências, IAM, Security Group, regras, EC2 com Nginx, validação independente e cleanup |
| Concluído | **Lab 21 — Estado remoto** | Bootstrap separado, S3 privado e versionado, migração do estado, identidade preservada, bloqueio concorrente e cleanup |
| Concluído | **Lab 22 — Variáveis, outputs e módulos** | Variáveis tipadas, entrada inválida rejeitada, módulo reutilizável, outputs, plano sem mudanças e remoção local |
| Planejado | **Lab 23 — Mudanças e drift** | Comparação entre código, estado e ambiente |
| Planejado | **Lab 24 — Validação automatizada** | Formatação, validação e verificação do código em pipeline |

### Resultados concluídos no módulo

O **Lab 19** executou o ciclo completo de um recurso local `terraform_data`, utilizando Terraform `1.16.1` e o workspace `default`.

A inicialização foi concluída, a formatação não apresentou diferenças e a configuração passou pela validação. O plano inicial propôs a criação de um único recurso e foi salvo, inspecionado e aplicado.

A consulta ao estado confirmou somente `terraform_data.lab19`. Os outputs corresponderam aos valores definidos na configuração, e um segundo plano confirmou ausência de mudanças, com código de saída `0`.

O destroy removeu o recurso. A validação final confirmou estado sem recursos e preservação dos arquivos `versions.tf`, `main.tf` e `outputs.tf`.

O exercício foi inteiramente local, sem provisionamento AWS. O procedimento e as evidências estão no [README do Lab 19](../labs/19-terraform-essential-workflow/README.md).

O **Lab 20** provisionou uma aplicação Nginx na AWS utilizando Terraform `1.16.1`, provider AWS `6.67.0` e estado local no workspace `default`.

O arquivo `.terraform.lock.hcl` foi versionado. A comparação entre a cópia local e a publicada confirmou conteúdo idêntico após normalizar os finais de linha LF e CRLF. A inicialização com `-lockfile=readonly` reutilizou a versão registrada do provider.

A pré-validação conferiu identidade AWS, estado local, rede compartilhada e conflitos de recursos exclusivos, sem alterar recursos AWS.

O plano salvo propôs a criação de sete recursos gerenciados:

- IAM Role para a instância EC2;
- associação com a política `AmazonSSMManagedInstanceCore`;
- Instance Profile;
- Security Group;
- regra de entrada HTTP restrita ao IPv4 autorizado;
- regra de saída HTTPS;
- instância EC2 com aplicação Nginx.

A VPC e a sub-rede compartilhadas do Lab 08 foram consultadas como fontes de dados e permaneceram fora do conjunto de recursos gerenciados.

A aplicação do plano criou os sete recursos. A validação independente conferiu estado, outputs, EC2, volume root, Security Group, IAM, Systems Manager e aplicação. A instância apresentou IMDSv2 obrigatório, volume root `gp3` criptografado e administração pelo Systems Manager, sem entrada SSH.

A inicialização da instância foi concluída, a configuração do Nginx passou na validação e os endpoints `/`, `/health` e `/version` responderam HTTP 200 local e externamente, com o conteúdo esperado da versão v1.

Um segundo plano confirmou ausência de mudanças, com código de saída `0`.

O plano de remoção foi salvo e revisado, incluindo a conferência das ações e dos identificadores dos sete recursos. Sua aplicação destruiu os sete recursos gerenciados.

A validação pós-cleanup confirmou:

- estado local preservado, sem recursos gerenciados restantes;
- instância EC2 encerrada ou ausente;
- volume root, Security Group e recursos IAM exclusivos ausentes;
- nenhuma EC2 ativa identificada pelos nomes ou tags do Lab 20;
- preservação das condições verificadas da VPC, sub-rede, rotas, Internet Gateway, Network ACL e DNS compartilhados;
- arquivos de configuração preservados.

Os arquivos Terraform, os scripts de validação e as evidências estão no [README do Lab 20](../labs/20-terraform-aws-infrastructure/README.md).

O **Lab 21** implementou um backend S3 exclusivo utilizando Terraform `1.16.1` e provider AWS `6.67.0`.

O bootstrap manteve seu estado local durante toda a execução e provisionou seis recursos: bucket, bloqueio de acesso público, controle de propriedade dos objetos, versionamento, criptografia e política de transporte seguro.

A validação independente confirmou bucket privado, versionamento habilitado, criptografia SSE-S3 `AES256`, propriedade `BucketOwnerEnforced`, tags esperadas e ausência inicial de versões e marcadores de exclusão.

O exercício criou `terraform_data.lab21` com estado local. O identificador e os outputs foram registrados, um segundo plano confirmou ausência de mudanças, e uma cópia do estado foi conferida por SHA256.

A migração para S3 preservou o identificador e os outputs. O backend utilizou `use_lockfile = true`, e a consulta independente ao objeto confirmou criptografia e identificador de versão.

O teste de concorrência utilizou uma aplicação interativa aguardando aprovação no primeiro terminal. A existência do objeto `.tflock` foi confirmada no S3. Uma segunda operação, com espera limitada a cinco segundos, foi recusada com `Error acquiring the state lock` e `PreconditionFailed`.

A resposta `no` cancelou a aplicação e liberou o bloqueio. Um novo plano foi executado com sucesso, sem mudanças e com o identificador original preservado.

O cleanup seguiu esta ordem:

1. Remoção do recurso do exercício pelo backend remoto.
2. Preservação de uma cópia do estado final sem recursos e outputs.
3. Inventário e exclusão de oito versões de objetos e seis marcadores de exclusão.
4. Confirmação do bucket vazio.
5. Aplicação do plano de remoção dos seis recursos do bootstrap.
6. Validação do estado local final e confirmação independente da ausência do bucket na conta AWS.

Os procedimentos, arquivos e evidências estão no [README do Lab 21](../labs/21-terraform-remote-state/README.md).

O **Lab 22** demonstrou parametrização e reutilização de configuração com Terraform `1.16.1`, Windows PowerShell, estado local e workspace `default`.

O módulo raiz chamou o mesmo módulo filho como `application` e `worker`. Cada chamada gerenciou um recurso integrado `terraform_data`, recebendo entradas tipadas e retornando identificador e dados para os outputs da raiz.

A inicialização, a formatação recursiva e a validação foram concluídas. Uma entrada com `replica_count = 0` foi rejeitada pela regra de número inteiro entre 1 e 5, com código de saída `1`. A comparação SHA256 confirmou que `terraform.tfvars` permaneceu inalterado durante o teste.

O plano salvo de criação propôs somente dois recursos. A aplicação, o estado e os outputs confirmaram os componentes, com valores de réplica `2` para `application` e `1` para `worker`. Esses parâmetros são dados didáticos, sem criação de serviços ou monitoramento real.

Um segundo plano confirmou ausência de mudanças, com código de saída `0`. O plano salvo de remoção foi revisado e aplicado, destruindo os dois recursos. A verificação final confirmou estado vazio e presença dos nove arquivos de configuração.

A execução foi inteiramente local, sem provisionamento AWS ou utilização do backend S3 removido no Lab 21. O procedimento, os resultados e as sete evidências estão no [README do Lab 22](../labs/22-terraform-variables-outputs-modules/README.md).


O módulo de Terraform está em desenvolvimento.

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
| Terraform | Em desenvolvimento |
| Monitoramento e logs | Planejado |
| Docker | Planejado |
| Segurança, custos e confiabilidade | Planejado |
| Projeto final | Planejado |

### Resumo numérico

| Indicador | Quantidade |
|:---:|:---:|
| Laboratórios concluídos | `23` |
| Laboratórios em desenvolvimento | `0` |
| Laboratórios planejados | `15` |
| Último laboratório concluído | `Lab 22` |
| Próximo laboratório | `Lab 23` |

O total considera os Labs 00 a 37. O projeto final é acompanhado separadamente.

O módulo de Terraform está em desenvolvimento: os Labs 19 a 22 foram concluídos, enquanto os Labs 23 e 24 permanecem planejados.

---

## Próxima etapa

**Lab 23 — Mudanças e drift**

O próximo laboratório abordará a comparação entre a configuração declarada, o estado do Terraform e o ambiente observado, incluindo mudanças intencionais e divergências introduzidas fora do Terraform.

O procedimento deverá incluir:

- definição do cenário, backend e recursos exclusivos;
- conferência do ambiente e do estado inicial;
- criação de um baseline e confirmação de plano sem mudanças;
- alteração intencional da configuração e revisão do plano resultante;
- aplicação do plano salvo e inspeção do estado e dos outputs;
- introdução de uma divergência controlada fora do Terraform;
- identificação da divergência pelo plano;
- revisão das ações propostas para reconciliar o ambiente com a configuração;
- aplicação da correção e confirmação de plano sem mudanças;
- remoção dos recursos exclusivos;
- validação final e publicação das evidências.

O cenário deverá distinguir mudanças de configuração e alterações externas, com resultados verificáveis em cada etapa.

O bucket removido no Lab 21 não estará disponível para reutilização automática. O estado final do Lab 22 está vazio, e seus arquivos de configuração foram mantidos.

A infraestrutura compartilhada e os recursos de outros projetos permanecerão fora do escopo de alteração e remoção.
