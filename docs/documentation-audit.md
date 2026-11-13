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

## Auditoria específica — Lab 02

**Data:** 2026-11-09  
**Arquivos examinados:** `labs/02-aws-cli-installation-and-configuration/README.md` e `scripts/validate-aws-cli.ps1`.  
**Intervenção:** criação de `README.en.md` com as 16 etapas, comandos e evidência visual preservados; inclusão de navegação recíproca PT-BR ↔ EN. Não houve instalação, autenticação, execução de scripts ou acesso à conta AWS nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-036 | Lab 02 | Atualizar procedimento SSO: AWS CLI v2.22.0+ utiliza PKCE por padrão e `--use-device-code` oferece alternativa explícita; URLs PKCE devem ser abertas no mesmo dispositivo | Alta | Pendente no PT-BR; esclarecido no EN |
| DOC-037 | Lab 02 | Diferenciar a Região do IAM Identity Center (`sso_region`) da Região padrão dos recursos (`us-east-1`) | Alta | Correto no PT-BR; preservado no EN |
| DOC-038 | Lab 02 | Esclarecer que `sts get-caller-identity` confirma identidade, mas não prova autorização ampla nem, isoladamente, a origem IAM Identity Center | Média | Registrado no EN; pendente no PT-BR |
| DOC-039 | Lab 02 | Reforçar proteção de saídas de `Get-ChildItem Env:AWS*`, `aws configure list` e caches SSO; não publicar valores sensíveis | Alta | Pendente no PT-BR; reforçado no EN |
| DOC-040 | Lab 02 | Etapa do download por `Invoke-WebRequest` verifica apenas presença e tamanho do MSI; considerar validação da assinatura digital | Média | Pendente no PT-BR; ressalva no EN |
| DOC-041 | Lab 02 | Verificar conformidade dos comandos com novas versões da AWS CLI e a precedência entre flags, perfil e variáveis de ambiente | Média | Pendente de teste prático; ressalva no EN |
| DOC-042 | Lab 02 | Checklist preenchido com `[x]` reflete execução documentada mas pode confundir leitores que reutilizem o procedimento | Média | Pendente no PT-BR; versão EN usa caixas vazias |
| DOC-043 | Lab 02 | Trocar expressão conversacional “No nosso caso” por documentação impessoal; reduzir seções de validação repetidas | Média | Pendente no PT-BR; tratado editorialmente no EN |
| DOC-044 | Lab 02 | Preservar a evidência registrada de 9 aprovações, 0 avisos e 0 falhas como resultado histórico e não como nova validação | Alta | Diferenciação explícita no EN |
| DOC-045 | Lab 02 | Revisar mensagem de cleanup: `aws sso logout` limpa tokens de cache local, não implica revogação de todas as sessões organizacionais | Média | Pendente no PT-BR; ressalva no EN |
| DOC-046 | Lab 02 | Inspecionar imagem para exposição de informações de identidade/credenciais; conferir integridade dos links e visualização Mermaid | Alta | Inspeção visual e renderização pendentes |
| DOC-047 | Lab 02 | Script usa sucesso com `assumed-role` como indício de sessão temporária; não é verificação suficiente para atribuir origem exclusiva ao IAM Identity Center | Média | Auditoria estática concluída; eventual aprimoramento de script pendente |
| DOC-048 | Lab 02 | Limpeza do instalador depende de variável de sessão `$AwsCliInstaller`; evitar recomendar exclusão sem validar caminho | Baixa | Esclarecido no EN; pendente no PT-BR |

**Resultado:** tradução técnica publicada, com 16 etapas e o mesmo caminho da evidência visual. O script foi lido estaticamente, sem execução. Os resultados 9/0/0 correspondem à execução anterior descrita no documento original, não à presente auditoria. O conteúdo português foi preservado, exceto pela navegação de idioma.

## Auditoria específica — Lab 03

**Data:** 2026-11-09  
**Arquivos examinados:** `labs/03-infrastructure-tools-installation/README.md`, `scripts/validate-infrastructure-tools.ps1` e inventário de cinco arquivos de imagem.  
**Intervenção:** criada versão inglesa `README.en.md` com as cinco referências visuais originais e links recíprocos de idioma. A tradução distingue registros históricos de orientações para novas execuções. Não foram alterados scripts, binários, evidências nem configurações de sistemas.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-049 | Lab 03 | O validador exige padrão exato `Terraform v1.16.1`; versões mais recentes podem gerar aviso apesar de válidas. Diferenciar versão registrada e requisito de compatibilidade | Média | Explicado no EN; revisão futura do script |
| DOC-050 | Lab 03 | Uso de `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` reduz verificações durante a sessão; orientar inspeção prévia e alternativas aprovadas | Alta | Observação no EN; PT-BR pendente |
| DOC-051 | Lab 03 | Hash SHA-256 comparado a checksum oficial não prova, sozinho, a autenticidade do arquivo de checksum; avaliar validação criptográfica da fonte ou assinatura | Alta | Observação no EN; procedimento futuro |
| DOC-052 | Lab 03 | Script exibe `$Command.Source` e saídas de ferramentas; avaliar risco de exposição de nomes locais/organizacionais nas capturas | Média | Advertência no EN; revisão visual pendente |
| DOC-053 | Lab 03 | Distinguir instalação e execução local do Session Manager Plugin de conexão operacional bem-sucedida a uma sessão SSM | Média | Esclarecido no EN |
| DOC-054 | Lab 03 | O validador retorna código `0` mesmo com avisos; explicitar que avisos não equivalem a reprovação e discutir uso em CI | Média | Esclarecido no EN; aprimoramento opcional |
| DOC-055 | Lab 03 | Checklist marcado `[x]` representa execução histórica; evitar interpretação de que o leitor concluiu o exercício | Média | Contextualizado no EN; PT-BR pendente |
| DOC-056 | Lab 03 | Preservar UTF-8 com BOM para PowerShell 5.1; testar após futuras edições e distinguir comportamento de versões mais recentes | Média | Documentado no EN; validação prática não realizada |
| DOC-057 | Lab 03 | Inspecionar visualmente as cinco capturas para confirmar legibilidade, correspondência e ausência de dados sensíveis | Alta | Pendente de inspeção visual |
| DOC-058 | Lab 03 | Avaliar inclusão de comandos completos de instalação/reprodução, atualmente o PT-BR documenta etapas executadas sem detalhar todos os comandos | Baixa | Pendente; escopo de registro histórico preservado |
| DOC-059 | Lab 03 | Validar se as versões fixadas no inventário continuam apropriadas e se caminhos locais devem ser tratados apenas como exemplos | Média | Esclarecido no EN; revisão de manutenção futura |

**Resultado:** tradução editorial publicada; 5/5 caminhos de imagens referenciados e arquivos correspondentes encontrados na árvore do repositório. Leitura estática do script concluída; comandos, atualizações e validações não foram reexecutados. A contagem histórica de 8 aprovações, 0 avisos, 0 falhas e saída 0 foi mantida sem atribuir nova execução.

## Auditoria específica — Lab 04

**Data:** 2026-11-09  
**Arquivos examinados:** `labs/04-linux-file-management/README.md`, `scripts/validate-linux-file-management.sh`, inventário de seis imagens e estrutura de diretórios.  
**Intervenção:** criação de `README.en.md` em inglês técnico, com as seis referências visuais preservadas, e navegação de idioma no README português. O script, os arquivos de evidência e o ambiente Linux não foram modificados nem executados nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-060 | Lab 04 | Caminho `/home/itamarsbt/...` depende do usuário da execução original; orientar o uso de `$HOME` em outras estações | Média | Esclarecido no EN; revisão PT-BR pendente |
| DOC-061 | Lab 04 | Os registros `ERROR` e `WARNING` são sintéticos, gerados por `printf`, e não devem ser descritos como incidentes reais | Alta | Explicitado no EN |
| DOC-062 | Lab 04 | Comandos com redirecionamento `>` sobrescrevem arquivos de destino existentes; incluir orientação preventiva para reutilização | Média | Advertência no EN; PT-BR pendente |
| DOC-063 | Lab 04 | Verificação `find` com `-o` não apresenta parênteses explícitos; preferir agrupamento de condições para clareza e futuras extensões | Baixa | Alternativa documentada no EN |
| DOC-064 | Lab 04 | O guard de cleanup compara `pwd` com caminho esperado, mas não cobre todas as situações envolvendo symlinks ou execução com shell diferente | Média | Limitação explicada no EN |
| DOC-065 | Lab 04 | O comando `exit 1` no guard pode encerrar o shell caso seja executado diretamente na sessão; recomendar execução isolada de guardas críticos | Média | Ressalva no EN |
| DOC-066 | Lab 04 | Script retorna código `0` quando há apenas `[AVISO]`, inclusive estrutura temporária não removida; distinguir warnings de conclusão totalmente limpa | Média | Documentado no EN; melhoria de critérios pendente |
| DOC-067 | Lab 04 | `grep -qE` verifica existência de padrões em vez de igualdade integral do arquivo; não interpretar como validação completa de configuração | Média | Esclarecido no EN |
| DOC-068 | Lab 04 | Preservar a distinção entre erro real de CRLF/LF do ambiente de execução e registros de erro simulados inseridos nos logs | Média | Esclarecido no EN |
| DOC-069 | Lab 04 | Regra `*.sh text eol=lf` evita discrepâncias em novos checkouts, mas arquivos já materializados podem exigir normalização | Baixa | Esclarecido no EN |
| DOC-070 | Lab 04 | Revisar se valores de distribuição, kernel, Bash, nome de usuário e logs datados são apresentados como registro histórico, não requisitos universais | Média | Contextualizado no EN |
| DOC-071 | Lab 04 | Inspecionar visualmente seis capturas para legibilidade, correspondência e ausência de informações identificadoras | Alta | Arquivos existentes; inspeção visual pendente |
| DOC-072 | Lab 04 | Preservar contagem histórica 21/0/0 e distinguir execução documentada de leitura estática do script na auditoria | Alta | Aplicado no EN |
| DOC-073 | Lab 04 | Reduzir duplicidade entre boas práticas, competências, resultado e status sem empobrecer o registro do procedimento | Baixa | Adaptação editorial no EN; PT-BR pendente |

**Resultado:** a versão inglesa preserva as seis imagens, os procedimentos Bash, a estrutura de arquivos e os resultados históricos 21 aprovações, 0 avisos, 0 falhas e código de saída 0. Foi realizada leitura estática do script; nenhuma execução do laboratório ou inspeção visual profunda das imagens foi feita nesta etapa.

## Auditoria específica — Lab 05

**Data:** 2026-11-09  
**Arquivos examinados:** `labs/05-linux-users-groups-permissions/README.md`, `scripts/validate-linux-users-groups-permissions.sh`, lista de oito capturas e estrutura do diretório.  
**Intervenção:** criação de `README.en.md` com oito imagens, sequência completa de comandos e navegação recíproca. README português preservado, exceto link de idioma. Nenhum script, conta Linux, grupo, diretório ou evidência foi modificado ou executado nesta etapa.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-074 | Lab 05 | O bloqueio de senha das contas temporárias não impede, por si só, todos os mecanismos de acesso (ex.: chaves ou execução privilegiada) | Alta | Limitação documentada no EN; PT-BR pendente |
| DOC-075 | Lab 05 | SGID em diretório define herança de grupo, mas não concede automaticamente permissão de escrita; considerar umask, modo do arquivo e ACLs | Alta | Esclarecido no EN |
| DOC-076 | Lab 05 | `sudo find /srv/cloudops-lab05 -depth -mindepth 1 -delete` é exclusão recursiva destrutiva; conferir caminho, propriedade e dependências antes de executar | Alta | Aviso reforçado no EN; PT-BR pendente |
| DOC-077 | Lab 05 | `userdel --remove` pode apagar diretórios pessoais e conteúdo não relacionado caso o alvo seja reutilizado; confirmar exclusividade dos usuários | Alta | Ressalva no EN; PT-BR pendente |
| DOC-078 | Lab 05 | Validação de negação usa `SUDO_USER`; sem usuário original válido ou com associação ao grupo, é registrada advertência, não prova de acesso negado | Alta | Documentado no EN |
| DOC-079 | Lab 05 | Script retorna código 0 quando só há avisos. Não interpretar código 0 como 37 verificações aprovadas em qualquer execução | Média | Distinção no EN; revisão futura do script |
| DOC-080 | Lab 05 | Conferir explicação de permissões 770/2770 e diferença entre grupos primários e suplementares, com indicação de herança apenas para novos objetos | Média | Explicado no EN |
| DOC-081 | Lab 05 | Uso de `grep -Fq` no validador confirma presença de conteúdo, mas não igualdade integral dos arquivos ou ausência de entradas adicionais | Média | Limitação no EN |
| DOC-082 | Lab 05 | Status histórico de 37 OK, zero avisos e zero falhas foi registrado antes do cleanup; validador não deve ser executado depois da exclusão esperando mesmo resultado | Alta | Contextualizado no EN |
| DOC-083 | Lab 05 | Revisar imagens para exposição de nomes de contas, informações pessoais e caminhos locais; melhorar textos alternativos genéricos | Média | Alt text aprimorado no EN; inspeção visual pendente |
| DOC-084 | Lab 05 | README possui seções repetitivas de competências, resultado, status e evidências; consolidar somente após revisão de paridade | Baixa | EN condensado editorialmente; PT-BR pendente |
| DOC-085 | Lab 05 | Verificar políticas de contas, permissões herdadas e possíveis ACLs em sistemas de arquivos diferentes antes de generalizar o resultado em WSL 2 | Média | Limitações contextualizadas no EN |
| DOC-086 | Lab 05 | Scripts e procedimentos administrativos devem ser reproduzidos apenas em ambiente de testes autorizado; não prometer segurança apenas por nomes explícitos de recursos | Alta | Aviso no EN; PT-BR pendente |

**Resultado:** versão inglesa publicada com oito imagens e oito fases de execução; preservados comandos, configurações, tabela de propriedade antes/depois do SGID e registros históricos de 37 aprovações, 0 avisos e 0 falhas. Script Bash revisado estaticamente, sem execução. Inspeção visual detalhada das capturas permanece pendente.

## Auditoria específica — Lab 06

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/06-linux-processes-services-logs/README.md`, `scripts/manage-lab06-service.sh` e inventário de duas imagens.  
**Intervenção:** criado `README.en.md` com procedimentos de `systemd`, seis ações do script e duas evidências referenciadas; README português recebeu navegação de idioma. Nenhum serviço, conta, script ou configuração Linux foi executado/modificado durante a revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-087 | Lab 06 | Distinguir falha deliberada de `WorkingDirectory` e código `200/CHDIR` de incidente real em produção | Alta | Explicitado no EN |
| DOC-088 | Lab 06 | O `python3 -m http.server` é adequado ao teste local, mas não é servidor de produção; descrever escopo restrito | Média | Esclarecido no EN |
| DOC-089 | Lab 06 | `systemctl is-active` e `curl` confirmam estado/resposta pontuais, não disponibilidade contínua ou acesso externo | Média | Esclarecido no EN |
| DOC-090 | Lab 06 | Script `setup` utiliza nomes fixos e regrava HTML/unit; verificações de identidade não excluem todas as colisões e dependências | Alta | Alerta no EN; revisão técnica futura |
| DOC-091 | Lab 06 | `cleanup` remove conta, grupo, unit e arquivos; conferir propriedade exclusiva, symlinks, conteúdo inesperado e dependências antes da execução | Alta | Alerta no EN; inspeção técnica futura |
| DOC-092 | Lab 06 | `simulate-failure` e `recover` usam override systemd; registrar que falha intencional provoca tentativas de reinício | Média | Explicado no EN |
| DOC-093 | Lab 06 | Controles `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem` e `ProtectHome` não constituem avaliação completa de hardening | Média | Escopo indicado no EN |
| DOC-094 | Lab 06 | `validate` verifica substring HTTP e estado ativo; não comprova autoria do processo sem outras consultas | Média | Limitação no EN |
| DOC-095 | Lab 06 | Ação `inspect` pode apresentar informações e registros de `journalctl` potencialmente identificadores; revisar material publicado | Média | Advertência no EN; inspeção visual pendente |
| DOC-096 | Lab 06 | Conferir a legibilidade e ausência de dados sensíveis nas duas imagens originais | Alta | Arquivos inventariados; inspeção visual pendente |
| DOC-097 | Lab 06 | README PT-BR é registro sucinto; considerar posteriormente ampliar requisitos e precauções de execução sem reescrever fatos históricos | Baixa | EN expandido; PT-BR pendente |
| DOC-098 | Lab 06 | Diferenciar revisão estática do script e resultados históricos; não declarar nova validação operacional | Alta | Preservado no EN |

**Resultado:** versão inglesa com seis ações do script e duas referências de imagens, mantendo as observações históricas de falha e recuperação. O script foi lido, não executado. Arquivos binários não foram inspecionados visualmente nesta fase. Navegação final conferida com o diretório real do Lab 07 (`07-aws-account-baseline`).

## Auditoria específica — Lab 07

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/07-aws-account-baseline/README.md`, `scripts/test-aws-account-baseline.ps1` e inventário da imagem `images/lab-07-baseline-summary.png`.  
**Intervenção:** criada versão inglesa `README.en.md` com inventário e resultados originais, além de navegação recíproca no README português. Nenhuma consulta à AWS foi executada; o script e a evidência foram preservados.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-099 | Lab 07 | Script retorna código `0` com avisos; resultado 17 OK/8 avisos/0 falhas não equivale a aprovação integral de segurança | Alta | Contextualizado no EN |
| DOC-100 | Lab 07 | `get-public-access-block` no S3 pode falhar por ausência de configuração, acesso negado ou outro erro; separar causas antes de inferir postura de segurança | Alta | Ressalva no EN; refinamento de script pendente |
| DOC-101 | Lab 07 | Falha de `get-bucket-website` é relatada como hospedagem não configurada, sem distinguir `AccessDenied` de ausência de configuração | Média | Ressalva no EN; script pendente |
| DOC-102 | Lab 07 | Quatro controles de Block Public Access não habilitados no bucket não provam, isoladamente, que o bucket esteja efetivamente público | Alta | Esclarecido no EN |
| DOC-103 | Lab 07 | `list-objects-v2 --max-keys 1` não comprova inexistência de versões não atuais ou delete markers; rever afirmação de bucket totalmente vazio | Média | Escopo esclarecido no EN |
| DOC-104 | Lab 07 | API Resource Groups Tagging não representa necessariamente todos os recursos; não interpretar 4 recursos como inventário total da conta | Alta | Esclarecido no EN |
| DOC-105 | Lab 07 | A falta de tags reflete convenção proposta no lab; sem política corporativa registrada, não classificar ausência como não conformidade comprovada | Média | Contextualizado no EN |
| DOC-106 | Lab 07 | Zero nós no Systems Manager ou zero alarmes métricos não é necessariamente falha: depende do inventário, do requisito e do monitoramento externo | Média | Esclarecido no EN |
| DOC-107 | Lab 07 | EC2 parada e monitoramento detalhado desabilitado podem ser estados válidos conforme objetivo e política; evitar tratar como incidentes | Média | Contextualizado no EN |
| DOC-108 | Lab 07 | Resultado de EBS não criptografado merece investigação prioritária, mas ação deve ser planejada após confirmar proprietário e dependências | Alta | Prioridade contextualizada no EN |
| DOC-109 | Lab 07 | Escopo regional `us-east-1` e chamadas globais/por bucket S3 não constituem varredura de todas as Regiões e contas | Alta | Clarificado no EN |
| DOC-110 | Lab 07 | `cloudwatch describe-alarms` analisa `MetricAlarms` no código, sem avaliação completa de alarmes compostos ou monitores externos | Média | Limitação no EN |
| DOC-111 | Lab 07 | Inventário anônimo oculta nomes e IDs, mas datas, contagens, perfil, Região e detalhes de saídas ainda podem ser sensíveis | Média | Aviso no EN; inspeção visual pendente |
| DOC-112 | Lab 07 | Resultados 17/8/0 e recursos inventariados são registros históricos; não descrever a conta como se tivesse sido verificada hoje | Alta | Diferenciação explícita no EN |
| DOC-113 | Lab 07 | Inspecionar captura `lab-07-baseline-summary.png` em resolução integral e validar ausência de informações sensíveis ou identificadores | Alta | Arquivo confirmado; inspeção visual pendente |
| DOC-114 | Lab 07 | Avaliar tratamento sanitizado de erros distintos da AWS CLI (permissão versus configuração ausente versus falha de conexão) | Alta | Auditoria estática concluída; evolução do script pendente |

**Resultado:** tradução inglesa publicada com 17 aprovações, 8 avisos, 0 falhas, código de saída 0, tabelas de inventário, limiares e conclusões de escopo preservados. O script PowerShell foi lido estaticamente, sem autenticação ou consultas à conta. O próximo diretório `08-aws-application-network` foi conferido no repositório.

## Auditoria específica — Lab 08

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/08-aws-application-network/README.md`, `scripts/deploy-aws-application-network.ps1`, `scripts/test-aws-application-network.ps1`, `scripts/remove-aws-application-network.ps1` e inventário de três imagens.  
**Intervenção:** criada a versão inglesa `README.en.md`, preservadas as três evidências, os valores da arquitetura e o relato de implantação, validação e cleanup; README português recebeu navegação bilíngue. Nenhuma chamada AWS ou execução PowerShell foi realizada nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-115 | Lab 08 | CIDR não encontrado na consulta regional não garante ausência de conflitos com redes conectadas/on-premises; ampliar verificação antes de interconexões | Média | Distinção no EN; análise técnica futura |
| DOC-116 | Lab 08 | Nome das zonas `us-east-1a` e `us-east-1b` tem mapeamento dependente de conta; preservar IDs físicos `use1-az1`/`use1-az2` apenas como registro original | Média | Esclarecido no EN |
| DOC-117 | Lab 08 | Habilitar `map-public-ip-on-launch` não cria IP público de imediato, mas instâncias futuras com IPv4 público podem gerar cobrança horária | Alta | Esclarecido no EN; PT-BR pendente |
| DOC-118 | Lab 08 | Rota `0.0.0.0/0` ao Internet Gateway caracteriza preparação de rede pública, não comprova acessibilidade real de instâncias ou aplicação | Alta | Diferenciado no EN |
| DOC-119 | Lab 08 | Security Group sem ingress não equivale a ausência de egress; verificar regras de saída padrão e futuras alterações | Alta | Ressalva no EN; script pendente |
| DOC-120 | Lab 08 | SSM como plano de administração sem SSH depende de agent, IAM e conectividade aos endpoints; não pressupor funcionalidade automática | Média | Contextualizado no EN |
| DOC-121 | Lab 08 | Tags ajudam na identificação e guarda do cleanup, mas não provam propriedade exclusiva ou inexistência de dependências externas | Alta | Advertência no EN |
| DOC-122 | Lab 08 | Script de implantação falha sem rollback automático; pode deixar recursos parcialmente criados e exigir inspeção antes de nova execução | Alta | Alerta no EN; melhoria de idempotência futura |
| DOC-123 | Lab 08 | Cleanup com `-ConfirmRemoval` valida dependências selecionadas, mas não garante ausência de relações de terceiros; inspecionar alvos e estado de AWS antes de autorizar | Alta | Alerta no EN; auditoria de código posterior |
| DOC-124 | Lab 08 | A verificação final pesquisa VPC por tag de nome, não constitui varredura integral de todas as contas/Regiões ou prova universal de ausência de recursos | Média | Escopo esclarecido no EN |
| DOC-125 | Lab 08 | Custos esperados zero correspondem à execução original sem EC2/NAT/EIP/ALB e sem tráfego relevante; não generalizar gratuidade de IPv4 público ou transferências futuras | Alta | Contextualizado no EN |
| DOC-126 | Lab 08 | Script de validação independente confirma configuração, não comprova teste de tráfego real a partir de instância ou endpoint de aplicação | Média | Explicitado no EN |
| DOC-127 | Lab 08 | Inspecionar as três imagens em resolução adequada para dados sensíveis, IDs, IPs e consistência com os comandos descritos | Alta | Arquivos confirmados; inspeção visual pendente |
| DOC-128 | Lab 08 | Checklist `[x]` representa atividade histórica; não sugerir que a execução do visitante já esteja validada | Média | Contextualizado no EN |
| DOC-129 | Lab 08 | Diferenciar no registro editorial os três scripts: implantação mutável, validação somente leitura e remoção destrutiva autorizada | Alta | Documentado no EN |
| DOC-130 | Lab 08 | Conservação de scripts e evidências sem reexecutar AWS: não declarar infraestrutura atualmente existente/ausente com base apenas em captura histórica | Alta | Aplicado no EN |

**Resultado:** tradução inglesa publicada com as três imagens e arquitetura original (`10.20.0.0/16`, sub-redes `10.20.10.0/24` e `10.20.20.0/24`, zonas `us-east-1a`/`us-east-1b`, rota Internet Gateway e Security Group sem ingress), assim como o relato histórico de validação e cleanup. Os scripts foram examinados estaticamente, não executados. A inspeção visual das capturas continua pendente.

## Auditoria específica — Lab 09

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/09-aws-ec2-systems-manager/README.md`, `scripts/deploy-aws-managed-instance.ps1`, `scripts/test-aws-managed-instance.ps1`, `scripts/remove-aws-managed-instance.ps1`, `policies/ec2-ssm-trust-policy.json` e inventário das quatro imagens.  
**Intervenção:** publicação de `README.en.md`, com as quatro referências visuais e navegação recíproca. Documentação em português mantida, exceto link de idioma. Nenhuma operação AWS, sessão Session Manager ou execução PowerShell realizada nesta auditoria.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-131 | Lab 09 | A resolução da AMI por parâmetro público do Amazon Linux 2023 seleciona imagem atualizada; fixar/registrar AMI ID se reprodutibilidade exata for necessária | Média | Limitação no EN; melhorias futuras |
| DOC-132 | Lab 09 | Session Manager sem SSH depende de permissões do operador, IAM Role, SSM Agent e saída de rede; não presumir que SG sem ingress garante todo o hardening | Alta | Esclarecido no EN |
| DOC-133 | Lab 09 | `AmazonSSMManagedInstanceCore` autoriza operações do managed node, não substitui a política IAM do usuário que inicia a sessão | Alta | Esclarecido no EN |
| DOC-134 | Lab 09 | `HttpTokens=required` exige IMDSv2, mas não representa proteção absoluta contra roubo de credenciais ou comprometimento da instância | Média | Ressalva no EN |
| DOC-135 | Lab 09 | Status `Online` do Systems Manager e validação por consulta são verificações pontuais; não comprovam SLO, disponibilidade contínua ou auditoria de sessões | Média | Escopo delimitado no EN |
| DOC-136 | Lab 09 | Atribuição de IPv4 público para saída aos endpoints pode gerar cobrança horária; não confundir ausência de SSH público com ausência de custo de IPv4 | Alta | Explicado no EN |
| DOC-137 | Lab 09 | Script de implantação não faz rollback transacional; falhas depois da criação IAM/SG/EC2 podem deixar recursos parciais | Alta | Alerta no EN; melhoria de idempotência futura |
| DOC-138 | Lab 09 | Cleanup requer `-ConfirmRemoval` e checa `Lab=09`/`Owner=itamarsb`, mas nomes/tags não provam propriedade exclusiva nem ausência de vínculos externos | Alta | Advertência no EN; revisão técnica futura |
| DOC-139 | Lab 09 | A exclusão de IAM Role e Instance Profile precisa de verificação de dependências e contexto da conta; avaliar condições de autorização e colisão de nomes | Alta | Contextualizado no EN; script preservado |
| DOC-140 | Lab 09 | `DeleteOnTermination=true` documenta comportamento esperado para o EBS raiz; reforçar inventário pós-cleanup para detectar outros volumes/snapshots | Média | Ressalva no EN; verificação adicional pendente |
| DOC-141 | Lab 09 | As verificações de SG sem ingress não analisam necessariamente todas as permissões de saída ou demais controles de rede | Média | Escopo no EN |
| DOC-142 | Lab 09 | Diferenciar os resultados históricos de implantação, validação, acesso `ssm-user` e remoção das verificações atuais da conta AWS | Alta | Explicitado no EN |
| DOC-143 | Lab 09 | Capturas podem exibir IDs de instâncias, identidade, hostnames e informações de sessão; inspecionar visualmente as quatro evidências | Alta | Arquivos confirmados; inspeção visual pendente |
| DOC-144 | Lab 09 | Preservar Lab 08 durante o cleanup; conferir também links de sequência de labs, incluindo `10-linux-web-service` | Média | Navegação conferida no EN |
| DOC-145 | Lab 09 | O script retorna IDs em saídas de implantação/validação; não declarar anonimização absoluta sem examinar as capturas | Alta | Observação registrada; revisão visual pendente |

**Resultado:** tradução inglesa publicada com quatro referências visuais, arquitetura, scripts, IAM trust policy e sequência de deploy/validate/session/cleanup preservadas. Os arquivos foram lidos estaticamente; a conta AWS não foi consultada. A inspeção visual das quatro imagens permanece pendente.

## Auditoria específica — Lab 10

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/10-linux-web-service/README.md`, `scripts/deploy-linux-web-service.ps1`, `scripts/test-linux-web-service.ps1`, `scripts/remove-linux-web-service.ps1`, `policies/ec2-ssm-trust-policy.json` e inventário de seis imagens.  
**Intervenção:** criada versão inglesa `README.en.md` com seis imagens e navegação recíproca; documentação portuguesa preservada exceto pelo link de idioma. Nenhuma execução de PowerShell, EC2, Systems Manager ou Nginx foi realizada durante esta auditoria.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-146 | Lab 10 | HTTP na porta 80 não utiliza TLS; limitar origem com `/32` não fornece criptografia nem autenticação da aplicação | Alta | Advertência no EN; PT-BR pendente |
| DOC-147 | Lab 10 | `/32` restringe a um endereço IPv4, mas não a um usuário; NAT, VPN, proxy ou mudanças de endereço podem afetar a origem efetiva | Média | Explicado no EN |
| DOC-148 | Lab 10 | `checkip.amazonaws.com` é consulta externa e o endereço observado pode não coincidir com a origem efetiva de todas as conexões HTTP | Média | Contextualizado no EN |
| DOC-149 | Lab 10 | Script de validação descrito como “somente leitura” emprega `ssm:SendCommand` com comandos locais de inspeção; operação não é API AWS estritamente read-only | Alta | Distinção explícita no EN; precisão do PT-BR pendente |
| DOC-150 | Lab 10 | HTTP 200 e conteúdo esperado demonstram resposta pontual, não disponibilidade contínua, SLO ou prontidão de produção | Média | Esclarecido no EN |
| DOC-151 | Lab 10 | AMI Amazon Linux 2023 é resolvida dinamicamente por parâmetro público SSM; execução posterior pode selecionar imagem diferente | Média | Ressalva no EN |
| DOC-152 | Lab 10 | User Data e parâmetros JSON SSM em UTF-8 sem BOM diferem do comportamento de scripts PowerShell 5.1; manter a distinção entre codificações | Média | Documentado no EN |
| DOC-153 | Lab 10 | Registrar falha histórica de serialização do `commands` separadamente do diagnóstico de Nginx: erro de chamada remota, não incidente web comprovado | Média | Diferenciado no EN |
| DOC-154 | Lab 10 | Entidades HTML para acentos corrigem compatibilidade de renderização; não alterar o procedimento histórico sem novo teste | Baixa | Preservado no EN |
| DOC-155 | Lab 10 | `-ConfirmRemoval` e tags são salvaguardas insuficientes para provar exclusividade de recursos e ausência de dependências IAM/EBS | Alta | Alerta no EN; revisão técnica futura |
| DOC-156 | Lab 10 | Cleanup de instância e IAM não substitui inspeção completa de snapshots, volumes e recursos fora dos filtros de descoberta | Média | Ressalva no EN |
| DOC-157 | Lab 10 | Verificar exposição de Instance ID, IPv4 público, CIDR de origem, DNS, hostnames e identidade nas seis capturas | Alta | Inventário confirmado; inspeção visual pendente |
| DOC-158 | Lab 10 | Status SSM Online e checks de `systemd` verificam estado na execução, não governança integral de sessões nem hardening do host | Média | Contextualizado no EN |
| DOC-159 | Lab 10 | EC2, EBS, IPv4 público e transferência podem gerar custos apesar da curta duração e do cleanup; não presumir gratuidade | Alta | Explicado no EN |
| DOC-160 | Lab 10 | Checklist preenchido reflete execução histórica, não conclusão automática para quem reproduzir o laboratório | Média | Explicitado no EN |
| DOC-161 | Lab 10 | Separar claramente implantação mutável, testes de configuração com SSM Run Command e cleanup destrutivo; preservar rede do Lab 08 | Alta | Documentado no EN |
| DOC-162 | Lab 10 | Conferir navegação e continuidade para o diretório real `11-aws-storage-recovery` | Baixa | Conferido no EN |

**Resultado:** documentação inglesa publicada com as seis evidências, arquitetura EC2/Nginx/`systemd`/SSM, porta HTTP 80 limitada a `/32`, passos de implantação, validação, sessão administrativa, cleanup e correção histórica de codificação. Leitura estática dos três scripts e da política IAM concluída, sem execução. Inspeção visual aprofundada das seis capturas pendente.

## Auditoria específica — Lab 11

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/11-aws-storage-recovery/README.md`, os quatro scripts `deploy-aws-storage-recovery.ps1`, `test-aws-storage-recovery.ps1`, `restore-aws-storage-data.ps1`, `remove-aws-storage-recovery.ps1`, as políticas `ec2-ssm-trust-policy.json` e `s3-storage-policy-template.json` e o inventário das oito imagens.  
**Intervenção:** publicado `README.en.md` com oito evidências e navegação recíproca; README português preservado fora do link de idioma. Nenhuma consulta à AWS, execução dos scripts ou recuperação de dados foi realizada durante esta auditoria.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-163 | Lab 11 | Texto PT-BR mistura futuro (“será”, “utilizará”) com evidências e resultado de laboratório já executado; uniformizar tempos verbais sem apagar histórico | Média | Corrigido editorialmente no EN; PT-BR pendente |
| DOC-164 | Lab 11 | Restaurar do S3 para outro diretório do mesmo volume EBS comprova recuperação de arquivo, não recuperação após perda total do volume ou instância | Alta | Escopo explicitado no EN |
| DOC-165 | Lab 11 | Hashes SHA-256 iguais indicam equivalência de bytes frente à referência; não asseguram autenticidade de backup se fonte e checksum puderem ser adulterados | Média | Esclarecido no EN |
| DOC-166 | Lab 11 | Validador `test-aws-storage-recovery.ps1` verifica infraestrutura, bucket e objeto; não calcula o SHA-256 restaurado, que depende de script e evidência separados | Alta | Distinção no EN |
| DOC-167 | Lab 11 | `mkfs.ext4` é operação destrutiva; validar cuidadosamente dispositivo EBS anexado/NVMe antes de formatar, sobretudo fora do ambiente original | Alta | Advertência no EN; revisão prática pendente |
| DOC-168 | Lab 11 | Registro `/etc/fstab` com UUID e `nofail` ajuda persistência de montagem sem garantir disponibilidade dos dados caso volume esteja ausente | Média | Limitação descrita no EN |
| DOC-169 | Lab 11 | S3 versioning não torna backups imutáveis; exclusão permanente exige tratar todas as versões e delete markers | Alta | Esclarecido no EN |
| DOC-170 | Lab 11 | Cleanup usa `list-object-versions` e limita a 20 versões; checar paginação/truncamento e concorrência antes de generalizar para buckets grandes | Alta | Registrado no EN; evolução do script pendente |
| DOC-171 | Lab 11 | Cleanup de bucket e volume com `-ConfirmRemoval` é irreversível; tags/nome não substituem revisão de ID, titularidade e dependências | Alta | Advertência no EN |
| DOC-172 | Lab 11 | Política de S3 permite apenas ações selecionadas e nega transporte inseguro para a identidade; avaliar controles de bucket e demais principais separadamente | Alta | Diferenciado no EN |
| DOC-173 | Lab 11 | Bucket nomeado com Account ID e Região pode expor ID de conta nas saídas e capturas; não pressupor anonimização integral | Alta | Alerta no EN; inspeção visual pendente |
| DOC-174 | Lab 11 | O teste local com mocks não equivale a integração S3 real; documentar cenários de resposta vazia, versão permitida e chave inesperada | Média | Distinção explícita no EN |
| DOC-175 | Lab 11 | Parser PowerShell sem erros verifica sintaxe, não compatibilidade operacional ou êxito de chamada AWS | Média | Esclarecido no EN |
| DOC-176 | Lab 11 | A recuperação executada pelo Systems Manager usa `ssm:SendCommand`, não sendo validação estritamente passiva; distinguir script de consulta e script mutável | Alta | Esclarecido no EN |
| DOC-177 | Lab 11 | Script de implantação pode deixar recursos parciais após falha; verificar a conta antes de reexecução e cleanup | Alta | Advertência no EN; idempotência futura |
| DOC-178 | Lab 11 | Versões antigas no S3, volumes, IPv4 público, instância EC2 e requisições geram custos potenciais mesmo em testes curtos | Alta | Limitações de custos no EN |
| DOC-179 | Lab 11 | Inspecionar visualmente as oito capturas para verificar legibilidade, coerência e exposição de Account ID, Bucket, Volume ID, Instance ID, IP ou dados | Alta | Inventário confirmado; inspeção visual pendente |
| DOC-180 | Lab 11 | Comparação 22 critérios de sucesso com evidências históricas exige distinguir montagem, objeto existente, recuperação verificada e cleanup | Média | Organizado no EN; revisão cruzada futura |
| DOC-181 | Lab 11 | Verificar persistência de rede compartilhada do Lab 08 e navegação ao diretório real do próximo laboratório `12-aws-application-availability` | Baixa | Navegação conferida no EN |
| DOC-182 | Lab 11 | Repetição de resumo, escopo, futuro e status no README PT-BR pode ser condensada para leitores terceiros sem perder evidências | Baixa | EN reorganizado; PT-BR pendente |

**Resultado:** criada documentação inglesa com as oito referências de evidência, comandos dos quatro scripts, políticas IAM, requisitos e 22 critérios registrados; preservada a distinção entre implantação histórica, teste local simulado, validação de infraestrutura, restauração SHA-256 e cleanup. Scripts e políticas lidos estaticamente, sem execução. Inspeção visual aprofundada das oito imagens permanece pendente.

## Auditoria específica — Lab 12

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/12-aws-application-availability/README.md`, quatro scripts (`deploy-aws-application-availability.ps1`, `test-aws-application-availability.ps1`, `invoke-aws-availability-failure.ps1` e `remove-aws-application-availability.ps1`), política `ec2-ssm-trust-policy.json` e inventário de cinco imagens.  
**Intervenção:** criado `README.en.md` com resultados históricos e cinco imagens; README original recebeu apenas navegação recíproca. Nenhum script, instância, ALB ou configuração AWS foi executado ou alterado durante esta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-183 | Lab 12 | Falha controlada de Nginx em um backend não corresponde à indisponibilidade de uma Availability Zone inteira | Alta | Esclarecido no EN |
| DOC-184 | Lab 12 | Vinte respostas HTTP consecutivas durante a janela após `unhealthy` comprovam continuidade observada, não 100% de uptime ou ausência de perdas durante transição | Alta | Limitação explicitada no EN |
| DOC-185 | Lab 12 | Health check HTTP `GET /health` com resposta esperada não representa teste completo de jornadas, dependências e SLIs/SLOs da aplicação | Média | Contextualizado no EN |
| DOC-186 | Lab 12 | Script de validação apresentado como somente leitura usa `ssm:SendCommand` para executar inspeções no host; não é exclusivamente consulta passiva AWS | Alta | Distinção no EN; PT-BR pendente |
| DOC-187 | Lab 12 | Recuperação obrigatória via `finally` reduz riscos do teste de falha, mas não garante recuperação caso SSM/instância/serviço estejam indisponíveis | Alta | Alerta no EN |
| DOC-188 | Lab 12 | `-ConfirmFailureTest` e `-ConfirmRemoval` autorizam ações disruptivas e destrutivas, mas exigem verificação contextual de alvos antes da execução | Alta | Alertas no EN |
| DOC-189 | Lab 12 | ALB expõe HTTP público na porta 80 sem TLS; distinguir isolamento de acesso na rede de confidencialidade de dados | Alta | Esclarecido no EN |
| DOC-190 | Lab 12 | Backend em sub-rede pública com ingress restrito ao Security Group do ALB não equivale a instância localizada em sub-rede privada | Média | Esclarecido no EN |
| DOC-191 | Lab 12 | Security Groups e ausência de SSH não demonstram controle completo de egress, IAM ou segurança da aplicação | Média | Ressalva no EN |
| DOC-192 | Lab 12 | Respostas observadas de A e B validam distribuição na amostra, não balanceamento percentual, latência ou desempenho em carga sustentada | Média | Limitação no EN |
| DOC-193 | Lab 12 | AMI Amazon Linux 2023 selecionada por parâmetro público SSM pode mudar em novas execuções; registrar AMI ID para reprodutibilidade | Média | Contextualizado no EN |
| DOC-194 | Lab 12 | Falha no provisionamento pode deixar recursos parciais; deployment não assegura rollback e exige avaliação antes de reexecução/cleanup | Alta | Alerta no EN |
| DOC-195 | Lab 12 | Cleanup depende de nomes, tags e IDs identificados; verificar dependências e dados antes da exclusão de recursos e respeitar rede compartilhada do Lab 08 | Alta | Alerta no EN |
| DOC-196 | Lab 12 | Troubleshooting de `Keep-Alive`/`Close` em PowerShell 5.1 e normalização de `\r` devem ser registrados como ajustes históricos, sem atribuir erro ao ALB | Média | Preservado no EN |
| DOC-197 | Lab 12 | Teste de sintaxe PowerShell e parsing JSON não comprovam êxito operacional das consultas e ações AWS | Média | Esclarecido no EN |
| DOC-198 | Lab 12 | Custo potencial de dois EC2, EBS, IPv4 público, ALB e transferência não é eliminado retroativamente por cleanup | Alta | Esclarecido no EN |
| DOC-199 | Lab 12 | Inspecionar visualmente cinco evidências para IDs de instância, ALB URL/ARN, dados de conta e integridade dos resultados | Alta | Inventário verificado; inspeção visual pendente |
| DOC-200 | Lab 12 | Critérios de sucesso marcados com `[x]` são resultados históricos, não execução recente de revisor ou futuro leitor | Média | Esclarecido no EN |
| DOC-201 | Lab 12 | Verificação final da rede deve preservar VPC e ambas as sub-redes do Lab 08; distinguir resultado histórico de inventário atual | Média | Documentado no EN |
| DOC-202 | Lab 12 | Verificar navegação ao diretório real do Lab 13, `13-aws-application-troubleshooting`, sem inventar rota | Baixa | Conferido no EN |

**Resultado:** tradução inglesa publicada com cinco imagens e procedimentos completos de implantação, validação, injeção de falha controlada, vinte requisições bem-sucedidas pelo backend B, recuperação, nova validação e cleanup. Scripts e política IAM inspecionados estaticamente. Nenhuma operação AWS realizada nesta fase. Evidências não inspecionadas visualmente em resolução integral.

## Auditoria específica — Lab 13

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/13-aws-application-troubleshooting/README.md`, seis scripts PowerShell (`deploy-aws-application-troubleshooting.ps1`, `invoke-aws-application-failure.ps1`, `diagnose-aws-application-failure.ps1`, `recover-aws-application-service.ps1`, `test-aws-application-troubleshooting.ps1`, `remove-aws-application-troubleshooting.ps1`), `policies/ec2-ssm-trust-policy.json` e inventário de três imagens.  
**Intervenção:** publicada versão inglesa `README.en.md` com evidências efetivamente existentes e links bilíngues. Português preservado exceto pelo link. Nenhum script, serviço Linux ou recurso AWS foi executado ou alterado nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-203 | Lab 13 | Diagnóstico que termina com sucesso confirma a causa esperada da falha, **não** significa que o serviço esteja recuperado | Alta | Explicado no EN |
| DOC-204 | Lab 13 | Injeção de configuração inválida mantém Nginx indisponível até executar script separado de recuperação; não há rollback automático da injeção | Alta | Advertência no EN |
| DOC-205 | Lab 13 | Diagnóstico cobre estado de serviço, processo, porta TCP 80, `nginx -t` e `journalctl`; explicitar que esse encadeamento caracteriza uma falha simulada conhecida | Média | Esclarecido no EN |
| DOC-206 | Lab 13 | Diagnóstico sem alterações corretivas usa `ssm:SendCommand`; distinguir comandos remotos observacionais de API AWS estritamente read-only | Alta | Distinção no EN |
| DOC-207 | Lab 13 | Injeção exige `-ConfirmFailureInjection`; recuperação `-ConfirmRecovery`; cleanup `-ConfirmRemoval`. As três ações possuem efeitos distintos | Alta | Fluxo detalhado no EN |
| DOC-208 | Lab 13 | Backup e marcador de falha são fundamentais para restaurar e evitar repetição ambígua da injeção; revisar estado e preservar evidências em falha parcial | Alta | Contextualizado no EN |
| DOC-209 | Lab 13 | `nginx -t` pode falhar de maneira esperada durante incidente; saída e status devem ser interpretados no contexto do diagnóstico | Média | Contextualizado no EN |
| DOC-210 | Lab 13 | Resultado HTTP público pode ser afetado por IP de origem, VPN/NAT ou configuração do SG; indisponibilidade isolada não identifica causa de aplicação | Média | Ressalva no EN |
| DOC-211 | Lab 13 | README em português contém IDs completos da VPC e da sub-rede na seção de resultados, apesar do compromisso de anonimização de evidências | Alta | Identificado; correção no PT-BR pendente de aprovação |
| DOC-212 | Lab 13 | Scripts imprimem IDs, IPv4 público e URL em saídas; inspecionar imagens e o README original antes de afirmar anonimização integral | Alta | Observação no EN; inspeção visual pendente |
| DOC-213 | Lab 13 | O inventário contém apenas três imagens; duas possuem nomes genéricos `Clipboard_...` e não devem receber descrições específicas sem inspeção visual | Média | EN preserva links neutros; análise visual pendente |
| DOC-214 | Lab 13 | Alguns trechos PT-BR ainda narram execução futura apesar de resultados finais documentados; uniformizar tempos verbais posteriormente | Média | EN relata histórico; PT-BR pendente |
| DOC-215 | Lab 13 | Ambiente EC2 não tem chave SSH, mas HTTP TCP 80 permanece sem TLS; restrição por IPv4 e ausência de SSH não são hardening completo | Alta | Esclarecido no EN |
| DOC-216 | Lab 13 | AMI Amazon Linux 2023 dinâmica impede reprodução bit a bit sem registrar AMI selecionada por execução | Média | Registrado no EN |
| DOC-217 | Lab 13 | Falhas no deploy podem deixar recursos parciais; cleanup exige conferência de IDs, propriedade e dependências além das tags e da autorização | Alta | Advertência no EN |
| DOC-218 | Lab 13 | Validação saudável e pós-recuperação é pontual; não comprova SLA/SLO ou resiliência de longo prazo | Média | Escopo no EN |
| DOC-219 | Lab 13 | Uma instância `t3.micro`, armazenamento EBS e IPv4 público podem gerar cobrança mesmo se removidos após a execução | Média | Custos contextualizados no EN |
| DOC-220 | Lab 13 | Critérios de sucesso (29) representam execução histórica registrada; não atribuir sua conclusão a revisor ou leitor | Média | Esclarecido no EN |
| DOC-221 | Lab 13 | Confirmar continuidade ao diretório real `14-aws-disk-utilization` e preservação da rede compartilhada do Lab 08 | Baixa | Navegação conferida no EN |
| DOC-222 | Lab 13 | A política EC2 permite assumir role, mas não substitui permissão IAM de operador para Session Manager; revisar auditoria de sessões em uso real | Média | Esclarecido no EN |

**Resultado:** publicação inglesa com roteiro completo de deploy, validação inicial, falha intencional, diagnóstico não remediador, recuperação autorizada, revalidação e cleanup. Os seis scripts e a política IAM foram revisados estaticamente. Inventário com três imagens confirmado, sendo duas vinculadas sem interpretação visual não verificada. IDs completos presentes no README português identificados como pendência prioritária. Nenhuma operação AWS realizada.

## Auditoria específica — Lab 14

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/14-aws-disk-utilization/README.md`, seis scripts (`deploy-aws-disk-utilization.ps1`, `invoke-aws-disk-pressure.ps1`, `diagnose-aws-disk-utilization.ps1`, `mitigate-aws-disk-utilization.ps1`, `test-aws-disk-utilization.ps1`, `remove-aws-disk-utilization.ps1`), `policies/ec2-ssm-trust-policy.json` e inventário de 15 imagens.  
**Intervenção:** publicada tradução inglesa `README.en.md`, preservadas referências das 15 imagens e adicionada navegação recíproca. README português preservado além do link de idioma. Nenhuma operação EC2/SSM/EBS, execução PowerShell/Bash ou alteração de infraestrutura foi realizada nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-223 | Lab 14 | Pressão em volume EBS dedicado de 2 GiB reduz risco ao sistema, mas não garante isolamento absoluto caso identificação do dispositivo ou mount esteja incorreta | Alta | Advertência no EN |
| DOC-224 | Lab 14 | `mkfs.ext4 -F` é operação destrutiva; conferir volume anexado, caminhos NVMe, identidade e ausência de filesystem prévio | Alta | Documentado no EN; revisão de execução futura |
| DOC-225 | Lab 14 | Script solicita alvo de 82% e execução registra 85%; preservar valores distintos e considerar alocação `ext4`, arredondamentos e contabilização do filesystem | Alta | Preservado e contextualizado no EN |
| DOC-226 | Lab 14 | Gerador de pressão requer utilização final estritamente inferior a 88%; validador aceita valor menor **ou igual** a 88%; harmonizar comparadores | Alta | Divergência documentada no EN; correção de script pendente |
| DOC-227 | Lab 14 | `88%` é limite de segurança arbitrado para este laboratório, não limite universal seguro de Linux, AWS ou EBS | Alta | Ressalva no EN |
| DOC-228 | Lab 14 | Cálculo `USED_BYTES + AVAILABLE_BYTES` trata blocos reservados do ext4 de forma diferente da capacidade nominal de 2 GiB; manter distinção de unidades/capacidade útil | Média | Esclarecido no EN |
| DOC-229 | Lab 14 | Diagnóstico que identifica `Elevated` e encerra com sucesso não equivale a mitigação nem ao retorno do estado saudável | Alta | Distinção no EN |
| DOC-230 | Lab 14 | Diagnóstico e validador usam `ssm:SendCommand` para observações no host; não são exclusivamente APIs AWS read-only | Média | Contextualizado no EN |
| DOC-231 | Lab 14 | Inode usage de 1% é evidência contra exaustão de inodes na amostra, não assegura ausência de outros gargalos em gravação | Média | Contextualizado no EN |
| DOC-232 | Lab 14 | Zero arquivos apagados e ainda abertos é observação pontual; a inspeção por `/proc` pode depender de permissões e condições de corrida | Média | Ressalva no EN |
| DOC-233 | Lab 14 | 24 arquivos e cerca de 1,50 GiB de recuperação potencial não equivalem a 1,50 GiB efetivamente recuperados, porque há compressão e retenção | Alta | Diferenciado no EN |
| DOC-234 | Lab 14 | Mitigação com `gzip -t` e comparação por `cmp` valida conteúdo comprimido antes de remover original, mas não comprova backup durável ou imutável fora do host | Média | Explicado no EN |
| DOC-235 | Lab 14 | Retenção limitada a cinco arquivos compactados implica descarte irreversível de outros arquivos; não aplicar sem avaliar requisitos forenses e legais de logs | Alta | Alerta no EN |
| DOC-236 | Lab 14 | `-ConfirmDiskPressure`, `-ConfirmMitigation` e `-ConfirmRemoval` são autorizações de ações diferentes e não substituem conferência de recursos | Alta | Fluxo distinguido no EN |
| DOC-237 | Lab 14 | Validação de estado `Healthy` usa percentual estritamente inferior a 60%, enquanto `Elevated` inicia em 80%; faixa intermediária merece semântica clara | Média | Estados contextualizados no EN |
| DOC-238 | Lab 14 | Cleanup repetível no histórico não é prova de idempotência universal em falhas parciais/concorrrência; etiquetas e nomes não garantem propriedade exclusiva | Alta | Escopo explicado no EN |
| DOC-239 | Lab 14 | Formatação, compressão, exclusão de logs, remoção EBS e encerramento EC2 são operações destrutivas; preservar evidências e requisitos de retenção antes de cleanup | Alta | Advertência no EN |
| DOC-240 | Lab 14 | Evidências contêm 15 imagens com nomes `Clipboard_...` e possíveis IDs EC2/EBS, IPs ou dados da conta; inspecionar individualmente em resolução integral | Alta | Inventário confirmado; inspeção visual pendente |
| DOC-241 | Lab 14 | Custo potencial de EC2 `t3.micro`, volume raiz, EBS de 2 GiB, IPv4 público e transferência não é eliminado retroativamente após cleanup | Média | Contextualizado no EN |
| DOC-242 | Lab 14 | Configuração de AMI Amazon Linux 2023 por parâmetro SSM pode mudar; registrar imagem resolvida para reprodutibilidade | Média | Ressalva no EN |
| DOC-243 | Lab 14 | Critérios de sucesso (28) e Git working tree limpa documentam execução histórica, não verificação atual de AWS ou garantia de segurança | Média | Diferenciação no EN |
| DOC-244 | Lab 14 | Verificar navegação para o diretório existente `15-aws-connectivity-troubleshooting` e preservação da rede do Lab 08 | Baixa | Conferido no EN |

**Resultado:** README inglês publicado com parâmetros, comandos, diagnóstico nas seis dimensões, observações históricas (85% de pico, 24 arquivos, 1,50 GiB potenciais, 1% inodes, 0 arquivos removidos abertos e 57% após mitigação), 15 evidências e sequência de cleanup. Os seis scripts foram analisados estaticamente, sem execução. A inspeção visual integral das imagens permanece pendente.

## Auditoria específica — Lab 15

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/15-aws-connectivity-troubleshooting/README.md`, seis scripts PowerShell (`deploy-aws-connectivity-troubleshooting.ps1`, `test-aws-connectivity-troubleshooting.ps1`, `invoke-aws-connectivity-failure.ps1`, `diagnose-aws-connectivity-failure.ps1`, `recover-aws-connectivity.ps1`, `remove-aws-connectivity-troubleshooting.ps1`), política `ec2-ssm-trust-policy.json` e inventário das dez imagens.  
**Intervenção:** criada documentação inglesa `README.en.md` com seis imagens incorporadas e quatro capturas históricas vinculadas; navegação recíproca adicionada, sem alterar o texto português fora do seletor de idioma. Scripts, evidências e serviços AWS não foram modificados ou executados.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-245 | Lab 15 | README português publica número completo de conta AWS, IDs da VPC, subnet, route table, NACL, EC2, SG, IDs de regras e IPv4 público de origem; avaliar anonimização antes de distribuição | Alta | Identificado; omitido no EN; PT-BR pendente |
| DOC-246 | Lab 15 | O primeiro check HTTP do deploy falhou, mas `curl.exe --noproxy "*"` confirmou HTTP 200 e conteúdo esperado sem segundo deploy; diferenciar erro do caminho cliente/proxy de falha da aplicação | Alta | Contextualizado no EN |
| DOC-247 | Lab 15 | Consulta `checkip.amazonaws.com` fornece IPv4 visível ao serviço, que pode divergir do IP de saída das requisições via proxy ou VPN | Alta | Advertência no EN |
| DOC-248 | Lab 15 | Falha controlada remove regra ingress TCP 80 do Security Group; não desliga instância, Nginx, rota, IGW ou NACL | Alta | Delimitado no EN |
| DOC-249 | Lab 15 | Validador `Failed` com execução bem-sucedida comprova estado negativo esperado, não disponibilidade de serviço ou conclusão de recuperação | Alta | Esclarecido no EN |
| DOC-250 | Lab 15 | Diagnóstico somente observacional usa `ssm:SendCommand`; execução remota não equivale a apenas consultas read-only AWS | Média | Distinção no EN |
| DOC-251 | Lab 15 | Diagnóstico lista Network ACL mas não realiza comparação de baseline antes/depois; evitar afirmar que houve inspeção exaustiva ou prova de inalterabilidade | Alta | Limitação no EN |
| DOC-252 | Lab 15 | Rota pública e IGW anexado isoladamente não provam tráfego ponta a ponta; considerar regras SG/NACL, origem e resposta real | Média | Documentado no EN |
| DOC-253 | Lab 15 | SG é stateful e NACL é stateless; apresentar como camadas distintas na análise de conectividade | Média | Esclarecido no EN |
| DOC-254 | Lab 15 | Falha registrada após mensagem de sucesso na injeção veio de `throw` do chamador ao avaliar `$LASTEXITCODE` depois de script PowerShell; não classificá-la erroneamente como falha da mutação AWS | Alta | Histórico preservado no EN |
| DOC-255 | Lab 15 | Regra reautorizada tem novo ID AWS; protocolo, porta e CIDR caracterizam o acesso equivalente, sem exigir reutilização do ID removido | Média | Esclarecido no EN |
| DOC-256 | Lab 15 | Diferenciar `-ConfirmConnectivityFailure`, `-ConfirmRecovery` e `-ConfirmRemoval` e conferir recursos antes de mudanças disruptivas/destrutivas | Alta | Procedimentos no EN |
| DOC-257 | Lab 15 | A restauração da regra pode não devolver HTTP saudável para todos os clientes; confirmar origem de teste e propagação, não somente existência da regra | Média | Ressalva no EN |
| DOC-258 | Lab 15 | HTTP em TCP 80 não oferece TLS; `/32` restringe rede mas não autentica usuário nem criptografa conteúdo | Alta | Advertência no EN |
| DOC-259 | Lab 15 | AMI Amazon Linux 2023 via parâmetro SSM público é dinâmica; registrar AMI ID para reprodutibilidade de nova execução | Média | Contextualizado no EN |
| DOC-260 | Lab 15 | Deploy pode terminar parcialmente após criar recursos; inventariar antes de repetir implantação ou iniciar cleanup | Alta | Ressalva no EN |
| DOC-261 | Lab 15 | Tags, nomes e `-ConfirmRemoval` não garantem ausência de dependências externas; cleanup pode ser parcial e exige nova inspeção | Alta | Alertas no EN |
| DOC-262 | Lab 15 | Custos de EC2, EBS e IPv4 público podem ser cobrados mesmo em execução curta seguida de exclusão | Média | Documentado no EN |
| DOC-263 | Lab 15 | Dez capturas existem; seis possuem descrição de etapa e quatro são genéricas. Verificar todas visualmente, inclusive exposição de account ID, CIDR e IDs de recurso | Alta | Inventário conferido; inspeção visual pendente |
| DOC-264 | Lab 15 | Estado histórico concluído em 25/09/2026 não representa disponibilidade/ausência atuais; não reusar IDs históricos em comandos atuais | Alta | Esclarecido no EN |
| DOC-265 | Lab 15 | Scripts de validação aceitam `Healthy`, `Failed` e `Any`; `Any` não exige sucesso do HTTP externo, evitar confundir seu resultado com disponibilidade | Média | Semântica documentada no EN |
| DOC-266 | Lab 15 | Navegação do próximo laboratório deve apontar para `16-aws-systems-manager-troubleshooting` efetivamente existente | Baixa | Confirmado no EN |

**Resultado:** README inglês publicado com dez caminhos de evidência (seis imagens incorporadas e quatro links), procedimentos completos de deploy/Healthy, injeção/Failed, diagnóstico, recuperação/Healthy, cleanup e distinções entre falha de proxy, regra SG removida e resposta local saudável. Seis scripts e política IAM analisados estaticamente. Identificadores históricos no README português registrados para revisão de privacidade, sem alterá-los nesta etapa. Inspeção visual aprofundada das dez capturas pendente.

## Auditoria específica — Lab 16

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/16-aws-systems-manager-troubleshooting/README.md`, seis scripts PowerShell (`deploy-aws-systems-manager-troubleshooting.ps1`, `test-aws-systems-manager-troubleshooting.ps1`, `invoke-aws-systems-manager-failure.ps1`, `diagnose-aws-systems-manager-failure.ps1`, `recover-aws-systems-manager.ps1`, `remove-aws-systems-manager-troubleshooting.ps1`), política `ec2-ssm-trust-policy.json` e inventário das seis imagens.  
**Intervenção:** criado `README.en.md` com seis imagens e navegação recíproca; texto em português preservado exceto pelo link de idioma. Nenhum script foi modificado, nenhuma chamada AWS foi executada e nenhuma instância foi reiniciada nesta auditoria.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-267 | Lab 16 | Primeira tentativa de revogar HTTPS foi **inconclusiva**: SSM permaneceu `Online` por 24 verificações e a regra foi restaurada; não apresentar como falha confirmada | Alta | Distinção preservada no EN |
| DOC-268 | Lab 16 | Segunda tentativa revogou saída HTTPS e reiniciou exclusivamente a instância Lab 16; `ConnectionLost` observado somente em 38/40 verificações | Alta | Sequência e limites detalhados no EN |
| DOC-269 | Lab 16 | Hipótese de conexões previamente estabelecidas/connection tracking é plausível, mas não foi comprovada diretamente com captura ou inspeção de conexões | Alta | Qualificada como hipótese no EN |
| DOC-270 | Lab 16 | `EC2 running` não implica `SSM Online`, e `SSM Online` isolado não comprova sucesso de sessão interativa ou Run Command | Alta | Estados distinguidos no EN |
| DOC-271 | Lab 16 | Diagnóstico e recuperação devem utilizar AWS control plane quando SSM está indisponível; não exigir Run Command para resolver falha da própria conectividade SSM | Alta | Método descrito no EN |
| DOC-272 | Lab 16 | Falha controlada exige `-ConfirmFailure` e inclui reboot disruptivo; não aplicar a instâncias compartilhadas ou produtivas | Alta | Advertência no EN |
| DOC-273 | Lab 16 | Script de injeção tenta restaurar saída em erro após mutação e antes da falha confirmada, mas recuperação automática pode falhar; verificar inventário após erro | Alta | Limite explicitado no EN |
| DOC-274 | Lab 16 | Validação `Failed` exige `ConnectionLost` e ausência de regra egress; diagnóstico isolado pode terminar reportando cenário inconclusivo | Alta | Semântica distinguida no EN |
| DOC-275 | Lab 16 | NACL foi inspecionada, porém não comparada a baseline; evitar afirmar exclusão definitiva de outras causas de conectividade | Média | Limitação no EN |
| DOC-276 | Lab 16 | Regra TCP 443 para `0.0.0.0/0` foi apropriada ao escopo histórico, mas é mais ampla que alternativa com VPC endpoints e restrições específicas | Alta | Discussão no EN; arquitetura futura |
| DOC-277 | Lab 16 | Recriar egress produz um novo Security Group Rule ID; conferir protocolo, portas, CIDR e SG em vez de comparar exclusivamente IDs antigos | Média | Registrado no EN |
| DOC-278 | Lab 16 | Timeout de 24/40 verificações não determina prazo universal de perda ou recuperação SSM; comportamento pode variar por agente, rede e estado de conexões | Média | Limite no EN |
| DOC-279 | Lab 16 | Primeira validação de IAM Instance Profile falhou pela comparação; ajuste usou ARN esperado completo e teste saudável passou sem reimplantar EC2 | Média | Troubleshooting preservado no EN |
| DOC-280 | Lab 16 | Problema de codificação em Windows PowerShell 5.1 exigiu UTF-8 com BOM no script diagnóstico; parser sem erros não comprova integração AWS | Média | Registrado no EN |
| DOC-281 | Lab 16 | README português inclui AWS Account ID e IDs completos de EC2, VPC, subnet, SG e regra; avaliar redução/anônimização antes de divulgação ampla | Alta | Identificado; omitido no EN; PT-BR pendente |
| DOC-282 | Lab 16 | Seis imagens presentes, mas inspeção visual integral para IDs de conta/recurso e clareza de evidência não foi realizada | Alta | Inventário confirmado; revisão visual pendente |
| DOC-283 | Lab 16 | IAM trust policy e `AmazonSSMManagedInstanceCore` não concedem, isoladamente, direitos de operador para iniciar sessões ou alterar EC2 | Alta | Distinção no EN |
| DOC-284 | Lab 16 | Cleanup exige `-ConfirmRemoval` e conferências, mas tags e nomes não provam ausência de dependências externas; não remover instância de outro repositório | Alta | Limite e proteção no EN |
| DOC-285 | Lab 16 | AMI Amazon Linux 2023 por parâmetro público pode variar e EC2/EBS/IPv4 público geram custos potenciais mesmo com cleanup posterior | Média | Registrado no EN |
| DOC-286 | Lab 16 | Resultado e checklist refletem execução histórica; nenhum estado atual da conta AWS foi consultado nesta tradução | Média | Escopo delimitado no EN |
| DOC-287 | Lab 16 | Próximo lab existente deve ser referenciado como `17-aws-controlled-update`; preservar navegação entre idiomas e rede do Lab 08 | Baixa | Diretório conferido e link inserido no EN |

**Resultado:** README inglês com sequência completa incluindo tentativa inconclusiva, reboot da instância exclusiva, `ConnectionLost` em 38/40, diagnóstico sem dependência de SSM, recuperação pela EC2 API, validação e cleanup. Seis evidências referenciadas e scripts/política lidos estaticamente. Identificadores históricos do README português registrados como prioridade de privacidade; inspeção visual das seis capturas pendente. Nenhuma operação AWS realizada.

## Auditoria específica — Lab 17

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/17-aws-controlled-update/README.md`, sete scripts PowerShell (`deploy-aws-controlled-update.ps1`, `test-aws-controlled-update.ps1`, `apply-aws-controlled-update.ps1`, `diagnose-aws-controlled-update.ps1`, `rollback-aws-controlled-update.ps1`, `confirm-aws-controlled-update.ps1`, `remove-aws-controlled-update.ps1`), `policies/ec2-ssm-trust-policy.json` e inventário das sete imagens.  
**Intervenção:** criada documentação inglesa `README.en.md` com sete imagens incorporadas; adicionada navegação bilíngue ao português sem outras alterações do texto original. Não houve execução de scripts, chamadas AWS, mudança de aplicação ou edição de evidências nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-288 | Lab 17 | Configuração inválida da candidata provoca falha em `nginx -t`, mas Nginx permanece ativo servindo v1; não descrever como indisponibilidade da aplicação | Alta | Precisão preservada no EN |
| DOC-289 | Lab 17 | Diferenciar os cinco estados `Baseline`, `CandidateFailed`, `RolledBack`, `Updated` e `Confirmed`; validação de `CandidateFailed` não é sucesso da release v2 | Alta | Tabela de estados no EN |
| DOC-290 | Lab 17 | Backup `backup-v1` e manifesto `SHA256SUMS` estão na mesma EC2: viabilizam rollback local, não recuperação após perda de instância/volume | Alta | Limitação explícita no EN |
| DOC-291 | Lab 17 | Rollback restaura `index.html`, `health`, `version` e `lab17-release.conf`, confirma configuração e compara conteúdo com backup; não é transação atômica multi-arquivo | Alta | Etapas e escopo no EN |
| DOC-292 | Lab 17 | SHA-256 e `cmp` demonstram equivalência de bytes aos dados de referência, mas não autenticidade/inviolabilidade do backup se ele puder ser alterado | Média | Esclarecido no EN |
| DOC-293 | Lab 17 | Na candidata inválida, somente `lab17-release.conf` divergiu do backup; `/health`, `/version` e página permaneceram em v1 | Média | Resultado preservado no EN |
| DOC-294 | Lab 17 | Marcador `updated` representa implantação v2 ainda não confirmada; `confirmed` exige comando separado e testes locais/externos | Alta | Fluxo diferenciado no EN |
| DOC-295 | Lab 17 | Confirmação da v2 mantém backup v1; não presumir backup externo, resiliência ou rollback automático a partir do marcador | Média | Limitação no EN |
| DOC-296 | Lab 17 | Diagnóstico sem remediação usa `ssm:SendCommand`; comando Linux observacional não é API AWS estritamente read-only | Média | Distinção no EN |
| DOC-297 | Lab 17 | Run Command assíncrono pode concluir no host antes de uma falha/timeout do cliente; registrar `CommandId`, investigar invocation e marcador antes de repetição | Alta | Advertência no EN |
| DOC-298 | Lab 17 | Falhas de encoding no Windows para `--parameters file://` e CRLF na linha `#!/bin/sh` exigiram normalização UTF-8/LF; parsing local isolado é insuficiente | Alta | Troubleshooting documentado no EN |
| DOC-299 | Lab 17 | README português expõe AWS Account ID, VPC, subnet, EC2, SG, IPv4 da instância, origem `/32`, cinco CommandIds e hashes; avaliar divulgação/anonimização | Alta | Valores evitados no EN; PT-BR pendente |
| DOC-300 | Lab 17 | Scripts também contêm identificador de conta esperado embutido; reprodução em outra conta depende de revisão explícita, não somente alterar `-ProfileName` | Alta | Identificado; revisão de parametrização futura |
| DOC-301 | Lab 17 | HTTP TCP 80 sem TLS e origem restrita por IPv4 não implementam confidencialidade nem autenticação de usuário | Alta | Alerta no EN |
| DOC-302 | Lab 17 | Teste v1/v2 é pontual numa instância única; não comprova rollout zero-downtime, disponibilidade contínua, ausência de erros sob carga ou SLA | Média | Escopo limitado no EN |
| DOC-303 | Lab 17 | Verificação do endereço via `curl.exe --noproxy "*"` depende da origem efetiva do cliente; IP pode variar por VPN/NAT/proxy | Média | Advertência no EN |
| DOC-304 | Lab 17 | Tags, nomes e confirmações de update/rollback/cleanup não substituem conferência de conta, ID da instância, dependências e retenção | Alta | Salvaguardas explicadas no EN |
| DOC-305 | Lab 17 | Cleanup da EC2 remove potencialmente backup local, marcadores e rastros; preservar evidência requerida antes de operação irreversível | Alta | Advertência no EN |
| DOC-306 | Lab 17 | AMI Amazon Linux 2023 resolvida dinamicamente; registrar AMI selecionada para reprodutibilidade de futuras execuções | Média | Ressalva no EN |
| DOC-307 | Lab 17 | Custo de instância EC2, EBS e IPv4 público pode ocorrer antes de cleanup e não é anulado retroativamente | Média | Registrado no EN |
| DOC-308 | Lab 17 | Sete imagens existem, mas a inspeção integral para legibilidade, hashes, CommandIds e identificadores pessoais/de conta não foi realizada | Alta | Inventário confirmado; inspeção visual pendente |
| DOC-309 | Lab 17 | Próximo laboratório tem diretório real `18-aws-application-backup-restore`; vincular sem atribuir execução atual aos resultados históricos | Baixa | Link inserido no EN |

**Resultado:** README inglês publicado com sete evidências, estados de release, comandos de deploy, candidata inválida, diagnóstico, rollback verificado, atualização v2, confirmação e cleanup. Sete scripts e política IAM examinados estaticamente. Exposição dos identificadores históricos no README português e account ID embutido em scripts registrada para revisão separada. Inspeção visual em resolução integral das sete capturas pendente. Nenhuma operação AWS realizada.

## Auditoria específica — Lab 18

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/18-aws-application-backup-restore/README.md`, sete scripts PowerShell (`deploy-aws-application-backup-restore.ps1`, `test-aws-application-backup-restore.ps1`, `create-aws-application-backup.ps1`, `invoke-aws-application-data-loss.ps1`, `diagnose-aws-application-data-loss.ps1`, `restore-aws-application-backup.ps1`, `remove-aws-application-backup-restore.ps1`), políticas `ec2-ssm-trust-policy.json` e `s3-application-backup-policy-template.json` e inventário de 13 imagens.  
**Intervenção:** README inglês publicado com nove evidências incorporadas e quatro imagens extras vinculadas; navegação bilíngue acrescentada ao português, sem modificar demais trechos. Nenhuma execução AWS, alteração de scripts, políticas ou imagens nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-310 | Lab 18 | Recuperação demonstrada é de **dois arquivos ativos** de aplicação; não representa restauração integral de instância, volume EBS, SO ou base de dados | Alta | Escopo explicitado no EN |
| DOC-311 | Lab 18 | Durante `DataLoss`, `/health` seguiu respondendo HTTP 200 mesmo com `/` e `/version` em 404; health check isolado não garante funcionalidade crítica | Alta | Destacado no EN |
| DOC-312 | Lab 18 | Backup depende de `VersionId` específico; evitar restaurar implicitamente versão mais recente ou objeto com mesmo nome sem conferir identidade | Alta | Documentado no EN |
| DOC-313 | Lab 18 | Conferir SHA-256 de pacote, membro e manifesto é evidência forte de integridade frente à referência, mas não garante autenticidade de origem adulterável | Média | Ressalva no EN |
| DOC-314 | Lab 18 | Archive `.tar.gz` exige exatamente cinco arquivos regulares sem diretórios e limites de tamanho; não generalizar verificador para arquivos tar arbitrários | Alta | Escopo esclarecido no EN |
| DOC-315 | Lab 18 | Política S3 da instância permite `GetBucketVersioning`, `PutObject` e `GetObjectVersion` no escopo delimitado; não concede exclusões S3 | Alta | Política documentada no EN |
| DOC-316 | Lab 18 | `aws:SecureTransport=false` aplica Deny ao acesso da identidade pelo bucket; avaliar demais principais e políticas de bucket separadamente | Média | Distinção no EN |
| DOC-317 | Lab 18 | Block Public Access, SSE-S3, `BucketOwnerEnforced` e versionamento são controles distintos; versionamento não cria backup imutável | Alta | Explicado no EN |
| DOC-318 | Lab 18 | Janela de 15 minutos após habilitação do versionamento é guarda programada no deploy; não afirmar que é requisito universal ou prova de propagação | Média | Limitação no EN |
| DOC-319 | Lab 18 | `ObservedRecoverySeconds=356,294` mede da perda até HTTP local recuperado, incluindo diagnóstico/espera do operador; não confundir com tempo apenas de script | Alta | Interpretado no EN |
| DOC-320 | Lab 18 | `RestoreOperationSeconds=0,663` mede trecho Python remoto, excluindo fluxo completo PowerShell/SSM; não anunciá-lo como RTO end-to-end | Alta | Diferenciado no EN |
| DOC-321 | Lab 18 | `BackupAgeSecondsAtLoss=77.716,093` é idade da cópia, não RPO observado nem volume de dados perdidos | Alta | Diferenciado no EN |
| DOC-322 | Lab 18 | SSM Run Command cria invocações mesmo durante diagnóstico não-remediador; timeouts podem exigir inspeção de `CommandId` e arquivos `pending` | Alta | Advertência no EN |
| DOC-323 | Lab 18 | `flock` e registros pendentes ajudam a evitar repetição concorrente ou cega de backup/perda/restauração, mas falhas parciais podem requerer inspeção manual | Média | Documentado no EN |
| DOC-324 | Lab 18 | Perda controlada apaga somente `index.html` e `version`; preservar `health`, configuração e bucket é essencial para a interpretação do experimento | Média | Delimitado no EN |
| DOC-325 | Lab 18 | Falha inicial de deploy relacionada a argumentos EC2 foi corrigida e os recursos parciais removidos antes de reimplantar; registrar histórico sem ocultar falha | Média | Troubleshooting no EN |
| DOC-326 | Lab 18 | Cleanup de bucket versionado exige exclusão permanente das versões e delete markers e inspeção de uploads multipart e concorrência | Alta | Alerta no EN |
| DOC-327 | Lab 18 | `Quiet=true` gerou resposta vazia e incompatível com parser JSON; ajuste para `Quiet=false` permitiu validação e retomada do cleanup parcial | Média | Registro no EN |
| DOC-328 | Lab 18 | Scripts têm AWS Account ID esperado hardcoded e Região limitada a `us-east-1`; não são portáveis apenas mudando perfil AWS CLI | Alta | Aviso no EN; parametrização futura |
| DOC-329 | Lab 18 | README português publica conta, IP, bucket/key/VersionId, timestamps e hashes históricos; revisar exposição pública e imagens antes de afirmar anonimização | Alta | Omitidos no EN quando desnecessários; PT-BR pendente |
| DOC-330 | Lab 18 | Existem 13 imagens, mas README português apresenta apenas nove; não atribuir conteúdo às quatro adicionais sem inspeção | Média | Nove incorporadas e quatro vinculadas no EN |
| DOC-331 | Lab 18 | Inspeção visual integral das 13 imagens para legibilidade, conta, IP, bucket, VersionId, CommandId e dados sensíveis permanece necessária | Alta | Inventário confirmado; inspeção visual pendente |
| DOC-332 | Lab 18 | Cleanup remove EC2, EBS e backup versionado; verificar retenção de evidências e possibilidade de recuperação antes de exclusão irreversível | Alta | Advertência no EN |
| DOC-333 | Lab 18 | EC2, EBS, IPv4 público, S3 versões, requisições e transferência podem custar mesmo com cleanup posterior | Média | Registrado no EN |
| DOC-334 | Lab 18 | Validações e métricas históricas não substituem testes de recuperação sob carga, falha completa de host, banco de dados ou definição formal de RTO/RPO | Média | Escopo no EN |
| DOC-335 | Lab 18 | Próximo lab existente deve ser vinculado por `19-terraform-essential-workflow`; preservar VPC/subnet compartilhadas do Lab 08 | Baixa | Diretório conferido no EN |

**Resultado:** versão inglesa publicada com fluxo `Baseline → BackedUp → DataLoss → Restored → cleanup`, comandos, integridade do pacote, VersionId, 404/200 da falha parcial, recuperação, intervalos distintos, cleanup S3 versionado e 13 caminhos de imagens. Sete scripts e duas políticas inspecionados estaticamente. Nenhuma operação AWS realizada. Inspeção visual integral das evidências e saneamento de identificadores históricos permanecem pendentes.

## Auditoria específica — Lab 19

**Data:** 2026-11-10  
**Arquivos examinados:** `labs/19-terraform-essential-workflow/README.md`, `terraform/versions.tf`, `terraform/main.tf`, `terraform/outputs.tf`, `.gitignore` na raiz do repositório e inventário de três imagens.  
**Intervenção:** publicado `README.en.md` em inglês com três imagens e documentação passo a passo; navegação bilíngue adicionada ao README original, sem alterar as demais seções. Nenhuma execução do Terraform, alteração de configuração HCL, estado ou recurso AWS ocorreu nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-336 | Lab 19 | `terraform_data.lab19` é recurso integrado registrado no estado local, não objeto EC2/S3 ou recurso provisionado na AWS | Alta | Escopo explicitado no EN |
| DOC-337 | Lab 19 | Execução documentada dispensou AWS CLI, credenciais AWS e infraestrutura de nuvem; não atribuir custos AWS ao exercício | Alta | Esclarecido no EN |
| DOC-338 | Lab 19 | Restrição `>= 1.4.0, < 2.0.0` aceita versões além da `1.16.1` historicamente utilizada; não confundir versão usada com pin exato | Média | Contextualizado no EN |
| DOC-339 | Lab 19 | `terraform plan -detailed-exitcode`: 0 sem mudanças, 1 erro e 2 mudanças propostas; código 2 não representa falha | Alta | Semântica documentada no EN |
| DOC-340 | Lab 19 | Arquivo de plano salvo deve ser inspecionado antes do `apply`; aplicação com caminho de plano não solicita confirmação interativa habitual | Alta | Advertência no EN |
| DOC-341 | Lab 19 | Planos podem ficar obsoletos com mudanças de estado; não reutilizar `.tfplan` depois de alterações concorrentes sem revisão | Alta | Advertência no EN |
| DOC-342 | Lab 19 | Segundo plano sem mudanças comprova convergência da configuração e estado do recurso local; não é validação de drift de infraestrutura AWS | Alta | Limitação no EN |
| DOC-343 | Lab 19 | `terraform destroy` remove o recurso gerenciado no workspace atual, não necessariamente arquivos de estado, backups ou arquivos `.tf` | Alta | Distinção no EN |
| DOC-344 | Lab 19 | Após destroy, um novo plano normal pode propor criação, pois os arquivos de configuração continuam declarando o recurso | Média | Esclarecido no EN |
| DOC-345 | Lab 19 | Antes de destroy, conferir workspace e `terraform state list` para prevenir destruição de objetos não pertencentes ao exercício | Alta | Salvaguarda no EN |
| DOC-346 | Lab 19 | Remover ou editar `terraform.tfstate` manualmente não equivale a destruir recurso com Terraform e pode prejudicar rastreabilidade | Alta | Advertência no EN |
| DOC-347 | Lab 19 | `.gitignore` exclui `.terraform/`, arquivos de estado e planos, mas não oferece criptografia, bloqueio de leitura nem garantia contra commits anteriores | Alta | Limitação no EN |
| DOC-348 | Lab 19 | Em deployments reais, estado e planos podem conter atributos sensíveis; tratar arquivos locais como dados operacionais protegidos | Alta | Alerta no EN |
| DOC-349 | Lab 19 | `.terraform.lock.hcl` é relevante para seleções de providers externos; exercício usa provider integrado, sem necessidade de plugin AWS | Média | Diferenciado no EN |
| DOC-350 | Lab 19 | Erro inicial `Too many command line arguments` decorreu de invocação CLI; array PowerShell corrigiu argumentos sem criar recurso na tentativa falha | Média | Histórico preservado no EN |
| DOC-351 | Lab 19 | `terraform fmt -check` verifica sem reformatar; execução de `terraform fmt` pode modificar arquivos e exige revisão Git | Baixa | Esclarecido no EN |
| DOC-352 | Lab 19 | `terraform validate` confirma validade de configuração, não que o plano foi aplicado ou que houve criação de recurso | Média | Limitação no EN |
| DOC-353 | Lab 19 | IDs do recurso `terraform_data` são específicos da criação; não reutilizar identificador histórico como parâmetro fixo | Baixa | Observação no EN |
| DOC-354 | Lab 19 | O laboratório não ensaia backend remoto, locking compartilhado, colaboração, AWS provider, políticas CI/CD ou risco de drift externo | Média | Limites explicitados no EN |
| DOC-355 | Lab 19 | Três imagens estão presentes e referenciadas, mas não foram inspecionadas integralmente para legibilidade ou dados acidentais | Média | Inventário confirmado; inspeção visual pendente |
| DOC-356 | Lab 19 | Caminho `C:\GitHub\...` é específico da estação original; documentação para terceiros deve permitir qualquer local de clone | Baixa | Ajustado no EN |
| DOC-357 | Lab 19 | Próximo diretório existente é `20-terraform-aws-infrastructure`; manter navegação e distinguir claramente Lab 19 local de Lab 20 AWS | Baixa | Confirmado no EN |

**Resultado:** README em inglês publicado com procedimentos `init`, `fmt`, `validate`, plano salvo, `apply`, inspeção de estado e outputs, plano sem mudanças, `destroy` e verificação de estado vazio. Três imagens preservadas. Arquivos HCL e `.gitignore` revisados estaticamente. Nenhum comando Terraform ou AWS foi executado. Inspeção visual integral das três imagens permanece pendente.

## Auditoria específica — Lab 20

**Data:** 2026-11-11  
**Arquivos examinados:** `labs/20-terraform-aws-infrastructure/README.md`, dez arquivos no diretório `terraform/` (oito `.tf`, `user-data.sh.tftpl`, `.terraform.lock.hcl`), três scripts PowerShell (`test-aws-terraform-prerequisites.ps1`, `test-aws-terraform-infrastructure.ps1`, `test-aws-terraform-cleanup.ps1`) e inventário de nove imagens.  
**Intervenção:** criado `README.en.md` em inglês, com nove evidências incorporadas; adicionado seletor de idiomas ao README em português sem alterar suas demais seções. Nenhuma execução Terraform/AWS ou edição dos arquivos HCL, scripts e imagens foi realizada.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-358 | Lab 20 | São sete recursos Terraform gerenciados; o root EBS está em `root_block_device` dentro de `aws_instance.application`, não como oitavo recurso independente | Alta | Explicitado no EN |
| DOC-359 | Lab 20 | Quatro data sources consultam identidade AWS, VPC, subnet e AMI; VPC/subnet do Lab 08 não são gerenciadas nem importadas para o estado do Lab 20 | Alta | Diferenciação no EN |
| DOC-360 | Lab 20 | `terraform apply` concluído não comprova cloud-init, SSM Online, Nginx saudável ou HTTP pronto; exigir validação operacional separada | Alta | Advertência no EN |
| DOC-361 | Lab 20 | Planos salvos de criação e destruição são aplicados sem prompt interativo habitual; revisão anterior ao apply é o controle principal | Alta | Fluxo no EN |
| DOC-362 | Lab 20 | `terraform plan -detailed-exitcode` retorna 0 sem alterações, 1 por erro, 2 com mudanças; exigir 2 no plano inicial e no destroy, 0 no segundo plano | Média | Documentado no EN |
| DOC-363 | Lab 20 | State local não oferece backend remoto ou locking entre operadores; compartilhar arquivos locais sem governança cria risco de concorrência e perda | Alta | Limitação no EN |
| DOC-364 | Lab 20 | Estado `terraform.tfstate` e planos `.tfplan` podem incluir user data, metadados e IDs; `.gitignore` não equivale a criptografia, sigilo ou controle de acesso | Alta | Advertência no EN |
| DOC-365 | Lab 20 | `terraform state rm` ou apagar estado não exclui recursos AWS; cleanup deve usar Terraform com plano revisado e verificação AWS independente | Alta | Ressalva no EN |
| DOC-366 | Lab 20 | A root EBS tem 8 GiB, `gp3`, criptografia e `delete_on_termination=true`; a exclusão AWS é verificada separadamente, sem contar o bloco como recurso gerenciado adicional | Média | Esclarecido no EN |
| DOC-367 | Lab 20 | Uso de `most_recent=true` na AMI Amazon Linux 2023 significa que novo plano pode selecionar imagem diferente; registrar AMI resolvida para reprodutibilidade | Média | Contextualizado no EN |
| DOC-368 | Lab 20 | Provider `hashicorp/aws` estava no lock em `6.67.0`, mas `~> 6.0` permite outras versões 6.x; usar `-lockfile=readonly` para seleção registrada | Média | Distinção no EN |
| DOC-369 | Lab 20 | Hash SHA-256 de arquivo de lock pode mudar com CRLF/LF enquanto conteúdo semântico é igual; diferenciar hash do arquivo dos checksums de providers no lock | Média | Troubleshooting no EN |
| DOC-370 | Lab 20 | `user-data.sh.tftpl` é carregado via `file()` e CRLF convertido a LF; trocar para `templatefile()` sem avaliar variáveis Bash pode quebrar o script | Média | Explicado no EN |
| DOC-371 | Lab 20 | Marcador `bootstrap-complete` só é escrito após checagens locais; não confundir sua presença com garantia de disponibilidade externa contínua | Média | Contextualizado no EN |
| DOC-372 | Lab 20 | Validador coleta hashes SHA-256 de arquivos Nginx, mas não os compara automaticamente a manifesto esperado; não anunciar autenticação ou verificação determinística de integridade | Alta | Limitação no EN |
| DOC-373 | Lab 20 | Validador não remedia a aplicação, porém usa SSM Run Command, isto é, execução remota e não apenas APIs read-only AWS | Média | Distinção no EN |
| DOC-374 | Lab 20 | SG aceita HTTP TCP 80 de /32 e HTTPS egress TCP 443 para `0.0.0.0/0`; sem TLS, autenticação HTTP ou egress mínimo em rede de produção | Alta | Advertência no EN |
| DOC-375 | Lab 20 | `allowed_account_ids` é proteção útil, mas valor `expected_account_id` tem default histórico em HCL e scripts; revisar ao portar para outra conta | Alta | Registrado no EN; parametrização futura |
| DOC-376 | Lab 20 | Validação de IPv4 obtido por checkip pode diferir do tráfego HTTP via proxy/VPN/NAT; revalidar origem antes do plano e dos testes | Média | Advertência no EN |
| DOC-377 | Lab 20 | Pré-validação da VPC, subnet, IGW e NACL e conferência pós-cleanup inspecionam atributos selecionados, não um diff integral de rede compartilhada | Média | Escopo delimitado no EN |
| DOC-378 | Lab 20 | Antes de destruir, registrar outputs/IDs para o validador pós-cleanup; depois do destroy outputs podem desaparecer | Alta | Procedimento explícito no EN |
| DOC-379 | Lab 20 | Falha parcial de apply ou destroy exige inspeção de estado e inventário AWS antes de gerar novo plano; não presumir rollback automático | Alta | Advertência no EN |
| DOC-380 | Lab 20 | Custos potenciais incluem EC2 `t3.micro`, EBS, IPv4 público e transferência; destroy posterior não elimina custos já incorridos | Média | Registrado no EN |
| DOC-381 | Lab 20 | README português contém AMI, EC2, EBS, SG, SG rules, rede compartilhada e SSM CommandId históricos; revisar exposição e evitar reutilização | Alta | Omitidos no EN; PT-BR pendente |
| DOC-382 | Lab 20 | Nove screenshots inventariados e incorporados, porém sem inspeção visual integral para legibilidade ou eventual exposição de conta/recursos | Alta | Inventário confirmado; inspeção visual pendente |
| DOC-383 | Lab 20 | No-change plan documenta convergência na verificação pontual, não ausência perpétua de drift, SLA, testes de carga ou alta disponibilidade | Média | Ressalva no EN |
| DOC-384 | Lab 20 | Documentar próximo diretório real `21-terraform-remote-state` e a distinção entre o state local atual e o backend remoto do Lab 21 | Baixa | Navegação conferida no EN |

**Resultado:** README inglês publicado com 9 imagens, sete recursos gerenciados, quatro data sources, comandos de planos salvos, validações operacionais e destruição controlada. Dez arquivos Terraform e três scripts PowerShell inspecionados estaticamente. README português recebeu apenas navegação. Nenhum Terraform/AWS foi executado. Inspeção visual das imagens permanece pendente.

## Auditoria específica — Lab 21

**Data:** 2026-11-11  
**Arquivos examinados:** `labs/21-terraform-remote-state/README.md`, seis arquivos de `bootstrap/` (incluindo `.terraform.lock.hcl`), três arquivos de `terraform/`, dois scripts PowerShell (`test-aws-terraform-remote-state-prerequisites.ps1`, `test-aws-terraform-state-bucket.ps1`) e inventário de 23 imagens.  
**Intervenção:** criada tradução inglesa `README.en.md` com links para 13 evidências aceitas no documento original e dez imagens históricas adicionais; adicionada navegação bilíngue ao README português, sem alterar as demais seções. Não houve execução Terraform/AWS, migração real, modificação HCL ou exclusão de estado.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-385 | Lab 21 | Bootstrap e exercício têm estados separados: bootstrap local gerencia o bucket; exercício migra local → S3; evitar backend dependente do próprio estado que ele hospeda | Alta | Arquitetura explicitada no EN |
| DOC-386 | Lab 21 | São seis recursos gerenciados pelo bootstrap e um `terraform_data.lab21` no exercício; este último não representa recurso AWS | Alta | Escopo no EN |
| DOC-387 | Lab 21 | `terraform/versions.tf` atual declara `backend "s3" {}` e reflete fase pós-migração; reprodução do baseline exige preparar configuração local antes de criar o primeiro estado | Alta | Lacuna de reprodução detalhada no EN; melhoria de automação futura |
| DOC-388 | Lab 21 | Após cleanup o bucket S3 não existe; execução direta de `terraform init` do exercício atual requer novo bootstrap e backend válido | Alta | Alerta no EN |
| DOC-389 | Lab 21 | `init -migrate-state` transfere estado existente; `init -reconfigure` não substitui migração do estado | Alta | Diferença explicitada no EN |
| DOC-390 | Lab 21 | Não reutilizar planos salvos antes de mudança de backend/estado; revisar novo plano no contexto S3 | Alta | Advertência no EN |
| DOC-391 | Lab 21 | Migração preservou ID e outputs de `terraform_data.lab21`; comprova continuidade no cenário histórico, não recuperação universal contra corrupção | Média | Escopo no EN |
| DOC-392 | Lab 21 | `use_lockfile=true` utiliza lock nativo do S3 por objeto `.tflock`; não envolve DynamoDB | Alta | Diferenciado no EN |
| DOC-393 | Lab 21 | Lock do estado e `.terraform.lock.hcl` têm finalidades distintas: concorrência da escrita versus seleção de dependências | Média | Esclarecido no EN |
| DOC-394 | Lab 21 | Tentativa inicial com `terraform console` não demonstrou lock; resultado aceito veio de `apply -replace` aguardando aprovação e segunda operação recusada | Alta | Histórico preservado no EN |
| DOC-395 | Lab 21 | Erro `412 PreconditionFailed` foi observação desta tentativa de concorrência; não generalizar como único código possível de conflito de estado | Média | Limite no EN |
| DOC-396 | Lab 21 | Aplicação em espera deve ser cancelada com `no`; aprovar substituição violaria a condição do ensaio de identidade preservada | Alta | Advertência no EN |
| DOC-397 | Lab 21 | Não remover manualmente lock ativo, usar `-lock=false` ou `force-unlock` sem provar ausência do dono; risco de operações concorrentes | Alta | Procedimento seguro no EN |
| DOC-398 | Lab 21 | Bucket com `force_destroy=false` não permite remoção automática de conteúdo; exige cleanup explícito e conferência de versões e delete markers | Alta | Explicado no EN |
| DOC-399 | Lab 21 | Inventário observou duas versões do estado, seis versões históricas do lock e seis delete markers: 14 itens excluídos por chave e `VersionId` | Alta | Números preservados no EN |
| DOC-400 | Lab 21 | Deleção de versão específica do S3 pode ser permanente; validar identidade, bucket, proprietário, chaves, versões e retenção antes de exclusão | Alta | Advertência no EN |
| DOC-401 | Lab 21 | Ordem do cleanup deve destruir exercício via backend remoto, limpar versões/marcadores S3 e só então destruir seis recursos bootstrap | Alta | Sequência detalhada no EN |
| DOC-402 | Lab 21 | Bootstrap exige `expected_account_id` sem default e workspace `default`; conferência da conta é proteção necessária em deploy e destroy | Alta | Pré-requisitos no EN |
| DOC-403 | Lab 21 | Versionamento, Block Public Access, `BucketOwnerEnforced`, SSE-S3 e DenyInsecureTransport são controles distintos; não equivalem a Object Lock/imutabilidade | Média | Diferenciado no EN |
| DOC-404 | Lab 21 | Política de bucket nega transporte inseguro, mas não demonstra least privilege global; revisar IAM de todos os operadores e outros principals | Alta | Ressalva no EN |
| DOC-405 | Lab 21 | Estado remoto não significa execução remota: Terraform rodou na estação Windows e apenas persistiu estado/bloqueio no S3 | Média | Esclarecido no EN |
| DOC-406 | Lab 21 | `local-artifacts/`, backend config, state e planos contêm dados operacionais; `.gitignore` não substitui segurança e sigilo dos arquivos locais | Alta | Avisos no EN |
| DOC-407 | Lab 21 | Diretório `images/` contém 23 imagens, mas README original relaciona 13 aceitas; não atribuir conteúdos específicos às dez outras sem exame visual | Média | Todas 23 referenciadas, dez neutras no EN |
| DOC-408 | Lab 21 | Inspeção visual integral das 23 capturas para IDs AWS, buckets, VersionIds, informação de estado, legibilidade e dados sensíveis permanece pendente | Alta | Inventário confirmado; inspeção visual pendente |
| DOC-409 | Lab 21 | Custo AWS limita-se essencialmente a S3 e operações associadas; arquivo `terraform_data` não provisiona EC2 nem gera cobrança de compute | Média | Custos contextualizados no EN |
| DOC-410 | Lab 21 | Navegação do próximo laboratório deve apontar para diretório existente `22-terraform-variables-outputs-modules` | Baixa | Link conferido no EN |

**Resultado:** README em inglês publicado com arquitetura de backend independente, migração e preservação da identidade, demonstração de bloqueio concorrente, cleanup versionado de 14 itens e seis recursos bootstrap removidos. Onze arquivos de código/configuração inspecionados estaticamente, com 23 imagens inventariadas e referenciadas. Identificada a necessidade de alternar o backend para local em uma nova reprodução completa. Nenhuma operação Terraform ou AWS realizada; inspeção visual detalhada pendente.

## Auditoria específica — Lab 22

**Data:** 2026-11-11  
**Arquivos examinados:** `labs/22-terraform-variables-outputs-modules/README.md`, cinco arquivos na raiz de `terraform/` (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars.example`), quatro arquivos do módulo filho em `terraform/modules/lab-component/` e inventário de sete imagens.  
**Intervenção:** publicada documentação inglesa `README.en.md` com todas as sete imagens referenciadas; navegação bilíngue incluída no README português, sem alterar demais conteúdos. Nenhuma execução Terraform ou AWS, nenhuma escrita em estado local e nenhuma edição dos arquivos HCL foi realizada.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-411 | Lab 22 | Exercício é exclusivamente local com provider integrado `terraform_data`, sem autenticação AWS, serviços em nuvem ou backend remoto do Lab 21 | Alta | Escopo documentado no EN |
| DOC-412 | Lab 22 | Duas chamadas ao módulo filho criam exatamente dois recursos `terraform_data`, um por chamada; valores de `replica_count` não representam quantidade de recursos criados | Alta | Distinção explícita no EN |
| DOC-413 | Lab 22 | `monitoring_enabled=true` é apenas metadado didático; não instala monitoramento, agentes ou observabilidade | Alta | Ressalva no EN |
| DOC-414 | Lab 22 | Módulo `application` recebe `replica_count` da raiz; módulo `worker` fixa o valor em 1 e não acompanha alterações da variável da raiz | Média | Explicado no EN |
| DOC-415 | Lab 22 | O `merge(var.tags, {...})` dá precedência aos campos do segundo mapa em conflitos de chave; distinguir mapa registrado de tags AWS reais | Média | Precedência esclarecida no EN |
| DOC-416 | Lab 22 | Variáveis raiz/filho rejeitam `null`; validar nomes, enumeração de ambiente e integridade da faixa inteira 1–5 | Média | Regras documentadas no EN |
| DOC-417 | Lab 22 | Somente um caso de entrada inválida (`replica_count=0`) foi testado; isso não comprova cobertura de limites, tipos, todos ambientes ou nomes | Média | Escopo delimitado no EN |
| DOC-418 | Lab 22 | Rejeição da entrada retornou código 1; SHA-256 de `terraform.tfvars` permaneceu igual, demonstrando preservação do arquivo nesse ensaio | Média | Resultado histórico no EN |
| DOC-419 | Lab 22 | `plan -detailed-exitcode`: 0 sem mudanças, 1 erro, 2 mudanças propostas; testar saída imediatamente via `$LASTEXITCODE` | Alta | Semântica documentada no EN |
| DOC-420 | Lab 22 | Plano salvo de criação e destruição não exige nova aprovação interativa no `apply`; revisar ambos antes de executar | Alta | Alertas no EN |
| DOC-421 | Lab 22 | `terraform fmt -check -diff -recursive` verifica raiz e filho sem modificar arquivos; diferença de formato exige avaliação antes de correção | Baixa | Etapa explicada no EN |
| DOC-422 | Lab 22 | Outputs `component_ids` e `lab_summary` agregam dados dos módulos filhos; não representam endpoints HTTP ou infraestrutura provisionada | Média | Distinção no EN |
| DOC-423 | Lab 22 | Identificadores UUID dos dois `terraform_data` são específicos da execução; não reutilizar como entradas fixas de novo ciclo | Baixa | IDs históricos omitidos no EN |
| DOC-424 | Lab 22 | Segundo plano sem mudanças confirma convergência de estado local e configuração naquele momento; não detecta drift externo nem prova disponibilidade | Média | Limite no EN |
| DOC-425 | Lab 22 | Plano destroy deve conter exclusivamente `module.application.terraform_data.component` e `module.worker.terraform_data.component` e exigir conferência do workspace | Alta | Procedimento no EN |
| DOC-426 | Lab 22 | Depois do destroy, estado vazio não significa remoção dos nove arquivos de configuração; novo plano pode propor duas recriações | Média | Explicado no EN |
| DOC-427 | Lab 22 | Não apagar estado ou executar `state rm` para fingir limpeza: o laboratório aplicou plano de destruição e verificou estado sem objetos | Alta | Advertência no EN |
| DOC-428 | Lab 22 | `terraform.tfvars`, planos e estado devem permanecer fora do Git; `.gitignore` não garante sigilo nem controle de acesso | Alta | Salvaguardas no EN |
| DOC-429 | Lab 22 | Sete imagens existem e foram referenciadas, mas inspeção visual integral para legibilidade, correspondência de etapa ou dados incidentais está pendente | Média | Inventário confirmado; exame visual pendente |
| DOC-430 | Lab 22 | Continuidade deve apontar para diretório existente `23-terraform-changes-drift`, sem sugerir execução AWS no Lab 22 | Baixa | Navegação conferida no EN |

**Resultado:** README inglês publicado com variáveis tipadas, validação, módulo reutilizável, outputs, dois recursos locais, planos salvos, no-change e destroy. Nove arquivos de configuração analisados estaticamente, sete capturas preservadas, scripts e serviços AWS intactos. Inspeção visual integral das evidências pendente.

## Auditoria específica — Lab 23

**Data:** 2026-11-11  
**Arquivos examinados:** `labs/23-terraform-changes-drift/README.md`, `.gitignore` do laboratório, seis arquivos em `terraform/` (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars.example`, `.terraform.lock.hcl`) e inventário de 14 imagens.  
**Intervenção:** publicado `README.en.md` em inglês, com 14 capturas incorporadas e distinções entre configuração, state e arquivo observado; adicionada navegação bilíngue no README português. Nenhuma execução Terraform, alteração HCL, manipulação de arquivo local ou operação AWS realizada.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-431 | Lab 23 | Exercício utiliza exclusivamente provider `hashicorp/local` e arquivo JSON de teste; não demonstrou drift em AWS, nem implantação/execução de aplicação | Alta | Escopo explicitado no EN |
| DOC-432 | Lab 23 | Distinguir mudança declarada `application_version v1→v2` de drift externo `log_level info→debug`; só a segunda não altera a configuração desejada | Alta | Cenários separados no EN |
| DOC-433 | Lab 23 | Terraform HCL, estado gravado e conteúdo real do arquivo são fontes diferentes; outputs anteriores ao refresh não comprovam leitura atual do recurso | Alta | Distinção detalhada no EN |
| DOC-434 | Lab 23 | Mudança intencional gerou plano `1 add, 0 change, 1 destroy` para substituição de um recurso lógico `local_file`; não significa duas aplicações ativas | Alta | Interpretado no EN |
| DOC-435 | Lab 23 | Drift externo gerou plano `1 add, 0 change, 0 destroy`; arquivo com `debug` ainda estava presente fisicamente após o plano | Alta | Plano diferenciado de observação física no EN |
| DOC-436 | Lab 23 | Ação `create` após drift depende do comportamento do provider/estado observado; não generalizar a outros providers ou cenários de drift | Alta | Ressalva no EN |
| DOC-437 | Lab 23 | A detecção exige confronto do arquivo real com baseline v2, configuração e state/outputs; planejamento isolado não executa reparo | Alta | Metodologia no EN |
| DOC-438 | Lab 23 | Reconciliar requer aplicar plano revisado e confirmar conteúdo e SHA-256 do arquivo restaurado, não apenas confiar na saída do apply | Alta | Validação no EN |
| DOC-439 | Lab 23 | Baseline v2 e recuperação compartilham SHA-256 registrado, enquanto drift apresenta valor diferente; preservar hashes como resultados históricos e verificar referência de confiança | Média | Quatro hashes preservados no EN |
| DOC-440 | Lab 23 | `jsonencode` gera JSON compacto seguido de LF explícito; JSON ilustrativo formatado não equivale aos mesmos bytes usados nos hashes | Média | Diferença explicada no EN |
| DOC-441 | Lab 23 | `expected_content_sha256` calcula hash do conteúdo declarado, não do arquivo lido continuamente; exigir hash independente do filesystem | Alta | Limitação dos outputs no EN |
| DOC-442 | Lab 23 | Drift manual limitado a `local-artifacts/application-config.json` e não editou `terraform.tfstate`; preservar isolamento para reprodução | Alta | Restrição registrada no EN |
| DOC-443 | Lab 23 | Provider `hashicorp/local` está fixado em 2.9.1 no HCL e lock; Terraform CLI permite `>=1.4,<2.0`; não confundir versões | Média | Dependências no EN |
| DOC-444 | Lab 23 | Planos salvos de baseline, mudança, reconciliação e destruição precisam de inspeção prévia; aplicar plano salvo não requer aprovação interativa habitual | Alta | Salvaguarda no EN |
| DOC-445 | Lab 23 | `plan -detailed-exitcode`: 0 sem mudanças, 1 erro, 2 mudanças propostas; verificar `$LASTEXITCODE` após cada comando externo | Média | Semântica documentada no EN |
| DOC-446 | Lab 23 | `.gitignore` local protege `local-artifacts/` do versionamento usual e root ignora states/plans; nenhum deles representa confidencialidade ou criptografia | Alta | Advertência no EN |
| DOC-447 | Lab 23 | Após destroy, confirmar simultaneamente estado vazio, arquivo gerenciado ausente e configuração/registros preservados; não apagar estado manualmente para simular limpeza | Alta | Critérios descritos no EN |
| DOC-448 | Lab 23 | Arquivo `terraform.tfvars.example` mantém v1/info/dev, ao passo que variáveis locais pós-exercício estavam em v2/info/dev; leitor deve preparar valores corretos em cada fase | Média | Reprodutibilidade no EN |
| DOC-449 | Lab 23 | Quatro registros locais `baseline-v1.json`, `baseline-v2.json`, `drift-observed.json` e `terraform-v1.tfvars` permaneceram fora do Git | Média | Inventário no EN |
| DOC-450 | Lab 23 | As 14 evidências existem e estão incorporadas, porém não houve inspeção visual em resolução integral de legibilidade e dados incidentais | Média | Inventário verificado; inspeção visual pendente |
| DOC-451 | Lab 23 | Próximo diretório existente é `24-terraform-automated-validation`; documentação deve apontar corretamente para ele | Baixa | Link conferido no EN |

**Resultado:** README inglês com baseline v1, mudança intencional para v2, drift do arquivo, plano de recuperação, validação independente por conteúdo/hash e limpeza final. Sete arquivos técnicos (HCL/lock/exemplo e .gitignore) revisados estaticamente, 14 capturas preservadas e nenhuma operação Terraform/AWS executada. Inspeção visual integral pendente.

## Auditoria específica — Lab 24

**Data:** 2026-11-11  
**Arquivos examinados:** `labs/24-terraform-automated-validation/README.md`, workflow `.github/workflows/lab24-terraform-validation.yml`, lock do provider do Lab 23 em `labs/23-terraform-changes-drift/terraform/.terraform.lock.hcl`, inventário de seis capturas e registro GitHub do pull request #1.  
**Intervenção:** criada versão inglesa `README.en.md` com cinco imagens incorporadas e uma imagem adicional vinculada; adicionada navegação bilíngue ao README original. Nenhum workflow foi executado novamente, nenhum arquivo YAML/HCL/lock foi modificado, nenhuma operação AWS foi realizada.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-452 | Lab 24 | Workflow CI valida somente Labs 22 e 23; matriz de dois jobs não representa cobertura de todos os laboratórios Terraform do repositório | Alta | Escopo definido no EN |
| DOC-453 | Lab 24 | Testes executam `terraform version`, `fmt`, `init -backend=false`, `validate`; não executam `plan`, `apply`, `destroy` ou integração AWS | Alta | Limitações explicitadas no EN |
| DOC-454 | Lab 24 | `init -backend=false` não verifica backend de estado, bloqueios, autenticação ou comunicação de recursos remotos | Alta | Limite documentado no EN |
| DOC-455 | Lab 24 | `fail-fast: false` mantém outro job em execução quando há falha, sem transformar resultado reprovado em aprovado | Média | Comportamento no EN |
| DOC-456 | Lab 24 | Alterações automáticas só acionam workflow em push/PR para `main` quando afetam filtros específicos; README e imagens do Lab 24 não acionam por si só | Média | Filtros explicitados no EN |
| DOC-457 | Lab 24 | Existe acionamento `workflow_dispatch`; não há execução periódica agendada no YAML examinado | Baixa | Gatilhos documentados no EN |
| DOC-458 | Lab 24 | Provider `hashicorp/local` 2.9.1 do Lab 23 exigiu ajustes de hashes para Windows e Linux; preservar `.terraform.lock.hcl` versionado e verificar integridade cross-platform | Alta | Histórico e reparo no EN |
| DOC-459 | Lab 24 | Lock de dependências e bloqueio de state são mecanismos diferentes; `-lockfile=readonly` impede atualização silenciosa do arquivo de dependências | Média | Distinção no EN |
| DOC-460 | Lab 24 | Comando `git diff --exit-code -- .terraform.lock.hcl` verifica arquivo imutável após init; não é análise de mudanças não versionadas fora da comparação Git | Média | Escopo especificado no EN |
| DOC-461 | Lab 24 | Falha de formatação do Lab 22 registrou código 3 no `fmt`; não confundir com `plan -detailed-exitcode` que utiliza 0/1/2 | Média | Advertência no EN |
| DOC-462 | Lab 24 | Falha em `fmt` interrompeu passos restantes daquele job, enquanto Lab 23 concluiu normalmente; não interpretar como falha simultânea dos dois labs | Média | Resultado no EN |
| DOC-463 | Lab 24 | Referência a variável inexistente passou pelo `fmt` e `init`, mas foi detectada por `validate` (exit 1); cenários demonstram responsabilidades de checks distintos | Alta | Teste descrito no EN |
| DOC-464 | Lab 24 | Após correções, ambos os jobs passaram; testes cobrem defeitos específicos e não todas as falhas possíveis de HCL, módulo ou provider | Alta | Generalização evitada no EN |
| DOC-465 | Lab 24 | PR #1 encontra-se fechado e não mesclado no GitHub; histórico afirma exclusão de branch temporária e arquivos de teste | Média | PR conferido; histórico contextualizado no EN |
| DOC-466 | Lab 24 | Checks aprovados não comprovam branch protection ou regra de status obrigatório para impedir merge com falhas | Alta | Limitação explícita no EN |
| DOC-467 | Lab 24 | Actions `actions/checkout@v6` e `hashicorp/setup-terraform@v4` usam tags em vez de SHA imutável; considerar pinagem para reduzir risco de supply chain | Alta | Recomendação no EN |
| DOC-468 | Lab 24 | Permissão `contents: read` e checkout sem credenciais persistentes restringem exposição, mas não são comprovação de segurança de todo pipeline | Média | Distinção no EN |
| DOC-469 | Lab 24 | Runner `ubuntu-24.04`, Terraform `1.16.1` e timeout de dez minutos por job são escolhas de execução registradas; avaliar upgrades separadamente | Baixa | Configuração documentada no EN |
| DOC-470 | Lab 24 | Diretório `images/` contém seis PNGs, apesar de README original incorporar cinco; sexta imagem vinculada sem atribuição de conteúdo não verificado | Média | Inventário completo no EN |
| DOC-471 | Lab 24 | Inspeção visual integral das seis capturas quanto a conteúdo, legibilidade e possível exposição de identidade/ambiente GitHub permanece pendente | Média | Pendente |
| DOC-472 | Lab 24 | Uso de GitHub-hosted Actions pode estar sujeito a limites/consumo de plataforma, mas laboratório não consome EC2/S3 nem AWS credentials | Baixa | Custos contextualizados no EN |
| DOC-473 | Lab 24 | Próximo diretório existente é `25-cloudwatch-metrics` e deve ser vinculado sem sugerir execução do Lab 25 | Baixa | Link inserido no EN |

**Resultado:** publicada documentação inglesa com arquitetura de dois jobs, filtros de eventos, inicialização readonly, dependências Windows/Linux, dois ensaios negativos, correções e encerramento de PR sem merge. Workflow, lock e PR inspecionados; seis imagens preservadas. Nenhuma execução do CI/Terraform/AWS nem modificação de YAML/HCL. Inspeção visual das evidências pendente.

## Auditoria específica — Lab 25

**Data:** 2026-11-11  
**Arquivos examinados:** `labs/25-cloudwatch-metrics/README.md`, oito scripts PowerShell (`lab25-common.ps1`, `deploy-aws-cloudwatch-metrics.ps1`, `test-aws-cloudwatch-metrics.ps1`, `invoke-aws-cloudwatch-cpu-load.ps1`, `new-aws-cloudwatch-dashboard.ps1`, `remove-aws-cloudwatch-dashboard.ps1`, `remove-aws-cloudwatch-metrics.ps1`, `test-aws-cloudwatch-cleanup.ps1`), dois JSONs (`lab25-settings.json` e `ec2-ssm-trust-policy.json`) e inventário de 17 imagens.  
**Intervenção:** publicado `README.en.md` com todas as 17 evidências vinculadas (duas incorporadas); adicionada navegação bilíngue ao README português. Nenhum script, JSON, screenshot ou recurso AWS foi modificado nesta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-474 | Lab 25 | Lab 25 usa VPC, subnet, gateway e rotas **exclusivas**, diferentemente dos laboratórios que reutilizam a rede do Lab 08; cleanup remove a própria VPC | Alta | Arquitetura e escopo no EN |
| DOC-475 | Lab 25 | Coleta inicial contempla quatro métricas; `CPUCreditBalance` é a quinta consulta complementar para análise de créditos e dashboard | Média | Distinguido no EN |
| DOC-476 | Lab 25 | `CPUUtilization Average 50,173%` refere-se ao intervalo completo de cinco minutos, não a média de toda a execução de 600 s | Alta | Precisão nos dados do EN |
| DOC-477 | Lab 25 | Carga de um processo em EC2 t3.micro de duas vCPUs produziu aproximadamente 50%; evitar interpretar como falha em atingir 100% ou uso de todas as vCPUs | Média | Contextualizado no EN |
| DOC-478 | Lab 25 | Início e término da carga ocorreram no interior de períodos de 300 s, reduzindo médias das janelas parciais 20:40 e 20:50 | Média | Tabela e explicação no EN |
| DOC-479 | Lab 25 | `CPUCreditBalance` é saldo agregado; variação líquida de cerca de 7,064 créditos não prova consumo bruto devido à acumulação simultânea | Alta | Limite explicitado no EN |
| DOC-480 | Lab 25 | Métricas `NetworkIn`/`NetworkOut` com `Sum` registram bytes no período, não taxa de bytes/s; `Maximum` não equivale a pico contínuo instantâneo | Média | Semântica documentada no EN |
| DOC-481 | Lab 25 | Publicação de dados CloudWatch pode atrasar; resposta sem pontos não pode ser transformada em valor zero nem indicar automaticamente ausência de uso | Alta | Advertência no EN |
| DOC-482 | Lab 25 | Os 50 valores `StatusCheckFailed = 0` indicam ausência de falhas nas verificações EC2 consultadas, não disponibilidade de aplicação ou SLO | Alta | Limitação no EN |
| DOC-483 | Lab 25 | Primeiro ponto de `NetworkIn` apresentou 88.826.944 bytes; não atribuir origem a processo específico ou adotar como baseline de tráfego estável | Média | Histórico preservado no EN |
| DOC-484 | Lab 25 | Submissão SSM com `CommandId` não comprova término da carga; exigir `Success`, `ResponseCode=0` e `LOAD_FINISHED_OK` | Alta | Procedimento no EN |
| DOC-485 | Lab 25 | Código 124 de `timeout` é esperado no shell após 600 s, mas a invocação SSM bem-sucedida retorna código 0 após tratamento pelo wrapper | Média | Distinção no EN |
| DOC-486 | Lab 25 | Tentativa inicial falhou por CRLF em Bash remoto e não compõe medição concluída; normalização para LF permitiu a execução posterior | Média | Troubleshooting no EN |
| DOC-487 | Lab 25 | Workload de CPU limitada ainda causa impacto e não deve ser aplicada em EC2 compartilhada/produção; lock reduz repetição concorrente | Alta | Advertência no EN |
| DOC-488 | Lab 25 | Dashboard possui cinco widgets e JSON gerado dinamicamente; a comparação estrutural normalizada evita falsos erros por ordem de propriedades/whitespace | Média | Detalhado no EN |
| DOC-489 | Lab 25 | Dashboard confirmado por API e console representa configuração e observação pontual, não garantia de coleta contínua ou monitoramento de SLO | Média | Escopo delimitado no EN |
| DOC-490 | Lab 25 | Arquivo de settings e função common contêm AWS Account ID fixo, restringindo portabilidade para outra conta; revisar antes de qualquer reprodução | Alta | Identificado; valores omitidos no EN |
| DOC-491 | Lab 25 | README original contém EC2 InstanceId, RunId e SSM CommandId históricos; considerar política de divulgação de identificadores nos textos e capturas | Alta | Valores omitidos no EN; PT preservado |
| DOC-492 | Lab 25 | Recurso pré-existente/inventário local bloqueia novo deploy, protegendo contra duplicidade; falhas parciais exigem inspeção em vez de apagar inventário | Alta | Limite no EN |
| DOC-493 | Lab 25 | Security Group não possui regras de entrada; administração SSM não depende de porta 22/SSH aberta, mas requer conectividade e permissões apropriadas | Média | Arquitetura no EN |
| DOC-494 | Lab 25 | Dashboard deve ser removido e confirmado antes do cleanup da infraestrutura; scripts validam recibo, ARN, conteúdo, tags e relações de recursos | Alta | Sequência no EN |
| DOC-495 | Lab 25 | Cleanup remove VPC exclusiva, EC2, EBS, IAM, SG, subnet e IGW; é operação destrutiva e incompatível com redes compartilhadas | Alta | Advertência no EN |
| DOC-496 | Lab 25 | Correção histórica de objeto PowerShell com propriedade `V` deve ser registrada sem ocultar falha original de cleanup | Baixa | Histórico preservado no EN |
| DOC-497 | Lab 25 | Onze verificações pós-cleanup cobrem recursos inventariados, IAM/dashboard e ENIs da VPC; não representam auditoria exaustiva da conta AWS | Alta | Escopo explicitado no EN |
| DOC-498 | Lab 25 | Validador aceita instância `terminated` ainda retornada no DescribeInstances; resultado histórico específico já indicava instância ausente | Média | Diferença documentada no EN |
| DOC-499 | Lab 25 | Registros sob `%LOCALAPPDATA%` incluem inventário, recibos e métricas; preservar e proteger dados operacionais e identificadores AWS | Média | Arquivos documentados no EN |
| DOC-500 | Lab 25 | 17 imagens presentes e referenciadas; inspeção visual integral para legibilidade, IDs AWS e informação de conta permanece pendente | Alta | Inventário conferido; inspeção visual pendente |
| DOC-501 | Lab 25 | EC2, EBS, IPv4, transferência e uso aplicável do CloudWatch podem cobrar mesmo com cleanup; não presumir Free Tier ou inferir faturamento zero | Média | Limitação no EN |
| DOC-502 | Lab 25 | Métricas nativas não incluem necessariamente memória/uso de disco de convidado; CloudWatch Agent pertence ao Lab 26 e alarmes à etapa posterior | Média | Fronteira do escopo no EN |
| DOC-503 | Lab 25 | AMI AL2023 selecionada por parâmetro SSM público pode variar entre execuções; registrar ID efetivo para reprodutibilidade | Baixa | Ressalva no EN |
| DOC-504 | Lab 25 | Próximo laboratório existente é `26-cloudwatch-agent`; link deve ser conferido para continuidade bilíngue | Baixa | Link no EN |

**Resultado:** README inglês publicado com VPC exclusiva, configurações SSM e métricas, cronologia UTC da carga, semântica de créditos de CPU, cinco widgets, procedimentos de validação e cleanup com onze verificações independentes. Oito scripts e dois JSONs examinados estaticamente. Todas as 17 imagens mantidas e referenciadas; inspeção visual das capturas pendente. Nenhum recurso AWS ou script modificado.

## Auditoria específica — Lab 26

**Data:** 2026-11-12  
**Arquivos examinados:** `labs/26-cloudwatch-agent/README.md`, sete scripts PowerShell (`deploy-aws-cloudwatch-agent.ps1`, `install-aws-cloudwatch-agent.ps1`, `invoke-aws-cloudwatch-log-events.ps1`, `lab26-common.ps1`, `remove-aws-cloudwatch-agent.ps1`, `test-aws-cloudwatch-agent-cleanup.ps1`, `test-aws-cloudwatch-agent.ps1`), quatro JSONs (`lab26-settings.json`, `ec2-ssm-trust-policy.json`, `cloudwatch-agent.json`, `cloudwatch-agent-publish-policy.json`) e inventário de 17 imagens.  
**Intervenção:** publicado `README.en.md` em inglês com 17 evidências referenciadas (três incorporadas); navegação bilíngue adicionada ao README original sem modificar seus demais trechos. Nenhum script, JSON, imagem ou recurso AWS foi alterado ou executado.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-505 | Lab 26 | A VPC, subnet, rota, gateway e SG são exclusivos do Lab 26, e não reutilizados do Lab 08; cleanup inclui exclusão dessa VPC | Alta | Arquitetura e limites no EN |
| DOC-506 | Lab 26 | CloudWatch Agent coleta `mem_used_percent` e `disk_used_percent` no namespace `Lab26/CWAgent`; métricas não são nativas do namespace `AWS/EC2` | Alta | Delimitado no EN |
| DOC-507 | Lab 26 | Disco se restringe a `/` com `drop_device=true`, dimensões `InstanceId,path=/,fstype=xfs`; uso de filesystem não mede IOPS ou latência EBS | Alta | Explicado no EN |
| DOC-508 | Lab 26 | Série de memória e disco têm dimensões distintas; consulta sem conjunto efetivo de dimensões pode retornar nenhum dado | Alta | Critério de descoberta no EN |
| DOC-509 | Lab 26 | Agent `running` e hash de configuração correto não comprovam publicação; o Lab validou séries e eventos separadamente no CloudWatch | Alta | Validação em etapas no EN |
| DOC-510 | Lab 26 | Janela de consulta exclui minuto ainda em andamento, mas 60 segundos de coleta não garantem exato ponto por minuto nem publicação instantânea | Média | Limite no EN |
| DOC-511 | Lab 26 | Ausência de datapoints é tratada como pendência/sem dados, não zero ou prova imediata de falha do agente | Alta | Advertência no EN |
| DOC-512 | Lab 26 | A role combina `AmazonSSMManagedInstanceCore` com política inline de métricas/logs; trust policy da EC2 não concede permissões operacionais ao usuário | Alta | IAM diferenciado no EN |
| DOC-513 | Lab 26 | `cloudwatch:PutMetricData` usa Resource `*` com condição `cloudwatch:namespace`; ação `logs:DescribeLogGroups` também usa recurso `*` | Média | Escopos corretos no EN |
| DOC-514 | Lab 26 | Publicação `logs:CreateLogStream`/`PutLogEvents` restringida aos streams do grupo específico; agente não recebe criação de grupo ou retenção | Alta | Política conferida no EN |
| DOC-515 | Lab 26 | ARNs da política de logs e settings/common contêm account ID fixo; execução em outra conta exige alteração coordenada e nova revisão de permissões | Alta | Valores não repetidos no EN; correção futura |
| DOC-516 | Lab 26 | JSON e shell normalizados em LF antes da instalação; SHA-256 calculado do JSON normalizado, não necessariamente dos bytes brutos originais no Windows | Média | Detalhado no EN |
| DOC-517 | Lab 26 | `SendCommand` com CommandId é aceite de envio; conclusão depende de consulta SSM com status, resposta, hash, versão e marcador esperado | Alta | Fluxo no EN |
| DOC-518 | Lab 26 | `-ValidateOnly` não cria/instala/remove; `-CheckStatus` consulta comando já enviado e não deve reenviar lote em situação pendente | Alta | Salvaguarda no EN |
| DOC-519 | Lab 26 | Eventos INFO, WARN e ERROR são sintéticos; mensagem ERROR não corresponde a incidente real de aplicação | Alta | Esclarecido no EN |
| DOC-520 | Lab 26 | Correspondência dos eventos requer linha completa local e evento na AWS no stream correto; marcador isolado não substitui validação integral | Média | Critério no EN |
| DOC-521 | Lab 26 | Diferenças observadas de 11 s no evento inicial e 6/5/9 s no lote são `timestamp` vs `ingestionTime`, não garantia de latência/SLO | Alta | Limitação no EN |
| DOC-522 | Lab 26 | Retenção de um dia só vale enquanto grupo existe; cleanup exclui o log group, impedindo consulta posterior, apesar de relatórios locais preservados | Alta | Aviso explícito no EN |
| DOC-523 | Lab 26 | Cleanup deve aguardar término de comandos SSM e remover grupo de logs após EC2 para evitar nova publicação; preservar recibos antes da exclusão | Alta | Ordem documentada no EN |
| DOC-524 | Lab 26 | 11 verificações independentes cobrem os recursos e nomes do inventário, não auditoria completa de todos os recursos AWS; EC2 `terminated` é aceito | Média | Escopo no EN |
| DOC-525 | Lab 26 | Inventário com RunId e IDs evita deploy duplicado; falha parcial exige inspeção e não remoção manual do inventário | Alta | Salvaguarda no EN |
| DOC-526 | Lab 26 | Métricas históricas de memória ~23,05–23,21% e disco ~23,576–23,578% não incluem ensaio de pressão, limiares ou alarmes | Média | Resultado contextualizado no EN |
| DOC-527 | Lab 26 | Pacote instalado reportou versão 1.300071.0 em 11/10/2026, mas novas execuções podem selecionar versão diferente | Baixa | Resultado histórico no EN |
| DOC-528 | Lab 26 | Capturas 01–17 existem e são referenciadas; inspeção visual integral para legibilidade, ARN, conta, IDs e dados de instância está pendente | Alta | Inventário conferido; inspeção visual pendente |
| DOC-529 | Lab 26 | Custos podem incluir EC2, EBS, IPv4, métricas customizadas, CloudWatch Logs ingestão/armazenamento, dados e APIs; não presumir Free Tier | Média | Limites registrados no EN |
| DOC-530 | Lab 26 | Próximo diretório existente `27-cloudwatch-alarms-notifications` deve ser usado na navegação, sem sugerir que alarmes foram implementados no Lab 26 | Baixa | Link inserido no EN |

**Resultado:** versão inglesa publicada com configuração versionada do CloudWatch Agent, duas séries customizadas, IAM de publicação, instalação com hash e SSM, verificação independente das métricas, evento inicial e três logs sintéticos, cleanup de infraestrutura e grupo, e onze verificações finais. Sete scripts e quatro JSONs examinados estaticamente, 17 capturas referenciadas. Não houve execução AWS. Inspeção visual integral das imagens e revisão de portabilidade dos ARNs/account ID permanecem pendentes.

## Auditoria específica — Lab 27

**Data:** 2026-11-12  
**Arquivos examinados:** `labs/27-cloudwatch-alarms-notifications/README.md`, `config/lab27-settings.json`, sete scripts PowerShell (`deploy-aws-cloudwatch-alarms.ps1`, `invoke-aws-alarm-metric-scenario.ps1`, `lab27-common.ps1`, `remove-aws-cloudwatch-alarms.ps1`, `subscribe-aws-alarm-email.ps1`, `test-aws-cloudwatch-alarms-cleanup.ps1`, `test-aws-cloudwatch-alarms.ps1`) e inventário de 25 imagens.  
**Intervenção:** criado `README.en.md` em inglês, com 25 imagens referenciadas (cinco incorporadas); acrescentada navegação bilíngue ao README português, sem alterar suas demais seções. Nenhum script, JSON, imagem ou recurso AWS foi modificado ou executado durante esta revisão.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-531 | Lab 27 | A métrica `ApplicationErrorCount` é sintética e enviada por PowerShell; não representa erros efetivos de aplicação, disponibilidade, SLI/SLO ou log-to-metric filter | Alta | Escopo delimitado no EN |
| DOC-532 | Lab 27 | Alarmes e SNS criados sem EC2, VPC, agente ou grupo de logs; recursos dos Labs 25 e 26 já estavam removidos | Média | Arquitetura esclarecida no EN |
| DOC-533 | Lab 27 | Threshold `Sum >= 3` exige 2 de 3 períodos de 60 segundos; um único ponto com valor 5 não basta para afirmar estado ALARM | Alta | Regras de avaliação no EN |
| DOC-534 | Lab 27 | `TreatMissingData=missing` não converte ausência em zero, breach ou recuperação; `INSUFFICIENT_DATA` é estado distinto de `OK` | Alta | Diferenciado no EN |
| DOC-535 | Lab 27 | Alarmes podem reavaliar pontos históricos além dos três períodos nominais; não garantir retorno a INSUFFICIENT_DATA exatamente três minutos após publicação | Média | Limite temporal no EN |
| DOC-536 | Lab 27 | Aceitação de `PutMetricData`, consulta de ponto, mudança de estado, ação SNS e recebimento de e-mail são evidências operacionalmente distintas | Alta | Fluxo de confirmação separado no EN |
| DOC-537 | Lab 27 | Cinco pontos por fase representam quinze períodos com `SampleCount=1`; primeira consulta trouxe 14 e consulta seguinte os 15, não sendo perda comprovada | Média | Histórico preservado no EN |
| DOC-538 | Lab 27 | Fases usam valores baseline 0, breach 5 e recovery 0; publisher verifica estado prévio OK para Breach e ALARM para Recovery | Alta | Condições no EN |
| DOC-539 | Lab 27 | Três ações SNS bem-sucedidas foram registradas para primeira entrada OK, ALARM e recuperação OK; não há ação em INSUFFICIENT_DATA | Alta | Transições e ações no EN |
| DOC-540 | Lab 27 | Captura 42 registra e-mail da recuperação `ALARM → OK`; não confundir ação SNS bem-sucedida com entrega confirmada ao destinatário | Alta | Evidências distintas no EN |
| DOC-541 | Lab 27 | Assinatura de e-mail exige confirmação pelo destinatário, mesmo com solicitação/ARN retornado; `-CheckStatus` verifica ativação sem reenviar | Alta | Procedimento no EN |
| DOC-542 | Lab 27 | E-mail não consta no JSON versionado, mas endereço aparece no recibo local e pode aparecer nas imagens; realizar revisão de privacidade antes de divulgar | Alta | Privacidade documentada; imagens pendentes |
| DOC-543 | Lab 27 | Política SNS gerada aceita `sns:Publish` por `cloudwatch.amazonaws.com`, restringindo `aws:SourceAccount` e `aws:SourceArn` ao alarme pretendido | Alta | Controles IAM/SNS no EN |
| DOC-544 | Lab 27 | `lab27-settings.json` e validações comuns contêm AWS Account ID histórico fixo; reutilização em outra conta exige revisão de identidade e ARNs | Alta | Valores omitidos no EN; parametrização futura |
| DOC-545 | Lab 27 | Inventário e recibos existentes impedem duplicação cega de deploy, assinatura ou publicação por fase; não apagar arquivos para ocultar falha parcial | Alta | Salvaguardas no EN |
| DOC-546 | Lab 27 | Falha histórica em `File.Replace` na persistência do inventário foi corrigida com caminho de backup explícito; tentativas antigas verificadas/arquivadas | Média | Troubleshooting no EN |
| DOC-547 | Lab 27 | Baseline anterior em 13/10 foi distinta da sequência principal de 14/10; histórico antigo ficou fora de consulta posterior limitada a 30 minutos | Média | Cronologia separada no EN |
| DOC-548 | Lab 27 | Intervalos e horários UTC/Brasília do ensaio são observados, não garantias de latência de avaliação do CloudWatch, SNS ou entrega de e-mail | Média | Ressalva no EN |
| DOC-549 | Lab 27 | Consulta com `-WindowMinutes 120` amplia histórico consultado, mas não altera EvaluationPeriods/DatapointsToAlarm configurados | Média | Distinção no EN |
| DOC-550 | Lab 27 | Orquestração das fases e exportação extra do histórico ocorreram em blocos PowerShell locais; não inventar arquivo separado no diretório versionado | Média | Inventário correto no EN |
| DOC-551 | Lab 27 | `-ValidateOnly` evita a mutação AWS correspondente, mas o publisher chama validador que pode salvar relatório local; não prometer zero escrita local | Média | Semântica delimitada no EN |
| DOC-552 | Lab 27 | Cleanup exige inspeção de ARNs, tags, RunId, referências de outros alarmes/compostos e assinaturas; excluir alarme antes do tópico | Alta | Ordem e salvaguardas no EN |
| DOC-553 | Lab 27 | Não existe exclusão mútua entre publisher e cleanup; devem parar publicações e preservar recibos antes de remover alarme/tópico | Alta | Risco de concorrência no EN |
| DOC-554 | Lab 27 | Validador de cleanup executa duas verificações independentes (alarme e tópico), não conferência individual adicional de assinaturas ou auditoria da conta | Média | Escopo corretamente declarado no EN |
| DOC-555 | Lab 27 | Cleanup não exclui datapoints históricos da métrica; retenção depende do CloudWatch após remoção de alarme e tópico | Média | Retenção no EN |
| DOC-556 | Lab 27 | Todas as 25 imagens existem e foram referenciadas, porém inspeção visual integral para endereço de e-mail, conta AWS, ARNs e legibilidade está pendente | Alta | Inventário confirmado; inspeção visual pendente |
| DOC-557 | Lab 27 | Custos podem incluir métrica customizada, alarmes, consultas e notificações SNS; não presumir nível gratuito nem custo zero com cleanup | Média | Custos contextualizados no EN |
| DOC-558 | Lab 27 | O próximo diretório existente é `28-cloudwatch-logs-insights` e deve ser vinculado sem atribuir ao Lab 27 consultas Logs Insights | Baixa | Navegação validada no EN |

**Resultado:** README inglês publicado com configuração de alarmes, assinatura SNS confirmada, quinze amostras, transições de OK/ALARM/INSUFFICIENT_DATA, três ações SNS, evidência de três e-mails e cleanup de dois recursos. Sete scripts e um JSON examinados estaticamente; todas as 25 imagens referenciadas. Nenhuma operação AWS realizada. Inspeção visual completa e ajuste de portabilidade da conta permanecem pendentes.

## Auditoria específica — Lab 28

**Data:** 2026-11-12  
**Arquivos examinados:** `labs/28-cloudwatch-logs-insights/README.md`, `config/lab28-settings.json`, `.gitignore`, sete consultas em `queries/` e oito scripts PowerShell (`deploy-aws-logs-insights.ps1`, `invoke-aws-log-investigation-scenario.ps1`, `invoke-aws-logs-insights-query.ps1`, `lab28-common.ps1`, `remove-aws-logs-insights.ps1`, `test-aws-log-events.ps1`, `test-aws-logs-insights-cleanup.ps1`, `test-aws-logs-insights.ps1`), além de inventário de 20 capturas.  
**Intervenção:** criado `README.en.md` em inglês, com sete consultas ligadas e as 20 evidências referenciadas (três incorporadas); acrescentada somente navegação bilíngue ao README português. Nenhum script, JSON, consulta, imagem ou recurso AWS alterado ou executado.

| ID | Escopo | Constatação ou recomendação | Prioridade | Situação |
|---|---|---|---|---|
| DOC-559 | Lab 28 | Dataset possui **60 logs JSON sintéticos** distribuídos 20/20/20; não houve API, indisponibilidade real, falha de dependência nem restauração efetiva de aplicação | Alta | Escopo explícito no EN |
| DOC-560 | Lab 28 | Doze eventos HTTP 503 são gerados deliberadamente no incidente; `dependency_timeout` é causa atribuída no campo, não diagnóstico validado de falha real | Alta | Limitação no EN |
| DOC-561 | Lab 28 | Taxa de erro de 60% refere-se somente à fase incident (12/20); taxa global de 20% refere-se às três fases (12/60) | Alta | Denominadores diferenciados no EN |
| DOC-562 | Lab 28 | Médias de 673,1 ms na fase incidente e 1037,5 ms nos erros de /orders têm populações diferentes (20 vs 12) | Média | Denominadores e resultados no EN |
| DOC-563 | Lab 28 | P95/P99 resultam de somente vinte eventos sintéticos por fase; não caracterizam cauda de latência real, confiança estatística ou SLO | Alta | Ressalva no EN |
| DOC-564 | Lab 28 | Minutos 23:02/23:03/23:04 de 16/10 são timestamps atribuídos ao dataset e não horários de ingestão ou execução da consulta | Média | Cronologia esclarecida no EN |
| DOC-565 | Lab 28 | Identificação de req-021 localiza um evento por requestId; não implementa tracing distribuído nem correlação multi-serviço | Média | Distinção no EN |
| DOC-566 | Lab 28 | `PutLogEvents` aceito sem rejeição não prova publicação consultável; script independente comparou mensagens e timestamps exatos dos 60 eventos | Alta | Verificação de ingestão no EN |
| DOC-567 | Lab 28 | GetLogEvents foi percorrido até token estável, com limite de 20 páginas; três páginas observadas no êxito histórico | Média | Paginação descrita no EN |
| DOC-568 | Lab 28 | Ausência de `nextForwardToken` não deve ser interpretada como conclusão da paginação; correção preserva diagnóstico e interrompe a validação | Alta | Tratamento documentado no EN |
| DOC-569 | Lab 28 | Ramo de falta de token foi observado na falha anterior; revalidação posterior dos 60 eventos exercitou caminho normal, não repetiu o caso faltante | Média | Evidência delimitada no EN |
| DOC-570 | Lab 28 | Grupo começou com retenção de 1 dia e foi alterado para 7 dias durante troubleshooting; não confundir capturas anteriores com configuração final | Alta | Histórico no EN |
| DOC-571 | Lab 28 | Eventos antigos tornaram-se consultáveis após ajuste da retenção, **sem republicação**, mas aumento de retenção não recupera necessariamente logs já excluídos fisicamente | Alta | Generalização evitada no EN |
| DOC-572 | Lab 28 | `MalformedQueryException` foi registrada ao consultar janela antiga e inclui contexto de criação/retention; não afirmar causa única comprovada ou garantia de comportamento AWS | Alta | Contextualizado no EN |
| DOC-573 | Lab 28 | Sete arquivos `.query` usam filtro por RunId; runner substitui token do dataset para impedir mistura com outras execuções | Alta | Escopo das consultas no EN |
| DOC-574 | Lab 28 | Consultas executadas em janela do dataset de até 10 minutos, timeout padrão 120 s e limite de 100 linhas; não caracterizar runner como exportador paginado genérico | Média | Limites no EN |
| DOC-575 | Lab 28 | Todas as sete consultas examinaram 60 registros e 17.574 bytes, independentemente das linhas retornadas; custo pode depender de bytes examinados | Alta | Métrica e risco no EN |
| DOC-576 | Lab 28 | Query runner aguarda estado `Complete`, preserva request/query IDs/estatísticas e tenta StopQuery em falha ou timeout quando apropriado | Média | Fluxo documentado no EN |
| DOC-577 | Lab 28 | Grupo exclusivo `STANDARD` com stream `controlled-application`, tags e RunId; nenhum EC2, rede, Agent, alarme ou SNS provisionado | Média | Arquitetura no EN |
| DOC-578 | Lab 28 | Settings e `lab28-common.ps1` incluem ID da conta AWS esperado fixo; mover de conta exige conferir código e JSON, além do perfil | Alta | Aviso no EN; parametrização futura |
| DOC-579 | Lab 28 | Preflight sem inventário cria RunId **temporário**, diferente do RunId salvo pelo deployment; não reusar ID da pré-validação | Média | Distinção no EN |
| DOC-580 | Lab 28 | Deployment pode recriar grupo ausente se inventário anterior permanece após cleanup; verificar ausência exclusivamente com script independente | Alta | Risco operacional no EN |
| DOC-581 | Lab 28 | Publicador bloqueia `dataset.json` existente para evitar republicação acidental de lote parcial; preservar recibos em vez de contornar proteção | Alta | Salvaguarda no EN |
| DOC-582 | Lab 28 | Exclusão do log group destrói streams e eventos remotos; `local-artifacts/` é preservado e ignorado pelo Git, mas .gitignore não fornece sigilo | Alta | Cleanup e privacidade no EN |
| DOC-583 | Lab 28 | Cleanup confirma exato grupo ausente em conta/região, não inventário completo da conta ou recuperação de dados após delete | Média | Escopo no EN |
| DOC-584 | Lab 28 | Imagens inventariadas são 20, numeradas 01–07 e 09–21; imagem 08 não existe; exame visual integral de dados e legibilidade segue pendente | Alta | 20 imagens referenciadas, nenhuma 08 inventada |
| DOC-585 | Lab 28 | Custos possíveis envolvem ingestão, retenção e leitura Logs Insights; linhas retornadas não permitem inferir custo zero ou ausência de scan | Média | Riscos explicitados no EN |
| DOC-586 | Lab 28 | Próximo diretório confirmado é `29-zabbix-monitoring`; link de continuidade deve apontar ao caminho real | Baixa | Link validado no EN |

**Resultado:** README inglês publicado com escopo didático, dataset de 60 eventos, sete consultas reais, percentis e taxas diferenciadas, verificação de read-back, diagnóstico de paginação/retenção, cleanup e inventário completo de 20 capturas. Oito scripts, sete consultas, JSON e .gitignore inspecionados estaticamente. Nenhuma operação AWS executada. Inspeção visual das evidências e parametrização do ID de conta ainda pendentes.

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
