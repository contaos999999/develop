create or replace function public.obter_visao_geral_competencia(p_id_competencia uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$ select privado.obter_visao_geral_competencia($1) $$;
revoke all on function privado.obter_visao_geral_competencia(uuid) from public, anon, authenticated, service_role;
revoke all on function public.obter_visao_geral_competencia(uuid) from public, anon, authenticated, service_role;
grant execute on function public.obter_visao_geral_competencia(uuid) to authenticated;
