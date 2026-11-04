# ContaOS 4.1 — Matriz RNF-001 a RNF-012: contratos de desempenho e prova

Data: 04/11/2026. Escopo: documentação estática; **não houve ensaio HML ou PROD nesta alteração**.

## Fonte original e integridade
Pacote: ContaOS_Pacote_Mestre_Arquitetura_4_1_100_PRD_Lovable_Supabase_BRAND_v1_0_FINAL.zip.
Pasta: 08_REQUISITOS_NAO_FUNCIONAIS.
Arquivo: ContaOS_RNF_Escalabilidade_Concorrencia_Performance_v2_0_Supabase.docx.
SHA-256 verificado: 89ef7ac29b2e9238a4cced6238982921d8320bdae5a1929b77b8b67a97b99ea4.
Correspondência: 11_RNF_PERFORMANCE_CONCORRENCIA_RESILIENCIA_4_1.md e 08D_REQUISITOS_073_096_4_1.md. Manter **96/96 IDs** e nenhum relaxamento do PRD.

## Metas quantitativas originais

| Indicador | Objetivo técnico inicial | Verificação exigida |
|---|---|---|
| API comum de leitura GET | **p95 ≤ 500 ms** | Percentil por rota em concorrência sintética representativa |
| Comando síncrono simples | **p95 ≤ 800 ms** | Teste segregado em comando de dados sintéticos, com idempotência e limpeza |
| Disponibilidade projetada | **≥ 99,9% mensal** | Monitoramento temporal representativo; **não é SLA comercial** |
| Sobrescrita silenciosa | **0** | Corridas de edição com versão obsoleta/409 |
| Efeitos duplicados em comando idempotente | **0** | Replay de chave/escopo e inspeção do efeito |
| Arquivo grande atravessando request interativa | **0** | Tráfego navegador↔Storage privado assinado |

**Proibição de falso positivo:** o k6 de leitura não mede p95 do comando de escrita. É proibido marcar meta 800 ms como PASS baseada em leituras GET ou alegar 99,9% com teste curto.

## Critérios técnicos complementares encontrados no DOCX original

1. PostgreSQL: pooling para aplicação; acesso administrativo direto segregado para migrations/schema; medir limite de conexões, lock waits e slow queries.
2. Concorrência: controle otimista com versão e HTTP 409; locks transacionais somente em janela crítica, nunca durante chamadas externas.
3. Idempotência: chave/escopo/resultado persistidos, impedindo efeito duplicado em retry.
4. Storage: URL assinada com bucket privado, transferência direta; upload <100 MB por fluxo direto; a partir de 100 MB upload resumível/multipart com retry e retomada. Limiar é configurável.
5. Filas: crítica, documentos/extrações, OCR, IA, embeddings, relatórios e integrações; limites/consumidores/retry separados, backoff, observabilidade e DLQ.
6. API: paginação server-side padrão inicial 25, máximo inicial sugerido 100, cursor em coleções extensas/mutáveis; índice/filtro/ordenação no backend.
7. Frontend: lazy load, virtualização de tabelas extensas, debounce remoto, cancelamento de pedidos superados, progresso/retry multipart, mensagem amigável no HTTP 409, navegação durante job.
8. Resiliência: health checks, instâncias substituíveis, timeout, backoff, circuit breaker ou equivalente, backup automático e PITR segundo RPO, runbook e rollback.
9. Observabilidade obrigatória: API p50/p95/p99, throughput, 4xx/5xx; banco pool, locks, slow queries; filas/Cron/Edge backlog/idade/duração/erros; Storage throughput/latência/falhas/multipart abandonados; CPU/memória/health; IA/OCR latência/falha/custo/retry.

## Cobertura por RNF com distinção evidência histórica x prova ainda necessária

| ID | Inspeção possível sem serviços reais | Prova externa ainda necessária |
|---|---|---|
| NFR-001 | Auditar desenho stateless de Edge/workers | Múltiplas instâncias, failover e pico |
| NFR-002 | Conferir estratégia de pool versionada | Conexões simultâneas, saturação e locks |
| NFR-003 | Conferir código e Storage assinado documentado no HML | Tráfego ponta a ponta e acesso negado |
| NFR-004 | Conferir configuração de 100MB e TUS | Arquivo ≥100 MB, interrupção, retry, retomada e hash |
| NFR-005 | Conferir filas/workers e resposta HTTP histórica | Backlog, processamento sem bloquear request |
| NFR-006 | Conferir famílias de filas e DLQ | OCR saturado sem bloquear fila crítica |
| NFR-007 | Conferir versão e lock SQL; certificado HML histórico | Concorrência sob pico com 409, sem perdas |
| NFR-008 | Conferir chaves/escopo; certificado HML histórico | Retry duplicado/timeout com único efeito |
| NFR-009 | Conferir filtros e paginação; 200 queries RLS no certificado | Cursor/limites em coleção extensa e mutável |
| NFR-010 | Conferir estruturas de logs/alertas | Dashboards, p50/p95/p99, alarmes e correlação reais |
| NFR-011 | Conferir timeout 10s, até 5 tentativas e webhook | Derrubar provedor em ensaio controlado |
| NFR-012 | Inspecionar k6 e certificado sintético HML p95 60,52 ms | Ensaio com pico esperado, falhas, upload e disponibilidade |

O certificado histórico do backend declara 12/12 RNF PASS no escopo testado em 02/11/2026; esta matriz não o revoga, nem o converte em prova de disponibilidade PROD.

## Testes que podem ser automatizados sem prova do ambiente

- Node examina thresholds de leitura segregados, tags de rota e uso exclusivo de GET no arquivo k6-hml.js.
- Node verifica restrição de URL de HML/local e o limite 25 no pedido paginado.
- CI valida regressões da especificação estática sem credenciais.
- Meta de 800 ms para **comandos** permanece explícita neste arquivo, mas o teste deve ser separado e condicionado à disponibilização de RPC sintética sem efeitos reais.

## Roteiro de ensaios HML que não podem ser simulados como sucesso

Registrar SHA, tempo Brasília, config, perfil de carga, credenciais sintéticas em Secrets, resultados e hashes de artefatos. Executar carga GET e comando separadamente, upload grande com falha/retomada, backlog OCR, falha de terceiro, alertas reais, pool e concorrência, RPO/RTO definido e restore **de backup** isolado (diferente do restore por migrations já certificado). Não tocar PROD, não usar dados reais e não declarar 99,9% antes de medição representativa.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Impacto visual: N/A, justificado por documentação e teste de carga somente. Preservar BRAND-01 sem editar src/public; executar via GitHub e Node sem créditos Lovable. O Teste C frontend não se aplica a estes arquivos. Backend e PROD permanecem intocados.
