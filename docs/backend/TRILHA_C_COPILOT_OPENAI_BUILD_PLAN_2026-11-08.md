# PLAN BUILD C-CHAT-001 — OpenAI no copiloto existente

Autorização expressa do titular, 08/11/2026. PLAN canônico PR #179 integrado em main. Preservado snapshot do manifesto PLAN anterior. Escopo exclusivo: `supabase/functions/copilot-query/index.ts` e teste de contrato, sem DDL nem mudanças de RLS/Auth/Storage.

## Desenho
Após JWT real e SELECT do contrato via cliente autenticado, recuperar evidências exclusivamente por RPCs scope-first já existentes, no escopo do contrato/contratante e referência temporal. Só enviar à OpenAI excertos recuperados, truncados e explicitamente tratados como dados não confiáveis. Não transmitir service key, tokens JWT, IDs internos de usuários ou segredos. Não chamar OpenAI sem evidências elegíveis. Modelo configurável por `OPENAI_CHAT_MODEL` e chave apenas `OPENAI_API_KEY` na Edge. Limitar saída e timeout; nunca executar ferramentas ou ações do modelo.

Resposta da IA é informativa, distingue evidência de inferência e exige revisão humana. Preservar classificação de conflito/baixa confiança e fallback determinístico se OpenAI falhar, sem derrubar a consulta ou transações. Persistência nas tabelas já existentes. Nenhuma aprovação, alteração, liberação, escrita de negócio ou execução de SQL pelo modelo.

## Testes e aceitação
Testes de contrato devem comprovar chave apenas backend, endpoint HTTPS OpenAI, limites de contexto e saída, timeout, fallback, ausência de chamada sem fonte, anti-prompt-injection, resposta não autoritativa, JWT/RLS anteriores preservados. CI Zero-Drift, segurança, regressão, HML JWT real e negativos cross-tenant antes de merge/deploy. Não certifica chat só com testes estáticos.

## Rollback
Reverter apenas PR BUILD; não há migração nem mudança de esquema. Preservar Trilha B certificada e os artefatos de evidência.


## Complemento mínimo de transporte e validação de resposta
Causa comprovada: o handler rejeita OPTIONS com 405 e não emite CORS. Reutilizar somente as três origens exatas já aprovadas nas Edges documentais: http://127.0.0.1:4173, https://scope-and-approval-keeper.lovable.app e https://contaos-41-hml.vercel.app. Preflight permite somente POST e authorization/x-client-info/apikey/content-type, antes da autenticação, sem cookies ou wildcard. Respostas POST mantêm JWT e autorização material, com cabeçalhos locais à requisição em todos os ramos.

Runtime TDD em Node22: executar o TypeScript real com stripTypeScriptTypes e capturar Deno.serve, substituindo somente fronteiras externas Supabase/embedding/fetch. Provar preflight sem acesso a Auth/DB/IA, origens/métodos/headers negados, erros e sucesso com CORS e isolamento concorrente. Provar autenticação/contrato antes de RAG/IA, sem chamada sem fonte, fallback de provedor, saída incompleta/malformada e citações ausentes/fora do conjunto enviado. Aceitar apenas resposta completed e citações F1..Fn válidas; não alegar validação semântica completa por regex. O resumo determinístico de conflito/baixa confiança permanece visível junto da síntese. Não modifica RLS/RPC/DDL, deployment ou configuração JWT.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual: N/A, alteração limitada à Edge e testes backend. ContaOS Brand v1.0 e frontend preservados. Ferramentas diretas GitHub/Node, delta mínimo e nenhuma execução Lovable. TDD, regressão, CI e revisão independente continuam obrigatórios; prova local não certifica HML nem substitui JWT real/cross-tenant.

## Evidência local e limites de integração
RED real: 34 testes, 15 PASS/19 FAIL pela ausência de CORS, aceitação de output incompleto/citações inválidas e supressão do resumo determinístico. GREEN: 34/34 no mesmo handler após correção mínima. Nenhum deployment ou alteração de JWT.

Bloqueio para certificação HML: a única definição das RPCs worker_buscar_fragmentos_temporais/worker_buscar_precedentes_ranqueados nas136migrations é0033. A primeira filtra organização/contrato/vigência, mas não verifica segurança/processamento do arquivo; a segunda recupera outros contratos do mesmo contratante sem checar acesso humano ao contrato de origem. Isso exige confronto formal com RBAC atual e prova material antes de qualquer certificação/envio externo. Não houve alteração SQL/RLS ou relaxamento desses requisitos. Citações F1..Fn são validadas estruturalmente, sem alegar verificação semântica integral das afirmações.

Runner HML: workflows existentes de domínios restantes têm environment hml e gates robustos, mas roteamento de tarefa impede uso para Trilha C. Nenhum segredo foi recuperado ou exportado. Harness e workflow manual específico dependem de PLAN/GATE documental separado antes de implementação.
