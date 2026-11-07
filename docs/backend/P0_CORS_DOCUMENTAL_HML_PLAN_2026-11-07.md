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
10. supabase/tests/p0_crud_global_hml.py

Os três arquivos do harness permitem o smoke publicado no runner atual. Python é indispensável para verificar separadamente o smoke adicional e as quatro provas locais, recuperar os cinco uploads e incluir todos no cleanup. Permanecem as mesmas quatro identidades e dois tenants; o smoke usa o mesmo contrato próprio, com documento e recibo separados. A inclusão de Python já fica fechada neste PLAN; não ampliar caminhos durante a implementação.

O teste existente `storage_upload_rbac.test.mjs` remove imports e executa o handler em VM. Por isso, helpers locais evitam alterar o loader ou as assertions desse teste só para acomodar a tarefa. Executá-lo integralmente, assim como `security-download-filename-check.mjs`.

Proibidos: todo frontend; workflows; migrations, schema, RLS, grants e RPCs; supabase/config.toml; outras funções; configuração Auth, Storage ou cron; segredos; canônicos/fingerprint; PROD.

Durante PLAN/GATE, somente documentos e manifesto são alteráveis. No BUILD validado, autorizar explicitamente os dois arquivos Edge e os testes/harness acima. Flags de banco, RLS, configuração Auth e Storage continuam false. Nenhum workflow novo ou alterado é proposto.

## 7. Smoke publicado no runner existente, antes da prova local

### Proveniência: origem comprovada, código publicado não vinculado

Foi procurada prova primária de paridade entre publicação e commit. `get_project` fornece `latest_commit_sha`, informações de sincronismo, `preview_url` e `is_published`, mas não informa o SHA efetivamente implantado na origem publicada. As capacidades de leitura disponíveis não expõem histórico de deployments; a operação `deploy_project` é mutável e não será usada para investigar. A busca no repositório não encontrou build-info, version.json ou marcador de BUILD_SHA servido que permita fazer esse vínculo. Metadado de sincronismo não será reinterpretado como prova de publicação.

Portanto, o smoke publicado será rotulado **origem comprovada / código não vinculado ao pin**. Nenhum upload feito nessa origem substituirá prova local nem será atribuído ao `frontend_head` aprovado. A origem do runner local continuará carregando o código do SHA exato aprovado pelo workflow existente.

### Runner e comando concretos

Reutilizar o job `private-browser` do workflow `.github/workflows/p0-crud-global-browser-hml.yml`. Ele já instala Chromium/Playwright, carrega o frontend pinado e executa:

`python3 supabase/tests/p0_crud_global_hml.py`

O Python já cria as fixtures por Auth Admin, mantém banco e credencial administrativa fora do Node, inicia o navegador, monitora o controle fechado e executa cleanup em finally. A proposta modifica somente os três arquivos desse harness para adicionar e verificar o smoke. Não criar outro executor, workflow, comando de deploy ou transferência manual de credenciais.

O smoke será o primeiro segmento do lote DOCUMENTOS nessa mesma invocação, depois das fixtures e antes das quatro provas locais. Não será um segundo processo com fixtures distintas nem um teste de curl.

### Sequência real de navegador

1. O Node abre um contexto em `https://scope-and-approval-keeper.lovable.app`, verifica a origem exata da página e efetua login pela UI normal com o administrador da fixture já criada. Seleciona a mesma organização e o mesmo contrato sintéticos que serão usados pelo runner local.
2. Reutiliza os helpers de login, seleção de organização e upload, parametrizados apenas por duas superfícies fechadas: PUBLICADA e LOCAL. A origem não pode vir de URL arbitrária, comando ou payload. Não importar `/src/...` na publicação, injetar um SDK, ler storages de autenticação ou extrair JWT. Não usar interceptação, mock ou resposta fabricada.
3. Pela UI publicada, envia **um TXT benigno adicional**, destinado exclusivamente ao smoke de CORS. A intenção privada tem nonce e nome próprios, diferentes dos quatro arquivos locais, e é persistida antes do request. O documento usa título de smoke distinto do prefixo dos dois documentos locais, dentro do mesmo contrato próprio.
4. Observa assinatura de upload, transferência ao Storage, confirmação e registro. Aguarda segurança e processamento reais pelo worker normal; não força status. Clica no download oficial e confere hash/tamanho dos bytes. O retorno de `storage-sign-download` deve ter sido recebido pelo navegador naquela origem. URL temporária e bytes permanecem privados.
5. Persiste esse recibo em coleção separada, por exemplo `published_smoke.uploads`, com superfície PUBLICADA, `frontend_head=null` e `source_parity=NAO_VERIFICADA`. Não inserir o recibo entre os quatro `uploads` locais. Um relatório próprio, `public-browser/cors-published-smoke.json`, identifica somente a prova de transporte dessa origem, com código não vinculado. Ele não herda o SHA do relatório documental local.
6. Se login, rota, controles de UI, assinatura, upload, worker ou download publicados falharem, interrompe antes da prova local e executa o cleanup. A origem pode servir código diferente; ausência do fluxo necessário é bloqueio explícito. Não contornar usando token, chamada fabricada ou aumento de allowlist.
7. Só após esse smoke passar, abre novo contexto em `http://127.0.0.1:4173`, faz login normal com a mesma identidade e seleciona o mesmo tenant/contrato. Executa **as quatro provas locais completas e inalteradas**: TXT v1/v2 e PDF v1/v2. Nenhum desses quatro uploads é substituído pelo smoke publicado.
8. A UI local pode aplicar seu filtro real de título para mostrar somente os dois documentos locais. O smoke tem título próprio e recibo separado. Isso evita confundir a contagem de duas entradas da prova local com a terceira entrada do contrato; o filtro é uma consulta real da UI, não remoção ou ocultação de evidência.
9. As negativas locais, incluindo revogação do vínculo próprio com sessão válida, continuam depois das quatro provas no pin aprovado. O cleanup único bane as mesmas identidades, revoga suas sessões nas duas origens, recupera todos os uploads por escopo/nonce e preserva histórico/objetos. Trabalho ativo mantém FAIL e cleanup pendente.

### Contagens fechadas e verificação pelo Python

O contrato passa a ter exatamente **cinco arquivos/objetos, três documentos e cinco versões**: um arquivo/documento/versão de smoke publicado, mais os quatro arquivos e quatro versões dos dois documentos locais. Não simplesmente aumentar um contador de quatro para cinco e tratar tudo como prova do pin.

O Python deverá verificar dois conjuntos disjuntos:

- **LOCAL_PIN_APROVADO:** exatamente os quatro recibos locais, dois documentos com duas versões cada, hashes distintos por nova versão, ator, auditoria, worker e downloads verificados. Preservar o significado dos asserts atuais de quatro uploads locais.
- **CORS_PUBLICADA_CODE_NAO_VINCULADO:** exatamente um recibo adicional, com documento/arquivo/versão distintos dos locais, estado e download reais, hash/tamanho corretos e nenhuma atribuição de SHA frontend aprovado.

A união exata dos dois conjuntos deve corresponder aos cinco arquivos e objetos recuperados no namespace próprio. Recibo ausente deve continuar recuperável pelo nonce, mesmo se o smoke falhar antes do segmento local; qualquer objeto ou job ambíguo mantém FAIL/pendência. O cleanup não depende apenas dos recibos recebidos e cobre todo o escopo próprio, inclusive o smoke adicional.

Manter a espera de até 300 segundos por arquivo e a janela global atual de 900 segundos, iniciada antes do smoke. Não reiniciar a janela ao trocar de origem nem aumentar timeouts implicitamente. Se a carga adicional exceder o limite, registrar FAIL e avaliar o tempo em tarefa governada; não fabricar PASS.

### Protocolo da orquestração e limites das conclusões

Testar a ordem PUBLICADA smoke adicional → LOCAL TXT v1/v2 e PDF v1/v2, a separação dos recibos, a ausência de substituição de upload local, a união exata de cinco uploads e o bloqueio do segmento local quando o smoke falha. Rejeitar origem arbitrária, recibo cruzado, duplicado ou atribuição do SHA local ao smoke publicado.

Testar recuperação e cleanup quando o smoke cria arquivo ou job, mas perde recibo; falha do watcher ainda deve encerrar o navegador, banir contas e revogar sessões. Preservar o ambiente allowlist, o controle fechado de revogação e `permission_control=REVOKED` sem sobrescrita pela cópia do Node.

O relatório publicado prova somente transporte das duas funções em navegador real na origem documentada. O relatório local mantém o `frontend_head` exato e as quatro provas correspondentes. `completed_scopes` continua parcial, `documentos_contrato` permanece não verificado como domínio integral e o frontend publicado não recebe certificação por esse smoke. Logs de OPTIONS 204 seguidos de POST e observação da resposta pela UI corroboram CORS; curl/OPTIONS isolados não substituem essa prova.

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
6. Conferir OPTIONS reais positivos e negativos. Depois restaurar a fase global em checkpoint aprovado para executar o job existente e o comando Python da seção 7. O navegador deve concluir o smoke publicado adicional antes das quatro provas locais no pin aprovado. Logs devem permitir correlacionar OPTIONS 204 e POST autenticado, sem valores de credenciais.
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

## Reancoragem executiva após frontend #309

Frontend #309 integrado em b0e22f5ab7a479ebb8a3c9bd2d907d5052ec81c5, HEAD aprovado 164b10b44eaf5b553efcc7ab4e053b86c4d3b269. Run 42421827969, jobs 128551769980 e 128551770379 SUCCESS; LOCK 42421827973 SUCCESS. Artefato 13593374754, SHA256 44889c1d42c940cd0e394c7f4851f42e7c9d969412497efc3fd1fb2f22f4b9df verificado, 225 entradas SHA256SUMS conferidas. As 24 capturas públicas foram revisadas sem achados; pilha Inter, Arial, sans-serif computada e 120 contrastes medidos PASS. Não certifica páginas privadas ou WCAG integral. A dependência de integração do #309 está atendida; este PLAN permanece sujeito aos seus próprios checks e a GATE separado. Backend base a672f44cdeebd3e0a1d3f2bc5b445a9a283e7ba0, fontes canônicas e fingerprint inalterados.
