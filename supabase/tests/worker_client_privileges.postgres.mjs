// Explicit PostgreSQL catalog regressions with synthetic roles/objects, no HML.
// Temporary test dependency: @electric-sql/pglite@0.3.14; no product dependency.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const {PGlite}=await import(process.env.CONTAOS_PGLITE_MODULE);
const source=spawnSync('python3',['-c',"import importlib.util; s=importlib.util.spec_from_file_location('b','supabase/tests/worker_api_boundary_hml.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.client_attack_surface_sql())"],{encoding:'utf8'});
assert.equal(source.status,0,source.stderr);
const sql=source.stdout;
const cases=[
 ['closed',null,true],
 ['client_login','ALTER ROLE anon LOGIN',false],
 ['client_superuser','ALTER ROLE authenticated SUPERUSER',false],
 ['client_create_role','ALTER ROLE anon CREATEROLE',false],
 ['client_bypass_rls','ALTER ROLE authenticated BYPASSRLS',false],
 ['inherited_elevation','GRANT service_role TO authenticated',false],
 ['vault_usage','GRANT USAGE ON SCHEMA vault TO anon',false],
 ['public_create','GRANT CREATE ON SCHEMA public TO authenticated',false],
 ['missing_endpoint','DROP FUNCTION public.worker_obter_webhook(uuid)',false],
 ['opened_endpoint','GRANT EXECUTE ON FUNCTION public.validar_token_interno(text) TO anon',false],
 ['unexpected_overload',"CREATE FUNCTION public.validar_token_interno(integer) RETURNS int LANGUAGE sql AS 'SELECT 1'",false],
 ['view_table_grant','CREATE VIEW public.leak AS SELECT name FROM vault.decrypted_secrets; GRANT SELECT ON public.leak TO authenticated',false],
 ['view_column_grant','CREATE VIEW public.leak AS SELECT name FROM vault.decrypted_secrets; GRANT SELECT(name) ON public.leak TO anon',false],
 ['function_bridge',"CREATE FUNCTION public.leak() RETURNS SETOF text LANGUAGE sql SECURITY DEFINER AS 'SELECT name FROM vault.decrypted_secrets'",false],
 ['sql_standard_bridge',"INSERT INTO vault.decrypted_secrets VALUES ('SYNTHETIC_CANARY'); CREATE FUNCTION public.sql_standard_bridge() RETURNS text LANGUAGE SQL SECURITY DEFINER RETURN (SELECT name FROM vault.decrypted_secrets LIMIT 1)",false],
 ['safe_view','CREATE VIEW public.safe AS SELECT 1 AS value; GRANT SELECT ON public.safe TO authenticated',true]
];
for(const [name,mutation,expected] of cases){
 const db=new PGlite();
 try{
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
   CREATE SCHEMA vault; CREATE TABLE vault.decrypted_secrets(name text); CREATE SCHEMA privado;
   REVOKE CREATE ON SCHEMA public FROM PUBLIC;
   CREATE FUNCTION privado.invocar_contaos_worker(text,integer) RETURNS int LANGUAGE sql AS 'SELECT 1';
   CREATE FUNCTION privado.invocar_edge_oficial(text,integer) RETURNS int LANGUAGE sql AS 'SELECT 1';
   CREATE FUNCTION public.validar_token_interno(text) RETURNS int LANGUAGE sql AS 'SELECT 1';
   CREATE FUNCTION public.worker_pull_job(text,integer) RETURNS int LANGUAGE sql AS 'SELECT 1';
   CREATE FUNCTION public.worker_finalizar_job(text,bigint,boolean,text,text,integer) RETURNS int LANGUAGE sql AS 'SELECT 1';
   CREATE FUNCTION public.worker_enfileirar_job(text,uuid,uuid,text,uuid,jsonb,text) RETURNS int LANGUAGE sql AS 'SELECT 1';
   CREATE FUNCTION public.worker_obter_webhook(uuid) RETURNS int LANGUAGE sql AS 'SELECT 1';
   REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC,anon,authenticated;
   REVOKE ALL ON ALL FUNCTIONS IN SCHEMA privado FROM PUBLIC,anon,authenticated;`);
  if(mutation)await db.exec(mutation);
  const result=(await db.query(sql)).rows[0].client_attack_surface;
  assert.equal(result,expected,name);
  console.log('LOCAL_CLIENT_PRIVILEGES_CASE_PASS '+name);
 }finally{await db.close();}
}
console.log('LOCAL_CLIENT_PRIVILEGES_CASES=16; HOSTED_API=NOT_CERTIFIED; HML=NOT_CHANGED');
