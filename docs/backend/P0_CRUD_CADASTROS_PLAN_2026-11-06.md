# P0 CRUD global — comandos canônicos de organizações e contratos
Data:06/11/2026. Autorização expressa do titular: executar integralmente CRUD global sem parar até concluir, mantendo Supabase. HML gklhhhyosgasnyoxlrui; PROD proibido.
Status: PLAN técnico VALIDADO; BUILD separado após guard SUCCESS e integração deste gate.

## Lacuna e evidência
Frontend já integrado até PR241. Catálogo HML confirmou ausência de atualização/transição canônica de contratos (#89) e de organizações. Existem versões, comandos_idempotentes, auditoria, RBAC e triggers. Criar/consultar já existem; orçamento possui remoção de rubrica em rascunho.
Nova migration gerada pela CLI real2.81.3, arquivo exato supabase/migrations/20261106230839_p0_crud_organizacoes_contratos.sql; somente scaffold local vazio antes deste gate. Nunca reescrever migration aplicada.
Touch genérico incrementa versao_registro além de controlar_versao_registro: usar touch exclusivo nestes dois cadastros para garantir incremento exatamente1, sem alterar a função genérica nem outras tabelas.
Não acrescentar DELETE de cadastros com retenção: história, auditoria e versões permanecem. Ações de exclusão permitidas por módulos existentes continuam sob seus contratos próprios.

## Arquitetura e interfaces públicas
Reutilizar tabelas e catálogo RBAC existentes, sem novo schema, tabela, permissão genérica ou backend paralelo.
1. obter_cadastro_operacional_v1(p_id_organizacao uuid,p_entidade text,p_id uuid)→jsonb: entidade fechada organizacoes|contratos, registro explícito e ações permitidas calculadas no backend.
2. atualizar_organizacao_v1(p_id_organizacao uuid,p_versao_esperada bigint,p_alteracoes jsonb,p_motivo text,p_request_id uuid)→jsonb.
3. alterar_situacao_organizacao_v1(p_id_organizacao uuid,p_versao_esperada bigint,p_situacao text,p_motivo text,p_request_id uuid)→jsonb.
4. atualizar_contrato_v1(p_id_organizacao uuid,p_id_contrato uuid,p_versao_esperada bigint,p_alteracoes jsonb,p_motivo text,p_request_id uuid)→jsonb.
5. alterar_situacao_contrato_v1(p_id_organizacao uuid,p_id_contrato uuid,p_versao_esperada bigint,p_situacao text,p_motivo text,p_request_id uuid)→jsonb.
Wrappers públicos SECURITY INVOKER, search_path vazio, EXECUTE apenas authenticated. Implementações privilegiadas só em privado, allowlist fechada, sessão ativa, RBAC E papel/escopo canônicos, sem SQL dinâmico de nomes/tabelas. Nenhum secret no cliente.
Resposta schema_versao=crud-cadastro-v1, entidade, registro com id/org/situação/versão e campos autorizados, pode_editar e transicoes fornecidos pelo backend, exclusao_permitida=false e fundamento de retenção. Mutação acrescenta request_id e evento_id.

## Políticas conservadoras para completar operações ausentes
Decisões de implementação dentro dos estados canônicos existentes, sem inventar estados novos:
- Organizações: administrar + papel administrador ou MASTER; ativa↔inativa. Suspender/reativar suspensa apenas MASTER, evitando que suspensão administrativa seja contornada. Listagem já inclui organizações inativas/suspensas, permitindo gestão/reativação autorizada.
- Contratos: editar + administrador/gestor ou MASTER, acesso ao contrato e organização correspondente. Organização deve estar ativa para mutações de contrato.
- Transições: rascunho→ativo|cancelado; ativo→suspenso|encerrado|cancelado; suspenso→ativo|encerrado|cancelado; encerrado/cancelado são terminais neste delta. Reabrir exige regra própria futura. O frontend usa transicoes retornadas; não calcula autorização.
- Metadados organização: razão social, nome fantasia, CNPJ. Preservar idioma, moeda, timezone e identificadores.
- Contrato: número, objeto, tipo, unidade, fonte, início/fim, valores global/mensal, periodicidade, prazo, dia-limite e criticidade. Proibir transferência de organização/contratante e edição de identificadores, configuração financeira/diligência, versão e campos de auditoria.
- Motivo obrigatório3–2000caracteres. Alteração usa versão esperada positiva, lock do cadastro, regra de vigência/valores e enums originais.
- Novas alterações contratuais geram snapshots/hash em versoes_contrato preservando estado anterior e posterior. Triggers existentes de invalidação de portão permanecem.
- Idempotência usa comandos_idempotentes com namespace fechado, request UUID, hash incluindo ator/org/alvo/versão/ação/payload/motivo, lock transacional, replay exato sem nova auditoria e409 se chave for reutilizada com outro conteúdo. Autorizar novamente antes do replay, inclusive após revogação.
- Lock organizacional antes do contrato evita alteração simultânea da situação organizacional durante edição de contrato. Não relaxar RLS/grants de tabelas.

## Arquivos permitidos
- docs/backend/P0_CRUD_CADASTROS_PLAN_2026-11-06.md
- docs/backend/P0_CRUD_CADASTROS_RESULTADO_2026-11-06.md
- docs/tasks/active-task.json
- supabase/migrations/20261106230839_p0_crud_organizacoes_contratos.sql
- supabase/tests/p0_crud_cadastros.sql
- supabase/tests/p0_crud_cadastros_jwt.py
- supabase/tests/p0_crud_cadastros_catalog_expected.json
- supabase/tests/history_catalog_compare.py (somente comparação explícita dos objetos novos aprovados; não dispensar diferenças inesperadas)
- .github/workflows/restore-isolado.yml (acrescentar suíte local CRUD; preservar testes existentes)
- .github/workflows/p0-crud-cadastros-hml.yml (orquestração HML protegida e provas JWT)
Proibidos frontend/src, tipos congelados, fontes normativas, Auth/schema/configuração, RLS existente, Storage, Edge e PROD. Fixtures Auth sintéticas próprias são permitidas apenas para os testes, sem alteração de configuração Auth.

## Ciclo e prova
1. Gate documental guard verde; RED real por ausência das cinco APIs no catálogo, sem DDL/dados.
2. BUILD com migration CLI e suíte local em transação rollback, sessão SQL sintética declarada como tal; testar permissões/estados/campos/versão/snapshots/auditoria/replay/negativas.
3. Restore isolado integral continua obrigatório. Catálogo histórico admite apenas registros exatos de nove funções novas aprovadas e continua bloqueando qualquer outro delta. Sem excluir nomes de forma ampla ou relaxar ACL.
4. CI guard + restore integral PASS no mesmo HEAD antes de merge/mutação HML.
5. Orquestrador só main após restore SUCCESS, guard SUCCESS, HEAD vivo idêntico, hash da migration fixo e manifesto específico. Disparar workflow canônico p0-hml-migration-version-parity.yml com deploy_one e versão20261106230839, usando GITHUB_TOKEN actions:write apenas no job necessário. Confirmar só uma migration pendente e paridade completa.
6. Provas JWT reais pós-deploy: usuários Auth sintéticos próprios, MASTER sem vínculo, administrador, leitor e usuário sem acesso em A/B; GET/API, edição, ativação/inativação/suspensão/encerramento, concorrência/replay, BOLA/BOPLA, negações sem efeitos, revogação. Sem modificar matriz global nem dados reais.
7. Credenciais geradas e tokens somente em RUNNER_TEMP privado, nunca logs/artifacts. Fixtures ficam em quarentena auditável ao final; sessões revogadas, usuários banidos e vínculos inativos. Não apagar auditoria/histórico para limpar teste.
8. Reancorar frontend no HEAD backend e executar PLAN frontend separado para formulários/ações de ambas entidades. Nada de conectar botão a API ausente ou status crítico por update genérico.
Rollback por migration corretiva/revogação dos novos pontos de entrada e restauro dos dois touch anteriores; preservar snapshots, eventos e comandos. Nunca apagar migration aplicada ou dados históricos.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
impacto_visual N/A: tarefa backend; nenhum asset/tema/tipo/rota frontend. GitHub e Supabase diretos; sem BUILD Lovable. TDD, CI, restauração, segurança, fonte, auditoria e Teste C posteriores não dispensados. Não certificar V1/CRUD global por este plano. Economia nunca substitui evidência.

## Emenda de segurança do deploy (06/11/2026)
Revisão independente detectou corrida entre gate TESTED_HEAD e workflow_dispatch --ref main. Acrescentar exclusivamente .github/workflows/p0-hml-migration-version-parity.yml à allowlist para receber expected_source_sha e expected_migration_sha256 no deploy_one, checkout do SHA exato e validação de hash antes de qualquer db push. Orquestrador passa ambos valores. Operação repair_68 preservada. Remover gatilho push histórico RBAC para não provocar deploy antigo inadvertido pela emenda. PLAN desta extensão precede BUILD. O touch dedicado também nega UPDATE authenticated direto, mantendo as duas triggers e nove funções previstas.
