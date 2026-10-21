# Lab 29 — Monitoramento com Zabbix

Monitoramento de um ambiente Linux com agente Zabbix, coleta de itens e acompanhamento de uma falha controlada em um serviço HTTP.

**Status:** em desenvolvimento — definição do cenário.

## Objetivo

Demonstrar o fluxo entre coleta de dados, avaliação de uma trigger, registro de problema e confirmação da recuperação.

O cenário permitirá observar um serviço HTTP indisponível enquanto o agente permanece respondendo.

## Cenário

Um ambiente Linux exclusivo executará o agente Zabbix e um pequeno serviço HTTP.

O Zabbix acompanhará a disponibilidade do agente e o estado do serviço. Após a confirmação do funcionamento normal, o serviço HTTP será interrompido de forma controlada.

O exercício deverá confirmar:

1. Coleta funcionando antes da falha.
2. Serviço HTTP indisponível.
3. Agente permanecendo disponível.
4. Trigger entrando em estado de problema.
5. Serviço HTTP restaurado.
6. Trigger retornando ao estado OK.

## Ambiente

O laboratório será executado localmente com Docker Desktop.

| Componente | Finalidade |
|:---:|:---:|
| Banco de dados exclusivo | Armazenar configurações, valores e eventos do laboratório |
| Zabbix Server | Coletar dados e avaliar triggers |
| Interface web | Configurar e acompanhar o monitoramento |
| Alvo Linux com agente | Fornecer os itens monitorados |
| Serviço HTTP no alvo | Permitir a falha controlada e a recuperação |

As versões, imagens, portas e configurações serão definidas nas próximas etapas e registradas nos arquivos do laboratório.

Os componentes utilizarão recursos exclusivos, identificados como pertencentes ao LAB 29.

## Escopo

- Preparar o ambiente local.
- Cadastrar o host monitorado.
- Confirmar a comunicação entre servidor e agente.
- Configurar e verificar os itens.
- Definir intervalos de coleta e critérios da trigger.
- Registrar o funcionamento normal.
- Interromper somente o serviço HTTP.
- Confirmar o problema e a continuidade da coleta pelo agente.
- Restaurar o serviço.
- Confirmar a recuperação.
- Preservar as evidências.
- Remover e validar a ausência dos recursos exclusivos.

A correlação mais ampla entre métricas, logs e estado do sistema será desenvolvida no Lab 30.

## Isolamento

Este laboratório será independente do repositório
`zabbix-linux-network-server-monitoring-lab`.

O ambiente utilizará um banco novo. O volume PostgreSQL antigo, seu backup e os recursos utilizados no teste de restauração permanecerão fora do escopo deste laboratório.

O agente instalado no Windows e os recursos de outros projetos não serão utilizados como alvos da falha controlada.

SNMP, notificações por e-mail e recuperação do ambiente Zabbix anterior não fazem parte deste exercício.

## Organização

| Caminho | Finalidade |
|:---:|:---:|
| `README.md` | Objetivo, procedimento e resultados |
| `config/` | Configurações versionadas |
| `scripts/` | Preparação, validação, experimento e cleanup |
| `images/` | Capturas de evidências |
| `local-artifacts/` | Inventário e resultados locais ignorados pelo Git |

Credenciais reais permanecerão em arquivos locais ignorados pelo Git. Os modelos versionados conterão somente instruções ou valores de exemplo.

## Fluxo de execução

| Etapa | Resultado esperado |
|:---:|:---:|
| Preparação | Configurações e pré-requisitos conferidos |
| Implantação | Componentes exclusivos em execução |
| Monitoramento | Host cadastrado e itens recebendo valores |
| Baseline | Agente disponível e serviço HTTP funcionando |
| Falha | Serviço HTTP interrompido e problema registrado |
| Recuperação | Serviço restaurado e trigger em OK |
| Cleanup | Recursos exclusivos removidos e evidências preservadas |

Cada etapa será executada e analisada antes do avanço para a seguinte.

## Critérios de validação

O laboratório será considerado concluído quando houver evidências de:

- recebimento de valores dos itens;
- funcionamento normal do serviço HTTP;
- indisponibilidade do serviço durante o experimento;
- continuidade da comunicação com o agente durante a falha;
- registro do problema pela trigger;
- recuperação do serviço e retorno da trigger para OK;
- remoção dos recursos exclusivos.

Os horários observados serão registrados para comparar a intervenção com a detecção e a recuperação no Zabbix.

Essas medições representarão o comportamento observado no laboratório, sem estabelecer garantias de tempo para ambientes de produção.

## Etapas

- [x] Definir o objetivo e os limites do cenário.
- [ ] Definir versões, imagens e comunicação entre componentes.
- [ ] Preparar os arquivos de configuração.
- [ ] Validar os pré-requisitos.
- [ ] Implantar o ambiente exclusivo.
- [ ] Cadastrar o host.
- [ ] Configurar e validar os itens.
- [ ] Configurar a trigger.
- [ ] Registrar o baseline.
- [ ] Executar a falha controlada.
- [ ] Confirmar a detecção e a disponibilidade do agente.
- [ ] Restaurar o serviço HTTP.
- [ ] Confirmar a recuperação.
- [ ] Realizar e validar o cleanup.
- [ ] Consolidar resultados e evidências.

## Resultados

O cenário de monitoramento ainda não foi executado.

As verificações e o teste de restauração do ambiente Zabbix anterior não constituem evidências de execução deste cenário.
