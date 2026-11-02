# ContaOS 4.1 — Arquitetura Frontend: Regras Constitucionais e Premissas Permanentes

Ambiente: HML. Supabase oficial conectado: `gklhhhyosgasnyoxlrui`.

Arquitetura oficial: frontend Lovable/React/TypeScript + backend Supabase próprio conectado ao projeto.

## Regras constitucionais

1. Supabase é a única fonte de verdade.
2. Toda tabela de negócio exposta usa RLS e grants mínimos.
3. O frontend nunca recebe secret key, senha de banco ou chave privada.
4. CRUD simples pode usar Data API com RLS.
5. Transições críticas usam RPC/Database Function ou Edge Function autenticada.
6. `PODE APRESENTAR AO CONTRATANTE` somente com 100,00% dos requisitos obrigatórios e aplicáveis conformes.
7. `PODE REAPRESENTAR AO CONTRATANTE` somente com 100% dos apontamentos da rodada tratados.
8. `VALIDADA` somente após parecer final favorável do contratante.
9. Alerta histórico transversal de outro contrato é informativo e não integra o portão de 100% por si só.
10. Documentos não são sobrescritos; nova correção = nova versão.
11. IA não cria obrigação sem fonte, escopo e aprovação humana.
12. Uma tarefa não pode alterar área fora do escopo.
13. Se precisar de algo não autorizado, PARE e explique.

## Premissas adicionais permanentes

- Obedecer PRD 4.1, Premissas, Arquitetura, Zero-Drift, matriz 96/96, PROMPT 00–99 e prompts atômicos 001–096.
- HML somente; PROD proibido nesta fase.
- Backend Supabase certificado deve ser consumido, não reconstruído.
- Nenhuma tabela, migration, RLS, Edge Function, Auth, Storage ou backend paralelo sem tarefa/autorização específica.
- Frontend em PT-BR, datas/horas brasileiras e moeda BRL.
- Tooltips acessíveis como componente padrão quando houver ganho real de compreensão, com hover + foco no desktop e alternativa por toque no mobile.
- Tudo deve ser documentado, registrado e versionado no GitHub.
- Design System oficial: Executive Command Center + Audit Workspace.
- Playwright, acessibilidade, responsividade 1440/1280/768/390 e Zero-Drift fazem parte do critério de pronto.

## Governança de sincronização

O projeto Lovable só poderá avançar para implementação funcional quando houver evidência de sincronização com o repositório HML `contaos9999/develop`, em branch de frontend autorizada, ou quando cada alteração for espelhada e versionada no GitHub antes de ser considerada válida.
