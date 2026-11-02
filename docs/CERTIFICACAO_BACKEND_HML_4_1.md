# Certificação Técnica do Backend ContaOS HML 4.1

Data: 02/11/2026, Horário de Brasília.

## Escopo certificado

Backend de homologação do ContaOS 1.0 a 5.0 no Supabase HML `gklhhhyosgasnyoxlrui`, versionado no repositório `contaos9999/develop`.

Fontes confrontadas: PRD, Premissas, Arquitetura Oficial, Manual de Ambiente, Backend Supabase, regras Zero-Drift, matriz oficial de 96 requisitos e matriz de auditoria/fontes/rastreabilidade do pacote mestre 4.1.

SHA-256 do pacote mestre utilizado: `55b5a7ecd7d4bdc76baa51364a44e19ba9a9d040cc58325d67af3c2b1ea5241b`.

## Resultado da certificação

**PASS**

- requisitos: **96/96 PASS** = 84 RF + 12 NFR;
- IDs oficiais: 96 exatos, 96 únicos, mesma ordem, 0 faltantes, 0 extras;
- entidades backend explícitas: **75/75 existentes e 75/75 com RLS**;
- migrations HML: **54**;
- última migration: `20261102021325_0049_context_hash_material_fields`;
- tabelas públicas: **117/117 com RLS**;
- tabelas privadas: **2/2 com RLS**;
- função pública `SECURITY DEFINER` executável por `anon`: **0**;
- dados sintéticos persistidos após testes: **0 organizações / 0 usuários**.

## Portões e governança

- 99% de conformidade não libera: PASS;
- 100% + parecer interno aprovado + hash atual libera: PASS;
- `PODE APRESENTAR AO CONTRATANTE`: texto exato;
- diligência pendente bloqueia: PASS;
- diligência 100% tratada + reanálise atual libera: PASS;
- `PODE REAPRESENTAR AO CONTRATANTE`: texto exato;
- `VALIDADA` somente após parecer final favorável do contratante: PASS;
- parecer não favorável move para `com_apontamentos`: PASS;
- rótulo `Apta para apresentação`: 0 ocorrência no catálogo;
- IA não libera portão: decisão crítica permanece humana.

## Anti-drift do contexto

As migrations `0047`, `0048` e `0049` implementam e testam a premissa de que mudanças materiais posteriores à análise/liberação exigem nova análise:

- alteração documental pós-liberação invalida portão: PASS;
- alteração financeira pós-liberação invalida portão: PASS;
- alteração de requisito torna hash antigo obsoleto: PASS;
- hash obsoleto bloqueia aprovação: PASS;
- aprovação/protocolo/reapresentação revalidam contexto atual: PASS.

## Segurança

- isolamento multiempresa A/B: PASS;
- perfil leitor não aprova: PASS;
- bucket `contaos-documentos` privado: PASS;
- Edge Functions de usuário exigem JWT: PASS;
- workers internos exigem token service-to-service: PASS;
- chamadas sem credencial retornam 401 com mensagem PT-BR: PASS;
- secrets não versionados: PASS;
- Security Advisor sem finding Critical da aplicação; único WARN controlado: `pg_net` em `public`.

## Filas, jobs e resiliência

- 8 filas oficiais: PASS;
- idempotência: PASS;
- retry limite → DLQ: PASS;
- 8 processadores oficiais autenticados: HTTP 200;
- 5 jobs Cron ativos;
- timeout de integração: 10 s;
- máximo de tentativas: 5;
- circuito de webhook e observabilidade operacional: presentes.

## OpenAI

- provedor: OpenAI;
- segredo: backend only;
- modelo operacional homologado: `gpt-6-luna`;
- análise: HTTP 200;
- OCR/visão: HTTP 200;
- worker principal: HTTP 200;
- regra: IA sugere, humano aprova.

## Storage e localização

- upload/download por URL assinada: PASS;
- upload resumível para arquivos grandes: configurado a partir de 100 MB;
- `pt-BR`, `America/Sao_Paulo`, `DD/MM/YYYY`, `HH24:MI:SS`, `BRL`: PASS;
- mensagens amigáveis em português do Brasil: PASS.

## Carga e concorrência

Ensaio sintético com rollback:

- 10.000 contratantes + 10.000 contratos;
- 200 consultas paginadas com RLS;
- p95: **60,52 ms**;
- 100 requisições concorrentes Edge;
- 100/100 HTTP 200;
- 0 HTTP 5xx;
- concorrência otimista por `versao_registro`: stale update rejeitado.

## Restore e reprodutibilidade

Workflow `ContaOS Restore Isolado`: **PASS**.

O banco foi reconstruído do zero em ambiente isolado apenas com as migrations versionadas, incluindo `0047–0049`. A suíte oficial `supabase/tests/hml_acceptance.sql` foi executada no banco restaurado e concluiu com sucesso. A evidência foi publicada como artifact do workflow.

## Zero-Drift

Presentes e ativos:

- regras de escopo;
- manifesto de tarefa;
- Architecture Guard;
- scan de secrets;
- verificação de migrations;
- CODEOWNERS;
- template de PR;
- CI Zero-Drift.

## Fontes e rastreabilidade

- evidências de requisito preservam documento/versão/página/trecho/hash;
- copiloto preserva fonte, versão, página, trecho e score;
- precedentes preservam origem, contrato, competência, relatório e revisão humana;
- inteligência transversal preserva contrato/competência/relatório/unidade/item/desfecho/similaridade;
- precedente externo não cria bloqueio automático sem fonte formal independente, aprovada e aplicável ao contrato atual.

## Manifesto SHA do pacote

Foram verificados **27/27 hashes não autorreferentes** do `MANIFEST_SHA256_v4_1.json`. O próprio manifesto contém hash autorreferente e, por definição, o valor muda ao finalizar o arquivo; a divergência autorreferente foi registrada como exceção documental controlada e não altera nenhuma regra, requisito ou comportamento certificado.

## Decisão

O backend ContaOS HML 4.1 está concluído para integração com o frontend Lovable. O ambiente PROD não foi promovido nem alterado nesta certificação.
