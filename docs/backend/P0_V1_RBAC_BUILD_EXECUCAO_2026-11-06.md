# BUILD candidato RBAC V1
Autorização: plano único PR76 e ordem expressa “Execute integralmente”. Issue53.
Baseline c3818e698e748a15b98ff31ae591fae0e1838f55. HML gklhhhyosgasnyoxlrui, PROD proibida.

## Objetos e fontes
Migration supabase/migrations/20261106014102_p0_v1_rbac_persistente.sql, arquivo vazio produzido realmente por Supabase CLI2.81.3, run42145435501, artifact13469991773, SHA256453a2f19b28fa5e3bc65b31d8b9417ad16910f3ead78aba434c01d0107fb7607.
RED real: P0001 seis objetos ausentes; chamada API futura 42883 antes de BUILD.
Inventário real:184 políticas public/storage,284 funções public/privado. Cobertura exata no JSON deste PR.
4 tabelas privadas com RLS, sem grants clientes: catálogo, permissões, versão global e comandos idempotentes.
3 APIs públicas SECURITY INVOKER: consultar_permissoes_efetivas(uuid,uuid), obter_matriz_rbac_master(), atualizar_matriz_rbac_master(bigint,uuid,jsonb).
Implementações privilegiadas somente privado com search_path vazio e sessão/MASTER verificados. Helpers privados rbac_permite e exigir_permissao_rbac.
17 recursos,40 tabelas V1 recebem políticas RESTRICTIVE adicionais. Políticas antigas preservadas integralmente; matriz não amplia seu alcance.
43 funções recebem guarda explícita antes da lógica original, preservando assinatura, corpo restante e regras especializadas. Storage SELECT recebe restrição adicional.

## Contrato
Consulta contextual não aceita usuário arbitrário; verifica organização e contrato correspondente, sessão e vínculo vigentes. Ausência é DENY.
MASTER existente mantém administração transversal sem vínculo, não é novo perfil e não recebe automaticamente direcao_aprovador.
Edição exclusiva MASTER: versão global bloqueada FOR UPDATE, expected_version, request UUID, payload validado, máximo500 itens, combinações fechadas e sem duplicatas.
Replay idêntico do mesmo ator retorna resposta original; payload/ator divergente PT409; stale versão PT409; nenhuma duplicação de auditoria.
Evento MatrizRbacAtualizada preserva antes/depois, ator, versão e request_id.

## Gates de prova
CI Zero-Drift, Context/Architecture/SQL/secret guards. Restore do zero agora roda também em PR afetado, mantendo as11 suítes existentes e adicionando rbac_matrix.sql com marcador obrigatório.
A suíte SQL usa fixtures em rollback e claims simuladas SOMENTE no restore isolado. Não é prova JWT real.
Após GREEN e revisão: merge e deploy_one canônico, verificação pós-DDL e JWT real. Sem apply_migration, sem DDL avulso nem reparo de histórico.
Não tocar frontend antes de contrato testado.

## Reversão
Antes do deploy guardar definições/grants/policies anteriores. Se falhar restore/CI/revisão não implantar.
Após deploy, reversão por NOVA migration CLI: remover apenas políticas rbac_v1_* e restaurar exatamente definições anteriores das43 funções e probe de auditoria. Preservar tabelas/configurações/comandos/eventos como histórico; não apagar auditoria. Frontend novo não deve ser promovido enquanto rollback estiver ativo.
Arquivo de migration aplicada é imutável. Reversão também exige testes e paridade.

## Estado
BUILD candidato, sem GREEN, sem deploy, sem JWT novo, sem certificação V1. PR75 e provas anteriores preservados; alterações de autorização exigirão regressão pertinente, sem declarar baselines antigos como nova prova.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Backend sem impacto visual. Brand1.0 e tipos congelados preservados; ferramentas diretas, sem Lovable ou serviço pago. Segurança e testes mantidos.
