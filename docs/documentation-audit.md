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
