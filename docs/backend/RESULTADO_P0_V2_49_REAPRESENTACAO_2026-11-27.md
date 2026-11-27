# Recibo backend P0 · Regular 49 · Reapresentação

27/11/2026. A correção de idempotência e comprovante está integrada na main do backend e aplicada em HML. O recibo do regular 49 exige a BUILD própria de V2-06.

| Evidência | Identidade |
| --- | --- |
| PLAN | [#242](https://github.com/contaos999999/develop/pull/242), merge `e0c64b0c40a8e542d24f270b59397dcb30d18bff`, revisão 6090800660 |
| RED | [46031504231](https://github.com/contaos999999/develop/actions/runs/46031504231), tentativa 1, job 140616191500, marcador V2_49_RED |
| BUILD | [#243](https://github.com/contaos999999/develop/pull/243), HEAD `2a3b54756578d05f3177ea9edec0ead0a56b2e2c`, revisão assistida [Edivan5002 6090895628](https://github.com/contaos999999/develop/pull/243#pullrequestreview-6090895628) |
| Main | `cb58d238b96a7f36644a1fac4d601df2f7b85be3`, pais `e0c64b0c40a8e542d24f270b59397dcb30d18bff` e `2a3b54756578d05f3177ea9edec0ead0a56b2e2c`, árvore `4a28f07307a68b44653746ec9d7104d204bcdb1a`, sete caminhos conferidos |
| Prova material | [46032059442](https://github.com/contaos999999/develop/actions/runs/46032059442), tentativa 1, job 140618050018, artefato 15214502870, SHA-256 `0e09f39a62f0058e4c9a49b2c300a5240cbb488bc436e652657e9d64073ec286` |
| Checkout | `dbb3fcc31a7cecc29f30dca237a471cb4223a3e5`. Pais, árvore, cinco membros e cinco hashes de fonte conferidos |
| Gates da BUILD | [Zero-Drift](https://github.com/contaos999999/develop/actions/runs/46032059428), [Histórico](https://github.com/contaos999999/develop/actions/runs/46032059429), [Restore](https://github.com/contaos999999/develop/actions/runs/46032059405), [regressão 47](https://github.com/contaos999999/develop/actions/runs/46032059527), [regressão 48](https://github.com/contaos999999/develop/actions/runs/46032059455) e prova material |
| Gates do merge | [Zero-Drift](https://github.com/contaos999999/develop/actions/runs/46032598478), [Restore e backup](https://github.com/contaos999999/develop/actions/runs/46032598424) e [CODE 49](https://github.com/contaos999999/develop/actions/runs/46032598451) |
| Aplicação HML | [46033217866](https://github.com/contaos999999/develop/actions/runs/46033217866), tentativa 1, job 140622013336. CLI 2.81.3, migração `20261127160826`, SHA-256 `ab364a7150f413b29b7f4d7b2ab053d594053d7585c1c64e3547164a1243356d` |

O contrato confirma a repetição pela identidade da intenção, preserva a correspondência dos recibos anteriores e valida organização, contrato e aprovação do comprovante. A prova confirma um pacote por intenção concorrente e a vinculação dos dois pacotes ao recibo e ao evento de auditoria. No primeiro GREEN, uma asserção comparava o identificador do ciclo com o identificador do pacote. O candidato final confere cada identificador na sua origem e preserva a prova de ponta a ponta.

O catálogo HML confirmou 142 migrações e uma única ocorrência da versão do regular 49. Os corpos, assinaturas, proprietário e privilégios das funções pública e privada coincidem com o selo versionado. Corpo privado MD5 `35bb3248e4329c5c9497157731a19ba7`. Corpo público MD5 `b3c925d218a9288f0106ef8f40cd049d`. Provas funcionais em CODE_FIXTURE. LIVE `NOT_RUN`. PROD `NO-GO`.

Próximo gate, PLAN frontend de V2-06.
