# ContaOS 4.1 — Matriz Canônica dos 96 Requisitos

Fonte: `MATRIZ_RASTREABILIDADE_PRD_96_v1_0.docx` do pacote mestre 4.1. Para manter leitura e validação confiáveis por qualquer agente, a matriz integral foi dividida em quatro arquivos canônicos, todos obrigatórios:

1. `08A_REQUISITOS_001_024_4_1.md`
2. `08B_REQUISITOS_025_048_4_1.md`
3. `08C_REQUISITOS_049_072_4_1.md`
4. `08D_REQUISITOS_073_096_4_1.md`

## Regras de uso

- Leia **as quatro partes integralmente** antes de alterar implementação.
- Trate cada ID como identificador estável.
- Antes de alterar uma área, localize todos os IDs impactados.
- Não marque requisito como atendido apenas porque a tela existe. Segurança, dados, backend e teste também fazem parte.
- Mudança que invalide um requisito é **NO-GO**.
- A certificação exige **84 RF + 12 NFR = 96/96**.

A divisão física não altera conteúdo, prioridade ou efeito da matriz.

## PROMPT 000 / BRAND-01 — fora da contagem 96/96

A adoção da Identidade Visual Oficial ContaOS Brand v1.0 acrescenta o **PROMPT TRANSVERSAL 000 — BRAND-01** ao caderno operacional, cuja faixa passa a ser **000–096**.

Isso **não cria o requisito 097** e não altera a matriz funcional:
- `001–096` continuam correspondendo exatamente aos 96 requisitos explícitos do PRD;
- `000` é regra transversal exclusivamente visual;
- a certificação permanece **84 RF + 12 NFR = 96/96**;
- BRAND-01 deve ser tratado em rastreabilidade separada, sem modificar o conteúdo dos IDs existentes.

A fonte canônica integral do PROMPT 000 é `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md`.
