-- V1-23: verificações estruturais de contrato/grants, sem dados persistidos.
do $test$
declare
  v_oid oid;
  v_policy text;
begin
  select to_regprocedure('public.pode_consultar_auditoria_organizacao(uuid)') into v_oid;
  if v_oid is null then raise exception 'V123: RPC ausente'; end if;
  if (select prosecdef from pg_proc where oid=v_oid) then
    raise exception 'V123: RPC nao pode ser SECURITY DEFINER';
  end if;
  if has_function_privilege('anon',v_oid,'EXECUTE') then
    raise exception 'V123: anon nao pode executar RPC';
  end if;
  if not has_function_privilege('authenticated',v_oid,'EXECUTE') then
    raise exception 'V123: authenticated deve executar RPC';
  end if;
  if (select proconfig is null or not ('search_path=' = any(proconfig)) from pg_proc where oid=v_oid) then
    raise exception 'V123: search_path nao protegido';
  end if;
  if public.pode_consultar_auditoria_organizacao(null::uuid) is distinct from false then
    raise exception 'V123: org nula deve negar';
  end if;
  if public.pode_consultar_auditoria_organizacao('00000000-0000-0000-0000-000000000001'::uuid) is distinct from false then
    raise exception 'V123: sessao sem JWT deve negar';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.eventos_auditoria'::regclass) then
    raise exception 'V123: RLS de eventos_auditoria desabilitada';
  end if;
  select pg_get_expr(polqual,polrelid) into v_policy
  from pg_policy
  where polrelid='public.eventos_auditoria'::regclass and polname='eventos_select';
  if v_policy is null or position('usuario_possui_perfil' in v_policy)=0 then
    raise exception 'V123: policy de auditoria divergente';
  end if;
end
$test$;
-- Testes autenticados A/B com JWT real (master, admin, auditor, juridico,
-- perfil comum, vinculo inativo, organizacao cruzada) sao gate separado e
-- nao podem ser declarados PASS apenas com este smoke estrutural.
