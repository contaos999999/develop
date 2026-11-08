-- Read-only application catalog. No rows, settings, secrets or function bodies exported.
with relations as (
 select c.*,n.nspname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where (n.nspname in ('public','privado') and c.relkind in ('r','v','m','S'))
 or (n.nspname='storage' and c.relname in ('objects','buckets') and c.relkind='r')
), functions as (
 select p.*,n.nspname,l.lanname from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where n.nspname in ('public','privado') and p.prokind='f'
), privileges as (
 select 'relation' kind,r.oid,coalesce(jsonb_agg(jsonb_build_object('grantor',pg_get_userbyid(a.grantor),'grantee',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,'privilege',a.privilege_type,'grantable',a.is_grantable) order by a.grantor,a.grantee,a.privilege_type) filter(where a.grantor is not null),'[]'::jsonb) acl
 from relations r left join lateral aclexplode(coalesce(r.relacl,acldefault(case when r.relkind='S' then 's'::"char" else 'r'::"char" end,r.relowner))) a on true group by r.oid
 union all
 select 'function',f.oid,coalesce(jsonb_agg(jsonb_build_object('grantor',pg_get_userbyid(a.grantor),'grantee',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,'privilege',a.privilege_type,'grantable',a.is_grantable) order by a.grantor,a.grantee,a.privilege_type) filter(where a.grantor is not null),'[]'::jsonb)
 from functions f left join lateral aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) a on true group by f.oid
), function_records as (
 select jsonb_build_object('schema',f.nspname,'name',f.proname,'args',pg_get_function_identity_arguments(f.oid),'result',pg_get_function_result(f.oid),'language',f.lanname,'owner',pg_get_userbyid(f.proowner),'definer',f.prosecdef,'leakproof',f.proleakproof,'strict',f.proisstrict,'volatility',f.provolatile,'parallel',f.proparallel,'config',f.proconfig,'body_sha256',encode(sha256(convert_to(f.prosrc,'UTF8')),'hex'),'acl',a.acl) record
 from functions f join privileges a on a.kind='function' and a.oid=f.oid
), relation_records as (
 select jsonb_build_object('schema',r.nspname,'name',r.relname,'kind',r.relkind,'owner',pg_get_userbyid(r.relowner),'rls',r.relrowsecurity,'force',r.relforcerowsecurity,'options',r.reloptions,'view_md5',case when r.relkind in ('v','m') then md5(pg_get_viewdef(r.oid,false)) else null end,'acl',a.acl) record
 from relations r join privileges a on a.kind='relation' and a.oid=r.oid
)
select jsonb_build_object(
 'schemas',(select coalesce(jsonb_agg(jsonb_build_object('schema',n.nspname,'owner',pg_get_userbyid(n.nspowner),'acl',(select coalesce(jsonb_agg(jsonb_build_object('grantor',pg_get_userbyid(g.grantor),'grantee',case when g.grantee=0 then 'PUBLIC' else pg_get_userbyid(g.grantee) end,'privilege',g.privilege_type,'grantable',g.is_grantable) order by g.grantor,g.grantee,g.privilege_type),'[]'::jsonb) from aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) g)) order by n.nspname),'[]'::jsonb) from pg_namespace n where n.nspname in ('public','privado','storage')),
 'column_privileges',(select coalesce(jsonb_agg(jsonb_build_object('schema',r.nspname,'table',r.relname,'column',a.attname,'acl',(select coalesce(jsonb_agg(jsonb_build_object('grantor',pg_get_userbyid(g.grantor),'grantee',case when g.grantee=0 then 'PUBLIC' else pg_get_userbyid(g.grantee) end,'privilege',g.privilege_type,'grantable',g.is_grantable) order by g.grantor,g.grantee,g.privilege_type),'[]'::jsonb) from aclexplode(a.attacl) g)) order by r.nspname,r.relname,a.attnum),'[]'::jsonb) from relations r join pg_attribute a on a.attrelid=r.oid where a.attnum>0 and not a.attisdropped),
 'relations',(select coalesce(jsonb_agg(record order by record->>'schema',record->>'name'),'[]'::jsonb) from relation_records),
 'functions',(select coalesce(jsonb_agg(record order by record->>'schema',record->>'name',record->>'args'),'[]'::jsonb) from function_records),
 'columns',(select coalesce(jsonb_agg(jsonb_build_object('schema',r.nspname,'table',r.relname,'name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'notnull',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid)) order by r.nspname,r.relname,a.attnum),'[]'::jsonb) from relations r join pg_attribute a on a.attrelid=r.oid left join pg_attrdef d on d.adrelid=r.oid and d.adnum=a.attnum where r.nspname in ('public','privado') and r.relkind='r' and a.attnum>0 and not a.attisdropped),
 'policies',(select coalesce(jsonb_agg(to_jsonb(x) order by schemaname,tablename,policyname),'[]'::jsonb) from pg_policies x where schemaname in ('public','privado','storage')),
 'triggers',(select coalesce(jsonb_agg(jsonb_build_object('schema',r.nspname,'table',r.relname,'name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid,false)) order by r.nspname,r.relname,t.tgname),'[]'::jsonb) from relations r join pg_trigger t on t.tgrelid=r.oid where r.nspname in ('public','privado') and not t.tgisinternal),
 'constraints',(select coalesce(jsonb_agg(jsonb_build_object('schema',r.nspname,'table',r.relname,'name',c.conname,'type',c.contype,'validated',c.convalidated,'definition',pg_get_constraintdef(c.oid,false)) order by r.nspname,r.relname,c.conname),'[]'::jsonb) from relations r join pg_constraint c on c.conrelid=r.oid where r.nspname in ('public','privado')),
 'indexes',(select coalesce(jsonb_agg(jsonb_build_object('schema',r.nspname,'table',r.relname,'name',x.relname,'valid',i.indisvalid,'definition',pg_get_indexdef(i.indexrelid)) order by r.nspname,r.relname,x.relname),'[]'::jsonb) from relations r join pg_index i on i.indrelid=r.oid join pg_class x on x.oid=i.indexrelid where r.nspname in ('public','privado'))
) as application_catalog;
