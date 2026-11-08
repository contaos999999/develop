# Resultado técnico da subtarefa CORS documental HML

Estado: EM VALIDAÇÃO. Este registro não certifica CRUD global, domínio documental, V1 ou PROD. Não houve deploy nesta etapa. O GATE original é `42a737acdcdb17f3b0684e8daf82f042696eb9ea` (PR #138); o complemento separado PR #140 foi aprovado e integrado em `765dac8aa1033f6c0ac6478738fac4ab768426e4`, HEAD documental `af5b62d4ce6ea8bb6d66e56ea3d3c3c730856971`, guard `42436855329` SUCCESS, restore manual `42436978545` com reconstrução `128597812865` e backup `128597812664` SUCCESS. Reancoragem normal do BUILD: `4a9e937290d713eda28049a194f06e67c2492172`, parents `2454c855975fa2e5df4a4d6d97226975989504f8` e `765dac8aa1033f6c0ac6478738fac4ab768426e4`, sem force push; o BUILD permanece no PR #139 enquanto a validação final está em andamento.

## Escopo e causa corrigida

O verificador estático do cliente publicado rejeitava três construções legítimas do bundle: `client.rpc.call(client, ...)`, alias de binding rebaixado pelo bundler para `var`, e `client.rpc.bind(client)`. A prova agora acompanha símbolos resolvidos, exige declaração única e uso de aliases, rejeita escape e mutações, incluindo alvos entre parênteses, e limita o receiver RPC à mesma instância. `bind` exige exatamente um argumento. A implementação do SDK continua comprovada por AST completo contra a referência congelada, sem heurística de ocorrência de URL.

A referência efetiva continua sendo SDK 2.118.0, rolldown 1.2.1 e instalação Bun congelada no runner. SHA256 do fonte SDK verificado: `5ff2a352cefac11d3e93e29d3c8396e7bea471323cb3cd42fe612adb604aa228`. Frontend pinado: `164b10b44eaf5b553efcc7ab4e053b86c4d3b269`. A publicação não recebeu SHA inferido: `source_parity=NAO_VERIFICADA`.

## Recibos canônicos e iterações

| HEAD do PR | Run público | Primeiro resultado relevante | Artefato e SHA256 |
|---|---|---|---|
| `f1ff450172f34d878c82b4e69c14d50c1f019637` | `42433520777` | FAIL em `PROVE_CONFIGURED_CLIENT`; o primeiro fix de `call` ainda não cobria o grafo integral | `13597584619`, `29a4e29ddb98849f4d4428366d84e42a6775bd43b70f1d01d0e4cc332744dd9b` |
| `3e6e56fe34de3b2697362d6b090b533aeed434f2` | `42434364925` | PASS_PUBLIC_PROBE, nove assertions, 114 módulos; não exercitava ainda o fence preventivo final | `13598921798`, `b88ff535748b75669b631e4c11dc239b94833ea7efaa0ed282fef72e4744f2ae` |
| `fb9be8877e94fa6d07607fc0bba2c67d729ae438` | `42434824243` | FAIL na primeira fixture `REDIRECT_307`; erro de instalação CDP ainda sem código fechado | `13598848053`, `9e786017515090e041e820a8ec67309807c5cbc968fb3f73254854db7d076212` |
| `918b33319974129ae062a3c15f151acd808a1978` | `42435012154` | FAIL `REDIRECT_307`, código `CDP_BROWSER_METADATA`; Headless Shell não forneceu o metadado solicitado | `13598803645`, `f427ac58097a2b2c7d63c6107cfcf92b4682025bcfd5c0479d5647b016bdc975` |
| `0e0cce601aa8d454c2643d1c651af87c9539d10c` | `42435147595` | Após concluir 307/308, FAIL em `POPUP_DIRECT`; somente CDP não comprovou o primeiro request do popup | `13599227389`, `8dd329c333b32a9c847ac0df4902aa996cf00aa909a3f4ca59652eeda239bf3d` |
| `48b2dc131f66a20d3d1121d7858d5932187f4d85` | `42435348414` | FAIL `REDIRECT_307`, TimeoutError na combinação inicial de dois pausadores de Request | `13599297720`, `b48fff13773a2b314ed29bfa73e6a15deeba74a92851a464744b65616b3f3aa9` |
| `6221dbdbef050e41ccbc409e4040d2a3b14fdc65` | `42435541618` | Após concluir 307/308 e popup negado, FAIL em `POPUP_ALLOWED`; erro assíncrono ainda sem causa preservada | `13599860352`, `984d82b466f34ae7a758ad822fb393ce06f2d0f5f54dd9374702933194ce843b` |

| `cb46fad5500af4adaba8b75f3bf1015634e17892` | `42435701991` | FAIL `POPUP_ALLOWED`, código `FENCE_ROUTE_IDENTITY`; sessão Playwright pré-commit substituída por inventário CDP | `13598804896`, `fc1fe8fec95145fb5bba3d437aa356fea441f55646ffee55cecb64eebe7b8164` |
| `eb2341a6c97b268f94a35d2b47ce44a65695eacb` | `42435838391` | FAIL `POPUP_REDIRECT`; a fixture positiva anterior ainda usava contadores globais | `13599253580`, `41c6f3c7fd4ac0921b2135e870d8619aba32d73f17bd2831814a8f88b472dffd` |
| `2454c855975fa2e5df4a4d6d97226975989504f8` | `42436054090` | FAIL `POPUP_ALLOWED`, `FENCE_POPUP_SOURCE_NOT_CHECKED`: HTML 1→1, JS 1→2, zero requests estrangeiros; nenhuma certificação de popup | `13599568037`, `c457238db46c9f4cde726c1dc1bf35265775e7dd880a760a23e2df47ec415257` |

| `f0ee587c72a760143591745ae1e176d064392663` | `42437607860` | RED contratual: testes novos rejeitam implementação anterior; public-probe ainda sem DENY repete HTMLpopup 1→1/JS1→2 e FAIL | `13600112663`, `d2242e448b79a502e341c629c077c68c80022aa44e1caefa65af7d21335a37f3` |

Os ZIPs acima foram baixados e seus SHA256 conferidos. SHA de merge sintético nos relatórios não é confundido com o HEAD do PR. SUCCESS de HEAD anterior não libera HEAD posterior. No HEAD `3e6e56fe...`, Zero-Drift `42434364929` e Restore `42434364927` também passaram; a prova material privada permaneceu SKIPPED.

## Fence em validação

A arquitetura atual mantém Request URL-only e CDP Response na página principal, com bloqueio de 3xx antes de seguir e hashes reais antes de credenciais. Para novas janelas, o complemento #140 determina DENY nativo com `--block-new-web-contents`, confirmado por fixtures reais, e fallback que aborta toda requisição de página diferente da principal ou identidade de frame ausente. `Page.windowOpen` inesperado observável mantém FAIL. Somente tentativa esperada após botão oficial, origem HML e path exato próprio pode ser cancelada sem FAIL, sempre sem transmissão. Não há retry de navegação, alteração de `window.open` ou API interna Playwright.

O GET físico usa `redirect:error` equivalente a zero redirects, `credentials:omit`, URL/path próprios validados antes do request e streaming limitado ao tamanho exato esperado antes de hash. A resposta da Edge recebida pela UI é uma prova CORS distinta. Janela/download renderizado permanece `NAO_CERTIFICADO`. Recibos exigem `download_proof_kind=UI_EDGE_AND_SIGNED_GET` e `popup_rendering=NAO_CERTIFICADO`; ausência ou alegação de popup PASS é rejeitada. `completed_scopes` contém somente `DOCUMENTOS_UPLOAD_VERSION_WORKER_UI_EDGE_AND_SIGNED_GET_PARTIAL`, sem certificar domínio integral.

Não há relay, fulfill, mock, troca de headers/cookies/Origin, leitura de body/header de autenticação ou handshake WebSocket fabricado. O mapa de hashes é não enumerável e fontes/HTML/tokens/erros brutos não são persistidos. O endpoint CDP loopback é vinculado ao target/context próprio antes de configurar a contenção.

As novas fixtures canônicas exigem zero HTTP/upgrade WebSocket e nenhuma nova página para window.open, target=_blank em link/formulário e about:blank com document.write/fetch/WebSocket. Preservam 307/308 na página principal, iframe/worker estrangeiros, script alterado sem executar e CORS nativo. A presença da flag não basta: CI real deve comprovar os contadores. Nenhuma dessas provas é declarada aprovada antes do runner final.

## Validação local e revisão

A suíte `node --test` executou 253 testes, todos PASS. O recorte `supabase/tests/*.test.mjs` não equivale à descoberta completa; os nove testes adicionais de histórico/RNF permanecem presentes. Fixtures reais do parser, análise inerte do grafo de 114 módulos, sintaxe, diff e dez guards passaram. A revisão independente encontrou e levou à correção da mutação entre parênteses e da lacuna probatória do popup; a revisão estática final não substitui Chromium real.

As duas Edges mantêm o delta CORS estreito e os controles existentes. Permanecem as origens exatas `http://127.0.0.1:4173` e `https://scope-and-approval-keeper.lovable.app`; projeto HML `gklhhhyosgasnyoxlrui`. Nenhuma alteração em dependências, workflows, frontend, Auth, RLS, migrations, Storage ou PROD foi introduzida nesta correção.

## Pendências e próximo passo

Validar a política DENY conforme GATE140, corrigir qualquer falha real sem afrouxar os controles, obter guard/restore/backup/public-probe no mesmo HEAD final, revisão independente do último delta e integração normal. Somente depois, seguir o deploy HML das duas fontes integradas com JWT true, conferência pós-deploy, checkpoint da fase material e provas reais de um TXT publicado mais quatro uploads locais, cinco recibos disjuntos, integridade, worker, negativos e cleanup. Nenhum desses resultados materiais é declarado executado por este BUILD.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Impacto visual: N/A backend. Reutilizados runner e protocolos existentes; sem turno Lovable, workflow novo, redução de testes ou ampliação de escopo.
