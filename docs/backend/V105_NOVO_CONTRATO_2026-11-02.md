# V1-05 — Novo contrato — Backend HML

Data: 02/11/2026  
Pacote canônico: ContaOS 4.1  
Supabase HML: `gklhhhyosgasnyoxlrui`  
PROD: intocado

## Gap identificado antes do frontend

A policy `contratos_insert` já permitia INSERT para `administrador` e `gestor_contrato`, porém um usuário com `escopo_todos_contratos=false` criava o contrato e não recebia escopo explícito no novo registro. Consequências comprovadas por teste sintético com `ROLLBACK`:

- INSERT simples sem RETURNING: acontecia;
- vínculo em `vinculos_usuario_contratos`: ausente;
- `privado.usuario_tem_acesso_contrato(novo_id)`: false;
- evento `ContratoCriado`: ausente;
- INSERT com RETURNING podia falhar porque a policy de SELECT ainda não via o novo contrato.

RED real: `inseriu=true`, `auto_escopo=false`, `auditado=false`, `visivel_criador=false`.

## Correção aplicada no HML

### Migration 1
`20261102173500_v105_contrato_criado_escopo_auditoria.sql`

Cria trigger AFTER INSERT `contaos_contrato_pos_insert_v105` e função privada SECURITY DEFINER `privado.pos_processar_contrato_criado_v105()`.

Após um INSERT já autorizado pela policy:

1. se o criador autenticado possui vínculo ativo e escopo restrito, cria vínculo explícito em `vinculos_usuario_contratos` para o contrato novo;
2. se o criador já possui `escopo_todos_contratos=true`, não cria vínculo redundante;
3. registra auditoria única `ContratoCriado`, com snapshot reduzido e `origem_operacao=v105.data_api_insert`.

A função privada não é executável por `anon` nem `authenticated`.

### Migration 2
`20261102174200_v105_confiar_mutacao_interna_escopo.sql`

O hardening `privado.bloquear_mutacao_fora_escopo_contrato()` bloqueava circularmente o grant interno porque o usuário ainda não tinha acesso ao contrato. A função foi preservada e passou a distinguir operação interna efetivamente executada como `postgres/service_role` de operação de cliente.

O cliente `authenticated` continua:

- sem privilégio INSERT em `vinculos_usuario_contratos`;
- submetido a `usuario_tem_acesso_contrato` nas mutações permitidas;
- incapaz de autoconceder escopo pela Data API.

## Contrato frontend resultante

V1-05 continua usando **Data API + RLS**, sem nova RPC e sem Edge.

O INSERT de contrato deve ser feito com `supabase.from('contratos').insert(payload)` **sem encadear `.select()`/RETURNING**. Depois da conclusão do INSERT, o trigger já concedeu o escopo quando necessário e a listagem/leitura subsequente funciona pela RLS normal.

Defaults oficiais preservados pelo banco:

- `situacao = 'rascunho'`;
- `criticidade = 'media'`;
- `versao_registro = 1`.

## Certificação final

Teste sintético real no HML com dados temporários e `ROLLBACK`: **11/11 PASS**.

Casos:

1. trigger/função privada e sem EXECUTE por cliente;
2. `authenticated` sem INSERT em tabela de escopo;
3. gestor restrito cria contrato por INSERT sem RETURNING;
4. gestor restrito recebe escopo explícito e acesso após criação;
5. auditoria `ContratoCriado` única, reduzida e com defaults oficiais;
6. administrador com escopo total cria normalmente;
7. escopo total não gera vínculo explícito redundante e mantém acesso;
8. duplicidade `(id_organizacao, numero)` preserva SQLSTATE `23505`;
9. vigência inválida preserva `23514`;
10. contratante de outra organização preserva FK composta e `23503`;
11. perfil leitor continua bloqueado pela RLS com `42501`.

Security Advisor pós-DDL: nenhum finding novo relacionado ao V1-05; permanece somente o aviso global pré-existente `auth_leaked_password_protection`.

## Conclusão

**BACKEND V1-05 APTO PARA FRONTEND.** Nenhuma RPC/Edge nova é necessária. A autoridade permanece RLS + constraints + triggers internos auditáveis.
