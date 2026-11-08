-- Reject explicit NULL pagination without changing RBAC, ACL or query contracts.
BEGIN;
DO $precondition$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('privado.obter_documentos_competencia_v115(uuid,integer,integer,integer,integer)')) IS DISTINCT FROM '76611a9a23e0d9bebf09aa1e0aa44093' THEN
  RAISE EXCEPTION 'RPC source changed: re-review migration before applying';
 END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.obter_analise_competencia_v116(uuid,integer,integer,integer,integer,integer,integer,text,text,text,text,text)')) IS DISTINCT FROM '84aaf91cce67651a5cbb3ecd16f8eaa2' THEN
  RAISE EXCEPTION 'RPC source changed: re-review migration before applying';
 END IF;
END;
$precondition$;

CREATE OR REPLACE FUNCTION privado.obter_documentos_competencia_v115(p_id_competencia uuid, p_documentos_offset integer DEFAULT 0, p_documentos_limite integer DEFAULT 25, p_requisitos_offset integer DEFAULT 0, p_requisitos_limite integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_comp public.competencias%rowtype;
  v_docs jsonb := '[]'::jsonb;
  v_reqs jsonb := '[]'::jsonb;
  v_docs_total integer := 0;
  v_req_total integer := 0;
  v_req_aplicaveis integer := 0;
  v_req_pendentes integer := 0;
  v_tem_erro boolean := false;
  v_processando boolean := false;
  v_estado text;
  v_pode_escrever boolean := false;
  v_motivo_obrigatorio boolean := false;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'documentos_competencia','consultar',(select id_contrato from public.competencias where id=p_id_competencia));

  if p_documentos_offset is null or p_requisitos_offset is null or p_documentos_limite is null or p_requisitos_limite is null or p_documentos_offset < 0 or p_requisitos_offset < 0
     or p_documentos_limite not between 1 and 100
     or p_requisitos_limite not between 1 and 100 then
    raise exception using errcode='PT400',message='Informe uma paginação válida.';
  end if;

  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then
    raise exception using errcode='PT404',message='Competência não encontrada.';
  end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa()
     or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato) then
    raise exception using errcode='42501',message='Você não tem permissão para acessar esta competência.';
  end if;

  v_pode_escrever := privado.usuario_possui_perfil(
    v_comp.id_organizacao,
    array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]
  );
  select exists(select 1 from public.execucoes_analise e where e.id_competencia=v_comp.id)
    into v_motivo_obrigatorio;

  select count(*) into v_docs_total
    from public.documentos_competencia d
   where d.id_competencia=v_comp.id;

  select
    count(*),
    count(*) filter(where r.aplicavel),
    count(*) filter(
      where r.aplicavel and not exists(
        select 1 from public.documentos_competencia d
         where d.id_competencia=v_comp.id
           and d.id_requisito_competencia=r.id
           and d.situacao='ativo'
      )
    )
  into v_req_total,v_req_aplicaveis,v_req_pendentes
  from public.requisitos_competencia r
  where r.id_competencia=v_comp.id
    and privado.v115_requisito_exige_documento(r.regra_validacao);

  select coalesce(jsonb_agg(x.obj order by x.atualizado_em desc,x.id desc),'[]'::jsonb)
    into v_docs
  from (
    select d.id,d.atualizado_em,
      jsonb_build_object(
        'id',d.id,
        'tipo',d.tipo,
        'titulo',d.titulo,
        'categoria',d.categoria,
        'situacao',d.situacao,
        'versao_atual',d.versao_atual,
        'versao_registro',d.versao_registro,
        'criado_em',d.criado_em,
        'atualizado_em',d.atualizado_em,
        'id_requisito_competencia',d.id_requisito_competencia,
        'requisito',case when r.id is null then null else jsonb_build_object(
          'id',r.id,'codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria,
          'obrigatorio',r.obrigatorio,'aplicavel',r.aplicavel,'impeditivo',r.impeditivo,'criticidade',r.criticidade
        ) end,
        'versao',case when vd.id is null then null else jsonb_build_object(
          'id',vd.id,'numero_versao',vd.numero_versao,'hash',vd.hash,
          'motivo_substituicao',vd.motivo_substituicao,'metadados_extraidos',vd.metadados_extraidos,
          'criado_em',vd.criado_em,'id_arquivo',vd.id_arquivo
        ) end,
        'arquivo',case when a.id is null then null else jsonb_build_object(
          'id',a.id,'nome_original',a.nome_original,'mime',a.mime,'tamanho',a.tamanho,
          'sha256',a.sha256,'status_seguranca',a.status_seguranca,'origem',a.origem,'criado_em',a.criado_em
        ) end,
        'processamento',case when pr.id is null then null else jsonb_build_object(
          'id',pr.id,'etapa',pr.etapa,'status',pr.status,'tentativas',pr.tentativas,
          'erro_codigo',pr.erro_codigo,'resultado',pr.resultado,
          'iniciado_em',pr.iniciado_em,'concluido_em',pr.concluido_em,'atualizado_em',pr.atualizado_em
        ) end
      ) as obj
    from public.documentos_competencia d
    left join public.requisitos_competencia r on r.id=d.id_requisito_competencia and r.id_competencia=d.id_competencia
    left join lateral (
      select v.* from public.versoes_documento v
       where v.id_documento_competencia=d.id
       order by v.numero_versao desc,v.id desc limit 1
    ) vd on true
    left join public.arquivos a on a.id=vd.id_arquivo
    left join lateral (
      select p.* from public.processamentos_documento p
       where p.id_versao_documento=vd.id
       order by p.criado_em desc,p.id desc limit 1
    ) pr on true
    where d.id_competencia=v_comp.id
    order by d.atualizado_em desc,d.id desc
    offset p_documentos_offset limit p_documentos_limite
  ) x;

  select coalesce(jsonb_agg(x.obj order by x.ordem,x.id),'[]'::jsonb)
    into v_reqs
  from (
    select r.id,r.ordem,
      jsonb_build_object(
        'id',r.id,'codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria,
        'obrigatorio',r.obrigatorio,'aplicavel',r.aplicavel,'impeditivo',r.impeditivo,
        'criticidade',r.criticidade,'ordem',r.ordem,
        'tipos_esperados',case
          when jsonb_typeof(r.regra_validacao #> '{documento,tipos}')='array'
            then r.regra_validacao #> '{documento,tipos}'
          else '[]'::jsonb end,
        'atendido',exists(
          select 1 from public.documentos_competencia d
           where d.id_competencia=v_comp.id
             and d.id_requisito_competencia=r.id
             and d.situacao='ativo'
        )
      ) as obj
    from public.requisitos_competencia r
    where r.id_competencia=v_comp.id
      and privado.v115_requisito_exige_documento(r.regra_validacao)
    order by r.ordem,r.id
    offset p_requisitos_offset limit p_requisitos_limite
  ) x;

  select exists(
    select 1
    from public.documentos_competencia d
    join lateral (
      select v.* from public.versoes_documento v
       where v.id_documento_competencia=d.id
       order by v.numero_versao desc,v.id desc limit 1
    ) vd on true
    join public.arquivos a on a.id=vd.id_arquivo
    left join lateral (
      select p.* from public.processamentos_documento p
       where p.id_versao_documento=vd.id
       order by p.criado_em desc,p.id desc limit 1
    ) pr on true
    where d.id_competencia=v_comp.id and d.situacao='ativo'
      and (a.status_seguranca in ('quarentena','bloqueado') or pr.status in ('falhou','cancelado'))
  ) into v_tem_erro;

  select exists(
    select 1
    from public.documentos_competencia d
    join lateral (
      select v.* from public.versoes_documento v
       where v.id_documento_competencia=d.id
       order by v.numero_versao desc,v.id desc limit 1
    ) vd on true
    join public.arquivos a on a.id=vd.id_arquivo
    left join lateral (
      select p.* from public.processamentos_documento p
       where p.id_versao_documento=vd.id
       order by p.criado_em desc,p.id desc limit 1
    ) pr on true
    where d.id_competencia=v_comp.id and d.situacao='ativo'
      and (a.status_seguranca='pendente' or pr.status in ('pendente','processando'))
  ) into v_processando;

  v_estado := case
    when v_tem_erro then 'error'
    when v_processando then 'processing'
    when v_req_pendentes>0 then 'missing_docs'
    else 'complete'
  end;

  return jsonb_build_object(
    'schema_versao','v115-v1',
    'competencia',jsonb_build_object(
      'id',v_comp.id,'id_contrato',v_comp.id_contrato,'id_organizacao',v_comp.id_organizacao,
      'competencia_referencia',v_comp.competencia_referencia,'situacao',v_comp.situacao,
      'versao_registro',v_comp.versao_registro,'atualizado_em',v_comp.atualizado_em
    ),
    'estado_documental',v_estado,
    'resumo',jsonb_build_object(
      'documentos_total',v_docs_total,
      'requisitos_documentais_total',v_req_total,
      'requisitos_documentais_aplicaveis',v_req_aplicaveis,
      'requisitos_documentais_pendentes',v_req_pendentes
    ),
    'documentos',v_docs,
    'documentos_paginacao',jsonb_build_object('offset',p_documentos_offset,'limite',p_documentos_limite,'total',v_docs_total),
    'requisitos_documentais',v_reqs,
    'requisitos_paginacao',jsonb_build_object('offset',p_requisitos_offset,'limite',p_requisitos_limite,'total',v_req_total),
    'capacidades',jsonb_build_object(
      'pode_enviar',v_pode_escrever,
      'pode_nova_versao',v_pode_escrever,
      'motivo_nova_versao_obrigatorio',v_motivo_obrigatorio
    )
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.obter_analise_competencia_v116(p_id_competencia uuid, p_resultados_offset integer DEFAULT 0, p_resultados_limite integer DEFAULT 25, p_execucoes_offset integer DEFAULT 0, p_execucoes_limite integer DEFAULT 10, p_apontamentos_offset integer DEFAULT 0, p_apontamentos_limite integer DEFAULT 25, p_filtro_resultado text DEFAULT NULL::text, p_filtro_criticidade text DEFAULT NULL::text, p_filtro_mecanismo text DEFAULT NULL::text, p_filtro_apontamento_status text DEFAULT NULL::text, p_busca text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_comp public.competencias%rowtype;
  v_exec public.execucoes_analise%rowtype;
  v_hash_atual text; v_portao jsonb; v_estado text; v_stale boolean:=false;
  v_perfil_analise boolean:=false; v_situacao_permite boolean:=false; v_busy boolean:=false;
  v_resultados jsonb:='[]'::jsonb; v_resultados_total integer:=0;
  v_execucoes jsonb:='[]'::jsonb; v_execucoes_total integer:=0;
  v_apontamentos jsonb:='[]'::jsonb; v_apontamentos_total integer:=0;
  v_mecanismos jsonb:='{}'::jsonb; v_busca text:=nullif(trim(coalesce(p_busca,'')),'');
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'analises','consultar',(select id_contrato from public.competencias where id=p_id_competencia));

  if p_id_competencia is null then raise exception using errcode='PT400',message='Informe a competência para consultar a análise.'; end if;
  if p_resultados_offset is null or p_execucoes_offset is null or p_apontamentos_offset is null or p_resultados_limite is null or p_execucoes_limite is null or p_apontamentos_limite is null or p_resultados_offset<0 or p_execucoes_offset<0 or p_apontamentos_offset<0 or p_resultados_limite<1 or p_resultados_limite>100 or p_execucoes_limite<1 or p_execucoes_limite>50 or p_apontamentos_limite<1 or p_apontamentos_limite>100 then raise exception using errcode='PT400',message='Os parâmetros de paginação informados não são válidos.'; end if;
  if p_filtro_mecanismo is not null and p_filtro_mecanismo not in ('deterministico','semantico','humano','nao_identificado') then raise exception using errcode='PT400',message='O filtro de mecanismo não é válido.'; end if;
  if p_filtro_criticidade is not null and p_filtro_criticidade not in ('critica','alta','media','baixa','informativo') then raise exception using errcode='PT400',message='O filtro de criticidade não é válido.'; end if;
  if p_filtro_resultado is not null and p_filtro_resultado not in ('nao_enviado','recebido','pendente','em_analise','conforme','nao_conforme','inconclusivo','requer_revisao','nao_aplicavel') then raise exception using errcode='PT400',message='O filtro de resultado não é válido.'; end if;
  if p_filtro_apontamento_status is not null and p_filtro_apontamento_status not in ('aberto','em_tratamento','resolvido','descartado') then raise exception using errcode='PT400',message='O filtro de apontamento não é válido.'; end if;

  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then raise exception using errcode='PT404',message='Não encontramos a competência informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato) then raise exception using errcode='42501',message='Você não possui acesso à competência informada.'; end if;
  v_perfil_analise:=privado.usuario_possui_perfil(v_comp.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]);
  if not v_perfil_analise then raise exception using errcode='42501',message='Seu perfil atual não permite consultar a análise desta competência.'; end if;

  select * into v_exec from public.execucoes_analise where id_competencia=v_comp.id order by criado_em desc,id desc limit 1;
  v_hash_atual:=privado.hash_contexto_competencia(v_comp.id);
  v_portao:=privado.avaliar_portao_conformidade(v_comp.id);
  v_situacao_permite:=v_comp.situacao not in ('apresentado','aguardando_contratante','validada','encerrada','cancelada');
  v_busy:=v_exec.id is not null and v_exec.status in ('pendente','processando');
  if v_exec.id is null then v_estado:='not_analyzed';
  elsif v_exec.status='pendente' then v_estado:='queued';
  elsif v_exec.status='processando' then v_estado:='processing';
  elsif v_exec.status in ('falhou','cancelada') then v_estado:='failed';
  elsif v_exec.status='concluida' then v_stale:=v_exec.hash_entrada is null or v_exec.hash_entrada<>v_hash_atual; v_estado:=case when v_stale then 'stale' else 'complete' end;
  else v_estado:='failed'; end if;

  select count(*)::integer into v_execucoes_total from public.execucoes_analise e where e.id_competencia=v_comp.id;
  select coalesce(jsonb_agg(x.obj order by x.criado_em desc,x.id desc),'[]'::jsonb) into v_execucoes from (
    select e.id,e.criado_em,jsonb_build_object('id',e.id,'tipo',e.tipo,'status',e.status,'hash_entrada',e.hash_entrada,'contexto_atual',coalesce(e.hash_entrada=v_hash_atual,false),'motor',e.motor,'versao_motor',e.versao_motor,'provedor',e.provedor,'modelo',e.modelo,'prompt_versao',e.prompt_versao,'iniciada_por',e.iniciada_por,'iniciada_em',e.iniciada_em,'concluida_em',e.concluida_em,'erro_codigo',e.erro_codigo,'requisitos_afetados',coalesce(to_jsonb(e.requisitos_afetados),'[]'::jsonb),'metadados',coalesce(e.metadados,'{}'::jsonb),'criado_em',e.criado_em) obj
    from public.execucoes_analise e where e.id_competencia=v_comp.id order by e.criado_em desc,e.id desc offset p_execucoes_offset limit p_execucoes_limite
  ) x;

  if v_exec.id is not null then
    with base as (
      select rr.*,r.codigo,r.descricao,r.categoria,r.criticidade,r.obrigatorio,r.aplicavel,r.impeditivo,r.efeito_portao,r.fonte_tipo,r.fonte_referencia,r.fonte_detalhe,
      case when rr.metadados->>'origem'='revisao_humana' then 'humano' when rr.metadados->>'mecanismo' in ('deterministico','semantico','humano') then rr.metadados->>'mecanismo' when nullif(rr.metadados->>'provedor','') is not null then 'semantico' when nullif(v_exec.provedor,'') is not null and rr.metadados->>'origem' is null then 'semantico' else 'nao_identificado' end mecanismo
      from public.resultados_requisitos rr join public.requisitos_competencia r on r.id=rr.id_requisito where rr.id_execucao=v_exec.id
    ), filtrado as (
      select * from base b where (p_filtro_resultado is null or b.resultado=p_filtro_resultado) and (p_filtro_criticidade is null or b.criticidade=p_filtro_criticidade) and (p_filtro_mecanismo is null or b.mecanismo=p_filtro_mecanismo) and (v_busca is null or coalesce(b.codigo,'') ilike '%'||v_busca||'%' or b.descricao ilike '%'||v_busca||'%')
    ), pagina as (
      select * from filtrado order by codigo nulls last,id_requisito,criado_em desc,id desc offset p_resultados_offset limit p_resultados_limite
    ), ev as (
      select e.id_resultado,jsonb_agg(jsonb_build_object('id',e.id,'id_versao_documento',e.id_versao_documento,'pagina',e.pagina,'trecho',e.trecho,'tipo_evidencia',e.tipo_evidencia,'referencia_externa',e.referencia_externa,'hash',e.hash,'criado_em',e.criado_em) order by e.criado_em,e.id) evidencias
      from public.evidencias_resultado e join pagina p on p.id=e.id_resultado group by e.id_resultado
    )
    select (select count(*)::integer from filtrado),coalesce((select jsonb_agg(jsonb_build_object('id_resultado',p.id,'id_requisito',p.id_requisito,'requisito',jsonb_build_object('codigo',p.codigo,'descricao',p.descricao,'categoria',p.categoria,'criticidade',p.criticidade,'obrigatorio',p.obrigatorio,'aplicavel',p.aplicavel,'impeditivo',p.impeditivo,'efeito_portao',p.efeito_portao,'fonte_tipo',p.fonte_tipo,'fonte_referencia',p.fonte_referencia,'fonte_detalhe',p.fonte_detalhe),'resultado',p.resultado,'mecanismo',p.mecanismo,'confianca',p.confianca,'justificativa',p.justificativa,'fundamento',p.fundamento,'hash_evidencias',p.hash_evidencias,'metadados',coalesce(p.metadados,'{}'::jsonb),'evidencias',coalesce(ev.evidencias,'[]'::jsonb),'criado_em',p.criado_em) order by p.codigo nulls last,p.id_requisito,p.criado_em desc,p.id desc) from pagina p left join ev on ev.id_resultado=p.id),'[]'::jsonb)
    into v_resultados_total,v_resultados;

    with b as (select case when rr.metadados->>'origem'='revisao_humana' then 'humano' when rr.metadados->>'mecanismo' in ('deterministico','semantico','humano') then rr.metadados->>'mecanismo' when nullif(rr.metadados->>'provedor','') is not null then 'semantico' when nullif(v_exec.provedor,'') is not null and rr.metadados->>'origem' is null then 'semantico' else 'nao_identificado' end mecanismo from public.resultados_requisitos rr where rr.id_execucao=v_exec.id)
    select jsonb_build_object('deterministico',count(*) filter(where mecanismo='deterministico'),'semantico',count(*) filter(where mecanismo='semantico'),'humano',count(*) filter(where mecanismo='humano'),'nao_identificado',count(*) filter(where mecanismo='nao_identificado')) into v_mecanismos from b;
  end if;

  select count(*)::integer into v_apontamentos_total from public.apontamentos_internos a left join public.requisitos_competencia r on r.id=a.id_requisito where a.id_competencia=v_comp.id and (p_filtro_apontamento_status is null or a.status=p_filtro_apontamento_status) and (p_filtro_criticidade is null or a.severidade=p_filtro_criticidade) and (v_busca is null or a.descricao ilike '%'||v_busca||'%' or coalesce(r.codigo,'') ilike '%'||v_busca||'%' or coalesce(r.descricao,'') ilike '%'||v_busca||'%');
  select coalesce(jsonb_agg(x.obj order by x.criado_em desc,x.id desc),'[]'::jsonb) into v_apontamentos from (
    select a.id,a.criado_em,jsonb_build_object('id',a.id,'id_requisito',a.id_requisito,'requisito',case when r.id is null then null else jsonb_build_object('codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria,'criticidade',r.criticidade) end,'descricao',a.descricao,'severidade',a.severidade,'status',a.status,'origem',a.origem,'regra_violada',a.regra_violada,'acao_sugerida',a.acao_sugerida,'fonte',coalesce(a.fonte,'{}'::jsonb),'criado_em',a.criado_em,'atualizado_em',a.atualizado_em) obj
    from public.apontamentos_internos a left join public.requisitos_competencia r on r.id=a.id_requisito where a.id_competencia=v_comp.id and (p_filtro_apontamento_status is null or a.status=p_filtro_apontamento_status) and (p_filtro_criticidade is null or a.severidade=p_filtro_criticidade) and (v_busca is null or a.descricao ilike '%'||v_busca||'%' or coalesce(r.codigo,'') ilike '%'||v_busca||'%' or coalesce(r.descricao,'') ilike '%'||v_busca||'%') order by a.criado_em desc,a.id desc offset p_apontamentos_offset limit p_apontamentos_limite
  ) x;

  return jsonb_build_object('schema_versao','v116-v1','competencia',jsonb_build_object('id',v_comp.id,'id_organizacao',v_comp.id_organizacao,'id_contrato',v_comp.id_contrato,'competencia_referencia',v_comp.competencia_referencia,'periodo_inicio',v_comp.periodo_inicio,'periodo_fim',v_comp.periodo_fim,'situacao',v_comp.situacao),'estado_analise',v_estado,'stale',v_stale,'hash_contexto_atual',v_hash_atual,'execucao_atual',case when v_exec.id is null then null else jsonb_build_object('id',v_exec.id,'tipo',v_exec.tipo,'status',v_exec.status,'hash_entrada',v_exec.hash_entrada,'motor',v_exec.motor,'versao_motor',v_exec.versao_motor,'provedor',v_exec.provedor,'modelo',v_exec.modelo,'prompt_versao',v_exec.prompt_versao,'iniciada_por',v_exec.iniciada_por,'iniciada_em',v_exec.iniciada_em,'concluida_em',v_exec.concluida_em,'erro_codigo',v_exec.erro_codigo,'requisitos_afetados',coalesce(to_jsonb(v_exec.requisitos_afetados),'[]'::jsonb),'metadados',coalesce(v_exec.metadados,'{}'::jsonb),'criado_em',v_exec.criado_em) end,'percentual',coalesce((v_portao->>'percentual')::numeric,0),'blocking_summary',v_portao,'allowed_actions',jsonb_build_object('executar_analise',v_perfil_analise and v_situacao_permite and not v_busy and (v_exec.id is null or v_exec.status in ('falhou','cancelada')),'reanalisar',v_perfil_analise and v_situacao_permite and not v_busy and v_exec.id is not null and v_exec.status='concluida','abrir_requisito',v_exec.id is not null),'mecanismos',coalesce(v_mecanismos,'{}'::jsonb),'resultados',v_resultados,'resultados_paginacao',jsonb_build_object('offset',p_resultados_offset,'limite',p_resultados_limite,'total',v_resultados_total),'execucoes',v_execucoes,'execucoes_paginacao',jsonb_build_object('offset',p_execucoes_offset,'limite',p_execucoes_limite,'total',v_execucoes_total),'apontamentos',v_apontamentos,'apontamentos_paginacao',jsonb_build_object('offset',p_apontamentos_offset,'limite',p_apontamentos_limite,'total',v_apontamentos_total));
end;$function$
;


COMMIT;
