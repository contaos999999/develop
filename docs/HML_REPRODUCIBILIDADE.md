# Reprodutibilidade do ContaOS HML

Data de referência: 02/11/2026, Horário de Brasília.

O ambiente oficial de homologação é o Supabase `gklhhhyosgasnyoxlrui` e o repositório oficial de HML é `contaos9999/develop`. O repositório `contaos9999/prod` permanece fora do desenvolvimento/homologação.

## Estado certificado

- migrations registradas no Supabase HML: **51**;
- última migration: `20261102000441_0046_openai_modelo_analise_operacional`;
- histórico antigo materializado em arquivos individuais por `supabase/scripts/materialize-migrations.mjs`;
- checkpoint imutável disponível em `supabase/applied-history/contaos-hml-full-history.sql`;
- Edge Functions ativas versionadas em `supabase/functions/`;
- testes de homologação ficam em `supabase/tests/`;
- secrets permanecem apenas no Supabase Secrets/Vault;
- nenhum valor de `OPENAI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, token interno ou segredo de webhook é versionado.

## Regras de versionamento

1. migration aplicada nunca é reescrita;
2. correção entra como nova migration;
3. timestamp e nome do histórico Supabase são preservados;
4. materializador falha se um arquivo existente divergir do checkpoint;
5. Zero-Drift e Architecture Guard executam no GitHub;
6. `prod` não recebe mudanças enquanto a versão não for homologada.

## Segurança

- **117/117** tabelas `public` com RLS;
- **2/2** tabelas `privado` com RLS, sem leitura para `anon`/`authenticated`;
- nenhuma função `SECURITY DEFINER` do schema `public` executável por `anon`;
- Storage `contaos-documentos` privado;
- RPCs críticas protegidas por autenticação/perfil/escopo;
- workers internos protegidos por token service-to-service do Vault;
- teste A/B de organizações/perfis executado com `ROLLBACK`: PASS.

O Security Advisor não possui Critical da aplicação. Permanece apenas o WARN `extension_in_public` para `pg_net`, extensão não relocável (`extrelocatable=false`) usada pelo runtime/Cron do Supabase. Não é drift de aplicação.

## Localização

- idioma: `pt-BR`;
- timezone: `America/Sao_Paulo`;
- data: `DD/MM/YYYY`;
- horário: `HH24:MI:SS`;
- data/hora: `DD/MM/YYYY HH24:MI:SS`;
- moeda: `BRL`;
- mensagens de interface: catálogo PT-BR com 38 entradas;
- status UI: catálogo com 23 entradas;
- `PODE APRESENTAR AO CONTRATANTE`;
- `PODE REAPRESENTAR AO CONTRATANTE`.

## Testes certificados

- RLS A/B e perfis: PASS;
- portão 99/100 e 100/100: PASS;
- parecer interno obrigatório: PASS;
- reapresentação 100%: PASS;
- concorrência otimista: PASS;
- idempotência + DLQ: PASS;
- oito processadores oficiais: HTTP 200;
- autenticação negativa de Edge: 401;
- OpenAI chave/modelo/análise estruturada/visão-OCR: PASS;
- Storage privado e URL assinada: PASS;
- 75/75 entidades explícitas da matriz: presentes e com RLS;
- carga: 10.000 contratantes + 10.000 contratos sintéticos, 200 consultas paginadas com RLS, p95 **60,52 ms**; 100/100 chamadas Edge concorrentes HTTP 200 e 0 HTTP 5xx. Dados revertidos.

## Observabilidade

O cron `contaos-saude-operacional` executa verificação de saúde a cada cinco minutos. Filas rápidas/pesadas têm schedules próprios, falhas são sanitizadas, retry/DLQ são rastreados e alertas operacionais preservam correlation id quando aplicável.

## Promoção futura para PROD

A promoção para produção deverá utilizar apenas migrations/Edge Functions homologadas no `develop`. Backup/PITR/RPO/RTO e teste de restauração do **ambiente PROD** são gates de implantação de produção e permanecem fora desta certificação do backend HML pré-frontend. O Manual de Ambiente determina que a produção é preparada em etapa posterior, depois da homologação. O procedimento de release/rollback está em `docs/RELEASE_ROLLBACK.md`.
