# Lab 13 — Troubleshooting de aplicação indisponível

## Objetivo

Implantar uma aplicação web inicialmente saudável, introduzir uma falha controlada no Nginx, executar um diagnóstico estruturado e recuperar o serviço.

O laboratório exercita uma investigação operacional baseada em cinco camadas:

1. estado do serviço;
2. existência do processo;
3. porta TCP utilizada pela aplicação;
4. validade da configuração;
5. logs do sistema.

A instância Amazon EC2 será administrada pelo AWS Systems Manager, sem chave SSH e sem regra de entrada para a porta TCP `22`.

A falha será provocada por uma configuração inválida do Nginx. O diagnóstico deverá identificar a causa sem modificar o ambiente. A recuperação será executada separadamente por um script específico.

> **English summary:** Deploy a healthy Nginx web application, introduce a controlled configuration failure, diagnose service, process, port, configuration and logs, recover the application, validate the final state and remove temporary AWS resources.

---

## Cenário

A aplicação será implantada e validada em estado saudável.

Em seguida, o laboratório executará este fluxo:

```text
Aplicação saudável
        |
        v
Configuração inválida introduzida
        |
        v
Restart do Nginx falha
        |
        v
Aplicação fica indisponível
        |
        v
Diagnóstico somente leitura
        |
        v
Causa identificada
        |
        v
Configuração válida restaurada
        |
        v
Nginx recuperado
        |
        v
Aplicação novamente disponível
