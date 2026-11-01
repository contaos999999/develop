begin;

-- Padrão oficial do ContaOS: português do Brasil + Horário de Brasília.
alter table public.organizacoes alter column timezone set default 'America/Sao_Paulo';
update public.organizacoes set timezone='America/Sao_Paulo' where timezone is null or timezone in ('America/Bahia','UTC','Etc/UTC');

create table if not exists public.configuracao_localizacao (
  id boolean primary key default true check(id=true),
  idioma text not null default 'pt-BR',
  timezone text not null default 'America/Sao_Paulo',
  formato_data text not null default 'DD/MM/YYYY',
  formato_hora text not null default 'HH24:MI:SS',
  formato_data_hora text not null default 'DD/MM/YYYY HH24:MI:SS',
  moeda text not null default 'BRL',
  separador_decimal text not null default ',',
  separador_milhar text not null default '.',
  atualizado_em timestamptz not null default now()
);
alter table public.configuracao_localizacao enable row level security;
drop policy if exists configuracao_localizacao_leitura on public.configuracao_localizacao;
create policy configuracao_localizacao_leitura on public.configuracao_localizacao for select to anon,authenticated using(true);
revoke all on public.configuracao_localizacao from anon,authenticated;
grant select on public.configuracao_localizacao to anon,authenticated;
insert into public.configuracao_localizacao(id,idioma,timezone,formato_data,formato_hora,formato_data_hora,moeda,separador_decimal,separador_milhar)
values(true,'pt-BR','America/Sao_Paulo','DD/MM/YYYY','HH24:MI:SS','DD/MM/YYYY HH24:MI:SS','BRL',',','.')
on conflict(id) do update set idioma=excluded.idioma,timezone=excluded.timezone,formato_data=excluded.formato_data,formato_hora=excluded.formato_hora,formato_data_hora=excluded.formato_data_hora,moeda=excluded.moeda,separador_decimal=excluded.separador_decimal,separador_milhar=excluded.separador_milhar,atualizado_em=now();

create or replace function public.formatar_data_br(p_data date)
returns text language sql immutable security invoker set search_path='' as $$
  select case when p_data is null then null else to_char(p_data,'DD/MM/YYYY') end
$$;

create or replace function public.formatar_data_hora_br(p_data_hora timestamptz)
returns text language sql stable security invoker set search_path='' as $$
  select case when p_data_hora is null then null else to_char(p_data_hora at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI:SS') end
$$;

create or replace function public.formatar_hora_br(p_data_hora timestamptz)
returns text language sql stable security invoker set search_path='' as $$
  select case when p_data_hora is null then null else to_char(p_data_hora at time zone 'America/Sao_Paulo','HH24:MI:SS') end
$$;

create or replace function public.agora_brasilia()
returns timestamptz language sql stable security invoker set search_path='' as $$
  select now()
$$;

revoke all on function public.formatar_data_br(date) from public;
revoke all on function public.formatar_data_hora_br(timestamptz) from public;
revoke all on function public.formatar_hora_br(timestamptz) from public;
revoke all on function public.agora_brasilia() from public;
grant execute on function public.formatar_data_br(date) to anon,authenticated;
grant execute on function public.formatar_data_hora_br(timestamptz) to anon,authenticated;
grant execute on function public.formatar_hora_br(timestamptz) to anon,authenticated;
grant execute on function public.agora_brasilia() to anon,authenticated;

-- Garante que a criação de organizações use Brasília por padrão.
create or replace function privado.criar_organizacao(
  p_razao_social text,
  p_nome_fantasia text default null,
  p_cnpj varchar default null,
  p_timezone text default 'America/Sao_Paulo'
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v_usuario uuid := auth.uid(); v_org uuid; v_timezone text := 'America/Sao_Paulo';
begin
  if v_usuario is null then raise exception 'Para continuar, faça login novamente.'; end if;
  insert into public.organizacoes(razao_social,nome_fantasia,cnpj,timezone)
  values(p_razao_social,p_nome_fantasia,p_cnpj,v_timezone) returning id into v_org;
  insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
  values(v_org,v_usuario,'administrador',true);
  insert into public.recursos_organizacao(id_organizacao,recurso,habilitado)
  values(v_org,'contaos_1',true);
  perform privado.registrar_evento_auditoria(v_org,'OrganizacaoCriada','organizacoes',v_org,null,jsonb_build_object('razao_social',p_razao_social,'timezone',v_timezone));
  return v_org;
end;
$$;

create or replace function public.criar_organizacao(
  p_razao_social text,
  p_nome_fantasia text default null,
  p_cnpj varchar default null,
  p_timezone text default 'America/Sao_Paulo'
)
returns uuid language sql security invoker set search_path='' as $$
  select privado.criar_organizacao($1,$2,$3,'America/Sao_Paulo')
$$;
revoke all on function public.criar_organizacao(text,text,varchar,text) from public,anon;
grant execute on function public.criar_organizacao(text,text,varchar,text) to authenticated;

comment on table public.configuracao_localizacao is 'Padrão global de localização do ContaOS: pt-BR, moeda BRL e Horário de Brasília (America/Sao_Paulo).';

commit;
