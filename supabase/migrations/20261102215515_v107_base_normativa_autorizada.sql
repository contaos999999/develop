-- ContaOS 4.1 V1-07. HML autorizado, issue25. Sem SQL dinâmico ou novas tabelas.
-- Funções auxiliares não são endpoints; apenas as quatro operações são concedidas.
create or replace function privado.v107_autorizar(p_org uuid,p_contrato uuid,p_aprovacao boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not privado.sessao_usuario_ativa() or not privado.usuario_possui_perfil(p_org,
    case when p_aprovacao then array['administrador','direcao_aprovador'] else array['administrador','gestor_contrato','juridico_conformidade'] end) then
    raise exception using errcode='42501',message='Você não tem permissão para esta operação normativa.';
  end if;
  if not exists(select 1 from public.organizacoes where id=p_org) or
     (p_contrato is not null and not exists(select 1 from public.contratos c where c.id=p_contrato and c.id_organizacao=p_org and privado.usuario_tem_acesso_contrato(c.id))) then
    raise exception using errcode='42501',message='O contrato não pertence ao seu escopo nesta organização.';
  end if;
end $$;
revoke all on function privado.v107_autorizar(uuid,uuid,boolean) from public,anon,authenticated;

create or replace function privado.v107_iniciar(p_org uuid,p_comando text,p_chave text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.comandos_idempotentes%rowtype; v_nome text:=p_comando||':'||auth.uid()::text;
v_hash text:=encode(extensions.digest(p_payload::text,'sha256'),'hex');
begin
  if auth.uid() is null or not privado.sessao_usuario_ativa() then raise exception using errcode='42501',message='Sua sessão não está ativa.'; end if;
  if p_chave is null or length(btrim(p_chave)) not between 1 and 200 then raise exception using errcode='PT400',message='Informe uma chave de operação válida.'; end if;
  insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,expira_em)
  values(p_org,v_nome,p_chave,v_hash,'iniciado',now()+interval '24 hours')
  on conflict(id_organizacao,comando,chave) do nothing returning * into v;
  if v.id is null then
    select * into v from public.comandos_idempotentes where id_organizacao=p_org and comando=v_nome and chave=p_chave for update;
    if v.hash_payload is distinct from v_hash then raise exception using errcode='PT409',message='Esta chave de operação já foi usada com dados diferentes.'; end if;
    if v.status='concluido' and v.resposta is not null then return jsonb_build_object('id',v.id,'resposta',v.resposta); end if;
    raise exception using errcode='PT409',message='Esta operação já está em processamento. Atualize a tela.';
  end if;
  return jsonb_build_object('id',v.id);
end $$;
revoke all on function privado.v107_iniciar(uuid,text,text,jsonb) from public,anon,authenticated;

create or replace function privado.v107_concluir(p_comando uuid,p_org uuid,p_evento text,p_entidade text,p_id uuid,p_antes jsonb,p_depois jsonb,p_resultado jsonb,p_fundamento text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_evento uuid; v_correlacao uuid; v_resposta jsonb;
begin
  v_evento:=privado.registrar_evento_auditoria(p_org,p_evento,p_entidade,p_id,p_antes,p_depois,jsonb_build_object('comando_id',p_comando,'fundamento',p_fundamento));
  select correlation_id into v_correlacao from public.eventos_auditoria where id=v_evento;
  v_resposta:=p_resultado||jsonb_build_object('schema_versao','v107-v1','correlation_id',v_correlacao);
  update public.comandos_idempotentes set status='concluido',resposta=v_resposta,atualizado_em=clock_timestamp() where id=p_comando;
  return v_resposta;
end $$;
revoke all on function privado.v107_concluir(uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,text) from public,anon,authenticated;

create or replace function privado.v107_capturar(p_org uuid,p_contrato uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r record; v jsonb:='{}';
begin
  -- Trava também as ainda em análise, coordenando com a liberação concorrente.
  for r in select id from public.competencias where id_organizacao=p_org and (p_contrato is null or id_contrato=p_contrato)
    order by id for update loop
    v:=v||jsonb_build_object(r.id::text,privado.snapshot_normativo_v107(r.id));
  end loop;
  return v;
end $$;
revoke all on function privado.v107_capturar(uuid,uuid) from public,anon,authenticated;

create or replace function privado.v107_invalidar(p_antes jsonb,p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r record;
begin
  for r in select key,value from jsonb_each(p_antes) order by key loop
    if r.value is distinct from privado.snapshot_normativo_v107(r.key::uuid) then
      perform privado.invalidar_portao_competencia(r.key::uuid,'Alteração material na base normativa.','fontes_normativas',p_id);
    end if;
  end loop;
end $$;
revoke all on function privado.v107_invalidar(jsonb,uuid) from public,anon,authenticated;

create or replace function privado.v107_tocar_fonte() returns trigger language plpgsql set search_path='' as $$
begin new.atualizado_em:=clock_timestamp(); return new; end $$;
revoke all on function privado.v107_tocar_fonte() from public,anon,authenticated;
drop trigger if exists fontes_normativas_touch on public.fontes_normativas;
create trigger fontes_normativas_touch before update on public.fontes_normativas for each row execute function privado.v107_tocar_fonte();

create or replace function privado.salvar_fonte_normativa_v107(p_id_organizacao uuid,p_id_contrato uuid,p_id_fonte uuid,p_tipo text,p_titulo text,p_referencia text,p_descricao text,p_situacao text,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.fontes_normativas%rowtype; v_antes jsonb; v_cmd jsonb; v_contexto jsonb;
begin
  perform privado.v107_autorizar(p_id_organizacao,p_id_contrato,false);
  if nullif(btrim(p_tipo),'') is null or nullif(btrim(p_titulo),'') is null or p_situacao is null or p_situacao not in('rascunho','ativa','inativa','revogada') then
    raise exception using errcode='PT400',message='Informe tipo, título e situação válidos.';
  end if;
  -- Autorização do registro antes de cache, inclusive em replays.
  if p_id_fonte is not null then
    select * into v from public.fontes_normativas where id=p_id_fonte and id_organizacao=p_id_organizacao and id_contrato is not distinct from p_id_contrato;
    if v.id is null then raise exception using errcode='PT404',message='Fonte normativa não encontrada neste escopo.'; end if;
    if p_situacao is distinct from v.situacao then perform privado.v107_autorizar(p_id_organizacao,p_id_contrato,true); end if;
  elsif p_situacao<>'rascunho' or p_versao_esperada is not null then
    raise exception using errcode='PT400',message='Uma nova fonte deve iniciar como rascunho.';
  end if;
  v_cmd:=privado.v107_iniciar(p_id_organizacao,'v107.salvar_fonte',p_chave_idempotencia,jsonb_build_array(p_id_contrato,p_id_fonte,p_tipo,p_titulo,p_referencia,p_descricao,p_situacao,p_versao_esperada));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  if p_id_fonte is null then
    insert into public.fontes_normativas(id_organizacao,id_contrato,tipo,titulo,referencia,descricao,situacao)
      values(p_id_organizacao,p_id_contrato,btrim(p_tipo),btrim(p_titulo),p_referencia,p_descricao,'rascunho') returning * into v;
  else
    select * into v from public.fontes_normativas where id=p_id_fonte for update;
    if p_versao_esperada is null or v.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='Esta fonte foi atualizada. Atualize a tela antes de salvar.'; end if;
    if p_situacao is distinct from v.situacao then perform privado.v107_autorizar(p_id_organizacao,p_id_contrato,true); end if;
    if p_situacao='ativa' and not exists(select 1 from public.versoes_fontes_normativas where id_fonte=v.id and aprovado_em is not null) then
      raise exception using errcode='PT400',message='A fonte precisa de uma versão aprovada para ser ativada.';
    end if;
    v_antes:=to_jsonb(v);
    v_contexto:=privado.v107_capturar(p_id_organizacao,p_id_contrato);
    update public.fontes_normativas set tipo=btrim(p_tipo),titulo=btrim(p_titulo),referencia=p_referencia,descricao=p_descricao,situacao=p_situacao where id=v.id returning * into v;
    perform privado.v107_invalidar(v_contexto,v.id);
  end if;
  return privado.v107_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V107FonteSalva','fontes_normativas',v.id,v_antes,to_jsonb(v),jsonb_build_object('fonte',to_jsonb(v)));
end $$;

create or replace function privado.registrar_versao_fonte_v107(p_id_organizacao uuid,p_id_fonte uuid,p_inicio_vigencia date,p_fim_vigencia date,p_id_arquivo uuid,p_conteudo_texto text,p_metadados jsonb,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f public.fontes_normativas%rowtype; v public.versoes_fontes_normativas%rowtype; a public.arquivos%rowtype; v_cmd jsonb; v_hash text; v_num integer;
begin
  perform privado.v107_autorizar(p_id_organizacao,null,false);
  select * into f from public.fontes_normativas where id=p_id_fonte and id_organizacao=p_id_organizacao;
  if f.id is null then raise exception using errcode='PT404',message='Fonte normativa não encontrada neste escopo.'; end if;
  perform privado.v107_autorizar(p_id_organizacao,f.id_contrato,false);
  if p_inicio_vigencia is null or p_fim_vigencia<p_inicio_vigencia or (p_id_arquivo is null and nullif(btrim(p_conteudo_texto),'') is null) or jsonb_typeof(p_metadados) is distinct from 'object' then
    raise exception using errcode='PT400',message='Informe vigência válida, metadados e um arquivo ou texto de origem.';
  end if;
  if p_id_arquivo is not null then
    select * into a from public.arquivos where id=p_id_arquivo and id_organizacao=p_id_organizacao and id_contrato is not distinct from f.id_contrato;
    if a.id is null or a.status_seguranca<>'aprovado' then raise exception using errcode='PT400',message='O arquivo não está disponível e aprovado neste escopo.'; end if;
  end if;
  v_cmd:=privado.v107_iniciar(p_id_organizacao,'v107.registrar_versao',p_chave_idempotencia,jsonb_build_array(p_id_fonte,p_inicio_vigencia,p_fim_vigencia,p_id_arquivo,p_conteudo_texto,p_metadados));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.fontes_normativas where id=f.id for update;
  select coalesce(max(versao),0)+1 into v_num from public.versoes_fontes_normativas where id_fonte=f.id;
  v_hash:=encode(extensions.digest(jsonb_build_array(p_inicio_vigencia,p_fim_vigencia,p_id_arquivo,a.sha256,p_conteudo_texto,p_metadados)::text,'sha256'),'hex');
  insert into public.versoes_fontes_normativas(id_organizacao,id_contrato,id_fonte,versao,inicio_vigencia,fim_vigencia,id_arquivo,conteudo_texto,metadados,hash)
    values(p_id_organizacao,f.id_contrato,f.id,v_num,p_inicio_vigencia,p_fim_vigencia,p_id_arquivo,p_conteudo_texto,p_metadados,v_hash) returning * into v;
  return privado.v107_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V107VersaoRegistrada','versoes_fontes_normativas',v.id,null,jsonb_build_object('id',v.id,'hash',v.hash,'versao',v.versao),jsonb_build_object('versao',to_jsonb(v)));
end $$;

create or replace function privado.aprovar_versao_fonte_v107(p_id_organizacao uuid,p_id_versao uuid,p_hash_esperado text,p_fundamento text,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.versoes_fontes_normativas%rowtype; f public.fontes_normativas%rowtype; v_cmd jsonb; v_antes jsonb; v_contexto jsonb;
begin
  perform privado.v107_autorizar(p_id_organizacao,null,true);
  select * into v from public.versoes_fontes_normativas where id=p_id_versao and id_organizacao=p_id_organizacao;
  select * into f from public.fontes_normativas where id=v.id_fonte and id_organizacao=p_id_organizacao and id_contrato is not distinct from v.id_contrato;
  if v.id is null or f.id is null then raise exception using errcode='PT404',message='Versão normativa não encontrada neste escopo.'; end if;
  perform privado.v107_autorizar(p_id_organizacao,f.id_contrato,true);
  if nullif(btrim(p_fundamento),'') is null then raise exception using errcode='PT400',message='Informe o fundamento da aprovação humana.'; end if;
  v_cmd:=privado.v107_iniciar(p_id_organizacao,'v107.aprovar_versao',p_chave_idempotencia,jsonb_build_array(p_id_versao,p_hash_esperado,p_fundamento));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.fontes_normativas where id=f.id for update;
  select * into v from public.versoes_fontes_normativas where id=p_id_versao for update;
  if v.hash is distinct from p_hash_esperado then raise exception using errcode='PT409',message='O conteúdo normativo mudou. Atualize e revise a versão.'; end if;
  if v.aprovado_em is not null then raise exception using errcode='PT409',message='Esta versão já foi aprovada. Atualize a tela.'; end if;
  if v.inicio_vigencia is null or v.fim_vigencia<v.inicio_vigencia or (v.id_arquivo is null and nullif(btrim(v.conteudo_texto),'') is null) then
    raise exception using errcode='PT400',message='A versão não tem vigência e origem válidas para aprovação.';
  end if;
  if v.id_arquivo is not null and not exists(select 1 from public.arquivos where id=v.id_arquivo and id_organizacao=p_id_organizacao and id_contrato is not distinct from f.id_contrato and status_seguranca='aprovado') then
    raise exception using errcode='PT400',message='O arquivo de origem não está aprovado neste escopo.';
  end if;
  v_antes:=jsonb_build_object('id',v.id,'hash',v.hash,'aprovado_em',v.aprovado_em);
  v_contexto:=privado.v107_capturar(p_id_organizacao,f.id_contrato);
  update public.versoes_fontes_normativas set aprovado_por=auth.uid(),aprovado_em=clock_timestamp() where id=v.id returning * into v;
  perform privado.v107_invalidar(v_contexto,f.id);
  return privado.v107_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V107VersaoAprovada','versoes_fontes_normativas',v.id,v_antes,jsonb_build_object('id',v.id,'hash',v.hash,'aprovado_por',v.aprovado_por,'aprovado_em',v.aprovado_em),jsonb_build_object('versao',to_jsonb(v)),p_fundamento);
end $$;

create or replace function privado.definir_aplicabilidade_fonte_v107(p_id_organizacao uuid,p_id_contrato uuid,p_id_versao uuid,p_aplicavel boolean,p_fundamento text,p_atualizado_em_esperado timestamptz,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.versoes_fontes_normativas%rowtype; f public.fontes_normativas%rowtype; a public.aplicabilidades_fonte%rowtype; v_cmd jsonb; v_antes jsonb; v_contexto jsonb;
begin
  perform privado.v107_autorizar(p_id_organizacao,p_id_contrato,true);
  if p_id_contrato is null or p_aplicavel is null or nullif(btrim(p_fundamento),'') is null then raise exception using errcode='PT400',message='Informe contrato, aplicabilidade e fundamento.'; end if;
  select * into v from public.versoes_fontes_normativas where id=p_id_versao and id_organizacao=p_id_organizacao and (id_contrato is null or id_contrato=p_id_contrato);
  select * into f from public.fontes_normativas where id=v.id_fonte and id_organizacao=p_id_organizacao and id_contrato is not distinct from v.id_contrato;
  if v.id is null or f.id is null then raise exception using errcode='PT404',message='Versão normativa não encontrada neste escopo.'; end if;
  if v.aprovado_em is null then raise exception using errcode='PT400',message='A versão precisa de aprovação humana antes da aplicabilidade.'; end if;
  v_cmd:=privado.v107_iniciar(p_id_organizacao,'v107.definir_aplicabilidade',p_chave_idempotencia,jsonb_build_array(p_id_contrato,p_id_versao,p_aplicavel,p_fundamento,p_atualizado_em_esperado));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.fontes_normativas where id=f.id for update;
  select * into a from public.aplicabilidades_fonte where id_fonte_versao=p_id_versao and id_contrato=p_id_contrato for update;
  if (a.id is null and p_atualizado_em_esperado is not null) or (a.id is not null and a.atualizado_em is distinct from p_atualizado_em_esperado) then
    raise exception using errcode='PT409',message='A aplicabilidade foi atualizada. Atualize a tela e revise os dados.';
  end if;
  v_antes:=case when a.id is null then null else to_jsonb(a) end;
  v_contexto:=privado.v107_capturar(p_id_organizacao,p_id_contrato);
  if a.id is null then
    insert into public.aplicabilidades_fonte(id_organizacao,id_contrato,id_fonte_versao,aplicavel,fundamento,aprovado_por,aprovado_em)
      values(p_id_organizacao,p_id_contrato,p_id_versao,p_aplicavel,p_fundamento,auth.uid(),clock_timestamp()) returning * into a;
  else
    update public.aplicabilidades_fonte set aplicavel=p_aplicavel,fundamento=p_fundamento,aprovado_por=auth.uid(),aprovado_em=clock_timestamp(),atualizado_em=clock_timestamp() where id=a.id returning * into a;
  end if;
  perform privado.v107_invalidar(v_contexto,f.id);
  return privado.v107_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V107AplicabilidadeDefinida','aplicabilidades_fonte',a.id,v_antes,to_jsonb(a),jsonb_build_object('aplicabilidade',to_jsonb(a)),p_fundamento);
end $$;

revoke insert,update,delete on public.fontes_normativas,public.versoes_fontes_normativas,public.aplicabilidades_fonte from authenticated;

create or replace function public.salvar_fonte_normativa_v107(p_id_organizacao uuid,p_id_contrato uuid,p_id_fonte uuid,p_tipo text,p_titulo text,p_referencia text,p_descricao text,p_situacao text,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.salvar_fonte_normativa_v107(p_id_organizacao,p_id_contrato,p_id_fonte,p_tipo,p_titulo,p_referencia,p_descricao,p_situacao,p_versao_esperada,p_chave_idempotencia);$$;
create or replace function public.registrar_versao_fonte_v107(p_id_organizacao uuid,p_id_fonte uuid,p_inicio_vigencia date,p_fim_vigencia date,p_id_arquivo uuid,p_conteudo_texto text,p_metadados jsonb,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.registrar_versao_fonte_v107(p_id_organizacao,p_id_fonte,p_inicio_vigencia,p_fim_vigencia,p_id_arquivo,p_conteudo_texto,p_metadados,p_chave_idempotencia);$$;
create or replace function public.aprovar_versao_fonte_v107(p_id_organizacao uuid,p_id_versao uuid,p_hash_esperado text,p_fundamento text,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.aprovar_versao_fonte_v107(p_id_organizacao,p_id_versao,p_hash_esperado,p_fundamento,p_chave_idempotencia);$$;
create or replace function public.definir_aplicabilidade_fonte_v107(p_id_organizacao uuid,p_id_contrato uuid,p_id_versao uuid,p_aplicavel boolean,p_fundamento text,p_atualizado_em_esperado timestamptz,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.definir_aplicabilidade_fonte_v107(p_id_organizacao,p_id_contrato,p_id_versao,p_aplicavel,p_fundamento,p_atualizado_em_esperado,p_chave_idempotencia);$$;

revoke all on function privado.salvar_fonte_normativa_v107(uuid,uuid,uuid,text,text,text,text,text,bigint,text),public.salvar_fonte_normativa_v107(uuid,uuid,uuid,text,text,text,text,text,bigint,text) from public,anon,authenticated;
revoke all on function privado.registrar_versao_fonte_v107(uuid,uuid,date,date,uuid,text,jsonb,text),public.registrar_versao_fonte_v107(uuid,uuid,date,date,uuid,text,jsonb,text) from public,anon,authenticated;
revoke all on function privado.aprovar_versao_fonte_v107(uuid,uuid,text,text,text),public.aprovar_versao_fonte_v107(uuid,uuid,text,text,text) from public,anon,authenticated;
revoke all on function privado.definir_aplicabilidade_fonte_v107(uuid,uuid,uuid,boolean,text,timestamptz,text),public.definir_aplicabilidade_fonte_v107(uuid,uuid,uuid,boolean,text,timestamptz,text) from public,anon,authenticated;
grant execute on function privado.salvar_fonte_normativa_v107(uuid,uuid,uuid,text,text,text,text,text,bigint,text),public.salvar_fonte_normativa_v107(uuid,uuid,uuid,text,text,text,text,text,bigint,text) to authenticated;
grant execute on function privado.registrar_versao_fonte_v107(uuid,uuid,date,date,uuid,text,jsonb,text),public.registrar_versao_fonte_v107(uuid,uuid,date,date,uuid,text,jsonb,text) to authenticated;
grant execute on function privado.aprovar_versao_fonte_v107(uuid,uuid,text,text,text),public.aprovar_versao_fonte_v107(uuid,uuid,text,text,text) to authenticated;
grant execute on function privado.definir_aplicabilidade_fonte_v107(uuid,uuid,uuid,boolean,text,timestamptz,text),public.definir_aplicabilidade_fonte_v107(uuid,uuid,uuid,boolean,text,timestamptz,text) to authenticated;

create or replace function privado.snapshot_normativo_v107(p_id_competencia uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('fonte',jsonb_build_object('id',f.id,'tipo',f.tipo,'titulo',f.titulo,'referencia',f.referencia,'descricao',f.descricao,'situacao',f.situacao,'versao_registro',f.versao_registro),
 'versao',jsonb_build_object('id',v.id,'versao',v.versao,'hash',v.hash,'inicio_vigencia',v.inicio_vigencia,'fim_vigencia',v.fim_vigencia),
 'aplicabilidade',case when a.id is null then null else jsonb_build_object('id',a.id,'aplicavel',a.aplicavel,'fundamento',a.fundamento) end) order by f.id,v.versao,v.id),'[]'::jsonb)
 from public.competencias c join public.fontes_normativas f on f.id_organizacao=c.id_organizacao and (f.id_contrato=c.id_contrato or f.id_contrato is null)
 join public.versoes_fontes_normativas v on v.id_fonte=f.id and v.id_organizacao=f.id_organizacao and v.id_contrato is not distinct from f.id_contrato
 left join public.aplicabilidades_fonte a on a.id_fonte_versao=v.id and a.id_contrato=c.id_contrato and a.id_organizacao=c.id_organizacao
 where c.id=p_id_competencia and f.situacao='ativa' and v.aprovado_em is not null
 and v.inicio_vigencia<=c.periodo_fim and (v.fim_vigencia is null or v.fim_vigencia>=c.periodo_inicio)
 and ((f.id_contrato=c.id_contrato and (a.id is null or (a.aplicavel and a.aprovado_em is not null)))
   or (f.id_contrato is null and a.aplicavel and a.aprovado_em is not null));
$$;
revoke all on function privado.snapshot_normativo_v107(uuid) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION privado.snapshot_contexto_competencia(p_id_competencia uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v public.competencias%rowtype;
  v_contrato jsonb;
begin
  select * into v from public.competencias where id=p_id_competencia;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;

  select to_jsonb(c)-'criado_em'-'atualizado_em' into v_contrato from public.contratos c where c.id=v.id_contrato;

  return jsonb_build_object(
    'competencia',jsonb_build_object('id',v.id,'referencia',v.competencia_referencia,'periodo_inicio',v.periodo_inicio,'periodo_fim',v.periodo_fim,'data_limite',v.data_limite),
    'contrato',coalesce(v_contrato,'{}'::jsonb),
    'requisitos',coalesce((
      select jsonb_agg((to_jsonb(r)-'criado_em') order by r.ordem,r.id)
      from public.requisitos_competencia r where r.id_competencia=v.id
    ),'[]'::jsonb),
    'documentos',coalesce((
      select jsonb_agg(jsonb_build_object(
        'documento',to_jsonb(d)-'criado_em'-'atualizado_em',
        'versao',to_jsonb(vd)-'criado_em'-'enviado_por'
      ) order by d.id)
      from public.documentos_competencia d
      join lateral (select x.* from public.versoes_documento x where x.id_documento_competencia=d.id order by x.numero_versao desc limit 1) vd on true
      where d.id_competencia=v.id and d.situacao='ativo'
    ),'[]'::jsonb),
    'propostas',coalesce((
      select jsonb_agg((to_jsonb(vp)-'criado_em'-'aprovado_em'-'aprovado_por') order by vp.vigencia_inicio,vp.numero_versao,vp.id)
      from public.versoes_proposta vp
      where vp.id_contrato=v.id_contrato and vp.vigencia_inicio<=v.periodo_fim and (vp.vigencia_fim is null or vp.vigencia_fim>=v.periodo_inicio)
    ),'[]'::jsonb),
    'linhas_orcamentarias',coalesce((
      select jsonb_agg((to_jsonb(l)-'criado_em') order by l.codigo,l.id)
      from public.linhas_orcamentarias l join public.versoes_proposta vp on vp.id=l.id_versao_proposta
      where l.id_contrato=v.id_contrato and vp.vigencia_inicio<=v.periodo_fim and (vp.vigencia_fim is null or vp.vigencia_fim>=v.periodo_inicio)
    ),'[]'::jsonb),
    'transacoes',coalesce((
      select jsonb_agg((to_jsonb(t)-'criado_em'-'pre_validada'-'pre_validada_em'-'status_fluxo') order by t.data,t.id)
      from public.transacoes_financeiras t where t.id_contrato=v.id_contrato and t.data between v.periodo_inicio and v.periodo_fim
    ),'[]'::jsonb),
    'conciliacoes',coalesce((
      select jsonb_agg((to_jsonb(c)-'criado_em'-'concluido_em'-'concluido_por') order by c.periodo,c.tipo,c.id)
      from public.conciliacoes c where c.id_contrato=v.id_contrato and c.periodo between date_trunc('month',v.periodo_inicio)::date and date_trunc('month',v.periodo_fim)::date
    ),'[]'::jsonb),
    'motor','contaos','versao_snapshot','4.1','idioma','pt-BR','timezone','America/Sao_Paulo'
  ) || case when privado.snapshot_normativo_v107(v.id)='[]'::jsonb then '{}'::jsonb
       else jsonb_build_object('base_normativa',privado.snapshot_normativo_v107(v.id)) end;
end;
$function$;

-- A extensão do hash só altera contextos com base normativa efetiva.
-- Portões legados desses contextos exigem reanálise; demais hashes são preservados.
do $$ declare r record;
begin
  for r in select id from public.competencias where situacao in('pode_apresentar_contratante','pode_reapresentar_contratante')
    and privado.snapshot_normativo_v107(id)<>'[]'::jsonb order by id for update loop
    perform privado.invalidar_portao_competencia(r.id,'Contexto normativo incorporado ao hash oficial V1-07.','base_normativa',null);
  end loop;
end $$;


