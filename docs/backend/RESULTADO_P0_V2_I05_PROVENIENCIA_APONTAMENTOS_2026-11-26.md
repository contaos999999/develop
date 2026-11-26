# Resultado P0 V2 I05 · Proveniência de apontamentos

Em 26/11/2026, o backend integrou a ligação durável entre apontamento, parecer, arquivo e rodada. Cada item novo produzido pela extração conserva a identidade e o SHA-256 do arquivo processado. A leitura autenticada distingue origem comprovada, origem histórica sem vínculo e origem indisponível. A fonte de referência da V1 continua identificada pelo commit `a1516de1d8949e505d83b5e000eb1cc558b217a7`.

## Integração no GitHub

| Registro | Evidência |
| --- | --- |
| PLAN e emendas | [#231](https://github.com/contaos999999/develop/pull/231), [#233](https://github.com/contaos999999/develop/pull/233), [#234](https://github.com/contaos999999/develop/pull/234) |
| BUILD | [#232](https://github.com/contaos999999/develop/pull/232), HEAD `59804af968d1e394581f20a5960d7d4bcb88cd59`, árvore `2b88bca85dcefd330b579cfaa96f17f4e3584fe8` |
| RED material | [45902473238](https://github.com/contaos999999/develop/actions/runs/45902473238), ausência do contrato em PostgreSQL isolado |
| GREEN material | [45904764035](https://github.com/contaos999999/develop/actions/runs/45904764035), proveniência, escopo, concorrência, idempotência e regressão do worker |
| Demais verificações | [Verificar histórico HML](https://github.com/contaos999999/develop/actions/runs/45904764020), [ContaOS Zero-Drift](https://github.com/contaos999999/develop/actions/runs/45904763959), [ContaOS Domínios Restantes HML](https://github.com/contaos999999/develop/actions/runs/45904763965), [ContaOS Restore Isolado](https://github.com/contaos999999/develop/actions/runs/45904763956) |
| Revisão assistida | [Edivan5002 · 6081131313](https://github.com/contaos999999/develop/pull/232#pullrequestreview-6081131313), APPROVED do HEAD exato |
| Leitura na main | [`31f3ef9b95c8dc4e9eadbc786a2125e3c02a266d`](https://github.com/contaos999999/develop/commit/31f3ef9b95c8dc4e9eadbc786a2125e3c02a266d), pais `2599f92404a137ee5e44e720787dcb82ef778971` e `59804af968d1e394581f20a5960d7d4bcb88cd59`. Árvore e 10 blobs do HEAD revisado confirmados. |

No commit integrado, os jobs `guard`, `reconstruir-banco-do-zero` e `prova-backup-dados-sinteticos-duas-instancias` concluíram com sucesso. O restore confrontou o catálogo histórico com as cinco colunas e três funções aditivas esperadas, incluindo assinaturas, corpos, proprietários e permissões. [Zero-Drift na main](https://github.com/contaos999999/develop/actions/runs/45905126898) · [Restore na main](https://github.com/contaos999999/develop/actions/runs/45905126820)

## Paridade do HML

- Projeto `gklhhhyosgasnyoxlrui`. Migração `20261126221545`, SHA-256 `28fd2190e3f61555d461597658b0d7b72c858848766fede460d4ecfb10571733`. O workflow fixou o commit integrado de origem, confirmou uma única versão pendente e zero órfãs, aplicou a migração com a CLI 2.81.3 e verificou o histórico. A leitura pós-deploy confirmou as 139 versões. [Run 45905601026 · tentativa 1 · job 140201459166](https://github.com/contaos999999/develop/actions/runs/45905601026)
- Conferência de catálogo somente leitura com as cinco colunas e três funções do restore. `obter_fonte_apontamento_contratante(uuid,uuid)` é `SECURITY INVOKER`, executável pelo papel autenticado sob RLS. `registrar_extracao_apontamentos(uuid,uuid,text,jsonb)` é restrita ao serviço. Os gatilhos de preservação da origem e agendamento da extração estão ativos.
- `queue-worker-ai` v6, ACTIVE, configuração `verify_jwt=false` preexistente e autenticação interna preservada. Bundle `033a8d596665296f4503e6b1ae4c35c873b43ad7d69c41e038005ef71f288ac5`. Os três arquivos retornados pelo HML coincidem byte a byte com os arquivos do merge.

| Arquivo publicado | SHA-256 |
| --- | --- |
| `index.ts` | `91a5276e5e6cd47a31f8dd3c511d017fb2ef695056aa671e52ed6d43626025da` |
| `job-envelope.mjs` | `9bc449aa5f7f577b380b00fca6903bc67215b1a73c968b377245782100536748` |
| `diligencia-origem.mjs` | `18af192e1200dabaf919a1ed9387d2ca1aeade109956bbb71c8d22c1a0cd1ad3` |

O alcance dos testes funcionais é CODE com dados sintéticos. A homologação confirmou instalação e paridade de fonte e catálogo. LIVE `NOT_RUN`. PROD `NO-GO`. A V2-03 e a V2-07 têm critérios funcionais próprios e devem consumir a origem registrada nas suas entregas.
