# Lab 23 — Mudanças e drift

## Resumo

Laboratório local de Terraform para comparar mudanças intencionais na configuração com alterações realizadas diretamente em um recurso gerenciado.

O exercício utilizará o provider `hashicorp/local` e um recurso `local_file` para gerenciar um arquivo JSON. A execução incluirá criação de um baseline, mudança controlada, introdução de drift, diagnóstico, recuperação e remoção.

**Estado:** em desenvolvimento. Estrutura inicial criada; configuração e execução pendentes.

> **English summary:** Local Terraform exercise focused on planned configuration changes and resource drift. A managed JSON file will be used to establish a baseline, apply an intentional change, introduce an external modification, inspect the resulting plan, restore the declared configuration and complete cleanup. Implementation and execution are pending.

## Objetivos

- Diferenciar configuração declarada, estado e recurso observado.
- Interpretar um plano após uma mudança intencional.
- Introduzir uma alteração controlada fora do Terraform.
- Detectar a divergência entre o arquivo existente e a configuração.
- Revisar as ações propostas antes da aplicação.
- Restaurar o conteúdo declarado.
- Validar o arquivo diretamente, além de consultar estado e outputs.
- Confirmar ausência de mudanças após a recuperação.
- Remover o recurso pelo Terraform e verificar o resultado.

## Escopo

O laboratório utilizará:

- Windows PowerShell 5.1;
- Terraform CLI;
- provider `hashicorp/local`;
- estado local;
- workspace `default`;
- um recurso `local_file`;
- um arquivo JSON exclusivo em `local-artifacts/`.

Não haverá provisionamento AWS, autenticação por SSO ou utilização do backend S3 do Lab 21.

O arquivo representará uma configuração didática de aplicação. Nenhum serviço será iniciado a partir dele.

A alteração externa ficará restrita ao arquivo gerenciado pelo LAB 23. O arquivo de estado não será editado manualmente.

## Organização

| Caminho | Finalidade |
|:---:|:---:|
| `README.md` | Roteiro, resultados e evidências |
| `.gitignore` | Exclusão dos artefatos locais do laboratório |
| `images/` | Capturas selecionadas da execução |
| `terraform/versions.tf` | Restrições de versão e declaração do provider |
| `terraform/variables.tf` | Entradas e validações |
| `terraform/main.tf` | Conteúdo declarado e recurso gerenciado |
| `terraform/outputs.tf` | Caminho e informações do recurso |
| `terraform/terraform.tfvars.example` | Exemplo de parâmetros |
| `terraform/.terraform.lock.hcl` | Versão selecionada e hashes do provider |
| `local-artifacts/` | Arquivo gerenciado e registros locais |

Os arquivos Terraform serão adicionados na etapa de implementação.

O arquivo `.terraform.lock.hcl` será gerado durante a inicialização e deverá ser versionado.

Diretório de execução:

```text
C:\GitHub\cloud-infrastructure-operations-lab\labs\23-terraform-changes-drift\terraform
```

## Conceitos

| Conceito | Aplicação no laboratório |
|:---:|:---:|
| Configuração declarada | Conteúdo que o Terraform deverá manter no arquivo |
| Estado | Registro dos atributos conhecidos do recurso gerenciado |
| Recurso observado | Arquivo que existe no sistema de arquivos |
| Baseline | Situação inicial validada e sem mudanças pendentes |
| Mudança intencional | Alteração dos parâmetros ou do código seguida de plano e aplicação |
| Drift | Alteração externa no recurso gerenciado |
| Reconciliação | Aplicação das ações necessárias para atingir a configuração declarada |
| Validação independente | Leitura do arquivo e conferência de conteúdo e hash pelo PowerShell |

Os outputs e o estado não substituem a leitura direta do arquivo. Após uma alteração externa, eles podem continuar apresentando valores registrados anteriormente.

As ações propostas dependem do comportamento do provider. Uma alteração de conteúdo poderá resultar em substituição ou recriação do recurso, conforme o cenário. A interpretação será feita a partir do plano efetivamente gerado.

## Pré-requisitos

- Git e Terraform disponíveis no PATH.
- Repositório local sincronizado.
- Configuração do laboratório publicada antes da execução.
- Acesso à internet para a instalação inicial do provider.
- Diretório e workspace conferidos.
- Ausência de recursos anteriores não identificados no estado do laboratório.
- Caminho exclusivo do arquivo gerenciado conferido antes da primeira aplicação.

## Procedimento planejado

Os comandos completos e as verificações serão fornecidos durante a execução de cada etapa.

### 1. Preparar o ambiente

Conferir o estado do repositório e sincronizar os arquivos.

Verificar a versão do Terraform, a presença dos arquivos de configuração e o caminho reservado ao recurso.

O arquivo de destino deverá estar ausente na primeira execução. Caso já exista, investigar sua origem antes de aplicar o plano.

### 2. Inicializar e validar

Inicializar o diretório Terraform e confirmar o workspace `default`.

Registrar a versão selecionada do provider no arquivo de dependências.

Conferir a formatação e validar a configuração.

### 3. Criar o baseline

Preparar os parâmetros iniciais e gerar um plano salvo.

Conferir que o plano contém somente o recurso esperado e que seu destino pertence ao laboratório.

Aplicar o plano revisado.

Consultar o estado e os outputs, ler o arquivo JSON e registrar seu conteúdo e hash SHA256.

Executar um segundo plano e confirmar ausência de mudanças.

### 4. Aplicar uma mudança intencional

Alterar um parâmetro que componha o conteúdo declarado do arquivo.

Gerar e revisar um novo plano salvo, identificando os atributos alterados e as ações propostas.

Aplicar o plano e conferir o novo conteúdo diretamente no sistema de arquivos.

Registrar o novo baseline e confirmar novamente um plano sem mudanças.

### 5. Introduzir drift

Alterar um campo do arquivo JSON diretamente pelo PowerShell.

Preservar os arquivos Terraform e os parâmetros usados na última aplicação.

Conferir que o arquivo continua sendo um JSON válido e que seu conteúdo e hash diferem do baseline.

Essa etapa representa uma alteração externa ao fluxo do Terraform.

### 6. Diagnosticar a divergência

Comparar:

- conteúdo declarado;
- valores registrados no estado e nos outputs;
- conteúdo efetivamente presente no arquivo;
- hash anterior e hash após a alteração externa.

Gerar um plano para identificar como o provider representa a divergência e quais ações o Terraform propõe.

O plano deverá ser analisado antes de qualquer correção.

### 7. Restaurar a configuração declarada

Salvar e revisar o plano de recuperação.

Confirmar o endereço do recurso e o caminho do arquivo envolvido.

Aplicar o plano para restaurar o conteúdo declarado.

Ler novamente o JSON e comparar seu conteúdo e hash com o baseline registrado após a mudança intencional.

### 8. Confirmar ausência de mudanças

Executar um novo plano com os mesmos parâmetros.

Confirmar ausência de mudanças, código de saída `0` e consistência entre configuração, estado e arquivo observado.

### 9. Remover e validar

Gerar um plano salvo de remoção e conferir seu escopo.

Aplicar o plano revisado.

Confirmar que o estado não contém recursos e que o arquivo gerenciado está ausente.

Preservar os arquivos de configuração e os registros selecionados da execução.

## Interpretação dos planos

| Código de `plan -detailed-exitcode` | Significado |
|:---:|:---:|
| `0` | Plano concluído sem mudanças |
| `1` | Erro |
| `2` | Plano concluído com mudanças propostas |

O código `2` será esperado quando houver ações propostas para criação, mudança, recuperação ou remoção.

No PowerShell, `$LASTEXITCODE` deverá ser consultado imediatamente após cada comando externo.

A aplicação de um plano salvo executa suas ações sem uma nova confirmação interativa. Por isso, cada plano será revisado antes da aplicação.

Um plano com `-refresh-only` pode ajudar a inspecionar diferenças entre o estado registrado e o recurso observado. Aplicá-lo atualiza o estado; essa operação, por si só, não restaura o conteúdo declarado no arquivo.

## Versionamento

| Item | Tratamento |
|:---:|:---:|
| Arquivos `.tf` | Versionar |
| `terraform.tfvars.example` | Versionar |
| `.terraform.lock.hcl` | Versionar |
| README, `.gitignore` e evidências selecionadas | Versionar |
| `terraform.tfvars` | Não versionar |
| `.terraform/` | Não versionar |
| Estados e cópias de estado | Não versionar |
| Planos salvos | Não versionar |
| Conteúdo de `local-artifacts/` | Não versionar |

O `.gitignore` da raiz cobre os arquivos locais do Terraform. O `.gitignore` deste laboratório exclui seu diretório `local-artifacts/`.

## Resultados esperados

| Etapa | Critério | Situação |
|:---:|:---:|:---:|
| Inicialização | Provider instalado e workspace conferido | Pendente |
| Formatação e validação | Configuração válida e sem diferenças de formatação | Pendente |
| Baseline | Um recurso criado e arquivo conferido | Pendente |
| Plano inicial de verificação | Ausência de mudanças | Pendente |
| Mudança intencional | Novo conteúdo aplicado e validado | Pendente |
| Drift | Alteração externa registrada | Pendente |
| Diagnóstico | Divergência identificada e plano interpretado | Pendente |
| Recuperação | Conteúdo declarado restaurado | Pendente |
| Plano final de verificação | Ausência de mudanças | Pendente |
| Remoção | Estado vazio e arquivo gerenciado ausente | Pendente |

## Evidências previstas

- Inicialização, versão do provider, formatação e validação.
- Criação do baseline e conferência do arquivo.
- Plano e aplicação da mudança intencional.
- Alteração externa e comparação de conteúdo e hash.
- Diagnóstico da divergência pelo Terraform.
- Recuperação e verificação do conteúdo restaurado.
- Plano sem mudanças após a recuperação.
- Remoção e validação final.

Os links serão adicionados após a execução e a publicação das capturas.

## Critérios de conclusão

- [x] Estrutura inicial criada.
- [x] Diretório de artefatos locais excluído do Git.
- [ ] Configuração Terraform publicada.
- [ ] Provider inicializado e arquivo de dependências versionado.
- [ ] Formatação e validação concluídas.
- [ ] Baseline criado e validado.
- [ ] Mudança intencional planejada, aplicada e conferida.
- [ ] Drift introduzido no arquivo exclusivo.
- [ ] Divergência diagnosticada.
- [ ] Plano de recuperação salvo e revisado.
- [ ] Conteúdo declarado restaurado e validado.
- [ ] Plano sem mudanças após a recuperação.
- [ ] Recurso removido e arquivo ausente.
- [ ] Estado final sem recursos.
- [ ] Evidências e resultados publicados.

## Referências

- [Gerenciamento de resource drift](https://developer.hashicorp.com/terraform/tutorials/state/resource-drift)
- [Recurso local_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file)
- [Comando terraform plan](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Arquivo de dependências](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
