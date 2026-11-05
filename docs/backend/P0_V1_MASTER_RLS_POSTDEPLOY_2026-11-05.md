# P0 V1 MASTER RLS — pós-implantação HML (05/11/2026)

## Evidência real
- PR #62 merge `9de83d6baeee2dfda3e1b0b3e9fd6326e382f042`, Zero-Drift `42120653752` SUCCESS.
- PR #63 merge `682953fcf54f1bc4dec02f720a1ae01bdf608aa5`, Zero-Drift `42120858473` SUCCESS.
- Projeto **somente HML** `gklhhhyosgasnyoxlrui`. SQL CLI versionado `supabase/migrations/20261105221559_p0_v1_master_rls_defense.sql` executado por MCP SQL em transação; pós-consulta `relrowsecurity=true`, `relforcerowsecurity=false`, owner `postgres`, sem `SELECT` para `anon`/`authenticated`, zero policies. `privado.usuario_e_administrador_master()` sem JWT retornou `false`.
- `supabase_migrations.schema_migrations` **não contém** versão `20261105221559` (também não listada pela API list_migrations). **Não reaplicar DDL**.

## Pendências e gates
1. Reconciliar histórico com CLI Supabase `migration repair` somente após inspeção do `--help`, confirmação do alvo HML e autorização de gate separado. Reparar histórico não significa aplicar SQL. Não registrar versão por INSERT manual.
2. Preparar identidades Auth sintéticas novas, sessões JWT válidas MASTER/usuários comuns e negativos; repetir provas pós-RLS, revogar sessões e limpar fixtures. O ensaio anterior 133/133 PASS foi **pré-RLS** e não substitui essas provas.
3. Testar funcionalmente as nove RPCs `SECURITY DEFINER` públicas com perfis e contratos distintos, incluindo BOLA/IDOR, antes de certificar. Advisor `rls_enabled_no_policy` INFO na tabela privada é esperado para DENY direto.
4. Matriz RBAC persistente permanece não implementada; não declarar V1 certificada. PROD intocada.

## Regra operacional
Nesta tarefa `database_changes_allowed=false` e `rls_changes_allowed=false`. Nenhuma alteração HML/PROD ou registro de migração nesta PR. Executar Zero-Drift antes de merge.
