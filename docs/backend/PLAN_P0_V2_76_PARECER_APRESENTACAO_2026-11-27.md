# PLAN P0 76 · Recebimento de parecer e vínculo à apresentação

27/11/2026. O P0 confirmou o regular 76 após o [recibo 49 #847](https://github.com/contaos999999/contaos-hml-control/pull/847). O [plano executivo #825](https://github.com/contaos999999/contaos-hml-control/pull/825) e a matriz de 26/11/2026 exigem vínculo com a apresentação exata e prova de extração. [Checkpoint oficial](https://github.com/contaos999999/contaos-hml-control/issues/708#issuecomment-7228238595)

## Causa e alcance

O corpo HML de `privado.registrar_parecer_contratante` (MD5 `f1af8bce4d1620aebf22df42e4ea3078`) coincide com a migração `20261101211140_0010_diligencias_v2.sql`. Ele confere acesso ao contrato da competência. A FK da apresentação confere existência e as FKs do arquivo conferem existência, organização e contrato. Esse conjunto não confirma a competência da apresentação nem a aprovação do arquivo. Uma chamada repetida cria outro parecer e pode criar outro ciclo e outra extração. O papel autenticado tem leitura de parecer sob RLS, com escrita pela RPC. O gatilho de extração de parecer não favorável já enfileira o trabalho e o [recibo I05 #235](https://github.com/contaos999999/develop/pull/235) comprova o vínculo do item produzido ao parecer e seu arquivo.

## Contrato

- Preservar a assinatura pública atual. Validar sessão, papel, competência, organização, contrato, apresentação e arquivo existente e aprovado no servidor. O mesmo ator e os mesmos dados para a mesma apresentação e arquivo recuperam o recibo persistido. Divergência de conteúdo ou vínculo falha sem novo efeito. Reusar a trava por competência e a trilha de auditoria existente.
- Auditar a apresentação, o arquivo e o ciclo exatos. Manter o gatilho e o worker certificados pelo I05. Proteger o status final e a geração da rodada na mesma transação da gravação do parecer. Acompanhar o processamento com uma leitura autenticada, limitada à competência, contrato e parecer acessíveis. Expor estado, tentativas e instantes sem retornar mensagens internas, caminhos privados ou conteúdo da fila.
- Validar storage privado a partir do contrato existente e provas CODE_FIXTURE. Preservar a operação de upload da V1. O frontend receberá PLAN próprio para lote de listagem, classificação, prazo, estado da fila e navegação V2-01, V2-02, V2-03 e V120.
- Provar I03, I04, I05, I16, C08, C09, C10 e C30 onde aplicáveis. A trilha V2-08 será fechada pelo regular 77. Exigir RED, GREEN, concorrência, regressão I05, restauração e prova de catálogo. CI, revisão assistida no HEAD exato, leitura da main e paridade HML antes do recibo.

## Caminhos autorizados

Este PLAN altera `docs/backend/PLAN_P0_V2_76_PARECER_APRESENTACAO_2026-11-27.md` e `docs/tasks/active-task.json`. BUILD e prova em:

- `supabase/migrations/20261127211427_p0_v2_76_parecer_apresentacao.sql`
- `supabase/tests/v2_76_parecer_fixture.sql`
- `supabase/tests/v2_76_parecer.test.sql`
- `supabase/tests/v2_76_parecer_run.py`
- `supabase/tests/v2_76_catalog_pins.json`
- `supabase/tests/history_catalog_compare.py`
- `.github/workflows/p0-v2-76-parecer-code.yml`

Recibo posterior em `docs/backend/RESULTADO_P0_V2_76_PARECER_APRESENTACAO_2026-11-27.md`. Migração gerada com Supabase CLI 2.81.3. HML referência 142 versões. CODE_FIXTURE. LIVE `NOT_RUN`. PROD `NO-GO`.
