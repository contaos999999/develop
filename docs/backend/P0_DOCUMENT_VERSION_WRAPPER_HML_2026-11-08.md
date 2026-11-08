# Delegação da nova versão documental: plano e GATE

**Objetivo:** corrigir a RPC pública de nova versão sem abrir execução direta da rotina privada.

**Arquitetura:** manter frontend, Auth/sessão, RBAC/tenant, RPCs e duas Edges existentes. A entrada pública deve executar como seu owner e a rotina privada mantém todas as verificações do usuário real. PostgreSQL/Supabase, migration aditiva CLI2.81.3, testes Node e Restore SQL real.

**Especificação:** continuidade autorizada Trilha B/GATE138, padrão de delegação já aplicado150 e prova material148 no HEADce30d485518b2b077575fc967746ea2000a9da92.

## Evidência e limite

Run42479943135/job128729514650FAILURE. Artifact13616839267/SHA2561119397b14c337aacf5add6bf011f256c113a7f006ef1d97d4a85fa49196e9b9 baixado e conferido. PublicadoTXT1 PASS_SMOKE comworker/download/GETintegridade e114módulos com SHA dos bytes carregados/fencefailedfalse; frontend_headnull/paridadeNAO_VERIFICADA. LocalTXT1 concluiu; TXT2assinatura/storage/confirmação200, registro403. PDFnãoexecutado, sem5/3/5PASS. Quarentena4users/2org/3uploadspreservados/0jobsativos; SQLreadonly próprio confirmou Authbantrue/3files/0active. Não reutilizar esse nonce949b267631c24181b8edb34b8563f9fa nem fixtures152/160 alheias.

Catálogo real: public.adicionar_versao_documento_contrato(uuid,uuid,text,text) INVOKER,ownerpostgres/search_pathvazio, ACLpostgres/service_role/authenticatedEXECUTE/anonfalse, corpoMD56d0c5926f4b25fd0e9562b0c010174ef. Chama privado.adicionar_versao_documento_contrato_v110, DEFINER/corpo10698cb96e7de1de5a88b25960b341e5/ACLpostgresapenas. INVOKER não pode executar essa rotina. Ela já exige permissão documentos_contrato/editar, sessão ativa, tenant/contrato/perfil e motivo, preservados integralmente.

## Limites deste GATE

Somente plano/manifesto nesta etapa. Autoriza BUILD subsequente com migrationCLI20261108122815_fix_document_version_wrapper.sql gerada vazia, precondições de corpos/owner/ACL/search_path exatos e uma única alteração de atributo SECURITYDEFINER da assinatura pública. Não alterar corpo, owner, grants, rotina privada, schema, RLS, Edge, frontend317, segredos, Authconfig, plano/cobrança ou PROD. Senha vazada excluída pelo titular. Nenhuma certificaçãoCRUD/V1/V2.

## Implementação e provas

- [ ] RED Node exige a migration aditiva e delta de catálogo exato; não editar migrations aplicadas.
- [ ] Migration transacional recusa drift antes do ALTER exato. Comparação de catálogo aceita somente definerfalse→true da assinatura/config/ACL únicas, mantendo os demais registros visíveis e entradas imutáveis. Casos de campo alterado, ausência e duplicata devem recusar.
- [ ] Aceitação SQL real com sessão autenticada: criação e nova versão positivas próprias; negar semsessão/sessão inválida/leitor/outrotenant e arquivo de outrocontrato, preservando contagens/versões/idempotência. Teste de motivo obrigatório PT400, preservando regras atuais.
- [ ] Preflight material só permite Auth/fixtures quando catálogo confirma esse wrapper pronto e privada fechada; simular metadata ausente/falsa para RED→GREEN antes de Auth.
- [ ] Suíte completa, dez guards, revisão independente, guard/public-probe/Restore/rebuild/backup SUCCESS no MESMO HEAD antes ready/merge normal CAS. Falha nunca vira PASS por remover teste.
- [ ] Deploy canônico deploy_one somente HML, expected_source_sha e SHA256 fixos, uma migration pendente/paridade global. Verificar atributo modificado e corpos/owner/ACL/search_path preservados. Só depois reativar lote novo1publicado+4locais e comprovar5/3/5/recibos/worker/cleanup, sem reutilizar fixture parcial.

Arquivos BUILD são os oito caminhos exatos em version_wrapper_guard.planned_build_paths no manifesto. Neste GATE somente este documento e active-task.json são editáveis. Revisão do escopo e guard obrigatórios antes integração.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visualN/A, backend existente, semLovable/frontend/PROD.


## BUILD após GATE163

GATE163integrado b7ea3d8e6605f5a4636c24ae36731f2efd471e5a,guard42480584324SUCCESS noHEAD2dddafb2da306999f39acafe3dee73547f2adc57,revisãoindependentesemCriticalImportant. EsteBUILDrespeitaoitocaminhos, semalterarmigrationaplicada.

REDsdirigidos confirmados: migrationCLIaindavazia e reconciliador inexistente falharam; prepareREAL recusoumetadataantesdeAuthquandofaltouchavenova. GREEN343/343Node,33casospreAuth (ausente/falso/null/string/númeronuncaTrue),10guards/PythonAST/diffPASS. Catálogopúblico/privadoesperadoantesALTER éfechado,preconditionrecusaqualquerdrift. A únicaalteração produto é atributoSECURITYDEFINER,nenhumcorpoougrant.

Treze casosSQLREAIS acrescidosàaceitaçãotransacional descartável:2metadados,criaçãopública,V2pública,replayidempotente,versão1preservada,6negativos(semsessão/sessãoinválida/outrotenant/leitor/semmotivo/arquivooutrocontratomesmaorg) econtagens6tabelassemefeitos. AguardamRestore remoto,semPASSantecipado. PreflightDOCUMENTOS exige wrapperexatodefiner/body/owner/path e privadafechada antesdequalquerAuth/fixture. SHA256migrationda346e512e0888a61c52a6653e7a99d44fe93da9b765c07df9f5e18ea458e56f.


CI iniciala365f20d:guard42481080884/verify42481080871PASS,backup42481080877PASS,rebuild128732929834FAIL naaceitação.12/13casosVERSION_WRAPPERt;Somentesemsessãof porfixturequeconfiguravaJSONsub/session_idvazios emvezdeausênciaJWT. Corrigida preparação para claims{} conforme demaisnegativoscanônicos, semalterarexpectativa42501. Seisnegativos agoraexibemSQLSTATEreal nosdiagnósticos sanitizados. Nenhumteste retirado,nenhumcodeproduto/migration/hashmodificado;novoHEADexigeCIcompletanovamente. NenhumDDLHMLaplicado.


## Retomada dependente, ainda não liberada

Este checkpoint é filho direto doHEAD164/4705cd45bf8f7f9fba23c0fa066f0c5da938b14b, preservandoTODOSseusarquivos/código/testes,semduplicarcommits. Altera plano/manifesto e fortalece preflight do harness emrelaçãoa164. PRdependenteDRAFT permite validar deantemãoguard/public/Restore/backup nesteSHAsemAuthmaterial(onPRpuladoporroteamentoexistente). Enquanto164nãoestiverintegrado/aplicado/verificadoHML e esteHEADnãoestiverrevisado/comchecksSUCCESS, condições técnicas ainda não cumpridas paraready/merge.

A migrationpermitida no manifesto continuaSOMENTE a164/hashesimutáveis; nãoautorizaqualqueroutraDDL. Flagdatabase_changes_allowedpermanece paraaCIenxergara164quandoabasePRaindaéGATE163;após164main,deltaéestes2documentos eoguardadicional doharness. Nenhumdeployautomáticoocorreporestecheckpoint. Novo preflight járecusaversion_wrapper_readyfalse antesAuth, portanto afase não contorna adependênciaHML.

Depoisde164HMLverificado+checks desteHEAD,mergenormalCAS eRestorepushmain/currentmain/guard/rebuild/backupnoMESMOmergeHEADliberamNOVOnonce. Publicado1TXTprimeiro,depois4locaisTXT/PDFv1/v2;5arquivos/3docs/5versões/5recibosdisjuntos/worker/downloadintegridade/negativos/cleanuppróprio. Não reutilizar949bquarentenadonemfixtures152/160deoutroexecutor. Falhaoriginalpreservada; nenhumPASSmaterial/CRUD/V1/V2antecipado. Nãoavançarmain/faseenquantorunnerativo.


### Guarda adicional de histórico antes da nova prova

O harness agoraexigeexatamente1registro daCLI20261108122815 naqueryversion_wrapper_ready,alémdeatributos/corpos/ACLsexatos. ImpedeAuth/fixturesquandoatributoaparecepronto masaplicação canônicanãoestáregistrada. ApenasmetadataSQLreadonly,semDDL/grant/frontend/Edge. Esteéoterceirocaminhodaretomada,preflightp0_crud_global_hml.py jáincluídonoGATE163;nenhumcódigoproduto164alterado. A mudança legítima também fazRestorepushmain dispararpelospathsexistentes,permitindo orunnerworkflow_run/eventpushsemnovo workflow oubypass. NovoHEADexigeseuscheckscompletos;CI1efanteriorarquivadaenãoliberaestaalteração.
