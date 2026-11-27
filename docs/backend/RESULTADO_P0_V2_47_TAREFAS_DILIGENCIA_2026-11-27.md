# Recibo backend P0 · Regular 47 · Vínculos e revalidação de tarefas

27/11/2026. O backend do regular 47 está integrado e conferido no HML. Este recibo comprova o contrato de que depende a interface V2-04. O regular passa a contar na V2 após a integração da BUILD e do recibo próprio do frontend.

## GitHub e prova CODE

| Evidência | Identidade |
| --- | --- |
| PLAN P0 | [#236](https://github.com/contaos999999/develop/pull/236), merge `f364c01cfa5101a1540f53ef02e2ad08cb3a3307` |
| RED | [45945138055](https://github.com/contaos999999/develop/actions/runs/45945138055), job 140327999963, contra a ausência da operação autenticada |
| HEAD e revisão | `fc8068ca2311ea7f41501be481e263324b646399`, [Edivan5002 · 6086402316](https://github.com/contaos999999/develop/pull/237#pullrequestreview-6086402316) |
| BUILD e leitura da main | [#237](https://github.com/contaos999999/develop/pull/237), merge `88d0489d92474d4c0f94fcb342e28fb1b81180f5`, pais `f364c01cfa5101a1540f53ef02e2ad08cb3a3307` e `fc8068ca2311ea7f41501be481e263324b646399`, árvore `44e58199208e46b5a899a97efa8d1c68477337f7`, 11 blobs exatos |
| Prova transacional e de concorrência | [45947535696](https://github.com/contaos999999/develop/actions/runs/45947535696), tentativa 1, job 140335570280, artefato 15175635937, SHA-256 `34ccc00049ccbe6331e87839aba6625d9cdba3c5ee02fa12eca66d3e88ba3c56` |
| Checkout e ZIP | `791087073bbaca23de6232a5af4d19cb2e9f7720` com a árvore da BUILD e ambos os pais. Sete membros e seis hashes de fonte conferidos. PostgreSQL, duas transações concorrentes e 13 casos Node sem falhas ou skips |
| Gates do HEAD revisado | [Zero-Drift 45947535647](https://github.com/contaos999999/develop/actions/runs/45947535647), [histórico 45947535680](https://github.com/contaos999999/develop/actions/runs/45947535680), [Restore 45947535617](https://github.com/contaos999999/develop/actions/runs/45947535617), [I05 45947535717](https://github.com/contaos999999/develop/actions/runs/45947535717) |
| Gates do merge | [Zero-Drift 45978243695](https://github.com/contaos999999/develop/actions/runs/45978243695), [Restore 45978243685](https://github.com/contaos999999/develop/actions/runs/45978243685). Reconstrução e restauração entre duas instâncias concluídas |

O Zero-Drift encontrou RPC com nome indireto no worker do primeiro candidato. A restauração encontrou diferença entre a representação qualificada do tipo composto e o inventário histórico. Os nomes foram fixados na chamada e a representação da comparação histórica foi reconciliada com preservação do selo nativo. O candidato final inclui negação do painel ao leitor sem atribuição e prova da preferência de notificação do papel.

## HML

- O [workflow 45978865282](https://github.com/contaos999999/develop/actions/runs/45978865282), tentativa 1, job 140437390826, usou a CLI 2.81.3. Aplicou somente a migração `20261127050308` do merge, SHA-256 `7235e308597091c3a27257caed9c91ac45dea1cc886121e59af3bba87f980fae`. Histórico de 139 para 140 versões com zero órfãs.
- Leitura de catálogo confirmou coluna, chave, índice, seis combinações de privilégio e 20 funções com assinatura, corpo, proprietário e ACL esperados. As operações de leitura e escrita usam o escopo da rodada, do contrato, da competência e do item. As operações do worker permanecem de serviço. A prova valida decisão humana fundamentada e revalidação da versão corrente.
- Worker `queue-worker-ai` v7 ACTIVE, SHA-256 do bundle `28129243fcadfa11f970d1232bcd1d9d5b7d9c28cd66cc4e92c47f2448ad71d1`. Os quatro arquivos coletados do HML coincidem byte a byte com a main. A configuração JWT preexistente e a verificação do token interno foram preservadas.

| Arquivo publicado | SHA-256 |
| --- | --- |
| `diligencia-origem.mjs` | `18af192e1200dabaf919a1ed9387d2ca1aeade109956bbb71c8d22c1a0cd1ad3` |
| `diligencia-revalidacao.mjs` | `1ebab73a1941e962f28dc6768bb4e0bcd16687603123c40f7edd160496d8b9af` |
| `index.ts` | `663a98127feba7dd6a006d7d4120a462d88ce1fb8ffee56ba17b29151282c228` |
| `job-envelope.mjs` | `9bc449aa5f7f577b380b00fca6903bc67215b1a73c968b377245782100536748` |

Fila AI sem execução pendente antes e após a publicação. A prova funcional usa CODE_FIXTURE com identidades, documentos e transporte sintéticos. LIVE `NOT_RUN`. PROD `NO-GO`.

Próxima tarefa elegível, PLAN frontend do regular 47. [Acompanhamento #708](https://github.com/contaos999999/contaos-hml-control/issues/708#issuecomment-7215362611)
