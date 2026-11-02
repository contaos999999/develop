# ContaOS Zero-Drift

O Zero-Drift impede que uma tarefa pequena altere banco, RLS, autenticação, regras críticas ou arquivos fora do escopo. Quanto mais importante a regra, menos ela depende da memória do chat.

Controles instalados: Project/Workspace Instructions, `AGENTS.md`, `docs/tasks/active-task.json`, Plan Mode, Build fechado, revisão de migrations, auditoria de diff, Architecture Guard, security scan e revisão por PR.

Fluxo obrigatório: reancorar contexto → planejar sem editar → revisar arquivos/banco/RLS/RPC → aprovar plano → build mínimo → testar sem correção automática → auditar diff/migrations → security scan → PR/revisão → fechar tarefa.

Regra final: o agente pode propor; o manifesto autoriza; RLS limita; RPC protege; o diff revela; o scan aponta; o humano aprova.
