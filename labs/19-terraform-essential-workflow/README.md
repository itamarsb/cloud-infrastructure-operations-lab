# Lab 19 — Fluxo essencial do Terraform

## Estado

Em preparação. Estrutura inicial criada; configuração e execução pendentes.

## Objetivo

Praticar o fluxo essencial do Terraform em um exercício local:

- inicializar o diretório com `terraform init`;
- formatar a configuração com `terraform fmt`;
- validar a configuração com `terraform validate`;
- analisar as mudanças com `terraform plan`;
- aplicar o plano com `terraform apply`;
- conferir o estado e os outputs;
- remover os recursos do exercício com `terraform destroy`.

## Escopo

O laboratório utilizará o recurso integrado `terraform_data`, com estado local.

A execução não provisionará recursos AWS. A infraestrutura compartilhada dos laboratórios anteriores permanecerá fora do escopo.

## Organização

| Diretório | Finalidade |
|---|---|
| `terraform/` | Configuração Terraform do exercício |
| `images/` | Evidências reais de execução |

## Critérios de conclusão

- [ ] Configuração criada e formatada.
- [ ] Validação concluída.
- [ ] Plano analisado antes da aplicação.
- [ ] Aplicação concluída e outputs conferidos.
- [ ] Estado local inspecionado.
- [ ] Segunda execução do plano sem mudanças.
- [ ] Remoção concluída e validada.
- [ ] Evidências publicadas.
