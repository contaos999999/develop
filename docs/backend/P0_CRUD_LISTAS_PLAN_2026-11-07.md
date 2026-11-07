# P0 CRUD global — listas de verificação V1
Data07/11/2026UTC. HMLgklhhhyosgasnyoxlrui, PRODproibido. Autorização expressa do titular: executar CRUDglobal integralmente, sem parar. PLAN/GATE desta tarefa precede qualquer BUILD.

## Fonte e lacuna
V1-CHK-001..004 (08A/catálogo canônico): lista configurável, norma de origem, versão/vigência, obrigatoriedade condicional e critérios poritem. Fonte/frontendPROMPT30 registra versões sóleitura porfaltaRPC. RegrasContrato/regrasDados sóconsultam3tabelas e aprovam regra preventiva. MetadadosHML: listas_verificacao cabeçalho comversao_registro, versoes_lista semversãoconcorrência (rascunho/publicada/substituida), itens_lista semversãoconcorrência. Publicado ainda tem DMLdireto em listas/itens porRLS; versoes_lista éSELECT-only. Não presumir CRUD pelo grant. Competência copia snapshot de itens das versões publicadas cuja vigência intersecta período. Atual touchheader incrementa duasvezes junto ao controlar_versao_registro.
Migration vazia gerada pelaCLIreal2.81.3: supabase/migrations/20261107001620_p0_crud_listas_verificacao.sql. SemDDL remoto ouarquivo aplicado reescrito.

## Interfaces fechadas
1. public.obter_lista_operacional_v1(p_id_organizacao uuid,p_id_contrato uuid,p_id_lista uuid defaultnull,p_id_versao uuid defaultnull,p_pagina_versoes integer default0,p_pagina_itens integer default0)→jsonb.
2. public.executar_comando_lista_v1(p_id_organizacao uuid,p_id_contrato uuid,p_id_lista uuid,p_versao_esperada bigint,p_acao text,p_payload jsonb,p_motivo text,p_request_id uuid)→jsonb. Idlista/versãoesperada nulos SOMENTE criar_lista. Ação fechada, payload porallowlist, nenhum SQLdinâmico/tabela/parâmetroidentidade/perfil fornecido pelo cliente.
Wrappers INVOKER/search_pathvazio/authenticated-only. Implementações SD sóprivado. Setefunções novas: duas públicas eprivado.crud_lista_autorizar_v1,crud_lista_consultar_v1,crud_lista_mutar_v1,crud_lista_integridade_v1,crud_lista_validar_regra_v1. Grantauthenticated apenas consultar/mutar necessários aos wrappers. Helpers e trigger não expostos.
Getter schema_versao crud-lista-v1: contexto,headerouNULL,açõespermitidas calculadas no backend, versões/itens paginados25 comtotal, versão selecionada, exclusão deheader/versãopublicadafalse e motivo. p_id_versao semlista oualvo deoutra lista/org/contrato nega. Semlistas novas no getter, cabeçalhos já têmSELECTpaginado existente.
Mutação retorna esquema/ação/contexto,headercomversãonova,idversão/item quando aplicável,request_id/evento_id. Recibo pode ser histórico emreplay: UI posterior deve reconciliar leitura atual e não regredir cache.

## Autoridade e ações
Sessão ativa, org/contrato exatos, acesso canônico, RBAClistas e papel emcada chamada/replay. Escrita apenasorgativa econtratorascunho/ativo. Criar/editar: papeladministrador/gestor_contrato/prestacao_contas/juridico_conformidade ouMASTER, alémRBAC. Publicar/encerrarvigência: RBAClistas/editar E papelrealadministrador/direcao_aprovador; MASTER não herda aprovação especializada. Alterarsituação header: administrador ouMASTER+listas/editar.
- criar_lista: nome/descrição e vigênciainicial, criaheader+versão1rascunho; header.versao_atual0 atépublicação.
- editar_lista: só nome/descrição.
- criar_versao: id_versao_origem opcional da mesmalista para copiar itens; vigência. Uma versão rascunho aberta porlista, número max+1 semreuso; manterversão publicadaanterior.
- editar_vigencia_rascunho: id_versao,início/fim; apenasrascunho.
- salvar_item: id_versao,id_item nulo/criação ouexistente/edição; codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,id_fonte_versao,regra_validacao,ordem. Subentidades sempre mesmolista/contrato/org. Nova criação exigecriar; edição exigeeditar.
- remover_item: id_versao/id_item, apenasrascunho nunca referenciado emrequisitos/snapshots. Exclusão real permitida apenas doitemdeRASCUNHO, comversão/motivo/auditoria; não excluircabeçalho/versõespublicadas/eventos.
- publicar_versao: apenasrascunho cominício explícito, fim>=início, pelo menosumitem e fonteaprovada/aplicável/vigente para itensmateriais(obr/impeditivo/regra) aplicáveis. RegraJSON objetolimitado64KiB; validar estruturas nativas documento.obrigatorio/tipos econdicao/tipos realmente aceitos poravaliar_condicao_requisito, não aceitar tipo desconhecido que cairia emtrue. Não inventarDSL ouprocessamento automático cliente.
- encerrar_vigencia: sóversãopublicada ainda semfim, papeldeaprovação,motivo, fim>=início e>=maiorperiodo_fim das competências que jáusamversão. Permite criar intervalos semsobreposição sem reescrever itens/apagar snapshots; alteração temporal auditada. Fechamento apenasuma vez neste delta. Vigência retroativa que conflite comsnapshot énegada, não alterar snapshot emsilêncio.
- alterar_situacao: ativa/inativa; ativa requer ao menosversãopublicada, não reabrirversões descartadas; publicação podeativarheader. Lista inativa preserva consulta/gestão autorizada.
- descartar_rascunho: marca versão não usada como substituida, semaprovado_em; preservaitens/história, UI rotula descartada. Não inventaenum.
Publicações da mesmalista não podemter vigências sobrepostas. Versãoantiga publicada comfimNULL deveprimeiroencerrarvigência sobaprovação e dependências. Versões antigas continuam publicadas comintervalo fechado para competênciasretroativas usaremversãocorreta; não marcar todasassubstituídas/removerpassado. Header.versao_atual significaúltimanumeropublicado,nãoregra vigentehoje. Semcalcularportãono cliente.

## Transação, concorrência e integridade
Versãoconcorrência doHEADERéagregado de todoscomandos, pois filhasnão têmversãoprópria. Lockorgcompartilhado→contratoexclusivo→advisoryorg/ação/request→header FORUPDATE. Autorizar novamente apósespera antes de replay e escrita. Para criar header, advisoryantes da criação e receipt armazenaUUIDgerado. Incrementoheader exatamente1 porcomando, semduplicadotouch. Versões/items publicados imutáveis salvo fimtemporal autorizado acima.
Reusarcomandos_idempotentes namespacefechado,hash ator/org/contrato/alvo/versão/ação/payload/motivo,UUID e replayexato;409 porreuse diferente, semduplicaraudit/versões/itens. Mudanças eauditoria atômicas; negativas semefeitos. Campo protegido/JSONtipo errado/ação desconhecida→422.
Novo guardDML dos3cadastros nega INSERT/UPDATE/DELETE authenticated direto que contorne API, sem relaxar RLS/grants. Owner/SDprocessos legítimos mantidos. Touchheader dedicado sótimestamp; preservar controlar_versao_registro.
Alteração mínima emprivado.criar_competencia(uuid,date,date,date,date): adquirir locks orgcompartilhado→contratocompartilhado antes dos inserts/snapshot, compatíveis com ordemacima; preservarassinatura,role/RBAC e todasas regrasexistentes. Assimpublicar/encerrarvigência e criarcompetência serializam; não fecharvigência ignorando competência concorrente. Teste obrigatório emduasconexões +JWTHTTP.

## Escopo fechado
- docs/backend/P0_CRUD_LISTAS_PLAN_2026-11-07.md
- docs/backend/P0_CRUD_LISTAS_RESULTADO_2026-11-07.md
- docs/tasks/active-task.json
- supabase/migrations/20261107001620_p0_crud_listas_verificacao.sql
- supabase/tests/p0_crud_listas.sql
- supabase/tests/p0_crud_listas_concurrency.py
- supabase/tests/p0_crud_listas_jwt.py
- supabase/tests/p0_crud_listas_catalog_expected.json
- supabase/tests/history_catalog_compare.py
- .github/workflows/restore-isolado.yml
- .github/workflows/p0-crud-listas-hml.yml
- .github/workflows/p0-crud-cadastros-hml.yml
Workflowantigocadastros: arquivar automático noSHAjácomprovadobfd741d para que não tente redeploy doalvoaplicado emtodo restore futuro; semalterarmigration/receitas. Novo orquestradorlistas clona padrão jávalidado deSHA/hash/guard/restore, ambienteHML,check:read,actions:write apenasdispatch, diretórioprivado viaRUNNER_TEMP naetapa. Dispara canônico existente comdeploy_one+versão+SHA/hash; umaúnicapendente eparidadecompleta. Semoutros caminhos/tabelasnovas/RLS/Edge/Storage/configAuth/frontend/PROD. Authapenasfixturespróprias.

## Gates e prova
PLANguardSUCCESS+merge antesRED/BUILD. RED real porausênciadas2APIs e proteções depublicada. SuíteSQLrollback declara claimssimuladas, nãoJWT. Cobrir CRUDdraft/itens, todosestados, concorrênciaheader, papéis/sessão/MASTERsemherançaaprovação, fontes/aplicabilidade, campos/tenant, vigências/sobreposição/fechamentodependências, snapshotsanterioresimutáveis, idempotência e DMLdireto negado. Suíte deconcorrência local emduasconexões; preservar todas14suítesanteriores e restoreduasinstâncias. Catálogo histórico admite SOMENTEregistros exatos das7funções novas e mantém9cadastros; nenhuma exclusão genérica de nomes.
Após CI/revisão e merge, canônico aplica apenasmigrationtestada e comprova127+1 versõesparitárias. JWTreal comusuários/orgs/listas/fontes próprios, MASTER/admin/leitor/restrito, HTTPconcorrente e snapshotvigente/retroativo; preservar matrizglobal. Quarentena: banircontas/revogarsessões/MASTER/vínculos e inativarorgs, sem apagareventos/versões. Manifestos sanitizados comIDs antes do seed, tokens/password sóRUNNER_TEMP, segunda tentativa cleanupsempre, artefatos semsecrets. Advisorantes/depois.
Frontend posterior sóapós APIs reaisverificadas, PLAN fechado inline RegrasContrato, semrota/tipos; configuração, nova versão/itens/remoçãodraft/aprovação/encerramentovigência/inativação comcapacidades e requestUUID. Não anteciparcertificação V1/global.
Rollback corretivo pornovamigration ourevogaçãodasnovasAPIsporincidente, nunca reescreverarquivomigrado/apagarsnapshots. Fontes normativas25/catálogo permanecemimutáveis.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Backendapenas, semassets/temas/fontes/rotaUI. GitHub+Supabase diretos, semBUILD Lovable. Economia não substitui testereal, segurança ouCI. Aprovado para execução pelo pedido global expresso; não pedir outra confirmação rotineira.
