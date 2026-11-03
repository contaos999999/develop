# Retrospectiva verificável de backend — Prompts regulares 01–15

**Data da leitura atual:** 03/11/2026 (Brasília). **Projeto exclusivamente HML:** Supabase `gklhhhyosgasnyoxlrui`. **Método:** leitura dos prompts originais na pasta `06_PROMPTS_COPIAR_COLAR`, catálogo PostgreSQL (schemas, extensões, tabelas, funções), bucket Storage e certificados RESTORE/96/96 existentes no GitHub. Nenhum DDL/DML foi executado.

## Critério rigoroso

O resultado `PASS_ESTRUTURAL` demonstra **presença de estruturas e evidência histórica agregada**, não prova que cada prompt foi enviado ao Lovable ou ao Supabase em uma sessão de PLAN/BUILD/TESTE individual, nem que todos os casos negativos são reproduzíveis hoje. A revalidação independente de segurança por cenário/contrato permanece necessária onde aplicável. Não fabricar registros retroativos.

## Evidência atual comum

- Schemas `public` e `privado`: PRESENTES.
- Extensões `pg_cron`, `pgmq` e `vector`: PRESENTES.
- Tabelas públicas: **117/117 com RLS** (0 sem RLS) conforme consulta atual de `pg_class` e `pg_namespace`.
- Funções públicas `SECURITY DEFINER` executáveis pelo papel `anon`: **0**.
- Bucket `contaos-documentos`: PRIVADO (`storage.buckets.public = false`).
- RPCs `criar_competencia`, `avaliar_portao_conformidade`, `aprovar_apresentacao`, `registrar_apresentacao`, `solicitar_reanalise_requisitos`, `obter_analise_competencia_v116`, `obter_detalhe_requisito_v117`: presentes em `pg_proc`.
- Matriz inicial: 96/96 RF+NFR no certificado HML de 02/11/2026, com Restore Isolado. Certificações posteriores V107–V117 estão em `docs/backend/`.
- Avisos atuais: **6 funções autenticadas SECURITY DEFINER (WARN)**, **proteção de senhas vazadas desativada (WARN)**; **86 FKs sem índices cobridores (INFO)**. Esses avisos exigem revisão de risco, e não demonstram por si só exploração nem autorizam desligar RPCs.

## Verificação individual

| Prompt | Escopo original | Objetos/evidências corroborados | Fontes de verificação | Resultado |
|---|---|---|---|---|
| 01 | Fundação PostgreSQL e extensões | schemas public/privado; extensões vector, pgmq, pg_cron | pg_catalog: schemas e pg_extension; 117 tabelas públicas com RLS | **PASS_ESTRUTURAL** |
| 02 | Identidade, organizações e vínculos | organizacoes, perfis_usuarios, vinculos_usuarios, eventos_auditoria, comandos_idempotentes | pg_tables public; certificação histórico RLS A/B; anon não executa security definer pública | **PASS_ESTRUTURAL** |
| 03 | Contratantes e contratos 1.0 | contratantes, contratos, versoes_contrato, vinculos_usuario_contratos | pg_tables public; V1-03 e V1-06 possuem testes específicos posteriores | **PASS_ESTRUTURAL** |
| 04 | Base normativa, orçamento e listas 1.0 | fontes_normativas, versoes_fontes_normativas, aplicabilidades_fonte, propostas_orcamentarias, versoes_proposta, linhas_orcamentarias, listas_verificacao, versoes_lista, itens_lista, regras_conformidade, regras_preventivas | pg_tables public; certificação V107, V108 e V109 subsequentes | **PASS_ESTRUTURAL** |
| 05 | Storage e documentos 1.0 | bucket privado contaos-documentos; arquivos, documentos_contrato, versoes_documento, processamentos_documento, paginas_documento, fragmentos_documento | pg_tables + storage.buckets; 1 bucket confirmado privado; V110/V115 e Edge de URL assinada certificados historicamente | **PASS_ESTRUTURAL** |
| 06 | Competências e análise 1.0 | competencias, requisitos_competencia, execucoes_analise, resultados_requisitos, evidencias_resultado, apontamentos_internos, acoes_corretivas, pareceres_internos | pg_tables public; V114/V115/V116 certificados HML | **PASS_ESTRUTURAL** |
| 07 | Portão, aprovação e apresentação 1.0 | RPCs criar_competencia, avaliar_portao_conformidade, aprovar_apresentacao, registrar_apresentacao | pg_proc public; cenários 99% bloqueia, 100% + parecer + hash atual, validação e reapresentação no histórico do Restore | **PASS_ESTRUTURAL** |
| 08 | Histórico e precedentes 1.0 | relatorios_historicos_contratante, apontamentos_historicos, precedentes, respostas_historicas, desfechos_historicos | pg_tables public; matriz 96/96 histórica e política de precedente externo sem bloqueio automático | **PASS_ESTRUTURAL** |
| 09 | Queues, Cron e Edge Functions | pgmq, pg_cron, jobs_dlq, execucoes_assincronas | pg_extension e pg_tables; certificado 8 workers, idempotência, DLQ e cron em HML | **PASS_ESTRUTURAL** |
| 10 | ContaOS 2.0 — Diligências | ciclos_diligencia, pareceres_contratante, apontamentos_contratante, analises_apontamentos, planos_acao, tarefas_diligencia, contestacoes, pacotes_reapresentacao | pg_tables public e matriz 96/96; telas V2 não executadas | **PASS_ESTRUTURAL** |
| 11 | ContaOS 3.0 — Financeiro preventivo | fontes_financeiras, importacoes_financeiras, transacoes_financeiras, documentos_transacao, fornecedores, consumo_orcamentario, conciliacoes, alertas_preventivos | pg_tables public e matriz 96/96; frontend V3 não executado | **PASS_ESTRUTURAL** |
| 12 | ContaOS 4.0 — Inteligência histórica | vector, relacionamentos_conhecimento, similaridades_precedentes, alertas_historicos_transversais, padroes_historicos, riscos_corporativos | pg_extension/pg_tables; precedente informativo não libera/bloqueia portão automaticamente; V4 não executado | **PASS_ESTRUTURAL** |
| 13 | ContaOS 5.0 — Conformidade | controles_conformidade, versoes_controle, execucoes_controle, excecoes_controle, nao_conformidades, planos_remediacao, alteracoes_normativas, avaliacoes_impacto | pg_tables public; escopo backend histórico, frontend V5 não executado | **PASS_ESTRUTURAL** |
| 14 | ContaOS 5.0 — API e webhooks | clientes_api, escopos_clientes_api, webhooks, eventos_webhook, pacotes_evidencias, assinaturas_eventos_integracao | pg_tables public; hardening SSRF/webhook em commits anteriores | **PASS_ESTRUTURAL** |
| 15 | Hardening e testes do backend | 117/117 tabelas public com RLS; 0 funções públicas SECURITY DEFINER executáveis por anon; Restore isolado; 96/96 RF+NFR no certificado | consultas atuais HML + relatório de certificação e CI Restore Isolado; advisor atual 6 authenticated definer WARN e leaked password WARN | **PASS_ESTRUTURAL_COM_RISCOS_ABERTOS** |

## Decisão e pendências

1. **Estrutura dos módulos 01–15: CORROBORADA** pela evidência do catálogo HML e dos certificados históricos. Os 15 módulos não precisam ser reconstruídos para gerar artificialmente um novo histórico de execução.
2. **Rito individual de PLAN → aprovação → BUILD → TDD → TESTE C: NÃO COMPROVADO retrospectivamente para 01–15**. A certificação de backend é uma prova agregada de funcionalidade e segurança, com limites claros.
3. Cada prompt 01–15 do rastreador deve vincular este relatório, o commit de implementação/migration correspondente, testes da matriz 96/96 e o resultado Restore, delimitando se houve nova prova funcional; não declarar 100% individual somente porque a tabela existe.
4. Classificar explicitamente 6 funções `SECURITY DEFINER` authenticated conforme modelo RLS/autoridade, proteger contra BOLA, reavaliar password leaked protection e índices por consultas de produção. Nenhuma alteração técnica sem PLAN de escopo.
5. PROD não foi alterado.

**Status retro 01–15:** **ESTRUTURA VERIFICADA, COMPLETUDE DE PROCESSO INTEGRAL AINDA NÃO CERTIFICADA.**
