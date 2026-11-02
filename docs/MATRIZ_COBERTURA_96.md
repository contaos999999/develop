# Matriz de Cobertura Executada 96/96 — ContaOS HML 4.1

Data: 02/11/2026, Horário de Brasília.

Fonte normativa: matriz oficial `MATRIZ_RASTREABILIDADE_PRD_96_v1_0.docx` do pacote mestre 4.1.

## Resultado

- Requisitos funcionais: **84/84 PASS**.
- Requisitos não funcionais: **12/12 PASS**.
- Total: **96/96 PASS**.
- A comparação programática confirmou **96 IDs exatos, 96 únicos, na mesma ordem da matriz oficial, sem requisito faltante ou extra**.
- Entidades backend explícitas referenciadas pela matriz: **75/75 existentes e 75/75 com RLS**.

## IDs oficiais validados

### ContaOS 1.0 — 24/24
`V1-CON-001`, `V1-CON-002`, `V1-CON-003`, `V1-CON-004`, `V1-CON-005`, `V1-HIS-001`, `V1-HIS-002`, `V1-HIS-003`, `V1-HIS-004`, `V1-HIS-005`, `V1-CHK-001`, `V1-CHK-002`, `V1-CHK-003`, `V1-CHK-004`, `V1-DOC-001`, `V1-DOC-002`, `V1-DOC-003`, `V1-DOC-004`, `V1-DOC-005`, `V1-AUD-001`, `V1-AUD-002`, `V1-AUD-003`, `V1-AUD-004`, `V1-AUD-005`.

### ContaOS 2.0 — 19/19
`V2-DIL-001`, `V2-DIL-002`, `V2-DIL-003`, `V2-DIL-004`, `V2-PRO-001`, `V2-PRO-002`, `V2-PRO-003`, `V2-PRO-004`, `V2-ACT-001`, `V2-ACT-002`, `V2-ACT-003`, `V2-ACT-004`, `V2-CONTEST-001`, `V2-CONTEST-002`, `V2-CONTEST-003`, `V2-CONTEST-004`, `V2-KB-001`, `V2-KB-002`, `V2-KB-003`.

### ContaOS 3.0 — 11/11
`V3-PREV-001`, `V3-PREV-002`, `V3-PREV-003`, `V3-PREV-004`, `V3-PREV-005`, `V3-PREV-006`, `V3-PREV-007`, `V3-ALT-001`, `V3-ALT-002`, `V3-ALT-003`, `V3-ALT-004`.

### ContaOS 4.0 — 20/20
`V4-INT-001`, `V4-INT-002`, `V4-INT-003`, `V4-INT-004`, `V4-PREC-001`, `V4-PREC-002`, `V4-PREC-003`, `V4-PREC-004`, `V4-TRV-001`, `V4-TRV-002`, `V4-TRV-003`, `V4-TRV-004`, `V4-TRV-005`, `V4-TRV-006`, `V4-TRV-007`, `V4-TRV-008`, `V4-COP-001`, `V4-COP-002`, `V4-COP-003`, `V4-COP-004`.

### ContaOS 5.0 — 10/10
`V5-CCM-001`, `V5-CCM-002`, `V5-CCM-003`, `V5-CCM-004`, `V5-REG-001`, `V5-REG-002`, `V5-REG-003`, `V5-AUDPORT-001`, `V5-AUDPORT-002`, `V5-AUDPORT-003`.

### NFR — 12/12
`NFR-001`, `NFR-002`, `NFR-003`, `NFR-004`, `NFR-005`, `NFR-006`, `NFR-007`, `NFR-008`, `NFR-009`, `NFR-010`, `NFR-011`, `NFR-012`.

## Evidências operacionais transversais

- **Multiempresa/RLS:** teste A/B PASS; 117/117 tabelas públicas com RLS; 2/2 tabelas privadas com RLS; 0 função pública `SECURITY DEFINER` executável por `anon`.
- **Portão de apresentação:** 99% bloqueia; 100% + parecer humano aprovado + hash de contexto atual libera; rótulo exato `PODE APRESENTAR AO CONTRATANTE`.
- **Portão de reapresentação:** apontamento pendente bloqueia; 100% tratado + reanálise atual libera; rótulo exato `PODE REAPRESENTAR AO CONTRATANTE`.
- **Anti-drift de contexto:** alteração documental ou financeira após liberação invalida automaticamente o portão, zera conformidade e exige reanálise; hash antigo bloqueia aprovação/protocolo.
- **Validação final:** somente parecer final favorável do contratante leva a `validada`; parecer não favorável leva a `com_apontamentos`.
- **Documentos/Storage:** bucket privado, upload/download assinados, upload resumível a partir de 100 MB, versionamento, hash e cadeia de evidência.
- **IA/OpenAI:** OCR/visão e análise operacional com `gpt-6-luna` validadas HTTP 200; IA sugere e aprovação permanece humana.
- **Assíncrono/resiliência:** 8 filas oficiais, idempotência, retry, DLQ, token interno, 5 Cron ativos e healthcheck operacional.
- **Concorrência:** `versao_registro` rejeita atualização obsoleta com mensagem PT-BR.
- **Carga:** base sintética de 10.000 contratantes + 10.000 contratos; 200 consultas paginadas com RLS p95 60,52 ms; 100/100 chamadas Edge HTTP 200; 0 HTTP 5xx; rollback integral.
- **Rastreabilidade/fontes:** evidências registram documento/versão/página/trecho/hash; inteligência transversal preserva contrato, competência, relatório, unidade, item, desfecho e similaridade; precedente externo não bloqueia sem fonte formal aplicável e aprovada.
- **Restore:** workflow `ContaOS Restore Isolado` reconstrói PostgreSQL/Supabase limpo exclusivamente pelas migrations versionadas e executa a suíte oficial de aceitação sobre o banco reconstruído.
- **Zero-Drift:** manifesto de tarefa, regras, Architecture Guard, scan de secrets, verificação de migrations, CODEOWNERS e CI ativos.
- **Testes sintéticos:** executados com `ROLLBACK`; 0 organizações e 0 usuários sintéticos persistidos.

## Exceção técnica documental controlada

O `MANIFEST_SHA256_v4_1.json` do pacote mestre possui um hash autorreferente do próprio manifesto. Foram verificados **27/27 hashes não autorreferentes**. A divergência do hash do próprio manifesto é consequência da autorreferência e não altera PRD, Premissas, Arquitetura, Backend, requisitos ou comportamento do HML.
