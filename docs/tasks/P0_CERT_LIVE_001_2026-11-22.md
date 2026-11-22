# PLAN — P0-CERT-LIVE-001 (22/11/2026)

## Causa raiz
O mesmo gate de certificação combina prova de integridade do código e evidência operacional LIVE autenticada, antecipando requisitos do pré-PROD e impedindo certificações individuais apesar de CI automatizada válida.

## Autorização e coexistência
Decisão expressa do titular em 22/11/2026. Tarefa independente. **Não substituir nem editar** `docs/tasks/active-task.json` de outra missão. Se o Context Gate não aceitar tarefa paralela, propor alteração estritamente tipada com testes negativos; nunca bypass. Esta tarefa documental não afirma que o BUILD técnico já foi aprovado ou integrado.

## Matriz de escopo
| Componente | Autorizado nesta missão | Limite |
|---|---|---|
| Normas P0 frontend/backend | Sim | Aditivo; sem reescrever PRD |
| Manifesto P0 de versões | Sim, em BUILD próprio | Campo de política; preservar certificados e SHAs |
| `scripts/p0-evidence-live-gate.mjs` | Sim, em BUILD próprio | Separar atestação GitHub/CI da prova HML operacional |
| Testes do gate e workflows consumidores | Sim, em BUILD próprio | Testes RED/GREEN, negativos e regressão |
| Context Gate/escopo paralelo | Somente se necessário, PLAN específico | Sem isenção genérica |
| `docs/tasks/active-task.json` | **Não** | Preservar tarefa concorrente |
| `src/`, `supabase/`, migrations, RLS, RPC, Auth, Edge, PROD | **Não** | Fora do escopo |

## Análise de impacto e prevenção de regressão
Verificar consumidores do `verifyEvidenceLive`, `scripts/p0-evidence-live-gate.mjs`, workflow Zero-Drift, gate de versões e testes. Preservar autenticação GitHub de PR/review/CI e SHA para certificados de código; mover somente exigências de HML implantado e credenciais/sessões operacionais para `GATE_PROD_LIVE`. Guard de produção deve falhar fechado, inclusive com provas ausentes, falsificadas, SKIPPED ou de SHA divergente.

## RED/GREEN e aceite
1. RED: certificado V2–V5 com CI/revisão legítimos, mas sem HML LIVE, não pode falhar exclusivamente por LIVE; antes da correção deve reproduzir o bloqueio.
2. GREEN: certificado de código válido sem LIVE passa os checks aplicáveis; certificado sem CI/revisão continua FAIL.
3. NEGATIVO: GATE_PROD_LIVE sem LIVE autenticado falha; com artefato fictício, SKIPPED ou SHA divergente falha.
4. Regressões completas dos guards, Zero-Drift, Context Gate e Teste C aplicável; CI e revisão independente no mesmo HEAD.
5. PRs separados frontend/backend, merges protegidos e readback de main. Não declarar integração antes dos recibos reais.

## Estado de abertura
PLAN documental, sem execução de contraprovas LIVE, sem alteração de PROD, sem certificado retroativo. Próximo: identificar consumidores, implementar BUILD técnico com testes e submeter à auditoria.
