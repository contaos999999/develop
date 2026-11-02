# Evidência — PROMPT 18 / SYS-03 — Envio real de recuperação

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Usuário de teste: `edivanpablo99@gmail.com`

## Procedimento
Foi utilizada exclusivamente a tela SYS-02 `/esqueci-senha` já implementada, sem alteração de código ou configuração.

Primeira interação às 10:45:55 UTC ocorreu antes da hidratação e não gerou request ao Auth. Portanto, não houve envio.

Envio real único:
- horário: 10:46:10 UTC / 07:46:10 Brasília;
- endpoint observado: `POST /auth/v1/recover`;
- resposta: HTTP 200;
- projeto: `gklhhhyosgasnyoxlrui`;
- mensagem neutra apresentada: `Solicitação recebida. Se existir uma conta vinculada a este e-mail, você receberá as instruções para redefinir sua senha. Verifique também a caixa de spam.`

## Segurança
- nenhum token/link de recuperação foi lido, capturado ou registrado;
- nenhum secret/service_role foi utilizado;
- nenhum arquivo, Auth config, senha, sessão ou banco foi alterado nesta etapa;
- git status antes/depois permaneceu idêntico.

## Gate pendente
Para concluir o item 2 do teste oficial do PROMPT 18, o proprietário da caixa de entrada deve abrir o link real diretamente em seu navegador, sem compartilhar o URL/token, concluir a redefinição e comprovar a tela de sucesso e o login posterior com a nova senha.

Até essa ação humana, o fluxo E2E real permanece `BLOQUEADO POR AÇÃO HUMANA`, não PASS por inferência.
