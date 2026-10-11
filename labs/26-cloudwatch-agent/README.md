# LAB 26 — CloudWatch Agent

## Status

Em desenvolvimento.

Etapa atual: definição do cenário e organização inicial.

A infraestrutura ainda não foi provisionada. O CloudWatch Agent ainda não foi instalado, e os resultados ainda não foram coletados.

## Objetivo

Instalar, configurar e validar o Amazon CloudWatch Agent em uma instância EC2 Linux exclusiva.

O laboratório complementará as métricas nativas estudadas no LAB 25 com:

- utilização de memória;
- utilização do sistema de arquivos raiz;
- envio de eventos de um arquivo de log dedicado;
- validação do serviço do agente;
- confirmação independente da chegada dos dados à AWS;
- remoção dos recursos exclusivos ao final.

## Organização

| Caminho | Finalidade |
|:---:|:---:|
| `README.md` | Cenário, procedimento, resultados e evidências |
| `config/` | Configuração do agente, parâmetros e políticas |
| `scripts/` | Provisionamento, configuração, validação e cleanup |
| `images/` | Capturas da execução |

Inventário, recibos e relatórios de execução serão armazenados localmente fora do repositório.

## Ambiente previsto

| Item | Configuração |
|:---:|:---:|
| Estação de trabalho | Windows 11 |
| Shell | Windows PowerShell 5.1 |
| Interface AWS | AWS CLI |
| Autenticação | AWS IAM Identity Center |
| Perfil | `cloud-operations-lab` |
| Região | `us-east-1` |
| Zona de disponibilidade | `us-east-1a` |
| Sistema operacional da instância | Amazon Linux 2023 |
| Arquitetura | `x86_64` |
| Tipo de instância | `t3.micro` |
| Modo de créditos | `standard` |
| Monitoramento nativo EC2 | Básico |
| Acesso administrativo | AWS Systems Manager |
| Volume raiz | EBS `gp3`, criptografado, 8 GiB |
| Coletor adicional | Amazon CloudWatch Agent |

A AMI será resolvida pelo parâmetro público:

```text
/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
```

A infraestrutura exclusiva do LAB 25 foi removida. Este laboratório terá novos recursos e um inventário próprio.

## Cenário

O exercício terá quatro etapas principais:

1. Provisionar e validar uma instância gerenciada pelo Systems Manager.
2. Instalar o CloudWatch Agent e aplicar a configuração versionada.
3. Confirmar métricas de memória e disco e eventos do arquivo de log dedicado.
4. Remover os recursos e confirmar o cleanup.

A execução inicial observará o comportamento normal da instância. Não será necessário provocar esgotamento de memória ou preencher o volume raiz.

Os eventos de log serão sintéticos e identificados como parte do laboratório. Eles servirão para validar o caminho entre o arquivo local e o CloudWatch Logs.

## Infraestrutura exclusiva

| Recurso | Nome previsto |
|---|---|
| VPC | `lab26-cloudwatch-agent-vpc` |
| Subnet pública | `lab26-cloudwatch-agent-public-subnet-a` |
| Internet Gateway | `lab26-cloudwatch-agent-igw` |
| Tabela de rotas | `lab26-cloudwatch-agent-public-rt` |
| Security group | `lab26-cloudwatch-agent-instance-sg` |
| IAM role | `lab26-cloudwatch-agent-ec2-role` |
| Instance profile | `lab26-cloudwatch-agent-ec2-profile` |
| Instância EC2 | `lab26-cloudwatch-agent-instance` |
| Grupo de logs | `/cloud-infrastructure-operations-lab/lab26/application` |

A rede utilizará:

- VPC: `10.26.0.0/16`;
- subnet: `10.26.1.0/24`;
- rota pública pelo Internet Gateway;
- IPv4 público atribuído automaticamente à instância.

A instância terá:

- IMDSv2 obrigatório;
- nenhuma regra de entrada no security group;
- saída para os serviços necessários;
- administração pelo Systems Manager;
- exclusão do volume raiz na terminação.

Não serão criados NAT Gateway, Elastic IP, load balancer ou VPC endpoints.

Os recursos que suportarem tags receberão:

```text
Project=cloud-infrastructure-operations-lab
Lab=26
ManagedBy=lab26-powershell
RunId=<identificador da execução>
Name=<nome do recurso>
```

Os IDs e identificadores de propriedade serão registrados antes das etapas de validação e cleanup.

## Identidade e permissões

A identidade do operador será validada antes das chamadas AWS.

A instância utilizará uma IAM role exclusiva, com permissões para:

- gerenciamento pelo Systems Manager;
- publicação das métricas previstas;
- envio dos eventos ao grupo de logs do laboratório.

As políticas efetivamente utilizadas serão documentadas e conferidas durante a implementação.

O grupo de logs será criado e identificado pelo provisionamento, com retenção explícita de um dia.

Credenciais estáticas não serão gravadas na instância nem nos arquivos de configuração.

## Métricas previstas

| Métrica publicada | Origem | Unidade | Coleta prevista |
|---|---|---|---|
| `mem_used_percent` | Memória do sistema operacional | Percent | 60 segundos |
| `disk_used_percent` | Sistema de arquivos raiz `/` | Percent | 60 segundos |

Namespace exclusivo:

```text
Lab26/CWAgent
```

A configuração adicionará `InstanceId` às métricas.

As dimensões efetivamente publicadas serão consultadas e registradas antes das consultas de valores. A métrica de disco poderá incluir dimensões adicionais referentes ao caminho, dispositivo e tipo de sistema de arquivos.

Não serão criadas agregações adicionais na configuração inicial.

### Interpretação

- Memória utilizada será interpretada segundo a definição da métrica do agente.
- Utilização de disco será associada ao sistema de arquivos observado.
- A ocupação do sistema de arquivos não será confundida com métricas de I/O do volume EBS.
- Percentuais de memória e disco não serão comparados como se representassem o mesmo recurso.
- As consultas registrarão namespace, dimensões, janela, período e estatística.
- Uma resposta sem pontos não será convertida em zero.
- O atraso de publicação será considerado antes de concluir que existe falha de coleta.

## Coleta de logs

Arquivo dedicado previsto na instância:

```text
/var/log/lab26/application.log
```

Grupo exclusivo:

```text
/cloud-infrastructure-operations-lab/lab26/application
```

O stream identificará a instância. Cada evento de teste incluirá:

- timestamp em UTC;
- identificador da execução;
- marcador exclusivo do evento;
- mensagem sintética do laboratório.

A validação confirmará:

1. Existência do arquivo e permissões de leitura pelo agente.
2. Presença do marcador no arquivo local.
3. Existência do grupo e do stream esperados.
4. Chegada do mesmo marcador ao CloudWatch Logs.

O status ativo do serviço não será considerado suficiente para provar que os eventos chegaram à AWS.

A retenção será de um dia. O grupo de logs será removido no cleanup; a retenção não substituirá a exclusão.

## Instalação e configuração do agente

A instalação e a configuração serão executadas pelo Systems Manager.

A implementação deverá:

- registrar a versão instalada;
- copiar a configuração JSON versionada;
- preservar as expressões de metadados usadas pelo agente;
- aplicar a configuração explicitamente;
- confirmar o resultado do comando SSM;
- consultar o estado do serviço e o status do agente;
- verificar os logs locais de configuração e execução;
- confirmar a publicação de métricas e eventos.

A validação distinguirá:

- instalação do pacote;
- aceitação da configuração;
- serviço em execução;
- chegada dos dados ao CloudWatch.

## Sequência de execução

1. Criar e validar a estrutura do laboratório.
2. Definir parâmetros, trust policy e configuração do agente.
3. Validar sintaxe PowerShell e conteúdo dos JSONs.
4. Conferir identidade AWS, região, zona, AMI e conflitos de nomes.
5. Provisionar a infraestrutura e o grupo de logs exclusivos.
6. Confirmar EC2 e gerenciamento SSM.
7. Instalar e configurar o CloudWatch Agent.
8. Conferir serviço, configuração e logs locais do agente.
9. Aguardar e consultar métricas de memória e disco.
10. Gerar eventos sintéticos identificados.
11. Confirmar os eventos no CloudWatch Logs.
12. Registrar resultados e evidências.
13. Remover os recursos exclusivos.
14. Confirmar o cleanup por consultas independentes.
15. Concluir a documentação.

## Custos

O cenário poderá gerar cobranças por:

- execução da instância EC2;
- armazenamento EBS;
- utilização do IPv4 público;
- transferência de dados aplicável;
- métricas personalizadas;
- ingestão e armazenamento de logs;
- chamadas de API conforme a utilização.

Não será presumida elegibilidade ao nível gratuito.

A configuração inicial limitará a coleta a duas métricas, ao sistema de arquivos raiz e a um arquivo de log dedicado.

O intervalo de coleta previsto será de 60 segundos. Não será utilizada coleta de métricas com intervalo inferior a 60 segundos.

O volume de eventos sintéticos será pequeno e controlado. A infraestrutura permanecerá ativa somente durante o exercício.

## Cleanup previsto

O cleanup deverá:

1. Conferir conta, região, inventário e propriedade.
2. Confirmar a conclusão dos comandos SSM do laboratório.
3. Terminar a instância e aguardar sua finalização.
4. Confirmar a exclusão do volume raiz.
5. Remover o instance profile e a IAM role exclusivos.
6. Remover os componentes exclusivos da rede.
7. Remover o grupo de logs exclusivo.
8. Confirmar a ausência dos recursos por consultas independentes.
9. Preservar inventário, recibos e relatórios locais.

As métricas históricas poderão permanecer consultáveis após a remoção da instância. O cleanup não tentará excluir pontos individuais de métricas.

Recursos de outros laboratórios e projetos permanecerão fora do escopo de alteração e remoção.

## Evidências previstas

- Estrutura e configurações publicadas.
- Identidade AWS e pré-requisitos.
- Infraestrutura criada e SSM Online.
- Versão instalada do CloudWatch Agent.
- Configuração aplicada.
- Serviço e status do agente.
- Métricas de memória e disco com suas dimensões.
- Marcador de teste no arquivo local.
- Mesmo marcador recebido pelo CloudWatch Logs.
- Retenção do grupo de logs.
- Remoção dos recursos.
- Verificação final do cleanup.

## Critérios de conclusão

- [x] Cenário e escopo definidos.
- [x] Fontes de custo e estratégia de cleanup documentadas.
- [ ] Configurações e scripts publicados.
- [ ] Identidade AWS e pré-requisitos validados.
- [ ] Infraestrutura exclusiva provisionada e validada.
- [ ] CloudWatch Agent instalado.
- [ ] Configuração aplicada e conferida.
- [ ] Serviço e status do agente validados.
- [ ] Métricas de memória recebidas.
- [ ] Métricas de disco recebidas.
- [ ] Dimensões e resultados interpretados.
- [ ] Eventos sintéticos recebidos no CloudWatch Logs.
- [ ] Retenção conferida.
- [ ] Evidências publicadas.
- [ ] Recursos exclusivos removidos.
- [ ] Cleanup confirmado.
- [ ] Documentação concluída.

## Referências

- [Instalação do CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-EC2-Instance.html)
- [Instalação pelo Systems Manager](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/installing-cloudwatch-agent-ssm.html)
- [Configuração do CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)
- [Exemplos de configuração](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file-examples.html)
