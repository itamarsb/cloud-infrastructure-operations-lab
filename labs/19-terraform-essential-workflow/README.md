# Lab 19 — Fluxo essencial do Terraform

## Resumo

Este laboratório introduz o fluxo de trabalho do Terraform por meio de um exercício local com o recurso integrado `terraform_data`.

O procedimento abrange inicialização, formatação, validação, planejamento, aplicação, inspeção do estado e remoção.

**Estado:** em preparação. Configuração e execução pendentes.

> **English summary:** Local Terraform workflow exercise using the built-in terraform_data resource. Covers initialization, formatting, validation, plan review, application, state inspection and destruction. Execution evidence is pending.

## Objetivo

Compreender como o Terraform compara a configuração desejada com o estado registrado e propõe as operações necessárias.

Ao final, o operador deverá conseguir:

- identificar o diretório de execução;
- inicializar uma configuração;
- conferir formatação e validade;
- interpretar um plano;
- aplicar um plano previamente analisado;
- consultar recursos e outputs no estado;
- verificar a ausência de mudanças após a aplicação;
- remover o recurso do exercício;
- distinguir remoção de recursos de exclusão dos arquivos locais.

## Escopo

O exercício utilizará um único recurso `terraform_data`, sem provisioners ou comandos externos.

Esse recurso permite registrar dados e acompanhar seu ciclo de vida no estado do Terraform. Sua criação não representa uma instância, um bucket ou outro recurso AWS.

A execução será local, sem autenticação AWS e sem provisionamento em nuvem.

A rede compartilhada do Lab 08 e os recursos de outros projetos permanecem fora do escopo.

O provisionamento AWS com Terraform será abordado no Lab 20.

## Pré-requisitos

- Git instalado.
- Terraform disponível no PATH.
- Windows PowerShell 5.1.
- Repositório local em `C:\GitHub\cloud-infrastructure-operations-lab`.
- Arquivos deste laboratório publicados e sincronizados.
- Repositório sem alterações locais antes da atualização.

A versão instalada será conferida com `terraform version` e deverá atender à restrição definida em `versions.tf`.

## Organização

| Caminho | Finalidade |
|:---:|:---:|
| `README.md` | Procedimento, critérios e resultados |
| `images/` | Evidências reais da execução |
| `terraform/versions.tf` | Restrição de versão do Terraform |
| `terraform/main.tf` | Recurso integrado do exercício |
| `terraform/outputs.tf` | Informações disponibilizadas após a aplicação |

Os arquivos Terraform serão publicados antes da execução.

O diretório de trabalho será:

```text
C:\GitHub\cloud-infrastructure-operations-lab\labs\19-terraform-essential-workflow\terraform
```

Os comandos devem ser executados nesse diretório, e não na raiz do repositório ou na pasta de outro laboratório.

## Conceitos utilizados

| Conceito | Significado neste exercício |
|:---:|:---:|
| Configuração | Arquivos `.tf` que descrevem o resultado desejado |
| Recurso | Objeto `terraform_data` acompanhado pelo Terraform |
| Estado | Registro local dos objetos gerenciados e de seus atributos |
| Plano | Operações propostas a partir da configuração e do estado |
| Aplicação | Execução das operações do plano |
| Output | Valor disponibilizado pela configuração |
| Remoção | Encerramento do recurso gerenciado por este exercício |

O estado não substitui a configuração. A configuração descreve o que deve existir; o estado registra o que o Terraform acompanha.

## Procedimento previsto

### 1. Conferir e atualizar o repositório

Na raiz do repositório:

- conferir `git status --porcelain`;
- interromper se houver alterações locais;
- executar `git pull --ff-only`;
- conferir o código de saída;
- verificar a presença dos três arquivos `.tf`;
- consultar `terraform version`.

Depois, acessar somente o diretório `terraform/` deste laboratório.

### 2. Inicializar

Executar:

```powershell
terraform init -input=false
```

Resultado esperado: inicialização concluída.

O exercício utiliza um provider integrado ao Terraform e não depende de um plugin AWS.

### 3. Conferir formatação

Executar:

```powershell
terraform fmt -check -diff
```

Resultado esperado: código de saída zero.

Se houver diferenças, revisar a saída e corrigir os arquivos antes de continuar. Uma correção com `terraform fmt` pode alterar os arquivos versionados e deve ser conferida no Git.

### 4. Validar a configuração

Executar:

```powershell
terraform validate
```

Resultado esperado: configuração válida.

Essa validação não comprova que o recurso foi criado. Ela verifica a configuração antes do planejamento e da aplicação.

### 5. Gerar e analisar o plano

Executar:

```powershell
terraform plan -input=false -out=lab19-create.tfplan
```

Inspecionar o plano salvo:

```powershell
terraform show lab19-create.tfplan
```

Para a primeira execução, o resultado esperado é:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Conferir:

- apenas um recurso `terraform_data`;
- dados correspondentes ao Lab 19;
- ausência de recursos AWS;
- ausência de alterações ou remoções inesperadas.

Se o plano divergir do esperado, interromper e investigar antes da aplicação.

### 6. Aplicar o plano analisado

Executar somente após revisar o plano:

```powershell
terraform apply -input=false lab19-create.tfplan
```

A aplicação de um plano salvo não solicita uma nova confirmação interativa. A revisão deve ocorrer antes desse comando.

Resultado esperado:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

### 7. Inspecionar estado e outputs

Executar separadamente:

```powershell
terraform state list
terraform show
terraform output
```

Conferir:

- um único recurso gerenciado;
- identificação do exercício;
- valores dos outputs compatíveis com a configuração.

Não editar manualmente o arquivo de estado.

### 8. Verificar ausência de mudanças

Executar:

```powershell
terraform plan -input=false -detailed-exitcode
```

Conferir imediatamente `$LASTEXITCODE`.

| Código | Significado |
|:---:|:---:|
| `0` | Plano concluído sem mudanças |
| `1` | Erro |
| `2` | Plano concluído com mudanças propostas |

Após a aplicação, sem alterações na configuração, o resultado esperado é código `0` e mensagem de ausência de mudanças.

O código `2` não significa falha de execução, mas exige análise das mudanças propostas.

### 9. Remover o recurso

Executar:

```powershell
terraform destroy
```

Antes de confirmar, conferir que a proposta contém somente a remoção do recurso do Lab 19.

Resultado esperado:

```text
Plan: 0 to add, 0 to change, 1 to destroy.
```

Digitar `yes` após conferir o escopo.

Ao final, o resultado esperado é:

```text
Destroy complete! Resources: 1 destroyed.
```

### 10. Validar a remoção

Executar:

```powershell
terraform state list
```

Resultado esperado: código de saída zero e nenhum recurso listado.

Os arquivos `.tf` permanecem no diretório. Por isso, um novo plano normal após o destroy proporá criar o recurso novamente.

Um plano de criação após a remoção não indica falha no cleanup.

## Arquivos locais e versionamento

| Arquivo ou diretório | Tratamento |
|---|---|
| Arquivos `.tf` | Versionar |
| `README.md` e evidências | Versionar |
| `.terraform/` | Não versionar |
| `terraform.tfstate` e backups | Não versionar |
| Planos `*.tfplan` | Não versionar |
| `.terraform.lock.hcl`, caso gerado | Versionar quando registrar dependências externas |

O `.gitignore` principal já contém regras para o diretório `.terraform/`, arquivos de estado e planos com extensão `.tfplan`.

O destroy remove o recurso gerenciado, mas pode manter arquivos locais de estado e seus backups. Esses arquivos não devem ser publicados como evidência nem adicionados ao Git.

Não excluir o estado para simular uma remoção: a remoção deve ser feita pelo Terraform e comprovada pela consulta ao estado.

## Resultados esperados

| Etapa | Critério |
|---|---|
| Inicialização | Concluída sem erro |
| Formatação | Código zero em `fmt -check` |
| Validação | Configuração válida |
| Plano inicial | Um recurso a criar |
| Aplicação | Um recurso criado |
| Inspeção | Um recurso no estado e outputs corretos |
| Segundo plano | Nenhuma mudança; código zero |
| Destroy | Um recurso removido |
| Pós-destroy | Nenhum recurso no estado |

## Evidências

As capturas serão adicionadas em `images/` após a execução, mantendo seus nomes reais.

Registrar:

- versão do Terraform;
- inicialização, formatação e validação;
- plano inicial;
- aplicação e outputs;
- consulta ao estado;
- plano sem mudanças;
- destroy e estado sem recursos.

Nenhum resultado de execução foi registrado nesta etapa.

## Limites do exercício

O laboratório demonstra o fluxo essencial do Terraform e o uso de estado local.

Não demonstra provisionamento AWS, estado remoto, colaboração entre operadores, bloqueio remoto ou detecção de drift em infraestrutura externa.

Esses assuntos serão desenvolvidos nos próximos laboratórios.

## Critérios de conclusão

- [ ] Configuração publicada.
- [ ] Versão do Terraform conferida.
- [ ] Inicialização concluída.
- [ ] Formatação conferida.
- [ ] Configuração validada.
- [ ] Plano inicial analisado.
- [ ] Aplicação concluída.
- [ ] Estado e outputs conferidos.
- [ ] Segundo plano sem mudanças.
- [ ] Recurso removido pelo Terraform.
- [ ] Estado sem recursos após o destroy.
- [ ] Evidências publicadas.
- [ ] Documentação atualizada com os resultados reais.

## Referências

- [Recurso terraform_data](https://developer.hashicorp.com/terraform/language/resources/terraform-data)
- [Fluxo de execução do Terraform](https://developer.hashicorp.com/terraform/cli/run)
- [Comando terraform plan](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Comando terraform apply](https://developer.hashicorp.com/terraform/cli/commands/apply)
- [Estado do Terraform](https://developer.hashicorp.com/terraform/language/state)
