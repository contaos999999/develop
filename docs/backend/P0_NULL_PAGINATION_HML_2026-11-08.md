# Correção de paginação NULL em HML, 08/11/2026

## Plano mínimo autorizado de segurança

Titular determinou buscar/implementar solução segura preservando arquitetura e, na última instrução, excluiu proteção de senha vazada desta entrega. Não alterar plano, cobrança ou configuraçãoAuth.

Base maina9abcdf54099c9d3fba8681ccca1b5c9180aef95/PR161integrado. A revisão defensiva independente dos10avisosSECURITYDEFINER confirmou autorização intencional, sessão/tenant/RBAC e search_pathqualificado; identificou defeito concreto: comparações comNULL não rejeitam argumento eLIMITNULL remove limite de consulta. Não foi observado acesso cruzado entre organizações; o risco é consumo semlimite noescopo autorizado.

Dois objetos: privado.obter_documentos_competencia_v115(uuid,integer,integer,integer,integer) e public.obter_analise_competencia_v116(uuid,integer,integer,integer,integer,integer,integer,text,text,text,text,text). SQLHMLsomenteleitura confirmou corpoMD576611a9a23e0d9bebf09aa1e0aa44093 e84aaf91cce67651a5cbb3ecd16f8eaa2, ambosownerpostgres/SECURITYDEFINER/search_pathvazio; ACLs permanecem protegidas. Fontes da migrationRBAC jáaplicada correspondem BYTEaoscorpos atuais porMD5. Nunca editar migrations aplicadas.

Nova migrationCLI2.81.3 gerada como20261108114652_p0_null_pagination_guard.sql. Transação única exige corposanteriores exatos antes deCREATEORREPLACE, preservandoassinaturas,owner,ACL,STABLE/DEFINER/search_path, toda autorização e consultas. Acrescenta somente rejeição explícita deNULL nos4argumentosinteiros dosdocumentos e6daanálise; mantém códigosPT400/mensagens/intervalos existentes e filtros textuaisNULL permitidos. Mudança de corpo concorrente causaFAIL antesdegravação. NenhumGRANT/REVOKE/policy/tabela/Edge/cron/Storage/secret/frontend/PROD.

## Provas e aplicação

TDDRED comnovo contrato ausente; Nodecompara definições completas contra fontes canônicas com SOMENTE as duas substituições aprovadas. PostgreSQLlocal avalia predicates reais comNULL,negativos/zero/acima100/50 e limitesválidos. Suítehml_acceptance recebe10negativosNULL e2positivos pelasRPCsreais com fixtures/session/RBAC existentes, além de negação de outrotenant antesdevalidarparâmetros, terminandoROLLBACK. Suítecompleta/10guards/Python/diff/revisãoindependente, guard/public-probe/RestoreSQL/backup SUCCESSnomesmoHEAD antesready/mergenormal/CAS. NenhumFAIL viraPASSporremoção deassertions.

Apósmerge, aplicar somente esta migration via deploy_one canônico, expected_source_sha e SHA256 fixados, umaúnicapendente eparidadehistórica. ConfirmarcatálogoHML com novoscorpos/owner/ACL/assinaturas/search_path e NULLrejeitado nosvalidadores; nãofabricarsessão nemlerJWT/segredos. Provasmateriais reais dependemdo próprio rito148. Reversão somenteporoutramigration revisada, semreabrirpaginaçãoilimitada oualterarhistórico.

FontePRD: NFR009/paginação, V1DOC/V1AUD; mantém formato deAPI e autoridadebackend. Não certificar segurançauniversal,CRUD,V1 ou iniciarV2.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: N/Avisual, deltadevalidaçãoSQLmínimo semLovable/frontend317/PROD; Gates existentes preservados, sem novos serviços ou créditos.

## Evidência local própria

RED reproduzido: novo contrato falhou por ausência das duas definições na migration vazia gerada por CLI. GREEN:340/340 testesNode completos,0falhas/skip;29/29 avaliações PostgreSQLlocal dospredicados reais;10guardsPASS e diffchecklimpo. Teste de preservação compara somente dois corpos completos, com extração pelo fechamento real dollarquote, evitando capturar rotina adjacente. A migration contém exatamente2CREATEORREPLACE e preconditionCAS dos2corposanteriores. CasosSQLreais14 aguardam Restore remoto, não declaradosPASS localmente.

## Reparação de infraestrutura reproduzida

HEAD3ad2d4e: guard42477728912/public42477728986/backup42477729003PASS. Publicartifact13616280979/digestf1e63e8d2bcb11a6f0fb9fa1662d300f363d62f41abc74791aca8c0c2d9aad40 ebackup13616810404/digest8e199fc32c8a274a4c04eb1bdce745438d8e81fe92143f3483984799c824b432 baixados/conferidos. Rebuild128722692129 falhou no downloadsetupCLI504 antesSQL; rerun128724405530 também reproduziu dois504. Não liberar3ad comessasprovasparciais.

Reparo mínimo sétimocaminho restore-isolado: instalar pacote oficialnpm supabase@2.122.0, mesma versão anterior, comscriptsdesativados e prefixotemporário próprio. Exige saídaexata2.122.0 antes de adicionar aoPATH e novamente no próximo passo. Distribuição oficial testada localmente retorna2.122.0. Semcontinue-on-error,semfallbacksilencioso,semalterarcheck/SQL/proteção/versão; stepinstaller legado dobackup permanece intacto. NovoHEADexige novamenteguard/public/rebuild/backup e revisão. NenhumHMLwriteenquantobloqueado.
