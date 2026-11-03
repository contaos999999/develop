# Certificação Frontend — V1-16 Competência: Análise

Data: 03/11/2026
Ambiente: HML
Prompt: 37 / V1-16
Status: CERTIFICADO
PROD: intocado

## Escopo certificado

Tela `/competencias/:id/analise` para executar e acompanhar a análise da competência, revisar resultados por requisito, visualizar estado assíncrono, percentual, bloqueios, mecanismos, evidências, apontamentos internos e histórico de execuções.

O frontend não calcula portão, percentual, bloqueio, stale, mecanismo, criticidade ou permissão crítica. Esses dados e decisões permanecem no backend HML V1-16 certificado.

## Backend utilizado

Leitura autoritativa:

- `public.obter_analise_competencia_v116`
- schema `v116-v1`
- paginação server-side: resultados 25, execuções 10, apontamentos 25
- filtros server-side: resultado, criticidade, mecanismo, status de apontamento e busca

Ação global de análise/reanálise conforme o PLAN aprovado deste Prompt 37:

- `public.solicitar_analise_competencia(p_id_competencia uuid, p_tipo text)`
- Executar análise: `completa`
- Reanalisar global: `reanálise`

`public.solicitar_reanalise_requisitos` não é consumida neste Prompt 37. O detalhe de requisito e o fluxo incremental permanecem fora do escopo desta entrega.

Certificação backend relacionada:

- `docs/backend/V116_CERTIFICACAO_ANALISE_COMPETENCIA_2026-11-03.md`
- migration Git `supabase/migrations/20261103124500_v116_obter_analise_competencia.sql`
- commit backend `a1536a20c4d6c5e2f9af53d0490e9b7177a70c11`
- migration HML `20261103135545 v116_obter_analise_competencia`
- testes `PASS_V116_READ` e `PASS_V116_NEGATIVOS`
- backend HML congelado para o frontend V1-16

## Frontend auditado

Repositório: `contaos9999/contaos-hml-control`

- Base operacional: `cdfbc59be69007b844391d63f32f28894b56d2b1`.
- Primeiro candidato submetido ao Teste C: `12df4b4e94ba06a76644676da9114b4b7e5f2c0f`.
- Primeiro Teste C: FAIL no item de apontamentos, pois `origem` e `fonte` retornadas pelo backend não eram exibidas.
- Correção mínima com TDD RED -> GREEN realizada em turno separado.
- SHA funcional final auditado no Teste C: `d4b9b77dafa7ff6ca7644a99fee737bfed590a1e`.
- `src/integrations/supabase/types.ts`: blob certificado `8ea7750b75fd9d76b29c36ce7613392e3ab65e19` no próprio SHA auditado.

Diff final contra `cdfbc59b` limitado aos caminhos autorizados do Prompt 37:

- `.lovable/plan.md`
- `.lovable/plan/prompt-37-v1-16-competência-análise-plan-2026-11-03.md`
- `docs/frontend/lovable/PROMPT-37-V1-16-competencia-analise.md`
- `src/components/competencias/CompetenciaAnalise.tsx`
- `src/components/competencias/CompetenciaVisaoGeral.tsx`
- `src/lib/competencias/competenciaAnaliseDados.ts`
- `src/routeTree.gen.ts`
- `src/routes/competencias_.$id_.analise.tsx`
- `src/test/competenciaAnalise.test.tsx`
- `src/test/competenciaVisaoGeral.test.tsx`

## Evidências funcionais

- Rota `/competencias/:id/analise`, `ssr:false`, head PT-BR e H1 único.
- UUID inválido encerra antes de `getUser`, preferência de organização e RPC da feature.
- UUID válido segue sessão -> preferência de organização como contexto -> leitura V1-16.
- Organização selecionada não substitui autorização de backend/RLS.
- 401/403/42501/PGRST301, PT404 e demais falhas recebem mensagens sanitizadas em PT-BR.
- Uma leitura agregada por ciclo/refetch, sem N+1 e sem API REST paralela.
- Parser fail-closed para schema, estado, stale, percentual, allowed actions, paginações, arrays e mecanismos.
- Valor 0 e booleanos `false` válidos são preservados.
- Sem execução, `mecanismos={}` é representado como ausência, sem inventar contagens.
- Com execução, os quatro mecanismos são exigidos e exibidos exatamente como retornados: `deterministico`, `semantico`, `humano`, `nao_identificado`.
- `stale` vem exclusivamente do backend; não existe comparação local de hash.
- `PercentGauge` exibe o percentual do backend. Qualquer clamp 0..100 é somente visual para largura da barra; não altera o valor autoritativo exibido.
- `BlockingSummary` apenas renderiza o resumo do backend; não decide liberação.
- Resultados, criticidade, confiança, justificativa, fundamento e evidências são exibidos conforme payload.
- Apontamentos internos exibem severidade/criticidade, regra, ação, origem e fonte quando fornecidas.
- `fonte={}` não cria conteúdo artificial; `fonte` não objeto falha closed no parser.
- Conteúdo de origem/fonte é renderizado pelo React sem `dangerouslySetInnerHTML`.
- Paginações de resultados, execuções e apontamentos são independentes.
- Resultado/mecanismo resetam somente resultados; criticidade e busca resetam resultados e apontamentos; status do apontamento reseta somente apontamentos; execuções permanecem independentes.
- Busca é aplicada por botão/Enter e não dispara leitura a cada tecla.
- Troca A -> B limpa filtros/offsets/estado vinculados ao recurso, aborta a leitura anterior e descarta resposta tardia.
- `allowed_actions` é autoridade para os botões críticos.
- Executar análise chama `solicitar_analise_competencia(id,'completa')`.
- Reanalisar global chama `solicitar_analise_competencia(id,'reanálise')`.
- Duplo clique é bloqueado localmente; concorrência/idempotência real permanece no backend.
- Em erro/timeout ambíguo de escrita, ocorre uma única leitura de reconciliação e nunca uma segunda escrita automática.
- `allowed_actions.abrir_requisito=true` permanece staged `Em breve`, `aria-disabled`, sem href/onClick/RPC, preservando o limite V1-17.
- Polling ocorre somente em `queued|processing`, reutilizando `atrasoPolling` da V1-10 e terminando em estado terminal, erro, unmount ou troca de recurso.
- V1-14: Análise passou a link real; Documentos permanece real; Parecer e Apresentação permanecem staged.

## TDD e correções incorporadas

REDs documentados e preservados:

1. RED inicial porque a V1-16 ainda não existia.
2. RED específico para a habilitação do link Análise na V1-14.
3. RED pós-primeiro Teste C com 3 falhas reais:
   - `fonte` de apontamento não objeto deveria falhar closed;
   - `origem` deveria ser exibida quando fornecida;
   - `fonte` estruturada deveria ser exibida quando fornecida.

GREEN mínimo da correção:

- parser passou a preservar fonte objeto de forma segura;
- valores primitivos da fonte são exibidos como chave/valor;
- fonte vazia não é mostrada;
- origem é exibida somente quando fornecida;
- nenhum comportamento de análise, filtro, paginação, polling ou autorização foi alterado pela correção.

## Teste C final

SHA auditado: `d4b9b77dafa7ff6ca7644a99fee737bfed590a1e`.

Auditoria executada em cópia isolada por `git archive`.

Resultados:

- V1-16 + visão geral: **126/126**.
- Suíte completa serial `--maxWorkers=1`: **739/739**, 26 arquivos, exit 0.
- Lint dos 6 arquivos alterados: exit 0.
- Static scan: sem `service_role`, secrets, `getPublicUrl`, `dangerouslySetInnerHTML`, REST manual, escrita direta em tabela, derivação de stale, regra local de portão ou `solicitar_reanalise_requisitos` no código de produção V1-16.
- Security Scan: 0 Critical, 0 High, 0 Medium e 0 Low; 1 Info preexistente sobre proteção contra senhas vazadas. Wiz não configurado.
- `tsgo --noEmit`: exit 0 na cópia isolada.
- `vite build`: exit 0 na cópia isolada.
- Teste C: **PASS**.

## Visual, acessibilidade e Brand

- BRAND-01 preservada; sem alteração de `src/styles.css`, shared UI ou assets de marca.
- Navegador em 1440 / 1280 / 768 / 390 px, claro e escuro, no cenário de UUID inválido real: oito combinações sem overflow global, um H1 e zero chamadas ao Supabase.
- Estados assíncronos usam texto e ícone, não apenas cor.
- Filtros possuem labels; regiões dinâmicas usam roles/`aria-live` quando aplicável.
- Em resoluções intermediárias, filtros utilizam painel/Sheet e tabelas usam rolagem controlada.

## Zero-Drift

Diff protegido = zero na árvore certificada para:

- `supabase/**`
- `package.json` / `bun.lock`
- `src/integrations/supabase/client.ts`
- `src/integrations/supabase/types.ts`
- `src/components/ui/**`
- `src/styles.css`
- `public/brand/**`
- AGENTS
- PROD

Durante turnos do Lovable, `types.ts` foi regenerado automaticamente em estados posteriores do workspace. Esses commits posteriores não foram usados como candidato. O SHA auditado `d4b9b77d...` contém diretamente o blob certificado `8ea7750b...`.

## Limitações registradas

- Não houve sessão HML real no navegador para os fluxos autenticados. Estados, ações, troca de competência, filtros, paginações e polling autenticados foram cobertos com fixtures/mocks e testes automatizados.
- O teste visual automatizado do cenário de UUID inválido foi executado na prévia do workspace; a auditoria de código, testes, typecheck e build foi executada no SHA imutável via cópia isolada.
- Backend HML, RPCs, grants, RLS e isolamento foram certificados em etapa própria e não foram modificados nesta entrega frontend.

## Conclusão

**PROMPT 37 / V1-16 — APROVADO / TESTE C PASS / TYPESCRIPT PASS / BUILD PASS / ZERO-DRIFT CONFIRMADO.**
