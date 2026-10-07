# Lab 24 — Validação automatizada

## Resumo

Laboratório de integração contínua para verificar automaticamente configurações Terraform por meio do GitHub Actions.

O pipeline verificará a formatação, inicializará as dependências necessárias e validará as configurações dos Labs 22 e 23.

A execução incluirá uma configuração válida, falhas controladas em uma branch de teste, análise dos resultados e confirmação de sucesso após a correção.

**Estado:** em desenvolvimento. Estrutura inicial criada; workflow e execução pendentes.

> **English summary:** Terraform continuous integration exercise using GitHub Actions. The workflow will check formatting, initialize required dependencies and validate the configurations from Labs 22 and 23. Controlled failures will demonstrate detection and recovery. Workflow implementation and execution are pending.

## Objetivos

- Automatizar verificações de configuração Terraform.
- Definir explicitamente os diretórios verificados.
- Conferir formatação com `terraform fmt -check`.
- Preparar dependências para `terraform validate`.
- Utilizar o arquivo de dependências versionado quando presente.
- Executar as verificações em um ambiente independente da estação local.
- Identificar a etapa responsável por uma falha.
- Demonstrar detecção de formatação incorreta.
- Demonstrar detecção de configuração inválida.
- Corrigir as falhas e confirmar o retorno ao sucesso.
- Registrar resultados e evidências do pipeline.

## Escopo

| Item | Definição |
|:---:|:---:|
| Plataforma | GitHub Actions |
| Ferramenta | Terraform CLI |
| Configuração do Lab 22 | Variáveis, outputs e módulo filho local |
| Configuração do Lab 23 | Recurso `local_file` e provider `hashicorp/local` |
| Verificações | Formatação, inicialização e validação |
| Provisionamento | Fora do escopo |
| Credenciais AWS | Não necessárias |
| Estado local dos laboratórios | Não utilizado pelo pipeline |

Os diretórios verificados serão:

```text
labs/22-terraform-variables-outputs-modules/terraform
labs/23-terraform-changes-drift/terraform
```

O workflow não executará `terraform apply` ou `terraform destroy`.

Os estados e arquivos `terraform.tfvars` locais não serão enviados ao pipeline.

## Organização

| Caminho | Finalidade |
|:---:|:---:|
| `README.md` | Escopo, procedimento, resultados e evidências |
| `images/` | Capturas selecionadas das execuções |
| `../../.github/workflows/lab24-terraform-validation.yml` | Workflow a ser implementado |

As configurações Terraform permanecerão nos diretórios dos Labs 22 e 23. Não haverá duplicação desses arquivos no LAB 24.

O workflow deverá ficar em `.github/workflows/`, na raiz do repositório.

## Conceitos

| Conceito | Aplicação no laboratório |
|---|---|
| Integração contínua | Verificação automática das alterações no repositório |
| Workflow | Definição dos eventos, jobs e etapas |
| Job | Unidade de execução das verificações |
| Matriz | Execução das mesmas verificações em diretórios distintos |
| Formatação | Conferência do padrão de escrita dos arquivos Terraform |
| Inicialização | Preparação dos módulos e providers necessários |
| Validação | Verificação da consistência da configuração |
| Falha controlada | Alteração temporária para comprovar a detecção |
| Evidência | Registro da execução e da etapa que aprovou ou rejeitou a alteração |

A aprovação dessas verificações não demonstra que uma infraestrutura foi provisionada ou que uma aplicação está saudável.

Os resultados representarão o escopo dos comandos executados pelo workflow.

## Pré-requisitos

- Configurações dos Labs 22 e 23 publicadas.
- Arquivo de dependências do Lab 23 versionado.
- GitHub Actions disponível no repositório.
- Permissão para criar uma branch e um pull request de teste.
- Arquivos de estado, planos e parâmetros locais excluídos do Git.

## Procedimento planejado

### 1. Implementar o workflow

Definir:

- eventos de execução;
- filtros de caminhos;
- permissões necessárias;
- versão do Terraform;
- diretórios da matriz;
- comandos e ordem das verificações.

A execução manual também será prevista para facilitar a demonstração.

### 2. Verificar a formatação

Executar `terraform fmt -check -diff -recursive` em cada diretório selecionado.

Uma diferença de formatação deverá produzir falha na etapa correspondente.

O pipeline deverá conferir os arquivos sem reformatá-los automaticamente.

### 3. Inicializar e validar

Inicializar os diretórios sem configurar um backend operacional.

No Lab 23, utilizar o arquivo de dependências versionado e impedir sua alteração durante a inicialização.

Executar `terraform validate` após preparar módulos e providers.

### 4. Registrar uma execução válida

Executar o workflow com as configurações válidas.

Conferir os resultados dos dois diretórios e registrar as etapas concluídas.

### 5. Demonstrar falha de formatação

Criar uma branch de teste e introduzir uma diferença controlada de formatação.

Abrir um pull request e conferir a rejeição pelo pipeline.

Registrar o arquivo alterado, a etapa responsável e a mensagem apresentada.

Corrigir a formatação e confirmar nova execução bem-sucedida.

### 6. Demonstrar falha de validação

Na branch de teste, introduzir uma configuração inválida que permaneça corretamente formatada.

Conferir que a formatação passa e que a validação rejeita a configuração.

Registrar a mensagem e corrigir a alteração.

### 7. Confirmar o resultado final

Confirmar sucesso nos dois diretórios após as correções.

Encerrar o pull request de teste e remover a branch temporária após conferir que as configurações originais foram restauradas.

Publicar os resultados e as evidências.

## Resultados esperados

| Etapa | Critério | Situação |
|---|---|---|
| Workflow | Eventos e diretórios definidos | Pendente |
| Execução válida | Labs 22 e 23 aprovados | Pendente |
| Formatação incorreta | Falha detectada na etapa de formatação | Pendente |
| Correção da formatação | Retorno ao sucesso | Pendente |
| Configuração inválida | Falha detectada na etapa de validação | Pendente |
| Correção da configuração | Retorno ao sucesso | Pendente |
| Encerramento | Branch de teste removida e configurações preservadas | Pendente |

## Evidências previstas

- Workflow publicado.
- Execução válida nos dois diretórios.
- Falha controlada de formatação.
- Execução após a correção da formatação.
- Falha controlada de validação.
- Execução final bem-sucedida.
- Encerramento do pull request de teste.

Os links serão adicionados após a execução e a publicação das capturas.

## Critérios de conclusão

- [x] Estrutura inicial criada.
- [x] Escopo dos diretórios definido.
- [ ] Workflow implementado e publicado.
- [ ] Formatação verificada automaticamente.
- [ ] Dependências inicializadas.
- [ ] Configurações validadas.
- [ ] Execução válida registrada nos dois diretórios.
- [ ] Falha de formatação detectada e corrigida.
- [ ] Falha de validação detectada e corrigida.
- [ ] Execução final bem-sucedida.
- [ ] Configurações originais preservadas.
- [ ] Pull request de teste encerrado.
- [ ] Branch temporária removida.
- [ ] Resultados e evidências publicados.
