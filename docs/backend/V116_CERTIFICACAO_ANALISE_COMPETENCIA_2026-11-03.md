# Certificação Backend — V1-16 Competência: Análise

Data: 03/11/2026
Ambiente: HML
Prompt: 37 / V1-16
Status: BACKEND READ CERTIFICADO E CONGELADO
PROD: intocado

## Objetivo

Disponibilizar uma única leitura autoritativa e paginada para a tela V1-16 `/competencias/:id/analise`, sem reconstruir no frontend estado assíncrono, stale, portão, bloqueios, filtros ou permissões.

## Lacuna comprovada

O HML já possuía `solicitar_analise_competencia`, `solicitar_reanalise_requisitos`, `registrar_resultado_requisito`, `avaliar_portao_conformidade`, `hash_contexto_competencia` e as entidades de execução/resultados/evidências/apontamentos. Não existia RPC/view agregada equivalente aos GETs exigidos pelo manual frontend para execução + requisitos/resultados. Consultas dispersas no React violariam a autoridade backend e criariam N+1/regras locais.

## Migration e contrato

Git:
- `supabase/migrations/20261103124500_v116_obter_analise_competencia.sql`
- commit da migration: `a1536a20c4d6c5e2f9af53d0490e9b7177a70c11`

HML:
- `20261103135545 v116_obter_analise_competencia`

RPC:
- `public.obter_analise_competencia_v116(...) returns jsonb`
- `STABLE SECURITY DEFINER`, `search_path=''`
- authenticated EXECUTE: true
- anon EXECUTE: false
- leitura apenas; não cria/classifica resultados, não altera portão, competência, execução ou apontamentos.

Resposta `schema_versao='v116-v1'`:
- competência e contexto;
- `estado_analise`: `not_analyzed|queued|processing|failed|complete|stale`;
- `stale` calculado somente no backend por hash atual versus `hash_entrada`;
- execução atual + histórico paginado e metadados reproduzíveis;
- `percentual` e `blocking_summary` de `avaliar_portao_conformidade()`;
- `allowed_actions.executar_analise|reanalisar|abrir_requisito` backend-side;
- resultados atuais paginados com requisito, criticidade, confiança, justificativa, fundamento, fonte e evidências agregadas;
- mecanismos `deterministico|semantico|humano|nao_identificado`, apenas por marca objetiva;
- apontamentos internos paginados com severidade/status/regra/ação/fonte;
- filtros backend por resultado, criticidade, mecanismo, status e busca.

## Segurança

- paginação/filtro inválido: PT400;
- competência inexistente: PT404;
- sessão/acesso/perfil insuficiente: 42501;
- sessão ativa real + `usuario_tem_acesso_contrato` obrigatórios;
- perfis seguem o mesmo conjunto das operações de análise;
- `erro_detalhe` não é exposto, somente `erro_codigo`;
- nenhum EXECUTE para anon;
- isolamento de tenant permanece no backend.

## Separação de mecanismos

A arquitetura preserva `unique(execucao,requisito)`: uma linha representa o resultado consolidado por requisito. A leitura classifica o mecanismo somente quando houver evidência objetiva:
1. revisão humana explícita -> `humano`;
2. `metadados.mecanismo` explícito -> valor registrado;
3. provedor explícito -> `semantico`;
4. caso contrário -> `nao_identificado`.

A RPC não fabrica resultado determinístico e nunca interpreta “sem provedor” como determinístico. O material canônico descreve as seis camadas A–F, mas não fornece DSL operacional suficiente para inventar um interpretador genérico. Qualquer evolução do worker deve preservar a linha consolidada e registrar o mecanismo explicitamente.

## Testes HML

Sessão real de homologação com `session_id` ativo e vínculo administrador. Fixtures sintéticas em `BEGIN/ROLLBACK`.

Bateria principal: **PASS_V116_READ**:
- not_analyzed, queued, processing, failed, complete e stale;
- stale por hash backend;
- allowed actions;
- paginação independente de resultados, execuções e apontamentos;
- histórico preservado;
- mecanismos semântico, humano, determinístico explícito e não identificado;
- evidência com página/trecho/referência/hash;
- filtro por mecanismo;
- apontamento com criticidade/regra/ação/fonte;
- leitura sem mutação.

Bateria negativa: **PASS_V116_NEGATIVOS**:
- PT400 paginação;
- PT404 inexistente;
- 42501 sem sessão.

Rollback confirmado: zero resíduos em competências, execuções, resultados, apontamentos, contratos e contratantes.

## Gates de governança

Commit da migration `a1536a20…`:
- Histórico HML: run `41648619441` — SUCCESS.
- Restore Isolado: run `41648619515` — SUCCESS.
- Zero-Drift: run `41648619400` — SUCCESS.

Observação temporal: o run automático de Histórico HML terminou imediatamente antes do registro temporal da aplicação HML. Por isso a presença pós-aplicação foi confirmada novamente diretamente com `list_migrations`, que retorna `20261103135545 v116_obter_analise_competencia`. A correspondência funcional também foi comprovada pela bateria `PASS_V116_READ` executada na função já aplicada.

Commit de certificação `f0567af387467d8da6ca83dd58d72e010d885e07`:
- Zero-Drift: run `41649997652` — SUCCESS.

## Referências canônicas

V1-16 exige `AnalysisHeader`, `PercentGauge`, `RequirementTable`, `FilterBar`, `AsyncJobStatus`, `BlockingSummary`; estados not analyzed/queued/processing/failed/complete/stale; ações Executar análise/Reanalisar/Abrir requisito; stale/bloqueios/allowed actions vindos do backend; sem portão client e sem rules client.

V1-AUD-001..005: execução reproduzível, separação de mecanismos, criticidade, evidência e reanálise incremental.

## Conclusão

**Backend read V1-16 CERTIFICADO E CONGELADO no HML. PROD intocado.**
