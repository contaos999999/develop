# GATE P0 — roteamento dos workflows HML históricos — 07/11/2026

## Dependência e decisão
PLAN do PR #103 integrado em 534a6d3dec156f60ac31b5b0c7f1fd05ab6bbbe7, após prova privada V117 run 42391662453 SUCCESS e quarentena das oito identidades sintéticas verificada. Este GATE é documental e **não autoriza deploy, DDL, execução administrativa, mudança em PROD nem certificação V1**. BUILD permanece bloqueado até merge deste GATE com checks exigidos verdes no mesmo HEAD.

## Contrato do BUILD
1. Selecionar tarefa e fase explicitamente **antes** de qualquer step com GH_TOKEN privilegiado, conexão HML, Auth, fixture, deploy ou dispatch. Aplicar aos workflows de listas, revisão V117 e prova privada V117, somente nos caminhos já permitidos pelo manifesto.
2. Para tarefa ou fase não aplicável, job deve apresentar `skipped` de modo inequívoco, sem efeitos materiais; a execução histórica 42369440188 permanece FAIL no registro.
3. Na tarefa aplicável, preservar sem flexibilização a validação do SHA exato da main, hashes de migration, allowlist, checks guard/restore/backup, restrições de origem e quarentena/finally/always. Falha de controle deve continuar FAIL, nunca ser convertida em skip.
4. Não criar usuários Auth por SQL nem repetir deploy canônico quando a tarefa é V117. Nenhuma alteração de migration, RLS, API, Auth config, storage, frontend ou PROD.
5. RED antes de BUILD em `supabase/tests/p0_workflow_routing.test.mjs`: testar a configuração YAML efetiva e as expressões de seleção para tarefa aplicável, tarefa diferente, fase incorreta, evento externo/PR, guard ausente, preservação de dispatch e cleanup. GREEN local e CI, revisão independente e prova de execução pós-merge sem reimplantar HML.
6. Registrar HEADs, PR, checks, evidência de skip real e limitações no checkpoint canônico frontend. Não marcar V1 certificada.

## Reversão e zero-drift
Reverter somente o roteamento, sem apagar provas anteriores. BRAND-01, 25 documentos canônicos e catálogo 100/97 preservados. O GATE não altera comportamento em runtime e não dispensa verificações de segurança ou acessibilidade.

**Estado:** GATE proposto; aguarda checks, revisão e integração.

## Execução do BUILD

GATE117 integrado8f48e37317c711c6736a33e9a34421c3967326d3 após guardSUCCESS. RED local:13testes,4PASS/9FAIL por scopeausente. GREEN posterior13/13. Seleção read-only interpreta manifesto no SHA do restore, aceita somente evento workflow_run de push main do próprio repositório e restoreSUCCESS. Origem ou tarefa/fase não aplicável deixa jobs materiais SKIPPED; manifesto malformado falha. Aplicável mantém gates SHA/hash/allowlist/checks, dispatch e cleanup inalterados. Missing guard/restore/backup é executado contra gates reais com transporte gh controlado sem rede e produz FAIL pelo check ausente, não por setup.

Decisão técnica: listas e revisão só permitem fase BUILD_EM_VALIDACAO para deploy; a fase histórica PLAN_VALIDADO_AGUARDANDO_CI_RED_BUILD não autoriza deploy. Isso impede execução material durante planejamento e exige manifesto explícito em eventual nova tarefa. Browser privado preserva BUILD_PROVA_PRIVADA_FRONTEND. Tarefa atual BUILD_ROTEAMENTO_WORKFLOW_HML não deve executar nenhum dos três jobs materiais. Sem autorização atual de DB/Auth, campos gerais do manifesto agora false; evidências e escopos históricos preservados.

Revisão, CI e evidência pós-merge ainda pendentes. Falhas históricas continuam FAIL; nenhum sucesso material inferido de skip.

## Encerramento comprovado — 07/11/2026

**PASS no escopo de roteamento.** BUILD118 HEAD545231b2ea47198b089085c50c38eb77f93f359a integrado2ebb9e3a639ea837430f3d9f1b4e7acfdbb8bb35 após guard/restore/backup/public-probe SUCCESS no mesmoHEAD. Guard42393190669, restore42393190805, probe42393190673. Suíte local completa30/30 e protocoloV117PASS; foco13/13. Revisão independente semCritical/Important. Limitação minor: extraçãoYAML por regex e semânticaJS para expressões simples, checkoutref semassertion específica; validação Actions e prova real complementam, não substituem autoria/testes.

Main guard42393429313 e restore42393429340 SUCCESS. Artefatos restore13582580695 SHA256197e1bb8a3ee72b9d67e3a4c517a51242bf1952ee9a5cfa0466bd2a641d5707b; backup13582950289 SHA256dac294b64c078276ea425791a31bfb4ec28dfe7e30994ca57a8dd9a6d41fea99 (metadadosGitHub).

| Workflow / run | Scope | Material |
| --- | --- | --- |
| Listas42393625175 | 128466217848 SUCCESS | deploy128466249496 SKIPPED; JWT128466249648 SKIPPED |
| Revisão42393625123 | 128466217768 SUCCESS | deploy128466247984 SKIPPED; JWT128466248525 SKIPPED |
| Browser42393625096 | 128466217565 SUCCESS | privado128466249394 SKIPPED; probe128466218545 SKIPPED |

Três logs scope lidos: NOT_APPLICABLE_TASK_OR_PHASE: material jobs skipped. Todos no HEAD2ebb9e3a639ea837430f3d9f1b4e7acfdbb8bb35, faseBUILD_ROTEAMENTO_WORKFLOW_HML. Nenhum job material executado, nenhuma repetição de deploy/fixture/JWT. Cadastros42393625068 permaneceuSKIPPED sem alteração. Runs anteriores de listas permanecemFAIL no histórico. Prova privadaV117 anterior42391662453 PASS e quarentena8 preservadas, não repetidas por conveniência. Conclusão não certifica V1/WCAG/upload/worker/CRUDglobal integral; manter pendências e fontes. Nenhuma alteração de PROD, DB, Authconfig, RLS, APIs ou frontend.
