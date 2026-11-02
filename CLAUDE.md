# CLAUDE — Instrução obrigatória do ContaOS 4.1

Você está trabalhando no repositório HML certificado do ContaOS. **Antes de qualquer alteração**, abra `00_AI_LEIA_ANTES_DE_ALTERAR.md`, leia integralmente os documentos canônicos `00` a `18`, incluindo `08A`–`08D` na ordem definida, leia `AI_CONTEXT_MANIFEST.md`, `AGENTS.md` e `docs/tasks/active-task.json`.

Não faça Build, não edite arquivo, não gere migration e não proponha refatoração antes de concluir essa leitura. Se o contexto não puder ser lido, pare.

O backend Supabase HML 4.1 já está certificado. A próxima fase é frontend Lovable; não recrie backend nem duplique regras. Toda mudança deve respeitar PRD, Premissas, Arquitetura, matriz 96/96 e Zero-Drift.

Fingerprint esperado do pacote de contexto: `01d17aa3f71b8b4e4b67395f3d70fdcb158bc6d7b31dca1126aea49bc86ad4df`. Consulte `AI_CONTEXT_MANIFEST.md`; se divergir, use o fingerprint do manifesto vigente e atualize o `active-task.json` antes de implementar.
