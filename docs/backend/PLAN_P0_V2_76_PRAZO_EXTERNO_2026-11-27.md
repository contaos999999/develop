# PLAN P0 76 · Prazo externo parametrizado

27/11/2026. O regular 76 permanece a tarefa elegível. O [recibo #247](https://github.com/contaos999999/develop/pull/247) comprova o vínculo do parecer e a extração. O [PLAN frontend #848](https://github.com/contaos999999/contaos-hml-control/pull/848) aguarda reconciliação do requisito V2-DIL-004, atômico 028. [Checkpoint oficial](https://github.com/contaos999999/contaos-hml-control/issues/708#issuecomment-7228564614)

## Causa comprovada em HML

As funções pública e privada de registro de parecer existem e nenhuma consulta a configuração de diligência do contrato. O corpo privado replica `p_prazo_resposta` ao abrir ciclo. Sem data informada, o vencimento fica nulo mesmo com a regra normativa de cinco dias corridos da configuração padrão. O PRD exige verificar o vencimento pela regra configurada e preservar a análise jurídica em situação ambígua.

## Escopo

- Preservar a assinatura, as ACLs, a sessão, o escopo da apresentação, a aprovação do arquivo, a concorrência, a idempotência e a extração já certificadas na #246. A migração substitui somente o corpo privado do registro.
- Na abertura de ciclo não favorável, aplicar a data explicitamente informada. Sem data informada, aplicar o número inteiro não negativo de dias corridos de `contratos.configuracao_diligencia` no mesmo contrato e organização. Usar a data de recebimento registrada pelo servidor, no calendário de negócio America/Sao_Paulo. Preservar o prazo persistido de ciclo existente.
- Para configuração indisponível ou sem regra de calendário reconhecida, manter o prazo pendente de confirmação humana. Não inferir contagem em dias úteis nem feriados a partir de convenção não definida. O recebimento continua vinculado ao documento e à apresentação. Registrar em auditoria o prazo informado, o prazo aplicado e a origem. Repetir a mesma intenção recupera o resultado persistido mesmo após mudança da configuração.
- Provar RED e GREEN com cálculo padrão e ajustado, prazo explícito, pendência por regra indefinida, escopo, auditoria, replay após alteração da configuração e testes da BUILD #246. Conferir catálogo e restauração. Revisar no HEAD final, integrar via branch protegida e aplicar apenas a versão autenticada em HML com conferência da paridade.

## Caminhos

Este PLAN muda `docs/backend/PLAN_P0_V2_76_PRAZO_EXTERNO_2026-11-27.md` e `docs/tasks/active-task.json`. A BUILD e as provas limitam-se aos caminhos:

- `supabase/migrations/20261127213828_p0_v2_76_prazo_externo.sql`
- `supabase/tests/v2_76_prazo_fixture.sql`
- `supabase/tests/v2_76_prazo.test.sql`
- `supabase/tests/v2_76_prazo_catalog_pins.json`
- `supabase/tests/v2_76_parecer_run.py`
- `supabase/tests/history_catalog_compare.py`
- `.github/workflows/p0-v2-76-parecer-code.yml`

O recibo posterior usa `docs/backend/RESULTADO_P0_V2_76_PRAZO_EXTERNO_2026-11-27.md`. Rollback por nova PR e migração corretiva versionada, preservando pareceres e datas persistidas. CLI 2.81.3. HML parte de 143 versões. CODE_FIXTURE. LIVE `NOT_RUN`. PROD `NO-GO`.
