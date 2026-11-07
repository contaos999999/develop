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
