# ContaOS — HML / Homologação

Este repositório é o ambiente oficial de **desenvolvimento e homologação (HML)** do ContaOS.

## Regra de ambientes

- `contaos9999/develop` = desenvolvimento e homologação.
- `contaos9999/prod` = produção. Não recebe alterações durante o desenvolvimento e homologação.
- Supabase HML: projeto `gklhhhyosgasnyoxlrui`.
- Frontend HML: será conectado ao Lovable após o fechamento do backend.

## Fonte de verdade

1. PRD, premissas e pacote mestre ContaOS Arquitetura 4.1.
2. Histórico de migrations do Supabase HML.
3. Código das Edge Functions em `supabase/functions/`.
4. Banco Supabase HML validado.
5. Frontend Lovable homologado, quando conectado.

## Estado atual do backend HML

- 46 migrations registradas no Supabase.
- Última migration: `20261101233244_0042_hardening_grants_anon`.
- 117 tabelas públicas com RLS habilitada.
- Storage `contaos-documentos` privado.
- Filas: `documents`, `ocr`, `ai`, `embeddings`, `finance_imports`, `reports`, `integrations` e `webhooks`.
- Workers e Crons ativos.
- OpenAI configurada no backend para IA e OCR, sem segredo versionado.
- Padrão de interface e mensagens: português do Brasil.
- Datas e horários: `America/Sao_Paulo`, formato brasileiro.

## Versionamento

As migrations iniciais permanecem individualizadas em `supabase/migrations/`.

O histórico posterior, extraído diretamente do Supabase, está em `supabase/applied-history/`. O arquivo `contaos-hml-full-history.sql` contém o snapshot até a migration `0038`; as migrations posteriores permanecem como deltas cronológicos nessa mesma pasta.

Não alterar migrations já aplicadas. Toda correção deve ser uma nova migration com timestamp único.

## Fluxo de promoção

`develop` → Supabase HML → testes/QA → frontend Lovable HML → homologação → promoção controlada para `prod`.

Nunca copiar dados fictícios, segredos ou credenciais do HML para produção. `OPENAI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, tokens internos e segredos de webhooks devem permanecer exclusivamente nos Secrets/Vault do ambiente correspondente.
