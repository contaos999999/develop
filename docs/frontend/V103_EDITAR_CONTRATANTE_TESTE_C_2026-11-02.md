# PROMPT 24 / V1-03 — Certificação frontend

Data: 02/11/2026. Ambiente: HML. PROD não alterado.

## Estado final

- Rota: `/contratantes/$id/editar`.
- Repositório frontend: `contaos9999/contaos-hml-control`.
- HEAD certificado: `72ef720c386c672daaa2c41c12e7d7d53217b955`.
- Backend oficial: `public.atualizar_contratante(...)`, schema `v103-v1`.
- Backend `develop/main`: `8ef10ebb0066f4d6d85855da5e6f08d116957086`.
- Teste Oficial C: **18/18 PASS**.

## Evidências frescas

- V1-03 focado: **30/30 PASS**.
- Regressão completa: **238/238 PASS em 12 arquivos**.
- `tsgo --noEmit`: exit 0.
- `vite build --outDir /tmp/v103build`: exit 0, sem alterar o repositório.
- Security Scan: **0 Critical**. Permanece apenas o aviso global pré-existente `auth_leaked_password_protection`.
- Git status inicial/final: limpo; HEAD inalterado durante o Teste C.

## Concorrência otimista

- O frontend envia `p_versao_esperada` exatamente igual à `versao_registro` lida.
- Não incrementa versão no React.
- `PT409` não gera retry automático nem overwrite.
- Valores locais ficam preservados durante o conflito.
- `Recarregar versão atual` executa apenas leitura; somente em sucesso substitui formulário e versão.
- Novo salvamento exige novo clique manual e usa a nova versão lida.

## Segurança da superfície frontend

Nos arquivos novos do V1-03:

- zero `.update(`;
- zero `.insert(`;
- zero `.delete(`;
- zero `.upsert(`;
- zero `functions.invoke`;
- zero `service_role` / `sb_secret`;
- zero backend paralelo;
- única RPC de escrita: `atualizar_contratante`.

O contrato TypeScript da RPC foi incorporado a `src/integrations/supabase/types.ts`. O cast temporário criado durante o BUILD foi removido antes da certificação; o helper final usa diretamente `supabase.rpc("atualizar_contratante", args)`.

## Responsividade e acessibilidade

Browser controlado em 1440, 1280, 768 e 390 px:

- overflow horizontal relevante: 0;
- formulário, conflito e sucesso utilizáveis;
- um H1;
- labels e estados acessíveis;
- foco coerente em conflito e sucesso;
- alvos principais e tooltip compatíveis com 44 px.

A evidência de browser foi CONTROLADA por interceptação das respostas Supabase e não é apresentada como prova de RLS real. A prova de autorização/concorrência real permanece na certificação backend 9/9 com rollback integral.

## Zero-Drift

Comparação contra `46176b9b4a6fd88695ce6bb3526ae94f3fcee79a`: sete arquivos esperados do PROMPT 24 (plano arquivado, componente, tipos Supabase, helper, route tree, rota e teste). V1-01, V1-02, SYS, ADM, shared UI, `client.ts`, `package.json` e backend não foram alterados pelo frontend.

## Consumo Lovable

- PLAN: 1,0 crédito.
- BUILD retomado pelo mesmo gate do plano: 9,3 créditos.
- Teste C consolidado: 4,5 créditos.
- Correção do cast temporário: feita via GitHub, sem novo crédito Lovable.

## Conclusão

**PROMPT 24 / V1-03 — CERTIFICADO. TESTE OFICIAL C: PASS 18/18.**
