# Evidência — PROMPT 16 SYS-01 Login — Teste oficial

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Commit Lovable da correção visual: `10ebeba38bcb423d39898ba73f77d77b236b697d`

## Resultado

| # | Critério oficial | Resultado | Evidência resumida |
|---|---|---|---|
| 1 | rota abre | PASS | `/login` respondeu 200 e exibiu `Bem-vindo de volta` |
| 2 | perfil autorizado funciona | BLOQUEADO/PENDENTE | Não há credencial HML válida de teste disponível; não foi inferido PASS |
| 3 | perfil não autorizado bloqueado pelo backend/RLS | PASS parcial / PENDENTE | Sem sessão, leitura e tentativa de alteração em `vinculos_usuarios` foram rejeitadas pelo backend. Cenário autenticado sem vínculo depende de credencial |
| 4 | loading/empty/error funcionam | PASS parcial / PENDENTE | Loading, validação, credencial inválida e rede offline foram confirmados. Estado real `sem acesso` pós-login depende de usuário HML sem vínculo |
| 5 | nenhuma request usa secret key | PASS | Requisições observadas usam publishable key; busca no frontend sem `service_role` ou `sb_secret_` |
| 6 | nenhuma ação crítica é update direto | PASS | SYS-01 usa autenticação e leitura; nenhuma escrita crítica direta encontrada |
| 7 | desktop 1440 e 1280 | PASS | Sem overflow horizontal; formulário e bloco `Acesso protegido` visíveis |
| 8 | tablet 768 | PASS | Faixa institucional compacta; sem overflow horizontal |
| 9 | mobile 390 preserva dados críticos | PASS | Formulário, contexto de homologação e `Acesso protegido` preservados |
| 10 | teclado/foco/labels | PASS | Foco inicial, botão de senha, Enter, labels e tooltip por foco/hover verificados |
| 11 | console sem erro e sem log sensível | PASS com ressalva | Sem log da aplicação ou dado sensível. Erros de rede observados foram respostas esperadas dos testes negativos deliberados |
| 12 | Security scan sem novo Critical | PASS | Lovable informou nenhum achado novo ligado ao SYS-01. O scan também reportou alertas preexistentes de backend, fora do escopo desta tarefa; nenhum foi alterado nesta execução |

## Situação do gate

`PROMPT 16`: **NÃO FECHADO**.

Bloqueadores remanescentes para PASS integral:
1. login válido com usuário HML autorizado;
2. usuário HML autenticado sem vínculo/permissão para validar o bloqueio real pós-login;
3. estado `sem acesso`/leitura de vínculos em sessão real.

A ausência dessas credenciais não autoriza criar usuário, mudar Auth, RLS ou backend dentro da tarefa de frontend. A tarefa ativa tem `auth_changes_allowed=false`.

## Governança

- O próximo prompt não deve ser iniciado enquanto os itens obrigatórios do PROMPT 16 não forem fechados ou houver decisão expressa e formal de governança para tratar o bloqueio em tarefa separada.
- Nenhum secret deve ser solicitado ou registrado em GitHub/chat.
- `AGENTS.md` alterado indevidamente no BUILD inicial foi revertido no Lovable e não será espelhado como alteração canônica.
