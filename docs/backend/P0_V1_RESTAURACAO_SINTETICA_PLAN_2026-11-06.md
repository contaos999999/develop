# PLAN P0 V1 — prova de backup/restauração de dados sintéticos em duas instâncias locais

**Data:** 06/11/2026. **Estado:** PLAN; nenhum BUILD, resultado ou certificado nesta etapa. **Autorização:** plano único de fechamento V1 pelo titular, sem PROD. Contexto 4.1, 25 fontes canônicas 00–20, fingerprint `c5dc0a97dd3a371fbdfbbd425c3fd31089e2d82f7c51a7458f0ecaedc2330088`, regra P0 versão-first e AGENTS.md conferidos. HEAD inicial backend `67668c61054405368d5c7895f5087ccfa9eb9dfc`.

## Lacuna e resultado esperado

O workflow `.github/workflows/restore-isolado.yml` certifica recriação do **schema** local por migrations e 13 suítes oficiais (exemplo [run 42149828756](https://github.com/contaos999999/develop/actions/runs/42149828756) SUCCESS). **Não** comprova recuperação de uma linha real de dados após perda do container original. O requisito transversal NFR-011/012 e o plano de fechamento V1 exigem distinguir reconstrução do schema de **backup de dados e restore**. A falha não autoriza alteração do backend certificado, das migrations ou de PROD.

Planejar um **segundo job isolado** no mesmo workflow, com seu próprio runner e serviço PostgreSQL Supabase local, distinto da job preexistente, para executar:
1. preflight de CLI e Docker, projeto local, URL exclusivamente localhost:54322; recusar credenciais remotas e projeto diferente;
2. instância local A: `supabase db start` + `supabase db reset --local --no-seed`; confirmar catálogo/migrations e RLS; exigir zero linhas em `public.organizacoes`;
3. inserir **uma única organização sintética** com UUID aleatório e nome marcador único em tabela de negócio real, sem usuários reais, arquivo, serviço externo, keys ou tenants HML;
4. registrar hash SHA-256 do conteúdo canônico da linha, versão/lista de migrations e política RLS; efetuar `pg_dump` **somente** da tabela permitida pela conta local Postgres 17 para backup custom binário, validar checksum e escopo de uma linha; nunca extrair qualquer dado da HML remota;
5. interromper a instância A com `supabase stop --no-backup` **e checar sucesso antes de remover temp/arquivos**, inspecionar que o container anterior deixou de existir;
6. instância local B: iniciar nova instância sequencial e recriar o schema versionado pelas migrations; exigir origem vazia e versão idêntica; restaurar exclusivamente `public.organizacoes` com `pg_restore --single-transaction --exit-on-error --no-owner --no-acl`;
7. conferir UUID, conteúdo, SHA-256, uma linha exata, migrações e RLS intactos; provar falha fechada quando faltar qualquer prova;
8. parar a segunda instância; manter temporários até a parada bem-sucedida; exportar **somente relatório sanitizado** em artifact com SHA das evidências e duração observada; eliminar temporários e NÃO publicar dump binário.

Sem novas migrations, DDL de produção/HML, Auth, RLS, Edge, Storage, Queue, alteração de tabela real, secretaria de email ou ferramentas pagas. CI de demais trabalhos permanece intacto; nenhum teste é desativado para facilitar resultado.

## Escopo mínimo proposto para BUILD posterior ao PLAN aprovado

- Novo: `scripts/p0-v1-synthetic-data-restore.sh` (script de teste exclusivamente local, fail-closed, traps de cleanup).
- Existente: `.github/workflows/restore-isolado.yml` (acrescentar job independente com CLI fixa 2.122.0; não mexer nas 13 provas do job principal).
- Documento: `docs/backend/P0_V1_RESTAURACAO_SINTETICA_RESULTADO_2026-11-06.md` (criar somente após prova em GitHub Actions).
- Manifesto: `docs/tasks/active-task.json` (allowlist e estado factual).
- Checkpoint oficial frontend: atualizar por PR coordenado **somente depois** de verificar BUILD/CI, sem quebrar snapshot backend.

PLAN precisa passar pelo Zero-Drift antes de começar o BUILD, com PR e merge próprios. BUILD usa branch nova a partir do main pós-PLAN. O teste de restore dispara como `pull_request` quando o workflow for alterado; cumprir `Zero-Drift` e `Restore Isolado` no SHA do BUILD antes de merge. Regressão de schema é pré-existente; novo job não substitui 13 testes originais.

## Resultados e limites de aceitação

- PASS exige **execução real** de ambas as instâncias, cópia/restore verificados da linha sintética, RLS, versão de migrations, cleanup e artifacts, além do CI e merge.
- FAIL ou ausência de logs bloqueiam PASS e certificação.
- Tempo de ensaio **não é** RPO/RTO contratado; um backup local de uma tabela sintética **não** prova PITR, recuperação de todo banco HML/PROD, Storage, SLA 99,9% nem recuperação de incidentes com dados reais.
- Status ao fim do PLAN: `PLANEJADO_NAO_EXECUTADO`. As demais pendências SYS-03 real, Teste C privado, carga, rastreabilidade e 3 ressalvas continuam abertas.
- Rollback: reverter commit de workflow/script; nenhum rollback DDL remoto. Instâncias locais só existem nos runners efêmeros.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE

**Impacto visual N/A:** escopo shell/workflow documental e runners locais, Brand v1.0 e PROMPT 000 preservados. Sem frontend, tokens, logos, CSS, componentes ou rotas. Executar por GitHub e Supabase CLI já usados, sem créditos Lovable, sem contratação nem dados/segredos em frontend. Não reduzir CI, controles, retenção da evidência ou escopo para economizar recursos.
