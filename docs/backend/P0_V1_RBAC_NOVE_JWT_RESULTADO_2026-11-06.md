# P0 V1: regressão JWT das nove funções após RBAC

HML exclusivo gklhhhyosgasnyoxlrui. Execução real em06/11/2026UTC, sem PROD, nova DDL/RLS, configuração Auth/Storage, alteração da matriz ou worker. Gate PR84, HEAD 1aaedb477a35c1f7a7a60e5d7d978bc4bc93c5de, CI42154235932 SUCCESS, merge 1edb2c40595e01f7e1e8c5f80160b7b3a4113c12.

## Resultado comprovado

**377/377 verificações aprovadas,0falhas.** Auth real com14contas novas,10perfis,MASTERsemvínculo,semvínculo,gestorrestritoA1 e leitorB. Duasorganizações,trêscontratosA1/A2/B1. Campo user_metadata.master=true forjado não concede MASTER.

| Etapa | Verificações | PASS |
|---|---:|---:|
| Login/identidade, organizações, RLS e noveAPIs por perfil/contexto, anônimo/JWTinválido |344|344|
| MesmoJWT contabilidade após revogar vínculo |9|9|
| Logout MASTER |1|1|
| NoveAPIs com JWT MASTER revogado |9|9|
| Logout final14identidades |14|14|
| Total |377|377|

306chamadas às APIs:94ALLOW,212DENY. Outras71verificações de Auth,organizações,RLS e logout.

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

Negativas autenticadas exigiram403/42501 ou mensagem canônica específica de gestão sem permissão. Erro de negócio genérico não foi aceito como prova de autorização. Sem token/JWTinválido exigiram401/403. Leitura positiva conferiu ID exato da competência/requisito; escritas conferiram IDs/UUIDs e contrato do retorno.

Perfis comuns testados emA1/B1, incluindo sentidoB→A pelo leitorB. MASTER e gestorrestrito tambémA2; o gestor restrito foi negado fora deA1. RLS da lista de contratos conferiu conjunto exatoA1/A2/B1 por perfil. Isso descreve os cenários executados, não todas as permutações possíveis de usuários/objetos.

## Persistência independente e ausência de efeitos negativos

SQL após as chamadas confirmou3documentos,3versões,3relatórios. Respostas/desfechos reais:exatamente6de cada, apenas administradorA1,gestorA1,gestorrestritoA1,MASTER A1/A2/B1. Nenhuma resposta de perfil ou contexto negado foi persistida.

Histórico:3execuções e3mensagens novas, repetição idempotente entre gestores sem duplicação. Os3payloads foram comparados a organização,contrato,relatório eversão esperados:3/3exatos. Mensagens próprias arquivadas:3; pendentes:0; execuções próprias canceladas:3. Auditoria preservada. Nenhuma fila/configuração de usuário real foi alterada.

Snapshot agregado durante a rodada:12conexões/limite60,0locks aguardando,0deadlocks registrados. Não é teste de saturação do pool, latência, disponibilidade ou observabilidade completa.

## Limites que permanecem explícitos

Criação documental e nova versão usaram84comandos de replay previamente concluídos e vinculados a cada ator. A função executou a autorização antes de permitir replay. Isso prova autorização/negação do replay, não primeira criação física, cadeia completa de upload ou processamento.

Registro histórico retornou relatório próprio existente. Enfileiramento e tratamento gravaram efeitos reais acima. Arquivo aprovado e processamento concluído foram pré-condições sintéticas no banco, semblob físico. Worker não foi executado nem certificado.

Os avisos Advisor sobre funções SECURITY DEFINER não foram apagados por revogação cega de EXECUTE nem alteração do contrato. A justificativa funcional permanece limitada aos fluxos e ACLs verificados. Este relatório não certifica integralmente V1.

## Quarentena verificada

14UUIDs e scope=P0-RBAC-NINE exatos. Contas bloqueadas100anos e senhas invalidadas,MASTER/vínculos/escopos desativados,2organizações inativas,semDELETE.

| Verificação | Resultado |
|---|---:|
| Contas bloqueadas |14|
| Sessões persistidas |0|
| MASTER ativo |0|
| Vínculos ativos |0|
| Escopos contratuais ativos |0|
| Organizações inativas |2|

Leitura independente posterior repetiu14bloqueadas/0sessões/0MASTER/0vínculos. A matriz não foi alterada nesta rodada. Contas antigas bloqueadas não foram reutilizadas.

Relatório sanitizado SHA256 cd5ed639120a8e201cf5b858fd3ec1cafd9a216904d0d4a425fc847c3229e3ec. Senhas/JWTs/emails privados fora do Git e dos logs.

## Continuidade do plano único

Backend referência 1edb2c40595e01f7e1e8c5f80160b7b3a4113c12; frontend PLAN180 integrado em50709cd796d876149c8f011607fc24369ab5d28a, BUILD local em revisão. Após resolver achado de desmontagem da matriz ao filtrar usuários, executar CI e TesteC noSHA exato. Fonte normativa25/25 e catálogo100/97 permanecem inalterados; HEADbackend deve ser reancorado no frontend quando este relatório for integrado.

Restam interface/RBAC/menu, SYS03real, WCAG/TesteCprivado, RNFs práticos e reconciliação dos486critérios literaisV1 contra488históricos. Última etapa comprovada:noveAPIs comJWT real e quarentena. Próxima tarefa:concluir e validar BUILDfrontend. V1 NÃO CERTIFICADA; V2 bloqueada; PRODintacta.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Somente evidência e checkpoint. Sem visual, tipos,DDL,RLS ouPROD. As provas anteriores válidas foram preservadas; nova regressão foi necessária por novas restriçõesRBAC.
