# Worker documental HML: PLAN/GATE, 08/11/2026

## Causa comprovada e propriedade

Base main9af2c6a6b42ec175126d1bd2b2f33905742d8ad7, checkpoint152 preservado.148HEAD55c70 passouguard42451862873/public42451862890/Restore42451862920, porémmergenormal foi recusado405 após avanço152.148permaneceDRAFT; nenhumfixture destaexecução criado. EstaexecuçãoTrilhaB assume somente este reparo de runtime;145/147/150/152 e suasfixtures continuamdeoutroexecutor.

SELECTsread-onlyHML em05:46–05:49UTC: pg_net disponível0.20.4, nãoinstalado; schemanet ausente; crons5/6/9 ativos com falhas repetidas `schema "net" does not exist`. Jobdocumental de152 enfileirado/tentativas0, semalteração. Migration inicial20261101205846_0001 jáexige `create extension if not exists pg_net`. Funções cron oficiais usam net.http_post; a falta da extensão impede qualquer chamada ao worker. DestinoVault comparado somente no servidor: booleantrue para URLexataHML,2nomes desegredos presentes, nenhumvalor/token/hashsecretorecuperado. Inventáriooficial: queue-worker-documentsv4ACTIVE, autenticaçãointernapreservada; storage-sign-uploadv8/downloadv6ACTIVE/JWTtrue. Falha500 aorecuperarbundleworker foi preservada; inventário não prova paridade debytes.

Advisorshealthsemavisos; security/performance lidos semalterações oportunistas. Crons são observados, nunca invocados manualmente. Fonteoficial: https://supabase.com/docs/guides/database/extensions/pg_net confirma que CREATEEXTENSION habilita aextensão e cria próprionet; requests sóiniciam apóscommit.

## BUILD mínimo permitido após esteGATE integrado

Nova migration20261108060000_restore_document_worker_pg_net.sql contém exclusivamente `CREATE EXTENSION IF NOT EXISTS pg_net;`, repondo dependência canônica ausente. Não modificar migrationsantigas, funções deproduto,ACL/RBAC/RLS/Auth/Storage,cron/schedules,queues,payloads,configuraçõesVaultousegredos,workflows,frontend317 ouPROD. Não implantar outraEdge: workersjáexistentes são preservados, duasEdgesstoragejávalidadasnão sãoreimplantadas por este reparo. A ativação restaura o processamento normal doscronsjáativos emHML; não chamar consumidor global, não fabricar efeito e nãoalterar/cancelar job alheio.

Acrescentar preflightreadonly de extensão/schemanet/assinaturahttp_post/cronrápidoativo/destinoHMLexato antesde qualquer criaçãoAuth/fixture, somente noloteDOCUMENTOS. Falha deve impedir requestsadministrativos, com relatório sanitizado. Regressão no testeprotocolo existente deve executar métodoREAL/prepare e provar recusa antesdeAuth, alémdoteste da migrationexata eSELECTSQL noRestore. Apenas seis caminhos declarados no manifestoBUILD, semampliação tácita.

## Provas, integração e retomada

REDHML catalogado acima e REDunitário antesda implementação; GREENsuíteNodecompleta,10guards/sintaxe/diff,revisãoindependente semCritical/Important, guard/public-probe/Restore(rebuild+backup)SUCCESS no mesmoHEAD. Mergenormal comexpectedSHA/CAS, semforce/bypass. Aplicar somente migrationintegrada ao projetoHMLfixo pelo fluxo canônicoexistente,conferindoSHA/version/paridade. Antesdaaplicação repetircomparação booleana dodestinoHML, disponibilidade e ausência daextensão; nãoexportarVault.

Apósaplicação: conferir pg_extension/net/http_post,cronssucessoeHTTPcodes sanitizados pelo funcionamento normal, semlerheaders oucorpo sensível. Se existir nova falha deworker, preservarFAIL e corrigir por rito específico,semcertificar. Reancorar148preservando152/esteGATE eBUILD; repetirCI no novoHEAD. Somente então runner1TXTpublicadoPRIMEIRO+4locaisTXT/PDFv1/v2,5arquivos/3documentos/5versões,workerreal,negativos,5recibos ecleanuppróprio. Fixture152 permanecealheia e nãopode comporrecibos148.

Rollback exige nova migration/PR revisada, semDROP CASCADE, apagarfilas/objetos/evidências oucancelar trabalhosalheios; se aextensão jáestiverpresente, migraçãono-op e conferência obrigatória. Falha técnica mantém148DRAFT/semcertificaçãoCRUD/V1. NãoiniciarV2.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visualN/A, reparodeinfraestruturaHMLjáprevista, semLovable/frontend, semrelaxarguardsouautorização.
