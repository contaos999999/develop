# PLAN BUILD C-CHAT-001 — OpenAI no copiloto existente

Autorização expressa do titular, 08/11/2026. PLAN canônico PR #179 integrado em main. Preservado snapshot do manifesto PLAN anterior. Escopo exclusivo: `supabase/functions/copilot-query/index.ts` e teste de contrato, sem DDL nem mudanças de RLS/Auth/Storage.

## Desenho
Após JWT real e SELECT do contrato via cliente autenticado, recuperar evidências exclusivamente por RPCs scope-first já existentes, no escopo do contrato/contratante e referência temporal. Só enviar à OpenAI excertos recuperados, truncados e explicitamente tratados como dados não confiáveis. Não transmitir service key, tokens JWT, IDs internos de usuários ou segredos. Não chamar OpenAI sem evidências elegíveis. Modelo configurável por `OPENAI_CHAT_MODEL` e chave apenas `OPENAI_API_KEY` na Edge. Limitar saída e timeout; nunca executar ferramentas ou ações do modelo.

Resposta da IA é informativa, distingue evidência de inferência e exige revisão humana. Preservar classificação de conflito/baixa confiança e fallback determinístico se OpenAI falhar, sem derrubar a consulta ou transações. Persistência nas tabelas já existentes. Nenhuma aprovação, alteração, liberação, escrita de negócio ou execução de SQL pelo modelo.

## Testes e aceitação
Testes de contrato devem comprovar chave apenas backend, endpoint HTTPS OpenAI, limites de contexto e saída, timeout, fallback, ausência de chamada sem fonte, anti-prompt-injection, resposta não autoritativa, JWT/RLS anteriores preservados. CI Zero-Drift, segurança, regressão, HML JWT real e negativos cross-tenant antes de merge/deploy. Não certifica chat só com testes estáticos.

## Rollback
Reverter apenas PR BUILD; não há migração nem mudança de esquema. Preservar Trilha B certificada e os artefatos de evidência.
