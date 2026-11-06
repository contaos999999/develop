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

## Atualização comprovada da rodada JWT e quarentena

Esta seção substitui somente o estado operacional provisório acima. A análise estrutural das nove funções continua insuficiente para sua certificação funcional.

- Probe aprovado no PR #80, HEAD 2c52101b4594aa816987f2326f0e289b4524b172; CI 42150663608.
- Matriz: 120 verificações iniciais aprovadas; concorrência de dois escritores, conflito de versão, replay, payload divergente, revogação com o mesmo JWT e restauração aprovados. Interrupção proposital após commit também restaurou e conferiu o valor original.
- Comparação final das 480 permissões via RPC MASTER: igualdade integral com a captura anterior; versão 5; estado de restauração dirty=false.
- Primeiro teste Edge: MASTER, administrador e leitor receberam HTTP 500. Causa reproduzida: PostgREST fornece thenable sem método catch. O mock anterior usava Promise completa. Falhas preservadas, sem apagamento de evidência.
- Correção PR #82: HEAD a551d686b88b4e684f0edfe0e361f5bbf767ac3a; CI 42153421502 SUCCESS; merge 4c21fe2961f54218891e1f1edf25ef5e21137106. Testes com thenable realista: 8 RED antes, 8 GREEN depois.
- Implantação Edge versão 6 ACTIVE, verify_jwt=true. Fonte retornada pelo HML idêntica à fonte aprovada; ezbr SHA256 1562cdc549369430bcbd53d7474619d167443a4fc6d7bfd303b88ba29caff880.
- Reteste JWT Edge: MASTER e administrador HTTP 200; leitor e sem vínculo negados sem URL/token. Somente assinatura testada; nenhum blob enviado e nenhum worker certificado.
- Revogação de vínculo contabilidade: mesmo JWT negado HTTP 403/42501.
- Logout: 14 respostas HTTP 204; JWT MASTER anterior rejeitado pela RPC com HTTP 403/42501.
- Registro integral: 152 tentativas, 149 aprovadas e 3 falhas históricas corrigidas. Resultado mais recente por nome: 147/147 cenários distintos aprovados. Nome de restauração repetido em duas fases; não inflar quantidade de cenários.
- SHA256 do relatório local sanitizado: 93efe4d243330f94033570efdcb90d7b0b63ad817af263476e5dedf2855d0f9c. Credenciais e tokens não integram este documento.

### Quarentena e conferência independente

DML limitado aos 14 UUIDs próprios, metadado scope=P0-RBAC-BUILD, duas organizações e três contratos sintéticos. Senhas invalidadas, contas bloqueadas por 100 anos, concessão MASTER e vínculos desativados, organizações inativas, auditoria preservada. Nenhuma exclusão de conta.

| Verificação | Resultado |
|---|---:|
| Contas sintéticas bloqueadas | 14 |
| Sessões persistidas | 0 |
| MASTER sintético ativo | 0 |
| Vínculos ativos | 0 |
| Escopos contratuais ativos | 0 |
| Organizações sintéticas inativas | 2 |

Consulta independente após a transação repetiu 14 bloqueadas / 0 sessões / 0 MASTER / 0 vínculos. A matriz já estava restaurada antes do logout e bloqueio.

### Última etapa e continuidade

Última etapa comprovada: matriz persistente implantada, rodada JWT da matriz/isolamento/assinador/revogação encerrada e quarentena conferida. Próxima tarefa: regressão funcional das nove RPCs sob as novas restrições RBAC, seguida da integração frontend da matriz e navegação; SYS-03, WCAG/Teste C privado, RNFs e reconciliação dos critérios continuam no plano único. A recuperação dos DOCX originais confirmou 486 critérios literais V1, preservando os 488 registros históricos para análise do diferencial, sem dispensar obrigações de outras fontes.

Frontend de referência: be842a39a413c8ef53c71412ff83be3b0a49b8a9; baseline local 35 suites/886 testes aprovados antes de alterações, tipos congelados preservados. V1 NÃO CERTIFICADA; V2 bloqueada; PROD intacta.
