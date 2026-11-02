# ContaOS HML - Supabase

Este diretório é a fonte versionada do backend de homologação do ContaOS 4.1.

## Fonte de verdade

- Supabase HML: `gklhhhyosgasnyoxlrui`;
- GitHub HML: `contaos9999/develop`;
- migrations atuais: **54**;
- última migration: `20261102021325_0049_context_hash_material_fields`;
- checkpoint histórico: `supabase/applied-history/contaos-hml-full-history.sql`;
- materializador: `supabase/scripts/materialize-migrations.mjs`;
- suíte oficial: `supabase/tests/hml_acceptance.sql`;
- restore isolado: `.github/workflows/restore-isolado.yml`.

## Regras de promoção HML -> PROD

1. Nunca copiar dados de teste do HML para PROD.
2. Promover apenas migrations, Edge Functions e configurações versionáveis homologadas.
3. Segredos permanecem no Supabase Secrets/Vault e nunca no GitHub.
4. O frontend usa somente chave pública/publishable e RLS.
5. `service_role` e `OPENAI_API_KEY` são exclusivos do backend.
6. Mensagens de usuário são em português do Brasil.
7. Datas e horários usam `America/Sao_Paulo` e apresentação brasileira.
8. Antes de promover, executar Advisors, isolamento multiempresa, restore e suíte de aceitação.
9. O repositório de produção não recebe alterações antes da homologação formal.

## Status críticos

- `PODE APRESENTAR AO CONTRATANTE`
- `PODE REAPRESENTAR AO CONTRATANTE`

Não utilizar `Apta para apresentação` ou substitutos.

A IA produz análises e sugestões. Aprovações e liberações críticas permanecem sob decisão humana.

## Anti-drift de contexto

As migrations `0047–0049` fazem o backend invalidar liberações quando documentos ou dados materiais mudam. A análise guarda snapshot/hash; aprovação e protocolo revalidam esse hash. Contexto obsoleto exige nova análise completa/reanálise.

## Restore certificado

O workflow `ContaOS Restore Isolado` reconstrói um Supabase/PostgreSQL limpo a partir das migrations e executa a suíte oficial de aceitação nesse banco. O run certificado concluiu todos os passos com sucesso.

## Estado de homologação

Backend HML: **96/96 requisitos PASS**, RLS 117/117 public + 2/2 privado, OpenAI IA/OCR PASS, filas/DLQ/Cron PASS, Storage privado PASS, carga PASS, Zero-Drift PASS e restore limpo PASS.

A próxima etapa é o frontend Lovable conectado exclusivamente a este HML, respeitando RPC/RLS e sem criar backend paralelo.
