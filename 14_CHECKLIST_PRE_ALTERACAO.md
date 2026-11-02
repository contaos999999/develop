# ContaOS 4.1 — Checklist Obrigatório Antes de Alterar

Use esta lista antes de qualquer Build. Se uma resposta obrigatória for “não sei”, pare e investigue.

## Contexto
- [ ] Li integralmente `00` a `18` na raiz, incluindo as quatro partes `08A`–`08D` da matriz 96/96.
- [ ] Li integralmente `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` e registrei `brand_01_read_acknowledged = true`.
- [ ] Classifiquei se esta tarefa possui escopo visual/brand. Se possuir, o PROMPT 000 será executado em PLAN → aprovação → BUILD → TESTE.
- [ ] Li `docs/tasks/active-task.json`.
- [ ] Sei quais requisitos 96/96 são impactados.
- [ ] Sei quais telas são impactadas.
- [ ] Sei se a tarefa é HML ou PROD. Durante desenvolvimento, deve ser HML.

## Backend
- [ ] Verifiquei se a capacidade já existe no Supabase antes de criar tabela/RPC/Edge.
- [ ] Não vou criar backend paralelo.
- [ ] Se houver DDL, existe autorização explícita e migration nova.
- [ ] Não vou editar migration aplicada.
- [ ] Se RLS mudar, existe autorização específica.
- [ ] Se Edge/Auth/Storage mudar, existe autorização específica.
- [ ] Se esta for uma tarefa BRAND-01, confirmei que **nenhuma alteração de backend/Supabase é permitida**; necessidade desse tipo será tratada como LACUNA ou CONFLITO.

## Segurança
- [ ] Nenhum secret irá para frontend/Git/log.
- [ ] Tenant/organização/contrato continuam isolados.
- [ ] Autorização existe no backend, não só na UI.
- [ ] Bucket permanece privado.
- [ ] `SECURITY DEFINER` não será usado como atalho.

## Regras de negócio
- [ ] 100% continua sendo portão objetivo, não média.
- [ ] `PODE APRESENTAR AO CONTRATANTE` continua exato.
- [ ] `PODE REAPRESENTAR AO CONTRATANTE` continua exato.
- [ ] `VALIDADA` continua dependente de parecer final favorável.
- [ ] Alteração pós-liberação continua invalidando contexto/portão.
- [ ] Precedente transversal continua não impeditivo por si só.
- [ ] IA continua sem poder de liberação.
- [ ] BRAND-01 não será usado para alterar conteúdo funcional, regra, status, cálculo, fluxo, permissão ou dado.

## Histórico e auditoria
- [ ] Não vou apagar histórico/versionamento.
- [ ] Fontes/evidências continuarão rastreáveis.
- [ ] Evento material continuará auditado.
- [ ] Snapshots/hashes relevantes não serão quebrados.
- [ ] Se houver escopo visual, usarei somente assets oficiais da ContaOS Brand v1.0 e preservarei sua rastreabilidade.

## Performance/RNF
- [ ] Processo pesado continua assíncrono.
- [ ] Listagem grande continua paginada.
- [ ] Comando repetível continua idempotente.
- [ ] Concorrência/stale update continua protegida.

## Frontend
- [ ] Não vou calcular status crítico em React.
- [ ] Não vou usar update genérico de status.
- [ ] Mensagens serão PT-BR amigáveis.
- [ ] Acessibilidade/loading/empty/error/success serão tratados.
- [ ] Não criarei Design System paralelo.
- [ ] Em tarefa visual, vou primeiro mapear tokens existentes e aplicar `REUTILIZAR > ESTENDER > CRIAR`.
- [ ] Em tarefa visual, não vou redesenhar SVG/logo/símbolo oficial nem substituir componente por preferência estética.
- [ ] Em tarefa visual, validarei 1440 / 1280 / 768 / 390 px e dark mode.

## Testes
- [ ] Happy path definido.
- [ ] Teste negativo/perfil definido.
- [ ] RLS A/B quando aplicável.
- [ ] Concorrência/idempotência quando aplicável.
- [ ] Teste de portão quando aplicável.
- [ ] Restore/reprodutibilidade se migration alterar banco.
- [ ] Zero-Drift/Architecture Guard/scan de secrets serão executados.
- [ ] Se BRAND-01 for executado, os 72 itens PASS/FAIL serão avaliados em fase TESTE read-only e o diff será conferido contra os arquivos aprovados no PLAN.

## Declaração
Somente depois de todos os itens aplicáveis acima o Build pode começar.

O PROMPT 000 é transversal e não altera a certificação PRD 96/96. Os prompts 001–096 continuam vinculados aos 96 requisitos explícitos do produto.
