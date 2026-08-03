# Arquitetura do Repositório

> **Projeto:** Cloud Infrastructure Operations Lab  
> **Versão:** 1.0 (Draft)  
> **Status:** Em desenvolvimento  
> **Idioma principal:** Português (Brasil)

---

# Índice

1. Introdução
2. Objetivos
3. Público-alvo
4. Escopo do Projeto
5. Princípios do Projeto
6. Estrutura do Repositório
7. Organização dos Laboratórios
8. Estratégia de Infraestrutura como Código (Terraform)
9. Recursos de Apoio
10. Simulações de Incidentes
11. Templates e Padronização
12. Convenções
13. Evolução do Projeto
14. Considerações Finais

---

# 1. Introdução

O **Cloud Infrastructure Operations Lab** é um projeto open source desenvolvido com o objetivo de preparar profissionais para atuar em cargos de entrada na área de Computação em Nuvem, especialmente nas funções de **Analista Cloud Júnior**, **Analista de Infraestrutura Cloud** e **Cloud Operations**.

O projeto foi concebido para reproduzir atividades frequentemente encontradas no ambiente corporativo brasileiro, priorizando experiências práticas em detrimento da simples apresentação de conceitos teóricos.

Ao contrário de repositórios focados exclusivamente na preparação para certificações, este projeto busca desenvolver a capacidade de operar, documentar, investigar problemas e compreender o funcionamento de ambientes em nuvem utilizando a Amazon Web Services (AWS).

Todo o conteúdo foi planejado para ser estudado de forma progressiva, permitindo que profissionais iniciantes desenvolvam fundamentos sólidos antes de avançarem para temas mais complexos.

---

# 2. Objetivos

Os principais objetivos deste projeto são:

- desenvolver conhecimentos práticos em Cloud Computing utilizando AWS;
- preparar profissionais para vagas de Analista Cloud Júnior;
- ensinar fundamentos de Linux aplicados à Computação em Nuvem;
- desenvolver conhecimentos básicos de redes de computadores;
- introduzir Infraestrutura como Código utilizando Terraform;
- ensinar boas práticas de documentação técnica;
- desenvolver capacidade de troubleshooting;
- estimular o raciocínio operacional utilizado em equipes de Cloud Operations;
- criar um portfólio técnico organizado e alinhado às necessidades do mercado brasileiro.

---

# 3. Público-alvo

Este projeto foi desenvolvido para:

- estudantes de tecnologia;
- profissionais em transição de carreira;
- candidatos buscando sua primeira oportunidade em Cloud Computing;
- profissionais iniciando estudos em AWS;
- profissionais interessados em Cloud Operations;
- profissionais interessados em Infraestrutura Cloud.

Não é necessário possuir experiência prévia com Amazon Web Services.

Conhecimentos básicos de informática e sistemas operacionais são suficientes para acompanhar os laboratórios.

---

# 4. Escopo do Projeto

Este repositório possui um escopo bem definido.

Seu objetivo não é apresentar todas as tecnologias existentes no ecossistema Cloud, mas concentrar esforços naquelas mais frequentemente encontradas em vagas de Analista Cloud Júnior no mercado brasileiro.

## Tecnologias incluídas

Entre os principais temas abordados estão:

- Amazon Web Services (AWS);
- Linux;
- Redes de Computadores;
- Git;
- GitHub;
- Visual Studio Code;
- Bash;
- AWS CLI;
- AWS Systems Manager (SSM);
- Amazon EC2;
- Amazon VPC;
- IAM;
- Amazon S3;
- Amazon CloudWatch;
- Terraform;
- Docker (fundamentos);
- Zabbix Agent.

## Tecnologias fora do escopo

Nesta primeira versão do projeto não fazem parte do escopo:

- Kubernetes avançado;
- Amazon EKS;
- OpenTelemetry;
- Prometheus;
- Grafana;
- Loki;
- Tempo;
- Jaeger;
- Service Mesh;
- Chaos Engineering;
- Platform Engineering;
- CI/CD avançado.

Esses temas poderão ser abordados em projetos independentes ou em futuras evoluções deste repositório.

---

# 5. Princípios do Projeto

Todo o desenvolvimento deste projeto segue os princípios descritos abaixo.

## Aprendizado baseado em prática

Todo conceito apresentado deverá possuir aplicação prática através de laboratórios.

Sempre que possível, a teoria será acompanhada de exemplos reais de utilização.

---

## Um laboratório, uma competência principal

Cada laboratório deverá possuir um objetivo bem definido.

Evita-se reunir diversos assuntos diferentes em um único laboratório.

---

## Progressão gradual

Os laboratórios foram organizados do nível básico para o intermediário.

Novos conhecimentos sempre utilizarão conceitos apresentados anteriormente.

---

## Documentação como parte da engenharia

A produção de documentação técnica é considerada uma competência fundamental para profissionais de Cloud Computing.

Cada laboratório deverá ser suficientemente documentado para permitir sua reprodução por outros profissionais.

---

## Simulação de ambientes reais

Sempre que possível, os laboratórios serão contextualizados através de situações semelhantes às encontradas no ambiente corporativo.

Essa abordagem busca aproximar o estudante da rotina de trabalho em equipes de Cloud Operations.

---

## Consciência de custos

Todo laboratório que criar recursos na AWS deverá apresentar orientações para remoção da infraestrutura ao final da atividade.

O objetivo é incentivar boas práticas de utilização da nuvem e evitar custos desnecessários.

---

## Infraestrutura antes da automação

Sempre que possível, a infraestrutura será criada manualmente antes da utilização do Terraform.

Essa abordagem facilita a compreensão do funcionamento dos serviços da AWS antes da introdução da automação.

---

## Simplicidade antes da complexidade

Sempre será priorizada a compreensão dos fundamentos antes da introdução de arquiteturas mais sofisticadas.

Este projeto não pretende acelerar artificialmente a curva de aprendizado do estudante.

---

## Terminologia técnica

Embora a documentação seja produzida em português, os nomes oficiais de serviços, comandos, tecnologias e recursos permanecerão em inglês.

Essa decisão aproxima o estudante da terminologia utilizada no ambiente profissional.
