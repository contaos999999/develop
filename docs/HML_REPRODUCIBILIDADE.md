# Reprodutibilidade do ContaOS HML

O ambiente oficial de homologação é o Supabase `gklhhhyosgasnyoxlrui` e o repositório oficial de HML é `contaos9999/develop`.

## Regras de versionamento

- migrations aplicadas nunca são reescritas;
- toda correção posterior entra como nova migration;
- timestamps registrados em `supabase_migrations.schema_migrations` são preservados;
- Edge Functions ativas são versionadas em `supabase/functions/`;
- testes de homologação ficam em `supabase/tests/`;
- segredos permanecem apenas no Supabase Secrets/Vault;
- `contaos9999/prod` não recebe alterações durante homologação;
- o histórico SQL completo pode ser exportado pelo endpoint interno `export-migration-history`, protegido pelo token interno do Vault;
- a exportação integral é gerada diretamente de `supabase_migrations.schema_migrations`, evitando reconstrução manual.

## Estado sincronizado

- Quantidade atual de migrations no HML: 48.
- Última migration: `20261101233537_0043_hardening_funcoes_privadas`.
- Snapshot histórico versionado: `supabase/applied-history/contaos-hml-full-history.sql`.
- O snapshot preserva o histórico consolidado até `20261101225646_0038_exportacao_historico_migrations`.
- Migrations posteriores ao snapshot estão versionadas individualmente em `supabase/migrations/`, incluindo onboarding Auth, hardening de grants anônimos, configuração OpenAI por organização e hardening do schema privado.
- O materializador `supabase/scripts/materialize-migrations.mjs` separa o checkpoint histórico em migrations individuais e recusa divergências de conteúdo.

## Segurança

Nenhum arquivo de versionamento contém o valor de `OPENAI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, token interno dos workers ou segredos de webhooks. O `.env.example` contém somente nomes de variáveis e valores não secretos.

Todas as tabelas públicas do HML estão com RLS habilitada e possuem policy. A role `anon` não executa funções no schema `privado` e não possui acesso a dados de organizações/contratos. Antes do login, ficam públicos apenas catálogos de interface/localização e utilitários de formatação sem acesso a tenant.

As funções internas `SECURITY DEFINER` usam `search_path` controlado. As ações críticas são expostas por wrappers/RPCs específicos e continuam subordinadas a autenticação, perfil e escopo contratual.

O Advisor de segurança apresenta somente o aviso `extension_in_public` para `pg_net`, extensão de infraestrutura utilizada nas chamadas HTTP dos workers/Cron. A relocação não foi forçada para evitar quebra do runtime gerenciado.

## Testes de homologação

Os testes versionados estão em:

- `supabase/tests/hml_acceptance.sql`: isolamento A/B, perfil leitor, portão 99/100, portão 100/100, não aplicável sem fundamento, estados de apresentação/reapresentação e concorrência otimista;
- `supabase/tests/queues_edge_auth.sql`: idempotência de jobs, DLQ, workers oficiais e autenticação negativa de Edge Functions.

Os cenários sintéticos utilizam transações com `ROLLBACK`, portanto não deixam organizações, usuários, contratos ou competências de teste no HML.

## Performance

O Advisor de performance não aponta chaves estrangeiras sem índice. Em um HML sem carga operacional, índices podem aparecer como `unused_index`; eles não devem ser removidos antes de testes de carga e uso real, pois incluem cobertura de FKs, RLS, filtros operacionais e busca vetorial.

## Observabilidade

O cron `contaos-saude-operacional` executa `privado.verificar_saude_operacional()` a cada cinco minutos. O monitor registra alertas por organização quando encontra jobs enviados à DLQ nas últimas 24 horas ou concentração de falhas assíncronas na última hora.

Os workers rápidos e pesados possuem schedules próprios, e o histórico do `pg_cron` deve permanecer monitorado no HML e em produção.

## Localização

O padrão oficial do produto é:

- idioma: `pt-BR`;
- timezone: `America/Sao_Paulo`;
- data: `DD/MM/YYYY`;
- horário: `HH24:MI:SS`;
- moeda: `BRL`.

## Promoção futura

A promoção para produção deverá utilizar exclusivamente migrations, Edge Functions e configurações homologadas no `develop`. Dados fictícios ou operacionais do HML não devem ser promovidos.

Antes da promoção, executar novamente os testes versionados, Advisors de segurança/performance, teste de carga, validação de backup/restauração do projeto PROD e testes ponta a ponta do frontend. O procedimento de release e rollback está em `docs/RELEASE_ROLLBACK.md`.
