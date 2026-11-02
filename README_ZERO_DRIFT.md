# ContaOS Zero-Drift

O Zero-Drift impede que uma tarefa altere banco, RLS, Auth, regras críticas ou arquivos fora do escopo.

## Context Gate

Antes do Zero-Drift tradicional, o CI valida o pacote de contexto da raiz. Qualquer alteração de implementação exige tarefa ativa declarando leitura integral dos documentos canônicos `00` a `18`, incluindo `08A`–`08D` e fingerprint igual ao `AI_CONTEXT_MANIFEST.md`.

## Controles

- documentos canônicos 00–18;
- `AGENTS.md` e instruções específicas para agentes;
- `docs/tasks/active-task.json`;
- Context Gate;
- allowed/forbidden paths;
- Plan Mode;
- migrations imutáveis;
- Architecture Guard;
- scan de secrets;
- auditoria de diff;
- testes/restore;
- CI/revisão.

Fluxo: ler contexto → declarar fingerprint → planejar → revisar impacto → Build mínimo → testar → auditar diff/migrations → security scan → CI → concluir.

Regra final: o agente pode propor; o contexto limita; o manifesto autoriza; RLS protege; o teste prova; o CI bloqueia; o humano decide.
