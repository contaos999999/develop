# Certificação Frontend HML — V1-12 Competências

**Data:** 03/11/2026  
**Prompt:** 33  
**Tela:** V1-12 — Competências  
**Repositório frontend:** `contaos9999/contaos-hml-control`  
**Branch:** `main`  
**SHA final consolidado:** `b22dfd93c61f8be3970b5c01c8e0af2f0e40241e`  
**Árvore funcional auditada:** equivalente byte a byte a `ad834ad368e99d7b32a5820b97e922a29e397b97`  
**Backend:** Supabase HML `gklhhhyosgasnyoxlrui`  
**PROD:** intocado

## Resultado

**TESTE C: PASS.**

A certificação combina a auditoria read-only do SHA funcional com verificação independente de TypeScript e Build no GitHub Actions. O SHA final da `main` possui a mesma árvore de arquivos do SHA auditado; os commits posteriores serviram apenas para neutralizar regeneração automática de `types.ts` pelo Lovable.

## Escopo validado

- rota `/contratos/:id/competencias`;
- gate literal UUID válido → sessão → organização → contrato → competências;
- UUID inválido encerra antes de `getUser`, preferência e Data API;
- leitura de `public.competencias` apenas após contrato autorizado;
- paginação server-side de 25 itens com `count: exact`;
- filtros server-side por competência e situação;
- ordenação determinística `competencia_referencia desc, id desc`;
- status exibido literalmente como retornado pelo backend, sem renomeação;
- `percentual_conformidade` apenas exibido, sem recálculo ou uso como portão;
- estados loading, empty, error e success;
- `Nova competência` e `Abrir competência` presentes como affordances staged/`Em breve`, sem antecipar V1-13/V1-14;
- navegação `Competências` habilitada nas cinco telas irmãs previstas;
- BRAND-01, dark mode, acessibilidade e responsividade preservados;
- backend, RLS, RPCs, Edge Functions, Auth, Storage e PROD sem alteração.

## TDD e regressão

### Correção do gate UUID

A auditoria externa detectou que o primeiro BUILD calculava a validade do UUID, porém chamava `getUser()` antes de encerrar o fluxo inválido.

Foi aplicado TDD mínimo:

- **RED:** teste exigindo `getUser` zero para UUID inválido;
- **GREEN:** retorno do fluxo antes da autenticação, sem hook condicional;
- fluxo válido preservado em sessão → organização → contrato → competências.

### Resultados

- V1-12 + V1-11 + V1-10: **87/87 PASS**;
- V1-12 isolado: **19/19 PASS**;
- ADM-01 isolado após correção determinística do harness: **58/58 PASS**;
- suíte completa determinística, `--maxWorkers=1`: **520/520 PASS**, 22 arquivos;
- ESLint dos arquivos V1-12: **0 erros / 0 warnings**;
- cinco componentes irmãos: **0 erros / 0 warnings**, sem aumento contra baseline.

## Manutenção do harness

Durante o Teste C, um teste preexistente de ADM-01 apresentou falha probabilística porque verificava `JSON.stringify(ultimoSalvar()).not.toContain("c9")`, incluindo uma chave de idempotência gerada por `crypto.randomUUID()`.

A correção foi exclusivamente no teste: passou a validar `p_ids_contratos_ativar` e `p_ids_contratos_revogar`, que são os campos efetivamente relacionados ao contrato `c9`. Código de produção não foi alterado.

A suíte paralela também apresentou duas esperas intermitentes em testes assíncronos preexistentes, ambas presas em estado de loading. Os mesmos testes passaram integralmente na execução serial. O V1-12 passou 19/19 em ambas as modalidades. Para certificação, a suíte integral serial foi usada como execução determinística do ambiente.

## TypeScript e Build independentes

Como o ambiente read-only do Lovable bloqueou a execução manual de `tsc` e `build`, foi criada branch temporária de verificação, sem alteração da `main`, contendo somente workflow de CI.

GitHub Actions:

- run: `41604819480`;
- TypeScript `bunx tsc --noEmit`: **success**;
- Build `bun run build`: **success**;
- workflow: **completed / success**.

A branch de verificação partiu da mesma árvore funcional auditada; o único arquivo adicional era o workflow de CI.

## Segurança

Security Scan nativo do Lovable:

- Critical: **0**;
- High: **0**;
- Medium: **0**;
- Low: **0**;
- Info: **1 preexistente**, referente à checagem de senhas vazadas do Supabase Auth;
- achado novo atribuível ao V1-12: **nenhum**.

Varredura estática confirmou ausência, nos arquivos V1-12, de `service_role`, segredos, `getPublicUrl`, escrita direta, RPC de negócio, `dangerouslySetInnerHTML` e `as any`.

## Responsividade e acessibilidade

Validação visual em oito combinações:

- 1440 px claro/escuro;
- 1280 px claro/escuro;
- 768 px claro/escuro;
- 390 px claro/escuro.

Resultado: sem overflow global; tabela móvel com rolagem horizontal contida; sem ocultação de informação crítica; H1, labels e nomes acessíveis preservados; status não depende exclusivamente de cor; console sem erro atribuível à V1-12.

## Zero-Drift

No SHA final `b22dfd93c61f8be3970b5c01c8e0af2f0e40241e`:

- `src/integrations/supabase/types.ts` blob SHA: `8ea7750b75fd9d76b29c36ce7613392e3ab65e19`, idêntico ao baseline `e10f7973260df0c455bb66baa091e5c9b3124efe`;
- `.lovable/north-star/north-star.md`: ausente;
- `package.json` / lock: intocados;
- `src/styles.css`: intocado;
- `src/components/ui/**`: intocado;
- `public/brand/**`: intocado;
- `src/integrations/supabase/client.ts`: intocado;
- `supabase/**`: intocado;
- V1-13 e V1-14: não implementados.

## Conclusão

**V1-12 / Prompt 33: APROVADO — TESTE C PASS — ZERO-DRIFT CONFIRMADO.**
