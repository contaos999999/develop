-- ContaOS 4.1 — V1-16 Competência: análise
-- Leitura agregada, paginada e autoritativa para o frontend.
-- Não cria/classifica resultados, não altera portão e não executa IA.

create or replace function public.obter_analise_competencia_v116(
  p_id_competencia uuid,
  p_resultados_offset integer default 0,
  p_resultados_limite integer default 25,
  p_execucoes_offset integer default 0,
  p_execucoes_limite integer default 10,
  p_apontamentos_offset integer default 0,
  p_apontamentos_limite integer default 25,
  p_filtro_resultado text default null,
  p_filtro_criticidade text default null,
  p_filtro_mecanismo text default null,
  p_filtro_apontamento_status text default null,
  p_busca text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_comp public.competencias%rowtype;
  v_exec public.execucoes_analise%rowtype;
  v_hash_atual text;
  v_portao jsonb;
  v_estado text;
  v_stale boolean := false;
  v_perfil_analise boolean := false;
  v_situacao_permite boolean := false;
  v_busy boolean := false;
  v_resultados jsonb := '[]'::jsonb;
  v_resultados_total integer := 0;
  v_execucoes jsonb := '[]'::jsonb;
  v_execucoes_total integer := 0;
  v_apontamentos jsonb := '[]'::jsonb;
  v_apontamentos_total integer := 0;
  v_mecanismos jsonb := '{}'::jsonb;
  v_busca text := nullif(trim(coalesce(p_busca,'')), '');
begin
  if p_id_competencia is null then
    raise exception using errcode='PT400', message='Informe a competência para consultar a análise.';
  end if;
  if p_resultados_offset < 0 or p_execucoes_offset < 0 or p_apontamentos_offset < 0
     or p_resultados_limite < 1 or p_resultados_limite > 100
     or p_execucoes_limite < 1 or p_execucoes_limite > 50
     or p_apontamentos_limite < 1 or p_apontamentos_limite > 100 then
    raise exception using errcode='PT400', message='Os parâmetros de paginação informados não são válidos.';
  end if;
  if p_filtro_mecanismo is not null and p_filtro_mecanismo not in ('deterministico','semantico','humano','nao_identificado') then
    raise exception using errcode='PT400', message='O filtro de mecanismo não é válido.';
  end if;
  if p_filtro_criticidade is not null and p_filtro_criticidade not in ('critica','alta','media','baixa','informativo') then
    raise exception using errcode='PT400', message='O filtro de criticidade não é válido.';
  end if;
  if p_filtro_resultado is not null and p_filtro_resultado not in (
    'nao_enviado','recebido','pendente','em_analise','conforme','nao_conforme','inconclusivo','requer_revisao','nao_aplicavel'
  ) then
    raise exception using errcode='PT400', message='O filtro de resultado não é válido.';
  end if;
  if p_filtro_apontamento_status is not null and p_filtro_apontamento_status not in ('aberto','em_tratamento','resolvido','descartado') then
    raise exception using errcode='PT400', message='O filtro de apontamento não é válido.';
  end if;

  select * into v_comp
  from public.competencias
  where id = p_id_competencia;

  if v_comp.id is null then
    raise exception using errcode='PT404', message='Não encontramos a competência informada.';
  end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato) then
    raise exception using errcode='42501', message='Você não possui acesso à competência informada.';
  end if;

  v_perfil_analise := privado.usuario_possui_perfil(
    v_comp.id_organizacao,
    array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]
  );
  if not v_perfil_analise then
    raise exception using errcode='42501', message='Seu perfil atual não permite consultar a análise desta competência.';
  end if;

  select * into v_exec
  from public.execucoes_analise
  where id_competencia = v_comp.id
  order by criado_em desc, id desc
  limit 1;

  v_hash_atual := privado.hash_contexto_competencia(v_comp.id);
  v_portao := privado.avaliar_portao_conformidade(v_comp.id);
  v_situacao_permite := v_comp.situacao not in ('apresentado','aguardando_contratante','validada','encerrada','cancelada');
  v_busy := v_exec.id is not null and v_exec.status in ('pendente','processando');

  if v_exec.id is null then
    v_estado := 'not_analyzed';
  elsif v_exec.status = 'pendente' then
    v_estado := 'queued';
  elsif v_exec.status = 'processando' then
    v_estado := 'processing';
  elsif v_exec.status in ('falhou','cancelada') then
    v_estado := 'failed';
  elsif v_exec.status = 'concluida' then
    v_stale := v_exec.hash_entrada is null or v_exec.hash_entrada <> v_hash_atual;
    v_estado := case when v_stale then 'stale' else 'complete' end;
  else
    v_estado := 'failed';
  end if;

  -- Histórico de execuções: preserva cada rodada e informa se o contexto ainda coincide.
  select count(*)::integer into v_execucoes_total
  from public.execucoes_analise e
  where e.id_competencia = v_comp.id;

  select coalesce(jsonb_agg(x.obj order by x.criado_em desc, x.id desc), '[]'::jsonb)
    into v_execucoes
  from (
    select e.id, e.criado_em,
      jsonb_build_object(
        'id',e.id,
        'tipo',e.tipo,
        'status',e.status,
        'hash_entrada',e.hash_entrada,
        'contexto_atual',coalesce(e.hash_entrada = v_hash_atual,false),
        'motor',e.motor,
        'versao_motor',e.versao_motor,
        'provedor',e.provedor,
        'modelo',e.modelo,
        'prompt_versao',e.prompt_versao,
        'iniciada_por',e.iniciada_por,
        'iniciada_em',e.iniciada_em,
        'concluida_em',e.concluida_em,
        'erro_codigo',e.erro_codigo,
        'requisitos_afetados',coalesce(to_jsonb(e.requisitos_afetados),'[]'::jsonb),
        'metadados',coalesce(e.metadados,'{}'::jsonb),
        'criado_em',e.criado_em
      ) obj
    from public.execucoes_analise e
    where e.id_competencia = v_comp.id
    order by e.criado_em desc, e.id desc
    offset p_execucoes_offset limit p_execucoes_limite
  ) x;

  if v_exec.id is not null then
    -- Resultado consolidado por requisito; mecanismo só é classificado quando há marca objetiva.
    with base as (
      select rr.*, r.codigo, r.descricao, r.categoria, r.criticidade, r.obrigatorio, r.aplicavel,
             r.impeditivo, r.efeito_portao, r.fonte_tipo, r.fonte_referencia, r.fonte_detalhe,
             case
               when rr.metadados->>'origem' = 'revisao_humana' then 'humano'
               when rr.metadados->>'mecanismo' in ('deterministico','semantico','humano') then rr.metadados->>'mecanismo'
               when nullif(rr.metadados->>'provedor','') is not null then 'semantico'
               when nullif(v_exec.provedor,'') is not null and rr.metadados->>'origem' is null then 'semantico'
               else 'nao_identificado'
             end mecanismo
      from public.resultados_requisitos rr
      join public.requisitos_competencia r on r.id = rr.id_requisito
      where rr.id_execucao = v_exec.id
    ), filtrado as (
      select * from base b
      where (p_filtro_resultado is null or b.resultado = p_filtro_resultado)
        and (p_filtro_criticidade is null or b.criticidade = p_filtro_criticidade)
        and (p_filtro_mecanismo is null or b.mecanismo = p_filtro_mecanismo)
        and (v_busca is null or b.codigo ilike '%'||v_busca||'%' or b.descricao ilike '%'||v_busca||'%')
    ), pagina as (
      select * from filtrado
      order by codigo nulls last, id_requisito, criado_em desc, id desc
      offset p_resultados_offset limit p_resultados_limite
    ), ev as (
      select e.id_resultado,
             jsonb_agg(jsonb_build_object(
               'id',e.id,
               'id_versao_documento',e.id_versao_documento,
               'pagina',e.pagina,
               'trecho',e.trecho,
               'tipo_evidencia',e.tipo_evidencia,
               'referencia_externa',e.referencia_externa,
               'hash',e.hash,
               'criado_em',e.criado_em
             ) order by e.criado_em,e.id) evidencias
      from public.evidencias_resultado e
      join pagina p on p.id = e.id_resultado
      group by e.id_resultado
    )
    select
      (select count(*)::integer from filtrado),
      coalesce((select jsonb_agg(jsonb_build_object(
        'id_resultado',p.id,
        'id_requisito',p.id_requisito,
        'requisito',jsonb_build_object(
          'codigo',p.codigo,'descricao',p.descricao,'categoria',p.categoria,'criticidade',p.criticidade,
          'obrigatorio',p.obrigatorio,'aplicavel',p.aplicavel,'impeditivo',p.impeditivo,'efeito_portao',p.efeito_portao,
          'fonte_tipo',p.fonte_tipo,'fonte_referencia',p.fonte_referencia,'fonte_detalhe',p.fonte_detalhe
        ),
        'resultado',p.resultado,
        'mecanismo',p.mecanismo,
        'confianca',p.confianca,
        'justificativa',p.justificativa,
        'fundamento',p.fundamento,
        'hash_evidencias',p.hash_evidencias,
        'metadados',coalesce(p.metadados,'{}'::jsonb),
        'evidencias',coalesce(ev.evidencias,'[]'::jsonb),
        'criado_em',p.criado_em
      ) order by p.codigo nulls last,p.id_requisito,p.criado_em desc,p.id desc)
      from pagina p left join ev on ev.id_resultado=p.id), '[]'::jsonb)
    into v_resultados_total, v_resultados;

    with b as (
      select case
        when rr.metadados->>'origem'='revisao_humana' then 'humano'
        when rr.metadados->>'mecanismo' in ('deterministico','semantico','humano') then rr.metadados->>'mecanismo'
        when nullif(rr.metadados->>'provedor','') is not null then 'semantico'
        when nullif(v_exec.provedor,'') is not null and rr.metadados->>'origem' is null then 'semantico'
        else 'nao_identificado' end mecanismo
      from public.resultados_requisitos rr where rr.id_execucao=v_exec.id
    )
    select jsonb_build_object(
      'deterministico',count(*) filter(where mecanismo='deterministico'),
      'semantico',count(*) filter(where mecanismo='semantico'),
      'humano',count(*) filter(where mecanismo='humano'),
      'nao_identificado',count(*) filter(where mecanismo='nao_identificado')
    ) into v_mecanismos from b;
  end if;

  select count(*)::integer into v_apontamentos_total
  from public.apontamentos_internos a
  left join public.requisitos_competencia r on r.id=a.id_requisito
  where a.id_competencia=v_comp.id
    and (p_filtro_apontamento_status is null or a.status=p_filtro_apontamento_status)
    and (p_filtro_criticidade is null or a.severidade=p_filtro_criticidade)
    and (v_busca is null or a.descricao ilike '%'||v_busca||'%' or coalesce(r.codigo,'') ilike '%'||v_busca||'%' or coalesce(r.descricao,'') ilike '%'||v_busca||'%');

  select coalesce(jsonb_agg(x.obj order by x.criado_em desc,x.id desc),'[]'::jsonb)
    into v_apontamentos
  from (
    select a.id,a.criado_em,jsonb_build_object(
      'id',a.id,
      'id_requisito',a.id_requisito,
      'requisito',case when r.id is null then null else jsonb_build_object('codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria,'criticidade',r.criticidade) end,
      'descricao',a.descricao,
      'severidade',a.severidade,
      'status',a.status,
      'origem',a.origem,
      'regra_violada',a.regra_violada,
      'acao_sugerida',a.acao_sugerida,
      'fonte',coalesce(a.fonte,'{}'::jsonb),
      'criado_em',a.criado_em,
      'atualizado_em',a.atualizado_em
    ) obj
    from public.apontamentos_internos a
    left join public.requisitos_competencia r on r.id=a.id_requisito
    where a.id_competencia=v_comp.id
      and (p_filtro_apontamento_status is null or a.status=p_filtro_apontamento_status)
      and (p_filtro_criticidade is null or a.severidade=p_filtro_criticidade)
      and (v_busca is null or a.descricao ilike '%'||v_busca||'%' or coalesce(r.codigo,'') ilike '%'||v_busca||'%' or coalesce(r.descricao,'') ilike '%'||v_busca||'%')
    order by a.criado_em desc,a.id desc
    offset p_apontamentos_offset limit p_apontamentos_limite
  ) x;

  return jsonb_build_object(
    'schema_versao','v116-v1',
    'competencia',jsonb_build_object(
      'id',v_comp.id,
      'id_organizacao',v_comp.id_organizacao,
      'id_contrato',v_comp.id_contrato,
      'competencia_referencia',v_comp.competencia_referencia,
      'periodo_inicio',v_comp.periodo_inicio,
      'periodo_fim',v_comp.periodo_fim,
      'situacao',v_comp.situacao
    ),
    'estado_analise',v_estado,
    'stale',v_stale,
    'hash_contexto_atual',v_hash_atual,
    'execucao_atual',case when v_exec.id is null then null else jsonb_build_object(
      'id',v_exec.id,'tipo',v_exec.tipo,'status',v_exec.status,'hash_entrada',v_exec.hash_entrada,
      'motor',v_exec.motor,'versao_motor',v_exec.versao_motor,'provedor',v_exec.provedor,'modelo',v_exec.modelo,
      'prompt_versao',v_exec.prompt_versao,'iniciada_por',v_exec.iniciada_por,'iniciada_em',v_exec.iniciada_em,
      'concluida_em',v_exec.concluida_em,'erro_codigo',v_exec.erro_codigo,
      'requisitos_afetados',coalesce(to_jsonb(v_exec.requisitos_afetados),'[]'::jsonb),'metadados',coalesce(v_exec.metadados,'{}'::jsonb),
      'criado_em',v_exec.criado_em
    ) end,
    'percentual',coalesce((v_portao->>'percentual')::numeric,0),
    'blocking_summary',v_portao,
    'allowed_actions',jsonb_build_object(
      'executar_analise',v_perfil_analise and v_situacao_permite and not v_busy and (v_exec.id is null or v_exec.status in ('falhou','cancelada')),
      'reanalisar',v_perfil_analise and v_situacao_permite and not v_busy and v_exec.id is not null and v_exec.status='concluida',
      'abrir_requisito',v_exec.id is not null
    ),
    'mecanismos',coalesce(v_mecanismos,'{}'::jsonb),
    'resultados',v_resultados,
    'resultados_paginacao',jsonb_build_object('offset',p_resultados_offset,'limite',p_resultados_limite,'total',v_resultados_total),
    'execucoes',v_execucoes,
    'execucoes_paginacao',jsonb_build_object('offset',p_execucoes_offset,'limite',p_execucoes_limite,'total',v_execucoes_total),
    'apontamentos',v_apontamentos,
    'apontamentos_paginacao',jsonb_build_object('offset',p_apontamentos_offset,'limite',p_apontamentos_limite,'total',v_apontamentos_total)
  );
end;
$function$;

revoke all on function public.obter_analise_competencia_v116(uuid,integer,integer,integer,integer,integer,integer,text,text,text,text,text) from public;
revoke all on function public.obter_analise_competencia_v116(uuid,integer,integer,integer,integer,integer,integer,text,text,text,text,text) from anon;
grant execute on function public.obter_analise_competencia_v116(uuid,integer,integer,integer,integer,integer,integer,text,text,text,text,text) to authenticated;

comment on function public.obter_analise_competencia_v116(uuid,integer,integer,integer,integer,integer,integer,text,text,text,text,text)
is 'V1-16: leitura agregada read-only da análise da competência. Stale, bloqueios, paginação e allowed_actions são autoritativos do backend; não cria nem classifica resultados.';
