do $migration$
declare
  r record;
  v_constraint_name text;
  v_on_delete text;
begin
  for r in
    with tenant_tables as (
      select c.oid, c.relname as table_name
      from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relkind in ('r','p')
        and exists (
          select 1 from pg_catalog.pg_attribute a
          where a.attrelid = c.oid and a.attname = 'id_organizacao' and not a.attisdropped
        )
        and exists (
          select 1 from pg_catalog.pg_attribute a
          where a.attrelid = c.oid and a.attname = 'id_contrato' and not a.attisdropped
        )
    ), existing_composite as (
      select con.conrelid
      from pg_catalog.pg_constraint con
      join lateral unnest(con.conkey, con.confkey) with ordinality as x(local_attnum, foreign_attnum, ord) on true
      join pg_catalog.pg_attribute a on a.attrelid = con.conrelid and a.attnum = x.local_attnum
      join pg_catalog.pg_attribute af on af.attrelid = con.confrelid and af.attnum = x.foreign_attnum
      where con.contype = 'f'
        and con.confrelid = 'public.contratos'::regclass
      group by con.conrelid, con.oid
      having array_agg(a.attname order by x.ord) = array['id_contrato','id_organizacao']::name[]
         and array_agg(af.attname order by x.ord) = array['id','id_organizacao']::name[]
    ), contract_fk as (
      select con.conrelid, con.confdeltype
      from pg_catalog.pg_constraint con
      join pg_catalog.pg_attribute a
        on a.attrelid = con.conrelid and a.attnum = con.conkey[1]
      where con.contype = 'f'
        and con.confrelid = 'public.contratos'::regclass
        and cardinality(con.conkey) = 1
        and a.attname = 'id_contrato'
    )
    select t.oid, t.table_name, f.confdeltype
    from tenant_tables t
    join contract_fk f on f.conrelid = t.oid
    left join existing_composite e on e.conrelid = t.oid
    where e.conrelid is null
    order by t.table_name
  loop
    v_constraint_name := 'fk_tenant_contract_' || substr(md5(r.table_name), 1, 12);
    v_on_delete := case r.confdeltype
      when 'c' then 'CASCADE'
      when 'r' then 'RESTRICT'
      when 'n' then 'SET NULL'
      when 'd' then 'SET DEFAULT'
      else 'NO ACTION'
    end;

    execute format(
      'alter table public.%I add constraint %I foreign key (id_contrato, id_organizacao) references public.contratos(id, id_organizacao) on delete %s not valid',
      r.table_name,
      v_constraint_name,
      v_on_delete
    );

    execute format(
      'alter table public.%I validate constraint %I',
      r.table_name,
      v_constraint_name
    );
  end loop;
end
$migration$;

alter table public.execucoes_assincronas
  add constraint execucoes_assincronas_contrato_exige_org_chk
  check (id_contrato is null or id_organizacao is not null) not valid;
alter table public.execucoes_assincronas
  validate constraint execucoes_assincronas_contrato_exige_org_chk;

alter table public.jobs_dlq
  add constraint jobs_dlq_contrato_exige_org_chk
  check (id_contrato is null or id_organizacao is not null) not valid;
alter table public.jobs_dlq
  validate constraint jobs_dlq_contrato_exige_org_chk;
