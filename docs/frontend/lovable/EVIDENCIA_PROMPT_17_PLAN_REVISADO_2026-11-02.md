# Evidência — PROMPT 17 SYS-02 Esqueci a senha — PLAN revisado

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Lovable plan commit interno: `46401cead67fda4940f69684776599b87ed8a8da`
Status: **PLAN FINAL REVISADO — AGUARDANDO APROVAÇÃO HUMANA**

## Fonte funcional

SYS-02 — Esqueci a senha:
- rota oficial `/esqueci-senha`;
- acesso público;
- backend oficial `Supabase Auth.resetPasswordForEmail`;
- sem secret no browser;
- estados, responsividade e acessibilidade conforme Manual Frontend 4.1.

## Revisões de governança aplicadas antes da aprovação

O primeiro PLAN do Lovable foi rejeitado porque propunha:
1. extrair/refatorar o AuthShell do SYS-01, extrapolando o escopo;
2. hardcode de cooldown local de 60 segundos para rate limit;
3. documentação canônica criada apenas no sandbox Lovable.

O segundo PLAN foi rejeitado para um último ajuste de segurança porque normalizava genericamente erros inesperados como sucesso, o que poderia ocultar falha técnica real, e fazia referência a headers não expostos diretamente pelo SDK.

O PLAN final corrige esses pontos.

## Backend/Auth encontrado

- cliente existente `src/integrations/supabase/client.ts`, publishable key apenas;
- operação única planejada: `supabase.auth.resetPasswordForEmail(email, { redirectTo })`;
- nenhuma tabela, RPC ou endpoint próprio;
- nenhum backend ou configuração Auth será criado/alterado.

## Redirect de recuperação

Planejado: `${window.location.origin}/redefinir-senha`.

A configuração hospedada de Redirect URLs/Site URL do HML não é legível pelo sandbox Lovable. Portanto permanece registrada:

**LACUNA DE AUTH/REDIRECT:** confirmar se a origem do frontend e a rota `/redefinir-senha` estão permitidas na configuração de URLs do Auth HML. Esta tarefa não autoriza alterar essa configuração.

SYS-03 `/redefinir-senha` permanece dependência futura e não será implementado pelo PROMPT 17.

## Arquivos planejados

Novos:
- `src/routes/esqueci-senha.tsx`;
- `src/components/auth/ForgotPasswordForm.tsx`;
- `src/test/forgotPassword.test.tsx`.

Alterações mínimas:
- `src/components/auth/LoginForm.tsx`: somente link `Esqueci minha senha` para `/esqueci-senha`;
- `src/routeTree.gen.ts`: apenas regeneração automática de rota.

Explicitamente fora do escopo:
- `src/routes/login.tsx`;
- `AGENTS.md`;
- AppShell/root/index/start;
- `src/integrations/**`;
- `styles.css`;
- `package.json`;
- `supabase/**`;
- backend/RLS/Auth config/Storage/Edge Functions.

## UX e estados

- inicial: e-mail + `Enviar link`;
- validação: `Informe um e-mail válido.`;
- submitting: botão bloqueado e `Enviando…`;
- sucesso neutro: `Se existir uma conta vinculada a este e-mail, você receberá as instruções para redefinir sua senha.`;
- orientação adicional para caixa de spam;
- rate limit: copy segura, sem cooldown/contagem inventada, sem retry automático;
- erro técnico/configuração/captcha/serviço: mensagem genérica segura;
- `Voltar ao login` em todos os estados;
- tooltip acessível no contexto de segurança/anti-enumeração, sem substituir texto principal.

## Anti-enumeração

- resposta aceita pelo Supabase resulta sempre na mesma mensagem neutra, independentemente de conta existente ou inexistente;
- se o SDK expuser erro que materialmente revele existência de conta, somente esse caso é normalizado para sucesso neutro;
- erros técnicos inesperados não são mascarados como sucesso: exibem falha genérica segura, sem detalhes ou indicação sobre a existência da conta;
- nenhum e-mail, token ou dado sensível é persistido em storage;
- nenhum segredo é logado.

## Testes previstos

1. e-mail inválido não chama Supabase;
2. duplo envio gera uma chamada;
3. sucesso com copy neutra e `redirectTo` correto;
4. anti-enumeração e erro técnico genérico;
5. rate limit sem timer inventado e sem retry automático;
6. rota `/esqueci-senha`;
7. Login → Esqueci senha → Voltar ao login;
8. HML real com e-mail existente e e-mail válido inexistente, observando rate limit;
9. Network apenas com publishable key, sem secret/service_role;
10. visual 1440/1280/768/390;
11. teclado, foco, labels e tooltip;
12. console, security scan, typecheck e regressão SYS-01.

## Gate

Nenhum BUILD foi executado para o PROMPT 17.

Lovable está pausado em `plan--show`, aguardando decisão humana antes de qualquer alteração de código.
