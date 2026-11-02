# Evidência — PROMPT 18 / SYS-03 — Build, auditoria e correção

Data: 02/11/2026
Ambiente: HML
Supabase: `gklhhhyosgasnyoxlrui`
Branch canônica: `design/frontend-master-plan`

## Autoridade
- Pacote 4.1 recém-anexado e validado por SHA-256.
- Manual Mestre: 100 prompts regulares, `PROMPT 00` a `PROMPT 99`.
- Caderno: 96 prompts atômicos, `001` a `096`.
- PROMPT regular aplicável: `PROMPT 18 — SYS-03 — Redefinir senha`.
- Rastreabilidade atômica: não há prompt atômico específico de domínio para SYS-03; trata-se de tela sistêmica de Auth. Não foi criada associação artificial.

## BUILD inicial Lovable
Commit Lovable: `340c742486056c490246228d8d097b98a36b6d82`.

Arquivos criados/gerados:
- `src/components/auth/ResetPasswordForm.tsx`
- `src/routes/redefinir-senha.tsx`
- `src/test/resetPassword.test.tsx`
- `src/routeTree.gen.ts`

Resultados iniciais reportados:
- 33 testes passando;
- typecheck sem erro;
- navegador em 1440, 1280, 768 e 390 sem overflow;
- fluxo real por e-mail e security scan ainda pendentes.

## Auditoria independente
Foram encontrados dois desvios antes de aceitar o BUILD:

1. O formulário era liberado por qualquer sessão existente, usando `getSession()` e eventos Auth comuns. Isso conflita com o acesso `público/token` do SYS-03 e com o fluxo oficial de recuperação baseado em `PASSWORD_RECOVERY`.
2. O frontend impunha regra local fixa de mínimo de 8 caracteres, sem conhecer a política efetivamente configurada no Auth HML. O pacote determina que a política material de senha pertence ao backend/Auth e não deve ser duplicada de forma divergente no React.

## Correção TDD
Commit Lovable corrigido: `aa29d1073586a176f1d00e0e389d4c5a96e5c87e`.

### RED
Antes de alterar código de produção, foram adicionados testes para provar os desvios. Resultado: 3 falhas esperadas:
- `SIGNED_IN` com sessão comum liberava o formulário;
- `getSession()` com sessão comum liberava o formulário;
- senha curta era bloqueada localmente antes de chegar ao Auth.

### GREEN
Correção restrita a:
- `src/test/resetPassword.test.tsx`
- `src/components/auth/ResetPasswordForm.tsx`

Mudanças:
- somente `PASSWORD_RECOVERY` libera o formulário;
- `getSession()` deixou de ser condição de acesso;
- nenhum outro evento Auth comum libera SYS-03;
- removida regra local fixa de 8 caracteres;
- validação local ficou limitada a senha não vazia + confirmação igual;
- política de força permanece no Auth HML via `updateUser({ password })` e `weak_password`;
- mensagens PT-BR, duplo clique, `signOut` após sucesso, tooltips e acessibilidade preservados.

### VERIFY da correção
- `resetPassword.test.tsx`: 15/15 PASS;
- suíte completa: 36/36 PASS em 5 arquivos;
- typecheck: PASS;
- build: PASS;
- navegador sem token: estado de link inválido, sem formulário;
- hash `otp_expired`: estado inválido imediato;
- console: sem erros;
- backend/Auth config/cliente Supabase/package.json: não alterados.

## Espelhamento GitHub
Estado final do SYS-03 foi versionado em `frontend/src/**` na branch canônica. Nenhum secret, token de recuperação ou senha foi versionado.

## Pendências para o TESTE oficial
- executar bloco C literal do PROMPT 18;
- security scan;
- revalidar 1440/1280/768/390 após correção;
- fluxo real com link de recuperação depende de link real/redirect allowlist e não será marcado PASS por inferência.
