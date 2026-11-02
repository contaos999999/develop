# ContaOS 4.1 — Mapa do Pacote Mestre para os Documentos Canônicos da Raiz

Pacote de origem: `ContaOS_Pacote_Mestre_Arquitetura_4_1_100_PRD_Lovable_Supabase_FINAL.zip`.

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
| `06_PROMPTS_COPIAR_COLAR/Caderno_96_Prompts_Atomicos_PRD_v1_0.docx` | `08`, `12` |
| `07_ZERO_DRIFT/ZeroDrift_v2_Lovable_Supabase.docx` | `07`, `14` |
| `08_REQUISITOS_NAO_FUNCIONAIS/ContaOS_RNF_Escalabilidade_Concorrencia_Performance_v2_0_Supabase.docx` | `11` |
| `09_AUDITORIA_E_FONTES/MANIFEST_SHA256_v4_1.json` | `09`, `17` |
| `09_AUDITORIA_E_FONTES/RELATORIO_ANALISE_DOCUMENTAL_TRANSICAO_ARQUITETURA_4_0.docx` | `09`, `17` |
| `09_AUDITORIA_E_FONTES/CHANGELOG_v1_0.md` | `17` |
| `09_AUDITORIA_E_FONTES/MANIFEST_SHA256_v1_0.json` | `17` |
| `09_AUDITORIA_E_FONTES/FONTES_TECNICAS_01_11_2026.md` | `17` |
| `09_AUDITORIA_E_FONTES/RELATORIO_QA_CONTEUDO_v1_0.json` | `17` |
| `09_AUDITORIA_E_FONTES/CERTIFICACAO_FINAL_QA_v1_0.md` | `17` |
| `09_AUDITORIA_E_FONTES/FONTES_CUSTOS_01_11_2026.md` | `16`, `17` |
| `09_AUDITORIA_E_FONTES/CERTIFICACAO_COBERTURA_PRD_4_1.md` | `08`, `17` |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_E_CUSTOS_ContaOS_4_1.xlsx` | `08`, `16` |
| `10_RASTREABILIDADE_PRD/MATRIZ_RASTREABILIDADE_PRD_96_v1_0.docx` | `08` |
| `11_CUSTOS_POR_ETAPA/PLANO_CUSTOS_POR_ETAPA_ContaOS_4_1.docx` | `16` |

## Estado posterior ao pacote

O pacote 4.1 era documentação de especificação. Depois dele, o backend HML foi implementado e certificado. Para não fazer uma IA voltar no tempo, a raiz também inclui:
- `05_BACKEND_SUPABASE_CERTIFICADO_4_1.md`;
- `15_ESTADO_CERTIFICADO_HML_4_1.md`;
- certificado detalhado em `docs/CERTIFICACAO_BACKEND_HML_4_1.md`.

Portanto a leitura correta combina **intenção original + premissas + arquitetura + estado real certificado**.
