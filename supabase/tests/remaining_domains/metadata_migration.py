"""Apply only the reviewed additive wrapper migration through the official CLI.
Called after exact HEAD/guard/Restore/backup checks and before Auth fixtures.
No arbitrary migration, catalog drift or missing history is accepted.
"""
import hashlib,json,os
from pathlib import Path
import subprocess,urllib.parse
VERSION='20261108184219'
FILE='supabase/migrations/'+VERSION+'_fix_reviewed_metadata_append_version.sql'
CATALOG="select json_build_object('functions',(select json_agg(x order by x.schema,x.name) from (select n.nspname schema,p.proname name,pg_get_function_identity_arguments(p.oid) args,md5(p.prosrc) body_md5,p.prosecdef definer,p.proconfig config,pg_get_userbyid(p.proowner) owner,p.proacl::text acl,has_function_privilege('authenticated',p.oid,'execute') auth_exec,has_function_privilege('anon',p.oid,'execute') anon_exec from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='privado' and p.proname in ('revisar_sugestao_extracao','bloquear_mutacao_historico')) or(n.nspname='public' and p.proname='revisar_sugestao_extracao')) x),'historical_trigger',(select json_build_object('name',t.tgname,'enabled',t.tgenabled,'function',t.tgfoid::regprocedure::text,'definition',pg_get_triggerdef(t.oid,false)) from pg_trigger t where t.tgrelid='public.versoes_documento'::regclass and t.tgname='versoes_documento_immutable' and not t.tgisinternal));"
REVIEWED_SQL_SHA256='7d5ea8651d9df4324f78ac029df3155cb71d6178c34866fb495965bfaff40323'
def expected_catalog(after):
    common={'config':['search_path=""'],'owner':'postgres','anon_exec':False,'auth_exec':True}
    args='p_id_sugestao uuid, p_aprovar boolean, p_conteudo_revisado text, p_categoria_revisada text, p_id_requisito_revisado uuid'
    functions=[{**common,'schema':'privado','name':'bloquear_mutacao_historico','args':'','body_md5':'2025ca71f9414e6c68aaf8eb0cb1388c','definer':False,'acl':'{postgres=X/postgres,authenticated=X/postgres}'},{**common,'schema':'privado','name':'revisar_sugestao_extracao','args':args,'body_md5':('ac887b23c3f0db3cbecbc2025810bbb2' if after else '6c790a96348eeece99cd40ca2d9dedfb'),'definer':True,'acl':'{postgres=X/postgres,authenticated=X/postgres}'},{**common,'schema':'public','name':'revisar_sugestao_extracao','args':args,'body_md5':'e4a845c2fdf0e4bc72ccefa5fe918396','definer':False,'acl':'{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'}]
    return {'functions':functions,'historical_trigger':{'name':'versoes_documento_immutable','enabled':'O','function':'privado.bloquear_mutacao_historico()','definition':'CREATE TRIGGER versoes_documento_immutable BEFORE DELETE OR UPDATE ON public.versoes_documento FOR EACH ROW EXECUTE FUNCTION privado.bloquear_mutacao_historico()'}}

def migration_plan(local,remote,catalog):
    assert len(local)==len(set(local)) and local==sorted(local) and local.count(VERSION)==1
    if remote==local:
        assert catalog==expected_catalog(True),'Applied migration catalog changed'
        return 'ALREADY_APPLIED'
    assert remote==[v for v in local if v!=VERSION],'Only the single approved migration may be missing'
    assert catalog==expected_catalog(False),'Pre-migration catalog changed concurrently'
    return 'APPLY_ONE'
def ensure_migration(env):
    root=Path(env['CONTAOS_TEST_PRIVATE_DIR']);base=Path(env['RUNNER_TEMP']).resolve()
    assert root.resolve().is_relative_to(base) and root.resolve()!=base
    root.mkdir(mode=0o700,parents=True,exist_ok=True);os.chmod(root,0o700)
    receipt={'schema':'contaos.single-reviewed-migration.v1','backend_head':env['TESTED_HEAD'],'version':VERSION,'loaded_module_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'state':'FAIL_CLOSED','global_complete':False}
    def save():
        p=root/'migration-receipt.json';p.write_text(json.dumps(receipt,indent=2)+'\n');os.chmod(p,0o600)
    save()
    try:
        task=json.loads(Path('docs/tasks/active-task.json').read_text());proof=task['remaining_certification']['approved_hml_migration']
        assert env['DOMAIN']=='documento_detalhe' and task['remaining_certification']['domains_to_run']==['documento_detalhe']
        assert proof['file']==FILE and proof['version']==VERSION and proof['scope']=='REVIEWED_METADATA_APPEND_ONLY_NO_HISTORICAL_MUTATION'
        raw=Path(FILE).read_bytes();sha=hashlib.sha256(raw).hexdigest();assert sha==proof['sha256']
        assert sha==REVIEWED_SQL_SHA256,'Reviewed metadata SQL changed'
        assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==env['TESTED_HEAD']
        db=env['DATABASE_URL'];u=urllib.parse.urlsplit(db);assert u.username=='postgres.gklhhhyosgasnyoxlrui' and u.hostname.endswith('.pooler.supabase.com')
        def query(sql):
            r=subprocess.run(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',sql],capture_output=True,text=True,timeout=45)
            assert r.returncode==0,'Own HML migration metadata query failed'
            return r.stdout.strip()
        local=sorted(p.name.split('_',1)[0] for p in Path('supabase/migrations').glob('*.sql'))
        remote=query('select version from supabase_migrations.schema_migrations order by version').splitlines();catalog=json.loads(query(CATALOG));plan=migration_plan(local,remote,catalog)
        receipt.update(source_sha256=sha,plan=plan,prior_catalog_sha256=hashlib.sha256(json.dumps(catalog,sort_keys=True).encode()).hexdigest());save()
        live=json.loads(subprocess.check_output(['gh','api','repos/contaos999999/develop/commits/main'],text=True));assert live['sha']==env['TESTED_HEAD'],'Live HEAD changed before migration'
        if plan=='APPLY_ONE':
            # Preflight proved every other migration applied; CLI preserves filename version.
            cli_env={k:env[k] for k in ('PATH','HOME','TMPDIR','LANG') if k in env};cli_env.update(CI='true',SUPABASE_TELEMETRY_DISABLED='true')
            result=subprocess.run(['supabase','migration','up','--db-url',db,'--yes'],capture_output=True,text=True,timeout=180,env=cli_env)
            assert result.returncode==0,'Official single approved HML migration failed'
        after_versions=query('select version from supabase_migrations.schema_migrations order by version').splitlines();after=json.loads(query(CATALOG))
        assert migration_plan(local,after_versions,after)=='ALREADY_APPLIED'
        receipt.update(state='APPLIED_AND_EXACT_PARITY' if plan=='APPLY_ONE' else 'ALREADY_APPLIED_AND_EXACT_PARITY',after_catalog_sha256=hashlib.sha256(json.dumps(after,sort_keys=True).encode()).hexdigest(),migration_count=len(local));save()
        print('SINGLE_REVIEWED_MIGRATION_EXACT_PARITY')
    except Exception:
        save();raise RuntimeError('Single reviewed HML migration failed closed; sanitized receipt recorded') from None
