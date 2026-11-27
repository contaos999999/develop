# Recibo backend P0 · Regular 76 · Prazo externo

27/11/2026. A configuração de diligência passou a definir o vencimento de novos ciclos em HML. O registro preserva a data informada, o prazo de ciclos existentes e o resultado de uma intenção já processada. Configuração indefinida mantém confirmação humana pendente. O [recibo #247](https://github.com/contaos999999/develop/pull/247) preserva a prova do vínculo do parecer, do arquivo aprovado e da extração.

| Evidência | Identidade |
| --- | --- |
| PLAN | [#248](https://github.com/contaos999999/develop/pull/248), merge `a766d89bad84c9dccf611a1687af342922e0c490`, revisão 6093565758, Zero-Drift 46071816438 |
| RED | [46071978680](https://github.com/contaos999999/develop/actions/runs/46071978680), tentativa 1, job 140750837770, HEAD `0253308d416b8a4c52143ac6806db2dcbef47e4d`, marcador V2_76_PRAZO_RED |
| BUILD | [#249](https://github.com/contaos999999/develop/pull/249), HEAD `20f7dcc47018f64e4ca5c6a43a59dfcaf8582c9d`, [revisão assistida Edivan5002 6093648947](https://github.com/contaos999999/develop/pull/249#pullrequestreview-6093648947) |
| Main | `c900bbcbca4a0826b83a3fd0c4bdb4120d80778e`. Pais `a766d89bad84c9dccf611a1687af342922e0c490` e `20f7dcc47018f64e4ca5c6a43a59dfcaf8582c9d`, árvore `c9aea44df44f31a5e14ff6893581464d9c50e169`. Sete caminhos conferidos, blob SQL `58bf1829d5831b43f21f349a3b5baeb034f88ac7` |
| Prova material | [46072257366](https://github.com/contaos999999/develop/actions/runs/46072257366), tentativa 1, job 140751727444, ZIP 15233830495, SHA-256 `f3dba4ed116ccd71e07f052df043a46032d38be14ac1bd919035e9300aa38e34` |
| Checkout | `5f138db4b4661d8f59d13e29a32923004229674c`. Pais, árvore, cinco membros e nove hashes de fonte conferidos |
| CI da BUILD | CODE 76 46072257366, CODE 49 46072257291, CODE 48 e I05 46072257233, CODE 47 46072257205, Zero-Drift 46072257219, Histórico 46072257225, Restore 46072257380 |
| CI da main | CODE 76 46072796183, CODE 49 46072796126, CODE 48 e I05 46072796152, CODE 47 46072796148, Zero-Drift 46072796099, Histórico 46072796153, Restore 46072796150 |
| Aplicação HML | [46073226704](https://github.com/contaos999999/develop/actions/runs/46073226704), tentativa 1, job 140754855876, Supabase CLI 2.81.3, versão `20261127213828`, SHA-256 `2909774d5be1e0fbd55883291c89ca877a4ed6312577d2346dfe822ef8238284` |

A prova passou com regra de cinco dias, regra própria de outro contrato, data explícita, regra sem calendário reconhecido, configuração inválida, replay, prazo da rodada existente e parecer favorável. Os resultados V2_76_GREEN, V2_76_CONCORRENCIA_PASS, V2_76_TRAVA_PASS e V2_76_PRAZO_GREEN constam no ZIP autenticado. A auditoria registra o prazo solicitado, o aplicado e sua origem.

O histórico HML confirmou 144 versões, com ocorrência única da migração. O corpo privado do registro tem MD5 `1cb26ba5b7b5950a0e8f53164df33d77`, e as outras três funções conferem com o selo anterior. Proprietários, privilégios e assinaturas conferidos. O catálogo de segurança retornou um INFO e dois WARN, sem Critical.

Próximo gate, finalizar o PLAN V2-07 com a âncora deste recibo. CODE_FIXTURE. LIVE `NOT_RUN`. PROD `NO-GO`.
