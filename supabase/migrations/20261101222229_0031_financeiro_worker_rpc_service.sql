begin;
create or replace function public.worker_validar_transacao_preventiva(p_id_transacao uuid)
returns jsonb language sql security definer set search_path=''
as $$ select privado.validar_transacao_preventivamente(p_id_transacao); $$;
revoke all on function public.worker_validar_transacao_preventiva(uuid) from public,anon,authenticated;
grant execute on function public.worker_validar_transacao_preventiva(uuid) to service_role;
commit;
