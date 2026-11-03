# V1-17 / Prompt 38 — Diagnóstico de lacunas backend (HML)

Data: 03/11/2026
Projeto: ContaOS 4.1
Ambiente: Supabase HML `gklhhhyosgasnyoxlrui`
Status: DIAGNÓSTICO DOCUMENTADO; IMPLEMENTAÇÃO AINDA NÃO AUTORIZADA NESTA FASE
PROD: intocado

## 1. Fonte e objetivo
- `06_FRONTEND_LOVABLE_ESPECIFICACAO_4_1.md`: tela V1-17 = Requisito — detalhe/evidências.
- Manual original `FE_v3_DOWNLOAD(2).docx`, capítulo V1-17 (página textual 66): drawer, não rota nova; componentes RequirementDrawer, SourceReference, EvidenceList, ResultBadge e AuditTimeline. Estados loading, sem resultado, conforme, não conforme, N/A válido/inválido e inconclusivo. Ações abrir evidência e baixar documento autorizado. Somente leitura salvo ação existente; nenhuma mutação genérica de resultado.
- `08A_REQUISITOS_001_024_4_1.md`: V1-CHK-001..004, V1-AUD-002..005. V1-AUD-005 exige reanálise incremental sem apagar o histórico.
- `09_RASTREABILIDADE_FONTES_AUDITORIA_4_1.md`: fonte/versionamento/localização/hash rastreáveis.
- V1-16 funcional auditada: `d4b9b77dafa7ff6ca7644a99fee737bfed590a1e`; main posterior `d7a418bbd96f065c839191ae03b2f2b818d649b8` com ZERO arquivos diferentes do SHA auditado (GitHub compare).
- Supabase `types.ts` SHA de conteúdo protegido: `8ea7750b75fd9d76b29c36ce7613392e3ab65e19`.

## 2. Inventário read-only HML realizado
O catálogo `pg_proc` consultado na data acima confirmou:
- `public.obter_analise_competencia_v116`: leitura agregada paginada da competência; NÃO seleciona arbitrariamente o detalhe/histórico completo de um requisito fora da página de resultados.
- `public.obter_documentos_competencia_v115`: leitura documental da competência, não da evidência/resultado individual.
- Não há `public.obter_detalhe_requisito_v117` nem leitura equivalente específica para o drawer nos endpoints `obter_*` existentes examinados.
- `public.solicitar_reanalise_requisitos(uuid,uuid[])`: escrita incremental oficial, autenticado EXECUTE=true, anon=false, delegando a `privado.solicitar_reanalise_requisitos`.
- `public.requisitos_competencia`, `resultados_requisitos`, `evidencias_resultado`, `apontamentos_internos`, `execucoes_analise` e `acoes_corretivas`: RLS=true e authenticated SELECT=true. Isso, isoladamente, NÃO equivale a contrato agregado seguro e não autoriza N+1 no frontend.
- V1-16 `obter_analise_competencia_v116` faz `auth.uid()`, `privado.usuario_tem_acesso_contrato` e verificação de perfil antes de ler dados; preservar esse padrão em nova leitura, sem copiar segurança para o frontend.

## 3. Lacuna L1 — Leitura detalhada autoritativa
A V1-17 precisa de:
1. requisito do snapshot, código, descrição, origem, regra de validação, obrigatoriedade, aplicabilidade, criticidade, fonte e versão;
2. resultado da execução corrente e estado SEM resultado, mecanismo explícito, confiança, justificativa e fundamento;
3. evidências com `id_versao_documento`, página, trecho, tipo, referência, hash, data e metadados de origem autorizada;
4. histórico do requisito entre execuções, sem substituir/apagar resultados anteriores; paginação server-side;
5. apontamentos do requisito pertinentes, com origem/fonte, quando aplicáveis;
6. validade de `não aplicável` devolvida pelo backend, NUNCA calculada em React;
7. acesso, capacidade de abrir/baixar evidência e ações críticas determinados pelo backend.

Proposta sujeita a PLAN/backend: uma RPC READ-ONLY `public.obter_detalhe_requisito_v117(p_id_competencia uuid,p_id_requisito uuid, ... paginações ...)` com resposta versionada `v117-v1`. O contrato concreto, filtros, limites, GRANT e SQL ainda exigem especificação, testes e certificação antes de BUILD Lovable. Não criar outra fonte de verdade nem alterar V1-16.

## 4. Lacuna L2 — validade de N/A
O HML `privado.avaliar_portao_conformidade` considera `nao_aplicavel` válido SOMENTE quando o último resultado do requisito possui `fundamento` não vazio E existe ao menos uma `evidencias_resultado` vinculada. O drawer deve receber do backend resultado explícito dessa regra e sua proveniência, não duplicar a condição no cliente. Necessário conferir se a execução exibida é a última global utilizada pelo portão.

## 5. Risco R1 — reanálise incremental e concorrência
A função `privado.solicitar_reanalise_requisitos` hoje:
- valida sessão/contrato/perfil e que os UUIDs selecionados pertencem à competência;
- chama `privado.solicitar_analise_competencia(...,'parcial')`;
- em seguida executa `UPDATE public.execucoes_analise SET requisitos_afetados=p_requisitos, metadados=metadados||{'reanálise_incremental':true} WHERE id=v_exec`.

A função global pode retornar UUID já em andamento. Portanto é necessária prova de concorrência/idempotência para garantir que chamadas concomitantes ou seleções diferentes não sobrescrevam `requisitos_afetados` de execução existente, não alterem histórico concluído e não iniciem processamento inconsistente. **Não habilitar a ação incremental na V1-17 antes dessa prova e eventual correção especificamente autorizada.** O diagnóstico não conclui que uma vulnerabilidade foi explorada.

## 6. Evidência/download
O fluxo oficial V1-10/V1-15 usa Storage privado e `storage-sign-download`; a V1-17 deve reutilizar a autorização e o helper certificado quando possível. `id_versao_documento` não implica URL pública. Não criar `getPublicUrl`, URL permanente, endpoint paralelo ou adivinhar vínculo arquivo/versão.

## 7. Critérios de certificação backend V1-17
- contrato READ versionado, sem regras de resultado/status/portão no cliente;
- tenant A/B e perfil: acesso somente a requisitos da própria competência e contrato; UUID inexistente ou cruzado sem vazamento; anon não executa;
- fonte/versão/hash/página/trecho fieis ao banco, N/A válido/inválido provado;
- sem resultado e históricos/offsets com resposta determinística; sem N+1;
- evidência/documento autorizado, bucket privado;
- reanálise: autorização, IDs explícitos, zero seleção vazia, concorrência, sem sobrescrever job existente/histórico, sem retry automático;
- testes HML em transação com rollback e prova de zero fixtures residuais;
- migration nova e imutável se aprovada; GitHub, HML migration, CI Zero-Drift/Restore/Histórico certificados antes de frontend BUILD;
- PROD intocado.

## 8. Decisão de escopo atual
**FASE ATUAL = BACKEND_GAP_ANALYSIS**. Somente documentação/inspeção read-only HML e governança autorizadas. Nenhuma migration, RPC, tabela, RLS, Edge, Auth, Storage ou código frontend alterados nesta fase. Próximo gate: PLAN da menor extensão backend necessária; aprovação e autorização específicas em active-task antes de DDL. Só após certificação, PLAN Lovable do V1-17 e eventual gate humano obrigatório.
