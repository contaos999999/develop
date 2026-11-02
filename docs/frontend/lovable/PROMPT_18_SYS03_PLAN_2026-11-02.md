# PROMPT 18 — SYS-03 — PLAN

Fonte primária: `ContaOS_Pacote_Mestre_Arquitetura_4_1_100_PRD_Lovable_Supabase_FINAL.zip`
Manual: `06_PROMPTS_COPIAR_COLAR/Manual_Mestre_Prompts_4_1_100_PRD.docx`

## Texto literal do pacote 4.1

PROMPT 18 - SYS-03 - Redefinir senha

Objetivo em palavras simples: Construir a tela Redefinir senha (SYS-03) na rota /redefinir-senha.

ANTES DE COLAR: A operação Supabase citada no plano precisa existir e estar autorizada.

A. PLAN MODE - copie e cole

MODO: PLAN. NÃO ALTERE CÓDIGO.
TAREFA: SYS-03 - Redefinir senha
ROTA: /redefinir-senha
ACESSO: público/token
BACKEND AUTORIZADO: Supabase Auth: updateUser

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

Não implemente até aprovação.

## Cruzamento documental

O frontend 4.1 define para SYS-03:
- rota `/redefinir-senha`;
- acesso `público/token`;
- leitura por sessão de recovery do Supabase Auth;
- escrita `updateUser(password)`;
- fluxo oficial de recuperação de senha;
- sessão mantida pelo cliente Supabase, sem token próprio;
- nenhuma secret no browser;
- estados mínimos loading, empty, success, denied, error e saving/processing quando aplicável;
- responsividade 1440/1280/768/390;
- labels, foco, teclado e status textual.

O Caderno 96 não associa SYS-03 a um requisito funcional atômico específico do PRD. SYS-03 é tela sistêmica de Auth governada pelo PROMPT 18 e regras transversais de segurança/Zero-Drift.

## Restrições adicionais já aprovadas para este projeto

- preservar SYS-01 e SYS-02 já certificados;
- tooltip contextual quando acrescentar compreensão real, com hover/foco e alternativa de toque quando aplicável;
- não alterar `client.ts`/Auth global sem necessidade expressamente aprovada;
- não criar cliente Auth paralelo;
- não alterar backend HML nesta tarefa;
- tudo deve ser registrado e versionado no GitHub.