# ContaOS HML - Production Readiness do Backend

Data de referência: 01/11/2026, Horário de Brasília.

## Conclusão executiva

O backend do ContaOS em HML está implementado e homologado estruturalmente para as versões 1.0 a 5.0. Banco, RLS, RPCs, Storage privado, filas, DLQ, Cron, observabilidade, Edge Functions, auditoria, concorrência, portões de negócio, localização brasileira e versionamento foram validados.

A liberação para desenvolvimento do frontend Lovable pode ocorrer usando este HML como backend.

Isto não significa que o ambiente esteja liberado para produção. Permanecem gates externos de Production Readiness antes de qualquer promoção para PROD.

## Estado do HML após os testes

- organizações persistidas: 0;
- usuários Auth persistidos: 0;
- jobs assíncronos persistidos: 0;
- DLQ persistida: 0;
- migrations registradas: 48;
- última migration: `20261101233537_0043_hardening_funcoes_privadas`.

Todos os cenários sintéticos de homologação foram executados em transações com `ROLLBACK`.

## Gates aprovados

### Estrutura 1.0 a 5.0

PASS

- 1.0: 44/44 artefatos centrais presentes;
- 2.0: 10/10;
- 3.0: 11/11;
- 4.0: 13/13;
- 5.0: 19/19;
- RPCs críticas: 33/33 presentes.

### Segurança multiempresa

PASS

- todas as 117 tabelas públicas com RLS habilitada;
- todas as tabelas RLS possuem policies;
- teste A/B executado com usuários e organizações sintéticas;
- usuário da organização A não leu organização/contrato B;
- usuário da organização B não leu organização/contrato A;
- perfil leitor não executou aprovação;
- schema `privado` sem execução por `anon`;
- bucket `contaos-documentos` privado;
- funções de usuário exigem JWT;
- workers internos exigem token service-to-service.

### Portões de negócio

PASS

- 99/100 requisitos não libera apresentação;
- 100/100 requisitos libera o portão de conformidade;
- `não aplicável` sem fundamento/evidência não libera;
- aprovação final exige parecer interno aprovado;
- transição validada para `pode_apresentar_contratante`;
- rótulo oficial: `PODE APRESENTAR AO CONTRATANTE`;
- diligência com apontamento pendente não libera;
- diligência 100% tratada libera;
- transição validada para `pode_reapresentar_contratante`;
- rótulo oficial: `PODE REAPRESENTAR AO CONTRATANTE`.

### Concorrência, filas e resiliência

PASS

- controle por `versao_registro` rejeitou atualização obsoleta;
- mesma chave de idempotência retornou o mesmo job;
- mensagem no limite de tentativas foi preservada na DLQ;
- oito processadores oficiais responderam HTTP 200 em chamada interna autenticada;
- schedules de workers e saúde operacional ativos;
- healthcheck operacional monitora DLQ e concentração de falhas.

### Edge Functions e GitHub

PASS

As 18 Edge Functions ativas do HML estão versionadas em `supabase/functions/` no repositório `contaos9999/develop`.

### Localização

PASS

- `pt-BR`;
- `America/Sao_Paulo`;
- `DD/MM/YYYY`;
- `HH24:MI:SS`;
- BRL;
- mensagens de interface em português do Brasil.

### Advisors Supabase

PASS COM EXCEÇÃO CONTROLADA

Security Advisor:
- nenhum finding crítico;
- único WARN: `pg_net` no schema `public`, mantido como exceção técnica controlada porque participa das chamadas HTTP do runtime/Cron.

Performance Advisor:
- nenhuma FK sem índice;
- apenas `unused_index`, esperado neste HML sem carga operacional representativa.

## OpenAI

PARCIALMENTE APROVADO / BLOQUEIO EXTERNO

- segredo `OPENAI_API_KEY` permanece somente no backend;
- OCR/visão com `gpt-6-luna`: PASS, HTTP 200;
- análise com `gpt-6.1-sol`: bloqueada pelo provedor com HTTP 429 `credit_balance_exhausted`;
- a integração e a autenticação da chave estão corretas;
- é necessário restabelecer créditos/saldo da API OpenAI para executar o fluxo real de análise com `gpt-6.1-sol`.

A regra de governança permanece: IA sugere, humano aprova.

## Gates ainda pendentes antes de PROD

### Teste de carga

PENDENTE

O cenário `tests/load/k6-hml.js` está versionado. Deve ser executado com usuário sintético persistente do HML e volume representativo antes da promoção para PROD.

Critérios configurados no cenário inicial:
- taxa de erro HTTP menor que 1%;
- p95 menor que 1 segundo para o cenário-base.

Os limites finais devem ser revistos com o perfil real de carga do produto.

### Backup, restore e PITR

PENDENTE PARA PROD

A integração Supabase disponível nesta sessão não expõe operação de backup/restauração. Não foi registrado como aprovado sem evidência.

Antes de produção:
- confirmar política de backup/PITR do projeto PROD;
- criar ponto de recuperação antes do release;
- testar restauração em ambiente isolado;
- registrar resultado do teste.

### Reprodutibilidade física das migrations históricas

PRONTO, COM PASSO OPERACIONAL PENDENTE ANTES DE PROD

O checkpoint histórico integral e o materializador determinístico estão versionados. Antes da promoção para PROD, executar:

```bash
node supabase/scripts/materialize-migrations.mjs
```

O script cria as migrations individuais ausentes do checkpoint e falha se detectar divergência com arquivos existentes.

## Decisão atual

### Backend HML para integração com Lovable

GO

O frontend Lovable pode ser conectado ao Supabase HML e começar a ser desenvolvido/testado contra o backend atual.

### Promoção para produção

NO-GO neste momento

Motivos objetivos:
1. saldo/créditos OpenAI para `gpt-6.1-sol` precisam ser restabelecidos e o teste E2E de análise deve ser repetido;
2. teste de carga k6 ainda precisa ser executado;
3. backup/restauração/PITR do PROD ainda precisa ser validado;
4. materialização final das migrations históricas deve ser executada antes do primeiro `db push` do PROD.

## Arquivos de referência no repositório

- `docs/HML_REPRODUCIBILIDADE.md`
- `docs/RELEASE_ROLLBACK.md`
- `supabase/README_HML.md`
- `supabase/tests/hml_acceptance.sql`
- `supabase/tests/queues_edge_auth.sql`
- `tests/load/k6-hml.js`
- `supabase/scripts/materialize-migrations.mjs`
- `supabase/applied-history/contaos-hml-full-history.sql`
