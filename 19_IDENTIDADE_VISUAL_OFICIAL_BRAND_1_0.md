# ContaOS 4.1 — Identidade Visual Oficial ContaOS Brand v1.0

**Status:** CANÔNICO  
**Data de integração:** 02/11/2026  
**Escopo:** exclusivamente visual  
**Pacote oficial:** `ContaOS_Marca_Oficial_v1.0_FINAL.zip`

## 1. Regra constitucional

A ContaOS Brand v1.0 passa a ser a fonte oficial da identidade visual da marca ContaOS. Esta camada **complementa** o pacote mestre Arquitetura 4.1 e não substitui PRD, premissas, arquitetura, Design System, UX, segurança, backend, rastreabilidade, requisitos, testes ou Zero-Drift.

Em qualquer conflito que afete comportamento, arquitetura, segurança, Design System, navegação, acessibilidade, responsividade estrutural ou regra funcional, **o pacote 4.1 prevalece**.

## 2. Fonte de verdade da marca

A marca oficial define logomarca, símbolo, favicon, ícones PWA, versões horizontal/vertical, aplicações para fundos claro/escuro, versões monocromáticas, proteção, tamanhos mínimos, paleta institucional e Manual de Identidade Visual.

Pacote mestre integrado e validado em 02/11/2026:
`ContaOS_Pacote_Mestre_Arquitetura_4_1_100_PRD_Lovable_Supabase_BRAND_v1_0_FINAL.zip`

SHA-256 do pacote mestre integrado:
`5ee115d12e263d98068288b6bb722f5f303f2d19e1e4c0b5e930e69da03621da`

SHA-256 do pacote oficial da marca incorporado ao mestre:
`f26337dd0c5a217f5e51c3920625fecab0a91d79fdad5ab876459401a2d8b371`

## 3. Paleta oficial

- Navy / Principal: `#0F172A`
- Azul Institucional: `#0EA5E9`
- Teal / Destaque: `#14B8A6`
- Superfície: `#F1F5F9`

A prioridade é **REUTILIZAR > ESTENDER > CRIAR** tokens no Design System existente. Não criar segunda paleta global.

## 4. Tipografia

A identidade utiliza **Inter**. Antes de alterar tipografia, verificar a fonte já existente no projeto. Não introduzir segunda família sem necessidade e não modificar layout global apenas para adaptar a marca.

## 5. Conceito da marca

O símbolo representa **Governança + Rastreabilidade + Arquitetura Modular**.

Contrato → Evidência → Auditoria → Financeiro → Compliance → Inteligência.

O espaço negativo central representa a fonte única da verdade do contrato.

Não redesenhar, deformar, alterar proporções, adicionar elementos ou recriar manualmente o símbolo quando houver SVG oficial.

## 6. PROMPT 000 obrigatório

O `20_PROMPT_000_BRAND_01.md` é o **PROMPT ATÔMICO 000** e deve ser lido e executado integralmente antes de qualquer alteração visual no frontend Lovable.

A faixa canônica de prompts atômicos passa a ser **000–096**, total de 97 prompts:
- 000 = BRAND-01, transversal;
- 001–096 = 96 requisitos PRD/NFR existentes, sem renumeração.

A cobertura PRD/NFR permanece **96/96**. BRAND-01 não é o 97º requisito do PRD.

## 7. Limite de escopo

BRAND-01 é exclusivamente visual e não autoriza qualquer alteração funcional, arquitetural ou de backend. Todas as proibições detalhadas permanecem no `00_AI_LEIA_ANTES_DE_ALTERAR.md`, no `07_ZERO_DRIFT_GOVERNANCA_4_1.md` e no texto integral do PROMPT 000.

Se uma necessidade visual ultrapassar esse limite: **PARE e reporte como LACUNA ou CONFLITO. Não improvise.**

## 8. Aplicação esperada

No PLAN, auditar antes de alterar: Design System, tokens, layout global, login, sidebar expandida/recolhida, header, navegação mobile, favicon, PWA/manifest, metadata, light/dark mode, responsividade 1440/1280/768/390, acessibilidade, estrutura `public`, documentação frontend, AGENTS.md e Zero-Drift.

A marca deve se adaptar ao ContaOS. **O ContaOS não deve ser reconstruído para se adaptar à logomarca.**

## 9. Teste e certificação

A fase TESTE de BRAND-01 é read-only e deve validar individualmente os 72 itens definidos em `20_PROMPT_000_BRAND_01.md`.

A implantação somente pode ser declarada concluída com todos os gates críticos verdes e Git diff limitado ao escopo visual aprovado.
