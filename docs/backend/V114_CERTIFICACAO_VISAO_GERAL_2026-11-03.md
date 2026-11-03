# Certificação Backend V1-14 — Competência: visão geral

Data: 03/11/2026
Ambiente: Supabase HML `gklhhhyosgasnyoxlrui`
PROD: intocado

## Objetivo

Fechar a lacuna de backend da V1-14 para que o frontend receba estado, bloqueios e `allowed_actions` do servidor, sem recalcular portão ou liberação por percentual no cliente.

## Migrations versionadas

1. `20261103093000_v114_visao_geral_competencia.sql`
   - cria `privado.obter_visao_geral_competencia(uuid)`;
   - cria wrapper público `public.obter_visao_geral_competencia(uuid)`;
   - consolida competência, portão oficial, blocking summary e allowed actions;
   - nenhuma tabela, coluna, RLS, trigger, Edge, Auth ou Storage nova.

2. `20261103093200_v114_visao_geral_wrapper_security_definer.sql`
   - corrige o wrapper público para `STABLE SECURITY DEFINER`;
   - função privada continua sem EXECUTE para authenticated;
   - wrapper público executável apenas por `authenticated`.

## Contrato da RPC pública

`public.obter_visao_geral_competencia(p_id_competencia uuid) returns jsonb`

Retorna:
- `competencia`: campos oficiais da competência, inclusive `situacao` e `percentual_conformidade` armazenados;
- `portao`: resultado oficial de `avaliar_portao_conformidade`;
- `blocking_summary`: pendentes, não conformes, inconclusivos, em análise, NCs bloqueantes, parecer aprovado, análise atual e aprovação atual;
- `allowed_actions`: `abrir_documentos`, `analisar`, `abrir_parecer`, `apresentar`.

A função é read-only: não executa análise, aprovação, apresentação, parecer ou atualização de competência.

## Segurança e autorização

- acesso exige sessão ativa e `usuario_tem_acesso_contrato`;
- outro tenant recebe SQLSTATE `42501`;
- `anon` e `public` não possuem EXECUTE no wrapper;
- `authenticated` possui EXECUTE apenas no wrapper público;
- função privada permanece sem EXECUTE direto para `authenticated`.

## Testes transacionais HML

Todos executados com fixtures sintéticas e `ROLLBACK`.

- `PASS_V114_READ_ONLY_ALLOWED_ACTIONS`
  - requisito pendente → portão não liberado;
  - `analisar=true` para perfil autorizado;
  - `apresentar=false`;
  - documentos/parecer disponíveis como affordance;
  - leitura não alterou `situacao` nem `percentual_conformidade`.

- `PASS_V114_ISOLAMENTO_TENANT`
  - competência de organização sem vínculo do usuário foi negada com `42501`.

- `PASS_V114_100_NAO_LIBERA_LOCALMENTE`
  - `percentual_conformidade=100` armazenado, mas requisito ainda pendente;
  - `portao.liberado=false`;
  - `allowed_actions.apresentar=false`.
  - prova que o frontend não pode usar `percent===100` para habilitar apresentação.

## CI/Governança

Commit das migrations finais: `d23c802b6a250740166636a9df8f81b8f0a52e0c`.

- Verificar histórico HML — run `41610412740`: **success**.
- ContaOS Restore Isolado — run `41610412819`: **success**.
- Zero-Drift inicialmente falhou apenas porque a tarefa ativa não enumerava os 22 documentos canônicos; a declaração foi corrigida sem alterar a RPC.
- Zero-Drift no head corrigido `7a4fbfa30060345f2219122ab4fd905fe707c142` — run `41610875283`: **success**.

## Status

**BACKEND V1-14 CERTIFICADO PARA FRONTEND.**

A partir deste ponto, o Prompt 35 no Lovable deve ser frontend-only e não está autorizado a criar migration, RLS, RPC, Edge Function, alteração Auth/Storage ou regenerar `types.ts`.
