# ContaOS 4.1 — RNF, Performance, Concorrência e Resiliência

Consolidação de `ContaOS_RNF_Escalabilidade_Concorrencia_Performance_v2_0_Supabase.docx` e NFR-001 a NFR-012.

## NFR-001 — Escala horizontal
API/workers não dependem de estado local crítico. Componentes podem escalar independentemente.

## NFR-002 — Pool de banco
Sob concorrência em produção, acesso PostgreSQL de aplicação deve respeitar pooling/mecanismos gerenciados apropriados. Conexão administrativa/migration é separada.

## NFR-003 — Transferência direta
Upload/download prioriza navegador↔Storage com autorização temporária, sem usar API como proxy de bytes grandes.

## NFR-004 — Upload grande
Multipart/resumível, retry e retomada. Limiar inicial homologado para upload resumível: 100 MB, configurável.

## NFR-005 — Assincronicidade
OCR, IA, embeddings, relatórios pesados e importações não prendem request web até conclusão.

## NFR-006 — Isolamento de filas
Workloads de perfis diferentes possuem filas/consumidores/retry independentes para evitar efeito cascata.

## NFR-007 — Concorrência
- transação/lock em ação crítica;
- controle otimista em edição comum;
- atualização obsoleta é rejeitada;
- não aceitar last-write-wins silencioso em dado material.

## NFR-008 — Idempotência
Comando repetido por retry/reenvio não pode duplicar efeito.

## NFR-009 — Paginação
Coleções grandes usam paginação/filtro/índice. Padrão e limite devem ser definidos no backend.

## NFR-010 — Observabilidade
Monitorar API, banco, Queues, Edge Functions, Cron, Storage, jobs, falhas e correlation id. Erros internos são sanitizados para o usuário.

## NFR-011 — Resiliência
Integrações externas usam timeout, retry e isolamento. Falha de terceiro não derruba núcleo transacional. Circuit breaker quando aplicável.

## NFR-012 — Teste de carga
Produção exige ensaio compatível com capacidade esperada.

## Estado homologado HML

Ensaios já executados no backend:
- 10.000 contratantes + 10.000 contratos sintéticos;
- 200 consultas paginadas com RLS;
- p95 60,52 ms no ensaio registrado;
- 100 chamadas Edge concorrentes;
- 100/100 HTTP 200;
- 0 HTTP 5xx;
- dados de carga revertidos.

Isso é evidência de HML, não promessa de SLA de produção.

## Regras de performance para frontend

- paginação server-side;
- debounce quando apropriado;
- não carregar dataset inteiro para filtrar;
- mostrar progresso de job assíncrono;
- upload direto;
- evitar polling agressivo sem necessidade;
- respeitar limites e backoff.

## Testes obrigatórios quando afetar RNF

- concorrência/stale update;
- idempotência;
- retry/DLQ;
- timeout de integração;
- paginação/limites;
- restore/migration;
- carga focal quando alteração impactar caminho crítico.
