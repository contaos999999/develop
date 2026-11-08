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


## Proposta independente: aborto atômico antes do COMMIT

Base do delta: PR155/d5d79b626a8236f3ed0a618d2ae5d733f311aac7. Main lida diretamente: a779e75a6985f63bba9dcc5019b48f6b6aed38d7; checkpoint157 mantém bloqueio de segurança. Este executor não modifica a branch155 nem atribui a si commits ou provas anteriores.

Defeito adicional: a migration ainda não aplicada executa CREATE e quatro REVOKEs, mas chega ao COMMIT mesmo que PostgreSQL emita WARNING e não retire privilégio algum. Teste posterior detecta o problema quando a extensão já foi confirmada. A proteção preventiva precisa ocorrer dentro da mesma transação.

Plano mínimo para revisão: manter os quatro REVOKEs e acrescentar um DO antes do único COMMIT, verificando assinatura e objetos obrigatórios, USAGE/CREATE de schema, todos os privilégios de tabela e coluna, sequências e funções para anon/authenticated, inclusive herança PUBLIC, mais acesso do scheduler postgres. Qualquer falha levanta 42501 com mensagem fixa, sem ler filas, headers, Vault ou segredos. Não captura exceção para continuar. Não altera owner, role, catálogo, policy, cron ou Edge.

Esse complemento fortalece GATE153 sem substituir a exigência de isolamento. A alternativa DataAPI do checkpoint157 permanece sem implementação/aplicação. A mudança textual do contrato exato da migration exige revisão do complemento antes de integração ao PR155; este delta fica em PR separado e DRAFT. A migration não consta de main nem foi aplicada no HML, portanto não reescreve migration aplicada. Os quatro comandos de REVOKE e as oito assertions posteriores permanecem exigidos.

Validação: reproduzir RED por ausência da barreira, testar o bloco SQL em PostgreSQL local com ACLs sintéticas abertas/fechadas e falhas individuais, verificar rollback real, executar suíte Node completa e dez guards. O PostgreSQL de teste não prova pg_net gerenciado, firewall nativo, Restore ou HML. Exigir CI e revisão independente do mesmo HEAD. Restore no provedor continuará bloqueado de forma antecipada até solução suportada; nunca converter esse bloqueio em PASS.

Pendência de decisão técnica: o provedor não suporta as revogações exigidas. A opção documentada157 aceita logins SQL diretos como fronteira administrativa confiável e mantém net fora da DataAPI, mas muda a condição de segurança. A instrução genérica de resolver não é registrada como aceite específico desse risco. Sem decisão específica ou solução que mantenha a proteção, nenhum deploy ou prova material é liberado.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: impacto visual N/A, somente barreira SQL preventiva e regressão; nenhum frontend ou turno Lovable, sem bypass de checks, sem PROD e sem certificação V1/CRUD.


### Evidências desta execução para a barreira atômica

- Baseline no HEAD155 d5d79b6: node --test, 329/329 PASS.
- RED novo: teste worker ACL failure, 0/1 PASS, ausência da barreira antes de COMMIT.
- Primeiro ensaio PostgreSQL local detectou 42809: otimizador podia avaliar has_sequence_privilege em relação não-sequência apesar do filtro AND. Correção mínima usa CASE por relkind, preservando a exigência de privilégio efetivo. Falha não foi aceita como isolamento.
- GREEN: node --test, 330/330 PASS, zero skip/cancelamento; protocolo71/71 na revisão técnica independente; dez guards e git diff --check PASS.
- PostgreSQL local PGlite@0.3.14: 13/13 cenários PASS, reexecutados pelo revisor. Cenário fechado confirma COMMIT; outros12 confirmam 42501, transação25P02 e COMMIT convertido em ROLLBACK da sentinela. Casos: PUBLICschema, CREATEauth, tabela, coluna, resposta, sequência, função, roleherdado, tabelaextra, funçãoextra, objetoausente e assinaturaausente.
- Regressão reproduzível: instalar @electric-sql/pglite@0.3.14 em diretório temporário com --ignore-scripts, definir CONTAOS_PGLITE_MODULE como fileURL de dist/index.js e executar node supabase/tests/worker_atomic_acl.postgres.mjs na raiz. Dependência apenas de teste local; nenhuma biblioteca de produto adicionada. O teste usa objetos/ACLs sintéticos no mecanismo PostgreSQL, sem pg_net instalado.
- Revisão técnica independente read-only sem Critical/Important; contexto normativo integral da revisão ainda pendente no momento deste registro. Nenhuma aprovação de merge/aplicação derivada dessa revisão técnica.
- SQL HML desta execução: consulta de catálogo somente leitura confirmou netausente; pg_cron em pg_catalog, httpextensiondisponível masnãoinstalada; crons4–9 ativos. Não consultou conteúdo de filas/headers/Vault, não invocou worker e não criou fixture.
- Não houve novas provas materiais5/3/5, deploy, merge, alteraçãofrontend317 ouPROD. Continuam condições técnicas ainda não cumpridas. Este delta não resolve a limitação da plataforma nem substitui a decisão documentada157.
