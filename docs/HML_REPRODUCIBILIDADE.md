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

- Quantidade atual de migrations no HML: 46
- Última migration: `20261101233244_0042_hardening_grants_anon`
- Snapshot integral versionado: `supabase/applied-history/contaos-hml-full-history.sql`
- O snapshot integral já contém o histórico até `20261101225646_0038_exportacao_historico_migrations`.
- Deltas posteriores: `05_0041_auth_onboarding_timezone_brasilia.sql` e `06_0042_hardening_grants_anon.sql`.
- SHA-256 da exportação completa atual do histórico SQL: `9a40763031b5d022416523ae28c9c3ed666860946d618191d02f65dd05af9230`

## Segurança

Nenhum arquivo de versionamento contém o valor de `OPENAI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, token interno dos workers ou segredos de webhooks. O `.env.example` contém apenas nomes de variáveis e valores não secretos de configuração.

A role `anon` possui somente leitura dos catálogos públicos de mensagens, status e localização. Dados de organizações, contratos, documentos, filas, notificações, auditoria e demais módulos dependem de autenticação e RLS.

Todas as tabelas públicas do HML estão com RLS habilitada. As funções públicas `SECURITY DEFINER` de infraestrutura não são executáveis pelas roles `anon` ou `authenticated`; permanecem restritas ao `service_role`.

O Advisor de segurança apresenta somente o aviso `extension_in_public` para a extensão `pg_net`, instalada no schema `public`. Trata-se de extensão de infraestrutura utilizada para as chamadas HTTP dos workers/Cron e mantida como exceção técnica controlada. Não foi forçada relocação para evitar quebra do runtime do Supabase.

## Performance

O Advisor de performance pode listar índices como `unused_index` enquanto o HML estiver sem carga operacional representativa. Esses índices não devem ser removidos antes dos testes de carga e do uso real das consultas, pois incluem cobertura de chaves estrangeiras, RLS, filtros operacionais e busca vetorial.

## Localização

O padrão de produto é:

- idioma: `pt-BR`;
- timezone: `America/Sao_Paulo`;
- data: `DD/MM/YYYY`;
- horário: `HH24:MI:SS`;
- moeda: `BRL`.

## Promoção futura

A promoção para produção deverá utilizar exclusivamente migrations e Edge Functions homologadas no `develop`. Dados fictícios ou operacionais do HML não devem ser promovidos para produção. Antes da promoção, executar novamente testes de RLS, portões de negócio, idempotência, filas, Storage, OpenAI, Advisors de segurança/performance e testes ponta a ponta do frontend.
