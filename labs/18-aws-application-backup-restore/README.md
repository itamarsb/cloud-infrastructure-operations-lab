# Lab 18 — Backup e restauração de aplicação na AWS

## Resumo

Este laboratório exercitará a recuperação de uma aplicação Nginx após uma perda controlada de arquivos ativos. O fluxo prevê registrar um baseline saudável, criar um backup verificável em um bucket Amazon S3 exclusivo, reproduzir uma falha parcial, investigar o estado da aplicação, restaurar uma versão específica do backup e validar o serviço local e externamente.

**Estado:** planejado; scripts e execução ainda não concluídos.

> **English summary:** Practice application recovery after controlled data loss. Capture a verifiable, versioned S3 backup; diagnose a partial web failure; restore the selected object version; verify file integrity and HTTP behavior; and remove lab-specific resources.

## Relação com os laboratórios anteriores

O [Lab 11](../11-aws-storage-recovery/) copiou um arquivo de teste entre EBS e S3 e confirmou sua integridade em um diretório de restauração. O Lab 18 terá como objeto uma **aplicação em funcionamento**: seus arquivos serão recuperados nos caminhos ativos e o resultado será comprovado por hashes e respostas HTTP. O [Lab 17](../17-aws-controlled-update/) tratou de mudança e rollback de versão; aqui o gatilho será a perda de arquivos após um backup independente.

## Objetivos

- Registrar o estado inicial do serviço e os hashes dos arquivos protegidos.
- Criar um pacote de backup com manifesto de integridade e enviá-lo a um bucket S3 privado e versionado.
- Registrar a chave, o `VersionId` e o SHA-256 do pacote antes de introduzir a falha.
- Simular a perda apenas de arquivos ativos pertencentes ao Lab 18.
- Diagnosticar separadamente o serviço, o endpoint de saúde, as páginas afetadas e a disponibilidade do backup.
- Restaurar explicitamente a versão registrada do objeto, validar o pacote antes de substituir arquivos e comparar os hashes finais.
- Medir o tempo observado entre a falha controlada e a recuperação validada.
- Remover os recursos exclusivos sem alterar a rede compartilhada do Lab 08 ou recursos de outros projetos.

## Arquitetura prevista

| Componente | Uso |
|:---|:---|
| VPC e sub-rede do Lab 08 | Rede compartilhada, somente reutilizada |
| Amazon EC2 com Amazon Linux 2023 | Instância exclusiva com Nginx e arquivos da aplicação |
| AWS Systems Manager | Execução dos procedimentos sem entrada SSH |
| Security Group exclusivo | HTTP TCP `80` limitado ao IPv4 público do operador; sem entrada SSH |
| IAM Role e Instance Profile exclusivos | Systems Manager e acesso limitado aos objetos de backup do Lab 18 |
| Bucket S3 exclusivo | Backup privado, bloqueio de acesso público, SSE-S3 e versionamento |
| Manifesto SHA-256 | Verificação dos arquivos antes e depois da restauração |

O bucket e a instância existirão apenas durante a execução. O laboratório não usará o bucket do Lab 11 nem a instância removida do Lab 17. O endereço HTTP e o CIDR autorizado serão descobertos e validados durante a implantação.

## Estrutura prevista

```text
labs/18-aws-application-backup-restore/
├── README.md
├── images/
│   └── .gitkeep
├── policies/
│   ├── ec2-ssm-trust-policy.json
│   └── s3-application-backup-policy-template.json
└── scripts/
    ├── deploy-aws-application-backup-restore.ps1
    ├── test-aws-application-backup-restore.ps1
    ├── create-aws-application-backup.ps1
    ├── invoke-aws-application-data-loss.ps1
    ├── diagnose-aws-application-data-loss.ps1
    ├── restore-aws-application-backup.ps1
    └── remove-aws-application-backup-restore.ps1
```

| Script | Responsabilidade prevista |
|:---|:---|
| `deploy-aws-application-backup-restore.ps1` | Validar pré-requisitos, criar recursos exclusivos, publicar a aplicação e registrar o baseline |
| `test-aws-application-backup-restore.ps1` | Validar sem mutações os estados `Baseline`, `BackedUp`, `DataLoss` e `Restored` |
| `create-aws-application-backup.ps1` | Criar o pacote, verificar o upload e registrar chave, `VersionId` e hash |
| `invoke-aws-application-data-loss.ps1` | Introduzir uma perda limitada aos arquivos ativos definidos para o teste |
| `diagnose-aws-application-data-loss.ps1` | Coletar diagnóstico sem alterar a instância ou o backup |
| `restore-aws-application-backup.ps1` | Recuperar a versão registrada, validar integridade e restaurar os arquivos ativos |
| `remove-aws-application-backup-restore.ps1` | Apagar versões do bucket e remover somente recursos exclusivos após conferir sua propriedade |

Nenhum nome de captura de tela está reservado. As evidências serão vinculadas após sua publicação em `images/`.

## Arquivos protegidos e falha controlada

O escopo do backup será limitado a `index.html`, `health`, `version` e ao arquivo de configuração Nginx exclusivo do Lab 18. O pacote conterá um manifesto SHA-256 para esses quatro arquivos. Os caminhos definitivos serão documentados quando os scripts forem implementados.

A falha removerá somente `index.html` e `version` do diretório ativo. O endpoint `/health` poderá continuar respondendo, enquanto a página principal e `/version` deixarão de atender aos critérios esperados. Essa diferença mostrará por que a validação deve incluir o conteúdo da aplicação, além da disponibilidade do processo.

O diagnóstico confirmará os arquivos ausentes e registrará o estado do Nginx, os códigos HTTP e a versão do objeto de backup. A restauração fará download da versão específica registrada, validará o hash do pacote e seu manifesto em uma área temporária, conferirá os caminhos permitidos e somente então substituirá os arquivos ativos. A configuração Nginx será testada antes de qualquer recarga necessária.

## Sequência de execução

1. Verificar repositório limpo, sessão AWS SSO, conta, Região, rede compartilhada e IPv4 público atual.
2. Implantar EC2, IAM, Security Group e bucket exclusivos; aguardar Nginx e Systems Manager ficarem disponíveis.
3. Validar `Baseline`: serviço ativo, configuração válida, `/health`, `/version` e página principal corretos.
4. Após habilitar o versionamento, respeitar a janela de propagação recomendada pela AWS; criar e validar o backup, registrar a versão do objeto e confirmar `BackedUp`.
5. Introduzir a perda controlada e confirmar `DataLoss`.
6. Executar o diagnóstico somente leitura e registrar as evidências antes da restauração.
7. Restaurar o pacote verificado e confirmar `Restored` por hashes, configuração Nginx e HTTP local e externo.
8. Registrar o tempo observado de recuperação e o intervalo entre backup e falha.
9. Remover os recursos exclusivos e verificar que a VPC e a sub-rede do Lab 08 continuam disponíveis.

## Critérios de validação

| Estado | Critérios esperados |
|:---|:---|
| `Baseline` | Nginx e configuração válidos; arquivos protegidos presentes; página, `/health` e `/version` respondem conforme o baseline |
| `BackedUp` | Baseline preservado; bucket privado e versionado; objeto recuperável por `VersionId`; hash do pacote e manifesto conferidos |
| `DataLoss` | `index.html` e `version` ausentes; falha observável nos respectivos endpoints; `/health` e Nginx ainda ativos; backup preservado |
| `Restored` | Quatro arquivos ativos conferem com o manifesto; configuração válida; página, `/health` e `/version` voltam ao resultado esperado |
| Pós-cleanup | Recursos exclusivos ausentes; VPC e sub-rede compartilhadas preservadas |

Se o estado observado divergir, a execução deverá parar para diagnóstico. Um comando do Systems Manager que falhar ou perder sua resposta exigirá verificação do `CommandId` e do estado real antes de qualquer repetição.

## Proteções e limites

- Todas as operações AWS usarão o perfil `cloud-operations-lab` e a Região `us-east-1`, com validação da conta esperada.
- A simulação de perda e o cleanup exigirão parâmetros explícitos de confirmação.
- Somente arquivos e recursos identificados como pertencentes ao Lab 18 poderão ser modificados ou removidos.
- O teste de estado e o diagnóstico serão somente leitura.
- A política S3 da instância será limitada ao bucket e às chaves de backup do laboratório, incluindo a permissão necessária para ler uma versão específica.
- A IAM Role da instância não terá permissão para excluir versões do backup; a remoção ocorrerá apenas pelo procedimento de cleanup, após a validação de propriedade.
- A restauração usará o `VersionId` registrado, sem depender de qual objeto é o mais recente.
- O bucket será esvaziado de versões e marcadores de exclusão antes de sua remoção.
- Não serão criados NAT Gateway, Elastic IP, Load Balancer, Key Pair ou regra de entrada SSH.

## Critérios de conclusão

- [ ] Infraestrutura exclusiva implantada e baseline validado.
- [ ] Backup criado, versionado e conferido por SHA-256.
- [ ] Perda controlada reproduzida e diagnóstico coletado.
- [ ] Versão registrada restaurada com integridade confirmada.
- [ ] Respostas HTTP locais e externas recuperadas.
- [ ] Tempos observados de backup, falha e recuperação registrados.
- [ ] Evidências reais publicadas em `images/`.
- [ ] Recursos exclusivos removidos e rede compartilhada preservada.

## Referências

- [AWS Systems Manager Run Command](https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html)
- [Recuperar uma versão específica de objeto no Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/RetrievingObjectVersions.html)
- [AWS CLI `s3api get-object`](https://docs.aws.amazon.com/cli/latest/reference/s3api/get-object.html)
- [Habilitar versionamento em buckets S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/manage-versioning-examples.html)
