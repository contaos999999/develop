# Certificação Frontend — V1-14 Competência: Visão Geral

Data: 03/11/2026
Ambiente: HML
Prompt: 35 / V1-14
Status: CERTIFICADO
PROD: intocado

## Escopo certificado

Tela `/competencias/:id` para resumo de preparação, análise, bloqueios e ações permitidas da competência.

O frontend consome exclusivamente a autoridade do backend para portão e ações. Não existe liberação local por percentual ou situação.

## Backend utilizado

RPC oficial certificada:

- `public.obter_visao_geral_competencia(p_id_competencia uuid) returns jsonb`

Certificação backend relacionada:

- `docs/backend/V114_CERTIFICACAO_VISAO_GERAL_2026-11-03.md`
- `PASS_V114_READ_ONLY_ALLOWED_ACTIONS`
- `PASS_V114_ISOLAMENTO_TENANT`
- `PASS_V114_100_NAO_LIBERA_LOCALMENTE`

## Frontend auditado

Repositório: `contaos9999/contaos-hml-control`

- Base V1-13: `8b62e506a8351fba9819afb1b4508be449be7228`
- SHA funcional auditado no Teste C: `b5fe91f31e70b37ecceacfc89ea79b6d17e1b642`
- SHA atual da `main` após limpeza do drift automático do turno read-only: `77ffd79195fedf8f4b30ff2c50c8ae43c9b89482`
- Comparação `b5fe91f3… -> 77ffd791…`: zero arquivos diferentes. A árvore final da `main` é byte a byte equivalente à árvore auditada.
- `src/integrations/supabase/types.ts`: blob certificado `8ea7750b75fd9d76b29c36ce7613392e3ab65e19`.

## Evidências funcionais

- Rota literal `/competencias/:id`, `ssr:false`, metadados PT-BR.
- UUID inválido encerra antes de Auth/RPC.
- Gate: UUID válido -> sessão -> preferência de organização -> RPC oficial.
- RPC de visão geral chamada uma vez com somente `p_id_competencia`.
- Adapter local estreitamente tipado, sem REST manual e sem alteração de generated types.
- `AbortSignal` e cleanup evitam efeito tardio após cancelamento/troca de id.
- 401/403/42501, P0001/missing e erros de transporte possuem mensagens sanitizadas em PT-BR.
- `PercentGauge` é exclusivamente visual.
- `BlockingSummary` renderiza os valores entregues pelo backend sem recalcular portão.
- `AllowedActions` depende exclusivamente de `allowed_actions`.
- Regressão crítica aprovada: percentual 100 + `apresentar=false` continua bloqueado; percentual baixo + `apresentar=true` continua permitido pelo backend.
- Estados visuais `preparation`, `analysis`, `blocked`, `ready` e `presented` são apenas apresentacionais.
- Status críticos usam `PODE APRESENTAR AO CONTRATANTE` e `PODE REAPRESENTAR AO CONTRATANTE`; não existe copy `Apta`.
- V1-12 `Abrir competência` passou a apontar para `/competencias/:id`.
- V1-15/V1-16/V1-18/V1-19 permaneceram staged, sem rotas antecipadas.

## Testes

BUILD e Teste C:

- V1-14: 32/32.
- V1-14 + V1-13 + V1-12 + V1-11 + V1-10: 143/143.
- Suíte completa serial: 576/576, 24 arquivos.
- Lint dos arquivos alterados: 0 erros.
- Teste C: PASS nos 16 grupos, sem desvio concreto.
- Security Scan: 0 Critical, 0 High, 0 Medium, 0 Low; 1 Info preexistente sobre proteção contra senhas vazadas, não introduzido pela V1-14.

Gate externo independente no GitHub Actions, executado sobre a árvore auditada:

- Run `41615153710` — `Verify V1-14 Temp`.
- TypeScript `bunx tsc --noEmit`: SUCCESS.
- Build `bun run build`: SUCCESS.

## Visual, acessibilidade e Brand

- BRAND-01 preservada; `ContaOSMarca` e tokens existentes reutilizados.
- Sem nova paleta, sem mudança de shared UI e sem alteração de estilos globais.
- 1440 / 1280 / 768 / 390 px, claro e escuro, sem overflow crítico.
- H1 único, estados/alertas semânticos, `meter`, `tablist`, nomes acessíveis e status não dependente somente de cor.

## Zero-Drift

Diff protegido = zero em:

- `supabase/**`
- package/lock
- `src/integrations/supabase/client.ts`
- `src/integrations/supabase/types.ts`
- `src/components/ui/**`
- `src/styles.css`
- `public/brand/**`
- AGENTS

O turno read-only do Teste C regenerou automaticamente apenas `types.ts`; o efeito foi removido diretamente no GitHub e a `main` voltou à árvore certificada.

## Limitação registrada

A validação visual da tela autenticada usou fixture controlada. O Teste C não executou navegação completa com uma sessão HML real no navegador. A RPC, segurança, isolamento e contratos de dados foram verificados diretamente no HML e em testes automatizados.

## Conclusão

**PROMPT 35 / V1-14 — APROVADO / TESTE C PASS / ZERO-DRIFT CONFIRMADO.**
