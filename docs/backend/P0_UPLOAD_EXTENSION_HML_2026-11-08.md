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

### BUILD do wrapper

GATE149 integrado7406e9c187ddb9c788e0b80258d470ec5451ce50, guard42450959313SUCCESS e revisão independente sem Critical/Important. RED operacional42501privado/atributo públicoINVOKER e NodeausênciamigrationFAIL. Nova migration contém somente ALTER exato de atributo. Acceptance acrescenta catálogo/corpos/ACLs/owner/search_path, quatro chamadas reais negadas pela mensagemRBAC exata (sem sessão, sessão inexistente, tenantB→A e leitor) e comparação de cinco tabelas sem sideeffects. Não confundir recusaACL em inglês com controle material. Corpo público MD576a15744ab7c8e4e2fb11f3e6477e661 e privado4bd3d0edebe2522b9ced4e1d6c482e9d congelados antes; wrappers e privados não são reescritos. CI/restore/aplicação/positivo material pendentes.

### GATE complementar: comparação histórica exata

BUILD150 HEADd8d368aceb513ae80c3c86dd0976e7c40905c223: guard42451142642 e histórico42451142764SUCCESS; restore42451142640/reconstrução128640429218FAIL em HISTORY_CATALOG após sete/seteUPLOAD_WRAPPER SQLPASS, incluindo quatro negativas reais e cinco tabelas semefeitos. O catálogo histórico espera wrapperdefinerfalse; mudançaaprovada149 exige true. Nenhum merge/aplicação150 liberado por testeparcial.

Complemento fechado permite acrescentar somente supabase/tests/history_catalog_compare.py ao BUILD150 após esteGATE integrado; manter oscinco caminhosanteriores e produtoALTERúnico. O comparador deve exigir exatamenteum registroanterior e umregistroaprovado comtodososcampos: schemapublic, nomecriar_documento_contrato_completo, assinatura9argsnominaisexata, configsearch_pathvazio, auth_exec=true, anon_exec=false, defineranteriorfalse/aprovadotrue. Substituir somente oregistro esperado emcópia pela nova tupla, manterreal intacto e comparar todososdemaisobjetos/campos. Não editar baselinehistórico, não excluirnome/schemagenérico, não relaxarACL/hash/owner/RBAC, não removerpassos/negativas.

TDD em testeupload_document_wrapper existente: helperPython real extraído viaAST sem iniciarDB devefalharantesdeexistir; depois aceitar somente deltaexato e rejeitar campo divergente, registroausente ouduplicado. TestsSQLdeowner/corpos/ACLs/RBAC mantidos. Nodecompleto/guards/revisão e novoCI/restore/backupmesmoHEAD antesmerge/deploycontrolado/retesteUI. Falha históricapreservada; não redigirsucessoglobal. ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visualN/A, semLovable, ajusteexato deexpectativacanônica aprovada e semignorar diffs.

Complemento151 integradoff090938de5a2cd7d8dec856e965a49f2db2ce09 após guard42451366023SUCCESS e revisão semCritical/Important. Reancoragem normal preserva osdoispais d8d368+ff090, semforce. TDDNode RED helperausente1PASS/1FAIL; helpernovo exige tuplasinteirasúnicas, retorna cópiadaexpectativa e deixaoriginal/real intactos. Negativosde7campos,ausências,duplicidades eobjetoestrangeiro preservado. Mudançadeprodutocontinua oúnicoALTER, seteSQLpassaramnoHEADanterior mas novoCIinteiro obrigatóriopendente.

## Checkpoint final comprovado: upload autenticado concluído

Em 08/11/2026, às 05:41:35 UTC, a chamada autenticada `criar_documento_contrato_completo` retornou HTTP 200. A interface exibiu “Concluído” e “Envio concluído. O processamento segue em segundo plano.” O documento permaneceu na lista após recarregar, e o detalhe apresentou a versão 1 e a cadeia de evidência.

### Código, testes e implantação

- PR #150 integrado em `cb074f501b8b0d527bda3c0840248e4e8c589d56`; HEAD testado `46a7b821a4e06cf5b5162513c82e3afc5d9b93a2` é ancestral integrado da main, com migration idêntica ao merge.
- Guard `42451502833`, histórico `42451502812` e restore `42451502838` aprovados. Jobs de reconstrução `128641498974` e backup `128641498745` SUCCESS. Logs confirmam sete testes UPLOAD_WRAPPER aprovados e HISTORY_CATALOG_PASS.
- Suíte Node completa: **322/322 PASS**, zero skips. Revisão independente final sem Critical/Important; quatro arquivos do delta conferidos contra os blobs remotos.
- Deploy controlado `42451722019`, job `128642176181`, SUCCESS. O workflow existente conferiu fonte, hash, manifesto e checks, aplicou exatamente uma migration pela CLI e confirmou paridade global de versões.
- Migration `20261108054500_fix_document_upload_wrapper.sql`, SHA-256 `5798d972d1592b48c25139e7e489e900831af8fe3ce74c9057b1da7fadbb0f5d`.

O catálogo HML posterior confirma wrapper público DEFINER, owner postgres, search_path vazio, EXECUTE anon=false/authenticated=true. A função privada permanece DEFINER, owner postgres, search_path vazio e EXECUTE anon=false/authenticated=false. Corpos e ACLs foram preservados: MD5 público `76a15744ab7c8e4e2fb11f3e6477e661`, privado `4bd3d0edebe2522b9ced4e1d6c482e9d`.

### Evidência material autenticada

Organização **ContaOS HML Teste**, contrato **AUD-A-VERCEL-20261108**, origem `https://contaos-41-hml.vercel.app`. A ação “Tentar novamente” retomou a criação com o mesmo arquivo já confirmado. Não houve novo envio ao Storage nem duplicação da confirmação. Nenhum JWT ou cookie foi extraído; nenhum backend foi simulado.

| Registro | Identificador |
| --- | --- |
| Contrato | `be89ef7e-d839-46c0-9cfb-4da81edf8b74` |
| Arquivo | `8cc6ac08-7f5b-469c-ab50-7b33d5a12379` |
| Documento | `525e54fc-feec-4dc0-b540-1510a3c52485` |
| Versão 1 | `2ea42a44-db27-4c4e-801f-9fc5227c2458` |

Consultas somente de leitura confirmaram **1 objeto, 1 arquivo, 1 documento e 1 versão** próprios. O detalhe mostrou documento ativo, tipo Lista de verificação, arquivo TXT, MIME text/plain e 285 bytes. SHA-256 do TXT local, do arquivo e da versão iguais: `773eb577ba88a260247803d37dced4f5469e8c39347dd3fe7c58c4d9f4681103`.

Capturas e DOM foram preservados nesta execução. Os recibos abaixo não afirmam que os PNGs foram incorporados ao Git:

| Captura | SHA-256 |
| --- | --- |
| `upload-persistido-lista.png` | `14f53826dcbbf55e393688fdeb8cf190dfd717ac740890e2af87d704fa9541e1` |
| `upload-persistido-detalhe.png` | `be6469db13284e05b2a6601d15ee59460083cbaa1f40d23ab5267116a9b9657a` |

[Detalhe autenticado do documento](https://contaos-41-hml.vercel.app/contratos/be89ef7e-d839-46c0-9cfb-4da81edf8b74/documentos/525e54fc-feec-4dc0-b540-1510a3c52485).

### Planejamento da continuidade

**Última etapa concluída:** upload TXT autenticado, confirmação, registro documental, persistência após recarregar e detalhe com cadeia de evidência. Não repetir PRs #145, #147 e #150 nem reimplementar CORS, extração da extensão ou delegação. Estas fixtures não pertencem ao runner #148 e não devem ser eliminadas por limpeza de outro executor. O manifesto fecha novas alterações de banco neste checkpoint.

**Próximas pendências:** processamento e worker reais, verificação de segurança, demais formatos e limites, retomada, novas versões, CRUD e matriz visual/acessibilidade da Trilha A, mediante os respectivos PLAN/GATE. O PR #148 é uma frente independente e não recebe certificação por esta prova.

O arquivo permanece com `status_seguranca=pendente`; processamento **Na fila**, tentativas **0**. Nenhum download foi liberado artificialmente. A prova não certifica V1, matriz 232/72 ou CRUD global. PROD permanece intacto.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: correção de backend com impacto visual N/A; prova material na interface existente, sem novo turno Lovable e sem reduzir guards, RBAC, RLS ou JWT.
