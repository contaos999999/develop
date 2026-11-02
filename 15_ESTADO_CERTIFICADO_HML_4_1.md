# ContaOS 4.1 — Estado Certificado do HML Antes do Frontend

Data de referência da certificação: 02/11/2026, Horário de Brasília.

## Decisão

**BACKEND HML CONCLUÍDO E LIBERADO PARA INTEGRAÇÃO DO FRONTEND LOVABLE.**

Isso não é autorização para PROD.

## Evidências principais

- 96/96 requisitos PASS;
- 84 RF + 12 NFR;
- 96 IDs oficiais, únicos, mesma ordem, sem faltantes/extras;
- 75/75 entidades explícitas presentes e com RLS;
- 54 migrations;
- última: `20261102021325_0049_context_hash_material_fields`;
- 117/117 tabelas públicas com RLS;
- 2/2 privadas com RLS;
- 0 `SECURITY DEFINER` público executável por `anon`;
- RLS A/B: PASS;
- portão 99/100 e 100/100: PASS;
- hash/contexto anti-drift: PASS;
- reapresentação: PASS;
- `VALIDADA` somente com parecer favorável: PASS;
- concorrência otimista: PASS;
- idempotência/DLQ: PASS;
- OpenAI IA/OCR: PASS;
- Storage privado/assinados: PASS;
- carga: PASS;
- restore isolado do zero + suíte oficial: PASS;
- último Zero-Drift CI da certificação: PASS;
- dados sintéticos persistidos após testes: zero.

## Advisors

Security Advisor: sem Critical da aplicação; único WARN controlado na certificação era `pg_net` instalado em `public`, extensão de infraestrutura não relocável utilizada pelo runtime/Cron.

Performance Advisor em HML sem carga persistente: avisos de índices ainda não utilizados são informativos e não autorizam apagar índices automaticamente.

## Consequência para a próxima IA

A próxima etapa é **frontend**, não reconstrução do backend. Uma IA de frontend deve presumir que:
- schema/RLS/RPC/Edge existentes são fonte de integração;
- criação de nova tabela exige prova de lacuna + autorização;
- nomes/status/payloads não devem ser “melhorados” sem migração planejada;
- qualquer backend change deve reabrir gates correspondentes.

## Fontes operacionais no repositório

- `docs/CERTIFICACAO_BACKEND_HML_4_1.md`
- `docs/PRODUCTION_READINESS_HML.md`
- `docs/HML_REPRODUCIBILIDADE.md`
- `supabase/README_HML.md`
- `supabase/migrations/`
- `supabase/tests/hml_acceptance.sql`
- `.github/workflows/zero-drift.yml`
- `.github/workflows/restore-isolado.yml`
