-- Complementa as identidades e relações isoladas do fixture do regular 47.
alter table public.documentos_contrato add column id_organizacao uuid,
  add column id_contrato uuid,add column titulo text,add column situacao text,add column versao_atual integer;
create table public.versoes_fontes_normativas (id uuid primary key);
create table public.paginas_documento(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_versao_documento uuid not null references public.versoes_documento(id) on delete cascade,numero_pagina integer not null check(numero_pagina>0),texto_extraido text,hash_texto text,metadados jsonb not null default '{}'::jsonb,criado_em timestamptz not null default now(),constraint paginas_documento_uk unique(id_versao_documento,numero_pagina));

create table public.contestacoes (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, id_apontamento uuid not null references public.apontamentos_contratante(id) on delete restrict,
 versao integer not null, texto text not null, fundamento text not null,
 status_aprovacao text not null default 'rascunho' check(status_aprovacao in ('rascunho','pendente','aprovada','rejeitada','substituida')),
 criado_por uuid references auth.users(id) on delete set null, aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz,
 hash text not null, criado_em timestamptz not null default now(), constraint contestacoes_uk unique(id_apontamento,versao));

create table public.mapas_evidencias_contestacao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_contestacao uuid not null references public.contestacoes(id) on delete restrict, id_versao_documento uuid references public.versoes_documento(id) on delete restrict,
 pagina integer, trecho text, descricao text, hash text, criado_em timestamptz not null default now());

create table public.regras_conformidade(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,codigo text not null,descricao text not null,tipo text not null default 'deterministica',efeito_portao boolean not null default true,id_fonte_versao uuid references public.versoes_fontes_normativas(id) on delete set null,configuracao jsonb not null default '{}'::jsonb,situacao text not null default 'rascunho' check(situacao in ('rascunho','ativa','inativa','substituida')),versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now(),constraint regras_conformidade_codigo_uk unique(id_contrato,codigo));
alter table public.contestacoes add column if not exists recomendada boolean not null default false;
alter table public.contestacoes add column if not exists justificativa_recomendacao text;
alter table public.contestacoes add column if not exists resultado_final text;
alter table public.contestacoes add column if not exists resultado_registrado_em timestamptz;

alter table public.contestacoes enable row level security;
alter table public.mapas_evidencias_contestacao enable row level security;
create policy contestacoes_select on public.contestacoes for select to authenticated
  using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy mapas_select on public.mapas_evidencias_contestacao for select to authenticated
  using(privado.usuario_tem_acesso_contrato(id_contrato));
grant select,insert on public.contestacoes,public.mapas_evidencias_contestacao to authenticated;
grant select,insert,update,delete on public.contestacoes,public.mapas_evidencias_contestacao to service_role;

create trigger apontamentos_fixture_touch before update on public.apontamentos_contratante
  for each row execute function privado.tocar_atualizado_em();
create or replace function privado.aprovar_contestacao(p_id_contestacao uuid,p_aprovar boolean,p_fundamento text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v public.contestacoes%rowtype;
begin
 select * into v from public.contestacoes where id=p_id_contestacao for update;
 if v.id is null then raise exception 'Contestação não encontrada.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Perfil sem permissão.'; end if;
 update public.contestacoes set status_aprovacao=case when p_aprovar then 'aprovada' else 'rejeitada' end,aprovado_por=auth.uid(),aprovado_em=now() where id=v.id;
 if p_aprovar then update public.apontamentos_contratante set status='contestado_aprovado' where id=v.id_apontamento; end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ContestacaoRevisada','contestacoes',v.id,null,jsonb_build_object('aprovada',p_aprovar,'fundamento',p_fundamento));
end;$$;
create function public.aprovar_contestacao(p_id_contestacao uuid,p_aprovar boolean,p_fundamento text default null) returns void language sql security invoker set search_path='' as $$select privado.aprovar_contestacao($1,$2,$3)$$;
create or replace function privado.avaliar_portao_reapresentacao(p_id_ciclo uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_org uuid; v_contrato uuid; v_total int; v_tratados int; v_abertos int;
begin
 select id_organizacao,id_contrato into v_org,v_contrato from public.ciclos_diligencia where id=p_id_ciclo;
 if v_org is null then raise exception 'Ciclo não encontrado.'; end if;
 if not privado.usuario_tem_acesso_contrato(v_contrato) then raise exception 'Acesso negado.'; end if;
 select count(*)::int,count(*) filter(where status in ('resolvido','nao_procedente','contestado_aprovado','encerrado'))::int,count(*) filter(where status not in ('resolvido','nao_procedente','contestado_aprovado','encerrado'))::int
 into v_total,v_tratados,v_abertos from public.apontamentos_contratante where id_ciclo=p_id_ciclo;
 return jsonb_build_object('total',v_total,'tratados',v_tratados,'abertos',v_abertos,'liberado',(v_total>0 and v_total=v_tratados));
end;$$;
create function public.avaliar_portao_reapresentacao(p_id_ciclo uuid) returns jsonb language sql stable security invoker set search_path='' as $$select privado.avaliar_portao_reapresentacao($1)$$;
create or replace function privado.criar_contestacao(p_id_apontamento uuid,p_texto text,p_fundamento text,p_evidencias jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.apontamentos_contratante%rowtype; v_ver int; v_id uuid; v_hash text; v_ev jsonb;
begin
 select * into v from public.apontamentos_contratante where id=p_id_apontamento;
 if v.id is null then raise exception 'Apontamento não encontrado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 select coalesce(max(versao),0)+1 into v_ver from public.contestacoes where id_apontamento=v.id;
 v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,v_ver::text,p_texto,p_fundamento,coalesce(p_evidencias,'[]'::jsonb)::text),'sha256'),'hex');
 insert into public.contestacoes(id_organizacao,id_contrato,id_competencia,id_ciclo,id_apontamento,versao,texto,fundamento,status_aprovacao,criado_por,hash)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id_ciclo,v.id,v_ver,p_texto,p_fundamento,'pendente',auth.uid(),v_hash) returning id into v_id;
 for v_ev in select * from jsonb_array_elements(coalesce(p_evidencias,'[]'::jsonb)) loop
   insert into public.mapas_evidencias_contestacao(id_organizacao,id_contrato,id_competencia,id_contestacao,id_versao_documento,pagina,trecho,descricao,hash)
   values(v.id_organizacao,v.id_contrato,v.id_competencia,v_id,nullif(v_ev->>'id_versao_documento','')::uuid,nullif(v_ev->>'pagina','')::integer,v_ev->>'trecho',v_ev->>'descricao',v_ev->>'hash');
 end loop;
 update public.apontamentos_contratante set status='contestado' where id=v.id;
 return v_id;
end;$$;
create function public.criar_contestacao(p_id_apontamento uuid,p_texto text,p_fundamento text,p_evidencias jsonb default '[]'::jsonb)
returns uuid language sql security invoker set search_path='' as $$select privado.criar_contestacao($1,$2,$3,$4)$$;
create or replace function privado.solicitar_minuta_contestacao(p_id_apontamento uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.apontamentos_contratante%rowtype; v_job uuid;
begin
 select * into v from public.apontamentos_contratante where id=p_id_apontamento;
 if v.id is null then raise exception 'Não encontramos o apontamento informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite solicitar uma minuta de contestação.'; end if;
 v_job:=privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'minuta_contestacao',v.id,jsonb_build_object('entidade_tipo','minuta_contestacao','id_apontamento',v.id),'minuta-contestacao:'||v.id::text||':'||v.versao_registro::text);
 return v_job;
end;$$;
create or replace function public.solicitar_minuta_contestacao(p_id_apontamento uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_minuta_contestacao($1)$$;
revoke all on function public.criar_contestacao(uuid,text,text,jsonb) from public,anon;
grant execute on function public.criar_contestacao(uuid,text,text,jsonb) to authenticated;
revoke all on function privado.criar_contestacao(uuid,text,text,jsonb) from public,anon;
grant execute on function privado.criar_contestacao(uuid,text,text,jsonb) to authenticated;
revoke all on function public.solicitar_minuta_contestacao(uuid) from public,anon;
grant execute on function public.solicitar_minuta_contestacao(uuid) to authenticated;
revoke all on function privado.solicitar_minuta_contestacao(uuid) from public,anon;
grant execute on function privado.solicitar_minuta_contestacao(uuid) to authenticated;
revoke all on function public.aprovar_contestacao(uuid,boolean,text) from public,anon;
grant execute on function public.aprovar_contestacao(uuid,boolean,text) to authenticated;
revoke all on function privado.aprovar_contestacao(uuid,boolean,text) from public,anon;
grant execute on function privado.aprovar_contestacao(uuid,boolean,text) to authenticated;
grant execute on function privado.aprovar_contestacao(uuid,boolean,text) to service_role;
revoke all on function public.avaliar_portao_reapresentacao(uuid) from public,anon;
grant execute on function public.avaliar_portao_reapresentacao(uuid) to authenticated;
revoke all on function privado.avaliar_portao_reapresentacao(uuid) from public,anon;
grant execute on function privado.avaliar_portao_reapresentacao(uuid) to authenticated;

insert into public.perfis_usuarios(codigo) values ('direcao_aprovador'),('juridico_conformidade');
insert into auth.users(id) values (fixture.id(7)),(fixture.id(8));
insert into public.usuarios(id_usuario,nome) values
  (fixture.id(7),'Aprovação restrita sintética'),(fixture.id(8),'Aprovação da rodada sintética');
insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos) values
  (fixture.id(47),fixture.id(11),fixture.id(7),'direcao_aprovador',false),
  (fixture.id(48),fixture.id(11),fixture.id(8),'direcao_aprovador',false);
insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato) values
  (fixture.id(11),fixture.id(47),fixture.id(23)),(fixture.id(11),fixture.id(48),fixture.id(21));

insert into public.documentos_contrato(id,id_organizacao,id_contrato,titulo,situacao,versao_atual)
values (fixture.id(310),fixture.id(11),fixture.id(21),'Norma sintética','ativo',1);
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash)
values(fixture.id(410),fixture.id(11),fixture.id(21),fixture.id(310),1,fixture.id(501),repeat('f',64));
insert into public.paginas_documento(id_organizacao,id_contrato,id_versao_documento,numero_pagina,texto_extraido)
select id_organizacao,id_contrato,id,1,'Assinatura conferida no comprovante. Valor conciliado na fonte.'
  from public.versoes_documento;
insert into public.regras_conformidade(id_organizacao,id_contrato,codigo,descricao,situacao) values
  (fixture.id(11),fixture.id(21),'REGRA-ESCOPO','A assinatura deve constar no comprovante.','ativa'),
  (fixture.id(12),fixture.id(22),'REGRA-ALHEIA','Regra do outro contrato.','ativa'),
  (fixture.id(11),fixture.id(21),'REGRA-INATIVA','Regra desativada.','inativa');


create function privado.rbac_permite(p_organizacao uuid,p_modulo text,p_acao text,p_contrato uuid)
returns boolean language sql stable set search_path='' as $$
  select p_organizacao is not null and p_acao='consultar' and
    p_modulo in ('arquivos','documentos_contrato','documentos_competencia') and
    privado.usuario_tem_acesso_contrato(p_contrato) and
    current_setting('contaos.fixture.bloqueio_doc',true) is distinct from p_modulo
$$;

create function fixture.assert48(condicao boolean,prova text) returns void language plpgsql as $$
begin
  if condicao is distinct from true then raise exception 'V248_FALHA: %',prova; end if;
end
$$;
create function fixture.recusar48(comando text,estado text) returns void language plpgsql as $$
begin
  execute comando;
  raise exception 'V248_FALHA: operação deveria retornar %',estado;
exception when others then
  if sqlstate<>estado then raise; end if;
end
$$;
create function fixture.cfg48(chave text) returns uuid language sql stable as $$
  select current_setting('contaos.fixture.'||chave)::uuid
$$;
create function fixture.mapa48(documento integer default 401,pagina integer default 1,
  trecho text default 'Assinatura conferida no comprovante.') returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('id_versao_documento',fixture.id(documento),
    'pagina',pagina,'trecho',trecho,'descricao','Assinatura prevista foi conferida.'))
$$;
