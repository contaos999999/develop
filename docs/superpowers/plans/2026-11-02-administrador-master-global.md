# Administrador Master Global Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implementar Administrador Master global no HML, integrado à autorização central, ADM-01, login e seleção de organização, sem `service_role` no navegador.

**Architecture:** Identidade global em tabela privada + helper SECURITY DEFINER. Os helpers centrais de RLS passam a reconhecer Master; uma RPC pública de leitura fornece as organizações disponíveis para SYS-01/SYS-04. O frontend apenas consome a autorização decidida pelo backend.

**Tech Stack:** PostgreSQL/Supabase RLS + RPC, React/TypeScript/TanStack Query/Router, GitHub.

**Spec:** `docs/superpowers/specs/2026-11-02-administrador-master-global-design.md`

## Global Constraints
- HML apenas; PROD intocado.
- RLS continua ativa.
- `service_role` nunca no frontend.
- Master global não depende de `vinculos_usuarios`.
- Administrador comum continua organizacional.
- Ações críticas permanecem em RPC/caso de uso protegido.
- TDD RED → GREEN e Teste C separado.
- Economia de créditos Lovable: backend/GitHub fora do Lovable; Lovable somente para frontend/browser.

## Review Focus
- Master sem vínculo consegue listar todas as organizações e acessar contratos de organizações distintas.
- Usuário comum sem vínculo continua sem acesso.
- Administrador de Org A não passa a acessar Org B.
- Master inativo/expirado perde o privilégio.
- SYS-01/SYS-04 não vazam dados entre organizações nem mantêm cache antigo após troca.

---

### Task 1: Identidade Master e helpers centrais
**Files:**
- Create: `supabase/tests/admin_master_global.sql`
- Create: `supabase/migrations/<timestamp>_admin_master_global.sql`

**Interfaces:**
- Produces: `privado.usuario_e_administrador_master() -> boolean`
- Modifies: `privado.usuario_tem_acesso_organizacao(uuid)`, `privado.usuario_tem_acesso_contrato(uuid)`, `privado.usuario_possui_perfil(uuid,text[])`, `privado.usuario_possui_vinculo_ativo()`.

- [ ] Escrever teste RED provando que usuário sem vínculo não possui acesso global e helper Master ainda não existe.
- [ ] Executar RED no HML.
- [ ] Criar tabela privada e helper Master; alterar somente helpers centrais.
- [ ] Executar testes positivos/negativos com dados sintéticos e `ROLLBACK`.
- [ ] Verificar grants, RLS e Security Advisor.

### Task 2: Fonte oficial de organizações e ADM-01
**Files:** mesma migration/teste da Task 1 quando atomicamente relacionado.

**Interfaces:**
- Produces: `public.listar_organizacoes_disponiveis() -> jsonb` ou tipo tabular estável.
- ADM-01 continua usando `validar_administrador_organizacao`/helpers existentes.

- [ ] Testar Master sem vínculo listando Org A e B.
- [ ] Testar usuário comum recebendo apenas organizações vinculadas.
- [ ] Testar Master usando `validar_administrador_organizacao` e listagens ADM-01 em organização sem vínculo.
- [ ] Testar administrador comum negado fora de sua organização.

### Task 3: Frontend SYS-01/SYS-04
**Files:**
- Modify: `src/components/auth/LoginForm.tsx`
- Modify: `src/lib/auth/resolverDestinoPosLogin.ts` se necessário para o novo contrato de dados.
- Modify: `src/components/organizacao/OrganizationSelector.tsx`
- Modify: `src/integrations/supabase/types.ts` apenas para contrato gerado da RPC.
- Tests: `src/test/login.test.tsx`, `src/test/resolverDestinoPosLogin.test.ts`, `src/test/selecionarOrganizacao.test.tsx`.

- [ ] PLAN Lovable único com contrato backend já pronto.
- [ ] RED: Master sem vínculos físicos deve entrar e receber múltiplas organizações.
- [ ] GREEN: login/SYS-04 usam somente `listar_organizacoes_disponiveis`.
- [ ] Regressão completa, typecheck, build, 1440/1280/768/390, teclado/foco/console.

### Task 4: Certificação e integração
- [ ] Teste C separado sem auto-fix.
- [ ] Auditar diff/Zero-Drift.
- [ ] Registrar certificação backend/frontend no GitHub.
- [ ] Abrir PR e integrar somente com testes verdes.
- [ ] Reancorar PROMPT 26 após a mudança transversal.
