# V1-06 — Contrato: visão geral — Backend HML

Data: 02/11/2026  
Prompt: 27  
Ambiente: HML Supabase `gklhhhyosgasnyoxlrui`  
PROD: **não alterado**

## Objetivo

Suportar a rota `/contratos/:id` com leitura oficial via Data API + RLS e distinção segura entre contrato inexistente e contrato existente no mesmo tenant, porém fora do escopo do usuário.

## Contrato principal de leitura

O happy path permanece em `public.contratos` via Data API. A policy `contratos_select` usa `privado.usuario_tem_acesso_contrato(id)`, preservando isolamento por contrato e o Administrador Master global.

Não foi criado endpoint paralelo para leitura de detalhes e não foi criada Edge Function.

## Lacuna 403/404 identificada

Um `SELECT ... WHERE id = :id` sob RLS retorna zero linhas tanto para registro inexistente quanto para registro existente mas invisível. O requisito V1-06 exige 404 e 403 distintos.

Foi criada a RPC pública somente leitura:

`public.classificar_acesso_contrato_v106(p_id_contrato uuid) -> text`

Uso previsto: **somente depois** de o SELECT Data API do detalhe retornar zero linhas.

Resultados possíveis:

- `permitido`: usuário possui acesso contratual;
- `negado`: contrato existe e o usuário já pertence à mesma organização, mas não possui acesso àquele contrato;
- `nao_encontrado`: contrato inexiste ou pertence a outro tenant.

A existência de contrato de outro tenant é mascarada como `nao_encontrado`, evitando enumeração/oráculo cross-tenant.

Privilégios: `authenticated` possui EXECUTE; `anon` não possui EXECUTE.

## TDD e evidências

RED inicial: `to_regprocedure('public.classificar_acesso_contrato_v106(uuid)')` retornou `false` antes da migration.

Teste versionado: `supabase/tests/v106_contrato_visao_geral_acesso.sql`.

Resultado HML após implementação e após hardening: **10/10 PASS com ROLLBACK**.

Cobertura:

1. RPC somente para authenticated;
2. RLS lê contrato autorizado;
3. RLS oculta contrato do mesmo tenant sem escopo;
4. autorizado classifica `permitido`;
5. mesmo tenant sem escopo classifica `negado`;
6. inexistente classifica `nao_encontrado`;
7. cross-tenant existente continua mascarado como `nao_encontrado`;
8. contratante relacionado é legível no tenant ativo;
9. Administrador Master sem vínculo físico classifica contrato existente como `permitido`;
10. RLS permite leitura do contrato ao Administrador Master.

## Hardening BOLA descoberto durante a regressão

A regressão `supabase/tests/contract_scope_bola.sql` revelou um desvio pré-existente em `privado.aprovar_parecer_interno`: a função `SECURITY DEFINER` validava perfil na organização, mas não `usuario_tem_acesso_contrato(v.id_contrato)`.

Como a atualização era executada sob função privilegiada, o trigger genérico de mutação não substituía essa checagem explícita.

RED da regressão após atualização do fixture para o schema atual: **5/7**, com aprovação indevida do parecer do Contrato B.

Correção aplicada em `20261102193500_v106_corrigir_bola_aprovar_parecer_interno.sql`:

- exige sessão/usuário;
- exige `privado.usuario_tem_acesso_contrato(v.id_contrato)`;
- mantém exigência do perfil autorizado na organização;
- negação usa SQLSTATE `42501`;
- fluxo permitido e segregação autor/revisor foram preservados.

Resultado pós-correção: **7/7 PASS com ROLLBACK**. O Contrato A permanece permitido; o Contrato B retorna `42501` e permanece inalterado.

Também foi atualizado apenas o fixture de `contract_scope_bola.sql` para informar `inicio`, hoje obrigatório no schema.

## Migrations

- `20261102192500_v106_classificar_acesso_contrato_detalhe.sql`
- `20261102193500_v106_corrigir_bola_aprovar_parecer_interno.sql`

## Tipagem oficial

Tipos gerados diretamente do HML confirmam:

```ts
classificar_acesso_contrato_v106: {
  Args: { p_id_contrato: string }
  Returns: string
}
```

O frontend deverá sincronizar exatamente essa assinatura, sem casts improvisados.

## Security Advisor

Pós-DDL: nenhum novo finding de banco relacionado às migrations V1-06.

Permanece o aviso global pré-existente `auth_leaked_password_protection` — Leaked Password Protection Disabled.

Remediação oficial: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Restrições para o frontend

- happy path: Data API + RLS, por `id` do contrato;
- não inferir autorização pela organização armazenada no cliente;
- RPC `classificar_acesso_contrato_v106` somente após zero linhas;
- 403 somente para `negado`;
- 404 para `nao_encontrado`;
- `permitido` após zero linhas é inconsistência e deve virar erro genérico, nunca bypass;
- não carregar documentos/competências no primeiro paint;
- não implementar edição de contrato neste prompt sem contrato canônico específico de edição/concurrency;
- PROD permanece intocado.
