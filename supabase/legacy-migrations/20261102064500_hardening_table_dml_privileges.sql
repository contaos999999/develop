begin;

-- Novas tabelas públicas deixam de conceder escrita automaticamente a clientes.
-- SELECT continua sob controle de GRANT + RLS; qualquer escrita futura deverá
-- ser concedida explicitamente pela migration que criar a policy correspondente.
alter default privileges for role postgres in schema public
  revoke insert, update, delete, truncate, references, trigger on tables from anon;

alter default privileges for role postgres in schema public
  revoke insert, update, delete, truncate, references, trigger on tables from authenticated;

-- Clientes nunca precisam truncar tabelas, criar FKs ou instalar triggers.
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;

-- Para authenticated, mantenha DML somente quando existe policy de RLS para
-- a mesma operação. Isso reduz o blast radius de uma policy futura incorreta.
do $block$
declare
  r record;
  v_tem_policy boolean;
begin
  for r in
    select c.oid, c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
    order by c.relname
  loop
    if has_table_privilege('authenticated', r.oid, 'INSERT') then
      select exists (
        select 1 from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = r.relname
          and p.cmd in ('INSERT','ALL')
          and ('authenticated' = any(p.roles) or 'public' = any(p.roles))
      ) into v_tem_policy;
      if not v_tem_policy then
        execute format('revoke insert on table public.%I from authenticated', r.relname);
      end if;
    end if;

    if has_table_privilege('authenticated', r.oid, 'UPDATE') then
      select exists (
        select 1 from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = r.relname
          and p.cmd in ('UPDATE','ALL')
          and ('authenticated' = any(p.roles) or 'public' = any(p.roles))
      ) into v_tem_policy;
      if not v_tem_policy then
        execute format('revoke update on table public.%I from authenticated', r.relname);
      end if;
    end if;

    if has_table_privilege('authenticated', r.oid, 'DELETE') then
      select exists (
        select 1 from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = r.relname
          and p.cmd in ('DELETE','ALL')
          and ('authenticated' = any(p.roles) or 'public' = any(p.roles))
      ) into v_tem_policy;
      if not v_tem_policy then
        execute format('revoke delete on table public.%I from authenticated', r.relname);
      end if;
    end if;
  end loop;
end;
$block$;

commit;
