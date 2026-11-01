begin;

create or replace function public.worker_exportar_historico_migrations()
returns text
language sql
security definer
set search_path=''
as $$
  select string_agg(
    '-- MIGRATION ' || version || '_' || name || E'\n' || array_to_string(statements,E'\n\n'),
    E'\n\n-- ============================================================\n\n'
    order by version
  )
  from supabase_migrations.schema_migrations;
$$;

revoke all on function public.worker_exportar_historico_migrations() from public,anon,authenticated;
grant execute on function public.worker_exportar_historico_migrations() to service_role;

commit;
