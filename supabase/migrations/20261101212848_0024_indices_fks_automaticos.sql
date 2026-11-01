begin;

do $$
declare
  r record;
  v_cols text;
  v_idx_name text;
begin
  for r in
    select c.oid as constraint_oid,
           n.nspname as schema_name,
           t.relname as table_name,
           c.conname,
           c.conkey
      from pg_constraint c
      join pg_class t on t.oid=c.conrelid
      join pg_namespace n on n.oid=t.relnamespace
     where c.contype='f'
       and n.nspname='public'
       and not exists (
         select 1
           from pg_index i
          where i.indrelid=c.conrelid
            and i.indisvalid
            and (i.indkey::smallint[])[0:cardinality(c.conkey)-1] = c.conkey
       )
  loop
    select string_agg(quote_ident(a.attname),', ' order by k.ord)
      into v_cols
      from unnest(r.conkey) with ordinality as k(attnum,ord)
      join pg_attribute a on a.attrelid=(quote_ident(r.schema_name)||'.'||quote_ident(r.table_name))::regclass and a.attnum=k.attnum;

    v_idx_name := left('fk_'||r.table_name||'_'||substr(md5(r.conname),1,10)||'_idx',63);
    execute format('create index if not exists %I on %I.%I (%s)',v_idx_name,r.schema_name,r.table_name,v_cols);
  end loop;
end $$;

commit;
