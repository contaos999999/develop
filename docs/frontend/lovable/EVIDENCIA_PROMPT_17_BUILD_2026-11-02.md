# Evidência — PROMPT 17 / SYS-02 — BUILD

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Branch: `design/frontend-master-plan`

## Resultado do BUILD

BUILD executado no Lovable após aprovação expressa do PLAN final revisado.

### Arquivos criados
- `frontend/src/routes/esqueci-senha.tsx`
- `frontend/src/components/auth/ForgotPasswordForm.tsx`
- `frontend/src/test/forgotPassword.test.tsx`
- `frontend/src/routeTree.gen.ts` — arquivo gerado pelo TanStack Router e versionado por exigência de rastreabilidade.

### Arquivo alterado
- `frontend/src/components/auth/LoginForm.tsx` — única mudança funcional: link `Esqueci minha senha` para `/esqueci-senha` junto ao campo Senha.

### Arquivos expressamente não alterados
- `frontend/src/routes/login.tsx`
- backend Supabase
- migrations
- RLS
- RPCs
- Edge Functions
- Storage
- Auth config/allowlist
- `package.json`
- `AGENTS.md`
- AppShell e features de negócio

## Implementação funcional

- Rota oficial `/esqueci-senha`.
- Campo E-mail com validação local.
- Uso exclusivo de `supabase.auth.resetPasswordForEmail` pelo cliente existente.
- `redirectTo` aponta para `${window.location.origin}/redefinir-senha`.
- Nenhuma configuração do Auth foi modificada.
- H1 `Recuperar acesso`.
- Estados de envio, sucesso neutro e erro técnico seguro.
- `Voltar ao login` em todos os estados.
- Tooltip acessível: `Por segurança, não informamos se o e-mail possui cadastro.`
- Tooltip controlado também por clique/toque além de hover/foco.

## Anti-enumeração

A inspeção do comportamento do HML identificou que rate limit por e-mail pode ocorrer de forma distinta para contas existentes. Para não permitir enumeração pela interface, a implementação atual classifica como `sucesso` neutro:

- resposta sem erro;
- `user_not_found`;
- `email_not_found`;
- HTTP 429;
- `over_email_send_rate_limit`;
- `over_request_rate_limit`.

Todos esses casos exibem exatamente a mesma mensagem:

> Se existir uma conta vinculada a este e-mail, você receberá as instruções para redefinir sua senha.

Erros técnicos, de configuração, captcha ou serviço continuam produzindo mensagem genérica de falha, sem informação que permita inferir a existência da conta.

## Testes executados pelo BUILD

- Typecheck: PASS, sem erros.
- Vitest: 19/19 PASS.
- Novos testes SYS-02: 7 cenários PASS.
- Testes anteriores do SYS-01: permanecem PASS.
- E-mail inválido não chama Supabase: PASS.
- Duplo envio produz apenas uma chamada: PASS.
- Sucesso usa copy neutra: PASS.
- `redirectTo` termina em `/redefinir-senha`: PASS.
- Erro de enumeração normalizado: PASS.
- Erro inesperado usa falha genérica: PASS.
- 429/rate limit usa a mesma resposta neutra e não gera retry automático: PASS.
- Erro de rede usa falha genérica: PASS.
- Busca por `sb_secret`/`service_role` nos arquivos novos: nenhuma ocorrência.

## Lacunas registradas

1. `SYS-03 /redefinir-senha` ainda não existe e será implementado no prompt correspondente.
2. A allowlist/Redirect URLs do Auth HML não é verificável pelo sandbox do Lovable; precisa ser validada em etapa própria, sem alteração automática da configuração.
3. O link `Esqueci minha senha` no Login foi implementado como `<a href>` para preservar os testes isolados existentes de SYS-01. Funcionalmente navega para a rota correta; eventual conversão para `Link` do TanStack exigirá alteração dos testes do Login e deve ter escopo próprio.

## Gate

BUILD tecnicamente aceito para prosseguir ao TESTE oficial. O PROMPT 17 ainda não deve ser marcado como PASS final até a execução de browser/Playwright/HML, Network, responsividade, acessibilidade e security scan.
