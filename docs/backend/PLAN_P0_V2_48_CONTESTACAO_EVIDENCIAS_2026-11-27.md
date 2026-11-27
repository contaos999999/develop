# PLAN P0 48 · Contestação, revisão e mapa de evidências

27/11/2026. O titular autorizou expressamente o PLAN próprio e a correção em HML, com CI e revisão no HEAD exato. Regular 48, V2-05, atômicos 037–039. A precedência depende do recibo 47 lido na main e do P0 indicando o 48. [Recibo 47 #841](https://github.com/contaos999999/contaos-hml-control/pull/841), merge `3ce3c97e4bee05bbd617265c3bc467eae806cca3`. [Plano executivo #825](https://github.com/contaos999999/contaos-hml-control/pull/825)

## Causa e alcance

A função privada que aprova a contestação verifica papel na organização e trava a versão. O catálogo HML confirmou que ela não verifica o acesso ao contrato nem a elegibilidade do mapa. As duas tabelas ainda permitem INSERT autenticado no escopo das políticas existentes. A nova operação centraliza a gravação e conserva a leitura sob RLS. A criação verifica acesso ao contrato do apontamento, mas grava referências de versão, página e hash a partir do corpo informado. A propriedade da versão e a origem da evidência precisam ser verificadas no servidor. As restrições e o lock também devem proteger a versão concorrente e distinguir rascunho, versão submetida e aprovação. Backend de referência `270c2bf56b566d05143a5835e3cc2714769cf74d`, 140 versões HML, worker AI v7.

## Contrato

- Preservar as assinaturas públicas legadas e conduzi-las ao mesmo controle. Validar sessão ativa, papel, organização, contrato, competência, rodada e item, com lock no mesmo ordenamento usado pelo 47. A leitura do painel retorna capacidades oficiais e fontes acessíveis. A criação versionada, submissão e decisão recebem chave idempotente, versão esperada e fundamento. A aprovação atualiza estado material apenas para a versão corrente, elegível e fundamentada.
- Vincular cada alegação a versão oficial e referência que a suporta. Consultar o hash do catálogo e a página ou o dado oficial, com contrato e organização do apontamento, e competência exata quando o documento é da competência. Documentos normativos de contrato permanecem no mesmo contrato. Preservar o histórico, marcar novas versões e impedir reaproveitamento de prova inválida, acesso cruzado ou aprovação silenciosa de rascunho. Um rascunho legado continua consultável.
- A minuta assistida usa as evidências e as regras do escopo, distingue recomendação de decisão e mantém indicação da origem. A gravação do worker verifica a execução e preserva o efeito único. Para a revisão humana, registrar ator, instante, versão, mapa, decisão, fundamento, antes/depois e correlação. O portão consome a última versão elegível e aprovada. O resultado externo permanece vinculado à origem e à linha do tempo e será comprovado integralmente no regular responsável.
- Provar I09, I10, I13, I19, C03, C16 e C32 nas entregas aplicáveis. O painel frontend tem PLAN próprio. Nenhuma alteração nas fontes normativas, no produto V1 ou no ambiente PROD.

## Caminhos exatos

Este PLAN altera somente o documento e docs/tasks/active-task.json. BUILD posterior limitada a:

- supabase/migrations/20261127105223_p0_v2_48_contestacao_evidencia.sql
- supabase/functions/queue-worker-ai/index.ts
- supabase/functions/queue-worker-ai/contestacao-evidencias.mjs
- supabase/tests/v2_48_contestacao_fixture.sql
- supabase/tests/v2_48_contestacao.test.sql
- supabase/tests/v2_48_contestacao_concorrencia.py
- supabase/tests/v2_48_worker.test.mjs
- supabase/tests/v2_48_catalog_pins.json
- supabase/tests/v2_48_catalog.test.mjs
- supabase/tests/history_catalog_compare.py
- .github/workflows/p0-v2-48-contestacao-code.yml

Recibo HML posterior em docs/backend/RESULTADO_P0_V2_48_CONTESTACAO_EVIDENCIAS_2026-11-27.md.

## Provas e rollback

- RED PostgreSQL descartável para o contrato de gravação e a prova de escopo da aprovação. GREEN material com criação, versão vigente, revisão, vínculo de página e hash oficial, recibo idempotente, concorrência, perfil cruzado, competência e rodada indevidas, fundamento ausente, versão substituída e retorno do portão. A prova usa somente identidades e documentos sintéticos.
- Rodar a regressão I05 e do regular 47 no mesmo worker, verificação de privilégios, Zero-Drift, histórico HML e Restore Isolado com delta exato do catálogo. Conferir HEAD, árvore, pais, jobs, ZIP e hashes. Revisão assistida de Edivan5002 e integração por PR com o HEAD aprovado. Aplicação da versão única pela CLI 2.81.3 no workflow oficial e readback do catálogo e dos fontes em HML.
- Para rollback, conservar a trilha e as versões já gravadas. Suspender consumidores da nova operação e testar migração posterior de compatibilidade se necessário. Aplicar regras vigentes de paridade e rever versão do worker antes de novo deploy.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE (OBRIGATÓRIO)

CODE_FIXTURE. LIVE `NOT_RUN`. PROD `NO-GO`.
