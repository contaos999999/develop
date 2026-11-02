# ContaOS — Regras obrigatórias do agente

Este repositório é o HML oficial do ContaOS. A fonte de verdade é, nesta ordem: decisão funcional mais recente aprovada, PRD/Premissas do pacote 4.1, Arquitetura Oficial Lovable + Supabase, Manual Backend Supabase, migrations/testes versionados e banco HML validado.

## Regras absolutas
- Backend oficial: Supabase próprio. Não criar backend paralelo.
- `contaos9999/develop` é HML. `contaos9999/prod` não pode ser alterado durante desenvolvimento/homologação.
- Nenhum secret, `service_role`, senha de banco ou token privado pode ir para frontend, Git ou logs de usuário.
- Toda tabela de negócio exposta deve ter RLS. Ações críticas usam RPC/Edge Function autorizada.
- Frontend nunca calcula nem atualiza diretamente status críticos.
- `PODE APRESENTAR AO CONTRATANTE` exige 100% dos requisitos obrigatórios e aplicáveis conformes e parecer interno aprovado.
- `PODE REAPRESENTAR AO CONTRATANTE` exige 100% dos apontamentos da rodada tratados.
- Documento não é sobrescrito. Correção gera nova versão.
- Alerta histórico transversal de outro contrato é informativo e não integra o portão de 100%.
- Regra preventiva material exige fonte formal, escopo, versão e aprovação humana.
- Histórico, auditoria, versões e evidências críticas são append-only no fluxo normal.
- IA sugere e fundamenta; decisão material permanece sujeita à aprovação humana.
- Mensagens de usuário: PT-BR amigável. Exibição de datas/horas: `DD/MM/YYYY HH:mm:ss`, `America/Sao_Paulo`, moeda BRL.

## Zero-Drift
Antes de editar, leia `docs/frontend/ZERO_DRIFT.md` e `docs/tasks/active-task.json`. Não altere caminho proibido nem saia do escopo autorizado. Mudança de banco, RLS ou Edge Function só pode ocorrer se explicitamente autorizada no manifesto.
