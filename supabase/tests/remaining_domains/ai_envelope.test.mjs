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
from remaining_domains.ai_deploy_gate import validate_receipt,runtime_route,FILES
hashes={p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest() for p in FILES}
proof={'project':'gklhhhyosgasnyoxlrui','function_slug':'queue-worker-ai','from_version':4,'expected_version':5,'verify_jwt':False,'source_sha256':hashes,'prior_source_sha256':'4dcd7031ee37747fa5aa42a78616ffb682149edafd9a435efff6b009c7b9da14'}
task={'remaining_certification':{'project':proof['project'],'approved_ai_worker_deploy':proof}}
head='a'*40
r={'schema':'contaos.ai-worker-deployment.v1','backend_head':head,'project':proof['project'],'function_slug':'queue-worker-ai','version':5,'prior_version':4,'verify_jwt':False,'status':'ACTIVE','readback_equal':True,'source_sha256':hashes,'prior_source_sha256':proof['prior_source_sha256'],'management_bundle_sha256':'b'*64,'active_ai_jobs_before':0,'active_ai_jobs_after':0}
assert validate_receipt(task,head,r)==r
assert runtime_route(task,'workflow_dispatch') and not runtime_route(task,'workflow_run')
assert not runtime_route(task,'pull_request') and runtime_route({},'workflow_run')
for key,value in [('backend_head','c'*40),('project','prod'),('function_slug','storage-sign-upload'),('version',4),('readback_equal',False),('active_ai_jobs_before',1),('active_ai_jobs_after',True),('verify_jwt',True),('management_bundle_sha256','invalid'),('source_sha256',{})]:
 bad=copy.deepcopy(r);bad[key]=value
 try:validate_receipt(task,head,bad)
 except (AssertionError,KeyError):pass
 else:raise AssertionError('Unsafe deployment receipt accepted '+key)
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});

test('actual routing holds automatic material runs until reviewed deployment receipt dispatch',()=>{
 const code=String.raw`import re,subprocess,tempfile,pathlib,os,json
source=pathlib.Path('.github/workflows/p0-crud-remaining-hml.yml').read_text()
start=source.index('      - name: Read-only exact task routing');end=source.index('  public-probe:',start)
section=source[start:end];script=section.split('        run: |\n',1)[1]
script='\n'.join(line[10:] if line.startswith('          ') else line for line in script.splitlines())
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
for event,patch,ok,applicable in [('workflow_run',{},True,False),('workflow_dispatch',{},True,True),('workflow_dispatch',{'REQUESTED_HEAD':'0'*40},False,False),('workflow_dispatch',{'RESTORE_RUN_ID':'bad'},False,False),('workflow_dispatch',{'DEPLOY_RECEIPT_COMMENT_ID':''},False,False),('workflow_dispatch',{'GITHUB_REF':'refs/heads/foreign'},False,False)]:
 with tempfile.TemporaryDirectory() as d:
  env={'PATH':os.environ['PATH'],'GITHUB_OUTPUT':d+'/out','GITHUB_SHA':head,'REQUESTED_HEAD':head,'GITHUB_EVENT_NAME':event,'GITHUB_REF':'refs/heads/main','RESTORE_RUN_ID':'11','DEPLOY_RECEIPT_COMMENT_ID':'22',**patch}
  r=subprocess.run(['bash','-e','-o','pipefail','-c',script],env=env,capture_output=True,text=True)
  assert (r.returncode==0)==ok,(event,patch,r.stderr)
  if ok:assert ('applicable='+str(applicable).lower()) in pathlib.Path(d+'/out').read_text()
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});
