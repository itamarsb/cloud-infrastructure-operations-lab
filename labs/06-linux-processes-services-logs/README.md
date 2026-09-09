# Lab 06 — Processos, serviços e logs no Linux

## Visão geral

Este laboratório apresenta operações fundamentais de monitoramento e administração de processos, serviços e logs em um sistema Linux.

A atividade será executada no Ubuntu 24.04 LTS sobre WSL 2, utilizando processos e serviços exclusivos do laboratório.

---

## Objetivo

Desenvolver competências práticas para observar processos, controlar uma carga de trabalho, administrar um serviço com `systemd` e investigar eventos registrados no journal do sistema.

Ao concluir o laboratório, o estudante deverá conseguir:

- identificar o sistema de inicialização;
- consultar processos com `ps`;
- observar consumo de recursos com `top`;
- interpretar PID, PPID, usuário, estado e prioridade;
- iniciar um processo controlado em segundo plano;
- ajustar a prioridade de um processo;
- enviar sinais e finalizar processos;
- criar uma unidade de serviço exclusiva;
- administrar serviços com `systemctl`;
- consultar logs com `journalctl`;
- filtrar eventos por serviço, prioridade e período;
- automatizar verificações com Bash;
- interpretar códigos de saída;
- realizar cleanup controlado.

---

## Ambiente previsto

| Componente | Configuração |
|:---:|:---:|
| Sistema hospedeiro | Windows 11 Pro |
| Ambiente Linux | WSL 2 |
| Distribuição | Ubuntu 24.04 LTS |
| Sistema de inicialização | `systemd` |
| Shell | Bash |
| Ferramentas principais | `ps`, `top`, `systemctl`, `journalctl`, `logger` |
| Serviço do laboratório | `cloudops-lab06.service` |
| Diretório de trabalho | `/opt/cloudops-lab06` |

---

## Escopo de segurança

Todos os processos, arquivos e serviços manipulados serão criados exclusivamente para este laboratório.

Não serão interrompidos ou alterados:

- processos do Windows ou do WSL;
- serviços essenciais do sistema;
- serviços pertencentes a outros projetos;
- unidades preexistentes do `systemd`;
- registros originais do sistema.

Os comandos de encerramento utilizarão PIDs previamente identificados e vinculados à carga controlada do Lab 06.

A unidade `cloudops-lab06.service` e o diretório `/opt/cloudops-lab06` serão removidos durante o cleanup final.

---

## Estrutura do laboratório

```text
labs/
└── 06-linux-processes-services-logs/
    ├── README.md
    ├── images/
    └── scripts/
```

---

## Plano de execução

1. Validar o ambiente Linux e o `systemd`.
2. Observar processos e recursos do sistema.
3. Criar uma carga de trabalho controlada.
4. Inspecionar PID, PPID, estado e prioridade.
5. Ajustar a prioridade com `nice` e `renice`.
6. Encerrar o processo utilizando sinais.
7. Preparar o diretório do serviço.
8. Criar a unidade `cloudops-lab06.service`.
9. Administrar o serviço com `systemctl`.
10. Consultar eventos com `journalctl`.
11. Simular e investigar uma falha controlada.
12. Executar o script de validação.
13. Registrar as evidências técnicas.
14. Realizar o cleanup do laboratório.
15. Concluir a documentação.

---

## Status

🚧 Laboratório em desenvolvimento.

---

## Progresso atual

- [ ] Validação do Linux, WSL e `systemd`.
- [ ] Inventário inicial de processos.
- [ ] Criação da carga controlada.
- [ ] Inspeção detalhada do processo.
- [ ] Ajuste de prioridade.
- [ ] Encerramento por sinal.
- [ ] Criação do serviço do laboratório.
- [ ] Administração com `systemctl`.
- [ ] Consulta de logs com `journalctl`.
- [ ] Investigação de falha controlada.
- [ ] Execução do script de validação.
- [ ] Seleção e registro das evidências.
- [ ] Cleanup dos recursos.
- [ ] Documentação final.
