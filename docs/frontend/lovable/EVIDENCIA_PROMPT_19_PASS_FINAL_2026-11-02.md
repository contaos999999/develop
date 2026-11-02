# PROMPT 19 / SYS-04 — PASS FINAL

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Lovable: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Rota: `/selecionar-organizacao`

## Governança

- Prompt regular: PROMPT 19 / SYS-04.
- Caderno de prompts atômicos 001–096 revisado: não existe prompt atômico específico aplicável ao SYS-04. Nenhuma associação artificial foi criada.
- Backend autorizado: `vinculos_usuarios + RLS`.
- Seleção local é preferência de navegação não autoritativa; RLS permanece autoridade.

## Build

Arquivos funcionais:
- `frontend/src/routes/selecionar-organizacao.tsx`
- `frontend/src/components/organizacao/OrganizationSelector.tsx`
- `frontend/src/lib/organizacao/preferenciaOrganizacao.ts`
- `frontend/src/test/selecionarOrganizacao.test.tsx`
- `frontend/src/routeTree.gen.ts`

Lovable BUILD inicial: `a410fbb1489169c889506c388cffcd87cdf63b5f`
Microcorreção de auditoria: `5ecbfdd2734a7776cfe0c9277d187549860582a3`
Correção FAIL 01: `cf140b194ab020698e29ed45c67b19d219986876`

## FAIL 01 e correção

O primeiro TESTE oficial detectou que o SDK real devolve `AuthSessionMissingError` (status 400) quando não há sessão. A implementação confundia esse caso com erro técnico e não redirecionava ao login.

Correção TDD:
- teste RED reproduziu exatamente `AuthSessionMissingError`;
- produção passou a tratar `AuthSessionMissingError`/`session_not_found` como ausência de sessão;
- demais erros de Auth continuam exibindo mensagem genérica + retry.

Evidência histórica: `EVIDENCIA_PROMPT_19_FAIL_01_2026-11-02.md`.

## RLS real no HML

Teste controlado com role `authenticated` e sessão ativa do usuário de teste, sem migration e sem mutação persistente:

- `vinculos_visiveis = 1`
- `organizacao_vinculada_visivel = 1`
- `organizacao_sem_vinculo_visivel = 0`

Conclusão: a policy de `organizacoes` impede leitura de organização ativa sem vínculo; a preferência local não amplia autorização.

## TESTE oficial C — resultado final

1. Rota abre: PASS. Sem login, a rota real redireciona para `/login` com o `AuthSessionMissingError` real do Supabase.
2. Perfil autorizado funciona: PASS. RLS real retorna vínculo/organização autorizados; UI controlada seleciona, grava contexto local e navega.
3. Não autorizado bloqueado pelo backend/RLS: PASS. Organização sem vínculo retorna 0 linhas; 403/42501 é mostrado como acesso negado.
4. Loading/empty/error: PASS. Loading bloqueia ação; empty orienta administrador; erro técnico é genérico com retry; denied não vira empty.
5. Nenhuma request usa secret key: PASS. Somente publishable key.
6. Nenhuma ação crítica é update direto: PASS. SYS-04 não possui insert/update/delete/upsert/RPC; apenas leitura, Auth getUser/signOut e contexto local.
7. Desktop 1440x900 e 1280x720: PASS.
8. Tablet 768x1024: PASS.
9. Mobile 390x844: PASS, preservando nome, razão social, CNPJ, perfil e situação.
10. Teclado/foco/labels: PASS. Tab, ArrowDown/ArrowUp, Espaço, Enter e foco visível validados; radiogroup rotulado.
11. Console sem erro/log sensível: PASS.
12. Security scan sem novo Critical: PASS. Apenas o achado informativo preexistente de Leaked Password Protection no plano Free.

## Verificações finais

- SYS-04: 19/19 testes.
- Suíte completa: 55/55 testes em 6 arquivos.
- Typecheck: PASS.
- Build: PASS.
- Git status antes/depois do TESTE: idêntico.
- Nenhuma alteração em backend, RLS, Auth config, cliente Supabase, `__root.tsx`, `router.tsx`, `LoginForm` ou `package.json`.

### Observação sobre evidência visual

Os quatro breakpoints e os estados autenticados foram exercitados por Playwright com interceptação controlada das respostas do Auth/Data API. Isso prova UI, responsividade e interação, mas não substitui autorização. A autorização foi comprovada separadamente pela RLS real no HML, conforme seção acima.

## Gate

**PROMPT 19 / SYS-04: PASS 12/12.**

Dependência subsequente: a navegação `Continuar` aponta para `/`, pertencente ao SYS-05 / PROMPT 20.
