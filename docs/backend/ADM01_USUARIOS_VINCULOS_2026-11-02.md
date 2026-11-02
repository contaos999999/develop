# PROMPT 21 / ADM-01 — Backend de usuários e vínculos

Data: 02/11/2026
Ambiente: HML
Projeto Supabase: `gklhhhyosgasnyoxlrui`
Contrato canônico atual: `adm01-v2`

## Escopo

Backend autorizado para `/administracao/usuarios`, com Supabase como fonte única de verdade e RLS/RPC como autoridade. PROD permaneceu intocado.

## Transversais aplicáveis

- **091 / NFR-007 — concorrência:** `versao_registro`, lock transacional e `PT409` para versão divergente. Nenhuma sobrescrita silenciosa.
- **092 / NFR-008 — idempotência:** `comandos_idempotentes` + chave única por intenção lógica. Retry do mesmo payload devolve a mesma resposta sem novo efeito/auditoria.
- **093 / NFR-009 — paginação:** lista principal e escopo paginados no backend; page size limitado; ordenação determinística. O contrato v2 usa deltas de escopo para que páginas não visitadas permaneçam intactas.
- **094 / NFR-010 — observabilidade:** sem infraestrutura paralela ou log sensível. Operações materiais preservam `correlation_id` via auditoria.

## Histórico de migrations HML

A sequência aplicada e versionada é:

1. `20261102124852_adm01_admin_usuarios_vinculos.sql` — primeira superfície administrativa canônica.
2. `20261102125242_adm01_usuarios_vinculos_backend.sql` — migration intermediária aplicada no HML; criou endpoints auxiliares/redundantes.
3. `20261102125612_adm01_consolidar_contrato_publico.sql` — consolidou a superfície pública e removeu os endpoints redundantes da etapa anterior.
4. `20261102130001_adm01_scope_pagination_integrity.sql` — contrato canônico atual `adm01-v2`; corrige integridade do escopo paginado e substitui a mutação de conjunto completo por deltas `ativar/revogar`.

As migrations 2 e 3 foram recuperadas diretamente de `supabase_migrations.schema_migrations` e versionadas no GitHub para reproduzir fielmente o histórico já aplicado. Seus hashes MD5 no histórico do Supabase são, respectivamente, `4bc1723bca326dc700b7d06187a4fbae` e `3f624433a7a67f62fad2829cb2b9711a`. A migration 4 tem hash `63c650e8b7446982364c08bff9ff6221` no histórico aplicado.

## RPCs oficiais para o frontend

### `public.listar_usuarios_vinculos_adm`
Args: `p_id_organizacao uuid, p_pagina integer, p_tamanho_pagina integer, p_busca text, p_ativo boolean`

Retorno `adm01-v1`: organização, paginação, `perfis_disponiveis` e itens de vínculo com identidade básica, perfil, status e `versao_registro`.

### `public.listar_escopo_contratos_usuario_adm`
Args: `p_id_organizacao uuid, p_id_usuario uuid | null, p_pagina integer, p_tamanho_pagina integer, p_busca text`

Retorno **`adm01-v2`**. `p_id_usuario=null` é válido para o fluxo “Vincular usuário existente”. Cada item contém:
- `selecionado`: vínculo explícito ativo naquele contrato;
- `acesso_efetivo`: acesso efetivo por `escopo_todos_contratos` ou vínculo explícito.

A RPC só lista contratos dentro do escopo efetivo do administrador chamador. Paginação é real no backend.

### `public.listar_auditoria_vinculo_usuario_adm`
Args: `p_id_organizacao uuid, p_id_usuario uuid, p_pagina integer, p_tamanho_pagina integer`

Retorno `adm01-v1`: eventos materiais, ator, before/after, `correlation_id`, paginação. Eventos/contratos fora do escopo do administrador são filtrados/redigidos pelo backend.

### `public.salvar_vinculo_usuario_adm`
Assinatura canônica atual:

`p_id_organizacao uuid, p_id_usuario uuid | null, p_email text | null, p_perfil text, p_escopo_todos_contratos boolean, p_ativo boolean, p_ids_contratos_ativar uuid[], p_ids_contratos_revogar uuid[], p_versao_esperada bigint | null, p_chave_idempotencia text`

Retorno **`adm01-v2`**: `schema_versao`, `correlation_id`, `id_usuario` e vínculo atualizado.

Semântica de escopo:
- IDs em `ativar` são concedidos/reativados;
- IDs em `revogar` são revogados;
- contrato não presente em nenhum dos dois arrays fica **intacto**, mesmo que esteja em página não visitada;
- o mesmo contrato não pode estar simultaneamente nos dois arrays;
- se `escopo_todos_contratos=true` ou `ativo=false`, os vínculos explícitos ativos são desativados pelo backend;
- todos os contratos alterados precisam pertencer ao escopo efetivo do administrador.

A RPC aceita `p_id_usuario` ou resolve conta existente por `p_email`. Ela **não cria nem convida usuário no Supabase Auth**. `auth.admin.*` e `service_role` permanecem fora do navegador. Conta inexistente retorna `PT404`.

## Segurança

- wrappers públicos `SECURITY INVOKER` e `search_path=''`;
- lógica privilegiada em `privado` com validação explícita de administrador;
- `anon` sem EXECUTE;
- `authenticated` com EXECUTE apenas na superfície oficial;
- sem INSERT/UPDATE/DELETE direto em `vinculos_usuarios` ou `vinculos_usuario_contratos`;
- wrappers legados de alteração permanecem sem EXECUTE para `authenticated`;
- mutação v1 de conjunto completo foi removida para não existir caminho paralelo incompatível com a paginação;
- auditoria material registra before/after, ator e `correlation_id`.

## Testes

### Estrutural ADM-01
`supabase/tests/adm01_usuarios_vinculos.sql`

Resultado pós-v2: **11/11 PASS**, incluindo paginação, idempotência, versão stale `PT409`, auditoria, bloqueio de não administrador, grants mínimos, ausência de escrita direta e wrappers públicos `SECURITY INVOKER`.

### Regressão de escopo paginado
`supabase/tests/adm01_scope_pagination_regression.sql`

Resultado: **3/3 PASS**:
1. vínculo novo lista contratos com `p_id_usuario=null`;
2. ativar contrato em uma página preserva contrato selecionado em página não visitada;
3. revogação explícita afeta somente o contrato informado.

Todos os dados de teste foram criados em transação e finalizados com `ROLLBACK`.

## Advisors

Security Advisor pós-v2: nenhum finding novo da tarefa. Permanece apenas o warning global preexistente `Leaked Password Protection Disabled`.

Performance Advisor: apenas INFOs globais/preexistentes de FKs sem índice e índices ainda não utilizados; ADM-01 v2 não criou tabela ou índice novo.

## Frontend autorizado

O Lovable pode consumir somente:
- `getUser()` e fluxo de sessão já existente;
- preferência de organização do SYS-04;
- as 4 RPCs oficiais acima;
- `signOut()` quando aplicável.

Não pode criar backend, Edge Function, usar `auth.admin`, expor `service_role`, nem escrever diretamente nas tabelas de vínculo.

No `ContractScopeDialog`, o frontend deve manter apenas deltas locais por intenção: `ativar` e `revogar`. Trocar página/busca não pode limpar os deltas. Contratos não visitados nunca devem ser enviados como revogação implícita.

## Resultado

**BACKEND DO PROMPT 21 / ADM-01 CERTIFICADO NO HML COM CONTRATO `adm01-v2`.**

- Estrutural: 11/11 PASS.
- Regressão escopo paginado: 3/3 PASS.
- PROD intocado.
