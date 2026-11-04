# REGRA CANÔNICA P0 — execução por versão, certificação por versão e GO/NO-GO global

**DECISÃO EXPRESSA DO RESPONSÁVEL PELO CONTAOS 4.1: 04/11/2026, Brasília.** Regra constitucional de **PRIORIDADE ZERO, ADITIVA** a PRD/Premissas/Arquitetura, 96 requisitos, Brand-01, Zero-Drift, RLS, LGPD, tipo imutável, TDD/CI/Teste C e aprovações humanas já existentes. **É obrigatória a leitura antes de PLAN, BUILD, teste, auditoria ou documentação** por qualquer desenvolvedor, pessoa, agente ou automação, seja frontend GitHub, Lovable, backend Supabase ou IDE. Nenhum agente pode usar a antiga ordem meramente numérica dos prompts para avançar de versão.

## Regra mandatória

**Executar, com comprovação individual, TODOS os 100 prompts regulares 00–99 e TODOS os 97 prompts atômicos 000–096, mas ORGANIZAR o desenvolvimento por VERSÃO DO PRODUTO: concluir, validar, homologar e certificar V1 antes de iniciar V2; repetir V2→V3→V4→V5; por último executar a auditoria transversal/certificação global e decidir GO/NO-GO de produção.**

### Sequência obrigatória dos 57 regulares ainda restantes

1. **ContaOS V1:** 43 (V1-22 Ingestão de histórico), **75 (V1-23 Trilha de auditoria)**, auditoria retroativa individual do histórico 00–42 e certificado integrado V1. **V1 AINDA NÃO CERTIFICADA.**
2. **ContaOS V2:** 44,45,46,47,48,49,76,77; certificado integrado V2. **Não iniciar antes da V1 certificada.**
3. **ContaOS V3:** 50,51,52,53,54,55,78,79; certificado integrado V3. **Não iniciar antes da V2 certificada.**
4. **ContaOS V4:** 56,57,58,59,80,81,82,83; certificado integrado V4. **Não iniciar antes da V3 certificada.**
5. **ContaOS V5:** 60,61,62,63,64,65,66,84,85,86,87,88,89; certificado integrado V5. **Não iniciar antes da V4 certificada.**
6. **Certificação global V1–V5:** 67,68,69,70,71,72,73,74,90,91,92,93,94,95,96,97,98,99, cada qual com prova própria. O PROMPT 74 não substitui o GO/NO-GO final do 99. **PROD só após homologação integral e autorização expressa; nunca promover automaticamente.**

**Contagem:** 43 regulares 00–42 no histórico (sem presumir certificação retrospectiva) + **57 a executar** = **100 únicos**. A sequência funcional por versão não altera o texto, ID, intenção ou aceite de nenhum prompt original.

### Atômicos obrigatórios

- `000`: BRAND-01 transversal;
- `001–024`: 24 requisitos V1;
- `025–043`: 19 requisitos V2;
- `044–054`: 11 requisitos V3;
- `055–074`: 20 requisitos V4;
- `075–084`: 10 requisitos V5;
- `085–096`: 12 RNF, NFR-001 a NFR-012, aplicáveis transversalmente a cada versão quando pertinentes e novamente à homologação global.

**97 no total = 1 identidade visual + 84 RF + 12 NFR.** Atômicos são requisitos transversais/funcionais, **não** 97 novas telas ou 97 BUILDs artificiais. Cada prompt regular deve localizar e confrontar seus requisitos com a fonte original, registrar PLAN/GATE, implementações e provas, sem confundir inventário com certificação.

### Gates rígidos de saída por versão

A versão só se torna **PASS/CERTIFICADA** se houver documento de certificação publicado em PR integrado à main com SHA/CI, tabela 100%-conforme de regulares da versão (incluindo legado V1 00–42), atômicos aplicáveis, RNFs, segurança, RLS/tenancy sob sua prova exigível, auditoria e fontes, testes positivos/negativos, TDD, build, Zero-Drift, identidade visual BRAND-01, responsividade e acessibilidade, Teste C independente e **dois checks CI verdes no mesmo SHA**. Falta relevante, FAIL ou NÃO VERIFICADO obrigatório = **NO-GO da versão**; corrigir nela, sem saltar para próxima. N/A legítimo exige justificativa rastreável; não usar mock ou tela existente como prova operacional.

**Decisão de HML preservada:** ensaio operacional RLS A/B entre organizações do frontend permanece **NÃO VERIFICADO, FACULTATIVO APÓS O REGULAR 99 E NÃO BLOQUEANTE ISOLADAMENTE AO DESENVOLVIMENTO**, conforme decisão do titular já versionada; isto não dispensa os demais checks de isolamento/segurança nem autoriza alegar que a prova real foi executada.

### Registro e execução

- O repositório frontend `contaos999999/contaos-hml-control` contém a norma detalhada `docs/frontend/governanca/P0_PRIORIDADE_ZERO_ORDEM_POR_VERSAO_4_1.md`, o catálogo imutável de sequenciamento `P0_ORDEM_POR_VERSAO_4_1.json` e o gate automatizado `scripts/p0-version-order-gate.mjs`, incluído na CI Zero-Drift e com testes negativos.
- **Antes de qualquer mudança**, leia `AGENTS.md`, **este arquivo**, os 25 documentos canônicos do `00_AI_LEIA_ANTES_DE_ALTERAR.md`, o fingerprint, o manifesto da tarefa e o checkpoint oficial frontend. Confirme HEADs e matriz P0 atual, sobretudo o último certificado efetivamente integrado. Ferramentas incapazes de ler = **PARAR sem alterar**.
- **Backend permanece certificado e protegido:** esta decisão é organizacional. **Não habilita** nova migration, DDL, RPC, Edge Function, RLS, Storage, Auth, segredo ou acesso PROD. Lacuna backend exige aprovação específica e PLAN/GATE próprios, sem tocar dados de produção.
- Se existirem documentos antigos prescrevendo avançar 43→44 por numeração ou GO/NO-GO antes do fechamento V1–V5, esta decisão expressa P0 **prevalece apenas no sequenciamento**; não revoga requisitos, escopo, evidências nem segurança.
- Atualizar status da execução, certificados e checkpoints nos PRs, sem apagar histórico. **Próximo regular: 43/V1-22, depois 75/V1-23 e certificar V1, só então 44/V2-01.**

### Proveniência

Fonte regular: `Manual_Mestre_Prompts_4_1_100_PRD.docx`, SHA-256 `8a15d96568d021ac86fdd45e79038e2cb969d69c12b2edb84f012a6129b8940e`. Caderno atômico 000–096 SHA-256 `d9faaae47de4b697b18ad7fb71e4738384514936813cd5b18779f4cb8aed83b8`. Catálogo original consolidado `docs/prompts/PROMPT_TRACKS_4_1.json` permanece **intocado**; fonte normativa/PRD e hashes não são reescritos por esta instrução.
