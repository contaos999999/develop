# ContaOS 4.1 — Protocolo de Prompts e Implementação

Consolida `Manual_Mestre_Prompts_4_1_100_PRD.docx`, `Manual_Mestre_Prompts_Lovable_Backend_Supabase_Frontend_1_a_5.*` e `Caderno_96_Prompts_Atomicos_PRD_v1_0.docx`.

## 1. Regra principal

Prompts do pacote são **instrumentos de execução do PRD**, não autorização para reinterpretar o produto. O agente deve primeiro ler PRD/Premissas/Arquitetura/Zero-Drift e o estado atual do repositório.

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

### B. BUILD MODE
Somente após plano aprovado:
- alterar exclusivamente arquivos autorizados;
- não refatorar por conveniência;
- reutilizar backend certificado;
- migration nova se realmente necessária;
- mensagens PT-BR;
- preservar contratos/API existentes.

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

## 3. Caderno atômico 96/96

Existe um prompt atômico para cada requisito explícito. Padrão obrigatório de análise de requisito:
1. localizar implementação existente;
2. localizar RLS/grants e provar isolamento;
3. localizar tela/fluxo quando aplicável;
4. localizar auditoria/idempotência/lock/Queue/Cron/Edge quando exigido;
5. localizar evidência/fonte;
6. comparar com texto literal do requisito;
7. propor menor plano para fechar somente a lacuna;
8. não alterar outro requisito/refatorar por conveniência;
9. testar antes de PASS.

## 4. Sequência do pacote

O pacote original organiza fundação, backend, frontend e versões 1→5, seguido de testes/segurança/GO-NO-GO. O backend HML já foi concluído/certificado; portanto, para a próxima etapa, prompts de frontend devem **consumir** o backend existente, não repetir prompts de fundação que criariam estruturas paralelas.

## 5. Prompts especiais

O conjunto inclui prompts para:
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

## 7. Frontend a partir de agora

Antes de cada prompt Lovable:
- contexto raiz lido;
- tarefa ativa criada;
- tela/requisitos identificados;
- confirmar que não há necessidade de schema novo;
- conectar ao Supabase HML certificado;
- usar RPCs/queries existentes;
- Build pequeno;
- teste;
- diff/scan.

## 8. Complemento canônico — PROMPT 000 / BRAND-01

A partir de 02/11/2026, o caderno atômico recebe uma camada transversal adicional de identidade visual oficial:

- `PROMPT 000`: BRAND-01 — Identidade Visual Oficial ContaOS v1.0;
- `PROMPTS 001–096`: permanecem exatamente os 96 prompts de requisitos PRD/NFR já existentes, sem renumeração.

A faixa canônica passa a ser **000–096**, com 97 prompts no caderno. A cobertura do PRD continua **96/96**, porque BRAND-01 é transversal e não constitui um 97º requisito funcional.

Antes de qualquer alteração visual no frontend Lovable, é obrigatória a leitura integral de:
- `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md`;
- `20_PROMPT_000_BRAND_01.md`.

O PROMPT 000 deve ser executado rigorosamente em **PLAN → aprovação → BUILD → TESTE**.

BRAND-01 é exclusivamente visual. Ele não autoriza alteração de backend, arquitetura, rotas, permissões, regras de negócio, estados, cálculos, integrações ou conteúdo funcional. O Design System existente deve ser preservado e os assets oficiais reutilizados.

Em caso de conflito entre estética e qualquer regra funcional/arquitetural do pacote 4.1, **o pacote 4.1 prevalece**.

Se o PLAN indicar necessidade de alteração fora do escopo visual, classificar `PLAN: NÃO APROVÁVEL`, parar e reportar a lacuna ou conflito.
