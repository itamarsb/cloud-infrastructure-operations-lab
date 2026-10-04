# Lab 21 — Estado remoto do Terraform

## Status

Em desenvolvimento.

A estrutura inicial foi criada. As configurações, os scripts e os procedimentos executáveis serão adicionados nas próximas etapas.

Os resultados e as evidências permanecem pendentes.

---

## Objetivo

Implementar armazenamento remoto do estado do Terraform em Amazon S3, com versionamento, proteção de acesso e bloqueio de operações concorrentes.

O laboratório demonstrará:

- provisionamento separado dos recursos do backend;
- criação de um recurso de exercício com estado local;
- migração desse estado para o backend S3;
- preservação da identidade do recurso durante a migração;
- validação do estado remoto;
- teste controlado de bloqueio;
- remoção do recurso de exercício;
- cleanup separado dos recursos do backend.

---

## Cenário

O laboratório utilizará duas configurações Terraform independentes.

| Configuração | Diretório | Estado | Responsabilidade |
|:---:|:---:|:---:|:---:|
| Bootstrap | `bootstrap/` | Local | Provisionar e remover o armazenamento do backend |
| Exercício | `terraform/` | Local inicialmente; remoto após a migração | Gerenciar um recurso `terraform_data` e validar o backend |

O bootstrap criará um bucket S3 exclusivo para o Lab 21.

O exercício utilizará um recurso `terraform_data`, permitindo observar a migração e o bloqueio do estado sem provisionar uma nova aplicação EC2.

O estado do bootstrap permanecerá local durante todo o laboratório. O bucket não armazenará o estado da configuração responsável por criá-lo.

---

## Escopo

### Recursos do backend

- bucket S3 exclusivo;
- versionamento habilitado;
- criptografia padrão SSE-S3;
- bloqueio de acesso público;
- propriedade dos objetos com `BucketOwnerEnforced`;
- política de bucket para negar requisições sem transporte seguro;
- identificação por nomes e tags do laboratório.

### Configuração do exercício

- um recurso `terraform_data`;
- workspace `default`;
- estado local antes da migração;
- backend S3 após a migração;
- chave exclusiva para o estado;
- bloqueio nativo do backend S3 com `use_lockfile = true`.

### Fora do escopo

- provisionamento de EC2;
- implantação de aplicação web;
- alterações na rede compartilhada do Lab 08;
- migração dos estados dos Labs 19 ou 20;
- alteração de recursos de outros projetos;
- adoção do backend por outros laboratórios;
- configuração de múltiplos workspaces.

---

## Ambiente de referência

| Componente | Referência |
|:---:|:---:|
| Sistema operacional | Windows 11 |
| Shell | Windows PowerShell 5.1 |
| Terraform | Versão 1.16.1 utilizada nos laboratórios anteriores |
| AWS CLI | AWS CLI v2 |
| Autenticação | AWS IAM Identity Center |
| Perfil AWS | `cloud-operations-lab` |
| Região | `us-east-1` |
| Workspace | `default` |
| Provider AWS | Dependência definida e registrada no lock do bootstrap |
| Recurso do exercício | `terraform_data` |

A versão efetivamente utilizada do provider será registrada após a inicialização do bootstrap.

---

## Organização

| Caminho | Finalidade |
|---|---|
| `README.md` | Objetivo, cenário, sequência, proteções e resultados |
| `bootstrap/` | Configuração dos recursos AWS do backend |
| `terraform/` | Configuração do recurso de exercício |
| `scripts/` | Pré-validações e verificações independentes |
| `images/` | Evidências de execução |

Os arquivos Terraform e os scripts serão adicionados durante a implementação.

---

## Conceitos demonstrados

| Elemento | Função |
|---|---|
| Configuração `.tf` | Define os recursos e o comportamento desejado |
| Estado | Registra os recursos gerenciados e seus atributos |
| Backend | Define onde o estado é armazenado |
| Plano salvo | Registra uma proposta de mudanças para aplicação |
| `.terraform.lock.hcl` | Registra as versões e os hashes dos providers |
| Objeto `.tflock` | Participa do bloqueio de operações sobre o estado no backend S3 |
| Versionamento S3 | Mantém versões anteriores dos objetos armazenados |

O lock de dependências e o bloqueio do estado têm finalidades diferentes.

O primeiro controla a seleção dos providers. O segundo coordena operações concorrentes sobre o mesmo estado.

O armazenamento remoto também não implica execução remota: os comandos Terraform deste laboratório serão executados na estação de trabalho.

---

## Autenticação e acesso

A autenticação utilizará sessões temporárias do perfil AWS SSO.

Credenciais não serão inseridas nos arquivos Terraform, nos parâmetros do backend ou na documentação.

O acesso deverá permitir:

- provisionamento e consulta dos recursos exclusivos do bootstrap;
- leitura e gravação do estado no caminho definido;
- criação, leitura e remoção do objeto de bloqueio;
- consulta das versões dos objetos para validação;
- remoção dos objetos e de suas versões durante o cleanup autorizado.

As permissões de operação do backend e as permissões de provisionamento serão avaliadas separadamente.

A existência de uma sessão SSO válida não comprova, por si só, autorização para todas essas operações.

---

## Proteções

- validação da conta e da Região antes das operações AWS;
- uso exclusivo do workspace `default`;
- configurações e estados separados para bootstrap e exercício;
- identificação explícita do bucket e da chave do estado;
- revisão dos planos antes da aplicação;
- versionamento e criptografia do bucket;
- bloqueio de acesso público;
- exigência de transporte seguro;
- cópia de segurança local antes da migração;
- conferência do recurso e de seu identificador após a migração;
- manutenção do bloqueio durante as operações;
- inventário de objetos e versões antes do cleanup;
- remoção do backend somente após encerrar sua utilização.

O teste de concorrência não utilizará `-lock=false`.

A remoção manual do objeto de bloqueio e o uso de `force-unlock` não farão parte do fluxo normal do laboratório.

---

## Proteção dos arquivos

### Arquivos versionados

- configurações Terraform;
- modelos de parâmetros sem credenciais;
- scripts PowerShell;
- documentação;
- `.terraform.lock.hcl` quando gerado para as dependências do bootstrap;
- evidências revisadas.

### Arquivos locais fora do versionamento

- estados e backups de estado;
- planos salvos;
- diretórios `.terraform/`;
- arquivos locais de parâmetros;
- configuração local do backend;
- cópias do estado obtidas para inspeção;
- arquivos temporários de diagnóstico.

Antes da execução, as regras do `.gitignore` serão verificadas para os dois diretórios Terraform.

Estados e planos podem conter informações sensíveis. Sua publicação não será utilizada como evidência.

---

## Sequência de execução

### 1. Pré-validação

- conferir o estado do repositório;
- verificar Terraform e AWS CLI;
- autenticar pelo perfil SSO;
- validar conta e Região;
- conferir os diretórios e arquivos necessários;
- verificar os estados locais existentes;
- consultar possíveis conflitos com os recursos exclusivos;
- validar as regras de proteção dos arquivos gerados.

### 2. Provisionamento do bootstrap

- inicializar a configuração;
- registrar o lock de dependências;
- conferir formatação e validade;
- gerar e revisar o plano salvo;
- aplicar somente o plano analisado;
- validar o bucket e suas proteções;
- registrar os outputs necessários ao backend.

### 3. Baseline com estado local

- inicializar a configuração do exercício com backend local;
- gerar e revisar o plano;
- criar o recurso `terraform_data`;
- registrar seu identificador e seus outputs;
- confirmar ausência de mudanças em um segundo plano;
- preservar uma cópia do estado local.

### 4. Migração para S3

- configurar o backend S3;
- definir bucket, chave, Região e bloqueio;
- executar a inicialização com migração de estado;
- revisar e confirmar a transferência apresentada pelo Terraform;
- conferir o recurso e seu identificador no backend remoto;
- validar os outputs;
- confirmar ausência de mudanças após a migração;
- verificar o objeto do estado no bucket.

A migração deverá preservar a identidade do recurso existente.

Planos gerados antes da mudança de backend não serão reutilizados após a migração.

### 5. Teste de bloqueio

O teste utilizará duas sessões sobre o mesmo backend e a mesma chave de estado.

- iniciar uma operação Terraform controlada que mantenha o bloqueio;
- confirmar que o bloqueio foi adquirido;
- executar uma segunda operação com tempo de espera limitado;
- registrar a recusa por impossibilidade de adquirir o bloqueio;
- permitir que a primeira operação termine normalmente;
- verificar a liberação do bloqueio;
- repetir a verificação após a liberação e confirmar sucesso.

Um erro de autenticação, acesso ou configuração não será aceito como evidência de bloqueio.

A conclusão do teste dependerá da observação do conflito e da operação bem-sucedida após a liberação.

### 6. Validação independente

- confirmar o backend utilizado;
- conferir bucket, chave e workspace;
- consultar o recurso gerenciado;
- comparar seu identificador com o baseline;
- validar os outputs;
- verificar versionamento e criptografia;
- conferir as proteções do bucket;
- confirmar ausência de bloqueio ativo após as operações;
- gerar um plano sem mudanças.

### 7. Remoção do exercício

- gerar um plano de remoção usando o backend remoto;
- revisar o recurso e a ação proposta;
- aplicar o plano salvo;
- confirmar ausência de recursos gerenciados no estado do exercício;
- preservar o registro final necessário à validação;
- encerrar as operações que dependem do backend.

A remoção do recurso de exercício não representa a remoção do bucket ou de todas as versões do estado.

### 8. Cleanup do backend

- confirmar que nenhuma operação Terraform utiliza o backend;
- validar identidade, propriedade e escopo do bucket;
- inventariar objetos, versões e marcadores de exclusão;
- preservar a cópia final necessária antes da exclusão;
- remover somente o conteúdo autorizado do bucket exclusivo;
- gerar e revisar o plano de remoção do bootstrap;
- aplicar o plano analisado;
- confirmar ausência do bucket;
- confirmar ausência de recursos gerenciados no estado do bootstrap;
- preservar os arquivos de configuração.

A ordem de cleanup será: exercício, conteúdo do bucket e recursos do bootstrap.

---

## Critérios de conclusão

- [ ] Pré-validação concluída.
- [ ] Bootstrap provisionado e validado.
- [ ] Lock de dependências do bootstrap registrado.
- [ ] Bucket privado, versionado e criptografado.
- [ ] Política de transporte seguro validada.
- [ ] Recurso do exercício criado com estado local.
- [ ] Identificador e outputs do baseline registrados.
- [ ] Cópia do estado local preservada antes da migração.
- [ ] Migração para S3 concluída.
- [ ] Identidade do recurso preservada.
- [ ] Estado remoto validado.
- [ ] Conflito de bloqueio observado em teste controlado.
- [ ] Operação bem-sucedida após a liberação do bloqueio.
- [ ] Plano sem mudanças confirmado.
- [ ] Recurso do exercício removido pelo Terraform.
- [ ] Estado final do exercício validado.
- [ ] Objetos, versões e marcadores exclusivos removidos.
- [ ] Recursos do bootstrap removidos.
- [ ] Validação pós-cleanup concluída.
- [ ] Arquivos de configuração preservados.
- [ ] Evidências revisadas e publicadas.

---

## Evidências previstas

| Etapa | Evidência |
|---|---|
| Pré-validação | Ferramentas, identidade e ausência de conflitos |
| Bootstrap | Plano, aplicação e proteções do bucket |
| Baseline local | Recurso, identificador, outputs e plano sem mudanças |
| Migração | Transferência do estado e identidade preservada |
| Estado remoto | Consulta pelo Terraform e objeto S3 |
| Bloqueio | Conflito entre operações e liberação posterior |
| Validação | Backend, outputs e plano sem mudanças |
| Cleanup | Remoção do exercício e do bootstrap |
| Pós-cleanup | Ausência dos recursos exclusivos e configurações preservadas |

As imagens serão adicionadas ao diretório `images/` após a execução.

Credenciais, URLs de autenticação e conteúdo integral dos estados não deverão aparecer nas evidências publicadas.

---

## Custos e limites

Os recursos AWS deste laboratório estarão concentrados no armazenamento S3 e nas requisições relacionadas ao backend.

O versionamento mantém versões anteriores que também ocupam armazenamento. O cleanup deverá considerar todas as versões e os marcadores de exclusão.

O laboratório não estabelecerá uma solução de backend compartilhado para produção. O exercício utilizará um bucket exclusivo e um ciclo de vida limitado à atividade.

A validação do bloqueio demonstrará coordenação entre operações sobre o mesmo estado. Não substituirá controles de acesso, revisão de mudanças ou proteção das credenciais.

---

## Resultados

Execução pendente.

Os resultados observados, as versões utilizadas, as evidências e a confirmação de cleanup serão registrados após a execução.

---

## Referências

- [Backend S3 — HashiCorp](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Comando terraform init — HashiCorp](https://developer.hashicorp.com/terraform/cli/commands/init)
- [Bloqueio de estado — HashiCorp](https://developer.hashicorp.com/terraform/language/state/locking)
- [Estado do Terraform — HashiCorp](https://developer.hashicorp.com/terraform/language/state)
