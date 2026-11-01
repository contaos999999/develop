# ContaOS HML - Supabase

Este diretório representa o backend de homologação do ContaOS.

## Fonte de verdade

O banco HML utiliza migrations versionadas no Supabase. O checkpoint histórico exato está em:

`supabase/applied-history/contaos-hml-full-history.sql`

Esse arquivo preserva, em ordem cronológica, o SQL registrado pelo próprio `supabase_migrations.schema_migrations` até a migration `20261101225646_0038_exportacao_historico_migrations`.

As migrations posteriores ao checkpoint devem permanecer em `supabase/migrations/` como arquivos normais. Atualmente a sequência posterior inclui `20261101230710_0041_auth_onboarding_timezone_brasilia.sql`.

## Materializar migrations individuais

Na raiz do repositório, execute:

```bash
node supabase/scripts/materialize-migrations.mjs
```

O script separa o checkpoint pelos marcadores oficiais `-- MIGRATION <timestamp>_<nome>`, cria somente os arquivos ausentes e valida byte a byte os arquivos que já existem. Se detectar divergência, encerra com erro e não considera o histórico consistente.

## Regras de promoção HML -> PROD

1. Nunca copiar dados de teste do HML para PROD.
2. Promover apenas migrations, Edge Functions e configurações versionáveis aprovadas.
3. Segredos permanecem no Supabase Secrets/Vault e nunca no GitHub.
4. O frontend usa somente chave pública/publishable e RLS.
5. `service_role` e `OPENAI_API_KEY` são exclusivos de backend.
6. Todas as mensagens de usuário são em português do Brasil.
7. Datas e horários usam `America/Sao_Paulo` e apresentação no padrão brasileiro.
8. Antes de promover, executar Advisors de segurança/performance e testes de isolamento multiempresa.
9. O repositório de produção não deve receber alterações antes da homologação formal.

## Status críticos do fluxo

Os rótulos oficiais de liberação são:

- `PODE APRESENTAR AO CONTRATANTE`
- `PODE REAPRESENTAR AO CONTRATANTE`

A inteligência artificial produz análises e sugestões. Aprovações e liberações críticas continuam sob decisão humana.
