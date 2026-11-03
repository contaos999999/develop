# Certificação V1-13 — Nova Competência

Data: 03/11/2026
Ambiente: HML
Frontend: `contaos9999/contaos-hml-control`
SHA final certificado: `8b62e506a8351fba9819afb1b4508be449be7228`
Base V1-12: `b22dfd93c61f8be3970b5c01c8e0af2f0e40241e`
Supabase HML: `gklhhhyosgasnyoxlrui`
PROD: intocado

## Resultado

**TESTE C: PASS**

## Evidências

- Testes focados V1-13 + V1-12 + V1-11 + V1-10: **111/111**.
- Suíte completa serial: **544/544**, 23 arquivos, exit 0.
- ESLint dos arquivos alterados: exit 0.
- Security Scan: **0 Critical / 0 High / 0 Medium / 0 Low**; 1 Info preexistente sobre proteção de senha vazada, sem relação com V1-13.
- GitHub Actions `Verify V1-13`, run `41609276908`: **success**.
  - TypeScript `tsc --noEmit`: success.
  - Build: success.
- `src/integrations/supabase/types.ts`: blob certificado `8ea7750b75fd9d76b29c36ce7613392e3ab65e19`.
- Após Teste C read-only, commits automáticos do Lovable que regeneraram somente `types.ts` foram removidos da `main`; a branch `main` foi restaurada exatamente ao SHA auditado `8b62e506...`.

## Comportamentos certificados

- Rota `/contratos/:id/competencias/nova`.
- Gate: UUID válido → sessão → organização → contrato → perfil.
- UUID inválido não chama Auth/Data/RPC da feature.
- Perfil UX lê somente vínculo ativo por `id_usuario`, `id_organizacao` e `ativo=true`.
- Perfis de criação: `administrador`, `gestor_contrato`, `prestacao_contas`.
- `input type=month` com conversão `YYYY-MM` → `YYYY-MM-01` pelo helper certificado.
- Uma única RPC `criar_competencia`; zero INSERT/UPDATE direto no frontend.
- Duplo clique protegido.
- `23505` → duplicidade amigável.
- `P0001` → erro genérico sanitizado, nunca classificado como sem permissão.
- 401/403/42501 → sem permissão.
- Resultado ambíguo reconciliado por leitura exata `(id_contrato, competencia_referencia)` antes de retry manual.
- Sucesso/Cancelar retornam somente à V1-12; V1-14 não foi antecipada.
- V1-12 `Nova competência` é link real; `Abrir competência` permaneceu staged até V1-14.
- BRAND-01, responsividade e acessibilidade preservados.

## Backend

Nenhuma migration, RLS, Edge Function, Auth, Storage ou schema foi alterado pelo V1-13. A tela consome a RPC HML certificada `public.criar_competencia`, que materializa o snapshot no backend e registra auditoria.

## Status

V1-13 / Prompt 34: **CERTIFICADO — TESTE C PASS — ZERO-DRIFT CONFIRMADO**.
