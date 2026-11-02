# Reprodutibilidade do ContaOS HML

Data de referência: 02/11/2026, Horário de Brasília.

O ambiente oficial de homologação é o Supabase `gklhhhyosgasnyoxlrui` e o repositório oficial de HML é `contaos9999/develop`. O repositório `contaos9999/prod` permanece intocado.

## Estado certificado

- migrations registradas no Supabase HML: **54**;
- última migration: `20261102021325_0049_context_hash_material_fields`;
- histórico materializado em arquivos individuais e protegido pelo materializador determinístico;
- checkpoint histórico em `supabase/applied-history/contaos-hml-full-history.sql`;
- Edge Functions versionadas em `supabase/functions/`;
- testes oficiais em `supabase/tests/`;
- secrets apenas no Supabase Secrets/Vault;
- nenhum valor de `OPENAI_API_KEY`, `service_role`, token interno ou segredo de webhook versionado.

## Restore limpo executado

O workflow `.github/workflows/restore-isolado.yml` executou com **PASS** no HML versionado atual:

1. iniciou PostgreSQL/Supabase local isolado;
2. executou `supabase db reset --local --no-seed`;
3. reconstruiu o banco exclusivamente pelas migrations do repositório, incluindo `0047`, `0048` e `0049`;
4. executou `supabase/tests/hml_acceptance.sql` contra o banco recém-reconstruído;
5. todos os passos terminaram com sucesso e a evidência foi publicada como artifact do workflow.

## Regras de versionamento

1. migration aplicada nunca é reescrita;
2. correção entra como nova migration;
3. timestamp e nome do histórico Supabase são preservados;
4. materializador falha se arquivo existente divergir do checkpoint;
5. Zero-Drift e Architecture Guard executam no GitHub;
6. `prod` não recebe mudanças antes da homologação formal.

## Segurança

- **117/117** tabelas `public` com RLS;
- **2/2** tabelas `privado` com RLS;
- nenhuma função `SECURITY DEFINER` pública executável por `anon`;
- bucket `contaos-documentos` privado;
- RPCs críticas protegidas por autenticação, perfil e escopo;
- workers internos protegidos por token service-to-service;
- RLS A/B e perfil leitor: PASS;
- 0 organizações e 0 usuários sintéticos persistidos após os testes.

## Anti-drift do contexto de negócio

As migrations `0047–0049` fecham a regra das Premissas segundo a qual alteração documental ou material após liberação exige nova análise:

- mudança de documento/versão, requisito, contrato, proposta, linha orçamentária, transação ou conciliação relevante invalida o portão já liberado;
- a competência volta a `em_reanalise`, zera o percentual de conformidade e limpa timestamps de liberação;
- análises armazenam snapshot e hash do contexto material;
- aprovação, apresentação, liberação de reapresentação e reapresentação revalidam o hash atual;
- contexto obsoleto bloqueia o fluxo com mensagem amigável em PT-BR.

Testes executados: documento pós-liberação invalida portão PASS; dado financeiro pós-liberação invalida portão PASS; hash antigo bloqueia aprovação PASS.

## Localização e rótulos

- idioma: `pt-BR`;
- timezone: `America/Sao_Paulo`;
- data: `DD/MM/YYYY`;
- horário: `HH24:MI:SS`;
- moeda: `BRL`;
- `PODE APRESENTAR AO CONTRATANTE`;
- `PODE REAPRESENTAR AO CONTRATANTE`;
- ocorrência de rótulo proibido `Apta para apresentação`: **0**.

## Evidências operacionais

- 96 requisitos: **96/96 PASS**;
- 75 entidades explícitas da matriz: **75/75 existentes e com RLS**;
- portão 99/100 e 100/100: PASS;
- parecer interno + hash atual obrigatórios: PASS;
- `VALIDADA` somente após parecer final favorável: PASS;
- reapresentação 100%: PASS;
- concorrência otimista: PASS;
- idempotência + DLQ: PASS;
- 8 processadores oficiais: HTTP 200;
- autenticação negativa Edge: HTTP 401;
- OpenAI análise/OCR/visão com `gpt-6-luna`: PASS HTTP 200;
- carga: 10.000 contratantes + 10.000 contratos, consultas RLS p95 **60,52 ms**, 100/100 chamadas Edge HTTP 200, 0 HTTP 5xx, rollback integral;
- restore limpo + suíte oficial: PASS;
- Zero-Drift CI: PASS.

## Advisors

Security Advisor: sem Critical da aplicação; permanece somente WARN de `pg_net` em `public`, exceção técnica de infraestrutura usada por runtime/Cron.

Performance Advisor: apenas `unused_index` INFO em HML sem carga persistente representativa.

## Promoção futura para PROD

A certificação é do **backend HML**. Produção será uma etapa separada, promovendo somente migrations, Edge Functions e configurações homologadas. O projeto/repositório PROD não foi alterado nesta certificação.
