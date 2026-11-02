# ContaOS 4.1 — Evidência de divergência de versionamento Lovable ↔ GitHub

Data: 02/11/2026
Branch alvo: `design/frontend-master-plan`
Projeto Lovable: `b113dd59-6caf-4c92-8302-457a037a0c6f`

## Diagnóstico
O sandbox do Lovable mantém seu próprio repositório Git interno. Os remotes identificados são internos ao Lovable e não apontam para `contaos9999/develop`.

O commit interno Lovable `3396296a1512235b21c3e5cfae26b96f46ebc9bc` não existe como commit no repositório GitHub `contaos9999/develop`.

O projeto Lovable reportou 98 arquivos rastreados no seu Git interno. Entre os arquivos-base rastreados estão `src/routeTree.gen.ts`, `src/components/ui/button.tsx`, `src/router.tsx`, `package.json`, `bun.lock`, `vite.config.ts`, `tsconfig.json`, `src/styles.css`, `src/routes/__root.tsx`, `src/start.ts` e outros arquivos do scaffold.

## Situação observada no GitHub
Os arquivos alterados/gerados pelo PROMPT 17 passaram a aparecer de forma parcial/diferida no diretório `frontend/` da branch canônica, inclusive:
- `frontend/src/components/auth/ForgotPasswordForm.tsx`;
- `frontend/src/components/auth/LoginForm.tsx`;
- `frontend/src/routes/esqueci-senha.tsx`;
- `frontend/src/test/forgotPassword.test.tsx`;
- `frontend/src/routeTree.gen.ts`.

Entretanto, arquivos-base do scaffold que já existiam no Lovable antes do PROMPT 17 ainda não estavam integralmente presentes no GitHub na verificação realizada, por exemplo `frontend/src/components/ui/button.tsx`.

## Consequência de governança
O PROMPT 17 está funcionalmente PASS e seus arquivos específicos estão versionados, mas o frontend completo do Lovable ainda não pode ser considerado 100% reproduzível a partir do GitHub enquanto o scaffold-base integral não estiver espelhado.

Isso é uma lacuna de versionamento/reprodutibilidade, não um FAIL funcional do SYS-02.

## Regra para fechamento da lacuna
Antes de considerar a fundação do frontend plenamente reproduzível, deve existir um espelho integral e verificável do codebase Lovable sob `frontend/` no GitHub, excluindo somente itens deliberadamente não versionáveis/secretos e mantendo `supabase/**` do backend certificado fora de qualquer sobrescrita.

A sincronização deve preservar:
- código-fonte;
- componentes-base;
- configurações de build/teste;
- lockfile;
- testes;
- rotas;
- documentação pertinente;
- `.env.example` ou equivalente sem segredos.

Não deve introduzir `service_role`, secret key, credenciais privadas, `node_modules`, `dist`, `.workspace` ou artefatos temporários.

## Estado
**PENDÊNCIA DE GOVERNANÇA ABERTA** — sincronização integral do scaffold Lovable para GitHub.
