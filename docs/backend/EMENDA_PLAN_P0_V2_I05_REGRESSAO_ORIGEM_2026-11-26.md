# Emenda ao PLAN P0 V2 I05 · Âncora da regressão de implantação

26/11/2026. A BUILD [#232](https://github.com/contaos999999/develop/pull/232) altera o worker de extração no escopo da [PR #231](https://github.com/contaos999999/develop/pull/231). O teste de prontidão da antiga implantação valida uma autorização da versão 5, porém usa como diretório de leitura os arquivos do checkout candidato. Mesmo o caso positivo passou a rejeitar a fonte no novo HEAD. A exigência de rejeitar bytes diferentes está correta. O erro de preparação está em fornecer a fonte nova ao teste positivo do recibo antigo.

O SHA histórico do recibo é `a06b97eb0a2110dd727e66ebe98e91c593e4528b`. Nesta emenda, o caso positivo testa o guard em diretório isolado com os dois blobs históricos desse SHA, o manifesto oficial e o script atual. Os negativos existentes continuam a executar. Acrescentar contraprova material com um arquivo divergente no diretório de evidência. O teste dos envelopes e o adaptador I05 continuam a usar a fonte atual. A leitura histórica não será declarada como paridade HML do candidato de outra versão.

A emenda legitima um caminho a mais no diff da BUILD:

- `supabase/tests/remaining_domains/ai_envelope.test.mjs`

A CI própria do I05 passa a buscar histórico necessário pelo checkout e mantém o teste no `.github/workflows/p0-v2-i05-proveniencia-code.yml`, já previsto. Preservar `ai_deploy_gate.py`, o workflow LIVE anterior, contrato de seleção, hashes originais e o arquivo histórico de recibos. O I05 exige sua prova estática, PostgreSQL isolado, revisão assistida e nova prova de paridade após publicar em HML. A correção desta preparação não precisa de alteração de permissões, configuração de fila, backend de produção ou credenciais.

A emenda contém este documento e `docs/tasks/active-task.json`. Somente após merge e readback da emenda a BUILD pode alterar o teste. LIVE `NOT_RUN`. PROD `NO-GO`.
