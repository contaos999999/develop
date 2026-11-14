# ContaOS V1 — protocolo persistente somente-leitura (GATE #138)

Este documento **não é certificado V1**, nem instrução para reabrir fases concluídas. Origem: PLAN P0 saneamento #670, Fase 3 GATE backend #220 integrado `0f7725be5feb8efa028157a57f7629374366b913`, preservando C13 ativa. Construção da PR #219 restrita a este documento e a `scripts/executor-state-controller.mjs/.test.mjs`.

## Semântica
- O GATE #138 é **histórico e somente-leitura**. O programa não publica comentários, não cria PR, não dispara workflow, não opera autenticação, banco, HML ou PROD.
- Comment com marcador `CONTAOS_EXECUTOR_STATE_V1` e JSON validado é evento append-only. Autor permitido `contaos9999` ou `Edivan5002`. Comentário externo não dá autoridade. Registro malformado de autor autorizado bloqueia a leitura e não faz fallback silencioso para estado anterior.
- Ler **todas** as páginas de comentários, ordenar por ID, selecionar o mais recente válido; paginação incompleta bloqueia. Estado `UNINITIALIZED` é possível, não é PASS.
- Campos obrigatórios: `schema=1`, `phase_id=1..8`, `task_id`, `head_sha` SHA-40, `status` em PENDING/RUNNING/BLOCKED/VALIDATING/COMPLETED e `next_action`. PR/Run ID devem ser inteiros positivos ou null. Evidências são referências, não autorização.
- Se existir `run_id`, consultar GitHub Actions real por GET e conferir ID, repositório, HEAD, status e resultado. Se `pr_number`, consultar PR real e conferir repositório e HEAD.
- Run em progresso → RUNNING; failure/cancelled/mismatch/API ausente → BLOCKED; run SUCCESS → apenas **VALIDATING**, com revisão de CI, LOCK, Zero-Drift, provas e auditoria independente ainda necessária. Nunca converter `COMPLETED` do JSON em certificação.
- Saída sempre contém `dispatch_allowed:false`. Não há cron de 5 minutos, mutações, locks de concorrência nem credenciais em logs. Tokens são somente leitura e jamais publicados.

## Execução segura
`GITHUB_TOKEN=<read-only token> node scripts/executor-state-controller.mjs`; `node --test scripts/executor-state-controller.test.mjs`. Erro bloqueado resulta exit 2; `UNINITIALIZED` ou `VALIDATING` não significa certificação.

## Segurança e limites
Este leitor valida apenas **identidade estrutural** da informação consultada; sem um processo de aprovação de checkpoint por revisão independente e CAS para novos escritores, comentários não são autorização para dispatch. NÃO implementar dispatch automático com este módulo. Não reconstruir históricos aprovados, não recertificar V1 e não tocar produção.
