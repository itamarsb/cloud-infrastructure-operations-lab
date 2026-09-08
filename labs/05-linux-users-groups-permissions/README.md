# Lab 05 — Usuários, grupos e permissões

## Objetivo

Praticar o gerenciamento de identidades e controles de acesso em um ambiente Linux, incluindo usuários, grupos, propriedade de arquivos, permissões tradicionais e execução administrativa com `sudo`.

## Ambiente

- Windows Subsystem for Linux 2;
- Ubuntu 24.04 LTS;
- Bash;
- usuário administrativo com acesso controlado ao `sudo`;
- contas e grupos exclusivos do laboratório.

## Competências previstas

Ao longo deste laboratório serão realizadas as seguintes atividades:

- identificação do usuário e dos grupos atuais;
- validação controlada do acesso ao `sudo`;
- criação de um grupo dedicado ao laboratório;
- criação de usuários temporários;
- inclusão de usuários em grupos;
- consulta das bases locais de usuários e grupos;
- criação de diretórios compartilhados;
- aplicação de propriedade com `chown`;
- configuração de permissões com `chmod`;
- interpretação das permissões simbólicas e numéricas;
- validação de acesso com diferentes identidades;
- aplicação do bit SGID em diretório compartilhado;
- automação das verificações com Bash;
- remoção controlada das contas e do grupo ao final;
- registro de evidências técnicas.

## Escopo de segurança

As contas e os grupos utilizados serão exclusivos deste laboratório.

Nenhuma conta existente será removida ou terá suas permissões alteradas. Todas as operações administrativas serão executadas com alvos explícitos e verificações anteriores à alteração.

## Status

🚧 Laboratório em desenvolvimento.

## Progresso atual

- [ ] Validação do usuário, dos grupos e do acesso ao `sudo`.
- [ ] Criação do grupo do laboratório.
- [ ] Criação das contas temporárias.
- [ ] Associação das contas ao grupo.
- [ ] Preparação do diretório compartilhado.
- [ ] Configuração de proprietário e grupo.
- [ ] Aplicação das permissões tradicionais.
- [ ] Configuração e validação do SGID.
- [ ] Testes de acesso entre usuários.
- [ ] Execução do script de validação.
- [ ] Seleção e registro das evidências.
- [ ] Cleanup das contas e do grupo.
- [ ] Documentação final do laboratório.
