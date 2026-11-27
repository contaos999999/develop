begin;

revoke insert,update,delete on public.contestacoes,public.mapas_evidencias_contestacao
  from public,anon,authenticated;

create function privado.v248_pode_submeter(p_org uuid)
returns boolean language sql stable set search_path='' as $$
  select coalesce(privado.usuario_possui_perfil(p_org,
    array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']),false)
$$;

create function privado.v248_pode_revisar(p_org uuid)
returns boolean language sql stable set search_path='' as $$
  select coalesce(privado.usuario_possui_perfil(p_org,
    array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']),false)
$$;

create function privado.v248_travar_item(p_item uuid,p_interno boolean default false)
returns public.apontamentos_contratante language plpgsql set search_path='' as $$
declare rodada public.ciclos_diligencia; item public.apontamentos_contratante; ciclo uuid;
begin
  select a.id_ciclo into ciclo from public.apontamentos_contratante a where a.id=p_item;
  rodada:=privado.v247_travar_rodada(ciclo,p_interno);
  select * into item from public.apontamentos_contratante a
    where a.id=p_item and (a.id_organizacao,a.id_contrato,a.id_competencia,a.id_ciclo)=
          (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id) for update;
  if not found then
    raise exception using errcode='42501',message='Apontamento indisponível para contestação.';
  end if;
  return item;
end
$$;

create function privado.v248_item_editavel(p_item public.apontamentos_contratante)
returns boolean language sql stable set search_path='' as $$
  select privado.v247_escopo_editavel((p_item).id_ciclo) and
    (p_item).status in ('aberto','em_analise','procedente','em_tratamento','contestado','contestado_aprovado')
$$;

create function privado.v248_versoes(p_item public.apontamentos_contratante,p_interno boolean default false)
returns table(id uuid,titulo text,numero integer,hash text,vigente boolean)
language sql stable set search_path='' as $$
  select v.id,coalesce(dc.titulo,ds.titulo),v.numero_versao,lower(v.hash),
    case when dc.id is not null then dc.situacao='ativo' and dc.versao_atual=v.numero_versao
      else ds.situacao='ativo' and ds.versao_atual=v.numero_versao end
  from public.versoes_documento v
  left join public.documentos_competencia dc on dc.id=v.id_documento_competencia
    and (dc.id_organizacao,dc.id_contrato,dc.id_competencia)=
        ((p_item).id_organizacao,(p_item).id_contrato,(p_item).id_competencia)
  left join public.documentos_contrato ds on ds.id=v.id_documento_contrato
    and (ds.id_organizacao,ds.id_contrato)=((p_item).id_organizacao,(p_item).id_contrato)
  where (v.id_organizacao,v.id_contrato)=((p_item).id_organizacao,(p_item).id_contrato)
    and (dc.id is not null or ds.id is not null) and v.hash ~ '^[0-9a-fA-F]{64}$'
    and (p_interno or (
      privado.rbac_permite(v.id_organizacao,'arquivos','consultar',v.id_contrato) and
      ((dc.id is not null and privado.rbac_permite(v.id_organizacao,'documentos_competencia','consultar',v.id_contrato))
        or (ds.id is not null and privado.rbac_permite(v.id_organizacao,'documentos_contrato','consultar',v.id_contrato)))
    ))
$$;

create function privado.v248_mapa(p_item public.apontamentos_contratante,p_evidencias jsonb,p_interno boolean default false)
returns jsonb language plpgsql stable set search_path='' as $$
declare linha jsonb; referencia uuid; pagina_lida integer; alegacao text; trecho_lido text;
        hash_oficial text; mapa jsonb:='[]'::jsonb; entrada jsonb;
begin
  if p_evidencias is null or jsonb_typeof(p_evidencias)<>'array' then
    raise exception using errcode='PT400',message='Informe o mapa de evidências da contestação.';
  end if;
  if jsonb_array_length(p_evidencias) not between 1 and 40 then
    raise exception using errcode='PT400',message='Vincule de 1 a 40 referências às afirmações da contestação.';
  end if;
  for linha in select value from jsonb_array_elements(p_evidencias) loop
    if jsonb_typeof(linha)<>'object' or
      (linha-array['id_versao_documento','pagina','trecho','descricao','hash']::text[])<>'{}'::jsonb or
      jsonb_typeof(linha->'id_versao_documento') is distinct from 'string' or
      jsonb_typeof(linha->'descricao') is distinct from 'string' or
      jsonb_typeof(linha->'trecho') is distinct from 'string' or
      jsonb_typeof(linha->'pagina') is distinct from 'number' then
      raise exception using errcode='PT400',message='Cada afirmação requer versão, página e trecho de apoio.';
    end if;
    begin
      referencia:=(linha->>'id_versao_documento')::uuid;
      pagina_lida:=(linha->>'pagina')::integer;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception using errcode='PT400',message='Identificador de versão ou página inválido.';
    end;
    alegacao:=btrim(linha->>'descricao');
    trecho_lido:=btrim(linha->>'trecho');
    select v.hash into hash_oficial from privado.v248_versoes(p_item,p_interno) v where v.id=referencia;
    if hash_oficial is null or ((linha ? 'hash') and lower(linha->>'hash') is distinct from hash_oficial) or
      length(alegacao) not between 1 and 1500 or length(trecho_lido) not between 1 and 2000 or
      pagina_lida<1 or not exists (
        select 1 from public.paginas_documento p
        where p.id_versao_documento=referencia and p.numero_pagina=pagina_lida and
          (p.id_organizacao,p.id_contrato)=(p_item.id_organizacao,p_item.id_contrato) and
          strpos(regexp_replace(lower(coalesce(p.texto_extraido,'')),'[[:space:]]+',' ','g'),
                 regexp_replace(lower(trecho_lido),'[[:space:]]+',' ','g'))>0
      ) then
      raise exception using errcode='PT400',message='Confira a versão, o hash e o trecho literal na página informada.';
    end if;
    entrada:=jsonb_build_object('id_versao_documento',referencia,'pagina',pagina_lida,
      'trecho',trecho_lido,'descricao',alegacao,'hash',hash_oficial);
    if mapa @> jsonb_build_array(entrada) then
      raise exception using errcode='PT400',message='Remova referências duplicadas do mapa.';
    end if;
    mapa:=mapa||jsonb_build_array(entrada);
  end loop;
  return (select jsonb_agg(e order by e->>'descricao',e->>'id_versao_documento',(e->>'pagina')::integer,e->>'trecho')
    from jsonb_array_elements(mapa) e);
end
$$;

create function privado.v248_hash(p_item uuid,p_versao integer,p_texto text,p_fundamento text,p_mapa jsonb)
returns text language sql immutable set search_path='' as $$
  select encode(extensions.digest(jsonb_build_object('id_apontamento',p_item,'versao',p_versao,
    'texto',p_texto,'fundamento',p_fundamento,'mapa',p_mapa)::text,'sha256'),'hex')
$$;

create function privado.v248_inserir(
  p_item public.apontamentos_contratante,p_versao integer,p_texto text,p_fundamento text,p_mapa jsonb,
  p_status text,p_recomendada boolean,p_justificativa text
) returns public.contestacoes language plpgsql set search_path='' as $$
declare versao public.contestacoes;
begin
  insert into public.contestacoes(id_organizacao,id_contrato,id_competencia,id_ciclo,id_apontamento,
    versao,texto,fundamento,status_aprovacao,criado_por,hash,recomendada,justificativa_recomendacao)
  values(p_item.id_organizacao,p_item.id_contrato,p_item.id_competencia,p_item.id_ciclo,p_item.id,
    p_versao,p_texto,p_fundamento,p_status,auth.uid(),
    privado.v248_hash(p_item.id,p_versao,p_texto,p_fundamento,p_mapa),p_recomendada,p_justificativa)
  returning * into versao;

  insert into public.mapas_evidencias_contestacao(id_organizacao,id_contrato,id_competencia,id_contestacao,
    id_versao_documento,pagina,trecho,descricao,hash)
  select versao.id_organizacao,versao.id_contrato,versao.id_competencia,versao.id,
    e.id_versao_documento,e.pagina,e.trecho,e.descricao,e.hash
  from jsonb_to_recordset(p_mapa) as e(id_versao_documento uuid,pagina integer,trecho text,descricao text,hash text);
  return versao;
end
$$;

create function privado.v248_versao(p_item uuid)
returns integer language sql stable set search_path='' as $$
  select coalesce(max(c.versao),0) from public.contestacoes c where c.id_apontamento=p_item
$$;

create function privado.v248_recibo(
  p_comando uuid,p_versao public.contestacoes,p_evento text,p_antes jsonb,p_detalhes jsonb
) returns jsonb language plpgsql set search_path='' as $$
declare id_evento uuid; correlacao uuid; v_resultado jsonb;
begin
  id_evento:=privado.registrar_evento_auditoria(p_versao.id_organizacao,p_evento,'contestacoes',p_versao.id,
    p_antes,jsonb_build_object('id_apontamento',p_versao.id_apontamento,'versao',p_versao.versao,
      'hash',p_versao.hash,'status_aprovacao',p_versao.status_aprovacao)||p_detalhes,
    jsonb_build_object('comando_id',p_comando));
  select e.correlation_id into correlacao from public.eventos_auditoria e where e.id=id_evento;
  v_resultado:=jsonb_build_object('schema_versao','v248-v1','id_contestacao',p_versao.id,
    'id_apontamento',p_versao.id_apontamento,'versao',p_versao.versao,
    'hash',p_versao.hash,'status_aprovacao',p_versao.status_aprovacao,'correlation_id',correlacao);
  update public.comandos_idempotentes set status='concluido',resposta=v_resultado,
    atualizado_em=clock_timestamp() where id=p_comando;
  return v_resultado;
end
$$;

create function public.salvar_contestacao_v2(
  p_id_apontamento uuid,p_versao_esperada integer,p_texto text,p_fundamento text,p_evidencias jsonb,p_chave text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.apontamentos_contratante; nova public.contestacoes; comando jsonb; mapa jsonb;
begin
  item:=privado.v248_travar_item(p_id_apontamento);
  if not privado.v248_pode_submeter(item.id_organizacao) then
    raise exception using errcode='42501',message='Seu papel não permite submeter uma contestação.';
  end if;
  comando:=privado.v107_iniciar(item.id_organizacao,'v248_submeter',p_chave,
    jsonb_build_object('item',item.id,'versao',p_versao_esperada,'texto',p_texto,'fundamento',p_fundamento,'mapa',p_evidencias));
  if comando ? 'resposta' then return comando->'resposta'; end if;
  if not privado.v248_item_editavel(item) or p_versao_esperada is distinct from privado.v248_versao(item.id) then
    raise exception using errcode='PT409',message='A rodada ou a versão mudou. Releia a contestação.';
  end if;
  if coalesce(length(btrim(p_texto)),0) not between 1 and 20000 or
     coalesce(length(btrim(p_fundamento)),0) not between 1 and 5000 then
    raise exception using errcode='PT400',message='Informe a manifestação e seu fundamento.';
  end if;
  mapa:=privado.v248_mapa(item,p_evidencias);
  update public.contestacoes set status_aprovacao='substituida'
    where id_apontamento=item.id and status_aprovacao in ('pendente','aprovada')
      and (id_organizacao,id_contrato,id_competencia,id_ciclo)=
          (item.id_organizacao,item.id_contrato,item.id_competencia,item.id_ciclo);
  nova:=privado.v248_inserir(item,p_versao_esperada+1,btrim(p_texto),btrim(p_fundamento),mapa,'pendente',false,null);
  update public.apontamentos_contratante set status='contestado' where id=item.id;
  return privado.v248_recibo((comando->>'id')::uuid,nova,'ContestacaoSubmetida',null,
    jsonb_build_object('mapa',mapa,'autor',auth.uid()));
end
$$;

create function public.revisar_contestacao_v2(
  p_id_contestacao uuid,p_versao_esperada integer,p_aprovar boolean,p_fundamento text,p_chave text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.apontamentos_contratante; alvo public.contestacoes; anterior jsonb; comando jsonb;
        id_item uuid; mapa jsonb;
begin
  select c.id_apontamento into id_item from public.contestacoes c where c.id=p_id_contestacao;
  item:=privado.v248_travar_item(id_item);
  if not privado.v248_pode_revisar(item.id_organizacao) then
    raise exception using errcode='42501',message='Seu papel não permite revisar esta contestação.';
  end if;
  select * into alvo from public.contestacoes c where c.id=p_id_contestacao and
    (c.id_organizacao,c.id_contrato,c.id_competencia,c.id_ciclo,c.id_apontamento)=
    (item.id_organizacao,item.id_contrato,item.id_competencia,item.id_ciclo,item.id) for update;
  if not found then
    raise exception using errcode='42501',message='A versão da contestação está fora do escopo.';
  end if;
  comando:=privado.v107_iniciar(item.id_organizacao,'v248_revisar',p_chave,
    jsonb_build_object('contestacao',alvo.id,'versao',p_versao_esperada,'aprovar',p_aprovar,'fundamento',p_fundamento));
  if comando ? 'resposta' then return comando->'resposta'; end if;
  if p_aprovar is null or coalesce(length(btrim(p_fundamento)),0) not between 1 and 5000 then
    raise exception using errcode='PT400',message='Informe a decisão e o fundamento da revisão.';
  end if;
  if not privado.v248_item_editavel(item) or alvo.versao is distinct from p_versao_esperada or
    alvo.versao<>privado.v248_versao(item.id) or alvo.status_aprovacao<>'pendente' then
    raise exception using errcode='PT409',message='A revisão exige a versão submetida mais recente.';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id_versao_documento',e.id_versao_documento,'pagina',e.pagina,
     'trecho',e.trecho,'descricao',e.descricao,'hash',e.hash)),'[]'::jsonb) into mapa
    from public.mapas_evidencias_contestacao e where e.id_contestacao=alvo.id
    and (e.id_organizacao,e.id_contrato,e.id_competencia)=(item.id_organizacao,item.id_contrato,item.id_competencia);
  if p_aprovar then
    mapa:=privado.v248_mapa(item,mapa);
    if alvo.hash is distinct from privado.v248_hash(item.id,alvo.versao,alvo.texto,alvo.fundamento,mapa) then
      raise exception using errcode='PT409',message='O mapa não corresponde ao conteúdo registrado nesta versão.';
    end if;
  end if;
  anterior:=to_jsonb(alvo);
  update public.contestacoes set status_aprovacao=case when p_aprovar then 'aprovada' else 'rejeitada' end,
    aprovado_por=auth.uid(),aprovado_em=clock_timestamp()
    where id=alvo.id returning * into alvo;
  update public.apontamentos_contratante
    set status=case when p_aprovar then 'contestado_aprovado' else 'em_tratamento' end where id=item.id;
  return privado.v248_recibo((comando->>'id')::uuid,alvo,'ContestacaoRevisada',anterior,
    jsonb_build_object('aprovada',p_aprovar,'fundamento',btrim(p_fundamento),'revisor',auth.uid(),'mapa',mapa));
end
$$;

create function public.obter_contestacoes_v2(
  p_id_ciclo uuid,p_id_apontamento uuid,p_offset integer default 0,p_limite integer default 10,
  p_offset_fontes integer default 0
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  item public.apontamentos_contratante;
  pode_submeter boolean;
  pode_revisar boolean;
  editavel boolean;
  versao_atual integer;
  lista jsonb;
begin
  select a.* into item from public.apontamentos_contratante a join public.ciclos_diligencia c on c.id=a.id_ciclo
    and (c.id_organizacao,c.id_contrato,c.id_competencia)=(a.id_organizacao,a.id_contrato,a.id_competencia)
    where a.id=p_id_apontamento and a.id_ciclo=p_id_ciclo and auth.uid() is not null
      and privado.sessao_usuario_ativa() and privado.usuario_tem_acesso_contrato(a.id_contrato);
  if not found then
    raise exception using errcode='42501',message='Apontamento indisponível para contestação.';
  end if;
  pode_submeter:=privado.v248_pode_submeter(item.id_organizacao);
  pode_revisar:=privado.v248_pode_revisar(item.id_organizacao);
  if not (pode_submeter or pode_revisar) then
    raise exception using errcode='42501',message='Seu papel não dá acesso ao painel de contestação.';
  end if;
  if p_offset is null or p_offset<0 or p_limite is null or p_limite not between 1 and 30
    or p_offset_fontes is null or p_offset_fontes<0 then
    raise exception using errcode='PT400',message='Página de contestação inválida.';
  end if;
  editavel:=privado.v248_item_editavel(item);
  versao_atual:=privado.v248_versao(item.id);
  with pagina as (
    select c.* from public.contestacoes c
    where (c.id_organizacao,c.id_contrato,c.id_competencia,c.id_ciclo,c.id_apontamento)=
      (item.id_organizacao,item.id_contrato,item.id_competencia,item.id_ciclo,item.id)
    order by c.versao desc,c.id offset p_offset limit p_limite
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'versao',c.versao,'texto',c.texto,'fundamento',c.fundamento,'hash',c.hash,
    'recomendada',c.recomendada,'justificativa_recomendacao',c.justificativa_recomendacao,'criado_em',c.criado_em,
    'status_aprovacao',c.status_aprovacao,'aprovado_por',c.aprovado_por,'aprovado_em',c.aprovado_em,
    'resultado_final',c.resultado_final,'resultado_registrado_em',c.resultado_registrado_em,
    'revisar',editavel and pode_revisar and c.versao=versao_atual and c.status_aprovacao='pendente',
    'mapa',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'id_versao_documento',e.id_versao_documento,
      'titulo',v.titulo,'versao_documento',v.numero,'pagina',e.pagina,'descricao',e.descricao,'trecho',e.trecho,'hash',e.hash)
      order by e.descricao,e.id)
      from public.mapas_evidencias_contestacao e join privado.v248_versoes(item) v on v.id=e.id_versao_documento
      where e.id_contestacao=c.id and (e.id_organizacao,e.id_contrato,e.id_competencia)=
      (item.id_organizacao,item.id_contrato,item.id_competencia)),'[]'::jsonb)
  ) order by c.versao desc,c.id),'[]'::jsonb) into lista from pagina c;

  return jsonb_build_object('id_ciclo',item.id_ciclo,'id_apontamento',item.id,'versao_atual',versao_atual,
    'versao_apontamento',item.versao_registro,'submeter',editavel and pode_submeter,
    'solicitar_minuta',editavel and pode_submeter and not exists(
       select 1 from public.contestacoes c where c.id_apontamento=item.id and c.status_aprovacao='pendente'),
    'offset',p_offset,'limite',p_limite,
    'total',(select count(*) from public.contestacoes c where
      (c.id_organizacao,c.id_contrato,c.id_competencia,c.id_ciclo,c.id_apontamento)=
      (item.id_organizacao,item.id_contrato,item.id_competencia,item.id_ciclo,item.id)),
    'contestacoes',lista,'offset_fontes',p_offset_fontes,
    'total_fontes',(select count(*) from privado.v248_versoes(item)),
    'fontes',coalesce((select jsonb_agg(to_jsonb(v) order by v.vigente desc,v.titulo,v.numero desc,v.id)
      from (select * from privado.v248_versoes(item) order by vigente desc,titulo,numero desc,id offset p_offset_fontes limit 20) v),'[]'::jsonb),
    'minuta',(select jsonb_build_object('id',e.id,'estado',e.status) from public.execucoes_assincronas e
      where e.fila='ai' and e.entidade_tipo='minuta_contestacao' and e.entidade_id=item.id and
      (e.id_organizacao,e.id_contrato)=(item.id_organizacao,item.id_contrato)
      order by e.criado_em desc,e.id limit 1));
end
$$;

create function public.solicitar_minuta_contestacao_v2(
  p_id_apontamento uuid,p_versao_esperada integer,p_chave text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.apontamentos_contratante; v_comando jsonb; dados jsonb; v_id uuid; resposta_nova jsonb;
begin
  item:=privado.v248_travar_item(p_id_apontamento);
  if not privado.v248_pode_submeter(item.id_organizacao) then
    raise exception using errcode='42501',message='Seu papel não permite solicitar uma minuta.';
  end if;
  v_comando:=privado.v107_iniciar(item.id_organizacao,'v248_minuta',p_chave,
    jsonb_build_object('item',item.id,'versao',p_versao_esperada));
  if v_comando ? 'resposta' then return v_comando->'resposta'; end if;
  if not privado.v248_item_editavel(item) or p_versao_esperada is distinct from privado.v248_versao(item.id)
    or exists(select 1 from public.contestacoes c where c.id_apontamento=item.id and c.status_aprovacao='pendente')
    or exists(select 1 from public.execucoes_assincronas e where e.fila='ai' and e.entidade_tipo='minuta_contestacao'
      and e.entidade_id=item.id and e.status in ('enfileirado','processando')
      and e.metadados->>'versao_esperada'=p_versao_esperada::text) then
    raise exception using errcode='PT409',message='A contestação tem versão ou processamento em andamento.';
  end if;
  dados:=jsonb_build_object('id_apontamento',item.id,'id_ciclo',item.id_ciclo,'versao_esperada',p_versao_esperada);
  v_id:=privado.enfileirar_job('ai',item.id_organizacao,item.id_contrato,'minuta_contestacao',item.id,
    dados,'v248-minuta:'||(v_comando->>'id'));
  update public.execucoes_assincronas set metadados=coalesce(metadados,'{}'::jsonb)||dados where id=v_id;
  resposta_nova:=jsonb_build_object('id_execucao',v_id,'id_apontamento',item.id,'versao_esperada',p_versao_esperada);
  update public.comandos_idempotentes set status='concluido',resposta=resposta_nova,atualizado_em=clock_timestamp()
    where id=(v_comando->>'id')::uuid;
  perform privado.registrar_evento_auditoria(item.id_organizacao,'MinutaContestacaoSolicitada',
    'apontamentos_contratante',item.id,null,resposta_nova,jsonb_build_object('comando_id',v_comando->>'id'));
  return resposta_nova;
end
$$;

create function privado.v248_contexto_worker(p_id_execucao uuid,p_id_apontamento uuid)
returns jsonb language plpgsql set search_path='' as $$
declare item public.apontamentos_contratante; execucao public.execucoes_assincronas;
begin
  select * into execucao from public.execucoes_assincronas e where e.id=p_id_execucao and e.fila='ai'
    and e.entidade_tipo='minuta_contestacao' and e.entidade_id=p_id_apontamento;
  if not found then
    raise exception using errcode='42501',message='A execução não está vinculada à contestação.';
  end if;
  if not (execucao.metadados ? 'versao_esperada') then return jsonb_build_object('estado','obsoleta'); end if;
  item:=privado.v248_travar_item(p_id_apontamento,true);
  select * into strict execucao from public.execucoes_assincronas e where e.id=p_id_execucao;
  if (execucao.id_organizacao,execucao.id_contrato,execucao.metadados->>'id_apontamento',execucao.metadados->>'id_ciclo')
    is distinct from (item.id_organizacao,item.id_contrato,item.id::text,item.id_ciclo::text) then
    raise exception using errcode='42501',message='A execução está fora do escopo do apontamento.';
  end if;
  if execucao.metadados ? 'recibo_v248' then return execucao.metadados->'recibo_v248'; end if;
  if not privado.v248_item_editavel(item) or
     execucao.metadados->>'versao_esperada' is distinct from privado.v248_versao(item.id)::text then
    return jsonb_build_object('estado','obsoleta');
  end if;
  if execucao.status<>'processando' then
    raise exception using errcode='PT409',message='A execução ainda não está em processamento.';
  end if;
  return jsonb_build_object('estado','pendente','id_competencia',item.id_competencia,
    'descricao',item.descricao,'fundamento',item.fundamento);
end
$$;

create function public.obter_contexto_minuta_contestacao_v2(p_id_execucao uuid,p_id_apontamento uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare contexto jsonb; item public.apontamentos_contratante;
begin
  contexto:=privado.v248_contexto_worker(p_id_execucao,p_id_apontamento);
  if contexto->>'estado'<>'pendente' then return contexto; end if;
  select * into strict item from public.apontamentos_contratante where id=p_id_apontamento;
  return contexto||jsonb_build_object(
    'fontes',coalesce((select jsonb_agg(to_jsonb(p) order by p.id_versao_documento,p.pagina)
      from (select pg.id_versao_documento,pg.numero_pagina as pagina,substr(pg.texto_extraido,1,2500) as trecho,
        v.titulo,v.numero,v.hash from privado.v248_versoes(item,true) v join public.paginas_documento pg
          on pg.id_versao_documento=v.id and (pg.id_organizacao,pg.id_contrato)=(item.id_organizacao,item.id_contrato)
        where v.vigente and length(btrim(coalesce(pg.texto_extraido,'')))>0
        order by pg.id_versao_documento,pg.numero_pagina limit 24) p),'[]'::jsonb),
    'regras',coalesce((select jsonb_agg(to_jsonb(r) order by r.codigo)
      from (select codigo,substr(descricao,1,1200) as descricao from public.regras_conformidade
        where situacao='ativa' and (id_organizacao,id_contrato)=(item.id_organizacao,item.id_contrato)
        order by codigo limit 24) r),'[]'::jsonb));
end
$$;

create function public.registrar_minuta_contestacao_v2(
  p_id_execucao uuid,p_id_apontamento uuid,p_recomendada boolean,p_justificativa text,
  p_texto text,p_fundamento text,p_evidencias jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare contexto jsonb; item public.apontamentos_contratante; nova public.contestacoes;
        mapa jsonb; recibo jsonb;
begin
  contexto:=privado.v248_contexto_worker(p_id_execucao,p_id_apontamento);
  if contexto->>'estado'<>'pendente' then return contexto; end if;
  select * into strict item from public.apontamentos_contratante where id=p_id_apontamento;
  perform 1 from public.execucoes_assincronas e where e.id=p_id_execucao and e.status='processando' for update;
  if not found then
    raise exception using errcode='PT409',message='A execução mudou durante o processamento.';
  end if;
  if p_recomendada is null or coalesce(length(btrim(p_justificativa)),0) not between 1 and 3000 or
     coalesce(length(btrim(p_texto)),0) not between 1 and 20000 or
     coalesce(length(btrim(p_fundamento)),0) not between 1 and 5000 then
    raise exception using errcode='PT400',message='A recomendação precisa de justificativa, síntese e fundamento.';
  end if;
  mapa:=case when not p_recomendada and p_evidencias='[]'::jsonb then '[]'::jsonb
    else privado.v248_mapa(item,p_evidencias,true) end;
  nova:=privado.v248_inserir(item,privado.v248_versao(item.id)+1,btrim(p_texto),btrim(p_fundamento),
    mapa,'rascunho',p_recomendada,btrim(p_justificativa));
  recibo:=jsonb_build_object('estado','registrada','id_contestacao',nova.id,'id_apontamento',item.id,
    'id_execucao',p_id_execucao,'versao',nova.versao,'hash',nova.hash,'recomendada',nova.recomendada);
  update public.execucoes_assincronas set metadados=jsonb_set(metadados,'{recibo_v248}',recibo) where id=p_id_execucao;
  perform privado.registrar_evento_auditoria(item.id_organizacao,'MinutaContestacaoRegistrada','contestacoes',
    nova.id,null,recibo,jsonb_build_object('id_execucao',p_id_execucao));
  return recibo;
end
$$;

-- As assinaturas legadas convergem para o mesmo contrato e a mesma decisão humana.
create or replace function privado.criar_contestacao(p_id_apontamento uuid,p_texto text,p_fundamento text,p_evidencias jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare item public.apontamentos_contratante; dados jsonb;
begin
  item:=privado.v248_travar_item(p_id_apontamento);
  dados:=public.salvar_contestacao_v2(item.id,privado.v248_versao(item.id),p_texto,p_fundamento,p_evidencias,
    encode(extensions.digest(jsonb_build_array(item.id,item.versao_registro,p_texto,p_fundamento,p_evidencias)::text,'sha256'),'hex'));
  return (dados->>'id_contestacao')::uuid;
end
$$;

create or replace function privado.aprovar_contestacao(p_id_contestacao uuid,p_aprovar boolean,p_fundamento text default null)
returns void language plpgsql security definer set search_path='' as $$
declare n integer;
begin
  select c.versao into n from public.contestacoes c where c.id=p_id_contestacao;
  perform public.revisar_contestacao_v2(p_id_contestacao,n,p_aprovar,p_fundamento,
    encode(extensions.digest(jsonb_build_array(p_id_contestacao,p_aprovar,p_fundamento)::text,'sha256'),'hex'));
end
$$;

create or replace function privado.solicitar_minuta_contestacao(p_id_apontamento uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare item public.apontamentos_contratante; n integer; dados jsonb;
begin
  item:=privado.v248_travar_item(p_id_apontamento);
  n:=privado.v248_versao(item.id);
  dados:=public.solicitar_minuta_contestacao_v2(item.id,n,'legado-minuta:'||item.id||':'||n);
  return (dados->>'id_execucao')::uuid;
end
$$;

revoke all on function
  privado.v248_pode_submeter(uuid),privado.v248_pode_revisar(uuid),privado.v248_travar_item(uuid,boolean),
  privado.v248_item_editavel(public.apontamentos_contratante),privado.v248_versoes(public.apontamentos_contratante,boolean),
  privado.v248_mapa(public.apontamentos_contratante,jsonb,boolean),privado.v248_hash(uuid,integer,text,text,jsonb),
  privado.v248_inserir(public.apontamentos_contratante,integer,text,text,jsonb,text,boolean,text),
  privado.v248_versao(uuid),privado.v248_recibo(uuid,public.contestacoes,text,jsonb,jsonb),privado.v248_contexto_worker(uuid,uuid),
  public.obter_contestacoes_v2(uuid,uuid,integer,integer,integer),public.salvar_contestacao_v2(uuid,integer,text,text,jsonb,text),
  public.revisar_contestacao_v2(uuid,integer,boolean,text,text),public.solicitar_minuta_contestacao_v2(uuid,integer,text),
  public.obter_contexto_minuta_contestacao_v2(uuid,uuid),public.registrar_minuta_contestacao_v2(uuid,uuid,boolean,text,text,text,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function public.obter_contestacoes_v2(uuid,uuid,integer,integer,integer),
  public.salvar_contestacao_v2(uuid,integer,text,text,jsonb,text),public.revisar_contestacao_v2(uuid,integer,boolean,text,text),
  public.solicitar_minuta_contestacao_v2(uuid,integer,text) to authenticated;
grant execute on function public.obter_contexto_minuta_contestacao_v2(uuid,uuid),
  public.registrar_minuta_contestacao_v2(uuid,uuid,boolean,text,text,text,jsonb) to service_role;
commit;
