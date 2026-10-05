# Lab 22 — Variáveis, outputs e módulos

## Resumo

Laboratório local de Terraform com variáveis tipadas, validação de entradas, reutilização de um módulo filho e outputs do módulo raiz.

O módulo raiz chama o mesmo módulo filho duas vezes: `application` e `worker`. Cada chamada gerencia um recurso integrado `terraform_data` e retorna seu identificador e seus dados.

**Estado:** concluído em 04/10/2026. Configuração validada, entrada inválida rejeitada, criação e outputs conferidos, segundo plano sem mudanças e remoção concluída com estado vazio.

> **English summary:** Completed local Terraform exercise covering typed variables, input validation, reusable child modules and root outputs. Two built-in terraform_data resources were created, inspected and removed. A subsequent plan confirmed no changes before cleanup; the final state contains no resources.

## Objetivos alcançados

- Declarar variáveis com tipos explícitos, descrições e valores padrão.
- Rejeitar uma entrada incompatível com a validação declarada.
- Passar parâmetros do módulo raiz para o módulo filho.
- Reutilizar o mesmo módulo em duas chamadas.
- Expor identificadores e dados dos componentes por outputs da raiz.
- Executar planos salvos de criação e remoção.
- Confirmar ausência de mudanças após a aplicação.
- Remover os recursos e conferir o estado vazio.

## Escopo e ambiente

Execução no Windows PowerShell, com Terraform `v1.16.1` para `windows_amd64`, estado local e workspace `default`.

O exercício utiliza o recurso integrado `terraform_data`, sem provisioners, autenticação AWS ou utilização do backend S3 do Lab 21.

Os componentes registram dados no estado. `replica_count` e `monitoring_enabled` são parâmetros didáticos: não criam réplicas de serviços nem ativam monitoramento real. Cada chamada do módulo cria um único recurso.

Diretório de execução:

```text
C:\GitHub\cloud-infrastructure-operations-lab\labs\22-terraform-variables-outputs-modules\terraform
```

Os comandos Terraform são executados no módulo raiz.

## Organização

| Caminho | Finalidade |
|:---:|:---:|
| `README.md` | Procedimento, resultados e evidências |
| `images/` | Capturas da execução |
| `terraform/versions.tf` | Restrição de versão da raiz |
| `terraform/variables.tf` | Entradas e validações da raiz |
| `terraform/main.tf` | Chamadas `application` e `worker` |
| `terraform/outputs.tf` | Outputs `component_ids` e `lab_summary` |
| `terraform/terraform.tfvars.example` | Exemplo de parâmetros |
| `terraform/modules/lab-component/versions.tf` | Restrição de versão do filho |
| `terraform/modules/lab-component/variables.tf` | Interface e validações do filho |
| `terraform/modules/lab-component/main.tf` | Recurso `terraform_data.component` |
| `terraform/modules/lab-component/outputs.tf` | Outputs `component_id` e `component_summary` |

A raiz e o módulo filho aceitam Terraform `>= 1.4.0, < 2.0.0`.

## Entradas utilizadas

O exemplo foi copiado para `terraform.tfvars`, preservado fora do Git.

```hcl
project_name       = "cloud-infrastructure-operations-lab"
environment        = "dev"
replica_count      = 2
monitoring_enabled = true

common_tags = {
  Owner   = "itamarsb"
  Purpose = "terraform-learning"
}
```

| Entrada da raiz | Tipo | Regra ou finalidade |
|:---:|:---:|:---:|
| `project_name` | `string` | De 3 a 50 caracteres; letras minúsculas, números e hífens; início com letra |
| `environment` | `string` | Aceita `dev`, `staging` ou `prod` |
| `replica_count` | `number` | Número inteiro entre 1 e 5 |
| `monitoring_enabled` | `bool` | Indicador registrado nos dados do componente |
| `common_tags` | `map(string)` | Tags comuns passadas ao módulo filho |

As variáveis não aceitam `null`. O módulo filho também valida `component_name`, com 3 a 30 caracteres no mesmo padrão de nomes.

A chamada `application` recebe `replica_count = 2` da raiz; `worker` recebe explicitamente `replica_count = 1`. Ambas recebem ambiente `dev` e `monitoring_enabled = true`.

O módulo acrescenta as tags `Project`, `Environment`, `Component`, `ManagedBy = "terraform"` e `Lab = "22"` às tags fornecidas.

## Execução e resultados

### 1. Inicialização, formatação e validação

O repositório foi sincronizado com `git pull --ff-only`. Os nove arquivos de configuração foram conferidos antes da execução.

```powershell
terraform init -input=false -no-color
terraform workspace show
terraform fmt -check -diff -recursive -no-color
terraform validate -no-color
```

Inicialização concluída, workspace `default`, formatação sem diferenças e configuração válida. Não havia arquivo de estado local no início do exercício.

### 2. Entrada inválida

```powershell
terraform plan -input=false -json -detailed-exitcode -var="replica_count=0"
```

O Terraform rejeitou a entrada com código de saída `1` e o diagnóstico esperado:

```text
replica_count deve ser um numero inteiro entre 1 e 5.
```

O teste verificou o diagnóstico em JSON e comparou o SHA256 de `terraform.tfvars` antes e depois: o arquivo permaneceu inalterado.

### 3. Plano salvo de criação

```powershell
terraform plan -input=false -no-color -detailed-exitcode -var-file=terraform.tfvars -out=lab22-create.tfplan
terraform show -no-color lab22-create.tfplan
```

Código de saída `2`, com resultado:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

A inspeção JSON confirmou exclusivamente duas ações de criação, nos endereços esperados:

```text
module.application.terraform_data.component
module.worker.terraform_data.component
```

### 4. Aplicação, estado e outputs

```powershell
terraform apply -input=false -no-color lab22-create.tfplan
terraform state list
terraform output -json
```

Dois recursos criados. O estado e os outputs foram conferidos: `component_ids` expôs os identificadores, e `lab_summary` apresentou os dados retornados pelo módulo filho.

| Componente | Réplicas registradas | Identificador observado |
|:---:|:---:|:---:|
| `application` | `2` | `9c19ca55-1571-c531-8e7f-c75ba220d24e` |
| `worker` | `1` | `4e7e9a83-1e42-84e9-2141-6077e51fb0d6` |

Os identificadores pertencem a esta execução e podem mudar em uma nova criação.

### 5. Segundo plano sem mudanças

```powershell
terraform plan -input=false -no-color -detailed-exitcode -var-file=terraform.tfvars
```

O estado continha exclusivamente os dois recursos esperados. O plano terminou com código `0`:

```text
No changes. Your infrastructure matches the configuration.
```

### 6. Plano salvo de remoção

```powershell
terraform plan -destroy -input=false -no-color -detailed-exitcode -var-file=terraform.tfvars -out=lab22-destroy.tfplan
terraform show -no-color lab22-destroy.tfplan
```

Código de saída `2`, com resultado:

```text
Plan: 0 to add, 0 to change, 2 to destroy.
```

O plano salvo foi conferido para garantir exclusivamente a remoção dos dois recursos do laboratório.

### 7. Remoção e verificação final

```powershell
terraform apply -input=false -no-color lab22-destroy.tfplan
terraform state list
```

Resultado observado:

```text
Apply complete! Resources: 0 added, 0 changed, 2 destroyed.
LAB 22: remocao concluida.
Recursos no estado: 0
Arquivos de configuracao presentes: 9
```

A consulta ao estado terminou com código `0` e sem recursos. Os nove arquivos de configuração continuaram presentes.

A remoção ocorreu pelo Terraform, sem excluir o estado para simular limpeza. Como a configuração permanece, um novo plano normal poderá propor a criação dos dois recursos novamente.

## Interpretação dos códigos de saída

| Código de `plan -detailed-exitcode` | Significado | Resultado neste laboratório |
|---|---|---|
| `0` | Plano concluído sem mudanças | Segundo plano |
| `1` | Erro | Entrada inválida rejeitada |
| `2` | Plano concluído com mudanças propostas | Planos de criação e remoção |

No PowerShell, `$LASTEXITCODE` foi conferido imediatamente após os comandos externos. O código `2` dos planos válidos foi tratado como resultado esperado.

A aplicação de um plano salvo executa as operações sem uma nova confirmação interativa; por isso, seu conteúdo foi revisado antes de cada aplicação.

## Evidências

| Etapa | Captura |
|---|---|
| Inicialização, formatação e validação | [Evidência 62](images/Clipboard_10-04-2026_62.png) |
| Entrada inválida rejeitada | [Evidência 63](images/Clipboard_10-04-2026_63.png) |
| Plano salvo de criação | [Evidência 64](images/Clipboard_10-04-2026_64.png) |
| Aplicação, estado e outputs | [Evidência 65](images/Clipboard_10-04-2026_65.png) |
| Segundo plano sem mudanças | [Evidência 66](images/Clipboard_10-04-2026_66.png) |
| Plano salvo de remoção | [Evidência 67](images/Clipboard_10-04-2026_67.png) |
| Remoção e estado vazio | [Evidência 68](images/Clipboard_10-04-2026_68.png) |

## Versionamento

| Item | Tratamento |
|---|---|
| Arquivos `.tf` e `terraform.tfvars.example` | Versionar |
| README e evidências selecionadas | Versionar |
| `terraform.tfvars` e outros valores locais `*.tfvars` | Não versionar |
| `.terraform/` | Não versionar |
| Estados `*.tfstate` e suas cópias | Não versionar |
| Planos `*.tfplan` | Não versionar |
| `.terraform.lock.hcl`, quando houver dependências externas | Versionar |

## Critérios de conclusão

- [x] Configuração da raiz e do módulo filho publicada.
- [x] Exemplo de parâmetros publicado.
- [x] Inicialização, formatação e validação concluídas.
- [x] Entrada inválida rejeitada pela regra esperada.
- [x] Arquivo local de parâmetros preservado durante o teste.
- [x] Plano de criação salvo e revisado.
- [x] Dois recursos criados; estado e outputs conferidos.
- [x] Segundo plano sem mudanças, com código `0`.
- [x] Plano de remoção salvo e revisado.
- [x] Dois recursos removidos; estado vazio confirmado.
- [x] Nove arquivos de configuração presentes após a remoção.
- [x] Sete evidências publicadas.
- [x] Resultados documentados.

## Referências

- [Variáveis de entrada](https://developer.hashicorp.com/terraform/language/values/variables)
- [Bloco module](https://developer.hashicorp.com/terraform/language/block/module)
- [Recurso terraform_data](https://developer.hashicorp.com/terraform/language/resources/terraform-data)
- [Comando plan](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Comando apply](https://developer.hashicorp.com/terraform/cli/commands/apply)
