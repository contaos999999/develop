# Tarefas Zero-Drift do ContaOS 4.1

Antes de qualquer alteração de implementação:

1. leia integralmente `00_AI_LEIA_ANTES_DE_ALTERAR.md` e todos os 23 documentos canônicos indicados nele, incluindo `08A`–`08D`;
2. leia `AI_CONTEXT_MANIFEST.md` e confirme o fingerprint vigente;
3. copie `docs/tasks/TEMPLATE.json` para `docs/tasks/active-task.json`;
4. preencha objetivo, branch, requisitos 96/96 impactados, telas, `allowed_paths`, `forbidden_paths`, permissões de banco/RLS/Edge/Auth, objetos aprovados, critérios de aceite e testes;
5. somente após concluir a leitura, altere `context_read_acknowledged` para `true`, informe `context_read_acknowledged_at`, `context_read_by`, copie o fingerprint vigente para `context_manifest_sha256` e liste **todos** os documentos lidos em `context_documents_read`;
6. execute Plan Mode antes do Build.

O Context Gate rejeita mudança de implementação se a tarefa não estiver ativa, se a leitura não estiver declarada, se faltar qualquer documento obrigatório ou se o fingerprint estiver desatualizado.

Não amplie `allowed_paths` por conveniência. Se o plano exigir algo fora do manifesto, pare e obtenha aprovação humana para atualizar o escopo antes do Build.

Se o contexto canônico mudar, a leitura anterior fica inválida. Leia novamente o conjunto vigente e atualize o fingerprint da tarefa.
