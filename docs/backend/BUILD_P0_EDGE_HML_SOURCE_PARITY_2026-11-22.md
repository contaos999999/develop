# BUILD P0 Edge HML: reconciliação das fontes canônicas (22/11/2026)

**Autorização de escopo:** PR backend #224 (PLAN integrado em `5b844be04f80b5e320e17666d3e659ff4ee7f574`) e PR #225 (manifesto fechado integrado em `1f72ad5f62de384dd8c073808be7418521742643`). **Sem deployment nesta PR.**

## RED confirmado antes do BUILD
- HML Supabase `gklhhhyosgasnyoxlrui`: 20 Edge Functions ACTIVE; a árvore GitHub possuía 19 entrypoints.
- `queue-worker-historico` HML v2, `verify_jwt=false`, com `validar_token_interno`, existia no provedor mas `supabase/functions/queue-worker-historico/index.ts` ausente na fonte `develop`. Contraprova histórica: consulta árvore de arquivos e lista de commits do GitHub não retornou fonte.
- `notify-user` HML v4: arquivo do provedor possui 1 LF final adicional ao Git; conteúdo funcional idêntico.
- `queue-worker-finance` HML v5: literal RTF publicado usa escape com semântica divergente e não detecta a sequência RTF real, enquanto o código GitHub tem o literal correto. A contraprova está no [comentário do PLAN #224](https://github.com/contaos999999/develop/pull/224#issuecomment-7073821597). **Não reduzir a fonte Git à versão vulnerável.**

## BUILD limitado desta PR
- Criado o arquivo `supabase/functions/queue-worker-historico/index.ts` copiando exatamente a fonte ACTIVE v2 obtida via API Supabase, sem substituições de chaves, método, autorização ou código.
- Alinhado apenas o LF final em `supabase/functions/notify-user/index.js` ao conteúdo ACTIVE v4, sem alteração funcional.
- Adicionado `supabase/tests/p0_backend_edge_source_parity.test.mjs`: inventário completo dos 20 entrypoints, contrato de token interno da fila histórica, negativa contra escape RTF vulnerável e LF de notificações. Tests locais não substituem prova do runtime Supabase.
- `queue-worker-finance/index.ts` não foi alterado: sua versão Git é a referência correta e requer **republicação exclusivamente HML controlada** após CI, revisão e gate de deployment separado.

## Critérios de aceite
1. CI `guard` SUCCESS, testes adicionais RED/GREEN e reconciliação exata do diff ao manifesto. Sem abrir escopo C13, sem DB, Auth, RLS, migrações, Storage, PROD nem token interno.
2. Parecer técnico independente elegível no HEAD final antes do merge.
3. Após merge, comprovar 20/20 fontes Git equivalentes em bytes às versões HML; qualquer mismatch exige deploy HML revisado de função exata + readback versão/hash/verify_jwt. Nunca preencher `CONTAOS_HML_EXPECTED_BACKEND_SHA` por mera igualdade de versão de migração.
4. O histórico de 138/138 migrações apenas comprova equivalência de versões, não conteúdo do banco. SHA backend publicado só PASS com provas cumulativas e vínculo de deployment imutável.

**Estado desta PR: BUILD de fonte, ainda não é CERTIFICAÇÃO de deploy.** Alterações de runtime no Supabase não executadas. `NO-GO` para ativação PROD, isolamento HML/RLS e `SEMANTIC_COMPLETENESS` global.
