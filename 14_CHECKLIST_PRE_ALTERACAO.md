# ContaOS 4.1 — Checklist Obrigatório Antes de Alterar

Use esta lista antes de qualquer Build. Se uma resposta obrigatória for “não sei”, pare e investigue.

## Contexto
- [ ] Li integralmente `00` a `18` na raiz, incluindo as quatro partes `08A`–`08D` da matriz 96/96.
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

## Histórico e auditoria
- [ ] Não vou apagar histórico/versionamento.
- [ ] Fontes/evidências continuarão rastreáveis.
- [ ] Evento material continuará auditado.
- [ ] Snapshots/hashes relevantes não serão quebrados.

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

## Testes
- [ ] Happy path definido.
- [ ] Teste negativo/perfil definido.
- [ ] RLS A/B quando aplicável.
- [ ] Concorrência/idempotência quando aplicável.
- [ ] Teste de portão quando aplicável.
- [ ] Restore/reprodutibilidade se migration alterar banco.
- [ ] Zero-Drift/Architecture Guard/scan de secrets serão executados.

## Declaração
Somente depois de todos os itens aplicáveis acima o Build pode começar.
