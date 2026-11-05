# P0 V1 | Plano de geração de migration com Supabase CLI em runner

**Estado:** PLAN, sem autorização para DDL. **Ambiente:** exclusivamente HML `gklhhhyosgasnyoxlrui`. PROD proibida.

## Contexto comprovado
- PR #59 integrado, Zero-Drift run 42118305523 SUCCESS, merge `c4b6446f77096fdd123ded343bdcbe9b6ba15513`.
- O ambiente interativo não disponibiliza executável `supabase`; não inventar timestamps ou nomes de migração.
- `docs/tasks/active-task.json` ainda proíbe `supabase/migrations/**`, alterações em RLS e DDL.
- O HML possui a tabela privada MASTER com RLS desabilitado e sem SELECT para `anon`/`authenticated`. Funções privadas SECURITY DEFINER de owner `postgres` precisam de teste de regressão.

## Procedimento de geração, sem aplicar ao HML
1. Em runner confiável com Node e acesso ao repositório, verificar `supabase --version`, `supabase --help`, `supabase migration --help`, `supabase migration new --help`. Usar versão de CLI fixada e aprovada.
2. Criar arquivo exclusivamente com `supabase migration new p0_v1_master_rls_defense`; capturar o caminho efetivamente retornado. Não usar timestamp inventado.
3. Antes de adicionar arquivo, criar um novo gate BUILD e alterar a allowlist para o caminho exato gerado; remover conflito com `supabase/migrations/**` de modo controlado. Preservar demais proibições.
4. Implementação proposta somente após aprovação BUILD: RLS na tabela privada, sem policies abertas para cliente e sem FORCE RLS automático. Validar que proprietário das funções e consultas MASTER continuam funcionais.
5. Preparar rollback reversível com captura prévia de estado, executar teste JWT real MASTER e usuário comum antes/depois, isolamento de organizações, sessão revogada, funções de leitura e escrita, auditoria e Zero-Drift.
6. Aplicar somente em HML depois de merge de migration e verificação de hash, branch protection, teste RED/GREEN e plano de rollback. Registrar commit, execução, resultados e pendências.

## Segurança e rastreabilidade
Nunca imprimir `CONTAOS_HML_DATABASE_URL` em logs; nunca usar `service_role` no navegador. O secret GitHub Actions existente é exclusivo HML. Não confundir documentação PLAN com correção concluída.

## V1
Matriz RBAC persistente, nove RPCs privilegiadas, proteção de senhas vazadas e provas JWT permanecem pendentes. V1 NÃO certificada.
