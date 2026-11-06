# Gate P0 V1: defesa em profundidade da tabela MASTER (HML)

Data: 05/11/2026. Ambiente exclusivo: Supabase HML `gklhhhyosgasnyoxlrui`. Este PR é documental e NÃO autoriza DDL, alteração de Auth ou produção.

## Evidências reais
- `privado.administradores_master`: RLS desabilitado. `anon` não possui USAGE do schema nem SELECT da tabela; `authenticated` possui USAGE do schema, porém não possui SELECT nem UPDATE na tabela. Não foi demonstrada exposição direta da tabela.
- `privado.sessao_usuario_ativa`, `privado.usuario_e_administrador_master`, `privado.usuario_possui_perfil`, `privado.usuario_tem_acesso_organizacao`: todas SECURITY DEFINER, proprietário postgres, executáveis por authenticated. Alterar FORCE RLS sem teste pode mudar comportamento.
- Nove RPCs public SECURITY DEFINER: EXECUTE para authenticated e não para anon; cinco validam sessão/contrato/perfil no corpo público e quatro wrappers delegam a funções privadas com verificações de autenticação/escopo/perfil. Não considerar apenas inspeção estática como prova E2E.

## Gate obrigatório para BUILD
1. Verificar definições integrais, dependências, grants, RLS e owner, e registrar baseline de funções e políticas.
2. Gerar migration com Supabase CLI, sem inventar timestamp; criar allowlist exata de migração no active-task e CI Zero-Drift.
3. Projetar RLS sem policies permissivas a anon/authenticated; não aplicar FORCE ROW LEVEL SECURITY automaticamente.
4. Antes/depois com JWT real: MASTER em duas organizações, perfil comum restrito à própria organização, revogação de vínculo e sessão; negar leitura direta da tabela; testar funções MASTER.
5. Verificar Zero-Drift, advisors, auditoria, rollback e regressão; reverter caso os controles legítimos falhem.
6. Somente depois executar DDL no HML e documentar evidências. PROD permanece proibida.

A matriz RBAC persistente e a proteção de senhas vazadas seguem no mesmo P0, mas em gates próprios. V1 NÃO certificada.

## Zero-Drift
Somente docs e active-task. Nenhuma alteração em banco, migrações, Auth, frontend ou produção.
