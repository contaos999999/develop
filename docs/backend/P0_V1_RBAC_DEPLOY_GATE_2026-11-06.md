# GATE de implantação RBAC HML
Autorização expressa: executar integralmente plano único V1, PR76. BUILD PR77 integrado em 3c118ed4385a5828af58e3134f2fd785f5140950.
HEAD aprovado 9aa4bd837453d9e74e36adc66db9c75a09e25955.
Zero-Drift42147037080 SUCCESS; Restore42147037054 SUCCESS; histórico42147037061 SUCCESS.
Restore comprovou as11 suítes anteriores e RBAC_ISOLATED_PASS + concorrência real2sessões, conflito stale e replay sem duplicar auditoria. Artifact13469938934 SHA256 dce297835c51a33316c5e0f9253706bff7c24030c0ef27bc352171c58dc09c77.
Revisão independente: corrigidos catálogo/políticas incoerentes e INSERT de contrato. RPCs legadas não têm EXECUTE anon/authenticated, confirmado em SQL, portanto achado condicional de bypass não se aplica. Nenhum grant foi ampliado nesses endpoints.
Erro canônico de reanálise preservado sem relaxar testes.
Migration supabase/migrations/20261106014102_p0_v1_rbac_persistente.sql SHA256 99f51e2d9d57d5d340144d14305714307be642bec83245d73b427d2b17c2b36d.
Deploy automático somente no push deste workflow após PR/CI/merge, com versão e hash fixos, checagem dos3gates do SHA aprovado. O canal continua sendo o workflow canônico deploy_one; nenhuma DDL direta/API.
Pré-check exatamente1pendente,nenhum histórico órfão; CLI2.81.3 db push; pós-check registro único e paridade global.
Correção no pós-check: não utilizar constante1/0 em CASE, que pode ser avaliada pelo otimizador mesmo no ramo não escolhido.
PROD proibida. Nenhuma configuração Auth/secret alterada. Deploy não certifica JWT/Edge/frontend/V1.
Próximo: verificação SQL/advisors, novas fixtures JWT com escopo próprio, corrigir guard de storage-sign-upload, integrar frontend e demais pendências do plano único.
## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Sem UI; Brand preservada; ferramentas diretas. Sem redução de gates ou novo custo.
