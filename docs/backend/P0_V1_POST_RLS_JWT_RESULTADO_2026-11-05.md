# P0 V1: provas funcionais JWT pós-RLS MASTER
Data: 05/11/2026, Brasília. HML exclusivo: gklhhhyosgasnyoxlrui. PR #67. Produção intocada.

## Resultado executivo: FAIL funcional, autorização aprovada no escopo executado
**354 verificações reais: 349 PASS e 5 FAIL.**
Os cinco FAIL reproduzem o mesmo defeito de ingestão histórica, issue #68. Não são falhas descartadas, não foram convertidas em negação bem-sucedida e não permitem certificado integral da V1.
- 203/203 negações das nove RPCs PASS, incluindo perfis, organizações, escopo, anônimo, JWT inválido e revogações.
- 80/85 positivos de RPC PASS no modo descrito abaixo; cinco enfileiramentos válidos falharam.
- 66 verificações auxiliares PASS: login/identidade Auth, organizações, RLS de contratos, logout MASTER e limpeza de sessões.

## Ambiente e integridade
- Baseline backend main: 0d198f300a786667b92fa4f2d88314ec2dc8312d.
- RLS MASTER ativo, FORCE RLS desativado; acesso direto SELECT anon/authenticated negado; nenhuma execução anônima das nove SECURITY DEFINER.
- Migração 20261105221559: exatamente um registro antes e depois. Nenhum SQL de migração foi reaplicado.
- Contexto canônico fingerprint c5dc0a97dd3a371fbdfbbd425c3fd31089e2d82f7c51a7458f0ecaedc2330088 preservado.
- Comparação antes/depois das nove funções públicas e quatro delegações privadas: **13/13 definições idênticas**.
- CI do probe e gate: 42126233013 SUCCESS, HEAD e3ee1a46f39a241dbd0dd00a17675dbbbb5e39c7. Conferir novo HEAD/CI deste relatório antes de integrar.
- SHA-256 do JSON sanitizado de execução: 417959adfad1ae5a030f4db3e3310b0ea100d1551aaf0e5f69170ff9368c34f5.
- Zero-Drift do código é uma verificação de escopo/qualidade. O resultado funcional acima continua FAIL.

## Metodologia e cobertura
13 identidades sintéticas: MASTER global sem vínculo físico; administrador; gestor_contrato; auditor; contabilidade; direcao_aprovador; financeiro; juridico_conformidade; leitor; prestacao_contas; rh_dp; sem vínculo com metadados falsos de administrador; usuário restrito a A1.
Duas organizações A/B e três contratos A1/A2/B1, com competências, requisitos e metadados sintéticos de arquivo/documento/relatório/apontamento.
Tokens emitidos por /auth/v1/token e identidades conferidas em /auth/v1/user. Nenhum JWT foi fabricado nem substituído por set_config.
Mesmos IDs existentes foram usados em positivos e negativas. A falta de acesso não foi inferida de um UUID inexistente.
MASTER consultou A1/A2/B1 sem vínculo físico. Perfis comuns acessaram somente o escopo previsto. O usuário restrito leu A1 e recebeu negação em A2/B1.
JWT MASTER foi mantido após logout global e rejeitado nas nove RPCs; o mesmo ocorreu com JWT Contabilidade após UPDATE confirmado de seu vínculo para inativo.
Quatro workers no máximo, somente em identidades independentes. Revogações ocorreram depois do baseline; negações dos dois usuários revogados em dois workers no mesmo processo, sem corrida no arquivo de evidências.

### Limites dos positivos
- Consultas: respostas reais e IDs de competência/requisito conferidos.
- criar_documento_competencia_v115 e adicionar_versao_documento_competencia_v115: **replay idempotente previamente registrado**, com verificação da autorização antes da resposta em cache. Não comprova criação inicial, upload, nova versão efetivamente gravada ou execução de worker.
- registrar_relatorio_historico_hml: retorno do relatório sintético já existente. Não comprova ingestão de arquivo novo.
- vincular_tratamento_historico_hml: escrita real de cinco respostas e cinco desfechos, somente por MASTER/administrador/gestor no escopo autorizado.
- enfileirar_ingestao_historica_hml: tentativa real de enfileirar com relatório/versão/contrato válidos e processamento sintético marcado concluído; falhou em cinco positivos.
Metadados de arquivo e processamento foram preparados como fixtures; não representam upload, OCR ou análise documental efetivamente executados.

## Matriz das nove funções
| Função | Casos | PASS | FAIL | Negações PASS |
|---|---:|---:|---:|---:|
| obter_visao_geral_competencia | 32 | 32 | 0 | 18 |
| obter_documentos_competencia_v115 | 32 | 32 | 0 | 18 |
| obter_analise_competencia_v116 | 32 | 32 | 0 | 21 |
| obter_detalhe_requisito_v117 | 32 | 32 | 0 | 21 |
| criar_documento_competencia_v115 | 32 | 32 | 0 | 22 |
| adicionar_versao_documento_competencia_v115 | 32 | 32 | 0 | 22 |
| registrar_relatorio_historico_hml | 32 | 32 | 0 | 27 |
| enfileirar_ingestao_historica_hml | 32 | 27 | 5 | 27 |
| vincular_tratamento_historico_hml | 32 | 32 | 0 | 27 |

## Falha funcional reproduzida: issue #68
Endpoint enfileirar_ingestao_historica_hml:
- Esperado: UUID de execução.
- Obtido: HTTP 400, SQLSTATE 23514, execucoes_assincronas_fila_check.
- Reproduções: gestor A1, administrador A1, MASTER A1/A2/B1.
- A fila pgmq historico existe. O CHECK de execucoes_assincronas aceita documents, ocr, ai, embeddings, finance_imports, reports, integrations e webhooks, mas a função tenta inserir historico.
- Nenhuma constraint, grant, RLS ou função foi alterada para fazer o teste passar.
Próxima correção: PLAN/GATE e migration nova pela CLI, preservando os valores existentes e o contrato da fila/worker; reexecutar os positivos falhos e regressões antes de certificar.

## Conferência independente dos efeitos
SQL após baseline confirmou:
- 3 documentos, 3 versões e 3 relatórios originais de fixture: nenhuma criação extra nos replays/negativas.
- 5 respostas e 5 desfechos: exclusivamente administrador A1, gestor A1 e MASTER A1/A2/B1.
- 0 execuções assíncronas e 0 mensagens pgmq históricas para essas organizações.
- Não houve escrita por perfil sem permissão nem por usuário fora da organização/contrato.
Essa prova compara os efeitos persistidos com os cinco positivos de tratamento; não usa apenas códigos HTTP.

## Quarentena e preservação de auditoria
Após os testes:
- 13 contas sintéticas bloqueadas por 100 anos, senhas substituídas por valores aleatórios não retidos;
- 0 sessões, 0 concessões MASTER ativas, 0 vínculos ativos e 0 escopos contratuais ativos;
- 2 organizações sintéticas inativas;
- eventos de auditoria e dados de prova preservados.
Não declarar exclusão de fixtures nem zero linhas. As contas/organizações são identificadas pelo prefixo p0postrls e scope P0-POST-RLS-JWT. Nenhuma conta ou registro de negócio real foi alterado.
Senhas, tokens, refresh tokens e dados reais não constam no Git. Os arquivos privados de fixture/sessões/seed devem ser descartados após o registro.

## Continuidade oficial
Última etapa comprovada: execução real JWT pós-RLS com todas as nove funções e isolamento A/B/contrato, com falha funcional explícita na ingestão.
RLS MASTER e histórico da migração permanecem verificados; não repetir a reconciliação.
Pendências: corrigir issue #68; matriz RBAC persistente/editável e integração ADM-01/sidebar continuam na issue #53; demais gates V1 permanecem exigíveis.
**V1 não certificada, V2 bloqueada, nenhuma promoção ou alteração PROD.**

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual N/A: somente teste e documentação backend; Brand v1.0/assets preservados. GitHub/Supabase e Python padrão, sem BUILD Lovable ou novo serviço pago. Não houve DDL, alteração RLS/grants/funções/Auth config, migrations aplicadas reescritas, tipos congelados ou backend paralelo. Houve somente dados sintéticos autorizados e sua quarentena. Falhas reais mantidas, sem reduzir controles.

## Evidências individuais
| Nº | Caso | Esperado | HTTP | Código | Resultado |
|---:|---|---|---:|---|---|
| 1 | auditor:Auth login | AUXILIAR | 200 |  | PASS |
| 2 | gestor_contrato:Auth login | AUXILIAR | 200 |  | PASS |
| 3 | master:Auth login | AUXILIAR | 200 |  | PASS |
| 4 | administrador:Auth login | AUXILIAR | 200 |  | PASS |
| 5 | administrador:Auth identity | AUXILIAR | 200 |  | PASS |
| 6 | gestor_contrato:Auth identity | AUXILIAR | 200 |  | PASS |
| 7 | auditor:Auth identity | AUXILIAR | 200 |  | PASS |
| 8 | master:Auth identity | AUXILIAR | 200 |  | PASS |
| 9 | gestor_contrato:organizations | AUXILIAR | 200 |  | PASS |
| 10 | master:organizations | AUXILIAR | 200 |  | PASS |
| 11 | auditor:organizations | AUXILIAR | 200 |  | PASS |
| 12 | administrador:organizations | AUXILIAR | 200 |  | PASS |
| 13 | gestor_contrato:contracts RLS | AUXILIAR | 200 |  | PASS |
| 14 | master:contracts RLS | AUXILIAR | 200 |  | PASS |
| 15 | auditor:contracts RLS | AUXILIAR | 200 |  | PASS |
| 16 | administrador:contracts RLS | AUXILIAR | 200 |  | PASS |
| 17 | master:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 18 | auditor:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 19 | administrador:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 20 | gestor_contrato:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 21 | administrador:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 22 | gestor_contrato:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 23 | master:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 24 | auditor:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 25 | master:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 26 | auditor:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 27 | gestor_contrato:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 28 | administrador:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 29 | master:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 30 | administrador:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 31 | gestor_contrato:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 32 | auditor:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 33 | master:A1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 34 | gestor_contrato:A1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 35 | auditor:A1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 36 | administrador:A1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 37 | master:A1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 38 | administrador:A1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 39 | auditor:A1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 40 | gestor_contrato:A1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 41 | auditor:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 42 | master:A1:registrar_relatorio_historico_hml | ALLOW | 200 |  | PASS |
| 43 | administrador:A1:registrar_relatorio_historico_hml | ALLOW | 200 |  | PASS |
| 44 | gestor_contrato:A1:registrar_relatorio_historico_hml | ALLOW | 200 |  | PASS |
| 45 | auditor:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 46 | gestor_contrato:A1:enfileirar_ingestao_historica_hml | ALLOW | 400 | 23514 | FAIL |
| 47 | administrador:A1:enfileirar_ingestao_historica_hml | ALLOW | 400 | 23514 | FAIL |
| 48 | master:A1:enfileirar_ingestao_historica_hml | ALLOW | 400 | 23514 | FAIL |
| 49 | auditor:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 50 | master:A1:vincular_tratamento_historico_hml | ALLOW | 200 |  | PASS |
| 51 | gestor_contrato:A1:vincular_tratamento_historico_hml | ALLOW | 200 |  | PASS |
| 52 | administrador:A1:vincular_tratamento_historico_hml | ALLOW | 200 |  | PASS |
| 53 | gestor_contrato:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 54 | administrador:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 55 | master:A2:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 56 | auditor:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 57 | gestor_contrato:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 58 | auditor:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 59 | master:A2:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 60 | administrador:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 61 | administrador:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 62 | gestor_contrato:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 63 | master:A2:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 64 | auditor:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 65 | auditor:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 66 | administrador:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 67 | master:A2:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 68 | gestor_contrato:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 69 | gestor_contrato:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 70 | auditor:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 71 | master:A2:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 72 | administrador:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 73 | gestor_contrato:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 74 | administrador:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 75 | master:A2:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 76 | auditor:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 77 | auditor:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 78 | administrador:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 79 | master:A2:registrar_relatorio_historico_hml | ALLOW | 200 |  | PASS |
| 80 | gestor_contrato:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 81 | gestor_contrato:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 82 | administrador:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 83 | auditor:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 84 | master:A2:enfileirar_ingestao_historica_hml | ALLOW | 400 | 23514 | FAIL |
| 85 | auditor:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 86 | gestor_contrato:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 87 | administrador:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 88 | master:A2:vincular_tratamento_historico_hml | ALLOW | 200 |  | PASS |
| 89 | master:B1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 90 | direcao_aprovador:Auth login | AUXILIAR | 200 |  | PASS |
| 91 | contabilidade:Auth login | AUXILIAR | 200 |  | PASS |
| 92 | financeiro:Auth login | AUXILIAR | 200 |  | PASS |
| 93 | direcao_aprovador:Auth identity | AUXILIAR | 200 |  | PASS |
| 94 | financeiro:Auth identity | AUXILIAR | 200 |  | PASS |
| 95 | contabilidade:Auth identity | AUXILIAR | 200 |  | PASS |
| 96 | master:B1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 97 | master:B1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 98 | financeiro:organizations | AUXILIAR | 200 |  | PASS |
| 99 | contabilidade:organizations | AUXILIAR | 200 |  | PASS |
| 100 | direcao_aprovador:organizations | AUXILIAR | 200 |  | PASS |
| 101 | direcao_aprovador:contracts RLS | AUXILIAR | 200 |  | PASS |
| 102 | financeiro:contracts RLS | AUXILIAR | 200 |  | PASS |
| 103 | contabilidade:contracts RLS | AUXILIAR | 200 |  | PASS |
| 104 | master:B1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 105 | master:B1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 106 | financeiro:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 107 | direcao_aprovador:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 108 | contabilidade:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 109 | master:B1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 110 | contabilidade:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 111 | financeiro:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 112 | direcao_aprovador:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 113 | master:B1:registrar_relatorio_historico_hml | ALLOW | 200 |  | PASS |
| 114 | direcao_aprovador:A1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 115 | financeiro:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 116 | contabilidade:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 117 | direcao_aprovador:A1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 118 | financeiro:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 119 | master:B1:enfileirar_ingestao_historica_hml | ALLOW | 400 | 23514 | FAIL |
| 120 | contabilidade:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 121 | direcao_aprovador:A1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 122 | contabilidade:A1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 123 | financeiro:A1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 124 | master:B1:vincular_tratamento_historico_hml | ALLOW | 200 |  | PASS |
| 125 | direcao_aprovador:A1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 126 | contabilidade:A1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 127 | financeiro:A1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 128 | juridico_conformidade:Auth login | AUXILIAR | 200 |  | PASS |
| 129 | contabilidade:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 130 | juridico_conformidade:Auth identity | AUXILIAR | 200 |  | PASS |
| 131 | direcao_aprovador:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 132 | financeiro:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 133 | financeiro:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 134 | direcao_aprovador:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 135 | contabilidade:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 136 | juridico_conformidade:organizations | AUXILIAR | 200 |  | PASS |
| 137 | direcao_aprovador:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 138 | financeiro:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 139 | contabilidade:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 140 | juridico_conformidade:contracts RLS | AUXILIAR | 200 |  | PASS |
| 141 | financeiro:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 142 | direcao_aprovador:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 143 | contabilidade:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 144 | juridico_conformidade:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 145 | financeiro:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 146 | juridico_conformidade:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 147 | contabilidade:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 148 | direcao_aprovador:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 149 | contabilidade:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 150 | financeiro:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 151 | direcao_aprovador:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 152 | juridico_conformidade:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 153 | financeiro:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 154 | contabilidade:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 155 | direcao_aprovador:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 156 | juridico_conformidade:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 157 | financeiro:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 158 | contabilidade:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 159 | juridico_conformidade:A1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 160 | direcao_aprovador:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 161 | financeiro:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 162 | direcao_aprovador:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 163 | juridico_conformidade:A1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 164 | contabilidade:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 165 | financeiro:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 166 | juridico_conformidade:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 167 | contabilidade:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 168 | direcao_aprovador:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 169 | direcao_aprovador:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 170 | financeiro:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 171 | juridico_conformidade:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 172 | contabilidade:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 173 | contabilidade:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 174 | financeiro:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 175 | direcao_aprovador:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 176 | juridico_conformidade:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 177 | juridico_conformidade:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 178 | prestacao_contas:Auth login | AUXILIAR | 200 |  | PASS |
| 179 | rh_dp:Auth login | AUXILIAR | 200 |  | PASS |
| 180 | leitor:Auth login | AUXILIAR | 200 |  | PASS |
| 181 | juridico_conformidade:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 182 | leitor:Auth identity | AUXILIAR | 200 |  | PASS |
| 183 | rh_dp:Auth identity | AUXILIAR | 200 |  | PASS |
| 184 | prestacao_contas:Auth identity | AUXILIAR | 200 |  | PASS |
| 185 | juridico_conformidade:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 186 | leitor:organizations | AUXILIAR | 200 |  | PASS |
| 187 | rh_dp:organizations | AUXILIAR | 200 |  | PASS |
| 188 | prestacao_contas:organizations | AUXILIAR | 200 |  | PASS |
| 189 | leitor:contracts RLS | AUXILIAR | 200 |  | PASS |
| 190 | juridico_conformidade:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 191 | rh_dp:contracts RLS | AUXILIAR | 200 |  | PASS |
| 192 | prestacao_contas:contracts RLS | AUXILIAR | 200 |  | PASS |
| 193 | juridico_conformidade:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 194 | leitor:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 195 | prestacao_contas:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 196 | rh_dp:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 197 | juridico_conformidade:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 198 | prestacao_contas:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 199 | rh_dp:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 200 | leitor:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 201 | leitor:A1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 202 | juridico_conformidade:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 203 | prestacao_contas:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 204 | rh_dp:A1:obter_analise_competencia_v116 | ALLOW | 200 |  | PASS |
| 205 | rh_dp:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 206 | leitor:A1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 207 | juridico_conformidade:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 208 | prestacao_contas:A1:obter_detalhe_requisito_v117 | ALLOW | 200 |  | PASS |
| 209 | leitor:A1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 210 | juridico_conformidade:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 211 | rh_dp:A1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 212 | prestacao_contas:A1:criar_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 213 | leitor:A1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 214 | prestacao_contas:A1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 215 | rh_dp:A1:adicionar_versao_documento_competencia_v115 | ALLOW | 200 |  | PASS |
| 216 | sem_vinculo:Auth login | AUXILIAR | 200 |  | PASS |
| 217 | leitor:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 218 | sem_vinculo:Auth identity | AUXILIAR | 200 |  | PASS |
| 219 | rh_dp:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 220 | prestacao_contas:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 221 | prestacao_contas:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 222 | leitor:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 223 | sem_vinculo:organizations | AUXILIAR | 200 |  | PASS |
| 224 | rh_dp:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 225 | leitor:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 226 | sem_vinculo:contracts RLS | AUXILIAR | 200 |  | PASS |
| 227 | rh_dp:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 228 | prestacao_contas:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 229 | rh_dp:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 230 | sem_vinculo:A1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 231 | prestacao_contas:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 232 | leitor:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 233 | sem_vinculo:A1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 234 | rh_dp:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 235 | leitor:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 236 | prestacao_contas:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 237 | prestacao_contas:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 238 | sem_vinculo:A1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 239 | leitor:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 240 | rh_dp:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 241 | leitor:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 242 | sem_vinculo:A1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 243 | rh_dp:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 244 | prestacao_contas:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 245 | sem_vinculo:A1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 246 | leitor:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 247 | rh_dp:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 248 | prestacao_contas:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 249 | rh_dp:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 250 | prestacao_contas:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 251 | sem_vinculo:A1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 252 | leitor:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 253 | sem_vinculo:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 254 | prestacao_contas:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 255 | leitor:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 256 | rh_dp:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 257 | rh_dp:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 258 | prestacao_contas:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 259 | leitor:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 260 | sem_vinculo:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 261 | prestacao_contas:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 262 | sem_vinculo:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 263 | rh_dp:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 264 | leitor:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 265 | restrito:Auth login | AUXILIAR | 200 |  | PASS |
| 266 | sem_vinculo:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 267 | restrito:Auth identity | AUXILIAR | 200 |  | PASS |
| 268 | sem_vinculo:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 269 | sem_vinculo:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 270 | restrito:organizations | AUXILIAR | 200 |  | PASS |
| 271 | sem_vinculo:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 272 | restrito:contracts RLS | AUXILIAR | 200 |  | PASS |
| 273 | sem_vinculo:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 274 | restrito:A1:obter_visao_geral_competencia | ALLOW | 200 |  | PASS |
| 275 | sem_vinculo:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 276 | restrito:A1:obter_documentos_competencia_v115 | ALLOW | 200 |  | PASS |
| 277 | sem_vinculo:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 278 | restrito:A1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 279 | sem_vinculo:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 280 | restrito:A1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 281 | restrito:A1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 282 | sem_vinculo:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 283 | restrito:A1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 284 | restrito:A1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 285 | restrito:A1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 286 | restrito:A1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 287 | restrito:A2:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 288 | restrito:A2:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 289 | restrito:A2:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 290 | restrito:A2:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 291 | restrito:A2:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 292 | restrito:A2:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 293 | restrito:A2:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 294 | restrito:A2:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 295 | restrito:A2:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 296 | restrito:B1:obter_visao_geral_competencia | DENY | 403 |  | PASS |
| 297 | restrito:B1:obter_documentos_competencia_v115 | DENY | 403 |  | PASS |
| 298 | restrito:B1:obter_analise_competencia_v116 | DENY | 403 |  | PASS |
| 299 | restrito:B1:obter_detalhe_requisito_v117 | DENY | 403 |  | PASS |
| 300 | restrito:B1:criar_documento_competencia_v115 | DENY | 403 |  | PASS |
| 301 | restrito:B1:adicionar_versao_documento_competencia_v115 | DENY | 403 |  | PASS |
| 302 | restrito:B1:registrar_relatorio_historico_hml | DENY | 400 |  | PASS |
| 303 | restrito:B1:enfileirar_ingestao_historica_hml | DENY | 400 |  | PASS |
| 304 | restrito:B1:vincular_tratamento_historico_hml | DENY | 400 |  | PASS |
| 305 | anon:obter_visao_geral_competencia | DENY | 401 |  | PASS |
| 306 | anon:obter_documentos_competencia_v115 | DENY | 401 |  | PASS |
| 307 | anon:obter_analise_competencia_v116 | DENY | 401 |  | PASS |
| 308 | anon:obter_detalhe_requisito_v117 | DENY | 401 |  | PASS |
| 309 | anon:criar_documento_competencia_v115 | DENY | 401 |  | PASS |
| 310 | anon:adicionar_versao_documento_competencia_v115 | DENY | 401 |  | PASS |
| 311 | anon:registrar_relatorio_historico_hml | DENY | 401 |  | PASS |
| 312 | anon:enfileirar_ingestao_historica_hml | DENY | 401 |  | PASS |
| 313 | anon:vincular_tratamento_historico_hml | DENY | 401 |  | PASS |
| 314 | invalid_jwt:obter_visao_geral_competencia | DENY | 401 |  | PASS |
| 315 | invalid_jwt:obter_documentos_competencia_v115 | DENY | 401 |  | PASS |
| 316 | invalid_jwt:obter_analise_competencia_v116 | DENY | 401 |  | PASS |
| 317 | invalid_jwt:obter_detalhe_requisito_v117 | DENY | 401 |  | PASS |
| 318 | invalid_jwt:criar_documento_competencia_v115 | DENY | 401 |  | PASS |
| 319 | invalid_jwt:adicionar_versao_documento_competencia_v115 | DENY | 401 |  | PASS |
| 320 | invalid_jwt:registrar_relatorio_historico_hml | DENY | 401 |  | PASS |
| 321 | invalid_jwt:enfileirar_ingestao_historica_hml | DENY | 401 |  | PASS |
| 322 | invalid_jwt:vincular_tratamento_historico_hml | DENY | 401 |  | PASS |
| 323 | master:logout revocation | AUXILIAR | 204 |  | PASS |
| 324 | master:A1:obter_visao_geral_competencia:revoked | DENY | 403 |  | PASS |
| 325 | contabilidade:A1:obter_visao_geral_competencia:revoked | DENY | 403 |  | PASS |
| 326 | master:A1:obter_documentos_competencia_v115:revoked | DENY | 403 |  | PASS |
| 327 | contabilidade:A1:obter_documentos_competencia_v115:revoked | DENY | 403 |  | PASS |
| 328 | contabilidade:A1:obter_analise_competencia_v116:revoked | DENY | 403 |  | PASS |
| 329 | master:A1:obter_analise_competencia_v116:revoked | DENY | 403 |  | PASS |
| 330 | master:A1:obter_detalhe_requisito_v117:revoked | DENY | 403 |  | PASS |
| 331 | contabilidade:A1:obter_detalhe_requisito_v117:revoked | DENY | 403 |  | PASS |
| 332 | master:A1:criar_documento_competencia_v115:revoked | DENY | 403 |  | PASS |
| 333 | contabilidade:A1:criar_documento_competencia_v115:revoked | DENY | 403 |  | PASS |
| 334 | contabilidade:A1:adicionar_versao_documento_competencia_v115:revoked | DENY | 403 |  | PASS |
| 335 | master:A1:adicionar_versao_documento_competencia_v115:revoked | DENY | 403 |  | PASS |
| 336 | contabilidade:A1:registrar_relatorio_historico_hml:revoked | DENY | 400 |  | PASS |
| 337 | master:A1:registrar_relatorio_historico_hml:revoked | DENY | 400 |  | PASS |
| 338 | contabilidade:A1:enfileirar_ingestao_historica_hml:revoked | DENY | 400 |  | PASS |
| 339 | master:A1:enfileirar_ingestao_historica_hml:revoked | DENY | 400 |  | PASS |
| 340 | contabilidade:A1:vincular_tratamento_historico_hml:revoked | DENY | 400 |  | PASS |
| 341 | master:A1:vincular_tratamento_historico_hml:revoked | DENY | 400 |  | PASS |
| 342 | master:cleanup logout | AUXILIAR | 403 |  | PASS |
| 343 | auditor:cleanup logout | AUXILIAR | 204 |  | PASS |
| 344 | gestor_contrato:cleanup logout | AUXILIAR | 204 |  | PASS |
| 345 | administrador:cleanup logout | AUXILIAR | 204 |  | PASS |
| 346 | direcao_aprovador:cleanup logout | AUXILIAR | 204 |  | PASS |
| 347 | financeiro:cleanup logout | AUXILIAR | 204 |  | PASS |
| 348 | contabilidade:cleanup logout | AUXILIAR | 204 |  | PASS |
| 349 | juridico_conformidade:cleanup logout | AUXILIAR | 204 |  | PASS |
| 350 | rh_dp:cleanup logout | AUXILIAR | 204 |  | PASS |
| 351 | prestacao_contas:cleanup logout | AUXILIAR | 204 |  | PASS |
| 352 | sem_vinculo:cleanup logout | AUXILIAR | 204 |  | PASS |
| 353 | leitor:cleanup logout | AUXILIAR | 204 |  | PASS |
| 354 | restrito:cleanup logout | AUXILIAR | 204 |  | PASS |
