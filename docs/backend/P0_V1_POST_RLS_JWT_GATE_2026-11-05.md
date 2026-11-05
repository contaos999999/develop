# GATE de prova JWT pós-RLS MASTER

Titular autorizou expressamente provas funcionais JWT para MASTER, perfis comuns, isolamento e nove SECURITY DEFINER. Baseline backend 0d198f300a786667b92fa4f2d88314ec2dc8312d; fingerprint canônico c5dc0a97dd3a371fbdfbbd425c3fd31089e2d82f7c51a7458f0ecaedc2330088 preservado. Histórico 20261105221559 tem um registro confirmado. Não reaplicar SQL.

Escopo: somente dados sintéticos prefixo p0postrls. MASTER sem vínculo, dez perfis, sem vínculo e usuário com contrato restrito; duas organizações, três contratos (A1/A2/B1), competências, requisitos, metadados de arquivos/documentos/relatórios. Tokens emitidos por Auth e confirmados com getUser HTTP. Mesmos UUIDs existentes para positivos e negativas de tenant, evitando falsa prova por UUID inexistente.

Nove funções: obter_visao_geral_competencia; obter_documentos_competencia_v115; obter_analise_competencia_v116; obter_detalhe_requisito_v117; criar_documento_competencia_v115; adicionar_versao_documento_competencia_v115; registrar_relatorio_historico_hml; enfileirar_ingestao_historica_hml; vincular_tratamento_historico_hml. Validar perfis reais, anônimo, JWT inválido, B e A2 sem escopo, revogação com mesmo JWT. Positivos de comandos assíncronos usarão replay idempotente previamente conhecido para testar autorização sem disparar worker/IA ou transferir arquivo; isso não prova criação nova/upload/worker. Tratamento histórico pode criar resposta/desfecho exclusivamente sintético, com verificação de ausência de efeito nos casos negados. Nenhum HTTP 500 ou erro arbitrário equivale a negação PASS.

Sem schema, RLS, grants, Storage, código produtivo, tipos congelados ou PROD. Cleanup por logout, bloqueio de contas/senhas aleatórias, revogação de MASTER/vínculos e organizações inativas. Preservar auditoria; não declarar zero fixtures se quarentena. Interromper diante de vazamento ou mutação indevida e registrar a falha sem corrigir fora do escopo.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual N/A: provas backend sem UI/assets. Brand v1.0 preservada. GitHub/Supabase diretos e Python padrão; quatro workers em identidades independentes, fases dependentes sequenciais. CI antes da execução, relatório sanitizado e checkpoint após resultado. V1 não certificada, V2 bloqueada, PROD proibida.
