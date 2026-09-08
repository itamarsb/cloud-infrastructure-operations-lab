# Lab 03 — Instalação das ferramentas de infraestrutura

## Objetivo

Instalar e validar as ferramentas de infraestrutura utilizadas nos próximos laboratórios do projeto **Cloud Infrastructure Operations Lab**.

## Ferramentas previstas

- Git;
- Terraform;
- AWS Systems Manager Session Manager Plugin;
- Windows Package Manager — WinGet;
- PowerShell;
- Visual Studio Code.

## Status

🚧 Laboratório em desenvolvimento.

## Progresso atual

- [x] Inventário inicial das ferramentas disponíveis.
- [x] Instalação do AWS Systems Manager Session Manager Plugin.
- [x] Atualização controlada do Terraform.
- [ ] Validação das ferramentas no PowerShell.
- [ ] Validação das ferramentas no terminal do Visual Studio Code.
- [ ] Criação do script de validação.
- [ ] Registro e revisão das evidências.
- [ ] Documentação final do laboratório.


## Evidências parciais

### Inventário inicial das ferramentas

A verificação inicial confirmou que Git, Terraform e WinGet estavam disponíveis, enquanto o AWS Systems Manager Session Manager Plugin ainda não estava instalado.

![Inventário inicial das ferramentas](images/LAB03_Cloud_Operations_Tool_Inventory_01.png)

### AWS Systems Manager Session Manager Plugin

A instalação foi validada pela localização do executável e pela execução bem-sucedida do comando `session-manager-plugin`.

![Validação do Session Manager Plugin](images/LAB03_Cloud_Operations_Session_Manager_Plugin_02.png)

### Atualização do Terraform

A instalação existente utilizava o Terraform 1.15.8 diretamente no diretório `C:\Terraform` e não era gerenciada pelo WinGet.

![Estado anterior do Terraform](images/LAB03_Cloud_Operations_Terraform_Pre_Update_03.png)

Após a validação do checksum oficial, foi criado um backup da versão anterior e o Terraform foi atualizado para a versão 1.16.1.

![Terraform atualizado](images/LAB03_Cloud_Operations_Terraform_Update_04.png)
