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
