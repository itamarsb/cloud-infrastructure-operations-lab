# Lab 17 — Atualização controlada de aplicação na AWS

## Resumo

Este laboratório executou uma atualização controlada de uma aplicação Nginx em uma instância Amazon EC2. O fluxo incluiu implantação da versão inicial, introdução de uma configuração inválida, diagnóstico, rollback, aplicação da versão v2, confirmação e remoção dos recursos exclusivos.

**Estado:** concluído; recursos exclusivos removidos após a validação final.

A VPC e a sub-rede compartilhadas do Lab 08 foram preservadas.

## Objetivos

- Implantar uma aplicação acessível por HTTP e gerenciada pelo AWS Systems Manager.
- Registrar uma versão inicial saudável e um backup verificável.
- Reproduzir uma falha de configuração sem perder a resposta HTTP da versão ativa.
- Diagnosticar a falha antes de executar o rollback.
- Restaurar a versão v1 e comparar os arquivos com o backup.
- Aplicar e confirmar a versão v2 após validação local e externa.
- Remover somente os recursos exclusivos do Lab 17.

## Ambiente utilizado

| Item | Valor durante a execução |
| :---: | :---: |
| Conta AWS | `412381774441` |
| Região | `us-east-1` |
| Perfil AWS CLI | `cloud-operations-lab` |
| VPC compartilhada | `vpc-0aad44f1f16b804ad` |
| Sub-rede compartilhada | `subnet-04048dcc4a1a66b63` |
| Instância EC2 do laboratório | `i-0901a1fb940f9e0e1` |
| Security Group do laboratório | `sg-06fdb21d5703bb054` |
| IAM Role | `lab17-ec2-controlled-update-role` |
| Instance Profile | `lab17-ec2-controlled-update-instance-profile` |
| IPv4 público da instância durante a execução | `44.200.151.148` |
| Origem HTTP autorizada durante a execução | `177.35.240.154/32` |

Os identificadores, o endereço público e o CIDR acima documentam a execução realizada. A instância e os demais recursos exclusivos já foram removidos; o endereço não representa um endpoint ativo do laboratório.

O Security Group autorizou HTTP na porta 80 apenas para o IPv4 público usado nos testes. Nenhuma regra de entrada SSH foi criada. O gerenciamento da instância ocorreu pelo Systems Manager.

## Fluxo executado

| Etapa | Estado verificado |
| :---: | --- |
| Implantação e baseline | Nginx ativo; configuração válida; `/health` saudável; `/version` em `v1` |
| Candidata inválida | Configuração rejeitada por `nginx -t`; processo Nginx ainda ativo; HTTP servindo `v1` |
| Diagnóstico | Diretiva inválida identificada; backup íntegro; somente o arquivo de configuração ativo diferia do backup |
| Rollback | Quatro arquivos restaurados; configuração válida; HTTP em `v1`; marcador `rolled-back` |
| Atualização válida | Nginx saudável; versão local e externa `v2`; marcador `updated` |
| Confirmação | Versão `v2` saudável; backup da v1 preservado; marcador `confirmed` |
| Cleanup | EC2, Security Group, Instance Profile e IAM Role exclusivos removidos; VPC e sub-rede compartilhadas preservadas |

A falha foi introduzida por uma diretiva inválida em `/etc/nginx/conf.d/lab17-release.conf`. O teste de configuração retornou `unknown directive "lab17_invalid_directive"`. Como a configuração inválida não foi carregada, o Nginx continuou respondendo com a versão v1 até o rollback.

## Validações e rastreabilidade

| Operação | CommandId do Systems Manager |
| --- | --- |
| Aplicação da candidata inválida | `4ae5454c-7a70-41c6-a896-5fae37e237d5` |
| Diagnóstico | `c2a5f8b5-cc99-4ebf-aeba-dbc630e3e136` |
| Rollback | `0251f080-9b68-4d2d-ab07-284cc053518c` |
| Aplicação da candidata v2 | `8879804c-9025-475f-8471-d75effe15e40` |
| Confirmação da v2 | `6ea6af13-e0e8-4b5a-89aa-3c9ec46ed383` |

Os hashes SHA-256 após o rollback coincidiram com os do baseline v1:

| Arquivo | SHA-256 da v1 e após rollback | SHA-256 da v2 confirmada |
| --- | --- | --- |
| `index.html` | `088411c1140f02c9ec9d01bb8e7525da9dee1a53420fcc964877e49cd061bdf6` | `ab9acd41a12eff3a56359668eb5963f0fc80f049a5b4c2377ecfa655f4e9e775` |
| `health` | `63745aef95742025c6d7a1b4fc0e7107e6f3c3eb2e0cb290f33c46f176e6740d` | `63745aef95742025c6d7a1b4fc0e7107e6f3c3eb2e0cb290f33c46f176e6740d` |
| `version` | `2d27fbdf4e8ca207afbfa388ca9172fbcc6c70e534af2476b3b704f87debadcf` | `81db67b6a5702b9b68f0016f061c409bf3fb16d062fc854d1b424bb4e9c28c56` |
| `lab17-release.conf` | `7c2bfcae6f599a5699d22b65bb9d0c9bf27eddb6b128a1a2ac741b8ab70b0cd5` | `94fbe177e37f89bbefc22e2e142341f9328ba741c9b410117c449ff542b3fc70` |

Durante a candidata inválida, os arquivos `index.html`, `health` e `version` permaneceram iguais aos do backup v1. Apenas `lab17-release.conf` diferiu, com hash `df0590c8e7ab6cb7b63f94dbc783ceae7376e9a749db19c8a8aba3f2983b3929`.

## Evidências

As capturas publicadas em [`images/`](images/) documentam as etapas da execução:

| Etapa | Captura |
| --- | --- |
| Implantação e baseline v1 | [Baseline](images/Clipboard_09-27-2026_06.png) |
| Candidata inválida | [Falha controlada](images/Clipboard_09-28-2026_08.png) |
| Diagnóstico | [Diagnóstico](images/Clipboard_09-28-2026_09.png) |
| Rollback | [Restauração da v1](images/Clipboard_09-28-2026_10.png) |
| Atualização válida | [Aplicação da v2](images/Clipboard_09-28-2026_11.png) |
| Confirmação | [Validação da v2 confirmada](images/Clipboard_09-28-2026_12.png) |

O resultado do cleanup foi registrado na saída da execução: instância encerrada, Security Group, Instance Profile e IAM Role removidos, recursos exclusivos ausentes na validação posterior e rede compartilhada preservada.

## Como reproduzir

Execute a partir da raiz do repositório, em PowerShell, após autenticar o perfil AWS e conferir a conta e a região. Uma nova execução criará novos identificadores de recursos.

```powershell
aws sso login --profile cloud-operations-lab

$Lab = ".\labs\17-aws-controlled-update\scripts"
$PublicIp = (curl.exe --noproxy "*" -fsS https://checkip.amazonaws.com).Trim()

if ($LASTEXITCODE -ne 0) {
    throw "Não foi possível obter o IPv4 público."
}

$ParsedIp = $null
if (-not [Net.IPAddress]::TryParse($PublicIp, [ref]$ParsedIp) -or
    $ParsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
    throw "IPv4 público inválido: $PublicIp"
}

$AllowedHttpCidr = "$PublicIp/32"
$env:AWS_CLI_FILE_ENCODING = "UTF-8"
```

Implante e valide o baseline:

```powershell
& (Join-Path $Lab "deploy-aws-controlled-update.ps1") `
    -AllowedHttpCidr $AllowedHttpCidr

& (Join-Path $Lab "test-aws-controlled-update.ps1") `
    -AllowedHttpCidr $AllowedHttpCidr `
    -ExpectedReleaseState Baseline
```

Aplique a candidata inválida, valide o estado e colete o diagnóstico antes do rollback:

```powershell
& (Join-Path $Lab "apply-aws-controlled-update.ps1") `
    -ReleaseMode FailedCandidate `
    -ConfirmUpdate

& (Join-Path $Lab "test-aws-controlled-update.ps1") `
    -AllowedHttpCidr $AllowedHttpCidr `
    -ExpectedReleaseState CandidateFailed

& (Join-Path $Lab "diagnose-aws-controlled-update.ps1")
```

Restaure a v1 e valide o resultado:

```powershell
& (Join-Path $Lab "rollback-aws-controlled-update.ps1") `
    -ConfirmRollback

& (Join-Path $Lab "test-aws-controlled-update.ps1") `
    -AllowedHttpCidr $AllowedHttpCidr `
    -ExpectedReleaseState RolledBack
```

Aplique a candidata válida e confirme a v2 somente após a validação:

```powershell
& (Join-Path $Lab "apply-aws-controlled-update.ps1") `
    -ReleaseMode ValidCandidate `
    -ConfirmUpdate

& (Join-Path $Lab "test-aws-controlled-update.ps1") `
    -AllowedHttpCidr $AllowedHttpCidr `
    -ExpectedReleaseState Updated

& (Join-Path $Lab "confirm-aws-controlled-update.ps1") `
    -AllowedHttpCidr $AllowedHttpCidr `
    -ConfirmUpdate

& (Join-Path $Lab "test-aws-controlled-update.ps1") `
    -AllowedHttpCidr $AllowedHttpCidr `
    -ExpectedReleaseState Confirmed
```

Após registrar as evidências, remova os recursos exclusivos:

```powershell
& (Join-Path $Lab "remove-aws-controlled-update.ps1") `
    -ConfirmRemoval
```

Interrompa o fluxo se alguma validação falhar. Antes de repetir uma operação do Systems Manager, registre o `CommandId` e verifique o estado efetivo da instância.

## Problemas encontrados e correções

Durante as primeiras tentativas de atualização, o envio do parâmetro `--parameters file://` encontrou problemas de codificação no Windows. O fluxo também precisou normalizar as quebras de linha do script remoto para LF: uma quebra CRLF no interpretador `#!/bin/sh` impedia a execução na instância Linux.

Os scripts de atualização, diagnóstico, rollback e confirmação foram ajustados para tratar a codificação, normalizar o conteúdo enviado e obter o `CommandId` sem imprimir a resposta completa do `send-command`. O baseline foi validado antes de prosseguir para a candidata inválida.

## Proteções e limites

- Os scripts verificam a conta AWS esperada e os recursos que pertencem ao Lab 17.
- A entrada HTTP é limitada ao IPv4 público informado na execução; se o endereço mudar, o acesso deve ser reavaliado.
- A VPC, a sub-rede e a rota compartilhadas do Lab 08 não fazem parte do cleanup.
- O diagnóstico coleta o estado e não altera a aplicação.
- O rollback verifica o backup e restaura os arquivos da versão inicial.
- Os identificadores e hashes desta página documentam a execução concluída; não devem ser reutilizados como parâmetros de uma nova implantação.
- Recursos de outros projetos ficam fora do escopo de seleção e remoção do Lab 17.

## Resultado

- [x] Baseline v1 implantado e validado local e externamente.
- [x] Candidata inválida reproduzida e diagnosticada.
- [x] Backup v1 verificado e rollback concluído com hashes idênticos aos do baseline.
- [x] Candidata v2 aplicada e validada.
- [x] Versão v2 confirmada com o backup v1 preservado.
- [x] Recursos exclusivos removidos e ausência confirmada após o cleanup.
- [x] VPC e sub-rede compartilhadas preservadas.

## Referências

- [AWS Systems Manager Run Command](https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html)
- [AWS CLI `ssm send-command`](https://docs.aws.amazon.com/cli/latest/reference/ssm/send-command.html)
- [Gerenciamento de pacotes no Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/package-management.html)
