# Histórico aplicado no Supabase HML

Esta pasta contém o histórico SQL **exatamente como registrado em `supabase_migrations.schema_migrations`** no projeto HML do ContaOS.

## Regras

- Ambiente: Supabase HML `gklhhhyosgasnyoxlrui`.
- Repositório: `contaos9999/develop`.
- O repositório `contaos9999/prod` não deve receber alterações durante a homologação.
- Os blocos desta pasta preservam a ordem cronológica, os timestamps e os nomes das migrations efetivamente aplicadas.
- Não editar migrations históricas já aplicadas. Toda correção deve entrar como nova migration.
- Os blocos de histórico não devem ser reaplicados sobre o HML existente.
- Para reconstrução de um ambiente vazio, os blocos devem ser executados em ordem cronológica após as migrations individuais anteriores correspondentes.
- Nenhuma credencial ou segredo é versionado aqui.

## Estratégia

As primeiras migrations permanecem em `supabase/migrations/`. O histórico posterior também é preservado nesta pasta em blocos cronológicos extraídos diretamente do banco, evitando reconstrução manual e drift.

As Edge Functions ativas ficam em `supabase/functions/` e utilizam apenas nomes de variáveis de ambiente. Valores como `OPENAI_API_KEY` permanecem exclusivamente nos Secrets do Supabase.
