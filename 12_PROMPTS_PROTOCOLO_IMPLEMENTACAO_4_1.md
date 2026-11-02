# ContaOS 4.1 — Protocolo de Prompts e Implementação

Consolida `Manual_Mestre_Prompts_4_1_100_PRD.docx`, `Manual_Mestre_Prompts_Lovable_Backend_Supabase_Frontend_1_a_5.*`, `Caderno_96_Prompts_Atomicos_PRD_v1_0.docx` e, como camada complementar, o `PROMPT 000 / BRAND-01` da Identidade Visual Oficial ContaOS Brand v1.0.

## 1. Regra principal

Prompts do pacote são **instrumentos de execução do PRD**, não autorização para reinterpretar o produto. O agente deve primeiro ler PRD/Premissas/Arquitetura/Zero-Drift, `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` e o estado atual do repositório.

O BRAND-01 complementa o pacote 4.1 exclusivamente no domínio visual. Ele não substitui nenhum prompt funcional, requisito, arquitetura, premissa ou regra existente.

## 2. Fluxo de prompt

Para cada capacidade:

### A. PLAN MODE
O agente deve:
1. citar requisito(s) e tela(s);
2. localizar backend existente antes de criar qualquer coisa;
3. identificar tabelas/RLS/RPCs/Edge já presentes;
4. apontar arquivos que seriam alterados;
5. explicar impacto em segurança, histórico, tenant, portões e temporalidade;
6. propor a menor mudança possível;
7. listar testes;
8. não editar ainda.

Em tarefa visual/brand, o PLAN deve obedecer adicionalmente ao PROMPT 000 e declarar arquivos exatos, assets oficiais, mapeamento claro/escuro, tokens, responsividade, acessibilidade, riscos e ausência de backend.

### B. BUILD MODE
Somente após plano aprovado:
- alterar exclusivamente arquivos autorizados;
- não refatorar por conveniência;
- reutilizar backend certificado;
- migration nova se realmente necessária em tarefas funcionais autorizadas;
- mensagens PT-BR;
- preservar contratos/API existentes.

Em BRAND-01, migration/backend não são permitidos: qualquer necessidade desse tipo é **LACUNA ou CONFLITO** e exige parada.

### C. TESTE
Depois do Build:
- happy path;
- erro;
- perfil não autorizado;
- isolamento RLS;
- auditoria;
- concorrência/idempotência quando aplicável;
- acessibilidade para UI;
- Zero-Drift;
- não corrigir automaticamente item fora do escopo.

Para BRAND-01, a fase TESTE é read-only e segue os 72 itens PASS/FAIL definidos no PROMPT 000.

## 3. Caderno atômico 96/96 e faixa operacional 000–096

O caderno original possuía um prompt atômico para cada requisito explícito, numerado de `001` a `096`.

Com a Identidade Visual Oficial, a edição complementar passa a ter a faixa **000–096**:
- `000` = `BRAND-01`, transversal exclusivamente visual;
- `001–096` = os mesmos 96 prompts vinculados aos requisitos explícitos do PRD, preservados sem renumeração.

A faixa 000–096 possui 97 prompts operacionais, mas a certificação funcional continua **96/96**. O PROMPT 000 **não é requisito 097**.

Padrão obrigatório de análise de requisito 001–096:
1. localizar implementação existente;
2. localizar RLS/grants e provar isolamento;
3. localizar tela/fluxo quando aplicável;
4. localizar auditoria/idempotência/lock/Queue/Cron/Edge quando exigido;
5. localizar evidência/fonte;
6. comparar com texto literal do requisito;
7. propor menor plano para fechar somente a lacuna;
8. não alterar outro requisito/refatorar por conveniência;
9. testar antes de PASS.

Para o PROMPT 000, a análise é visual e deve preservar rigorosamente backend, comportamento, Design System existente e conteúdo funcional.

## 4. Sequência do pacote

O pacote original organiza fundação, backend, frontend e versões 1→5, seguido de testes/segurança/GO-NO-GO. O backend HML já foi concluído/certificado; portanto, para a próxima etapa, prompts de frontend devem **consumir** o backend existente, não repetir prompts de fundação que criariam estruturas paralelas.

A edição de marca não altera a numeração `PROMPT 00–99` do Manual Mestre. O novo `PROMPT 000` pertence ao caderno transversal/atômico e é executado antes de tarefas de identidade visual.

## 5. Prompts especiais

O conjunto inclui prompts para:
- BRAND-01 / PROMPT 000 — identidade visual oficial;
- auditoria Zero-Drift;
- isolamento multi-organização;
- portões 100%;
- documentos/filas;
- financeiro/RAG;
- security deep scan;
- smoke HML;
- GO/NO-GO produção;
- diagnóstico de lacuna de backend;
- recuperação após drift.

## 6. Regra de recuperação após drift

Se o agente detectar mudança fora do escopo:
1. parar Build;
2. identificar primeiro ponto de drift;
3. não mascarar o drift com novas alterações;
4. comparar com PRD/manifesto;
5. propor reversão mínima;
6. repetir testes e CI.

Para drift visual, comparar também com o pacote oficial ContaOS Brand v1.0 e com o PROMPT 000, sem alterar regra funcional para “acomodar” estética.

## 7. Frontend a partir de agora

Antes de cada prompt Lovable:
- contexto raiz lido, incluindo `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md`;
- tarefa ativa criada;
- tela/requisitos identificados;
- confirmar que não há necessidade de schema novo;
- conectar ao Supabase HML certificado;
- usar RPCs/queries existentes;
- Build pequeno;
- teste;
- diff/scan.

Se o prompt envolver identidade visual, logo, favicon, PWA, theme, tokens de marca ou aplicação da marca, executar o ciclo **PLAN → aprovação → BUILD → TESTE** do PROMPT 000 antes de declarar conclusão.
