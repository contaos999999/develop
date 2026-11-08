"""Compare real HML against the independent isolated Restore on the same HEAD.
Read-only SQL; full source hashes/ACL/RLS metadata, never rows or function bodies.
"""
import hashlib,io,json,os,re,subprocess,urllib.parse,zipfile
from pathlib import Path
SECTIONS=('schemas','column_privileges','relations','functions','columns','policies','triggers','constraints','indexes')
HOSTED_HELPER=json.loads('{"acl":[{"grantee":"postgres","grantor":"postgres","grantable":false,"privilege":"EXECUTE"},{"grantee":"service_role","grantor":"postgres","grantable":false,"privilege":"EXECUTE"}],"args":"","name":"rls_auto_enable","owner":"postgres","config":["search_path=pg_catalog"],"result":"event_trigger","schema":"public","strict":false,"definer":true,"body_sha256":"325ae266d9b166715ef5230ceaf7ff9d523e483cf5610dfb9779ab3f183f4af9","language":"plpgsql","parallel":"u","leakproof":false,"volatility":"v"}')
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False)
def normalize(catalog):
    assert set(catalog)==set(SECTIONS)
    result={}
    for section in SECTIONS:
        records=catalog[section];assert isinstance(records,list) and records and all(isinstance(x,dict) for x in records)
        values=[]
        for source in records:
            # Match the hosted exception against RAW metadata before any
            # semantic owner normalization; altered helpers still fail closed.
            if section=='functions' and {**source,'acl':sorted(source.get('acl',[]),key=canonical)}=={**HOSTED_HELPER,'acl':sorted(HOSTED_HELPER['acl'],key=canonical)}:
                continue
            record={**source}
            if 'acl' in record:
                assert isinstance(record['acl'],list)
                assert all(isinstance(g,dict) and set(g)=={'grantor','grantee','privilege','grantable'} and type(g['grantable']) is bool and all(isinstance(g[k],str) and g[k] for k in ('grantor','grantee','privilege')) for g in record['acl']),'Malformed ACL metadata'
                # PostgreSQL object owners implicitly hold every grant option,
                # regardless of the redundant raw ACL bit. Do not synthesize a
                # missing ordinary privilege, owner, grantee or grantor.
                record['acl']=sorted([{**grant,'grantable':True} if grant.get('grantee')==record.get('owner') and record.get('owner') is not None else dict(grant) for grant in record['acl']],key=canonical)
            if section=='policies' and 'roles' in record:record['roles']=sorted(record['roles'])
            values.append(record)
        serialized=[canonical(x) for x in values];assert len(serialized)==len(set(serialized)),'Duplicate catalog record'
        if section=='functions':
            known={**HOSTED_HELPER,'acl':sorted(HOSTED_HELPER['acl'],key=canonical)}
            # Exact hosted DDL-only helper: no anonymous/authenticated ACL, pinned body.
            values=[x for x in values if x!=known]
        result[section]=sorted(values,key=canonical)
    return result

def compare_catalogs(expected,actual):
    left,right=normalize(expected),normalize(actual);differences={}
    for section in SECTIONS:
        a={canonical(x) for x in left[section]};b={canonical(x) for x in right[section]}
        if a!=b:differences[section]={'missing_count':len(a-b),'unexpected_count':len(b-a),'missing_sha256':sorted(hashlib.sha256(v.encode()).hexdigest() for v in a-b),'unexpected_sha256':sorted(hashlib.sha256(v.encode()).hexdigest() for v in b-a)}
    return {'state':'FAIL_APPLICATION_CATALOG_DRIFT' if differences else 'PASS_EXACT_APPLICATION_CATALOG','raw_expected_sha256':hashlib.sha256(canonical(expected).encode()).hexdigest(),'raw_actual_sha256':hashlib.sha256(canonical(actual).encode()).hexdigest(),'equivalence_rules':['POSTGRES_OWNER_IMPLICIT_GRANT_OPTION','EXACT_HOSTED_DDL_HELPER'],'expected_sha256':hashlib.sha256(canonical(left).encode()).hexdigest(),'actual_sha256':hashlib.sha256(canonical(right).encode()).hexdigest(),'counts':{s:len(right[s]) for s in SECTIONS},'differences':differences}

def prove(env):
    sha=env['TESTED_HEAD'];assert re.fullmatch('[0-9a-f]{40}',sha)
    run=env['RESTORE_RUN_ID'];assert re.fullmatch('[1-9][0-9]{1,20}',run)
    root=Path(env['CONTAOS_TEST_PRIVATE_DIR']);base=Path(env['RUNNER_TEMP']).resolve();assert root.resolve().is_relative_to(base) and root.resolve()!=base
    root.mkdir(mode=0o700,parents=True,exist_ok=True);os.chmod(root,0o700)
    receipt={'schema':'contaos.full-catalog-parity.v1','backend_head':sha,'restore_run':int(run),'state':'FAIL_CLOSED','global_complete':False}
    def save():
        p=root/'catalog-parity-receipt.json';p.write_text(json.dumps(receipt,indent=2)+'\n');os.chmod(p,0o600)
    save()
    try:
        gh_env={k:env[k] for k in ('PATH','HOME','GH_TOKEN') if k in env}
        def api(path,binary=False):
            p=subprocess.run(['gh','api','repos/contaos999999/develop/'+path],env=gh_env,capture_output=True,timeout=60)
            assert p.returncode==0 and len(p.stdout)<=10_000_000,'Bounded own CI artifact read failed'
            return p.stdout if binary else json.loads(p.stdout)
        source=api('actions/runs/'+run)
        assert source['head_sha']==sha and source['head_branch']=='main' and source['event']=='push' and source['status']=='completed' and source['conclusion']=='success' and source['name']=='ContaOS Restore Isolado'
        artifacts=api('actions/runs/'+run+'/artifacts?per_page=100')['artifacts']
        matches=[a for a in artifacts if a['name']=='contaos-hml-restore-proof' and not a['expired']];assert len(matches)==1
        artifact=matches[0];assert artifact['workflow_run']['head_sha']==sha and type(artifact['id']) is int and artifact['id']>0
        digest=artifact['digest'];assert re.fullmatch('sha256:[0-9a-f]{64}',digest)
        raw=api('actions/artifacts/'+str(artifact['id'])+'/zip',binary=True);assert hashlib.sha256(raw).hexdigest()==digest.split(':')[1]
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            assert archive.namelist().count('catalog-parity.json')==1 and archive.namelist().count('catalog-parity-head.txt')==1
            assert archive.getinfo('catalog-parity.json').file_size<=3_000_000 and archive.getinfo('catalog-parity-head.txt').file_size<=100
            assert archive.read('catalog-parity-head.txt').decode().strip()==sha
            expected=json.loads(archive.read('catalog-parity.json'))
        db=env['DATABASE_URL'];u=urllib.parse.urlsplit(db);assert u.username=='postgres.gklhhhyosgasnyoxlrui' and u.hostname.endswith('.pooler.supabase.com')
        assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==sha and api('commits/main')['sha']==sha
        query=Path('supabase/tests/remaining_domains/catalog_parity.sql').read_text()
        p=subprocess.run(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1'],input='begin read only;\n'+query+'\ncommit;',capture_output=True,text=True,timeout=60)
        assert p.returncode==0 and len(p.stdout)<=3_000_000,'Read-only HML catalog query failed'
        actual=json.loads(p.stdout.strip());result=compare_catalogs(expected,actual)
        receipt.update(result,restore_artifact=artifact['id'],restore_artifact_sha256=digest.split(':')[1],query_sha256=hashlib.sha256(query.encode()).hexdigest());save()
        assert result['state']=='PASS_EXACT_APPLICATION_CATALOG','Application catalog drift'
        assert api('commits/main')['sha']==sha,'Live HEAD changed before Auth'
        print('FULL_APPLICATION_CATALOG_PARITY_PASS')
    except Exception:
        save();raise RuntimeError('Full HML catalog parity failed closed; sanitized receipt recorded') from None
