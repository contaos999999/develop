## ContaOS — Checklist Zero-Drift
- [ ] Li `AGENTS.md` e `docs/tasks/active-task.json`.
- [ ] Diff está integralmente dentro de `allowed_paths` e fora de `forbidden_paths`.
- [ ] Mudanças de banco/RLS/Edge estão explicitamente autorizadas no manifesto.
- [ ] Nenhum secret foi versionado ou exposto ao frontend.
- [ ] Nenhuma tabela de negócio exposta ficou sem RLS.
- [ ] Nenhum status crítico é calculado/atualizado diretamente no frontend.
- [ ] Documentos/evidências continuam versionados e em Storage privado.
- [ ] Testes positivos e negativos aplicáveis passaram.
- [ ] Fontes/rastreabilidade foram preservadas.

### Evidências
Descreva testes, migrations, RPCs/Edge Functions e riscos revisados.
