# PLAN P0 49 · Idempotência e comprovante de reapresentação

27/11/2026. Autorização do titular confirmada para PLAN próprio e correção HML. [Recibo 48 #844](https://github.com/contaos999999/contaos-hml-control/pull/844), [plano executivo #825](https://github.com/contaos999999/contaos-hml-control/pull/825) e [checkpoint do preflight](https://github.com/contaos999999/contaos-hml-control/issues/708#issuecomment-7222679419).

## Causa e alcance

O catálogo do HML confirmou `privado.registrar_reapresentacao` com corpo MD5 `97dd7b2a58a9fa3c06939228f6f0ddc4`, correspondente à migração `20261102021238_0048_gate_context_hash_checks.sql`. A reapresentação repete o recibo por organização e chave. O vínculo vigente do comprovante confere a existência do arquivo por chave estrangeira. O gatilho do contrato incide sobre o registro principal.

## Contrato

- Manter as assinaturas, ACLs e valores opcionais públicos atuais. Conferir sessão, acesso e escopo do ciclo antes de decidir a repetição. Vincular o retorno ao ator, contrato, competência, rodada e dados da intenção. Aceitar repetição legada apenas quando o recibo persistido comprovar a correspondência. A transação produz um pacote e um protocolo por intenção, incluindo sob concorrência.
- Para um comprovante informado em nova gravação, conferir no servidor organização, contrato e aprovação do arquivo, com leitura protegida na mesma transação. Conservar os recibos históricos, a reanálise, o hash do contexto, o portão e a decisão humana vigentes. Preservar os registros de I09/I10 e comprovar o resultado do assistente posteriormente em V2-06, pelas jornadas J02, J09, J10 e J12.
- O RED e o GREEN usam PostgreSQL isolado e dados sintéticos. Provar nova gravação válida, repetição exata, comprovante fora do escopo, estado de segurança do arquivo, rejeição de pedido divergente, papel e sessão, concorrência, rastreabilidade no pacote e no recibo. Conferir reconstrução, histórico, catálogo e arquivos exatos antes da aplicação autorizada da migração em HML.

## Caminhos autorizados

Este PLAN altera `docs/backend/PLAN_P0_V2_49_REAPRESENTACAO_2026-11-27.md` e `docs/tasks/active-task.json`. BUILD e evidência nos caminhos:

- `supabase/migrations/20261127160826_p0_v2_49_reapresentacao_escopo.sql`
- `supabase/tests/v2_49_reapresentacao_fixture.sql`
- `supabase/tests/v2_49_reapresentacao.test.sql`
- `supabase/tests/v2_49_reapresentacao_run.py`
- `supabase/tests/v2_49_catalog_pins.json`
- `supabase/tests/history_catalog_compare.py`
- `.github/workflows/p0-v2-49-reapresentacao-code.yml`

Recibo posterior em `docs/backend/RESULTADO_P0_V2_49_REAPRESENTACAO_2026-11-27.md`. Migração gerada com Supabase CLI 2.81.3. Backend de referência `6998cf2625c3affe0313e2472ffaa0de78693c3a`, HML com 141 versões. CI, revisão assistida no HEAD exato e confirmação na main antes de aplicar a migração canônica. O frontend tem PLAN próprio após a leitura HML e o recibo backend. LIVE `NOT_RUN`. PROD `NO-GO`.
