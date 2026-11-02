# PROMPT 21 / ADM-01 — Backend de usuários e vínculos

Data: 02/11/2026
Ambiente: HML
Projeto Supabase: `gklhhhyosgasnyoxlrui`
Branch: `feature/adm-01-usuarios-vinculos`

## Escopo

Preparação do backend autorizado para a rota `/administracao/usuarios`, preservando Supabase como fonte única de verdade e RLS como autoridade. Nenhum recurso de PROD foi alterado.

## Transversais aplicáveis

- **091 / NFR-007 — concorrência:** a mutação administrativa usa `versao_registro`, `SELECT ... FOR UPDATE` e advisory lock transacional. Versão divergente retorna `PT409` e não sobrescreve silenciosamente.
- **092 / NFR-008 — idempotência:** `salvar_vinculo_usuario_adm` usa `comandos_idempotentes` e a chave única já existente `(id_organizacao, comando, chave)`. Repetição com mesma chave/payload devolve a mesma resposta sem novo efeito nem nova auditoria.
- **093 / NFR-009 — paginação:** as RPCs de lista limitam `tamanho_pagina` a 100; a auditoria limita a 50; ordenação é determinística.
- **094 / NFR-010 — observabilidade:** requisito operacional global verificado no fechamento. A mudança produz `correlation_id` via auditoria e não adiciona logs/secrets nem infraestrutura paralela.

## Migration HML

`20261102124852_adm01_admin_usuarios_vinculos`

Arquivo versionado:
`supabase/migrations/20261102124852_adm01_admin_usuarios_vinculos.sql`

## RPCs oficiais para o frontend

### `public.listar_usuarios_vinculos_adm`
Args: `p_id_organizacao uuid, p_pagina integer, p_tamanho_pagina integer, p_busca text, p_ativo boolean`
Retorno: `jsonb`, `schema_versao=adm01-v1`.
Inclui organização, paginação, perfis disponíveis e itens com identidade básica e versão do vínculo.

### `public.listar_escopo_contratos_usuario_adm`
Args: `p_id_organizacao uuid, p_id_usuario uuid, p_pagina integer, p_tamanho_pagina integer, p_busca text`
Retorno: contratos do próprio escopo efetivo do administrador, com `selecionado`, paginação e `schema_versao=adm01-v1`.

### `public.listar_auditoria_vinculo_usuario_adm`
Args: `p_id_organizacao uuid, p_id_usuario uuid, p_pagina integer, p_tamanho_pagina integer`
Retorno: eventos materiais do vínculo, `correlation_id`, ator, antes/depois, paginação e `schema_versao=adm01-v1`.

### `public.salvar_vinculo_usuario_adm`
Args: `p_id_organizacao uuid, p_id_usuario uuid, p_email text, p_perfil text, p_escopo_todos_contratos boolean, p_ativo boolean, p_ids_contratos uuid[], p_versao_esperada bigint, p_chave_idempotencia text`
Retorno: `schema_versao=adm01-v1`, `correlation_id`, usuário e vínculo atualizado.

A RPC aceita `p_id_usuario` ou, para vincular conta já existente, `p_email`. Ela **não cria/convida usuário no Supabase Auth**. `auth.admin.*` permanece fora do navegador e nenhuma `service_role` é exposta. Conta inexistente retorna `PT404` com orientação para vincular uma conta ContaOS existente.

## Segurança

- wrappers públicos: `SECURITY INVOKER`, `search_path=''`;
- lógica privada: `SECURITY DEFINER` com checagem explícita de sessão ativa + perfil `administrador`;
- `anon`: sem EXECUTE;
- `authenticated`: EXECUTE somente nos novos wrappers oficiais;
- INSERT/UPDATE/DELETE direto em `vinculos_usuarios` e `vinculos_usuario_contratos` permanece revogado;
- wrappers legados `definir_vinculo_usuario` e `definir_acesso_contrato_usuario` tiveram EXECUTE revogado de `authenticated`, eliminando bypass de concorrência/idempotência;
- o administrador só lista/atribui contratos do próprio escopo efetivo;
- alterações materiais geram auditoria com before/after e `correlation_id`.

## Testes

Arquivo: `supabase/tests/adm01_usuarios_vinculos.sql`.
Dados sintéticos em transação com `ROLLBACK` integral.

Resultado: **11/11 PASS**:
1. lista paginada + identidade segura;
2. page size limitado;
3. idempotência sem efeito/auditoria duplicados;
4. escopo contratual sincronizado atomicamente;
5. versão stale retorna `PT409`;
6. Audit Drawer paginado encontra a mudança;
7. não administrador bloqueado no backend;
8. anon sem EXECUTE e authenticated com EXECUTE nas RPCs novas;
9. wrappers legados sem bypass;
10. sem escrita direta nas tabelas de vínculo;
11. wrappers públicos confirmados como SECURITY INVOKER.

## Advisors

Security Advisor pós-migration: nenhum finding novo da tarefa. Permanece apenas o warning global preexistente `Leaked Password Protection Disabled`.

Performance Advisor: somente INFOs globais/preexistentes de FKs sem índice e índices ainda não utilizados; nenhum objeto novo de tabela/índice foi criado por ADM-01.

## Frontend autorizado

O Lovable pode consumir exclusivamente as 4 RPCs acima para ADM-01, além de `getUser()`, preferência de organização já existente e `signOut()` quando necessário. Não criar backend paralelo, Edge Function ou chamada `auth.admin` no frontend.

## Resultado

**LACUNA DE BACKEND DO PROMPT 21: RESOLVIDA NO HML.**

PROD intocado.
