# ContaOS 4.1 — PROMPT 00 BUILD

Data: 02/11/2026
Ambiente: HML
Projeto Lovable: b113dd59-6caf-4c92-8302-457a037a0c6f
Supabase HML: gklhhhyosgasnyoxlrui

## Texto exato enviado ao Lovable

MODO: BUILD.

Salve as regras constitucionais aprovadas nas Project Instructions e crie/atualize AGENTS.md e docs/frontend/ARQUITETURA.md com o mesmo conteúdo. Não crie tabelas ainda. Não altere design.

Regras constitucionais a registrar:
1. Supabase é a única fonte de verdade.
2. Toda tabela de negócio exposta usa RLS e grants mínimos.
3. O frontend nunca recebe secret key, senha de banco ou chave privada.
4. CRUD simples pode usar Data API com RLS.
5. Transições críticas usam RPC/Database Function ou Edge Function autenticada.
6. PODE APRESENTAR AO CONTRATANTE somente com 100,00% dos requisitos obrigatórios e aplicáveis conformes.
7. PODE REAPRESENTAR AO CONTRATANTE somente com 100% dos apontamentos da rodada tratados.
8. VALIDADA somente após parecer final favorável do contratante.
9. Alerta histórico transversal de outro contrato é informativo e não integra o portão de 100% por si só.
10. Documentos não são sobrescritos; nova correção = nova versão.
11. IA não cria obrigação sem fonte, escopo e aprovação humana.
12. Uma tarefa não pode alterar área fora do escopo.
13. Se precisar de algo não autorizado, PARE e explique.

Premissas adicionais permanentes desta implementação:
- obedecer PRD 4.1, Premissas, Arquitetura, Zero-Drift, matriz 96/96, PROMPT 00–99 e prompts atômicos 001–096;
- HML somente; PROD proibido nesta fase;
- backend Supabase certificado deve ser consumido, não reconstruído;
- nenhuma tabela, migration, RLS, Edge Function, Auth, Storage ou backend paralelo sem tarefa/autorização específica;
- frontend em PT-BR, datas/horas brasileiras e moeda BRL;
- tooltips acessíveis como componente padrão quando houver ganho real de compreensão, com hover + foco no desktop e alternativa por toque no mobile;
- tudo deve ser documentado, registrado e versionado no GitHub;
- Design System oficial: Executive Command Center + Audit Workspace;
- Playwright, acessibilidade, responsividade 1440/1280/768/390 e Zero-Drift fazem parte do critério de pronto.

Ao final, liste exatamente os arquivos alterados e confirme explicitamente que nenhuma tabela, migration, secret, Edge Function ou backend paralelo foi criado.