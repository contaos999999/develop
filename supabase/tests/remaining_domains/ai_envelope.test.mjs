import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const ids={org:'11111111-1111-4111-8111-111111111111',contract:'22222222-2222-4222-8222-222222222222',entity:'33333333-3333-4333-8333-333333333333',job:'44444444-4444-4444-8444-444444444444'};
const message={msg_id:1,read_ct:1,id_execucao:ids.job,payload:{entidade_tipo:'execucao_analise',entidade_id:ids.entity,id_execucao:ids.entity,id_organizacao:ids.org,id_contrato:ids.contract}};
test('actual AI dispatch consumes the nested worker_pull_job envelope',async()=>{
 const source=fs.readFileSync('supabase/functions/queue-worker-ai/index.ts','utf8');
 const body=source.match(/async function processar\(job:any\)\{[^\n]+/)[0].replace('(job:any)','(job)');
 const {normalizeAIJob}=fs.existsSync('supabase/functions/queue-worker-ai/job-envelope.mjs')?await import('../../functions/queue-worker-ai/job-envelope.mjs'):{normalizeAIJob:x=>x};
 const names=['extrairDocumento','analisarCompetencia','gerarParecer','extrairDiligencia','revalidarApontamento','minutaContestacao','aprenderDesfecho'];
 const dispatch=Function('normalizeAIJob',...names,body+';return processar;')(normalizeAIJob,...names.map(name=>async job=>({handler:name,job})));
 const result=await dispatch(message);assert.equal(result.handler,'analisarCompetencia');assert.equal(result.job.entidade_id,ids.entity);assert.equal(result.job.id_execucao,ids.job);
});

test('all implemented producers preserve canonical entity and distinct job identity',async()=>{
 const {normalizeAIJob}=await import('../../functions/queue-worker-ai/job-envelope.mjs');
 const types={extrair_documento:'id_versao_documento',execucao_analise:'id_execucao',gerar_parecer_interno:'id_competencia',extrair_diligencia:'id_parecer_contratante',revalidar_apontamento:'id_apontamento',minuta_contestacao:'id_apontamento',aprendizado_desfecho:'id_desfecho'};
 for(const [type,key] of Object.entries(types)){
  const original={...message,payload:{...message.payload,entidade_tipo:type,[key]:ids.entity,...(type==='aprendizado_desfecho'?{id_precedente:ids.contract}:{})}};
  const before=JSON.stringify(original);const result=normalizeAIJob(original);
  assert.equal(result.entidade_tipo,type);assert.equal(result.entidade_id,ids.entity);assert.equal(result.id_execucao,ids.job);assert.equal(result.payload[key],ids.entity);assert.equal(JSON.stringify(original),before);assert.notEqual(result.payload,original.payload);
 }
});
test('unknown, orphan, conflicting, invalid or unsafe envelopes never reach dispatch',async()=>{
 const {normalizeAIJob}=await import('../../functions/queue-worker-ai/job-envelope.mjs');
 for(const patch of [{payload:null},{msg_id:Number.MAX_SAFE_INTEGER+1},{read_ct:0},{id_execucao:null},{entidade_tipo:'gerar_parecer_interno'},{entidade_id:ids.contract},{id_organizacao:ids.entity},{payload:{...message.payload,entidade_tipo:'consulta_semantica'}},{payload:{...message.payload,id_execucao:ids.contract}},{payload:{...message.payload,id_contrato:'foreign'}},{payload:{...message.payload,id_evidencia:'invalid'}}])assert.throws(()=>normalizeAIJob({...message,...patch}));
});

import {spawnSync} from 'node:child_process';
test('AI deployment gate binds source readback and manual routing to this exact HEAD',()=>{
 const code=String.raw`import sys,pathlib,hashlib,copy
sys.path.insert(0,'supabase/tests')
from remaining_domains.ai_deploy_gate import validate_receipt,runtime_route,find_deployment_receipt,FILES
hashes={p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest() for p in FILES}
proof={'project':'gklhhhyosgasnyoxlrui','function_slug':'queue-worker-ai','from_version':4,'expected_version':5,'verify_jwt':False,'source_sha256':hashes,'prior_source_sha256':'4dcd7031ee37747fa5aa42a78616ffb682149edafd9a435efff6b009c7b9da14'}
task={'remaining_certification':{'project':proof['project'],'approved_ai_worker_deploy':proof}}
head='a'*40
r={'schema':'contaos.ai-worker-deployment.v1','backend_head':head,'project':proof['project'],'function_slug':'queue-worker-ai','version':5,'prior_version':4,'verify_jwt':False,'status':'ACTIVE','readback_equal':True,'source_sha256':hashes,'prior_source_sha256':proof['prior_source_sha256'],'management_bundle_sha256':'b'*64,'active_ai_jobs_before':0,'active_ai_jobs_after':0,'deployed_at':'2026-11-08T20:02:00Z','verified_at':'2026-11-08T20:02:01Z'}
assert validate_receipt(task,head,r)==r
import json
comment={'id':22,'created_at':'2026-11-08T20:02:02Z','user':{'login':'contaos9999'},'issue_url':'https://api.github.com/repos/contaos999999/develop/issues/138','body':json.dumps(r)}
assert find_deployment_receipt(task,head,[comment])==(22,r)
for comments in ([],[comment,comment],[{**comment,'user':{'login':'foreign'}}],[{**comment,'issue_url':'https://api.github.com/repos/foreign/repo/issues/138'}]):
 try:find_deployment_receipt(task,head,comments)
 except AssertionError:pass
 else:raise AssertionError('Unverified/ambiguous receipt accepted')
assert runtime_route(task,'workflow_dispatch') and runtime_route(task,'workflow_run')
assert not runtime_route(task,'pull_request') and runtime_route({},'workflow_run')
for key,value in [('backend_head','c'*40),('project','prod'),('function_slug','storage-sign-upload'),('version',4),('readback_equal',False),('active_ai_jobs_before',1),('active_ai_jobs_after',True),('verify_jwt',True),('management_bundle_sha256','invalid'),('source_sha256',{})]:
 bad=copy.deepcopy(r);bad[key]=value
 try:validate_receipt(task,head,bad)
 except (AssertionError,KeyError):pass
 else:raise AssertionError('Unsafe deployment receipt accepted '+key)
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});

test('actual routing limits explicit manual resume to exact main inputs',()=>{
 const code=String.raw`import re,subprocess,tempfile,pathlib,os,json
source=pathlib.Path('.github/workflows/p0-crud-remaining-hml.yml').read_text()
start=source.index('      - name: Read-only exact task routing');end=source.index('  runtime-ready:',start)
section=source[start:end];script=section.split('        run: |\n',1)[1]
script='\n'.join(line[10:] if line.startswith('          ') else line for line in script.splitlines())
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
for event,patch,ok,applicable in [('workflow_run',{},True,True),('workflow_dispatch',{},True,True),('workflow_dispatch',{'REQUESTED_HEAD':'0'*40},False,False),('workflow_dispatch',{'RESTORE_RUN_ID':'bad'},False,False),('workflow_dispatch',{'DEPLOY_RECEIPT_COMMENT_ID':''},False,False),('workflow_dispatch',{'GITHUB_REF':'refs/heads/foreign'},False,False)]:
 with tempfile.TemporaryDirectory() as d:
  env={'PATH':os.environ['PATH'],'GITHUB_OUTPUT':d+'/out','GITHUB_SHA':head,'REQUESTED_HEAD':head,'GITHUB_EVENT_NAME':event,'GITHUB_REF':'refs/heads/main','RESTORE_RUN_ID':'11','DEPLOY_RECEIPT_COMMENT_ID':'22',**patch}
  fixture=pathlib.Path(d)/'fixture';fixture.mkdir()
  for name in ['supabase','.github','.git']:(fixture/name).symlink_to(pathlib.Path(name).resolve(),target_is_directory=name!='.git')
  (fixture/'docs/tasks').mkdir(parents=True)
  task=json.loads(pathlib.Path('docs/tasks/active-task.json').read_text());task['id']='P0-CRUD-GLOBAL-HML-20261107';task['phase']='BUILD_CERTIFICACAO_DOMINIOS_RESTANTES'
  (fixture/'docs/tasks/active-task.json').write_text(json.dumps(task))
  r=subprocess.run(['bash','-e','-o','pipefail','-c',script],env=env,cwd=fixture,capture_output=True,text=True)
  assert (r.returncode==0)==ok,(event,patch,r.stderr)
  if ok:assert ('applicable='+str(applicable).lower()) in pathlib.Path(d+'/out').read_text()
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});

test('actual runtime readiness gate revalidates unchanged deployed source against current CI and original receipt',()=>{
 const code=String.raw`import os,pathlib,subprocess,tempfile,json,copy
source=pathlib.Path('.github/workflows/p0-crud-remaining-hml.yml').read_text();start=source.index('  runtime-ready:');section=source[start:source.index('  public-probe:',start)]
assert 'environment:' not in section and 'secrets.' not in section
assert "needs: [scope, runtime-ready]" in source and "needs.runtime-ready.result == 'success'" in source
script=section.split('        run: |\n',1)[1];script='\n'.join(x[10:] if x.startswith('          ') else x for x in script.splitlines())
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();task=json.load(open('docs/tasks/active-task.json'));p=task['remaining_certification']['approved_ai_worker_runtime'];approval=p['origin_approval']
origin={'schema':'contaos.ai-worker-deployment.v1','backend_head':p['origin_backend_head'],'project':p['project'],'function_slug':p['function_slug'],'version':5,'prior_version':4,'verify_jwt':False,'status':'ACTIVE','readback_equal':True,'source_sha256':p['source_sha256'],'prior_source_sha256':approval['prior_source_sha256'],'management_bundle_sha256':p['expected_bundle_sha256'],'active_ai_jobs_before':0,'active_ai_jobs_after':0,'deployed_at':p['expected_deployed_at'],'verified_at':'2026-11-08T20:27:30Z'}
r={**origin,'schema':'contaos.ai-worker-runtime.v1','backend_head':head,'verified_at':'2026-11-08T21:02:01Z','origin_deployment_receipt_id':p['origin_receipt_comment_id']}
comment={'id':22,'created_at':'2026-11-08T21:02:02Z','user':{'login':'contaos9999'},'issue_url':'https://api.github.com/repos/contaos999999/develop/issues/138','body':json.dumps(r)}
parent={'id':p['origin_receipt_comment_id'],'created_at':'2026-11-08T20:28:06Z','user':{'login':'contaos9999'},'issue_url':comment['issue_url'],'body':json.dumps(origin)}
for case in ['valid','missing','ambiguous','stale_restore','failed_backup','advanced_head','stale_comment','altered_deployment_time','early_verification','newer_failed_backup','origin_adulterated','origin_foreign_actor','origin_changed_bundle','initial_receipt_instead_of_runtime','current_source_changed']:
 with tempfile.TemporaryDirectory() as d:
  base=pathlib.Path(d);(base/'bin').mkdir();gh=base/'bin/gh'
  gh.write_text("#!/usr/bin/env python3\nimport json,sys,os\nd=json.load(open(os.environ['FIXTURE']));p=sys.argv[-1]\nif p.endswith('/commits/main'):v={'sha':d['live']}\nelif '/check-runs?' in p:v={'check_runs':d['checks']}\nelif '/actions/runs/' in p:v=d['restore']\nelif '/issues/138/comments?' in p:v=d['comments']\nelif '/issues/comments/' in p:v=d['origin']\nelse:raise SystemExit('Unexpected API')\nprint(json.dumps(v))\n");gh.chmod(0o700)
  data={'live':head,'checks':[{'id':10+i,'name':n,'head_sha':head,'conclusion':'success','completed_at':'2026-11-08T21:01:00Z'} for i,n in enumerate(['guard','reconstruir-banco-do-zero','prova-backup-dados-sinteticos-duas-instancias'])],'restore':{'head_sha':head,'head_branch':'main','event':'push','status':'completed','conclusion':'success','name':'ContaOS Restore Isolado','created_at':'2026-11-08T21:00:00Z','updated_at':'2026-11-08T21:01:00Z'},'comments':[copy.deepcopy(comment)],'origin':copy.deepcopy(parent)}
  if case=='missing':data['comments']=[]
  if case=='ambiguous':data['comments']=[comment,comment]
  if case=='stale_restore':data['restore']['head_sha']='b'*40
  if case=='failed_backup':data['checks'][-1]['conclusion']='failure'
  if case=='newer_failed_backup':data['checks'].append({**data['checks'][-1],'id':99,'conclusion':'failure'})
  if case=='advanced_head':data['live']='b'*40
  if case=='stale_comment':data['comments'][0]['created_at']='2026-11-08T19:00:00Z'
  if case=='origin_foreign_actor':data['origin']['user']['login']='foreign'
  if case in ('origin_adulterated','origin_changed_bundle'):
   bad=copy.deepcopy(origin)
   if case=='origin_adulterated':bad['source_sha256']['supabase/functions/queue-worker-ai/index.ts']='0'*64
   else:bad['management_bundle_sha256']='0'*64
   data['origin']['body']=json.dumps(bad)
  if case=='initial_receipt_instead_of_runtime':data['comments'][0]['body']=json.dumps({**origin,'backend_head':head})
  if case in ('altered_deployment_time','early_verification','current_source_changed'):
   bad=copy.deepcopy(r)
   if case=='altered_deployment_time':bad['deployed_at']='2026-11-08T19:00:00Z'
   if case=='early_verification':bad['verified_at']='2026-11-08T20:28:00Z'
   if case=='current_source_changed':bad['source_sha256']['supabase/functions/queue-worker-ai/index.ts']='0'*64
   data['comments'][0]['body']=json.dumps(bad)
  (base/'fixture').write_text(json.dumps(data));env={'PATH':str(base/'bin')+':'+os.environ['PATH'],'FIXTURE':str(base/'fixture'),'TESTED_HEAD':head,'RESTORE_RUN_ID':'11','GITHUB_OUTPUT':str(base/'out'),'DEPLOY_RECEIPT_COMMENT_ID':''}
  result=subprocess.run(['bash','-e','-o','pipefail','-c',script],env=env,capture_output=True,text=True)
  assert (result.returncode==0)==(case=='valid'),(case,result.stderr)
  if case=='valid':assert (base/'out').read_text()=='receipt_comment_id=22\n'
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});
