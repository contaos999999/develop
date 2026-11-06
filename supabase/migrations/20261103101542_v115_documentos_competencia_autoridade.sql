-- V1-15 — Competência: documentos
-- Contrato explícito de requisito documental:
-- regra_validacao.documento = {"obrigatorio": true, "tipos": ["..."]}
-- Somente o backend interpreta esse marcador. Ausência/malformação = não declarar requisito documental.

create or replace function privado.v115_requisito_exige_documento(p_regra jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_regra #> '{documento,obrigatorio}','false'::jsonb) = 'true'::jsonb;
$$;

create or replace function privado.v115_concluir_comando(
  p_id_comando uuid,
  p_id_organizacao uuid,
  p_evento text,
  p_entidade text,
  p_id_entidade uuid,
  p_depois jsonb,
  p_resultado jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evento uuid;
  v_correlacao uuid;
  v_resposta jsonb;
begin
  v_evento := privado.registrar_evento_auditoria(
    p_id_organizacao,p_evento,p_entidade,p_id_entidade,null,p_depois,
    jsonb_build_object('comando_id',p_id_comando,'origem','V1-15')
  );
  select correlation_id into v_correlacao from public.eventos_auditoria where id=v_evento;
  v_resposta := p_resultado || jsonb_build_object('schema_versao','v115-v1','correlation_id',v_correlacao);
  update public.comandos_idempotentes
     set status='concluido',resposta=v_resposta,atualizado_em=clock_timestamp()
   where id=p_id_comando;
  return v_resposta;
end;
$$;

create or replace function privado.obter_documentos_competencia_v115(
  p_id_competencia uuid,
  p_documentos_offset integer default 0,
  p_documentos_limite integer default 25,
  p_requisitos_offset integer default 0,
  p_requisitos_limite integer default 25
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
  if p_documentos_offset < 0 or p_requisitos_offset < 0
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
$$;

create or replace function privado.criar_documento_competencia_v115(
  p_id_competencia uuid,
  p_tipo text,
  p_titulo text,
  p_categoria text,
  p_id_requisito uuid,
  p_id_arquivo uuid,
  p_chave_idempotencia text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_comp public.competencias%rowtype;
  v_arquivo public.arquivos%rowtype;
  v_doc uuid;
  v_ver uuid;
  v_job uuid;
  v_cmd jsonb;
  v_resultado jsonb;
begin
  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then raise exception using errcode='PT404',message='Competência não encontrada.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa()
     or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato)
     or not privado.usuario_possui_perfil(v_comp.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then
    raise exception using errcode='42501',message='Seu perfil atual não permite incluir documentos nesta competência.';
  end if;
  if nullif(btrim(p_tipo),'') is null then raise exception using errcode='PT400',message='Informe o tipo do documento.'; end if;
  if nullif(btrim(p_titulo),'') is null then raise exception using errcode='PT400',message='Informe o título do documento.'; end if;
  if p_id_requisito is not null and not exists(
    select 1 from public.requisitos_competencia r where r.id=p_id_requisito and r.id_competencia=v_comp.id
  ) then raise exception using errcode='PT400',message='O requisito informado não pertence a esta competência.'; end if;

  v_cmd:=privado.v110_iniciar_comando(
    v_comp.id_organizacao,'v115.criar_documento_competencia',p_chave_idempotencia,
    jsonb_build_object('id_competencia',v_comp.id,'tipo',btrim(p_tipo),'titulo',btrim(p_titulo),
      'categoria',nullif(btrim(coalesce(p_categoria,'')),''),'id_requisito',p_id_requisito,'id_arquivo',p_id_arquivo)
  );
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;

  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_comp.id_organizacao,v_comp.id_contrato);
  insert into public.documentos_competencia(
    id_organizacao,id_contrato,id_competencia,tipo,titulo,categoria,id_requisito_competencia,situacao,versao_atual
  ) values(
    v_comp.id_organizacao,v_comp.id_contrato,v_comp.id,btrim(p_tipo),btrim(p_titulo),
    nullif(btrim(coalesce(p_categoria,'')),''),p_id_requisito,'ativo',1
  ) returning id into v_doc;
  insert into public.versoes_documento(
    id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,enviado_por
  ) values(
    v_comp.id_organizacao,v_comp.id_contrato,v_doc,1,v_arquivo.id,v_arquivo.sha256,auth.uid()
  ) returning id into v_ver;
  v_job:=privado.enfileirar_job(
    'documents',v_comp.id_organizacao,v_comp.id_contrato,'versao_documento',v_ver,
    jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text
  );
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_ver,'documents','pendente');

  v_resultado:=privado.v115_concluir_comando(
    (v_cmd->>'id')::uuid,v_comp.id_organizacao,'DocumentoCompetenciaCriado','documentos_competencia',v_doc,
    jsonb_build_object('id_competencia',v_comp.id,'id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,
      'id_arquivo',v_arquivo.id,'id_requisito',p_id_requisito,'id_job',v_job),
    jsonb_build_object('id_competencia',v_comp.id,'id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,
      'id_arquivo',v_arquivo.id,'id_job',v_job)
  );
  return v_resultado;
end;
$$;

create or replace function privado.adicionar_versao_documento_competencia_v115(
  p_id_documento uuid,
  p_id_arquivo uuid,
  p_motivo text,
  p_chave_idempotencia text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doc public.documentos_competencia%rowtype;
  v_arquivo public.arquivos%rowtype;
  v_num integer;
  v_ver uuid;
  v_job uuid;
  v_cmd jsonb;
  v_resultado jsonb;
  v_motivo_obrigatorio boolean;
begin
  select * into v_doc from public.documentos_competencia where id=p_id_documento;
  if v_doc.id is null then raise exception using errcode='PT404',message='Documento não encontrado.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa()
     or not privado.usuario_tem_acesso_contrato(v_doc.id_contrato)
     or not privado.usuario_possui_perfil(v_doc.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then
    raise exception using errcode='42501',message='Seu perfil atual não permite criar uma nova versão deste documento.';
  end if;

  v_cmd:=privado.v110_iniciar_comando(
    v_doc.id_organizacao,'v115.adicionar_versao_documento_competencia',p_chave_idempotencia,
    jsonb_build_object('id_documento',v_doc.id,'id_arquivo',p_id_arquivo,'motivo',nullif(btrim(coalesce(p_motivo,'')),''))
  );
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;

  select * into v_doc from public.documentos_competencia where id=p_id_documento for update;
  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_doc.id_organizacao,v_doc.id_contrato);
  select exists(select 1 from public.execucoes_analise e where e.id_competencia=v_doc.id_competencia)
    into v_motivo_obrigatorio;
  if v_motivo_obrigatorio and nullif(btrim(coalesce(p_motivo,'')),'') is null then
    raise exception using errcode='PT400',message='Informe o motivo da nova versão porque esta competência já possui análise registrada.';
  end if;

  select coalesce(max(numero_versao),0)+1 into v_num
    from public.versoes_documento where id_documento_competencia=v_doc.id;
  insert into public.versoes_documento(
    id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,motivo_substituicao,enviado_por
  ) values(
    v_doc.id_organizacao,v_doc.id_contrato,v_doc.id,v_num,v_arquivo.id,v_arquivo.sha256,
    nullif(btrim(coalesce(p_motivo,'')),''),auth.uid()
  ) returning id into v_ver;
  update public.documentos_competencia set versao_atual=v_num where id=v_doc.id;
  v_job:=privado.enfileirar_job(
    'documents',v_doc.id_organizacao,v_doc.id_contrato,'versao_documento',v_ver,
    jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text
  );
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
  values(v_doc.id_organizacao,v_doc.id_contrato,v_ver,'documents','pendente');

  v_resultado:=privado.v115_concluir_comando(
    (v_cmd->>'id')::uuid,v_doc.id_organizacao,'VersaoDocumentoCompetenciaCriada','versoes_documento',v_ver,
    jsonb_build_object('id_competencia',v_doc.id_competencia,'id_documento',v_doc.id,'id_versao',v_ver,
      'numero_versao',v_num,'id_arquivo',v_arquivo.id,'id_job',v_job,'motivo',nullif(btrim(coalesce(p_motivo,'')),'')),
    jsonb_build_object('id_competencia',v_doc.id_competencia,'id_documento',v_doc.id,'id_versao',v_ver,
      'numero_versao',v_num,'id_arquivo',v_arquivo.id,'id_job',v_job)
  );
  return v_resultado;
end;
$$;

create or replace function public.obter_documentos_competencia_v115(
  p_id_competencia uuid,
  p_documentos_offset integer default 0,
  p_documentos_limite integer default 25,
  p_requisitos_offset integer default 0,
  p_requisitos_limite integer default 25
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select privado.obter_documentos_competencia_v115($1,$2,$3,$4,$5);
$$;

create or replace function public.criar_documento_competencia_v115(
  p_id_competencia uuid,
  p_tipo text,
  p_titulo text,
  p_categoria text,
  p_id_requisito uuid,
  p_id_arquivo uuid,
  p_chave_idempotencia text
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select privado.criar_documento_competencia_v115($1,$2,$3,$4,$5,$6,$7);
$$;

create or replace function public.adicionar_versao_documento_competencia_v115(
  p_id_documento uuid,
  p_id_arquivo uuid,
  p_motivo text,
  p_chave_idempotencia text
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select privado.adicionar_versao_documento_competencia_v115($1,$2,$3,$4);
$$;

revoke all on function privado.v115_requisito_exige_documento(jsonb) from public,anon,authenticated,service_role;
revoke all on function privado.v115_concluir_comando(uuid,uuid,text,text,uuid,jsonb,jsonb) from public,anon,authenticated,service_role;
revoke all on function privado.obter_documentos_competencia_v115(uuid,integer,integer,integer,integer) from public,anon,authenticated,service_role;
revoke all on function privado.criar_documento_competencia_v115(uuid,text,text,text,uuid,uuid,text) from public,anon,authenticated,service_role;
revoke all on function privado.adicionar_versao_documento_competencia_v115(uuid,uuid,text,text) from public,anon,authenticated,service_role;

revoke all on function public.obter_documentos_competencia_v115(uuid,integer,integer,integer,integer) from public,anon;
revoke all on function public.criar_documento_competencia_v115(uuid,text,text,text,uuid,uuid,text) from public,anon;
revoke all on function public.adicionar_versao_documento_competencia_v115(uuid,uuid,text,text) from public,anon;
grant execute on function public.obter_documentos_competencia_v115(uuid,integer,integer,integer,integer) to authenticated,service_role;
grant execute on function public.criar_documento_competencia_v115(uuid,text,text,text,uuid,uuid,text) to authenticated,service_role;
grant execute on function public.adicionar_versao_documento_competencia_v115(uuid,uuid,text,text) to authenticated,service_role;

comment on function public.obter_documentos_competencia_v115(uuid,integer,integer,integer,integer) is
'V1-15: leitura autoritativa/paginada de documentos, requisitos documentais explícitos e estado documental da competência.';
comment on function public.criar_documento_competencia_v115(uuid,text,text,text,uuid,uuid,text) is
'V1-15: cria documento da competência com idempotência, versão 1, fila de processamento e auditoria.';
comment on function public.adicionar_versao_documento_competencia_v115(uuid,uuid,text,text) is
'V1-15: cria nova versão idempotente; motivo é obrigatório após existir qualquer execução de análise da competência.';
