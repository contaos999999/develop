# Evidência — PROMPT 17 / SYS-02 — TESTE OFICIAL

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Branch: `design/frontend-master-plan`

## Conclusão

`PROMPT 17: FAIL`

Motivo único de falha: o tooltip/dica de segurança funciona por foco/teclado e mouse, mas não permaneceu aberto por toque simulado em viewport mobile 390 px. O teste foi interrompido imediatamente após o FAIL, conforme protocolo. Nenhuma correção automática foi aplicada.

## Gates técnicos

- Typecheck completo: PASS, sem erros.
- Vitest completo: PASS, 20/20 testes.
- Build de produção: PASS, concluído sem erros, saída temporária fora do projeto.
- Nenhum arquivo protegido do backend alterado: PASS.
- Nenhum `sb_secret` ou `service_role` introduzido: PASS.
- Arquivos alterados durante o TESTE: zero.

## Tabela 25/25

| # | Critério | Resultado | Evidência |
|---|---|---|---|
| 1 | Typecheck | PASS | Sem erros. |
| 2 | Vitest | PASS | 20/20. |
| 3 | Build de produção | PASS | Exit sem erro. |
| 4 | Nenhum arquivo protegido alterado | PASS | SYS-02 limitado à rota, formulário, teste, link do Login e routeTree. |
| 5 | Nenhuma chave secreta | PASS | Sem `sb_secret`/`service_role` nos arquivos SYS-02 e build. |
| 6 | E-mail inválido não chama Supabase | PASS | Teste automático. |
| 7 | Duplo envio = uma chamada | PASS | Teste automático. |
| 8 | redirectTo termina em `/redefinir-senha` | PASS | Teste automático e request real. |
| 9 | Erros de enumeração normalizados | PASS | `user_not_found`, rate limits cobertos; `email_not_found` tratado no código. |
| 10 | Erro inesperado/rede seguro | PASS | Mensagem genérica, sem retry automático. |
| 11 | `/esqueci-senha` abre | PASS | HTTP 200 e um único H1 `Recuperar acesso`. |
| 12 | Navegação Login → Esqueci → Voltar | PASS | Fluxo termina em `/login`. |
| 13 | Responsividade 1440/1280/768/390 | PASS | Sem overflow horizontal; ações críticas visíveis. |
| 14 | Teclado/labels/ARIA | PASS | Tab, label, aria-invalid/aria-describedby, aria-busy/aria-live validados. |
| 15 | Tooltip hover/foco/toque | **FAIL** | Hover e foco PASS; toque simulado mobile não abriu/permanecia aberto. |
| 16 | Console | PASS | Sem erro de aplicação ou dado sensível; apenas aviso de rede do 429 esperado. |
| 17 | Pedidos reais HML | PASS | 1 existente e 1 inexistente, sem expor tokens/credenciais. |
| 18 | UI idêntica anti-enumeração | PASS | Backend respondeu diferente, UI final ficou idêntica. |
| 19 | E-mail não reexibido no sucesso | PASS | Nenhum e-mail completo na tela final. |
| 20 | Network oficial | PASS | Somente `/auth/v1/recover`, publishable key, nenhum endpoint próprio. |
| 21 | Sem sessão/token persistido | PASS | localStorage vazio; sessionStorage sem sessão/token. |
| 22 | Security scan | NÃO EXECUTADO | Teste interrompido após FAIL do item 15. |
| 23 | 429 normalizado | PASS | 429 real mapeado para sucesso neutro, sem retry. |
| 24 | SYS-03 inexistente | REGISTRADO | `/redefinir-senha` é dependência futura. |
| 25 | Allowlist Auth não certificada | REGISTRADO | Sandbox não permite provar Redirect URLs; Auth config não foi alterado. |

## Teste real anti-enumeração

Foram feitos no máximo dois pedidos reais, conforme plano:

- e-mail existente de teste: backend respondeu HTTP 429 / `over_email_send_rate_limit`;
- e-mail reservado inexistente: backend respondeu HTTP 200.

Apesar da diferença de backend, a implementação atual classificou ambos para a mesma resposta visual neutra:

> Se existir uma conta vinculada a este e-mail, você receberá as instruções para redefinir sua senha.

O e-mail não foi reexibido na tela de sucesso, não foi criada sessão e não houve access token ou refresh token.

## Falha do item 15

Componente atual:
- `Tooltip open={dicaAberta} onOpenChange={setDicaAberta}`
- trigger também executa `onClick={() => setDicaAberta((v) => !v)}`.

Hipótese técnica a confirmar na correção: no toque, o Radix pode abrir/fechar por eventos próprios e o `onClick` alterna novamente o estado, fechando imediatamente.

## Microcorreção proposta

Escopo exclusivo: `frontend/src/components/auth/ForgotPasswordForm.tsx`.

Objetivo: garantir que interação por toque abra a dica sem alternância dupla, preservando hover e foco. A solução deve evitar cooldown, backend, Auth config ou qualquer mudança fora da UI.

Após correção, reexecutar:
1. teste específico do tooltip por foco/hover/toque;
2. typecheck;
3. Vitest completo;
4. build;
5. browser 390/768/1280/1440;
6. security scan;
7. checklist final do PROMPT 17.

Nenhuma correção foi aplicada nesta rodada.
