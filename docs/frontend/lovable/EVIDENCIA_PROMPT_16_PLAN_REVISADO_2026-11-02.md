# Evidência — PROMPT 16 SYS-01 Login — PLAN revisado

Data: 02/11/2026, Horário de Brasília
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Supabase HML: `gklhhhyosgasnyoxlrui`
Status: aguardando aprovação humana para BUILD

## Escopo aprovado no PLAN

Tela: SYS-01 — Login
Rota: `/login`
Acesso: público
Backend autorizado: Supabase Auth `signInWithPassword`

## Correções realizadas sobre o primeiro PLAN

1. Removida criação de páginas placeholder de SYS-04/SYS-05.
2. Corrigidas rotas oficiais: `/selecionar-organizacao` e `/`.
3. Ausência de SYS-04/SYS-05 registrada como `DEPENDÊNCIA DE FRONTEND`, não LACUNA DE BACKEND.
4. `src/routes/index.tsx` não será alterado no SYS-01.
5. Espelhamento `frontend/**` será feito externamente no GitHub, não dentro do sandbox Lovable.
6. Ausência do protótipo MagicPath no sandbox não bloqueia o Build; Design System e Project Instructions são autoridade visual, com validação externa posterior.
7. Cliente Supabase, package.json, layout global, schema, migrations, RLS, Auth config, Edge Functions e Storage ficam fora do escopo.
8. Tooltip não substitui nome acessível do botão de mostrar/ocultar senha.
9. Testes distinguem PASS do SYS-01 de dependências futuras de SYS-04/SYS-05.
10. Autenticação permanece exclusivamente via `signInWithPassword`; vínculos são lidos sob RLS.

## Arquivos planejados no Lovable

Novos:
- `src/routes/login.tsx`
- `src/components/auth/LoginForm.tsx`
- `src/lib/auth/resolverDestinoPosLogin.ts`
- `src/test/resolverDestinoPosLogin.test.ts`
- `src/test/login.test.tsx`
- `docs/frontend/lovable/SYS-01-login.md`

Não alterar:
- `src/routes/index.tsx`
- `src/routes/__root.tsx`
- `src/start.ts`
- `src/integrations/supabase/**`
- `package.json`
- `src/styles.css`
- schema/migrations/RLS/Auth config/Edge Functions/Storage

`src/routeTree.gen.ts` pode ser regenerado automaticamente pelo framework, sem edição manual.

## Operações Supabase planejadas

- `supabase.auth.signInWithPassword({ email, password })`
- leitura da sessão existente para tratamento de usuário já autenticado
- leitura de `vinculos_usuarios` via Data API sob RLS para resolver destino pós-login

Nenhuma tabela, RPC ou Edge Function nova.

## Estados

- inicial
- validação local
- processing
- credencial inválida com mensagem neutra
- erro de rede/servidor
- carregando vínculos
- empty/denied sem vínculo ativo
- erro de leitura de vínculos
- success
- sessão já existente

## Destinos oficiais

- múltiplos vínculos → `/selecionar-organizacao` (SYS-04, dependência futura)
- um vínculo → `/` (SYS-05 Dashboard, dependência futura)

Nenhuma dessas telas será criada no PROMPT 16.

## Responsividade e acessibilidade

- 1440/1280: painel institucional + cartão Login
- 768: painel reduzido/faixa + cartão centralizado
- 390: cartão único, sem scroll horizontal, alvos >= 44 px
- labels explícitos, foco visível, teclado, Enter, `aria-describedby`, `aria-live`, `aria-busy`, status com texto/ícone
- PT-BR integral

## Testes planejados

PASS possível no SYS-01:
- unitário do resolver 0/1/vários vínculos
- componente: labels, validação, loading, disabled durante envio, erro genérico, erro de rede, sem vínculos
- rota `/login`
- Playwright de render/teclado/credencial errada em 1440/1280/768/390
- acessibilidade/axe
- scan de secrets
- Zero-Drift

Dependências futuras, sem forçar FAIL artificial:
- render completo da rota `/selecionar-organizacao` depende do SYS-04
- render completo do Dashboard `/` depende do SYS-05

## Decisão

PLAN tecnicamente alinhado ao PROMPT 16, FE 4.1, Design System e Zero-Drift. Nenhum Build foi executado nesta etapa.
