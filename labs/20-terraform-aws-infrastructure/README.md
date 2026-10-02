# Lab 20 — Infraestrutura AWS como código

## Resumo

Este laboratório aplica o fluxo de trabalho do Terraform ao provisionamento de uma aplicação Nginx na AWS.

O escopo inclui recursos IAM, um Security Group e uma instância EC2 administrada pelo AWS Systems Manager, utilizando a rede compartilhada do Lab 08.

O procedimento abrange autenticação temporária, validação da configuração, análise de plano salvo, aplicação, inspeção do estado, testes da aplicação e remoção dos recursos exclusivos.

**Estado:** em preparação. Estrutura criada; configuração e execução pendentes.

> **English summary:** AWS infrastructure exercise using Terraform to provision IAM resources, a Security Group and an EC2 instance running Nginx. The instance will use Systems Manager for administration and the shared network from Lab 08. Configuration and execution are pending.

## Objetivo

Provisionar, validar e remover recursos AWS por meio de uma configuração Terraform, com revisão do plano, inspeção do estado e preservação da infraestrutura compartilhada.

O exercício permite:

- configurar o provider AWS;
- utilizar autenticação temporária por IAM Identity Center;
- distinguir recursos gerenciados de dependências consultadas;
- definir dependências entre IAM, segurança e EC2;
- revisar um plano antes do provisionamento;
- aplicar um plano salvo;
- consultar recursos e outputs;
- verificar a aplicação independentemente do resultado do apply;
- conferir um segundo plano sem mudanças;
- remover os recursos exclusivos pelo Terraform;
- validar a preservação da rede compartilhada.

## Escopo

### Recursos exclusivos

A configuração deverá gerenciar:

| Componente | Finalidade |
|:---:|:---:|
| IAM Role | Identidade utilizada pela instância EC2 |
| Associação de política IAM | Permissões necessárias ao Systems Manager |
| Instance Profile | Associação da IAM Role à instância |
| Security Group | Controle do tráfego da instância |
| Regras do Security Group | Entrada HTTP restrita e saída definida |
| Instância EC2 | Execução da aplicação Nginx |
| Volume root da EC2 | Sistema operacional e arquivos da aplicação |

O volume root será definido na configuração da instância, com criptografia e remoção no encerramento. Ele não deverá ser gerenciado simultaneamente como um volume independente.

### Dependências compartilhadas

A VPC e a sub-rede pública do Lab 08 serão consultadas como dependências existentes.

Esses recursos não serão declarados como recursos gerenciados pelo LAB 20 nem importados para seu estado.

Permanecem fora do escopo de alteração ou remoção:

- VPC do Lab 08;
- sub-redes compartilhadas;
- Internet Gateway;
- tabelas de rotas;
- Network ACLs;
- recursos de outros laboratórios ou projetos.

### Fora do escopo

Este laboratório não inclui:

- criação de uma nova rede VPC;
- Application Load Balancer;
- Auto Scaling;
- banco de dados;
- bucket de aplicação ou backup;
- estado remoto;
- módulos Terraform reutilizáveis;
- pipeline de execução;
- alterações manuais para simular drift.

Estado remoto, módulos, drift e validação automatizada serão abordados nos próximos laboratórios.

## Ambiente previsto

| Item | Valor |
|:---:|:---:|
| Sistema local | Windows |
| Shell | Windows PowerShell 5.1 |
| Terraform | Versão compatível com `versions.tf` |
| Provider | `hashicorp/aws` |
| Perfil AWS | `cloud-operations-lab` |
| Região | `us-east-1` |
| Workspace | `default` |
| Sistema da instância | Amazon Linux 2023 |
| Tipo da instância | `t3.micro` |
| Aplicação | Nginx |
| Administração | AWS Systems Manager |
| Estado Terraform | Local |

A versão do provider será definida na configuração e registrada no arquivo de dependências após a inicialização.

A AMI será consultada durante o planejamento. Seu identificador será registrado nos resultados da execução.

## Pré-requisitos

- LAB 19 concluído.
- Git, AWS CLI e Terraform disponíveis no PATH.
- Perfil `cloud-operations-lab` configurado para IAM Identity Center.
- Sessão SSO válida.
- Permissões para consultar a rede e gerenciar os recursos exclusivos.
- Rede compartilhada do Lab 08 disponível.
- Sub-rede pública com rota para o Internet Gateway.
- IPv4 público atual do operador identificado.
- Repositório sincronizado e sem alterações locais antes da atualização.
- Configuração Terraform e scripts de validação publicados.

A identidade AWS deverá ser conferida antes do planejamento, da aplicação e da remoção.

## Organização

| Caminho | Finalidade |
|:---:|:---:|
| `README.md` | Escopo, procedimento, critérios e resultados |
| `images/` | Evidências da execução |
| `terraform/` | Configuração de infraestrutura e inicialização da aplicação |
| `scripts/` | Verificações operacionais em PowerShell |

Diretório de execução do Terraform:

```text
C:\GitHub\cloud-infrastructure-operations-lab\labs\20-terraform-aws-infrastructure\terraform
```

Os comandos Terraform deverão ser executados nesse diretório, no workspace `default`.

O estado local do LAB 19 não será reutilizado.

## Identificação dos recursos

Os recursos exclusivos deverão utilizar nomes associados ao LAB 20 e tags de identificação:

| Tag | Valor previsto |
|:---:|:---:|
| `Project` | `cloud-infrastructure-operations-lab` |
| `Environment` | `lab` |
| `Lab` | `20` |
| `ManagedBy` | `terraform` |
| `Owner` | `itamarsb` |

A instância, o volume root e os demais recursos que suportam tags deverão ser identificados.

As tags auxiliam o inventário e a validação de propriedade. O escopo de remoção do Terraform é determinado pelos recursos gerenciados no estado do laboratório.

## Configuração de segurança

A configuração deverá incluir:

- autenticação temporária, sem credenciais gravadas nos arquivos;
- perfil e Região explícitos;
- restrição do provider à conta esperada;
- IAM Role assumida pelo serviço EC2;
- política do Systems Manager associada à role;
- Instance Profile exclusivo;
- entrada TCP `80` somente para o IPv4 público autorizado, com máscara `/32`;
- ausência de regra de entrada SSH;
- ausência de Key Pair;
- IMDSv2 obrigatório;
- volume root criptografado;
- remoção do volume root no encerramento;
- créditos de CPU em modo `standard`;
- identificação dos recursos por nomes e tags.

A saída de rede deverá permitir a instalação dos pacotes e a comunicação necessária ao Systems Manager, conforme as regras definidas na configuração.

O acesso HTTP utiliza conteúdo demonstrativo, sem credenciais ou dados sensíveis.

## Aplicação prevista

A inicialização da instância deverá:

1. instalar o Nginx;
2. publicar uma página de identificação do LAB 20;
3. criar o endpoint `/health`;
4. criar o endpoint `/version`;
5. validar a configuração do Nginx;
6. habilitar e iniciar o serviço.

Respostas esperadas:

| Endpoint | Código HTTP | Conteúdo |
|:---:|:---:|:---:|
| `/` | `200` | Página de identificação do LAB 20 |
| `/health` | `200` | `healthy` |
| `/version` | `200` | `v1` |

A criação da instância pelo Terraform não comprova que a instalação da aplicação terminou. A conclusão dependerá das verificações do serviço e das respostas HTTP.

## Procedimento previsto

### 1. Conferir o repositório

Na raiz do repositório:

- consultar o estado do Git;
- interromper se houver alterações locais;
- atualizar com `git pull --ff-only`;
- conferir o código de saída;
- verificar os arquivos da configuração e dos scripts.

### 2. Validar identidade e dependências

- autenticar pelo AWS SSO;
- consultar a identidade com AWS STS;
- confirmar conta e Região;
- identificar a VPC e a sub-rede do Lab 08;
- conferir a conectividade pública da sub-rede;
- identificar o IPv4 público atual;
- verificar conflitos com nomes e tags do LAB 20.

Se houver recursos de uma tentativa anterior, conferir o inventário e o estado antes de repetir o provisionamento.

### 3. Preparar os parâmetros locais

Definir os valores exigidos pela configuração, incluindo:

- perfil AWS;
- Região;
- conta esperada;
- VPC e sub-rede compartilhadas;
- origem HTTP autorizada.

Os parâmetros locais não deverão conter credenciais.

### 4. Inicializar e validar

Executar:

- `terraform init`;
- consulta do workspace;
- `terraform fmt -check -diff`;
- `terraform validate`.

Conferir o resultado de cada comando.

A inicialização deverá instalar o provider AWS e gerar o arquivo de dependências.

### 5. Gerar e analisar o plano

Gerar um plano salvo com `-detailed-exitcode`.

No Windows PowerShell, utilizar argumentos como strings em um array, incluindo o argumento completo de saída do plano.

Conferir:

- somente recursos exclusivos do LAB 20 a criar;
- perfil, conta e Região corretos;
- VPC e sub-rede utilizadas como dependências;
- regras de rede compatíveis com o escopo;
- configuração IAM;
- tipo da instância e AMI;
- criptografia e remoção do volume root;
- IMDSv2 obrigatório;
- nomes e tags;
- ausência de alterações ou remoções de recursos compartilhados.

O número esperado de recursos será definido após a publicação da configuração, considerando a representação das regras e associações no Terraform.

### 6. Aplicar o plano analisado

Aplicar o arquivo de plano salvo somente após sua revisão.

A aplicação de um plano salvo não solicita nova confirmação interativa.

Registrar o resultado, os recursos criados e os outputs.

### 7. Validar o ambiente

As verificações deverão conferir:

- recursos presentes no estado do LAB 20;
- nomes, tags e relações entre os recursos;
- instância EC2 em execução;
- volume root criptografado;
- IMDSv2 obrigatório;
- Instance Profile correto;
- Security Group e regras esperadas;
- instância `Online` no Systems Manager;
- conclusão da inicialização da aplicação;
- Nginx ativo;
- configuração válida em `nginx -t`;
- respostas HTTP locais;
- respostas HTTP externas;
- conteúdo de identificação e versão.

Os testes externos deverão ser executados a partir do IPv4 autorizado.

Os scripts de validação não deverão alterar recursos nem reparar automaticamente o ambiente.

### 8. Conferir o segundo plano

Executar um novo plano com a mesma configuração e os mesmos parâmetros.

Resultado esperado:

- ausência de mudanças;
- código de saída `0`.

Uma mudança proposta deverá ser analisada antes de qualquer nova aplicação.

### 9. Planejar a remoção

Antes da remoção:

- conferir identidade, Região e workspace;
- consultar os recursos no estado;
- confirmar o escopo exclusivo do LAB 20;
- gerar e inspecionar um plano de destruição salvo;
- verificar que a rede compartilhada não será removida.

### 10. Aplicar a remoção

Aplicar somente o plano de destruição analisado.

Se a operação falhar ou ficar parcial, registrar a saída e consultar o estado e o inventário antes de continuar.

A remoção deverá ser concluída pelo Terraform, mantendo o registro dos recursos sob seu gerenciamento.

### 11. Validar após a remoção

Conferir:

- ausência de recursos gerenciados ativos no estado;
- instância encerrada;
- volume root removido;
- Security Group exclusivo ausente;
- Instance Profile exclusivo ausente;
- IAM Role exclusiva ausente;
- VPC e sub-rede compartilhadas preservadas;
- arquivos de configuração preservados.

Consultas de data sources podem continuar presentes no estado. A validação deverá distinguir essas consultas dos recursos gerenciados.

## Estado e versionamento

| Arquivo ou diretório | Tratamento |
|:---:|:---:|
| Configuração `.tf` | Versionar |
| Template de inicialização | Versionar |
| Scripts de validação | Versionar |
| README e evidências | Versionar |
| `.terraform.lock.hcl` | Versionar |
| `.terraform/` | Não versionar |
| Arquivos de estado e backups | Não versionar |
| Planos salvos | Não versionar |
| Parâmetros locais de execução | Manter fora do versionamento |

O estado e os planos podem conter dados da infraestrutura e conteúdo da inicialização da instância. Eles não devem ser publicados como evidência.

Não excluir o estado para simular cleanup.

Não remover recursos manualmente apenas para fazer o estado parecer vazio.

Enquanto houver recursos gerenciados ativos, preservar o estado utilizado no provisionamento.

## Tratamento de falhas

Uma falha no apply pode ocorrer após a criação de parte dos recursos.

Nessa situação:

- registrar a saída completa;
- consultar o estado;
- conferir o inventário AWS;
- identificar quais operações foram concluídas;
- corrigir a causa;
- gerar e analisar um novo plano antes de continuar.

Uma falha nos testes da aplicação também não significa que nenhum recurso foi criado.

Problemas de acesso HTTP deverão ser investigados considerando o IPv4 autorizado, as regras do Security Group, a rede, a inicialização da instância e o serviço local.

## Custos e remoção

A instância EC2, o volume EBS e o IPv4 público podem gerar cobrança.

Os recursos exclusivos deverão permanecer ativos somente durante a execução do laboratório.

O cleanup será executado pelo Terraform e validado por consultas independentes.

## Resultados esperados

| Etapa | Critério |
|:---:|:---:|
| Identidade | Conta, perfil e Região conferidos |
| Rede compartilhada | Dependências identificadas e preservadas |
| Inicialização | Provider instalado |
| Formatação | Sem diferenças |
| Validação | Configuração válida |
| Plano inicial | Somente criações dentro do escopo |
| Aplicação | Recursos exclusivos provisionados |
| Systems Manager | Instância `Online` |
| Nginx | Serviço ativo e configuração válida |
| HTTP | Página, health e versão corretos |
| Segundo plano | Sem mudanças; código `0` |
| Remoção | Recursos exclusivos removidos |
| Pós-cleanup | Nenhum recurso gerenciado ativo; rede preservada |

## Evidências

As capturas da execução serão publicadas em `images/`.

As evidências deverão demonstrar:

- inicialização e validação;
- plano de provisionamento;
- aplicação e outputs;
- recursos gerenciados no estado;
- validação AWS, Systems Manager e aplicação;
- plano sem mudanças;
- plano de destruição;
- remoção concluída;
- validação após o cleanup.

Arquivos de estado, planos e credenciais não serão utilizados como evidências públicas.

## Resultados obtidos

Execução pendente.

Os resultados serão registrados após o provisionamento, as validações e a remoção.

## Critérios de conclusão

- [x] Estrutura inicial criada.
- [ ] Configuração Terraform publicada.
- [ ] Scripts de validação publicados.
- [ ] Identidade AWS conferida.
- [ ] Dependências compartilhadas validadas.
- [ ] Inicialização concluída.
- [ ] Formatação e configuração validadas.
- [ ] Plano de provisionamento analisado.
- [ ] Plano aplicado.
- [ ] Estado e outputs conferidos.
- [ ] Systems Manager `Online`.
- [ ] Nginx e endpoints validados.
- [ ] Segundo plano sem mudanças.
- [ ] Plano de destruição analisado.
- [ ] Recursos exclusivos removidos.
- [ ] Validação pós-cleanup concluída.
- [ ] Rede compartilhada preservada.
- [ ] Evidências publicadas.
- [ ] Resultados documentados.

## Referências

- [Provider AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Data sources do Terraform](https://developer.hashicorp.com/terraform/language/data-sources)
- [Comando terraform plan](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Comando terraform apply](https://developer.hashicorp.com/terraform/cli/commands/apply)
- [Comando terraform destroy](https://developer.hashicorp.com/terraform/cli/commands/destroy)
- [Arquivo de dependências](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- [AWS Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html)
