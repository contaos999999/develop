# Certificação Backend — V1-16 Competência: Análise

Data: 03/11/2026
Ambiente: HML
Prompt: 37 / V1-16
Status: BACKEND READ CERTIFICADO
PROD: intocado

## Objetivo

Disponibilizar uma única leitura autoritativa e paginada para a tela V1-16 `/competencias/:id/analise`, sem reconstruir no frontend estado assíncrono, stale, portão, bloqueios, filtros ou permissões.

## Lacuna comprovada

O HML já possuía:
- `public.solicitar_analise_competencia`
- `public.solicitar_reanalise_requisitos`
- `public.registrar_resultado_requisito`
- `public.avaliar_portao_conformidade`
- `privado.hash_contexto_competencia`
- `execucoes_analise`, `resultados_requisitos`, `evidencias_resultado`, `apontamentos_internos`, `acoes_corretivas`

Não existia RPC/view agregada equivalente aos GETs exigidos pelo manual frontend para execução + requisitos/resultados. Consultas dispersas no React violariam a autoridade backend e criariam N+1/regras locais.

## Migration

Git:
- `supabase/migrations/20261103124500_v116_obter_analise_competencia.sql`
- commit inicial da migration: `a1536a20c4d6c5e2f9af53d0490e9b7177a70c11`

HML:
- `20261103135545 v116_obter_analise_competencia`

RPC pública:
- `public.obter_analise_competencia_v116(...) returns jsonb`
- `SECURITY DEFINER`, `search_path=''`
- EXECUTE: `authenticated=true`, `anon=false`
- leitura apenas; não cria resultados, não altera competência, portão, execução ou apontamentos.

## Contrato da resposta

`schema_versao = v116-v1`

A resposta contém:
- competência e contexto;
- `estado_analise`: `not_analyzed`, `queued`, `processing`, `failed`, `complete` ou `stale`;
- `stale` calculado no backend por `hash_contexto_competencia()` versus `execucoes_analise.hash_entrada`;
- `hash_contexto_atual` e metadados reproduzíveis da execução;
- `percentual` e `blocking_summary` vindos de `avaliar_portao_conformidade()`;
- `allowed_actions.executar_analise`, `reanalisar`, `abrir_requisito` definidos no backend;
- execução atual e histórico paginado;
- resultados da execução atual paginados, com requisito, criticidade, fonte, confiança, justificativa, fundamento e evidências agregadas;
- `mecanismo` por resultado: `deterministico`, `semantico`, `humano` ou `nao_identificado`, somente quando há marca objetiva; nunca infere determinístico por ausência de provedor;
- resumo de mecanismos;
- apontamentos internos paginados com severidade, status, regra violada, ação sugerida e fonte;
- filtros backend por resultado, criticidade, mecanismo, status do apontamento e busca textual.

## Autoridade e segurança

- Competência inexistente: `PT404`.
- Paginação/filtro inválido: `PT400`.
- Sessão/acesso/perfil insuficiente: `42501`.
- Acesso exige sessão ativa real e `usuario_tem_acesso_contrato`.
- Perfil de análise segue o mesmo conjunto já autorizado pelas operações de análise: administrador, gestor_contrato, prestacao_contas, financeiro, contabilidade, rh_dp, juridico_conformidade e auditor.
- `erro_detalhe` da execução não é exposto; somente `erro_codigo`.
- Nenhum dado de outro tenant é retornado.
- Nenhum EXECUTE para `anon`.

## Estado `stale`

O frontend não compara hashes. O backend retorna `stale=true` e `estado_analise='stale'` somente quando a execução mais recente está concluída e o `hash_entrada` está ausente ou diverge do hash do contexto atual.

## Separação de mecanismos

A arquitetura mantém `unique(execucao,requisito)` em `resultados_requisitos`; portanto a linha é o resultado consolidado por requisito.

A RPC identifica o mecanismo com precedência objetiva:
1. `metadados.origem='revisao_humana'` -> `humano`;
2. `metadados.mecanismo` explicitamente em `deterministico|semantico|humano` -> valor explícito;
3. provedor explicitamente registrado no resultado ou execução -> `semantico`;
4. caso contrário -> `nao_identificado`.

A RPC **não fabrica resultado determinístico**. A inexistência de um DSL formal suficiente para as seis camadas A–F foi registrada como ponto separado do contrato de leitura; qualquer evolução do worker deve preservar o resultado consolidado e registrar o mecanismo de forma explícita.

## Testes HML

Sessão real de homologação utilizada, com `session_id` ativo e vínculo `administrador` de organização. Todas as entidades de teste foram sintéticas e criadas dentro de `BEGIN/ROLLBACK`.

Bateria principal: `PASS_V116_READ`.
Cobertura:
- `not_analyzed`;
- `queued`;
- `processing`;
- `failed`;
- `complete` com hash atual;
- `stale` com hash divergente;
- `allowed_actions` para executar/reanalisar;
- paginação independente de resultados, execuções e apontamentos;
- histórico de duas execuções preservado;
- quatro mecanismos: semântico, humano, determinístico explícito e não identificado;
- evidência agregada com página/trecho/referência/hash;
- filtro por mecanismo;
- apontamento com criticidade/regra/ação/fonte;
- leitura não alterou contagens de competências, execuções ou resultados.

Bateria negativa: `PASS_V116_NEGATIVOS`.
- paginação inválida -> `PT400`;
- competência inexistente -> `PT404`;
- sessão ausente -> `42501`.

Grants:
- authenticated EXECUTE: true;
- anon EXECUTE: false.

Rollback:
- competências fixture: 0;
- execuções fixture: 0;
- resultados fixture: 0;
- apontamentos fixture: 0;
- contratos fixture: 0;
- contratantes fixture: 0.

## Referências canônicas

Manual frontend V1-16 exige:
- `AnalysisHeader`, `PercentGauge`, `RequirementTable`, `FilterBar`, `AsyncJobStatus`, `BlockingSummary`;
- estados `not analyzed`, `queued`, `processing`, `failed`, `complete`, `stale`;
- ações Executar análise, Reanalisar, Abrir requisito;
- stale, bloqueios e allowed actions vindos do backend;
- sem portão client, sem rules client.

PRD V1-AUD-001..005 exige execução reproduzível, separação de mecanismos, criticidade, evidência e reanálise incremental.

## Conclusão

**Backend read V1-16 CERTIFICADO funcionalmente no HML.**

Antes do PLAN Lovable, ainda devem ser concluídos os gates de governança do repositório (Histórico HML, Restore Isolado e Zero-Drift) no commit que contém esta certificação.
