# P0 V1: matriz RBAC, organizações e provas autenticadas
Data: 05/11/2026. Origem: solicitação expressa do titular para completar RBAC, verificar organizações e executar autorização/negação autenticadas. Issue frontend #166.

## Baseline e lacuna comprovada
Backend main: 3aa4af7a292b80243045e0a426ee6399ba948ff2. Frontend último BUILD conhecido: PR #177, merge be842a39a413c8ef53c71412ff83be3b0a49b8a9.
Leitura SQL HML gklhhhyosgasnyoxlrui confirmou:
- MASTER privado e vigente, condicionado a auth.sessions. Não depende de vínculo físico.
- listar_organizacoes_disponiveis: MASTER recebe todas; demais recebem somente vínculos ativos/vigentes.
- criar_organizacao já existe, autentica sessão, cria organização/vínculo e audita. Ausência de INSERT direto em organizacoes é intencional, não lacuna.
- usuario_possui_perfil aceita MASTER como administrador, sem atribuir direcao_aprovador.
- Dez perfis: administrador, auditor, contabilidade, direcao_aprovador, financeiro, gestor_contrato, juridico_conformidade, leitor, prestacao_contas, rh_dp.
- Não foram encontradas tabelas de matriz granular perfil/recurso/ação. Existem regras fixas em políticas e RPCs. Não substituir nem duplicar o mecanismo MASTER.
- Não foram executados logins JWT nesta rodada.

## Goal
Entregar matriz persistente consultável/editável por MASTER, autorização material nas operações V1 e provas HTTP com tokens emitidos por Auth, positivas e negativas.

## Architecture
PostgreSQL/Supabase continua fonte única. Matriz se soma à autorização nativa: permissão granular E sessão E tenant E escopo E regras especializadas. A concessão granular não substitui os gates de aprovação.
A matriz terá catálogo fechado de recursos/ações V1 e permissões por perfil, com negação por padrão. Alterações por RPC exclusiva MASTER, auditadas, com versão esperada e idempotência. Org específica não pode alterar concessão MASTER global. Não conceder acesso por e-mail/user_metadata/localStorage.

## Escopo e arquivos
Planejamento: docs/backend/P0_V1_RBAC_ORGANIZACOES_PLAN_2026-11-05.md e docs/tasks/active-task.json.
BUILD backend posterior a gate: nova migration criada pela CLI (nome exato a incluir no manifesto antes do BUILD), supabase/tests/p0_v1_rbac.sql, testes HTTP e relatório em tarefa dedicada. Não editar migrations aplicadas.
Frontend posterior em PLAN/GATE próprio: admUsuariosRpc.ts, AdminUsuarios.tsx, menuV1.ts, ContaOSAppShell.tsx, testes correspondentes. types.ts congelado.
Reconciliar contratos de RPC antes de autorizar o BUILD. Restore isolado, regressão e CI exigidos antes de certificação. Não declarar gates PASS sem resultado.

## Matriz inicial e limites
Derivar os valores iniciais das regras atuais, sem inventar privilégios. Conferência já feita:
- Contratantes e contratos: criar/editar administrador e gestor_contrato.
- Orçamento: administrador, gestor_contrato, financeiro, contabilidade.
- Documentos de competência: editar administrador, gestor_contrato, prestacao_contas, financeiro, contabilidade, rh_dp, juridico_conformidade.
- Documentos contratuais/listas: administrador, gestor_contrato, prestacao_contas, juridico_conformidade.
- Normativo: administrador, gestor_contrato, juridico_conformidade.
- Auditoria: administrador, auditor, juridico_conformidade.
- Parecer: elaborar não implica aprovar; a aprovação deve preservar direcao_aprovador, contexto e segregação.
- Leitura: preservar tenant e escopo a contratos, não transformar perfil em leitura global.
- MASTER: administração transversal e visibilidade de todas as telas V1 existentes; aprovações especializadas continuam protegidas.
Antes de seed, completar a conferência das demais RPCs V1 e registrar cada combinação perfil/recurso/ação e sua fonte.

## Execução nativa, na ordem
- [ ] Gate dedicado: manifesto com fingerprint c5dc0a97dd3a371fbdfbbd425c3fd31089e2d82f7c51a7458f0ecaedc2330088, 25 fontes, lista exata de objetos e autorização DB/RLS, HML exclusivo. CI verde do PLAN separado.
- [ ] TDD RED: matriz ausente, negação sem sessão, MASTER sem vínculo, perfil Contabilidade, escopo contrato A/B, alteração RBAC por não-MASTER, revogação e concorrência.
- [ ] BUILD mínimo incremental, com grants mínimos, RLS em toda tabela exposta e funções privilegiadas internas. Integrar cada autorização V1 por operação, evitando uma matriz apenas informativa.
- [ ] GREEN SQL + restore limpo + regressão canônica, scan de secrets, Architecture Guard, Context Gate e CI.
- [ ] Runner HTTP HML reutiliza segredo de banco já autorizado em environment hml; nunca lê/exporta valor do secret. Criar somente identidades sintéticas próprias, senha aleatória em memória, autenticar em /auth/v1/token e validar /auth/v1/user. SQL set_config não equivale a JWT real.
- [ ] Fixtures organizações A/B e contratos A1/A2/B1. MASTER global sem vínculo, administrador A, dez perfis, usuário sem vínculo, vínculo inativo/futuro/expirado e escopo contratual restrito.
- [ ] Autorização positiva tem de produzir efeito e conferir persistência/auditoria. Negativa tem de comprovar HTTP/SQL esperado E ausência de efeito; não aceitar apenas status menor que 500.
- [ ] Negativas: anônimo, token inválido/expirado, sessão revogada, acesso B por usuário A, UUID conhecido sem escopo, editar matriz por não-MASTER, autoelevação, user_metadata falso, conflito de versão e repetição idempotente.
- [ ] Revogar sessões antes de remover contas; cleanup em finally e verificação independente de zero fixtures. Não alterar contas reais nem expor emails/ids/tokens no relatório.
- [ ] Integrar matriz à administração e navegação via contrato backend, revalidando sessão/organização/revogação e ignorando respostas obsoletas.
- [ ] Teste C separado, visual 1440/1280/768/390 claro/escuro, teclado/contraste/estados e arquivamento de relatório sanitizado. Registrar HEAD, CI, asserts e pendências.

## Rollback
Migration reversa nova e revisada, nunca rewrite. Preservar eventos de auditoria e decisões de permissão. Reverter consumidores por PR e manter negação segura; não restaurar permissões amplas para obter CI verde.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Marca ContaOS Brand v1.0/BRAND-01. Impacto visual deste PLAN backend: N/A, nenhum asset ou componente alterado. Futuro frontend reutiliza ContaOSMarca, tokens e componentes existentes, sem hardcodes ou redesenho, com prova nas quatro larguras e dois temas.
Economia Lovable: GitHub/Supabase diretos; execução agrupada, sem consumir BUILD Lovable; reutilizar provas ainda válidas. Não reduzir TDD, CI, segurança, Teste C nem evidência.
PROD proibida. V1 não certificada. V2 bloqueada. Este PLAN não é implementação nem autorização para pular o gate do manifesto.
