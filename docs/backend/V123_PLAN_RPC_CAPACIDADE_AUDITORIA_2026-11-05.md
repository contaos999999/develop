# PLAN P0 V1-23 — RPC de capacidade de consulta à Auditoria (somente planejamento)
Data: 05/11/2026. Decisão do titular: **Opção A, planejar ampliação do backend**, sem autorização para BUILD/DDL. Status: **PROPOSTO / NO-GO BUILD**.

## Contexto canônico e escopo
Pacote 4.1, 25 documentos canônicos 00–20 incluindo 08A–08D conferidos em main nesta etapa. Escopo V1-23, trilha de auditoria e autorização por organização; prioridade V1 antes de V2–V5. Não renumerar prompts 00–99 e atômicos 000–096. Backend certificado HML: projeto `gklhhhyosgasnyoxlrui`. Frontend: `contaos999999/contaos-hml-control`. **Não alterar PROD.**

**Lacuna verificada por leitura SQL HML:** `public.eventos_auditoria` possui RLS e política `eventos_select` que autoriza perfis `administrador`, `auditor` e `juridico_conformidade` via `privado.usuario_possui_perfil(id_organizacao,text[])`. A RPC pública `validar_administrador_organizacao(uuid)` verifica somente administrador. Não foi identificada RPC pública específica para capacidade de leitura de Auditoria. O menu atual exige retorno administrativo para exibir o link Auditoria. Esta é lacuna de contrato de navegação, não prova de acesso indevido a dados.

## Proposta de contrato mínimo, sujeita a validação
Criar por migration **nova e imutável**, em tarefa backend específica, `public.pode_consultar_auditoria_organizacao(p_id_organizacao uuid) returns boolean`. Corpo somente leitura, sem dados pessoais, consulta `privado.usuario_possui_perfil(p_id_organizacao,array['administrador','auditor','juridico_conformidade']::text[])`. Nulo ou ausência de sessão/vínculo devem resultar `false` (fail-closed); avaliar tratamento de erro SQL sem mascarar indisponibilidade operacional. `SECURITY INVOKER` com invocação de helper privado protegido ou desenho mínimo equivalente após conferir GRANT e segurança. `SET search_path = ''`, referências qualificadas, `STABLE`, revogar EXECUTE de PUBLIC e anon, conceder somente authenticated. **Não expor schema privado, não ampliar RLS, não criar tabela, não retornar dados de auditoria na RPC.** A autorização de dados continua exclusivamente na RLS. Verificar que chamadas por anon não podem invocar a função via Data API.

## Matriz de compatibilidade FE ↔ BE
| Requisito | Backend existente | Lacuna | Gate |
| --- | --- | --- | --- |
| Administrador acessa gestão de usuários | `public.validar_administrador_organizacao` | Nenhuma identificada | Verificar E2E |
| Administrador/auditor/jurídico consultam eventos da própria organização | `eventos_select` e `privado.usuario_possui_perfil` | Sem RPC pública de capacidade para menu | NO-GO até RPC |
| Outros perfis não consultam auditoria | RLS `eventos_select` | Teste autenticado negativo pendente | NÃO VERIFICADO |
| Usuário A não consulta organização B | RLS com vínculo ativo e sessão | Teste A/B real nesta alteração pendente | NÃO VERIFICADO |
| Sidebar separa Usuários e Auditoria | AppShell frontend | Depende do novo contrato backend | NO-GO frontend |

## PLAN → GATE → BUILD → TESTE
1. Antes de BUILD, abrir manifesto backend dedicado sem sobrescrever silenciosamente a tarefa ativa `RNF-AUD-001-STATIC-20261104`, cujo `database_changes_allowed=false` e `supabase/**` é proibido. Reconciliar eventual trabalho concorrente e solicitar autorização específica para DDL se exigida pela política do manifesto.
2. Confirmar HEAD do `develop`, migrations atuais, assinaturas/grants, ausência de nome conflitante, estado HML e 25 documentos; congelar allowlist de **um arquivo migration novo**, manifesto e testes pertinentes, com SHA do contexto e impacto de segurança.
3. Testes TDD: anônimo negado; sem sessão false; admin master true; administrador org true; auditor true; juridico_conformidade true; perfil comum false; vínculo expirado/inativo false; org B false; UUID nulo false; erros de grants fail-closed; RLS de `eventos_auditoria` inalterada; restore limpo e regressão de 96 requisitos.
4. Migration idempotente conforme convenção do projeto e revisão de `SECURITY DEFINER/INVOKER`, grants e search_path. Não editar migration aplicada.
5. CI backend Zero-Drift, Architecture Guard, secret scan, testes A/B com JWT autenticado HML, restore isolado e evidências permanentes. Somente depois permitir PLAN frontend separado e implementação tipada com estados de carregamento, falha fechada e invalidação ao trocar sessão/organização.
6. Rollback por **nova migration de reversão**, sem apagar histórico; verificar frontend consumidor antes de revogar RPC. Não executar rollback destrutivo ad hoc.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual backend: **N/A**; esta tarefa não modifica marca, componentes, CSS, rotas ou identidade. Economia Lovable: implementação backend diretamente por GitHub/Supabase, sem gerar telas no Lovable; nenhum atalho em segurança, testes ou documentação.

## Condições de aceite
**PLAN:** evidências de 25 fontes e SHA, manifesto backend dedicado aprovado, gates e CI de planejamento, aprovação de escopo de DDL, rollback e testes definidos. **BUILD:** migration aplicada e sincronizada Git/HML, perfis e isolamento A/B comprovados, CI e restore verdes, sem mudanças em PROD. **Frontend:** contrato HML comprovado antes de validar PLAN/BUILD; não inferir permissão de sessionStorage.

**Situação desta proposta:** somente planejamento. Nenhuma migration executada, nenhuma nova RPC implantada, V1 não certificada.

## Gate de escopo atualizado
PR #40 integrou o caminho deste documento à allowlist do manifesto, com CI 42008835804 SUCCESS. Esta atualização de documentação força reexecução dos checks sobre o estado vigente da main; não concede permissão de DDL nem altera a tarefa RNF.

## Evidência de execução parcial (05/11/2026)
- PR #42: manifesto V123 ativado, CI 42009509252 SUCCESS.
- PR #43: migration e teste integrados, CI 42009775650 e 42009775526 SUCCESS; merge `0d0670bbe746774a81e4aa3b7eb61ad8a20d2a32`.
- Supabase HML `gklhhhyosgasnyoxlrui`: aplicação da RPC retornou `success=true`. Catálogo confirma `SECURITY INVOKER`, `STABLE`, search_path vazio, anon EXECUTE=false, authenticated EXECUTE=true; sem sessão e com UUID nulo retornou false.
- **Divergência de histórico a resolver antes da certificação:** conector Supabase registrou versão aplicada `20261105102019_v123_auditoria_capacidade`, mas arquivo versionado em Git é `20261105120000_v123_auditoria_capacidade.sql`. Não alterar histórico aplicado nem declarar sincronização até conciliação segura via gate específico; manter SQL da função sem reaplicar.
- Teste SQL inicial falhou apenas na asserção da serialização de `search_path` (PostgreSQL retornou `search_path=""`); correção em PR separado para aceitar ambas representações. **Reexecutar o teste e registrar resultado.**
- Testes JWT reais de perfis, isolamento A/B, restore isolado e regressão canônica permanecem **PENDENTES**. Nenhum PASS ou certificação V1 declarado.

## Evidências adicionais de verificação (05/11/2026)
- PR #44 integrado, CI `42010044037` SUCCESS. Teste `supabase/tests/v123_auditoria_capacidade.sql` executado no HML após correção: **PASS** (DO sem exceções).
- Teste SQL em transação `BEGIN; SET LOCAL ROLE authenticated; SELECT public.pode_consultar_auditoria_organizacao('00000000-0000-0000-0000-000000000001'::uuid); ROLLBACK;`: resultado **false** sem JWT.
- Consulta de leitura em `supabase_migrations.schema_migrations` confirmou `version=20261105102019`, `name=v123_auditoria_capacidade` e o SQL original da migration aplicada; arquivo Git atual tem prefixo `20261105120000`. **Divergência nominal ainda aberta**: propor reconciliação por PR específico que alinhe o arquivo versionado ao identificador aplicado, com prévia verificação de CI/restore e sem modificar diretamente a tabela de histórico do Supabase. Não duplicar DDL nem editar migration já aplicada no banco.
- Teste estrutural não substitui testes com JWT reais de perfis (master, admin, auditor, jurídico, comum) e isolamento A/B, nem restore limpo. **Certificação pendente.**

## Matriz simulada de autorização HML (05/11/2026)
Executada consulta SQL de leitura, sem persistir dados, com dez linhas `VALUES` e a mesma conjunção de condições de `privado.usuario_possui_perfil`: sessão ativa, perfil permitido, vínculo ativo, vigência e correspondência da organização.
- 10/10 casos com resultado esperado: administrador A, auditor A, jurídico A = permitido; usuário comum, auditor A→B, auditor B→A, inativo, expirado, futuro e sem sessão = negado.
- **Escopo de evidência: simulação lógica**, não chamadas RPC autenticadas, não RLS com JWT real e não teste end-to-end de isolamento A/B.
- O teste SQL estrutural real da RPC e o caso authenticated sem JWT foram aprovados separadamente.
- Não houve INSERT/UPDATE/DELETE nem modificação de AUTH, RLS ou PROD.
- Gates ainda pendentes: JWT/sessões reais para cada perfil, RLS de eventos_auditoria, restore isolado e regressão. **Não certificar V1/V1-23 integralmente.**
