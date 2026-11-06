-- ContaOS 4.1 V1-17 B1. Contrato de leitura do detalhe de requisito.
-- Acesso: usuario autenticado + contrato + perfil, sem escrita e sem URL de storage.
create function public.obter_detalhe_requisito_v117(
  p_id_competencia uuid,
  p_id_requisito uuid,
  p_evidencias_offset integer default 0,
  p_evidencias_limite integer default 25,
  p_historico_offset integer default 0,
  p_historico_limite integer default 25,
  p_apontamentos_offset integer default 0,
  p_apontamentos_limite integer default 25
)
returns jsonb language plpgsql stable security definer set search_path = ''
as $v117$
declare
  v_comp public.competencias%rowtype;
  v_req public.requisitos_competencia%rowtype;
  v_exec public.execucoes_analise%rowtype;
  v_atual public.resultados_requisitos%rowtype;
  v_ultimo public.resultados_requisitos%rowtype;
  v_na_valido boolean;
  v_evidencias jsonb := '[]'::jsonb;
  v_historico jsonb := '[]'::jsonb;
  v_apontamentos jsonb := '[]'::jsonb;
  v_evidencias_total integer := 0;
  v_historico_total integer := 0;
  v_apontamentos_total integer := 0;
  v_capacidades jsonb;
  v_mecanismo text;
begin
  if p_id_competencia is null or p_id_requisito is null then
    raise exception using errcode='PT400', message='Informe a competência e o requisito.';
  end if;
  if p_evidencias_offset is null or p_historico_offset is null or p_apontamentos_offset is null
    or p_evidencias_limite is null or p_historico_limite is null or p_apontamentos_limite is null
    or p_evidencias_offset < 0 or p_historico_offset < 0 or p_apontamentos_offset < 0
    or p_evidencias_limite not between 1 and 100 or p_historico_limite not between 1 and 100
    or p_apontamentos_limite not between 1 and 100 then
    raise exception using errcode='PT400', message='Paginação inválida para o detalhe do requisito.';
  end if;
  if auth.uid() is null then
    raise exception using errcode='42501',message='Você não possui acesso a este requisito.';
  end if;
  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then
    raise exception using errcode='PT404',message='Requisito não encontrado.';
  end if;
  if not privado.usuario_tem_acesso_contrato(v_comp.id_contrato)
    or not privado.usuario_possui_perfil(
      v_comp.id_organizacao,
      array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]
    ) then
    raise exception using errcode='42501',message='Você não possui acesso a este requisito.';
  end if;
  select * into v_req from public.requisitos_competencia
  where id=p_id_requisito and id_competencia=v_comp.id
    and id_contrato=v_comp.id_contrato and id_organizacao=v_comp.id_organizacao;
  if v_req.id is null then
    raise exception using errcode='PT404',message='Requisito não encontrado.';
  end if;
  -- Fonte única para capacidades; não duplicar regras de análise do V1-16.
  v_capacidades := (public.obter_analise_competencia_v116(
    v_comp.id,0,1,0,1,0,1,null,null,null,null,null
  ))->'allowed_actions';
  select * into v_exec from public.execucoes_analise e
    where e.id_competencia=v_comp.id and e.id_contrato=v_comp.id_contrato
      and e.id_organizacao=v_comp.id_organizacao
    order by e.criado_em desc,e.id desc limit 1;
  if v_exec.id is not null then
    select * into v_atual from public.resultados_requisitos rr
      where rr.id_execucao=v_exec.id and rr.id_requisito=v_req.id
        and rr.id_competencia=v_comp.id and rr.id_contrato=v_comp.id_contrato
        and rr.id_organizacao=v_comp.id_organizacao
      order by rr.criado_em desc,rr.id desc limit 1;
  end if;
  -- Referencia do portão = último resultado daquele requisito em qualquer execução.
  select * into v_ultimo from public.resultados_requisitos rr
    where rr.id_requisito=v_req.id and rr.id_competencia=v_comp.id
      and rr.id_contrato=v_comp.id_contrato and rr.id_organizacao=v_comp.id_organizacao
    order by rr.criado_em desc,rr.id desc limit 1;
  v_na_valido := v_ultimo.id is not null and v_ultimo.resultado='nao_aplicavel'
    and nullif(trim(coalesce(v_ultimo.fundamento,'')),'') is not null
    and exists (select 1 from public.evidencias_resultado ev
      where ev.id_resultado=v_ultimo.id and ev.id_competencia=v_comp.id
        and ev.id_contrato=v_comp.id_contrato and ev.id_organizacao=v_comp.id_organizacao);
  if v_ultimo.id is not null then
    v_mecanismo := case
      when v_ultimo.metadados->>'origem'='revisao_humana' then 'humano'
      when v_ultimo.metadados->>'mecanismo' in ('deterministico','semantico','humano')
        then v_ultimo.metadados->>'mecanismo'
      when nullif(v_ultimo.metadados->>'provedor','') is not null then 'semantico'
      when exists (select 1 from public.execucoes_analise ee where ee.id=v_ultimo.id_execucao
        and nullif(ee.provedor,'') is not null and v_ultimo.metadados->>'origem' is null)
        then 'semantico'
      else 'nao_identificado'
    end;
    select count(*)::integer into v_evidencias_total
      from public.evidencias_resultado ev where ev.id_resultado=v_ultimo.id
        and ev.id_competencia=v_comp.id and ev.id_contrato=v_comp.id_contrato
        and ev.id_organizacao=v_comp.id_organizacao;
    select coalesce(jsonb_agg(q.obj order by q.criado_em,q.id),'[]'::jsonb)
    into v_evidencias from (
      select ev.id,ev.criado_em,
        jsonb_build_object(
          'id',ev.id,'id_resultado',ev.id_resultado,
          'id_versao_documento',ev.id_versao_documento,
          'pagina',ev.pagina,'trecho',ev.trecho,'tipo_evidencia',ev.tipo_evidencia,
          'referencia_externa',ev.referencia_externa,'hash',ev.hash,'criado_em',ev.criado_em,
          'documento',case when vd.id is null then null else jsonb_build_object(
            'id_versao_documento',vd.id,'numero_versao',vd.numero_versao,
            'hash_versao',vd.hash,'id_arquivo',a.id,
            'nome_original',a.nome_original,'mime',a.mime,'status_seguranca',a.status_seguranca
          ) end
        ) obj
      from public.evidencias_resultado ev
      left join public.versoes_documento vd on vd.id=ev.id_versao_documento
        and vd.id_contrato=v_comp.id_contrato and vd.id_organizacao=v_comp.id_organizacao
      left join public.arquivos a on a.id=vd.id_arquivo
        and a.id_organizacao=v_comp.id_organizacao and a.id_contrato=v_comp.id_contrato
      where ev.id_resultado=v_ultimo.id and ev.id_competencia=v_comp.id
        and ev.id_contrato=v_comp.id_contrato and ev.id_organizacao=v_comp.id_organizacao
      order by ev.criado_em,ev.id offset p_evidencias_offset limit p_evidencias_limite
    ) q;
  end if;
  select count(*)::integer into v_historico_total
    from public.resultados_requisitos rr join public.execucoes_analise ee on ee.id=rr.id_execucao
      and ee.id_competencia=v_comp.id and ee.id_contrato=v_comp.id_contrato
      and ee.id_organizacao=v_comp.id_organizacao
    where rr.id_requisito=v_req.id and rr.id_competencia=v_comp.id
      and rr.id_contrato=v_comp.id_contrato and rr.id_organizacao=v_comp.id_organizacao;
  select coalesce(jsonb_agg(q.obj order by q.exec_criado desc,q.exec_id desc,q.res_criado desc,q.res_id desc),'[]'::jsonb)
  into v_historico from (
    select rr.id res_id,rr.criado_em res_criado,ee.id exec_id,ee.criado_em exec_criado,
      jsonb_build_object(
        'id_resultado',rr.id,'id_execucao',ee.id,'resultado',rr.resultado,
        'confianca',rr.confianca,'fundamento',rr.fundamento,'justificativa',rr.justificativa,
        'hash_evidencias',rr.hash_evidencias,'criado_em',rr.criado_em,
        'tipo_execucao',ee.tipo,'status_execucao',ee.status,
        'motor',ee.motor,'versao_motor',ee.versao_motor,'provedor',ee.provedor,
        'modelo',ee.modelo,'prompt_versao',ee.prompt_versao,'hash_entrada',ee.hash_entrada,
        'iniciada_em',ee.iniciada_em,'concluida_em',ee.concluida_em,
        'mecanismo',case
          when rr.metadados->>'origem'='revisao_humana' then 'humano'
          when rr.metadados->>'mecanismo' in ('deterministico','semantico','humano') then rr.metadados->>'mecanismo'
          when nullif(rr.metadados->>'provedor','') is not null then 'semantico'
          when nullif(ee.provedor,'') is not null and rr.metadados->>'origem' is null then 'semantico'
          else 'nao_identificado' end
      ) obj
    from public.resultados_requisitos rr join public.execucoes_analise ee
      on ee.id=rr.id_execucao and ee.id_competencia=v_comp.id
      and ee.id_contrato=v_comp.id_contrato and ee.id_organizacao=v_comp.id_organizacao
    where rr.id_requisito=v_req.id and rr.id_competencia=v_comp.id
      and rr.id_contrato=v_comp.id_contrato and rr.id_organizacao=v_comp.id_organizacao
    order by ee.criado_em desc,ee.id desc,rr.criado_em desc,rr.id desc
    offset p_historico_offset limit p_historico_limite
  ) q;
  select count(*)::integer into v_apontamentos_total
    from public.apontamentos_internos ap
    where ap.id_requisito=v_req.id and ap.id_competencia=v_comp.id
      and ap.id_contrato=v_comp.id_contrato and ap.id_organizacao=v_comp.id_organizacao;
  select coalesce(jsonb_agg(q.obj order by q.criado_em desc,q.id desc),'[]'::jsonb)
  into v_apontamentos from (
    select ap.id,ap.criado_em,jsonb_build_object(
      'id',ap.id,'descricao',ap.descricao,'severidade',ap.severidade,
      'status',ap.status,'origem',ap.origem,'regra_violada',ap.regra_violada,
      'acao_sugerida',ap.acao_sugerida,'fonte',ap.fonte,
      'criado_em',ap.criado_em,'atualizado_em',ap.atualizado_em
    ) obj from public.apontamentos_internos ap
    where ap.id_requisito=v_req.id and ap.id_competencia=v_comp.id
      and ap.id_contrato=v_comp.id_contrato and ap.id_organizacao=v_comp.id_organizacao
    order by ap.criado_em desc,ap.id desc
    offset p_apontamentos_offset limit p_apontamentos_limite
  ) q;
  return jsonb_build_object(
    'schema_versao','v117-v1',
    'competencia',jsonb_build_object(
      'id',v_comp.id,'id_organizacao',v_comp.id_organizacao,
      'id_contrato',v_comp.id_contrato,'competencia_referencia',v_comp.competencia_referencia,
      'situacao',v_comp.situacao
    ),
    'requisito',jsonb_build_object(
      'id',v_req.id,'codigo',v_req.codigo,'descricao',v_req.descricao,
      'categoria',v_req.categoria,'origem_tipo',v_req.origem_tipo,
      'origem_id',v_req.origem_id,'origem_versao',v_req.origem_versao,
      'obrigatorio',v_req.obrigatorio,'aplicavel',v_req.aplicavel,
      'impeditivo',v_req.impeditivo,'criticidade',v_req.criticidade,
      'fonte_tipo',v_req.fonte_tipo,'fonte_referencia',v_req.fonte_referencia,
      'fonte_detalhe',v_req.fonte_detalhe,'efeito_portao',v_req.efeito_portao,
      'hash_snapshot',v_req.hash_snapshot,'regra_validacao',v_req.regra_validacao,
      'condicao_aplicabilidade',v_req.condicao_aplicabilidade
    ),
    'execucao_atual',case when v_exec.id is null then null else jsonb_build_object(
      'id',v_exec.id,'tipo',v_exec.tipo,'status',v_exec.status,
      'hash_entrada',v_exec.hash_entrada,'motor',v_exec.motor,
      'versao_motor',v_exec.versao_motor,'provedor',v_exec.provedor,
      'modelo',v_exec.modelo,'prompt_versao',v_exec.prompt_versao,
      'iniciada_em',v_exec.iniciada_em,'concluida_em',v_exec.concluida_em,
      'criado_em',v_exec.criado_em
    ) end,
    'resultado_atual',case when v_atual.id is null then null else jsonb_build_object(
      'id',v_atual.id,'id_execucao',v_atual.id_execucao,
      'resultado',v_atual.resultado,'confianca',v_atual.confianca,
      'justificativa',v_atual.justificativa,'fundamento',v_atual.fundamento,
      'hash_evidencias',v_atual.hash_evidencias,'criado_em',v_atual.criado_em
    ) end,
    'resultado_referencia',case when v_ultimo.id is null then null else jsonb_build_object(
      'id',v_ultimo.id,'id_execucao',v_ultimo.id_execucao,
      'resultado',v_ultimo.resultado,'mecanismo',v_mecanismo,
      'confianca',v_ultimo.confianca,'justificativa',v_ultimo.justificativa,
      'fundamento',v_ultimo.fundamento,'hash_evidencias',v_ultimo.hash_evidencias,
      'criado_em',v_ultimo.criado_em
    ) end,
    'na_validade',case when v_ultimo.resultado='nao_aplicavel' then jsonb_build_object(
      'valido',v_na_valido,'id_resultado_referencia',v_ultimo.id,
      'possui_fundamento',nullif(trim(coalesce(v_ultimo.fundamento,'')),'') is not null,
      'possui_evidencia',exists (select 1 from public.evidencias_resultado ev
          where ev.id_resultado=v_ultimo.id and ev.id_competencia=v_comp.id
          and ev.id_contrato=v_comp.id_contrato and ev.id_organizacao=v_comp.id_organizacao)
    ) else null end,
    'allowed_actions',coalesce(v_capacidades,'{}'::jsonb),
    'evidencias',v_evidencias,
    'evidencias_paginacao',jsonb_build_object('offset',p_evidencias_offset,'limite',p_evidencias_limite,'total',v_evidencias_total),
    'historico',v_historico,
    'historico_paginacao',jsonb_build_object('offset',p_historico_offset,'limite',p_historico_limite,'total',v_historico_total),
    'apontamentos',v_apontamentos,
    'apontamentos_paginacao',jsonb_build_object('offset',p_apontamentos_offset,'limite',p_apontamentos_limite,'total',v_apontamentos_total)
  );
end;
$v117$;
revoke all on function public.obter_detalhe_requisito_v117(uuid,uuid,integer,integer,integer,integer,integer,integer) from public,anon;
grant execute on function public.obter_detalhe_requisito_v117(uuid,uuid,integer,integer,integer,integer,integer,integer) to authenticated;
