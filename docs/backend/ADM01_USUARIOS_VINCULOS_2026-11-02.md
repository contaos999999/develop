# PROMPT 21 / ADM-01 — Backend de usuários e vínculos

Data: 02/11/2026  
Ambiente: HML  
Projeto Supabase: `gklhhhyosgasnyoxlrui`  
Branch: `feature/adm-01-usuarios-vinculos`

## Escopo

Preparação e endurecimento do backend autorizado para a rota `/administracao/usuarios`, preservando Supabase como fonte única de verdade, RLS/escopo de contrato como autoridade e ausência de `service_role` no navegador. Nenhum recurso de PROD foi alterado.

O frontend do PROMPT 21 ainda não está certificado. Este documento certifica o contrato de banco HML e o deploy da Edge de convite. A chamada autenticada real da Edge pelo navegador permanece como prova obrigatória do Teste C do frontend.

## PROMPT regular e transversais aplicáveis

PROMPT regular: **21 / ADM-01 — Usuários e vínculos**.

Aplicáveis cumulativamente:

- auditoria material dos vínculos e escopo, em linha com os requisitos transversais de auditoria aplicáveis;
- **091 / NFR-007 — concorrência:** `versao_registro`, row lock e advisory lock transacional. Versão divergente retorna `PT409` e nunca há sobrescrita silenciosa;
- **092 / NFR-008 — idempotência:** `comandos_idempotentes`, chave única por organização/comando/chave e replay sem duplicação de efeito/auditoria;
- **093 / NFR-009 — paginação:** usuários e contratos limitados a 100 itens por página; auditoria limitada a 50; ordenação determinística;
- **094 / NFR-010 — observabilidade:** `correlation_id` via auditoria, mensagens sem segredo e nenhuma infraestrutura paralela criada.

## Migrations HML relacionadas ao ADM-01

1. `20261102124852_adm01_admin_usuarios_vinculos`
2. `20261102125242_adm01_usuarios_vinculos_backend`
3. `20261102125612_adm01_consolidar_contrato_publico`
4. `20261102130001_adm01_scope_pagination_integrity`
5. `20261102131014_adm01_uniformizar_schema_v2`
6. `20261102131140_adm01_redigir_metadados_auditoria`

Todas foram versionadas na branch. A migration intermediária de 12:52 foi mantida no GitHub porque ela existe no histórico real do HML; as migrations posteriores consolidam a superfície pública canônica.

## Contrato canônico final — ADM01-v2

Todos os wrappers públicos abaixo são `SECURITY INVOKER`, usam `search_path=''`, não concedem EXECUTE a `anon` e concedem EXECUTE a `authenticated`.

### `public.validar_administrador_organizacao`

Args: `p_id_organizacao uuid`  
Retorno: `boolean`.

Valida sessão/perfil administrador no backend. Não confiar em ocultação de botão ou papel calculado apenas no frontend.

### `public.listar_usuarios_vinculos_adm`

Args: `p_id_organizacao uuid, p_pagina integer, p_tamanho_pagina integer, p_busca text, p_ativo boolean`  
Retorno: `jsonb`, `schema_versao=adm01-v2`.

Traz lista paginada, identidade básica, vínculo, `versao_registro` e catálogo oficial de perfis. O frontend não lê `auth.users`.

### `public.listar_escopo_contratos_usuario_adm`

Args: `p_id_organizacao uuid, p_id_usuario uuid, p_pagina integer, p_tamanho_pagina integer, p_busca text`  
Retorno: `jsonb`, `schema_versao=adm01-v2`.

Retorna somente contratos dentro do escopo efetivo do administrador chamador, com `selecionado` e `acesso_efetivo`. O frontend não pode reconstruir uma lista global de contratos fora desta API.

### `public.listar_auditoria_vinculo_usuario_adm`

Args: `p_id_organizacao uuid, p_id_usuario uuid, p_pagina integer, p_tamanho_pagina integer`  
Retorno: `jsonb`, `schema_versao=adm01-v2`.

Traz eventos materiais do vínculo, ator, `correlation_id`, before/after e metadados. A leitura redige contratos fora do escopo do administrador inclusive em:

- `antes.escopo_contratos`;
- `depois.escopo_contratos`;
- `metadados.id_contrato`;
- `metadados.ids_contratos_ativar`;
- `metadados.ids_contratos_revogar`.

O registro bruto de `eventos_auditoria` permanece íntegro.

### `public.salvar_vinculo_usuario_adm`

Args:

`p_id_organizacao uuid, p_id_usuario uuid, p_email text, p_perfil text, p_escopo_todos_contratos boolean, p_ativo boolean, p_ids_contratos_ativar uuid[], p_ids_contratos_revogar uuid[], p_versao_esperada bigint, p_chave_idempotencia text`

Retorno: `jsonb`, `schema_versao=adm01-v2`, `correlation_id`, `id_usuario` e vínculo atualizado.

Regras obrigatórias para o frontend:

- conta já existente pode ser localizada por `p_id_usuario` ou `p_email`;
- para vínculo existente, enviar a `versao_registro` lida da API como `p_versao_esperada`;
- `PT409` exige recarregar/revisar, nunca sobrescrever silenciosamente;
- mudança de perfil/vínculo não é otimista;
- contrato não deve ser enviado como “lista final”. O frontend deve comparar a seleção atual devolvida pela API com a nova seleção do usuário e enviar somente o delta em `p_ids_contratos_ativar` e `p_ids_contratos_revogar`;
- o backend rejeita contrato fora do escopo do administrador;
- se `escopo_todos_contratos=true` ou `ativo=false`, os arrays de delta não são usados para ampliar acesso;
- a operação é atômica, idempotente e auditada.

## Edge Function oficial de identidade

Função: `admin-invite-user`  
HML: `ACTIVE`, versão 2  
`verify_jwt=true`.

Responsabilidade limitada:

1. validar sessão do chamador;
2. validar administrador da organização via RPC oficial;
3. localizar conta existente por e-mail exato ou enviar convite com `auth.admin.inviteUserByEmail` server-side;
4. aplicar idempotência própria ao convite;
5. retornar somente a identidade necessária para a próxima ação.

Ela **não salva perfil, situação ou escopo contratual**. Após a identidade ser localizada/convidada, o frontend chama `salvar_vinculo_usuario_adm`.

`SUPABASE_SERVICE_ROLE_KEY` permanece somente no ambiente server-side da Edge. Nenhuma chave privilegiada é enviada ao navegador.

## Segurança

- RLS continua autoridade sobre os dados expostos;
- nenhuma permissão de INSERT/UPDATE/DELETE direto foi concedida ao frontend em `vinculos_usuarios` ou `vinculos_usuario_contratos`;
- wrappers legados `definir_vinculo_usuario` e `definir_acesso_contrato_usuario` permanecem sem EXECUTE para `authenticated`;
- `anon` não executa as RPCs canônicas;
- contratos fora do escopo não podem ser atribuídos nem descobertos pelo AuditDrawer;
- alterações materiais geram before/after, metadados e `correlation_id`;
- conflito de versão/idempotência usa `PT409`, evitando sobrescrita silenciosa e evitando tratar conflito de negócio como retry transacional `40001`.

## Teste transacional final

Arquivo: `supabase/tests/adm01_usuarios_vinculos.sql`.

Dados sintéticos, execução em transação e `ROLLBACK` integral.

Resultado final do estado atual: **15/15 PASS, falhas=[]**.

Cobertura:

1. administrador autorizado;
2. lista, escopo e auditoria uniformes em `adm01-v2`;
3. limites de paginação 100/100/50;
4. vínculo de conta existente por e-mail;
5. escopo vindo da API com seleção real;
6. replay idempotente sem duplicar efeito/auditoria;
7. mesma chave com payload diferente retorna `PT409`;
8. versão stale retorna `PT409`;
9. edição atômica ativa um contrato, revoga outro e altera perfil;
10. nova leitura de escopo reflete o delta aplicado;
11. auditoria `adm01-v2` registra a mudança;
12. não administrador recebe bloqueio real `42501`;
13. administrador restrito lista somente contrato do próprio escopo;
14. administrador restrito não altera e não descobre contrato oculto, inclusive em metadados de auditoria;
15. privilégios mínimos e wrappers legados sem bypass.

## Advisors

No fechamento anterior, o Security Advisor não apresentou finding novo da tarefa; permaneceu apenas o warning global preexistente de proteção contra senhas vazadas desabilitada. Como regra de fechamento, o Advisor deve ser reexecutado após as migrations finais antes da liberação do PLAN.

## Estado para o frontend

**Contrato SQL do backend HML: certificado 15/15.**

**Edge de convite: deploy compilado/ativo v2 e JWT obrigatório confirmados.**

Prova ainda pendente para fechamento completo do PROMPT 21: chamada autenticada real da Edge no navegador, tratamento de estados e responsividade/acessibilidade no Teste C do Lovable.

PROD intocado.
