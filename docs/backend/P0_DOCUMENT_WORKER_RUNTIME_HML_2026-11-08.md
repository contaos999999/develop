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

## BUILD em validação, sem aplicação HML

GATE153 HEADf51c3be/guard42452599376/review5816824761 integrado4a5bd7c. Complemento154 HEADfbb81464/guard42453132612/review5816842954 integrado884fc628.10caminhosBUILDdeclarados;nenhumtrabalhoalheioalterado.

Regressõesnovasde migrationexata/preflightREALprepare: RED63PASS2FAIL antesimplementação; GREENprotocolo67/67, com23metadatacasesguardantesAuth e8negaçõesdohelperrealantesSupabase. RegressãohelperexecutadacontrafonteGATEsemhelper:1FAILesperado. SQLmetadataextraídodométodoREAL eexecutadoreadonlyHML: extension_ready=false,http_post_ready=false,acl_isolated=false,scheduler_ready=false,destination_is_hml=true; provaoriginalpreservada,nenhumfixturecriado.

SuíteNodecompleta326/326PASS;10guards/sintaxePython/Bash/diffPASSlocais. Mudançaworkflowmantémtodosjobs/testes/eventos/pins/condições/permissões/artefatos, substituindoapenasstart/reset/migrationlistporwrapperlocalnativo. Backupmantémduasinstânciasreais eassertionsoriginais. Helperprovémredeinternalpré-start,ownership/attachmentúnico,recriaçãoB,controlespositivoshostePostgresloopback/negativoaoMESMOlistenercontrolado,JSONLsanitizado. Ausência/falhadeferramentanãocontacomoDENY.

Migrationinstalaextensãoforapublice4REVOKEsnetnumaúnicatransação. AcceptanceSQLrealacrescenta10checksde namespace/assinatura/scheduler/ACLsefetivasdeanon/authsemretornarheader/token. RegressãoqueuesEdgeAuthmantémidempotência/DLQ eexigepresençaexatanonpubliccomnetschemafechado,superandoassertantigodeausênciasobGATE153.

Dockerlocalindisponível;nãocontarprovaTCPouRestorelocalcomoPASS. Próximo: revisãoindependente/CIguard/publicprobe/RestoreSQLreal/backup+contençãonativanoMESMOHEAD. Sóapósmergenormal echecagensHMLbacklog/destino,aplicaçãocanônicaHMLdomigrationhash.148permaneceDRAFT,semCRUDglobal/V1/V2/PROD.

RevisãoBUILDidentificouImportantcleanup: helperpodiainiciarDBefalharnoTCPantesstarted=1. REDrealorquestraçãobackup:1FAIL,STARTEDsemCLEANUP_ATTEMPT. Corrigidoregistroantesdosdoisstarts; testeexecutabackuprealcomhelperquecriarecursoefalhapósstart,exigetentativacleanup,recursoencerrado,statusFAIL_OR_INCOMPLETE,semconverterfalhaemPASS.

### BUILD reancorado após GATE156

Complemento156HEAD6784bfa/guard42454206109/review5816878744 integrado7f692dc15a50e25d648bd164d65301018c83f03c. PreservadosGATE153/154,FAIL0f36aecheckpoint152. Helperagorausaúnicabridgeown,IPv6desabilitado/rotasglobaisausentes,regrasnativasLinuxowncomESTABLISHEDapenas+DROPinINPUT/DOCKER-USERantesstart,revalidandoprioridade/body/labels/NIC/kernelcountersantes/depoisreset. Políticaalheia/divergentenuncaésobrescrita. PortapublicadalocalCLIpermaneceparaSQLreal;nenhumproxy/relay/mockouguardignorado.

BootstrapREALhelperREDcontra0f36a:1FAILsemKERNEL-SINPUT; GREENnovohelper68/68protocolo. RegressãopositivadebootstrapcomkernelstubcheganaCLIapóschecartodasregras,CLIcontinuaFAILsimulado93semprovaTCPfake;cadeiaACCEPTextraérecusadaantesCLIsemoverwrite. SuíteNodecompleta327/327PASS,10guards/sintaxe/diffPASSlocais. Nãoatestamkernel/Dockerreal.

ProvanativanovoCIobrigatória: controlespositivoshostantes/depois ePostgresloopback,TCPdeniedcomDROPdelta,receptor0;apósresetrealnet.http_postLOCALaoMESMOlistenerbenignosemsegredos,errobounded+DROPdelta+receptor0. ArtefatoJSONLexplicitaTCP/HTTP(S),dns_certifiedfalse,pg_netN/Aantesresetseausente,sucessorealobrigatóriopósreset. Sequalquerrota,IPv6,rule,counter,workerlocal/SQLfalhar,manterFAIL. SemnovoHMLwriteatéCIrevisão/mergenormal;148DRAFT/nenhumCRUD/V1/V2.

### Falha real do canário e diagnóstico fechado

HEADe2e069a:guard42454681799/histórico42454682030/public42454681852SUCCESS. Restore42454681892rebuild128651070065/backup128651070216FAILapósdbstart,antesreset/migrationnova,emnativaTCPgenericafailure. Backupartifact13606742586/SHA256db9a2be04c4e0ba829c931d438c89bbc29350e2e6cfca9f9c3f66916e5253a09.NenhumHMLwriteoufixture. Causaexatamantinhanãoclassificada; nãopresumirqueDROPestáfuncionando.

ControlepositivoagoraconsultaSHOWportREALdoPostgreslocalviaUnixsocketDockerpsql,exigeinteiro1..65535,nãoassume5432. DiagnósticopublicaapenasclassesfechadasTIMEOUT_TOOL_MISSING/LOCAL_POSTGRES_TCP_POSITIVE_FAILED/EXTERNAL_TCP_NOT_DENIED/DOCKER_OR_UNKNOWN_FAILURE,deltaDROP/contagemreceiver,semstderrraw/IP/credenciais. Falhaemqualquerclassecontinuabloqueante,contador/receptor/pg_netrealmantidos. CIpróprionovoHEADobrigatório,semrelaxarmétodoonativofirewall.

### Prova TCP com ferramenta PostgreSQL e status normativo

HEAD3fa747a/Restore42454969255rebuild128651938029/backup128651937842FAILantesreset. DiagnósticoREAL: DROPdelta3,receptor0,maswrapperdeTCPretornouclasseEXTERNAL_TCP_NOT_DENIEDsemexporstatusinterno. Nãoequivaleaconexãopermitida/nemPASS;causaexatautilitárianãopresumida. Artifactbackup13607665188/SHA2565d51599618f0ca52d2cf943403c0deb0fa844e5966aefde2916ad58de2a36a03. SemHMLwrite.

SubstituídométododeferramentaBash/timeoutporpg_isready(PQping)doPostgresjáinstalado,comtimeout3s e códigosnormativos:0servidoraceita,2semresposta;outroscódigosnãoatestamDENY. https://www.postgresql.org/docs/17/app-pg-isready.html. ControleloopbackusaportaSHOWportreal eexige0;mesmoendpointcontroladoexternoexige2+DROPdelta>0+receiver0+positivoshostantes/depois. Ferramentanãotransmitepassword;PGPASSWORD/PGPASSFILE/PGSERVICEherdadoszerados eusername/databasebenignosconstantes,semHMLcredenciais. Nenhumcódigo143/127/1éaceitoparaconverterFAILemPASS.

Novo validadorREALextraídoporAST:RED1FAILausente→GREEN69/69protocolo;suítefull328/328PASS. Negativosstatusambíguo,errodetool,DROPausente,receiveratingido,tipoerradobloqueiam. Firewall,pré-start/IPv6/rules eprovaREALnet.http_postpósresetinalterados; nãoháprovanativaforaCI. Revisãoindependente/novoCIcontinuamobrigatórios.

### Ambiente limpo para o controle positivo

HEAD28e157e/Restore42455364024falhou no controle positivo local de pg_isready, antes de testar o destino externo/reset/nova migration. Backup13607765338/SHA256d340e4adc03e8a8ec9d0e374570e9cacfb5efe67d74bf5804cfd64338c77d4d2. O status não havia sido exposto; a causa anterior continua não comprovada. HML não foi alterado.

O processo agora usa `env -i`, preservando somente PATH e PGPASSFILE=/dev/null. Serviço e senha herdados são removidos, em vez de passados como opções vazias. Host, porta e usuário/database benignos são parâmetros explícitos. O status do controle positivo e sua classe fechada são registrados antes de qualquer recusa, sem stderr ou dados privados. Nenhuma exigência0/2/DROP/receptor/pg_net/IPv6 é relaxada.

Regressão extrai a função tcp_probe real, emula apenas Dockerexec e executa o shell/processo reais com canários herdados: RED1FAIL na versão anterior; GREEN comprova ausência de serviço, senha e qualquer canário no processo final. Protocolo70/70 e suítecompleta329/329PASS. Revisão independente favorável, mas contenção e pg_net reais ainda precisam passar no novo CI; sem material/CRUD/V1/V2.

## Diagnóstico ACL do último CI, continuação autorizada do titular

HEAD4deade48a165d4df2d0643643b778cf283b46b09: guard42455696954, histórico42455696922, public42455696932 e backup128654108357SUCCESS. Reconstrução128654108585/restore42455696916FAIL em Teste1: oito verificações de privilégio efetivo net retornaramfalse; presençaextensions eownerpostgres passaram. Provas nativasTCP/HTTP passaram antes/depoisreset. Causa da ACL ainda NÃO determinada. Não afrouxar teste, instalarHML, liberararquivo manualmente ou alegar conclusão.

Delta somente de diagnóstico noSQLjápermitido: SELECTcatálogo dosroles/superuser/herança e ACLs/owners de schema/tabelas/sequências/funçõesnet, semler filas,headers,segredos oucriarobjetos. Mantidas todasassertions bloqueantes. O titular nesta conversa determinou resolverworker e verificações dafixture152; reutilizar155 semduplicação. HMLcontinua intacto e arquivo152 pendente/enfileirado.

Diagnóstico40323f2/restore42456721306: owners/grantors net=supabase_admin; grantsPUBLIC eexplícitosanon/authcontinuamabertos; rolesclientesnãoSuperuser/nãomembrospostgres. CausaentreREVOKEineficazporgrantor e reaplicaçãopósCLI aindaadistinguir. PróximodeltasomenteSQLlocalemsavepoint: executar osmesmos4REVOKEs, registrar catálogoimediato eROLLBACKTOantesdasassertionsoriginais. NenhumREVOKEcorrectivotardio éusadoparaaprovar. Sepermissõespermaneceremabertasantes/depois, nãoaplicarHML e buscarfluxooficialdeowner/instalação.

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

## GATE complementar aprovado pelo titular: fronteira efetiva da API

Em 08/11/2026 o titular respondeu **“Surorizo”**, interpretado no contexto inequívoco como **“Autorizo”**, à pergunta expressa do checkpoint #157. A autorização aceita manter os workers no Supabase, proteger a fronteira da API e limitar SQL direto a serviços administrativos confiáveis, ciente de que essas contas podem ler headers da fila pg_net. Não solicitar novamente essa mesma decisão. O registro histórico de oito negativas ACL e da decisão anterior permanece intacto.

Este complemento substitui **somente** a condição inexequível de revogar os grants gerenciados de pg_net do GATE #153. Não afirma ACLs fechadas nem ausência de acesso SQL administrativo. Preserva o backend Supabase, Auth/JWT/token interno/RBAC/RLS/Storage, workers/crons, filas e payloads existentes, a contenção real TCP/HTTP dos GATEs #154/#156, as provas de restore/backup/guards e a proibição de consumidor global manual. Frontend, PROD e migrations já aplicadas permanecem intocados.

### BUILD fechado após integração deste GATE

Reutilizar o PR #155 com reancoragem normal, mantendo seus dez caminhos já autorizados e acrescentando somente:

- `.github/workflows/p0-hml-migration-version-parity.yml`;
- `supabase/tests/worker_api_boundary_hml.py`;
- `supabase/tests/worker_api_boundary.test.mjs`.

A migration **ainda não aplicada** `20261108060000_restore_document_worker_pg_net.sql` passa a conter somente BEGIN, CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions e COMMIT. Retirar os REVOKEs ineficazes dessa versão não aplicada, preservando seus hashes/falhas anteriores no histórico. Não mudar owners, grantors, roles, membership, LOGIN, configuraçãoAuth ou catálogos privilegiados. A extensão deve estar fora de public, sua API oficial disponível ao scheduler e as identidades de aplicação sem LOGIN. Qualquer role SQL de LOGIN além da lista nominal dos serviços já inventariados deve bloquear a implantação para análise, sem revogação cega de infraestrutura.

Substituir as oito assertions que exigiam ACLs impossíveis por testes precisos de contrato gerenciado: namespace, assinatura, owners gerenciados, capacidade do scheduler, anon/authenticated sem LOGIN e inventário fechado de logins. Registrar que esses testes SQL não certificam a Data API. Não retirar as demais provas e negativas existentes. O preflight do runner documental deve exigir extensão/cron/destino HML e os controles efetivos, sem alegar grants revogados.

### Prova real antes e depois do deploy

No workflow canônico de deploy_one, **somente para a versão 20261108060000**, executar o novo script antes de qualquer DDL e novamente depois da aplicação, após conferir fonte/hash/checks/manifesto e exatamente uma migration pendente. Disponibilizar `CONTAOS_HML_AUTH_ADMIN_KEY` somente no passo de prova correspondente, dentro do ambiente protegido hml. Nenhum token, senha, body de erro ou URL assinada pode ser impresso ou publicado. Preservar comportamentos/inputs das outras migrations e os gates atuais da CLI.

O script valida project ref/host/role do DATABASE_URL e origem HTTPS fixa, sem redirects. Lê somente metadados de extensão, roles e comparação booleana do destino Vault, nunca valores de secrets ou linhas das filas. Cria apenas uma identidade Auth sintética própria por execução, com escopo/nonce/intent_id recuperáveis; autentica pela API normal e confirma identidade. Usa a chave pública já existente, mantendo a chave administrativa apenas na API Auth. Exige controles positivos de API pública e sessão autenticada; para **ambas** as identidades, uma leitura com `Accept-Profile: net`, seleção apenas de id e limite zero deve retornar exatamente 406/PGRST106. Outros erros, falha de transporte ou autenticação não contam como proteção. Essa é a prova da configuração efetiva da API; não inferir configuração global de GUC ausente numa sessão SQL. Não selecionar headers, body, tokens ou linhas de net.

A identidade própria deve ser excluída e sua ausência confirmada, inclusive quando a requisição de criação tiver resultado incerto. Verificar scope/nonce/intent_id antes de qualquer exclusão; não excluir usuário preexistente, de outra execução ou da fixture #152. Limpeza incompleta mantém FAIL; relatório sanitizado identifica estágio, HEAD, booleans e status, sem credenciais. Não criar arquivos/documentos/jobs nem chamar workers nesse preflight. Um FAIL anterior impede DDL; FAIL posterior impede declarar conclusão e preserva os recibos para correção, sem apagar filas ou aplicar rollback destrutivo automaticamente.

TDD deve provar recusa de status/código divergentes, erro de transporte/redirect, inventário inesperado, estados de extensão incompatíveis e ciclo de recuperação/cleanup de identidade própria. Regressão valida o workflow exato antes/depois do deploy e limita a migration ao contrato aprovado. Suíte Node completa, sintaxe Python/YAML, todos os guards, public-probe, restore SQL e backup reais no mesmo HEAD, mais revisão independente do conjunto, são obrigatórios antes de merge/aplicação.

Após implantação e controles efetivos aprovados, **observar os crons normais**, sem consumidor manual, até processar a fixture #152. Comprovar job real, segurança aprovada pelo worker, extração, páginas/fragmentos e atualização autenticada na interface. Não atualizar status de segurança manualmente nem atribuir a prova de um TXT a antivírus universal, todos os formatos, CRUD global ou certificação V1. Encerrar com checkpoint integrado de commits, CI, implantação e pendências reais.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visual N/A; reaproveitar workers e código existentes, sem turno Lovable, nova arquitetura de backend ou relaxamento silencioso de requisito. A mudança da condição de segurança está expressamente aprovada e delimitada acima.

Ruling: reancorar155 no GATE158 aprovado, preservando histórico/diagnósticos e contenção existentes. Somente a condição rawACL é substituída pela fronteiraAPI expressamente autorizada; custo se errado: exposição indevida da rede, bloqueada por provas reais antes/depois do deploy.

## BUILD da alternativa expressamente autorizada

GATE158 HEAD e7466f2f82c497d3a6be057ddbec7901b170fb9d integrado em eedf922cdf3fab0673438fb4627c327411819bd2 após guard42473235121SUCCESS e revisão independente sem Critical/Important. Reancoragem155 preserva dois pais d5d79b+eedf922, semforce. Autorização do titular e risco administrativo aceito estão no manifesto, não implícitos.

TDD: novo teste recusou ausência do script; contrato da migration recusou os quatro REVOKEs antigos; teste de limpeza reproduziu falsa confirmação de ausência após criação incerta e passou após bloqueá-la; teste de workflow recusou ausência dos passos reais pre/post; preflight antigo recusou novo contrato antes da adaptação. GREEN dirigido73/73. O novo script não lê filas ou valores Vault, mantém credenciais apenas em memória, recusa redirects e só exclui identidade comprovadamente própria, com confirmação de ausência. A etapa SQL isolada agora prova o contrato gerenciado e LOGIN, sem alegar acesso API negado por SQL. Provas HTTP reais permanecem exigidas no deploy.

O pipeline de deploy mantém todos os inputs/versões/gates anteriores; somente migration20261108060000 executa testes Auth/API reais antes e depois, com segredo administrativo limitado aos dois passos. Artefato contém apenas relatórios sanitizados e IDs opacos de recuperação, sem JWT/senha/admin secret ou bodies HTTP. A prova #152 continua intacta até o cron normal. CI, revisão final, merge e aplicação ainda pendentes neste registro.

### Continuidade P0: papel efetivo da prova autenticada e diagnóstico HTTP local

Base publicada `94667da1265e37232d6b494d18da7f21924727e0`. Guard/public/histórico SUCCESS; Restore `42473999159` teve backup `128711118826` SUCCESS e reconstrução `128711119115` FAILURE após reset. TCP positivo0/negativo2/DROPdelta8/receptor0 passou; a prova pg_net HTTP falhou sem discriminar resposta e contador. Acrescentado diagnóstico apenas de booleans/contagens: resposta própria de erro, DROP delta, receptor, pedido próprio ainda enfileirado e worker visível. Nenhum URL, header, corpo, segredo ou nova chamada HML. FAIL original e requisito HTTP continuam intactos.

Revisão independente encontrou risco de falso PASS autenticado quando token emitido pelo Auth conserva sub mas usa role anon. RED dirigido:3PASS/1FAIL (`wrong issued token certified authenticated`). Correção mínima exige role authenticated e sub da fixture no mesmo token retornado pelo fluxo Auth legítimo e confirmado pelo endpoint Auth/user, antes das chamadas REST autenticadas. Parse local é somente coerência, não substitui verificação de assinatura pelo Auth; nenhuma sessão de navegador é extraída e nenhum JWT é impresso. GREEN4/4 dirigido e333/333 suíte em cópia isolada, sem skip; revisor separado reexecutou4/4 e aprovou estritamente esse delta sem Critical/Important. CI completo do novo HEAD, integração, implantação e provas HML ainda PENDENTES.

GATE158 integrado `eedf922cdf3fab0673438fb4627c327411819bd2`; execução adicional Restore `42473442988` comprovou reconstrução `128709374356` e backup `128709374177` SUCCESS no HEAD do GATE `e7466f2f82c497d3a6be057ddbec7901b170fb9d`, junto com guard `128708700681`. Não reutilizar esses checks no BUILD. Fixture152 continua enfileirada/tentativas0 na consulta somente leitura; pg_net HML ainda ausente. Proposta159 usa condição ACL supersedida, manter separada sem reintroduzir requisito antigo. V1 não certificada; V2/PROD bloqueados.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visual N/A, deltas mínimos em caminhos já autorizados, testes e GitHub sem Lovable; sem nova configuração Auth, mudança RLS, consumo manual ou alteração PROD.


### Conciliação final dos controles HTTP e execução no Restore

Preservado integralmente9c263374 e seu diagnóstico pg_net, manifesto e correção JWT. Revisão final encontrou controle positivo anônimo inacessível (DataAPIroot401) e suíte boundary ausente no comando Restore. RED dos dois cenários reproduzido; GREEN usa Auth/settings200 anônimo e DataAPI/configuracao_upload?select=id&limit=0 com token authenticated200, mantendo net406/PGRST106 estrito. Restore executa a suíte nova antes da criação do banco. Teste usa Probe.run real, transporte apenas simulado e JWT sintético coerente; não é prova HML. GREEN6/6boundary e335/335Node completo, zero skip/fail. Revisão independente do conjunto sem Important adicional; JWT já revisado e conciliado. CI do novo HEAD e correção de eventual diagnóstico de isolamento continuam obrigatórios antes de merge/deploy. Nenhum write HML.


### Espera assíncrona da prova local após reset

HEADd21fb055: guard42474670270/histórico42474670303/public42474670278SUCCESS. Restore42474670328: reconstrução128713192747 concluiu suites SQL masFAIL no canário da etapa Registrar histórico (queuedtrue/deniedfalse/DROP37/receptor0); backup128713192615FAIL no último canárioHTTP. Diagnóstico exato: própria resposta ausente e request ainda na fila após10s, worker visível, DROPdelta46 e receptor0. As três provasHTTP anteriores confirmaram resposta negada e DROP2. Não é conexão externa permitida nem PASS do backup. Crons existentes têm timeout10000ms por request, executam em lotes e permanecem ativos no banco reconstruído;10s não cobrem necessariamente a espera do lote anterior mais o próprio request.

Delta mínimo de hipótese temporal: polling do MESMO request até45s, mantendo exigências resposta statusnull com timeout/error, DROPpositivo e receptor0, sem restart/pausa de worker/cron, sem apagar filas, sem trocar destino nem relaxar firewall. Deadline vencida continua FAIL. Teste extrai funçãoREAL: REDausente; GREENresposta só após12s e caso sem resposta recusa até45s. Suíte336/336PASS. NovoCIreal ainda obrigatório para confirmar hipótese; HML intacto.


## Checkpoint oficial: duas pendências resolvidas no HML em 08/11/2026

Este registro substitui o estado pendente dos checkpoints152/157 para a fixture152, preservando os diagnósticos anteriores como histórico. **Worker documental e verificação de segurança desta fixture foram executados e comprovados.** Não repetir upload, instalação da extensão ou processamento já concluídos. A auditoria global da Trilha A e a prova material própria do PR148 continuam dependentes de seus requisitos específicos.

### Fonte, revisão, CI e implantação

- PR155 integrado normalmente em `79aec0002712df1a2262bdee9185cc406ba21eb2`; HEAD testado `39cb9ef93f319056be4161f344d705ecd5a7ec1f`, ancestral do merge com bytes da migration idênticos, verificados por git. Local336/336Node, zero falhas/skips. Revisão independente do conjunto e das correções sem Critical/Important pendente.
- Guard42475021499, histórico42475021428, public-probe42475021264 e Restore42475021266: **SUCCESS** no mesmo HEAD. Reconstrução128714305872 e backup128714305654: **SUCCESS**, incluindo controles nativosTCP/HTTP com respostas negativas dos próprios requests, DROPpositivo e receptor0. A última prova da reconstrução precisou mais de10s e terminou com deniedtrue/DROP82, confirmando a espera assíncrona sem afrouxar isolamento.
- [Implantação42475332474](https://github.com/contaos999999/develop/actions/runs/42475332474), job128715271347: **SUCCESS**. Inputs: deploy_one, versão20261108060000, HEAD39cb9ef93 completo e SHA256 `b9eaba3e21f4d811f1d20a90bf9269ea2ab32825cbcc110618778fcc6b26a191`. CLI2.81.3 aplicou uma única migration, confirmou uma linha de histórico e paridade global. Nenhum replay de SQL histórico.
- SQL pós-deploy confirmou pg_net0.20.4 emextensions e a versão20261108060000 presente uma única vez. Mantido o contrato gerenciado expressamente autorizado no GATE158, inclusive risco residual de leitura administrativa SQL dos headers internos. Sem alteração de workers, RLS, configuração Auth ou PROD.

### Prova real da fronteira API antes e depois

Artefato13614902486 `contaos-worker-api-boundary`, ZIP SHA256 `ba7d49fd5921faada31db7042d33133757b0424802414200771e302863a77292`, baixado e conferido. Os dois JSONs apontam o HEAD39cb9ef93 completo, estadoPASS, nove assertions true e limpeza `OWN_AUTH_ABSENT_CONFIRMED`. Não contêm senhas, JWT, chave administrativa, headers internos ou bodies HTTP. Artefato expira em08/12/2026; os resultados essenciais ficam persistidos neste checkpoint e no manifesto.

| Controle real | Preinstall | Postinstall |
|---|---|---|
| Extensão no estado esperado, clientes sem LOGIN, inventário SQL nominal, destino e cron HML | PASS | PASS |
| Auth/settings anônimo, sem credencial administrativa | 200 | 200 |
| DataAPI net anônimo | 406/PGRST106 | 406/PGRST106 |
| Criação de identidade própria, login e /auth/v1/user | 200, identidade confirmada | 200, identidade confirmada |
| JWT emitido pelo Auth com roleauthenticated e sub próprio | PASS | PASS |
| DataAPI pública com JWTnormal, seleção id/limit0 | 200 | 200 |
| DataAPI net com o mesmo JWTnormal | 406/PGRST106 | 406/PGRST106 |
| Exclusão da própria identidade e ausência confirmada | PASS | PASS |

### Resultado material da fixture152 preservada

Contrato `be89ef7e-d839-46c0-9cfb-4da81edf8b74` / AUD-A-VERCEL-20261108, organização ContaOS HML Teste. Arquivo `8cc6ac08-7f5b-469c-ab50-7b33d5a12379`, documento `525e54fc-feec-4dc0-b540-1510a3c52485`, versão1 `2ea42a44-db27-4c4e-801f-9fc5227c2458`, job `431c5c89-812e-4d7e-99be-5550a55bafcf`.

O cron normal5 succeeded em11:21:14UTC. O job iniciou em11:21:16.353468UTC e concluiu em11:21:17.529059UTC, **uma tentativa, sem erro**. Não houve chamada manual ao consumidor global nem UPDATE manual de aprovação. O worker aprovou o arquivo por `integridade_e_assinatura` e gravou `DOCUMENTO_PROCESSADO`, documentsconcluido, uma página e um fragmento. O TXT permaneceu285bytes com SHA256 `773eb577ba88a260247803d37dced4f5469e8c39347dd3fe7c58c4d9f4681103`; hash do texto da página coincide com o arquivo. Contagem de execucoes_assincronas é1tentativa; processamentos_documento/UI exibe tentativas0 em seu contador próprio, sem confundir os dois campos.

Às11:22UTC, crons5/6/9 succeeded após implantação; consulta somente de status confirmou21 respostasHTTP200 semtimeout, sem ler headers/body. A interface autenticada Vercel, após reload, mostrou **Aprovado**, **Concluído**, **Página1** e **Fragmento1** com o texto sintético preservado. Captura `contaos-worker-approved-20261108.png`, SHA256 `ece23efad5f4478fcb94ee898296668e7736d0bcc77ce8a35fea89b8ef7dbf7a`, registra organização, nome/hash/285bytes, aprovação e processamento concluído.

Tentativa adicional de download não gerou recibo de conclusão no navegador automatizado antes de um timeout da ferramenta. Não contabilizar esse download como PASS nem como falha funcional comprovada do produto. A prova destas duas pendências é processamento/segurança por SQL e interface autenticada, não transferência de download.

### Continuidade sem repetir trabalho

Última etapa comprovada: upload152 preservado, runtime155 integrado/aplicado e aprovação/processamento da sua fixture concluídos, com provasAPI reais e cleanup. As duas pendências específicas desta execução estão encerradas. Próxima tarefa: retomar a matriz de requisitos ainda pendentes no planejamento da Trilha A; a prova material do executor Trilha B/PR148 deve ser própria, reancorada e validada no HEAD correspondente. Este checkpoint não autoriza limpar/reutilizar a fixture152 nem incorporar prova alheia.

Não declarar antivírus universal, todos os formatos, CRUD global ou V1 certificados com este TXT. Nenhum V2 ou PROD. Qualquer novo código/DDL exige novo escopo e validação; este PR de checkpoint altera somente estes dois documentos. ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: resultado reaproveita frontend e workers existentes, sem alteração visual ou novo turno Lovable; evidências preservadas e trabalho concluído não repetido.

## Defesa adicional contra elevação e exposição indireta, proposta independente

Titular pediu buscar/implementar solução segura preservando arquitetura. Reancoragem155/39cb9ef e main/eedf922, sem avançar branch nem sobrescreverWIP do outro executor. O GATE158 existente permanece fonte canônica; este delta acrescenta controles de catálogo somenteleitura ao preflight antes de qualquerAuth/DDL.

HipótesealternativaHTTPprivado descartada sem publicar/executarDDL: fonteprimária pramsey/pgsql-http SHAee52345b5929f63a3871685f85974f34b5fa8508/http.c linhas1278–1281 força FOLLOWLOCATION1/MAXREDIRS5 emPOST; a listaSQL de opções não permite desligá-lo. Não trocar persistência de token por risco de transmissão emredirects. Testes locais da pesquisa não contamcomo solução operacional.

Plano mínimo desta defesa: acrescentar um booleano estrito client_attack_surface ao metadataSQL existente. Deve exigir duas rolescliente presentes, semLOGIN/SUPERUSER/CREATEROLE/CREATEDB/REPLICATION/BYPASSRLS, semmembership emrolesSQL/administrativas; semUSAGE/CREATE deVault ouCREATEpúblico, seteassinaturas exatas de transporte/token/worker fechadas ao cliente, nenhumaexposição direta pública deVault/net porviews/materializedviews ourotinas executáveis. O teste inclui permissões decoluna para evitar fuga porSELECTparcial. A aplicação destes controles não lê tokens, bodies oulinhas de net, não altera qualquergrant ourole e não representaosserviçosadministrativoscomo usuárioscomuns.

Critérios: novoRED aceitaausência/nãoaplicação da guarda; GREENrecusacatálogo inseguro antesdequalquerrequestAuth; consultasSQLreais HML somenteleitura; casosnegativosSQLemPostgreSQLlocal comACLs sintéticas; suítetotal/guards/revisãoindependente. Guard/public/Restore/backupnomesmoHEAD continuamobrigatórios; nenhuma conclusãoPASSmaterialouzerorisco. O conjunto não é análise transitiva completa de qualquerSQLdinâmico nem substitui scannerSQL/RLS/negativosAPIautenticados.

Arquitetura preservada: frontendContaOS, API/RPC/Edges/Auth/RBAC/RLS, PostgreSQL/Storage/Auditoria noSupabase. NenhumaEdge extra oualteraçãofrontend317/PROD. Trabalhodohelperdecontenção ecorreçõesJWT/positivoAPI pertencemaosoutrosexecutores e são reutilizadossematribuiçãoindevida.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: N/Avisual, deltacatálogo/readiness comdoisarquivosjáGATE158, semLovable, semschema/migration/roles/Authconfig/Edges/fixturesalheias.


### Evidências próprias e reancoragem pós-integração155

Base agora79aec0002712df1a2262bdee9185cc406ba21eb2, árvore idêntica ao39cb9ef testado, avançada localmente porFF puro sem tocarbranch155. Integração155 e deployHML42475332474 pertencem a outroexecutor. LeituraGitHub confirma passos WorkerAPIboundarybefore/afterdeploySUCCESS e artefato13614902486/digestba7d49fd5921faada31db7042d33133757b0424802414200771e302863a77292. SELECTs próprios somenteleitura confirmaram pg_net emextensions e fixture152 jobconcluído/tentativas1; essafixture não é prova própria nemlote5/3/5.

Neste delta: REDausênciaguarda client_attack_surface eREDausência deexecuçãoSQLnoRestore reproduzidos; implementaçãoGREEN9/9testesdirigidos e339/339Nodecompletos,semSKIP. SQLHMLreal antes/depois da instalação executado somenteleitura retornou client_attack_surface=true,semexportarsecretoulinha dafila.

A revisãoindependente encontrou Important no primeiro scanner(prosrc não cobre corposSQLpadrão). ReproduzidoRED real com funçãoSQL RETURN diretamente referenciando tabelaVault sintética; corrigido por pg_get_functiondef comCASEprokindf/p/w, evitandoaggregates. RegressãoPostgreSQLlocal PGlite0.3.14:16/16 cenáriosPASS,incluindoLOGIN/SUPERUSER/CREATEROLE/BYPASSRLS,membershipadministrativa,VaultUSAGE,CREATEpublic,endpointausente/aberto/overload,viewcomgrantdetabela/coluna,funçãoponte/corpoSQLpadrão eviewsegura. Nenhumcanário ouobjeto dessesfoicriado emHML.

Revisor confirmou Importantresolvido porinspeção. Observação menor: timeout/psqlausente deveria produzir recibosanitizado. Corrigida comrecusafechada deOSError/TimeoutExpired; RED retirando a captura, GREENexecutandocódigo REALextraído do stepCI com dependênciaSQLindisponível. Nemstdout/stderrSQL nemtracebackpublicados, JSONcontémsomentestate/head/catalog_only.

Acrescentado sexto caminho .github/workflows/restore-isolado.yml: disparosPR/push para os testes novos e passo Workerclientprivilegecatalog apósreset antesaceitação. Executa MESMAconsulta emBEGINREADONLY/ROLLBACKnoPostgresLOCALreal eexigesomente t comexit0. Não remove/skiptestes ouproteções; as provaslegadas decontenção/backup/material permanecem. O scriptPGliteé suplementolocalcomdependênciatemporária fixada, nãodependênciadeproduto nemcertificaçãoHTTP/HML.

Estado: código eprovaslocaisconcluídos; CIremoto/revisãofinal/integraçãodestedeltacontinuamobrigatórios. Não declara segurançauniversal, resoluçãodequalquerSQLdinâmico/análisetransitivacompleta,5provasmateriais,CRUDouV1. NenhumanovaEdge/DDL/grant/role/Authconfig/Storage/frontend/PROD alterados.


Reancoragem concorrente: checkpoint160/main a1ecb48546e1298d1d35e4f4e4d8b76d4eb59e57 preservado integralmente antes desta seção. Manifesto mantém verified_receipt e todas as evidências alheias; merge normal de b7a9e6d+a1ecb48, sem force/CAS sobre branches alheias. Novos checks precisam corresponder ao HEAD reancorado.


Complemento de integração antes de publicar HEAD final: o preflight MATERIALDOCUMENTOS também reutiliza client_attack_surface_sql do mesmo módulo, semduplicarconsulta. Red no prepare REAL com chave nova/ausente reproduzido; exige booleanaTrue antesAuth/fixture. Dois caminhos adicionais já previstos noGATE158, p0_crud_global_hml.py e p0_crud_global_protocol.test.mjs, total8caminhos. A mudança também faz o public-probe PR legítimo disparar peloescopoexistente, semalterar workflowpúblico oupermissões. HEAD393637f anterior sóiniciouguard/Restore e não possuía public-probe; nenhumcheckanterior será usado para liberarHEADfinal.
