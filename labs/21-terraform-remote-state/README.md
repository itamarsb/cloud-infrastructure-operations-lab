# Lab 21 — Estado remoto do Terraform

## Status

Concluído e validado em 04/10/2026.

O laboratório demonstrou a migração de um estado local para Amazon S3, a preservação da identidade do recurso e o bloqueio de operações concorrentes.

O cleanup foi concluído: o recurso do exercício, todas as versões e marcadores de exclusão do bucket e os seis recursos do bootstrap foram removidos. A ausência do bucket foi confirmada por consulta independente à AWS.

---

## Objetivo

Implementar armazenamento remoto do estado do Terraform em Amazon S3, com versionamento, proteção de acesso e bloqueio nativo.

O laboratório validou:

- provisionamento separado dos recursos do backend;
- criação de um recurso com estado local;
- preservação de uma cópia do estado antes da migração;
- migração do estado para S3;
- preservação do identificador e dos outputs do recurso;
- consulta independente do objeto de estado;
- recusa de uma operação concorrente por conflito de bloqueio;
- liberação do bloqueio após cancelamento controlado;
- remoção do exercício e cleanup separado do backend.

---

## Cenário

Foram utilizadas duas configurações Terraform independentes.

| Configuração | Diretório | Estado utilizado | Responsabilidade |
|---|---|---|---|
| Bootstrap | `bootstrap/` | Local durante toda a execução | Provisionar e remover o bucket e suas configurações |
| Exercício | `terraform/` | Local no baseline; S3 após a migração | Gerenciar `terraform_data.lab21` e testar o backend |

O bootstrap provisionou um bucket exclusivo para o LAB 21.

O exercício utilizou o recurso integrado `terraform_data`, sem necessidade de provisionar uma aplicação EC2.

O bucket não armazenou o estado da configuração responsável por criá-lo. Essa separação permitiu remover o backend mantendo disponível o estado local do bootstrap.

---

## Ambiente validado

| Componente | Valor utilizado |
|---|---|
| Sistema operacional | Windows 11 |
| Shell | Windows PowerShell 5.1 |
| Terraform | 1.16.1 |
| Provider AWS do bootstrap | 6.67.0 |
| Restrição do provider AWS | `~> 6.0` |
| Restrição do Terraform | `>= 1.16.1, < 1.17.0` |
| AWS CLI | v2 |
| Autenticação | AWS IAM Identity Center |
| Perfil AWS | `cloud-operations-lab` |
| Região | `us-east-1` |
| Workspace | `default` |
| Responsável | `itamarsb` |

A versão do provider e seus hashes estão registrados em `bootstrap/.terraform.lock.hcl`.

---

## Organização

| Caminho | Finalidade |
|---|---|
| `README.md` | Cenário, procedimentos, resultados e evidências |
| `bootstrap/main.tf` | Bucket S3 e configurações de proteção |
| `bootstrap/providers.tf` | Perfil, Região, conta autorizada e tags |
| `bootstrap/variables.tf` | Parâmetros e validações de entrada |
| `bootstrap/outputs.tf` | Identificação do bucket e parâmetros do backend |
| `bootstrap/versions.tf` | Versões exigidas e backend local |
| `bootstrap/.terraform.lock.hcl` | Seleção e hashes do provider AWS |
| `terraform/main.tf` | Recurso `terraform_data.lab21` |
| `terraform/outputs.tf` | Identificador e resumo do exercício |
| `terraform/versions.tf` | Versão exigida e backend S3 |
| `scripts/test-aws-terraform-remote-state-prerequisites.ps1` | Pré-validação do ambiente |
| `scripts/test-aws-terraform-state-bucket.ps1` | Validação independente do bucket |
| `images/` | Evidências publicadas |
| `local-artifacts/` | Cópias e registros locais fora do versionamento |

---

## Recursos e proteções

O bootstrap gerenciou seis recursos:

1. `aws_s3_bucket.state`
2. `aws_s3_bucket_public_access_block.state`
3. `aws_s3_bucket_ownership_controls.state`
4. `aws_s3_bucket_versioning.state`
5. `aws_s3_bucket_server_side_encryption_configuration.state`
6. `aws_s3_bucket_policy.state`

As seguintes proteções foram conferidas:

- quatro bloqueios de acesso público habilitados;
- política classificada pelo S3 como não pública;
- propriedade dos objetos com `BucketOwnerEnforced`;
- versionamento habilitado;
- criptografia padrão SSE-S3 com `AES256`;
- política `DenyInsecureTransport` para o bucket e seus objetos;
- identificação por tags do projeto, laboratório e responsável;
- restrição de conta no provider;
- workspace `default`;
- `force_destroy = false`.

O exercício utilizou uma única instância de `terraform_data.lab21`.

### Caminhos do backend

| Elemento | Padrão |
|---|---|
| Bucket | `lab21-terraform-state-<ACCOUNT_ID>-us-east-1` |
| Estado | `lab21/exercise/terraform.tfstate` |
| Bloqueio | `lab21/exercise/terraform.tfstate.tflock` |

A configuração do backend incluiu:

- `profile = "cloud-operations-lab"`;
- `region = "us-east-1"`;
- `allowed_account_ids` com a conta autorizada;
- `encrypt = true`;
- `use_lockfile = true`.

---

## Conceitos demonstrados

| Elemento | Função |
|---|---|
| Configuração `.tf` | Define os recursos e o comportamento desejado |
| Estado | Registra recursos gerenciados e seus atributos |
| Backend | Define onde o estado é armazenado |
| Plano salvo | Registra as ações propostas para aplicação |
| `.terraform.lock.hcl` | Registra versões e hashes dos providers |
| Objeto `.tflock` | Coordena operações concorrentes sobre o estado no S3 |
| Versionamento S3 | Preserva versões anteriores dos objetos |

O lock de dependências e o bloqueio do estado têm finalidades diferentes.

O armazenamento remoto do estado também não implica execução remota. Os comandos deste laboratório foram executados na estação Windows.

---

## Sequência executada

### 1. Pré-validação

Foram conferidos o ambiente, a autenticação, a conta, a Região, o workspace, os arquivos necessários e as condições iniciais do laboratório.

Estados, planos e arquivos locais do backend permaneceram fora do versionamento.

### 2. Provisionamento do bootstrap

A configuração foi inicializada, formatada e validada.

O plano salvo foi revisado antes da aplicação:

```text
Plan: 6 to add, 0 to change, 0 to destroy.
```

Após o provisionamento, o validador independente conferiu a identidade AWS, as proteções, as tags e a ausência inicial de versões e marcadores de exclusão.

A variável `expected_account_id` é obrigatória nos planos do bootstrap, inclusive nos planos de remoção.

### 3. Baseline com estado local

O exercício foi inicialmente executado com backend local.

O plano salvo propôs:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

A aplicação criou `terraform_data.lab21`.

O identificador e os outputs foram registrados. Um segundo plano confirmou ausência de mudanças.

A cópia do estado local foi comparada com o original por SHA256.

Registros locais:

- `local-artifacts/lab21-before-migration.tfstate`
- `local-artifacts/lab21-local-outputs.json`

### 4. Migração para S3

O backend do exercício foi alterado para:

```hcl
backend "s3" {}
```

Os parâmetros foram obtidos dos outputs do bootstrap e gravados no arquivo local `terraform/lab21.s3.tfbackend.json`.

A migração utilizou:

```powershell
terraform "-chdir=$ExercisePath" init `
    "-migrate-state" `
    "-backend-config=$BackendPath"
```

A transferência foi confirmada no prompt do Terraform.

Após a migração, foram conferidos:

- backend S3 inicializado;
- bucket e chave esperados;
- workspace `default`;
- bloqueio nativo habilitado;
- mesmo recurso e identificador do baseline;
- mesmos outputs;
- plano sem mudanças.

Planos criados antes da mudança de backend não foram reutilizados após a migração.

### 5. Validação independente do estado remoto

A consulta `head-object` confirmou que o objeto inicial do estado remoto apresentava:

| Atributo | Resultado |
|---|---|
| Chave | `lab21/exercise/terraform.tfstate` |
| Tamanho | 2.625 bytes |
| Criptografia | `AES256` |
| VersionId | Presente e válido |

Também foi confirmada a ausência de um objeto `.tflock` ativo após as operações.

### 6. Teste controlado de bloqueio

O teste foi realizado em dois terminais sobre o mesmo backend.

No terminal A, foi iniciada uma aplicação interativa com substituição proposta do recurso:

```powershell
terraform "-chdir=.\labs\21-terraform-remote-state\terraform" apply `
    "-replace=terraform_data.lab21" `
    "-lock=true" `
    "-input=true" `
    "-auto-approve=false"
```

A operação ficou aguardando resposta no prompt de aprovação.

Enquanto esse prompt permanecia aberto, o terminal B confirmou a existência do objeto `.tflock` no S3 e executou:

```powershell
terraform "-chdir=.\labs\21-terraform-remote-state\terraform" plan `
    "-input=false" `
    "-lock-timeout=5s" `
    "-no-color"
```

A segunda operação foi recusada com:

```text
Error acquiring the state lock
StatusCode: 412
PreconditionFailed
Operation: OperationTypeApply
```

No terminal A, a resposta `no` cancelou a aplicação e liberou o bloqueio.

Depois da liberação, um novo plano foi executado com sucesso, sem mudanças e com o identificador original preservado.

A substituição proposta não foi aplicada.

Uma tentativa anterior com `terraform console` não apresentou objeto `.tflock` ativo no ambiente observado. Essa tentativa foi tratada como diagnóstico; a comprovação do bloqueio veio da aplicação interativa aguardando aprovação.

O teste não utilizou `-lock=false`, exclusão manual de bloqueio ativo ou `force-unlock`.

### 7. Remoção do exercício

O plano de remoção foi gerado usando o backend remoto:

```text
Plan: 0 to add, 0 to change, 1 to destroy.
```

Após a revisão, o plano salvo foi aplicado:

```text
Apply complete! Resources: 0 added, 0 changed, 1 destroyed.
```

Foram confirmados:

- ausência de recursos no estado do exercício;
- remoção dos outputs;
- preservação da cópia final em `local-artifacts/lab21-after-destroy.tfstate`.

### 8. Limpeza do conteúdo do bucket

O inventário completo identificou:

| Tipo | Quantidade |
|---|---:|
| Versões do objeto de estado | 2 |
| Versões antigas do objeto de bloqueio | 6 |
| Marcadores de exclusão do bloqueio | 6 |
| Total | 14 |

Somente as chaves do estado e do bloqueio do LAB 21 estavam presentes.

O inventário e a solicitação de exclusão foram preservados localmente:

- `local-artifacts/lab21-before-bucket-cleanup.json`
- `local-artifacts/lab21-delete-versions.json`

Os 14 itens foram excluídos por chave e `VersionId`.

A resposta foi conferida quanto a erros individuais. Uma nova consulta confirmou ausência de versões e marcadores de exclusão.

### 9. Remoção do bootstrap

Com o bucket vazio, suas proteções e propriedade foram novamente validadas.

O plano salvo propôs:

```text
Plan: 0 to add, 0 to change, 6 to destroy.
```

Após a revisão, a aplicação concluiu:

```text
Apply complete! Resources: 0 added, 0 changed, 6 destroyed.
```

A validação final confirmou:

- nenhum recurso gerenciado no estado local do bootstrap;
- outputs removidos;
- cópia final preservada em `local-artifacts/lab21-bootstrap-after-destroy.tfstate`;
- bucket ausente na listagem da conta AWS autenticada.

---

## Estado atual e reprodução

Os recursos AWS do LAB 21 foram removidos. Os arquivos de configuração e as evidências permanecem no repositório.

A configuração versionada do exercício está com backend S3, representando a etapa posterior à migração.

Para repetir o laboratório desde o baseline:

1. Conferir e separar os estados e artefatos locais da execução anterior.
2. Provisionar novamente o bootstrap com a conta autorizada.
3. Configurar o exercício com backend local antes de criar o baseline.
4. Criar o recurso, registrar os outputs e preservar a cópia do estado.
5. Alterar o backend do exercício para S3.
6. Inicializar com `-migrate-state` e conferir a identidade do recurso.
7. Executar o teste de bloqueio e as validações.
8. Realizar o cleanup na ordem documentada.

Não utilizar `init -reconfigure` como substituto da migração do estado existente.

A configuração S3 exige um bucket disponível. Após o cleanup, novas operações no exercício dependem da preparação de um novo ciclo do laboratório.

---

## Proteção dos arquivos

### Arquivos versionados

- configurações Terraform;
- scripts PowerShell;
- documentação;
- lock de dependências do bootstrap;
- evidências revisadas.

### Arquivos locais fora do versionamento

- estados e backups;
- planos salvos;
- diretórios `.terraform/`;
- parâmetros locais;
- configuração local do backend;
- inventários e solicitações de cleanup;
- registros em `local-artifacts/`.

Estados e planos podem conter informações sensíveis. O conteúdo integral desses arquivos não foi utilizado como evidência publicada.

Os registros JSON locais foram gravados em UTF-8 sem BOM.

Nos comandos PowerShell, os argumentos com `=` foram passados como strings, inclusive por arrays, para evitar problemas de interpretação.

---

## Critérios de conclusão

- [x] Pré-validação concluída.
- [x] Bootstrap provisionado e validado.
- [x] Lock de dependências do bootstrap registrado.
- [x] Bucket privado, versionado e criptografado.
- [x] Política de transporte seguro validada.
- [x] Recurso do exercício criado com estado local.
- [x] Identificador e outputs do baseline registrados.
- [x] Cópia do estado local preservada antes da migração.
- [x] Migração para S3 concluída.
- [x] Identidade do recurso preservada.
- [x] Estado remoto validado.
- [x] Conflito de bloqueio observado em teste controlado.
- [x] Operação bem-sucedida após a liberação do bloqueio.
- [x] Plano sem mudanças confirmado.
- [x] Recurso do exercício removido pelo Terraform.
- [x] Estado final do exercício validado.
- [x] Objetos, versões e marcadores exclusivos removidos.
- [x] Recursos do bootstrap removidos.
- [x] Validação pós-cleanup concluída.
- [x] Arquivos de configuração preservados.
- [x] Evidências publicadas.

---

## Evidências

As evidências estão disponíveis em `images/`. A seleção abaixo apresenta as principais etapas concluídas.

| Etapa | Evidência |
|---|---|
| Aplicação do bootstrap | [Criação dos recursos](images/Clipboard_10-04-2026_42.png) |
| Plano do baseline local | [Criação do exercício](images/Clipboard_10-04-2026_44.png) |
| Baseline local | [Aplicação, identificador e cópia do estado](images/Clipboard_10-04-2026_45.png) |
| Migração | [Transferência para S3 e validação](images/Clipboard_10-04-2026_46.png) |
| Objeto remoto | [Versionamento, criptografia e ausência de bloqueio ativo](images/Clipboard_10-04-2026_47.png) |
| Bloqueio concorrente | [Objeto de bloqueio e recusa da segunda operação](images/Clipboard_10-04-2026_52.png) |
| Liberação do bloqueio | [Plano sem mudanças e identificador preservado](images/Clipboard_10-04-2026_53.png) |
| Plano de remoção do exercício | [Uma remoção proposta](images/Clipboard_10-04-2026_54.png) |
| Remoção do exercício | [Estado final vazio e cópia preservada](images/Clipboard_10-04-2026_55.png) |
| Inventário do bucket | [Versões e marcadores de exclusão](images/Clipboard_10-04-2026_56.png) |
| Limpeza do conteúdo | [14 exclusões e bucket vazio](images/Clipboard_10-04-2026_57.png) |
| Plano de remoção do bootstrap | [Seis remoções propostas](images/Clipboard_10-04-2026_60.png) |
| Cleanup final | [Seis recursos removidos e bucket ausente](images/Clipboard_10-04-2026_61.png) |

As capturas de tentativas e diagnósticos também permanecem no diretório. Os resultados aceitos como comprovação são os associados às etapas concluídas acima.

---

## Custos e limites

Os recursos AWS deste laboratório ficaram concentrados no armazenamento S3 e nas requisições relacionadas ao backend.

O versionamento preservou versões anteriores do estado e do bloqueio. Por isso, o cleanup considerou tanto versões de objetos quanto marcadores de exclusão.

O laboratório utilizou um bucket exclusivo e um ciclo de vida limitado à atividade. Uma adoção em produção exige definição própria de permissões, retenção, recuperação e governança.

O bloqueio coordena operações sobre o mesmo estado. Ele não substitui controles de acesso ou revisão dos planos.

---

## Resultados

| Validação | Resultado |
|---|---|
| Bootstrap | Seis recursos provisionados e validados |
| Baseline | Um recurso criado com estado local |
| Migração | Estado transferido para S3 |
| Identidade | Identificador e outputs preservados |
| Convergência | Planos sem mudanças antes e depois da migração |
| Objeto remoto | VersionId válido e criptografia AES256 |
| Concorrência | Segunda operação recusada por conflito de bloqueio |
| Liberação | Aplicação cancelada e operação seguinte bem-sucedida |
| Exercício | Recurso removido e estado final preservado |
| Conteúdo do bucket | 14 versões e marcadores excluídos |
| Bootstrap | Seis recursos removidos |
| Pós-cleanup | Bucket ausente na conta AWS |

A execução demonstrou a separação entre o ciclo de vida do backend e o ciclo de vida dos recursos que utilizam seu estado.

---

## Referências

- [Backend S3 — HashiCorp](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Comando terraform init — HashiCorp](https://developer.hashicorp.com/terraform/cli/commands/init)
- [Comando terraform plan — HashiCorp](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Comando terraform apply — HashiCorp](https://developer.hashicorp.com/terraform/cli/commands/apply)
- [Bloqueio de estado — HashiCorp](https://developer.hashicorp.com/terraform/language/state/locking)
- [Estado do Terraform — HashiCorp](https://developer.hashicorp.com/terraform/language/state)
- [Listagem de versões — AWS CLI](https://docs.aws.amazon.com/cli/latest/reference/s3api/list-object-versions.html)
- [Exclusão de versões — AWS CLI](https://docs.aws.amazon.com/cli/latest/reference/s3api/delete-objects.html)
