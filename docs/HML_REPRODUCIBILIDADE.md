# Reprodutibilidade do ContaOS HML

O ambiente oficial de homologação é o Supabase `gklhhhyosgasnyoxlrui` e o repositório oficial de HML é `contaos9999/develop`.

## Regras de versionamento

- migrations aplicadas nunca são reescritas;
- toda correção posterior entra como nova migration;
- timestamps registrados em `supabase_migrations.schema_migrations` são preservados;
- Edge Functions ativas são versionadas em `supabase/functions/`;
- segredos permanecem apenas no Supabase Secrets/Vault;
- `contaos9999/prod` não recebe alterações durante homologação;
- o histórico SQL completo pode ser exportado pelo endpoint interno `export-migration-history`, protegido pelo token interno do Vault;
- a exportação integral é gerada diretamente de `supabase_migrations.schema_migrations`, evitando reconstrução manual.

## Estado sincronizado

- Quantidade atual de migrations no HML: 45
- Última migration: `20261101230710_0041_auth_onboarding_timezone_brasilia`
- Snapshot integral versionado: `supabase/applied-history/contaos-hml-full-history.sql`
- O snapshot integral já contém o histórico até `20261101225646_0038_exportacao_historico_migrations`.
- Delta posterior: `supabase/applied-history/05_0041_auth_onboarding_timezone_brasilia.sql`
- SHA-256 da exportação completa atual do histórico SQL: `f11dd51912cf959d141dff717b9e0defa3938d8d43beeb9249cda63a661059b4`

## Segurança

Nenhum arquivo de versionamento contém o valor de `OPENAI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, token interno dos workers ou segredos de webhooks. O `.env.example` contém apenas nomes de variáveis e valores não secretos de configuração.

## Localização

O padrão de produto é:

- idioma: `pt-BR`;
- timezone: `America/Sao_Paulo`;
- data: `DD/MM/YYYY`;
- horário: `HH24:MI:SS`;
- moeda: `BRL`.

## Promoção futura

A promoção para produção deverá utilizar exclusivamente migrations e Edge Functions homologadas no `develop`. Dados fictícios ou operacionais do HML não devem ser promovidos para produção. Antes da promoção, executar novamente testes de RLS, portões de negócio, idempotência, filas, Storage, OpenAI, Advisors de segurança/performance e testes ponta a ponta do frontend.
