# Auditoria de grants RBAC e MASTER | HML | 05/11/2026

Ambiente exclusivamente HML `gklhhhyosgasnyoxlrui`. Evidência SQL real, somente leitura. Zero mudanças em PROD, Auth, RLS, grants e DDL.

## Exposição da tabela MASTER
Consultas `has_schema_privilege` e `has_table_privilege`:
- anon: USAGE do schema privado = false; SELECT na tabela privado.administradores_master = false.
- authenticated: USAGE do schema privado = true; SELECT = false; UPDATE = false.
- RLS desabilitado conforme `list_tables`; **não foi comprovado acesso direto** de cliente à tabela. O alerta exige defesa em profundidade, mas habilitar RLS sem avaliar funções SECURITY DEFINER, owner e política pode causar indisponibilidade MASTER. Não aplicar correção cega.

## Nove funções públicas privilegiadas
SQL `has_function_privilege`: todas as nove com EXECUTE para authenticated e **nenhuma** com EXECUTE para anon:
1. adicionar_versao_documento_competencia_v115
2. criar_documento_competencia_v115
3. enfileirar_ingestao_historica_hml
4. obter_analise_competencia_v116
5. obter_detalhe_requisito_v117
6. obter_documentos_competencia_v115
7. obter_visao_geral_competencia
8. registrar_relatorio_historico_hml
9. vincular_tratamento_historico_hml

Inspeção parcial `pg_get_functiondef` confirmou `search_path=''` nas nove, wrappers V1-15/16 com delegação privada e verificações de `auth.uid()`, perfil e contrato nas rotinas históricas examinadas. **Não é prova de ausência de vulnerabilidade**: auditar integralmente as funções internas chamadas, testes HTTP JWT por papel, isolamento A/B, revogação e side effects.

## Impedimentos e gate
`docs/tasks/active-task.json` ainda proíbe `supabase/migrations/**` e alterações de RLS/Auth. Antes de qualquer DDL: reconciliar todas as políticas e dependências, migration nomeada pela CLI, allowlist BUILD, CI Zero-Drift, RED/GREEN e rollback HML. Não alterar função legítima apenas para zerar alerta do advisor. Proteção contra senha vazada depende de configuração Auth, a ser habilitada apenas após checagem de impacto e ferramenta autorizada.

**Estado:** auditoria de grants concluída; correções e RBAC persistente pendentes; V1 NÃO certificada.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Sem alteração visual, Brand 1.0 e AppShell preservados; sem uso Lovable.
