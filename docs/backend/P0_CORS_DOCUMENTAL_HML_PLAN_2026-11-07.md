# Proposta de PLAN próprio: CORS documental HML

Data: 07/11/2026. Estado: proposta local, sem BUILD ou deploy.

Esta preparação não alterou código, manifesto, frontend, Git remoto ou configuração do HML. O objetivo é corrigir a negociação CORS de duas Edge Functions existentes, preservando seus controles de acesso e a API documental.

## 1. Causa comprovada e evidências

O lote DOCUMENTOS permanece FAIL. A execução HML `42420832115`, job `128548730992`, usou backend `a672f44cdeebd3e0a1d3f2bc5b445a9a283e7ba0` e frontend `618cfe3f5cc1142553bbaf2a1d525c7c2ab95c1b`. A parada ocorreu em `DOCUMENT_TXT_V1_WAIT_SIGN_UPLOAD`.

O relatório em `/tmp/documentos-hml-42420832115/public-browser/report.json` comprova configuração HTTP 200, TXT/PDF permitidos, formulário aberto e preenchido, uma tentativa de assinatura com `http=null` e `failed=true`. Não houve request de Storage, confirmação ou registro documental. O ZIP teve SHA-256 conferido: `f9f192a04b0a629ecdb07aa885b7d4dc0768a81020a6086293f814181b53f7d6`. O cleanup verificou quatro usuários e duas organizações em quarentena, sem arquivo, objeto ou job criado.

Root consultou `function_edge_logs` pelo mecanismo ClickHouse, em modo de leitura, na janela de 22:29 a 22:32: houve exatamente um `OPTIONS /functions/v1/storage-sign-upload` com HTTP 405 e nenhum POST. Essa consulta foi informada pelo root; este agente não a apresenta como consulta própria.

A leitura independente de `get_edge_function` confirmou:

| Função | Versão e estado | verify_jwt | Bundle ezbr_sha256 | Constatação |
|---|---|---|---|---|
| storage-sign-upload | 6, ACTIVE | true | 1562cdc549369430bcbd53d7474619d167443a4fc6d7bfd303b88ba29caff880 | Rejeita todo método diferente de POST com 405; não trata OPTIONS nem devolve headers CORS. |
| storage-sign-download | 4, ACTIVE | true | fd6b7668421313e35a3afaccc0b0fa084dd12211b1cbb2ddd085e51c766d3779 | Apresenta a mesma lacuna; o lote ainda não alcançou o download. |

Os hashes identificam bundles retornados pelo provedor, não hashes calculados do arquivo TypeScript. O projeto alvo exclusivo é `gklhhhyosgasnyoxlrui`.

A causa do bloqueio atual é a recusa do preflight antes do POST autenticado. Parser, worker, integridade e cadastro documental ainda não foram exercitados nessa rodada. A documentação oficial confirma a necessidade de tratar preflight e incluir CORS nas respostas efetivas e de erro: https://supabase.com/docs/guides/functions/cors . Seus exemplos genéricos com curinga não serão copiados.

## 2. Contexto, autoridade e coordenação

O contexto obrigatório 00–20, P0, matriz 08A–08D, manifesto e tarefa foi lido nesta sessão. O Context Gate confirmou o fingerprint inalterado `c5dc0a97dd3a371fbdfbbd425c3fd31089e2d82f7c51a7458f0ecaedc2330088`. Requisitos relacionados: V1-CON-001, V1-DOC-001/003/005 e NFR-003, preservando autorização, tenancy e histórico.

O manifesto vigente proíbe `supabase/functions/**` e não autoriza alterações em Edges. Portanto é necessário declarar o escopo técnico de CORS por PLAN e GATE próprios antes de editar as funções. Isso não autoriza alterar permissões, premissas funcionais ou PROD.

O master frontend permanece único. No backend, a proposta mantém `id=P0-CRUD-GLOBAL-HML-20261107` e registra `technical_subtask.id=P0-CORS-DOCUMENTAL-HML-20261107`, com objetivo, arquivos, flags e evidências próprios. Mantém também o crosswalk do Prompt 31, suas fontes, hashes e a política BRAND-01. Não foi identificada regra canônica que obrigue trocar o ID do master para essa dependência técnica.

As fases propostas são `PLAN_CORS_DOCUMENTAL_HML`, `GATE_CORS_DOCUMENTAL_HML` e `BUILD_CORS_DOCUMENTAL_HML`. Elas suspendem a execução material do CRUD pelo roteamento existente. Somente depois do deploy e da conferência das duas Edges será restaurada a fase `BUILD_PROVA_PRIVADA_CRUD_GLOBAL` para executar o runner existente.

Não publicar este PLAN antes de frontend 309 integrado, conforme coordenação do root. Depois, reancorar os HEADs e o pin aprovado uma única vez. A revisão da proposta não representa execução de BUILD ou deploy.

## 3. Auditoria de invokes e limite de duas funções

A busca em todo o código de produto, excluindo testes, encontrou três adaptadores com `functions.invoke`:

| Adaptador | Funções invocadas | Consumidores observados | Limite |
|---|---|---|---|
| src/lib/contratos/documentosDados.ts | storage-sign-upload e storage-sign-download | DocumentosContrato, DocumentoDetalhe, CompetenciaDocumentos, RequirementDrawer e ImportarHistorico | Duas funções dentro do fix. |
| src/lib/contratos/baseNormativaDados.ts | storage-sign-upload e storage-sign-download | BaseNormativaContrato e operações de arquivo do orçamento | O transporte compartilhado será corrigido; esses módulos não recebem certificação funcional por isso. |
| src/lib/administracao/admUsuariosRpc.ts | admin-invite-user | Administração e convites | Fora do escopo; não copiar nem alterar seu CORS existente. |

Não foi encontrado outro `fetch` direto de `/functions/v1/` no produto. As transferências simples/TUS usam Storage; confirmação e comandos documentais usam RPCs. Nenhum worker, cron, bucket, RPC ou outra Edge entra nesta tarefa. Nenhuma alteração frontend é necessária.

## 4. Origens comprovadas e allowlist exata

| Origem | Fonte | Decisão |
|---|---|---|
| http://127.0.0.1:4173 | Base e servidor fixos em supabase/tests/p0_crud_global_browser.mjs; frontend .github/workflows/contaos-teste-c-independente.yml também usa esse endereço. | Incluir apenas esse IP e essa porta para o runner. |
| https://scope-and-approval-keeper.lovable.app | frontend playwright.config.ts e workflows contaos-sys03-hml-authenticated.yml e contaos-sys03-hml-playwright-smoke.yml declaram essa URL operacional. | Incluir e executar o smoke real descrito adiante. No GATE, conferir as fontes no pin integrado aprovado. |
| https://id-preview--b113dd59-6caf-4c92-8302-457a037a0c6f.lovable.app | Lovable get_project retornou exatamente esse preview para o projeto ligado pelo README. | Não incluir: a existência do preview não demonstra necessidade neste escopo. |
| https://lovable.dev | É a origem do editor ou de um ancestral de autenticação. | Não incluir: não é a origem da aplicação que invoca as funções. |
| localhost, outras portas, outros previews, novos domínios e PROD | Não há necessidade comprovada neste plano. | Bloquear. |

A URL publicada acima vem de configuração operacional versionada, não do nome do projeto. `get_project` confirmou o preview e `is_published=true`, mas não retornou `published_url`. Não confundir essas fontes. Um override de `CONTAOS_HML_FRONTEND_URL` não amplia a allowlist.

## 5. Contrato CORS a implementar

1. Usar helper local autocontido em cada função, com testes de paridade. Não criar módulo importado, dependência, wrapper ou atualização de SDK. A versão existente é supabase-js 2.118.0.
2. Comparar `Origin` com as duas strings exatas. Não confiar em prefixo, sufixo, regex, Host ou Referer. Rejeitar origem nula, múltipla, malformada, parecida ou com porta diferente.
3. Aceitar preflight somente com origem aprovada, `Access-Control-Request-Method: POST` e headers requisitados contidos na lista aprovada. Retornar 204 sem executar Auth, DB, RPC ou Storage e sem emitir URL ou token.
4. Retornar `Access-Control-Allow-Origin` com a origem exata; `Access-Control-Allow-Methods: POST, OPTIONS`; `Access-Control-Allow-Headers: authorization, x-client-info, apikey, content-type`.
5. A lista de headers corresponde ao cliente JSON autenticado atual. Não há configuração de region ou tracePropagation. Headers opcionais adicionais permanecem bloqueados até necessidade comprovada. Conferir o SDK pinado e os nomes efetivamente enviados, sem registrar seus valores.
6. Usar `Vary: Origin` nas respostas efetivas. No preflight, incluir também `Access-Control-Request-Method` e `Access-Control-Request-Headers`. Preservar `cache-control: no-store` e `x-content-type-options: nosniff`; não introduzir cache duradouro de preflight.
7. Não incluir `Access-Control-Allow-Credentials`, cookies, curinga ou exposição desnecessária de headers. Nenhum token, URL assinada ou path entra em log ou relatório.
8. Preflight não aprovado retorna 403 sem `Allow-Origin` e sem efeito material. OPTIONS sem Origin permanece 405. Métodos reais GET, PUT, PATCH, DELETE e HEAD continuam 405, com o corpo atual.
9. POST de origem aprovada mantém todas as validações existentes. POST com Origin não aprovado falha antes de efeito material. POST sem Origin mantém o contrato de cliente não navegador, exigindo JWT e os controles atuais. CORS não substitui autorização para clientes capazes de omitir ou forjar Origin.
10. Todas as respostas geradas pelos handlers para uma origem aprovada, inclusive os erros existentes, recebem CORS. Status, códigos, corpos JSON, limite de 8 KiB, validade de URLs, `upsert=false`, MIME, tamanho e timezone permanecem iguais. Não criar catch que esconda erro de produto ou altere respostas do gateway.
11. `verify_jwt=true` permanece no deploy e na consulta posterior. Upload mantém getUser, organização, contrato, RBAC e permissão arquivos/criar. Download mantém bearer, SELECT sob RLS e autorização Storage. Não introduzir download privilegiado ou novo uso de service_role.

## 6. Arquivos permitidos na futura subtarefa

A allowlist proposta contém exatamente:

1. docs/backend/P0_CORS_DOCUMENTAL_HML_PLAN_2026-11-07.md
2. docs/backend/P0_CORS_DOCUMENTAL_HML_GATE_2026-11-07.md
3. docs/backend/P0_CORS_DOCUMENTAL_HML_RESULTADO_2026-11-07.md
4. docs/tasks/active-task.json
5. supabase/functions/storage-sign-upload/index.ts
6. supabase/functions/storage-sign-download/index.ts
7. supabase/tests/storage_document_cors.test.mjs
8. supabase/tests/p0_crud_global_browser.mjs
9. supabase/tests/p0_crud_global_protocol.test.mjs

Os dois últimos arquivos permitem o smoke publicado no runner atual. Python não precisa ser alterado: o desenho mantém as mesmas quatro identidades, dois tenants, quatro uploads e dois documentos já previstos. O guardião, o monitor do processo, a verificação SQL e o cleanup atuais permanecem aplicáveis. Se surgir necessidade real de mudar Python, declarar essa lacuna antes do GATE ou em emenda; não ampliar a lista durante a implementação.

O teste existente `storage_upload_rbac.test.mjs` remove imports e executa o handler em VM. Por isso, helpers locais evitam alterar o loader ou as assertions desse teste só para acomodar a tarefa. Executá-lo integralmente, assim como `security-download-filename-check.mjs`.

Proibidos: todo frontend; workflows; migrations, schema, RLS, grants e RPCs; supabase/config.toml; outras funções; configuração Auth, Storage ou cron; segredos; canônicos/fingerprint; PROD.

Durante PLAN/GATE, somente documentos e manifesto são alteráveis. No BUILD validado, autorizar explicitamente os dois arquivos Edge e os testes/harness acima. Flags de banco, RLS, configuração Auth e Storage continuam false. Nenhum workflow novo ou alterado é proposto.

## 7. Smoke publicado no runner existente, antes da prova local

### Runner e comando concretos

Reutilizar o job `private-browser` do workflow `.github/workflows/p0-crud-global-browser-hml.yml`. Ele já instala Chromium/Playwright, carrega o frontend pinado e executa:

`python3 supabase/tests/p0_crud_global_hml.py`

O Python já cria as fixtures por Auth Admin, mantém banco e credencial administrativa fora do Node, inicia o browser, monitora o controle fechado e executa cleanup em finally. Não criar outro executor, workflow, comando de deploy ou transferência manual de credenciais.

O smoke será o primeiro segmento do lote DOCUMENTOS nessa mesma invocação, depois de fixtures criadas e antes do segmento documental local. Não será um segundo processo com fixtures próprias nem um teste de curl.

### Sequência de navegador e preservação das contagens

1. O Node abre um contexto real em `https://scope-and-approval-keeper.lovable.app`, verifica a origem exata da página e efetua login pela UI normal com a identidade administrador da fixture existente. Seleciona a mesma organização e o mesmo contrato sintéticos.
2. Reutiliza os helpers atuais de login, seleção de organização e upload, parametrizados apenas por duas superfícies fechadas: PUBLICADA e LOCAL. A origem não vem de URL arbitrária, comando ou payload. Não importar `/src/...` na aplicação publicada, não injetar um SDK e não ler localStorage, storageState, sessionStorage ou JWT para autenticar requests de teste.
3. Na UI publicada, executa o TXT versão 1 que já integra os quatro uploads aprovados. Grava intenção privada antes da ação; observa a chamada de `storage-sign-upload`, o envio ao Storage, a confirmação e o registro. Usa o worker normal, sem alterar status, e aguarda a segurança real.
4. Ainda na UI publicada, clica no download oficial do mesmo arquivo. Confere o retorno de `storage-sign-download` e a integridade/tamanho dos bytes recebidos, conforme o helper atual. A URL temporária permanece privada e não vira evidência pública. Isso comprova que o navegador recebeu as respostas CORS das duas funções, não apenas que OPTIONS respondeu.
5. Persiste o recibo desse TXT na mesma fixture, com marca de superfície PUBLICADA. Registra no relatório somente estágios, booleanos, status e contagens. Se login, rota, assinatura, upload, worker ou download falhar, interrompe antes do segmento local e executa o cleanup existente.
6. Somente após o smoke passar, abre um novo contexto em `http://127.0.0.1:4173`, faz novo login normal com a mesma identidade e seleciona a mesma organização/contrato. Continua a prova local com TXT versão 2, PDF versão 1 e PDF versão 2. O TXT versão 1 publicado é reutilizado pelo recibo; não é enviado de novo.
7. Assim, permanecem quatro uploads e dois documentos, com duas versões cada. O Python atual ainda exige quatro arquivos, quatro objetos, integridade, ator, auditoria, worker e versões preservadas. Não mudar seus asserts nem aceitar contagem maior para acomodar o smoke. A janela de 900 segundos do lote começa antes do primeiro upload publicado; não reiniciar o orçamento de espera ao trocar de origem.
8. As negativas existentes, inclusive revogação do vínculo próprio com sessão ainda válida, continuam no segmento local. Depois delas, o cleanup único bane as mesmas contas, revoga todas as sessões dessas identidades nas duas origens, preserva objetos/histórico e mantém FAIL se houver trabalho ativo.

O sucesso publicado deve produzir uma evidência separada de superfície, por exemplo `CORS_PUBLICADA_UPLOAD_DOWNLOAD`, sem certificar visual, versão de código publicada ou domínio documental inteiro. A correspondência do bundle publicado com o pin GitHub não será presumida pela URL; registrar a versão se houver prova primária, ou mantê-la como não comprovada. O objetivo desse segmento é a negociação CORS da origem operacional usando UI real. Se os controles de UI necessários não existirem na publicação atual, registrar o bloqueio e não contornar pelo JWT ou por chamadas fabricadas.

### Testes da integração no harness

O protocolo deve provar, por callbacks/objetos de teste fechados, que a ordem é PUBLICADA TXT v1 → LOCAL TXT v2/PDF v1/PDF v2; que o primeiro recibo é reutilizado; que falha publicada impede as ações locais; que não há quinto upload; e que as origens não podem ser trocadas por string arbitrária. Isso testa a orquestração sem simular um PASS HML.

Testar também que a troca de superfície não extrai tokens, não altera a fixture após o handshake de revogação e não apaga `permission_control=REVOKED`. Preservar o ambiente allowlist e o controle fechado do Python. `completed_scopes` continua parcial e `documentos_contrato` permanece entre os domínios não verificados.

## 8. Roteamento e impacto nos testes atuais

O scope existente ativa o job material somente para a dupla `P0-CRUD-GLOBAL-HML-20261107` / `BUILD_PROVA_PRIVADA_CRUD_GLOBAL`. As fases técnicas CORS deixam esse job desabilitado até a retomada explícita após o deploy.

Verificação somente leitura já executada: o script real de scope foi extraído e rodou com cinco manifests temporários isolados. PLAN, GATE e BUILD_CORS com o ID master resultaram `applicable=false`; ID CORS com fase BUILD global também false; a dupla master/BUILD global resultou true. O manifesto real não foi alterado. Resultado: `CORS_PLAN_ROUTING_READONLY_PASS`.

A suíte atual foi executada com o comando exato `node --test`: 60/60 PASS. Os testes de roteamento e inicializador usam seus próprios manifests temporários e não precisam ser afrouxados por causa de PLAN/GATE. Context Gate exige o fingerprint vigente; Crosswalk exige manter as fontes e o Prompt 31. Não alterar testes funcionais para aceitar uma fase ou um ID novo.

## 9. TDD, revisão e provas exigidas

Antes do código, demonstrar RED nos handlers reais das duas Edges: OPTIONS válido retorna 405 e não fornece CORS no baseline. O padrão VM já usado no teste RBAC pode substituir somente o transporte externo, permitindo contar efeitos.

Cobertura obrigatória:

- As duas origens exatas têm preflight 204, origem exata, métodos POST/OPTIONS e Vary correto, sem nenhuma chamada Auth/DB/RPC/Storage.
- Origem desconhecida, null, malformada, múltipla, subdomínio parecido, protocolo trocado, porta diferente, localhost e preview não aprovado são negados. Request-Method PUT/DELETE e header adicional também são negados, sem assinatura ou efeito.
- Métodos reais GET/PUT/PATCH/DELETE/HEAD permanecem 405. POST sem Origin preserva o contrato atual de cliente não navegador, com autenticação e autorização.
- JWT ausente ou inválido, leitor, tenant B, sessão/permissão revogada, contexto divergente, erro RBAC, erro de transporte e resposta RBAC malformada continuam negados. Nenhum deles emite URL ou token.
- Respostas efetivas de sucesso e erros gerados pelos handlers incluem CORS apenas para origem aprovada; não incluem curinga ou credentials. Status/corpos/limite JSON/filename/validade de URL permanecem iguais.
- O novo protocolo do harness comprova a sequência publicada/local e as contagens descritas na seção 7, sem mocks que virem evidência operacional.
- Relatórios descartam canários de token, path, URL, nome de arquivo, HTML, payload e erro bruto.

GREEN local exige o novo protocolo, testes RBAC e filename existentes, suíte Node completa, sintaxe e gates Context, ZeroDrift, Crosswalk, Architecture, SQL, segurança e histórico. Teste C independente é somente leitura. Guard, restore e backup devem passar no mesmo HEAD final. Testes locais não provam o gateway HML.

## 10. Sequência de integração e deploy controlado

1. Após frontend 309 integrado, reancorar HEADs, pin, fontes e versões implantadas. Integrar PLAN documental e manifesto técnico após revisão e CI/restore/backup no mesmo SHA. Não habilitar código ou deploy nessa etapa.
2. Integrar GATE separado, fechando origens, headers, arquivos, método de deploy e invariantes JWT/RBAC/RLS.
3. Executar RED → BUILD mínimo → GREEN local e CI → Teste C independente. Integrar a implementação e o ajuste estrito do harness.
4. Antes do deploy, conferir checks, SHA integrado, hashes das fontes, alvo `gklhhhyosgasnyoxlrui` e `verify_jwt=true`. Usar CLI com comandos previamente conferidos por `--help`, ou ferramenta oficial com contrato verificado. Não editar workflow para improvisar deploy.
5. Implantar somente `storage-sign-upload` e `storage-sign-download`, com as fontes do SHA aprovado e JWT true explícito. Não usar deploy-all ou `--no-verify-jwt`. Conferir novamente fonte, versão, hash e metadata de ambas; guardar a baseline para rollback.
6. Conferir OPTIONS reais positivos e negativos. Depois restaurar a fase global em checkpoint aprovado para executar o job existente e o comando Python da seção 7. O navegador deve concluir o smoke publicado antes da prova local. Logs devem permitir correlacionar OPTIONS 204 e POST autenticado, sem valores de credenciais.
7. Inspecionar relatórios, hashes, recibos, worker, negativas e cleanup. HTTP 401/500 não contam como prova de negação RBAC. Um erro posterior ao CORS permanece FAIL e segue investigação própria, sem status forçado.
8. Registrar resultado e checkpoint efetivamente integrados. Não certificar domínio documental integral, CRUD global, V1 ou PROD por esse escopo parcial.

## 11. Impacto e rollback

Impacto intencional: as duas origens aprovadas passam a negociar e ler as respostas das duas funções existentes. Outros consumidores dessas mesmas funções recebem o transporte corrigido, mantendo as mesmas permissões. Isso não certifica os demais módulos.

Rollback: interromper novos uploads, executar o cleanup independente e verificar filas. Reimplantar somente as fontes anteriores conferidas das duas funções, preservando JWT true. Upload v6 e download v4 identificam a baseline de conteúdo; o provedor pode gerar novas versões ao reimplantá-las. Não reverter migration, RLS, Auth ou Storage, nem apagar objetos ou histórico. O rollback restitui a indisponibilidade CORS e deve ser registrado como NO-GO.

Se apenas uma função for implantada, bloquear a prova documental até completar e conferir ambas ou executar rollback controlado. Não anunciar uma correção parcial como PASS.

Nenhum risco material novo não delegável foi identificado nesta proposta. Origens adicionais, alteração de permissão/premissa ou PROD permanecem fora do plano. A ausência de UI necessária na publicação, divergência de fonte ou impedimento no método de deploy é um bloqueio técnico a registrar, não autorização para extrair JWT, criar executor ou expandir caminhos.

## 12. Baseline dos advisors, sem relação causal com OPTIONS 405

Root informou: health 0; security INFO `rls_enabled_no_policy` 5 no schema privado, WARN `authenticated_security_definer_function_executable` 9 e WARN `leaked_password_protection` 1; performance INFO `unindexed_foreign_keys` 89 e `unused_index` 188. Não foram expostas credenciais.

As URLs abaixo foram conferidas diretamente no retorno atual de `get_advisors`, em consulta somente leitura deste agente. São exatamente as remediações fornecidas pelo provedor:

| Achado | URL retornada pelo provider |
|---|---|
| RLS habilitada sem policy | https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy |
| SECURITY DEFINER executável por authenticated | https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable |
| Proteção contra senha vazada | https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection |
| Foreign keys sem índice | https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys |
| Índices não utilizados | https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index |

Esses achados são baseline e não explicam o preflight 405. Não revogar RPCs, alterar policy/grant, criar/remover índices ou mudar Auth nesta tarefa. Cada eventual tratamento exige confronto com o desenho canônico e escopo próprio.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Impacto visual de implementação: N/A justificado. A mudança se limita à negociação HTTP de duas funções e à prova do harness existente; nenhum componente, asset, token ou Design System é alterado. ContaOS Brand v1.0 e BRAND-01 permanecem preservados.

Reutilizar contratos, runner, fixtures, testes e ferramentas oficiais. Nenhum turno Lovable de implementação é necessário. A consulta get_project foi somente leitura para distinguir a origem de preview. Não reduzir TDD, segurança, CI, Teste C, cleanup ou prova real por economia. A proposta local não representa BUILD, deploy ou publicação.


## Revisão e reancoragem do integrador

Revisão independente do PLAN sem Critical/Important. Precisão incorporada: completed_scopes exige PASS real do lote, não apenas correção CORS. Integrador reexecutou node --test em backend a672f44:60/60 PASS; Context/Zero-Drift/Crosswalk/Architecture/diff PASS. Os25blobs canônicos comparados com c993e38 permanecem sem diff; fingerprint preservado. Consulta própria get_edge_function confirmou uploadv6ACTIVE/JWTtrue/bundle1562cdc549369430bcbd53d7474619d167443a4fc6d7bfd303b88ba29caff880; query_logs na janela22:29–22:32 confirmou OPTIONS405. Nenhum valor de credencial foi lido ou publicado. Reancoragem frontend309 realizada antes da publicação: mergeb0e22f5, HEAD164b10b, trêschecksSUCCESS. Revisão visual independente abriu24GREEN e24RED públicos sem regressão;208casosprotegidos continuam sem sessão.

Método canônico de deploy disponível e inspecionado: ferramenta oficial Supabase deploy_edge_function com project_id exato, name por função, entrypoint_path e files do SHA integrado, verify_jwt=true explícito. Não será usada antes de BUILD integrado e gates; não há necessidade de alterar workflow.
