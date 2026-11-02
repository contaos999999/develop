# PROMPT 27 / V1-06 — Contrato: visão geral (`/contratos/:id`)

Base: `113fb94660281d2f486d0779fc9981e3c3eaa216`. Backend certificado, consumido sem alteração. PROD intocado.

## 1. Arquivos exatos
- criar `src/routes/contratos_.$id.tsx` — rota não aninhada (mesma convenção de `contratos_.novo.tsx`), `createFileRoute("/contratos_/$id")`, `ssr:false`, head: title `Contrato — ContaOS`, description/og:*, og:type, twitter:card, robots `noindex`.
- criar `src/components/contratos/VisaoGeralContrato.tsx` — página, `StatusSelo`, `ResumoContrato` e `NavegacaoContrato` locais neste arquivo (nenhum componente auxiliar em outro arquivo).
- criar `src/lib/contratos/contratoDetalheDados.ts` — UUID, SELECT, classificador, classificação de erros, formatadores.
- criar `src/test/contratoDetalhe.test.tsx`.
- `src/integrations/supabase/types.ts` — somente adicionar em `Functions`: `classificar_acesso_contrato_v106: { Args: { p_id_contrato: string }; Returns: string }` (confirmado ausente hoje; FK `contratos_contratante_org_fk` confirmada presente).
- `src/routeTree.gen.ts` — regeneração automática; plano arquivado.
- Não tocar: ListaContratos, NovoContrato, contratosDados, novoContratoDados, SYS, ADM, dashboard, contratantes, shared UI, client.ts, package.json, .env, backend. Sem link novo na lista (fica para escopo futuro aprovado).

## 2. Query exata
```text
supabase.from("contratos")
  .select("id,id_organizacao,id_contratante,numero,objeto,situacao,criticidade,inicio,fim,
           tipo_contrato,unidade_vinculada,fonte_recurso,valor_global,valor_mensal_referencia,
           periodicidade,prazo_prestacao_dias,dia_limite_apresentacao,
           contratante:contratantes!contratos_contratante_org_fk(razao_social,nome_fantasia,documento)")
  .eq("id", id).abortSignal(signal).maybeSingle()
```
- Join embutido SEM `!inner` (left join): contrato autorizado nunca vira zero linhas por contratante invisível; contratante ausente/invisível = "—". Uma requisição só (menos carga que leitura posterior). `versao_registro` omitido (sem uso no resumo, sem mutação).
- Sem `eq id_organizacao`: autorização é da RLS `contratos_select`; preferência é só contexto.
- Não seleciona `conta_bancaria_vinculada`, `configuracao_*` nem outras colunas.

## 3. Sequência
```text
getUser → (ausente /login | erro: msg+retry, sem signOut)
preferência org → (ausente /selecionar-organizacao)
UUID inválido → "não encontrado", zero API
SELECT por id:
  linha            → sucesso (zero classificador)
  erro 401/403/42501/PGRST301 → negado, zero classificador
  erro 500/rede    → erro técnico + retry, zero classificador
  zero linhas      → rpc("classificar_acesso_contrato_v106",{p_id_contrato:id})
       "negado"         → 403 Acesso negado
       "nao_encontrado" → 404 Não encontrado (inclui cross-tenant mascarado)
       "permitido"      → erro de consistência genérico (sem reconsulta)
       outro/erro/rede  → erro técnico sanitizado (nunca 404)
```
- Query key `["contratos","detalhe",uid,idOrganizacao,id]`, sem placeholderData; signal do Query; componente com `key={uid+org+id}` para A→B sem remount de rota não exibir dados antigos (resposta tardia descartada por key).

## 4. Resumo (somente leitura)
H1 `Contrato {numero}` (fallback `Contrato`). Cabeçalho com Situação e Criticidade em selo textual (texto do backend, sem cor como único sinal, desconhecido sem significado crítico). Seções `h2`: Identificação (objeto, tipo, unidade, fonte de recurso), Contratante (razão social, nome fantasia, documento), Vigência e prazos (início–fim DD/MM/AAAA por regex sem fuso, periodicidade, prazo de prestação em dias, dia-limite de apresentação), Valores (global e mensal de referência BRL). Nulos "—". Não há catálogo de status no frontend atual: exibe o texto oficial do domínio (padrão V1-04). Sem cards de indicadores ou contagens.

## 5. Navegação
`nav aria-label="Seções do contrato"`: Visão geral (atual, `aria-current="page"`) e Base normativa, Orçamento, Regras, Documentos, Competências como itens não-link `aria-disabled` com texto "Em breve" visível — sem rotas placeholder, links quebrados ou prefetch. Ações: `Voltar para contratos` (/contratos) e `Selecionar organização` (rota existente). Sem destino vindo da URL (sem open redirect).

## 6. Estados
carregando (status aria-live), sessão-erro/retry, negado 403, não encontrado 404, erro técnico/retry, consistência, sucesso. Mensagens PT-BR sem code/detail/hint/stack. Foco visível, alvos ≥44px, um H1.

## 7. Rastreabilidade
- PROMPT 27 / V1-06: contemplado.
- 001, 002, 004, 005 (V1-CON-*): parcial — apenas resumo, vigência, navegação; upload/extração IA/fonte completa dependem de V1-07/08/10, não declarados concluídos.
- NFR-009/093: preservado (1 SELECT limitado, sem cargas secundárias). NFR-005/089: preservado (nada pesado no request, sem jobs inventados).
- NFR-007/091 e NFR-008/092: N/A (sem mutações).
- Demais atômicos: N/A sem associação artificial.

## 8. TDD
RED: criar só o teste, rodar focado (falha por módulo ausente). GREEN mínimo. Casos: colunas/join exatos, eq id, maybeSingle, abort; leitor e Master lêem (sem gate de perfil); sucesso = zero RPC; zero linhas × negado/nao_encontrado/permitido/inesperado/erro RPC/rede; SELECT 401/403/42501/PGRST301/500/rede = zero RPC; sem sessão, erro getUser sem signOut, sem org; UUID inválido zero API; sanitização; retry; A→B id/org com resposta tardia sem stale; datas/BRL/nulos; navegação futura sem requisições extras; source scan (zero `.insert/.update/.delete/.upsert`, `functions.invoke`, `service_role`, `sb_secret`, `localStorage`, `as any`, `as never`, `as unknown as`; único `.rpc` = classificador).
Depois: focado, suíte completa, `npx tsgo --noEmit`, build, browser CONTROLADO 1440/1280/768/390. Sem Teste C/Security Scan no BUILD.

## 9. Teste C proposto (18 gates, turno separado, read-only)
1 HEAD/status; 2 Zero-Drift; 3 assinatura types.ts exata sem casts; 4 rota/head/H1; 5 sessão/org; 6 SELECT exato sem filtro org; 7 sucesso sem classificador; 8 zero linhas → 403/404; 9 permitido/inesperado/erro → erro, nunca 404; 10 SELECT falho zero RPC; 11 UUID inválido zero API; 12 stale A→B; 13 formatação data/BRL/nulos; 14 navegação futura acessível sem carga; 15 responsividade 4 larguras; 16 acessibilidade; 17 console/network/source scan; 18 regressão fresca + Security Scan + HEAD/git final.

## 10. Lacunas e parada
- Prova RLS real é backend (já certificada); browser é CONTROLADO.
- Se a edição de `types.ts` for rejeitada pela ferramenta (arquivo gerado), PARAR e reportar, sem cast.
- Qualquer necessidade fora dos arquivos listados: PARAR e explicar.

## Registro externo da revisão e autorização

- Plano produzido no Lovable: commit frontend `33b8942c34c8a112028a0de394d0c85210d175eb`.
- Revisado contra PROMPT27, FE V1-06, backend V106 e tarefa ativa do pacote 4.1; aprovado expressamente pelo usuário nesta sessão.
- Frontend exclusivamente pelo Lovable; nenhum código de produto criado pelo controlador externo.
- Manutenção documental autorizada: `1eb92b19c05207b7b52aa2c5b69c995955351e65`; complemento do caminho autorizado: `c4f5b1c20d3047377346131139d338437e1db79f`.
- Context Gate oficial: PASS, fingerprint `5a6683274ed17a7ece4c1fc61626a2f0d0b065376a10b46845adcf2e74e57fcd`.
- Zero-Drift CI: run `41522184949`, success. A falha anterior por ausência do caminho AI_CONTEXT_MANIFEST.md no escopo foi registrada e corrigida sem alterar guards.
- BUILD retomado via gate original, sem reenviar prompt. Teste C será separado, read-only e exigirá 18/18; qualquer FAIL ou INCOMPLETO interrompe sem auto-fix.
- Rastreabilidade e prompt exato: https://github.com/contaos9999/develop/issues/23.
- PROD e backend permanecem intocados.
