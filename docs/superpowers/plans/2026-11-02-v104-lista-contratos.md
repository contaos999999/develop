# V1-04 — Contratos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar `/contratos` como lista paginada somente leitura, usando Data API + RLS e respeitando integralmente o contexto multi-organização do SYS-04 do pacote 4.1.

**Architecture:** Reutilizar `obterPreferenciaOrganizacao()` e o fluxo SYS-04 já existente; não criar novo mecanismo de contexto. A query de contratos usa `id_organizacao` selecionado apenas como contexto e permanece sujeita à RLS `usuario_tem_acesso_contrato(id)`. Toda troca de organização limpa dados/cache antigos, volta à página 1 e executa uma nova query sem `placeholderData`.

**Tech Stack:** React, TanStack Router, TanStack Query, Supabase JS, Vitest/Testing Library, Tailwind/shadcn existentes.

**Spec:** `docs/superpowers/specs/2026-11-02-v104-lista-contratos-design.md`

## Global Constraints

- Fonte normativa exclusiva: pacote ContaOS 4.1.
- Rota: `/contratos`.
- Acesso: `autorizado`.
- Backend: Data API com RLS; nenhuma RPC/Edge nova para V1-04.
- Usar `src/lib/organizacao/preferenciaOrganizacao.ts`; não alterar SYS-04.
- `OrganizationSelector` já faz `queryClient.clear()` quando a preferência muda; preservar esse comportamento.
- RLS é autoridade; organização selecionada é preferência/contexto.
- Usuário com múltiplos vínculos pode alternar A ↔ B e a lista deve refletir somente a organização ativa.
- Paginação obrigatória: 25 por página, server-side.
- Zero secret, zero DML, zero backend paralelo, zero request por linha.
- Estados: loading, empty, success, denied, error.
- Responsivo: 1440/1280/768/390.
- Teste C em turno separado, sem auto-fix.
- Menor consumo possível de créditos Lovable sem reduzir qualidade, segurança ou evidência.

## Review Focus

1. **Troca A → B:** nenhum contrato de A pode permanecer visível enquanto B carrega.
2. **Resposta tardia:** request atrasada de A não pode sobrescrever B depois que B virou organização ativa.
3. **Volta B → A:** comportamento simétrico e página volta para 1.
4. **RLS restrita:** dentro da organização ativa, mostrar somente linhas que a Data API/RLS retornou; não inferir acesso pelo perfil.
5. **Zero linhas:** organização autorizada sem contratos = `empty`; organização não autorizada = `denied`.

---

### Task 1: Camada de leitura V1-04

**Files:**
- Create: `src/lib/contratos/contratosDados.ts`
- Test: `src/test/contratos.test.tsx`

**Interfaces:**
- `TAMANHO_PAGINA_CONTRATOS = 25`
- `ContratoLista`
- `PaginaContratos`
- `ErroContratos`
- `verificarAcessoOrganizacaoContratos(idOrganizacao: string): Promise<true>`
- `listarContratos({ idOrganizacao, pagina }): Promise<PaginaContratos>`
- formatadores PT-BR de vigência, moeda, situação e criticidade.

- [ ] **Step 1: Escrever RED da camada de dados**

Testar:
- gate de organização usa backend oficial e distingue `negado`/`erro`;
- lista seleciona somente `id,id_organizacao,numero,objeto,situacao,criticidade,inicio,fim,valor_global`;
- `.eq('id_organizacao', idOrganizacao)` é sempre aplicado;
- página 1 usa `range(0,24)`, página 2 `range(25,49)`;
- ordenação `numero ASC`, depois `id ASC`;
- 401/403/42501/PGRST301 => `negado`;
- PGRST103/416 => `faixa`;
- rede/500/schema inválido => `erro`;
- zero `.insert`, `.update`, `.delete`, `.upsert`, `.rpc`, `functions.invoke`.

- [ ] **Step 2: Rodar teste focado e comprovar RED**

Run: `npm test -- --run src/test/contratos.test.tsx`
Expected: FAIL por módulo/exports ainda ausentes.

- [ ] **Step 3: Implementar camada mínima**

Sem filtros de UI inventados, sem joins, sem detalhe por linha.

- [ ] **Step 4: Rodar focused GREEN**

Run: `npm test -- --run src/test/contratos.test.tsx`
Expected: PASS.

### Task 2: Tela `/contratos` e contexto SYS-04

**Files:**
- Create: `src/components/contratos/ListaContratos.tsx`
- Create: `src/routes/contratos.tsx`
- Modify generated only: `src/routeTree.gen.ts`
- Test: `src/test/contratos.test.tsx`

**Interfaces:**
- Consumes `obterPreferenciaOrganizacao(idUsuario)` de `src/lib/organizacao/preferenciaOrganizacao.ts`.
- Consumes Task 1.

- [ ] **Step 1: Escrever RED de sessão/contexto**

Testar:
- sessão ausente -> `/login`;
- erro técnico de `getUser` -> retry sem logout automático;
- preferência ausente -> `/selecionar-organizacao`;
- organização selecionada inválida/negada -> estado `denied` e zero query de contratos;
- query key inclui `idUsuario`, `idOrganizacao` e `pagina`;
- não usar `placeholderData`/`keepPreviousData`.

- [ ] **Step 2: Escrever RED multi-organização A → B → A**

Cenário controlado:
1. usuário possui vínculos A e B;
2. preferência A -> renderiza somente contratos retornados para A;
3. mudar preferência para B pelo fluxo SYS-04 e remount/navegação correspondente -> contratos de A desaparecem, loading aparece, página volta para 1 e somente B é renderizada;
4. resposta tardia de A não altera a tela já em B;
5. voltar para A repete o processo simetricamente.

- [ ] **Step 3: Rodar teste e comprovar RED**

Run: `npm test -- --run src/test/contratos.test.tsx`
Expected: FAIL porque rota/componente ainda não existem.

- [ ] **Step 4: Implementar tela mínima**

- um H1 `Contratos`;
- botão/link para `Selecionar organização`, reutilizando a rota existente;
- tabela em desktop/tablet e cards em mobile, sem ocultar número, objeto, situação, criticidade, vigência e valor;
- loading explícito em troca de organização/página;
- `empty`, `denied`, `error` visual e semanticamente distintos;
- paginação anterior/próxima >=44px;
- nenhuma funcionalidade V1-05/V1-06.

- [ ] **Step 5: Rodar focused GREEN**

Run: `npm test -- --run src/test/contratos.test.tsx`
Expected: PASS incluindo A → B → A e stale response.

### Task 3: Verificação BUILD

- [ ] Regressão completa do projeto: PASS.
- [ ] Typecheck fresco permitido: exit 0.
- [ ] Build fresco permitido: exit 0.
- [ ] Auditar fonte: zero secret/DML/RPC/Edge/local critical status.
- [ ] Auditar diff: somente arquivos V1-04 + `routeTree.gen.ts` gerado.
- [ ] Confirmar V1-01/V1-02/V1-03/SYS/ADM/shared UI/client/package/backend intocados.

### Task 4: Teste Oficial C separado

TEST ONLY, sem edição e sem auto-fix.

- [ ] Executar os 12 itens canônicos do PROMPT 25 exatamente conforme pacote 4.1.
- [ ] Validar 1440/1280/768/390.
- [ ] Validar teclado/foco/labels/status.
- [ ] Validar console/network sem segredo.
- [ ] Security Scan sem novo Critical.
- [ ] Reexecutar regressão/typecheck/build frescos.
- [ ] Acrescentar evidência transversal SYS-04: A → B → A, limpeza de cache/dados, página 1 e proteção contra resposta tardia.
- [ ] Confirmar HEAD inalterado e git clean ao final.

## Self-review

- **Spec coverage:** PROMPT 25 + SYS-04 + RNF paginação cobertos; nenhuma exigência de manual anterior foi herdada.
- **Type consistency:** camada de dados e componente compartilham `ContratoLista/PaginaContratos/ErroContratos`.
- **Security:** autorização continua RLS; sessionStorage guarda somente preferência não autoritativa já existente.
- **Credit efficiency:** backend e contexto foram auditados fora do Lovable; o Lovable deve receber contrato pronto e não redescobrir Supabase/SYS-04.
