# P0 V1 | Manifesto BUILD RBAC granular | 05/11/2026

**Status: PLAN, não BUILD.** Origem: autorização do titular, PLAN #50, GATE #51, 133 provas autenticadas integradas pelo PR #52, issue #53. HML: gklhhhyosgasnyoxlrui. PROD proibida. V1 não certificada; V2 bloqueada.

## Fronteira de autorização
Acesso efetivo = sessão Auth vigente E tenant/organização ativa E vínculo vigente ou MASTER vigente E escopo do contrato E permissão perfil/recurso/ação E regra especializada de estado/aprovação. Uma matriz positiva nunca deve ampliar as políticas/RPC existentes. Ausência de combinação é DENY. Nunca confiar em user_metadata, menu, claims desatualizadas ou role do cliente. MASTER não ganha aprovação direcao_aprovador.

## Catálogo V1 inicial, sujeito à reconciliação com todas as políticas e RPCs
Recursos: organizacoes, usuarios, auditoria, contratantes, contratos, orcamentos, normativos, documentos_contrato, documentos_competencia, competencias, analises, pareceres, apresentacoes, diligencias, historico. Ações candidatas: consultar, criar, editar, excluir, aprovar, apresentar, reapresentar, administrar. Somente combinações efetivamente existentes e autorizadas pelas fontes canônicas serão inseridas. Perfil base: administrador, auditor, contabilidade, direcao_aprovador, financeiro, gestor_contrato, juridico_conformidade, leitor, prestacao_contas, rh_dp. MASTER é identidade transversal privada, não novo perfil de vinculo.

## Objetos propostos e controle de mudanças
1. Tabelas **privado.rbac_catalogo_acoes**, **privado.rbac_permissoes_perfis**, **privado.rbac_versoes**: catálogo fechado, chave composta única (perfil,recurso,acao), boolean permitido, versão e auditoria. Schema privado não exposto. Confirmar inexistência/colisão no catálogo antes de BUILD.
2. RPC de leitura autenticada e contextual **public.consultar_permissoes_efetivas**: devolve somente ações permitidas para organização/contrato solicitado após validação de sessão, tenant e escopo; sem aceitar id_usuario arbitrário. Não substitui autorização em RLS.
3. RPC de alteração exclusiva MASTER **public.atualizar_matriz_rbac_master**: catálogo fechado, expected_version e request_id único, idempotência, transação atômica, evento auditável; erro 42501 para não-MASTER; nenhuma operação direta de INSERT/UPDATE/DELETE pelo cliente.
4. Predicado interno **privado.rbac_permite**: sessão, perfil atual e matriz; invocação a partir das políticas/RPC existentes, com dependências revisadas para não criar recursão nem privilégio via SECURITY DEFINER. Qualquer função privilegiada exige justificativa, schema privado, search_path fixo, EXECUTE restrito e revisão de advisors.
5. Integração progressiva nas RLS/RPC existentes por recurso e ação; preservar USING/WITH CHECK, escopo contratual, segregação de aprovações, isolamento tenant e regras de estado. Não trocar todas as políticas num único corte sem restore e rollback ensaiados.
6. Frontend ADM-01: exibir matriz somente ao MASTER, controles acessíveis, edição versionada, feedback de conflito, revalidação após troca de organização, sem presumir autorização a partir da UI. BRAND-01 e AppShell preservados.

## Sequência e arquivos permitidos
Esta branch: **somente** docs/backend/P0_V1_RBAC_BUILD_MANIFESTO_2026-11-05.md. Nenhuma alteração SQL ou frontend.
Próxima tarefa BUILD requer novo docs/tasks/active-task.json, manifesto de migração com nome real criado pela CLI, arquivos exatos em supabase/migrations e supabase/tests, TDD RED, gate CI e autorização já concedida condicionada aos controles. Frontend somente após contrato RPC estabilizado, com PLAN/GATE próprio. Nenhuma alteração em types.ts, auth config, schema PROD ou fontes canônicas.

## Aceite verificável
- RED: matriz ausente e tentativas de autoelevação/alteração por não-MASTER; sem DDL antes do gate.
- GREEN: autorização positiva com efeito e auditoria, negativa com ausência de efeito, dez perfis, MASTER sem vínculo, org A/B, contrato A1/A2/B1, vínculo inativo, JWT revogado, idempotência, conflito de versão, concorrência, aprovação especializada e Storage.
- CI Zero-Drift, teste C independente, advisors, restore em HML, diff de grants/policies, secret scan e regressão canônica.
- Remoção definitiva das 12 contas sintéticas em quarentena, somente mediante confirmação válida, sem apagar auditoria. Não repetir as 133 provas baseline sem justificativa.

## Impedimentos explícitos
Catálogo de políticas/RPCs completo ainda precisa de reconciliação e definição de objetos por migration. Este manifesto não declara RBAC implementado nem autoriza aplicar DDL com a allowlist anterior, que explicitamente proíbe migrations. PR #52 está integrado; este PLAN é a próxima etapa.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual desta etapa: N/A. Futuro frontend deve reutilizar Brand v1.0, testar 1440/1280/768/390 em claro/escuro e teclado. GitHub/Supabase diretos, sem consumo Lovable nesta etapa; controles de segurança e CI preservados.
