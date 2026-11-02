# PROMPT 16 — SYS-01 Login — Correção de fidelidade visual e Zero-Drift

Data: 02/11/2026
Ambiente: HML
Branch canônica: `design/frontend-master-plan`
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
MagicPath referência: projeto `467916888211595264`, componente Login `467916892707889152`.

## Motivo
Auditoria do BUILD inicial do PROMPT 16 identificou:
1. o Login funcional ficou visualmente simplificado em relação ao protótipo MagicPath aprovado;
2. o botão ícone mostrar/ocultar senha não recebeu tooltip contextual, embora a premissa oficial determine tooltip quando ele agrega compreensão;
3. o Lovable acrescentou uma decisão em `AGENTS.md`, caminho não autorizado pelo `active-task.json`. Essa alteração deve ser revertida no Lovable e não será espelhada para o GitHub canônico.

## Instrução exata a enviar ao Lovable

MODO: BUILD CORRETIVO DO PROMPT 16. ALTERE SOMENTE SYS-01 LOGIN. NÃO ALTERE BACKEND.

1. Reverta exclusivamente o bloco `## Decisões de frontend` que foi acrescentado ao `AGENTS.md` no BUILD anterior, restaurando o arquivo ao estado anterior a essa alteração. Não modifique nenhuma outra linha do `AGENTS.md`.
2. Mantenha integralmente a lógica funcional já aprovada do Login, inclusive `signInWithPassword`, leitura de `vinculos_usuarios` sob RLS, estados, rotas oficiais e dependências de SYS-04/SYS-05.
3. Ajuste apenas a apresentação de `src/routes/login.tsx` para maior fidelidade ao protótipo MagicPath aprovado `ContaOS — Login`, componente `467916892707889152`, preservando o Design System `Executive Command Center + Audit Workspace`:
   - desktop com painel institucional escuro à esquerda e área de autenticação clara à direita;
   - painel escuro com profundidade cinematográfica discreta, grid sutil e glows desfocados sem comprometer contraste;
   - marca `ContaOS` e subtítulo `CONTROLE • AUDITORIA • CONFORMIDADE`;
   - badge `Ambiente seguro de homologação`;
   - headline `Inteligência e governança para cada etapa da prestação de contas.`;
   - texto de apoio institucional;
   - três cartões: `Rastreável — Fontes, versões e decisões`, `Seguro — Acesso por organização e perfil`, `Explicável — IA sempre vinculada à evidência`;
   - rodapé institucional `ContaOS • Ambiente HML` e `Segurança e rastreabilidade por padrão`;
   - área direita com `ACESSO AO CONTAOS`, `Bem-vindo de volta` e texto explicativo;
   - após o formulário, cartão `Acesso protegido` explicando que a sessão respeita permissões e vínculos da organização;
   - não criar link funcional de recuperação de senha nesta tarefa, pois SYS-02 pertence ao próximo prompt.
4. Em `src/components/auth/LoginForm.tsx`, mantenha `aria-label` e `aria-pressed` no botão mostrar/ocultar senha e adicione tooltip contextual usando o componente Tooltip já existente no projeto. Texto: `Mostrar senha` / `Ocultar senha`. Tooltip deve funcionar por hover e foco. No mobile, o botão continua autoexplicativo pelo ícone/ação e nome acessível; tooltip não substitui label nem erro.
5. Responsividade obrigatória: 1440, 1280, 768 e 390 px. Em 768, painel institucional vira faixa superior compacta. Em 390, manter somente os elementos essenciais, sem rolagem horizontal e sem ocultar informação funcional crítica.
6. Não altere `src/routes/index.tsx`, `src/routes/__root.tsx`, `src/start.ts`, `src/integrations/supabase/**`, `package.json`, `src/styles.css`, schema, migrations, RLS, Auth config, Edge Functions, Storage ou qualquer outra feature.
7. Não crie tabela, RPC, migration, policy, Edge Function, secret ou backend paralelo.
8. Atualize `docs/frontend/lovable/SYS-01-login.md` registrando esta correção visual, a reversão da alteração indevida de `AGENTS.md` e os testes repetidos.
9. Rode novamente, do estado final: typecheck completo, suíte Vitest do projeto, verificação de secrets no frontend e Playwright em 1440/1280/768/390, incluindo teclado e credencial inválida.
10. Ao final, liste exatamente os arquivos alterados e resultados PASS/FAIL. Não avance para SYS-02.

## Critério de aceite
A correção só será espelhada no GitHub se o diff permanecer restrito ao SYS-01, a alteração de `AGENTS.md` ficar revertida, backend permanecer intocado e as verificações finais produzirem evidência atualizada.
