# ADR-DEV-001 — Registro espelhado da decisão oficial de desenvolvimento

**Data:** 03/11/2026  
**Status:** APROVADA pelo responsável pelo projeto ContaOS 4.1

Esta página é uma **referência cruzada**. O texto normativo canônico está em:
- https://github.com/contaos9999/contaos-hml-control/blob/main/docs/frontend/ADR-DEV-001-GITHUB-DIRETO.md
- https://github.com/contaos9999/contaos-hml-control/blob/main/AGENTS.md

## Decisão

**Frontend:** alterações e correções diretamente no GitHub `contaos9999/contaos-hml-control` (React/TypeScript); Lovable permanece como plataforma de sincronização e visualização e não como agente de BUILD.  
**Backend:** Supabase HML `gklhhhyosgasnyoxlrui` como única fonte de verdade, governado tecnicamente e versionado no `contaos9999/develop`.  
**PROD:** não alterar.  
**Controles:** PRD 4.1, BRAND-01, Zero-Drift, TDD RED/GREEN, CI, testes de acessibilidade/responsividade e Teste C independente mantidos sem redução.  
**Arquivo imutável:** `src/integrations/supabase/types.ts`, blob Git `8ea7750b75fd9d76b29c36ce7613392e3ab65e19`. A rotina Auto-Lock demonstrou restauração efetiva após a regeneração involuntária do Lovable.

## Protocolo para troca de chat

Documento canônico de continuidade: https://github.com/contaos9999/contaos-hml-control/blob/main/docs/frontend/ESTADO_E_RETOMADA_CONTAOS_4_1.md

Ao iniciar um chat novo, antes de qualquer intervenção, verificar HEAD atual, diff, últimos jobs de CI e issues de ambos os repositórios e ler:
- `docs/prompts/PLANO_SANEAMENTO_39_PROMPTS_2026-11-03.json`
- `docs/prompts/CRITERIOS_ORIGINAIS_39_PROMPTS_2026-11-03.json`
- `docs/prompts/MATRIZ_416_CRITERIOS_STATUS_E_PROVAS_2026-11-03.json`
- `docs/prompts/evidencias_individuais/PROMPT_00.json` até `PROMPT_38.json`

A retomada não depende exclusivamente de memória do chat. Atualizar o checkpoint no GitHub após mudanças relevantes e registrar evidência individual; não declarar 39/39 sem E2E real onde exigido.

**Ponto de continuidade:** retomar o diagnóstico e a correção mais prioritários que possam ser executados sem intervenção externa, verificar testes e Zero-Drift e preservar a rastreabilidade.
