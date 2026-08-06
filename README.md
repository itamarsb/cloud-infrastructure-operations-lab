# Cloud Infrastructure Operations Lab

Laboratórios práticos para desenvolvimento das competências exigidas em vagas de **Analista Cloud Júnior**, utilizando **AWS**, **Linux**, **Terraform**, **Docker**, **CloudWatch** e **Zabbix**.

O objetivo deste repositório é proporcionar uma experiência de aprendizagem baseada em cenários reais de operações em nuvem, priorizando simplicidade, boas práticas e produtividade.

---

## Tecnologias

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonaws&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![CloudWatch](https://img.shields.io/badge/CloudWatch-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![Zabbix](https://img.shields.io/badge/Zabbix-D40000?style=for-the-badge&logo=zabbix&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)
![Markdown](https://img.shields.io/badge/Markdown-000000?style=for-the-badge&logo=markdown&logoColor=white)
![Mermaid](https://img.shields.io/badge/Mermaid-FF3670?style=for-the-badge&logo=mermaid&logoColor=white)

## Competências

![Cloud Operations](https://img.shields.io/badge/Cloud%20Operations-0052CC?style=for-the-badge)
![Linux Administration](https://img.shields.io/badge/Linux%20Administration-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Networking](https://img.shields.io/badge/Networking-0078D4?style=for-the-badge)
![Infrastructure as Code](https://img.shields.io/badge/Infrastructure%20as%20Code-7B42BC?style=for-the-badge)
![Monitoring](https://img.shields.io/badge/Monitoring-FF9900?style=for-the-badge)
![Observability](https://img.shields.io/badge/Observability-6F42C1?style=for-the-badge)
![Troubleshooting](https://img.shields.io/badge/Troubleshooting-FF6B00?style=for-the-badge)
![Incident Response](https://img.shields.io/badge/Incident%20Response-E63946?style=for-the-badge)
![FinOps](https://img.shields.io/badge/FinOps-00A86B?style=for-the-badge)

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

    subgraph F1["01 · Fundamentos"]
        direction LR
        M00["Módulo 00<br/>Preparação do ambiente"]
        M01["Módulo 01<br/>Fundamentos de Linux e Git"]
        M02["Módulo 02<br/>Redes e AWS Core"]

        M00 --> M01
        M01 --> M02
    end

    subgraph F2["02 · Operações em Nuvem"]
        direction LR
        M03["Módulo 03<br/>Cloud Operations"]
        M04["Módulo 04<br/>Infraestrutura como Código<br/>com Terraform"]

        M03 --> M04
    end

    subgraph F3["03 · Observabilidade e Containers"]
        direction LR
        M05["Módulo 05<br/>Monitoramento e<br/>Observabilidade"]
        M06["Módulo 06<br/>Fundamentos de Docker"]

        M05 --> M06
    end

    subgraph F4["04 · Confiabilidade e Resolução de Problemas"]
        direction LR
        M07["Módulo 07<br/>Troubleshooting e<br/>Resposta a Incidentes"]
    end

    subgraph F5["05 · FinOps e Projeto Integrador"]
        direction LR
        M08["Módulo 08<br/>Fundamentos de FinOps"]
        M09["Módulo 09<br/>Projeto Final<br/>Operações de Infraestrutura<br/>em Nuvem"]
        DONE([Portfólio pronto<br/>para demonstração])

        M08 --> M09
        M09 --> DONE
    end

    START --> M00
    M02 --> M03
    M04 --> M05
    M06 --> M07
    M07 --> M08

    C1["Marco 1<br/>Linux / Git / Redes / AWS"]
    C2["Marco 2<br/>Cloud Operations / Terraform"]
    C3["Marco 3<br/>Observabilidade / Docker"]
    C4["Marco 4<br/>Diagnóstico / Resposta / Recuperação"]
    C5["Marco 5<br/>FinOps / Projeto Final"]

    M02 -.-> C1
    M04 -.-> C2
    M06 -.-> C3
    M07 -.-> C4
    M09 -.-> C5

    classDef start fill:#0f172a,stroke:#38bdf8,color:#ffffff,stroke-width:2px
    classDef module fill:#f8fafc,stroke:#64748b,color:#0f172a,stroke-width:1.5px
    classDef milestone fill:#eef2ff,stroke:#6366f1,color:#312e81,stroke-width:1.5px
    classDef final fill:#ecfdf5,stroke:#10b981,color:#064e3b,stroke-width:2px
    classDef finish fill:#0f766e,stroke:#14b8a6,color:#ffffff,stroke-width:2px

    class START start
    class M00,M01,M02,M03,M04,M05,M06,M07,M08 module
    class C1,C2,C3,C4,C5 milestone
    class M09 final
    class DONE finish

    style F1 fill:#f8fafc,stroke:#94a3b8,stroke-width:1px
    style F2 fill:#f8fafc,stroke:#94a3b8,stroke-width:1px
    style F3 fill:#f8fafc,stroke:#94a3b8,stroke-width:1px
    style F4 fill:#f8fafc,stroke:#94a3b8,stroke-width:1px
    style F5 fill:#f0fdfa,stroke:#14b8a6,stroke-width:1.5px
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
|:------:|----------|
| 00 | Preparação do ambiente |
| 01 | Linux e Git |
| 02 | Redes e AWS Core |
| 03 | Cloud Operations |
| 04 | Terraform |
| 05 | Monitoramento |
| 06 | Docker |
| 07 | Troubleshooting |
| 08 | FinOps básico |
| 09 | Projeto Final |

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
