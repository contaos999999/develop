do $$
declare
  r record;
  v_index_name text;
begin
  for r in
    select
      n.nspname as schema_name,
      c.relname as table_name,
      con.conname as constraint_name,
      con.conkey as fk_cols
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    where con.contype = 'f'
      and n.nspname = 'public'
      and not exists (
        select 1
        from pg_index i
        where i.indrelid = con.conrelid
          and i.indisvalid
          and (i.indkey::smallint[])[0:cardinality(con.conkey)-1] = con.conkey
      )
  loop
    v_index_name := left('fk_' || r.table_name || '_' || substr(md5(r.constraint_name),1,10) || '_idx', 63);
    execute format(
      'create index if not exists %I on %I.%I (%s)',
      v_index_name,
      r.schema_name,
      r.table_name,
      (
        select string_agg(quote_ident(a.attname), ', ' order by u.ord)
        from unnest(r.fk_cols) with ordinality u(attnum, ord)
        join pg_attribute a
          on a.attrelid = format('%I.%I',r.schema_name,r.table_name)::regclass
         and a.attnum = u.attnum
      )
    );
  end loop;
end $$;
