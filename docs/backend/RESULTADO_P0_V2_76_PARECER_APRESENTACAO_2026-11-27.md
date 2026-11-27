# Recibo backend P0 · Regular 76 · Parecer do contratante

Em 27/11/2026, a correção do registro de parecer e da consulta de processamento foi integrada na main e aplicada em HML.

| Evidência | Identidade |
| --- | --- |
| PLAN | [#245](https://github.com/contaos999999/develop/pull/245), merge `26d84a3089321afa0d8c9f6bd285527a11b35628`, revisão assistida 6093414139, Zero-Drift 46069086443 |
| RED | [46069339352](https://github.com/contaos999999/develop/actions/runs/46069339352), tentativa 1, job 140742248578, HEAD `f30678066b02edd196652ea9e6ca828a437c8cd5`, marcador V2_76_RED |
| BUILD | [#246](https://github.com/contaos999999/develop/pull/246), HEAD `83defd73275d1d7820d7e1b24ceab55c320cf3ae`, [revisão assistida Edivan5002 6093460263](https://github.com/contaos999999/develop/pull/246#pullrequestreview-6093460263) |
| Main | `f5a54e7b578f1508b059f9718b0c3fa6bb8956ba`, pais `26d84a3089321afa0d8c9f6bd285527a11b35628` e `83defd73275d1d7820d7e1b24ceab55c320cf3ae`, árvore `ff917d98ed8f936281f735530e6e1c3231699f5d`. Sete caminhos conferidos |
| Prova material | [46069678194](https://github.com/contaos999999/develop/actions/runs/46069678194), tentativa 1, job 140743344659, ZIP 15232037701, SHA-256 `7c3b8e15fc96357bc022ae68e4406415fd0bffb2ecfc703bb8b958cff4bab0dc` |
| Checkout da prova | `60c07ef1cddbde289f92ad5a67b395e4aed9b9c4`, pais, árvore, cinco membros e cinco hashes de fonte conferidos |
| CI da BUILD | CODE 76 46069678194, regressão CODE 48 e worker I05 46069678241, Zero-Drift 46069678197, Histórico 46069678240, CODE 49 46069678317, CODE 47 46069678203, Restore 46069678192 |
| CI da main | CODE 76 46070066567, CODE 49 46070066508, CODE 47 46070066531, CODE 48 e worker I05 46070066573, Zero-Drift 46070066506, Histórico 46070066556, Restore 46070066572 |
| Aplicação HML | [46070800452](https://github.com/contaos999999/develop/actions/runs/46070800452), tentativa 1, job 140747008021. CLI 2.81.3, versão `20261127211427`, SHA-256 `33d1bc9258203cc2d59394becfc314979ebe323415313c3ba607b0e2dde7d0a4` |

O registro confirma a competência exata da apresentação, o contrato e a aprovação do arquivo privado. A identidade da intenção é estável sob repetição concorrente. O evento de auditoria vincula parecer, apresentação, competência e ciclo. A consulta de processamento valida o mesmo escopo e retorna somente os metadados autorizados de fila. As provas nativas em PostgreSQL isolado registraram V2_76_GREEN, V2_76_CONCORRENCIA_PASS e V2_76_TRAVA_PASS.

O histórico HML passou de 142 para 143 migrações, com uma ocorrência da versão alvo. Assinaturas, configuração, proprietário, privilégios e corpos das quatro funções coincidem com o selo da BUILD.

| Objeto | MD5 do corpo |
| --- | --- |
| privado.registrar_parecer_contratante | `79d33ea933bb99f73b7cb57c15a1495f` |
| public.registrar_parecer_contratante | `36bcdc97f60eda06561f6d395de09648` |
| privado.obter_processamento_parecer_v2 | `6fef0b8fbd4ff2f9f6dc92e480c0fe5b` |
| public.obter_processamento_parecer_v2 | `013f2bb6882b01bfc6010d977b4ec75a` |

Evidência funcional em CODE_FIXTURE. LIVE `NOT_RUN`. PROD `NO-GO`. Próximo gate, PLAN frontend de V2-07.
