# Trilha C: elegibilidade RAG, quota atômica e prova HML
> Execução posterior: seguir o plano tarefa por tarefa, com TDD e revisão independente. Este PR altera somente documentação. Não libera BUILD, SQL remoto, merge ou deployment.

**Objetivo:** impedir envio externo de fonte não autorizada/insegura, limitar consumo por ator/organização e comprovar o copiloto com JWT real.
**Arquitetura:** userClient/RLS determina o conjunto elegível antes de qualquer similaridade. Novas assinaturas service-only recebem IDs previamente autorizados e repetem os filtros materiais antes do ranking. Uma reserva transacional em consultas_semanticas limita chamadas concorrentes e custo sem tabela paralela.
**Stack:** Supabase/PostgreSQL/Edge existente, Node22, Bun frozen e Playwright somente no runner de prova.
**Fontes:** 00..20, P0, PLAN179; backend PR180 7494f06576be81e6c3136e2bbe0683a9c9ebeb97; frontend PR379 9bc106ce8322e2ed55ee4946e2a6e71d6d752dfd (CI deve ser reancorado antes do BUILD).

## Causas comprovadas e bloqueios
- 136 migrations lidas: somente 0033 define worker_buscar_fragmentos_temporais e worker_buscar_precedentes_ranqueados.
- A Edge usa admin.rpc após SELECT contratos. Isso contorna a política restritiva rbac_v1_select de fragmentos_documento que exige rbac_permite(org,'arquivos','consultar',contrato).
- A RPC documental não filtra arquivos.status_seguranca nem processamentos_documento.status. Acesso ao contrato sozinho não autoriza transmitir seu conteúdo à OpenAI.
- Ranking de precedentes filtra organização/contratante, porém precisa respeitar também a política humana vigente para cada origem. Não ampliar inteligência transversal.
- O limitador existente api_autenticar_cliente usa privado.consumo_rate_limit_api para clientes_api; copilot-query não o chama e usuários JWT não são clientes_api. Não existe enforcement de flood/custo comprovado para esta Edge. Tokens máximos e timeout não resolvem o problema.
- IMPORTANT: elegibilidade e quota bloqueiam certificação e deployment OpenAI. Nenhuma prova visual ou CORS substitui esses gates. HML ainda NÃO CERTIFICADO.

## Escopo documental deste PR
Somente docs/tasks/active-task.json e este plano. Flags DB/RLS/Edge/Auth/Storage continuam false. Preservar task anterior por inteiro e seus recibos; não reiniciar inventários375/376.

## Fase 0: caminho CLI gerado e GATE fechado neste PLAN
- [x] Geração local offline executada: Supabase CLI oficial2.122.0, ajuda migration new conferida, comando migration new c_chat_scope_quota. Caminho real supabase/migrations/20261108232731_c_chat_scope_quota.sql; SHA256 do esqueleto vazio e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855. Nenhuma conexão ou SQL remoto; esqueleto ainda não integra este PR documental.
- [ ] Após revisão/CI/integração deste PLAN/GATE, allowlist BUILD autoriza somente o caminho CLI exato acima. O hash vazio prova a geração, não aprova corpoSQL inexistente. O corpo implementado terá SHA256 final registrado/revisado com Restore/backup antes de qualquer aplicaçãoHML. Nenhum glob, migration antiga ou timestamp inventado autorizado.
- [ ] GATE lista somente Edge existente, testes focais existentes, migration gerada, supabase/tests/copilot_scope_quota.sql, supabase/tests/p0_crud_global_remaining.test.mjs, supabase/tests/remaining_domains/ai_envelope.test.mjs, supabase/tests/copilot_hml.mjs, .github/workflows/copilot-hml.yml, .github/workflows/restore-isolado.yml, manifesto e este plano. A modificação Restore limita-se a executar o novo teste SQL sem retirar suites/isolamento/backup.
- [ ] CI e revisão do GATE antes de código. SQL remoto somente após BUILD revisado, checks no SHA exato, restore limpo e backup sintético de duas instâncias.

## Fase 1: fonte elegível antes da similaridade
**Interfaces propostas, sem alterar assinaturas certificadas:**
- worker_buscar_fragmentos_copiloto(p_id_organizacao uuid,p_id_contrato uuid,p_ids_fragmentos uuid[],p_embedding vector(384),p_data_referencia date,p_limite integer): mesmo retorno documental0033.
- worker_buscar_precedentes_copiloto(p_id_organizacao uuid,p_id_contratante uuid,p_id_contrato uuid,p_ids_precedentes uuid[],p_embedding vector(384),p_limite integer): mesmo retorno de precedentes0033.
- Somente service_role executa essas assinaturas; PUBLIC/anon/authenticated sem EXECUTE, search_path vazio, nenhum grant novo de leitura/escrita e nenhuma RLS alterada.

- [ ] RED SQL real: fonte de outro tenant, contrato sem permissão arquivos, arquivo pendente/quarentena/bloqueado, processamento pendente/falhou e fonte fora da vigência nunca integram resultado ou contexto externo, mesmo com similaridade maior que a fonte segura.
- [ ] Edge consulta fragmentos_documento, versoes_documento, arquivos e processamentos_documento por userClient com JWT validado; IDs/escopos devem coincidir. Relações reais: fragmentos_documento.id_versao_documento -> versoes_documento.id; versoes_documento.id_arquivo -> arquivos.id; processamentos_documento.id_versao_documento.
- [ ] Elegível documental: RLS de cada entidade permite leitura, arquivos.status_seguranca='aprovado', processamento documental normal concluído e nenhuma etapa corrente pendente/processando/falhou para a versão. Etapa real confirmada em queue-worker-documents/index.js: documents, atualização concluido com concluido_em. Exigir documents concluido e ausência de qualquer processamento da versão pendente/processando/falhou/cancelado; versão sem processamento concluído falha fechada. Exigir a mesma organização/contrato em todosjoins, embedding presente e fonte aprovada/aplicável quando normativa.
- [ ] Aplicar vigência como0033 e preservar tipo de fonte formal/documental. Normas exigem versão aprovada/aplicabilidade quando pertencentes a esse domínio; não transformar documento qualquer em norma.
- [ ] Precedentes: IDs por userClient/RLS no mesmo tenant/contratante, status ativo, autorização ao contrato origem e fonte de origem elegível quando documental. Preservar próprio/transversal, precedentes contraditórios e ausência de efeito impeditivo.
- [ ] Paginar por ID com cursor até limite fechado de1000 candidatos por família; páginas100. Se exceder, pedir refinamento com erro amigável, sem truncamento silencioso ou fallback privilegiado. Limitar arraysRPC e checar IDs duplicados/UUIDs inválidos/escopo divergente.
- [ ] Novas RPCs materializam primeiro conjunto permitido por IDs, org/contrato/contratante e estados seguros/temporalidade. Só depois calculam similaridade e ranking. Revalidar segurança/processamento dentro do SQL evita corrida entre leitura Edge e recuperação. Não filtrar após topK.
- [ ] Corrigir somente setup isolado dos dois testes de governança dependentes do manifesto ativo: p0_crud_global_remaining.test.mjs (real gate rejects missing check, failed check and advanced HEAD before Auth) e remaining_domains/ai_envelope.test.mjs (actual routing limits explicit manual resume to exact main inputs). Baseline ebe4:26casos24PASS2FAIL; HEAD0c3ad25a suíteíntegra428casos426PASS2FAIL, mesmosdoistítulos. Usar snapshotBimutável/fixture explícita de tarefaB em diretório temporário e testar separadamente tarefaC não aplicável. Não alterar routing, assertions de checks/SHA, workflowB ou marcarSKIPcomoPASS.
- [ ] GREEN e regressão: chamadas worker certificadas originais permanecem idênticas; novos consumers só copilot-query. RLS/grants/owners/search_path existentes preservados. Nenhuma tabela nova, nenhuma mutation material pelo modelo.

## Fase 2: reserva e quota transacionais
**Interface:** worker_reservar_consulta_copiloto(p_id_organizacao uuid,p_id_contrato uuid,p_id_usuario uuid,p_texto text,p_filtros jsonb,p_modelo text) retorna id_consulta e resultado autorizado/codigo/retry_after. Service-only. Usa consultas_semanticas existente, com criado_por validado na Edge e escopo comprovado por userClient. Não reutilizar identidade de clientes_api para representar usuário.

- [ ] RED concorrente em duas conexões: sete pedidos na mesma janela do mesmo ator, finalizando cada reserva para isolar a taxa, com apenas seis reservas/minuto; teste separado com três reservas simultâneas mantém somente duas ativas. Segundo ator não contorna teto do tenant; chamadas negadas não chegam a embedding/OpenAI.
- [ ] Locks transacionais em ordem organização→ator, contagem e INSERT de reserva na mesma transação. Limites operacionais HML definidos para este BUILD:6/minuto/ator,30/hora/ator,120/hora/organização, máximo2 consultas processando/ator e8/organização. Contar todas reservas, inclusive fallback/falha, para impedir custo de retry não limitado. Nenhuma contagem desprotegida na Edge.
- [ ] Finalização transacional service-only worker_concluir_consulta_copiloto(p_id_consulta uuid,p_token uuid,p_id_sessao uuid,p_retorno jsonb,p_fontes jsonb): lock da reserva, verifica namespace/ator/escopo/token/lease ainda válido pelo relógioDB, insere retornos_modelo/mensagem/fontes e conclui consulta na mesma transação. worker_falhar_consulta_copiloto(p_id_consulta uuid,p_token uuid,p_codigo text) limita erro a enum fechado e CAS de estado/token; nenhuma mensagem final de executor vencido. Tokens de fencing nunca retornam ao browser/log/artefato.
- [ ] Handler substitui seu INSERT direto da consulta pela reserva, antes de embedding/IA. Resultado excedido HTTP429 amigável com Retry-After e CORS. Nenhuma tentativa automática ao provedor429/timeout que duplique reserva.
- [ ] Lease/fencing no JSON filtros da própria consulta, sem tabela nova: namespace copilot, token aleatório backend, expires_at definido pelo relógio PostgreSQL e deadline absoluto. Configuração operacional deste BUILD: request total45s com cancelamento de I/O e lease90s, fixada neste GATE. Toda chamada externa e persistência final exigem token correto e lease ainda válido; executor vencido não pode enviar, renovar ou concluir resultado.
- [ ] Sob os mesmos locks organização→ator, recuperar somente reservas próprias no namespace cujo lease expirou: marcar falhou com motivo LEASE_EXPIRADA preservando linha/histórico/criado_em; continuam contando taxa/custo da janela. Reserva ativa não é recuperada; renovação CAS nunca ultrapassa deadline absoluto. Nenhum delete ou reset de contador para simular recuperação.
- [ ] RED/GREEN nativo: crash após reserva semfinally, expiração por relógio controladoSQL, disputa simultânea entre recuperação/conclusão/renovação; lease ativo preservado, vencido rejeitado e uma única transição. Positivo em execução dentro do deadline não é liberado por outra instância. Após expiração a capacidade é recuperada, sem devolver quota de taxa/custo.
- [ ] Valores6/minuto,30/hora,120/hora,2/8 e45/90s originaram-se como propostas operacionais conservadoras e ficam definidos neste GATE para este BUILD HML. São decisão técnica versionada de contenção de consumo e concorrência, não parâmetros canônicos nem certificação de carga/SLA/custo financeiro. Predicados documentais também ficam definidos neste GATE: documents concluido com concluido_em, arquivo aprovado e ausência de processamento pendente/processando/falhou/cancelado. Nenhum ajuste de limite no teste para fabricarPASS.
- [ ] Limites fechados registrados no manifesto; testar fronteira temporal, concorrência, tenant B, replay e ausência de segredo no log. Não alegar orçamento financeiro exato: cota de pedidos + limites de contexto/tokens, sem preços presumidos.
- [ ] GREEN SQL/runtime e restore/backup/segurança/regressões completos antes de review final.

## Fase 3: runner HML manual e prova independente
**Arquivos:** supabase/tests/copilot_hml.mjs e .github/workflows/copilot-hml.yml.
- [ ] workflow_dispatch somente, nunca pull_request/fork/workflow_run automático. Branch main do repositório exato, tested_head SHA40 exato e live main CAS, manifeste da tarefa/fase, guard/Restore/backup verdes no mesmoSHA antes de acessar environment hml.
- [ ] Inputs: tested_head, frontend_head, restore_run_id, edge_source_sha256, edge_bundle_sha256, edge_version, deployment_receipt_comment_id, nonce único. Validar entrada estrita e recibo source-readback HML com verify_jwt=true, slug copilot-query, projeto gklhhhyosgasnyoxlrui. Ler fonte/versão Management, sem recuperar valores de Secrets.
- [ ] Secrets existentes somente environment hml e processo do runner: DATABASE_URL/AuthAdmin/publishable quando necessário. Não exportar ao browser, tool output ou artefatos. Browser recebe somente chave pública e sessões JWT sintéticas próprias em memória por SDK real.
- [ ] Duas organizações novas e identidades via Auth Admin API; nunca INSERT auth.users. Usar namespace/nonce manifesto próprio, sem tocar fixtures de outro executor ou identidades preexistentes.
- [ ] Positivo documental via fluxo oficial e processamento normal, sem forçar aprovação/worker. Fixtures negativas artificiais estritamente próprias e identificadas podem testar exclusão, nunca servem de prova positiva de worker ou fonte.
- [ ] JWT real: consulta autorizada, outro tenant, contrato fora do escopo, papel sem arquivos.consultar, sessão revogada e id_sessao de terceiro. Exigir status/código exatos e ausência de fontes/persistência em escopo alheio.
- [ ] Provar provider openai e citações existentes nas tabelas certificadas com conteúdo seguro; ausência de fonte usa fallback sem chamada externa. Falha de provedor via isolamento local/runtime, sem alterar secrets/modelo/configuraçãoHML para fabricar PASS.
- [ ] Provar flood/custo com reserva real concorrente e429; zero chamada externa após quota. CORS somente origens127.0.0.1:4173 e canonical HML autorizadas, negativos exatos, sem desligar JWT.
- [ ] Frontend em checkout separado no SHA completo aprovadoPR379 ou sucessor revisado, Bun install --frozen-lockfile e Playwright versionado. Interação real login/chat/fontes/conversa seguinte/timeout/reload e teclado. Sem interceptação/mock para converterFAILemPASS; sem secrets administrativos no browser.
- [ ] finally no harness e always no workflow: revogar próprias sessões/banir contas, remover vínculos/Master temporários, verificar jobs próprios e quarentenar artefatos imutáveis próprios. Se cleanup falhar: FAIL, relatório preservado, sem alegar ausência de efeito.
- [ ] Artefato sanitizado: HEADs, hashes, checks/runs/jobs, contagens, status/negativas, IDs sintéticos necessários à auditoria, cleanup. NuncaJWT, senha, chave, headersAuthorization, URL assinada ou conteúdo documental sensível.
- [ ] Sequência sem circularidade: implementar elegibilidade+quota → TDD/revisão/CI/Restore/backup verdes → integrar código aprovado → deployment TÉCNICO somenteHML porCLI canônico, ainda NÃO CERTIFICADO → readback exato fonte/bundle/versão/verify_jwt → runner JWT/frontend → certificação final. O bloqueio atual proíbe deploymentOpenAI antes dos controles; a prova materialHML ocorre depois desse deployment técnico delimitado. Deployment não significa certificação nem liberaçãoPROD. Este PR documental não executa deployment.

## Critérios finais e rollback
PASS exige todas fases autorizadas integradas e verificadas, sem Important/Critical aberto, prova positiva/negativa real, quotas concorrentes e cleanup. Fonte não elegível, ausência de quota ou provaHML faltante = NO-GO. Reverter consumer Edge e assinaturas novas apenas por migration nova aprovada, sem reescrever migration aplicada nem apagar evidência/histórico. Revalidar TrilhaB e contratos originais.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Marca ContaOS Brand v1.0; assets, tokens, Design System e telas certificadas preservados. Backend impacto_visual N/A por não alterar UI. Prova frontend exige1440/1280/768/390 claro/escuro, acessibilidade e estados reais; sem imagem não declararPASSvisual. GitHub/Supabase/Node diretamente, sem turnoLovable desnecessário. Menor diff, reutilizar testes/receipts válidos e preservar TDD, CI, Restore/backup, revisão independente e TesteC separado. Economia nunca substitui segurança ou prova.

## GATE aditivo: catálogo histórico e nove funções C
Motivo comprovado: history_catalog_compare.py compara todo o catálogo restaurado e só conhece deltas anteriores. As nove funções novas seriam unexpected. Nenhuma exceção por prefixo, glob worker* ou remoção de funçõesC do catálogo real é permitida.

Paths adicionais exatos para BUILD posterior: supabase/tests/history_catalog_compare.py e supabase/tests/copilot_catalog.test.mjs. Este PR somente altera manifesto/plano; nenhuma migration, guard, teste ou dado remoto implementado.

A comparação adicionará ao expected as nove identidades aprovadas abaixo e manterá todos registros actual. Consulta nativa independente ao mesmo Restore/SHA comprova assinatura completa, retorno, linguagem, owner postgres, SECURITY DEFINER, search_path vazio, md5(prosrc), ACL bruto e EXECUTE efetivo. Owner postgres mantém EXECUTE próprio sem grant option; somente seis funções public concedem EXECUTE service_role sem grant option. Três helpers privado não concedem EXECUTE a service_role, anon, authenticated ou PUBLIC. Nenhum grant a papel extra. A comparação histórica original de todas tabelas/colunas/policies/funções permanece ativa.

DDL local proposta no caminhoCLI20261108232731_c_chat_scope_quota.sql, SHA256 8057aa5f5ff82b7b36ad305f19a29a9067ce3cf3fcb8603ed32f6bfd6c2fa667. Hash é proposta rastreável, ainda sem SQL nativo GREEN e sem aprovação de deploy; correções após teste exigem atualizar recibo/hash e CI/revisão no BUILD, nunca aceitar corpo observado automaticamente como expected. Raw fencing token fica apenas na resposta service-only; filtros persistem exclusivamente digestSHA256, testado contra o texto do nonce e chave recuperável.

Teste de regressão executa a função real do guard com baseline controlada e metadados fixos: funçãoC extra, ausência/duplicação, assinatura diferente, bodyMD5 alterado, owner diferente, SECURITY/search_path/ACL/EXECUTE divergentes e função antiga alterada continuam FAIL. Execução SQL nativa no Restore do mesmoSHA confirma as nove funções contra este contrato, além do teste focal SQL já previsto; teste de fixture não substitui catálogo real. Novo teste Node integra hookRestore permitido, sem retirar suites ou provas de backup/duasinstâncias.

Identidades aprovadas propostas:
```json
[
  {
    "schema": "privado",
    "name": "copilot_versao_elegivel",
    "args": "p_versao uuid, p_org uuid, p_contrato uuid, p_data date",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "sql",
    "returns": "boolean",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": false,
    "public_exec": false,
    "body_md5": "802dccbc6b41c244ea7dd57b3719feac"
  },
  {
    "schema": "privado",
    "name": "copilot_precedente_elegivel",
    "args": "p_id uuid, p_org uuid, p_contratante uuid",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "sql",
    "returns": "boolean",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": false,
    "public_exec": false,
    "body_md5": "d2bcc6291453a42f96bfb4ffc664b7d8"
  },
  {
    "schema": "public",
    "name": "worker_buscar_fragmentos_copiloto",
    "args": "p_id_organizacao uuid, p_id_contrato uuid, p_ids_fragmentos uuid[], p_embedding extensions.vector, p_data_referencia date, p_limite integer",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "plpgsql",
    "returns": "TABLE(id uuid, id_versao_documento uuid, pagina_inicio integer, pagina_fim integer, texto text, similaridade double precision, fonte_temporal text, inicio_vigencia date, fim_vigencia date)",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": true,
    "public_exec": false,
    "body_md5": "58268b61ee1b83a0e9ac8693ebee4ed8"
  },
  {
    "schema": "public",
    "name": "worker_buscar_precedentes_copiloto",
    "args": "p_id_organizacao uuid, p_id_contratante uuid, p_id_contrato uuid, p_ids_precedentes uuid[], p_embedding extensions.vector, p_limite integer",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "plpgsql",
    "returns": "TABLE(id uuid, id_contrato_origem uuid, competencia_origem date, problema text, solucao text, desfecho text, escopo_resultado text, similaridade double precision, forca_score numeric, score_final numeric, confirmacoes integer, hierarquia_normativa integer, confianca numeric)",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": true,
    "public_exec": false,
    "body_md5": "67a23d26ebc9608da48d576d33bf6ec6"
  },
  {
    "schema": "privado",
    "name": "copilot_ator_permite",
    "args": "p_org uuid, p_contrato uuid, p_ator uuid, p_sessao uuid",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "plpgsql",
    "returns": "boolean",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": false,
    "public_exec": false,
    "body_md5": "364955d7b3eee1325d8691dde52dc3db"
  },
  {
    "schema": "public",
    "name": "worker_reservar_consulta_copiloto",
    "args": "p_id_organizacao uuid, p_id_contrato uuid, p_id_usuario uuid, p_texto text, p_filtros jsonb, p_modelo text",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "plpgsql",
    "returns": "jsonb",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": true,
    "public_exec": false,
    "body_md5": "b68f1ad83a5b68d6bd13d4782fdd1e4b"
  },
  {
    "schema": "public",
    "name": "worker_falhar_consulta_copiloto",
    "args": "p_id_consulta uuid, p_token uuid, p_codigo text",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "plpgsql",
    "returns": "boolean",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": true,
    "public_exec": false,
    "body_md5": "8a1ca3751651956c646d9d8d9a2277d9"
  },
  {
    "schema": "public",
    "name": "worker_validar_lease_copiloto",
    "args": "p_id_consulta uuid, p_token uuid",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "plpgsql",
    "returns": "boolean",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": true,
    "public_exec": false,
    "body_md5": "12a3a6349ed40ad9452473bc3c96b7d8"
  },
  {
    "schema": "public",
    "name": "worker_concluir_consulta_copiloto",
    "args": "p_id_consulta uuid, p_token uuid, p_id_sessao uuid, p_retorno jsonb, p_fontes jsonb",
    "owner": "postgres",
    "definer": true,
    "config": [
      "search_path=\"\""
    ],
    "language": "plpgsql",
    "returns": "jsonb",
    "auth_exec": false,
    "anon_exec": false,
    "service_exec": true,
    "public_exec": false,
    "body_md5": "0cfce0ca3da751f82391606a631d79a5"
  }
]
```

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: backend impacto_visual N/A, nenhumaUI/assets alterados. Ferramentas diretas e menor delta; ContextGate/ZeroDrift/Restore/backup/revisão mantidos; sem SQL remoto, segredo ouPROD.

## Ledger BUILD SQL após GATE183
RED SQL real: a50b0a16 Restore42535847920/job128899846756, COPILOT_SQL_RED_RESERVA_RPC_AUSENTE; nenhuma falha de transferência é contada comoRED. DuasfixturesdegovernançaB setupisolado26/26GREEN. TDDcatálogorealguard offline:baseline13FAIL/5PASS→18/18GREEN, sem afirmarSQLnativo. CorpoSQLcandidate atualizado após corrigir nonceSHA256/nultokenfailclosed/replayrevalidaçãosessão, hash 9015181ae955d334274a3981ab0337cf6ecf29868cbc1b3b54ef310523a33f15. Novo contrato nativoMD5 consta no manifestoBUILD e guard; proposal8057 do GATE preservada como histórico, semautoaceitarcatálogoobservado.
Ruling: worker_validar_lease_copiloto(uuid,uuid) éRPCaditiva service-only para verificação antesI/O, semrenovação; integra as9identidadesdoGATE183. Headers/rawtoken nunca persistem; filtrosguardamsóSHA256. Lease expirada não reinicia quota/histórico. Testeconcorrência usa2clientesPostgreSQL+terceiroholderda trava e reutiliza identidadeV117localprévia, semINSERTauth.users novo e semconstituirJWT HML.
