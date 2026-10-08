# LAB 25 — Métricas no CloudWatch

## Status

Em desenvolvimento.

Etapa atual: organização da estrutura e planejamento do cenário.

## Objetivo

Consultar e interpretar métricas no Amazon CloudWatch e organizar um dashboard para acompanhar recursos identificados do laboratório.

O exercício deverá demonstrar:

- identificação de namespaces, métricas e dimensões;
- consultas com intervalo de tempo, período e estatística definidos;
- interpretação dos valores retornados;
- distinção entre ausência de dados e valor zero;
- criação e validação de um dashboard;
- registro de evidências;
- remoção dos recursos exclusivos ao final.

## Organização

| Caminho | Finalidade |
|---|---|
| `README.md` | Procedimento, resultados e evidências |
| `scripts/` | Scripts PowerShell de preparação, consulta, validação e cleanup |
| `config/` | Configurações versionadas das consultas e do dashboard |
| `images/` | Capturas da execução |

## Ambiente previsto

| Item | Configuração |
|---|---|
| Estação de trabalho | Windows 11 e Windows PowerShell |
| Interface AWS | AWS CLI |
| Autenticação | AWS IAM Identity Center |
| Perfil | `cloud-operations-lab` |
| Região | `us-east-1` |
| Serviço de observação | Amazon CloudWatch |

Os recursos observados e os nomes dos artefatos serão definidos antes da implementação.

## Escopo

O laboratório terá foco em métricas, consultas e dashboard.

A coleta adicional com CloudWatch Agent será tratada no Lab 26. Alarmes e notificações serão tratados no Lab 27.

Os recursos removidos nos laboratórios anteriores não serão considerados disponíveis.

A infraestrutura compartilhada e os recursos de outros projetos deverão ser preservados.

## Sequência planejada

1. Definir o recurso observado e as métricas do exercício.
2. Identificar os recursos exclusivos e suas tags.
3. Definir os custos envolvidos e o cleanup.
4. Implementar os scripts e as configurações.
5. Validar a sessão AWS e os pré-requisitos.
6. Preparar o ambiente observado.
7. Consultar e interpretar as métricas.
8. Criar e validar o dashboard.
9. Registrar os resultados e as evidências.
10. Remover os recursos exclusivos.
11. Confirmar o cleanup e concluir a documentação.

## Validações previstas

- Identidade AWS e Região conferidas.
- Recurso observado identificado explicitamente.
- Métricas consultadas com as dimensões esperadas.
- Intervalos de consulta registrados.
- Períodos e estatísticas documentados.
- Respostas vazias tratadas explicitamente.
- Dashboard correspondente aos recursos do laboratório.
- Consultas de validação sem alterações nos recursos.
- Cleanup limitado aos recursos exclusivos.

## Evidências previstas

- Identificação do ambiente observado.
- Consulta das métricas e resultados retornados.
- Comparação dos valores e estatísticas utilizados.
- Dashboard configurado.
- Validação do dashboard.
- Remoção dos recursos exclusivos.
- Verificação final do cleanup.

## Critérios de conclusão

- [ ] Cenário e recursos definidos.
- [ ] Custos e cleanup documentados.
- [ ] Scripts e configurações publicados.
- [ ] Identidade AWS e pré-requisitos validados.
- [ ] Métricas consultadas e interpretadas.
- [ ] Ausência de dados tratada corretamente.
- [ ] Dashboard criado e validado.
- [ ] Evidências publicadas.
- [ ] Recursos exclusivos removidos.
- [ ] Cleanup confirmado.
- [ ] Documentação concluída.
