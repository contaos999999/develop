# Issue #68: reteste JWT dos cinco casos anteriormente reprovados
Data: 05/11/2026, Bahia. Projeto HML gklhhhyosgasnyoxlrui. PR #75.

## Resultado: 5/5 PASS
Somente os cinco cenários anteriormente reprovados foram executados novamente. As 349 provas funcionais anteriores não foram repetidas nem tiveram seus registros históricos alterados.

| Caso | JWT real / getUser | Primeira chamada | Replay | Execução / mensagem / escopo | Idempotência | Resultado |
|---|---|---:|---:|---|---|---|
| gestor_contrato A1 | PASS | 200 | 200 | PASS | PASS | PASS |
| administrador A1 | PASS | 200 | 200 | PASS | PASS | PASS |
| MASTER A1 | PASS | 200 | 200 | PASS | PASS | PASS |
| MASTER A2 | PASS | 200 | 200 | PASS | PASS | PASS |
| MASTER B1 | PASS | 200 | 200 | PASS | PASS | PASS |

## O que foi comprovado
- Três contas novas e sintéticas: gestor_contrato, administrador e MASTER global sem vínculo físico. Login por /auth/v1/token e identidade conferida por /auth/v1/user, todos HTTP 200.
- Duas organizações e três contratos/relatórios/versões novos, identificados por prefixo p0retry68. Nenhuma conta banida foi reutilizada.
- Dez chamadas reais à RPC enfileirar_ingestao_historica_hml: primeira chamada e repetição em cada um dos cinco cenários.
- Cada retorno foi HTTP 200 com UUID válido e o replay retornou exatamente o mesmo UUID.
- SQL independente confirmou execução com fila historico, organização, contrato e entidade-relatório corretos; message_id apontando para mensagem efetivamente existente em pgmq.q_historico.
- O corpo de cada mensagem correspondia a relatório, versão documental, organização e contrato esperados.
- Contagem por relatório antes/depois do replay: exatamente uma execução e uma mensagem.
- Contagem global das fixtures: antes **0 execuções / 0 mensagens**; depois **3 execuções / 3 mensagens**, com três eventos IngestaoHistoricaEnfileirada. Gestor, administrador e MASTER compartilham o relatório A1 e reutilizaram a mesma execução; A2 e B1 possuem suas próprias execuções.
- O antigo erro SQLSTATE 23514 não reapareceu.

## Correção estrutural e paridade verificadas
- Migração versionada no GitHub e registrada no HML: **20261105232056_p0_v1_historico_fila_check**.
- Versão divergente 20261106003138: ausente.
- Exatamente um registro da versão original no histórico.
- CHECK preserva documents, ocr, ai, embeddings, finance_imports, reports, integrations e webhooks, acrescentando historico.
- RLS MASTER permanece ativo.
- Definição da RPC enfileirar_ingestao_historica_hml inalterada durante o reteste: MD5 antes/depois c7dd035f3a863c17f554cb90835c6fc8.
Nenhuma migração foi reaplicada nesta rodada e nenhuma alteração de RLS, grants, função, worker, Cron, configuração Auth, Storage ou produção foi realizada.

## Controle do consumidor e limpeza
O consumidor histórico está ativo a cada minuto. Para permitir observação independente e evitar processar documentos fictícios, somente o vt das mensagens das fixtures foi postergado durante a prova. Não houve alteração de configuração da fila, Cron ou worker.
Após concluir e verificar todos os casos:
- 3 mensagens sintéticas arquivadas em pgmq.a_historico; 0 permanecem pendentes em pgmq.q_historico;
- 3 execuções sintéticas marcadas cancelado com P0_RETRY68_FIXTURE_CLEANUP, somente como limpeza posterior ao PASS;
- 3 contas bloqueadas, senhas substituídas por valores aleatórios não retidos;
- 0 sessões e 0 concessões MASTER/vínculos ativos;
- 2 organizações sintéticas inativas;
- eventos de auditoria e evidências preservados.
Os cancelamentos de fixture não são falhas dos testes. Não foi declarada exclusão de registros: a limpeza adotou quarentena e arquivamento auditáveis. Nenhuma conta ou registro real foi modificado.

## Limites da conclusão
Os arquivos, versões e processamentos documentais são metadados sintéticos preparados para testar autorização e enfileiramento. O reteste comprova chamada JWT, criação real de execução/mensagem e idempotência.
**Não certifica upload, OCR, leitura/extração de documento ou execução ponta a ponta do worker.** As mensagens foram arquivadas depois da comprovação para impedir processamento desnecessário das fixtures.
Os cinco FAIL históricos do PR #67 foram resolvidos pelo novo reteste; o relatório original permanece histórico, sem converter seus FAIL em PASS. Isto não é uma nova execução dos 354 casos.
A matriz RBAC persistente/editável, sidebar e demais gates V1 continuam com seus próprios estados. **A V1 não está certificada; V2 bloqueada; PROD intocada.**

## GitHub e integridade
- Baseline main: 3333ebf6cdc985a8cdb4eec2dfe5c93156628971.
- PLAN corretivo #69 e migration/controles #70–#74 preservados.
- Código do reteste: 1b3846b43e1503b48c1ecfd5364960994237529f, CI Zero-Drift **42143425452 SUCCESS**.
- Relatório e checkpoint deste PR exigem CI no HEAD final antes de merge.
- SHA-256 do JSON privado de resultados, sem senhas/tokens: 55cc092728f9eca55516544a1c0cf6b61a55f0b2f7c4a9ad7db03daa8142ce93.
- Arquivo de teste: supabase/tests/p0_v1_retry68_jwt_five.py. As credenciais, tokens e seed SQL não são versionados. Para outra execução, usar diretório privado fora do checkout via CONTAOS_TEST_PRIVATE_DIR, novas identidades e novo manifesto autorizado.
- Os campos de identificação de execução do JSON correspondem somente a fixtures sintéticas; nenhum ID de dado real foi publicado.

## Próxima etapa
Encerrar issue #68 após integração deste relatório. Preservar as 349 provas anteriores e registrar os cinco retestes como PASS com estas limitações. Retomar a matriz RBAC e demais requisitos faltantes da V1 conforme issue #53, sem repetir a reconciliação de migração já comprovada.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual N/A: somente testes/documentação backend, Brand v1.0 preservada. Ferramentas diretas e Python padrão, sem BUILD Lovable. Reteste focado conforme decisão do titular, preservando CI, segurança, evidência e rastreabilidade. Nenhum novo SaaS ou serviço pago.
