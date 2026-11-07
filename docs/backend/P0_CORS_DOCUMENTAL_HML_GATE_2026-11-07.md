# GATE técnico: CORS documental HML

Data: 07/11/2026. Subtarefa: `P0-CORS-DOCUMENTAL-HML-20261107`, vinculada ao master backend `P0-CRUD-GLOBAL-HML-20261107`.

Este PR altera somente o GATE e o manifesto, sem habilitar Edges, BUILD, deploy ou nova prova HML. Deve ser integrado após os seus próprios checks antes da implementação.

## 1. PLAN integrado e linha de base

Conforme evidências informadas pelo root, PLAN #137 foi integrado em `5743453e729362d4fa841aad16b357b9926c5688`, a partir de `93fee8ac`:

| Evidência | Resultado informado |
|---|---|
| Blob final do PLAN | `7b550a2a164bc0ebb03938838833fe7b42c95ec7`, conferido também na árvore local |
| Guard `42422472451`, job `128553651513` | SUCCESS |
| Restore `42422690948`, tentativa 2, reconstrução `128554990490` | SUCCESS |
| Mesmo restore, backup `128554989468` | SUCCESS |
| Tentativa 1 do restore | Falhou por bind da porta 54322; não constitui prova CORS e não substitui a tentativa 2 concluída |

Frontend aprovado para as quatro provas locais: HEAD `164b10b44eaf5b553efcc7ab4e053b86c4d3b269`, integrado por #309 em `b0e22f5ab7a479ebb8a3c9bd2d907d5052ec81c5`, com CI e LOCK registrados no PLAN. Isso não comprova o SHA da aplicação publicada.

A causa delimitada é OPTIONS 405 antes do POST em `storage-sign-upload`. Upload v6 e download v4 implantados não tratam preflight nem devolvem CORS; ambos têm `verify_jwt=true`. Preservam-se as evidências do run `42420832115` e do PLAN. Nenhuma prova de parser, worker ou CRUD documental foi aprovada por essa falha de transporte.

## 2. Escopo fechado de implementação futura

O BUILD poderá alterar somente estes dez caminhos, após a integração deste GATE e a declaração explícita no manifesto:

1. `docs/backend/P0_CORS_DOCUMENTAL_HML_PLAN_2026-11-07.md`
2. `docs/backend/P0_CORS_DOCUMENTAL_HML_GATE_2026-11-07.md`
3. `docs/backend/P0_CORS_DOCUMENTAL_HML_RESULTADO_2026-11-07.md`
4. `docs/tasks/active-task.json`
5. `supabase/functions/storage-sign-upload/index.ts`
6. `supabase/functions/storage-sign-download/index.ts`
7. `supabase/tests/storage_document_cors.test.mjs`
8. `supabase/tests/p0_crud_global_browser.mjs`
9. `supabase/tests/p0_crud_global_protocol.test.mjs`
10. `supabase/tests/p0_crud_global_hml.py`

Este GATE é documental: não autoriza editar Edges antes de integrado. No BUILD validado, a permissão de alterar Edges fica restrita às duas funções acima. Não inclui outras funções, dependências, SDK, frontend, workflows, migrations, schema, RPCs, grants, RLS, configuração Auth/Storage/cron ou PROD. O provisionamento e a quarentena de identidades próprias continuam limitados ao harness e à autorização de fixtures já registrada no master; configuração e política de autenticação do produto não mudam.

Manter helpers CORS locais autocontidos nas duas funções. O teste RBAC existente executa o handler em VM e remove imports; não alterar seu loader ou suas assertions só para acomodar novo módulo. O teste CORS novo deve comprovar paridade das duas políticas locais.

## 3. Duas origens e contrato de transporte

As únicas origens permitidas são:

| Origem exata | Fonte e finalidade |
|---|---|
| `http://127.0.0.1:4173` | Runner existente e workflow Teste C; quatro provas locais com fonte pinada |
| `https://scope-and-approval-keeper.lovable.app` | Configuração Playwright e dois workflows HML versionados; smoke publicado separado |

Não incluir localhost, outra porta, preview, editor Lovable, subdomínio variável ou novo domínio. Não usar regex, curinga, reflexão irrestrita de Origin, Host ou Referer como autoridade. Origin nulo, múltiplo, malformado ou diferente é rejeitado. A existência de uma URL de preview não autoriza incluí-la.

Métodos permitidos para negociação: `POST, OPTIONS`. Headers permitidos: `authorization, x-client-info, apikey, content-type`.

- Preflight válido exige origem exata aprovada, Request-Method POST e apenas os headers da lista; retorna 204 sem corpo material, sem consulta Auth/DB/RPC/Storage e sem assinatura ou efeito de negócio.
- Preflight inválido retorna 403 sem Allow-Origin e pode ser negado sem body material. OPTIONS sem Origin permanece 405.
- GET, PUT, PATCH, DELETE e HEAD reais permanecem 405, com o contrato atual. OPTIONS não executa operação documental.
- POST com origem aprovada percorre o fluxo atual; Origin não aprovado impede efeito material. POST sem Origin preserva o cliente não navegador e seus controles de autenticação e autorização.
- Allow-Origin contém somente a origem exata aprovada. Não usar Allow-Credentials, cookies ou Expose-Headers desnecessário.
- Vary inclui Origin; no preflight inclui também Request-Method e Request-Headers. Preservar no-store e nosniff, sem cache duradouro de preflight.
- Aplicar CORS a todas as saídas geradas pelos handlers para a origem aprovada, inclusive erros existentes. Não inventar novo código de erro: usar o catálogo existente quando houver body, como AUTH_ACESSO_NEGADO e METODO_INVALIDO. Não alterar o erro do gateway nem escondê-lo por catch genérico.

## 4. Conferência dos headers no SDK e no cliente aprovado

O `bun.lock` do commit frontend `164b10b44eaf5b553efcc7ab4e053b86c4d3b269` fixa `@supabase/supabase-js` e `@supabase/functions-js` em 2.118.0. O cliente Supabase desse mesmo commit aponta ao projeto HML e configura apenas armazenamento e persistência de autenticação; não ativa região específica, tracing ou headers personalizados nos dois adaptadores documentais.

A conferência primária do SDK foi feita no tag oficial `v2.118.0`:

| Fonte primária | Blob | Resultado relevante |
|---|---|---|
| https://github.com/supabase/supabase-js/blob/v2.118.0/packages/core/functions-js/src/FunctionsClient.ts | `a92fec00afaa5d81638df2a56bec46c50839fe85` | POST padrão, Content-Type application/json para objeto, x-region somente com região diferente de any |
| https://github.com/supabase/supabase-js/blob/v2.118.0/packages/core/supabase-js/src/lib/fetch.ts | `803f6948701fed3997ce7037d663c1b645cf3465` | Inclusão de apikey e Authorization; trace headers dependem de ativação explícita |
| https://github.com/supabase/supabase-js/blob/v2.118.0/packages/core/supabase-js/src/lib/constants.ts | `8c194c8cb6489db78ed8cd9f98c5c48639e8e69c` | X-Client-Info padrão e tracing desativado por padrão |

Os adaptadores `documentosDados.ts` e `baseNormativaDados.ts` do pin chamam `functions.invoke(nome, { body })`, sem região ou headers extras. A lista estrita de quatro headers atende esse contrato. Headers adicionais permanecem bloqueados até prova e revisão; não ampliar a lista por conveniência.

O node_modules local está em 2.119.0 e não foi usado como prova de 2.118.0. Não exigir nova ferramenta ou instalação local: o runner canônico já faz `bun install --frozen-lockfile` no pin aprovado, e essa é a conferência runtime exigida. RED/GREEN Node dos handlers não precisa executar o SDK externo.

## 5. Invariantes materiais e de segurança

Permanecem iguais: payloads, status e códigos de erro existentes, corpos JSON, limite de 8 KiB, MIME/extensões/tamanhos, validade das assinaturas, filename seguro, timezone, bucket privado e `upsert=false`.

`verify_jwt=true` é obrigatório antes e depois do deploy das duas funções. O preflight apenas negocia transporte e não autentica usuário. Upload mantém getUser, organização, contrato, RBAC e arquivos/criar antes de assinar. Download mantém bearer, SELECT sob RLS e autorização Storage. Nenhum novo download privilegiado, bypass, permissão, service_role no navegador ou configuração Auth é autorizado.

Somente Python guarda banco e Auth Admin. Node/Chromium recebem o ambiente allowlist e credenciais de fixtures para login normal. Não extrair JWT, ler storages de autenticação, usar storageState/HAR/trace ou publicar token, URL temporária, path, byte, HTML, payload ou stack. Não usar interceptação ou mock para converter falha em PASS.

## 6. Condição obrigatória antes de credenciais na origem publicada

A URL de workflow comprova a origem operacional escolhida, mas não prova que sua aplicação viva aponta ao backend HML. Por isso, nenhuma credencial de fixture deve ser preenchida ou submetida na publicação antes desta verificação somente leitura:

1. Procurar metadado primário atual que vincule a configuração Supabase daquela publicação ao projeto `gklhhhyosgasnyoxlrui`. Informações genéricas de sincronismo ou o simples texto HML no nome não bastam.
2. Se esse metadado não estiver disponível, o harness deve inspecionar apenas artefatos públicos da própria origem, antes de executar login: HTML/manifesto de assets e configuração efetiva do cliente nos módulos por eles referenciados. Usar leitura limitada e mesma origem, sem executar requests em projeto Supabase desconhecido. A configuração deve identificar inequivocamente `https://gklhhhyosgasnyoxlrui.supabase.co` como destino do cliente usado pelo fluxo; mera ocorrência de uma string HML em código não vinculado à configuração não basta.
3. Se os artefatos não permitirem determinar essa configuração com segurança, se houver destino divergente/ambíguo ou necessidade de consultar PROD para decidir, marcar `PUBLICADA_BACKEND_NAO_COMPROVADO`, interromper antes das credenciais e executar cleanup. Não adivinhar nem criar endpoint no frontend para resolver a lacuna.
4. Com o destino público inequivocamente confirmado, abrir a UI em contexto novo e sem sessão, conferir origem e observar a rede normal. Qualquer destino Supabase divergente ou redirecionamento não aprovado impede o login e mantém FAIL. Nunca usar credenciais como sondagem para descobrir o ambiente.

A verificação acima prova somente a configuração do backend da publicação. Não é paridade de SHA. Não foi encontrada prova primária de deploy ↔ commit para a aplicação publicada; `latest_commit_sha` de sincronismo não será reinterpretado como published SHA.

## 7. Smoke publicado separado e quatro provas locais

Reutilizar o job `private-browser` e o comando existentes, sem workflow ou executor novo:

`python3 supabase/tests/p0_crud_global_hml.py`

O mesmo Python cria as quatro identidades e dois tenants próprios, inicia o Node, monitora o processo e executa cleanup. O smoke usa o mesmo administrador, organização e contrato próprios, sem novas identidades ou tenants.

Depois da verificação de backend da seção 6, o navegador faz login pela UI publicada, seleciona organização/contrato e envia um TXT benigno adicional. Antes do request, persistir intenção e nonce próprios. Observar os recibos reais de assinatura, Storage, confirmação e registro. O download deve partir do botão oficial, após segurança e worker reais.

A readiness publicada deve vir da UI e da rede normal, com confirmação SQL do guardião Python para os IDs e o escopo próprios. É proibido importar `/src/...` ou avaliar o cliente local como se existisse na publicação. Se necessário, o watcher existente pode confirmar uma fase fixa de readiness do smoke por handshake privado e somente SELECTs hardcoded dos próprios arquivo/documento/versão/job; nonce e IDs devem ser verificados, sem aceitar SQL, comando, URL ou escopo arbitrário do Node. Esse controle não altera status de produto nem consome fila.

Se UI, rede, backend confirmado, segurança, worker ou confirmação SQL não permitirem concluir o smoke, interromper antes da prova local. Não usar fallback por JWT, SDK injetado, chamada fabricada ou arquivo seeded.

Registrar o smoke em recibos separados e relatório próprio, com `frontend_head=null` e `source_parity=NAO_VERIFICADA`. Ele comprova apenas CORS da origem operacional, com código não vinculado ao pin. Não substitui TXT v1 local nem recebe certificação de frontend publicado.

Só depois executar integralmente, em `http://127.0.0.1:4173`, as quatro provas do código pinado: TXT v1/v2 e PDF v1/v2. Login normal e origem local nova; nenhum recibo publicado entra no conjunto local. Um filtro real de título pode separar na UI os dois documentos locais do documento de smoke; não apagar ou ocultar evidência no banco.

### Cinco recibos, duas proveniências e cleanup completo

| Conjunto | Arquivos/objetos | Documentos | Versões | Proveniência |
|---|---:|---:|---:|---|
| Smoke publicado | 1 | 1 | 1 | Origem e backend comprovados; código não vinculado, frontend_head=null |
| Prova local completa | 4 | 2 | 4 | HEAD frontend 164b10b44eaf5b553efcc7ab4e053b86c4d3b269 |
| União disjunta exigida | 5 | 3 | 5 | Nenhuma substituição, duplicata ou atribuição cruzada |

Python deve verificar os dois conjuntos separadamente e a união exata com os objetos recuperados por namespace/nonce próprios. Não apenas trocar o contador quatro por cinco. Recibo perdido, objeto órfão ou ambiguidade deve ser recuperado ou manter FAIL.

O cleanup cobre todos os cinco uploads, mesmo se o smoke falhar antes da prova local. Deve banir as mesmas contas e revogar suas sessões nas duas origens, MASTER e vínculos, preservando objetos privados, versões e auditoria. Só cancelar pendências próprias ainda não consumidas; worker ativo, filho concorrente ou fila restante mantém FAIL/cleanup pendente e repetição independente. Não inativar organização como falsa prova de interrupção de worker.

Preservar `permission_control=REVOKED` e impedir sobrescrita pelo fixture antigo do Node. Falha do watcher encerra o navegador e ainda executa banimento/revogação. Manter até 300 segundos por arquivo e a janela global de 900 segundos, iniciada antes do smoke, sem reiniciá-la na troca de origem ou ampliar timeouts silenciosamente.

## 8. TDD e revisão antes de integrar o BUILD

O RED deve exercitar os handlers reais das duas Edges e demonstrar o baseline OPTIONS 405/sem CORS. Substituir somente o transporte externo em testes locais para contar efeitos; mocks locais nunca são prova de HML.

Exigir testes positivos das duas origens e negativos de Origin, porta, protocolo, hostname parecido, preview não aprovado, métodos e headers extras. Preflight não pode consultar Auth/DB/RPC/Storage. Verificar headers em todas as saídas geradas pelos handlers e preservar status/corpos, limite JSON, filename e controles de assinatura.

Executar integralmente as regressões existentes de RBAC, incluindo permissão revogada, erro de backend, transporte e resposta malformada; não afrouxá-las. Sessão ausente/inválida, leitor, tenant B e contexto divergente permanecem negados. HTTP 401, 500 ou falha de transporte não contam como prova RBAC.

O protocolo do harness deve demonstrar:

- Bloqueio antes das credenciais se backend publicado não for inequivocamente HML.
- Readiness publicada sem `/src`, extração de JWT ou código pinado fictício.
- Ordem smoke publicado adicional → quatro provas locais; smoke FAIL impede o segmento local.
- Cinco recibos disjuntos, proveniência separada e recuperação de recibo ausente nos dois conjuntos.
- Controle SQL de readiness restrito a leitura e escopo próprio; rejeição de nonce/ID terceiro, ação desconhecida e replay indevido.
- Cleanup de todos, inclusive falha do watcher/worker, sem perda do marcador de revogação.
- Saneamento de relatórios com canários; ausência de token, URL, path, nome de arquivo, byte, HTML e erro bruto.

GREEN exige novo teste CORS, protocolo e suíte Node completa, sintaxe e gates Context, ZeroDrift, Crosswalk, Architecture, SQL, segurança e histórico. A baseline anterior é `node --test`: 60/60 PASS; não inventar o total futuro antes de executar os novos testes. Frozen install do runner confirma o SDK pinado. Teste C independente é somente leitura; guard, restore e backup devem passar no mesmo SHA final.

## 9. Integração, deploy HML e rollback

Após a integração deste GATE e dos checks próprios, declarar `BUILD_CORS_DOCUMENTAL_HML` e os dez caminhos no manifesto. A fase técnica continua sem disparar o job CRUD material. Executar RED → BUILD → GREEN → revisão independente → CI → integração.

O deploy posterior fica estritamente limitado às duas funções, projeto `gklhhhyosgasnyoxlrui`, fontes do SHA integrado aprovado e `verify_jwt=true` explícito. Conferir hashes, checks e contrato da ferramenta oficial ou CLI antes de executar. Não usar arquivo provisório, branch solta, deploy-all ou `--no-verify-jwt`. Não editar workflow para improvisar executor.

Consultar novamente fonte, versão, hash e JWT de ambas depois do deploy. Só então retomar a fase global em checkpoint próprio para o runner existente. OPTIONS real é verificação de transporte; somente o smoke de navegador e as quatro provas locais, com negativos e cleanup, podem sustentar seus respectivos resultados parciais.

Guardar as fontes anteriores verificadas para rollback: upload v6 e download v4 são a baseline de conteúdo. Se necessário, suspender novos uploads, executar cleanup e reimplantar somente essas fontes com JWT true; o provedor pode gerar novas versões. Não reverter banco, RLS, Auth, Storage ou histórico. Rollback restitui a lacuna CORS e deve ser registrado como NO-GO. Se apenas uma função for atualizada, não iniciar prova documental até completar ambas ou reverter de modo controlado.

## 10. Autorizações estreitas, negações e resultado permitido

A continuidade autorizada pelo titular abrange a correção HML por seu rito próprio, fixtures próprias e cleanup. Não há nova aprovação humana rotineira a solicitar por hipótese. Não há autorização para novas origens, outras funções, PROD, mudança de permissão, premissa funcional ou fornecedor.

Os advisors registrados no PLAN são baseline não causal. Não revogar RPCs, criar ou apagar índices, alterar políticas ou configurar Auth nesta tarefa. Nenhum risco material novo não delegável foi identificado; uma lacuna técnica concreta deve ser registrada sem ampliar escopo.

`completed_scopes` permanece parcial. Domínio documental integral, frontend publicado, CRUD global, V1, versões seguintes e PROD não recebem certificação por este GATE ou pelo smoke. Sem provas reais dos critérios obrigatórios, manter FAIL/NO-GO e pendências explícitas.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Impacto visual de implementação: N/A justificado. ContaOS Brand v1.0, BRAND-01, componentes, assets e tokens permanecem preservados. Reutilizar o runner, as fixtures e os contratos oficiais; nenhum workflow novo ou turno Lovable de implementação. Economia não reduz TDD, Teste C, segurança, CI, proveniência, cleanup ou prova de navegador.

Esta minuta pode ser validada e publicada somente como GATE documental, com manifesto ainda sem habilitar Edges. BUILD e deploy dependem da integração e dos checks de suas etapas. Não declarar executado o que este documento apenas condiciona.
