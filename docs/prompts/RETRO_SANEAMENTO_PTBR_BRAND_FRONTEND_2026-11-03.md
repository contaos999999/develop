# Saneamento executado — idioma global e identidade visual (Prompts 00–38)

**Data:** 03/11/2026. **Repositório do frontend:** `contaos9999/contaos-hml-control`.
**Origem:** auditoria retrospectiva de 39 prompts e BRAND-01. **Escopo:** somente arquivos frontend e testes; sem Supabase, Auth, banco ou PROD.

## Código alterado e evidência por commit

| Mudança | Commit GitHub | Resultado verificável |
|---|---|---|
| Testes de idioma global em PT-BR (4 cenários) | [7851e42574764ef8759a7b1d3ecac499811b7ce3](https://github.com/contaos9999/contaos-hml-control/commit/7851e42574764ef8759a7b1d3ecac499811b7ce3) | Criados `src/test/rootLocale.test.tsx`, exigindo lang=pt-BR, orientação 404 e erro global, e preservação de router/reset. |
| Teste BRAND-01 expandido para 22 telas | [c75c03c78b18a6d46a9f0ccac15f20d798bfaaad](https://github.com/contaos9999/contaos-hml-control/commit/c75c03c78b18a6d46a9f0ccac15f20d798bfaaad) | Acrescentadas as 9 telas V1-08 a V1-16 e verificação de ausência de paleta/branding paralelo. |
| Root 404/erro integralmente PT-BR | [b1fe1695f40880f410ef458c1d91b9d9a7c5db9c](https://github.com/contaos9999/contaos-hml-control/commit/b1fe1695f40880f410ef458c1d91b9d9a7c5db9c) | `<html lang="pt-BR">`, títulos, botões e explicações em português. Mantidos `router.invalidate`, `reset`, `reportLovableError` e `<Outlet />`. |
| Ajuste de CI para rodar regressão e build antes do gate visual final | [e874b67f79284d3f3c882391ce168b949caf01a0](https://github.com/contaos9999/contaos-hml-control/commit/e874b67f79284d3f3c882391ce168b949caf01a0) | Não torna gate opcional. |
| SVG navy oficial horizontal adicionado | [910ca759003dc28860e6791983f5198b40830acd](https://github.com/contaos9999/contaos-hml-control/commit/910ca759003dc28860e6791983f5198b40830acd) | Asset original do pacote mestre v1.0; SHA-256 exigido `bd924993afbb620647d1053614688efea1f157523cbf41b3c36a368b0d0c976c`. |
| SVG navy oficial símbolo adicionado | [c1958cd904418e80719444b35918c3ad05b11c64](https://github.com/contaos9999/contaos-hml-control/commit/c1958cd904418e80719444b35918c3ad05b11c64) | Asset original do pacote mestre v1.0; SHA-256 exigido `5773eb79ade28369b1efd457bf3b69b70f79a9ede87a05aa5e622f44d56e3252`. |
| Seleção light/dark no componente `ContaOSMarca` | [bf332dc70e165eed57e2c7bad4a4e447e9d1f11c](https://github.com/contaos9999/contaos-hml-control/commit/bf332dc70e165eed57e2c7bad4a4e447e9d1f11c) | O único componente central usa variantes white/navy conforme `.dark` sem nova paleta ou mudança nas 22 páginas. |
| Testes de SHA-256 das variantes e renderização de classes `dark:` | [9881f6f8d50ffdbedf411b97d2de2c90739a0e26](https://github.com/contaos9999/contaos-hml-control/commit/9881f6f8d50ffdbedf411b97d2de2c90739a0e26) | Testes estáticos/DOM; NÃO equivalem sozinhos a medição real de contraste e screenshot. |

## Gates e condições para certificação

1. Testes `rootLocale` e `brand` devem passar após o delta, além da suíte completa, TS e build em CI.
2. O workflow `contaos-frontend-zero-drift.yml` verifica 22/22 telas, os ativos oficiais por SHA, ausência de cores hardcoded, root PT-BR e blob `types.ts` certificado `8ea7750b75fd9d76b29c36ce7613392e3ab65e19`.
3. É indispensável **Teste C independente read-only** sobre SHA imutável, com prova renderizada 1440/1280/768/390 px, claro/escuro, 404/erro, login e telas autenticadas quando viável; registros ausentes ficam NÃO VERIFICADO.
4. Sem aprovação dos gates, o frontend continua NÃO CERTIFICADO 100%.
5. PROD, backend Supabase, Auth, Storage, RLS, estilos globais e 22 componentes de negócio não foram alterados.

## Próximas etapas da auditoria retrospectiva

Completar evidências por linha do rastreador `PLANO_SANEAMENTO_39_PROMPTS_2026-11-03.json`, validar a integração do Prompt 38, SYS-03 E2E real e impossibilidade atual de ruleset obrigatório em repositório privado no plano GitHub. Não fechar 39/39 até obter prova individual, evitando atribuir resultado ao que não foi testado.
