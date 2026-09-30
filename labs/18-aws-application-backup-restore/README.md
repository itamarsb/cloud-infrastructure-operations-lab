# Lab 18 — Backup e restauração de aplicação na AWS

## Resumo

Este laboratório demonstrou a recuperação de uma aplicação Nginx após a perda controlada de dois arquivos ativos. O backup foi armazenado em um bucket Amazon S3 privado e versionado, recuperado pelo `VersionId` registrado e validado por SHA-256 e manifesto antes da restauração.

**Estado:** concluído, com execução, restauração e cleanup validados em 30/09/2026. Os recursos exclusivos foram removidos; a VPC e a sub-rede compartilhadas do Lab 08 foram preservadas.

> **English summary:** Completed application recovery after controlled data loss. A private, versioned S3 backup was verified and restored using its recorded object version. File hashes and local/external HTTP checks confirmed recovery. Lab-specific resources were removed while preserving the shared network.

## Resultado demonstrado

- Baseline v1 saudável registrado com hashes de quatro arquivos.
- Pacote de backup enviado ao S3 e baixado pela versão registrada para conferir sua integridade.
- Perda limitada a `index.html` e `version`, produzindo HTTP 404 em `/` e `/version`.
- Nginx ativo e `/health` saudável durante a falha parcial.
- Dois arquivos recuperados; os quatro hashes finais coincidiram com o baseline.
- HTTP 200 e conteúdo esperado confirmados local e externamente após a recuperação.
- Cleanup concluído, incluindo EC2, volume root, Security Group, bucket, Instance Profile e IAM Role exclusivos.

## Relação com os laboratórios anteriores

O [Lab 11](../11-aws-storage-recovery/) verificou a recuperação de um arquivo de teste entre EBS e S3. Neste laboratório, a recuperação ocorreu nos caminhos ativos de uma aplicação e foi comprovada também por respostas HTTP.

O [Lab 17](../17-aws-controlled-update/) exercitou mudança e rollback de versão. No Lab 18, o gatilho foi a exclusão de arquivos após a criação de um backup verificável.

## Arquitetura utilizada

| Componente | Uso |
|---|---|
| VPC e sub-rede do Lab 08 | Rede compartilhada reutilizada |
| EC2 `t3.micro` com Amazon Linux 2023 | Instância exclusiva com Nginx |
| AWS Systems Manager Run Command | Execução remota sem entrada SSH |
| Security Group exclusivo | HTTP TCP 80 limitado ao IPv4 público do operador em `/32` |
| IAM Role e Instance Profile exclusivos | Systems Manager e acesso ao backup do laboratório |
| Bucket S3 exclusivo | Bloqueio de acesso público, SSE-S3, versionamento e propriedade do bucket verificados |
| Manifesto SHA-256 | Referência de integridade dos quatro arquivos protegidos |

O acesso HTTP autorizado nesta execução foi `177.35.240.154/32`. Em uma nova execução, o IPv4 público deve ser obtido novamente e validado.

Não foram criados NAT Gateway, Elastic IP, Load Balancer, Key Pair ou regra de entrada SSH.

## Estrutura e scripts

As pastas do laboratório são `images/`, `policies/` e `scripts/`.

| Arquivo | Responsabilidade |
|---|---|
| `policies/ec2-ssm-trust-policy.json` | Permitir que a EC2 assuma a IAM Role |
| `policies/s3-application-backup-policy-template.json` | Definir o acesso da instância ao bucket e aos objetos de backup |
| `scripts/deploy-aws-application-backup-restore.ps1` | Criar recursos exclusivos, publicar a aplicação e registrar o baseline |
| `scripts/test-aws-application-backup-restore.ps1` | Validar os estados `Baseline`, `BackedUp`, `DataLoss` e `Restored` sem alterar a aplicação |
| `scripts/create-aws-application-backup.ps1` | Criar, enviar, recuperar e verificar o backup; registrar chave, versão e hash |
| `scripts/invoke-aws-application-data-loss.ps1` | Remover somente os dois arquivos definidos para a perda controlada |
| `scripts/diagnose-aws-application-data-loss.ps1` | Coletar estado, hashes, HTTP, logs e metadados S3 sem alterar a aplicação ou o backup |
| `scripts/restore-aws-application-backup.ps1` | Recuperar a versão registrada e restaurar os dois arquivos perdidos |
| `scripts/remove-aws-application-backup-restore.ps1` | Validar propriedade e remover os recursos exclusivos |

Os procedimentos foram executados no Windows PowerShell 5.1, com AWS CLI e `curl.exe`. As operações AWS usaram o perfil `cloud-operations-lab`, a Região `us-east-1` e a conta `412381774441`.

## Arquivos protegidos e formato do backup

| Arquivo ativo | Papel | Perda controlada |
|---|---|---|
| `/usr/share/nginx/html/index.html` | Página principal | Removido |
| `/usr/share/nginx/html/health` | Resposta `healthy` | Preservado |
| `/usr/share/nginx/html/version` | Resposta `v1` | Removido |
| `/etc/nginx/conf.d/lab18-app.conf` | Configuração da aplicação | Preservado |

O pacote `.tar.gz` contém exatamente cinco arquivos regulares, sem diretórios: `index.html`, `health`, `version`, `lab18-app.conf` e `manifest.sha256`.

O baseline local foi registrado em `/var/lib/lab18/baseline.sha256`. O registro do backup contém bucket, chave, `VersionId`, SHA-256 e horários de criação e verificação.

A criação do backup conferiu o pacote baixado pela versão específica e comparou os arquivos ativos novamente antes de registrar `BackedUp`. A restauração verificou versão, criptografia, hash do pacote, membros permitidos e manifesto antes de gravar os arquivos perdidos. `health` e a configuração Nginx permaneceram preservados.

## Sequência executada

1. Conferir repositório limpo, atualizar com `git pull --ff-only` e validar a sintaxe dos scripts.
2. Validar sessão AWS SSO, conta, Região, rede compartilhada e IPv4 público.
3. Implantar recursos exclusivos e validar `Baseline`.
4. Respeitar a janela de 15 minutos prevista no script após habilitar o versionamento; criar e validar o backup em `BackedUp`.
5. Aplicar a perda com `-ConfirmDataLoss` e validar `DataLoss`.
6. Coletar diagnóstico e registrar evidências antes da restauração.
7. Restaurar com `-ConfirmRestore` e validar `Restored`.
8. Registrar os intervalos observados de recuperação e a idade do backup.
9. Executar cleanup com `-ConfirmRemoval` e validar a ausência dos recursos exclusivos.

Os scripts de deploy, teste, backup, perda e restauração recebem `-AllowedHttpCidr`. O teste também exige `-ExpectedState`. A criação, a perda e a restauração executam suas respectivas validações de estado antes e depois da operação.

Em caso de erro ou perda de resposta, registrar o `CommandId` e conferir o estado real antes de repetir. Os registros pendentes existem para impedir a repetição automática de operações incompletas. Após encerrar a EC2, a retomada de um cleanup parcial usa o inventário do script de remoção, sem executar novamente um teste HTTP da aplicação.

## Estados e respostas HTTP observadas

| Estado | `/` | `/health` | `/version` | Arquivos e serviço |
|---|---|---|---|---|
| `Baseline` | 200, página do Lab 18 | 200, `healthy` | 200, `v1` | Quatro arquivos válidos; Nginx ativo |
| `BackedUp` | 200 | 200, `healthy` | 200, `v1` | Baseline preservado; backup verificável por versão |
| `DataLoss` | 404 | 200, `healthy` | 404 | `index.html` e `version` ausentes; Nginx ativo e configuração válida |
| `Restored` | 200, página do Lab 18 | 200, `healthy` | 200, `v1` | Quatro hashes iguais ao baseline |

Os resultados foram conferidos tanto pela própria instância quanto pelo computador do operador. A resposta saudável de `/health` durante a falha mostrou que esse endpoint, isoladamente, não comprovava a disponibilidade da página principal.

## Backup e recuperação registrados

Os identificadores abaixo são históricos. O bucket e sua versão de backup foram removidos no cleanup.

| Campo | Valor |
|---|---|
| Bucket | `lab18-app-backup-412381774441-us-east-1` |
| Chave | `backups/application-v1-20260930T004914Z-7ffa80ef94424f51909e71c4b6e18a14.tar.gz` |
| VersionId | `c2IcBx1ixAjrHrOJjayEkNws1.4r6oLM` |
| SHA-256 do pacote | `be85e070ae1bcbc3d60d0632bd69f6aa6904ba08e1af28888595d785c879ba5d` |
| Criação do backup, UTC | `2026-09-30T00:49:14.449252+00:00` |
| Início da perda, UTC | `2026-09-30T22:24:30.542479+00:00` |
| Recuperação observada localmente, UTC | `2026-09-30T22:30:26.836125+00:00` |

### Intervalos medidos

| Medição | Valor | Interpretação |
|---|---|---|
| `ObservedRecoverySeconds` | 356,294 s | Da perda até a confirmação HTTP local; inclui diagnóstico e espera do operador |
| `RestoreOperationSeconds` | 0,663 s | Trecho Python remoto, incluindo download, verificações, gravação e confirmação local |
| `BackupAgeSecondsAtLoss` | 77.716,093 s | Idade do backup quando a perda foi introduzida |

O intervalo observado foi de **5 min 56,294 s**. A idade do backup foi de **21 h 35 min 16,093 s**.

A duração de 0,663 s não inclui toda a execução PowerShell, as validações anteriores/posteriores ou a espera pelo Systems Manager. A idade do backup não mede perda efetiva de dados: os arquivos recuperados coincidiram com o baseline. Estas medições documentam este ensaio; não estabelecem objetivos de RTO ou RPO para produção.

### Hashes finais dos arquivos ativos

```text
0c005dd629b9b4dab4df9ebc19f51a633e04832c7f223f109292dae76b78c733  /usr/share/nginx/html/index.html
63745aef95742025c6d7a1b4fc0e7107e6f3c3eb2e0cb290f33c46f176e6740d  /usr/share/nginx/html/health
2d27fbdf4e8ca207afbfa388ca9172fbcc6c70e534af2476b3b704f87debadcf  /usr/share/nginx/html/version
34bba41dc9059f26dc18c0e7090d3026ffc8e419d2cf7edbb842c8ef842342a2  /etc/nginx/conf.d/lab18-app.conf
```

## Ajustes realizados durante a execução

- **Criação da EC2:** substituição de `--min-count` e `--max-count` por `--count 1`. A implantação parcial foi removida antes de um novo deploy.
- **Exclusão de versões S3:** alteração de `Quiet = $true` para `Quiet = $false`, pois o parser exigia JSON e a exclusão bem-sucedida em modo silencioso retornou saída vazia. Na retomada, o bucket já estava sem versões ou marcadores; bucket e recursos IAM restantes foram removidos.
- **Aviso Nginx:** o aviso sobre `types_hash` não impediu a validação da configuração, que retornou código zero. A configuração protegida foi mantida durante o exercício.

## Proteções e limites

- Recursos e tags de propriedade conferidos antes das remoções.
- HTTP limitado ao IPv4 público autorizado em `/32`; sem entrada SSH.
- Bucket privado, versionado e com SSE-S3.
- IAM da instância limitado a consulta de versionamento, envio e leitura de versões de backup; sem permissão de exclusão S3.
- Uso explícito do `VersionId` registrado, sem seleção implícita da versão mais recente.
- Perda limitada aos dois caminhos definidos; sem exclusão por curinga.
- Exclusões S3 por chave e versão, com conferência de erros e novo inventário antes de remover o bucket.
- VPC e sub-rede compartilhadas preservadas; recursos de outros projetos fora do escopo.

O backup cobre somente os quatro arquivos definidos. Não é uma imagem da instância, snapshot EBS ou backup completo do sistema operacional. O exercício utiliza conteúdo estático e não demonstra consistência de banco de dados ou recuperação de gravações concorrentes.

## Evidências

| Etapa | Captura publicada |
|---|---|
| Remoção da implantação parcial após correção da EC2 | [Clipboard_09-29-2026_16.png](images/Clipboard_09-29-2026_16.png) |
| Deploy e baseline v1 | [Clipboard_09-29-2026_17.png](images/Clipboard_09-29-2026_17.png) |
| Backup versionado validado | [Clipboard_09-29-2026_19.png](images/Clipboard_09-29-2026_19.png) |
| Sintaxe da perda controlada | [Clipboard_09-30-2026_20.png](images/Clipboard_09-30-2026_20.png) |
| Sintaxe do diagnóstico | [Clipboard_09-30-2026_21.png](images/Clipboard_09-30-2026_21.png) |
| Sintaxe da restauração | [Clipboard_09-30-2026_22.png](images/Clipboard_09-30-2026_22.png) |
| Perda controlada e diagnóstico | [Clipboard_09-30-2026_23.png](images/Clipboard_09-30-2026_23.png) |
| Restauração e estado Restored | [Clipboard_09-30-2026_24.png](images/Clipboard_09-30-2026_24.png) |
| Cleanup concluído e rede preservada | [Clipboard_09-30-2026_25.png](images/Clipboard_09-30-2026_25.png) |

## Critérios de conclusão

- [x] Infraestrutura exclusiva implantada e baseline validado.
- [x] Backup criado, versionado e conferido por SHA-256 e manifesto.
- [x] Perda controlada reproduzida e diagnóstico coletado.
- [x] Versão registrada recuperada com integridade confirmada.
- [x] Respostas HTTP locais e externas recuperadas.
- [x] Horários e intervalos observados registrados.
- [x] Evidências publicadas em `images/`.
- [x] Recursos exclusivos removidos e rede compartilhada preservada.

## Referências

- [AWS Systems Manager Run Command](https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html)
- [Recuperar uma versão específica de objeto no Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/RetrievingObjectVersions.html)
- [AWS CLI s3api get-object](https://docs.aws.amazon.com/cli/latest/reference/s3api/get-object.html)
- [Habilitar versionamento em buckets S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/manage-versioning-examples.html)
- [AWS CLI s3api delete-objects](https://docs.aws.amazon.com/cli/latest/reference/s3api/delete-objects.html)
