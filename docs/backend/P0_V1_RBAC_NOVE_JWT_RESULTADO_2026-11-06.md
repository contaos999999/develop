# P0 V1: regressão JWT das nove funções após RBAC

HML exclusivo gklhhhyosgasnyoxlrui. Execução real em 06/11/2026 (UTC), sem PROD, nova DDL/RLS, configuração Auth/Storage, alteração da matriz ou worker. Gate PR84, HEAD 1aaedb477a35c1f7a7a60e5d7d978bc4bc93c5de, CI42154235932 SUCCESS, merge 1edb2c40595e01f7e1e8c5f80160b7b3a4113c12.

## Resultado comprovado

**377/377 verificações aprovadas,0 falhas.** Auth real com14 contas novas,10 perfis,MASTER sem vínculo,sem vínculo,gestor restrito A1 e leitor B. Duas organizações, três contratosA1/A2/B1. Campo user_metadata.master=true forjado não concede MASTER.

| Etapa | Verificações | PASS |
|---|---:|---:|
| Login/identidade, organizações, RLS e nove APIs por perfil/contexto, anônimo/JWT inválido |344|344|
| Mesmo JWT contabilidade após revogar vínculo |9|9|
| Logout MASTER |1|1|
| NoveAPIs com JWT MASTER revogado |9|9|
| Logout final14 identidades |14|14|
| Total |377|377|

306 chamadas às APIs:94 ALLOW,212 DENY. Outras 71 verificações de Auth,organizações,RLS e logout.

| Função pública | ALLOW | DENY |
|---|---:|---:|
| obter_visao_geral_competencia |15|19|
| obter_documentos_competencia_v115 |15|19|
| obter_analise_competencia_v116 |12|22|
| obter_detalhe_requisito_v117 |12|22|
| criar_documento_competencia_v115 |11|23|
| adicionar_versao_documento_competencia_v115 |11|23|
| registrar_relatorio_historico_hml |6|28|
| enfileirar_ingestao_historica_hml |6|28|
| vincular_tratamento_historico_hml |6|28|

Negativas autenticadas exigiram403/42501 ou mensagem canônica específica de gestão sem permissão. Erro de negócio genérico não foi aceito como prova de autorização. Sem token/JWT inválido exigiram401/403. Leitura positiva conferiu ID exato da competência/requisito; escritas conferiram IDs/UUIDs e contrato do retorno.

Perfis comuns testados em A1/B1, incluindo sentido B→A pelo leitor B. MASTER e gestorrestrito também A2; o gestor restrito foi negado fora de A1. RLS da lista de contratos conferiu conjunto exatoA1/A2/B1 por perfil. Isso descreve os cenários executados, não todas as permutações possíveis de usuários/objetos.

## Persistência independente e ausência de efeitos negativos

SQL após as chamadas confirmou3 documentos, 3 versões e 3 relatórios. Respostas/desfechos reais: exatamente 6 de cada, apenas administrador A1, gestor A1, gestor restrito A1 e MASTER A1/A2/B1. Nenhuma resposta de perfil ou contexto negado foi persistida.

Histórico:3 execuções e 3 mensagens novas, repetição idempotente entre gestores sem duplicação. Os 3 payloads foram comparados a organização,contrato,relatório e versão esperados:3/3 exatos. Mensagens próprias arquivadas: 3; pendentes: 0; execuções próprias canceladas: 3. Auditoria preservada. Nenhuma fila/configuração de usuário real foi alterada.

Snapshot agregado durante a rodada:12 conexões de um limite de 60, 0 locks aguardando,0 deadlocks registrados. Não é teste de saturação do pool, latência, disponibilidade ou observabilidade completa.

## Limites que permanecem explícitos

Criação documental e nova versão usaram 84 comandos de replay previamente concluídos e vinculados a cada ator. A função executou a autorização antes de permitir replay. Isso prova autorização/negação do replay, não primeira criação física, cadeia completa de upload ou processamento.

Registro histórico retornou relatório próprio existente. Enfileiramento e tratamento gravaram efeitos reais acima. Arquivo aprovado e processamento concluído foram pré-condições sintéticas no banco, sem blob físico. Worker não foi executado nem certificado.

Os avisos Advisor sobre funções SECURITY DEFINER não foram apagados por revogação cega de EXECUTE nem alteração do contrato. A justificativa funcional permanece limitada aos fluxos e ACLs verificados. Este relatório não certifica integralmente V1.

## Quarentena verificada

14 UUIDs e scope=P0-RBAC-NINE exatos. Contas bloqueadas por 100 anos e senhas invalidadas,MASTER/vínculos/escopos desativados,2 organizações inativas,sem DELETE.

| Verificação | Resultado |
|---|---:|
| Contas bloqueadas |14|
| Sessões persistidas |0|
| MASTER ativo |0|
| Vínculos ativos |0|
| Escopos contratuais ativos |0|
| Organizações inativas |2|

Leitura independente posterior repetiu14 bloqueadas / 0 sessões / 0 MASTER / 0 vínculos. A matriz não foi alterada nesta rodada. Contas antigas bloqueadas não foram reutilizadas.

Relatório sanitizado SHA256 cd5ed639120a8e201cf5b858fd3ec1cafd9a216904d0d4a425fc847c3229e3ec. Senhas, JWTs e e-mails privados fora do Git e dos logs.

## Continuidade do plano único

Backend referência 1edb2c40595e01f7e1e8c5f80160b7b3a4113c12; frontend PLAN #180 integrado em 50709cd796d876149c8f011607fc24369ab5d28a, BUILD local em revisão. Após resolver achado de desmontagem da matriz ao filtrar usuários, executar CI e Teste C no SHA exato. Fonte normativa 25/25 e catálogo 100/97 permanecem inalterados; HEAD backend deve ser reancorado no frontend quando este relatório for integrado.

Restam interface/RBAC/menu, SYS-03 real, WCAG/Teste C privado, RNFs práticos e reconciliação dos 486 critérios literais V1 contra 488 históricos. Última etapa comprovada:nove APIs com JWT real e quarentena. Próxima tarefa: concluir e validar BUILD frontend. V1 NÃO CERTIFICADA; V2 bloqueada; PROD intacta.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Somente evidência e checkpoint. Sem visual, tipos, DDL, RLS ou PROD. As provas anteriores válidas foram preservadas; nova regressão foi necessária por novas restrições RBAC.
