# TDD RED RBAC | 05/11/2026

Baseline HML `gklhhhyosgasnyoxlrui`. PR #55 GATE integrado em `cfcef7a48fa172816de85432e457bc4af6bd971c`; Zero-Drift run 42115827623 SUCCESS. PR #54 PLAN integrado.

Consulta SQL de catálogo executada no HML: **zero** tabelas `rbac_%` nos schemas public/privado e **zero** funções `consultar_permissoes_efetivas`, `atualizar_matriz_rbac_master`, `rbac_permite`. Portanto RED de existência de catálogo **confirmado por inspeção real**. O arquivo `supabase/tests/p0_v1_rbac_matrix_red.sql` é teste RED que lança P0001 até existir o catálogo; **não foi executado** nesta rodada. Não confundir inspeção com execução do script. Testes HTTP de edição/negação e concorrência só após a implementação, com JWT real. Nenhuma DDL, grant, RLS ou dado alterado.

Próximo gate: inventário exaustivo das políticas e RPCs por recurso, migração criada pela CLI e allowlist BUILD específica; não liberar DDL antes disso. 133 provas baseline anteriores permanecem válidas. V1 NÃO certificada, PROD intacta.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Sem UI, Brand 1.0 preservada. Sem execução Lovable.
