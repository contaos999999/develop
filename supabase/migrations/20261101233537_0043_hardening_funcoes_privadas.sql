begin;

revoke usage on schema privado from public, anon;
revoke execute on all functions in schema privado from public, anon;
alter default privileges in schema privado revoke execute on functions from public;

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as assinatura
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='privado'
      and exists(
        select 1
        from pg_proc q
        join pg_namespace nq on nq.oid=q.pronamespace
        where nq.nspname='public'
          and q.proname=p.proname
          and q.proargtypes=p.proargtypes
      )
  loop
    execute format('grant execute on function %s to authenticated', r.assinatura);
  end loop;
end $$;

commit;
