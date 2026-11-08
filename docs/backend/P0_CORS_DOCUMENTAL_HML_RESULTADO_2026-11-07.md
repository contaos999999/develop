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


## Complemento CSP: evidência e BUILD em validação

O public-probe f945953, run42440477002/job128608523471, falhou em WORKER_DENY_DATA: START1/HTTP estrangeiro1, waiting1/Runtime.resume próprio0. Artefato13600703885 SHA256 be23f1399bcd6515b909431c1faa1861c5225f8dde87d0a00510729433dc790a. As verificações HTTP/blob anteriores ao fechamento não certificam ausência de efeitos tardios.

GATE separado #141 HEAD17954ba8996e606a4e6ccab9d53286a43a1a3d61 integrado7ecdf3bda151fb9956beab8cca390f5074548cf2: guard42441024842 SUCCESS, restore42441240654 reconstrução128610718308 e backup128610718471 SUCCESS; revisão normativa sem Critical/Important. Reancoragem normal #139 cd9cf5b9db2b4b6a1b659f32c75803a9df1f4423 preserva ambos os pais.

RED CSP: 51PASS/1FAIL no protocolo por nativeDocumentWorkerPolicy ausente; commit d91801f8f51b573b195bea1dbf95d5ee48d96205. GREEN local: protocolo52/52 e suíte completa node --test258/258. A única alteração de headers autorizada é CSP adicional worker-src 'none' em Document próprio após hash, conservando array original/multiplicidade, status, phrase e corpo; nenhum routing Playwright, resposta sintética ou alteração de CORS. Audits worker-src enforced interrompe a aplicação com FAIL. Os contadores finais são reavaliados após context.close, drenagem TCP e observação explícita100ms, inclusive CORS permitido/negado. Não fechar sockets do servidor para fabricar zero.

Estado: EM_VALIDACAO_CI_REAL. Nenhum PASS operacional CSP/CORS, credencial, deploy ou certificação integral decorre dos testes locais. Browser Workers, janela nativa e critérios integrais documentais/CRUD/V1 continuam pendentes; worker backend, cinco recibos e cleanup preservados.


## Barreira nativa de destinos: GATE142 e BUILD em validação

O diagnóstico2447807580249d57b0e8215c4a078e9b2ae4a0cf/public42441727347/job128612183414 confirmou CSP raw continued1/observed1 e, ainda assim, Worker HTTP bootstrap1/START1/foreignHTTP1 após close/drain. Artefato13601469706 SHA25627445c61bd0c0b3dae9b401fd831beec77886f9d71af6a3967eaeda86e090721. Guard42441727381 e restore42441727357 (reconstrução128612183310, backup128612183535) SUCCESS não anulam public-probe FAIL: NO-GO.

GATE separado142 HEAD6d11f8c43c21bc2371faaa5854c15110d294a5ff integrado15dbd2e8644e559607302c7f8279b7e1c77f810a, guard42442110865 e restore42442221070 (reconstrução128613667404, backup128613667619) SUCCESS no mesmo HEAD, revisão normativa sem Critical/Important. #139 reancorado6cd5caeeca4b743843d547396a4ec8576229d688 preservando pais244780+15dbd2e, sem force.

RED proxy20d156717f8f05384b0c4444e19ea643e0f009d0: protocolo52PASS/2FAIL, helpers de configuração/TCP ausentes. Revisão encontrou Important de Worker local tardio permitir PASS; RED adicional53PASS/1FAIL por finalizador ausente, corrigido com latch persistente e checagem depois de browser.close/deny.close. GREEN local54/54protocolo, node --test260/260, dez guards/sintaxe/diff-check PASS. A unidade CSP obsoleta foi retirada conforme §13; os257 testes anteriores permanecem, mais2 testes proxy e1 latch. Revisão técnica independente final sem Critical/Important, limitada à análise estática e testes Node.

A implementação configura proxy nativo por contexto antes de criar página: bypass exato das origens aprovadas e <-loopback> explícito. O endpoint loopback TCP fecha sem ler/responder/encaminhar; nenhum fallback DIRECT. A alteração de header CSP foi retirada. Fixtures isoladas sem CDP guard avaliam bypass com HTML/status reais, destinos não aprovados HTTP/HTTPS/WS/WSS/IPv4/IPv6/aliases/porta e proxy indisponível. Workers HTTP/blob/data próprios devem realmente executar START1 e produzir tentativas DENY, sem conexões no destino estrangeiro depois de close/drain. Isso não certifica execução Worker de produto. Worker inesperado na aplicação marca FAIL persistente, inclusive tardio.

Estado EM_VALIDACAO_CI_REAL: eficácia da barreira e CORS nativo positivo/negativo ainda dependem do Chromium congelado. Preservados hashes/SDK antes de credenciais, redirects, popup DENY, Auth/RLS/RBAC, cinco recibos, worker backend e cleanup. Nenhum material HML, deploy, credencial ou certificação integral foi executado por esta correção.


### Provas de proxy e correção da expectativa DATA

HEAD9b9ad321/public42442958319/job128615896480 FAIL em NATIVE_PROXY_WORKER_DATA; artefato13602427213 SHA256978f3d6779b1677079738abdd1ac20eef795cbc6ab7f6f0211b74b5c9cb41705. Positivo DIRECT com HTML/status reais, nove negativos de origem e WS/WSS, Worker HTTP e BLOB passaram suas respectivas asserções e contadores finais; não constituem PASS do probe inteiro.

Diagnóstico341111b9538fd446512149db35586dc0036fa282/public42443226070/job128616673183, artefato13602866198 SHA256caaf89c72fb24e02e80c474fb2773317788727aa0e359f6dc4582b90f75a444c: DATA ownSTART1/bootstrap0/DENY2 e foreignTCP0/HTTP0/WS0 após close/drain, mas own-fetch statusnull/rejectedtrue. A expectativa200 era incorreta: WHATWG HTML §10.2.6.2 atribui origem opaca ao Worker data; sem ACAO a leitura CORS deve falhar. Não alterar o endpoint, CORS, no-cors ou política proxy.

Fix exige DATA self.origin==='null' classificado OPAQUE e statusnull/rejectedtrue, HTTP/BLOB origem própria efetivamente verificada e200, preservando START1/DENY>0/zero transporte estrangeiro. Novo validador TDD RED54PASS/1FAIL ausente→GREEN55/55protocolo e261/261suíte; revisão estática independente sem Critical/Important. A origem é medida dentro do Worker, não inferida do rótulo da fixture. CI operacional do novo HEAD continua pendente.


## Execução independente: BUILD do GATE143, 08/11/2026

Base comprovada846a256f485aa0f81c092e7b4f6e3bc6f0663dea. Guard42444723789 e Restore42444723828 SUCCESS; public42444723802/job128621135259 FAILURE. Artefato13601984914 baixado nesta execução e digest c34ad7e921a5a3e128527904acab8bd783ba5202f4fb40c4fa50db2cd219fe3d conferido. O HTML variável em entradas executáveis continua registrado como FAIL histórico, sem normalização.

Delta desta execução: parse5/grafo/AST/SDK aplicados ao mesmo Document pausado, UTF-8 sem perda e resolução pela URL real; hashes congelados antes de continuar a resposta original. Inspeção assíncrona que termina após latch failed/closed não pode continuar. O snapshot positivo guarda hashes do documento/grafo e scripts efetivamente liberados no relatório da proveniência ativa, sem fonte/URL. Seis fixtures novas do runner usam SDK real bundlado pelo rolldown congelado, duas variantes positivas e negativas de origem estrangeira, SDK ausente, configuração divergente e ScriptResponse alterada; contadores finais após close/drain.

TDD local:56PASS/2FAIL por inspector ausente; regressão adicional do path real falhou antes da correção. GREEN:61/61 protocolo e267/267 suíte Node completa; regressão VM confirma Fetch.failRequest sem continue após falha durante await. AST real local confirmou duas variantes e hashes diferentes com SDK2.118.0/rolldown1.2.1. O download local Chromium1.64.1 retornou ZIP inválido, portanto as fixtures reais permanecem PENDENTES do runner canônico, sem substituição de versão.

Estado: EM VALIDAÇÃO CI REAL, condições técnicas ainda não cumpridas. Nenhum resultado material, deploy ou certificação CRUD/V1 decorre dos testes locais. Revisão independente apontou e levou à correção de resolução de URL, corrida de falha e persistência positiva; parecer final condicionado ao CI. Publicação por CAS no HEAD base, preservando trabalho concorrente; nenhum commit anterior é atribuído a esta execução.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: impacto visual N/A justificado, harness backend; frontend/issue317/PROD intactos. Ferramentas locais/GitHub, sem turnos Lovable, timeout ampliado ou controle afrouxado.


### Primeiro CI do BUILD143 e latch síncrono

HEAD7bf439d6dc439ff29c69cd197648363276db0a6b: guard42448576205 SUCCESS; public42448576211/job128632687130 FAILURE em CHANGED_SCRIPT, antes das novas fixtures. Artefato13604377240 digest6b1ffaf4b2d7439f766f6b26dd33afdb7d872365224dd33fad9817d89085fcb2 baixado/verificado: zero execução do script alterado e zero foreignTCP/HTTP/WS. AssertionError sem mensagem bruta não certifica causa única; investigação local reproduziu uma corrida concreta do caminho: a fixture pode consultar failed antes que o tracker o registre depois do await Fetch.failRequest. Novo RED: resposta rejeitada observa latch=false antes do abort; GREEN registra fail(error) sincronicamente antes do await. Nenhum conteúdo rejeitado passa a ser permitido. Protocolo62/62, suíte268/268; repetir CI no novo HEAD. Nenhum merge/deploy/material liberado.


### Segundo CI e drenagem do leitor inerte da fixture

HEAD49275f778cf2a5551e41be8a3f40dd55bf14f353/public42448737328 chegou a PUBLISHED_BACKEND_READONLY_FENCE após todas as fixtures antigas, inclusive ChangedJS zero execução e CORS real positivo/negativo. FAILURE antes da primeira evidência da nova fixture; artefato13604452311 digest809fbc88de08da0e2106dbd87b8ab8ebdf3122911de31f9b132148054f4da85f baixado e conferido. A instrumentação não identificava qual assertion do finally falhou. ReproduçãoHTTP local real demonstrou1TCP idle do Node após1100ms e0 quando o próprio servidor de fixture responde Connection:close. Delta mínimo: servidor loopback novo responde com semânticaHTTP de fechamento original; nenhum socket é destruído para produzir zero e nenhum header é reescrito pelo guard. As evidências finais passam a ser salvas antes das assertions, preservando eventual falha seguinte. Testes268/268 locais; eficácia canônica ainda PENDENTE.


### Primeiro public-probe operacional aprovado e fechamento do Teste C

HEAD2b2bb2cf172d654966ec76d7764b215a37326d00/public42448929569 SUCCESS, artefato13604249723 SHA256e3bd0eb6e147afe93991596bfc70d07df39460ecfdf193124b4320b5b8be62e4 baixado/conferido:12assertions PASS, seis variantes de Document,114módulos e49hashes de scripts efetivamente carregados; SDK2.118.0 fonte5ff2a352cefac11d3e93e29d3c8396e7bea471323cb3cd42fe612adb604aa228. Todos negativos com foreignTCP/HTTP/execução rejeitada0 após close/drain. Não é prova material nem paridade SHA publicada.

Teste C independente do harness completo(Node/Python/Edges/CORS/GATE1–14/manifesto) reexecutou268/268, confirmou5arquivos/3documentos/5versões, publicado primeiro, quatro locais, SQLreadiness restrita e quarentena preservando running. Encontrou Important de falha CDP tardia não revalidada no relatório final. Corrigido após RED helper ausente: finalizadores capturam sink original da proveniência e revalidam/persistem snapshot.failed após browser.close/deny.close; qualquer falha força FAIL e exitCode1, inclusive smoke separado. GREEN63/63protocolo269/269suíte. Novo HEAD exige CI inteiro novamente; SUCCESS anterior não o libera. Sem deploy, credenciais materiais ou certificação.


## Origem Vercel HML: BUILD separado, 08/11/2026

PR139 integrado em a58689e1cd0d414abd503e674832aa4a1e4b2c37 após guard42449196158, restore42449196348 e public42449196146 SUCCESS noHEAD2fcd7bae. Artefato13604378113 SHA256ef57f6f10fbc9754f9c44e8646cf906a1cf24379ef3188421c0f5a6a32b38366 conferido:12assertionsPASS, sem upload material. GATE144 reconciliado mantendo manifesto139 e integrado ea48a5350cfc1ca031cb69ed60cd7e11f3300138 após guard42449528794SUCCESS e revisão independente semCritical/Important.

TDD desta continuação: suíteCORS com origemVercel e oito variações maliciosas/preview retornou152PASS/74FAIL contra funções antigas, total226. O único delta de produto adiciona literalmente https://contaos-41-hml.vercel.app às listas de upload e download. Preservados JWTtrue,POST/OPTIONS,quatroheaders,RBAC/RLS,no-store,Vary,semcookies ouwildcard. Testes positivos/negativos ampliados sem remoção de assertions. GREEN e CI final requeridos antes do merge/deploy. Nenhum deploy ou upload material é alegado por este registro.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: impacto visual N/A; funções existentes reutilizadas; sem mudanças frontend, SDK, Auth, schema, Storageconfig, workflows ou PROD.


## Checkpoint de retomada material documental, 08/11/2026

Estado: PENDENTE_PROVAS_MATERIAIS. PR139 foi integrado por esta execução em a58689e1cd0d414abd503e674832aa4a1e4b2c37, após guard42449196158, restore42449196348/reconstrução128634559207/backup128634559038 e public42449196146 SUCCESS no mesmo2fcd7bae; revisão independente completa269/269, sem Critical/Important. Artefatos public13604378113/ef57f6f10fbc9754f9c44e8646cf906a1cf24379ef3188421c0f5a6a32b38366, restore13605110912/fa89c5053a91d1fa194a3ffde433105b9283b85e64d2c9f127107b9c89d403ca e backup13604688827/dbce8bb3d3eaa96a86e5074fab6814c56218ae0087eda76022df233e65992ea8 baixados/conferidos. SQLdocumentquarantine local PASS. Merge sintético9e367720 e HEAD2fcd7bae tiveram árvore idêntica033be046cddcf7193b741f7ac2b25e4a717db1df.

O deploy executado por esta sessão foi uploadv7/downloadv5,JWTtrue, fontes exatasdea58689e;12HTTPcases reais PASS nas duas origens antigas, negativos e semJWT. Posteriormente,outroexecutor integrou GATE144 ea48a535 e BUILD145 b8003019fe937c8dad436fae3a0334aee23f2453 (HEADa475479d,guard42449646955/restoremanual42449952690), acrescentando a terceira origem Vercel autorizada. Seus commits/deploys NÃO são atribuídos a esta execução. Fontes atuais uploadv8/downloadv6 consultadas oficialmente e comparadas byteabyte ao b800301,ACTIVE/JWTtrue. Bundles940e854c213c399c0f5c08d99278f8bb6a8f4d3676acc189bb5e1a67fbd3d5a4 e d641c940614865bcbe6eb0b75c8e95a0531b69f62a6d64ff0183fd18c09be025. Complementos concorrentes preservados.

Este checkpoint habilita somente fixtures próprias no runner existente:1TXT publicado PRIMEIRO; depois TXT/PDFv1/v2 locais pinados164b10b4, total5arquivos/3documentos/5versões, recibos disjuntos e união exata. Publicado frontend_head=null/sourceparityNAO_VERIFICADA. Worker normal, negativos de leitor/tenant/revogação, readiness SQLSELECT fechada, banimento/revogação antes de quarentena e preservação de running/completo continuam obrigatórios.300s/arquivo e900s totais desde antes do smoke, sem ampliação. DDL/RLS/Authconfig/Storageconfig/PROD e alterações de produto/frontend não autorizados por este checkpoint.

Regressão real adicional confirma que prazo global vencido durante a prova readonly de backend impede iniciar credenciais publicadas e uploads locais. Não altera implementação/workflow. Esse caminho de teste aciona naturalmente public-probe/Restore no PR e Restore push/main; documentos isolados não acionariam o runner e Restoremanual não atende o filtro eventpush. CI e revisão deste novoHEAD são exigidos antes de integrar; private-browser repete seu preflight semcredenciais no mesmoHEAD atual de main antes de Python/Authfixtures. NenhumPASS de outroHEAD é transferido para esse lote.

Próxima etapa: comprovar smoke+4locais,5recibos,worker,SQL e cleanup pelo artefato do runner. Falha permaneceFAIL e é investigada sem relaxar segurança. CRUDglobal/domínio documental integral/V1 NÃO CERTIFICADOS; V2 não iniciada.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: impacto visual N/A justificado; sem frontend/issue317/PROD, sem novoexecutorworkflow ou turnoLovable. Somente manifesto,resultado e regressão de prazo nos caminhos existentes.

Confirmação antes de publicar checkpoint: repetidos12/12HTTPcases reais nas fontes atuaisv8/v6, duasorigens antigas204,negativos403 e semJWT401. Novorecorte local320/320Node, semskip;regressão de prazo passa. Escopo deste checkpoint:3caminhos próprios; comparação local usa diff contra baseb800301, sem atribuir deltaCORS145 a estaexecução.

Bloqueio vivo antes de publicar a ativação: teste autenticado do outroexecutor após145 revelou P0001 confirmar_upload_arquivo por regexp deextensão, GATE146 aberto. Estaexecução realizou apenas SELECT HML independente:7casos reproduzem nomeinteiro com padrão atual e extensãofinal correta comexpressão reparada;evil.txt.exe permaneceexe,nomesemextensão permaneceinválido,pontofinalvazio. Nenhuma migration/DDL/RPC/material executada por esteturno. A ativação permanecerá semmerge até reparo proprietário integrado/aplicado e comprovado; não duplicar seuscommits.

Reancoragem de continuidade ao HEADff4e0d83d2d8010d08753b8f0460044b11e813b3 preserva GATE146/BUILD147, migration nova e metadados do proprietário. O deploySQL feito PELO OUTROEXECUTOR via workflowcanônico42450754658 terminouSUCCESS. Leitura independenteHML destaexecução confirmou histórico20261108053000 com1statement, prosrcprivadoMD5a0c3d54699ca5ac54e0caf718b7426d1 igualesperado, wrapperpublic2671383869a4df20e454b7b6a7556261 inalterado, ACL/searchpath/SECDEF/invoker e anonEXECfalse preservados. BloqueioSQL solucionado em fonte/histórico; prova material permanecePENDENTE e seráo reteste próprio. Nenhumaautoria/aplicação147 atribuída a esteturno.

### Retomada reancorada após correção concorrente150

O primeiro checkpoint148/2757d64 teve guard42450940596, public42450940617 e Restore42450940569 SUCCESS; artefatos public13605208005/SHA25612c1c1fa0d12bcb4299e2a5cd267a0af28eb81f95e6e695ad7597fb51cc9f4bd, backup13605771908/4499297fa7845f51732281e5426d401e71e50fe8375da3b23c8055975c451373 e restore13605756884/601b0cc7deadd92aa5848227dc657647a122c4c66b60ec7b7ae74cdba4892ebd conferidos. Não houve merge nem fixtures: novo bloqueio de criação documental exigiu preservar o trabalho de outro executor nosGATE149/151 e BUILD150.148 voltouDRAFT.

BUILD150 de outro executor, HEAD46a7b821a4e06cf5b5162513c82e3afc5d9b93a2, integrado cb074f501b8b0d527bda3c0840248e4e8c589d56 após guard42451502833/Restore42451502838 SUCCESS. Aplicação canônica42451722019 SUCCESS, migration20261108054500/hash5798d972d1592b48c25139e7e489e900831af8fe3ce74c9057b1da7fadbb0f5d. Inspeção independente HML confirmou1statement, wrapper públicoDEFINER/bodyMD576a15744ab7c8e4e2fb11f3e6477e661/authEXECtrue/anonfalse; privadoDEFINER/body4bd3d0edebe2522b9ced4e1d6c482e9d/auth+anonEXECfalse, ownerpostgres/search_pathvazio preservados. Não apliquei nem atribuo esta migração à execuçãoTrilhaB.12casos independentes da função real do comparadorPASS, reconhecendo exclusivamente o delta aprovado.

Reancoragem preserva integralmente campos concorrentes GATE149/151/BUILD150. Suíte local323/323PASS, incluindo prazo global vencido antes das credenciais. Checks anteriores148 não autorizam este novoHEAD; revisão eCI próprios novamente obrigatórios. Material continuaPENDENTE: nenhum dos5recibos ou5/3/5 é presumido; semCRUDglobal/V1/V2.
