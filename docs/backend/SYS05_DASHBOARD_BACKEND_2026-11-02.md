# SYS-05 — Backend do Dashboard operacional

Data: 02/11/2026
Ambiente: HML
Projeto Supabase: gklhhhyosgasnyoxlrui
Branch: `backend/sys05-dashboard-summary`

## Contexto

O PROMPT 20 / SYS-05 autoriza o frontend a consumir somente views/RPCs de resumo já existentes no Supabase. A inspeção do HML confirmou que não existia endpoint de resumo operacional de contratos, competências, prazos e atenções. A RPC preexistente `obter_saude_operacional` trata saúde técnica de jobs/DLQ/storage/cron e não atende o Dashboard operacional.

A lacuna foi resolvida no backend HML antes da continuação do frontend.

## Endpoint criado

`public.obter_resumo_dashboard(p_id_organizacao uuid) returns jsonb`

Características de segurança e governança:
- `STABLE` e read-only;
- `SECURITY INVOKER`, preservando as policies RLS das tabelas lidas;
- `search_path=''`;
- exige sessão autenticada ativa e acesso à organização por `privado.usuario_tem_acesso_organizacao`;
- `anon` e `public` sem EXECUTE;
- EXECUTE somente para `authenticated` e `service_role`;
- prazos avaliados em `America/Sao_Paulo`, alinhados ao padrão Brasília;
- não cria nem altera dados;
- não substitui nem antecipa o Painel Executivo V5-12 / PROMPT 88.

## Contrato de retorno

O retorno usa `schema_versao = sys05-v1` e contém:
- organização;
- resumo: contratos visíveis, contratos ativos, competências em fluxo, competências que exigem atenção, itens com prazo vencido e atenções abertas;
- distribuição de contratos por situação;
- distribuição de competências por situação;
- próximos prazos, limitado a 8;
- atenções prioritárias, limitado a 8;
- data/hora de geração em formato brasileiro.

Os KPIs são calculados no PostgreSQL. O frontend não recalcula autorização, status ou indicadores críticos.

## Migration

Arquivo versionado:
`supabase/migrations/20261102114500_sys05_dashboard_summary.sql`

Migration aplicada no HML com sucesso e registrada pelo Supabase como:
- version: `20261102114958`
- name: `sys05_dashboard_summary`

## Testes de regressão

Arquivo:
`supabase/tests/sys05_dashboard_summary.sql`

Teste executado em transação com dados sintéticos e `ROLLBACK` integral. Resultado: 6/6 PASS.

1. `anon` não possui EXECUTE: PASS.
2. `authenticated` possui EXECUTE: PASS.
3. organização sem vínculo bloqueada com SQLSTATE `42501`: PASS.
4. organização autorizada retorna `schema_versao=sys05-v1`: PASS.
5. escopo contratual preservado: dois contratos sintéticos na organização, usuário com acesso a apenas um, resumo contabilizou exatamente 1 contrato e 1 competência: PASS.
6. função confirmada como `SECURITY INVOKER`: PASS.

Nenhum dado sintético permaneceu no HML após o teste.

## Verificação estrutural

Estado pós-migration:
- `prosecdef=false`;
- `proconfig=[search_path=""]`;
- `anon_exec=false`;
- `authenticated_exec=true`;
- `service_role_exec=true`.

## Advisors

Security Advisor pós-DDL:
- nenhum alerta novo relacionado à RPC;
- permanece somente o warning preexistente `Leaked Password Protection Disabled`, já documentado e dependente de plano Supabase Pro.

Performance Advisor:
- apenas achados INFO globais/preexistentes de FKs sem índice e índices ainda não utilizados;
- nenhum finding específico criado pela RPC;
- não houve ampliação de escopo para corrigir centenas de avisos globais durante esta tarefa.

## Zero-Drift

- HML apenas;
- PROD intocado;
- nenhuma alteração de frontend nesta branch;
- nenhuma policy RLS removida ou flexibilizada;
- nenhuma tabela nova;
- nenhuma Edge Function nova;
- rollback, se necessário, deve ser feito por migration compensatória, sem reescrever histórico.

## Resultado

**LACUNA DE BACKEND DO PROMPT 20: RESOLVIDA.**

O frontend SYS-05 está autorizado a consumir exclusivamente `public.obter_resumo_dashboard(uuid)` para o resumo operacional inicial.