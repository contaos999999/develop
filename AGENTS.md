# ContaOS — Regras obrigatórias para qualquer agente de IA

## P0 — REGRA CONSTITUCIONAL DE PRIORIDADE ZERO: SEQUENCIAMENTO POR VERSÃO

**LEITURA OBRIGATÓRIA ANTES DE QUALQUER PLAN/GATE/BUILD:** `docs/prompts/P0_PRIORIDADE_ZERO_ORDEM_POR_VERSAO_4_1.md`, além de `00_AI_LEIA_ANTES_DE_ALTERAR.md`, 25 fontes canônicas, manifesto e tarefa. Para frontend, ler também `contaos999999/contaos-hml-control/docs/frontend/governanca/P0_PRIORIDADE_ZERO_ORDEM_POR_VERSAO_4_1.md` e `P0_ORDEM_POR_VERSAO_4_1.json`. Se não conseguir ler, **PARAR**.

**O DESENVOLVIMENTO DEVE SEGUIR V1 → certificação V1 → V2 → certificação V2 → V3 → certificação V3 → V4 → certificação V4 → V5 → certificação V5 → auditoria/certificação GLOBAL e GO/NO-GO**, NUNCA a numeração simples dos regulares. Executar/avaliar com prova **todos os 100 regulares (00–99) e 97 atômicos (000–096)**. No estado atual: regular **43/V1-22**, depois **75/V1-23**, revisão do legado V1 00–42, **certificar V1 antes de iniciar 44/V2-01**. Sequência completa e regras de certificação no documento P0. A versão seguinte está **BLOQUEADA** sem certificado PASS integrado e CI/Teste C, sem aprovação falsa.

Esta regra prioriza **ordem e certificação**, é aditiva e **NÃO enfraquece** PRD, arquitetura, BRAND-01, segurança, RLS, idempotência, Zero-Drift, RNFs, autorização humana ou PROD. Ensaio RLS HML A/B operacional pós-99 mantém status facultativo e NÃO VERIFICADO, sem dispensar outros testes. Nada nesta decisão autoriza mudança de backend certificado ou promoção a produção.



## BLOQUEIO DE CONTEXTO

Antes de analisar, planejar ou alterar qualquer parte deste repositório, **leia integralmente `00_AI_LEIA_ANTES_DE_ALTERAR.md` e, na ordem indicada nele, todos os documentos canônicos `00` a `18` da raiz**. Em seguida, leia `AI_CONTEXT_MANIFEST.md` e `docs/tasks/active-task.json`.

Se não puder ler todos os documentos, **não altere nada**. Informe que o contexto obrigatório não foi concluído.

Para uma tarefa de implementação, o `active-task.json` deve declarar a leitura do contexto atual e conter o fingerprint vigente. O CI `Context Gate` bloqueia alterações sem essa declaração.

## Fonte de verdade

1. decisão funcional mais recente expressamente aprovada;
2. PRD Mestre 4.1;
3. Premissas Funcionais e Técnicas 4.1;
4. Arquitetura Oficial Lovable + Supabase;
5. Zero-Drift e matriz 96/96;
6. migrations/RLS/RPC/Edge/tests já certificados no HML;
7. documentação auxiliar/prompts.

Nenhuma IA pode alterar premissa funcional para facilitar implementação.

## Regras absolutas

- Backend oficial: Supabase próprio. Não criar backend paralelo.
- `contaos9999/develop` é HML. `contaos9999/prod` não deve receber mudanças durante desenvolvimento/homologação.
- O backend HML 4.1 já está certificado. Frontend deve reutilizá-lo; mudança de backend exige tarefa própria e novos gates.
- Nenhum secret, `service_role`, senha, chave de IA ou token privado em frontend/Git/log de usuário.
- Toda tabela de negócio exposta usa RLS; autorização material é backend-side.
- Frontend nunca calcula nem atualiza diretamente status críticos.
- `PODE APRESENTAR AO CONTRATANTE` exige 100% dos requisitos obrigatórios/aplicáveis conformes + parecer interno + contexto atual.
- `PODE REAPRESENTAR AO CONTRATANTE` exige 100% dos apontamentos da rodada tratados + reanálise/contexto atual.
- `VALIDADA` somente após parecer final favorável do contratante.
- Documento não é sobrescrito; correção gera nova versão.
- Alteração material após liberação invalida portão e exige nova análise.
- Alerta histórico transversal de outro contrato é informativo e não integra o portão de 100% por si só.
- Regra preventiva material exige fonte/governança e aprovação humana.
- IA sugere/fundamenta; decisão material permanece humana.
- Mensagens de usuário em PT-BR amigável.
- Migration aplicada nunca é reescrita.

## Zero-Drift

Antes de editar, confirme escopo no `docs/tasks/active-task.json`. Não altere caminho proibido nem expanda escopo por conveniência. Database/RLS/Edge/Auth só podem mudar quando explicitamente autorizados. Rode testes, audit diff, Architecture Guard, Context Gate, scan de secrets e CI.
