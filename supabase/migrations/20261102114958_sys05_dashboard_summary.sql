create or replace function public.obter_resumo_dashboard(p_id_organizacao uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_organizacao jsonb;
  v_resumo jsonb;
  v_contratos_por_situacao jsonb;
  v_competencias_por_situacao jsonb;
  v_proximos_prazos jsonb;
  v_atencoes_prioritarias jsonb;
begin
  if auth.uid() is null
     or not privado.usuario_tem_acesso_organizacao(p_id_organizacao) then
    raise exception using
      errcode = '42501',
      message = 'Acesso negado ao resumo desta organização.';
  end if;

  select jsonb_build_object(
           'id', o.id,
           'razao_social', o.razao_social,
           'nome_fantasia', o.nome_fantasia,
           'situacao', o.situacao
         )
    into v_organizacao
    from public.organizacoes o
   where o.id = p_id_organizacao;

  if v_organizacao is null then
    raise exception using
      errcode = '42501',
      message = 'Acesso negado ao resumo desta organização.';
  end if;

  select jsonb_build_object(
    'contratos_visiveis', (select count(*) from public.contratos c where c.id_organizacao = p_id_organizacao),
    'contratos_ativos', (select count(*) from public.contratos c where c.id_organizacao = p_id_organizacao and c.situacao = 'ativo'),
    'competencias_em_fluxo', (select count(*) from public.competencias c where c.id_organizacao = p_id_organizacao and c.situacao not in ('validada','encerrada','cancelada')),
    'competencias_exigem_atencao', (select count(*) from public.competencias c where c.id_organizacao = p_id_organizacao and c.situacao in ('pendente_correcao','com_apontamentos')),
    'itens_com_prazo_vencido',
      (select count(*) from public.competencias c where c.id_organizacao = p_id_organizacao and c.data_limite is not null and c.data_limite < (now() at time zone 'America/Sao_Paulo')::date and c.situacao not in ('validada','encerrada','cancelada'))
      + (select count(*) from public.tarefas_diligencia t where t.id_organizacao = p_id_organizacao and t.prazo is not null and t.prazo < (now() at time zone 'America/Sao_Paulo')::date and t.status in ('pendente','em_execucao'))
      + (select count(*) from public.nao_conformidades n where n.id_organizacao = p_id_organizacao and n.prazo is not null and n.prazo < (now() at time zone 'America/Sao_Paulo')::date and n.status in ('aberta','em_analise','em_remediacao')),
    'atencoes_abertas',
      (select count(*) from public.apontamentos_internos a where a.id_organizacao = p_id_organizacao and a.status in ('aberto','em_tratamento'))
      + (select count(*) from public.apontamentos_contratante a where a.id_organizacao = p_id_organizacao and a.status in ('aberto','em_analise','procedente','em_tratamento','contestado','contestado_aprovado'))
      + (select count(*) from public.nao_conformidades n where n.id_organizacao = p_id_organizacao and n.status in ('aberta','em_analise','em_remediacao'))
  ) into v_resumo;

  select coalesce(jsonb_agg(jsonb_build_object('situacao', x.situacao, 'quantidade', x.quantidade) order by x.situacao),'[]'::jsonb)
    into v_contratos_por_situacao
    from (select c.situacao, count(*)::bigint as quantidade from public.contratos c where c.id_organizacao = p_id_organizacao group by c.situacao) x;

  select coalesce(jsonb_agg(jsonb_build_object('situacao', x.situacao, 'quantidade', x.quantidade) order by x.situacao),'[]'::jsonb)
    into v_competencias_por_situacao
    from (select c.situacao, count(*)::bigint as quantidade from public.competencias c where c.id_organizacao = p_id_organizacao group by c.situacao) x;

  select coalesce(jsonb_agg(to_jsonb(x) - 'ordem_criticidade' order by x.prazo asc, x.ordem_criticidade desc, x.tipo, x.id),'[]'::jsonb)
    into v_proximos_prazos
    from (
      select * from (
        select 'competencia'::text as tipo, c.id, c.id_contrato, ct.numero as contrato_numero,
               ('Competência ' || pg_catalog.to_char(c.competencia_referencia, 'MM/YYYY'))::text as titulo,
               c.data_limite as prazo, c.situacao as status, ct.criticidade as criticidade,
               case ct.criticidade when 'critica' then 4 when 'alta' then 3 when 'media' then 2 else 1 end as ordem_criticidade
          from public.competencias c join public.contratos ct on ct.id = c.id_contrato
         where c.id_organizacao = p_id_organizacao and c.data_limite is not null and c.situacao not in ('validada','encerrada','cancelada')
        union all
        select 'tarefa_diligencia'::text, t.id, t.id_contrato, ct.numero, pg_catalog.left(t.descricao, 180), t.prazo, t.status, t.prioridade,
               case t.prioridade when 'critica' then 4 when 'alta' then 3 when 'media' then 2 else 1 end
          from public.tarefas_diligencia t join public.contratos ct on ct.id = t.id_contrato
         where t.id_organizacao = p_id_organizacao and t.prazo is not null and t.status in ('pendente','em_execucao')
        union all
        select 'nao_conformidade'::text, n.id, n.id_contrato, ct.numero, pg_catalog.left(n.descricao, 180), n.prazo, n.status, n.severidade,
               case n.severidade when 'critica' then 4 when 'alta' then 3 when 'media' then 2 else 1 end
          from public.nao_conformidades n left join public.contratos ct on ct.id = n.id_contrato
         where n.id_organizacao = p_id_organizacao and n.prazo is not null and n.status in ('aberta','em_analise','em_remediacao')
      ) z order by z.prazo asc, z.ordem_criticidade desc, z.tipo, z.id limit 8
    ) x;

  select coalesce(jsonb_agg(to_jsonb(x) - 'ordem_severidade' order by x.ordem_severidade desc, x.criado_em desc, x.tipo, x.id),'[]'::jsonb)
    into v_atencoes_prioritarias
    from (
      select * from (
        select 'apontamento_interno'::text as tipo, a.id, a.id_contrato, ct.numero as contrato_numero, a.id_competencia,
               pg_catalog.left(a.descricao, 220) as descricao, a.severidade, a.status, null::date as prazo, a.criado_em,
               case a.severidade when 'critica' then 5 when 'alta' then 4 when 'media' then 3 when 'baixa' then 2 else 1 end as ordem_severidade
          from public.apontamentos_internos a join public.contratos ct on ct.id = a.id_contrato
         where a.id_organizacao = p_id_organizacao and a.status in ('aberto','em_tratamento')
        union all
        select 'apontamento_contratante'::text, a.id, a.id_contrato, ct.numero, a.id_competencia,
               pg_catalog.left(a.descricao, 220), a.severidade, a.status, null::date, a.criado_em,
               case a.severidade when 'critica' then 5 when 'alta' then 4 when 'media' then 3 when 'baixa' then 2 else 1 end
          from public.apontamentos_contratante a join public.contratos ct on ct.id = a.id_contrato
         where a.id_organizacao = p_id_organizacao and a.status in ('aberto','em_analise','procedente','em_tratamento','contestado','contestado_aprovado')
        union all
        select 'nao_conformidade'::text, n.id, n.id_contrato, ct.numero, n.id_competencia,
               pg_catalog.left(n.descricao, 220), n.severidade, n.status, n.prazo, n.criado_em,
               case n.severidade when 'critica' then 5 when 'alta' then 4 when 'media' then 3 when 'baixa' then 2 else 1 end
          from public.nao_conformidades n left join public.contratos ct on ct.id = n.id_contrato
         where n.id_organizacao = p_id_organizacao and n.status in ('aberta','em_analise','em_remediacao')
      ) z order by z.ordem_severidade desc, z.criado_em desc, z.tipo, z.id limit 8
    ) x;

  return jsonb_build_object(
    'schema_versao', 'sys05-v1',
    'gerado_em', public.formatar_data_hora_br(now()),
    'organizacao', v_organizacao,
    'resumo', v_resumo,
    'contratos_por_situacao', v_contratos_por_situacao,
    'competencias_por_situacao', v_competencias_por_situacao,
    'proximos_prazos', v_proximos_prazos,
    'atencoes_prioritarias', v_atencoes_prioritarias
  );
end;
$$;

revoke all on function public.obter_resumo_dashboard(uuid) from public;
revoke all on function public.obter_resumo_dashboard(uuid) from anon;
grant execute on function public.obter_resumo_dashboard(uuid) to authenticated, service_role;

comment on function public.obter_resumo_dashboard(uuid) is
'SYS-05: resumo operacional read-only da organização selecionada. SECURITY INVOKER preserva RLS por organização/contrato; não substitui o Painel Executivo 5.0 do PROMPT 88.';
