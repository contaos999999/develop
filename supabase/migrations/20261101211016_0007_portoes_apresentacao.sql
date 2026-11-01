begin;

create table public.aprovacoes (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  tipo text not null check(tipo in ('apresentacao','reapresentacao','parecer_interno','contestacao','regra','controle','remediacao')),
  status text not null default 'aprovada' check(status in ('pendente','aprovada','rejeitada','revogada')),
  aprovado_por uuid references auth.users(id) on delete set null,
  fundamento text,
  hash_contexto text not null,
  percentual_conformidade numeric(5,2),
  id_execucao_analise uuid references public.execucoes_analise(id) on delete restrict,
  criado_em timestamptz not null default now()
);
create index aprovacoes_comp_idx on public.aprovacoes(id_competencia,tipo,criado_em desc);

create table public.pacotes_competencia (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  numero integer not null,
  tipo text not null default 'apresentacao' check(tipo in ('apresentacao','reapresentacao')),
  status text not null default 'congelado' check(status in ('preparando','congelado','apresentado','substituido')),
  hash_pacote text not null,
  criado_por uuid references auth.users(id) on delete set null,
  congelado_em timestamptz,
  criado_em timestamptz not null default now(),
  constraint pacotes_competencia_uk unique(id_competencia,numero,tipo)
);
create index pacotes_competencia_comp_idx on public.pacotes_competencia(id_competencia,tipo,numero desc);

create table public.itens_pacote_competencia (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  id_pacote uuid not null references public.pacotes_competencia(id) on delete restrict,
  entidade_tipo text not null,
  entidade_id uuid not null,
  versao_id uuid,
  hash text not null,
  ordem integer not null default 0,
  metadados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index itens_pacote_competencia_idx on public.itens_pacote_competencia(id_pacote,ordem);

create table public.apresentacoes_contratante (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  id_pacote uuid not null references public.pacotes_competencia(id) on delete restrict,
  numero_rodada integer not null default 1,
  tipo text not null default 'apresentacao' check(tipo in ('apresentacao','reapresentacao')),
  protocolo text,
  forma_apresentacao text,
  id_comprovante_arquivo uuid references public.arquivos(id) on delete restrict,
  idempotency_key text not null,
  apresentado_em timestamptz not null default now(),
  apresentado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  constraint apresentacoes_idempotency_uk unique(id_organizacao,idempotency_key)
);
create index apresentacoes_comp_idx on public.apresentacoes_contratante(id_competencia,numero_rodada desc);
create unique index apresentacoes_protocolo_uidx on public.apresentacoes_contratante(id_contrato,protocolo) where protocolo is not null;

alter table public.aprovacoes enable row level security;
alter table public.pacotes_competencia enable row level security;
alter table public.itens_pacote_competencia enable row level security;
alter table public.apresentacoes_contratante enable row level security;

create policy aprovacoes_select on public.aprovacoes for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy pacotes_competencia_select on public.pacotes_competencia for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy itens_pacote_competencia_select on public.itens_pacote_competencia for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy apresentacoes_contratante_select on public.apresentacoes_contratante for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));

create or replace function public.aprovar_apresentacao(p_id_competencia uuid,p_fundamento text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_portao jsonb; v_exec uuid; v_aprov uuid; v_hash text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]) then raise exception 'Perfil sem permissão para aprovação.'; end if;
  if v.situacao not in ('em_analise','em_reanalise','pendente_correcao','rascunho') then raise exception 'Situação não elegível para aprovação.'; end if;
  v_portao:=public.avaliar_portao_conformidade(v.id);
  if coalesce((v_portao->>'liberado')::boolean,false) is not true then raise exception 'A competência não atingiu 100,00%% de conformidade.'; end if;
  select id into v_exec from public.execucoes_analise where id_competencia=v.id and status='concluida' order by concluida_em desc nulls last,criado_em desc limit 1;
  v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,coalesce(v_exec::text,''),v_portao::text,coalesce(p_fundamento,'')),'sha256'),'hex');
  insert into public.aprovacoes(id_organizacao,id_contrato,id_competencia,tipo,status,aprovado_por,fundamento,hash_contexto,percentual_conformidade,id_execucao_analise)
  values(v.id_organizacao,v.id_contrato,v.id,'apresentacao','aprovada',auth.uid(),p_fundamento,v_hash,100.00,v_exec) returning id into v_aprov;
  update public.competencias set situacao='pode_apresentar_contratante',percentual_conformidade=100.00,liberada_para_apresentacao_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'CompetenciaLiberadaParaApresentacao','competencias',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','pode_apresentar_contratante','id_aprovacao',v_aprov));
  return jsonb_build_object('id_aprovacao',v_aprov,'situacao','pode_apresentar_contratante','percentual_conformidade',100.00);
end;$$;
revoke all on function public.aprovar_apresentacao(uuid,text) from public;
grant execute on function public.aprovar_apresentacao(uuid,text) to authenticated;

create or replace function public.registrar_apresentacao(p_id_competencia uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_pacote uuid; v_num integer; v_hash text; v_apres uuid; v_exist uuid;
begin
  if nullif(trim(p_idempotency_key),'') is null then raise exception 'idempotency_key obrigatório.'; end if;
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  select id into v_exist from public.apresentacoes_contratante where id_organizacao=v.id_organizacao and idempotency_key=p_idempotency_key;
  if v_exist is not null then return v_exist; end if;
  if v.situacao <> 'pode_apresentar_contratante' then raise exception 'Competência não liberada para apresentação.'; end if;
  if not exists(select 1 from public.aprovacoes a where a.id_competencia=v.id and a.tipo='apresentacao' and a.status='aprovada') then raise exception 'Aprovação humana ausente.'; end if;
  select coalesce(max(numero),0)+1 into v_num from public.pacotes_competencia where id_competencia=v.id and tipo='apresentacao';
  select encode(extensions.digest(string_agg(x.hash,'|' order by x.id::text),'sha256'),'hex') into v_hash
  from (
    select vd.id,vd.hash from public.versoes_documento vd join public.documentos_competencia dc on dc.id=vd.id_documento_competencia
    where dc.id_competencia=v.id and dc.situacao='ativo'
    union all
    select pi.id,pi.hash from public.pareceres_internos pi where pi.id_competencia=v.id and pi.status='aprovado'
  ) x;
  v_hash:=coalesce(v_hash,encode(extensions.digest(v.id::text,'sha256'),'hex'));
  insert into public.pacotes_competencia(id_organizacao,id_contrato,id_competencia,numero,tipo,status,hash_pacote,criado_por,congelado_em)
  values(v.id_organizacao,v.id_contrato,v.id,v_num,'apresentacao','congelado',v_hash,auth.uid(),now()) returning id into v_pacote;
  insert into public.itens_pacote_competencia(id_organizacao,id_contrato,id_competencia,id_pacote,entidade_tipo,entidade_id,versao_id,hash,ordem)
  select v.id_organizacao,v.id_contrato,v.id,v_pacote,'documento_competencia',dc.id,vd.id,vd.hash,row_number() over(order by dc.tipo,dc.id)
  from public.documentos_competencia dc join lateral (select * from public.versoes_documento x where x.id_documento_competencia=dc.id order by numero_versao desc limit 1) vd on true
  where dc.id_competencia=v.id and dc.situacao='ativo';
  insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,id_pacote,numero_rodada,tipo,protocolo,forma_apresentacao,id_comprovante_arquivo,idempotency_key,apresentado_por)
  values(v.id_organizacao,v.id_contrato,v.id,v_pacote,1,'apresentacao',p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo,p_idempotency_key,auth.uid()) returning id into v_apres;
  update public.pacotes_competencia set status='apresentado' where id=v_pacote;
  update public.competencias set situacao='aguardando_contratante',versao_pacote_atual=v_num where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'ApresentacaoRegistrada','apresentacoes_contratante',v_apres,null,jsonb_build_object('id_competencia',v.id,'id_pacote',v_pacote,'protocolo',p_protocolo));
  return v_apres;
end;$$;
revoke all on function public.registrar_apresentacao(uuid,text,text,text,uuid) from public;
grant execute on function public.registrar_apresentacao(uuid,text,text,text,uuid) to authenticated;

commit;