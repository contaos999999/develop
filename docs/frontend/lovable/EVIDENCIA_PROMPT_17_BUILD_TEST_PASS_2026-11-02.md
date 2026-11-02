# ContaOS 4.1 — PROMPT 17 / SYS-02 — BUILD + TESTE OFICIAL

Data: 02/11/2026
Ambiente: HML
Branch canônica: `design/frontend-master-plan`
Projeto Lovable: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Commit interno Lovable reportado: `3396296a1512235b21c3e5cfae26b96f46ebc9bc`

## Escopo
Implementação de SYS-02 — Esqueci a senha, rota `/esqueci-senha`, consumindo exclusivamente `supabase.auth.resetPasswordForEmail`, sem alteração de backend, Auth config, RLS, schema, Edge Functions, Storage ou package.json.

## Achado durante o primeiro teste HML
O primeiro teste real identificou diferença observável entre e-mail existente e inexistente quando a conta existente estava submetida a rate limit do Supabase Auth. O e-mail existente recebeu 429 e a UI mostrava mensagem específica de excesso de tentativas, enquanto o e-mail inexistente recebia resposta aceita e a UI mostrava sucesso neutro.

Isso permitia inferência de existência de conta por diferença de comportamento visual. O BUILD foi interrompido e classificado inicialmente como FAIL até correção.

## Correção aplicada
Correção mínima exclusivamente no frontend:
- `AuthError.status === 429`;
- `over_email_send_rate_limit`;
- `over_request_rate_limit`;

passam a produzir exatamente a mesma mensagem neutra de sucesso apresentada quando o pedido é aceito pelo Supabase.

Não há cooldown inventado, contador local, Retry-After simulado ou reenvio automático.

Erros técnicos/configuração/captcha/rede/500 continuam produzindo mensagem genérica de falha, sem detalhe técnico e sem revelar existência de conta.

## Resultado final
**PROMPT 17: PASS**

1. Testes automáticos completos incluindo regressão SYS-01: **PASS — 20/20**.
2. Typecheck/montagem do app: **PASS**.
3. HML real, e-mail existente x inexistente: **PASS**. O backend devolveu 429 para o e-mail existente e 200 para o inexistente, mas a UI apresentou texto idêntico.
4. Responsividade 1440/1280/768/390: **PASS**. Sem rolagem lateral e com conteúdo crítico visível.
5. Navegação Login → Esqueci minha senha → Voltar ao login: **PASS**.
6. Teclado, foco, labels e tooltip: **PASS**. Abertura por toque físico não foi validada em aparelho real nesta rodada.
7. Network `/auth/v1/recover`: **PASS**. Apenas chave publicável; nenhuma `service_role`/secret observada.
8. Console: **PASS para aplicação**. Houve apenas aviso do navegador associado ao 429 retornado pelo Supabase.
9. Security scan Lovable: **PASS para o SYS-02**. Nenhum achado novo vinculado às telas desta tarefa.

## Arquivos do SYS-02
- `frontend/src/components/auth/ForgotPasswordForm.tsx`
- `frontend/src/components/auth/LoginForm.tsx`
- `frontend/src/routes/esqueci-senha.tsx`
- `frontend/src/test/forgotPassword.test.tsx`
- `frontend/src/routeTree.gen.ts`

## Lacunas remanescentes
1. Confirmar em Supabase HML → Authentication → URL Configuration se `/redefinir-senha` e a origem HML estão autorizadas como Redirect URLs.
2. SYS-03 `/redefinir-senha` ainda não implementado neste prompt.
3. O link `Esqueci minha senha` no SYS-01 usa `<a href>` e provoca recarregamento completo. Mantido para preservar testes atuais do SYS-01. Pode ser revisitado em tarefa específica sem alterar comportamento funcional.
4. O scanner do Lovable reportou alertas preexistentes fora do escopo SYS-02 envolvendo leitura por usuários autenticados em `configuracao_api`, `configuracao_upload` e `perfis_usuarios`, além de itens informativos. Nenhuma correção foi aplicada nesta tarefa porque o backend está fora do escopo ativo.

## Zero-Drift
Nenhuma migration, tabela, RLS, RPC, Edge Function, Storage, Auth config, rate limit, SMTP ou pacote foi alterado.
