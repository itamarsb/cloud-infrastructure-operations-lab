# Auditoria de documentação e internacionalização

**Repositório:** `cloud-infrastructure-operations-lab`  
**Início:** 2026-11-09  
**Idioma principal:** português brasileiro  
**Idioma complementar:** inglês técnico  
**Objetivo:** melhorar legibilidade, consistência, precisão e navegação para leitores externos sem alterar ou ampliar os resultados documentados.

Este arquivo registra oportunidades de melhoria. Um item listado aqui **não representa uma falha técnica comprovada** até que seu documento e suas evidências sejam examinados. O registro não deve substituir os procedimentos nem a documentação de execução dos laboratórios.

## Convenção editorial

- Preservar `README.md` como fonte principal em português e criar `README.en.md` no mesmo diretório.
- Disponibilizar links recíprocos PT-BR ↔ EN no início de cada README.
- Usar inglês natural, objetivo e consistente, evitando tradução literal e frases promocionais.
- Distinguir **executado / observado / inferido / simulado / planejado**.
- Preservar valores, unidades, datas, parâmetros, comandos, nomes de serviços e limitações.
- Não transformar experimentos sintéticos em incidentes reais, nem observações isoladas em garantias.
- Preferir instruções dirigidas ao leitor, sem trechos com aparência de conversa privada.
- Reutilizar imagens e scripts existentes; não duplicar evidências sem necessidade.
- Validar links relativos, imagens, Markdown e coerência entre o índice principal e cada laboratório.
- Registrar alterações propostas antes de intervenções técnicas maiores.

## Controle de auditoria

| ID | Escopo | Constatação ou verificação proposta | Prioridade | Situação |
|---|---|---|---|---|
| DOC-001 | `README.md` | Resumo em inglês atual é curto para servir como documentação paralela; criar link para `README.en.md` | Alta | Em implementação |
| DOC-002 | `README.en.md` | Verificar paridade de escopo com o documento português e preservar ressalvas sobre dados sintéticos | Alta | Primeira versão editorial |
| DOC-003 | Índice de labs | Conferir todos os caminhos, status e distinção entre Labs 00–28 concluídos e Lab 29 planejado | Alta | Estrutura conferida; links individuais pendentes |
| DOC-004 | README principal | Avaliar redundância entre tabela de progresso, resultados anteriores, práticas demonstradas e princípios operacionais | Média | Pendente |
| DOC-005 | README principal | Distinguir ferramentas já utilizadas das previstas (por exemplo, Docker e Zabbix) | Alta | Sinalização existente; revisar por laboratório |
| DOC-006 | Labs 25–28 | Revisar métricas, janelas, unidades, dados ausentes, testes sintéticos e afirmações sobre cleanup | Alta | Pendente |
| DOC-007 | Labs 14–18 | Revisar termos de falha, mitigação, rollback, disponibilidade e intervalos observados | Alta | Pendente |
| DOC-008 | Labs 19–24 | Verificar precisão sobre estado Terraform, locking, drift, plano sem mudanças e CI | Alta | Pendente |
| DOC-009 | Labs 00–13 | Avaliar pré-requisitos, neutralidade editorial, reprodutibilidade e clareza das instruções | Média | Pendente |
| DOC-010 | Todos os READMEs | Procurar trechos com tom de conversa, autoelogio, repetição excessiva ou menções a interlocutores | Média | Pendente |
| DOC-011 | Todos os READMEs | Revisar terminologia bilíngue, ortografia, pontuação e clareza para público externo | Média | Pendente |
| DOC-012 | Recursos visuais | Conferir legendas, descrição das evidências, acessibilidade e links relativos | Média | Pendente |
| DOC-013 | `docs/roadmap.md` | Avaliar necessidade de `docs/roadmap.en.md` e consistência com o progresso dos laboratórios | Média | Pendente |
| DOC-014 | `docs/career-path.md` e `docs/faq.md` | Arquivos possuem apenas conteúdo mínimo; decidir entre preenchimento útil ou remoção posterior | Baixa | Pendente |
| DOC-015 | Templates auxiliares | Revisar templates vazios ou mínimos para evitar aparência de documentação inacabada | Baixa | Pendente |
| DOC-016 | Segurança | Revisar comandos destrutivos, custos, referências sensíveis e proteção dos recursos compartilhados | Alta | Pendente |

## Auditoria específica — Lab 00

**Data:** 2026-11-09  
**Arquivos examinados:** `labs/00-workstation-preparation/README.md` e `labs/00-workstation-preparation/scripts/validate-workstation.ps1`.  
**Intervenção:** criada a documentação `README.en.md` com navegação recíproca; o conteúdo técnico português original e o script foram preservados.

| ID | Escopo | Constatação ou verificação proposta | Prioridade | Situação |
|---|---|---|---|---|
| DOC-017 | Lab 00 | Checklist de execução em PT-BR usa `[X]` e pode ser interpretado como preenchido pelo leitor; separar exemplo histórico de checklist reutilizável | Média | Pendente no PT-BR; mitigado no EN |
| DOC-018 | Lab 00 | Reforçar o aviso de remoção irreversível por `Remove-Item -Recurse -Force` e preservar a cópia local antes do cleanup | Alta | Pendente no PT-BR; reforçado no EN |
| DOC-019 | Lab 00 | Remover expressão conversacional “No nosso caso” e revisar referências a publicação no LinkedIn; manter tom neutro para leitor desconhecido | Média | Pendente no PT-BR; ajustado no EN |
| DOC-020 | Lab 00 | Consolidar repetições entre validação, checklist, lições aprendidas e resultado final sem perder critérios de aceitação | Média | Pendente |
| DOC-021 | Lab 00 | Descrições de imagens `![LAB00]` são genéricas; criar textos alternativos específicos | Média | Pendente no PT-BR; ajustado no EN |
| DOC-022 | Lab 00 | Diferenciar pré-requisito de conta GitHub e clonagem anônima de repositório público; esclarecer `git remote -v` sem sugerir acesso de escrita | Baixa | Pendente no PT-BR; ajustado no EN |
| DOC-023 | Lab 00 | Comando `Test-Connection` não demonstra, isoladamente, funcionamento do GitHub via HTTPS; esclarecer limitações do teste | Média | Pendente no PT-BR; observado no EN |
| DOC-024 | Lab 00 | Verificar consistência do checklist, nomes dos diretórios, imagens e documentação do script de validação com os arquivos do repositório | Média | Leitura estática concluída; execução não realizada |
| DOC-025 | Lab 00 | O script usa PowerShell ≥5 e Windows; o README mostra exemplo PowerShell 7; evitar tratar versão exemplificativa como obrigatória | Baixa | Esclarecido no EN |

**Critério editorial:** a versão inglesa conserva os doze passos e as dezenove imagens existentes, substitui descrições genéricas das imagens por alternativas mais informativas e esclarece que os comandos mostrados não foram reexecutados nesta revisão. O código do script foi inspecionado estaticamente, não executado. Os apontamentos sobre o texto português permanecem abertos para revisão posterior.

## Auditoria específica — Lab 01

**Data:** 2026-11-09  
**Arquivo examinado:** `labs/01-secure-aws-account-configuration/README.md`.  
**Intervenção:** criação de `README.en.md` com 13 etapas e 10 imagens preservadas; navegação bilíngue adicionada ao README principal do laboratório. Nenhuma configuração AWS foi alterada e não houve reexecução dos procedimentos.

| ID | Escopo | Constatação ou verificação proposta | Prioridade | Situação |
|---|---|---|---|---|
| DOC-026 | Lab 01 | Distinguir planos AWS Free e Paid, créditos e limites atuais; não presumir elegibilidade uniforme ao Free Tier | Alta | Registrado para PT-BR; esclarecido no EN |
| DOC-027 | Lab 01 | Evidenciar que Budgets/alertas não são teto de gastos, não bloqueiam serviços e podem ter atraso | Alta | Ressalva existente no PT-BR; reforçada no EN |
| DOC-028 | Lab 01 | Atualizar recomendações de MFA com preferência por métodos resistentes a phishing e dispositivos redundantes, sem descaracterizar o experimento TOTP | Alta | Pendente no PT-BR; contextualizado no EN |
| DOC-029 | Lab 01 | A etapa de recebimento de alertas não comprova entrega antes de ocorrer uma notificação; distinguir destinatário configurado de e-mail recebido | Média | Pendente no PT-BR; corrigido no EN |
| DOC-030 | Lab 01 | Revisar checklist com `[X]`, que pode ser confundido com validação feita pelo visitante; preferir checklist reutilizável | Média | Pendente no PT-BR; mitigado no EN |
| DOC-031 | Lab 01 | Substituir alt text `LAB01_DevOps_Operations` por descrições contextuais das capturas, com revisão futura de dados sensíveis | Média | Pendente no PT-BR; alt text ajustado no EN; inspeção visual pendente |
| DOC-032 | Lab 01 | Esclarecer limites de acesso root e a diferença entre exemplo educacional e controles corporativos | Média | Pendente no PT-BR; contextualizado no EN |
| DOC-033 | Lab 01 | Rever menção a `sa-east-1` como Região de referência sem apresentar a escolha como obrigatória ou válida para qualquer conta | Baixa | Pendente no PT-BR; esclarecido no EN |
| DOC-034 | Lab 01 | Validar futuramente menus e campos do console, políticas de custo, links oficiais e alterações da AWS Free Tier | Média | Referências oficiais consultadas; navegação do console não reexecutada |
| DOC-035 | Lab 01 | Inspecionar as 10 imagens para identificar eventual exposição de conta, contatos, MFA e informações de cobrança, antes de atestar sua segurança | Alta | Pendente de inspeção visual |

**Critério editorial:** versão inglesa mantém os 13 passos, os 10 links de imagens, as tabelas operacionais, os limiares de 50%/80%/100%, o orçamento ilustrativo de USD 5 e os procedimentos de troubleshooting. O fluxograma Mermaid foi simplificado editorialmente na tradução, enquanto o diagrama detalhado permanece no README português. Esta é uma auditoria documental e não comprova reexecução das configurações AWS.

## Sequência de execução

1. **Etapa 1 — README principal:** criar versão inglesa navegável e registrar observações editoriais iniciais.
2. **Etapa 2 — Labs 00–13:** leitura técnica e editorial individual, criação de `README.en.md`, registro das observações.
3. **Etapa 3 — Labs 14–18:** troubleshooting, atualização, backup e recuperação.
4. **Etapa 4 — Labs 19–24:** Terraform e validação automatizada.
5. **Etapa 5 — Labs 25–28:** CloudWatch, métricas, alarmes e Logs Insights.
6. **Etapa 6 — Lab 29 e documentos auxiliares:** preservar a distinção entre planejado e executado; avaliar traduções de roadmap e demais documentos.
7. **Etapa final — Revisão cruzada:** verificar links, paridade técnica, linguagem natural e estado de todos os itens de auditoria.

## Critérios para encerrar um item

- O texto revisado corresponde aos procedimentos e evidências realmente existentes.
- Resultados quantitativos e limitações estão corretamente expressos.
- A versão inglesa comunica o mesmo significado técnico, sem exageros.
- Links e referências são válidos.
- A alteração editorial não modifica scripts, recursos ou evidências.
- O item foi registrado como concluído somente após verificação.

## Observações iniciais — 2026-11-09

- README principal em PT-BR contém aproximadamente 30 KB e descreve 29 laboratórios concluídos (00–28).
- O diretório do Lab 29 possui README, porém é tratado como atividade futura no índice principal.
- Existem arquivos auxiliares praticamente vazios em `docs/` e `templates/`; não são prioritários nesta etapa.
- O resumo inglês original do README não oferece navegação integral pelos labs para o leitor internacional.
- A primeira versão inglesa do índice principal é uma **adaptação editorial**, não uma auditoria linha a linha de todos os procedimentos; a análise detalhada fica registrada como pendente.
