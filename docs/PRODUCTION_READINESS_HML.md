# ContaOS HML - Production Readiness do Backend

Data de referência: 02/11/2026, Horário de Brasília.

## Decisão

**GO para conexão do Lovable ao HML.**

O backend HML foi confrontado com PRD, Premissas, Arquitetura Oficial, Manual de Ambiente, Backend Supabase, Zero-Drift, matriz oficial de 96 requisitos e matriz de auditoria/fontes/rastreabilidade. Os gates de backend aplicáveis antes do frontend foram executados e aprovados.

Esta decisão não promove o sistema para PROD. Produção continua sendo etapa posterior e separada.

## Gates certificados

| Gate | Resultado |
|---|---|
| 84 requisitos funcionais | **84/84 PASS** |
| 12 NFR | **12/12 PASS** |
| Total da matriz oficial | **96/96 PASS** |
| Entidades explícitas da matriz | **75/75 presentes e com RLS** |
| Tabelas públicas | **117/117 com RLS** |
| Tabelas privadas internas | **2/2 com RLS** |
| `SECURITY DEFINER` pública executável por `anon` | **0** |
| RLS A/B e perfis | **PASS** |
| 99% bloqueia / 100% libera | **PASS** |
| Parecer interno + hash atual antes da apresentação | **PASS** |
| Reapresentação 100% + reanálise atual | **PASS** |
| Alteração pós-liberação invalida portão | **PASS** |
| Contexto obsoleto bloqueia aprovação/protocolo | **PASS** |
| `VALIDADA` somente com parecer final favorável | **PASS** |
| Concorrência otimista | **PASS** |
| Idempotência e DLQ | **PASS** |
| 8 workers oficiais | **HTTP 200** |
| Edge sem credencial | **HTTP 401** |
| OpenAI IA/OCR | **PASS — `gpt-6-luna`** |
| Storage privado/direto/resumível | **PASS** |
| Cron/Queues | **PASS** |
| Carga | **PASS — p95 60,52 ms; 100/100 Edge 200; 0 5xx** |
| Restore limpo por migrations | **PASS** |
| Suíte oficial no banco restaurado | **PASS** |
| Zero-Drift CI | **PASS** |
| Security Advisor | **sem Critical da aplicação** |
| Performance Advisor | **somente `unused_index` INFO** |

## Estado versionado

- migrations HML: **54**;
- última migration: `20261102021325_0049_context_hash_material_fields`;
- HML Supabase: `gklhhhyosgasnyoxlrui`;
- repositório HML: `contaos9999/develop`;
- repositório PROD: não alterado.

## Portões de negócio

- 99/100 requisitos: não libera;
- 100/100 requisitos: libera somente com parecer interno aprovado e hash do contexto atual;
- `não aplicável` sem fundamento/evidência: não libera;
- `PODE APRESENTAR AO CONTRATANTE`: texto exato;
- diligência com pendência: não libera;
- diligência 100% tratada + reanálise atual: libera;
- `PODE REAPRESENTAR AO CONTRATANTE`: texto exato;
- parecer final favorável do contratante: `validada`;
- parecer não favorável: `com_apontamentos`;
- rótulo proibido `Apta para apresentação`: 0 ocorrência no catálogo.

## Regra anti-drift de contexto

As migrations `0047–0049` implementam a premissa de invalidação automática após mudança material:

- documento/versão, requisito, contrato, proposta, linha orçamentária, transação ou conciliação relevante após liberação força `em_reanalise`;
- percentual volta a 0 e timestamps de liberação são limpos;
- análise registra snapshot/hash material;
- aprovação, apresentação, reapresentação e protocolo exigem hash atual;
- análise antiga não pode liberar dados novos.

Os três cenários críticos foram executados e passaram com rollback.

## OpenAI

A chave permanece exclusivamente no backend. O modelo operacional homologado é `gpt-6-luna` para análise e OCR/visão. `gpt-6.1-sol` permanece apenas como preferência futura quando houver quota, sem ser dependência do fluxo homologado. Governança: **IA sugere; humano aprova**.

## Carga

Ensaio sintético com rollback:

- 10.000 contratantes;
- 10.000 contratos;
- 200 consultas paginadas com RLS;
- p95: **60,52 ms**;
- 100 requisições concorrentes a Edge Function;
- 100 HTTP 200;
- 0 HTTP 5xx.

## Restore e reprodutibilidade

O workflow `ContaOS Restore Isolado` executou com sucesso sobre o commit que contém as migrations `0047–0049`. Ele iniciou um Supabase/PostgreSQL vazio, aplicou exclusivamente a cadeia versionada e executou `supabase/tests/hml_acceptance.sql` no banco reconstruído. Todos os passos passaram.

## Advisors

Security Advisor: único WARN controlado `pg_net` em `public`, extensão de infraestrutura usada por runtime/Cron.

Performance Advisor: somente `unused_index` INFO, esperado em HML sem carga persistente representativa.

## Próxima etapa

O backend HML está concluído para esta fase. O Lovable pode ser conectado ao **Supabase HML** e o frontend deve ser construído sob Zero-Drift, reutilizando RLS, RPCs, Storage e Edge Functions existentes, sem backend paralelo e sem cálculo local dos portões críticos.
