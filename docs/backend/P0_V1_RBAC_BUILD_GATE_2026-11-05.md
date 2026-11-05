# GATE P0 V1 | RBAC persistente | 05/11/2026

Origem: PLAN #54 integrado, provas reais #52 (133/133), issue #53. Este GATE **não autoriza DDL**, somente TDD RED e inventário de dependências antes de abrir allowlist BUILD. HML gklhhhyosgasnyoxlrui. PROD proibida.

## Inspeção real
Funções existentes em HML: privado.usuario_e_administrador_master, privado.usuario_possui_perfil, privado.usuario_tem_acesso_organizacao são SECURITY DEFINER; public.listar_organizacoes_disponiveis, public.validar_administrador_organizacao e public.pode_consultar_auditoria_organizacao são SECURITY INVOKER. Não duplicar MASTER nem criar bypass. Reconciliar todas as políticas de tenant/contrato e RPCs com PRD antes de modificar uma só.

## Gate operacional
1. Produzir RED versionado que falha por ausência da matriz, leitura contextual e edição MASTER, com negação para anônimo, usuário sem vínculo, administrador comum e metadados forjados.
2. Inventariar dependências, grants, RLS, tabelas e funções antes de escolher a migração. Criar arquivo de migração pela CLI, nunca inventar nome.
3. Após RED e manifesto BUILD com arquivos exatos, atualizar task e allowlist, obter CI verde; só então executar HML. Mudanças de autorização exigem advisors e testes HTTP reais com JWT, não apenas SQL simulando role.
4. Não editar frontend antes de contratos RPC testados. MASTER não herda aprovações especializadas. Não modificar PROD.

## Critérios bloqueantes
Sem RED, sem BUILD. Sem isolamento A/B e escopo por contrato, sem GREEN. Sem provas reais, sem certificação. Sem CI Zero-Drift, sem merge. Cleanup das fixtures em quarentena pendente de confirmação legítima, nunca declarar DELETE concluído.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Documento backend sem impacto visual. Frontend futuro preserva Brand 1.0, AppShell, acessibilidade e testes responsivos. Sem Lovable nesta fase.
