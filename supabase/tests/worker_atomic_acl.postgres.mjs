// Explicit local PostgreSQL regression. This does not install or certify pg_net.
// Temporary dependency only: @electric-sql/pglite@0.3.14, see runtime checkpoint.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const {PGlite}=await import(process.env.CONTAOS_PGLITE_MODULE);
const sql=readFileSync('supabase/migrations/20261108060000_restore_document_worker_pg_net.sql','utf8');
const fence=sql.match(/DO \$worker_acl_fence\$[\s\S]*?\$worker_acl_fence\$;/)?.[0];
assert(fence,'migration must assert effective privileges before commit');
const cases=[
 ['closed',null],
 ['public_schema','GRANT USAGE ON SCHEMA net TO PUBLIC'],
 ['authenticated_schema','GRANT CREATE ON SCHEMA net TO authenticated'],
 ['table','GRANT SELECT ON net.http_request_queue TO anon'],
 ['column','GRANT SELECT(headers) ON net.http_request_queue TO authenticated'],
 ['response','GRANT UPDATE ON net._http_response TO authenticated'],
 ['sequence','GRANT USAGE ON SEQUENCE net.http_request_queue_id_seq TO anon'],
 ['function','GRANT EXECUTE ON FUNCTION net.http_post(text,jsonb,jsonb,jsonb,integer) TO authenticated'],
 ['inherited','CREATE ROLE client_group; GRANT client_group TO anon; GRANT SELECT ON net.http_request_queue TO client_group'],
 ['new_table','CREATE TABLE net.extra(headers text); GRANT SELECT ON net.extra TO PUBLIC'],
 ['new_function',"CREATE FUNCTION net.extra() RETURNS int LANGUAGE SQL AS 'SELECT 1'"],
 ['missing_object','DROP TABLE net._http_response'],
 ['missing_signature','DROP FUNCTION net.http_post(text,jsonb,jsonb,jsonb,integer)']
];
for(const [name,exposure] of cases){
 const db=new PGlite();
 try{
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA net;
   CREATE SEQUENCE net.http_request_queue_id_seq;
   CREATE TABLE net.http_request_queue(id bigint,headers jsonb);
   CREATE TABLE net._http_response(id bigint);
   CREATE FUNCTION net.http_post(text,jsonb,jsonb,jsonb,integer) RETURNS bigint LANGUAGE SQL AS 'SELECT 1::bigint';
   REVOKE ALL ON SCHEMA net FROM PUBLIC,anon,authenticated;
   REVOKE ALL ON ALL TABLES IN SCHEMA net FROM PUBLIC,anon,authenticated;
   REVOKE ALL ON ALL SEQUENCES IN SCHEMA net FROM PUBLIC,anon,authenticated;
   REVOKE ALL ON ALL FUNCTIONS IN SCHEMA net FROM PUBLIC,anon,authenticated;`);
  if(exposure)await db.exec(exposure);
  await db.exec('BEGIN; CREATE TABLE public.atomic_install_sentinel(id integer);');
  if(exposure){
   await assert.rejects(()=>db.exec(fence),error=>error.code==='42501'&&error.message==='WORKER_RUNTIME_ACL_FENCE_REFUSED');
   await assert.rejects(()=>db.query('SELECT 1'),error=>error.code==='25P02');
   // PostgreSQL converts COMMIT of an aborted transaction to ROLLBACK.
   await db.exec('COMMIT');
   assert.equal((await db.query("SELECT to_regclass('public.atomic_install_sentinel') IS NULL AS rolled_back")).rows[0].rolled_back,true);
  }else{
   await db.exec(fence+' COMMIT;');
   assert.equal((await db.query("SELECT to_regclass('public.atomic_install_sentinel') IS NOT NULL AS committed")).rows[0].committed,true);
  }
  console.log('LOCAL_POSTGRES_ACL_CASE_PASS '+name);
 }finally{await db.close();}
}
console.log('LOCAL_POSTGRES_ACL_CASES=13; MANAGED_PG_NET=NOT_VERIFIED; HML=NOT_CHANGED');
