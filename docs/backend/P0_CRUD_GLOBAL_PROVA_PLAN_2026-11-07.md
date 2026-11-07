# PLAN P0 — prova privada de fechamento CRUD global V1

Titular autorizou execução integral: auditar/implementar/provar operações aplicáveis de todo frontend mantendo Supabase e controles. PLAN frontend289 registra28rotas/18domínios/68rótulos e fontes originais comhash. Tipos congelados, backenddeproduto e PROD intocados. Este plano é somente harness de prova; não cria RPC/migration nem declara CRUDglobal pronto.

## Dependências e âmbito
Baseline backenda6399adc39e984293c14d7adcf106b00ab76ce50; frontend6363edeb. Falha real CRUD-LISTA-001 está em correção por PLAN289/GATE290 separados. Não executar prova global antes de fixfrontend integrado comZeroDrift/TesteC/protecttypesSUCCESS e pinexato no manifesto; não usar branch como substituto de main. ProvaV117 run42391662453 PASS preservada, não repetida como suposta prova de CRUDglobal.

## Arquitetura do runner
Workflow dedicado, scope job contentsread lendo tarefa/fase no SHA do restore; jobprivado apenas P0-CRUD-GLOBAL-HML-20261107/BUILD_PROVA_PRIVADA_CRUD_GLOBAL e origem ownpushmain/restoreSUCCESS. Guard/restore/backup exigidos no SHA exato/livemain; frontend pinintegradoe3checks. Semdispatch/deploy. Frontendfonteexata emVite/Chromium/axe fixados, installfrozen. Preflightpúblicosemcredenciaisantesfixtures.
Python único guardião de banco/AuthAdmin; Node/Chromium recebe ambiente porallowlist semDB/AUTH_ADMIN_KEY/GH_TOKEN/service_role. SessõesGoTrue próprias pelotesteeUI; semJWTforjado, mocks, routeinterception, HAR/trace/storageState. Credenciais somenteRUNNER_TEMP privado, nuncaGit/artifact. APIAuthAdmin exclusivamente cria/banefix­tures próprias; nuncainsert/updateauth.users porSQL para provisioning. Reutilizar recuperação de criaçãoambígua porintent_nonce+emailpróprios játestadaV117. IDS/intenções persistidos antesderequests/seed; SQLseed mínimo emorgs/contratos/fontes/rascunhos próprios, nuncaALTER/RLS/grants/DDLconfig. Sem matrizglobalpermissãoalterada ou identidadepreexistente.

## Jornadas e afirmações
- Cadaação aplicável da matriz temcaso, botãoreal, chamadaAPI protegida, asserçãoUI e confirmação de persistência/auditoria. Registrar estágio/domínio/ação ePASS/FAILsemvaloresprivados. Não contarpáginaabrindo comoCRUDPASS.
- Criar/consultar/editar/transitar organização/contratante/contrato; exclusões proibidas ficamN/Acomfonteretenção, não botãoinventado. MASTERsemvínculo eadmin/leitor/tenantB, permissão revogada/contextodivergente eCAS/replay onde contrato exige.
- Normativa/orçamento/listas: versõesrascunho, alterações/remoçõeslegítimas deitens/linhas, publicação/fechamentovigência/situação, recarga eimutabilidade. Prova da falha409/refetchtransitório usa duasabas reais no mesmocontexto, escritaconcorrenteviaUI e offline/online navegador sem respostas falsas; draftpreservadoe backendsemnovoescritadurantefalha.403permanecenegado.
- Documentoscontrato/competência: arquivoPDFbenigno próprio poruploadStorageassinado, confirmaçãosegurança eprocessamentoworker quandoexigido; nova versão, evidência/download. Metadadoseedednãoéuploadfísico. Nenhumstatusforçado para anunciarworkerPASS.
- Competência/análise/revisão/parecer/apresentação/protocolo/histórico/admin/auditoria: somenteoperaçõesV1autorizadas; decisãocríticaRPC, semupdateclient/statusforjado. Módulo/tela imutávelnão ganhaCRUDgenérico. Não desenvolverV2–5 para preencherinexistênciadeDELETE.
- 28rotas e quatro larguras1440/1280/768/390, doistemas, navegação/foco/teclado/overflow/axe e capturas sintéticassemcredenciais. Registrar incompletos e auditoriamanualseparados; axe/captura não certificamWCAGintegral. ChamadasIA/worker somente dentrofixtures e contratos existentes, semmudarprovedor/config.

## Recuperação, segurança e limpeza
finally e alwaysindependente banemcontas/revogamsessões/MASTER/vínculos e inativamorgs próprias, incluindoorgs criadaspelaUI recuperadaspelo nonceúnico eatorpróprio. Não depender sódeIDsrecebidos apósresposta. Mensagens/execuções próprias isoladas e recuperadas por IDs/escopo; preservar auditoria/documentos/versões, nunca apagarhistórico para esconderteste. Quarentenaverificada contagens eausênciadeacesso; falhalimpeza oucriaçãoambígua mantémFAIL. Arquivo/projeto/caminhoHML allowlist; semcomandosarbitrários. Browserfailnão interrompecleanup.
Artifacts somente relatóriosporallowlist e screenshots de negócio sintético seminputscredenciais. Errosbrutos/stackSQL/URLsassinadas/respostas/tokens/fixtures/senha/dumpfora; diretórioprivado apagado após evidênciasecleanup. Nenhumtokenadministrativo podeviajarnode/browser/artefatos.

## Rito e critérios
PLAN→guard/merge→GATE separado→guard/merge→RED protocolo/canários/cleanup/ambiente/pin/scope e funcional ondeaplicável→BUILD→GREENlocal/suites/restore/backup/probe→revisão→merge→provaHML→correções governadas→GREENecheckpoint. TesteCindependente não edita implementação. Registrar nãoverificados/falhassem inventarpercentual/100%; globalPASS sótodasoperaçõesaplicáveiscomprova, retençãojustificada e0FAILobrigatório. SemcertificarV1porCRUDisolado. Rollback sóharness/workflow, não reverterdadossemrisco nem reimplantarprodutos.

## Caminhos fechados / ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Os8caminhos exatos do manifesto. Nenhumsrc/public/typesschema/migration/RLS/Edge/PROD. Componentes/tokens/BRAND01 preservados. GitHubdireto, pipeline/normasjáaprovados reutilizados; não consumemLovableBUILD. Economia não reduzsegurança/testes/evidência. Arquivoespecíficodecorreção deproduto requeroutroPLAN/GATE; esteharnessnãodispensaaprovaçãodecisãomaterial inédita.

## GATE separado — validado

PLAN120 integradof19e3e6375574994cc17fcdc9a9d72d13d89f252 apósguardSUCCESS. FrontendFIX291 HEAD74cd8ef9aa15bd19d33ce1b5d2dc6515f6066db8 integrado46b28e3ae8588b78f32e7f7be2d9221ed5e940d7 comZeroDrift/TesteC/protecttypesSUCCESS,1150testeslocais eCRUD-LISTA-001tratado. Pinexatoaprovado paraexecução, semtrocarporbranch.

Revisão técnica: jobprivado não fazdeploy; exige sourceSHA/main eguard/restore/backup, pinfrontendintegrado/3checks, namespaceHMLexato. AuthAdmin/banco somentePython; browsercomambienteallowlist ecredenciaisprópriasGoTrue, fixturesporAPIoficial/intentrecuperável, semSQLauth.users. finally+always independentes eartefatos porallowlist/canários. Testesdematriz porjornada podemserexecutados emlotes paraisolarfalhas, mas nenhumlotepartial viraPASSglobal; faltantesmantêmNO_GO epróximafila. Não omitir novasfalhas, nãofazerstatus/workerfalso. CorreçãodeprodutoforaAPIexigePLAN/GATEpróprio. Nenhumriscoineditointransferível identificado; autorizaçãorotineira do titular vigente. BUILD sóapósCIeintegraçãodesteGATE.
