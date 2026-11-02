# PROMPT 17 — SYS-02 Esqueci a senha — BUILD

Data: 02/11/2026
Ambiente: Supabase HML `gklhhhyosgasnyoxlrui`
Branch: `design/frontend-master-plan`

## Aprovação
BUILD autorizado pelo usuário após aprovação do PLAN final revisado do PROMPT 17.

## Escopo autorizado

Implementar exclusivamente SYS-02 — Esqueci a senha.

1. Criar a rota `/esqueci-senha`.
2. Criar formulário de recuperação com campo E-mail e ação `Enviar link`.
3. Usar exclusivamente o cliente Supabase existente com `supabase.auth.resetPasswordForEmail`.
4. Definir `redirectTo` para `${window.location.origin}/redefinir-senha`, sem alterar configuração do Auth HML.
5. Manter resposta visual neutra para impedir enumeração de usuários.
6. Tratar validação local, envio, sucesso neutro, falha técnica e rate limit sem retry automático.
7. Manter `Voltar ao login`.
8. Alterar SYS-01 apenas para incluir o link `Esqueci minha senha`.
9. Não redesenhar nem refatorar SYS-01.
10. Reproduzir a linguagem visual aprovada usando somente tokens/componentes existentes.
11. Aplicar acessibilidade e tooltip útil sem substituir informação crítica.

## Restrições invioláveis

- Nenhuma alteração em backend, banco, migration, RLS, RPC, Edge Function, Storage ou Auth config.
- Nenhuma secret/service_role no frontend, logs ou testes.
- Nenhum endpoint próprio.
- Nenhuma persistência de token de recuperação, senha ou dado sensível.
- `src/routes/login.tsx` não pode ser alterado.
- `package.json`, `AGENTS.md`, AppShell e features de negócio não podem ser alterados.
- Se houver necessidade de arquivo fora do escopo, parar e reportar.

## Arquivos autorizados

- `src/routes/esqueci-senha.tsx`
- `src/components/auth/ForgotPasswordForm.tsx`
- `src/test/forgotPassword.test.tsx`
- `src/components/auth/LoginForm.tsx` somente para o link
- `src/routeTree.gen.ts` somente por regeneração automática do TanStack Router

## Copy aprovada

- H1: `Recuperar acesso`
- Validação: `Informe um e-mail válido.`
- Botão: `Enviar link`
- Durante envio: `Enviando…`
- Sucesso neutro: `Se existir uma conta vinculada a este e-mail, você receberá as instruções para redefinir sua senha.`
- Apoio: `Verifique também a caixa de spam.`
- Falha técnica: `Não foi possível enviar a solicitação agora. Tente novamente em instantes.`
- Tooltip: `Por segurança, não informamos se o e-mail possui cadastro.`

## Anti-enumeração

O resultado visual deve ser idêntico para e-mail existente e inexistente quando a solicitação for aceita. Erros que revelem existência de usuário devem ser normalizados. Como o HML pode responder 429 de forma diferente para contas existentes, `429`, `over_email_send_rate_limit` e `over_request_rate_limit` devem ser normalizados para a mesma tela neutra de sucesso, evitando enumeração pela UI.

## Testes obrigatórios do BUILD

- E-mail inválido não chama Supabase.
- Duplo envio gera uma única chamada.
- Sucesso usa copy neutra e `redirectTo` termina em `/redefinir-senha`.
- Erro de enumeração é normalizado.
- Erro inesperado usa mensagem genérica.
- Rate limit não produz retry automático nem resposta visual que revele conta.
- Typecheck sem erros.
- Testes anteriores do SYS-01 permanecem verdes.

## Etapa posterior

Os testes funcionais reais em HML, incluindo browser/Playwright, Network, breakpoints, teclado/foco e comparação visual entre e-mail existente e inexistente, serão executados como etapa de TESTE separada após inspeção e versionamento do BUILD.
