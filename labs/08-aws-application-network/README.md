# Lab 08 — Rede da aplicação na AWS

## Objetivo

Construir uma base de rede própria e identificável para os próximos laboratórios do projeto.

O laboratório utilizará uma VPC dedicada, duas sub-redes públicas em zonas de disponibilidade diferentes, um Internet Gateway, uma tabela de rotas pública e um Security Group inicial. A topologia será criada com AWS CLI, validada por um script independente e removida por um procedimento de cleanup controlado.

> **English summary:** Deployment and validation of a low-cost AWS application network across two Availability Zones, using a dedicated VPC, public subnets, an Internet Gateway, route tables, security controls and automated cleanup.

---

## Escopo

O laboratório inclui:

- inspeção prévia da conta e da Região;
- criação de uma VPC dedicada;
- habilitação de resolução e nomes DNS na VPC;
- criação de duas sub-redes públicas;
- distribuição das sub-redes entre duas zonas de disponibilidade;
- associação de um Internet Gateway;
- criação de uma tabela de rotas pública;
- associação explícita das sub-redes à tabela de rotas;
- criação de um Security Group sem regras de entrada;
- aplicação de tags operacionais;
- validação automatizada da topologia;
- remoção controlada dos recursos.

O laboratório não inclui instâncias EC2, balanceadores, NAT Gateway, endereços Elastic IP ou regras de acesso SSH.

---

## Ambiente validado

| Componente | Configuração |
|:---:|:---:|
| Sistema operacional | Windows 11 |
| Terminal | Windows PowerShell 5.1 |
| AWS CLI | AWS CLI v2 |
| Autenticação | AWS IAM Identity Center |
| Perfil | `cloud-operations-lab` |
| Região | `us-east-1` |
| Provisionamento | AWS CLI |

---

## Inspeção inicial

A inspeção somente leitura confirmou:

| Verificação | Resultado |
|:---:|:---:|
| Perfil autenticado | Confirmado |
| Região configurada | `us-east-1` |
| Zonas disponíveis | 6 |
| VPC existente | VPC padrão `172.31.0.0/16` |
| CIDR proposto | `10.20.0.0/16` disponível |
| Recursos alterados durante a inspeção | Nenhum |

Os identificadores da conta, da sessão e dos recursos não serão publicados nas evidências.

---

## Arquitetura

| Componente | Configuração planejada |
|:---:|:---:|
| VPC | `10.20.0.0/16` |
| Sub-rede pública A | `10.20.10.0/24` |
| Sub-rede pública B | `10.20.20.0/24` |
| Zona da sub-rede A | `us-east-1a` |
| Zona da sub-rede B | `us-east-1b` |
| Internet Gateway | Um, associado à VPC |
| Tabela de rotas | Uma tabela pública dedicada |
| Rota externa | `0.0.0.0/0` pelo Internet Gateway |
| Security Group | Sem regras de entrada |
| NAT Gateway | Não utilizado |
| Acesso administrativo futuro | AWS Systems Manager |

### Fluxo de rede planejado

| Origem | Destino | Caminho |
|:---:|:---:|---|
| Sub-rede pública A | Internet | Tabela pública → Internet Gateway |
| Sub-rede pública B | Internet | Tabela pública → Internet Gateway |
| Internet | Recursos futuros | Somente quando uma regra de entrada for aprovada |
| Administração | Instâncias futuras | AWS Systems Manager, sem SSH público |

As zonas `us-east-1a` e `us-east-1b` correspondem, nesta conta, aos identificadores físicos `use1-az1` e `use1-az2`.

---

## Tags

Os recursos criados pelo laboratório receberão, quando suportado, as seguintes tags:

| Tag | Valor |
|:---:|:---:|
| `Project` | `cloud-infrastructure-operations-lab` |
| `Environment` | `lab` |
| `Lab` | `08` |
| `ManagedBy` | `aws-cli` |
| `Owner` | `itamarsb` |
| `Name` | Nome específico do recurso |

As tags permitem identificar a finalidade, a origem e a responsabilidade pelos recursos criados.

---

## Segurança

As seguintes proteções serão adotadas:

- nenhum endereço IP, ARN ou identificador de conta será gravado no repositório;
- o script localizará recursos por tags e parâmetros controlados;
- o Security Group será criado sem regras de entrada;
- nenhuma porta SSH será aberta;
- nenhuma instância será criada neste laboratório;
- o CIDR será verificado antes da implantação;
- a remoção será limitada aos recursos identificados como pertencentes ao Lab 08;
- o script interromperá a execução quando uma operação obrigatória falhar.

---

## Controle de custos

O laboratório não utilizará NAT Gateway, Elastic IP, instância EC2 ou balanceador.

A VPC, as sub-redes, o Internet Gateway, a tabela de rotas e o Security Group não possuem cobrança horária própria. Custos de transferência de dados poderão existir apenas quando recursos futuros utilizarem essa rede.

Como o laboratório cria somente componentes básicos de rede e não mantém tráfego, o custo esperado desta etapa é zero.

---

## Estrutura

    08-aws-application-network/
    ├── README.md
    ├── images/
    │   └── .gitkeep
    └── scripts/
        ├── deploy-aws-application-network.ps1
        ├── remove-aws-application-network.ps1
        └── test-aws-application-network.ps1

---

## Scripts

| Script | Finalidade |
|---|---|
| `deploy-aws-application-network.ps1` | Criar e configurar os componentes da rede |
| `test-aws-application-network.ps1` | Validar recursos, associações, rotas, tags e proteções |
| `remove-aws-application-network.ps1` | Remover os recursos na ordem correta e confirmar o cleanup |

Os scripts serão executados separadamente. O script de implantação não realizará o cleanup automaticamente.

---

## Sequência de execução

1. renovar a sessão do AWS IAM Identity Center;
2. executar a inspeção prévia;
3. validar a sintaxe do script de implantação;
4. criar a rede;
5. executar o script de validação;
6. registrar evidências sem informações sensíveis;
7. utilizar a rede nos próximos laboratórios ou executar o cleanup;
8. confirmar a remoção dos recursos.

---

## Resultado esperado

Ao final da implantação, a conta deverá possuir:

- uma VPC dedicada disponível;
- DNS habilitado na VPC;
- duas sub-redes públicas em zonas diferentes;
- um Internet Gateway associado;
- uma tabela pública com rota externa;
- associações explícitas entre a tabela e as sub-redes;
- um Security Group sem regras de entrada;
- tags operacionais aplicadas aos recursos.

O script de validação deverá apresentar código de saída `0` somente quando todos os componentes obrigatórios estiverem corretos.

---

## Evidências

As evidências serão adicionadas após a implantação e a validação.

Capturas com Account ID, ARN, credenciais, URLs de autenticação ou identificadores completos deverão ser anonimizadas antes da publicação.

---

## Status

🔄 Estrutura do laboratório criada  
✅ Inspeção inicial concluída  
✅ CIDR da VPC verificado  
✅ Zonas de disponibilidade identificadas  
⬜ Script de implantação pendente  
⬜ Script de validação pendente  
⬜ Script de cleanup pendente  
⬜ Implantação e evidências pendentes  
