# BUILD de prova privada CRUD global: lote CADASTROS_LISTAS

PLAN120 e GATE121 integrados; baseline34d88b8a77cd3ae2abfca72ee78d441c426e767b. Frontendexato74cd8ef9aa15bd19d33ce1b5d2dc6515f6066db8, integradoPR291. Checkpointfrontend292 integrado6ddf8323520a26b92c2dbee3f5b80ac13b40518a, CIprincipalSUCCESS.

RED observado: 2 testes falharam pela ausência dos dois arquivos novos. Implementação do protocolo com ambiente allowlist, credenciais só Python, AuthAdmin API/intenções persistidas, verificação SQL e finally+always de quarentena. Casos reais de UI: criar/editar/transitar organizações, contratantes e contratos, dez comandos de listas, duas abas para CAS409 e offline/online para draft. Artefatos somente relatório reduzido e capturas sintéticas. Nenhum deploy/migration/alteraçãoPROD.

Estado atual: BUILD em validação, sem execução HML deste lote. GREEN local: 38/38 testes (8 protocolo, 13 roteamento, 8 RBAC upload, 4 histórico, 5 RNF); syntax Node/Python, YAML2, Context/ZeroDrift/Crosswalk/arquitetura/segurança/históricoPASS. Revisãoindependente tratou Important de comprovação insuficiente: novo RED real por helper ausente, depois recibos comrequestid/evento/valores/CAS eSQL final de campos/estados/itens/versões/auditoria/idempotência. Revisor confirmousemCritical/Important restante. CIeHMLpendentes. Não há PASS global ou certificação V1. Capturas quatro larguras/dois temas e overflow não substituem auditoria manual de acessibilidade; worker/upload e os14 domínios restantes não são provados por este lote. Matrizfrontend mantémNO_GO até completar todas operações aplicáveis.

Sem segredo no browser, fixture, dump, HAR ou trace nosartefatos. A evidência privada não retorna nomes/emails/senhas/tokens/SQL/URLs assinadas. Contas próprias são banidas via API, sessões revogadas, vínculos/MASTER desativados e organizações próprias inativadas; auditoria/versões ficam preservadas.


## Primeira execução real e correção do harness

PR122 HEAD2676d888130ffa32f7935a34a67e7b3671098a32 integrado c5b0a31793ead6bace7a28246bcb848c26b0d107 após guard128478386065, restore128478386288, backup128478386249 eprobe128478386616SUCCESS. Mainrestore42397857433SUCCESS. Runprivado42398052328/job128479623493 falhouLIST_ITEM_CREATE apóscadastros/listaeditados porUI eHTTP200 paraitem; semPASSdelote. Artefato13583744282 SHA256528fdc8a960b2cc16002aeeb023976795e86d5d50064c9abf18cfed060e36b9d. Quarentena própria4usuários/3organizaçõesVERIFICADA, semruntimeerrors.

Causa confirmada porRED(8PASS/1FAIL): validador confundia descricao doitem comdescricao do cabeçalho. Corrigido comparando camposdocabeçalho apenasnas açõescriar/editarlista/alterarsituacao, mantendoidentidade/evento/request/CAS. Não atribuir ao produto nem abrandarpersistênciaSQLitens/versões.

Prevenção de falhadeteste adjacente, demonstrada comQueryClientreal: modooffline pausaquery antes deconsulta, semerro; nãoprova falhadeleitura. REDhelperausente(9PASS/1FAIL) seguidoCDP Network.setBlockedURLs exclusivamenteURLrealobter_lista_operacional_v1, navigatoronline; não fornece/mocka resposta, nãointercepta rota, nãoalteraAPI/autorização. finally limparegras/detach. Asserçõesrascunho+nenhumaescritadurantefalha. Mesmostimeouts30s, nenhumaescritasimulada. Protocolo10/10GREEN; retesterealpendente.


## Segunda execução real: validade da próxima versão

PR123 HEAD66f09ad0346360c2539689fd9b77b4989e382add integrado97ea8f2a52945510237705a8086e8c0a123fe9bb apósguard/restore/backup/probeSUCCESS. Run42398802825/job128481927942 avançouitenscriar/editar/remover, publicar eencerrarvigência comHTTP200/recibos; paroucriarversãoHTTP422. Artefato13584985531 SHA2567c715843f300a1fe0cd5a13b6ca8eac577baf5d3549f7579a88ed6244a46e0a5. Quarentena4usuários/3organizaçõesVERIFICADA.

Causa no preenchimento do teste: Formulario inicia vigencia_fim pela versão anterior2026-06-30; teste preenchia só novoinício2026-07-01. FonteRPC rejeita fim<início, corretamente. Helper agora preencheinício elimpa fim para nova vigência aberta, sem alterarvalidação ouproduto. REDhelperinexistente10PASS/1FAIL; GREEN11/11protocolo. Resto dos critérios permanece obrigatório; nenhumPASSdelote enquanto não houverUI/SQL/isolamento/capturas/limpeza completos.


## Terceira execução real: diagnóstico pós-descarte, sem causa presumida

PR124 HEAD `8b711281a5628998df9057fb1845621e540595ad`, merge `b30d69575609ae7aaf2fc15a8e0a85c8d0ef4322`. Main guard42399337475 e restore/backup42399337532 SUCCESS. Run privado42399542588/job128484142083 FAIL: LIST_VERSION_CREATE e LIST_DRAFT_DISCARD tiveram HTTP200 e recibos PASS; depois TimeoutError, sem assertion falsa registrada. O estágio antigo só era atualizado ao iniciar a RPC, portanto não identifica qual espera posterior falhou. Nenhuma causa atribuída a produto/backend sem evidência. Artefato13585021727 SHA256 `ba6ba6eed294da290f05d0f01e5ba807b9a02a34fdd4e4c707fffa7ac4c5ae85`, ZIP baixado e hash conferido; três relatórios lidos. Quarentena4usuários/3organizaçõesVERIFICADA; cleanup independente SUCCESS. Sem capturas ou confirmaçãoSQL final deste lote, nenhum PASS global.

Diagnóstico mínimo no escopo PLAN120/GATE121: fases OPEN/FILL/REVIEW antes das esperas de cada operação, flags booleanas de UI conhecidas e último statusHTTP da leitura. Não publica textoDOM/HTML/valores/errosbrutos/URLs/payloads/credenciais. Sem novo retry, timeout, mock, bypass ou mudança de produto. Falha na coleta registra apenas indisponibilidade, preservando FAIL e cleanup. RED11PASS/1FAIL por sanitizador ausente; GREEN12/12 protocolo e42/42 suíteNode. Próxima prova deve identificar etapa exata; corrigir somente após causa demonstrada. V1/CRUDglobal não certificados; outros14domínios, upload/worker, WCAG manual e retrospectiva continuam pendentes. ZIP mestre e doisDOCX recuperados nesta execução e trêsSHA256 conferidos com índice, prompt75 literal lido.

### ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual N/A: somente diagnóstico do harness. Marca e produto frontend preservados. Ferramentas diretas e fontes existentes, sem BUILD Lovable. Evidências anteriores preservadas; nenhum segredo, DDL/RLS/Edge/Authconfig ou PROD alterado.

Revisão independente do diagnóstico: sem Critical/Important. Limites minor: últimoHTTP é compartilhado entre páginas, não prova correlação com ação; diagnósticoPage pode ficar na segunda aba nas etapas posteriores; teste deHTTP inválido falha antes na ausência de flags. Não usar essas informações como prova de causa, conformidade ou PASS. Alvo imediato pós-descarte ocorre antes da segunda aba. Mantidos para evitar expansão do diagnóstico além da falha observada.


## Causa do timeout confirmada e correção restrita ao teste

O PR #125 foi integrado em `01cde2e96e2fc98d601f9c9dfc865f05af4629b8` após quatro checks SUCCESS no HEAD `773bca8e53986ea730a198f0a9b35cfecec309cd`. O PR #126 foi encerrado como duplicado de uma execução concorrente, preservando o delta e a revisão para consulta; não houve merge duplo.

A prova de diagnóstico `42400417695`, job `128486778827`, falhou precisamente em `LIST_STATE_INACTIVE_FILL`. A leitura retornou 200; botão de situação presente; loading, denied, inconsistent, transient e pending falsos. Artefato `13585232937`, SHA-256 `fd3e7af52d01c55dfd0201b0d057da958631328d470b7f4d176afb3fb18c5fe0`. Quarentena de quatro usuários e três organizações verificada. Não há PASS do lote.

Causa reproduzida com o código oficial da versão exata Playwright 1.64.1, `packages/injected/src/selectorUtils.ts` e engine `internal:label` em `injectedScript.ts`: `getElementLabels` usa o texto de todo o label, incluindo opções do select envolvido. O rótulo normalizado é `SituaçãoAtivaInativa`; `getByLabel('Situação', {exact:true})` não corresponde. Reprodução local com `elementText` oficial e DOM sintético confirmou a divergência, correlacionada com a subetapa real e ausência de erro de leitura/autorização.

Correção: selecionar o combobox único do formulário que contém o heading `Alterar situação`. Nenhum rótulo, produto, permissão, estado de backend ou timeout foi modificado. O preflight público em Chromium real agora usa DOM sintético com um filtro externo: comprova a divergência do seletor antigo, seleciona inativa/ativa no formulário correto e exige que o filtro externo permaneça intacto. Não acessa HML ou cria fixture Auth nesse teste de seletor.

RED observado: 12 PASS/1 FAIL por helper ausente. GREEN local: protocolo 13/13 e suíte 43/43. CI e nova prova HML ainda pendentes. A aprovação do preflight não substitui persistência SQL, CAS, isolamento, capturas ou limpeza do lote completo. Fontes oficiais consultadas: https://github.com/microsoft/playwright/blob/v1.64.1/packages/injected/src/selectorUtils.ts e https://github.com/microsoft/playwright/blob/v1.64.1/packages/injected/src/injectedScript.ts.


## Reteste do seletor127: transições confirmadas, espera entre abas ainda sem causa

PR127 integrado b66f4af1e555d14c03a28c08e7369616bf4820e9,HEAD8533f2acae1320f24f0753f60795b07f700ae4b5 eguard/restore/backup/probeSUCCESS. Mainrestore42401072142SUCCESS. Reteste42401271563/job128489348141 FAIL depoisLIST_STATE_INACTIVE eLIST_STATE_ACTIVE HTTP200/recibosPASS. Correçãodoseletor comprovada nessasduasoperações; nenhumPASSdelote. TimeoutError aindaestágioLIST_STATE_ACTIVE significaespera antesLIST_CONCURRENT_EDIT_OPEN, porqueaberturasegundaaba/gerência/primeiroformulário não tinhamfaseprópria. Não presumircausa dehidratação nemproduto.

Artefato13585512801 SHA256f6c5ac3b691d0c0692a002cd1b5c3c6721fd4490a10d34433741f409f3209fde, ZIPbaixado/hashconferido; relatórioslidos. Quarentena4contas/3organizaçõesVERIFICADA. Próximodiagnósticominimal adicionafasesconstantes emcriar/navegar/abrirgestãosegundaaba eabrir/preencherediçãoprimeiraaba; apontapáginaemdiagnóstico corretamente econfirma regiãovisível apósclick, semretryoumudançatimeout. Usa somente mecanismo de estágios/flags játestados, semnovo formato/coleçãodeconteúdo. PLAN120/GATE121 preservados. Próxima éprovaHMLdiagnóstica, nãocorreçãoespeculativa.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: impactoN/A,somenteharness;semproduto/tipos/schema/RLS/Authconfig/PROD; ferramentasdiretas,fontesválidas epublicaçãoúnica apósreconsultarfila paraevitarduplicação entreexecuções.


## Seletor aprovado em HML; contexto da segunda aba corrigido

PR #127 integrado em `b66f4af1e555d14c03a28c08e7369616bf4820e9` após guard, restore, backup e probe SUCCESS no HEAD `8533f2acae1320f24f0753f60795b07f700ae4b5`. O probe real confirmou ambas as situações e preservação do filtro externo.

Run `42401271563`, job `128489348141`: LIST_STATE_INACTIVE e LIST_STATE_ACTIVE retornaram HTTP 200 com recibos válidos, confirmando a correção específica. O lote ainda falhou por TimeoutError antes da edição concorrente. Artefato `13585512801`, SHA-256 `f6c5ac3b691d0c0692a002cd1b5c3c6721fd4490a10d34433741f409f3209fde`; quarentena de quatro usuários e três organizações verificada; nenhum erro de runtime.

Setup identificado: `context.newPage()` cria aba sem preferência organizacional no sessionStorage. A rota RegrasContrato consulta a preferência e redireciona para `/selecionar-organizacao` quando ausente. O teste tentava abrir a gestão antes de selecionar organização na nova aba. A segunda aba agora seleciona a mesma organização própria pela UI antes de abrir o contrato; subetapas ORG, OPEN e ORIGINAL_DRAFT explicitam as esperas. Não copia token, não injeta preferência, não altera ator, autorização ou timeout.

O preflight público real adiciona um marcador sintético sem credenciais no sessionStorage da primeira página e confirma sua ausência na aba nova do mesmo contexto/origem. Esse teste prova a premissa do setup; não simula sessão ou organização. A HML anterior é o RED operacional e permanece FAIL do lote. Protocolo local 13/13 e suíte 43/43 preservados; nova CI/HML necessárias para GREEN operacional e confirmação de CAS/persistência/isolamento/capturas.


Consolidação no PR #129: preservadas todas as subetapas e a confirmação de região do diagnóstico original. Acrescentados apenas seleção organizacional por UI, prova pública de isolamento de sessionStorage e registro no manifesto. Não foram publicados PRs duplicados desta correção. Todos os checks devem ser conferidos no novo HEAD.


## PASS funcional do lote CADASTROS_LISTAS e limite visual

A execução `42402246765`, job `128492370077`, terminou SUCCESS no backend `a0337932872402b12a5378040f18feb2161bc723`, frontend `74cd8ef9aa15bd19d33ce1b5d2dc6515f6066db8`. Relatório do navegador: 76/76 verificações. Relatório Python/SQL/HTTP: 37/37. Confirmados comandos e persistência de cadastros/listas, itens e versões, auditoria/idempotência, conflito real HTTP 409 entre abas, rascunho preservado sem escrita durante falha de leitura, recuperação HTTP 200, leitor sem mutações, tenant B sem dados A e zero erros de runtime. Quarentena independente confirmada: quatro usuários e três organizações próprias. Não há aprovação dos 14 domínios restantes ou certificação V1.

Artefato `13584889991`, SHA-256 `00fddbbdf18d76f4bc55c4e5fea8712973b92fa1fd375e151b9c6c19e1095110`. ZIP baixado e hash verificado, relatórios lidos. O PASS é restrito às jornadas efetivamente executadas; não substitui todos os critérios V1, WCAG manual ou upload/worker.

A revisão independente abriu as oito capturas e rejeitou quatro: 1440 claro/escuro e 1280 claro ainda mostram envio em andamento; 1280 escuro está estável, mas corta o início do painel. 768 e390, ambos os temas, foram aceitos somente para o painel; marca/cabeçalho mobile ficaram fora do enquadramento. Important: captura sem estabilização e rolagem normalizada. Minor: Menu flutuante cobre texto do cartão inferior no mobile; token sintético longo quebra de forma pouco elegante em768. Nenhum Critical. Gate visual não aprovado.

Correção exclusiva do harness: aguardar nome atualizado, botão de edição habilitado e ausência de envio; aguardar transições finitas reais; capturar topo da página e início do painel separadamente em cada combinação (16 imagens). Verificar foco/Tab entre ações e axe4.14.0 com tags AA aplicáveis, preservando regras incompletas. Relatório retém apenas id/impacto/contagem, sem DOM, HTML ou seletores. O preflight público usa estado sintético que muda de ocupado/obsoleto para atualizado/habilitado e comprova a espera.

RED local: 13 PASS/2 FAIL por predicates ausentes. GREEN: protocolo15/15, suíte45/45; revisão independente sem Critical/Important no delta. Nova execução ainda necessária para aceitar imagens. Contraste avaliado em estado estável não fecha a ocorrência transitória V117 anterior; WCAG manual continua pendente. O status HTTP do conflito agora registra o valor real também no caminho de falha, preservando a exigência 409 e evitando metadado constante incorreto.
