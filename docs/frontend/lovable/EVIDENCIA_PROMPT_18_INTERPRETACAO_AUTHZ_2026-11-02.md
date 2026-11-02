# PROMPT 18 / SYS-03 — Interpretação de autorização do item 3

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`

## Contexto
O teste literal do PROMPT 18 contém o critério genérico:

> perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI.

SYS-03, porém, não é uma tela de domínio protegida por RLS. O backend oficial definido pelo próprio pacote 4.1 é **Supabase Auth: `updateUser`**, com acesso da tela classificado como `público/token`.

## Semântica do backend oficial
Conforme a documentação oficial do Supabase Auth, `updateUser({ password })` é uma operação de usuário autenticado. O fluxo de recuperação cria/estabelece uma sessão válida e então utiliza `updateUser`. Uma sessão autenticada comum do próprio usuário também pode alterar a própria senha, sujeita às configurações de reautenticação do projeto.

Consequentemente, **uma sessão autenticada válida comum não é um perfil backend “não autorizado” para alterar a própria senha**. Tratar essa sessão como não autorizada pelo backend inventaria uma restrição que não existe no backend oficial autorizado pelo pacote.

A UI do SYS-03 permanece mais restritiva por finalidade de fluxo: ela só exibe o formulário quando recebe o evento `PASSWORD_RECOVERY`. Isso evita abrir a tela de recuperação por simples sessão comum, mas não é apresentado como autoridade de segurança do backend.

## Critério 3 aplicado corretamente ao SYS-03
Para o PROMPT 18, os casos realmente não autorizados pelo backend Auth são:

- ausência de Authorization/session válida;
- JWT inválido;
- sessão/token expirado ou inexistente;
- token/link de recuperação inválido.

Evidências executadas no HML:
- `PUT /auth/v1/user` sem Authorization → HTTP 401 `no_authorization`;
- JWT inválido → HTTP 403 `bad_jwt`;
- hash falso `type=recovery` → Auth rejeita e o formulário não abre;
- link/hash expirado → estado de link inválido, sem formulário;
- nenhum secret/service_role utilizado.

**Conclusão do item 3:** PASS para a semântica real do backend oficial. Não será criado backend paralelo ou restrição artificial “recovery-only” em `updateUser`.

## Pendência separada
O item 2 ainda exige evidência E2E de uma sessão real `PASSWORD_RECOVERY`, obtida pelo link real de recuperação. Não será marcado PASS por inferência ou mock.
