-- V1-23: capacidade de consulta da Auditoria; somente leitura e escopo HML.
-- A RLS de public.eventos_auditoria permanece autoridade para acesso aos registros.
create function public.pode_consultar_auditoria_organizacao(p_id_organizacao uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  select case
    when p_id_organizacao is null then false
    else coalesce(
      privado.usuario_possui_perfil(
        p_id_organizacao,
        array['administrador','auditor','juridico_conformidade']::text[]
      ), false
    )
  end;
$function$;

revoke all on function public.pode_consultar_auditoria_organizacao(uuid) from public;
revoke all on function public.pode_consultar_auditoria_organizacao(uuid) from anon;
grant execute on function public.pode_consultar_auditoria_organizacao(uuid) to authenticated;
