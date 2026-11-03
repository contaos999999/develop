# PLAN técnico backend — Prompt 38 / V1-17 Requisito: detalhe e evidências

Data: 03/11/2026
Status: PLANO, NÃO BUILD
Ambiente alvo: somente HML `gklhhhyosgasnyoxlrui`
Repositório de governança: `contaos9999/develop`
Fonte: `docs/backend/V117_DIAGNOSTICO_LACUNAS_REQUISITO_2026-11-03.md`
Referência frontend certificada: `d4b9b77dafa7ff6ca7644a99fee737bfed590a1e`; `main` restaurada `d7a418bbd96f065c839191ae03b2f2b818d649b8` (zero diff funcional).

## Gate zero-drift
**Não executar este plano enquanto `active-task.json.database_changes_allowed` for `false`.**
Somente a extensão de leitura listada abaixo poderá ser autorizada na Fase B1. RLS, Auth, Storage, Edge e PROD permanecem proibidos. A Fase B2 exige gate/manifesto próprio para o ajuste transacional.

## Fase B1 — Contrato de leitura V1-17 (única mudança conceitual)
Adicionar exclusivamente nova RPC pública:
`public.obter_detalhe_requisito_v117(p_id_competencia uuid, p_id_requisito uuid, p_evidencias_offset integer default 0, p_evidencias_limite integer default 25, p_historico_offset integer default 0, p_historico_limite integer default 25, p_apontamentos_offset integer default 0, p_apontamentos_limite integer default 25) returns jsonb`.

### Segurança e escopo
1. `STABLE SECURITY DEFINER SET search_path=''`; nomes de tabelas/funções totalmente qualificados. `REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon`; `GRANT EXECUTE ... TO authenticated`. Conferir `has_function_privilege`.
2. Validar UUIDs não nulos e offsets/limites (offset >=0, limite entre 1 e 100): `PT400` em parâmetros inválidos.
3. Buscar competência e requisito sob vínculo simultâneo `id_competencia`, `id_organizacao`, `id_contrato`; nenhum acesso por ID arbitrário. Competência/requisito inexistentes: `PT404` genérico que não revela tenant.
4. Autorização explícita: `auth.uid()` real + `privado.usuario_tem_acesso_contrato` + `privado.usuario_possui_perfil` no mesmo conjunto read V1-16 certificado; sem JWT `user_metadata` nem organização selecionada como prova.
5. Sem UPDATE/INSERT/DELETE nem mutation genérica; não expor `execucoes_analise.erro_detalhe`, URL privada nem secrets.

### Resposta `schema_versao='v117-v1'`
- `competencia`: ids, referência e situação do backend.
- `requisito`: snapshot `id,codigo,descricao,categoria,origem_tipo,origem_id,origem_versao,obrigatorio,aplicavel,impeditivo,criticidade,fonte_tipo,fonte_referencia,fonte_detalhe,efeito_portao,hash_snapshot,regra_validacao,condicao_aplicabilidade`.
- `execucao_atual`: última execução da competência por `criado_em desc,id desc`, com id, tipo/status, hash, modelo, versão de motor/prompt, horários e metadados seguros; null quando ausente.
- `resultado_atual`: somente resultado desse requisito nessa última execução, ou null (sem resultado). Campos `resultado,mecanismo,confianca,justificativa,fundamento,hash_evidencias,criado_em`. Mecanismo deve reproduzir EXATAMENTE a prioridade backend V1-16 (humano explícito, metadados explícitos, provedor explícito, senão `nao_identificado`); nunca inferir determinístico.
- `na_validade`: indicador autoritativo calculado no servidor somente para `nao_aplicavel`, preservando a regra do `privado.avaliar_portao_conformidade`: resultado aplicável mais recente com fundamento preenchido e evidência registrada. Incluir `id_resultado_referencia` e esclarecer se difere do resultado da execução corrente. Para não aplicável não selecionado: null.
- `evidencias`: da execução corrente, vinculadas ao resultado e ao requisito, com `id,id_versao_documento,pagina,trecho,tipo_evidencia,referencia_externa,hash,criado_em` e documento apenas se houver vínculo autorizado e verificável: `id_arquivo` via `versoes_documento` com mesmo contrato/organização, `numero_versao` e status seguro. Não fornecer signed URL; `storage-sign-download` autoriza em nova chamada de usuário.
- `evidencias_paginacao` (offset/limite/total): contagem e página server-side para evitar truncamento.
- `historico`: resultados por requisito de TODAS as execuções do mesmo contrato/competência, páginas 25, por data/id decrescentes, com id do resultado/execução, tipo, mecanismo, status, fundamento/justificativa e hashes/modelos/horários fornecidos. Preservar os resultados anteriores e não misturá-los com o atual.
- `historico_paginacao` (offset/limite/total).
- `apontamentos` do requisito: id, severidade, status, origem, regra violada, ação, fonte, criação; `apontamentos_paginacao`.
- `allowed_actions`: capacidades backend-only; leitura e disponibilidade de documento separadas do controle de reanálise incremental. Não liberar ação simplesmente porque o usuário tem o UUID.

### Não aplicar a regra N/A no React
A RPC pode utilizar os mesmos dados e predicado do portão atual, mas precisa de testes demonstrando que N/A válido/inválido do drawer corresponde à avaliação `privado.avaliar_portao_conformidade`. A leitura deverá distinguir resultado atual de resultado mais recente usado pelo portão para não sugerir equivalência falsa quando existirem várias execuções.

### Fonte e download
O frontend já tem `baixarDocumento(idArquivo)` em `src/lib/contratos/documentosDados.ts`, que envia `{id_arquivo}` à Edge certificada `storage-sign-download`, só abre URL assinada HTTPS. Na RPC, `id_versao_documento` por si só NÃO é `id_arquivo`. Resolver via `versoes_documento(id,id_arquivo,numero_versao,id_organizacao,id_contrato)` com joins de escopo. Zero `getPublicUrl`, bucket público ou URL persistida.

### Gate de SQL, migração e teste
- Antes da escrita: revisar a definição de V1-16, constraints e joins, executar `supabase migration new` em ambiente capaz de fazê-lo ou equivalente autorizado do pipeline; usar UMA migration NOVA, imutável, e versioná-la no GitHub. Não modificar migration aplicada.
- TDD com testes negativos e cenários read: sem sessão 42501; outro tenant/contrato 42501 ou PT404 sem vazamento; competência/requisito trocado PT404; offsets inválidos PT400; 0 resultados; N/A válido/inválido; mecanismo explícito/sem origem; documento com versão em outro contrato não vincula; evidência sem versão não gera ação download; histórico com duas execuções em ordem correta; duas páginas; sem erro_detalhe/sem URL pública.
- Executar em HML com sessão real e fixtures sob `BEGIN/ROLLBACK`; assegurar zero resíduos; checar RLS e grants, `EXPLAIN` sobre queries por requisito, indexes existentes antes de adicionar índice.
- CI Histórico HML, Zero-Drift, Restore Isolado e scan security; certificar o fingerprint e os SHAs reais. PROD intocado.
- Só então declarar `BACKEND V1-17 READ CERTIFICADO` e mudar fase da tarefa para frontend_plan.

## Fase B2 — Reanálise incremental, autorização SEPARADA
Problema comprovado: `privado.solicitar_analise_competencia(...,'parcial')` usa `SELECT ... FOR UPDATE` na competência e devolve UUID pendente/processando existente. `privado.solicitar_reanalise_requisitos` faz depois `UPDATE execucoes_analise SET requisitos_afetados=p_requisitos`, inclusive quando o UUID já existia. Nova seleção pode sobrescrever o escopo de um job em andamento.

Correção mínima a planejar e provar numa migration DIFERENTE:
1. Adquirir lock na competência ANTES de consultar execução pendente; validar sessão, tenant, perfil, situação, cardinalidade e pertinência de TODOS os UUIDs.
2. Se houver job pendente/processando, distinguir repetição EXATAMENTE idempotente da mesma seleção parcial (retornar mesmo UUID sem UPDATE) de seleção diferente/outro tipo (erro de conflito sanitizável `PT409`; não mudar job).
3. Se não houver, chamar RPC privada global `'parcial'` sob mesmo lock e gravar `requisitos_afetados` SOMENTE no novo job antes do commit; provar que worker não executa antes do commit e respeita o conjunto afetado.
4. Preservar histórico; nunca modificar execução concluída ou mudar requisitos de job já aceito. Não afrouxar RLS ou perfil.
5. Testar duas sessões concorrentes, seleções iguais/diferentes e global versus parcial, idempotência, atualização exata, erro/timeout com uma leitura sem retry de escrita, DLQ/retry worker e histórico.
6. Somente depois de B2 certificada, V1-17 pode expor a seleção incremental sob `allowed_actions` do backend. Se não demonstrado, manter botão desabilitado informando indisponibilidade; não prometer processamento parcial inexistente.

## Lovable PLAN futuro (após backend certificado)
- Nenhuma rota nova: drawer aberto a partir da tabela de requisitos de V1-16.
- Componentes: RequirementDrawer, SourceReference, EvidenceList, ResultBadge, AuditTimeline.
- Gate sessão/competência/requisito, leitura agregada V1-17, estado preso aos dois UUIDs, abort e reset A→B; parser fail-closed, mensagens PT-BR.
- Exibir snapshots, NA válido/inválido, mecanismo/criticidade/evidência/histórico conforme backend, sem regra local.
- Reutilizar `baixarDocumento` e tratamento de erro V1-10; impedir URL pública ou download de versão sem vínculo.
- Abertura de requisito V1-16 só habilitada depois de V1-17 GREEN; V1-18/19 staged.
- TDD RED/GREEN, suíte regressiva V1-16 (126/126), full serial (739/739 baseline), lint, scans, TypeScript/build, 8 visuais em claro/escuro, Teste C read-only separado, types blob idêntico, Zero-Drift.

## Proibido nesta etapa
Sem migrations aplicadas, sem DDL, sem RLS/Auth/Edge/Storage, sem alterações frontend, sem mutação em PROD. Este documento registra o PLAN para posterior autorização delimitada, não afirma execução nem certificação.
