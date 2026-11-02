# Evidência final — PROMPT 17 / SYS-02 — PASS

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Branch: `design/frontend-master-plan`

## Conclusão

`PROMPT 17: PASS`

O SYS-02 — Esqueci a senha foi reexecutado após a microcorreção do tooltip mobile e fechou 27/27 critérios em PASS ou REGISTRADO, sem alterações de backend, RLS, Auth config, schema, Edge Functions, Storage ou package.json.

## Causa raiz e microcorreção do item 15

Falha anterior: em contexto mobile 390 px com toque, o tooltip abria por foco e fechava no mesmo gesto de toque.

Evidência de eventos coletada antes da correção: `pointerdown → pointerup → focus → abre → click → fecha`.

Causa raiz: o trigger do Radix controlava `open` via `onOpenChange` e o `onClick` adicional alternava o mesmo estado, produzindo dupla transição e fechamento imediato.

Correção mínima aplicada somente em `frontend/src/components/auth/ForgotPasswordForm.tsx`:

- antes: `onClick={() => setDicaAberta((v) => !v)}`;
- depois: `preventDefault()` + `setDicaAberta(true)`.

Foi adicionado teste de regressão em `frontend/src/test/forgotPassword.test.tsx`.

## Gates finais

| # | Critério | Resultado |
|---|---|---|
| 1 | Typecheck | PASS |
| 2 | Vitest completo | PASS — 21/21 |
| 3 | Build de produção | PASS |
| 4 | Git status antes/depois do teste | PASS — idêntico |
| 5 | Arquivos fora do escopo | PASS — backend/Auth/package/AGENTS/login.tsx intocados |
| 6 | Secrets no frontend/bundle | PASS — nenhum `sb_secret`/`service_role` novo |
| 7 | E-mail inválido | PASS |
| 8 | Duplo envio | PASS — uma única chamada |
| 9 | `redirectTo` `/redefinir-senha` | PASS |
| 10 | Anti-enumeração | PASS |
| 11 | Erro técnico/rede seguro | PASS |
| 12 | `/esqueci-senha` abre | PASS — HTTP 200, H1 único |
| 13 | Navegação Login → Esqueci → Login | PASS |
| 14 | 1440/1280/768/390 | PASS — sem overflow e ações críticas visíveis |
| 15 | Teclado/labels/ARIA | PASS |
| 16 | Tooltip por hover | PASS |
| 17 | Tooltip por foco/teclado | PASS |
| 18 | Tooltip por toque mobile | PASS — visível após 100 ms e 1 s; tocar fora fecha; novo toque reabre |
| 19 | Console | PASS — sem erro de aplicação ou dado sensível |
| 20 | Pedidos reais HML | PASS — 2 no total |
| 21 | UI final idêntica | PASS |
| 22 | Network oficial | PASS — somente `/auth/v1/recover`, publishable key |
| 23 | Storage do navegador | PASS — sem sessão/token/e-mail sensível criado pelo SYS-02 |
| 24 | Security scan | PASS para escopo SYS-02; achados preexistentes registrados abaixo |
| 25 | SYS-03 | REGISTRADO — continua dependência futura |
| 26 | Allowlist Auth | REGISTRADO — sandbox não permite certificar; Auth config não alterado |
| 27 | Regressão do tooltip | PASS |

## Teste real anti-enumeração

Foram executados no máximo dois pedidos reais, ambos controlados pelo próprio usuário:

1. `edivanpablo99@gmail.com` → backend respondeu HTTP 429 / `over_email_send_rate_limit`;
2. alias controlado `edivanpablo99+contaos-inexistente@gmail.com` → backend respondeu HTTP 200.

Apesar das respostas diferentes do backend, a interface exibiu exatamente a mesma mensagem neutra nos dois casos:

> Se existir uma conta vinculada a este e-mail, você receberá as instruções para redefinir sua senha.

Nenhum e-mail foi reexibido na tela de sucesso. Não houve criação de sessão, access token ou refresh token pelo SYS-02.

## Security scan final

O scan executado após os testes não encontrou novo achado relacionado ao SYS-02. Entretanto, retornou 3 alertas graves e 4 informativos preexistentes no backend/HML.

### Alertas graves preexistentes

- política atual permite leitura ampla de `configuracao_api` por usuário autenticado;
- política atual permite leitura ampla de `configuracao_upload` por usuário autenticado;
- política atual permite leitura ampla de `perfis_usuarios` por usuário autenticado.

### Informativos preexistentes

- leitura pública de três catálogos;
- proteção contra senhas vazadas não habilitada.

Esses achados não foram criados, alterados ou corrigidos pelo PROMPT 17, pois backend/Supabase estavam fora do escopo desta tarefa. Devem permanecer registrados para tratamento em tarefa específica de segurança backend.

## Arquivos funcionais do SYS-02

- `frontend/src/routes/esqueci-senha.tsx`
- `frontend/src/components/auth/ForgotPasswordForm.tsx`
- `frontend/src/test/forgotPassword.test.tsx`
- `frontend/src/components/auth/LoginForm.tsx` — somente link `Esqueci minha senha`
- `frontend/src/routeTree.gen.ts`

## Estado final

- SYS-01 Login: PASS.
- SYS-02 Esqueci a senha: PASS.
- Próxima dependência funcional do fluxo de autenticação: SYS-03 `/redefinir-senha`.
- Nenhuma promoção para produção realizada.
