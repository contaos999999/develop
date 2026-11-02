# Certificação de Integração — BRAND-01 / PROMPT 000

Data: 02/11/2026  
Escopo: governança documental e integração ao Pacote Mestre ContaOS Arquitetura 4.1  
Branch de trabalho: `governance/brand-01-prompt-000`

## Resultado documental

- Identidade Visual Oficial: **ContaOS Brand v1.0**.
- PROMPT transversal oficial: **BRAND-01 / PROMPT 000**.
- Faixa operacional do caderno: **000–096**.
- Prompts 001–096: preservados sem renumeração funcional.
- Cobertura PRD: permanece **84 RF + 12 NFR = 96/96**.
- PROMPT 000: transversal visual, fora da contagem PRD.
- Autoridade do pacote 4.1: preservada integralmente.
- Autoridade da Brand v1.0: restrita à identidade visual.

## Validações do pacote mestre ampliado

No workspace de integração do pacote mestre foram verificados:

- 50/50 arquivos do pacote oficial da marca preservados com SHA-256 idêntico à fonte;
- SHA-256 do ZIP da marca: `f26337dd0c5a217f5e51c3920625fecab0a91d79fdad5ab876459401a2d8b371`;
- PROMPT 000 integral presente em Markdown e no novo caderno DOCX;
- conteúdo do PROMPT 000 no DOCX igual à fonte Markdown;
- exatamente 97 cabeçalhos de prompts, sequenciais de 000 a 096;
- conteúdo dos prompts 001–096 preservado em relação ao caderno original;
- caderno novo renderizado e inspecionado visualmente em 75 páginas;
- matriz complementar DOCX renderizada e inspecionada visualmente em 16 páginas;
- matriz XLSX original preservada e nova aba transversal criada na cópia complementar;
- planilha complementar sem erros de fórmula detectados;
- documentos originais do pacote 4.1 mantidos como histórico/fonte canônica original.

## GitHub develop

Documentos constitucionais passam a registrar:

- leitura obrigatória de `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` antes de qualquer alteração;
- execução integral do BRAND-01 para tarefas visuais;
- BRAND-01 como camada complementar, nunca substitutiva;
- precedência do 4.1 quando estética afetar arquitetura ou comportamento;
- proibição de backend/Supabase em tarefa BRAND-01;
- manutenção da certificação 96/96;
- rastreabilidade SHA-256 dos 50 arquivos oficiais da marca.

## Backend

**Nenhuma alteração de backend foi realizada nesta tarefa.**

## Supabase

**Nenhuma tabela, migration, RLS, grant, RPC, Database Function ou Edge Function foi criada, removida ou modificada.**

## Zero-Drift

`ZERO-DRIFT DOCUMENTAL: PASS`

O diff desta integração deve permanecer restrito a documentação, governança e manifesto da identidade visual. Nenhum arquivo em `supabase/`, nenhuma migration e nenhum código funcional devem integrar o PR.

## PROD

PROD permanece intocado.
