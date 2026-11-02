# ContaOS 4.1 — Mapa do Pacote Mestre para os Documentos Canônicos da Raiz

Pacote de origem: `ContaOS_Pacote_Mestre_Arquitetura_4_1_100_PRD_Lovable_Supabase_FINAL.zip`.

Extensão oficial integrada em 02/11/2026: `ContaOS_Pacote_Mestre_Arquitetura_4_1_100_PRD_Lovable_Supabase_BRAND_v1_0_FINAL.zip`.

Objetivo: garantir que nenhum agente precise adivinhar em qual DOCX/XLSX/pasta uma regra estava. Os documentos da raiz são a camada canônica de leitura para implementação; os arquivos originais permanecem como fonte de conferência histórica.

| Arquivo original do pacote | Conteúdo coberto na raiz |
|---|---|
| `00_LEIA_ME.md` | `00`, `13` |
| `01_PRD_E_PREMISSAS/ContaOS_PRD_Mestre_v2_0_Lovable_Supabase.docx` | `01` + `08` |
| `01_PRD_E_PREMISSAS/ContaOS_Premissas_Funcionais_Tecnicas_1_a_5_v2_0_Lovable_Supabase.docx` | `02` |
| `02_ARQUITETURA_OFICIAL/ARQUITETURA_4_0_OFICIAL_LOVABLE_SUPABASE.docx` | `03`, `18` |
| `03_MANUAL_AMBIENTE/Manual_ContaOS_v6_0_ZERO_CONHECIMENTO_Lovable_Supabase.docx` | `04`, `14` |
| `04_BACKEND_SUPABASE/Backend_Supabase_v3_0_Manual_Integral_Production_Readiness.docx` | `05`, `18` |
| `04_BACKEND_SUPABASE/docs/MATRIZ_RLS.md` | `18` |
| `04_BACKEND_SUPABASE/docs/PLANO_EDGE_QUEUES_CRON.md` | `18` |
| `04_BACKEND_SUPABASE/docs/SCHEMA_LOGICO_1_A_5.md` | `18` |
| `05_FRONTEND_LOVABLE/FE_v4_Manual_Integral_Lovable_Supabase.docx` | `06` |
| `06_PROMPTS_COPIAR_COLAR/Manual_Mestre_Prompts_Lovable_Backend_Supabase_Frontend_1_a_5.docx/.md` | `12` |
| `06_PROMPTS_COPIAR_COLAR/Manual_Mestre_Prompts_4_1_100_PRD.docx` | `12` |
| `06_PROMPTS_COPIAR_COLAR/Caderno_96_Prompts_Atomicos_PRD_v1_0.docx` | `08`, `12` — histórico original 001–096 |
| `06_PROMPTS_COPIAR_COLAR/Caderno_97_Prompts_Atomicos_000_096_PRD_BRAND_v1_1.docx` | `12`, `19`, `20` — caderno canônico atualizado |
| `06_PROMPTS_COPIAR_COLAR/PROMPT_000_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` | `20` |
| `07_ZERO_DRIFT/ZeroDrift_v2_Lovable_Supabase.docx` | `07`, `14` |
| `08_REQUISITOS_NAO_FUNCIONAIS/ContaOS_RNF_Escalabilidade_Concorrencia_Performance_v2_0_Supabase.docx` | `11` |
| `09_AUDITORIA_E_FONTES/MANIFEST_SHA256_v4_1.json` | `09`, `17` |
| `09_AUDITORIA_E_FONTES/MANIFEST_SHA256_v4_1_BRAND_v1_0.json` | `09`, `17`, `19` |
| `09_AUDITORIA_E_FONTES/RELATORIO_ANALISE_DOCUMENTAL_TRANSICAO_ARQUITETURA_4_0.docx` | `09`, `17` |
| `09_AUDITORIA_E_FONTES/CHANGELOG_v1_0.md` | `17` |
| `09_AUDITORIA_E_FONTES/CERTIFICACAO_INTEGRACAO_BRAND_v1_0.md` | `17`, `19` |
| `09_AUDITORIA_E_FONTES/MANIFEST_SHA256_v1_0.json` | `17` |
| `09_AUDITORIA_E_FONTES/FONTES_TECNICAS_01_11_2026.md` | `17` |
| `09_AUDITORIA_E_FONTES/RELATORIO_QA_CONTEUDO_v1_0.json` | `17` |
| `09_AUDITORIA_E_FONTES/CERTIFICACAO_FINAL_QA_v1_0.md` | `17` |
| `09_AUDITORIA_E_FONTES/FONTES_CUSTOS_01_11_2026.md` | `16`, `17` |
| `09_AUDITORIA_E_FONTES/CERTIFICACAO_COBERTURA_PRD_4_1.md` | `08`, `17` |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_E_CUSTOS_ContaOS_4_1.xlsx` | `08`, `16` |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_PRD_96_v1_0.docx` | `08` — histórico original |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_PRD_96_COM_PROMPT_000_BRAND_v1_1.docx` | `08`, `19`, `20` — 96/96 preservado + gate 000 |
| `11_CUSTOS_POR_ETAPA/PLANO_CUSTOS_POR_ETAPA_ContaOS_4_1.docx` | `16` |
| `12_IDENTIDADE_VISUAL_OFICIAL/ARQUIVO_ORIGINAL/ContaOS_Marca_Oficial_v1.0_FINAL.zip` | `19`, `20` |
| `12_IDENTIDADE_VISUAL_OFICIAL/ContaOS_Marca_Oficial_v1.0/` | `19`, `20` — assets, manual e implementação Lovable |

## Estado posterior ao pacote

O pacote 4.1 era documentação de especificação. Depois dele, o backend HML foi implementado e certificado. Para não fazer uma IA voltar no tempo, a raiz também inclui:
- `05_BACKEND_SUPABASE_CERTIFICADO_4_1.md`;
- `15_ESTADO_CERTIFICADO_HML_4_1.md`;
- certificado detalhado em `docs/CERTIFICACAO_BACKEND_HML_4_1.md`.

A integração Brand v1.0 acrescenta:
- `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md`;
- `20_PROMPT_000_BRAND_01.md`.

Portanto a leitura correta combina **intenção original + premissas + arquitetura + estado real certificado + identidade visual oficial quando o escopo for visual**.

## Regra de cobertura

A matriz de requisitos permanece **96/96**. O PROMPT 000 / BRAND-01 é transversal e não deve ser contado como requisito adicional do PRD. A faixa de prompts atômicos passa a ser **000–096** sem renumerar 001–096.
