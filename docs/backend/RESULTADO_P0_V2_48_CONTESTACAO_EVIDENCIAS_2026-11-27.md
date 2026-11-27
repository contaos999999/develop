# Recibo backend P0 · Regular 48 · Contestação e mapa de evidências

27/11/2026. Backend integrado na main e conferido em HML. Este recibo comprova o contrato para V2-05. O regular exige a integração e o recibo próprios do frontend.

## GitHub e prova CODE

| Evidência | Identidade |
| --- | --- |
| PLAN P0 | [#239](https://github.com/contaos999999/develop/pull/239), merge `9d38e7ac8b39dd63d8a9ab4d8f29c81dba584545` |
| RED | [45986687082](https://github.com/contaos999999/develop/actions/runs/45986687082), tentativa 1, job 140464043804, marcador V2_48_RED |
| BUILD e revisão | [#240](https://github.com/contaos999999/develop/pull/240), HEAD `af62a6d03d9525900eac695eeed1ff7252fab217`, [Edivan5002 · 6090114288](https://github.com/contaos999999/develop/pull/240#pullrequestreview-6090114288) |
| Merge e leitura na main | `80dc2d088a7010688f5172a6d9e43fb7e271d571`, pais `9d38e7ac8b39dd63d8a9ab4d8f29c81dba584545` e `af62a6d03d9525900eac695eeed1ff7252fab217`, árvore `f5e6aa9dd20a39aa6ef50bf2a92c3b3bcfe14879`, 11 caminhos do PLAN com blobs idênticos ao HEAD revisado |
| Prova PostgreSQL e worker | [45988110599](https://github.com/contaos999999/develop/actions/runs/45988110599), tentativa 1, job 140468784911, artefato 15191944655, SHA-256 `09d8edacaf1b3987d5e11661339107a1b66f0f9b4c1a48b9b60293973bae51e6` |
| Checkout e ZIP | `4862ced1fd2874befb275859a00182430e69886f`, pais e árvore conferidos. ZIP com sete hashes de fonte e provas de escopo, transação e concorrência. 18 casos Node sem falhas ou skips |
| Gates do HEAD | [Zero-Drift](https://github.com/contaos999999/develop/actions/runs/45988110549), [histórico](https://github.com/contaos999999/develop/actions/runs/45988110497), [Restore](https://github.com/contaos999999/develop/actions/runs/45988110516), [I05](https://github.com/contaos999999/develop/actions/runs/45988110438), [47](https://github.com/contaos999999/develop/actions/runs/45988110507) e prova CODE acima |
| Gates do merge | [Zero-Drift](https://github.com/contaos999999/develop/actions/runs/46022020893), [Restore](https://github.com/contaos999999/develop/actions/runs/46022020781) e [CODE 48](https://github.com/contaos999999/develop/actions/runs/46022020835). Jobs guard, reconstrução do zero e backup entre duas instâncias com sucesso |

A aprovação legada conferia papel sem verificar acesso ao contrato exato. O mapa aceitava referências fornecidas pelo cliente. O contrato aplicado valida ator, contrato, rodada, competência, item e versão documental. O PostgreSQL vincula o mapa ao hash da evidência e valida a página. A decisão é humana e fundamentada. A operação do worker persiste minuta vinculada à versão e mantém a revisão humana.

## HML

- [Workflow 46022686228](https://github.com/contaos999999/develop/actions/runs/46022686228), tentativa 1, job 140586063941. CLI 2.81.3 aplicou somente `20261127105223` do merge, SHA-256 `27c5acd2e614d8cccf60f9fc55c895c0827121215822db7b356f87589274bc16`. O histórico passou de 140 para 141 versões. O workflow confirmou a paridade integral.
- O catálogo HML coincidiu com os selos versionados em 20 funções, incluindo assinaturas, corpos, permissões e proprietário, e seis combinações de papel e tabela com RLS e privilégios.
- Worker `queue-worker-ai` v8 ACTIVE. Bundle SHA-256 `40158adf5b73684dc34a6d5342740b32f92509f0e9cc10086f26680e5aa7b972`. A leitura após publicação confirmou os cinco arquivos byte a byte, a configuração preexistente de JWT e o código de validação do token interno.

| Arquivo publicado | SHA-256 |
| --- | --- |
| `contestacao-evidencias.mjs` | `b2dd3df8718ea6bfed6f58037d57190682e422fa0a968ffab9c0094c98ccbf99` |
| `diligencia-origem.mjs` | `18af192e1200dabaf919a1ed9387d2ca1aeade109956bbb71c8d22c1a0cd1ad3` |
| `diligencia-revalidacao.mjs` | `1ebab73a1941e962f28dc6768bb4e0bcd16687603123c40f7edd160496d8b9af` |
| `index.ts` | `8253e03c9425ae300b192a39130b3baaf73553f3a73c0b75486e2c5c48c97fad` |
| `job-envelope.mjs` | `9bc449aa5f7f577b380b00fca6903bc67215b1a73c968b377245782100536748` |

Fila AI com zero execuções pendentes antes e depois. A prova funcional usa CODE_FIXTURE. LIVE `NOT_RUN`. PROD `NO-GO`.

Próxima tarefa elegível, PLAN frontend do regular 48. [Issue #708](https://github.com/contaos999999/contaos-hml-control/issues/708).
