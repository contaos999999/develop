# Histórico aplicado no Supabase HML

Esta pasta preserva o histórico SQL do projeto HML do ContaOS exatamente como registrado em `supabase_migrations.schema_migrations`.

## Ambiente oficial

- Supabase HML: `gklhhhyosgasnyoxlrui`
- GitHub HML: `contaos9999/develop`
- Produção: `contaos9999/prod`, sem alterações durante a homologação
- Localização: `pt-BR`, timezone `America/Sao_Paulo`

## Estado atual

O HML possui 45 migrations registradas. A versão mais recente é:

`20261101230710_0041_auth_onboarding_timezone_brasilia`

O arquivo `contaos-hml-full-history.sql` é um snapshot integral extraído diretamente do Supabase e já inclui o histórico até `20261101225646_0038_exportacao_historico_migrations`.

Para reproduzir o estado atual após esse snapshot, aplicar também:

`05_0041_auth_onboarding_timezone_brasilia.sql`

A exportação integral mais recente do HML gerada pelo backend possui SHA-256 do SQL:

`f11dd51912cf959d141dff717b9e0defa3938d8d43beeb9249cda63a661059b4`

Esse hash corresponde ao histórico atual completo, incluindo a migration `0041`. O snapshot versionado anterior e o delta devem ser preservados como histórico, sem reescrita retroativa.

## Regras

- Não editar migrations históricas já aplicadas.
- Toda correção entra como nova migration com timestamp único.
- Não reaplicar os blocos desta pasta sobre o HML existente.
- Em ambiente vazio, executar o histórico em ordem cronológica.
- Nenhuma credencial, `service_role`, token interno ou `OPENAI_API_KEY` deve ser versionada.
- Edge Functions ativas ficam em `supabase/functions/`.
- Valores de Secrets permanecem exclusivamente no Supabase Secrets/Vault.

## Observação sobre numeração

Existem nomes legados repetidos como `0030`, `0031` e `0032`. Isso não representa colisão de migration, porque o identificador de ordenação do Supabase é o timestamp, e todos os timestamps registrados são únicos. Esses nomes não devem ser alterados retroativamente.
