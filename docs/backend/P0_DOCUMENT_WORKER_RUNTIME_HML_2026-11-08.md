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

## GATE complementar: contenção TCP/HTTP compatível com porta SQL local

BUILD155HEAD0f36a471ae8b4ea831b5433babe271779200ccd8, guard42453742974/histórico42453743096SUCCESS. Restore42453742973:rebuild128648236429 ebackup128648236504FAILemdbstartECONNREFUSED127.0.0.1:54322;DockerinternalimpediutambémportapublicadalocaldaCLI.Nenhumreset/novaDDL/provanativaPASSouHMLwriteexecutado. BackupregistrouFAIL_OR_INCOMPLETE,artefato13607001525/SHA2569fbee7cca5163b8aa0a7571505ccb863cb1a5144c120c66a517412751e6864ee. Rebuildsemartefato(logretido). Nãoadotarrelay/proxy/mock nemignorarporta/erroparacertificar.

EstecomplementosupersedeAPENASmecanismo--internaldoGATE154, preservando todoobjetivodecontenção,controles/testes/cleanup e10caminhosBUILD. Usarbridgeprópriojob/run/attempt,IPv6desabilitado,ownershiplabels/NICúnico; ANTESdeQUALQUERstart,instalarfiltrosLinuxnativosdojob:jumpcomCIDRexatodaredeown emDOCKER-USER/FORWARD eINPUT, cadeiaexclusiva cujaúnicapermissãoderetornoéconntrackESTABLISHED(respostasdeconexõesSQLiniciadaspelohost);todoNOVOorigemCIDRownéDROP. SemRELATED,whitelistdeinternet,redeextra,proxy,DIRECTfallbackouhostnetwork. Nenhumacadeia/regraforaescopoownpodeseralterada/limpa;nomes/labels/ownership/camposcongelados e regraspreexistentesdivergentesdevemfalhar. Antes/depoiscriação/reset ebackupB: confirmar regrasREAISkernel/ordem/counters,redeúnica,EnableIPv6false,semendereço/rotaIPv6globalnocontainer. Firewallinacessível/falha/toolssemprova=FAIL,semfallbackpararedeaberta.

A conclusãoé bloqueioTCP/HTTP(S)docontainer,incluindoHML;NÃOcertificarisolamentodeTODOSprotocolos/DNScomprovaTCP. DNSembeddedDocker127.0.0.11épossívelcaminhodelegado;nenhumbypassfoicomprovado,nãopresumirnemdeclararDNSPASS. CronslocaissóusamURLcanônicaconstanteHML,semcredenciaisnodomínio. ManterHMLsecretsausentes econtrolfixturesemcredenciais;tokenaleatóriolocalnãopodetransmitirempayload/headerHTTP. Fonteprimária https://docs.docker.com/engine/network/firewall-iptables/ descrevecadeiaDOCKER-USEReconntrack.

Provanativaobrigatória: listenerTCPoriginalcontroladonohost/IPforasub-redeown,controlehostpositivoANTES/DEPOIS,controleloopbackPostgrespositivo,mesmoendpointnegadodocontainercomzeronovasconexõesnoreceptor eincrementoREALdocounterDROP. AlémdeBashTCP, apósresetcomextensãoinstalada,executarnet.http_postREALnoPostgresLOCALparaomesmoendpointcontroladocomURL/body/headersbenignossemsegredos. Aguardarrespostadeerrolocalbounded,exigirDROPdeltaezeroreceptor;ausênciaworker/timeouterrorsemDROPnãoéPASS. Antesresetsemextensão,registrarprovaHTTPN/A,nãocertificar;apósresetexigirprovaHTTPreal eSQL/backupcompletos. ArtefatosJSONLsanitizadosguardamcontroles/counters/estados,semheaders/responsebody/IPs/sessõesoucredenciais.

NegativosdohelperREALdevemrejeitarorigem/credentials/ownership/regras/nome/NIC/IPv6inválidosantesSupabase,comprovarcleanupemfalhapósstart. Casosunitáriosnãoatestamfirewallreal. CIprecisaexecutartodassuítes/Restore/backup/public/guardnomesmoHEADnovoeindependentreviewsemCritical/Importantantesmergenormal. DDLHML153permaneceCREATEextensions+4REVOKEsatômicos,semalterarcronHML/Vault/queues/Edges/frontend/PROD.148DRAFTatéworkerreal,semCRUDglobal/V1/V2.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: N/Avisual;compatibilidadeCLI+contençãoTCPnativa,semrelaxarCI/proteçõesouusarLovable.

## Checkpoint: impedimento comprovado da plataforma e decisão necessária

Em 08/11/2026, a continuação autorizada pelo titular investigou worker e verificação de segurança do arquivo do checkpoint #152. Ambos dependem do worker documental. O HML continua com o arquivo `8cc6ac08-7f5b-469c-ab50-7b33d5a12379` em segurança pendente e o job `431c5c89-812e-4d7e-99be-5550a55bafcf` enfileirado, zero tentativas. Nenhum status foi aprovado manualmente. Nenhuma extensão foi instalada no HML nesta execução.

### Evidência e causa definitiva do bloqueio atual

- PR #155, HEAD `4deade48a165d4df2d0643643b778cf283b46b09`: guard/public/histórico e backup passaram; a reconstrução bloqueou em oito testes de privilégio efetivo do schema net. Os testes nativos de contenção TCP/HTTP passaram.
- Diagnóstico somente de catálogo `40323f2c30d0891144a7c44be05abefadd540af7`: owners e grantors dos objetos net são `supabase_admin`; grants a PUBLIC e aos clientes continuam presentes. anon/authenticated não são superusers nem membros de postgres.
- Diagnóstico isolado em savepoint `d5d79b626a8236f3ed0a618d2ae5d733f311aac7`, run `42456946721`, job `128657901129`: os quatro REVOKEs originais emitiram **WARNING: no privileges could be revoked**. O catálogo imediatamente posterior continuou com anon_usage=true, auth_usage=true e anon_http=true. O rollback foi executado antes das oito assertions originais, que continuaram falhando. Não se trata de simplesmente afrouxar teste ou reaplicar uma revogação após o reset.

A [documentação oficial do Supabase, atualizada em 04/11/2026](https://supabase.com/kb/troubleshooting/revoking-access-to-pg_net-objects-has-no-effect-0bbc16) confirma que postgres não concedeu esses privilégios e não possui grant option. A plataforma não suporta alterar os grants de pg_net por projeto. Remover os grants de PUBLIC também quebraria workers que dependem deles. Portanto, o contrato literal de quatro REVOKEs eficazes do GATE #153 não é executável neste ambiente. Não tentar SET ROLE privilegiado, alterar ownership, editar catálogos, fabricar PASS ou acessar credenciais de administrador da plataforma.

### Alternativa concreta, ainda NÃO autorizada como BUILD

Preservar frontend e backend Supabase, os workers e crons existentes, usando a fronteira suportada pelo provedor: pg_net em namespace interno, net fora dos schemas expostos pela Data API, anon/authenticated sem LOGIN direto e acesso SQL direto somente por serviços confiáveis. Isso substituiria explicitamente a exigência de ACL interna fechada do GATE #153; não seria uma alegação falsa de revogação.

**Consequência material:** qualquer papel com acesso SQL direto pode ler headers de requisições pg_net enquanto estão na fila, inclusive o token interno enviado pelo cron. Esses acessos devem ser considerados administrativos e confiáveis. Esta mudança de condição de segurança exige decisão expressa do titular antes de habilitar a extensão, alterar testes ou integrar/aplicar o BUILD #155.

Provas preparatórias somente de leitura: HML inventariou apenas roles de infraestrutura/Supabase com LOGIN. A requisição anônima à Data API com Accept-Profile net, seleção apenas de id e limite zero, retornou **406/PGRST106, Invalid schema: net**. Isso prova somente a recusa dessa chamada; não substitui inventário completo da configuração gerenciada, prova autenticada ou verificação posterior à ativação. Nenhuma linha de fila, header ou segredo foi lido. A consulta de configuração da sessão não retornou db_schemas e não foi usada para alegar configuração global confirmada.

Se o titular aprovar esta alternativa, um GATE complementar deve fechar os caminhos e exigir: configuração gerenciada exata, negativos reais anon e authenticated para net, revisão dos logins diretos, preservação de JWT/token interno/RBAC/RLS, instalação versionada sem REVOKE ineficaz nem escalada, contenção TCP/HTTP real do Restore/backup, testes completos e revisão independente no mesmo HEAD, merge normal e deploy canônico. Depois, observar os crons normais processarem o mesmo arquivo #152 e comprovar segurança aprovada, extração real, páginas/fragmentos e estado de processamento, sem consumidor global manual ou liberação artificial.

**Estado:** diagnóstico concluído; duas pendências de produto ainda NÃO resolvidas; PR #155 bloqueado; nenhum deploy HML autorizado por este checkpoint. A prova de upload #152 permanece válida e não deve ser repetida ou apagada. V1/global/CRUD continuam sem certificação integral. Não iniciar V2 ou alterar PROD.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visual N/A; diagnóstico e planejamento sem turno Lovable, sem alteração do backend HML, sem reduzir teste ou proteção silenciosamente.
