# ContaOS 4.1 — PROMPT 17 / SYS-02 — FECHAMENTO FINAL

Data: 02/11/2026
Branch: `design/frontend-master-plan`
Status final: **PASS**

## Histórico
Durante o primeiro ciclo de teste do SYS-02 foi identificado um FAIL de anti-enumeração: o backend Supabase Auth retornava 429 para o e-mail existente submetido a rate limit e resposta aceita para um e-mail inexistente, e a UI inicialmente apresentava mensagens diferentes.

Esse FAIL foi corretamente registrado e deve permanecer no histórico GitHub como evidência do processo de teste.

## Correção
Foi aplicada correção mínima exclusivamente no frontend para que:
- resposta aceita;
- `user_not_found`/erro equivalente de enumeração;
- HTTP 429;
- `over_email_send_rate_limit`;
- `over_request_rate_limit`

apresentem a mesma mensagem neutra ao usuário quando o objetivo for impedir inferência de existência de conta.

Erros técnicos reais permanecem com mensagem genérica segura.

Nenhuma configuração de Auth, backend, RLS, schema, Edge Function, Storage, SMTP, rate limit ou package foi alterada.

## Testes finais
- Vitest total: **20/20 PASS**.
- Regressão SYS-01: **PASS**.
- Typecheck/build: **PASS**.
- HML real, e-mail existente x inexistente: **PASS com UI idêntica**.
- Responsividade 1440/1280/768/390: **PASS**.
- Navegação Login → Esqueci minha senha → Voltar ao login: **PASS**.
- Teclado/foco/labels/tooltip: **PASS**.
- Network `/auth/v1/recover`: **PASS**, somente chave publicável, sem `service_role`/secret.
- Console: **PASS para aplicação**.
- Security scan: **PASS para o escopo SYS-02**.

## Arquivos finais do SYS-02 versionados
- `frontend/src/components/auth/ForgotPasswordForm.tsx`
- `frontend/src/components/auth/LoginForm.tsx`
- `frontend/src/routes/esqueci-senha.tsx`
- `frontend/src/test/forgotPassword.test.tsx`
- `frontend/src/routeTree.gen.ts`

## Evidências relacionadas
- `EVIDENCIA_PROMPT_17_PLAN_REVISADO_2026-11-02.md`
- `EVIDENCIA_PROMPT_17_BUILD_2026-11-02.md`
- `EVIDENCIA_PROMPT_17_TESTE_OFICIAL_2026-11-02.md`
- `EVIDENCIA_PROMPT_17_BUILD_TEST_PASS_2026-11-02.md`
- `EVIDENCIA_DIVERGENCIA_VERSIONAMENTO_LOVABLE_GITHUB_2026-11-02.md`

## Interpretação do FAIL anterior
O registro de FAIL anterior é histórico e **está superado** por esta correção e pela bateria final de testes. O estado oficial atual do PROMPT 17 é **PASS**.

## Pendências não bloqueantes do SYS-02
1. Confirmar a allowlist do Auth para `/redefinir-senha` no HML.
2. Implementar SYS-03 em prompt próprio.
3. Resolver a pendência de governança de espelhamento integral do scaffold-base Lovable no GitHub. Essa pendência não invalida o PASS funcional do SYS-02, mas impede declarar o frontend completo 100% reproduzível somente a partir do GitHub enquanto não for resolvida.
