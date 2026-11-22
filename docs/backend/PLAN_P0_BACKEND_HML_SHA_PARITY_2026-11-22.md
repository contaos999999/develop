# PLAN P0-BACKEND-HML-SHA-20261122 | Fonte canônica e correspondência de deploy

**Estado:** PROPOSTO, documental, sem BUILD, sem mudança de banco/Edge/Auth/RLS/PROD, sem atestado de deploy. **Não altera a tarefa proprietária** `docs/tasks/active-task.json`.

## Fonte e alvo comprovados
- Backend GitHub: `contaos999999/develop@ffb9fa0558f87925ed5b9bf945a96741c1fa5ae6`.
- HML Supabase `gklhhhyosgasnyoxlrui`, status `ACTIVE_HEALTHY`.
- 138/138 versões do histórico `supabase_migrations.schema_migrations` coincidem exatamente com os 138 arquivos GitHub `supabase/migrations/` em versões, sem extras ou faltantes. Isso não prova bytes ou deployments.
- Inspeção somente leitura de 19 fontes `supabase/functions/<slug>/index.(ts|js)` e 20 funções ACTIVE do painel HML. Resultado: 17 fontes EXACT iguais à publicação, uma diferença de quebra de linha e uma divergência de conteúdo interno. `queue-worker-ai/job-envelope.mjs` também é idêntico. O `queue-worker-documents` inicialmente deu erro de leitura e foi recuperado, ficando com igualdade exata.

## Causas verificáveis em 22/11/2026
1. `queue-worker-finance/index.ts`: GitHub e deploy diferem no literal de detecção de RTF. GitHub tem literal de string que representa a sequência de barra invertida + `rtf` em `startsWith`; bundle HML apresenta escape com interpretação distinta. É uma diferença funcional potencialmente relevante em bloqueio de conteúdo, não formatar/normatizar para esconder drift. **Deploy HML a partir do GitHub aprovado**, não rebaixar fonte para coincidir com o código implantado.
2. `notify-user/index.js`: HML apresenta uma quebra de linha adicional ao final do arquivo em relação ao GitHub, sem alteração do corpo. A prova de equivalência exata deve separar essa diferença de byte de uma divergência operacional.
3. `queue-worker-historico` versão 2 ACTIVE, `verify_jwt=false`, entrypoint `index.ts` de 3885 caracteres no provedor, mas arquivo `supabase/functions/queue-worker-historico/index.ts` ausente no HEAD GitHub. É um gap material de proveniência. Fluxo de acesso depende do cabeçalho interno e de RPC `validar_token_interno`; revisar política completa antes de eventual reintegração e atualização. Não tratar simplesmente como função órfã a remover sem avaliar cron e consumidores.
4. GitHub Actions frontend [run 44980196211](https://github.com/contaos999999/contaos-hml-control/actions/runs/44980196211) mantém `BACKEND_SHA_UNVERIFIED`; o conteúdo implantado não satisfaz até aqui a prova completa do commit, ainda que o HEAD GitHub seja conhecido.

## Ordem de correção definitiva, requer autorização de transição
1. Fazer gate PLAN protegido no repositório backend com allowlist **exata** para `supabase/functions/queue-worker-historico/index.ts` (restauração de fonte do provedor após revisão), `supabase/functions/queue-worker-finance/index.ts` (sem alteração da lógica correta existente), `supabase/functions/notify-user/index.js` (sem alterações funcionais) e testes de proveniência/rejeição RTF; não incluir migrations, RPC, Auth, políticas, Edge adicionais, Storage ou PROD. Antes do BUILD comprovar revisão e não conflitar com a tarefa ativa alheia; se necessário emendar `docs/tasks/active-task.json` somente em PLAN separado com autorização.
2. Fazer recuperação auditada de histórico e registro da fonte real `queue-worker-historico`; comparar versão ativa inteira com novo arquivo proposto e escanear segredos/capacidades. Validar cron `queue-worker-historico` e políticas. Não executar requests privados ou copiar tokens.
3. Reproduzir via testes negativos o bug de detecção RTF no HML e positivo com o conteúdo correto. Nenhum parse de arquivos reais de usuário. Testes locais contra AST e fonte; bloquear drift se manifestado.
4. Após BUILD com CI, revisão independente e merge protegido, executar **somente deployment HML controlado** de Edge a partir do HEAD backend fechado usando workflow canônico. Confirmar `status=ACTIVE`, versão, `verify_jwt`, hashes do provider e **comparação byte a byte** dos arquivos publicados contra o novo HEAD.
5. Replicar inventário de todas as 20 funções publicadas e dependências locais (inclusive `job-envelope.mjs`); registrar HEAD backend, branch, ID do deploy, timestamp, versão, digest, source bytes e resultado. Para migrações, confirmar 138/138 sem executar SQL.
6. Somente então emitir `SHA_BACKEND_CANONICO=PASS` para o HML; se qualquer fonte extra, arquivo divergente, erro de bundle, job não autorizado ou digest não verificado, manter `NO-GO`. Configurar `CONTAOS_HML_EXPECTED_BACKEND_SHA` no Environment frontend apenas após confirmação da proveniência real, nunca para silenciar `preflight`.

## RED/GREEN, segurança e rollback
- RED já observado: divergência de bytes de finance, ausência de fonte versionada de historico, diferença de newline notify. GREEN precisa inventário 20/20, conteúdo conferido, testes de RTF, versão e hash da publicação e auditoria.
- Sem desligar `verify_jwt`, `validar_token_interno`, RBAC, RLS, controles CORS, limite de payload ou qualquer veto. Não gerar credenciais.
- Erro em teste ou revisão implica não executar deploy. Rollback exclusivamente por reinstalação de versão previamente certificada em HML após verificação das propriedades de segurança. PROD continua bloqueado.

**Conclusão:** SHA da árvore backend está localizado, mas equivalência do HML **não atestada**. Esta PR documental organiza correção em sua própria trilha, sem violar ownership da tarefa atual e sem fingir liberação.
