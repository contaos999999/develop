# ContaOS 4.1 — Backend Supabase Certificado

Este documento combina o manual `Backend_Supabase_v3_0_Manual_Integral_Production_Readiness.docx` com o estado efetivamente certificado do HML em 02/11/2026.

## 1. Estado certificado atual

- projeto HML Supabase: `gklhhhyosgasnyoxlrui`;
- repositório HML: `contaos9999/develop`;
- 96/96 requisitos do pacote 4.1: PASS;
- 54 migrations aplicadas/versionadas;
- última migration: `20261102021325_0049_context_hash_material_fields`;
- 117/117 tabelas `public` com RLS;
- 2/2 tabelas privadas com RLS;
- 0 função `SECURITY DEFINER` pública executável por `anon`;
- 75/75 entidades explícitas da matriz presentes e protegidas;
- restore limpo + suíte oficial: PASS;
- Zero-Drift/Architecture Guard/scan de secrets: PASS.

A fonte operacional detalhada dessa certificação está em `docs/CERTIFICACAO_BACKEND_HML_4_1.md`.

## 2. Receita obrigatória para tabelas/capacidades

Para qualquer nova capacidade:
1. identificar requisito PRD;
2. criar migration nova;
3. PK/FK/unique/check/index adequados;
4. `id_organizacao` e `id_contrato` quando material;
5. habilitar RLS;
6. policies por operação;
7. grants mínimos;
8. RPC para ação crítica;
9. auditoria;
10. teste A/B;
11. teste de perfil;
12. concorrência/idempotência quando aplicável;
13. fila/Cron quando pesado/periódico;
14. mensagens PT-BR;
15. evidência para a matriz.

## 3. Núcleo de dados

O backend implementa os domínios de:
- organização, identidade, perfis e escopos;
- contratantes e contratos;
- versões contratuais;
- fontes normativas/aplicabilidades;
- proposta/orçamento;
- listas/checklists/regras;
- arquivos/documentos/versionamento/processamento;
- competências/requisitos/análises/resultados/evidências;
- apontamentos/correções/parecer interno/aprovações;
- pacotes e apresentações;
- histórico/precedentes;
- diligências/contestações/reapresentações;
- financeiro preventivo;
- inteligência histórica/copiloto;
- controles de conformidade/remediações;
- normativos/riscos;
- integrações/API/webhooks;
- pacotes de evidência.

## 4. Portão de apresentação

A avaliação é backend-side. O React não calcula autoridade.

Regras certificadas:
- 99/100 bloqueia;
- 100/100 pode liberar se parecer interno aprovado e hash/contexto atual;
- não aplicável sem fundamento bloqueia quando fundamento é exigido;
- perfil sem permissão não aprova;
- status oficial retornado: `pode_apresentar_contratante` → `PODE APRESENTAR AO CONTRATANTE`.

## 5. Portão de reapresentação

- apontamento pendente bloqueia;
- 100% tratado libera quando demais condições estão válidas;
- status oficial: `pode_reapresentar_contratante` → `PODE REAPRESENTAR AO CONTRATANTE`.

## 6. Parecer do contratante

A operação de registro do parecer externo implementa:
- parecer final favorável → competência `validada`;
- parecer não favorável → abre/continua diligência e vai para `com_apontamentos`;
- `VALIDADA` não pode ser atribuída pela IA nem pelo frontend.

## 7. Anti-drift de contexto pós-liberação

Migrations 0047, 0048 e 0049 protegem o sistema contra reutilização de análise antiga:
- documento novo/alterado após liberação invalida portão;
- transação financeira material nova/alterada invalida portão;
- alterações materiais de requisito entram no snapshot/hash;
- hash antigo bloqueia aprovação;
- aprovação/protocolo/reapresentação validam contexto atual.

Não remover nem contornar esses mecanismos.

## 8. Documentos e Storage

- bucket privado;
- upload/download assinados;
- resumível para arquivos grandes a partir do limiar configurado;
- versões imutáveis;
- SHA-256 e metadados;
- processamento assíncrono;
- documentos só entram em análise conforme status de segurança/processamento apropriado.

## 9. Filas e workers

A arquitetura homologada possui filas/workers separados para cargas distintas, incluindo documentos, OCR, IA, embeddings, financeiro, relatórios, integrações e webhooks. Retry, idempotência, DLQ e autenticação interna fazem parte do contrato.

## 10. OpenAI

- segredo backend-only;
- modelo operacional homologado no HML: `gpt-6-luna`;
- análise estruturada: PASS;
- OCR/visão: PASS;
- worker IA: PASS;
- IA não tem poder de aprovação/liberação.

Não fixar provider/modelo no domínio de negócio de maneira que impeça substituição futura.

## 11. Concorrência

- operações materiais: transação/lock;
- edição comum: controle otimista (`versao_registro` ou mecanismo equivalente);
- stale update é rejeitado com mensagem amigável;
- comandos repetíveis usam idempotência.

## 12. Auditoria

Eventos relevantes devem preservar, conforme aplicável:
- organização;
- usuário/ator;
- entidade/tipo/id;
- antes/depois ou fundamento;
- correlation id;
- origem da ação;
- timestamp;
- relação com análise/IA/integração.

## 13. Testes que não podem regredir

- RLS organização A/B;
- perfil leitor não aprova;
- 99% bloqueia;
- 100% + parecer + hash atual libera;
- não aplicável sem fundamento bloqueia;
- documento pós-liberação invalida;
- financeiro pós-liberação invalida;
- hash antigo bloqueia;
- diligência pendente bloqueia;
- 100% tratada permite reapresentação;
- `VALIDADA` apenas com parecer final favorável;
- concorrência otimista;
- idempotência/DLQ;
- Edge sem credencial → 401;
- restore do zero;
- suíte `supabase/tests/hml_acceptance.sql`.

## 14. Regra de modificação

O backend já está certificado. Não recriar, renomear ou simplificar estruturas sem requisito e autorização explícita. Alterações devem ser incrementais por migration e preservar compatibilidade com o frontend a ser construído.
