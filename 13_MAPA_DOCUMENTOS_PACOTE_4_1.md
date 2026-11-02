# ContaOS 4.1 — Mapa do Pacote Mestre para os Documentos Canônicos da Raiz

Pacote de origem: `ContaOS_Pacote_Mestre_Arquitetura_4_1_100_PRD_Lovable_Supabase_FINAL.zip`.

Camada complementar oficial: `ContaOS_Marca_Oficial_v1.0_FINAL.zip`, incorporada sem substituir qualquer documento do pacote 4.1.

Objetivo: garantir que nenhum agente precise adivinhar em qual DOCX/XLSX/pasta uma regra estava. Os documentos da raiz são a camada canônica de leitura para implementação; os arquivos originais permanecem como fonte de conferência histórica.

| Arquivo original/complementar do pacote | Conteúdo coberto na raiz |
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
| `05_FRONTEND_LOVABLE/ANEXO_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` | `00_BRAND`, `06`, `07` |
| `06_PROMPTS_COPIAR_COLAR/Manual_Mestre_Prompts_Lovable_Backend_Supabase_Frontend_1_a_5.docx/.md` | `12` |
| `06_PROMPTS_COPIAR_COLAR/Manual_Mestre_Prompts_4_1_100_PRD.docx` | `12` |
| `06_PROMPTS_COPIAR_COLAR/Caderno_96_Prompts_Atomicos_PRD_v1_0.docx` | `08`, `12` — original histórico 001–096 preservado |
| `06_PROMPTS_COPIAR_COLAR/Caderno_97_Prompts_Atomicos_000_a_096_BRAND_v1_1.docx` | `00_BRAND`, `08`, `12` — edição operacional 000–096 |
| `06_PROMPTS_COPIAR_COLAR/PROMPT_000_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` | `00_BRAND`, `12` |
| `07_ZERO_DRIFT/ZeroDrift_v2_Lovable_Supabase.docx` | `07`, `14` |
| `07_ZERO_DRIFT/ANEXO_ZERO_DRIFT_BRAND_01.md` | `00_BRAND`, `07`, `14` |
| `08_REQUISITOS_NAO_FUNCIONAIS/ContaOS_RNF_Escalabilidade_Concorrencia_Performance_v2_0_Supabase.docx` | `11` |
| `09_AUDITORIA_E_FONTES/MANIFEST_SHA256_v4_1.json` | `09`, `17` |
| `09_AUDITORIA_E_FONTES/MANIFEST_SHA256_v4_1_BRAND_v1_0.json` | `09`, `17` — manifesto da edição ampliada |
| `09_AUDITORIA_E_FONTES/RELATORIO_ANALISE_DOCUMENTAL_TRANSICAO_ARQUITETURA_4_0.docx` | `09`, `17` |
| `09_AUDITORIA_E_FONTES/CHANGELOG_v1_0.md` | `17` |
| `09_AUDITORIA_E_FONTES/CHANGELOG_BRAND_v1_0.md` | `00_BRAND`, `09`, `17` |
| `09_AUDITORIA_E_FONTES/MANIFEST_SHA256_v1_0.json` | `17` |
| `09_AUDITORIA_E_FONTES/FONTES_TECNICAS_01_11_2026.md` | `17` |
| `09_AUDITORIA_E_FONTES/RELATORIO_QA_CONTEUDO_v1_0.json` | `17` |
| `09_AUDITORIA_E_FONTES/CERTIFICACAO_FINAL_QA_v1_0.md` | `17` |
| `09_AUDITORIA_E_FONTES/CERTIFICACAO_INTEGRACAO_BRAND_01_v1_0.md` | `00_BRAND`, `09`, `17` |
| `09_AUDITORIA_E_FONTES/FONTES_CUSTOS_01_11_2026.md` | `16`, `17` |
| `09_AUDITORIA_E_FONTES/CERTIFICACAO_COBERTURA_PRD_4_1.md` | `08`, `17` |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_E_CUSTOS_ContaOS_4_1.xlsx` | `08`, `16` — original 96/96 preservada |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_E_CUSTOS_ContaOS_4_1_BRAND_v1_0.xlsx` | `00_BRAND`, `08`, `09`, `16` — aba transversal separada |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_PRD_96_v1_0.docx` | `08` — original 96/96 preservada |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_PRD_96_MAIS_BRAND_01_v1_1.docx` | `00_BRAND`, `08`, `09` |
| `11_CUSTOS_POR_ETAPA/PLANO_CUSTOS_POR_ETAPA_ContaOS_4_1.docx` | `16` |
| `12_MARCA_OFICIAL/ContaOS_Marca_Oficial_v1.0/` | `00_BRAND`, `03`, `06`, `07`, `09`, `12` — 50 assets/documentos oficiais preservados byte a byte |
| `12_MARCA_OFICIAL/README_INTEGRACAO_BRAND_01.md` | `00_BRAND`, `13` |

## Estado posterior ao pacote

O pacote 4.1 era documentação de especificação. Depois dele, o backend HML foi implementado e certificado. Para não fazer uma IA voltar no tempo, a raiz também inclui:
- `05_BACKEND_SUPABASE_CERTIFICADO_4_1.md`;
- `15_ESTADO_CERTIFICADO_HML_4_1.md`;
- certificado detalhado em `docs/CERTIFICACAO_BACKEND_HML_4_1.md`.

Portanto a leitura correta combina **intenção original + premissas + arquitetura + estado real certificado + camada complementar oficial da marca**.

## Regra de precedência da camada de marca

A Brand v1.0 é soberana apenas para identidade visual. Ela **não substitui** PRD, premissas, arquitetura, Design System estrutural, UX funcional, frontend funcional, Zero-Drift, backend ou segurança.

A nova edição do caderno contém `000–096`, mas a matriz PRD permanece `001–096 = 96/96`. O PROMPT 000 é transversal e deve ser rastreado separadamente.
