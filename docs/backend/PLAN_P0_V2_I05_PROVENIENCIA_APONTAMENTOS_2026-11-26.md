# PLAN P0 V2 I05 · Proveniência do apontamento de diligência

26/11/2026. Titular autorizou o PLAN próprio e a correção exclusivamente em HML após a identificação da dependência I05. Frontend `b372f481c67156d429cbe9fb738990493a924cc7` com recibos 44 e 45 efetivos. O avanço da 46 e a integração da 76 dependem deste contrato. [Plano mestre #825](https://github.com/contaos999999/contaos-hml-control/pull/825) · [Checkpoint oficial](https://github.com/contaos999999/contaos-hml-control/issues/708#issuecomment-7199768596)

## Causa, evidências e impacto

O job `extrair_diligencia` recebe o parecer oficial e lê seu arquivo. Na gravação de `apontamentos_contratante`, o worker conserva o ciclo, página e trecho. A resposta de processamento informa apenas uma contagem. Dois pareceres do mesmo ciclo com itens iguais geram vínculos de origem indistinguíveis. A função de registro manual guarda somente o ciclo e os metadados informados e continuará disponível conforme seu contrato. [Worker normativo](https://github.com/contaos999999/develop/blob/a1516de1d8949e505d83b5e000eb1cc558b217a7/supabase/functions/queue-worker-ai/index.ts#L55-L56)

No HML, `pareceres_contratante` e `apontamentos_contratante` têm RLS e SELECT autenticado por contrato. Nenhuma relação de item a parecer ou arquivo identifica a origem entre vários pareceres da rodada. A associação atual do parecer com ciclo, competência, contrato, organização, apresentação e arquivo é a fonte para o novo vínculo. A versão 5 do `queue-worker-ai` instalada no HML foi conferida byte a byte contra o GitHub. O SHA-256 de `index.ts` é `634300b7f1a3447dfebea0ff344b28fd26033439301e7cdf46d2c944e33838ab` e o de `job-envelope.mjs` é `9bc449aa5f7f577b380b00fca6903bc67215b1a73c968b377245782100536748`. Projeto HML `gklhhhyosgasnyoxlrui`. Leitura somente de metadados e fonte, sem consumir fila.

A mudança atende I05, atômico 026, rastreabilidade 094, idempotência 092 e RBAC/RLS. Os consumidores do ciclo, revalidação, tarefas e contestação devem continuar lendo suas colunas atuais. Os dados existentes mantêm a referência original registrada. Itens legados sem origem comprovável têm estado explícito e nenhuma atribuição por data, trecho ou ordem. V1, arquivos históricos e o pacote canônico de 25 fontes permanecem ancorados.

## Contrato a integrar

1. Migração aditiva com `id_parecer_origem`, `id_arquivo_origem` e `sha256_arquivo_origem` no item. Uma chave composta confirma o vínculo do parecer com arquivo, ciclo, competência, contrato e organização. Os três campos de proveniência entram juntos. O vínculo conhecido permanece fixo. A migração não preenche por inferência registros existentes.
2. `registrar_extracao_apontamentos` é operação de serviço para o worker. Valida o parecer, o ciclo, o arquivo, o SHA-256 dos bytes processados, o escopo do job e os itens. Grava tudo em uma transação, incluindo o marcador de conclusão do lote e evento de auditoria. Lock do parecer preserva o primeiro resultado confirmado, inclusive vazio, em concorrência e retry. A prova cobre rejeição atômica e manutenção da origem histórica. O papel `service_role` pode executar a operação. O caminho usa `search_path` fixo e ACL explícita.
3. `obter_fonte_apontamento_contratante` é leitura autenticada sob RLS com `SECURITY INVOKER`. Identifica o item da rodada exata e projeta apenas as chaves e metadados autorizados do parecer e arquivo, com hash de origem. Diferencia origem registrada, falta de vínculo histórico e origem indisponível. Identidade sem acesso ao item não recebe seu conteúdo. Nunca expõe caminho, token ou bytes do arquivo.
4. `queue-worker-ai` confere a correspondência entre job e parecer/arquivo antes da extração, calcula hash dos bytes e usa a gravação atômica. Mantém o contrato dos demais tipos de job, autenticação interna, configuração Edge e envelope. A fonte e a contagem emitidas após a gravação vêm do retorno oficial da operação. Não atribuir ao worker a prova operacional de filas após V5.

## Escopo fechado

O PLAN altera somente este documento e `docs/tasks/active-task.json`. A BUILD posterior usa estes caminhos exatos:

- `supabase/migrations/20261126220000_v2_i05_proveniencia_apontamentos.sql`
- `supabase/functions/queue-worker-ai/index.ts`
- `supabase/functions/queue-worker-ai/diligencia-origem.mjs`
- `supabase/tests/v2_i05_proveniencia_fixture.sql`
- `supabase/tests/v2_i05_proveniencia.test.sql`
- `supabase/tests/v2_i05_worker.test.mjs`
- `.github/workflows/p0-v2-i05-proveniencia-code.yml`

O resultado de integração e de paridade HML poderá ser registrado separadamente em `docs/backend/RESULTADO_P0_V2_I05_PROVENIENCIA_APONTAMENTOS_2026-11-26.md`. Sem reescrever migrations aplicadas, alterar Auth, Storage, operação dos outros workers, arquivos da V1, proteções, fonte de 25 documentos, frontend ou `types.ts`.

## Prova e publicação

- RED material no GitHub, com o teste de PostgreSQL demonstrando a ausência do contrato de proveniência. A prova usa banco isolado do runner com esquema mínimo e identidades sintéticas. Os source blobs e workflow do candidato ficam vinculados ao HEAD.
- GREEN com dois pareceres do mesmo ciclo, itens iguais e arquivos distintos. Conferir rejeição de chaves cruzadas e hash divergente, gate sem acesso, leitura somente autenticada, RLS A/B sintética, operação restrita ao worker, página/trecho e legado. Exercitar duas chamadas concorrentes e retry com payload distinto, inclusive lote vazio, efeito único e evento coerente. Verificar teste real do código chamado pelo worker e regressão dos demais envelopes.
- CI Zero-Drift, Context, Architecture e SQL Security. Revisão técnica assistida de Edivan5002 no HEAD exato, merge via PR condicionado à revisão, base viva e CI. Ler árvore e blobs na main antes de publicar no HML.
- Aplicar só a migração aprovada no HML e publicar só o worker do mesmo merge com os módulos identificados e a configuração existente. Verificar catálogo, grants, versão e bytes publicados no HML. Teste das transações e das chamadas do worker usa CODE com dados sintéticos. LIVE e operação real das filas ficam registradas no gate próprio.
- Rollback por PR revisada e nova migration aditiva se necessária, preservando proveniência já gravada. Um retorno operacional do worker exige diagnóstico e prova das consequências para a extração. Enquanto a escrita durável estiver indisponível, I05 permanece pendente. Confirmar readback antes de reabrir 46.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE (OBRIGATÓRIO)

Supabase HML oficial e GitHub são as fontes. Teste C das telas permanece no fluxo frontend. LIVE `NOT_RUN`. PROD `NO-GO`.
