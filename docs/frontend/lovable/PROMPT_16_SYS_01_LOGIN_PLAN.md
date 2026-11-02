# PROMPT 16 — SYS-01 Login — PLAN

Data: 02/11/2026, Horário de Brasília
Ambiente: HML
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Supabase HML: `gklhhhyosgasnyoxlrui`

## Fonte

Manual Mestre `PROMPT 16 - SYS-01 - Login` + FE v4 + Premissas Vinculantes + Design System aprovado.

## Rastreabilidade 96/96

A matriz canônica 08A–08D não vincula diretamente SYS-01 a um RF/NFR específico. Não será atribuído ID atômico artificial. Aplicam-se as regras transversais do frontend, segurança, acessibilidade, responsividade e testes previstas no FE v4 e nas instruções permanentes do projeto.

## Mensagem exata enviada ao Lovable

MODO: PLAN. NÃO ALTERE CÓDIGO.
TAREFA: SYS-01 - Login
ROTA: /login
ACESSO: público
BACKEND AUTORIZADO: Supabase Auth: signInWithPassword

Regras:
- Supabase próprio já conectado;
- não criar tabela, RPC ou Edge Function nova se não existir; se faltar, declarar LACUNA DE BACKEND e parar;
- não colocar secret no frontend;
- não calcular status crítico localmente;
- não mudar layout global, auth, cliente Supabase ou outra feature sem necessidade explicitamente listada;
- preservar RLS como autoridade.

Planeje:
1. arquivos exatos a alterar;
2. queries/RPCs/functions usadas;
3. componentes;
4. estados loading/empty/success/denied/error e processing quando aplicável;
5. comportamento desktop 1440/1280, tablet 768 e mobile 390;
6. acessibilidade teclado/foco/labels/status;
7. testes.

Premissas vinculantes adicionais já aprovadas:
- direção visual Executive Command Center + Audit Workspace;
- Login deve seguir o protótipo MagicPath aprovado como referência visual, sem alterar regra funcional;
- campos e-mail/senha com label visível;
- botão Entrar desabilitado durante envio;
- erro de credencial não revela se usuário existe;
- após login, carregar vínculos e direcionar para seleção de organização ou dashboard conforme backend/contexto;
- tooltips acessíveis somente onde agregarem compreensão real, nunca substituindo label/erro;
- PT-BR, sem secret, sem token próprio em localStorage;
- não tocar em backend, schema, migrations, RLS, Edge Functions, Auth config ou Storage;
- todo Build futuro deverá ser espelhado e versionado no GitHub em `frontend/**` e acompanhado de evidência em `docs/frontend/lovable/**`.

Não implemente até aprovação.
