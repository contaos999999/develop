"""Own Auth Admin fixtures and SQL confirmation; never transfers admin/DB to browser."""
import json, os, secrets, subprocess, sys, uuid, urllib.request, urllib.error, urllib.parse
from pathlib import Path
URL='https://gklhhhyosgasnyoxlrui.supabase.co'
KEY='sb_publishable_sHKZ-UiYCbkEFMqR1QbHMA_iCSLL8Am'
ALLOWED=('PATH','HOME','RUNNER_TEMP','TMPDIR','LANG','TZ','CI','XDG_CACHE_HOME','CONTAOS_TEST_PRIVATE_DIR','CONTAOS_FRONTEND_DIR','CONTAOS_AXE_SOURCE_PATH','CONTAOS_PLAYWRIGHT_MODULE','TESTED_HEAD','FRONTEND_HEAD')
def browser_environment(env): return {k:env[k] for k in ALLOWED if k in env}
def q(value): return "'"+str(value).replace("'","''")+"'"
def uid(): return str(uuid.uuid4())
def public_record(name, passed, http=None):
    import re
    assert re.fullmatch('[A-Z0-9_]{1,100}',name) and type(passed) is bool
    assert http is None or type(http) is int and 100<=http<=599
    return dict(name=name,passed=passed,http=http)
class Runner:
    def __init__(self, env):
        self.env=env; self.root=Path(env['CONTAOS_TEST_PRIVATE_DIR']).resolve()
        assert str(self.root).startswith(str(Path(env['RUNNER_TEMP']).resolve())+'/')
        self.root.mkdir(mode=0o700,parents=True,exist_ok=True);os.chmod(self.root,0o700)
        self.db=env['DATABASE_URL'];u=urllib.parse.urlsplit(self.db)
        assert u.username=='postgres.gklhhhyosgasnyoxlrui' and u.hostname.endswith('.pooler.supabase.com')
        self.admin=env.get('AUTH_ADMIN_KEY','');assert self.admin,'Auth Admin API required'
        self.report={'schema':'contaos.crud-global.hml.v1','backend_head':env['TESTED_HEAD'],'frontend_head':env['FRONTEND_HEAD'],'state':'RUNNING','batch':'CADASTROS_LISTAS','global_complete':False,'assertions':[]}
    def save(self,name,data):
        assert name in ('fixture.json','report.json','cleanup.json')
        p=self.root/name;p.write_text(json.dumps(data,indent=2)+'\n');os.chmod(p,0o600)
        if name=='fixture.json':
            self.report['recovery']={'scope':data['scope'],'nonce':data['nonce'],'prefix':data['prefix'],'users':[{k:u[k] for k in ('id','intent_id','creation_state') if k in u} for u in data['users']]}
            self.save('report.json',self.report)
    def sql(self,source,fetch=False):
        p=subprocess.run(['psql',self.db,'-X','-qAt','-v','ON_ERROR_STOP=1'],input=source,capture_output=True,text=True,timeout=45)
        if p.returncode:raise RuntimeError('Own fixture database operation failed; private details withheld')
        return p.stdout.strip() if fetch else None
    def request(self,path,data=None,token=None,admin=False,method=None):
        assert path.startswith('/auth/v1/') or path.startswith('/rest/v1/')
        headers={'apikey':self.admin if admin else KEY,'Content-Type':'application/json'}
        if admin or token:headers['Authorization']='Bearer '+(self.admin if admin else token)
        req=urllib.request.Request(URL+path,data=None if data is None else json.dumps(data).encode(),headers=headers,method=method)
        try:
            with urllib.request.urlopen(req,timeout=30) as r:
                raw=r.read();return r.status,json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            try:return e.code,json.loads(e.read())
            except ValueError:return e.code,{}
        except Exception:return 0,{}
    def check(self,name,passed,http=None):
        self.report['assertions'].append(public_record(name,passed,http));self.save('report.json',self.report)
        if not passed:raise RuntimeError('CRUD proof assertion failed: '+name)
    def prepare(self):
        assert not (self.root/'fixture.json').exists(),'Refuse fixture reuse'
        nonce=uuid.uuid4().hex
        f={'scope':'P0-CRUD-GLOBAL-HML','nonce':nonce,'prefix':'0000 CRUDG '+nonce+' ','org':uid(),'org_b':uid(),'contractor':uid(),'contractor_b':uid(),'contract':uid(),'contract_b':uid(),'users':[],'created':{}}
        self.save('fixture.json',f)
        for role in ('master','administrador','leitor','usuario_b'):
            u={'profile':role,'intent_id':uid(),'email':'crudg-'+uid()+'@example.invalid','password':secrets.token_urlsafe(40)+'Aa1!','creation_state':'pending'}
            f['users'].append(u);self.save('fixture.json',f)
            st,data=self.request('/auth/v1/admin/users',{'email':u['email'],'password':u['password'],'email_confirm':True,'app_metadata':{'synthetic':True,'scope':f['scope'],'fixture_request_id':u['intent_id'],'crud_nonce':nonce}},admin=True)
            if 400<=st<500:u['creation_state']='rejected';self.save('fixture.json',f)
            self.check('AUTH_CREATE_'+role.upper(),st in (200,201) and isinstance(data,dict) and bool(data.get('id')),st)
            u.update(id=data['id'],creation_state='created');self.save('fixture.json',f)
        sql=['begin;']
        for suffix in ('','_b'):
            label='B' if suffix else 'A';org=f['org'+suffix];ct=f['contract'+suffix];cr=f['contractor'+suffix]
            sql += [f"insert into public.organizacoes(id,razao_social) values({q(org)},{q(f['prefix']+label)});",f"insert into public.contratantes(id,id_organizacao,razao_social) values({q(cr)},{q(org)},{q(f['prefix']+'contractor '+label)});",f"insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values({q(ct)},{q(org)},{q(cr)},{q('CRUDG-'+nonce+'-'+label)},'Own synthetic CRUD proof','2026-01-01');"]
        for u in f['users']:
            if u['profile']=='master':sql.append(f"insert into privado.administradores_master(id_usuario,motivo) values({q(u['id'])},'Own synthetic CRUD global proof');")
            else:
                org=f['org_b'] if u['profile']=='usuario_b' else f['org'];profile='administrador' if u['profile']=='usuario_b' else u['profile']
                sql.append(f"insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values({q(org)},{q(u['id'])},{q(profile)},true);")
        sql.append('commit;');self.sql('\n'.join(sql));return f
    def verify(self):
        f=json.loads((self.root/'fixture.json').read_text());created=f['created']
        for name in ('organization','contractor','contract','list'):
            assert name in created,'Browser receipt missing'
        self.check('ORG_PERSISTED',self.sql('select exists(select 1 from public.organizacoes where id='+q(created['organization'])+' and razao_social like '+q(f['prefix']+'%')+' and nome_fantasia='+q(f['prefix']+'edited')+" and situacao='suspensa');",True)=='t')
        self.check('CONTRACTOR_PERSISTED',self.sql('select exists(select 1 from public.contratantes where id='+q(created['contractor'])+' and id_organizacao='+q(f['org'])+' and nome_fantasia='+q(f['prefix']+'contractor-edited')+" and situacao='ativo');",True)=='t')
        self.check('CONTRACT_LIFECYCLE_PERSISTED',self.sql('select exists(select 1 from public.contratos where id='+q(created['contract'])+' and id_organizacao='+q(f['org'])+" and situacao='encerrado' and objeto='Own synthetic edited contract');",True)=='t')
        self.check('LIST_RECOVERY_PERSISTED',self.sql('select exists(select 1 from public.listas_verificacao where id='+q(created['list'])+' and id_contrato='+q(f['contract'])+' and nome='+q(f['prefix']+'recovered')+');',True)=='t')
        self.check('LIST_ITEM_EDIT_PERSISTED',self.sql('select exists(select 1 from public.itens_lista i join public.versoes_lista v on v.id=i.id_versao_lista where v.id_lista='+q(created['list'])+" and v.numero_versao=1 and i.codigo='OWN1' and i.descricao='Own optional item edited' and not i.obrigatorio);",True)=='t')
        self.check('LIST_TEMP_ITEM_REMOVED',self.sql('select not exists(select 1 from public.itens_lista i join public.versoes_lista v on v.id=i.id_versao_lista where v.id_lista='+q(created['list'])+" and i.codigo='TMP');",True)=='t')
        self.check('LIST_VERSION_LIFECYCLE',self.sql("select count(*)=2 and bool_and(case when numero_versao=1 then situacao='publicada' and vigencia_inicio='2026-01-01' and vigencia_fim='2026-06-30' and aprovado_em is not null when numero_versao=2 then situacao='substituida' and aprovado_em is null else false end) from public.versoes_lista where id_lista="+q(created['list'])+';',True)=='t')
        for command in f.get('commands',[]):
            self.check('COMMAND_AUDIT_AND_RECEIPT',self.sql("select exists(select 1 from public.eventos_auditoria where metadados->>'request_id'="+q(command['request_id'])+') and exists(select 1 from public.comandos_idempotentes where chave='+q(command['request_id'])+" and status='concluido');",True)=='t')
        self.check('OWN_AUDIT_PRESENT',int(self.sql('select count(*) from public.eventos_auditoria where id_organizacao='+q(f['org'])+';',True))>0)
    def cleanup(self):
        p=self.root/'fixture.json'
        if not p.exists():
            recovery=self.report.get('recovery')
            if not recovery:return
            self.save('fixture.json',recovery)
        f=json.loads(p.read_text());owned=[];unresolved=False
        for u in f['users']:
            ids=self.sql("select id from auth.users where raw_app_meta_data->>'fixture_request_id'="+q(u['intent_id'])+" and raw_app_meta_data->>'crud_nonce'="+q(f['nonce'])+" and raw_app_meta_data->>'scope'="+q(f['scope'])+';',True).splitlines()
            if len(ids)!=1:
                if u['creation_state']!='rejected':unresolved=True
                continue
            own=ids[0];owned.append(own);u['id']=own;self.save('fixture.json',f)
        # Recover UI-created organizations by a high-entropy own nonce, not untrusted receipts.
        orgs=self.sql('select id from public.organizacoes where razao_social like '+q(f['prefix']+'%')+';',True).splitlines()
        if owned:
            joined=','.join(map(q,owned));self.sql('begin;update privado.administradores_master set ativo=false where id_usuario in ('+joined+');update public.vinculos_usuarios set ativo=false where id_usuario in ('+joined+');commit;')
            for own in owned:
                st,_=self.request('/auth/v1/admin/users/'+own,{'ban_duration':'876000h'},admin=True,method='PUT')
                if st!=200:raise RuntimeError('Own Auth quarantine failed')
            self.sql('delete from auth.sessions where user_id in ('+joined+');')
            clean=self.sql('select not exists(select 1 from auth.sessions where user_id in ('+joined+')) and not exists(select 1 from privado.administradores_master where ativo and id_usuario in ('+joined+')) and not exists(select 1 from public.vinculos_usuarios where ativo and id_usuario in ('+joined+'));',True)
            assert clean=='t','Own identities not fully quarantined'
        if orgs:
            joined=','.join(map(q,orgs));self.sql("update public.organizacoes set situacao='inativa' where id in ("+joined+');')
            assert self.sql("select not exists(select 1 from public.organizacoes where situacao<>'inativa' and id in ("+joined+'));',True)=='t'
        if unresolved:raise RuntimeError('Ambiguous own Auth creation; known identities quarantined')
        result={'state':'QUARENTENA_VERIFICADA','own_users':len(owned),'own_organizations':len(orgs)};self.save('cleanup.json',result);self.report['cleanup']=result;self.save('report.json',self.report)
def self_test():
    import tempfile
    assert browser_environment({'PATH':'/bin','DATABASE_URL':'PRIVATE_CANARY','AUTH_ADMIN_KEY':'PRIVATE_CANARY','GH_TOKEN':'PRIVATE_CANARY'})=={'PATH':'/bin'}
    assert public_record('READ_SCOPE',True,200)=={'name':'READ_SCOPE','passed':True,'http':200}
    rejected=False
    try:public_record('secret@example.invalid',True)
    except AssertionError:rejected=True
    assert rejected,'unsafe public record accepted'
    r=object.__new__(Runner);r.report={'assertions':[]};calls=[]
    with tempfile.TemporaryDirectory() as d:
        r.root=Path(d);f={'scope':'P0-CRUD-GLOBAL-HML','nonce':'own-nonce','prefix':'own-prefix ','users':[{'intent_id':'own-intent','creation_state':'pending'}]};r.save('fixture.json',f)
        def fake_sql(source,fetch=False):
            calls.append(source)
            if source.startswith('select id from auth.users'):
                assert 'own-intent' in source and 'own-nonce' in source;return '11111111-1111-4111-8111-111111111111'
            if source.startswith('select id from public.organizacoes'):return '22222222-2222-4222-8222-222222222222'
            return 't' if fetch else None
        def fake_request(path,data=None,token=None,admin=False,method=None):
            assert path.endswith('11111111-1111-4111-8111-111111111111') and admin and method=='PUT';calls.append('BAN');return 200,{}
        r.sql=fake_sql;r.request=fake_request;r.cleanup()
        assert 'BAN' in calls and any('delete from auth.sessions' in x for x in calls)
        assert json.loads((r.root/'cleanup.json').read_text())['state']=='QUARENTENA_VERIFICADA'
        assert not any('insert into auth.users' in x.lower() for x in calls)
    print('CRUD_GLOBAL_PROTOCOL_PASS')
def main():
    if '--self-test' in sys.argv:self_test();return 0
    r=Runner(os.environ)
    if '--cleanup' in sys.argv:
        if (r.root/'report.json').exists():r.report=json.loads((r.root/'report.json').read_text())
        r.cleanup();return 0
    failed=False
    try:
        r.prepare()
        p=subprocess.run(['node','supabase/tests/p0_crud_global_browser.mjs'],env=browser_environment(os.environ),capture_output=True,text=True,timeout=1200)
        r.check('REAL_BROWSER_BATCH',p.returncode==0)
        r.verify();r.report['state']='PASS_BATCH';r.report['unverified_domains']=['regras_preventivas','base_normativa','orcamento','documentos_contrato','documento_detalhe','competencias','documentos_competencia','analise_revisao','parecer','apresentacao','protocolo','historico','administracao','auditoria']
    except Exception as e:
        failed=True;r.report['state']='FAIL';r.report['failure_class']=type(e).__name__
    finally:
        try:r.cleanup()
        except Exception:failed=True;r.report['state']='CLEANUP_FAILED'
        r.save('report.json',r.report)
    print('CRUD_GLOBAL_BATCH_'+('FAIL' if failed else 'PASS')+'; sanitized report and own quarantine recorded')
    return 1 if failed else 0
if __name__=='__main__':sys.exit(main())
