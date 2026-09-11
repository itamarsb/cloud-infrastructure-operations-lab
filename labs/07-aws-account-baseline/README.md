# Lab 07 — Baseline operacional da conta AWS

## Objetivo

Avaliar o estado operacional de uma conta AWS existente antes da implantação de novos recursos.

O laboratório utiliza consultas somente leitura para identificar configurações de identidade, rede, armazenamento, custos e tags, distinguindo recursos conhecidos de componentes legados ou sem origem documentada.

---

## Cenário

Uma conta AWS utilizada em diferentes laboratórios contém recursos criados em momentos distintos.

Antes de realizar novas implantações, é necessário:

- confirmar a identidade e a Região utilizadas;
- inventariar recursos existentes;
- identificar componentes parados ou potencialmente cobrados;
- verificar configurações de segurança do Amazon S3;
- revisar a cobertura de tags;
- confirmar a existência de controle orçamentário;
- evitar alterações em recursos cuja finalidade ainda não esteja clara.

---

## Ambiente

| Componente | Configuração |
|---|---|
| Estação de trabalho | Windows 11 |
| Terminal | PowerShell |
| AWS CLI | Versão 2 |
| Autenticação | AWS IAM Identity Center |
| Perfil | `cloud-operations-lab` |
| Região operacional | `us-east-1` |
| Modo inicial | Somente leitura |

---

## Escopo

O baseline contempla:

- validação da sessão AWS;
- confirmação do perfil e da Região;
- inventário de VPCs, sub-redes e Security Groups;
- identificação de instâncias EC2 e volumes EBS;
- consulta de Elastic IPs e NAT Gateways;
- verificação do Systems Manager;
- consulta de logs e alarmes do CloudWatch;
- análise das proteções de acesso público do S3;
- verificação de criptografia e versionamento dos buckets;
- avaliação da cobertura de tags;
- confirmação de orçamentos no AWS Budgets.

---

## Implementação

O script `scripts/test-aws-account-baseline.ps1` consolidará as consultas e apresentará um resumo anonimizado.

O script não deverá:

- criar recursos;
- modificar configurações;
- remover componentes;
- exibir nomes de buckets;
- exibir IDs de conta, ARNs ou credenciais;
- aplicar correções automaticamente.

As alterações necessárias serão avaliadas e executadas separadamente.

---

## Situação inicial identificada

A avaliação preliminar encontrou:

- uma VPC padrão;
- seis sub-redes;
- dois Security Groups;
- uma instância EC2 parada;
- um volume EBS associado;
- um bucket S3 legado;
- um orçamento AWS configurado;
- ausência de NAT Gateways e Elastic IPs;
- ausência de grupos de logs e alarmes no CloudWatch;
- baixa cobertura de tags operacionais.

Os recursos associados a outros repositórios serão preservados até que seu ciclo de vida seja revisado.

---

## Próximas ações

1. Adicionar o script de baseline.
2. Validar sua sintaxe.
3. Executar a auditoria somente leitura.
4. Revisar os desvios encontrados.
5. Remover o bucket legado após as verificações de segurança.
6. Registrar o estado final do ambiente.

---

## Status

🚧 Laboratório em desenvolvimento.
