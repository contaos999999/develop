# ContaOS HML - Production Readiness do Backend

Data de referência: 02/11/2026, Horário de Brasília.

## Decisão

**GO para conexão do Lovable ao HML.**

O backend HML foi confrontado com o pacote mestre 4.1 e passou pelos gates aplicáveis antes do frontend: banco, Auth/onboarding, RLS, RPCs, Storage, Queues, Cron, Edge Functions, OpenAI IA/OCR, concorrência, idempotência, observabilidade, carga, auditoria, localização, Zero-Drift e rastreabilidade.

Esta decisão não promove o sistema para PROD. Produção é etapa posterior e exige configuração própria de secrets, Auth/domínio, backup/PITR/RPO/RTO e restauração do projeto PROD, além de smoke/E2E com o frontend homologado.

## Gates do backend HML

| Gate | Resultado |
|---|---|
| 84 requisitos funcionais | **84/84 PASS** |
| 12 NFR | **12/12 PASS** |
| Entidades explícitas da matriz | **75/75 presentes e com RLS** |
| Tabelas públicas | **117/117 com RLS** |
| Tabelas privadas internas | **2/2 com RLS; sem grants de cliente** |
| RLS A/B e perfis | **PASS** |
| 99% bloqueia / 100% libera | **PASS** |
| Parecer interno antes da apresentação | **PASS** |
| Reapresentação 100% | **PASS** |
| Concorrência otimista | **PASS** |
| Idempotência e DLQ | **PASS** |
| 8 workers oficiais | **HTTP 200** |
| Edge sem credencial | **HTTP 401** |
| OpenAI | **PASS — `gpt-6-luna` operacional para IA/OCR** |
| Storage privado/direto | **PASS** |
| Cron/Queues | **PASS** |
| Carga | **PASS — p95 60,52 ms; 100/100 Edge 200; 0 5xx** |
| Security Advisor | **sem Critical da aplicação** |
| Performance Advisor | **somente `unused_index` INFO** |
| Migrations reproduzíveis | **PASS — cadeia materializada** |

## Portões de negócio

- 99/100 requisitos: não libera;
- 100/100 requisitos: libera o portão;
- `não aplicável` sem fundamento: não libera;
- aprovação exige parecer interno aprovado;
- `PODE APRESENTAR AO CONTRATANTE`: PASS;
- diligência com pendência: não libera;
- diligência 100% tratada: libera;
- `PODE REAPRESENTAR AO CONTRATANTE`: PASS.

## OpenAI

A chave é lida apenas de Supabase Secrets. O modelo operacional HML é `gpt-6-luna` para análise e OCR/visão. `gpt-6.1-sol` permanece como preferência futura quando houver quota, sem ser dependência do fluxo homologado. A governança permanece **IA sugere; humano aprova**.

Validações ao vivo: chave, modelo, resposta estruturada, visão/OCR e worker de IA: PASS HTTP 200.

## Carga e capacidade

Ensaio sintético executado em transação com rollback:

- 10.000 contratantes;
- 10.000 contratos;
- 200 consultas paginadas de 25 registros com RLS;
- p50: 31,88 ms;
- p95: **60,52 ms**;
- p99: 64,11 ms;
- máximo: 65,03 ms.

Rajada de Edge Functions:

- 100 requisições concorrentes;
- 100 respostas HTTP 200;
- 0 respostas HTTP 5xx.

## Advisors

Security Advisor: apenas `pg_net` em `public`. A extensão é `extrelocatable=false` e é usada pelo runtime/Cron; exceção de infraestrutura documentada.

Performance Advisor: apenas `unused_index` INFO em HML sem carga persistente. Não há alerta de FK sem índice.

## Produção

Backup/PITR/RPO/RTO e restauração do **projeto PROD** permanecem gate de implantação futura em produção, como previsto no Manual de Ambiente. Não são uma dependência para conectar o Lovable ao backend HML já homologado. O PROD continua intocado.

## Próxima etapa

Com o backend HML certificado, a próxima etapa é conectar o Lovable ao **Supabase HML** e construir o frontend sob Zero-Drift. O frontend não poderá criar backend paralelo, expor secrets, calcular portões críticos ou substituir RLS/RPC.
