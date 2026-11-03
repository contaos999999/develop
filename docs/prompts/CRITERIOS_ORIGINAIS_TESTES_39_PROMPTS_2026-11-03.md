# ContaOS 4.1 | 39 etapas e critérios originais de homologação

**Fonte validada:** pacote 4.1 BRAND v1.0, manual SHA-256 `8a15d96568d021ac86fdd45e79038e2cb969d69c12b2edb84f012a6129b8940e` e caderno atômico SHA-256 `d9faaae47de4b697b18ad7fb71e4738384514936813cd5b18779f4cb8aed83b8`.

**Cobertura documental:** 39 prompts e 416 critérios de teste originais extraídos, sem atribuir PASS às evidências ausentes.

**Limite:** o documento é um checklist de rastreabilidade e não um certificado de conclusão.

## PROMPT 00 - Constituição e reancoragem

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_00.json)

Prova existente delimitada: Knowledge 100/97 e Teste C do saneamento transversal 765/765 aprovado no escopo.

- [ ] - Project Instructions contêm backend Supabase próprio; **(não certificado individualmente nesta extração)**
- [ ] - AGENTS.md existe; **(não certificado individualmente nesta extração)**
- [ ] - nenhuma tabela/migration foi criada; **(não certificado individualmente nesta extração)**
- [ ] - nenhum secret foi criado; **(não certificado individualmente nesta extração)**
- [ ] - nenhum backend paralelo foi habilitado. **(não certificado individualmente nesta extração)**

## PROMPT 01 - Fundação PostgreSQL e extensões

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_01.json)

Escopo previsto: TAREFA: Fundação PostgreSQL e extensões. | OBJETIVO: Criar a fundação do banco, schemas e extensões. | ESCOPO TÉCNICO OBRIGATÓRIO: schemas public/privado; pgvector, pgmq, pg_cron quando disponíveis; convenções UUID/timestamptz/numeric; sem dados de negócio ainda.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 02 - Identidade, organizações e vínculos

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_02.json)

Escopo previsto: TAREFA: Identidade, organizações e vínculos. | OBJETIVO: Criar o isolamento multi-organização. | ESCOPO TÉCNICO OBRIGATÓRIO: organizacoes, perfis_usuarios, vinculos_usuarios, eventos_auditoria, comandos_idempotentes; trigger seguro para perfil básico se necessário; RLS e helpers privado.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 03 - Contratantes e contratos 1.0

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_03.json)

Escopo previsto: TAREFA: Contratantes e contratos 1.0. | OBJETIVO: Criar o núcleo contratual. | ESCOPO TÉCNICO OBRIGATÓRIO: contratantes, contratos, versoes_contrato, vinculos_usuario_contratos; integridade composta; versao_registro; RLS por organização/contrato.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 04 - Base normativa, orçamento e listas 1.0

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_04.json)

Escopo previsto: TAREFA: Base normativa, orçamento e listas 1.0. | OBJETIVO: Criar fontes, proposta e checklists. | ESCOPO TÉCNICO OBRIGATÓRIO: fontes/versões/aplicabilidades, propostas/versões/linhas, listas/versões/itens, regras_conformidade/regras_preventivas; fontes e vigências.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 05 - Storage e documentos 1.0

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_05.json)

Escopo previsto: TAREFA: Storage e documentos 1.0. | OBJETIVO: Criar arquivos privados e versionamento. | ESCOPO TÉCNICO OBRIGATÓRIO: bucket documentos privado; arquivos, documentos_contrato, versoes_documento, processamentos, paginas, fragmentos; sem overwrite/delete histórico.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 06 - Competências e análise 1.0

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_06.json)

Escopo previsto: TAREFA: Competências e análise 1.0. | OBJETIVO: Criar competência, snapshot e resultados. | ESCOPO TÉCNICO OBRIGATÓRIO: competencias, requisitos_competencia, execucoes_analise, resultados_requisitos, evidencias, apontamentos_internos, acoes_corretivas, pareceres_internos.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 07 - Portão, aprovação e apresentação 1.0

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_07.json)

Escopo previsto: TAREFA: Portão, aprovação e apresentação 1.0. | OBJETIVO: Implementar o 100% e apresentação crítica. | ESCOPO TÉCNICO OBRIGATÓRIO: RPC criar_competencia, avaliar_portao_conformidade, aprovar_apresentacao, registrar_apresentacao; locks, idempotência, pacotes e snapshots.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 08 - Histórico e precedentes 1.0

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_08.json)

Escopo previsto: TAREFA: Histórico e precedentes 1.0. | OBJETIVO: Ingerir relatórios antigos do contrato. | ESCOPO TÉCNICO OBRIGATÓRIO: relatorios_historicos, apontamentos/respostas/desfechos, precedentes; processamento assíncrono; fonte/contrato/competência.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 09 - Queues, Cron e Edge Functions

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_09.json)

Escopo previsto: TAREFA: Queues, Cron e Edge Functions. | OBJETIVO: Criar processamento pesado seguro. | ESCOPO TÉCNICO OBRIGATÓRIO: queues documents/ocr/ai/embeddings/finance_imports/reports/integrations/webhooks; consumers por Edge Functions; Cron; secrets backend.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 10 - ContaOS 2.0 - Diligências

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_10.json)

Escopo previsto: TAREFA: ContaOS 2.0 - Diligências. | OBJETIVO: Criar rodadas, apontamentos e reapresentação. | ESCOPO TÉCNICO OBRIGATÓRIO: ciclos, pareceres, apontamentos, análises, plano/tarefas, contestações, pacotes; portão 100% da rodada.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 11 - ContaOS 3.0 - Financeiro preventivo

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_11.json)

Escopo previsto: TAREFA: ContaOS 3.0 - Financeiro preventivo. | OBJETIVO: Criar importação e monitoramento financeiro. | ESCOPO TÉCNICO OBRIGATÓRIO: fontes, importações, transações, documentos, fornecedores, consumo, conciliações, alertas; numeric; deduplicação; queue.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 12 - ContaOS 4.0 - Inteligência histórica

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_12.json)

Escopo previsto: TAREFA: ContaOS 4.0 - Inteligência histórica. | OBJETIVO: Criar RAG e alertas transversais. | ESCOPO TÉCNICO OBRIGATÓRIO: pgvector, relacionamentos, similaridades, alertas_transversais, risco, perfis/padrões, consultas/retornos, regras_candidatas; filtros de escopo antes de vetor.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 13 - ContaOS 5.0 - Conformidade

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_13.json)

Escopo previsto: TAREFA: ContaOS 5.0 - Conformidade. | OBJETIVO: Criar controles corporativos e remediação. | ESCOPO TÉCNICO OBRIGATÓRIO: controles/versões/execuções/exceções/não conformidades/remediação/alterações normativas/impactos; versionamento.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 14 - ContaOS 5.0 - API e webhooks

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_14.json)

Escopo previsto: TAREFA: ContaOS 5.0 - API e webhooks. | OBJETIVO: Criar integração externa segura. | ESCOPO TÉCNICO OBRIGATÓRIO: clientes_api, escopos, webhooks, eventos, pacotes_evidencias; hash de segredo, rotação, assinatura, rate limit e queue.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 15 - Hardening e testes do backend

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_15.json)

Escopo previsto: TAREFA: Hardening e testes do backend. | OBJETIVO: Fechar segurança e Production Readiness. | ESCOPO TÉCNICO OBRIGATÓRIO: RLS matrix A/B, testes de RPC, concorrência, idempotência, Storage, queues, Edge auth, índices, advisors, security scan, backup/restore plan.

Prova existente delimitada: Consulta estrutural HML de 03/11: objetos e RLS detectados; validação por cenário de autorização permanece pendente.

- [ ] 1. migration aplicada em HML; **(não certificado individualmente nesta extração)**
- [ ] 2. tabelas/constraints esperadas; **(não certificado individualmente nesta extração)**
- [ ] 3. RLS habilitada onde aplicável; **(não certificado individualmente nesta extração)**
- [ ] 4. usuário organização A não lê/escreve organização B; **(não certificado individualmente nesta extração)**
- [ ] 5. perfil sem permissão falha; **(não certificado individualmente nesta extração)**
- [ ] 6. RPC crítica não pode ser substituída por update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. nenhum secret está no frontend/repositório; **(não certificado individualmente nesta extração)**
- [ ] 8. testes de erro e rollback lógico; **(não certificado individualmente nesta extração)**
- [ ] 9. Security view sem novo Critical relacionado. **(não certificado individualmente nesta extração)**

## PROMPT 16 - SYS-01 - Login

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_16.json)

Escopo previsto: TAREFA: SYS-01 - Login

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 17 - SYS-02 - Esqueci a senha

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_17.json)

Escopo previsto: TAREFA: SYS-02 - Esqueci a senha

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 18 - SYS-03 - Redefinir senha

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_18.json)

Escopo previsto: TAREFA: SYS-03 - Redefinir senha

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 19 - SYS-04 - Selecionar organização

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_19.json)

Escopo previsto: TAREFA: SYS-04 - Selecionar organização

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 20 - SYS-05 - Dashboard

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_20.json)

Escopo previsto: TAREFA: SYS-05 - Dashboard

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 21 - ADM-01 - Usuários e vínculos

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_21.json)

Escopo previsto: TAREFA: ADM-01 - Usuários e vínculos

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 22 - V1-01 - Contratantes

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_22.json)

Escopo previsto: TAREFA: V1-01 - Contratantes

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 23 - V1-02 - Novo contratante

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_23.json)

Escopo previsto: TAREFA: V1-02 - Novo contratante

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 24 - V1-03 - Editar contratante

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_24.json)

Escopo previsto: TAREFA: V1-03 - Editar contratante

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 25 - V1-04 - Contratos

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_25.json)

Escopo previsto: TAREFA: V1-04 - Contratos

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 26 - V1-05 - Novo contrato

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_26.json)

Escopo previsto: TAREFA: V1-05 - Novo contrato

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 27 - V1-06 - Contrato - visão geral

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_27.json)

Escopo previsto: TAREFA: V1-06 - Contrato - visão geral

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 28 - V1-07 - Contrato - base normativa

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_28.json)

Escopo previsto: TAREFA: V1-07 - Contrato - base normativa

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 29 - V1-08 - Contrato - orçamento

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_29.json)

Escopo previsto: TAREFA: V1-08 - Contrato - orçamento

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 30 - V1-09 - Contrato - listas/regras

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_30.json)

Escopo previsto: TAREFA: V1-09 - Contrato - listas/regras

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 31 - V1-10 - Central de documentos

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_31.json)

Escopo previsto: TAREFA: V1-10 - Central de documentos

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 32 - V1-11 - Detalhe/versões documento

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_32.json)

Escopo previsto: TAREFA: V1-11 - Detalhe/versões documento

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 33 - V1-12 - Competências

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_33.json)

Escopo previsto: TAREFA: V1-12 - Competências

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 34 - V1-13 - Nova competência

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_34.json)

Escopo previsto: TAREFA: V1-13 - Nova competência

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 35 - V1-14 - Competência - visão geral

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_35.json)

Escopo previsto: TAREFA: V1-14 - Competência - visão geral

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 36 - V1-15 - Competência - documentos

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_36.json)

Escopo previsto: TAREFA: V1-15 - Competência - documentos

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 37 - V1-16 - Competência - análise

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_37.json)

Escopo previsto: TAREFA: V1-16 - Competência - análise

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**

## PROMPT 38 - V1-17 - Requisito - detalhe/evidências

[Dossiê individual GitHub](https://github.com/contaos9999/develop/blob/main/docs/prompts/evidencias_individuais/PROMPT_38.json)

Escopo previsto: TAREFA: V1-17 - Requisito - detalhe/evidências

Prova existente delimitada: Suíte frontend 811/811 e CI no commit e238429fa..., sem E2E real autenticado universal; V1-17 aguarda Teste C após correção de acessibilidade.

- [ ] 1. rota abre; **(não certificado individualmente nesta extração)**
- [ ] 2. perfil autorizado funciona; **(não certificado individualmente nesta extração)**
- [ ] 3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI; **(não certificado individualmente nesta extração)**
- [ ] 4. loading/empty/error funcionam; **(não certificado individualmente nesta extração)**
- [ ] 5. nenhuma request usa secret key; **(não certificado individualmente nesta extração)**
- [ ] 6. nenhuma ação crítica é update direto; **(não certificado individualmente nesta extração)**
- [ ] 7. desktop 1440 e 1280 ok; **(não certificado individualmente nesta extração)**
- [ ] 8. tablet 768 ok; **(não certificado individualmente nesta extração)**
- [ ] 9. mobile 390 preserva dados críticos; **(não certificado individualmente nesta extração)**
- [ ] 10. teclado/foco/labels ok; **(não certificado individualmente nesta extração)**
- [ ] 11. console sem erro e sem log sensível; **(não certificado individualmente nesta extração)**
- [ ] 12. Security scan sem novo Critical. **(não certificado individualmente nesta extração)**
