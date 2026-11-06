# GATE: reteste exclusivo dos cinco casos #68

Origem: PLAN #69 e pedido expresso do titular. Backend main 3333ebf6cdc985a8cdb4eec2dfe5c93156628971. Conferência real: versão 20261105232056 registrada, versão divergente 20261106003138 ausente, CHECK com oito valores anteriores mais historico, RLS MASTER ativo. Não reaplicar migração.

Escopo fechado: novas identidades MASTER global sem vínculo físico, administrador A e gestor A; duas organizações e três contratos/relatórios/versões sintéticos prefixo p0retry68. Auth emite JWT real e getUser confirma identidade. Executar por REST somente os cinco cenários: gestor A1, administrador A1, MASTER A1/A2/B1, com replay para idempotência. Não executar outras 349 provas.

Cada cenário precisa de HTTP 200 e UUID válido, registro execucoes_assincronas com fila historico e escopo correto, message_id vinculado a mensagem real pgmq historico com relatório/versão/organização/contrato corretos e nenhum efeito duplicado no replay. Os três atores compartilham o relatório A1: idempotência deve preservar uma execução/mensagem para A1, além de A2/B1, total três.

Fixtures documentais são metadados preparados, não upload/OCR real. Para evitar que o consumidor remova a mensagem sintética durante a conferência, somente o vt das mensagens dessas fixtures pode ser postergado por poucos minutos, com captura SQL independente. Ao final, arquivar somente essas mensagens, cancelar somente as execuções sintéticas e preservar auditoria. Nenhuma mudança de configuração, worker, Cron, RLS, grants, função ou produção. Encerrar sessões, bloquear contas/senhas aleatórias, revogar MASTER/vínculos e inativar organizações. Sem reutilizar contas banidas.

Código e escopo sujeitos a CI Zero-Drift antes da prova; resultado PASS/FAIL individual com retorno, linha, mensagem e idempotência. Comparar estado estrutural e histórico antes/depois. V1 não certificada por este subconjunto; matriz RBAC continua pendente.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual N/A: teste backend sem UI/assets, Brand v1.0 preservada. Ferramentas diretas e Python padrão, sem BUILD Lovable. Menor reteste conforme o pedido, sem reduzir segurança, rastreabilidade ou evidência. PROD proibida.
