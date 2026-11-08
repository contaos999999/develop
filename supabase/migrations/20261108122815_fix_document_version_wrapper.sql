-- One approved security attribute; preserve all authorization bodies and ACLs.
BEGIN;
DO $precondition$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid=to_regprocedure('public.adicionar_versao_documento_contrato(uuid,uuid,text,text)')
  AND md5(p.prosrc)='6d0c5926f4b25fd0e9562b0c010174ef' AND NOT p.prosecdef
  AND pg_get_userbyid(p.proowner)='postgres' AND p.proconfig=ARRAY['search_path=""']::text[]
  AND p.proacl::text='{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}') THEN
  RAISE EXCEPTION 'Version wrapper catalog changed; re-review before applying';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid=to_regprocedure('privado.adicionar_versao_documento_contrato_v110(uuid,uuid,text,text)')
  AND md5(p.prosrc)='10698cb96e7de1de5a88b25960b341e5' AND p.prosecdef
  AND pg_get_userbyid(p.proowner)='postgres' AND p.proconfig=ARRAY['search_path=""']::text[]
  AND p.proacl::text='{postgres=X/postgres}'
  AND NOT has_function_privilege('authenticated',p.oid,'EXECUTE') AND NOT has_function_privilege('anon',p.oid,'EXECUTE')) THEN
  RAISE EXCEPTION 'Private version authorization changed; re-review before applying';
 END IF;
END;
$precondition$;
ALTER FUNCTION public.adicionar_versao_documento_contrato(uuid,uuid,text,text) SECURITY DEFINER;
COMMIT;
