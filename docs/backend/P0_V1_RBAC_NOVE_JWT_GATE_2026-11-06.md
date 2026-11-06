# GATE: regressão JWT das nove funções após RBAC

Autorização: plano único e pedido “Execute integralmente”. HML gklhhhyosgasnyoxlrui, sem PROD. Rodada anterior encerrada: PR83, 14 contas bloqueadas, zero sessões/privilégios; não reutilizar.

## Escopo e contrato

Probe supabase/tests/rbac_nine_jwt_probe.py. Novas 14 contas, dez perfis, MASTER sem vínculo, sem vínculo, gestor restrito A1 e leitor B. Duas organizações, três contratos A1/A2/B1. user_metadata master=true forjada não concede MASTER. IDs aleatórios, scope P0-RBAC-NINE; senhas bcrypt local Python3.12; somente hashes no SQL. Diretório privado externo obrigatório,0700/0600,sem credenciais em Git/log/chat.

Nove APIs: obter_visao_geral_competencia, obter_documentos_competencia_v115, obter_analise_competencia_v116, obter_detalhe_requisito_v117, criar_documento_competencia_v115, adicionar_versao_documento_competencia_v115, registrar_relatorio_historico_hml, enfileirar_ingestao_historica_hml, vincular_tratamento_historico_hml.

## Fixtures e limites explícitos

Três competências, requisitos manuais, arquivos sintéticos aprovados somente no banco, documentos/versões, relatórios e apontamentos. Não existe blob físico. Processamento sintético concluído é pré-condição controlada, não prova de worker. Cada ator tem comandos documentais idempotentes previamente concluídos: os positivos de criação e nova versão são replay autenticado, não primeira gravação. A autorização acontece antes de consultar o comando; negativas devem falhar mesmo com replay disponível. Relatório histórico positivo retorna relatório próprio existente; não comprova primeira importação. Vincular tratamento grava resposta e desfecho reais, com leitura SQL de persistência. Enfileirar histórico cria até três execuções/mensagens reais, com repetição idempotente entre gestores; SQL confere escopo e contagem. Nenhum upload, alteração de bucket, Cron, worker ou configuração Auth.

## Execução e aceites

1. CI verde no código exato antes de criar fixtures. Não modificar a matriz.
2. Login/identidade Auth, organizações e RLS por JWT; chamadas válidas nas nove APIs com os perfis e contextos permitidos e proibidos. A/B nos dois sentidos, A1/A2 restrito, MASTER A1/A2/B1, anônimo e JWT inválido.
3. Leituras positivas precisam devolver ID exato de competência/requisito, não somente HTTP200. Escritas precisam devolver UUID/IDs esperados. Negativas exigem 42501/403 ou mensagem canônica de gestão negada, sem aceitar erro de negócio genérico como autorização.
4. Revogar somente vínculo contabilidade; nove chamadas com mesmo JWT devem negar. Logout MASTER; nove chamadas com JWT revogado devem negar. Logout de todos.
5. SQL independente: documentos/versões/relatórios continuam3; até3 execuções históricas e mensagens com payload exato; respostas/desfechos somente combinações esperadas, nenhum texto de caso negado. Arquivar somente mensagens destas execuções, cancelar execuções próprias pendentes, preservando auditoria.
6. Quarentena por 14UUIDs e scope exatos: bloquear/inutilizar senhas, revogar MASTER/vínculos/escopos, inativar2organizações; verificar0sessões/0privilégios ativos.
7. Registrar PASS/FAIL, limites, hashes e último HEAD no relatório. Falhas reais exigem diagnóstico e reteste afetado, nunca relaxamento de asserções.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Sem visual, frontend, tipos congelados, DDL/RLS ou PROD. CI não substitui JWT real. Esta regressão não certifica V1 inteira, upload físico ou worker. Restam frontend, SYS03, WCAG/Teste C, RNFs e reconciliação literal486 versus histórico488.
