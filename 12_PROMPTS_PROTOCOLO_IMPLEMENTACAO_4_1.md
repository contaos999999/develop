# ContaOS 4.1 — Protocolo de Prompts e Implementação

Consolida `Manual_Mestre_Prompts_4_1_100_PRD.docx`, `Manual_Mestre_Prompts_Lovable_Backend_Supabase_Frontend_1_a_5.*`, o caderno original `Caderno_96_Prompts_Atomicos_PRD_v1_0.docx` e sua extensão oficial com BRAND-01.

## 1. Regra principal

Prompts do pacote são **instrumentos de execução do PRD e da governança transversal**, não autorização para reinterpretar o produto. O agente deve primeiro ler PRD/Premissas/Arquitetura/Zero-Drift, identidade visual oficial quando aplicável e o estado atual do repositório.

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
- migration nova se realmente necessária e autorizada;
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

## 3. Caderno atômico 000–096

A faixa canônica passa a ser **000–096**, total de 97 prompts:

- `000`: BRAND-01 — Identidade Visual Oficial ContaOS v1.0, transversal e exclusivamente visual;
- `001–096`: um prompt para cada um dos 96 requisitos explícitos do PRD/NFR, sem renumeração.

A cobertura PRD permanece **96/96**. BRAND-01 não deve ser contado como 97º requisito do PRD.

Para cada requisito 001–096, permanece o padrão obrigatório:
1. localizar implementação existente;
2. localizar RLS/grants e provar isolamento;
3. localizar tela/fluxo quando aplicável;
4. localizar auditoria/idempotência/lock/Queue/Cron/Edge quando exigido;
5. localizar evidência/fonte;
6. comparar com texto literal do requisito;
7. propor menor plano para fechar somente a lacuna;
8. não alterar outro requisito/refatorar por conveniência;
9. testar antes de PASS.

## 4. PROMPT 000 / BRAND-01

O texto integral está em `20_PROMPT_000_BRAND_01.md` e a norma de precedência em `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md`.

Ele é obrigatório antes de qualquer alteração visual no Lovable e deve ser executado em PLAN → aprovação → BUILD → TESTE.

Regras essenciais:
- exclusivamente visual;
- pacote 4.1 prevalece se estética afetar comportamento ou arquitetura;
- Design System existente é preservado;
- assets oficiais são reutilizados;
- nenhuma alteração funcional/backend é autorizada;
- responsividade 1440/1280/768/390 e acessibilidade são obrigatórias;
- fase de TESTE não altera código;
- se o PLAN exigir mudança fora do escopo visual, classificar `PLAN: NÃO APROVÁVEL` e parar.

## 5. Sequência do pacote

O pacote original organiza fundação, backend, frontend e versões 1→5, seguido de testes/segurança/GO-NO-GO. O backend HML já foi concluído/certificado; portanto, para a próxima etapa, prompts de frontend devem **consumir** o backend existente, não repetir prompts de fundação que criariam estruturas paralelas.

BRAND-01 não reinicia a sequência funcional e não altera o estado certificado. Ele é um gate transversal aplicado apenas quando a tarefa tiver impacto visual.

## 6. Prompts especiais

O conjunto inclui prompts para:
- identidade visual oficial (000 / BRAND-01);
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

## 7. Regra de recuperação após drift

Se o agente detectar mudança fora do escopo:
1. parar Build;
2. identificar primeiro ponto de drift;
3. não mascarar o drift com novas alterações;
4. comparar com PRD/manifesto;
5. propor reversão mínima;
6. repetir testes e CI.

Em BRAND-01, drift inclui redesenho não autorizado de asset, criação de Design System paralelo, hardcode de paleta em componentes, refatoração de tela ou qualquer alteração funcional/backend.

## 8. Frontend a partir de agora

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

Se houver qualquer impacto de identidade visual, adicionar antes do PLAN:
- leitura de `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md`;
- leitura integral de `20_PROMPT_000_BRAND_01.md`;
- inspeção dos assets oficiais do pacote Brand v1.0;
- declaração `prompt_000_brand_01_read = true` no manifesto da tarefa.
