# P0 V1 — evidência parcial pós-deploy Edge e auditoria de funções privilegiadas

Data de verificação: 06/11/2026 (UTC). Ambiente exclusivamente HML `gklhhhyosgasnyoxlrui`.
Fonte de referência: `main` em `d44b0c88e69ff51493d2cb43af0fd16f18843f23`.
**Status: PROVAS EM ABERTO / V1 NÃO CERTIFICADA / V2 BLOQUEADA.** Nenhuma DDL, reparo de histórico, alteração em Auth, migração de schema ou modificação de produção foi executada nesta verificação.

## Gate histórico e CI

- Paridade das versões GitHub ↔ HML: `ContaOS HML migration version parity` run `42149828772`, **SUCCESS**; relatório canônico do projeto aponta **126/126** versões. O job também confirmou pré-check de migração única e pós-check de paridade. Não repetir o antigo reparo em massa.
- `ContaOS Zero-Drift` run `42150796524`, commit `d44b0c88`, **SUCCESS**.
- PR #80 já integrado ao `main`. O delta adicionou autorização RBAC `arquivos/criar` antes de solicitar uma URL de upload privilegiada.

## Edge Function conferida diretamente no HML

- `storage-sign-upload`: **ACTIVE**, versão **5**, `verify_jwt=true`.
- Fonte de `index.ts` instalada na Edge Function comparada integralmente à versão `main` do GitHub: **igualdade exata**, 6302 caracteres em ambas; blob GitHub `a3127b7e7160db431391e73258ba72df2ae62a6f`.
- A comparação de fontes e os testes locais do PR #80 **não** substituem HTTP real Auth/JWT nem demonstram envio físico, processamento por worker ou isolamento E2E de upload.

## RBAC e sessões em HML: leitura independente

Consulta SQL somente leitura confirmou:
- 48 pares recurso/ação, 480 permissões por perfil, 287 atualmente permitidas.
- `privado.rbac_versoes.versao = 5`; `leitor/contratos/consultar = true` no instante consultado.
- 52 políticas RLS do schema `public` referenciam `rbac_permite`. Esta contagem isolada não substitui análise semântica por operação.
- Para fixtures com `raw_user_meta_data.scope = 'P0-RBAC-BUILD'`: 14 contas ainda não bloqueadas, 14 sessões persistidas, 12 vínculos ativos e 1 concessão MASTER sintética. Outro lote histórico de 12 usuários bloqueados integra rodada anterior distinta.
- Existem 4 comandos de alteração de matriz registrados, com operação recente. Isso **não** constitui demonstração de limpeza concluída ou resultado PASS do probe.

**Contenção:** não executar segunda mutação concorrente da matriz, não remover fixtures, não revogar sessões e não reexecutar testes sobre essas identidades sem obter o estado privado de restauração e o resultado da rodada em curso. Respeitar o mecanismo `matrix-restore-state.json` e o escopo exato das fixtures, evitando efeitos sobre usuários reais.

## Nove funções SECURITY DEFINER: análise estrutural, não certificação funcional

O Advisor Supabase em 06/11 detectou nove funções públicas `SECURITY DEFINER` executáveis por `authenticated`. A consulta em `pg_proc` confirmou **9/9 sem EXECUTE para `anon`** e controles textuais de RBAC, sessão e escopo em cada fluxo, com ressalvas abaixo.

**Delegação a auxiliares privadas** (a função pública é um wrapper, e o corpo privado possui controles de RBAC/sessão/escopo e não oferece EXECUTE direto para `authenticated`):
- `adicionar_versao_documento_competencia_v115`
- `criar_documento_competencia_v115`
- `obter_documentos_competencia_v115`
- `obter_visao_geral_competencia`

**Controles no próprio corpo da função pública**, verificados por inspeção SQL de `pg_proc`:
- `enfileirar_ingestao_historica_hml`
- `obter_analise_competencia_v116`
- `obter_detalhe_requisito_v117`
- `registrar_relatorio_historico_hml`
- `vincular_tratamento_historico_hml`

A presença textual de predicados **não comprova** que toda via de execução negue acesso corretamente. Necessárias provas reais com JWT/perfis, tenant A/B, contrato A1/A2, recurso permitido/negado, sessão revogada e persistência sem efeitos nas negativas. Não revogar EXECUTE nem trocar SECURITY DEFINER por INVOKER cegamente: a API atual precisa dessas entradas e uma mudança sem estudo pode quebrar contratos. O alerta permanece aberto até regressão e justificativa formal por função.

O Advisor também informa 5 `INFO` de RLS sem policy em tabelas privadas, estado de negação direta deliberada, sujeito à confirmação das concessões. Proteção contra senhas vazadas aparece como aviso separado por limitação de plano, sem alteração nesta rodada.

## Próximos gates do plano único

1. Recuperar evidência e estado de restauração da rodada das 14 fixtures sem expor credenciais; concluir ou comprovar limpeza e quarentena exata, com zero sessões e privilégios sintéticos ativos. Se houver `dirty=true`, executar **restore do próprio escopo** antes de quaisquer testes adicionais.
2. Confrontar o relatório do probe `supabase/tests/rbac_jwt_probe.py` com cada cenário HTTP; documentar PASS/FAIL e evidências reais. Reexecutar somente cenários efetivamente afetados pela alteração do assinador Edge e pelos ajustes de matriz.
3. Testar funcionalmente as nove funções privilegiadas, sem extrapolar os testes estruturais. Preservar testes RLS/MASTER/autolock/488 critérios já aprovados, salvo mudanças que os afetem.
4. Fechar integração ADM-01/sidebar e requisito transversal BRAND/Menu da V1; concluir SYS-03 real, Teste C/WCAG, RNFs, evidências por critérios, upload e worker conforme as ressalvas oficiais.
5. Somente após provas completas, atualizar checkpoint com SHAs, CI, resultados, pendências e decisão fundamentada de certificação. **Nenhuma promoção da V2 ou produção** antes do gate V1.

## Rastreabilidade

- Planejamento: `docs/backend/P0_V1_FECHAMENTO_UNICO_EXECUCAO_2026-11-06.md`
- Teste e limpeza: `docs/backend/P0_V1_RBAC_JWT_EDGE_GATE_2026-11-06.md`
- Implementação: PR #80, `supabase/functions/storage-sign-upload/index.ts`
- Deploy/paridade: https://github.com/contaos999999/develop/actions/runs/42149828772
- Zero-Drift: https://github.com/contaos999999/develop/actions/runs/42150796524
- Advisor: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable

## ZERO-DRIFT — identidade visual e escopo

Registro somente documental, sem mudança visual, código, RLS, grants, Auth, Storage ou worker. Fonte canônica Brand 1.0 permanece obrigatória. Este relatório **não** declara aprovação de JWT real, quarentena, E2E ou certificação V1.
