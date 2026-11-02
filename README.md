# ContaOS — HML / Homologação

> **ATENÇÃO PARA IA E DESENVOLVEDORES:** antes de qualquer alteração, leia `00_AI_LEIA_ANTES_DE_ALTERAR.md` e todos os documentos canônicos `00` a `18`, incluindo `08A`–`08D` da raiz. O `Context Gate` do CI bloqueia mudança de implementação sem declaração de leitura do contexto vigente.

Este repositório é o ambiente oficial de **desenvolvimento e homologação (HML)** do ContaOS.

## Ambientes

- `contaos9999/develop` = HML/desenvolvimento/homologação.
- `contaos9999/prod` = produção; permanece intocado durante desenvolvimento/homologação.
- Supabase HML: `gklhhhyosgasnyoxlrui`.
- Frontend HML: próxima etapa, Lovable conectado ao Supabase HML certificado.

## Estado certificado do backend

- 96/96 requisitos PASS.
- 54 migrations.
- Última: `20261102021325_0049_context_hash_material_fields`.
- 117/117 tabelas públicas com RLS.
- 2/2 tabelas privadas com RLS.
- Storage privado.
- OpenAI IA/OCR homologada no backend.
- filas/workers/Cron homologados.
- restore isolado + suíte oficial PASS.
- Zero-Drift/Architecture Guard/scan de secrets PASS.

Detalhes: `15_ESTADO_CERTIFICADO_HML_4_1.md` e `docs/CERTIFICACAO_BACKEND_HML_4_1.md`.

## Contexto obrigatório

- entrada: `00_AI_LEIA_ANTES_DE_ALTERAR.md`;
- manifesto/hashes: `AI_CONTEXT_MANIFEST.md`;
- regras gerais para agentes: `AGENTS.md`;
- escopo atual: `docs/tasks/active-task.json`.

Fingerprint inicial deste contexto canônico: `01d17aa3f71b8b4e4b67395f3d70fdcb158bc6d7b31dca1126aea49bc86ad4df`.

## Versionamento

Migration aplicada não é alterada. Correção entra como nova migration. Segredos permanecem no Supabase Secrets/Vault.

## Promoção

HML → testes/QA → frontend Lovable HML → homologação completa → promoção controlada para PROD. Dados sintéticos, secrets e credenciais do HML não são copiados para produção.
