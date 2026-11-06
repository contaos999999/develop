# P0 V1 — execução real: backup e restore de dados sintéticos locais

**Data:** 06/11/2026 (UTC). **Escopo:** exclusivamente runners isolados GitHub Actions, PostgreSQL 17, Supabase CLI `2.122.0`. **HML remoto `gklhhhyosgasnyoxlrui` não recebeu DDL/DML, reset, backup, novas identidades ou alteração de configuração nesta prova. PROD intacta. V1 NÃO CERTIFICADA.**

## Rastreamento de PLAN/BUILD e evidência

- PLAN [backend PR #86](https://github.com/contaos999999/develop/pull/86), merge `e7cfb5e7f953a11a8024ab6075fc0661b8277bfa`, CI Zero-Drift [42168079839](https://github.com/contaos999999/develop/actions/runs/42168079839) SUCCESS.
- BUILD [backend PR #87](https://github.com/contaos999999/develop/pull/87), HEAD final `5cffdd1028b72c58397d76b9f8507cfb81074cb0`, merge `0b790304ae3fd7d8e44dd6cfca1ca6e0a9a64a7f`; conteúdo integrado confirmado no `main`.
- Zero-Drift final [42168969380](https://github.com/contaos999999/develop/actions/runs/42168969380) `guard SUCCESS`.
- Teste [42168969390](https://github.com/contaos999999/develop/actions/runs/42168969390): job existente `reconstruir-banco-do-zero` **SUCCESS**; job novo `prova-backup-dados-sinteticos-duas-instancias` **SUCCESS**. Ambos testaram o mesmo HEAD do BUILD, em runners distintos.
- Evidência binária **sanitizada**, sem `pg_dump` e sem dados reais: [artifact 13480626051](https://github.com/contaos999999/develop/actions/runs/42168969390/artifacts/13480626051), nome `contaos-p0-v1-synthetic-data-restore`. Artefato baixado e inspecionado independentemente após a execução; contém `result.txt`, `cleanup.log`, SHA-256 da linha antes/depois, SHA-256 do backup, listas de migrations e snapshots RLS.

## Resultado observado, conferência do artefato

| Gate | Evidência real | Resultado |
| --- | --- | --- |
| Fonte isolada de dados | Um registro de `public.organizacoes` com UUID gerado no runner e marcador fictício; tabelas de destino inicialmente vazias | PASS |
| Backup PostgreSQL nativo 17 | Arquivo custom `pg_dump` somente `public.organizacoes`; TOC verificou uma única tabela; hash do arquivo `c5451c61bb28c660fe9bd9abc7b73695fb1ba31131702bfd7fd4e87caaa7850e` | PASS |
| Descarte da origem e nova instância | `supabase stop --no-backup`, verificação do container antigo, reinicialização em container com ID distinto | PASS |
| Restauração física da linha | `pg_restore --single-transaction --exit-on-error --no-owner --no-acl`; um registro recuperado e UUID idêntico | PASS |
| Hash de conteúdo antes/depois | `4e789ffd16c23b6a03faf844223f5d5b522885e3f4e2d0a0288e61485956fc8d` em ambos os arquivos de hash | PASS |
| Migrations source/destination | **126/126 versões idênticas**, byte-a-byte, SHA-256 da lista `a821e3702b5108357390a70fa8ce2bd808cbe53f38981f0e01ff9b9a39c25871` | PASS |
| RLS `public.organizacoes` | `relrowsecurity=true`, `relforcerowsecurity=false` antes e depois, mesmas flags | PASS |
| Cleanup | `cleanup.log` registra sucesso de `supabase stop --no-backup` após o segundo container | PASS |
| Tempo de observação | `seconds_recreate_and_restore=38` no runner, após parada da origem; não inclui PITR, restauração full, Storage ou recuperação PROD | 38 segundos, **não RTO certificado** |

As verificações foram confirmadas pela leitura direta do ZIP do artifact, incluindo igualdade exata das 126 linhas de migrations e dos dois arquivos de hash. O backup binário **não** foi anexado; nenhuma senha/token foi registrada no relatório.

## Falha original preservada e correção mínima

- Primeira execução [42168549551](https://github.com/contaos999999/develop/actions/runs/42168549551): job novo **FAIL**, job original SUCCESS, Zero-Drift [42168549667](https://github.com/contaos999999/develop/actions/runs/42168549667) SUCCESS.
- O [artifact inicial 13480600371](https://github.com/contaos999999/develop/actions/runs/42168549551/artifacts/13480600371) mostrou origem/dump e destino com 126 migrations/RLS conferidos, mas o comando final tentou `docker exec` usando o ID do segundo container obtido antes de `supabase db reset --local`, que o recriou. Log: `No such container`.
- Correção **somente** em `scripts/p0-v1-synthetic-data-restore.sh`, commit `5cffdd1028b72c58397d76b9f8507cfb81074cb0`: obter ID após `db reset`; expurgar arquivos de linhas/TOC dos artifacts inclusive quando houver falha.
- Nova execução PASS descrita acima. O histórico inicial de falha continua disponível no CI; não reclassificar primeira rodada como PASS.

## Auditoria RNF HML, somente leitura, separada do restore

Consulta de observabilidade do próprio HML em 06/11/2026 05:29:04 UTC: 7 conexões sobre `max_connections=60`, 1 query ativa no instante, 0 sessões aguardando locks, 0 deadlocks acumulados em `pg_stat_database`. Nove tabelas de fila `pgmq.q_*` sem mensagens pendentes; 6 mensagens arquivadas em `pgmq.a_historico`; outros arquivos de filas com 0; 6/6 jobs Cron ativos. Contagens são **snapshot instantâneo**, não carga concorrente representativa, monitoramento temporal de 99,9%, SLA, prova de latência 500/800ms, observabilidade ponta a ponta ou ausência histórica de falha.

## Escopo que continua pendente e limites rigorosos

Esta prova **NÃO** verifica: backup completo de todas as tabelas e Storage da aplicação, políticas PITR do Supabase, exportação/importação do HML real, integridade de arquivos privados ou RPO/RTO com falha real. **Não ampliar o PASS** a NFR-011 ou NFR-012 integrais por este ensaio de uma tabela. O backend certificado permanece inalterado em schema/funcionalidade.

Demais bloqueios V1: SYS-03 com envio, leitura de link, expiração/reuso e novo login reais usando alias sintético controlado; Teste C privado autenticado e WCAG real em quatro larguras e dois temas; RNFs de carga, latência por rota, integração externa e disponibilidade; reconciliação funcional item a item do universo V1 486/488. Ressalvas históricas R01 upload E2E físico, R02 worker E2E e R03 isolamento A/B real mantêm limites anteriores. V2/PROD bloqueados.

**Última etapa comprovada:** restore local de dado sintético em segunda instância com hash, migrations e RLS preservados, BUILD integrado. **Próxima:** configurar provas SYS-03 e Teste C privado com credenciais protegidas/identidades novas, sem reutilizar contas sintéticas bloqueadas, e completar RNFs restantes; registrar apenas resultados de fato executados.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

Impacto visual N/A, justificado por script/workflow isolados. Nenhum arquivo BRAND-01, arquivo de tipos congelados, frontend, migration, RLS, Edge, Auth, Storage, HML remoto ou PROD alterado. Ferramentas GitHub Actions/Supabase CLI já existentes, sem crédito Lovable ou novo fornecedor. TDD operacional histórico FAIL → fix mínimo → PASS preservado.
