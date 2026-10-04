# Lab 21 — Estado remoto do Terraform

## Status

Em desenvolvimento.

## Objetivo

Implementar armazenamento remoto, bloqueio e proteção do estado do Terraform, com validação independente e ciclo de vida explícito dos recursos do backend.

## Organização

| Diretório | Finalidade |
|:---:|:---:|
| `bootstrap/` | Configuração Terraform responsável pela criação dos recursos do backend |
| `terraform/` | Configuração do exercício que utilizará o estado remoto |
| `scripts/` | Scripts PowerShell de pré-validação e verificação |
| `images/` | Evidências de execução |

## Escopo previsto

- autenticação temporária na AWS;
- validação da conta e da Região;
- provisionamento do armazenamento do estado;
- proteção do armazenamento e controle de acesso;
- configuração do backend remoto;
- bloqueio de operações concorrentes;
- validação do estado remoto;
- revisão e aplicação de planos;
- remoção dos recursos do exercício;
- tratamento separado do ciclo de vida do backend.

## Proteções

- recursos exclusivos identificados por nomes e tags;
- configurações e estados separados para o backend e o exercício;
- estados, planos e parâmetros locais fora do versionamento;
- preservação da infraestrutura compartilhada dos laboratórios anteriores;
- remoção do backend somente após concluir as operações que dependem dele.

## Resultados

Execução e evidências pendentes.
