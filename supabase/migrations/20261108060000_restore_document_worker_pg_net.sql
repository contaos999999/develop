BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
REVOKE ALL PRIVILEGES ON SCHEMA net FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA net FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA net FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA net FROM PUBLIC, anon, authenticated;
-- REVOKE may only warn on managed objects. Never commit an ineffective fence.
DO $worker_acl_fence$
DECLARE
  client_role text;
BEGIN
  IF to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') IS NULL
     OR to_regclass('net.http_request_queue') IS NULL
     OR to_regclass('net._http_response') IS NULL
     OR to_regclass('net.http_request_queue_id_seq') IS NULL
     OR NOT has_schema_privilege('postgres','net','USAGE')
     OR NOT has_function_privilege('postgres','net.http_post(text,jsonb,jsonb,jsonb,integer)','EXECUTE') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'WORKER_RUNTIME_ACL_FENCE_REFUSED';
  END IF;
  FOREACH client_role IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF has_schema_privilege(client_role,'net','USAGE,CREATE')
       OR EXISTS (
         SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='net' AND CASE WHEN c.relkind IN ('r','p','v','m','f') THEN
           has_table_privilege(client_role,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
           OR has_any_column_privilege(client_role,c.oid,'SELECT,INSERT,UPDATE,REFERENCES') ELSE false END
       )
       OR EXISTS (
         SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='net' AND CASE WHEN c.relkind='S' THEN
           has_sequence_privilege(client_role,c.oid,'USAGE,SELECT,UPDATE') ELSE false END
       )
       OR EXISTS (
         SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='net' AND has_function_privilege(client_role,p.oid,'EXECUTE')
       ) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'WORKER_RUNTIME_ACL_FENCE_REFUSED';
    END IF;
  END LOOP;
END;
$worker_acl_fence$;
COMMIT;
