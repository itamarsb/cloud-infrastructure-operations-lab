# Lab 02 — Instalação e configuração da AWS CLI

## Objetivo

Instalar a AWS Command Line Interface versão 2 no Windows 11, configurar um perfil nomeado com autenticação temporária pelo AWS IAM Identity Center e validar, com segurança, a identidade, a Região e o funcionamento da comunicação entre a estação de trabalho e a AWS.

Ao final do laboratório, a AWS CLI deverá estar disponível no PowerShell e no terminal integrado do Visual Studio Code, utilizando o perfil `cloud-operations-lab` e a Região `us-east-1`, sem credenciais do usuário root e sem chaves de acesso de longa duração armazenadas no repositório.

---

## Cenário

> Você recebeu a tarefa de preparar uma estação de trabalho para executar atividades de Cloud Operations. A conta AWS já possui os controles básicos de segurança. Agora é necessário instalar a ferramenta oficial de linha de comando, configurar um acesso individual, identificar claramente o perfil utilizado e comprovar que os comandos estão sendo executados na conta e na Região corretas.

Em ambientes profissionais, essa preparação reduz erros de contexto, evita o uso indevido da identidade root e estabelece a base para automação, troubleshooting, infraestrutura como código e scripts operacionais.

---

## Informações rápidas

| Informação | Descrição |
|---|---|
| **Nível** | Básico |
| **Tempo estimado** | 35–50 minutos |
| **Custo estimado** | Sem custo esperado |
| **Serviços AWS** | AWS CLI, AWS IAM Identity Center e AWS Security Token Service — STS |
| **Competência principal** | Instalação, autenticação e validação segura da AWS CLI |
| **Sistema operacional principal** | Windows 11 com PowerShell |
| **Cleanup obrigatório** | Não |

---

## Competências desenvolvidas

Ao concluir este laboratório, você será capaz de:

- instalar e atualizar a AWS CLI versão 2 no Windows;
- localizar o executável utilizado pelo terminal;
- diferenciar AWS CLI v1 e v2;
- configurar um perfil nomeado com AWS IAM Identity Center;
- autenticar-se com credenciais temporárias;
- definir Região e formato de saída padrão;
- listar e inspecionar perfis sem revelar segredos;
- validar a identidade ativa com AWS STS;
- reconhecer a precedência básica entre parâmetros e perfis;
- registrar evidências técnicas sem publicar dados sensíveis.

---

## Pré-requisitos

Antes de iniciar, verifique se você possui:

- o **Lab 00 — Preparação da estação de trabalho** concluído;
- o **Lab 01 — Configuração segura da conta AWS** concluído;
- Windows 11 de 64 bits;
- PowerShell e Visual Studio Code instalados;
- permissão para instalar aplicativos no computador;
- acesso ao AWS Access Portal;
- um usuário individual no AWS IAM Identity Center;
- um permission set atribuído à conta de laboratório;
- MFA habilitado para o acesso, quando exigido;
- navegador atualizado;
- conexão com a internet.

Tenha disponíveis, sem publicá-los:

- a **SSO Start URL** ou **Issuer URL** do portal;
- a Região onde o IAM Identity Center foi configurado;
- a conta AWS e o permission set autorizados para seu usuário.

> [!IMPORTANT]
> Este laboratório adota autenticação pelo AWS IAM Identity Center, com sessões temporárias. Não crie access keys para o usuário root. Também não é necessário criar chaves de longa duração para concluir o procedimento principal.

> [!WARNING]
> Não publique SSO Start URL, Issuer URL, Account ID, códigos de autorização, tokens, access keys, secret access keys nem o conteúdo integral da pasta `%UserProfile%\.aws`.

---

## Ferramentas utilizadas

| Ferramenta | Finalidade |
|---|---|
| **PowerShell** | Instalar e validar a AWS CLI |
| **AWS CLI v2** | Executar comandos e acessar serviços AWS |
| **AWS IAM Identity Center** | Fornecer autenticação individual e temporária |
| **AWS STS** | Confirmar a identidade utilizada pela sessão |
| **Visual Studio Code** | Repetir as validações no terminal de trabalho |
| **Navegador** | Autorizar o login no AWS Access Portal |

---

## Visão geral do laboratório

Este laboratório não provisiona infraestrutura. O fluxo estabelece uma relação autenticada entre a estação de trabalho, o AWS IAM Identity Center e os serviços AWS.

```mermaid
flowchart TB
    START(["Início do Lab 02<br/>Preparar acesso pela AWS CLI"])

    subgraph INSTALL["1. Instalação"]
        CHECK["Verificar instalação existente"]
        MSI["Instalar AWS CLI v2<br/>com pacote oficial"]
        VERSION["Validar versão e executável"]
    end

    subgraph CONFIG["2. Configuração"]
        SSO["Executar aws configure sso"]
        PROFILE["Criar perfil nomeado<br/>cloud-operations-lab"]
        DEFAULTS["Definir Região us-east-1<br/>e saída json"]
    end

    subgraph AUTH["3. Autenticação"]
        LOGIN["Executar aws sso login"]
        PORTAL["Autorizar no navegador<br/>com identidade individual"]
        CACHE["Receber credenciais temporárias"]
    end

    subgraph VALIDATE["4. Validação"]
        STS["Executar sts get-caller-identity"]
        REGION["Confirmar perfil e Região"]
        VSCODE["Repetir teste no VS Code"]
    end

    READY(["AWS CLI pronta<br/>para os próximos laboratórios"])

    START --> CHECK --> MSI --> VERSION
    VERSION --> SSO --> PROFILE --> DEFAULTS
    DEFAULTS --> LOGIN --> PORTAL --> CACHE
    CACHE --> STS --> REGION --> VSCODE --> READY

    classDef start fill:#eef2ff,stroke:#4f46e5,color:#1e1b4b,stroke-width:2px
    classDef install fill:#eff6ff,stroke:#2563eb,color:#172554,stroke-width:1.5px
    classDef config fill:#f5f3ff,stroke:#7c3aed,color:#3b0764,stroke-width:1.5px
    classDef auth fill:#fff7ed,stroke:#ea580c,color:#7c2d12,stroke-width:1.5px
    classDef validation fill:#f0fdfa,stroke:#0f766e,color:#134e4a,stroke-width:1.5px
    classDef success fill:#ecfdf5,stroke:#059669,color:#064e3b,stroke-width:2.5px

    class START start
    class CHECK,MSI,VERSION install
    class SSO,PROFILE,DEFAULTS config
    class LOGIN,PORTAL,CACHE auth
    class STS,REGION,VSCODE validation
    class READY success

    style INSTALL fill:#f8fbff,stroke:#93c5fd,stroke-width:1.5px
    style CONFIG fill:#faf8ff,stroke:#c4b5fd,stroke-width:1.5px
    style AUTH fill:#fffaf5,stroke:#fdba74,stroke-width:1.5px
    style VALIDATE fill:#f5fffc,stroke:#5eead4,stroke-width:1.5px
```

---

# Etapa 1 — Abrir o PowerShell e verificar instalações existentes

Abra uma nova janela do PowerShell. Não é necessário executá-la como administrador para esta verificação.

Execute:

```powershell
aws --version
```

Se a AWS CLI ainda não estiver instalada, o PowerShell poderá informar que o termo `aws` não foi reconhecido. Esse resultado é esperado antes da instalação.

Em seguida, verifique se existe algum executável com esse nome no `PATH`:

```powershell
Get-Command aws -All -ErrorAction SilentlyContinue
```

### Resultado esperado

- nenhuma ocorrência, se a AWS CLI não estiver instalada; ou
- o caminho e o tipo do executável atualmente associado ao comando `aws`.

> [!IMPORTANT]
> Se a saída de `aws --version` começar com `aws-cli/1`, consulte o troubleshooting deste laboratório antes de continuar. As versões 1 e 2 usam o mesmo comando e uma instalação antiga pode ser encontrada primeiro no `PATH`.

### Evidência sugerida

Registre o PowerShell mostrando a verificação inicial. Não é necessário publicar nomes completos de diretórios do usuário.

---

# Etapa 2 — Baixar o instalador oficial da AWS CLI v2

No PowerShell, defina um caminho temporário para o instalador:

```powershell
$AwsCliInstaller = Join-Path $env:TEMP "AWSCLIV2.msi"
```

Baixe o pacote oficial:

```powershell
Invoke-WebRequest `
  -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" `
  -OutFile $AwsCliInstaller
```

Confirme que o arquivo foi baixado:

```powershell
Get-Item $AwsCliInstaller | Select-Object Name, Length, LastWriteTime
```

### Resultado esperado

O PowerShell deverá exibir o arquivo `AWSCLIV2.msi` com tamanho maior que zero.

> [!NOTE]
> O arquivo é salvo na pasta temporária do Windows e não deve ser incluído no repositório.

---

# Etapa 3 — Instalar a AWS CLI v2

Execute o instalador com a interface padrão do Windows:

```powershell
Start-Process msiexec.exe `
  -Wait `
  -ArgumentList "/i `"$AwsCliInstaller`""
```

1. Autorize a execução, caso o Windows solicite confirmação.
2. Avance pelo assistente.
3. Aceite os termos aplicáveis.
4. Mantenha o diretório padrão, salvo necessidade específica.
5. Conclua a instalação.

Feche o PowerShell após a instalação e abra uma nova janela. Isso permite que o terminal carregue o `PATH` atualizado.

### Resultado esperado

O assistente deverá informar que a instalação foi concluída com sucesso.

### Evidência sugerida

Registre a tela final do instalador, sem exibir dados pessoais desnecessários.

---

# Etapa 4 — Validar a versão instalada

Na nova janela do PowerShell, execute:

```powershell
aws --version
```

### Resultado esperado

A saída deverá começar com `aws-cli/2` e indicar Windows como plataforma. Os números exatos variam conforme a versão atual.

Exemplo de formato:

```text
aws-cli/2.x.x Python/3.x.x Windows/11 exe/AMD64
```

Localize também o executável:

```powershell
Get-Command aws | Select-Object Name, CommandType, Source
```

O caminho padrão normalmente aponta para:

```text
C:\Program Files\Amazon\AWSCLIV2\aws.exe
```

> [!NOTE]
> Não compare sua versão com o número ilustrativo. O requisito deste laboratório é utilizar a versão principal 2.

---

# Etapa 5 — Obter os dados do acesso programático no AWS Access Portal

1. Entre no AWS Access Portal com seu usuário individual.
2. Conclua a autenticação multifator, quando solicitada.
3. Localize a conta AWS utilizada nos laboratórios.
4. Abra o permission set atribuído ao seu usuário.
5. Escolha **Access keys**.
6. Selecione o método de credenciais do **IAM Identity Center**.
7. Localize a **SSO Start URL** e a **SSO Region**.

Não copie para o README valores reais apresentados no portal.

> [!CAUTION]
> Não selecione o método de credenciais de curta duração para copiar access key, secret key e session token. Neste laboratório, a autenticação será configurada diretamente com `aws configure sso`.

### Resultado esperado

Você deverá ter identificado a URL do portal e a Região do IAM Identity Center sem registrar esses valores em uma captura pública.

---

# Etapa 6 — Iniciar a configuração do perfil SSO

No PowerShell, execute:

```powershell
aws configure sso
```

Quando solicitado, informe um nome descritivo para a sessão:

```text
SSO session name (Recommended): cloud-operations-sso
```

Informe a URL obtida no portal:

```text
SSO start URL [None]: <SUA_SSO_START_URL>
```

Informe a Região em que o IAM Identity Center está configurado:

```text
SSO region [None]: <SUA_SSO_REGION>
```

Mantenha o escopo padrão:

```text
SSO registration scopes [sso:account:access]:
```

Pressione `Enter` para aceitar o valor exibido entre colchetes.

> [!IMPORTANT]
> A SSO Region não é necessariamente a Região onde os recursos do laboratório serão criados. Ela identifica onde o IAM Identity Center está configurado. A Região padrão dos recursos será definida posteriormente como `us-east-1`.

---

# Etapa 7 — Autorizar a AWS CLI no navegador

Durante a configuração, a AWS CLI deverá abrir o navegador padrão.

1. Confirme que o endereço pertence ao domínio legítimo da AWS.
2. Entre com o mesmo usuário individual utilizado no AWS Access Portal.
3. Confira o código ou a solicitação de autorização apresentada.
4. Autorize o acesso da AWS CLI.
5. Retorne ao PowerShell.

Se o navegador não abrir automaticamente, siga a URL e as instruções temporárias exibidas pelo próprio terminal.

### Resultado esperado

O navegador deverá informar que a autorização foi concluída, e o terminal deverá prosseguir para a seleção da conta e do permission set.

> [!CAUTION]
> Não publique o código de autorização nem a URL temporária exibida nessa etapa.

---

# Etapa 8 — Selecionar a conta e o permission set

A AWS CLI apresentará apenas as contas e os permission sets atribuídos ao usuário autenticado.

1. Se houver uma única conta, confirme a seleção.
2. Se houver mais de uma, escolha cuidadosamente a conta de laboratório.
3. Selecione o permission set autorizado para as atividades.

### Resultado esperado

O terminal deverá confirmar a conta e a função selecionadas antes de solicitar as configurações padrão do perfil.

> [!WARNING]
> Sempre confira a conta selecionada. Em um ambiente corporativo, executar um comando no ambiente errado pode causar indisponibilidade, exposição de dados ou custos inesperados.

---
