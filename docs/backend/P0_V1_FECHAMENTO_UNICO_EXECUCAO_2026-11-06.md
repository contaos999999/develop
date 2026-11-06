# Plano único de fechamento V1 e registro de execução

Autorização do titular: “Resolva tudo em um plano unico” e “Execute integralmente”.
Escopo HML; PROD intocada, V2 bloqueada até certificação V1. Este plano coordena todas as frentes e não converte pendência em PASS.

## Baseline preservado
Backend main 1810c608bf8dc6c3ae5b51db5a0552fe5df1f3e3; PR75 integrado.
133 provas de autorização anteriores, 349 provas pós-RLS e cinco retestes focados PASS permanecem históricos. Não reexecutar sem alteração que os afete.
Issue68 encerrada. Upload/worker não certificados. RLS/MASTER e paridade de migração já corrigidos não serão refeitos.

## Entregas sequenciais
1. Reconciliar 488 critérios indexados, 45 regulares V1, atômicos e 12 RNFs aplicáveis com evidências por requisito.
2. RBAC persistente: catálogo fechado perfil/recurso/ação, negação por padrão, consulta contextual, edição MASTER, auditoria, versão esperada e idempotência/concorrência.
3. Enforcement nas RLS/RPC/Storage V1 pertinentes, sem ampliar acesso atual nem substituir regras de sessão, tenant, contrato e aprovação especializada.
4. ADM-01/sidebar: matriz editável MASTER, organizações/usuários, invalidação de permissões e links diretos; BRAND e tipos congelados preservados.
5. JWT real dos contratos alterados, dez perfis, MASTER sem vínculo, A/B, A1/A2/B1, revogação, vínculos inativos, nove funções afetadas, ausência de efeitos nas negativas.
6. SYS-03 recuperação de senha real com caixa controlada, link válido/expirado/reutilizado e novo login; tokens fora de logs.
7. Teste C privado, teclado/foco/contraste/estados, 1440/1280/768/390, claro/escuro.
8. RNFs nas metas originais, recuperação/backup, observabilidade e custódia. Reaproveitar Auto-Lock já comprovado.
9. Matriz final, regressão, CI/Teste C no SHA, certificado e checkpoints integrados. Requisito obrigatório sem prova mantém NO-GO.

Cada entrega precisa de evidência, commit, teste e resultado. Executar continuamente dentro da autorização existente. Pedir somente insumo externo indispensável que não possa ser obtido nas conexões.

## Execução atual: RBAC
- Contexto: 25 documentos canônicos carregados, fingerprint vigente c5dc0a97dd3a371fbdfbbd425c3fd31089e2d82f7c51a7458f0ecaedc2330088.
- RED executado realmente no HML: supabase/tests/p0_v1_rbac_matrix_red.sql, SQLSTATE P0001, seis objetos ausentes. Não é novo teste JWT.
- Inventário real pg_policies public/storage obtido. Reconciliação por recurso ainda em andamento.
- Gerador CLI offline neste PR não possui segredo, conexão nem DDL. O arquivo gerado precisa ser recuperado e preenchido em BUILD posterior com allowlist exata.
- Deploy somente pelo workflow canônico de paridade deploy_one, CLI 2.81.3, versão GitHub=HML. Não usar apply_migration nem SQL direto para DDL.
- MASTER existente é transversal administrativo e não concede direcao_aprovador.

## Riscos que os testes precisam cobrir
- Usuário de outra organização: nenhuma leitura/mutação.
- Permissão revogada com JWT ainda válido: backend nega.
- Edição concorrente: stale version rejeitada e replay não duplica auditoria.
- MASTER sem vínculo: administração transversal preservada; aprovação especializada continua segregada.
- Permissão de UI divergente: backend permanece autoridade e menu é revalidado.

## Registro de progresso
Etapas 1–9 pendentes de conclusão; pré-requisitos RBAC/RED executados. Não declarar BUILD/GREEN/deploy.
Ressalvas de upload/worker e alcance de isolamento serão reconciliados com provas novas, sem falsa certificação.
Limpeza anterior em quarentena preservada, sem DELETE de auditoria.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Etapa atual backend/documental sem UI. BRAND v1.0 preservada. GitHub/Supabase diretos, testes e gates mantidos, nenhum novo serviço pago.
