# ContaOS V1 — protocolo de estado persistente (proposta)
## Escopo
Executor ChatGPT permanece horário. Este controlador apenas **lê** checkpoints no GATE #138 e reconcilia um Run ID real com GitHub Actions. Não dispara, altera ou certifica nada. Não requer Codex, cron de cinco minutos ou OpenAI API Key.
## Persistência
Um comentário GitHub com marcador `CONTAOS_EXECUTOR_STATE_V1` e JSON é um evento append-only. O comentário mais recente válido (por ID crescente) prevalece. O executor deve registrar um novo comentário após cada transição. Não modificar checkpoints anteriores. O GitHub é fonte da verdade; não confiar em resumos de conversa.
Exemplo:
```html
<!-- CONTAOS_EXECUTOR_STATE_V1
{"schema":1,"phase_id":3,"task_id":"fixtures-schema","head_sha":"5eca44aebead3183e81b5c1af0d1dffa5fb8feb6","pr_number":null,"run_id":null,"status":"BLOCKED","conclusion":null,"evidence":[],"next_action":"Reconciliar SHA e Run ID do workflow original"}
-->
```
## Ciclo obrigatório (horário)
1. Executar leitura do último comentário válido, recuperar phase/task/HEAD/PR/run.
2. Consultar GitHub real e reconciliar HEAD do run; se pendente, **aguardar**.
3. Se falhou, investigar causa e registrar BLOQUEADO; não repetir cegamente.
4. Se sucesso, verificar CI, LOCK, Zero-Drift, revisão independente e evidências; sucesso do workflow não certifica a fase.
5. Somente então escolher próxima ação autorizada e gravar novo comentário.
## Limites
Leitor é read-only e sempre devolve `dispatch_allowed:false`. Não fornece exclusão mútua transacional entre múltiplos escritores; para habilitar dispatch automático concorrente é obrigatório adicionar lease/CAS com fencing e testes. Nunca usar comentário como autorização para bypass de gates. O GATE #138 está fechado e é usado somente como histórico de checkpoint.
## Uso
`GITHUB_TOKEN=<token read-only> node scripts/executor-state-controller.mjs`.
Nunca registrar tokens em logs. O ChatGPT pode executar o mesmo protocolo por ferramentas GitHub sem acessar segredos.
