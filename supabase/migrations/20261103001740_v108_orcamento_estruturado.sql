begin;

alter table public.versoes_proposta
  add column if not exists id_arquivo_origem uuid references public.arquivos(id) on delete restrict;
create index if not exists versoes_proposta_arquivo_origem_idx on public.versoes_proposta(id_arquivo_origem) where id_arquivo_origem is not null;

alter table public.linhas_orcamentarias
  add column if not exists valor_mensal_previsto numeric(18,2),
  add column if not exists valor_anual_previsto numeric(18,2),
  add column if not exists permite_remanejamento boolean not null default false,
  add column if not exists observacoes text,
  add column if not exists versao_registro bigint not null default 1;

alter table public.linhas_orcamentarias drop constraint if exists linhas_orcamentarias_valor_mensal_ck;
alter table public.linhas_orcamentarias add constraint linhas_orcamentarias_valor_mensal_ck check(valor_mensal_previsto is null or valor_mensal_previsto>=0);
alter table public.linhas_orcamentarias drop constraint if exists linhas_orcamentarias_valor_anual_ck;
alter table public.linhas_orcamentarias add constraint linhas_orcamentarias_valor_anual_ck check(valor_anual_previsto is null or valor_anual_previsto>=0);
alter table public.linhas_orcamentarias drop constraint if exists linhas_orcamentarias_limite_remanejamento_ck;
alter table public.linhas_orcamentarias add constraint linhas_orcamentarias_limite_remanejamento_ck check(limite_remanejamento_percentual is null or (limite_remanejamento_percentual>=0 and limite_remanejamento_percentual<=100));
alter table public.linhas_orcamentarias drop constraint if exists linhas_orcamentarias_versao_registro_ck;
alter table public.linhas_orcamentarias add constraint linhas_orcamentarias_versao_registro_ck check(versao_registro>=1);

drop trigger if exists contaos_versao_linhas_orcamentarias on public.linhas_orcamentarias;
create trigger contaos_versao_linhas_orcamentarias before update on public.linhas_orcamentarias for each row execute function privado.controlar_versao_registro();

create or replace function privado.v108_autorizar(p_org uuid,p_contrato uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not privado.sessao_usuario_ativa() or not privado.usuario_possui_perfil(p_org,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]) then
    raise exception using errcode='42501',message='Você não tem permissão para alterar o orçamento deste contrato.';
  end if;
  if not exists(select 1 from public.organizacoes where id=p_org) or p_contrato is null or
     not exists(select 1 from public.contratos c where c.id=p_contrato and c.id_organizacao=p_org and privado.usuario_tem_acesso_contrato(c.id)) then
    raise exception using errcode='42501',message='O contrato não pertence ao seu escopo nesta organização.';
  end if;
end $$;
revoke all on function privado.v108_autorizar(uuid,uuid) from public,anon,authenticated;

create or replace function privado.v108_iniciar(p_org uuid,p_comando text,p_chave text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.comandos_idempotentes%rowtype; v_nome text:=p_comando||':'||auth.uid()::text; v_hash text:=encode(extensions.digest(p_payload::text,'sha256'),'hex');
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
revoke all on function privado.v108_iniciar(uuid,text,text,jsonb) from public,anon,authenticated;

create or replace function privado.v108_concluir(p_comando uuid,p_org uuid,p_evento text,p_entidade text,p_id uuid,p_antes jsonb,p_depois jsonb,p_resultado jsonb,p_fundamento text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_evento uuid; v_correlacao uuid; v_resposta jsonb;
begin
  v_evento:=privado.registrar_evento_auditoria(p_org,p_evento,p_entidade,p_id,p_antes,p_depois,jsonb_build_object('comando_id',p_comando,'fundamento',p_fundamento));
  select correlation_id into v_correlacao from public.eventos_auditoria where id=v_evento;
  v_resposta:=p_resultado||jsonb_build_object('schema_versao','v108-v1','correlation_id',v_correlacao);
  update public.comandos_idempotentes set status='concluido',resposta=v_resposta,atualizado_em=clock_timestamp() where id=p_comando;
  return v_resposta;
end $$;
revoke all on function privado.v108_concluir(uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,text) from public,anon,authenticated;

create or replace function privado.v108_hash_versao(p_id_versao uuid)
returns text language plpgsql stable security definer set search_path='' as $$
declare v public.versoes_proposta%rowtype; a public.arquivos%rowtype; v_linhas jsonb; v_payload jsonb;
begin
  select * into v from public.versoes_proposta where id=p_id_versao;
  if v.id is null then raise exception using errcode='PT404',message='Versão da proposta orçamentária não encontrada.'; end if;
  if v.id_arquivo_origem is not null then select * into a from public.arquivos where id=v.id_arquivo_origem; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'codigo',l.codigo,'grupo',l.grupo,'rubrica',l.rubrica,'subrubrica',l.subrubrica,'descricao',l.descricao,
    'valor_mensal_previsto',l.valor_mensal_previsto,'valor_anual_previsto',l.valor_anual_previsto,
    'permite_remanejamento',l.permite_remanejamento,'limite_remanejamento_percentual',l.limite_remanejamento_percentual,
    'observacoes',l.observacoes
  ) order by l.codigo,l.id),'[]'::jsonb) into v_linhas from public.linhas_orcamentarias l where l.id_versao_proposta=v.id;
  v_payload:=jsonb_build_object('id_proposta',v.id_proposta,'numero_versao',v.numero_versao,'vigencia_inicio',v.vigencia_inicio,'vigencia_fim',v.vigencia_fim,'arquivo_sha256',a.sha256,'linhas',v_linhas);
  return encode(extensions.digest(v_payload::text,'sha256'),'hex');
end $$;
revoke all on function privado.v108_hash_versao(uuid) from public,anon,authenticated;

create or replace function privado.v108_recalcular_versao(p_id_versao uuid)
returns public.versoes_proposta language plpgsql security definer set search_path='' as $$
declare v public.versoes_proposta%rowtype; v_total numeric(18,2);
begin
  select * into v from public.versoes_proposta where id=p_id_versao for update;
  if v.id is null then raise exception using errcode='PT404',message='Versão da proposta orçamentária não encontrada.'; end if;
  if v.situacao<>'rascunho' then raise exception using errcode='PT409',message='Uma versão publicada não pode ser alterada.'; end if;
  select coalesce(sum(coalesce(valor_anual_previsto,valor_mensal_previsto,0)),0)::numeric(18,2) into v_total from public.linhas_orcamentarias where id_versao_proposta=v.id;
  update public.versoes_proposta set valor_total=v_total,hash=privado.v108_hash_versao(v.id) where id=v.id returning * into v;
  return v;
end $$;
revoke all on function privado.v108_recalcular_versao(uuid) from public,anon,authenticated;

create or replace function privado.v108_proteger_versao_proposta()
returns trigger language plpgsql set search_path='' as $$
declare v_interno boolean:=coalesce(current_setting('contaos.v108_publicacao_interna',true),'')='1';
begin
  if tg_op='DELETE' and old.situacao<>'rascunho' then raise exception using errcode='PT409',message='Uma versão publicada não pode ser removida.'; end if;
  if tg_op='UPDATE' then
    if old.situacao='rascunho' and new.situacao<>'rascunho' and not v_interno then raise exception using errcode='PT409',message='Publique a proposta pela operação oficial do ContaOS.'; end if;
    if old.situacao in('publicada','substituida') then
      if not (v_interno and old.situacao='publicada' and new.situacao='substituida' and (to_jsonb(new)-array['situacao']::text[])=(to_jsonb(old)-array['situacao']::text[])) then
        raise exception using errcode='PT409',message='Uma versão publicada é imutável.';
      end if;
    end if;
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
revoke all on function privado.v108_proteger_versao_proposta() from public,anon,authenticated;
drop trigger if exists v108_proteger_versao_proposta on public.versoes_proposta;
create trigger v108_proteger_versao_proposta before update or delete on public.versoes_proposta for each row execute function privado.v108_proteger_versao_proposta();

create or replace function privado.v108_proteger_linha_orcamentaria()
returns trigger language plpgsql set search_path='' as $$
declare v_id uuid:=case when tg_op='DELETE' then old.id_versao_proposta else new.id_versao_proposta end; v_situacao text;
begin
  select situacao into v_situacao from public.versoes_proposta where id=v_id;
  if v_situacao is null then raise exception using errcode='PT404',message='Versão da proposta orçamentária não encontrada.'; end if;
  if v_situacao<>'rascunho' then raise exception using errcode='PT409',message='Rubricas de uma versão publicada são imutáveis.'; end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
revoke all on function privado.v108_proteger_linha_orcamentaria() from public,anon,authenticated;
drop trigger if exists v108_proteger_linha_orcamentaria on public.linhas_orcamentarias;
create trigger v108_proteger_linha_orcamentaria before insert or update or delete on public.linhas_orcamentarias for each row execute function privado.v108_proteger_linha_orcamentaria();

create or replace function privado.tg_invalidar_portao_proposta()
returns trigger language plpgsql security definer set search_path='' as $$
declare r record; v_contrato uuid; v_ini date; v_fim date; v_id uuid;
begin
  if tg_op='INSERT' then
    if new.situacao<>'publicada' then return new; end if;
    v_contrato:=new.id_contrato; v_ini:=new.vigencia_inicio; v_fim:=new.vigencia_fim; v_id:=new.id;
  elsif tg_op='UPDATE' then
    if not(old.situacao='rascunho' and new.situacao='publicada') then return new; end if;
    v_contrato:=new.id_contrato; v_ini:=new.vigencia_inicio; v_fim:=new.vigencia_fim; v_id:=new.id;
  else
    if old.situacao not in('publicada','substituida') then return old; end if;
    v_contrato:=old.id_contrato; v_ini:=old.vigencia_inicio; v_fim:=old.vigencia_fim; v_id:=old.id;
  end if;
  for r in select id from public.competencias where id_contrato=v_contrato and v_ini<=periodo_fim and (v_fim is null or v_fim>=periodo_inicio) order by id loop
    perform privado.invalidar_portao_competencia(r.id,'Alteração material de proposta orçamentária após liberação exige nova análise completa.',tg_table_name,v_id);
  end loop;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;

create or replace function privado.tg_invalidar_portao_linha_orcamentaria()
returns trigger language plpgsql security definer set search_path='' as $$
declare r record; v_contrato uuid:=coalesce(new.id_contrato,old.id_contrato); v_vp uuid:=coalesce(new.id_versao_proposta,old.id_versao_proposta); v_id uuid:=coalesce(new.id,old.id); v_ini date; v_fim date; v_situacao text;
begin
  select vigencia_inicio,vigencia_fim,situacao into v_ini,v_fim,v_situacao from public.versoes_proposta where id=v_vp;
  if v_situacao is null or v_situacao='rascunho' then if tg_op='DELETE' then return old; else return new; end if; end if;
  for r in select id from public.competencias where id_contrato=v_contrato and (v_ini is null or v_ini<=periodo_fim) and (v_fim is null or v_fim>=periodo_inicio) order by id loop
    perform privado.invalidar_portao_competencia(r.id,'Alteração material de linha orçamentária após liberação exige nova análise completa.',tg_table_name,v_id);
  end loop;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;

create or replace function privado.salvar_proposta_orcamentaria_v108(p_id_organizacao uuid,p_id_contrato uuid,p_id_proposta uuid,p_titulo text,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.propostas_orcamentarias%rowtype; v_antes jsonb; v_cmd jsonb;
begin
  perform privado.v108_autorizar(p_id_organizacao,p_id_contrato);
  if nullif(btrim(p_titulo),'') is null then raise exception using errcode='PT400',message='Informe o nome da proposta orçamentária.'; end if;
  if p_id_proposta is not null then
    select * into v from public.propostas_orcamentarias where id=p_id_proposta and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato;
    if v.id is null then raise exception using errcode='PT404',message='Proposta orçamentária não encontrada neste contrato.'; end if;
  elsif p_versao_esperada is not null then raise exception using errcode='PT400',message='Uma nova proposta não possui versão anterior.'; end if;
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.salvar_proposta',p_chave_idempotencia,jsonb_build_array(p_id_contrato,p_id_proposta,p_titulo,p_versao_esperada));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  if p_id_proposta is null then
    insert into public.propostas_orcamentarias(id_organizacao,id_contrato,titulo,situacao) values(p_id_organizacao,p_id_contrato,btrim(p_titulo),'rascunho') returning * into v;
  else
    select * into v from public.propostas_orcamentarias where id=p_id_proposta for update;
    if p_versao_esperada is null or v.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='A proposta foi atualizada por outra pessoa. Atualize a tela antes de salvar.'; end if;
    v_antes:=to_jsonb(v);
    update public.propostas_orcamentarias set titulo=btrim(p_titulo) where id=v.id returning * into v;
  end if;
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108PropostaSalva','propostas_orcamentarias',v.id,v_antes,to_jsonb(v),jsonb_build_object('proposta',to_jsonb(v)));
end $$;
revoke all on function privado.salvar_proposta_orcamentaria_v108(uuid,uuid,uuid,text,bigint,text) from public,anon,authenticated;

create or replace function privado.registrar_versao_proposta_v108(p_id_organizacao uuid,p_id_proposta uuid,p_vigencia_inicio date,p_vigencia_fim date,p_id_arquivo_origem uuid,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.propostas_orcamentarias%rowtype; v public.versoes_proposta%rowtype; a public.arquivos%rowtype; v_cmd jsonb; v_num integer; v_ultima date;
begin
  select * into p from public.propostas_orcamentarias where id=p_id_proposta and id_organizacao=p_id_organizacao;
  if p.id is null then raise exception using errcode='PT404',message='Proposta orçamentária não encontrada.'; end if;
  perform privado.v108_autorizar(p_id_organizacao,p.id_contrato);
  if p_vigencia_inicio is null or (p_vigencia_fim is not null and p_vigencia_fim<p_vigencia_inicio) then raise exception using errcode='PT400',message='Informe uma vigência válida para a proposta.'; end if;
  if p_id_arquivo_origem is null then raise exception using errcode='PT400',message='Anexe o documento-base da proposta orçamentária.'; end if;
  select * into a from public.arquivos where id=p_id_arquivo_origem and id_organizacao=p_id_organizacao and id_contrato=p.id_contrato;
  if a.id is null then raise exception using errcode='PT400',message='O documento-base não pertence a este contrato.'; end if;
  if a.status_seguranca not in('pendente','aprovado') then raise exception using errcode='PT400',message='O documento-base não está disponível para uso.'; end if;
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.registrar_versao',p_chave_idempotencia,jsonb_build_array(p_id_proposta,p_vigencia_inicio,p_vigencia_fim,p_id_arquivo_origem));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.propostas_orcamentarias where id=p.id for update;
  if exists(select 1 from public.versoes_proposta where id_proposta=p.id and situacao='rascunho') then raise exception using errcode='PT409',message='Já existe uma versão em rascunho. Conclua ou publique essa versão antes de iniciar outra.'; end if;
  select max(vigencia_inicio) into v_ultima from public.versoes_proposta where id_proposta=p.id and situacao in('publicada','substituida');
  if v_ultima is not null and p_vigencia_inicio<=v_ultima then raise exception using errcode='PT400',message='A nova versão deve iniciar após a versão publicada anterior.'; end if;
  select coalesce(max(numero_versao),0)+1 into v_num from public.versoes_proposta where id_proposta=p.id;
  insert into public.versoes_proposta(id_organizacao,id_contrato,id_proposta,numero_versao,vigencia_inicio,vigencia_fim,id_arquivo_origem,valor_total,hash,situacao)
    values(p_id_organizacao,p.id_contrato,p.id,v_num,p_vigencia_inicio,p_vigencia_fim,p_id_arquivo_origem,0,repeat('0',64),'rascunho') returning * into v;
  update public.versoes_proposta set hash=privado.v108_hash_versao(v.id) where id=v.id returning * into v;
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108VersaoRegistrada','versoes_proposta',v.id,null,to_jsonb(v),jsonb_build_object('versao',to_jsonb(v)));
end $$;
revoke all on function privado.registrar_versao_proposta_v108(uuid,uuid,date,date,uuid,text) from public,anon,authenticated;

create or replace function privado.salvar_linha_orcamentaria_v108(p_id_organizacao uuid,p_id_versao_proposta uuid,p_id_linha uuid,p_codigo text,p_grupo text,p_rubrica text,p_subrubrica text,p_descricao text,p_valor_mensal numeric,p_valor_anual numeric,p_permite_remanejamento boolean,p_limite_remanejamento_percentual numeric,p_observacoes text,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.versoes_proposta%rowtype; l public.linhas_orcamentarias%rowtype; v_antes jsonb; v_cmd jsonb; v_codigo text; v_descricao text; v_limite numeric; v_total numeric;
begin
  select * into v from public.versoes_proposta where id=p_id_versao_proposta and id_organizacao=p_id_organizacao;
  if v.id is null then raise exception using errcode='PT404',message='Versão da proposta orçamentária não encontrada.'; end if;
  perform privado.v108_autorizar(p_id_organizacao,v.id_contrato);
  if nullif(btrim(p_rubrica),'') is null then raise exception using errcode='PT400',message='Informe a rubrica orçamentária.'; end if;
  if p_valor_mensal is null and p_valor_anual is null then raise exception using errcode='PT400',message='Informe ao menos o valor mensal ou o valor anual previsto.'; end if;
  if coalesce(p_valor_mensal,0)<0 or coalesce(p_valor_anual,0)<0 then raise exception using errcode='PT400',message='Os valores previstos não podem ser negativos.'; end if;
  if p_limite_remanejamento_percentual is not null and (p_limite_remanejamento_percentual<0 or p_limite_remanejamento_percentual>100) then raise exception using errcode='PT400',message='O limite de remanejamento deve estar entre 0% e 100%.'; end if;
  v_limite:=case when coalesce(p_permite_remanejamento,false) then p_limite_remanejamento_percentual else null end;
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.salvar_linha',p_chave_idempotencia,jsonb_build_array(p_id_versao_proposta,p_id_linha,p_codigo,p_grupo,p_rubrica,p_subrubrica,p_descricao,p_valor_mensal,p_valor_anual,p_permite_remanejamento,v_limite,p_observacoes,p_versao_esperada));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  select * into v from public.versoes_proposta where id=p_id_versao_proposta for update;
  if v.situacao<>'rascunho' then raise exception using errcode='PT409',message='Uma versão publicada não pode ser alterada.'; end if;
  if p_id_linha is null then
    v_codigo:=coalesce(nullif(btrim(p_codigo),''),'RUB-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)));
    if exists(select 1 from public.linhas_orcamentarias where id_versao_proposta=v.id and codigo=v_codigo) then raise exception using errcode='PT409',message='Já existe uma rubrica com este código nesta versão.'; end if;
    v_descricao:=coalesce(nullif(btrim(p_descricao),''),concat_ws(' / ',nullif(btrim(p_grupo),''),btrim(p_rubrica),nullif(btrim(p_subrubrica),'')));
    v_total:=coalesce(p_valor_anual,p_valor_mensal,0);
    insert into public.linhas_orcamentarias(id_organizacao,id_contrato,id_versao_proposta,codigo,grupo,rubrica,subrubrica,descricao,quantidade,valor_unitario,valor_total,valor_mensal_previsto,valor_anual_previsto,permite_remanejamento,limite_remanejamento_percentual,observacoes)
      values(p_id_organizacao,v.id_contrato,v.id,v_codigo,nullif(btrim(p_grupo),''),btrim(p_rubrica),nullif(btrim(p_subrubrica),''),v_descricao,1,v_total,v_total,p_valor_mensal,p_valor_anual,coalesce(p_permite_remanejamento,false),v_limite,nullif(btrim(p_observacoes),'')) returning * into l;
  else
    select * into l from public.linhas_orcamentarias where id=p_id_linha and id_versao_proposta=v.id and id_organizacao=p_id_organizacao for update;
    if l.id is null then raise exception using errcode='PT404',message='Rubrica orçamentária não encontrada nesta versão.'; end if;
    if p_versao_esperada is null or l.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='A rubrica foi atualizada por outra pessoa. Atualize a tela antes de salvar.'; end if;
    v_codigo:=coalesce(nullif(btrim(p_codigo),''),l.codigo);
    if exists(select 1 from public.linhas_orcamentarias where id_versao_proposta=v.id and codigo=v_codigo and id<>l.id) then raise exception using errcode='PT409',message='Já existe uma rubrica com este código nesta versão.'; end if;
    v_descricao:=coalesce(nullif(btrim(p_descricao),''),concat_ws(' / ',nullif(btrim(p_grupo),''),btrim(p_rubrica),nullif(btrim(p_subrubrica),'')));
    v_total:=coalesce(p_valor_anual,p_valor_mensal,0); v_antes:=to_jsonb(l);
    update public.linhas_orcamentarias set codigo=v_codigo,grupo=nullif(btrim(p_grupo),''),rubrica=btrim(p_rubrica),subrubrica=nullif(btrim(p_subrubrica),''),descricao=v_descricao,quantidade=1,valor_unitario=v_total,valor_total=v_total,valor_mensal_previsto=p_valor_mensal,valor_anual_previsto=p_valor_anual,permite_remanejamento=coalesce(p_permite_remanejamento,false),limite_remanejamento_percentual=v_limite,observacoes=nullif(btrim(p_observacoes),'') where id=l.id returning * into l;
  end if;
  v:=privado.v108_recalcular_versao(v.id);
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108LinhaSalva','linhas_orcamentarias',l.id,v_antes,to_jsonb(l),jsonb_build_object('linha',to_jsonb(l),'versao',to_jsonb(v)));
end $$;
revoke all on function privado.salvar_linha_orcamentaria_v108(uuid,uuid,uuid,text,text,text,text,text,numeric,numeric,boolean,numeric,text,bigint,text) from public,anon,authenticated;

create or replace function privado.remover_linha_orcamentaria_v108(p_id_organizacao uuid,p_id_linha uuid,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare l public.linhas_orcamentarias%rowtype; v public.versoes_proposta%rowtype; v_cmd jsonb; v_antes jsonb;
begin
  select * into l from public.linhas_orcamentarias where id=p_id_linha and id_organizacao=p_id_organizacao;
  if l.id is null then raise exception using errcode='PT404',message='Rubrica orçamentária não encontrada.'; end if;
  perform privado.v108_autorizar(p_id_organizacao,l.id_contrato);
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.remover_linha',p_chave_idempotencia,jsonb_build_array(p_id_linha,p_versao_esperada));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  select * into v from public.versoes_proposta where id=l.id_versao_proposta for update;
  if v.situacao<>'rascunho' then raise exception using errcode='PT409',message='Rubricas de uma versão publicada são imutáveis.'; end if;
  select * into l from public.linhas_orcamentarias where id=p_id_linha for update;
  if p_versao_esperada is null or l.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='A rubrica foi atualizada por outra pessoa. Atualize a tela antes de remover.'; end if;
  v_antes:=to_jsonb(l); delete from public.linhas_orcamentarias where id=l.id;
  v:=privado.v108_recalcular_versao(v.id);
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108LinhaRemovida','linhas_orcamentarias',l.id,v_antes,null,jsonb_build_object('id_linha',l.id,'removida',true,'versao',to_jsonb(v)));
end $$;
revoke all on function privado.remover_linha_orcamentaria_v108(uuid,uuid,bigint,text) from public,anon,authenticated;

create or replace function privado.publicar_versao_proposta_v108(p_id_organizacao uuid,p_id_versao uuid,p_hash_esperado text,p_fundamento text,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.versoes_proposta%rowtype; p public.propostas_orcamentarias%rowtype; a public.arquivos%rowtype; v_cmd jsonb; v_hash text; v_antes jsonb; r record;
begin
  select * into v from public.versoes_proposta where id=p_id_versao and id_organizacao=p_id_organizacao;
  if v.id is null then raise exception using errcode='PT404',message='Versão da proposta orçamentária não encontrada.'; end if;
  select * into p from public.propostas_orcamentarias where id=v.id_proposta and id_organizacao=p_id_organizacao and id_contrato=v.id_contrato;
  if p.id is null then raise exception using errcode='PT404',message='Proposta orçamentária não encontrada.'; end if;
  perform privado.v108_autorizar(p_id_organizacao,v.id_contrato);
  if nullif(btrim(p_fundamento),'') is null then raise exception using errcode='PT400',message='Informe o fundamento da publicação da proposta.'; end if;
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.publicar_versao',p_chave_idempotencia,jsonb_build_array(p_id_versao,p_hash_esperado,p_fundamento));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.propostas_orcamentarias where id=p.id for update;
  select * into v from public.versoes_proposta where id=p_id_versao for update;
  perform 1 from public.linhas_orcamentarias where id_versao_proposta=v.id order by id for update;
  if v.situacao<>'rascunho' then raise exception using errcode='PT409',message='Esta versão já foi publicada ou substituída.'; end if;
  if v.vigencia_inicio is null or (v.vigencia_fim is not null and v.vigencia_fim<v.vigencia_inicio) then raise exception using errcode='PT400',message='A versão não possui vigência válida.'; end if;
  if not exists(select 1 from public.linhas_orcamentarias where id_versao_proposta=v.id) then raise exception using errcode='PT400',message='Inclua ao menos uma rubrica antes de publicar a proposta.'; end if;
  select * into a from public.arquivos where id=v.id_arquivo_origem and id_organizacao=p_id_organizacao and id_contrato=v.id_contrato;
  if a.id is null or a.status_seguranca<>'aprovado' then raise exception using errcode='PT400',message='O documento-base precisa estar aprovado antes da publicação.'; end if;
  v_hash:=privado.v108_hash_versao(v.id);
  if p_hash_esperado is null or v_hash is distinct from p_hash_esperado or v.hash is distinct from p_hash_esperado then raise exception using errcode='PT409',message='A proposta mudou. Atualize a tela e revise a versão antes de publicar.'; end if;
  for r in select id from public.competencias where id_contrato=v.id_contrato and v.vigencia_inicio<=periodo_fim and (v.vigencia_fim is null or v.vigencia_fim>=periodo_inicio) order by id for update loop null; end loop;
  v_antes:=jsonb_build_object('proposta',to_jsonb(p),'versao',to_jsonb(v));
  perform set_config('contaos.v108_publicacao_interna','1',true);
  update public.versoes_proposta set situacao='substituida' where id_proposta=p.id and id<>v.id and situacao='publicada';
  update public.versoes_proposta set situacao='publicada',aprovado_por=auth.uid(),aprovado_em=clock_timestamp(),hash=v_hash where id=v.id returning * into v;
  update public.propostas_orcamentarias set situacao='ativa',versao_atual=v.numero_versao where id=p.id returning * into p;
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108VersaoPublicada','versoes_proposta',v.id,v_antes,jsonb_build_object('proposta',to_jsonb(p),'versao',to_jsonb(v)),jsonb_build_object('proposta',to_jsonb(p),'versao',to_jsonb(v)),p_fundamento);
end $$;
revoke all on function privado.publicar_versao_proposta_v108(uuid,uuid,text,text,text) from public,anon,authenticated;

create or replace function privado.snapshot_contexto_competencia(p_id_competencia uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v public.competencias%rowtype; v_contrato jsonb;
begin
  select * into v from public.competencias where id=p_id_competencia;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  select to_jsonb(c)-'criado_em'-'atualizado_em' into v_contrato from public.contratos c where c.id=v.id_contrato;
  return jsonb_build_object(
    'competencia',jsonb_build_object('id',v.id,'referencia',v.competencia_referencia,'periodo_inicio',v.periodo_inicio,'periodo_fim',v.periodo_fim,'data_limite',v.data_limite),
    'contrato',coalesce(v_contrato,'{}'::jsonb),
    'requisitos',coalesce((select jsonb_agg((to_jsonb(r)-'criado_em') order by r.ordem,r.id) from public.requisitos_competencia r where r.id_competencia=v.id),'[]'::jsonb),
    'documentos',coalesce((select jsonb_agg(jsonb_build_object('documento',to_jsonb(d)-'criado_em'-'atualizado_em','versao',to_jsonb(vd)-'criado_em'-'enviado_por') order by d.id) from public.documentos_competencia d join lateral(select x.* from public.versoes_documento x where x.id_documento_competencia=d.id order by x.numero_versao desc limit 1) vd on true where d.id_competencia=v.id and d.situacao='ativo'),'[]'::jsonb),
    'propostas',coalesce((select jsonb_agg((to_jsonb(x)-'criado_em'-'aprovado_em'-'aprovado_por') order by x.vigencia_inicio,x.numero_versao,x.id) from (
      select vp.*,lead(vp.vigencia_inicio) over(partition by vp.id_proposta order by vp.vigencia_inicio,vp.numero_versao,vp.id) proxima_inicio
      from public.versoes_proposta vp where vp.id_contrato=v.id_contrato and vp.situacao in('publicada','substituida') and vp.aprovado_em is not null
    ) x where x.vigencia_inicio<=v.periodo_fim and (x.vigencia_fim is null or x.vigencia_fim>=v.periodo_inicio) and (x.proxima_inicio is null or x.proxima_inicio-1>=v.periodo_inicio)),'[]'::jsonb),
    'linhas_orcamentarias',coalesce((select jsonb_agg((to_jsonb(l)-'criado_em') order by l.codigo,l.id) from public.linhas_orcamentarias l join (
      select vp.id,vp.vigencia_inicio,vp.vigencia_fim,lead(vp.vigencia_inicio) over(partition by vp.id_proposta order by vp.vigencia_inicio,vp.numero_versao,vp.id) proxima_inicio
      from public.versoes_proposta vp where vp.id_contrato=v.id_contrato and vp.situacao in('publicada','substituida') and vp.aprovado_em is not null
    ) x on x.id=l.id_versao_proposta where x.vigencia_inicio<=v.periodo_fim and (x.vigencia_fim is null or x.vigencia_fim>=v.periodo_inicio) and (x.proxima_inicio is null or x.proxima_inicio-1>=v.periodo_inicio)),'[]'::jsonb),
    'transacoes',coalesce((select jsonb_agg((to_jsonb(t)-'criado_em'-'pre_validada'-'pre_validada_em'-'status_fluxo') order by t.data,t.id) from public.transacoes_financeiras t where t.id_contrato=v.id_contrato and t.data between v.periodo_inicio and v.periodo_fim),'[]'::jsonb),
    'conciliacoes',coalesce((select jsonb_agg((to_jsonb(c)-'criado_em'-'concluido_em'-'concluido_por') order by c.periodo,c.tipo,c.id) from public.conciliacoes c where c.id_contrato=v.id_contrato and c.periodo between date_trunc('month',v.periodo_inicio)::date and date_trunc('month',v.periodo_fim)::date),'[]'::jsonb),
    'motor','contaos','versao_snapshot','4.1','idioma','pt-BR','timezone','America/Sao_Paulo'
  ) || case when privado.snapshot_normativo_v107(v.id)='[]'::jsonb then '{}'::jsonb else jsonb_build_object('base_normativa',privado.snapshot_normativo_v107(v.id)) end;
end $$;

create or replace function public.salvar_proposta_orcamentaria_v108(p_id_organizacao uuid,p_id_contrato uuid,p_id_proposta uuid,p_titulo text,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.salvar_proposta_orcamentaria_v108(p_id_organizacao,p_id_contrato,p_id_proposta,p_titulo,p_versao_esperada,p_chave_idempotencia);$$;
create or replace function public.registrar_versao_proposta_v108(p_id_organizacao uuid,p_id_proposta uuid,p_vigencia_inicio date,p_vigencia_fim date,p_id_arquivo_origem uuid,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.registrar_versao_proposta_v108(p_id_organizacao,p_id_proposta,p_vigencia_inicio,p_vigencia_fim,p_id_arquivo_origem,p_chave_idempotencia);$$;
create or replace function public.salvar_linha_orcamentaria_v108(p_id_organizacao uuid,p_id_versao_proposta uuid,p_id_linha uuid,p_codigo text,p_grupo text,p_rubrica text,p_subrubrica text,p_descricao text,p_valor_mensal numeric,p_valor_anual numeric,p_permite_remanejamento boolean,p_limite_remanejamento_percentual numeric,p_observacoes text,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.salvar_linha_orcamentaria_v108(p_id_organizacao,p_id_versao_proposta,p_id_linha,p_codigo,p_grupo,p_rubrica,p_subrubrica,p_descricao,p_valor_mensal,p_valor_anual,p_permite_remanejamento,p_limite_remanejamento_percentual,p_observacoes,p_versao_esperada,p_chave_idempotencia);$$;
create or replace function public.remover_linha_orcamentaria_v108(p_id_organizacao uuid,p_id_linha uuid,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.remover_linha_orcamentaria_v108(p_id_organizacao,p_id_linha,p_versao_esperada,p_chave_idempotencia);$$;
create or replace function public.publicar_versao_proposta_v108(p_id_organizacao uuid,p_id_versao uuid,p_hash_esperado text,p_fundamento text,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.publicar_versao_proposta_v108(p_id_organizacao,p_id_versao,p_hash_esperado,p_fundamento,p_chave_idempotencia);$$;

revoke all on function public.salvar_proposta_orcamentaria_v108(uuid,uuid,uuid,text,bigint,text) from public,anon;
revoke all on function public.registrar_versao_proposta_v108(uuid,uuid,date,date,uuid,text) from public,anon;
revoke all on function public.salvar_linha_orcamentaria_v108(uuid,uuid,uuid,text,text,text,text,text,numeric,numeric,boolean,numeric,text,bigint,text) from public,anon;
revoke all on function public.remover_linha_orcamentaria_v108(uuid,uuid,bigint,text) from public,anon;
revoke all on function public.publicar_versao_proposta_v108(uuid,uuid,text,text,text) from public,anon;
grant execute on function public.salvar_proposta_orcamentaria_v108(uuid,uuid,uuid,text,bigint,text) to authenticated;
grant execute on function public.registrar_versao_proposta_v108(uuid,uuid,date,date,uuid,text) to authenticated;
grant execute on function public.salvar_linha_orcamentaria_v108(uuid,uuid,uuid,text,text,text,text,text,numeric,numeric,boolean,numeric,text,bigint,text) to authenticated;
grant execute on function public.remover_linha_orcamentaria_v108(uuid,uuid,bigint,text) to authenticated;
grant execute on function public.publicar_versao_proposta_v108(uuid,uuid,text,text,text) to authenticated;

revoke insert,update,delete on public.propostas_orcamentarias from authenticated;
revoke insert,update,delete on public.versoes_proposta from authenticated;
revoke insert,update,delete on public.linhas_orcamentarias from authenticated;

commit;
