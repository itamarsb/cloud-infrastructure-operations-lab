# Lab 22 — Variáveis, outputs e módulos

## Resumo

Este laboratório amplia o fluxo local do Terraform com parametrização, validação de entradas e reutilização de um módulo.

O módulo raiz utilizará duas chamadas do mesmo módulo filho. Cada chamada gerenciará um recurso integrado `terraform_data`, com parâmetros próprios e outputs expostos pelo módulo raiz.

**Estado:** em desenvolvimento. Estrutura criada; configuração e execução pendentes.

> **English summary:** Local Terraform exercise covering typed input variables, input validation, reusable child modules and root outputs. Two instances of the same module will manage built-in terraform_data resources using local state. Implementation and execution are pending.

## Objetivo

- Declarar variáveis com tipos explícitos, descrições e valores padrão.
- Rejeitar entradas incompatíveis com as regras do exercício.
- Passar parâmetros do módulo raiz para um módulo filho.
- Reutilizar o mesmo módulo em duas chamadas.
- Consultar outputs do módulo filho por meio do módulo raiz.
- Executar plano salvo, aplicação, inspeção, verificação sem mudanças e remoção.

## Escopo

O exercício utilizará estado local no workspace `default`, sem provisioners ou comandos externos.

Os dois recursos `terraform_data` registrarão dados no estado. Os componentes representam um cenário didático e não executam serviços.

Não haverá provisionamento AWS nem utilização do backend S3 do Lab 21. A execução não exige autenticação AWS.

## Pré-requisitos

- Git e Terraform disponíveis no PATH.
- Windows PowerShell 5.1.
- Repositório local em `C:\GitHub\cloud-infrastructure-operations-lab`.
- Arquivos do laboratório publicados e sincronizados antes da execução.
- Repositório sem alterações locais antes do `git pull --ff-only`.
- Conferência da versão do Terraform e do workspace.

## Organização

| Caminho | Finalidade |
|---|---|
| `README.md` | Roteiro, critérios e resultados |
| `images/` | Evidências da execução |
| `terraform/versions.tf` | Restrição de versão do módulo raiz |
| `terraform/variables.tf` | Entradas do módulo raiz |
| `terraform/main.tf` | Duas chamadas do módulo filho |
| `terraform/outputs.tf` | Resultados expostos pelo módulo raiz |
| `terraform/terraform.tfvars.example` | Exemplo de parâmetros sem dados sensíveis |
| `terraform/modules/lab-component/versions.tf` | Restrição de versão do módulo filho |
| `terraform/modules/lab-component/variables.tf` | Interface e validações do módulo filho |
| `terraform/modules/lab-component/main.tf` | Recurso integrado do componente |
| `terraform/modules/lab-component/outputs.tf` | Resultados retornados pelo componente |

Diretório de execução:

```text
C:\GitHub\cloud-infrastructure-operations-lab\labs\22-terraform-variables-outputs-modules\terraform
```

Executar os comandos Terraform no módulo raiz, não no diretório do módulo filho.

## Conceitos

| Conceito | Aplicação |
|---|---|
| Variável | Entrada declarada pela interface de um módulo |
| Tipo | Estrutura esperada para o valor recebido |
| Valor padrão | Valor utilizado quando a entrada não é fornecida |
| Validação | Regra adicional para aceitar ou rejeitar uma entrada |
| Módulo raiz | Configuração do diretório em que o Terraform é executado |
| Módulo filho | Configuração reutilizável chamada pelo módulo raiz |
| Output do filho | Valor acessível ao módulo que fez a chamada |
| Output da raiz | Valor consultável por `terraform output` |
| Estado local | Registro dos recursos gerenciados neste laboratório |

O arquivo `terraform.tfvars.example` não é carregado automaticamente. Para utilizar o exemplo, copiá-lo para `terraform.tfvars`, que permanecerá fora do Git.

## Procedimento planejado

Esta seção define a sequência da execução. Os comandos completos serão utilizados após a publicação dos arquivos Terraform.

### 1. Conferir o ambiente

Conferir o Git, atualizar com `git pull --ff-only`, verificar a presença dos arquivos e consultar a versão do Terraform.

Confirmar o workspace `default` e conferir se existe estado anterior neste diretório. Se houver recursos, identificar sua origem antes de planejar qualquer operação.

### 2. Preparar as entradas

Revisar as variáveis, seus tipos, valores padrão e regras de validação.

Copiar `terraform.tfvars.example` para `terraform.tfvars`. Conferir os valores que serão passados às duas chamadas do módulo.

As entradas do módulo filho serão fornecidas explicitamente pelo módulo raiz.

### 3. Inicializar, formatar e validar

Executar `terraform init -input=false -no-color`.

Conferir a formatação com `terraform fmt -check -diff -recursive -no-color` e validar com `terraform validate -no-color`.

A opção `-recursive` inclui os arquivos do módulo filho. Caso a formatação falhe, corrigir e revisar as mudanças antes de prosseguir.

### 4. Testar uma entrada inválida

Executar um plano com uma entrada que viole uma regra declarada nas variáveis.

Conferir o diagnóstico da validação e o código de saída `1`. Não aplicar esse plano.

Usar uma sobrescrita apenas para esse comando, preservando os valores válidos do arquivo local. A configuração rejeitada não deverá criar recursos nem alterar o estado.

### 5. Gerar e revisar o plano válido

Gerar um plano salvo em `lab22-create.tfplan`, utilizando `-input=false`, `-no-color` e `-detailed-exitcode`.

Em uma primeira execução, com estado sem recursos, o resultado esperado será:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Conferir no plano que cada chamada do módulo contém somente um recurso `terraform_data`, com os parâmetros esperados.

Usar `terraform show -no-color "lab22-create.tfplan"` para revisar o plano salvo antes da aplicação.

### 6. Aplicar e inspecionar

Aplicar somente o plano salvo e revisado.

A aplicação de um plano salvo executa as operações sem uma nova confirmação interativa.

Consultar `terraform state list`, `terraform show -no-color` e `terraform output -json`.

Confirmar dois recursos no estado, um em cada chamada do módulo. Conferir que os outputs da raiz refletem os dados retornados pelos módulos filhos.

### 7. Verificar ausência de mudanças

Executar um novo plano com as mesmas entradas válidas e `-detailed-exitcode`.

O resultado esperado será ausência de mudanças, com código de saída `0`.

| Código de saída | Significado de `plan -detailed-exitcode` |
|---|---|
| `0` | Plano concluído sem mudanças |
| `1` | Erro |
| `2` | Plano concluído com mudanças propostas |

No PowerShell, conferir `$LASTEXITCODE` imediatamente após cada comando externo. O código `2` é esperado no plano de criação e não representa erro.

### 8. Remover os recursos

Confirmar o diretório, o workspace e os dois recursos presentes no estado.

Gerar um plano de remoção salvo em `lab22-destroy.tfplan`, utilizando `terraform plan -destroy` com as mesmas entradas válidas.

Resultado esperado:

```text
Plan: 0 to add, 0 to change, 2 to destroy.
```

Revisar o plano salvo e aplicar somente após conferir seu escopo.

### 9. Validar a remoção

Confirmar que `terraform state list` termina com código `0` e não retorna recursos.

Preservar os arquivos de configuração. Não excluir o estado para simular a remoção.

Como a configuração permanece no diretório, um novo plano normal deverá propor a criação dos dois recursos novamente.

## Versionamento

| Item | Tratamento |
|---|---|
| Arquivos `.tf` e `terraform.tfvars.example` | Versionar |
| README e imagens selecionadas | Versionar |
| `terraform.tfvars` e outros valores locais `*.tfvars` | Não versionar |
| `.terraform/` | Não versionar |
| Estados `*.tfstate` e suas cópias | Não versionar |
| Planos `*.tfplan` | Não versionar |
| `.terraform.lock.hcl`, caso registre dependências externas | Versionar |

O `.gitignore` principal já contém regras para estados, planos, parâmetros locais e diretórios do Terraform.

## Resultados esperados

| Etapa | Critério esperado | Situação |
|---|---|---|
| Inicialização | Concluída no módulo raiz | Pendente |
| Formatação | Raiz e módulo filho sem diferenças | Pendente |
| Validação | Configuração válida | Pendente |
| Entrada inválida | Rejeitada com diagnóstico da regra | Pendente |
| Plano válido | Dois recursos a criar | Pendente |
| Aplicação | Dois recursos criados | Pendente |
| Estado e outputs | Compatíveis com as entradas | Pendente |
| Segundo plano | Sem mudanças; código `0` | Pendente |
| Remoção | Dois recursos removidos pelo Terraform | Pendente |
| Pós-remoção | Estado sem recursos | Pendente |

## Evidências previstas

Publicar em `images/` capturas da:

- inicialização, formatação e validação;
- rejeição da entrada inválida;
- revisão do plano com dois recursos;
- aplicação, estado e outputs;
- verificação sem mudanças;
- remoção e estado sem recursos.

Os links das imagens e os resultados observados serão adicionados após a execução.

## Critérios de conclusão

- [x] Estrutura inicial criada.
- [ ] Configuração do módulo raiz publicada.
- [ ] Módulo filho publicado.
- [ ] Exemplo de parâmetros publicado.
- [ ] Inicialização, formatação e validação concluídas.
- [ ] Entrada inválida rejeitada pela regra esperada.
- [ ] Plano válido salvo e revisado.
- [ ] Dois recursos criados.
- [ ] Estado e outputs conferidos.
- [ ] Segundo plano sem mudanças.
- [ ] Plano de remoção salvo e revisado.
- [ ] Recursos removidos e estado sem recursos.
- [ ] Evidências publicadas.
- [ ] Resultados documentados.

## Referências

- [Variáveis de entrada](https://developer.hashicorp.com/terraform/language/values/variables)
- [Bloco module](https://developer.hashicorp.com/terraform/language/block/module)
- [Recurso terraform_data](https://developer.hashicorp.com/terraform/language/resources/terraform-data)

