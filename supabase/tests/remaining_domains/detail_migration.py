"""Apply only the reviewed additive wrapper migration through the official CLI.
Called after exact HEAD/guard/Restore/backup checks and before Auth fixtures.
No arbitrary migration, catalog drift or missing history is accepted.
"""
import hashlib,json,os
from pathlib import Path
import subprocess,urllib.parse
VERSION='20261108183000'
FILE='supabase/migrations/'+VERSION+'_fix_document_vigency_wrapper.sql'
CATALOG="select coalesce(json_agg(x order by x.schema),'[]'::json) from (select n.nspname schema,p.proname name,pg_get_function_identity_arguments(p.oid) args,md5(p.prosrc) body_md5,p.prosecdef definer,p.proconfig config,pg_get_userbyid(p.proowner) owner,p.proacl::text acl,has_function_privilege('authenticated',p.oid,'execute') auth_exec,has_function_privilege('anon',p.oid,'execute') anon_exec from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='public' and p.proname='definir_vigencia_sugestao_extracao') or (n.nspname='privado' and p.proname='definir_vigencia_sugestao_extracao_v111')) x;"
def expected_catalog(after):
    common={'args':'p_id_sugestao uuid, p_vigencia_inicio date, p_vigencia_fim date','config':['search_path=""'],'owner':'postgres','anon_exec':False}
    return [{**common,'schema':'privado','name':'definir_vigencia_sugestao_extracao_v111','body_md5':'faad80003b4dbcf2faad66384a1a261b','definer':True,'acl':'{postgres=X/postgres}','auth_exec':False},{**common,'schema':'public','name':'definir_vigencia_sugestao_extracao','body_md5':'375c62747503ea82c02f8027ccdc7345','definer':after,'acl':'{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}','auth_exec':True}]
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
    receipt={'schema':'contaos.single-reviewed-migration.v1','backend_head':env['TESTED_HEAD'],'version':VERSION,'state':'FAIL_CLOSED','global_complete':False}
    def save():
        p=root/'migration-receipt.json';p.write_text(json.dumps(receipt,indent=2)+'\n');os.chmod(p,0o600)
    save()
    try:
        task=json.loads(Path('docs/tasks/active-task.json').read_text());proof=task['remaining_certification']['approved_hml_migration']
        assert env['DOMAIN']=='documento_detalhe' and task['remaining_certification']['domains_to_run']==['documento_detalhe']
        assert proof['file']==FILE and proof['version']==VERSION and proof['scope']=='ONE_PUBLIC_WRAPPER_SECURITY_ATTRIBUTE_ONLY'
        raw=Path(FILE).read_bytes();sha=hashlib.sha256(raw).hexdigest();assert sha==proof['sha256']
        assert '\n'.join(l for l in raw.decode().splitlines() if not l.startswith('--')).strip()=='ALTER FUNCTION public.definir_vigencia_sugestao_extracao(uuid,date,date) SECURITY DEFINER;'
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
