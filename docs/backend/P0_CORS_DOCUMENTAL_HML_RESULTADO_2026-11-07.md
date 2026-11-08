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

| `a99f20a8259c27eae81348a4b5d2c7184739c111` | `42437783015` | DENY nativo de janelas: zero HTTP/upgrade/nova página; FAIL posterior no WebSocket principal | `13600795348`, `8103427925c5705818c01991918ecb40c6812ec0b9a40a8f413fde5633dc7422` |
| `db58a1a2df0a7bf86578617cec818eecc9261750` | `42437970481` | FAIL WS: erro no browser mas um upgrade chegou ao servidor; bloqueador anterior insuficiente | `13599659034`, `7727d7484052d5db064c8d4db22cf369a505ed0ecf9a022c07f3ae171d518e47` |
| `f57e7fb22e2f557af99021ae3fe58bd25c75ab43` | `42438240615` | Regras nativas WS/WSS confirmam zero upgrades; FAIL posterior em Worker ainda não observado | `13600826124`, `1919103b28b5a91aede6a2f4a13993d6952f751ce6bb9fca6bec3cf828026fbb` |
| `1bc21812695ec0cedb732e13eb7d7af1b9c370fc` | `42438416123` | Worker: zero bootstrap/HTTP/upgrade, sem violação observada; não é prova de transmissão | `13600014957`, `e13d51dfbb7b3ae3998be2fac29d17de45d2b865f798162ca02f9661e197e9b9` |
| `668e98850a321d3f5a9e201e0ad32e86749cab9c` | `42438555300` | Worker criado, nenhum target pronto/bootstrap; hipótese de espera circular investigada | `13600039912`, `bb242449e52be7a00ff9e5c79e360864897f107ab95ff2c6afffb72a4c1c3e38` |
| `638aa415cd3fbc7e79c7b57f355ace152b4396bb` | `42438805341` | Bootstrap próprio liberado, Worker target observado; FAIL fechado em Fetch.enable, zero HTTP estrangeiro/upgrade | `13600746656`, `b3ca972700a48aa45d9fcdb2451a0345b1d306052da790d791e9b13d47b41771` |
| `4b2af243e23a3e4f2f0224fe0534f3fad08bcebc` | `42439124871` | Fetch no Worker retorna -32601/UNSUPPORTED; nenhuma execução permitida será inferida | `13600708288`, `7dd30bccd3e60d5c479599b055b9ae616cb2f52e92b582fa3a91c10ec4bc2f9e` |

| `6adec5ac48234595be8f8e879d47a619f1872e3d` | `42439328541` | Worker e SharedWorker inesperados: waiting1/resume0, zero START/HTTP estrangeiro/WS; FAIL posterior em CORS | `13601500221`, `959d79d8ceb8eb6b8b5eb1c11932392767ddd78987ba6d469eea2323c727297f` |
| `7e3276f51ca1c938a1ff6ec7441c7c39a76df963` | `42439558166` | FAIL CORS: OPTIONS0/POST1 apesar de rejeição de leitura; preflight fabricado pelo routing Playwright identificado e removido | `13601186497`, `d1839153b218806202c94f09902a62dfa16d3152e0bdf62d39246e1c806dbeaa` |

| `3fffe307c651d650c85eac9ba28af2c9f1618f8b` | `42439918141` | Sem routing PW, SharedWorker executou START1/HTTP estrangeiro1 apesar de waiting1/resumes0; FAIL antes de avaliar o CORS novo | `13600839220`, `776980328aac898dd62233137679d3ffc768cfa1d364da82d22562bf76b8d544` |

Os ZIPs acima foram baixados e seus SHA256 conferidos. SHA de merge sintético nos relatórios não é confundido com o HEAD do PR. SUCCESS de HEAD anterior não libera HEAD posterior. No HEAD `3e6e56fe...`, Zero-Drift `42434364929` e Restore `42434364927` também passaram; a prova material privada permaneceu SKIPPED.

## Fence em validação

A arquitetura atual mantém um único agente CDP nativo Request/Response, restrito ao contexto próprio e instalado antes da navegação, com bloqueio de 3xx antes de seguir e hashes reais antes de credenciais. Para novas janelas, o complemento #140 determina DENY nativo com `--block-new-web-contents`, confirmado por fixtures reais, e fallback CDP que aborta requisições de targets de página diferentes da principal; contexto de target ausente mantém FAIL. `Page.windowOpen` inesperado observável mantém FAIL. Somente tentativa esperada após botão oficial, origem HML e path exato próprio pode ser cancelada sem FAIL, sempre sem transmissão. Não há retry de navegação, alteração de `window.open` ou API interna Playwright.

O GET físico usa `redirect:error` equivalente a zero redirects, `credentials:omit`, URL/path próprios validados antes do request e streaming limitado ao tamanho exato esperado antes de hash. A resposta da Edge recebida pela UI é uma prova CORS distinta. Janela/download renderizado permanece `NAO_CERTIFICADO`. Recibos exigem `download_proof_kind=UI_EDGE_AND_SIGNED_GET` e `popup_rendering=NAO_CERTIFICADO`; ausência ou alegação de popup PASS é rejeitada. `completed_scopes` contém somente `DOCUMENTOS_UPLOAD_VERSION_WORKER_UI_EDGE_AND_SIGNED_GET_PARTIAL`, sem certificar domínio integral.

Não há ativação de page.route/context.route/routeWebSocket, relay, fulfill, mock, troca de headers/cookies/Origin, leitura de body/header de autenticação ou handshake WebSocket fabricado. A fonte exata Playwright1.64.1 crNetworkManager.ts309–330 fabrica OPTIONS204 quando routing está ativo; por isso a API foi removida integralmente. O CDP nativo apenas continua request/response com requestId original e sem overrides; o teste canônico exige OPTIONS real tanto no caso CORS permitido quanto negado. O mapa de hashes é não enumerável e fontes/HTML/tokens/erros brutos não são persistidos. As regras Native Network.emulateNetworkConditionsByRule usam somente padrões absolutos ws/wss com offline por regra, sem offline global ou alteração de navigator. A prova CI f57 confirmou erro nativo e zero upgrades. O endpoint CDP loopback é vinculado ao target/context próprio antes de configurar a contenção.

As novas fixtures canônicas exigem zero HTTP/upgrade WebSocket e nenhuma nova página para window.open, target=_blank em link/formulário e about:blank com document.write/fetch/WebSocket. Preservam 307/308 na página principal, iframe estrangeiro, script alterado sem executar e CORS nativo. Worker de navegador inesperado encerra com FAIL antes de qualquer resume enviado pelo harness; as fixtures cobrem HTTP, blob e data com marcador START absoluto próprio, fetch estrangeiro e WS, exigindo zero efeitos. SharedWorker é desabilitado pela feature nativa documentada --disable-blink-features=SharedWorker; exige interface ausente/ReferenceError e zero bootstrap/START/HTTP/WS. A feature consta de shared_worker.idl e runtime_enabled_features.json5 (stable). Waiting/resumes somente do nosso cliente não foram tratados como prova suficiente após o race observado em3ff. Se algum vetor DedicatedWorker executar, manter FAIL e preparar GATE separado para contenção CSP explícita; não liberar credenciais nem adicionar hipóteses sem rito. Sua execução não recebe aprovação; o worker de filas real do backend continua obrigatório. A presença da flag não basta: CI real deve comprovar os contadores. Nenhuma dessas provas é declarada aprovada antes do runner final.

## Validação local e revisão

A suíte `node --test` executou 257 testes, todos PASS. O recorte `supabase/tests/*.test.mjs` não equivale à descoberta completa; os nove testes adicionais de histórico/RNF permanecem presentes. Fixtures reais do parser, análise inerte do grafo de 114 módulos, sintaxe, diff e dez guards passaram. A revisão independente encontrou e levou à correção da mutação entre parênteses e da lacuna probatória do popup; a revisão estática final não substitui Chromium real.

As duas Edges mantêm o delta CORS estreito e os controles existentes. Permanecem as origens exatas `http://127.0.0.1:4173` e `https://scope-and-approval-keeper.lovable.app`; projeto HML `gklhhhyosgasnyoxlrui`. Nenhuma alteração em dependências, workflows, frontend, Auth, RLS, migrations, Storage ou PROD foi introduzida nesta correção.

## Pendências e próximo passo

Validar a política DENY conforme GATE140, corrigir qualquer falha real sem afrouxar os controles, obter guard/restore/backup/public-probe no mesmo HEAD final, revisão independente do último delta e integração normal. Somente depois, seguir o deploy HML das duas fontes integradas com JWT true, conferência pós-deploy, checkpoint da fase material e provas reais de um TXT publicado mais quatro uploads locais, cinco recibos disjuntos, integridade, worker, negativos e cleanup. Nenhum desses resultados materiais é declarado executado por este BUILD.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Impacto visual: N/A backend. Reutilizados runner e protocolos existentes; sem turno Lovable, workflow novo, redução de testes ou ampliação de escopo.
