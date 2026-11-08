import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
test('managed worker boundary proof rejects invalid metadata and false HTTP denials',()=>{
 assert(existsSync('supabase/tests/worker_api_boundary_hml.py'),'real API boundary proof is required');
 const code=String.raw`import importlib.util
s=importlib.util.spec_from_file_location('boundary','supabase/tests/worker_api_boundary_hml.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
good={'extension_present':False,'extension_ready':False,'scheduler_access':False,'application_logins_closed':True,'trusted_logins_only':True,'destination_is_hml':True,'token_present':True,'cron_active':True}
assert m.metadata_valid(good,'preinstall')
post={**good,'extension_present':True,'extension_ready':True,'scheduler_access':True}
assert m.metadata_valid(post,'postinstall') and not m.metadata_valid(post,'preinstall')
assert not m.metadata_valid(good,'other') and not m.metadata_valid({},'preinstall') and not m.metadata_valid({**good,'extra':True},'preinstall')
for key in good:
 for value in [None,'true',1,0,not good[key]]:
  assert not m.metadata_valid({**good,key:value},'preinstall'),(key,value)
assert m.api_denied(406,{'code':'PGRST106'})
for status in [0,200,400,401,403,404,500]:assert not m.api_denied(status,{'code':'PGRST106'})
for body in [None,[],{}, {'code':'42501'}, {'code':'PGRST301'}]:assert not m.api_denied(406,body)
try:m.NoRedirect().redirect_request(None,None,302,'',{},'https://foreign.invalid')
except m.BoundaryError:pass
else:raise AssertionError('redirect accepted')
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);
});
test('boundary cleanup recovers uncertain owned creation without deleting foreign identities',()=>{
 const code=String.raw`import importlib.util,uuid
s=importlib.util.spec_from_file_location('boundary','supabase/tests/worker_api_boundary_hml.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
nonce='n';intent=str(uuid.uuid4());email='worker-boundary-n@example.invalid';identifier=str(uuid.uuid4())
owned={'id':identifier,'email':email,'app_metadata':{'scope':m.SCOPE,'boundary_nonce':nonce,'fixture_request_id':intent}}
foreign={**owned,'id':str(uuid.uuid4()),'app_metadata':{**owned['app_metadata'],'boundary_nonce':'foreign'}}
assert m.own_record(owned,nonce,intent,email) and not m.own_record(foreign,nonce,intent,email)
assert not m.own_record({**owned,'id':'invalid'},nonce,intent,email)
def probe():
 p=object.__new__(m.Probe);p.creation_attempted=True;p.create_outcome='uncertain';p.user_id=None;p.nonce=nonce;p.intent=intent;p.email=email;return p
p=probe();p.find_owned=lambda:None
try:p.cleanup()
except m.BoundaryError:pass
else:raise AssertionError('uncertain create cannot certify absence')
p=probe();deleted=[];state={'gone':False}
def request(path,**kwargs):
 if '?page=' in path:return 200,{'users':[foreign] if state['gone'] else [foreign,owned]}
 if kwargs.get('method')=='DELETE':
  deleted.append(path);state['gone']=True;return 200,{}
 return (404,{'error_code':'user_not_found'}) if state['gone'] else (200,owned)
p.request=request
assert p.cleanup() and deleted==['/auth/v1/admin/users/'+identifier]
p=probe();p.user_id=identifier;p.request=lambda *a,**k:(200,foreign)
try:p.cleanup()
except m.BoundaryError:pass
else:raise AssertionError('foreign identity accepted')
p=probe();p.creation_attempted=False;p.request=lambda *a,**k:(_ for _ in ()).throw(AssertionError('unexpected Auth request'))
assert p.cleanup()
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);
});
test('worker boundary runs immediately before and after the single approved deploy',()=>{
 const w=readFileSync('.github/workflows/p0-hml-migration-version-parity.yml','utf8');
 const before=w.indexOf('Worker API boundary before deploy');const deploy=w.indexOf('name: Deploy only approved CLI migration');const after=w.indexOf('Worker API boundary after deploy');
 assert(before>=0&&before<deploy&&after>deploy,'real pre/post steps required');
 assert.equal((w.match(/AUTH_ADMIN_KEY: \$\{\{ secrets.CONTAOS_HML_AUTH_ADMIN_KEY \}\}/g)||[]).length,2);
 assert(w.includes('worker_api_boundary_hml.py --stage preinstall'));assert(w.includes('worker_api_boundary_hml.py --stage postinstall'));
 assert(w.includes("env.TARGET_VERSION == '20261108060000'"));
 assert(w.includes('path: ${{ runner.temp }}/contaos-worker-boundary/*-report.json'));
});
test('authenticated boundary refuses wrong issued token role or subject before authenticated REST',()=>{
 const code=String.raw`import importlib.util,uuid,json,base64
s=importlib.util.spec_from_file_location('boundary','supabase/tests/worker_api_boundary_hml.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
identifier=str(uuid.uuid4());other=str(uuid.uuid4());nonce='own';intent=str(uuid.uuid4());email='own@example.invalid'
owned={'id':identifier,'email':email,'app_metadata':{'scope':m.SCOPE,'boundary_nonce':nonce,'fixture_request_id':intent}}
def token(role,sub):
 enc=lambda v:base64.urlsafe_b64encode(json.dumps(v).encode()).decode().rstrip('=')
 return enc({'alg':'RS256'})+'.'+enc({'role':role,'sub':sub})+'.fixture'
def execute(issued):
 p=object.__new__(m.Probe);p.nonce=nonce;p.intent=intent;p.email=email;p.user_id=None;p.creation_attempted=False;p.stage='preinstall'
 p.report={'assertions':[],'cleanup':'NOT_REQUIRED','recovery':{}};p.save=lambda:None;p.cleanup=lambda:True
 p.read_metadata=lambda:{'extension_present':False,'extension_ready':False,'scheduler_access':False,'application_logins_closed':True,'trusted_logins_only':True,'destination_is_hml':True,'token_present':True,'cron_active':True}
 calls=[]
 def request(path,data=None,token=None,admin=False,method=None,profile=None):
  if token and path.startswith('/rest/v1/'):calls.append(path)
  if path=='/auth/v1/admin/users':return 200,owned
  if path.startswith('/auth/v1/token'):return 200,{'access_token':issued}
  if path=='/auth/v1/user':return 200,{'id':identifier}
  if profile=='net':return 406,{'code':'PGRST106'}
  return 200,{}
 p.request=request
 return p.run(),calls
ok,calls=execute(token('authenticated',identifier));assert ok and len(calls)==2
for invalid in [token('anon',identifier),token('service_role',identifier),token('authenticated',other),'malformed']:
 ok,calls=execute(invalid)
 assert not ok,'wrong issued token certified authenticated'
 assert calls==[],'wrong issued token reached authenticated REST'
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);
});
test('real probe uses accessible public controls and never certifies anonymous public 401',()=>{
 const code=String.raw`import importlib.util,tempfile,json,uuid,base64
from pathlib import Path
s=importlib.util.spec_from_file_location('boundary','supabase/tests/worker_api_boundary_hml.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
with tempfile.TemporaryDirectory() as d:
 p=object.__new__(m.Probe);p.stage='preinstall';p.report_path=Path(d)/'pre-report.json';p.nonce='testnonce';p.intent=str(uuid.uuid4());p.email='worker-boundary-testnonce@example.invalid';p.creation_attempted=False;p.create_outcome='not_started';p.user_id=None;p.report={'assertions':[],'recovery':{}}
 p.read_metadata=lambda:{'extension_present':False,'extension_ready':False,'scheduler_access':False,'application_logins_closed':True,'trusted_logins_only':True,'destination_is_hml':True,'token_present':True,'cron_active':True}
 identifier=str(uuid.uuid4());owned={'id':identifier,'email':p.email,'app_metadata':{'scope':m.SCOPE,'boundary_nonce':p.nonce,'fixture_request_id':p.intent}}
 enc=lambda v:base64.urlsafe_b64encode(json.dumps(v).encode()).decode().rstrip('=')
 token=enc({'alg':'RS256'})+'.'+enc({'role':'authenticated','sub':identifier})+'.PRIVATE_TOKEN_CANARY'
 state={'deleted':False};calls=[]
 def request(path,data=None,**kw):
  calls.append((path,kw.get('admin',False),kw.get('profile')))
  if path=='/auth/v1/settings':assert not kw.get('admin') and not kw.get('token');return 200,{}
  if path=='/rest/v1/':return 401,{'code':'42501'}
  if path=='/rest/v1/configuracao_upload?select=id&limit=0':assert kw.get('token')==token and not kw.get('admin');return 200,[]
  if path=='/rest/v1/http_request_queue?select=id&limit=0':assert kw.get('profile')=='net' and not kw.get('admin');return 406,{'code':'PGRST106'}
  if path=='/auth/v1/admin/users':assert kw.get('admin');return 201,owned
  if path.startswith('/auth/v1/token?'):assert not kw.get('admin');return 200,{'access_token':token}
  if path=='/auth/v1/user':return 200,{'id':identifier}
  if path.startswith('/auth/v1/admin/users?page='):return 200,{'users':[] if state['deleted'] else [owned]}
  if path=='/auth/v1/admin/users/'+identifier:
   if kw.get('method')=='DELETE':state['deleted']=True;return 200,{}
   return (404,{'error_code':'user_not_found'}) if state['deleted'] else (200,owned)
  raise AssertionError('unexpected request')
 p.request=request
 assert p.run(),'public 401 must be replaced by a genuine accessible control'
 assert state['deleted'] and p.report['state']=='PASS' and p.report['cleanup']=='OWN_AUTH_ABSENT_CONFIRMED'
 assert '/rest/v1/' not in [x[0] for x in calls]
 assert 'PRIVATE_TOKEN_CANARY' not in p.report_path.read_text()
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);
});
test('boundary security tests run before local database creation in Restore',()=>{
 const w=readFileSync('.github/workflows/restore-isolado.yml','utf8');
 const security=w.indexOf('node --test supabase/tests/p0_crud_global_protocol.test.mjs supabase/tests/worker_api_boundary.test.mjs');
 assert(security>=0&&security<w.indexOf('name: Iniciar PostgreSQL Supabase isolado'),'new boundary security suite must execute in CI before DB initialization');
});
