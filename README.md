# Cloud Infrastructure Operations Lab

Laboratórios práticos para desenvolvimento das competências exigidas em vagas de **Analista Cloud Júnior**, utilizando **AWS**, **Linux**, **Terraform**, **Docker**, **CloudWatch** e **Zabbix**.

O objetivo deste repositório é proporcionar uma experiência de aprendizagem baseada em cenários reais de operações em nuvem, priorizando simplicidade, boas práticas e produtividade.

---

## Tecnologias

![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazonaws&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![CloudWatch](https://img.shields.io/badge/CloudWatch-FF9900?logo=amazonaws&logoColor=white)
![Zabbix](https://img.shields.io/badge/Zabbix-D40000?logo=zabbix&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?logo=git&logoColor=white)
![Markdown](https://img.shields.io/badge/Markdown-000000?logo=markdown&logoColor=white)
![Mermaid](https://img.shields.io/badge/Mermaid-FF3670?logo=mermaid&logoColor=white)

---

## Objetivo

Este laboratório foi desenvolvido para ajudar estudantes e profissionais iniciantes a desenvolver competências práticas em:

- Administração de ambientes Linux;
- Serviços fundamentais da AWS;
- Infraestrutura como Código (Terraform);
- Containers com Docker;
- Monitoramento e Observabilidade;
- Troubleshooting;
- Cloud Operations.

Todo o conteúdo foi organizado em uma sequência progressiva de laboratórios, permitindo construir conhecimento passo a passo.

---

## Público-alvo

Este repositório é indicado para:

- estudantes de Computação;
- profissionais em transição para Cloud Computing;
- candidatos a vagas de Analista Cloud Júnior;
- profissionais de Infraestrutura;
- profissionais de Service Desk que desejam evoluir para Cloud.

---

## Roadmap

```mermaid
flowchart TB

    START([Início])

    subgraph F1["Fundamentos"]
        direction LR
        M00["Preparação<br/>do ambiente"]
        M01["Linux<br/>e Git"]
        M02["Redes<br/>e AWS Core"]

        M00 --> M01 --> M02
    end

    subgraph F2["Cloud Operations"]
        direction LR
        M03["Cloud<br/>Operations"]
        M04["Terraform"]

        M03 --> M04
    end

    subgraph F3["Operações"]
        direction LR
        M05["Monitoramento"]
        M06["Docker"]
        M07["Troubleshooting"]

        M05 --> M06 --> M07
    end

    subgraph F4["Capstone"]
        direction LR
        M08["Projeto Final"]
        DONE([Pronto para o portfólio])

        M08 --> DONE
    end

    START --> M00
    M02 --> M03
    M04 --> M05
    M07 --> M08

    classDef start fill:#0f172a,stroke:#38bdf8,color:#fff,stroke-width:2px;
    classDef module fill:#f8fafc,stroke:#64748b,color:#0f172a,stroke-width:1.5px;
    classDef final fill:#ecfdf5,stroke:#10b981,color:#064e3b,stroke-width:2px;
    classDef finish fill:#0f766e,stroke:#14b8a6,color:#fff,stroke-width:2px;

    class START start;
    class M00,M01,M02,M03,M04,M05,M06,M07 module;
    class M08 final;
    class DONE finish;

    style F1 fill:#f8fafc,stroke:#94a3b8
    style F2 fill:#f8fafc,stroke:#94a3b8
    style F3 fill:#f8fafc,stroke:#94a3b8
    style F4 fill:#f0fdfa,stroke:#14b8a6
```

---

## O que você aprenderá

Ao concluir esta trilha você será capaz de:

- preparar um ambiente profissional para estudos;
- utilizar Linux no contexto de Cloud Computing;
- administrar recursos básicos da AWS;
- criar infraestrutura utilizando Terraform;
- monitorar servidores com CloudWatch e Zabbix;
- trabalhar com containers Docker;
- solucionar problemas operacionais;
- executar um projeto integrador simulando um ambiente real.

---

## Tecnologias utilizadas

| Categoria | Tecnologias |
|-----------|-------------|
| Cloud Computing | AWS |
| Sistema Operacional | Linux |
| Infraestrutura como Código | Terraform |
| Containers | Docker |
| Monitoramento | CloudWatch, Zabbix |
| Versionamento | Git |
| Documentação | Markdown, Mermaid |

---

## Estrutura do projeto

```text
cloud-infrastructure-operations-lab/
│
├── docs/
├── labs/
├── terraform/
├── incident-response/
├── checklists/
├── resources/
├── templates/
├── scripts/
└── images/
```

---

## Organização dos laboratórios

| Fase | Conteúdo |
|------|----------|
| 00 | Preparação do ambiente |
| 01 | Linux e Git |
| 02 | AWS Foundations |
| 03 | Cloud Operations |
| 04 | Terraform |
| 05 | Monitoramento |
| 06 | Docker |
| 07 | Troubleshooting |
| 08 | Projeto Final |

---

## Como utilizar

1. Clone este repositório.

2. Consulte o roadmap.

3. Execute os laboratórios na ordem proposta.

4. Ao final de cada laboratório:

   - realize o cleanup dos recursos;
   - registre as lições aprendidas;
   - utilize os checklists de validação.

---

## Filosofia do projeto

Este repositório prioriza:

- simplicidade;
- produtividade;
- boas práticas;
- documentação clara;
- ambientes reproduzíveis;
- laboratórios de baixo custo;
- aprendizado baseado em prática.

O foco não é memorizar serviços da AWS, mas compreender como eles são utilizados em ambientes reais de Cloud Operations.

---

## Licença

Este projeto está distribuído sob a licença MIT.
