# Lab 11 — Armazenamento e recuperação com EBS e Amazon S3

## Objetivo

Implementar e validar um fluxo controlado de armazenamento e recuperação utilizando um volume Amazon EBS adicional e um bucket Amazon S3 privado.

O laboratório criará um arquivo de teste em um volume EBS, calculará seu hash SHA-256, enviará uma cópia para o Amazon S3 e restaurará o objeto para outro diretório. A integridade será confirmada pela comparação dos hashes do arquivo original e do arquivo recuperado.

A instância será administrada exclusivamente pelo AWS Systems Manager, sem chave SSH e sem regras de entrada no Security Group.

> **English summary:** Implement and validate a controlled storage and recovery workflow using an encrypted Amazon EBS volume, a private versioned Amazon S3 bucket, SHA-256 integrity verification, AWS Systems Manager administration, independent validation, and controlled cleanup.

---

## Arquitetura

O laboratório reutilizará a VPC e a sub-rede pública do Lab 08.

    AWS IAM Identity Center
              |
              v
    AWS Systems Manager
              |
              v
    EC2 Amazon Linux 2023
              |
              ├── volume raiz EBS
              |
              ├── volume EBS adicional
              |       |
              |       ├── arquivo original
              |       └── arquivo restaurado
              |
              └── Amazon S3
                      |
                      └── cópia protegida do arquivo

O fluxo de dados será:

    Arquivo original no EBS
              |
              | cálculo do SHA-256
              v
        Upload para o S3
              |
              | download controlado
              v
    Arquivo restaurado no EBS
              |
              | novo cálculo do SHA-256
              v
       Comparação de integridade

---

## Componentes

| Componente | Configuração |
|:---:|:---:|
| Região | `us-east-1` |
| Zona de disponibilidade | `us-east-1a` |
| VPC | `lab08-application-vpc` |
| Sub-rede | `lab08-public-subnet-a` |
| Instância | `lab11-storage-instance` |
| Tipo da instância | `t3.micro` |
| Sistema operacional | Amazon Linux 2023 |
| Security Group | `lab11-storage-sg` |
| IAM Role | `lab11-ec2-storage-role` |
| Instance Profile | `lab11-ec2-storage-instance-profile` |
| Política do Systems Manager | `AmazonSSMManagedInstanceCore` |
| Volume adicional | EBS `gp3`, 1 GiB e criptografado |
| Nome do volume | `lab11-storage-data-volume` |
| Ponto de montagem | `/mnt/lab11-data` |
| Bucket | Nome gerado com conta e Região |
| Acesso ao bucket | Privado |
| Criptografia S3 | SSE-S3 |
| Versionamento S3 | Habilitado |
| Verificação de integridade | SHA-256 |
| Acesso administrativo | AWS Systems Manager |
| Key Pair | Não utilizada |
| Regras de entrada | Nenhuma |

---

## Estrutura

    labs/11-aws-storage-recovery/
    ├── README.md
    ├── images/
    │   └── lab11-cleanup-success.png
    ├── policies/
    │   ├── ec2-ssm-trust-policy.json
    │   └── s3-storage-policy-template.json
    └── scripts/
        ├── deploy-aws-storage-recovery.ps1
        ├── restore-aws-storage-data.ps1
        ├── test-aws-storage-recovery.ps1
        └── remove-aws-storage-recovery.ps1

| Arquivo | Responsabilidade |
|:---:|---|
| `deploy-aws-storage-recovery.ps1` | Criar IAM, S3, EC2 e volume EBS, além de gerar e copiar os dados de teste |
| `restore-aws-storage-data.ps1` | Restaurar o objeto do S3 e comparar sua integridade |
| `test-aws-storage-recovery.ps1` | Validar a infraestrutura e as configurações de armazenamento |
| `remove-aws-storage-recovery.ps1` | Remover somente os recursos específicos do Lab 11 |
| `ec2-ssm-trust-policy.json` | Permitir que o serviço EC2 assuma a IAM Role |
| `s3-storage-policy-template.json` | Limitar o acesso da instância ao bucket específico do Lab 11 |

---

## Escopo

O laboratório incluirá:

- localização da VPC e da sub-rede do Lab 08;
- descoberta da imagem mais recente do Amazon Linux 2023;
- criação de IAM Role e Instance Profile;
- associação da política `AmazonSSMManagedInstanceCore`;
- aplicação de uma política limitada ao bucket do Lab 11;
- criação de Security Group sem regras de entrada;
- implantação de uma instância EC2 sem Key Pair;
- exigência de IMDSv2;
- criação de volume EBS adicional;
- criptografia do volume EBS;
- utilização do tipo de volume `gp3`;
- associação do volume à instância;
- criação de sistema de arquivos;
- montagem em `/mnt/lab11-data`;
- criação de um arquivo de teste;
- cálculo do hash SHA-256;
- criação de bucket S3 privado;
- bloqueio completo de acesso público;
- criptografia padrão do bucket;
- habilitação do versionamento;
- upload do arquivo para o S3;
- restauração para um diretório separado;
- comparação dos hashes;
- validação independente;
- cleanup controlado;
- validação do estado final;
- preservação da rede do Lab 08.

Não serão criados:

- NAT Gateway;
- VPC Endpoints;
- Elastic IP;
- Load Balancer;
- banco de dados;
- domínio DNS;
- Key Pair;
- regra de entrada para SSH;
- acesso público ao bucket.

---

## Fluxo de armazenamento

O arquivo original será criado em:

    /mnt/lab11-data/source/lab11-storage-data.txt

O hash original será registrado em:

    /mnt/lab11-data/source/lab11-storage-data.sha256

O objeto será enviado ao bucket utilizando uma chave semelhante a:

    backup/lab11-storage-data.txt

A restauração será realizada em:

    /mnt/lab11-data/restored/lab11-storage-data.txt

A validação comparará:

    SHA-256 do arquivo original
                  |
                  v
    SHA-256 do arquivo restaurado

A restauração somente será considerada válida quando os dois hashes forem idênticos.

---

## Controles de segurança

### Bucket privado

O bucket terá o bloqueio de acesso público configurado com:

- `BlockPublicAcls`;
- `IgnorePublicAcls`;
- `BlockPublicPolicy`;
- `RestrictPublicBuckets`.

Nenhum objeto será disponibilizado publicamente.

### Criptografia

O laboratório utilizará:

- criptografia EBS;
- volume `gp3`;
- criptografia padrão SSE-S3;
- conexões HTTPS realizadas pela AWS CLI.

### Menor privilégio

A instância receberá acesso somente ao bucket específico do Lab 11.

A política permitirá apenas as ações necessárias para:

- consultar o bucket;
- enviar o arquivo de teste;
- consultar o objeto;
- baixar o objeto restaurado.

### Administração sem SSH

A instância não utilizará Key Pair.

O Security Group não possuirá regras de entrada, e a administração ocorrerá pelo Systems Manager.

---

## Critérios de sucesso

O Lab 11 será considerado concluído quando:

1. existir exatamente uma instância ativa com as tags esperadas;
2. a instância executar Amazon Linux 2023;
3. nenhum Key Pair estiver associado;
4. o IMDSv2 estiver configurado como obrigatório;
5. o Security Group não possuir regras de entrada;
6. a instância estiver online no Systems Manager;
7. existir exatamente um volume adicional do Lab 11;
8. o volume adicional estiver criptografado;
9. o volume utilizar `gp3`;
10. o volume estiver associado à instância;
11. o sistema de arquivos estiver montado em `/mnt/lab11-data`;
12. o arquivo original existir no volume EBS;
13. existir exatamente um bucket do Lab 11;
14. o bucket estiver com acesso público bloqueado;
15. a criptografia padrão do bucket estiver habilitada;
16. o versionamento estiver habilitado;
17. o objeto de backup existir no bucket;
18. o arquivo restaurado existir no volume;
19. o hash do arquivo restaurado for igual ao original;
20. a validação independente terminar com código `0`;
21. o cleanup remover os recursos do Lab 11;
22. a VPC e a sub-rede do Lab 08 permanecerem disponíveis.

---

## Pré-requisitos

- Windows PowerShell 5.1 ou PowerShell 7;
- AWS CLI v2;
- Session Manager Plugin;
- perfil `cloud-operations-lab`;
- autenticação pelo AWS IAM Identity Center;
- Lab 08 implantado em `us-east-1`;
- permissões necessárias para EC2, EBS, IAM, S3 e Systems Manager.

Autenticação prevista:

    aws sso login --profile cloud-operations-lab

---

## Fluxo operacional

### 1. Implantação

A implantação será executada por:

    $DeployScript = ".\labs\11-aws-storage-recovery\scripts\deploy-aws-storage-recovery.ps1"

    & $DeployScript `
        -ProfileName "cloud-operations-lab" `
        -Region "us-east-1" `
        -AvailabilityZone "us-east-1a" `
        -InstanceType "t3.micro"

O script deverá:

- localizar a rede do Lab 08;
- criar os recursos IAM;
- criar o bucket S3;
- configurar a proteção do bucket;
- criar a instância EC2;
- criar e associar o volume EBS;
- preparar o sistema de arquivos;
- criar os dados de teste;
- calcular o hash original;
- enviar o arquivo para o S3.

### 2. Validação independente

    $TestScript = ".\labs\11-aws-storage-recovery\scripts\test-aws-storage-recovery.ps1"

    & $TestScript `
        -ProfileName "cloud-operations-lab" `
        -Region "us-east-1"

O validador realizará consultas somente leitura e verificará a infraestrutura, a segurança, o EBS, o bucket e o objeto armazenado.

### 3. Restauração

    $RestoreScript = ".\labs\11-aws-storage-recovery\scripts\restore-aws-storage-data.ps1"

    & $RestoreScript `
        -ProfileName "cloud-operations-lab" `
        -Region "us-east-1"

O script realizará o download do objeto para um diretório separado no volume EBS e comparará o hash do arquivo restaurado com o hash original.

### 4. Cleanup

    $RemoveScript = ".\labs\11-aws-storage-recovery\scripts\remove-aws-storage-recovery.ps1"

    & $RemoveScript `
        -ProfileName "cloud-operations-lab" `
        -Region "us-east-1" `
        -ConfirmRemoval

O cleanup removerá:

- instância EC2;
- volume EBS adicional;
- bucket S3 e suas versões;
- Security Group;
- política IAM específica;
- Instance Profile;
- IAM Role.

A VPC e a sub-rede do Lab 08 não serão modificadas.

---

## Evidências registradas

As capturas documentam etapas realizadas, com limites distintos:

| Captura | O que comprova |
|---|---|
| [Sintaxe local](images/lab11-local-syntax-validation.png) | O parser do PowerShell aceitou os scripts de implantação, restauração e validação após o `git pull`. |
| [Testes locais com respostas simuladas](images/lab11-local-s3-mock-tests.png) | A função de inspeção do bucket retornou zero itens para resposta vazia, contou uma versão válida e bloqueou uma chave inesperada. Não houve chamada real ao S3. |
| [Cleanup controlado](images/lab11-cleanup-success.png) | A execução parcial foi encerrada com remoção dos recursos do Lab 11, código de saída `0` e preservação da VPC e da sub-rede do Lab 08. |

A implantação completa, a validação independente na AWS e a restauração com comparação de hashes ainda não foram concluídas. Novas evidências serão adicionadas após essas etapas serem executadas e verificadas.

---

## Estado atual

- [x] arquitetura definida;
- [x] escopo definido;
- [x] nomes dos recursos definidos;
- [x] critérios de sucesso definidos;
- [ ] políticas IAM criadas;
- [x] scripts de implantação, restauração, validação e remoção preparados;
- [ ] validação sintática concluída;
- [ ] implantação executada;
- [ ] armazenamento validado;
- [ ] restauração executada;
- [ ] integridade confirmada;
- [x] evidência do cleanup registrada;
- [x] cleanup da execução parcial concluído;
- [ ] estado final validado.

---

## Considerações de custo

A instância EC2, o endereço IPv4 público, o volume EBS e o armazenamento no Amazon S3 podem gerar cobrança durante a execução.

O laboratório utilizará:

- uma instância `t3.micro`;
- um volume EBS adicional de 1 GiB;
- um único bucket S3;
- um pequeno arquivo de teste;
- nenhuma infraestrutura de alta disponibilidade;
- nenhum NAT Gateway.

Os recursos serão removidos após o registro das evidências.

---

## Resultado esperado

Ao final, o repositório deverá demonstrar:

- criação e associação de volume EBS;
- montagem persistente de sistema de arquivos;
- utilização segura do Amazon S3;
- bloqueio de acesso público;
- criptografia de dados;
- versionamento de objetos;
- controle de acesso por IAM;
- cálculo e comparação de hashes;
- restauração de dados;
- validação independente;
- administração sem SSH;
- cleanup dos recursos;
- preservação da infraestrutura compartilhada.
