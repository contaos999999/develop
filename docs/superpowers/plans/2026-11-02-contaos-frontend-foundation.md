# ContaOS Frontend Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir a fundação visual e técnica do frontend ContaOS com a linguagem Executive Command Center + Audit Workspace, validá-la em protótipo antes do Lovable e preparar uma base React/TypeScript testável para as telas 1.0 a 5.0.

**Architecture:** O frontend será isolado em `frontend/` e consumirá apenas o Supabase HML certificado por interfaces públicas permitidas, sem criar regra crítica no cliente. O design system e os shells serão definidos primeiro, seguidos por autenticação/contexto, dashboard e workspaces; módulos funcionais 1.0 a 5.0 serão implementados em planos separados sobre essa fundação.

**Tech Stack:** MagicPath, Lovable, React, TypeScript strict, TanStack conforme scaffold do Lovable, Supabase JS com publishable key, CSS/Tailwind conforme scaffold, Vitest/Testing Library quando presentes no scaffold, Playwright para E2E e regressão visual.

**Spec:** `docs/superpowers/specs/2026-11-02-contaos-frontend-master-design.md`

## Global Constraints

- Fonte funcional: PRD Mestre 4.1 e `06_FRONTEND_LOVABLE_ESPECIFICACAO_4_1.md`.
- Direção visual aprovada: `Executive Command Center + Audit Workspace`.
- Frontend oficial: Lovable/React/TypeScript.
- Backend oficial: Supabase próprio HML; nenhuma alteração de backend nesta tarefa.
- `service_role`, chave OpenAI, token interno, senha de banco ou qualquer secret são proibidos no browser.
- O frontend não calcula `PODE APRESENTAR AO CONTRATANTE`, `PODE REAPRESENTAR AO CONTRATANTE` nem `VALIDADA`.
- Ações críticas chamam apenas RPC/Edge Function oficial já existente.
- Mensagens ao usuário em PT-BR; datas/horas em padrão brasileiro e fuso da organização/Brasília conforme contrato vigente.
- TypeScript strict; nenhum `any` novo injustificado.
- Responsividade obrigatória: 1440, 1280, 768 e 390 px.
- Status nunca dependem apenas de cor.
- Estados mínimos: loading, empty, success, denied/403 e error; saving/processing/conflito/expirado quando aplicável.
- PROD permanece intocado.

## Review Focus

1. **Troca de organização:** limpar dados/cache visual da organização anterior e nunca misturar conteúdo entre organizações. Testado na Task 6.
2. **Sessão expirada/revogada:** sair do fluxo protegido sem loop, sem reutilizar conteúdo anterior e com mensagem segura. Testado na Task 6.
3. **Estado crítico divergente:** a UI deve refletir o backend e nunca inferir um portão pelo percentual exibido. Testado na Task 8.
4. **Conteúdo longo/denso:** tabelas, nomes de documentos, pareceres e evidências extensas não podem causar clipping ou ocultar informação crítica em 1280/768/390. Testado nas Tasks 4, 7 e 9.
5. **Usuário sem permissão:** esconder/desabilitar controles é apenas UX; resposta 403/RLS deve ser tratada como acesso negado sem fallback inseguro. Testado nas Tasks 6 e 9.

---

## File Structure Locked by This Plan

Quando o Lovable for conectado, a implementação será normalizada para esta estrutura, preservando arquivos obrigatórios do scaffold quando equivalentes:

```text
frontend/
  src/
    app/
      AppShell.tsx
      navigation.ts
      routes.tsx
    components/
      ui/
      feedback/
      status/
      evidence/
      gates/
      workspace/
    features/
      auth/
      organization/
      dashboard/
    lib/
      supabase/client.ts
      formatting/date.ts
      formatting/money.ts
      errors/mapAppError.ts
    styles/
      tokens.css
      globals.css
    test/
      setup.ts
  tests/
    e2e/
    visual/
  playwright.config.ts
  package.json
  tsconfig.json
```

Documentação persistente:

```text
docs/frontend/
  DESIGN_SYSTEM.md
  DECISOES.md
  PROTOTIPOS.md
  TESTES.md
```

---

### Task 1: Congelar a governança de frontend e o design system documental

**Files:**
- Create: `docs/frontend/DESIGN_SYSTEM.md`
- Create: `docs/frontend/DECISOES.md`
- Create: `docs/frontend/PROTOTIPOS.md`
- Create: `docs/frontend/TESTES.md`
- Modify: `docs/tasks/active-task.json`

**Interfaces:**
- Consumes: Master Design aprovado e contexto 4.1.
- Produces: fonte persistente para tokens, padrões de shell, motion, acessibilidade, protótipos e testes.

- [ ] **Step 1: Registrar ADR-FE-001**

Em `DECISOES.md`, registrar a decisão `Executive Command Center + Audit Workspace`, alternativas rejeitadas e proibição de estética excessivamente decorativa.

- [ ] **Step 2: Materializar tokens e regras no DESIGN_SYSTEM**

Definir semanticamente superfícies, texto, bordas, foco, success/warning/danger/info, tipografia, escala de espaçamento, radius, sombras, densidade e motion. Não fixar cor crítica sem verificar contraste WCAG no protótipo.

- [ ] **Step 3: Registrar matriz de testes**

Em `TESTES.md`, fixar 1440/1280/768/390, teclado/foco, estados mínimos, 403, sessão expirada, troca de organização e portões críticos.

- [ ] **Step 4: Commit**

```bash
git add docs/frontend docs/tasks/active-task.json
git commit -m "docs(frontend): congela governança visual da fundação"
```

---

### Task 2: Criar protótipos de referência no MagicPath antes do Lovable

**Files:**
- Modify: `docs/frontend/PROTOTIPOS.md`

**Interfaces:**
- Consumes: `DESIGN_SYSTEM.md` e Master Design.
- Produces: referências visuais aprováveis para `SYS-01`, `SYS-05`, `V1-06`, `V1-16` e `V5-12`.

- [ ] **Step 1: Criar projeto MagicPath `ContaOS Frontend 4.1`**

Usar canvas desktop 1440 como referência principal e preservar capacidade responsiva.

- [ ] **Step 2: Prototipar SYS-01 Login**

Critérios: identidade premium sóbria, formulário acessível, estados erro/loading e sem linguagem de segurança sensível.

- [ ] **Step 3: Prototipar SYS-05 Dashboard**

Critérios: Command Center com prioridades, contratos/competências, risco e pendências; sem gráficos ornamentais e sem estado inventado.

- [ ] **Step 4: Prototipar V1-06 Contrato — visão geral**

Critérios: shell de contrato, contexto persistente, navegação por domínio, status e próximos passos visíveis.

- [ ] **Step 5: Prototipar V1-16 Competência — análise**

Critérios: Audit Workspace denso, evidência/fonte, requisitos e apontamentos legíveis, ações críticas separadas.

- [ ] **Step 6: Prototipar V5-12 Painel executivo**

Critérios: visão multi-contrato/multi-entidade, sem vazamento visual entre organizações e com hierarquia executiva clara.

- [ ] **Step 7: Registrar IDs/links e decisão visual**

Salvar em `PROTOTIPOS.md` o projeto, componentes aprovados, data e observações de design que o Lovable deverá reproduzir.

- [ ] **Step 8: Revisão visual**

Validar manualmente contraste, densidade, clipping e coerência entre Command Center e Audit Workspace antes de conectar Lovable.

---

### Task 3: Inicializar scaffold Lovable somente após conexão explícita

**Files:**
- Create: `frontend/**` conforme scaffold oficial.
- Do not modify: `supabase/**`.

**Interfaces:**
- Consumes: protótipos aprovados e `06_FRONTEND_LOVABLE_ESPECIFICACAO_4_1.md`.
- Produces: aplicação React/TypeScript executável sem backend paralelo.

- [ ] **Step 1: Gerar scaffold pelo Lovable**

Exigir React + TypeScript strict e integração Supabase por `VITE_SUPABASE_URL` + publishable key. Não aceitar secret key.

- [ ] **Step 2: Rodar baseline antes de customizar**

Run: comandos de install/typecheck/lint/test/build definidos pelo scaffold.
Expected: baseline executável; qualquer falha deve ser registrada antes de design customizado.

- [ ] **Step 3: Criar teste de segurança de configuração**

Teste deve falhar se bundle/env frontend expuser nomes/padrões de `service_role`, `sb_secret`, chave OpenAI ou token interno.

- [ ] **Step 4: Implementar cliente Supabase único**

Interface: `frontend/src/lib/supabase/client.ts` exporta somente o cliente browser oficial criado a partir de URL + publishable key.

- [ ] **Step 5: Rodar testes e build**

Expected: PASS sem mudança em `supabase/**`.

- [ ] **Step 6: Commit**

```bash
git add frontend
git commit -m "feat(frontend): inicializa scaffold Lovable seguro"
```

---

### Task 4: Implementar tokens, primitives e estados visuais

**Files:**
- Create: `frontend/src/styles/tokens.css`
- Create: `frontend/src/styles/globals.css`
- Create: `frontend/src/components/status/StatusBadge.tsx`
- Create: `frontend/src/components/feedback/AppState.tsx`
- Create: `frontend/src/components/ui/SectionHeader.tsx`
- Test: arquivos de teste co-localizados ou padrão do scaffold.

**Interfaces:**
- Produces: `StatusBadge`, `AppState`, `SectionHeader` e tokens semânticos reutilizados por todas as telas.

- [ ] **Step 1: Escrever testes de StatusBadge/AppState**

Asserts: texto sempre presente; ícone/label além da cor; `loading`, `empty`, `error`, `denied`, `success`, `processing` renderizam sem depender de cor.

- [ ] **Step 2: Rodar testes e confirmar FAIL**

Expected: componentes ainda inexistentes.

- [ ] **Step 3: Implementar tokens e componentes mínimos**

`StatusBadge` recebe `{ label: string; tone: 'neutral'|'info'|'success'|'warning'|'danger' }` e nunca interpreta status de negócio sozinho.

- [ ] **Step 4: Testar contraste e teclado**

Executar testes de componente e smoke accessibility definidos no scaffold.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/styles frontend/src/components
git commit -m "feat(frontend): adiciona design tokens e estados visuais"
```

---

### Task 5: Implementar App Shell e navegação contextual

**Files:**
- Create: `frontend/src/app/AppShell.tsx`
- Create: `frontend/src/app/navigation.ts`
- Create: `frontend/src/components/workspace/WorkspaceHeader.tsx`
- Create: `frontend/src/components/workspace/ContextSwitcher.tsx`
- Test: shell/navigation tests.

**Interfaces:**
- Produces: `AppShell`, `WorkspaceHeader`, `ContextSwitcher`.
- Consumes: tokens e primitives da Task 4.

- [ ] **Step 1: Escrever testes do shell**

Asserts: sidebar desktop, navegação recolhível em 768, ação principal/contexto preservados em 390, foco visível e navegação por teclado.

- [ ] **Step 2: Confirmar FAIL**

- [ ] **Step 3: Implementar AppShell**

Sidebar por domínio: Visão geral, Contratos, Competências, Financeiro, Inteligência, Conformidade e Administração conforme permissão. Não inferir autorização a partir da visibilidade do item.

- [ ] **Step 4: Implementar WorkspaceHeader/ContextSwitcher**

Exibir organização, contrato e competência atuais; troca de contexto deve emitir evento/callback explícito para limpeza de cache na camada de dados.

- [ ] **Step 5: Rodar testes 1440/768/390**

Expected: sem clipping; ação principal e status preservados.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/app frontend/src/components/workspace
git commit -m "feat(frontend): implementa shell e contexto global"
```

---

### Task 6: Implementar autenticação e seleção de organização

**Files:**
- Create: `frontend/src/features/auth/LoginPage.tsx`
- Create: `frontend/src/features/auth/ForgotPasswordPage.tsx`
- Create: `frontend/src/features/auth/ResetPasswordPage.tsx`
- Create: `frontend/src/features/organization/SelectOrganizationPage.tsx`
- Create: `frontend/src/features/organization/organization-context.tsx`
- Test: auth/org unit tests and Playwright specs.

**Interfaces:**
- Consumes: cliente Supabase da Task 3.
- Produces: sessão UI e contexto de organização; não produz token próprio.

- [ ] **Step 1: Escrever testes de login e erro seguro**

Asserts: erro de credencial não revela existência de usuário; botão desabilita durante envio; sucesso segue para seleção/dashboard conforme vínculos.

- [ ] **Step 2: Escrever teste de sessão expirada**

Asserts: conteúdo protegido é limpo e usuário retorna ao login sem loop.

- [ ] **Step 3: Escrever teste de troca de organização**

Asserts: cache/dados visuais anteriores são limpos antes de renderizar nova organização.

- [ ] **Step 4: Implementar fluxo mínimo**

Usar Supabase Auth oficial; não armazenar token customizado; não usar `localStorage` manual para credenciais.

- [ ] **Step 5: Rodar unit + E2E**

Expected: happy path, erro, sessão expirada e troca de organização PASS.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/features/auth frontend/src/features/organization frontend/tests
git commit -m "feat(frontend): implementa auth e contexto organizacional"
```

---

### Task 7: Implementar Dashboard e shells de contrato/competência

**Files:**
- Create: `frontend/src/features/dashboard/DashboardPage.tsx`
- Create: `frontend/src/components/workspace/ContractWorkspace.tsx`
- Create: `frontend/src/components/workspace/CompetencyWorkspace.tsx`
- Test: dashboard/workspace tests.

**Interfaces:**
- Consumes: AppShell, organização selecionada e dados reais HML via interfaces autorizadas.
- Produces: fundação visual para SYS-05, V1-06 e V1-14 sem implementar regras específicas dos módulos.

- [ ] **Step 1: Escrever testes de estados**

Asserts para loading, empty, success, 403 e error; dados longos não removem status/prazo/ação principal.

- [ ] **Step 2: Implementar Dashboard como Command Center**

Cards apenas para indicadores realmente prioritários; listas/tabelas para pendências e próximos passos; nenhuma regra crítica local.

- [ ] **Step 3: Implementar ContractWorkspace e CompetencyWorkspace**

Contexto, breadcrumbs, status oficial, tabs/rotas filhas e slot para ação principal.

- [ ] **Step 4: Rodar testes responsivos**

Expected: 1440/1280/768/390 sem clipping/overlap crítico.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/features/dashboard frontend/src/components/workspace
git commit -m "feat(frontend): adiciona dashboard e workspaces base"
```

---

### Task 8: Implementar componentes críticos de portão, evidência e IA

**Files:**
- Create: `frontend/src/components/gates/CriticalGate.tsx`
- Create: `frontend/src/components/evidence/EvidencePanel.tsx`
- Create: `frontend/src/components/evidence/SourceReference.tsx`
- Test: gate/evidence tests.

**Interfaces:**
- `CriticalGate` consumes `{ label, state, blockers, action }` vindos do backend/adaptador e não calcula elegibilidade.
- `EvidencePanel` diferencia dado objetivo, inferência IA e decisão humana.

- [ ] **Step 1: Escrever teste anti-cálculo local**

Dado `percentual=100` mas `gate.state='blocked'`, o componente deve continuar bloqueado. Nenhuma inferência pelo percentual.

- [ ] **Step 2: Escrever teste dos rótulos oficiais**

Aceitar/exibir exatamente `PODE APRESENTAR AO CONTRATANTE` e `PODE REAPRESENTAR AO CONTRATANTE` quando recebidos do backend; não gerar `Apta para...`.

- [ ] **Step 3: Implementar CriticalGate**

Ação crítica exige confirmação de consequência e fica desabilitada durante requisição.

- [ ] **Step 4: Implementar EvidencePanel/SourceReference**

Mostrar fonte, versão/página/trecho quando disponível, confiança e tipo de conteúdo; IA nunca aparece como norma sem fonte formal.

- [ ] **Step 5: Rodar testes**

Expected: divergência percentual/portão, labels e evidências PASS.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/components/gates frontend/src/components/evidence
git commit -m "feat(frontend): adiciona portoes e evidencias explicaveis"
```

---

### Task 9: Instalar e consolidar Playwright/Webapp Testing

**Files:**
- Create: `frontend/playwright.config.ts`
- Create: `frontend/tests/e2e/auth.spec.ts`
- Create: `frontend/tests/e2e/organization-isolation.spec.ts`
- Create: `frontend/tests/e2e/dashboard.spec.ts`
- Create: `frontend/tests/visual/foundation.visual.spec.ts`
- Create: `.github/workflows/frontend-quality.yml`
- Modify: `docs/frontend/TESTES.md`

**Interfaces:**
- Consumes: aplicação das Tasks 3–8.
- Produces: gate automatizado para fluxo, permissão, responsividade e regressão visual.

- [ ] **Step 1: Configurar projects Playwright**

Viewports mínimos: 1440, 1280, 768 e 390. Não registrar secrets, tokens, documentos ou PII em traces de CI.

- [ ] **Step 2: Criar E2E de autenticação/contexto**

Cobrir happy path, credencial inválida, sessão expirada, troca de organização e 403.

- [ ] **Step 3: Criar E2E de dashboard/shell**

Cobrir navegação por teclado, contexto persistente e estados loading/empty/error via fixtures controladas ou ambiente HML seguro.

- [ ] **Step 4: Criar regressão visual**

Capturas das telas de referência alinhadas ao MagicPath nos quatro viewports; diferenças exigem revisão humana.

- [ ] **Step 5: Criar workflow frontend-quality**

Executar install lockfile, typecheck, lint, unit/component, build e Playwright. Actions de terceiros devem ser fixadas por SHA antes de merge.

- [ ] **Step 6: Rodar suíte completa**

Expected: todos os gates PASS.

- [ ] **Step 7: Commit**

```bash
git add frontend/tests frontend/playwright.config.ts .github/workflows/frontend-quality.yml docs/frontend/TESTES.md
git commit -m "test(frontend): adiciona Playwright e gates de qualidade"
```

---

### Task 10: Auditoria final da fundação e abertura dos planos por versão

**Files:**
- Modify: `docs/frontend/PROTOTIPOS.md`
- Modify: `docs/frontend/DECISOES.md`
- Modify: `docs/tasks/active-task.json`
- Create later: planos separados para ContaOS 1.0, 2.0, 3.0, 4.0 e 5.0.

**Interfaces:**
- Consumes: todos os artefatos anteriores.
- Produces: fundação aprovada para expansão modular.

- [ ] **Step 1: Revisar diff contra Master Design e PRD**

Confirmar nenhuma mudança em `supabase/**` e nenhum backend paralelo.

- [ ] **Step 2: Rodar todos os gates**

Run: typecheck + lint + unit/component + build + Playwright + Zero-Drift.
Expected: PASS.

- [ ] **Step 3: Comparar implementação com protótipos MagicPath**

Revisar hierarquia, densidade, contraste, motion, responsividade e estados. Não aprovar divergência silenciosa.

- [ ] **Step 4: Marcar task foundation concluída**

Registrar evidências no manifesto.

- [ ] **Step 5: Criar plano específico do ContaOS 1.0**

Somente após a fundação verde; depois repetir por versão/módulo para evitar um PR monolítico.

---

## Self-review

- **Spec coverage:** direção visual, responsividade, acessibilidade, segurança de browser, auth, organização, dashboard, shells, portões, IA/evidência, Playwright e governança estão cobertos.
- **Escopo deliberadamente fora deste plano:** CRUD funcional completo V1–V5, regras financeiras, diligências, RAG e conformidade específica; cada domínio terá plano próprio depois da fundação.
- **Type consistency:** componentes críticos recebem estado pronto do backend; nenhuma interface deste plano calcula regra de domínio.
- **Review Focus:** os cinco riscos principais estão amarrados a testes nas Tasks 4, 6, 7, 8 e 9.
- **Proportion:** o plano define interfaces e testes, não implementação detalhada de cada tela.
