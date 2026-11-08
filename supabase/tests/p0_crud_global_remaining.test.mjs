import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const run=code=>spawnSync('python3',['-c',"import sys;sys.path.insert(0,'supabase/tests')\n"+code],{encoding:'utf8'});
test('remaining selection and immutable documentary evidence fail closed',()=>{
 const r=run(`import json,copy,tempfile,pathlib,shutil
import p0_crud_global_remaining_hml as m
t=json.load(open('docs/tasks/active-task.json'));t['id']='P0-CRUD-GLOBAL-HML-20261107';t['phase']='BUILD_CERTIFICACAO_DOMINIOS_RESTANTES';t['remaining_certification']['domains_to_run']=['base_normativa','orcamento','competencias']
assert m.selected_domains(t)==['base_normativa','orcamento','competencias']
m.assert_preserved(pathlib.Path('.'),t)
for change in [{'project':'foreign'},{'domains_to_run':['../../attack']},{'domains_to_run':['base_normativa','base_normativa']},{'domains_to_run':[]}]:
 x=copy.deepcopy(t);x['remaining_certification'].update(change)
 try:m.selected_domains(x)
 except (AssertionError,ValueError):pass
 else:raise AssertionError('Unsafe selection accepted')
with tempfile.TemporaryDirectory() as d:
 root=pathlib.Path(d)
 for p in m.PROTECTED:
  target=root/p;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
 (root/m.PROTECTED[0]).write_text('tampered')
 try:m.assert_preserved(root,t)
 except AssertionError:pass
 else:raise AssertionError('Documentary regression accepted')
print('PRESERVED_EVIDENCE_PASS')`);assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/PRESERVED_EVIDENCE_PASS/);
});
test('remaining transport refuses redirect and foreign signed upload before credentials',()=>{
 const r=run(`import urllib.request,urllib.error
import p0_crud_global_remaining_hml as m
valid=m.URL+'/storage/v1/object/upload/sign/contaos-documentos/'+'a'*36+'/uploads/id/crudg-'+'b'*32+'-source.txt?token=private'
m.validate_target(valid,upload=True,org='a'*36,nonce='b'*32)
for url in ['https://foreign.invalid/auth/v1/token',m.URL+'@foreign.invalid/rest/v1/',m.URL+'/functions/v1/unknown',m.URL+'/storage/v1/object/upload/sign/other/a',valid.replace('crudg-','alien-'),valid+'#fragment']:
 try:m.validate_target(url,upload=True,org='a'*36,nonce='b'*32)
 except AssertionError:pass
 else:raise AssertionError('Unsafe target accepted')
handler=m.NoRedirect();assert handler.redirect_request(None,None,307,'',{},'https://foreign.invalid') is None
print('TRANSPORT_FAIL_CLOSED_PASS')`);assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/TRANSPORT_FAIL_CLOSED_PASS/);
});
test('domain PASS requires actual positive operations, SQL checks and exact negative roles',()=>{
 const r=run(`import p0_crud_global_remaining_hml as m,copy
for domain,required in m.REQUIRED.items():
 report={'domain':domain,'global_complete':False,'assertions':[{'name':n,'passed':True} for n in required['checks']],'receipts':[{'operation':n,'role':'administrador','http':200} for n in required['rpc']]+[{'role':role,'http':403} for role in ('leitor','usuario_b','anon')]}
 m.assert_complete(report,domain)
 for key in ('assertions','receipts'):
  bad={**report,key:[]}
  try:m.assert_complete(bad,domain)
  except AssertionError:pass
  else:raise AssertionError('Empty domain passed')
 for index in range(len(report['assertions'])):
  bad=copy.deepcopy(report);bad['assertions'][index]['passed']=False
  try:m.assert_complete(bad,domain)
  except AssertionError:pass
  else:raise AssertionError('Failed proof passed')
 bad=copy.deepcopy(report);bad['receipts'][-1]['http']=500
 try:m.assert_complete(bad,domain)
 except AssertionError:pass
 else:raise AssertionError('HTTP500 interpreted as denial')
print('INCOMPLETE_DOMAIN_NEVER_PASS')`);assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/INCOMPLETE_DOMAIN_NEVER_PASS/);
});
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,chmodSync,copyFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
const wf=()=>readFileSync('.github/workflows/p0-crud-remaining-hml.yml','utf8');
const section=(name)=>wf().match(new RegExp('^  '+name+':\\n([\\s\\S]*?)(?=^  [a-z][a-z-]*:|$(?![\\s\\S]))','m'))?.[1]||'';
const scripts=source=>[...source.matchAll(/^        run: \|\n((?:^          .*\n|^\n)+)/gm)].map(m=>m[1].split('\n').map(l=>l.startsWith('          ')?l.slice(10):l).join('\n'));
test('remaining routing is before HML environment and closes foreign/failed/PR origins',()=>{
 const s=section('scope'),job=section('domain-proof');assert(s&&job);assert.doesNotMatch(s,/secrets\.|environment:|GH_TOKEN/);assert.match(job,/needs: scope/);assert.match(job,/fail-fast: false/);assert.match(job,/Independent own quarantine/);assert.match(job,/cleanup.json/);
 const condition=s.match(/^    if: (.+)$/m)[1];
 for(const [change,want] of [[{},true],[{conclusion:'failure'},false],[{event:'pull_request'},false],[{head_branch:'feature'},false],[{head_repository:{full_name:'foreign/repo'}},false]]){
  const context={github:{event_name:'workflow_run',repository:'contaos999999/develop',event:{workflow_run:{conclusion:'success',event:'push',head_branch:'main',head_repository:{full_name:'contaos999999/develop'},...change}}}};
  assert.equal((new Function('github','return '+condition))(context.github),want);
 }
 assert.match(wf(),/unset GH_TOKEN\n          python3 supabase\/tests\/p0_crud_global_remaining_hml.py/);
});
test('real gate rejects missing check, failed check and advanced HEAD before Auth',()=>{
 const root=resolve('.'),dir=mkdtempSync(join(tmpdir(),'remaining-gate-'));
 try{
  const task=JSON.parse(readFileSync('docs/tasks/active-task.json','utf8'));const protectedPaths=Object.keys(task.remaining_certification.preserved_documental.protected_sha256);
  for(const p of [...protectedPaths,'supabase/tests/p0_crud_global_remaining_hml.py','docs/tasks/active-task.json']){mkdirSync(join(dir,p,'..'),{recursive:true});copyFileSync(p,join(dir,p));}
  task.remaining_certification.domains_to_run=['base_normativa'];writeFileSync(join(dir,'docs/tasks/active-task.json'),JSON.stringify(task));
  mkdirSync(join(dir,'bin'));
  writeFileSync(join(dir,'bin/git'),`#!/usr/bin/env python3
import sys,os
if sys.argv[1]=='show':sys.stdout.buffer.write(open(os.environ['SOURCE_ROOT']+'/'+sys.argv[2].split(':',1)[1],'rb').read())
else:print(os.environ['TESTED_HEAD'])
`);chmodSync(join(dir,'bin/git'),0o700);
  writeFileSync(join(dir,'bin/gh'),`#!/usr/bin/env python3
import sys,os,json
print(json.dumps({'sha':os.environ['LIVE_HEAD']} if sys.argv[-1].endswith('/commits/main') else json.loads(open(os.environ['CHECKS_FILE']).read())))
`);chmodSync(join(dir,'bin/gh'),0o700);
  const sha='a'.repeat(40),names=['guard','reconstruir-banco-do-zero','prova-backup-dados-sinteticos-duas-instancias'];const [gate]=scripts(section('domain-proof'));assert(gate);
  for(const kind of ['valid','missing','failed','stale_check','advanced_head']){
   const checks=names.filter(n=>kind!=='missing'||n!=='guard').map(name=>({name,head_sha:kind==='stale_check'?'b'.repeat(40):sha,conclusion:kind==='failed'?'failure':'success'}));
   writeFileSync(join(dir,'checks.json'),JSON.stringify({check_runs:checks}));
   const r=spawnSync('bash',['-e','-o','pipefail','-c',gate],{cwd:dir,env:{PATH:join(dir,'bin')+':'+process.env.PATH,SOURCE_ROOT:root,TESTED_HEAD:sha,LIVE_HEAD:kind==='advanced_head'?'b'.repeat(40):sha,DOMAIN:'base_normativa',CHECKS_FILE:join(dir,'checks.json'),RUNNER_TEMP:dir,GITHUB_ENV:join(dir,'env')},encoding:'utf8'});
   assert.equal(r.status===0,kind==='valid',r.stderr);assert.equal(r.stdout.includes('HEAD_MANIFEST_PRESERVED_PROOF_CHECKS_SUCCESS'),kind==='valid');
  }
 }finally{rmSync(dir,{recursive:true,force:true});}
});
test('Restore executes new domain gates and competency cannot pass without snapshot evidence',()=>{
 const restore=readFileSync('.github/workflows/restore-isolado.yml','utf8');assert.match(restore,/run: node --test[^\n]*p0_crud_global_remaining\.test\.mjs/);assert.match(restore,/fetch-depth: 0/);
 const r=run(`import p0_crud_global_remaining_hml as m
required=m.REQUIRED['competencias']['checks']
for n in ['COMPETENCE_SNAPSHOT_MATERIALIZED','COMPETENCE_SNAPSHOT_IMMUTABLE','COMPETENCE_SNAPSHOT_TENANT_ISOLATED','COMPETENCE_SNAPSHOT_SQL']:assert n in required
print('SNAPSHOT_AND_CI_GUARD_PASS')`);assert.equal(r.status,0,r.stderr);
});
test('runner context is resolved on runner steps rather than invalid job env',()=>{
 const job=section('domain-proof');const beforeSteps=job.slice(0,job.indexOf('    steps:'));assert.doesNotMatch(beforeSteps,/\$\{\{\s*runner\./);
 const [gate]=scripts(job);assert.match(gate,/os.environ\['RUNNER_TEMP'\]/);assert.match(gate,/GITHUB_ENV/);
});
test('budget prerequisite uses official registration and worker completion without direct approval',()=>{
 const r=run(`import json
from remaining_domains.orcamento import approve_source
class Fake:
 fixture={'org':'org','contract':'contract','prefix':'own '}
 def __init__(self,states):self.states=iter(states);self.calls=[];self.checks=[]
 def operation(self,name,payload):
  self.calls.append((name,payload));return {'id_documento':'doc','id_versao':'version','id_job':'job'}
 def entity(self,name,value):return value
 def sql(self,query,readonly):
  assert readonly is True and query.startswith('select ')
  assert 'aprovado' in query and 'concluido' in query and 'paginas_documento' in query and 'fragmentos_documento' in query
  return json.dumps(next(self.states))
 def check(self,name,value,*args):
  self.checks.append((name,value));assert value
r=Fake([{'owned':True,'ready':False,'failed':False},{'owned':True,'ready':True,'failed':False}]);approve_source(r,'file',timeout=1,pause=lambda _:None)
assert r.calls[0][0]=='criar_documento_contrato_completo'
assert ('BUDGET_SOURCE_WORKER_READY',True) in r.checks
for state in [{'owned':False,'ready':True,'failed':False},{'owned':True,'ready':False,'failed':True}]:
 try:approve_source(Fake([state]),'file',timeout=1,pause=lambda _:None)
 except AssertionError:pass
 else:raise AssertionError('Unready or foreign source approved')
print('BUDGET_PREREQUISITE_FAIL_CLOSED')`);assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/BUDGET_PREREQUISITE_FAIL_CLOSED/);
});
test('remaining second batch has positive operations, own worker prerequisites and mandatory SQL evidence',()=>{
 const r=run(`import importlib
import p0_crud_global_remaining_hml as m
for domain in ('regras_preventivas','documento_detalhe','documentos_competencia'):
 assert domain in m.DOMAINS
 requirement=m.REQUIRED[domain]
 assert len(requirement['rpc'])>=2 and any('SQL' in c for c in requirement['checks'])
 assert callable(importlib.import_module('remaining_domains.'+domain).run)
print('SECOND_BATCH_CLOSED_REGISTRY')`);assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/SECOND_BATCH_CLOSED_REGISTRY/);
});
test('own document worker refuses foreign, failed and timed out processing',()=>{
 const r=run(`import json
from remaining_domains.document_fixture import wait_document
class Fake:
 fixture={'org':'org','contract':'contract'}
 def __init__(self,states):self.states=iter(states)
 def entity(self,k,v):return v
 def sql(self,q,readonly):
  assert readonly is True and q.startswith('select ') and 'v.hash=a.sha256' in q
  assert 'id_organizacao' in q and 'id_contrato' in q
  return json.dumps(next(self.states))
 def check(self,n,v):assert v
receipt={'id_documento':'document','id_versao':'version','id_job':'job'}
for kind in ('contrato','competencia'):
 r=Fake([{'owned':True,'ready':False,'failed':False},{'owned':True,'ready':True,'failed':False}]);assert wait_document(r,receipt,'file',kind,pause=lambda _:None)==receipt
for state in [{'owned':False,'ready':True,'failed':False},{'owned':True,'ready':False,'failed':True},{'owned':True,'ready':False,'failed':False}]:
 try:wait_document(Fake([state]),receipt,'file','competencia',timeout=-1,pause=lambda _:None)
 except AssertionError:pass
 else:raise AssertionError('Invalid worker state passed')
print('OWN_WORKER_FAIL_CLOSED')`);assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/OWN_WORKER_FAIL_CLOSED/);
});
test('reviewed second batch cannot omit official reader or persisted vigency proof',()=>{
 const r=run(`import p0_crud_global_remaining_hml as m
assert 'obter_documentos_competencia_v115' in m.REQUIRED['documentos_competencia']['rpc']
assert 'COMP_DOC_OFFICIAL_READ' in m.REQUIRED['documentos_competencia']['checks']
assert 'DETAIL_SQL_VIGENCY' in m.REQUIRED['documento_detalhe']['checks']
print('REVIEW_GAPS_REQUIRED')`);assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/REVIEW_GAPS_REQUIRED/);
});
