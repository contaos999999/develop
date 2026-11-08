# Worker documental HML: PLAN/GATE, 08/11/2026

## Causa comprovada e propriedade

Base main9af2c6a6b42ec175126d1bd2b2f33905742d8ad7, checkpoint152 preservado.148HEAD55c70 passouguard42451862873/public42451862890/Restore42451862920, porémmergenormal foi recusado405 após avanço152.148permaneceDRAFT; nenhumfixture destaexecução criado. EstaexecuçãoTrilhaB assume somente este reparo de runtime;145/147/150/152 e suasfixtures continuamdeoutroexecutor.

SELECTsread-onlyHML em05:46–05:49UTC: pg_net disponível0.20.4, nãoinstalado; schemanet ausente; crons5/6/9 ativos com falhas repetidas `schema "net" does not exist`. Jobdocumental de152 enfileirado/tentativas0, semalteração. Migration inicial20261101205846_0001 exigia `create extension if not exists pg_net`. Funções cron oficiais usam net.http_post; a falta da extensão impede qualquer chamada ao worker. DestinoVault comparado somente no servidor: booleantrue para URLexataHML,2nomes desegredos presentes, nenhumvalor/token/hashsecretorecuperado. Inventáriooficial: queue-worker-documentsv4ACTIVE, autenticaçãointernapreservada; storage-sign-uploadv8/downloadv6ACTIVE/JWTtrue. Falha500 aorecuperarbundleworker foi preservada; inventário não prova paridade debytes.

Advisorshealthsemavisos; security/performance lidos semalterações oportunistas. Crons são observados, nunca invocados manualmente. Fonteoficial: https://supabase.com/docs/guides/database/extensions/pg_net confirma que CREATEEXTENSION habilita aextensão e cria próprionet; requests sóiniciam apóscommit.

## Histórico de segurança e alcance explícito

A revisão independente identificou a remoção INTENCIONAL posterior em20261102101651_remove_unused_pg_net.sql: DROP EXTENSION IF EXISTS pg_net RESTRICT, registrada no resultadoSEC_BACKEND_ALERTS_HML_2026-11-02 eV107. EsteGATE não trata a ausência como drift nemreescreve essa decisão: propõe sua supersessão estrita porque oscronsatuaischamamfunçõesprivadoqueusamnet.http_post e a provadeworkeragora é obrigatória. A antiga remoção/testemunho histórico são preservados. O testeatualqueues_edge_authqueexigeausência deve ser atualizado para exigir exatamente presença na namespaceextensions, jamaispublic, maishttp_postdisponível apenasparaowner, comACLnetfechado, semchamadarede ourelaxarDLQ/idempotência.

pg_available_extension_versionsHML:0.20.4,relocatablefalse,schemaNULL. Fonteprimáriapg_netv0.20.4 pg_net.control.in nãofixaschema; sql/pg_net.sqlqualificaobjetos comnet. Instalação inicial WITHSCHEMAextensions evita repor o warningextension_in_public; não éALTEREXTENSIONSETSCHEMA. Confirmar na reconstruçãoreal e advisorHML, mantendo exigênciaforadeschemapublic.

Raio deefeito: ativação permite chamadasnormais doscronsjáativos para documents,embeddings,AI,webhooks,financeiro,relatórios,notificações,OCR e histórico, semalterarschedules/slugs/payloads. Inventárioreadonly05:51UTC:1jobenfileiradodocuments, pertencentea152;demaisexecuçõesenfileiradas/processando/falhou=0. Contagenspgmq:documents1,ocr0,ai0,embeddings0,finance_imports0,reports0,webhooks0,historico0;integrations0confirmado. Repetirinventárioimediatamenteantesaplicação, registrar contagens/evolução,nuncaalteraroucontarfixture152comoprova148. Nenhumconsumidormanualglobal, segredoouheader/responsebodysensívelexposto.

### Isolamento obrigatório dos objetos net

Nova revisão da fontepg_netv0.20.4 identificou grantsPUBLICnativos deUSAGEschema eALLtabelas/sequências; funções têmEXECUTEpúblicopor padrão. A tabelahttp_request_queuearmazenaheadersdotokencron. Instalarfora dopublicnão resolveessesgrants. OBUILDprecisarevogarALLemSCHEMAnet,ALLTABLES,ALLSEQUENCES eALLFUNCTIONSnoschemanet dePUBLIC,anon,authenticated, na MESMA transação doCREATEantescommit,semjanela decrongravartokencomacessoherdado. Nenhumgrantnovo paraanon/auth; schedulerownerpostgrespreserva privilégiosdeowner e testesexigemowner/postgresUSAGEeEXECUTEhttp_posttrue. NãoalteraACLdeaplicação, nemgrantsdeoutrosschemas.

Migrationexata: BEGIN;CREATEEXTENSIONIFNOTEXISTSpg_netWITHSCHEMAextensions; quatroREVOKEALLPRIVILEGESnosobjetosnet citadosFROMPUBLIC,anon,authenticated;COMMIT. Contratocongelado pela regressão, semcomandosadicionais. SQLrealdoRestoredeveexigirnetHTTPassinadoeextnamespaceextensions,USAGEanon/authfalse,nenhumSELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGERemnenhumatabelanet,nenhumUSAGE/SELECT/UPDATEemsequênciasnet,nenhumEXECUTEemfunçãonetparaessesdoisperfis,maisprivilegiopostgrespreservado. PreflightantesAuthrepetechecagem deisolamentoefetivo, retornandobooleanssomente. Se algumgranthardeningforincompatívelcomworker,manterFAIL e corrigircomprova,nuncaabrirPUBLICparaaprovar.

## BUILD mínimo permitido após esteGATE integrado

Nova migration20261108060000_restore_document_worker_pg_net.sql instala `CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;` e fecha, na MESMA transação antesdequalquercommit/cron, osgrantsnetdescritosabaixo, reabilitando a dependência sob esteGATE que supersede estreitamente a remoção posterior. Não modificar migrationsantigas, funções deproduto,ACLdeaplicação/RBAC/RLS/Auth/Storage,cron/schedules,queues,payloads,configuraçõesVaultousegredos,workflows,frontend317 ouPROD. Não implantar outraEdge: workersjáexistentes são preservados, duasEdgesstoragejávalidadasnão sãoreimplantadas por este reparo. A ativação restaura o processamento normal doscronsjáativos emHML; não chamar consumidor global, não fabricar efeito e nãoalterar/cancelar job alheio.

Acrescentar preflightreadonly de extensão/schemanet/assinaturahttp_post/cronrápidoativo/destinoHMLexato antesde qualquer criaçãoAuth/fixture, somente noloteDOCUMENTOS. Falha deve impedir requestsadministrativos, com relatório sanitizado. Regressão no testeprotocolo existente deve executar métodoREAL/prepare e provar recusa antesdeAuth, alémdoteste da migrationexata eSELECTSQL noRestore,atualizando somenteassertantigodeausênciaemqueues_edge_auth para contratoexatoforapublic. Apenas sete caminhos declarados no manifestoBUILD, semampliação tácita.

## Provas, integração e retomada

REDHML catalogado acima e REDunitário antesda implementação; GREENsuíteNodecompleta,10guards/sintaxe/diff,revisãoindependente semCritical/Important, guard/public-probe/Restore(rebuild+backup)SUCCESS no mesmoHEAD. Mergenormal comexpectedSHA/CAS, semforce/bypass. Aplicar somente migrationintegrada ao projetoHMLfixo pelo fluxo canônicoexistente,conferindoSHA/version/paridade. Antesdaaplicação repetircomparação booleana dodestinoHML, disponibilidade e ausência daextensão; nãoexportarVault.

Apósaplicação: conferir pg_extension/net/http_post,cronssucessoeHTTPcodes sanitizados pelo funcionamento normal, semlerheaders oucorpo sensível. Se existir nova falha deworker, preservarFAIL e corrigir por rito específico,semcertificar. Reancorar148preservando152/esteGATE eBUILD; repetirCI no novoHEAD. Somente então runner1TXTpublicadoPRIMEIRO+4locaisTXT/PDFv1/v2,5arquivos/3documentos/5versões,workerreal,negativos,5recibos ecleanuppróprio. Fixture152 permanecealheia e nãopode comporrecibos148.

Rollback exige nova migration/PR revisada, semDROP CASCADE, apagarfilas/objetos/evidências oucancelar trabalhosalheios; se aextensão jáestiverpresente, somenteCREATEéno-op,hardeningcontinuaobrigatório e namespaceerradabloqueiaprova. Falha técnica mantém148DRAFT/semcertificaçãoCRUD/V1. NãoiniciarV2.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visualN/A, reparodeinfraestruturaHMLjáprevista, semLovable/frontend, semrelaxarguardsouautorização.

## GATE complementar: isolamento preventivo do Restore e backup locais

ApósGATE153integrado4a5bd7c, antesdeimplementarDDL, inspeçãomigration0019comprovouVaultURLHMLhardcoded+tokenaleatóriolocal. Habilitarpg_net noRestorepoderiafazercronslocais tentaremHTTPHML. Nenhumaextensãofoiaplicada,nenhumCIcomnovoDDLfoipublicado. OREDunitárioprópriojáexisteapenasnoisoladobackend-worker-build:63PASS/2FAIL,semproduto.

Complemento permite acrescentar somente3caminhosBUILD: .github/workflows/restore-isolado.yml, scripts/p0-v1-synthetic-data-restore.sh e scripts/isolated-db-network.sh. Mudançaexclusiva decontençãonativa doscontainerslocais; nãoremover/skipparjob,testes,guard,backup,restore oucontrolesnemadicionarsegredos/permissões/tokens. Eventos,branches,condições,CLIpin,assertionsSQL,artefatos e banco127.0.0.1 permanecem. Nenhumaalteração decronHML,workflowsprivadosouproduçãopermitida.

CriarbridgeDockerinternalANTESdedbstart/reset eforçarCLIcomflagglobal--network-id emtodasasoperações decontainerdessasprovas. Falharsemfallbackseainternalidade/nomevalidado/únicaredeanexadadoPostgresnãoforemcomprovados. Revalidarantes/depoisdarecriaçãoreal e nasduasinstânciasbackup. Helpercompartilhado deve exigirGitHubActions/repositóriocanônico,nenhumaDATABASE_URL/SUPABASE_DB_URL/SUPABASE_ACCESS_TOKENremota e operar somentecontainer/netnominaldoteste. SemalterarVault,crons,schemas oumigrations para simularisolamento.

ProvaREALnoCI: metadadosDockerInternaltrue eattachmentúnicoesperado antes/depoisreset; canárioTCPCONTROLADO porlisteneroriginalnohost, IPforadasub-redeinternal,semHTTP/credenciais; controlepositivonohostprovadisponibilidade,controledentrocontainerparaPostgresloopbackprovaferramenta/TCPfuncional, sóentãotentativaàmesmaIP/portadohostdevefalharcomlimitecurtoezeronovasconexõesnoreceptor; conectividadeSQLlocaldevepassartodassuítes ebackuprestore. Casosunitáriosnegativosdohelperreal rejeitamredeexterna,attachmentadicional eorigem/variáveisremotasantesdequalquercomandoSupabase. FonteprimáriaDocker https://docs.docker.com/reference/cli/docker/network/create/ documenta--internal; CLI https://supabase.com/docs/reference/cli/introduction documenta--network-idglobal e resetrecriandoPostgres. Errodeferramenta,parse,namespace,comando127ouausênciadecontrolepositivonuncacontacomoDENY. StopCLI podepodarrede: recriar/reinspecionarantesinstânciaB. NenhumPASSnativopresumidoantesdorun.

AplicaçãoHMLcontinuaexactamenteGATE153: únicatransaçãoCREATEpg_netextensions+4REVOKEsnet,semoutraEdge ouconsumidormanual. EstecomplementonãoliberaDDLantesBUILD/revisão/CIcompleto. ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: N/Avisual, contençãoCIsemLovable/frontend e semrelaxarproteções.
