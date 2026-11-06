# GATE de provas JWT e autorização de upload RBAC V1

Autorização: plano único PR #76 e solicitação expressa “Execute integralmente”. Ambiente exclusivo HML, projeto gklhhhyosgasnyoxlrui. PROD proibida.

## Evidências anteriores preservadas

O PR #77 integrou o BUILD da matriz. O PR #79 recuperou as fontes históricas e foi integrado em eb3e2a54804aa6f4406337644bcbe0d8770e0d20.

O restore 42149472852 passou nas 13 suítes e na comparação estrutural com o HML. O deploy canônico 42149828772 passou: 126 versões em paridade, somente a migração RBAC aplicada, sem repair nem reaplicação de DDL legado.

A consulta posterior confirmou quatro tabelas privadas com RLS e sem grants diretos de SELECT/UPDATE para clientes, 48 ações, 480 permissões, 71 políticas adicionais e versão inicial 1 da matriz. O Advisor foi capturado; sua revisão final continua pendente. Os avisos de tabelas privadas com RLS sem policy correspondem à negação direta prevista.

## Correção do assinador de upload

A fonte implantada de storage-sign-upload, versão 4 e verify_jwt=true, é idêntica à fonte anterior do GitHub. Ela validava organização e contrato, mas ainda não consultava a matriz antes de emitir a autorização de upload pelo cliente privilegiado.

O delta consulta consultar_permissoes_efetivas com organização, contrato e JWT do solicitante. A assinatura exige arquivos/criar. Erro de transporte, erro do backend, resposta malformada ou permissão ausente resultam em HTTP 403 antes da assinatura. A resposta de negação não contém URL nem token.

TDD local no handler real, com transporte Supabase substituído: cinco negativas falharam antes da correção. Após a correção e ampliação da cobertura, oito testes passaram. A suíte verifica também o contrato exato e o uso do cliente público com o JWT do solicitante. Isso não é prova de JWT ou upload real. O teste usa stripTypeScriptTypes experimental do Node 22; não altera o runtime de produção.

Somente esta Edge Function pode ser implantada, após CI aprovado, mantendo verify_jwt=true. Nenhum outro Edge, bucket, worker, Cron ou configuração Auth pode mudar. A fonte anterior está preservada para reversão, sem declarar RBAC concluído caso uma reversão reabra a lacuna.

## Provas reais autorizadas

O probe supabase/tests/rbac_jwt_probe.py prepara 14 contas sintéticas novas: dez perfis, MASTER sem vínculo, usuário sem vínculo, gestor restrito e leitor da organização B. Todas têm user_metadata forjada com master=true, para comprovar que esse campo não concede privilégio global.

As fixtures incluem duas organizações e três contratos próprios A1/A2/B1. Nenhuma conta banida anterior será reutilizada. A preparação exige Python 3.12 com bcrypt do sistema pelo módulo crypt. O SQL contém somente hashes de senha. CONTAOS_TEST_PRIVATE_DIR é obrigatório e deve ficar fora do checkout; arquivos privados usam permissões 0700/0600.

Cobertura: login e identidade Auth reais; edição e leitura exclusiva MASTER; permissões contextuais; RLS direta; isolamento A/B nos dois sentidos; contrato restrito; anônimo e JWT inválido; concorrência otimista por HTTP; replay; payload divergente; revogação de vínculo/sessão; autorização e negação do assinador Edge.

## Proteção da alteração temporária da matriz

A única combinação alterada será leitor/contratos/consultar. Antes de cada fase de mutação, uma consulta SQL deve confirmar zero vínculos leitor ativos externos às fixtures.

A evidência matrix-preflight.json deve registrar o scope, o hash dos IDs das 14 fixtures, a contagem externa zero e a data UTC. O probe exige correspondência e validade de até 120 segundos. Nenhuma mutação global ocorre se o baseline tiver falhas.

O estado de restauração pendente é persistido antes da primeira chamada e contém o valor original e os request IDs. A restauração roda em finally, inclusive após interrupção provocada depois de um commit. Se houver alteração de origem incerta, o probe não a sobrescreve. O valor original precisa ser conferido por nova leitura; somente então dirty=false é registrado.

Logout e quarentena ficam bloqueados enquanto a restauração estiver pendente. Em caso de interrupção do processo, executar o modo restore antes de continuar. O ensaio de interrupção pode gerar mais dois eventos próprios; todos permanecem auditáveis.

## Limpeza e limites

Após as provas: restaurar e conferir a matriz, encerrar sessões, revogar a concessão MASTER sintética, inativar vínculos e organizações, bloquear as 14 contas e invalidar suas senhas por IDs e scope exatos. Verificar zero sessões e zero privilégios ativos. Preservar auditoria; não declarar DELETE.

Nenhum arquivo será enviado e nenhum worker será certificado por este escopo. As nove funções preexistentes e demais rotas afetadas continuam exigindo sua regressão pertinente. As 349 provas antigas não serão apresentadas como uma nova execução. V1 continua não certificada.

Sequência: CI, implantação Edge, pré-verificação, fixtures, JWT, SQL independente, restauração, quarentena e relatório. Depois, integração administrativa/sidebar e demais etapas do plano único: SYS-03, WCAG, RNFs e rastreabilidade.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Sem alteração visual, Brand ou tipos congelados. Ferramentas diretas, segurança e gates preservados, sem novo serviço pago.
