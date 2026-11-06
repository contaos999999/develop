# P0 V1 | Correção dos cinco FAIL da prova JWT pós-RLS | Issue #68

## Diagnóstico confirmado no HML
As cinco chamadas autorizadas de `public.enfileirar_ingestao_historica_hml` retornaram SQLSTATE 23514. A função usa `fila='historico'` e publica em `pgmq.send('historico',...)`; o CHECK `execucoes_assincronas_fila_check` permite apenas `documents, ocr, ai, embeddings, finance_imports, reports, integrations, webhooks`. Portanto a restrição rejeita o INSERT após a tentativa de enfileiramento. A transação é revertida.

## PLAN e gate obrigatório
1. Não alterar a função SECURITY DEFINER, suas concessões, RLS, Auth, outros CHECKs, workers ou filas; preservar os oito valores atuais do CHECK.
2. Gerar uma **nova** migração versionada com Supabase CLI fixada e `supabase migration new` (não reutilizar o gerador de MASTER RLS nem reaplicar migrações antigas).
3. A migração altera somente `public.execucoes_assincronas_fila_check` para incluir `historico`; registrar pré-condição de definição anterior, pré-checagem de filas e estratégia de rollback compatível com linhas já criadas. Não aplicar rollback que remova `historico` se existirem execuções nessa fila.
4. Revisar o SQL no PR, executar Zero-Drift e os gates canônicos, aplicar **somente HML** após o gate e registrar histórico da migração.
5. Executar **apenas** o subconjunto de cinco positivos anteriormente reprovados com JWTs reais e novos fixtures sintéticos autorizados: gestor A1, administrador A1, MASTER A1/A2/B1. Para cada caso exigir HTTP 200 + UUID, linha `execucoes_assincronas` `fila=historico`, mensagem `pgmq.q_historico`, tenant/contrato corretos e idempotência. Comparar o número de linhas antes/depois; nunca contar resposta HTTP isolada como sucesso.
6. Verificar não regressão estrutural: os oito valores anteriores permanecem válidos, CHECK inclui `historico`, RLS MASTER e histórico anterior intactos. Encerrar sessões, revogar concessões e colocar contas/organizações sintéticas em quarentena. Não reutilizar contas banidas.
7. Relatório final: cinco casos PASS/FAIL individualizados, SHA/PR/CI, versão de migração, evidências HML e limitações. Não executar a bateria completa de 354 casos nesta rodada. Não certificar V1 por esse subconjunto.

## Restrições
Produção proibida. Sem alteração de frontend, identidade visual ou Lovable. Não expor tokens, senhas, strings de conexão. Nenhuma migração aplicada antes de PLAN/GATE e revisão do SQL. Matriz RBAC persistente da issue #53 permanece pendente.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Sem impacto visual, Brand v1.0 preservada. Reutilizar CLI/GitHub/Supabase existentes, sem ferramentas pagas adicionais. Manter gates e evidências funcionais reais, não transformar falha em PASS.
