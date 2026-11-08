# Upload HML: PLAN/GATE da extração de extensão, 08/11/2026

Escopo autorizado pelo titular: resolver upload autenticado no HML, com preservação de evidências. Base b8003019fe937c8dad436fae3a0334aee23f2453. V1 continua NO-GO global; nenhuma promoção PROD.

## Evidência e causa

PR145 integrado após Node319/319, guard42449646955 e restore42449952690 (reconstrução e backup SUCCESS). Deploy HML upload8/download6 JWTtrue; fontes exatos do merge. SHA256 upload f1653f2de4e7300f3e75c3427819c721a6453bfdd6f83f41af9475c33774f97c, download538f3a014316e05f44ecd47f113080ee6ab00a2aaad1b2cf3bf6c76b7c1cda9a. OPTIONS Vercel204/ACAOexato; origem maliciosa403/semACAO; POSTsemJWT401 gateway. Gateway emite ACAO* na própria recusa401, sem alteração nossa.

Reteste autenticado 05:17UTC, contrato sintético be89ef7e-d839-46c0-9cfb-4da81edf8b74: assinatura200, objeto recebido no Storage, confirmar_upload_arquivo400/P0001. Log PostgreSQL linha25: Este formato de arquivo não é aceito pelo ContaOS. Configuração aceita txt/text/plain. Consulta sem mutação reproduziu extração atual como nome completo, em vez de txt. Expressão regexp tem escape excessivo; histórico permanece intacto.

## BUILD fechado

Somente nova migration 20261108053000_fix_upload_extension_extraction.sql substitui a expressão de extração por ponto literal em classe [.] na função privado.confirmar_upload_arquivo, preservando corpo restante, assinatura, SECURITY DEFINER/search_path, RBAC, sessão, organização/contrato, path, MIME/extensão, limites, SHA256, metadados reais, inserção, auditoria e grants. Não reescrever migrations antigas. Nenhuma alteração Edge/Auth/Storage/RLS/frontend/workflow/SDK/segredo/PROD. Manifesto mantém histórico e abre os cinco caminhos declarados apenas no BUILD separado após integração deste GATE.

## Provas e execução

TDD SQL real em transação descartável: extrair a expressão da função instalada e avaliar nomes TXT/PDF/múltiplos pontos/maiúsculas; rejeitar extensão ausente, executável e sufixo enganoso conforme configuração. Regressão Node compara corpo novo com baseline permitindo somente a linha de extração. Preservar testes atuais e acrescentar SQL em hml_acceptance antes do relatório, executado pelo restore existente. RED antes da migration; GREEN após ela, suíte Node completa, contexto/arquitetura/ZeroDrift/security, guard e restore/reconstrução/backup no mesmoHEAD, revisão independente sem Critical/Important, merge normal. Aplicar somente migration integrada ao projeto gklhhhyosgasnyoxlrui e conferir corpo/grants. Repetir exatamente o TXT já enviado pela UI, sem duplicar Storage, JWT ou sessão exportados, e comprovar persistência/listagem/detalhe.

Rollback por nova migration/PR restaurando a definição anterior da função, sem apagar evidências/objetos ou reescrever histórico. A correção não amplia formatos aceitos nem autoriza limpar dados. Qualquer falha mantém NÃO CONCLUÍDO e exige diagnóstico. Não alegar cobertura232/72, CRUDintegral ou certificaçãoV1 a partir deste caso.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visual N/A, função backend existente; sem turno Lovable; menor delta funcional com testes reais, sem reduzir segurança ou governança.

## BUILD e RED

GATE146 integrado b432417ac3e9f17d8f75803443f343c84517b8ec, guard42450339687SUCCESS, revisão independente sem Critical/Important. RED SQL real por pattern extraído da função instalada: TXT/PDF/DOCX retornam nome completo, três assertions falsas. RED Node acusa ausência da migration. Migration nova troca somente v_ext por lower(coalesce(substring(p_nome_original from '[.]([^.]*)$'),'')); sem extensão produz vazio e mantém recusa. Acceptance SQL avalia a expressão da própria função instalada em onze casos e mantém MIME divergente negado. CI/restore/reteste material ainda pendentes.

## Checkpoint e PLAN/GATE: entrada documental pública, 08/11/2026

PR147 HEAD5297f1316b4a8d1fbfaeff0330f195da3300cdf8 integrado ff4e0d83d2d8010d08753b8f0460044b11e813b3 após guard42450525815, histórico42450525821, restore42450525816/reconstrução128638548603/backup128638548777SUCCESS e revisão independente sem Critical/Important. Node320/320;12/12UPLOAD_EXT SQLPASS. Deploy controlado existente42450754658/job128639258712SUCCESS aplicou exatamente20261108053000, fonte/hash/checks/paridadePASS. Corpo privado MD5a0c3d54699ca5ac54e0caf718b7426d1, ACLs/search_path/wrapper preservados.

Última etapa material comprovada: reteste UI do mesmo objeto,05:26:29UTC confirmar_upload_arquivo200 e arquivo8cc6ac08-7f5b-469c-ab50-7b33d5a12379 persistido,285bytes/text/plain/status_seguranca pendente. Etapa seguinte criar_documento_contrato_completo403/42501: permission denied for function criar_documento_contrato_v111, confirmado por log PostgreSQL,05:26:30UTC. Não há documento criado nem certificação integral. CORS e extração resolvidos não precisam ser repetidos/reimplementados.

Causa: wrapper público SQL SECURITY INVOKER, EXECUTEauthenticated e nãoanon, chama privado.criar_documento_contrato_v111 SECURITY DEFINER com EXECUTE apenaspostgres. Padrão dos wrappers V115 já registrado em P0_V1_RBAC_JWT_EDGE_RESULTADO_2026-11-06 mantém privados fechados e entrada pública DEFINER com autorização no corpo privado. Arquitetura§4 não permite usar DEFINER para contornar autorização; por isso não conceder acesso direto à privada nem alterar RBAC.

BUILD separado permitido somente após este GATE integrado: nova migration20261108054500_fix_document_upload_wrapper.sql com ALTER FUNCTION public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text) SECURITY DEFINER. Uma alteração de atributo, sem trocar corpo, assinatura, ownerpostgres,search_pathvazio ougrants. Privada continua fechada a authenticated/anon e preserva exigir_permissao_rbac(documentos_contrato,criar,contrato), sessãoativa, tenant, contrato, perfis, idempotência, fonte/versão e auditoria. Não alterar outrasfunções, RLS, tabelas, Auth, Storage, segurança doarquivo,frontend,SDK,workflow,PROD oumigrationsantigas.

TDD: REDSQL catálogo wrapperinvoker e chamadaauthenticated semsessão falha naACLprivada em vez de chegar à negaçãoRBAC; GREEN após migration deve chegar à negaçãoRBAC exata, nunca criarregistro. Acceptance no banco isolado deve provar wrapperDEFINER/search_path/owner, públicosanonnegados, privadaauthenticated/anonnegados, ausência desessão e tenant/perfilnãoautorizados negados semefeitos, preservandocorpos/ACLs. RegressãoNode limita migration a umALTER exato. Suítecompleta, Context/Architecture/ZeroDrift/security, guard+restore/reconstrução/backup no mesmoHEAD, revisãoindependente, merge e deploy_one do workflow jáexistente com fonte/hash/versionfixos e paridade. RetesteUI usando MESMOarquivo jáconfirmado, semnovoStorage/confirmarduplicado, deve registrar umdocumento/versão e aparecer apósrecarregar/listagem/detalhe. Segurança permanecependente atéworkerreal, semliberar download/análise artificialmente.

Rollback via nova migration/PR ALTER da mesmafunção SECURITY INVOKER, sem revogarouampliargrants. Falha em qualquer prova mantém NÃO CONCLUÍDO. Esta correção não transforma presença detextoRBAC em certificação de todos osperfis/232/72/V1; demais pendências continuam. ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visualN/A, menoratributopossível naentrada existente, semLovable, sematalho deautorização e semPROD.
