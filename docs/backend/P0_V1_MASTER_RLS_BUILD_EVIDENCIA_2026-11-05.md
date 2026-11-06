# Evidência BUILD | MASTER RLS | 05/11/2026

- Workflow manual real: https://github.com/contaos999999/develop/actions/runs/42119980043
- Resultado: success; job 127569476691; CLI v2.81.3; head main 3cc7fd1d841a09d1f19b166fec4672ef2cb12afa.
- Artefato: ID 13458405355, digest sha256:c8341354c22f13b00afe35aec4b7998b1e3f35ee00c86c53e03ed31fde30f063.
- ZIP inspecionado: 20261105221559_p0_v1_master_rls_defense.sql com 0 bytes, como gerado pela CLI. Conteúdo SQL deste PR foi escrito sobre o caminho autêntico, não sobre timestamp inventado.
- Baseline HML inspecionada previamente: owner postgres, RLS false, FORCE false, zero policies, anon/authenticated sem SELECT.
- SQL neste PR: habilita somente RLS convencional, não FORCE e não policies/grants. Guardas recusam drift de grants, owner e RLS, e verificam pós-condições.
- Testes ainda obrigatórios ANTES da aplicação: JWT MASTER válido duas organizações, perfil comum restrito, ausência de vínculo, sessão revogada; RPCs SECURITY DEFINER com seus fluxos operacionais. Verificar advisor e SQL completo das dependências. Capturar baseline antes e comparar depois. Rollback condicionado ao cenário anterior: ALTER TABLE privado.administradores_master DISABLE ROW LEVEL SECURITY, somente mediante incidente confirmado e auditado; nunca executar automaticamente.
- IMPORTANTE: SQL versionado e PR merge NÃO são evidência de aplicação à HML. Flag database_changes_allowed e rls_changes_allowed devem continuar false até gate de execução específico, com testes de segurança autorizados. PROD proibida. V1 NÃO CERTIFICADA.
