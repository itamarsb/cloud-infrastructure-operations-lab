# LAB 25 — Métricas no CloudWatch

## Status

Em desenvolvimento.

Etapa atual: cenário definido e validação dos pré-requisitos.

A infraestrutura ainda não foi provisionada e os resultados ainda não foram coletados.

## Objetivo

Consultar e interpretar métricas nativas de uma instância Amazon EC2 no Amazon CloudWatch e organizar um dashboard exclusivo do laboratório.

O exercício deverá demonstrar:

- identificação de namespace, métricas e dimensões;
- consultas com intervalo de tempo, período e estatística definidos;
- comparação entre repouso, carga de CPU e recuperação;
- distinção entre ausência de dados e valor zero;
- criação e validação de um dashboard;
- registro de evidências;
- remoção dos recursos exclusivos ao final.

## Organização

| Caminho | Finalidade |
|:---:|---|
| `README.md` | Procedimento, resultados e evidências |
| `scripts/` | Scripts PowerShell de preparação, consulta, validação e cleanup |
| `config/` | Configurações versionadas das consultas e do dashboard |
| `images/` | Capturas da execução |

## Ambiente

| Item | Configuração |
|:---:|:---:|
| Estação de trabalho | Windows 11 e Windows PowerShell 5.1 |
| Interface AWS | AWS CLI |
| Autenticação | AWS IAM Identity Center |
| Perfil | `cloud-operations-lab` |
| Região | `us-east-1` |
| Zona de disponibilidade prevista | `us-east-1a` |
| Sistema operacional da instância | Amazon Linux 2023 |
| Tipo de instância | `t3.micro` |
| Modo de créditos | `standard` |
| Monitoramento EC2 | Básico |
| Acesso administrativo | AWS Systems Manager |
| Namespace observado | `AWS/EC2` |
| Dimensão das consultas | `InstanceId` |

A AMI será resolvida pelo parâmetro público do Systems Manager:

`/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`

O ID da instância será obtido após o provisionamento e informado explicitamente nas consultas e no dashboard.

## Cenário

Será criada uma instância exclusiva para observar três fases:

1. Repouso: registrar o comportamento inicial após a estabilização.
2. Carga: executar uma atividade limitada de CPU pelo Systems Manager.
3. Recuperação: consultar as métricas após o encerramento da carga.

A duração da carga será limitada pelo próprio comando executado na instância.

O exercício não terá um valor obrigatório de utilização de CPU. A interpretação considerará a duração da carga, o período de agregação e os créditos disponíveis.

A carga será encerrada antes do cleanup.

## Infraestrutura exclusiva

| Recurso | Nome previsto |
|---|---|
| VPC | `lab25-cloudwatch-vpc` |
| Subnet pública | `lab25-cloudwatch-public-subnet-a` |
| Internet Gateway | `lab25-cloudwatch-igw` |
| Tabela de rotas | `lab25-cloudwatch-public-rt` |
| Security group | `lab25-cloudwatch-instance-sg` |
| IAM role | `lab25-cloudwatch-ec2-role` |
| Instance profile | `lab25-cloudwatch-ec2-profile` |
| Instância EC2 | `lab25-cloudwatch-instance` |
| Dashboard | `lab25-cloudwatch-metrics` |

Os recursos que suportarem tags receberão:

- `Project=cloud-infrastructure-operations-lab`
- `Lab=25`
- `ManagedBy=lab25-powershell`

O dashboard será identificado pelo nome exclusivo e pelo conteúdo validado.

A rede será exclusiva do laboratório, sem dependência de recursos removidos nos labs anteriores.

A instância terá:

- volume raiz EBS `gp3`, criptografado;
- exclusão do volume raiz ao terminar a instância;
- IMDSv2 obrigatório;
- IPv4 público atribuído automaticamente;
- nenhuma regra de entrada no security group;
- saída necessária para comunicação com os serviços AWS;
- acesso administrativo pelo Systems Manager;
- IAM role com a política `AmazonSSMManagedInstanceCore`.

Não serão criados NAT Gateway, Elastic IP, load balancer ou VPC endpoints.

Os IDs e ARNs dos recursos criados serão registrados para validação e cleanup.

## Métricas previstas

Todas as consultas utilizarão o namespace `AWS/EC2` e a dimensão `InstanceId` da instância exclusiva.

| Métrica | Estatística | Período | Interpretação |
|---|---|---|---|
| `CPUUtilization` | `Average` e `Maximum` | 300 segundos | Utilização de CPU no intervalo |
| `NetworkIn` | `Sum` | 300 segundos | Bytes recebidos no intervalo |
| `NetworkOut` | `Sum` | 300 segundos | Bytes enviados no intervalo |
| `StatusCheckFailed` | `Maximum` | 60 segundos | Ocorrência de falha nas verificações de status |

O monitoramento detalhado não será habilitado.

O tráfego de rede incluirá a comunicação administrativa e de serviços da instância. Não será interpretado como tráfego de usuários de uma aplicação.

As verificações de status da EC2 não serão utilizadas como medida de disponibilidade de uma aplicação.

## Regras de interpretação

- Registrar início e fim das consultas em UTC.
- Utilizar a mesma janela ao comparar estatísticas.
- Ordenar os pontos retornados por timestamp.
- Respeitar o período de publicação das métricas.
- Considerar o atraso de disponibilização dos dados.
- Não converter uma resposta vazia em zero.
- Não concluir que houve falha apenas porque ainda não existem pontos.
- Não exigir aumento de tráfego de rede durante uma carga de CPU.
- Não interpretar `Maximum` de um período agregado como captura instantânea.
- Registrar os horários de início e fim da carga para comparação com as métricas.

A janela inicial prevista será de 60 minutos, ajustada quando necessário para incluir todas as fases observadas.

## Dashboard

O dashboard terá widgets para:

- utilização de CPU;
- bytes recebidos;
- bytes enviados;
- falhas nas verificações de status.

Cada widget utilizará a Região e o InstanceId validados.

A configuração será mantida em `config/`, com substituição explícita do InstanceId antes da publicação.

A validação deverá conferir o conteúdo recuperado pela API, incluindo nome, Região, métricas, dimensão, períodos e estatísticas.

## Custos

O laboratório poderá gerar cobranças por:

- execução da instância EC2;
- armazenamento EBS;
- utilização do IPv4 público;
- transferência de dados aplicável;
- dashboard e chamadas de API do CloudWatch, conforme a utilização e as condições da conta.

Não será presumida elegibilidade ao nível gratuito.

O monitoramento básico evita habilitar o monitoramento detalhado pago da EC2.

O modo de créditos `standard` será configurado explicitamente para evitar cobrança de créditos excedentes do modo `unlimited`.

A instância permanecerá ativa somente durante o exercício.

A remoção do dashboard e da infraestrutura exclusiva faz parte dos critérios de conclusão.

## Escopo

Este laboratório terá foco em métricas nativas, consultas e dashboard.

Memória, ocupação do sistema de arquivos e coleta adicional com CloudWatch Agent serão tratados no Lab 26.

Alarmes e notificações serão tratados no Lab 27.

Recursos de outros projetos deverão ser preservados.

## Sequência de execução

1. Validar repositório local, identidade AWS, Região, zona e AMI.
2. Implementar os scripts e as configurações.
3. Validar a sintaxe e revisar os comandos de provisionamento.
4. Criar a infraestrutura exclusiva.
5. Confirmar a instância e o gerenciamento pelo Systems Manager.
6. Aguardar a estabilização e consultar as métricas de repouso.
7. Executar a carga limitada de CPU e registrar seus horários.
8. Consultar as métricas durante e após a carga.
9. Comparar repouso, carga e recuperação.
10. Criar e validar o dashboard.
11. Registrar resultados e evidências.
12. Remover o dashboard e a infraestrutura exclusiva.
13. Confirmar o cleanup e concluir a documentação.

## Cleanup

O cleanup deverá:

1. Confirmar conta, Região e identidade dos recursos.
2. Conferir nomes, tags e IDs registrados.
3. Remover somente o dashboard exclusivo.
4. Terminar a instância e aguardar sua finalização.
5. Confirmar a remoção do volume raiz.
6. Remover o instance profile e a IAM role exclusivos.
7. Remover os componentes exclusivos da rede na ordem de dependência.
8. Consultar novamente os serviços para confirmar a remoção.

A identificação de um recurso apenas por prefixo de nome não será suficiente para autorizar sua exclusão.

As métricas históricas do CloudWatch poderão permanecer consultáveis após a remoção da instância. Isso não significa que a infraestrutura continua ativa.

## Evidências previstas

- Identidade AWS, Região, zona e AMI.
- Recursos exclusivos provisionados.
- Instância gerenciada pelo Systems Manager.
- Consultas de repouso.
- Execução e horários da carga de CPU.
- Comparação entre repouso, carga e recuperação.
- Dashboard publicado e configuração recuperada.
- Remoção dos recursos exclusivos.
- Verificação final do cleanup.

## Critérios de conclusão

- [x] Cenário e recursos definidos.
- [x] Fontes de custo e estratégia de cleanup documentadas.
- [ ] Scripts e configurações publicados.
- [ ] Identidade AWS e pré-requisitos validados.
- [ ] Infraestrutura exclusiva provisionada e validada.
- [ ] Métricas consultadas e interpretadas.
- [ ] Ausência de dados tratada corretamente.
- [ ] Dashboard criado e validado.
- [ ] Evidências publicadas.
- [ ] Recursos exclusivos removidos.
- [ ] Cleanup confirmado.
- [ ] Documentação concluída.
