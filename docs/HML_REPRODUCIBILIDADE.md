# Reprodutibilidade do ContaOS HML

O ambiente de homologação é o Supabase `gklhhhyosgasnyoxlrui` e o repositório oficial de HML é `contaos9999/develop`.

## Regras de versionamento

- migrations já aplicadas nunca são reescritas;
- toda correção posterior entra como nova migration;
- os timestamps registrados em `supabase_migrations.schema_migrations` são preservados;
- Edge Functions ativas são versionadas em `supabase/functions/`;
- segredos permanecem apenas no Supabase Secrets/Vault;
- o repositório `prod` não recebe alterações durante homologação;
- o histórico SQL completo pode ser exportado pelo endpoint interno `export-migration-history`, protegido pelo token interno do Vault;
- a exportação integral é gerada diretamente a partir de `supabase_migrations.schema_migrations`, evitando reconstrução manual.

## Integridade

A sincronização deve validar SHA-256 do arquivo de histórico antes de usá-lo como evidência de configuração. O arquivo exportado não contém chaves OpenAI nem valores dos Secrets do Supabase.

## Promoção futura

A promoção para produção deve usar migrations e Edge Functions homologadas no `develop`. Dados de teste do HML não devem ser promovidos para produção.
