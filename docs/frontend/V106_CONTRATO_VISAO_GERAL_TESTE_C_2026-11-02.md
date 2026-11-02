# PROMPT 27 / V1-06 — Certificação frontend HML
Data: 02/11/2026 (America/Sao_Paulo).
Resultado: **TESTE OFICIAL C: 18/18 PASS**.
Frontend: `contaos9999/contaos-hml-control`.
HEAD certificado e inalterado durante C: `9c26e97e992ee6db529ba3615f2bd10f8ceefbb8`.
Base frontend: `113fb94660281d2f486d0779fc9981e3c3eaa216`.
Backend funcional certificado: `contaos9999/develop/main@28aa958f75a183052084461eae8e2782b52ca007`.
Supabase HML: `gklhhhyosgasnyoxlrui`. **PROD intocado; nenhuma promoção/publicação em produção.**

## Comportamento certificado
Rota `/contratos/:id`, somente leitura, `ssr:false`, título `Contrato — ContaOS`, robots noindex.
Resumo oficial de identificação, contratante, vigência/prazos e valores. Datas DD/MM/AAAA sem deslocamento, BRL pt-BR, nulos —; situação/criticidade somente dados oficiais.
Navegação canônica: visão geral atual; base normativa, orçamento, regras, documentos e competências indisponíveis e identificadas como Em breve, sem links quebrados/rotas placeholder/carga antecipada. Sem edição inline, mutações, upload, IA ou contagens pesadas.

Happy path: Data API SELECT por id sob RLS `contratos_select -> privado.usuario_tem_acesso_contrato(id)`. LEFT embed leve via FK composta `contratos_contratante_org_fk`; contratante invisível/nulo não oculta o contrato.
Somente depois de SELECT bem-sucedido com zero linhas: `classificar_acesso_contrato_v106({p_id_contrato:id})`.
- negado: apresentação de acesso negado 403.
- nao_encontrado: apresentação 404 idêntica para inexistente/cross-tenant mascarado.
- permitido após zero: erro de consistência, sem bypass.
- erro/inesperado: erro técnico sanitizado, nunca falso 404.
SELECT falho ou autorizado com linha: zero classificador.
UUID canônico minúsculo na chave/consulta/comparação; mesmo AbortSignal repassado a SELECT e RPC; abortado antes da classificação impede a chamada; dados tardios não invadem contrato/contexto novo.

## Escopo auditado externamente no GitHub
Exatamente sete caminhos contra a base certificada:
- `.lovable/plan/prompt-27-v1-06-contrato-visão-geral-contratos-id-2026-11-02.md`
- `src/components/contratos/VisaoGeralContrato.tsx`
- `src/lib/contratos/contratoDetalheDados.ts`
- `src/routes/contratos_.$id.tsx`
- `src/test/contratoDetalhe.test.tsx`
- `src/integrations/supabase/types.ts`: somente quatro linhas da assinatura oficial.
- `src/routeTree.gen.ts`: regeneração automática.
Nenhuma mudança em SYS/ADM/listas/NovoContrato/contratantes/shared UI/client/package/.env/backend.

## TDD, revisão e execução
Todo código frontend executado pelo Lovable conectado. Controle externo usou GitHub para inspeção, documentação e rastreabilidade.
BUILD original: RED por módulos ausentes; 23/23 focados; regressão final 322/322. Primeira regressão foi321/322 sem identificação do teste; **não foi classificada como flake conhecido**.
Revisão independente read-only do HEAD f42755a: dois findings P2 confirmados — UUID uppercase provocava loading infinito; classificador descartava AbortSignal.
Correção mínima consolidada no Lovable: RED exit1, quatro falhas comportamentais e25 aprovados antes da produção; GREEN32/32, suíte331/331; somente helper/componente/teste V1-06 alterados. Correções verificadas pelo diff e testes, preservando a proteção contra resposta de outro ID.
Teste C separado, sem auto-fix, no HEAD certificado: focused32/32, suíte15 arquivos331/331, tsgo/build exit0. Quatro larguras1440/1280/768/390, cenários de sucesso/403/404/erro/retry/UUID uppercase/troca de contrato.

## Rastreabilidade PRD/atômicos
- Regular PROMPT27 / telaV1-06: certificado neste escopo.
- Atômicos001/V1-CON-001,002/V1-CON-002,004/V1-CON-004,005/V1-CON-005: associação ao conjunto V1-06/07/08/10; este delta cobre resumo/vigência/navegação. Upload, extração IA e fontes completas permanecem dependentes das telas correlatas, **não declarados integralmente concluídos por este certificado**.
- NFR-005/089 e NFR-009/093: preservados pela leitura limitada e ausência de processos/cargas pesadas.
- NFR-007/091 e NFR-008/092: sem nova implementação; não há mutação que exija concorrência/idempotência neste delta.
- Demais atômicos: nenhuma conclusão artificial de cobertura.
Plano aprovado: [plano versionado](../superpowers/plans/2026-11-02-v106-contrato-visao-geral.md).
Prompt exato, aprovação, diagnóstico, correções, decisões e evidências: [issue23](https://github.com/contaos9999/develop/issues/23).

## Governança documental
Antes do BUILD houve bloqueio real por fingerprint desatualizado em00/06/07. Usuário autorizou correção exclusiva de hashes e completude da tarefa.
Commit1eb92b19 aplicou os quatro hashes do manifesto e tarefa; CI inicialmente falhou em Zero-Drift por omissão do caminho AI_CONTEXT_MANIFEST.md no allowed_paths. Falha reproduzida e corrigida estritamente na declaração do caminho autorizado, commitc4f5b1c. Context Gate e Zero-Drift passaram; CI41522184949 e41522509205 success.
Fingerprint vigente: `5a6683274ed17a7ece4c1fc61626a2f0d0b065376a10b46845adcf2e74e57fcd`,23 documentos. Nenhum guard foi afrouxado; nenhum documento canônico de regra foi alterado.

## Evidência do Teste C no runtime Lovable
Turno: `umsg_01m6f0wjhjebebznv9g11d2082`, threadmain. Ferramenta oficial `security--run_security_scan` invocada, relatório0 Critical/0 High; aviso informativo global preexistente auth_leaked_password_protection.
Abaixo está o relatório retornado pelo runtime, sem as chamadas intermediárias:

Now the browser test with screenshots, retry, keyboard, and target sizes.






















**PROMPT27 / V1-06 — TESTE OFICIAL C: 18/18 PASS — CERTIFICADO.** Nenhum arquivo foi editado.

**HEAD:** `9c26e97e992ee6db529ba3615f2bd10f8ceefbb8` no início e no fim. Git limpo, 0 arquivos não rastreados.

| # | Gate | Status | Evidência |
|---|---|---|---|
| 1 | HEAD/status inicial | PASS | HEAD exato, porcelain com 0 linhas, capturado antes de tudo |
| 2 | Zero-Drift | PASS | Diff desde `113fb946` só nos 7 arquivos autorizados: plano arquivado, componente, helper, rota, teste, `types.ts` (+4) e routeTree. Nada de SYS/ADM/listas/NovoContrato/compartilhados/package/.env/backend |
| 3 | Tipagem/RPC | PASS | `types.ts` muda só `classificar_acesso_contrato_v106` (Args `{p_id_contrato:string}`, Returns `string`). Chamada direta, zero casts, nenhum cliente paralelo |
| 4 | Rota/metadados | PASS | `ssr:false`, title "Contrato — ContaOS", robots noindex. No browser: 1 H1 e 4 H2. UUID `AAAA…` maiúsculo renderizou o contrato devolvido em minúsculas, sem carregamento infinito, nas 4 larguras |
| 5 | Sessão/contexto | PASS | Testes: sem sessão → /login; erro do getUser → retry sem signOut; sem preferência → /selecionar-organizacao com 0 SELECT; UUID inválido → não encontrado com 0 SELECT/RPC |
| 6 | SELECT | PASS | Colunas exatas, eq id, maybeSingle, abortSignal, LEFT embed via `contratos_contratante_org_fk`, sem `!inner`, sem filtro local por organização, sem configuração nem conta bancária |
| 7 | Sucesso/leitor/Master | PASS | Testes para leitor e Master: resumo renderizado, só a tabela `contratos` consultada, 0 classificador. Contratante null mostra "—"; status desconhecido aparece literal |
| 8 | Zero linhas → classificador | PASS | Uma RPC exata. Negado → 403. Não encontrado → 404, mesma tela para inexistente e cross-tenant |
| 9 | Inconsistência/erro | PASS | "permitido" → erro de consistência; inesperado, erro ou rede → erro técnico, nunca 404. Browser: sem loop, retry só ao clicar |
| 10 | SELECT falho | PASS | 42501/PGRST301/401/403 → negado; 500/rede → erro + retry; 0 classificador; detalhes técnicos não aparecem |
| 11 | Cancelamento | PASS | Testes: o mesmo signal chega ao SELECT e à RPC; signal abortado antes da RPC impede a chamada; unmount ou troca de id abortam |
| 12 | Isolamento/dados antigos | PASS | Chave com uid/org/id canônico, sem placeholderData. Troca A→B durante SELECT e durante RPC pendente, e organização A→B→A com remount, sem dados antigos (testes + browser) |
| 13 | Resumo/formatação | PASS | Datas DD/MM/AAAA sem deslocamento, R$ 1.000,00, nulos "—", nenhum cálculo de portão |
| 14 | Navegação/carga | PASS | Cinco seções "Em breve" com aria-disabled e 0 links. No browser, nenhuma requisição além de auth/contratos/classificador |
| 15 | Browser responsivo | PASS | 1440/1280/768/390 sem overflow nos cenários UUID maiúsculo, 403, 404, erro+retry e troca. Screenshots conferidas visualmente |
| 16 | Acessibilidade | PASS | H1 único, 0 alvos menores que 44px, foco por teclado com `:focus-visible` ativo (anel 1px do botão padrão), mensagens role alert/status com texto, sem tooltips |
| 17 | Qualidade | PASS | Focado 32/32 exit 0; suíte 15 arquivos, 331/331, exit 0; `npx tsgo --noEmit` exit 0; build em `/tmp` exit 0 |
| 18 | Segurança/somente leitura | PASS | Security Scan oficial: 0 Critical/High, só o aviso informativo global `auth_leaked_password_protection`. Varredura dos 3 arquivos de produção: única RPC é o classificador, sem mutações nem secrets. Network sem escritas no HML. Console só com os 500 simulados de propósito |

**Logs:** `/tmp/v106c-{focused,suite,tsgo,build}.log`, browser em `/tmp/browser/v106c/` (scripts e screenshots).

**Limitações**
- O browser usou respostas simuladas e não prova a RLS real. A prova de RLS real é a reutilizada do backend (V106 10/10 e BOLA 7/7).
- O cancelamento da requisição na rede não aparece no Playwright; a prova vem dos testes de unidade.
- O anel de foco é o padrão do botão compartilhado (1px), visível mas discreto sobre o cabeçalho escuro. Não foi alterado.

## Limites da certificação
- Browser CONTROLADO com respostas simuladas prova UI/queries; não substitui prova real de RLS. Autoridade real reutilizada da certificação backend V10610/10 e BOLA7/7 com ROLLBACK, documentada em [backendV106](../backend/V106_CONTRATO_VISAO_GERAL_2026-11-02.md).
- Cancelamento de rede não foi observado pelo Playwright; testes de unidade comprovam propagação/aborto do mesmo signal, com builderRPC realista.
- Foco padrão compartilhado1px visível porém discreto no cabeçalho, preservado sem alterar shared UI.
- Falha histórica321/322 não identificada permanece registrada; rodadas completas posteriores331/331, inclusive o Teste C fresco, passaram com logs completos.
- Certificado restrito a V1-06 em HML, não representa certificação de todo o frontend96/96 nem autorização para PROD.
