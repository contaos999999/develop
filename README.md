# ContaOS — HML / Homologação

Este repositório é o ambiente oficial de **desenvolvimento e homologação (HML)** do ContaOS.

## Regra de ambientes

- `contaos9999/develop` = desenvolvimento e homologação.
- `contaos9999/prod` = produção. Não recebe alterações diretamente durante o desenvolvimento.
- Supabase HML atual: projeto `gklhhhyosgasnyoxlrui`.
- Frontend HML: Lovable conectado ao ambiente de homologação.

## Fonte de verdade

1. PRD e pacote mestre ContaOS Arquitetura 4.1.
2. Migrations versionadas em `supabase/migrations/`.
3. Banco Supabase HML efetivamente validado.
4. Código do frontend e Edge Functions homologados.

## Fluxo

`develop` → Supabase HML → testes/QA → homologação → promoção controlada para `prod`.

Nunca copiar dados fictícios ou credenciais do HML para produção. Nenhuma secret key deve ser versionada neste repositório.

## Migrations HML já aplicadas

- `20261101205846_0001_extensoes_schemas.sql`
- `20261101205936_0002_identidade_organizacoes.sql`
- `20261101210017_0003_contratantes_contratos_core.sql`
- `20261101210030_0003b_acesso_contratos_rls.sql`
- `20261101210053_0004_fontes_orcamento_listas.sql`
- `20261101210110_0005_storage_documentos.sql`

As próximas migrations devem ser criadas primeiro aqui e aplicadas somente no Supabase HML até a homologação.
