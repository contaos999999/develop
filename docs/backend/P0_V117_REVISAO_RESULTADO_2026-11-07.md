Conferência do seletor pós-gravação antes da execução: ResultadoCard exibe o prefixo literal `Justificativa: `. Expectativa de atualização ajustada a esse texto real, mantendo valor integral e conferência independente no banco; sem alteração do produto.

## Causa concreta da sonda PR106 e correção mínima
Run42371378909 public-probe FAIL: `toHaveAttribute can be only used with Locator object`. Artifact13573678201 SHA256750f172a23ac0b2151734cd4ca1b7cac022ec8a6eb3c704d08a1c39e1af22666. Asserções foram carregadas de @playwright/test1.58.2 do frontend, mas locators vieram do executor isolado Playwright1.64.1. O binding inicial false tornou-se verdadeiro e o toggle real executou; falha concreta é incompatibilidade do harness, não prova de erro de Auth ou produto. Os dois primeiros timeouts de login continuam históricos, sem atribuição retroativa de causa não demonstrada.

Correção: carregar chromium e expect pelo mesmo export público playwright/test na instalação isolada, confirmar versão exata1.64.1 e registrá-la. Mantém dependências/lock frontend intactos. Separar grupos de concorrência PR/main conforme revisão para impedir que probe de PR substitua prova privada pending. Novo CI precisa comprovar probe PASS e guard/restore/backup, depois execução privada real.

A sonda pública também roda no PR, em job sem environment HML, sem secrets e sem fixtures, com fonte frontend exata e relatório explicitamente público. Serve ao diagnóstico rápido antes do merge; não substitui guard/restore/backup, não autoriza merge com FAILURE e não é Teste C privado. Execução HML continua separada somente após merge e restore da main exata.

## Probe público: falha anterior à criação de identidades
Run42370957041/job128398786661, source730b9756, frontend508c5ff: preflight público FAIL em CLIENT_INTERACTIVITY, initial_form_bound=false, em7segundos, sem erros JS no listener e sem flags conhecidas. Não foi timeout de30s nem execução Auth; nenhuma nova fixture criada. Artifact13573767113 SHA25607c80b070a9a0b0bbe50f2211b396365d195b690de0e4c8e5fe383d3199b129f. O erro concreto do driver ainda não foi registrado pela lista fechada de flags; não corrigir produto por hipótese.

Delta mínimo de diagnóstico: somente no modo PUBLIC_INTERACTIVITY_PROBE, antes de credenciais/fixture, registrar classe e primeira linha do erro com URLs, e-mails, caminhos privados e sequências longas redigidos; teste local de redator. Modo privado conserva apenas flags, sem mensagem. Probe tem env sem secrets e não é PASS privado. Sem mudança frontend/negócio/DDL/deploy/PROD.

## Segunda execução privada: estágio localizado, nenhuma autenticação UI comprovada
Run42370269292/job128396758916, backend9a66c63, frontend508c5ff: FAIL em LOGIN_SUBMIT, timeout waitForResponse. Inputs existem; screenshot após limpeza mostra tela de login sem estado de envio. Nenhuma assertion privada ou chamada Auth UI confirmada.38HTTP anteriores e quarentena8 novamente PASS; cleanup de processo corrigido não falhou nesta execução. Artifact13572967806 SHA256933a911355b395fcb0b3f155e53304950ed8c37eee177ceb04f4a106f54a8649. Não atribuir ainda a causa à hidratação, rede ou produto.

Próximo delta de diagnóstico: preflight público sem credenciais/fixtures antes da criação Auth; esperar binding do formulário e testar alternância acessível da senha. Reportar estágio e erros JS por classificação fixa/export identifier, sem mensagem bruta. Probe em arquivo/mode próprios, jamais conta como PASS privado. Se preflight falhar, não criar novas contas. Browser/Vite por allowlist no próprio Node também. Frontend e regras não são alterados por hipótese.

Revisão focal adicional do FIX104 encontrou que save/browser.close poderiam impedir stopServer. Reproduzido RED real com close rejeitado e grupo contendo neto que ignora TERM. Corrigido finally interno obrigatório, timeout de fechamento do browser e espera do processo após KILL. GREEN protocolo confirma processo/neto encerrados mesmo com close rejeitado. Não tratar execução antiga como evidência dessa correção; novo CI requerido.

## Primeira execução privada: FAIL preservado, quarentena PASS
Run42369440263, HEAD27fe28a1362df5a52182c75eafcf74f046e12a5c, job128394319425:38 assertions HTTP anteriores PASS, aceitação privada FAIL antes do primeiro check de login. Relatório sanitizado não tem assertions privadas nem capturas; não inventar causa da falha de login. Artifact13572468983 SHA256da26705cec856869de5f37f3608c068c997955967587bcec73c218c317dae1c6. Quarentena própria8usuários verificada no finally e always; sem nova aprovação ou exposição de credenciais.

Falha adicional comprovada: rm do frontend retornou diretório node_modules não vazio porque npm/Vite deixou processo filho ativo. Correção em validação: grupo próprio de processos, TERM/espera limitada/KILL e teste real sem rede confirma fim do filho. Diagnóstico passa a registrar apenas estágio enumerado e flags fixas de erro; screenshot de falha somente após esvaziar inputs. Nunca publicar stderr bruto, tokens ou storageState. Após CI/merge, reexecutar prova real pelo runner canônico sem deploy. Roteamento de listas fora de tarefa seguePLAN103 separado, sem integrar antes desta correção.

## BUILD do harness privado em validação
PLAN100 integrado6e53e57; GATE101 integrado937bd9b após guard verde em4c5b6fa. Harness Playwright novo em RED por módulo inexistente e GREEN no teste local do protocolo; não equivale a execução HML. Quarentena fault-injection local PASS. Revisão independente encontrou herança de segredos pelo subprocesso Node/Chromium: reproduzido teste negativo antes da função de allowlist; corrigido por ambiente restrito no Python, guarda fail-closed no Node e env explícito Chromium. Ambiente desconhecido fica excluído por padrão.

Workflow privado aguarda restore/backup/guard backend e frontend pin508c5ff471b4cb453961c71415d3ac62fbb0d245 integrado com todos checks. Sem deploy. Workflow anterior de deploy passa a exigir fase BUILD_EM_VALIDACAO; a fase de prova privada não reimplanta migration aplicada. Hook opt-in permanece inerte nos38 testes JWT anteriores sem CONTAOS_V117_BROWSER=1. Nova evidência documental é metadado sintético aprovado, não upload físico. Prova real, screenshots e inspeção visual ainda pendentes.

# Atualização comprovada em07/11/2026

O registro histórico abaixo foi superado neste ponto: BUILD99 integrado em744dee8636c164415774e413e76883e08dffbc09; deploy canônico42362617182 SUCCESS; JWT real42362609674 tentativa3, job128386155328 SUCCESS,38 assertions e quarentena própria verificada. Artifact ZIP SHA256 e082a3669c2e9adf34674ad9e74134bcb9ef46d20d88453887925fa3af92e43d. A chave Auth Admin foi configurada pelo titular e funcionou; não há bloqueio atual por ausência dela.

Frontend PLAN269 e GATE270 integrados; BUILD271 HEAD e4275ee62593fa6cce49d0b6a1417a37f389ae08 publicado,1128 testes locais. CI/merge e teste privado ainda pendentes neste registro. Próxima etapa: PLAN de prova privada com fixtures oficiais, sem repetir login pessoal cancelado, deploy ou DDL. V1 não certificada; CRUD global não concluído.

---

# Revisão humana V1-17: registro de execução

Estado: BUILD em validação. Nenhum deploy HML desta migration comprovado neste commit. V1 não certificada e CRUD global não concluído.

## Contexto e gates
PLAN backend #98 integrado em c1e138d7a60641e1059079e83649bc3bb7f31599, HEADf0f40b3ed338583931fab8800e8935ee65ba2138 e guard run42361197685 SUCCESS antes de BUILD. Base anterior4fec09bf. Frontend funcional permanece d8849c28877d97e5503f33c0fc9329b642ae9157, PR265/266 integrados; não repetir essa correção.

Migration nova criada pela CLI Supabase2.122.0:20261107094443_p0_v117_revisao_humana.sql. Nenhuma migration aplicada alterada. Novas RPCs obter_contexto_revisao_v117 e registrar_revisao_requisito_v117. Assinatura antiga preservada, mas fecha bypass sem CAS; nenhuma chamada ativa encontrada. Resultado anterior, UNIQUE(execução,requisito), workers e portões mantidos. Revisão gera nova execução incremental humana, com base cujo hash ainda é atual, resultado, evidências, parecer substituído, auditoria e recibo atômicos.

## TDD e diagnóstico
- RED HEAD375c908d62757ae9f4f1921244041d832738eac8, run42361330041, job128370168892: suites anteriores passam; novo teste falha em registrar_revisao_requisito_v117 inexistente. Não integrou RED.
- Primeiro BUILDab97deb, run42361619257: restore/migrations/catalog/suites anteriores passam; teste tinha expectativa incorreta para ator11, que era MASTER no setup reutilizado. Corrigido teste para ator12 sem vínculo e acrescentado positivo MASTER. Não afrouxou autorização.
- HEADf677b3b179139b04fc75152e8e049f6197195f59, run42361821602: logs job128371624304 comprovam V117_REVISAO_ISOLATED_PASS e V117_REVISAO_CONCURRENCY_PASS, incluindo preservação, replay, CAS, evidência válida, parecer, base obsoleta com2requisitos, revogação durante espera e reanálise concorrente. Checks finais do delta posterior ainda requeridos.
- Revisão independente encontrou ambiguidade no hash da base; explicitada igualdade base/servidor/CAS. Identificou direção excluída na leitura antiga, apesar de escrita legada autorizada: nova leitura usa o mesmo RBAC/tenant e lista da escrita legada, com prova de direção. Sem herança especializada nova ao MASTER.
- Revisão das fixtures encontrou criação Auth com resposta perdida e janela commit/seeded. Intenção agora persistida antes da API; recuperação de ID restrita ao próprio e-mail+nonce; organização desativada pelo UUID independentemente da flag. --self-test sem rede PASS local e em revisão independente. Se limpeza não puder ser comprovada, FAIL.
- Último delta adiciona evidência existente de outro tenant negada, tratamento de deadlock409 e recuperação de fixtures no restore. Novo CI completo obrigatório, sem presumir verde anterior.

## Próximas ações na ordem
1. Conferir guard, restore integral, backup sintético e revisão do SHA final do PR99; integrar somente com checks exigidos SUCCESS.
2. Workflow p0-v117-revisao-hml.yml aguarda restore main exato, exige SHA/hash/manifesto, despacha CLI canônica p0-hml-migration-version-parity.yml com exatamente uma migration pendente. Sem SQL solto/histórico manual/PROD.
3. Job real-jwt exige credencial Auth Admin HML já configurada em CONTAOS_HML_AUTH_ADMIN_KEY ou aliases existentes CONTAOS_HML_SERVICE_ROLE_KEY/SUPABASE_SERVICE_ROLE_KEY. Preflight sem chave gera CONFIG_BLOCKED_AUTH_ADMIN_KEY_MISSING e não cria fixture. Não alegar ausência antes do resultado. Nunca INSERT auth.users em HML; contas somente via API administrativa e login GoTrue real. Segredos não são publicados.
4. Conferir HTTP/JWT, múltiplas conexões e relatório sanitizado; quarentena de contas próprias, vínculos/MASTER desativados, sessões revogadas e organização sintética inativa. Falha não vira PASS. Testes isolados não são JWT real.
5. Só depois backend funcional/JWT comprovados: PLAN frontend, reancoragem das fontes canônicas e integração de revisão no drawer V117, preservando types8ea7750b e ações existentes. UI deve mostrar conflito/resultado incerto e permitir somente replay explícito da mesma intenção. Prova privada requer sessão autorizada, não repetir autenticação cancelada por iniciativa própria.
6. Atualizar checkpoint oficial frontend e issue166 com HEAD/PR/CI/deploy/provas/impedimentos; continuar V1 sem certificar por presunção.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual N/A: backend e testes apenas. Marca e frontend preservados. Delta limitado ao plano e manifesto; sem RLS/Edge/configuração Auth/PROD ou dependência de produto nova. API Auth administrativa limitada às fixtures próprias autorizadas. Ferramentas diretas e evidências reaproveitadas, sem reduzir testes/revisão/gates. Identidade visual N/A backend; Zero-Drift condicionado ao CI final; economia conforme.
