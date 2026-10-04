# Cloud Infrastructure Operations Lab

Laboratório progressivo de infraestrutura e operações em nuvem, com atividades práticas em **AWS, Linux, Terraform, Docker, CloudWatch, Zabbix, Bash e PowerShell**.

O projeto documenta a construção e a operação de um ambiente de aplicação ao longo de uma trilha evolutiva: preparação da estação de trabalho, acesso seguro à nuvem, administração Linux, infraestrutura AWS, automação, observabilidade, troubleshooting, segurança, custos e confiabilidade.

Cada laboratório apresenta contexto, procedimentos, validações, evidências e, quando aplicável, scripts reutilizáveis e etapas de cleanup.

> **English summary:** Hands-on cloud infrastructure and operations portfolio focused on AWS, Linux administration, Terraform, automation, observability, troubleshooting, security and operational reliability. Each lab includes documented procedures, validation results and execution evidence. Labs 00–20 are complete; the latest exercise provisioned seven AWS resources with Terraform, independently validated the application, verified a plan with no changes and removed the exclusive resources while preserving the shared network.

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
|:---:|:---:|---|
| Concluído | [Lab 00 — Preparação da estação de trabalho](labs/00-workstation-preparation/) | Git, VS Code, PowerShell e organização local |
| Concluído | [Lab 01 — Configuração segura da conta AWS](labs/01-secure-aws-account-configuration/) | Proteção da conta e acesso administrativo |
| Concluído | [Lab 02 — AWS CLI e autenticação por SSO](labs/02-aws-cli-installation-and-configuration/) | Perfis, sessões temporárias e validação de identidade |
| Concluído | [Lab 03 — Ferramentas de infraestrutura](labs/03-infrastructure-tools-installation/) | Terraform e Session Manager Plugin |
| Concluído | [Lab 04 — Arquivos e diretórios Linux](labs/04-linux-file-management/) | Navegação, busca e operações com arquivos |
| Concluído | [Lab 05 — Usuários, grupos e permissões](labs/05-linux-users-groups-permissions/) | Identidades, permissões e acesso compartilhado |
| Concluído | [Lab 06 — Serviços e logs no Linux](labs/06-linux-processes-services-logs/) | `systemctl`, `journalctl`, diagnóstico e recuperação de serviço |
| Concluído | [Lab 07 — Baseline operacional da conta AWS](labs/07-aws-account-baseline/) | Inventário somente leitura, segurança, tags, observabilidade e custos |
| Concluído | [Lab 08 — Rede da aplicação na AWS](labs/08-aws-application-network/) | VPC, sub-redes, rotas, Internet Gateway, Security Group e cleanup |
| Concluído | [Lab 09 — EC2 administrada pelo Systems Manager](labs/09-aws-ec2-systems-manager/) | EC2, IAM Role, Session Manager, validação e cleanup |
| Concluído | [Lab 10 — Serviço web Nginx em Linux](labs/10-linux-web-service/) | Nginx, `systemd`, acesso HTTP restrito, Systems Manager, validação e cleanup |
| Concluído | [Lab 11 — Armazenamento e recuperação](labs/11-aws-storage-recovery/) | EBS, Amazon S3, integridade, cópia e restauração |
| Concluído | [Lab 12 — Disponibilidade da aplicação](labs/12-aws-application-availability/) | Application Load Balancer, health checks, distribuição de tráfego e recuperação |
| Concluído | [Lab 13 — Troubleshooting de aplicação indisponível](labs/13-aws-application-troubleshooting/) | Nginx, falha controlada, diagnóstico estruturado, recuperação e cleanup |
| Concluído | [Lab 14 — Utilização de disco](labs/14-aws-disk-utilization/) | Volume EBS dedicado, pressão controlada, diagnóstico, mitigação e cleanup |
| Concluído | [Lab 15 — Troubleshooting de conectividade](labs/15-aws-connectivity-troubleshooting/) | Falha controlada no Security Group, diagnóstico por camadas, recuperação e cleanup |
| Concluído | [Lab 16 — Troubleshooting do AWS Systems Manager](labs/16-aws-systems-manager-troubleshooting/) | Falha controlada na saída HTTPS, diagnóstico SSM, recuperação e cleanup |
| Concluído | [Lab 17 — Atualização controlada de aplicação](labs/17-aws-controlled-update/) | Baseline v1, falha de configuração, diagnóstico, rollback, atualização v2, confirmação e cleanup |
| Concluído | [Lab 18 — Backup e restauração de aplicação](labs/18-aws-application-backup-restore/) | S3 versionado, SHA-256, perda controlada, diagnóstico, restauração por VersionId e cleanup |
| Concluído | [Lab 19 — Fluxo essencial do Terraform](labs/19-terraform-essential-workflow/) | Recurso local `terraform_data`, plano salvo, aplicação, estado, outputs, plano sem mudanças e destroy |
| Concluído | [Lab 20 — Infraestrutura AWS como código](labs/20-terraform-aws-infrastructure/) | Provider AWS, lock de dependências, sete recursos, EC2 com Nginx, validação independente, plano sem mudanças e cleanup |

**21 laboratórios concluídos**, considerando a numeração de 00 a 20.

O planejamento completo está disponível em [`docs/roadmap.md`](docs/roadmap.md).

---

## Resultado mais recente

O **Lab 20 — Infraestrutura AWS como código** executou o ciclo de provisionamento e remoção de uma aplicação Nginx na AWS utilizando Terraform `1.16.1`, provider AWS `6.67.0`, Windows PowerShell e estado local no workspace `default`.

O arquivo `.terraform.lock.hcl` foi versionado e a inicialização com `-lockfile=readonly` confirmou a reutilização da versão registrada do provider. A formatação e a configuração passaram pelas verificações do Terraform.

O plano salvo propôs sete recursos exclusivos: IAM Role, associação com a política do Systems Manager, Instance Profile, Security Group, regra de entrada HTTP, regra de saída HTTPS e instância EC2. A VPC e a sub-rede compartilhadas do Lab 08 foram consultadas como fontes de dados.

A aplicação do plano criou os sete recursos. Uma validação independente conferiu o estado, os outputs, a configuração AWS, o Systems Manager, a inicialização da instância e o Nginx. Os endpoints `/`, `/health` e `/version` responderam HTTP 200 local e externamente, com a aplicação na versão v1.

Um segundo plano confirmou ausência de mudanças, com código de saída `0`.

O plano de remoção foi salvo, revisado e aplicado, destruindo os sete recursos gerenciados. A validação pós-cleanup confirmou a ausência dos recursos exclusivos, incluindo o volume root, e a preservação das condições verificadas da rede compartilhada. O estado local e os arquivos de configuração foram mantidos.

Consulte o [Lab 20](labs/20-terraform-aws-infrastructure/) para os arquivos Terraform, os scripts de validação, os resultados e as evidências.

---

## Resultados anteriores

O **Lab 19 — Fluxo essencial do Terraform** executou o ciclo completo de um recurso local `terraform_data`, utilizando Terraform `1.16.1`, Windows PowerShell e o workspace `default`.

A inicialização foi concluída, a formatação não apresentou diferenças e a configuração passou pela validação. O plano inicial propôs somente a criação de `terraform_data.lab19` e foi salvo, inspecionado e aplicado.

Após a aplicação, o estado continha um único recurso, os outputs correspondiam à configuração e um segundo plano confirmou ausência de mudanças, com código de saída `0`.

O destroy removeu o recurso. A validação final confirmou estado sem recursos e preservação dos três arquivos `.tf`. O exercício foi inteiramente local, sem provisionamento AWS.

Consulte o [Lab 19](labs/19-terraform-essential-workflow/) para o procedimento, os resultados e as evidências.

O **Lab 18 — Backup e restauração de aplicação na AWS** criou um backup verificável de quatro arquivos de uma aplicação Nginx em um bucket S3 privado e versionado. O pacote foi recuperado pelo `VersionId` registrado e conferido por SHA-256 e manifesto antes da simulação de perda.

A exclusão controlada de `index.html` e `version` produziu HTTP 404 em `/` e `/version`, enquanto o Nginx permaneceu ativo e `/health` continuou saudável. O diagnóstico identificou os arquivos ausentes. A restauração recuperou os dois arquivos da versão registrada; os quatro hashes finais coincidiram com o baseline e os testes HTTP locais e externos retornaram 200 com o conteúdo esperado.

O intervalo entre a perda e a recuperação observada localmente foi de **5 min 56,294 s**, incluindo diagnóstico e espera do operador. O cleanup removeu EC2, volume root, Security Group, bucket e recursos IAM exclusivos, preservando a rede compartilhada do Lab 08.

Consulte o [Lab 18](labs/18-aws-application-backup-restore/) para os scripts, os resultados, os limites das medições e as evidências.

O **Lab 17 — Atualização controlada de aplicação na AWS** implantou uma aplicação Nginx na versão v1 e registrou seu estado inicial, com backup e hashes SHA-256. Uma candidata com diretiva inválida fez o teste `nginx -t` falhar, enquanto o serviço permaneceu ativo e continuou respondendo em v1. O diagnóstico confirmou que somente o arquivo de configuração diferia do backup.

O rollback restaurou os quatro arquivos da v1 com hashes idênticos aos do baseline. Em seguida, a candidata v2 passou pelas verificações do Nginx e pelos testes HTTP locais e externos, foi confirmada e manteve o backup v1. O cleanup removeu a instância EC2, o Security Group, o Instance Profile e a IAM Role exclusivos, preservando a VPC e a sub-rede compartilhadas do Lab 08.

Consulte o [Lab 17](labs/17-aws-controlled-update/) para o procedimento, os scripts, os estados validados e as evidências.

O **Lab 16 — Troubleshooting do AWS Systems Manager** investigou uma instância EC2 que continuava `running`, mas deixou de responder ao Systems Manager depois da remoção controlada de sua saída HTTPS. A primeira tentativa foi inconclusiva: o SSM permaneceu `Online` durante a janela de observação, e a regra foi restaurada. Após ajustar o procedimento para reiniciar somente a instância exclusiva e encerrar conexões existentes, uma segunda execução confirmou `ConnectionLost`.

O diagnóstico somente leitura verificou a rede compartilhada, a configuração IAM e a ausência da regra de saída no Security Group exclusivo. A recuperação restaurou HTTPS pela API do EC2, sem depender de uma sessão SSM, e a validação independente voltou a `Healthy`. Por fim, o cleanup removeu a instância, o Security Group, o Instance Profile e a IAM Role exclusivos, preservando a VPC e a sub-rede do Lab 08.

Consulte o [Lab 16](labs/16-aws-systems-manager-troubleshooting/) para os scripts, a cronologia das tentativas, o diagnóstico e as evidências.

O **Lab 15 — Troubleshooting de conectividade na AWS** confirmou que uma aplicação Nginx pode permanecer saudável localmente enquanto uma regra de entrada ausente no Security Group impede o acesso HTTP externo. Após validar o estado `Healthy`, a regra TCP `80` restrita ao IPv4 do operador foi removida de forma controlada. A validação independente confirmou `Failed`, com Systems Manager e Nginx saudáveis. O diagnóstico somente leitura identificou a regra ausente; a recuperação restaurou apenas essa autorização e a validação voltou a `Healthy`. Por fim, o cleanup removeu os recursos exclusivos do Lab 15 e preservou a VPC e a sub-rede compartilhadas do Lab 08.

Consulte o [Lab 15](labs/15-aws-connectivity-troubleshooting/) para os comandos, resultados, scripts e evidências.

O **Lab 14 — Utilização de disco e crescimento de logs** implementou um cenário completo de investigação e mitigação de utilização elevada de disco em uma instância Amazon EC2 administrada pelo AWS Systems Manager.

O laboratório incluiu:

- implantação de uma instância Amazon EC2 com Amazon Linux 2023;
- criação de um volume EBS `gp3` criptografado e dedicado aos logs;
- formatação do volume com `ext4`;
- montagem persistente por UUID em `/var/log/lab14`;
- administração pelo Systems Manager, sem Key Pair e sem regra de entrada para SSH;
- IMDSv2 obrigatório;
- geração controlada de arquivos de log;
- proteção por limite máximo de utilização;
- diagnóstico estruturado e somente leitura;
- análise de capacidade em bytes e consumo de inodes;
- identificação dos maiores diretórios e arquivos;
- inspeção de arquivos removidos ainda abertos;
- coleta de eventos recentes do sistema;
- mitigação por rotação, compressão e retenção;
- validação de integridade antes da remoção dos arquivos originais;
- validação independente após a mitigação;
- cleanup protegido e idempotente;
- preservação da rede compartilhada do Lab 08.

Durante o incidente controlado, a utilização do volume dedicado chegou a `85%`, ultrapassando o limite operacional de `80%` e permanecendo abaixo do limite máximo de segurança de `88%`.

O diagnóstico identificou:

- `24` arquivos de pressão;
- aproximadamente `1,50 GiB` de dados recuperáveis;
- arquivos de aproximadamente `64 MiB`;
- utilização de inodes de apenas `1%`;
- nenhum arquivo removido ainda aberto por processos;
- concentração do consumo no diretório controlado `/var/log/lab14/generated`.

A investigação confirmou que o incidente estava relacionado ao consumo da capacidade em bytes e não ao esgotamento de inodes.

A mitigação processou somente os arquivos controlados, realizou compressão temporária, validou a integridade do conteúdo e removeu os arquivos originais somente após a confirmação de sucesso.

Após a mitigação, a utilização foi reduzida de `85%` para `57%`. A validação independente confirmou o retorno ao estado `Healthy`.

O cleanup removeu:

- a instância EC2 do Lab 14;
- o volume EBS dedicado;
- o Security Group;
- o Instance Profile;
- a IAM Role e sua associação com a política do Systems Manager.

A validação pós-cleanup confirmou que nenhum recurso exclusivo do Lab 14 permaneceu ativo. A VPC e a sub-rede compartilhadas do Lab 08 foram preservadas.

Consulte o [Lab 14 — Utilização de disco e crescimento de logs](labs/14-aws-disk-utilization/) para acessar a documentação completa, os scripts e as evidências.

---

## Estrutura do repositório

| Diretório | Finalidade |
|:---:|:---:|
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
- diagnóstico antes da mitigação;
- scripts limitados ao escopo declarado;
- autorização explícita para operações destrutivas;
- proteção de credenciais e identificadores sensíveis;
- tratamento de respostas vazias e falhas esperadas;
- infraestrutura reproduzível e mudanças rastreáveis;
- preservação de recursos compartilhados;
- proteção do estado e dos planos do Terraform;
- versionamento do arquivo de dependências do Terraform;
- análise do plano antes da aplicação;
- scripts de cleanup idempotentes;
- controle de custos e cleanup documentado.

---

## Práticas demonstradas

Os laboratórios concluídos até esta etapa demonstram:

- preparação e validação de uma estação de trabalho;
- autenticação temporária na AWS por SSO;
- administração de sistemas Linux;
- usuários, grupos e permissões;
- serviços e logs com `systemd` e `journalctl`;
- inventário operacional de uma conta AWS;
- redes VPC, sub-redes, rotas e Internet Gateway;
- instâncias EC2 administradas pelo Systems Manager;
- IAM Roles e Instance Profiles;
- Security Groups com escopo controlado;
- armazenamento com Amazon EBS e Amazon S3;
- validação de integridade e recuperação de dados;
- disponibilidade com Application Load Balancer;
- health checks e distribuição de tráfego;
- introdução controlada de falhas;
- diagnóstico estruturado antes da recuperação;
- investigação de utilização elevada de disco;
- análise de capacidade e inodes;
- rotação, compressão e retenção de logs;
- investigação de perda de conectividade do Systems Manager;
- recuperação pela API do EC2 quando o SSM está indisponível;
- atualização controlada de aplicação com baseline, backup e confirmação;
- diagnóstico de configuração inválida e rollback verificado por hashes;
- backup de aplicação em S3 privado e versionado;
- restauração por VersionId com verificação de pacote e manifesto SHA-256;
- diagnóstico de perda parcial com comparação de arquivos e respostas HTTP;
- registro dos intervalos observados de recuperação e da idade do backup;
- inicialização, formatação e validação de configuração Terraform;
- configuração do provider AWS e versionamento de `.terraform.lock.hcl`;
- consulta de infraestrutura compartilhada por fontes de dados;
- provisionamento de IAM, Security Group, regras e EC2 pelo Terraform;
- análise e aplicação de plano salvo;
- inspeção de estado local e outputs;
- validação independente dos recursos AWS e da aplicação;
- verificação de plano sem mudanças após a aplicação;
- remoção pelo Terraform e validação do estado após o cleanup;
- confirmação da ausência de recursos exclusivos na AWS;
- automação com PowerShell e Bash;
- cleanup seguro e preservação de infraestrutura compartilhada.

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

Os laboratórios de preparação, operações Linux e infraestrutura AWS foram concluídos.

O módulo de operação e troubleshooting foi concluído. Os Labs 13 a 18 demonstraram aplicação indisponível, utilização elevada de disco, falha de conectividade, Systems Manager indisponível, atualização controlada e recuperação de aplicação a partir de backup versionado.

O módulo de Terraform está em andamento. O Lab 19 demonstrou o ciclo de vida de um recurso local, a aplicação de um plano salvo, a inspeção do estado e a remoção validada. O Lab 20 aplicou esse fluxo à AWS, com sete recursos gerenciados, validação independente, plano sem mudanças e cleanup verificado.

A próxima etapa prevista é o **Lab 21 — Estado remoto**, com foco em:

- configuração de armazenamento remoto para o estado do Terraform;
- controle de acesso e proteção das informações do estado;
- bloqueio para evitar operações concorrentes;
- distinção entre configuração, estado e planos;
- validação do uso do backend remoto;
- definição do ciclo de vida dos recursos que armazenam o estado.

---

## Licença

Este projeto está distribuído sob a [licença MIT](LICENSE).

---

## Repository Metrics

<p align="center">

<a href="https://info.flagcounter.com/g0hL"><img src="https://s01.flagcounter.com/count/g0hL/bg_FFFFFF/txt_000000/border_CCCCCC/columns_8/maxflags_100/viewers_0/labels_1/pageviews_1/flags_0/percent_0/" alt="Flag Counter" border="0"></a>

</p>
