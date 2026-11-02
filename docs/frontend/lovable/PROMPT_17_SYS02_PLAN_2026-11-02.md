# PROMPT 17 — SYS-02 Esqueci a senha — PLAN

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Modo: PLAN. NÃO ALTERAR CÓDIGO NEM BACKEND.

## Fontes obrigatórias
- Pacote Mestre ContaOS 4.1, PRD, Premissas, Arquitetura e Zero-Drift.
- Manual Integral Frontend Lovable/Supabase 4.1: SYS-02 `/esqueci-senha`, acesso público, backend `Supabase Auth.resetPasswordForEmail`.
- Protocolo 4.1 `12_PROMPTS_PROTOCOLO_IMPLEMENTACAO_4_1.md`.
- Design System e premissas Lovable versionados em `docs/frontend/**`.
- Estado real do Supabase HML conectado. Não criar backend alternativo.

## Tarefa
Planejar exclusivamente o SYS-02 — Esqueci a senha.

### Escopo funcional obrigatório
1. Criar rota oficial `/esqueci-senha`.
2. Formulário com campo de e-mail e ação `Enviar link`.
3. Usar exclusivamente `supabase.auth.resetPasswordForEmail(email, ...)` do cliente Supabase já existente.
4. O fluxo de recuperação deverá apontar para a rota oficial futura `/redefinir-senha` (SYS-03) usando `redirectTo`, mas somente se a configuração atual do Auth HML aceitar a URL; se houver lacuna de configuração, declarar `LACUNA DE AUTH/REDIRECT` e NÃO alterar Auth config neste prompt.
5. Copy neutra e anti-enumeração: a UI não pode revelar se o e-mail possui ou não conta. Em resposta aceita, exibir instrução genérica como `Se existir uma conta vinculada a este e-mail, você receberá as instruções para redefinir sua senha.`
6. Tratar validação local de formato do e-mail, loading/submitting, sucesso, erro seguro de rede/serviço e rate limit quando retornado pelo backend. Não fazer retry em loop.
7. Disponibilizar ação `Voltar ao login`.
8. Alterar SYS-01 somente o mínimo necessário para adicionar o link `Esqueci minha senha` para `/esqueci-senha`. Não redesenhar nem refatorar o Login.
9. Manter a linguagem visual do Auth Shell já aprovado no SYS-01, Design System oficial e PT-BR.
10. Aplicar tooltips acessíveis onde houver utilidade explicativa, por hover/foco e alternativa por toque, sem substituir label ou informação crítica.

## Segurança e Zero-Drift
- Nenhuma migration, tabela, RLS, RPC, Edge Function, Storage ou configuração Auth pode ser criada/alterada.
- Nenhuma secret/service_role no browser, código, logs ou testes.
- Não criar endpoint próprio de recuperação de senha.
- Não persistir token de recuperação, senha ou dados sensíveis.
- Não inferir existência de usuário pela resposta visual.
- Não alterar `package.json` por conveniência.
- Se algo necessário não existir no backend/configuração atual, PARAR e registrar lacuna.

## Arquivos potencialmente autorizados no PLAN
O Lovable deve confirmar a menor lista real possível. Esperado:
- `src/routes/esqueci-senha.tsx` ou equivalente do scaffold atual;
- `src/components/auth/ForgotPasswordForm.tsx` se necessário;
- testes específicos de SYS-02;
- `src/components/auth/LoginForm.tsx` somente para o link de navegação, se esse for o local mínimo correto;
- arquivos gerados de rotas somente se o framework os atualizar automaticamente.

Não alterar `AGENTS.md`, AppShell, features de negócio, Supabase backend ou arquivos fora do escopo.

## Responsividade e acessibilidade
- Validar 1440, 1280, 768 e 390 px sem overflow e sem ocultar ação principal.
- Heading único, label explícito, foco previsível, teclado, `aria-live` para submitting/sucesso quando apropriado.
- Status não depender apenas de cor.
- Mensagem de sucesso deve ser compreensível sem expor existência da conta.

## Testes que o PLAN deve prever
1. unit/component: e-mail inválido não chama Supabase;
2. unit/component: submitting desabilita ação e evita duplo envio;
3. unit/component: sucesso usa copy neutra;
4. unit/component: erro de rede/rate limit com mensagem segura;
5. Playwright: rota `/esqueci-senha` abre;
6. Playwright: navegação Login → Esqueci senha e Voltar ao login;
7. Playwright: pedido real no HML para e-mail existente e e-mail sintaticamente válido inexistente, verificando que a UI não diferencia existência de conta, respeitando rate limit;
8. Network/scan: nenhuma secret key e nenhum dado sensível;
9. visual: 1440/1280/768/390;
10. teclado/foco/labels/tooltips;
11. console sem erro ou log sensível;
12. security scan sem novo Critical.

## Saída esperada do PLAN
Responda sem editar código com:
- backend/Auth existente encontrado e assinatura usada;
- comportamento esperado do `redirectTo` e eventual dependência de URL allowlist;
- arquivos exatos a alterar;
- estados/copy propostos;
- impacto de segurança/anti-enumeração;
- testes exatos;
- lacunas, se existirem;
- confirmação expressa de que nenhum backend/Auth config será alterado.
