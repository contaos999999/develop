## ContaOS 4.1 — Checklist obrigatório de contexto e Zero-Drift

### Contexto antes do Build
- [ ] Li integralmente `00_AI_LEIA_ANTES_DE_ALTERAR.md` e todos os documentos canônicos `00` a `18`, incluindo `08A`–`08D`, na ordem obrigatória.
- [ ] Li `AI_CONTEXT_MANIFEST.md`, `AGENTS.md` e `docs/tasks/active-task.json`.
- [ ] O `context_manifest_sha256` da tarefa é igual ao fingerprint vigente do `AI_CONTEXT_MANIFEST.md`.
- [ ] `context_read_acknowledged = true` e `context_documents_read` contém todos os documentos obrigatórios.
- [ ] Identifiquei os IDs da matriz 96/96 afetados por esta mudança.

### Escopo e arquitetura
- [ ] Diff está integralmente dentro de `allowed_paths` e fora de `forbidden_paths`.
- [ ] A mudança ocorre no HML e não altera `contaos9999/prod` durante homologação.
- [ ] Não foi criado backend, banco ou fonte de verdade paralela.
- [ ] Mudanças de banco/RLS/Edge/Auth estão explicitamente autorizadas no manifesto.
- [ ] Migration já aplicada não foi reescrita.

### Segurança e regras críticas
- [ ] Nenhum secret foi versionado ou exposto ao frontend.
- [ ] Nenhuma tabela de negócio exposta ficou sem RLS.
- [ ] Isolamento multi-organização/contrato foi preservado.
- [ ] Nenhum status crítico é calculado/atualizado diretamente no frontend.
- [ ] `PODE APRESENTAR AO CONTRATANTE`, `PODE REAPRESENTAR AO CONTRATANTE` e `VALIDADA` mantêm as regras do PRD.
- [ ] Alteração material pós-liberação continua invalidando contexto/portão quando aplicável.
- [ ] Alerta histórico transversal continua não impeditivo por si só.
- [ ] IA continua sem poder de aprovação/liberação material.
- [ ] Documentos/evidências continuam versionados, rastreáveis e em Storage privado.

### Testes e evidências
- [ ] Testes positivos e negativos aplicáveis passaram.
- [ ] RLS A/B/perfis foram testados quando aplicável.
- [ ] Concorrência/idempotência/filas foram testadas quando aplicável.
- [ ] Restore/reprodutibilidade foi validado quando houve migration.
- [ ] Context Gate passou.
- [ ] Zero-Drift passou.
- [ ] Architecture Guard passou.
- [ ] Scan de secrets passou.

### Evidências
Informe os IDs 96/96 impactados, fingerprint do contexto, testes executados, migrations/RPCs/Edge Functions alteradas e riscos revisados.
