# V1-03 / PROMPT 24 — Backend de edição de contratante

Data: 02/11/2026. Ambiente: HML. PROD não alterado.

## Objetivo

Fechar a lacuna backend necessária para a tela `V1-03 — Editar contratante`, atendendo NFR-007 de concorrência otimista, isolamento por organização/perfil e auditoria de mutação material.

## Lacuna encontrada

A tabela `public.contratantes` já possuía RLS de UPDATE, grant para `authenticated` e trigger `contaos_versao_contratantes`, mas o fluxo existente não atendia integralmente o contrato da V1-03:

- o cliente teria de enviar manualmente `versao_registro = old + 1`;
- conflito do trigger genérico usava SQLSTATE `40001`, não o contrato explícito 409 da V1-03;
- não existia auditoria de UPDATE de contratante;
- havia incremento duplo de `versao_registro`: `contaos_versao_contratantes` e `contratantes_touch`/`privado.tocar_atualizado_em()` incrementavam a mesma coluna.

## Solução certificada

### RPC pública

`public.atualizar_contratante(
  p_id_organizacao uuid,
  p_id_contratante uuid,
  p_versao_esperada bigint,
  p_tipo_pessoa text,
  p_documento text,
  p_razao_social text,
  p_nome_fantasia text,
  p_contato jsonb,
  p_situacao text
) -> jsonb`

- wrapper `SECURITY INVOKER`;
- `anon` sem EXECUTE;
- `authenticated` com EXECUTE;
- chama `privado.atualizar_contratante`.

### Operação privada

`privado.atualizar_contratante` é `SECURITY DEFINER`, `search_path=''` e valida no servidor:

1. sessão autenticada;
2. perfil `administrador` ou `gestor_contrato` na organização;
3. versão esperada válida;
4. razão social não vazia;
5. registro existente na mesma organização;
6. bloqueio da linha por `SELECT ... FOR UPDATE`;
7. comparação entre `p_versao_esperada` e `versao_registro` atual;
8. conflito retorna `PT409` antes de qualquer escrita;
9. atualização dos campos editáveis;
10. auditoria material `ContratanteAtualizado`.

O frontend envia a versão que leu. Ele não incrementa a versão. O trigger canônico da tabela faz o incremento server-side.

### Auditoria

Evento: `ContratanteAtualizado`.

`antes` e `depois` são reduzidos aos campos não sensíveis necessários para rastreabilidade:
- tipo de pessoa;
- razão social;
- nome fantasia;
- situação;
- versão do registro.

`metadados` registra:
- `versao_anterior`;
- `versao_nova`;
- lista de `campos_alterados`.

Valores de `contato` e documento não são copiados para `antes`/`depois` do evento.

## Correção do incremento duplo

Foi criada `privado.tocar_atualizado_em_contratante()` e somente o trigger `contratantes_touch` passou a usá-la. Essa função atualiza apenas `atualizado_em`.

A função global `privado.tocar_atualizado_em()` não foi modificada, evitando impacto em outras tabelas. Para `contratantes`, `contaos_versao_contratantes` permanece como único responsável por `versao_registro`.

## Migrations HML

1. `v103_editar_contratante_concorrencia_auditoria`
   - fonte versionada: `supabase/migrations/20261102163500_v103_editar_contratante_concorrencia_auditoria.sql`
2. `v103_corrigir_incremento_duplo_contratante`
   - fonte versionada: `supabase/migrations/20261102164200_v103_corrigir_incremento_duplo_contratante.sql`

Migrations aplicadas no HML; migrations anteriores não foram reescritas.

## TDD e certificação

RED comprovado antes da migration: a RPC `public.atualizar_contratante(...)` não existia.

Teste final: `supabase/tests/v103_editar_contratante.sql`.

Resultado fresco: **9/9 PASS**, com dados sintéticos e `ROLLBACK` integral.

Cobertura:
1. contrato da RPC e privilégios;
2. happy path com versão 1 -> 2 server-side;
3. persistência e preservação da organização;
4. auditoria material reduzida;
5. versão stale -> `PT409`;
6. stale não altera nem duplica auditoria;
7. documento duplicado continua `23505`;
8. perfil leitor bloqueado;
9. isolamento entre organizações.

## Security Advisor

Após DDL, nenhum novo finding relacionado à V1-03. Permanece apenas o aviso global pré-existente `auth_leaked_password_protection` (Leaked Password Protection Disabled), fora do escopo deste prompt.

## Contrato TypeScript

Tipos regenerados diretamente do HML expõem `public.atualizar_contratante` com os 9 argumentos oficiais e retorno `Json`.

## Estado final

- backend V1-03 HML: certificado;
- frontend V1-03: ainda pendente de PLAN/BUILD/Teste C;
- PROD: intocado.
