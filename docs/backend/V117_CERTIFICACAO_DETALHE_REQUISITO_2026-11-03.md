# Certificação backend — Prompt 38 / V1-17 Requisito: detalhe e evidências

Data: 03/11/2026
Ambiente: Supabase HML gklhhhyosgasnyoxlrui
Status: BACKEND V1-17 CERTIFICADO
PROD: intocado

## Contrato canônico implementado
1. Nova RPC de leitura public.obter_detalhe_requisito_v117, JSON versionado schema_versao v117-v1, argumentos p_id_competencia, p_id_requisito, offsets e limites independentes de evidências/histórico/apontamentos. Fonte GitHub: supabase/migrations/20261103163000_v117_obter_detalhe_requisito.sql, commit 6c4435e323e4e0dc993679ce4491245122db63a3. HML: versão 20261103172929 v117_obter_detalhe_requisito.
2. Hardening transacional em privado.solicitar_reanalise_requisitos(uuid,uuid[]) preservando a API pública. Fonte GitHub: supabase/migrations/20261103163100_v117_reanalise_requisitos_concorrencia.sql, commit 6c75878fb978ecd700bbaf510a1731ae52fb2df9. HML: versão 20261103172945 v117_reanalise_requisitos_concorrencia.
3. REST HML autenticação: EXECUTE authenticated=true, anon=false em leitura e reanálise; segurança do detalhe exige auth.uid(), sessão ativa, acesso real ao contrato e perfil permitido; vínculo simultâneo de requisito ao id_competencia, id_contrato e id_organizacao. Objetos de negócio existentes com RLS preservada. Nenhum RLS/Auth/Edge/Storage/PROD alterado.
4. A leitura usa somente dados canônicos, exibe resultado da última execução e o resultado mais recente do requisito separadamente para reanálise parcial. N/A válido exige fundamento preenchido e evidência do resultado recente, conforme o portão backend. As evidências preservam versão/hash/página/trecho; id_arquivo só é exposto para vínculo verificado versão/contrato/organização, sem signed_url. Download final continua exclusivamente na Edge storage-sign-download certificada e reutilizada pelo frontend, não nesta RPC.
5. Mecanismo deterministico/semantico/humano/nao_identificado classificado no backend pela precedência documentada na V1-16. Três paginações server-side (25 por página), sem N+1 no navegador, com histórico imutável.
6. Reanálise incremental: bloqueio na linha de competência antes da inspeção de job ativo; lista UUID de requisitos ordenada e validada no tenant; repetição exata da seleção parcial retorna o UUID existente sem UPDATE; seleção diferente ou job global concorrente gera PT409; nova execução recebe requisitos_afetados antes de COMMIT, com evento de auditoria. Worker queue-worker-ai consome este campo e filtra a lista a processar. Preserva a restrição única de uma execução pendente/processando por competência.

## Provas diretas HML (fixtures em BEGIN/ROLLBACK)
- PASS_V117_NO_RESULT_ROLLBACK: sem execução, resultado nulo, parser versão/paginação e requisito correto.
- PASS_V117_NA_HISTORY_PAGING_NEGATIVE_ROLLBACK: N/A com fundamento e evidência = válido; sem evidência = inválido; reanálise parcial não apaga resultado histórico; última execução sem esse requisito -> resultado_atual=null; mecanismo explícito; histórico duas execuções com offset e ordenação; PT400/404.
- PASS_V117_INCREMENTAL_CONFLICT_IDEMPOTENCY_ROLLBACK: primeira solicitação parcial; repetição idêntica mesmo UUID; seleção diferente PT409 e não sobrescreve requisitos_afetados; job processando idempotente, conflito diferente; vazio/inválido PT400; falta de sessão 42501; zero segundo job.
- PASS_V117_TENANT_AB_SESSION_CROSS_SCOPE_ROLLBACK: UUID de requisito de outra competência PT404; sessão sem vínculo com contrato rejeita leitura/escrita 42501; sessão forjada 42501; sessão ausente 42501.
- PASS_V117_AUTHENTICATED_REAL_ROLE_ROLLBACK: RPC de leitura e escrita funcionam sob papel real authenticated, não apenas como postgres administrador.
- PASS_V117_DOCUMENT_VERSION_LINK_ROLLBACK: id_versao_documento da evidência resolve id_arquivo com vínculo org/contrato/versão, sem URL pública.
- Verificação pós-rollback: zero registros residuais com identificadores temporários V117_% no HML.
- NOTA: primeira tentativa do teste N/A produziu falso negativo por empatar timestamps de duas execuções sintéticas na mesma transação; fixture corrigida para horários distintos, rerun PASS. Nenhum código alterado para contornar teste.

## Gates de GitHub
- Teste legado supabase/tests/reanalysis_authz.sql manteve o mesmo código 42501 e anti-enumeração; somente quatro comparações literais foram atualizadas para a mensagem PT-BR sanitizada. Commit 484196998cf88f7ef6b6279bb7b6255e235cff2e.
- Teste novo supabase/tests/v117_reanalysis_concurrency.sh em banco PostgreSQL DESCARTÁVEL do GitHub CI com duas conexões concorrentes e terceiro lock-holder, commit 96bc3b94d70d3cd2afc0791beaef9b98eea0a3a2.
- Restore Isolado atualizado com hunk mínimo de Teste 11, commit c238627034b5257e399d9d1d81e3d38e0b9df742.
- Run Restore Isolado 41686766086: SUCCESS. Etapas recriar DB, Teste 8 autorização, Teste 10 concorrência V1-07, Teste 11 concorrência V1-17, histórico e artefato: SUCCESS.
- Log Teste 11: CLIENTE_A=OK:<UUID>; CLIENTE_B=ERR:PT409; PASS_V117_CONCORRENCIA_REAL: dois clientes, um job parcial, conflito PT409, replay idempotente. O vencedor pode alternar por escalonamento, sem alterar a propriedade testada.
- Run ContaOS Zero-Drift 41686766756: SUCCESS.
- Run Verificar histórico HML 41684700623: SUCCESS no commit da migration; presença posterior das versões 20261103172929 e 20261103172945 confirmada via list_migrations no HML.
- Restore anterior 41684700465 FAIL apenas pelo teste legado exigir texto antigo apesar de 42501 correto; corrigido e Restore posterior 41685921517 SUCCESS.
- Zero-Drift intermediário 41685921428 FAIL por caminho manifesto com descrição literal; corrigido para caminho exato; verificação 41686122533 SUCCESS e novo gate 41686766756 SUCCESS.

## Avisos de segurança
Supabase Advisor detectou authenticated_security_definer_function_executable em seis wrappers autenticados (cinco existentes incluindo V1-16, mais a nova V1-17) e auth_leaked_password_protection desativada. O primeiro aviso é genérico para wrappers intencionais; para V1-17, auth/RLS/tenant/perfil e grants foram testados concretamente, sem autorizar acesso anônimo. O segundo é preexistente, não alterado nesta tarefa. Ver recomendações:
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Limites da certificação
Provas executadas na função HML com sessão real e papel authenticated, mais rebuild de DB em CI isolado. Não foi realizado um teste navegador com sessão real e documento físico no Storage; este pertence ao frontend V1-17. Nenhum dado de demonstração ficou em HML. A comparação completa com todas as condições de negócio fora do contrato V1-17 não é reivindicada.

## Conclusão
BACKEND V1-17 certificado em HML para iniciar PLAN/BUILD frontend, sujeito aos gates PLAN Lovable e Teste C separados, mantendo PROD intacto.