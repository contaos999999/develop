# PLAN C13 HML: origem CORS explícita

Data: 2026-11-09. Escopo: Supabase HML gklhhhyosgasnyoxlrui, Edge copilot-query.

Evidência: auditoria autenticada HML https://agent.tinyfish.ai/runs/fb0334bc-8dbf-4843-9096-5536684b1fa0 apresentou falha de sessões e resultado incerto. Logs `function_edge_logs` registraram POST 403 em 2026-11-09T10:48:19Z e 10:48:44Z. Versão 7 da função possui allowlist CORS que não inclui origem do deployment `https://contaos-41-nygkrrbkq-contaos9999.vercel.app`.

Mudança permitida: APENAS `supabase/functions/copilot-query/index.ts`, adicionando exatamente essa origem à lista explícita `ORIGENS_CORS`. Sem wildcard, sem alteração de JWT, RLS, service role, quota, payload ou semântica C13.

Validação: revisão do diff e teste de preflight da origem nova (204), origem não autorizada (403), HTTP 403 de autorização não convertido em 200, testes backend C13 previamente aprovados preservados. Deploy de Edge HML apenas após aprovação dos gates; nenhum deploy Vercel necessário se frontend SHA não mudar. Teste focal autenticado da UI, sem reenvio automático da pergunta incerta, verificar sessões e resposta real. Atualizar GATE #138, certificar só após provas.
