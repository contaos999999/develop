# PLAN P0 47 · Vínculos e validação das tarefas de diligência

27/11/2026. Complemento de backend HML para o regular 47, atômicos 033–036 e relações I06, I07, I08, I12, C17 e C31. Autorização específica do titular registrada na retomada da V2. O recibo 46 está integrado e autenticado no frontend `74bb3273a5bbad2cb58903eb9dd6bc2972b80333` após a PR #837, com o P0 apontando o regular 47. [Plano executivo #825](https://github.com/contaos999999/contaos-hml-control/pull/825) · [Checkpoint oficial](https://github.com/contaos999999/contaos-hml-control/issues/708#issuecomment-7210481228)

## Causa e impacto

A criação em `tarefas_diligencia` tem política INSERT por contrato e perfil. As chaves simples da tarefa identificam o ciclo, o apontamento e a versão, sem exigir que esses vínculos pertençam juntos à competência da tarefa. Nenhuma operação pública atual valida a criação e as dependências como uma transação oficial. As RPCs de alteração, conclusão e revisão existem. A conclusão confirma o contrato do documento e o estado das dependências. A revisão pode aceitar uma tarefa concluída e pendente de validação antes do resultado do motor. O worker atual grava uma análise pelo apontamento e pela versão do documento, sem recibo persistente da execução da tarefa. Com a mesma versão em tarefas distintas, esses registros não identificam a análise da tarefa com precisão.

Baselines `cbf247724ecede59fdcba0d18d7b0e37c76f247f` no backend, I05 implantado e paridade HML de 139 versões. As consultas de catálogo confirmaram os grants, as políticas, as referências e as assinaturas implantadas de `atualizar_tarefa_diligencia`, `concluir_tarefa_diligencia` e `revisar_solucao_tarefa_diligencia`. O catálogo e fontes da V1 permanecem historicamente ancorados. A fonte de leitura e o contrato de revisão obtidos pela V2-03 continuam reconhecíveis no frontend.

## Contrato

1. A escrita de tarefa passa por operação autenticada, com autorização por sessão, contrato e papel. Somente o servidor resolve competência, organização e rodada do item. A referência a plano de ação e as dependências devem pertencer à mesma rodada. Validar responsável vinculado ao contrato, tipos e prioridade, versão esperada e chave idempotente. Preservar as assinaturas públicas existentes e conduzir seus comandos ao mesmo controle. Retirar a escrita direta obsoleta no escopo de tarefas. Preservar leituras RLS e histórico.
2. A operação de conclusão confere a versão documental apresentada na competência e sua integridade, verifica dependências aprovadas, gera recibo idempotente e enfileira a revalidação oficial por tarefa e submissão. O item fica em tratamento até a revisão. Proibir resultado de trabalho antigo, outra tarefa ou outro documento. Usar a infraestrutura de fila existente e provar o resultado no transporte simulado.
3. O worker confirma a submissão no backend antes de ler o documento. Grava uma análise autoritativa do processamento com IDs de tarefa, execução, apontamento e versão, em transação e por operação de serviço. Reexecução converge para o mesmo registro. Uma análise insuficiente ou indisponível permanece impeditiva. Mesmo com resultado suficiente, a decisão permanece humana. Permitir nova submissão após falha ou devolução pelo fluxo oficial.
4. A revisão autenticada exige revalidação da submissão vigente, fundamento e vinculação exata ao item e à versão. Aprovação válida de todas as tarefas aplicáveis pode atualizar o item para resolvido conforme o estado oficial. Locks por rodada/tarefa serializam a nova prova com modificação, revisão e liberação do portão. Registrar ator, instante, IDs, antes/depois e correlação. Consumir a preferência oficial de notificação para atribuição ou alteração material do prazo. Nenhuma notificação efetiva durante a prova CODE.
5. Fornecer leitura de tarefas, atividade e ações oficiais para o painel em RLS, com paginação e escopo da rodada. Reusar o catálogo de preferências existente. A BUILD do frontend tem PLAN próprio para interface, estados, integração e Teste C. O trabalho preserva V1, I05 e funções alheias a tarefas. Itens/decisões legados permanecem consultáveis; o estado do novo processo requer prova rastreada e não recebe atribuição retrospectiva por suposição.

## Caminhos exatos

O PLAN documental altera este arquivo e `docs/tasks/active-task.json`. O próximo BUILD poderá alterar:

- `supabase/migrations/20261127050308_p0_v2_47_tarefa_vinculo_revalidacao.sql`
- `supabase/functions/queue-worker-ai/index.ts`
- `supabase/functions/queue-worker-ai/diligencia-revalidacao.mjs`
- `supabase/tests/v2_47_tarefas_fixture.sql`
- `supabase/tests/v2_47_tarefas.test.sql`
- `supabase/tests/v2_47_tarefas_concorrencia.py`
- `supabase/tests/v2_47_worker.test.mjs`
- `supabase/tests/history_catalog_compare.py`
- `supabase/tests/v2_47_catalog_pins.json`
- `supabase/tests/v2_47_catalog.test.mjs`
- `.github/workflows/p0-v2-47-tarefas-code.yml`

Recibo documental separado em `docs/backend/RESULTADO_P0_V2_47_TAREFAS_DILIGENCIA_2026-11-27.md`, depois do readback HML.

## Provas e publicação

- RED no PostgreSQL isolado com catálogos e identidades sintéticas, reproduzindo a ausência da escrita autenticada completa e da amarração da revalidação. GREEN com plano, item, dependência e versão corretos. Rejeições para escopo divergente, usuário sem atribuição, ação inválida, erro da análise, falta de fundamento, revisão antiga, dependência pendente/circular, reabertura e duplicidade. Verificar concorrência, efeito único e eventos da mesma operação.
- Validar permissões públicas e de serviço, restauração integral, paridade e delta exato do catálogo com corpos e ACLs pinados. O contrato registra estados oficiais, decisão humana, efeito único e comportamento após retry. Preservar e reexecutar o teste de envelope e de origem I05 em alteração de worker. Aplicar o P0 e proteger fontes, credenciais, rollback e migrações anteriores.
- Integrar em PR com CI, revisão de Edivan5002 no HEAD exato e confirmação dos pais, árvore e blobs. Aplicar só a migração versionada com CLI 2.81.3 pelo workflow oficial após os checks do merge, paridade e confirmação de fila HML. Publicar os módulos do worker do merge e conferir versões, bytes, catálogo, privilégios e gatilhos. O canário de execução usa CODE_FIXTURE. Sem contraprova LIVE ou operação em produção.
- Se precisar reverter, suspender o consumidor frontend por PR, conservar versões/evidências/auditoria e usar release anterior do worker somente após avaliar o contrato de jobs e uma migração posterior compatível. Conferir readback e histórico antes de liberar novamente.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE (OBRIGATÓRIO)

O backend usa Supabase 4.1 existente e a fonte GitHub real. LIVE `NOT_RUN`. PROD `NO-GO`.
