# Lab 09 — Instância EC2 administrada pelo Systems Manager

## Objetivo

Implantar uma instância Amazon EC2 administrável pelo AWS Systems Manager Session Manager, sem chave SSH, sem porta administrativa exposta e sem regras de entrada no Security Group.

O laboratório reutiliza temporariamente a rede criada pelo Lab 08 e demonstra práticas de provisionamento seguro, acesso administrativo, validação independente, proteção contra remoção acidental e cleanup controlado.

> **English summary:** Secure deployment and validation of an Amazon EC2 instance managed through AWS Systems Manager Session Manager, without SSH keys or inbound Security Group rules.

---

## Escopo

O laboratório inclui:

- recriação temporária da rede do Lab 08;
- descoberta dinâmica da imagem mais recente do Amazon Linux 2023;
- criação de uma função IAM para a instância;
- associação da política gerenciada `AmazonSSMManagedInstanceCore`;
- criação de um Instance Profile;
- criação de um Security Group sem regras de entrada;
- implantação de uma instância EC2;
- exigência do Instance Metadata Service Version 2 — IMDSv2;
- criptografia do volume raiz;
- validação do registro da instância no Systems Manager;
- acesso administrativo pelo Session Manager;
- validação independente da configuração;
- remoção controlada dos recursos;
- registro de evidências sem exposição de informações sensíveis.

Não fazem parte deste laboratório:

- acesso administrativo por SSH;
- criação de Key Pair;
- abertura da porta TCP `22`;
- utilização de credenciais permanentes na instância;
- implantação de aplicação;
- criação de NAT Gateway;
- criação de VPC Endpoint;
- utilização de Elastic IP;
- criação de Load Balancer;
- manutenção permanente da instância.

---

## Arquitetura

A instância será implantada temporariamente em uma das sub-redes públicas criadas pelo Lab 08.

O acesso administrativo ocorrerá exclusivamente pelo Systems Manager Session Manager.

    Operador
       |
       | AWS CLI e sessão SSO
       v
    AWS Systems Manager
       |
       | Session Manager
       v
    Instância EC2
       |
       | IAM Instance Profile
       v
    AmazonSSMManagedInstanceCore

A instância não aceitará conexões iniciadas diretamente pela Internet.

| Componente | Definição |
|:---:|:---:|
| Região | `us-east-1` |
| VPC | `lab08-application-vpc` |
| CIDR da VPC | `10.20.0.0/16` |
| Sub-rede | `lab08-public-subnet-a` |
| Zona de disponibilidade | `us-east-1a` |
| Instância | `lab09-managed-instance` |
| Sistema operacional | Amazon Linux 2023 |
| Tipo inicial | `t3.micro` |
| Security Group | `lab09-managed-instance-sg` |
| Regras de entrada | Nenhuma |
| Acesso administrativo | AWS Systems Manager Session Manager |
| Key Pair | Não utilizado |
| IAM Role | `lab09-ec2-ssm-role` |
| Instance Profile | `lab09-ec2-ssm-instance-profile` |
| Política gerenciada | `AmazonSSMManagedInstanceCore` |
| IMDS | Versão 2 obrigatória |
| Volume raiz | Criptografado e removido com a instância |
| IPv4 público | Temporário, sem Elastic IP |
| Provisionamento | AWS CLI por PowerShell |

---

## Decisões de segurança

### Administração sem SSH

Nenhuma Key Pair será criada ou associada à instância.

O Security Group não possuirá regras de entrada, inclusive para a porta TCP `22`. A administração será realizada pelo Session Manager mediante autenticação AWS e autorização IAM.

Essa abordagem reduz:

- exposição de portas administrativas;
- gerenciamento de chaves SSH;
- risco de perda ou compartilhamento indevido de chaves privadas;
- dependência de endereços IP autorizados manualmente.

### Identidade da instância

A instância receberá credenciais temporárias por meio de uma função IAM associada a um Instance Profile.

A função utilizará somente a política gerenciada necessária para que a instância opere como nó gerenciado do Systems Manager:

- `AmazonSSMManagedInstanceCore`.

Nenhuma access key será armazenada na instância ou no repositório.

### Proteção do serviço de metadados

A configuração exigirá IMDSv2:

- tokens obrigatórios;
- endpoint de metadados habilitado;
- limite controlado de saltos de resposta.

Essa proteção reduz a exposição do serviço de metadados a requisições não autorizadas.

### Proteção do armazenamento

O volume raiz será:

- criptografado;
- configurado para remoção automática quando a instância for terminada;
- limitado ao tamanho necessário para o laboratório.

### Proteção contra remoção indevida

O script de cleanup deverá:

- localizar recursos pelas tags e pelos nomes esperados;
- confirmar a associação dos recursos ao Lab 09;
- recusar a remoção caso encontre inconsistências;
- exigir o parâmetro explícito `-ConfirmRemoval`;
- remover os recursos em ordem de dependência;
- não remover automaticamente recursos do Lab 08.

---

## Conectividade com o Systems Manager

A arquitetura deste laboratório não utiliza NAT Gateway nem VPC Endpoints.

Para alcançar os endpoints públicos necessários ao Systems Manager, a instância utilizará temporariamente:

- uma sub-rede pública;
- uma rota padrão pelo Internet Gateway;
- atribuição automática de endereço IPv4 público;
- regras de saída do Security Group.

O endereço IPv4 público não será usado para administração direta e não será associado como Elastic IP.

A instância continuará sem regras de entrada.

> Em um ambiente privado de produção, a conectividade com o Systems Manager poderia ser fornecida por NAT Gateway ou por VPC Endpoints específicos. Esses componentes não serão criados aqui para manter o laboratório pequeno e controlado.

---

## Considerações de custo

Este laboratório poderá gerar cobranças enquanto a instância EC2 estiver em execução.

Também poderá haver cobrança pelo endereço IPv4 público durante sua utilização. A elegibilidade a ofertas gratuitas depende da conta, da Região, do tipo de instância e das condições vigentes da AWS.

Para limitar custos:

- será utilizada apenas uma instância;
- o tipo padrão será `t3.micro`;
- não serão criados NAT Gateway, Elastic IP ou Load Balancer;
- o volume raiz terá tamanho reduzido;
- a instância será removida após as evidências;
- o cleanup será validado ao final.

Consulte antes da execução:

- [Amazon EC2 On-Demand Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Amazon VPC Pricing](https://aws.amazon.com/vpc/pricing/)
- [AWS Free Tier](https://aws.amazon.com/free/)

---

## Estrutura de arquivos

    labs/
    └── 09-aws-ec2-systems-manager/
        ├── README.md
        ├── images/
        │   └── .gitkeep
        ├── policies/
        │   └── ec2-ssm-trust-policy.json
        └── scripts/
            ├── deploy-aws-managed-instance.ps1
            ├── test-aws-managed-instance.ps1
            └── remove-aws-managed-instance.ps1

| Arquivo | Finalidade |
|:---:|---|
| `README.md` | Documentar arquitetura, controles, execução, validação, evidências e cleanup |
| `ec2-ssm-trust-policy.json` | Definir a relação de confiança que permite ao serviço EC2 assumir a função IAM |
| `deploy-aws-managed-instance.ps1` | Criar os recursos IAM, o Security Group e a instância EC2 |
| `test-aws-managed-instance.ps1` | Validar a instância e sua integração com o Systems Manager em modo de leitura |
| `remove-aws-managed-instance.ps1` | Remover os recursos do Lab 09 em ordem de dependência |

---

## Recursos previstos

O script de implantação deverá criar somente:

- uma função IAM;
- uma associação com a política `AmazonSSMManagedInstanceCore`;
- um Instance Profile;
- um Security Group sem regras de entrada;
- uma instância EC2;
- um volume raiz criptografado e vinculado à instância.

O script não deverá criar:

- Key Pair;
- regra de entrada;
- Elastic IP;
- NAT Gateway;
- VPC Endpoint;
- Load Balancer;
- Auto Scaling Group;
- banco de dados;
- bucket S3.

---

## Tags operacionais

Todos os recursos compatíveis deverão receber as tags:

| Chave | Valor |
|---|---|
| `Name` | Nome específico do recurso |
| `Project` | `cloud-infrastructure-operations-lab` |
| `Environment` | `lab` |
| `Lab` | `09` |
| `ManagedBy` | `aws-cli` |
| `Owner` | `itamarsb` |

As tags serão utilizadas para:

- identificação;
- validação de propriedade;
- controle do cleanup;
- prevenção contra alteração de recursos não relacionados.

---

## Pré-requisitos

Antes da implantação, confirme:

- AWS CLI v2 disponível;
- perfil SSO `cloud-operations-lab` configurado;
- sessão AWS válida;
- Região `us-east-1`;
- AWS Session Manager Plugin instalado;
- permissões para consultar parâmetros públicos do Systems Manager;
- permissões para administrar funções e Instance Profiles do IAM;
- permissões para criar e consultar Security Groups;
- permissões para criar, consultar e terminar instâncias EC2;
- rede do Lab 08 implantada;
- diretório de trabalho sem alterações não registradas.

A implantação da rede do Lab 08 deve ser concluída antes da execução deste laboratório.

---

## Sequência operacional

A ordem planejada é:

1. renovar a sessão AWS;
2. recriar a rede do Lab 08;
3. validar a rede;
4. revisar a política de confiança;
5. executar o script de implantação do Lab 09;
6. aguardar a instância entrar no estado `running`;
7. aguardar o registro no Systems Manager;
8. executar o script de validação independente;
9. testar uma sessão administrativa;
10. registrar as evidências;
11. executar a proteção inicial do cleanup sem autorização;
12. executar o cleanup com autorização explícita;
13. confirmar a ausência dos recursos do Lab 09;
14. registrar a evidência de cleanup;
15. remover a rede temporária com o script do Lab 08.

---

## Política de confiança

O arquivo `policies/ec2-ssm-trust-policy.json` definirá exclusivamente o serviço EC2 como principal autorizado a assumir a função IAM.

A política não deverá:

- conceder permissões operacionais;
- conter Account ID;
- conter ARN específico da conta;
- autorizar usuários;
- autorizar serviços diferentes do EC2;
- utilizar curingas como principal.

As permissões operacionais serão fornecidas separadamente pela política gerenciada `AmazonSSMManagedInstanceCore`.

---

## Script de implantação

O arquivo `scripts/deploy-aws-managed-instance.ps1` deverá:

- validar a disponibilidade da AWS CLI;
- validar a sessão AWS;
- localizar a VPC e a sub-rede esperadas;
- validar as tags da rede;
- descobrir a imagem mais recente do Amazon Linux 2023;
- criar ou validar a função IAM;
- associar `AmazonSSMManagedInstanceCore`;
- criar ou validar o Instance Profile;
- aguardar a propagação dos recursos IAM;
- criar um Security Group sem regras de entrada;
- iniciar uma única instância;
- impedir associação de Key Pair;
- exigir IMDSv2;
- configurar o volume raiz criptografado;
- aplicar as tags operacionais;
- aguardar o estado `running`;
- verificar o registro no Systems Manager;
- produzir um resumo sem exibir identificadores completos.

O script deverá interromper a implantação se encontrar recursos conflitantes ou com tags incompatíveis.

---

## Script de validação

O arquivo `scripts/test-aws-managed-instance.ps1` deverá operar exclusivamente em modo de leitura e validar:

- existência de uma única instância correspondente;
- estado esperado da instância;
- VPC e sub-rede corretas;
- imagem baseada em Amazon Linux 2023;
- ausência de Key Pair;
- associação do Security Group esperado;
- ausência de regras de entrada;
- associação do Instance Profile esperado;
- exigência de IMDSv2;
- criptografia do volume raiz;
- remoção automática do volume na terminação;
- presença das tags obrigatórias;
- registro da instância no Systems Manager;
- estado online do agente gerenciado.

A validação deverá retornar código de saída `0` somente quando todos os controles obrigatórios estiverem corretos.

---

## Script de cleanup

O arquivo `scripts/remove-aws-managed-instance.ps1` deverá executar duas etapas.

Sem `-ConfirmRemoval`, o script deverá:

- validar a sessão;
- descobrir os recursos;
- conferir nomes e tags;
- verificar dependências;
- informar que a remoção não foi autorizada;
- encerrar sem alterar recursos.

Com `-ConfirmRemoval`, o script deverá:

1. terminar a instância;
2. aguardar o estado `terminated`;
3. confirmar a remoção do volume raiz;
4. remover o Security Group;
5. remover o Instance Profile;
6. desassociar a política da função IAM;
7. remover a função IAM;
8. confirmar a ausência dos recursos do Lab 09.

A rede do Lab 08 será preservada pelo cleanup deste laboratório e removida separadamente.

---

## Evidências

Serão registradas três evidências principais.

### Implantação da instância

Arquivo planejado:

`images/LAB09_Cloud_Operations_EC2_Deployment_01.png`

A captura deverá demonstrar:

- validação dos pré-requisitos;
- criação ou validação dos recursos IAM;
- criação do Security Group;
- implantação da instância;
- estado final `running`;
- registro no Systems Manager;
- confirmação da ausência de SSH e Key Pair.

### Validação do Systems Manager

Arquivo planejado:

`images/LAB09_Cloud_Operations_SSM_Validation_02.png`

A captura deverá demonstrar:

- validação independente concluída;
- instância registrada como nó gerenciado;
- agente online;
- ausência de regras de entrada;
- IMDSv2 obrigatório;
- volume raiz criptografado;
- código de saída `0`.

Se for realizada uma sessão interativa, a captura poderá mostrar comandos não sensíveis, como:

    hostname
    whoami
    cat /etc/os-release
    systemctl is-active amazon-ssm-agent

### Cleanup

Arquivo planejado:

`images/LAB09_Cloud_Operations_EC2_Cleanup_03.png`

A captura deverá demonstrar:

- autorização explícita;
- término da instância;
- remoção do Security Group;
- remoção do Instance Profile;
- remoção da função IAM;
- confirmação da ausência dos recursos;
- código de saída `0`.

### Proteção das evidências

Antes da publicação, as imagens deverão ser revisadas.

Devem ser ocultados ou recortados:

- Account ID;
- ARN completo;
- Instance ID completo;
- VPC ID completo;
- Subnet ID completo;
- Security Group ID completo;
- Volume ID completo;
- endereço IPv4 público;
- URLs de autenticação;
- credenciais;
- tokens;
- nomes de usuário locais que não sejam necessários.

---

## Critérios de conclusão

O laboratório será considerado concluído quando:

- a rede temporária estiver disponível;
- a função IAM e o Instance Profile estiverem corretos;
- a instância estiver em execução;
- nenhuma Key Pair estiver associada;
- o Security Group não possuir regras de entrada;
- IMDSv2 estiver obrigatório;
- o volume raiz estiver criptografado;
- a instância estiver online no Systems Manager;
- a validação independente retornar código `0`;
- as três evidências estiverem registradas;
- todos os recursos do Lab 09 forem removidos;
- a rede temporária do Lab 08 for removida;
- nenhuma cobrança intencional permanecer ativa.

---

## Status

- [x] Estrutura do laboratório criada
- [ ] Arquitetura e proteções documentadas
- [ ] Política de confiança implementada
- [ ] Script de implantação implementado
- [ ] Script de validação implementado
- [ ] Script de cleanup implementado
- [ ] Rede do Lab 08 recriada
- [ ] Instância implantada
- [ ] Validação concluída
- [ ] Evidência da implantação registrada
- [ ] Evidência da validação registrada
- [ ] Cleanup validado
- [ ] Evidência do cleanup registrada
- [ ] Rede temporária removida
