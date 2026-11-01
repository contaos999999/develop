begin;

create schema if not exists privado;

create extension if not exists vector with schema extensions;
create extension if not exists pgmq;
create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists pgtap with schema extensions;

create or replace function privado.tocar_atualizado_em()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em = now();
  if to_jsonb(new) ? 'versao_registro' then
    new.versao_registro = coalesce(new.versao_registro, 0) + 1;
  end if;
  return new;
end;
$$;

create or replace function privado.usuario_atual()
returns uuid
language sql
stable
set search_path = ''
as $$ select auth.uid() $$;

revoke all on schema privado from public, anon, authenticated;
grant usage on schema privado to authenticated, service_role;

commit;
