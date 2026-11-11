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
