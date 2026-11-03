# Auditoria retrospectiva de premissas, prompts e evidências — ContaOS 4.1

**Data da auditoria:** 03/11/2026 (Brasília)  
**Objetivo:** verificar a execução REAL dos prompts regulares e atômicos em relação a PRD, Premissas, Arquitetura, BRAND-01, Zero-Drift, segurança, economia de créditos, TDD, Teste C e rastreabilidade.  
**Natureza:** auditoria documental, de código e de estado HML, SEM edição de código, Auth, PROD ou migrations.  
**Conclusão:** **NÃO É POSSÍVEL CERTIFICAR 100% DE CONFORMIDADE TRANSVERSAL/DE TODO O PROJETO.** Existem pendências comprovadas e limites de prova, embora haja muitos certificados de escopos locais.

## 1. Fonte oficial e universo

- Pasta original verificada dentro do ZIP mestre: `06_PROMPTS_COPIAR_COLAR/`.
- Manual regular: `Manual_Mestre_Prompts_4_1_100_PRD.docx`, SHA-256 `8a15d96568d021ac86fdd45e79038e2cb969d69c12b2edb84f012a6129b8940e`, IDs **00–99 = 100/100**.
- Caderno atômico: `Caderno_97_Prompts_Atomicos_000_096_PRD_BRAND_v1_1.docx`, SHA-256 `d9faaae47de4b697b18ad7fb71e4738384514936813cd5b18779f4cb8aed83b8`, IDs **000–096 = 97/97**; 000 é BRAND-01 e 001–096 correspondem aos 96 requisitos PRD/NFR, na ordem canônica 08A–08D.
- Backend `contaos9999/develop`; frontend `contaos9999/contaos-hml-control`; Supabase HML `gklhhhyosgasnyoxlrui`; Lovable projeto `b113dd59-6caf-4c92-8302-457a037a0c6f`.
- Foram consultados **360 registros** do histórico do projeto Lovable (162 mensagens do papel usuário) e os arquivos de certificação dos repositórios, commits e workflows CI.
- Evidência de execução no Lovable: prompt regular **00** e **16–37**, total 23 blocos regulares com atividade de implementação; **38** tem PLAN aprovado, sem BUILD. Os regulares **01–15** possuem certificação agregada de backend, mas não foram encontrados logs individuais de PLAN/BUILD/TEST na conversa Lovable; **39–99** não possuem execução frontend encontrada e não são marcados como concluídos.
- O PROMPT ATÔMICO **000 / BRAND-01** foi implementado, com teste de assets. Os **001–096** têm certificação **agregada de backend** de 96/96 requisitos. Isso NÃO equivale a 96 execuções individuais de PLAN → BUILD → TESTE no Lovable nem à conclusão frontend dos cinco módulos.

## 2. Veredito por prompt regular: 00–38

Legenda: **CERTIFICADO NO ESCOPO** significa validação da entrega específica, não de TODAS as premissas transversais; **RESSALVA** indica limite/falha historicamente registrada; **PROVA AGREGADA** indica que a certificação de backend não demonstra o rito individual do prompt.

| ID | Etapa do manual | Estado provado | Observação ou limite |
|---|---|---|---|
| 00 | Constituição e reancoragem | **EXECUTADO COM DESVIO** | Instruções permanentes atuais do Lovable ainda dizem 96 atômicos; não incluem expressamente BRAND-01/000 e a política universal de economia. |
| 01 | Fundação PostgreSQL e extensões | **BACKEND: PROVA AGREGADA** | Fundação coberta pelo certificado HML e restore; PLAN/BUILD/TEST individual não comprovado. |
| 02 | Identidade, organizações e vínculos | **BACKEND: PROVA AGREGADA** | RLS, tenant e Auth abrangidos por certificação; protocolo completo individual não demonstrado. |
| 03 | Contratantes e contratos 1.0 | **BACKEND: PROVA AGREGADA** | Tabelas/RLS verificadas e recursos cobertos; testes por prompt não segregados. |
| 04 | Base normativa, orçamento e listas 1.0 | **BACKEND: PROVA AGREGADA** | Backend inicial certificado; lacunas V107/V108 foram corrigidas depois, sem provar execução autônoma completa do regular 04. |
| 05 | Storage e documentos 1.0 | **BACKEND: PROVA AGREGADA** | Armazenamento privado, versões e URLs assinadas em certificados; E2E frontend posterior é prova separada. |
| 06 | Competências e análise 1.0 | **BACKEND: PROVA AGREGADA** | Portão/análise/competências cobertos no HML; evoluções V115/116 vieram posteriormente. |
| 07 | Portão, aprovação e apresentação 1.0 | **BACKEND: PROVA AGREGADA** | Cenários 99/100, aprovação humana, hash e revalidação certificados; execução individual do regular não comprovada. |
| 08 | Histórico e precedentes 1.0 | **BACKEND: PROVA AGREGADA** | Rastreabilidade/precedentes em matriz 96/96, frontend V1-21/V1-22 não implementado. |
| 09 | Queues, Cron e Edge Functions | **BACKEND: PROVA AGREGADA** | Workers/filas e autenticação certificados em HML; testes de frontend não se aplicam. |
| 10 | ContaOS 2.0 – Diligências | **BACKEND: PROVA AGREGADA** | Backend 2.0 incluído no escopo inicial, telas V2 ainda não implementadas. |
| 11 | ContaOS 3.0 – Financeiro preventivo | **BACKEND: PROVA AGREGADA** | Backend 3.0 incluído no escopo inicial, telas V3 ainda não implementadas. |
| 12 | ContaOS 4.0 – Inteligência histórica | **BACKEND: PROVA AGREGADA** | Backend 4.0 incluído no escopo inicial, telas V4 ainda não implementadas. |
| 13 | ContaOS 5.0 – Conformidade | **BACKEND: PROVA AGREGADA** | Backend 5.0 incluído no escopo inicial, telas V5 ainda não implementadas. |
| 14 | ContaOS 5.0 – API e webhooks | **BACKEND: PROVA AGREGADA** | API/webhooks e hardening presentes no HML; testes por prompt regular individual não provados. |
| 15 | Hardening e testes do backend | **BACKEND: CERTIFICADO NO ESCOPO HISTÓRICO** | Certificados RLS, restore, cargas e 96/96; advisors atuais exigem avaliação contínua, não equivalem a GO/NO-GO final. |
| 16 | SYS-01 – Login | **TESTE OFICIAL PASS NO ESCOPO** | Lovable reportou 12/12, inclusive sessão real e quatro larguras; root global ainda contém inglês. |
| 17 | SYS-02 – Esqueci a senha | **TESTE OFICIAL PASS COM RESSALVA** | Teste final registrado e 21/21 automatizados; configuração externa Auth não foi totalmente comprovada. |
| 18 | SYS-03 – Redefinir senha | **E2E REAL NÃO COMPROVADO** | Pedido real de recuperação retornou HTTP 200, mas não houve prova do fluxo completo de link, redefinição e novo login. |
| 19 | SYS-04 – Selecionar organização | **TESTE OFICIAL PASS NO ESCOPO** | Rodada final posterior à correção do FAIL registrada no Lovable. |
| 20 | SYS-05 – Dashboard | **TESTE OFICIAL PASS NO ESCOPO** | Backend RPC certificado e Teste C reaplicado após correção 403. |
| 21 | ADM-01 – Usuários e vínculos | **TESTE OFICIAL PASS NO ESCOPO** | Várias correções e última rodada do Teste C registradas; segurança do backend validada em PRs. |
| 22 | V1-01 – Contratantes | **TESTE OFICIAL PASS COM RESSALVA** | Teste C final 18/18, browser controlado; o próprio registro anotou html lang=en e não substitui RLS real. |
| 23 | V1-02 – Novo contratante | **TESTE OFICIAL PASS COM RESSALVA** | Teste C com 208/208; browser simulado e build provado por equivalência de SHA, não sessão HML real. |
| 24 | V1-03 – Editar contratante | **CERTIFICADO NO ESCOPO** | Documento de certificação Teste C 18/18, 238/238, TypeScript/build, concorrência backend. |
| 25 | V1-04 – Contratos | **CERTIFICADO NO ESCOPO** | Documento de certificação e teste C final registrado. |
| 26 | V1-05 – Novo contrato | **TESTE OFICIAL PASS NO ESCOPO** | Teste C final registrado; backend HML 11/11 com rollback. |
| 27 | V1-06 – Contrato visão geral | **CERTIFICADO NO ESCOPO** | Teste C 18/18, 331/331 e CI; limite documentado de browser com respostas simuladas. |
| 28 | V1-07 – Base normativa | **CERTIFICADO COM RESSALVA** | Backend normativo corrigido, Teste C 18/18 e registro final; observar caminho de upload resumível declarado indisponível quando sem contrato técnico. |
| 29 | V1-08 – Orçamento | **CERTIFICADO COM RESSALVA** | Teste funcional e correção posterior de lint; lint global mantinha dívida preexistente de 8.962 erros, sem novo Teste C após a última formatação. |
| 30 | V1-09 – Listas/Regras | **CERTIFICADO COM RESSALVA** | Teste C com 16 grupos PASS, browser interceptado; Security Scan no SHA fixado limitado e lint global preexistente não saneado. |
| 31 | V1-10 – Central de documentos | **CERTIFICADO NO ESCOPO** | Certificação documental Teste C PASS; backend/storage privado e reuso de helpers. |
| 32 | V1-11 – Detalhe/versões documento | **TESTE C PASS NO ESCOPO** | Lovable registra Teste C final e implementação; ausência de certificado separado do develop não prova auditoria transversal completa. |
| 33 | V1-12 – Competências | **CERTIFICADO NO ESCOPO** | Documento Teste C e CI, regressão serial 520/520; flake/timeout paralelo registrado. |
| 34 | V1-13 – Nova competência | **CERTIFICADO NO ESCOPO** | Documento Teste C e CI, 544/544; sem prova visual HML real em todos estados. |
| 35 | V1-14 – Visão geral competência | **CERTIFICADO COM RESSALVA** | Teste C e CI; cenários autenticados no navegador controlados por fixtures. |
| 36 | V1-15 – Documentos competência | **CERTIFICADO COM RESSALVA** | Teste C final no SHA imutável, 645/645; 8 combinações visuais no cenário UUID inválido, sem E2E de upload com sessão real. |
| 37 | V1-16 – Análise competência | **CERTIFICADO COM RESSALVA** | Teste C final SHA d4b9b77, 739/739; visual autenticado via mocks; latest main altera types.ts (+265 linhas). |
| 38 | V1-17 – Detalhe do requisito | **SOMENTE PLAN FRONTEND** | Backend HML certificado e plano aprovado, mas nenhuma implementação funcional do drawer presente no HEAD de main. |

**Não iniciados:** prompts **39–99** (61 etapas), abrangendo V1-18 em diante, etapas V2–V5, auditorias transversais 67–74 e 90–99 e GO/NO-GO de produção. Não declarar 100% do sistema.

## 3. Divergências e riscos encontrados

| Prioridade | Achado | Prova | Condição para PASS |
|---|---|---|---|
| P0 | **Drift de types.ts na main atual do frontend:** `src/integrations/supabase/types.ts` possui blob `37092ba09f97b9fe63d401b8ff4b5475bbc09ed9`, diferente do certificado `8ea7750b75fd9d76b29c36ce7613392e3ab65e19`. Comparação da main `67948df44587b1fd076ef36e724ce2a6dff8c2e7` contra SHA auditado V1-16 `d4b9b77dafa7ff6ca7644a99fee737bfed590a1e`: **+265 linhas**, além do arquivamento do PLAN. | GitHub compare_commits e fetch_file read-only | Restaurar blob certificado em BUILD específico aprovado, revalidar diff completo e bloquear regeneração via CI do frontend. Não restaurar silenciosamente no Teste C. |
| P0 | **Zero-Drift CI não é permanente no repositório frontend.** A `main` de `contaos-hml-control` não possui arquivos `.github/workflows/`; os 7 runs existentes são verificações históricas isoladas. | Árvore git main frontend; lista Actions | Implantar workflow obrigatório no repo frontend com verificação de SHA, arquivos proibidos, testes regressivos, BRAND-01, texto PT-BR e rastreabilidade por prompt. Validar branch protection aplicável. |
| P0 | **Português do Brasil no root:** `src/routes/__root.tsx` permanece com `<html lang="en">` na linha 116 e contém textos em inglês na página 404 e no erro global (ex.: `Page not found`, `Go home`, `Try again`). | Código atual GitHub `src/routes/__root.tsx` | Correção localizada para `pt-BR`, mensagens amigáveis em português, regressão 404/500/SSR e foco; sem modificar regra de negócio. |
| P1 | **Project Knowledge do Lovable desatualizado:** ainda lista 96 atômicos `001–096` e não explicita novo 000/BRAND-01 no conjunto total nem política universal de economia de créditos/validação visual. | Leitura direta de `get_project_knowledge` | Atualizar instruções permanentes em conformidade com `07_ZERO_DRIFT...` seção 11 e `12_PROMPTS...` seção 9, verificando persistência; não confundir com mero texto de um prompt isolado. |
| P1 | **BRAND-01 não cobre todas as telas posteriores:** `src/test/brand.test.tsx` testa 13 arquivos/telas até V1-07, mas não inclui todas as telas V1-08 a V1-16. Os certificados V1-15/V1-16 documentam visual nas 8 combinações do estado de UUID inválido, não todos os estados autenticados. | Código brand.test.tsx e certificados V115/V116 | Expandir testes de marca e matriz visual de 1440/1280/768/390 x claro/escuro para todas as telas/states alterados e coletar prova autenticada controlada com segurança. |
| P1 | **SYS-03 / regular 18 com E2E real não concluído:** HML respondeu 200 ao envio de recuperação, mas não houve prova de acesso ao link, nova senha e login posterior. | Mensagem final do Lovable no Teste E2E 18 | Executar fluxo real com o titular da conta, sem expor token, e registrar resultado final de sucesso/negação. |
| P1 | **Atômicos 001–096 não têm prova individual de ciclo PLAN/BUILD/TEST.** O backend 96/96 PASS comprova outra camada e não atesta todo o frontend. | Cadernos originais, 360 mensagens Lovable e certificados HML | Rastrear, testar e fechar os atômicos aplicáveis a cada regular de forma explícita. Reutilizar provas backend válidas, sem fazer 96 Builds artificiais. |
| P1 | **Crosswalk incompleto semanticamente:** `docs/prompts/PROMPT_TRACKS_4_1.json` tem contagem 100/97 e associação estrutural de 66 telas, mas não tem auditoria semântica exaustiva de 100 regulares versus 97 atômicos e todos os NFR transversais. O CI novo verifica catálogo e tarefa corrente, não conteúdo literal de cada prompt executado. | JSON e `scripts/prompt-crosswalk-gate.mjs` | Completar mapeamento semântico por tarefa, critérios de exclusão e testes; nunca marcar full_crosswalk_verified sem todas as evidências. |
| P1 | **Prompt 38:** backend V117 certificado e PLAN Lovable aprovado, porém não houve BUILD do drawer no código frontend atual. | GitHub tree e último turno do Lovable | BUILD autorizado dentro do escopo, RED→GREEN, novo SHA candidato, Teste C isolado, autenticação real quando apropriada e BRAND. |
| P2 | **Dívida técnica global de lint:** no momento do Prompt 29, ESLint global registrava 8.962 erros/9 avisos preexistentes; os erros novos V1-08 foram saneados e testes passaram, mas não há prova de lint global limpo. | Registro final da remediação Prompt 29 | Abrir correção específica da baseline; não imputar todos os avisos à feature nem alegar lint global PASS. |
| P2 | **Economia Lovable não comprovada universalmente:** alguns prompts registram créditos (ex. regular 24), muitos usam GitHub/Supabase externos; inexiste controle individual completo demonstrando aplicação/eficiência da seção obrigatória em TODOS os prompts anteriores à regra universal. | Logs Lovable, documentação Zero-Drift mais recente e certificados disponíveis | Exigir em cada PLAN/BUILD/TEST: evidências utilizadas, razão para novo turno, delta mínimo e consumo medido quando informado; não inventar economia de créditos. |
| P2 | **Avisos atuais Supabase:** 6 RPCs authenticated SECURITY DEFINER exigem revisão consciente do seu modelo de autorização; proteção de senhas vazadas permanece desativada (WARN). Advisor de performance reporta 86 FKs sem índice cobridor (INFO). Esses avisos não são, por si só, prova de exploração nem autorizam mudança automática. | Supabase Advisor consultado em 03/11/2026 | Revisão de risco e mitigação justificada/aceita; planejar índices por plano de consulta e workload; configurar proteção de senhas conforme política da conta e validação de usuário. |

## 4. Evidências positivas verificadas

- Certificação backend inicial: `docs/CERTIFICACAO_BACKEND_HML_4_1.md`, `docs/MATRIZ_COBERTURA_96.md`. Afirma 84/84 funcionais + 12/12 NFR sob testes do HML, não frontend universal; histórico restaurado.
- Leitura direta do HML nesta auditoria: **117 tabelas públicas, 117 com RLS, 0 sem RLS**; **0 função pública SECURITY DEFINER executável por anon**. É prova atual do estado, não auditoria de todas as policies ou lógicas.
- Teste final V1-16: `docs/frontend/V116_COMPETENCIA_ANALISE_TESTE_C_2026-11-03.md`, SHA auditado `d4b9b77...`, 739/739 regressões, escopo funcional PASS. Este não certifica a main posterior com regeneração de tipos.
- V1-15: `docs/frontend/V115_COMPETENCIA_DOCUMENTOS_TESTE_C_2026-11-03.md`; V1-14: `docs/frontend/V114_COMPETENCIA_VISAO_GERAL_TESTE_C_2026-11-03.md`; V1-13, V1-12, V1-10 e V1-06: arquivos específicos de Teste C.
- BRAND-01: `contaos-hml-control/docs/frontend/lovable/BRAND-01.md` registra assets byte-idênticos e testes de logomarca. A presença desses testes não prova todas as telas posteriores.
- GitHub CI em `develop`: run `41691239737` do Zero-Drift PASS, incluindo novo Prompt Crosswalk. Backend V1-17: Restore Isolado `41686766086` PASS e Zero-Drift `41686766756` PASS. Não atribuir esse gate automaticamente ao repositório frontend.

## 5. Resultado geral e decisão

**AUDITORIA RETROSPECTIVA: CONFORMIDADE INTEGRAL 100% NÃO COMPROVADA.**  
**GO técnico para preservar bases certificadas em HML e executar correções controladas.**  
**NO-GO para declarar todos os prompts/atômicos concluídos e NO-GO para certificação 100% PRD/produção.**

Não foram modificados código frontend, dados, RLS, Edge, Auth, Storage, migrations ou produção durante a auditoria. Apenas este relatório de governança foi versionado.

## 6. Ordem objetiva de saneamento

1. Congelar e restaurar drift de tipos após autorização de mudança, proteger com CI no repositório frontend e corrigir root PT-BR. Não avançar BUILD sem baseline confiável.
2. Atualizar e conferir Project Knowledge Lovable com 100 regulares, 97 atômicos, BRAND-01, economia e Zero-Drift; garantir seção explícita nos futuros prompts.
3. Fechar E2E do SYS-03, ampliar provas BRAND para telas autenticadas e estados da V1-08 a V1-16, mantendo Teste C isolado.
4. Terminar frontend V1-17 Prompt 38 e cruzar cada funcionalidade com atômicos diretos + NFRs transversais.
5. Preencher os registros de conformidade semântica dos atômicos aplicáveis a cada etapa executada, sem refazer engenharia já certificada e sem alterar backend HML por conveniência.
6. Prosseguir somente então para Prompt 39, monitorando os gates por commit; executar depois as auditorias finais 90–99 e GO/NO-GO.

### Referências rápidas

- [Manual e política de prompts](https://github.com/contaos9999/develop/blob/main/12_PROMPTS_PROTOCOLO_IMPLEMENTACAO_4_1.md)
- [Zero-Drift, gates BRAND + economia](https://github.com/contaos9999/develop/blob/main/07_ZERO_DRIFT_GOVERNANCA_4_1.md)
- [Catálogo 100 + 97 e crosswalk](https://github.com/contaos9999/develop/blob/main/docs/prompts/PROMPT_TRACKS_4_1.json)
- [Frontend root com língua e mensagens](https://github.com/contaos9999/contaos-hml-control/blob/main/src/routes/__root.tsx)
- [Frontend types.ts atual](https://github.com/contaos9999/contaos-hml-control/blob/main/src/integrations/supabase/types.ts)
- [BRAND-01 teste de telas](https://github.com/contaos9999/contaos-hml-control/blob/main/src/test/brand.test.tsx)
- [Certificação inicial backend 96/96](https://github.com/contaos9999/develop/blob/main/docs/CERTIFICACAO_BACKEND_HML_4_1.md)
- [Testes V1-16 / Prompt 37](https://github.com/contaos9999/develop/blob/main/docs/frontend/V116_COMPETENCIA_ANALISE_TESTE_C_2026-11-03.md)
- [CI Zero-Drift mais recente](https://github.com/contaos9999/develop/actions/runs/41691239737)
- [Security Advisor SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Configuração de proteção de senhas vazadas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
