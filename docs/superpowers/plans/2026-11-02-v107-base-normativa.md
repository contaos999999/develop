# V1-07 backend normativo — plano de implementação

> Execução: superpowers:executing-plans, em branch isolada; revisão independente antes de integração.

Objetivo: fechar exclusivamente a lacuna autorizada em #25, mantendo o backend Supabase como autoridade.
Spec: pacote4.1, 08A requisitos001/002/004/005, diagnóstico docs/frontend/V107_BASE_NORMATIVA_2026-11-02.md e autorização «autorizo».

## Contrato e limites

- HML gklhhhyosgasnyoxlrui; PROD intocado. Sem tabela, Edge, Auth ou Storage novos.
- Quatro comandos públicos SECURITY INVOKER, implementação privada SECURITY DEFINER search_path vazio, auth.uid/sessão/perfil/escopo reais. CRUD de fonte/versão: administrador, gestor_contrato, juridico_conformidade. Aprovação material: administrador ou direcao_aprovador. Master equivale apenas a administrador.
- salvar_fonte_normativa_v107(org,contrato,fonte nullable,tipo,titulo,referencia,descricao,situacao,versao_esperada,chave) retorna fonte ecorrelation_id. Escopo estrutural imutável, criação rascunho; ativação requer versão aprovada. Alteração material de situação exige perfil aprovador. Versão otimista incrementa uma vez, touch específico apenas timestamp.
- registrar_versao_fonte_v107(org,fonte,inicio,fim,arquivo nullable,texto nullable,metadados,chave) retorna versão imutável não aprovada, numeração pelo backend sob lock da fonte, hash SHA256 canônico do conteúdo+arquivo/vigência/metadados. Pelo menos arquivo ou texto; arquivo no mesmo org/escopo, seguro; vigência inicial obrigatória e fim>=início.
- aprovar_versao_fonte_v107(org,versao,hash_esperado,fundamento,chave) confere conteúdo/vigência/hash, ator/data backend, auditoria única. Não ativa regra preventiva nem promove histórico transversal.
- definir_aplicabilidade_fonte_v107(org,contrato,versao,aplicavel,fundamento,atualizado_em_esperado nullable,chave) exige versão aprovada, mesma org, fonte global ou do próprio contrato, escopo real e perfil aprovador; optimistic timestamp CAS, criação espera null. Aprovação humana explícita com fundamento, ator/data backend.
- Todo replay verifica autorização atual e escopo antes do cache. Chave escopada por org+comando+usuário, payload divergente PT409, resposta/evento únicos; usar comandos_idempotentes existente e locks transacionais. Sem SQL dinâmico.
- Revogar somente DML authenticated das três tabelas para impedir bypass de aprovação/auditoria; SELECT/RLS preservados. Não alterar políticas de leitura. Todas mutações necessárias passam pelos comandos oficiais.
- Mudanças normativas relevantes invalidam competências liberadas por helper certificado; snapshot inclui versões aprovadas vigentes de fontes ativas e aplicáveis ao contrato, sem histórico transversal ou rascunho. Manter todas as chaves existentes do snapshot.
- Texto pesado só sob demanda; frontend não recebe campo aprovado_por/em como entrada.

## Arquivos

- supabase/migrations/20261102213512_v107_base_normativa_autorizada.sql (nome criado peloCLI2.108.0)
- supabase/tests/v107_base_normativa.sql
- docs/backend/V107_BASE_NORMATIVA_2026-11-02.md
- docs/tasks/active-task.json
- docs/superpowers/plans/2026-11-02-v107-base-normativa.md

## Execução e evidências

- [ ] Criar testes de comportamento com fixtures sintéticas BEGIN/ROLLBACK: criação/edição+1, obsoleto409, versões sequenciais/imutáveis, vigência/hash, aprovação e aplicabilidade, tenant/contrato/leitor/anon/sessão expirada, Master, replay e mudança de payload, auditoria única, bypass DML, invalidação/hash material e não influência de fonte sem aplicação.
- [ ] Executar RED antes deDDL e registrar ausência real dos comandos/controles.
- [ ] Implementar migration sem reescrever histórico, executar focused GREEN; corrigir somente por migrations compensatórias se já aplicada.
- [ ] Revisão independente; regressão SQL pertinente, Advisor security, ContextGate/ZeroDrift/ArchitectureGuard/SQLguard/secrets.
- [ ] PR, CI, integração autorizada e restore limpo automático; sem certificar até todos gates passarem.
- [ ] Registrar contrato/evidências GitHub e só então corrigir PLAN28 noLovable, BUILD, testes completos e TesteC separado18/18.

## Pontos de revisão

Replays após revogação de acesso; fonte global com arquivo privado de outro contrato; alteração de aplicabilidade concorrente; aprovação preserva bytes/versão; mudança de norma fora da vigência não introduz requisito impeditivo. Testes específicos cobrem cada ponto.

