import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync} from 'node:fs';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,chmodSync,rmSync,copyFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import vm from 'node:vm';
const root=resolve('.');

import {spawnSync} from 'node:child_process';
const browser='supabase/tests/p0_crud_global_browser.mjs';
test('browser protocol exists before any privileged run',async()=>{
  assert(existsSync(browser),'CRUD browser protocol missing');
  const m=await import('./p0_crud_global_browser.mjs');
  assert.deepEqual(m.browserEnvironment({PATH:'/bin',AUTH_ADMIN_KEY:'PRIVATE_CANARY',DATABASE_URL:'PRIVATE_CANARY',GH_TOKEN:'PRIVATE_CANARY',UNEXPECTED_SECRET:'PRIVATE_CANARY'}),{PATH:'/bin'});
  assert.deepEqual(m.publicRecord({name:'ORG_CREATE',pass:true,http:200,password:'PRIVATE_CANARY',data:'PRIVATE_CANARY'}),{name:'ORG_CREATE',pass:true,http:200});
  assert.throws(()=>m.publicRecord({name:'secret@example.invalid',pass:true}));
  assert.throws(()=>m.publicRecord({name:'ORG_CREATE',pass:'true'}));
});
test('Python recovery and cleanup self-test runs without database or admin credential',()=>{
  assert(existsSync('supabase/tests/p0_crud_global_hml.py'),'CRUD fixture protocol missing');
  const r=spawnSync('python3',['supabase/tests/p0_crud_global_hml.py','--self-test'],{env:{PATH:process.env.PATH},encoding:'utf8'});
  assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/CRUD_GLOBAL_PROTOCOL_PASS/);assert(!r.stdout.includes('PRIVATE_CANARY'));
});

const cases=[{file:"p0-crud-global-browser-hml.yml",target:"private-browser",task:"P0-CRUD-GLOBAL-HML-20261107",phase:"BUILD_PROVA_PRIVADA_CRUD_GLOBAL"}];
const workflow=c=>readFileSync(join(root,'.github/workflows',c.file),'utf8');
function job(source,name){return source.match(new RegExp('^  '+name+':\\n([\\s\\S]*?)(?=^  [a-z][a-z-]*:|$(?![\\s\\S]))','m'))?.[1]||'';}
function runs(section){return [...section.matchAll(/^        run: \|\n((?:^          .*\n|^\n)+)/gm)].map(m=>m[1].split('\n').map(l=>l.startsWith('          ')?l.slice(10):l).join('\n'));}
function enabled(section,context){const expr=section.match(/^    if: (.+)$/m)?.[1];assert(expr,'job needs an explicit condition');return vm.runInNewContext(expr,context,{timeout:100})===true;}
function event(overrides={}){return {github:{event_name:'workflow_run',repository:'contaos999999/develop',event:{workflow_run:{conclusion:'success',event:'push',head_branch:'main',head_repository:{full_name:'contaos999999/develop'},...overrides}}}};}
function fixture(fn){const dir=mkdtempSync(join(tmpdir(),'contaos-routing-'));try{mkdirSync(join(dir,'docs/tasks'),{recursive:true});mkdirSync(join(dir,'bin'));return fn(dir);}finally{rmSync(dir,{recursive:true,force:true});}}
function taskfile(dir,t){writeFileSync(join(dir,'docs/tasks/active-task.json'),JSON.stringify(t));}
function run(script,dir,extra={}){return spawnSync('bash',['-e','-o','pipefail','-c',script],{cwd:dir,env:{PATH:join(dir,'bin')+':'+process.env.PATH,GITHUB_OUTPUT:join(dir,'output'),RUNNER_TEMP:dir,...extra},encoding:'utf8',timeout:10000});}
for(const c of cases){
  test(c.file+': routing occurs before privileged jobs',()=>{
    const scope=job(workflow(c),'scope');assert(scope,'read-only scope job is required');assert.match(scope,/contents: read/);assert.doesNotMatch(scope,/secrets\.|GH_TOKEN|actions: write|environment:/);
    const target=job(workflow(c),c.target);assert.match(target,/^    needs: scope$/m);
    for(const applicable of ['false','true'])assert.equal(enabled(target,{needs:{scope:{result:'success',outputs:{applicable}}}}),applicable==='true');
    assert.equal(enabled(target,{needs:{scope:{result:'failure',outputs:{applicable:'true'}}}}),false);
  });
  test(c.file+': rejects PR, foreign source, failed restore and non-main before checkout',()=>{
    const scope=job(workflow(c),'scope');assert.equal(enabled(scope,event()),true);
    for(const override of [{event:'pull_request'},{head_repository:{full_name:'outsider/fork'}},{conclusion:'failure'},{head_branch:'feature'}])assert.equal(enabled(scope,event(override)),false);
    const pr=event();pr.github.event_name='pull_request';assert.equal(enabled(scope,pr),false);
  });
  test(c.file+': execute real selection shell for exact task and phase',()=>fixture(dir=>{
    const [script]=runs(job(workflow(c),'scope'));assert(script,'selection script is required');
    for(const [task,phase,want] of [[c.task,c.phase,'true'],['UNRELATED',c.phase,'false'],[c.task,'PLAN_ROTEAMENTO_WORKFLOW_HML','false'],[c.task,'GATE_PROVA_PRIVADA_VALIDADO','false']]){
      taskfile(dir,{id:task,phase});writeFileSync(join(dir,'output'),'');const r=run(script,dir);assert.equal(r.status,0,r.stderr);assert.match(readFileSync(join(dir,'output'),'utf8'),new RegExp('^applicable='+want+'$','m'));
    }
    taskfile(dir,{id:c.task});writeFileSync(join(dir,'output'),'');assert.notEqual(run(script,dir).status,0,'malformed manifest must fail rather than skip');
    assert.doesNotMatch(readFileSync(join(dir,'output'),'utf8'),/applicable=true/);
  }));
  test(c.file+': missing required CI still fails in the real material gate',()=>fixture(dir=>{
    const sha='a'.repeat(40);taskfile(dir,{id:c.task,phase:c.phase,database_changes_allowed:true,allowed_paths:c.migration?['supabase/migrations/'+c.migration]:[],crud_global_proof:{frontend_head:'b'.repeat(40)}});
    if(c.migration){mkdirSync(join(dir,'supabase/migrations'),{recursive:true});copyFileSync(join(root,'supabase/migrations',c.migration),join(dir,'supabase/migrations',c.migration));}
    const gh=join(dir,'bin/gh');writeFileSync(gh,`#!/usr/bin/env python3\nimport sys,os,json\nif any('/commits/main' in a for a in sys.argv):\n print(os.environ['TESTED_HEAD'] if '--jq' in sys.argv else json.dumps({'sha':os.environ['TESTED_HEAD']}))\nelse: print(open(os.environ['CHECKS_FIXTURE']).read())\n`);chmodSync(gh,0o700);
    const [gate]=runs(job(workflow(c),c.target));assert(gate);
    for(const missing of ['guard','reconstruir-banco-do-zero','prova-backup-dados-sinteticos-duas-instancias']){
      writeFileSync(join(dir,'checks-fixture.json'),JSON.stringify({check_runs:['guard','reconstruir-banco-do-zero','prova-backup-dados-sinteticos-duas-instancias'].filter(n=>n!==missing).map(name=>({name,head_sha:sha,conclusion:'success'}))}));
      const r=run(gate,dir,{TESTED_HEAD:sha,GH_REPO:'contaos999999/develop',CHECKS_FIXTURE:join(dir,'checks-fixture.json')});assert.notEqual(r.status,0,'missing '+missing+' cannot pass');assert.match(r.stderr,new RegExp(missing),'failure must come from required CI, not fixture setup');
    }
  }));
}
test('deploy dispatch and independent quarantine remain guarded',()=>{
  for(const c of cases){const s=workflow(c);if(c.target==='canonical-deploy'){assert.match(s,/expected_source_sha="\$TESTED_HEAD"/);assert.match(s,/expected_migration_sha256=/);assert.match(job(s,'real-jwt'),/needs: canonical-deploy/);}
    assert.match(s,/Retry own fixture quarantine independently|Independent own fixture quarantine retry/);assert.match(s,/if: always\(\)/);assert.match(s,/--cleanup/);
  }
});

test('RPC receipt rejects HTTP success with missing identity or unchanged values',async()=>{
 const {validateReceipt}=await import('./p0_crud_global_browser.mjs');
 assert.equal(typeof validateReceipt,'function');
 const request={p_request_id:'11111111-1111-4111-8111-111111111111',p_alteracoes:{nome_fantasia:'Own edit'}};
 const data={request_id:request.p_request_id,evento_id:'22222222-2222-4222-8222-222222222222',registro:{nome_fantasia:'Own edit'}};
 assert.doesNotThrow(()=>validateReceipt('atualizar_organizacao_v1',request,data));
 assert.throws(()=>validateReceipt('atualizar_organizacao_v1',request,{...data,registro:{nome_fantasia:'Old'}}));
 assert.throws(()=>validateReceipt('atualizar_organizacao_v1',request,{...data,request_id:'wrong'}));
 assert.throws(()=>validateReceipt('executar_comando_lista_v1',request,{...data,lista:null}));
});

test('item receipt keeps item description separate from list header description',async()=>{
 const {validateReceipt}=await import('./p0_crud_global_browser.mjs');
 const id='11111111-1111-4111-8111-111111111111';
 const request={p_request_id:id,p_id_lista:id,p_versao_esperada:2,p_acao:'salvar_item',p_payload:{codigo:'OWN1',descricao:'Own optional item'}};
 const data={request_id:id,evento_id:id,acao:'salvar_item',lista:{id,versao_registro:3,descricao:'Own initial list description'}};
 assert.doesNotThrow(()=>validateReceipt('executar_comando_lista_v1',request,data));
});

test('transient read failure blocks transport only and always restores it',async()=>{
 const {withReadTransportFailure}=await import('./p0_crud_global_browser.mjs');
 assert.equal(typeof withReadTransportFailure,'function');const calls=[];
 const session={send:async(method,args)=>calls.push([method,args]),detach:async()=>calls.push(['DETACH'])};
 await assert.rejects(()=>withReadTransportFailure(session,async()=>{throw Error('assertion');}));
 assert.deepEqual(calls,[['Network.enable',undefined],['Network.setBlockedURLs',{urls:['*gklhhhyosgasnyoxlrui.supabase.co/rest/v1/rpc/obter_lista_operacional_v1*']}],['Network.setBlockedURLs',{urls:[]}],['DETACH']]);
});

test('new open version clears the prior closed version end date',async()=>{
 const {fillNextVersionDates}=await import('./p0_crud_global_browser.mjs');
 assert.equal(typeof fillNextVersionDates,'function');
 const fields={'Início da vigência':'2026-01-01','Fim da vigência':'2026-06-30'};
 const page={getByLabel:name=>({fill:async value=>{fields[name]=value;}})};
 await fillNextVersionDates(page,'2026-07-01');
 assert.deepEqual(fields,{'Início da vigência':'2026-07-01','Fim da vigência':''});
});


test('failure diagnostics expose only known UI flags and bounded read status',async()=>{
 const {sanitizeUiDiagnostic}=await import('./p0_crud_global_browser.mjs');
 assert.equal(typeof sanitizeUiDiagnostic,'function');
 assert.deepEqual(sanitizeUiDiagnostic({manage_list:true,change_state:false,loading:true,denied:false,inconsistent:true,transient:false,pending:false,read_http:200,secret:'PRIVATE_CANARY',text:'PRIVATE_CANARY'}),{manage_list:true,change_state:false,loading:true,denied:false,inconsistent:true,transient:false,pending:false,read_http:200});
 assert.throws(()=>sanitizeUiDiagnostic({manage_list:'PRIVATE_CANARY'}));
 assert.throws(()=>sanitizeUiDiagnostic({read_http:'PRIVATE_CANARY'}));
});

test('list state selector rejects unsupported state before touching the page',async()=>{
 const {selectListState}=await import('./p0_crud_global_browser.mjs');
 assert.equal(typeof selectListState,'function');
 await assert.rejects(()=>selectListState(new Proxy({}, {get(){throw Error('Unexpected DOM access');}}),'encerrada'),{name:'AssertionError'});
});

// Public audit reports must never contain backend payload columns or other tenants.
test('audit read validator rejects broad projection, wrong tenant and unbounded pages',async()=>{
 const {validateAuditRead}=await import('./p0_crud_global_browser.mjs');
 assert.equal(typeof validateAuditRead,'function');
 const org='11111111-1111-4111-8111-111111111111';
 const fields='id,criado_em,evento,entidade,origem,id_usuario,id_entidade,correlation_id';
 const url='https://gklhhhyosgasnyoxlrui.supabase.co/rest/v1/eventos_auditoria?select='+fields+'&id_organizacao=eq.'+org+'&offset=0&limit=25';
 const row=Object.fromEntries(fields.split(',').map(k=>[k,null]));
 assert.doesNotThrow(()=>validateAuditRead(url,[row],org));
 assert.doesNotThrow(()=>validateAuditRead(url,[row],org,206));
 assert.throws(()=>validateAuditRead(url,[row],org,400));
 assert.throws(()=>validateAuditRead(url,[row],org,201));
 assert.throws(()=>validateAuditRead(url,[{...row,metadados:'PRIVATE_CANARY'}],org));
 assert.throws(()=>validateAuditRead(url.replace('select='+fields,'select=*'),[row],org));
 assert.throws(()=>validateAuditRead(url, [row], '22222222-2222-4222-8222-222222222222'));
 assert.throws(()=>validateAuditRead(url.replace('limit=25','limit=500'),[row],org));
 assert.throws(()=>validateAuditRead(url,Array(26).fill(row),org));
 assert.throws(()=>validateAuditRead(url.replace('offset=0','offset=-1'),[row],org));
});

test('visual readiness rejects busy, disabled, stale and missing list panels',async()=>{
 const {listUiIsSettled}=await import('./p0_crud_global_browser.mjs');assert.equal(typeof listUiIsSettled,'function');
 const prior=globalThis.document;
 const state={exists:true,text:'Own recovered',disabled:false};
 globalThis.document={querySelector:()=>state.exists?{get textContent(){return state.text;},querySelectorAll:()=>[{textContent:'Editar lista',get disabled(){return state.disabled;}}]}:null};
 try{
  assert.equal(listUiIsSettled('Own recovered'),true);
  state.text='Old list';assert.equal(listUiIsSettled('Own recovered'),false);
  state.text='Own recovered Enviando operação…';assert.equal(listUiIsSettled('Own recovered'),false);
  state.text='Own recovered';state.disabled=true;assert.equal(listUiIsSettled('Own recovered'),false);
  state.disabled=false;state.exists=false;assert.equal(listUiIsSettled('Own recovered'),false);
 }finally{if(prior===undefined)delete globalThis.document;else globalThis.document=prior;}
});
test('accessibility summary drops raw HTML, selectors and unknown data',async()=>{
 const {summarizeAccessibility}=await import('./p0_crud_global_browser.mjs');assert.equal(typeof summarizeAccessibility,'function');
 const data={testEngine:{version:'4.14.0'},violations:[{id:'color-contrast',impact:'serious',nodes:[{html:'PRIVATE_CANARY',target:['PRIVATE_CANARY']}]}],incomplete:[{id:'color-contrast',nodes:[{}]}],url:'PRIVATE_CANARY'};
 const out=summarizeAccessibility(data);assert.deepEqual(out,{version:'4.14.0',violations:[{id:'color-contrast',impact:'serious',nodes:1}],incomplete:[{id:'color-contrast',nodes:1}]});assert(!JSON.stringify(out).includes('PRIVATE_CANARY'));
});

test('audit RLS denial cannot pass on an expired session or backend outage',async()=>{
 const {validateAuditDenied}=await import('./p0_crud_global_browser.mjs');
 assert.equal(typeof validateAuditDenied,'function');
 assert.doesNotThrow(()=>validateAuditDenied({status:200,count:0,code:null}));
 assert.doesNotThrow(()=>validateAuditDenied({status:403,count:null,code:'42501'}));
 for(const result of [{status:401,count:null,code:'PGRST301'},{status:500,count:null,code:'XX000'},{status:200,count:1,code:null}])assert.throws(()=>validateAuditDenied(result));
});

test('document quarantine rejects foreign scope and queues and preserves completed or running work',()=>{
 const code=`import runpy
m=runpy.run_path('supabase/tests/p0_crud_global_hml.py')
fn=m.get('document_quarantine_actions');assert callable(fn),'Missing document quarantine planner'
a='11111111-1111-4111-8111-111111111111';b='22222222-2222-4222-8222-222222222222';c='33333333-3333-4333-8333-333333333333';j='44444444-4444-4444-8444-444444444444'
row=dict(id=j,id_organizacao=a,id_contrato=c,fila='documents',status='enfileirado',message_id=17)
assert fn([row],{a},{c:a})=={'cancel':[j],'active':[]}
for status in ['concluido','cancelado']:
 assert fn([dict(row,status=status)],{a},{c:a})=={'cancel':[],'active':[]}
assert fn([dict(row,status='processando')],{a},{c:a})=={'cancel':[],'active':[j]}
for bad in [dict(row,id_organizacao=b),dict(row,fila='reports'),dict(row,id_contrato=b),dict(row,message_id='PRIVATE_CANARY'),dict(row,status='unknown')]:
 try:fn([bad],{a},{c:a})
 except (AssertionError,ValueError):pass
 else:raise AssertionError('Unsafe job accepted')
print('DOCUMENT_QUARANTINE_PLANNER_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});
 assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/DOCUMENT_QUARANTINE_PLANNER_PASS/);
});

test('document quarantine recovers missing receipts and refuses running or newly spawned work',()=>{
 const code=`import runpy,json
m=runpy.run_path('supabase/tests/p0_crud_global_hml.py');R=m['Runner']
assert callable(getattr(R,'quarantine_document_jobs',None)),'Missing own document quarantine'
a='11111111-1111-4111-8111-111111111111';c='33333333-3333-4333-8333-333333333333';j='44444444-4444-4444-8444-444444444444';done='55555555-5555-4555-8555-555555555555'
f={'scope':'P0-CRUD-GLOBAL-HML','nonce':'a'*32,'prefix':'0000 CRUDG '+'a'*32+' '}
base=dict(id_organizacao=a,id_contrato=c,fila='documents',message_id=17)
def run(active=False,processing=False,orphan=False):
 r=object.__new__(R);r.report={};calls=[];cancelled=False
 def sql(source,fetch=False):
  nonlocal cancelled
  calls.append(source)
  if 'DOCUMENT_OWN_SCOPE' in source:
   assert f['prefix'] in source
   return json.dumps({'orgs':[a],'contracts':[{'id':c,'id_organizacao':a}]})
  if 'DOCUMENT_ACTIVE_PROCESSINGS' in source:return '1' if processing else '0'
  if 'DOCUMENT_ACTIVE_QUEUE_MESSAGES' in source:return '1' if orphan else '0'
  if 'DOCUMENT_OWN_JOBS' in source:
   rows=[dict(base,id=done,status='concluido'),dict(base,id=j,status='cancelado' if cancelled else 'enfileirado')]
   if active and cancelled:rows.append(dict(base,id='66666666-6666-4666-8666-666666666666',status='processando'))
   return json.dumps(rows)
  assert 'DOCUMENT_QUARANTINE_PENDING' in source and j in source
  assert done not in source and 'pgmq.delete' in source and 'for update' in source.lower()
  assert 'update public.arquivos' not in source.lower() and 'delete from public.' not in source.lower()
  cancelled=True
 r.sql=sql
 if active or processing or orphan:
  try:r.quarantine_document_jobs(f,max_wait_seconds=0)
  except RuntimeError:pass
  else:raise AssertionError('Running child was called clean')
 else:
  result=r.quarantine_document_jobs(f,max_wait_seconds=0)
  assert result['active_jobs']==0 and result['cancelled_jobs']==1
 assert cancelled
run();run(True);run(processing=True);run(orphan=True)
print('DOCUMENT_QUARANTINE_RECOVERY_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});
 assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/DOCUMENT_QUARANTINE_RECOVERY_PASS/);
});

test('document SQL proof is restricted to the disposable local restore database',()=>{
 const code=`import runpy
m=runpy.run_path('supabase/tests/p0_crud_global_hml.py');fn=m.get('validate_local_restore_url')
assert callable(fn),'Missing local restore database guard'
fn('postgresql://postgres:postgres@127.0.0.1:54322/postgres')
for raw in ['postgresql://postgres:postgres@db.example.invalid:54322/postgres','postgresql://postgres:postgres@127.0.0.1:5432/postgres','postgresql://postgres:postgres@127.0.0.1:54322/other']:
 try:fn(raw)
 except AssertionError:pass
 else:raise AssertionError('Non-local proof target accepted')
print('LOCAL_RESTORE_GUARD_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/LOCAL_RESTORE_GUARD_PASS/);
});

test('cleanup bans and revokes before document quarantine and keeps pending state on active work',()=>{
 const code=`import runpy,json,tempfile
from pathlib import Path
R=runpy.run_path('supabase/tests/p0_crud_global_hml.py')['Runner']
for pending in [False,True]:
 r=object.__new__(R);r.report={};calls=[]
 with tempfile.TemporaryDirectory() as d:
  r.root=Path(d);f={'batch':'DOCUMENTOS','scope':'P0-CRUD-GLOBAL-HML','nonce':'a'*32,'prefix':'0000 CRUDG '+'a'*32+' ','users':[{'intent_id':'intent','creation_state':'created'}]};r.save('fixture.json',f)
  def sql(source,fetch=False):
   calls.append(source)
   if source.startswith('select id from auth.users'):return '11111111-1111-4111-8111-111111111111'
   if source.startswith('select id from public.organizacoes'):return '22222222-2222-4222-8222-222222222222'
   return 't' if fetch else None
  def quarantine(f):
   calls.append('DOCUMENTS')
   assert 'BAN' in calls and any('delete from auth.sessions' in x for x in calls)
   assert not any("set situacao='inativa'" in x for x in calls)
   if pending:raise RuntimeError('worker active')
   return {'active_jobs':0,'cancelled_jobs':1}
  r.recover_document_uploads=lambda f:{};r.sql=sql;r.request=lambda *a,**k:(calls.append('BAN') or (200,{}));r.quarantine_document_jobs=quarantine
  try:r.cleanup()
  except RuntimeError:assert pending
  else:assert not pending
  assert 'DOCUMENTS' in calls
  result=json.loads((r.root/'cleanup.json').read_text())
  assert result['state']==('QUARENTENA_PENDENTE' if pending else 'QUARENTENA_VERIFICADA')
  assert not pending or r.report['state']=='CLEANUP_FAILED'
print('DOCUMENT_CLEANUP_INTEGRATION_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/DOCUMENT_CLEANUP_INTEGRATION_PASS/);
});

test('document fixtures, receipts, integrity, worker state and denials fail closed',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');
 assert.equal(typeof m.documentFixture,'function');assert.equal(typeof m.validateDocumentReceipt,'function');
 for(const format of ['txt','pdf']){
  const a=m.documentFixture('a'.repeat(32),format,1),b=m.documentFixture('a'.repeat(32),format,2);
  assert(a.bytes.length>0&&a.bytes.length<10000);assert.notEqual(a.sha256,b.sha256);
  assert.equal(a.size,a.bytes.length);assert.equal(format==='pdf'?a.bytes.subarray(0,5).toString():a.mime,format==='pdf'?'%PDF-':'text/plain');
 }
 const id='11111111-1111-4111-8111-111111111111';const expected={org:id,contract:id,file:id,document:id,version:2,sha256:'a'.repeat(64),size:42};
 const receipt={id_documento:id,id_arquivo:id,id_versao:id,numero_versao:2};
 m.validateDocumentReceipt(receipt,expected);assert.throws(()=>m.validateDocumentReceipt({...receipt,numero_versao:1},expected));assert.throws(()=>m.validateDocumentReceipt({...receipt,id_arquivo:'bad'},expected));
 const progress={org:id,contract:id,file:id,sha256:expected.sha256,size:42,security:'aprovado',processing:'concluido',job:'concluido',pages:1,fragments:1};
 m.validateDocumentProgress(progress,expected);for(const change of [{security:'pendente'},{processing:'processando'},{job:'falhou'},{pages:0},{sha256:'b'.repeat(64)},{org:'foreign'},{size:41}])assert.throws(()=>m.validateDocumentProgress({...progress,...change},expected));
 m.validateDocumentDenial({status:403,code:'AUTH_ACESSO_NEGADO'},'upload');m.validateDocumentDenial({status:404,code:'REGISTRO_NAO_ENCONTRADO'},'download');
 for(const status of [0,200,401,500])assert.throws(()=>m.validateDocumentDenial({status,code:'AUTH_ACESSO_NEGADO'},'upload'));
});

test('document initialization and receipt recovery use private nonce scope without granting upload during gate',()=>{
 const code=`import runpy,json,tempfile,os
from pathlib import Path
m=runpy.run_path('supabase/tests/p0_crud_global_hml.py');R=m['Runner'];assert callable(getattr(R,'recover_document_uploads',None))
with tempfile.TemporaryDirectory() as d:
 env={'RUNNER_TEMP':d,'CONTAOS_TEST_PRIVATE_DIR':d+'/own','DATABASE_URL':'postgresql://postgres.gklhhhyosgasnyoxlrui:canary@aws-0.pooler.supabase.com/postgres','AUTH_ADMIN_KEY':'PRIVATE_CANARY','TESTED_HEAD':'a'*40,'FRONTEND_HEAD':'b'*40}
 Path(d+'/docs/tasks').mkdir(parents=True);Path(d+'/docs/tasks/active-task.json').write_text(json.dumps({'phase':'GATE_PROVA_PRIVADA_DOCUMENTOS','crud_global_proof':{'batch':'DOCUMENTOS'}}));os.chdir(d)
 r=R(env);assert r.batch=='DOCUMENTOS';assert not r.material_enabled
 try:r.prepare()
 except AssertionError:pass
 else:raise AssertionError('GATE cannot create material fixtures')
 calls=[]
 f={'batch':'DOCUMENTOS','scope':'P0-CRUD-GLOBAL-HML','nonce':'a'*32,'prefix':'0000 CRUDG '+'a'*32+' ','org':'11111111-1111-4111-8111-111111111111','contract':'22222222-2222-4222-8222-222222222222','users':[]}
 def sql(source,fetch=False):
  calls.append(source);assert f['nonce'] in source and f['org'] in source and f['prefix'] in source and 'own_contract' in source
  if 'DOCUMENT_RECOVER_OBJECTS' in source:
   assert "bucket_id='contaos-documentos'" in source and '/uploads/' in source;return '[]'
  assert 'DOCUMENT_RECOVER_FILES' in source and f['contract'] in source;return '[]'
 r.sql=sql;r.recover_document_uploads(f);assert len(calls)==2
 assert json.loads((r.root/'fixture.json').read_text())['recovered_uploads']==[]
 assert 'PRIVATE_CANARY' not in (r.root/'report.json').read_text()
print('DOCUMENT_PRIVATE_RECOVERY_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/DOCUMENT_PRIVATE_RECOVERY_PASS/);
});

test('main finally still quarantines identities when browser fails and own worker remains active',()=>{
 const code=`import runpy,json,tempfile,sys
from pathlib import Path
from types import SimpleNamespace
m=runpy.run_path('supabase/tests/p0_crud_global_hml.py');R=m['Runner'];main=m['main'];calls=[]
with tempfile.TemporaryDirectory() as d:
 r=object.__new__(R);r.root=Path(d);r.batch='DOCUMENTOS';r.report={'assertions':[]};r.prepare=lambda:None
 r.save('fixture.json',{'batch':'DOCUMENTOS','scope':'P0-CRUD-GLOBAL-HML','nonce':'a'*32,'prefix':'0000 CRUDG '+'a'*32+' ','users':[{'intent_id':'intent','creation_state':'created'}]})
 def sql(source,fetch=False):
  calls.append(source)
  if source.startswith('select id from auth.users'):return '11111111-1111-4111-8111-111111111111'
  if source.startswith('select id from public.organizacoes'):return '22222222-2222-4222-8222-222222222222'
  return 't' if fetch else None
 r.sql=sql;r.request=lambda *a,**k:(calls.append('BAN') or (200,{}));r.recover_document_uploads=lambda f:{}
 def quarantine(f):calls.append('QUARANTINE');raise RuntimeError('pending own worker')
 r.quarantine_document_jobs=quarantine
 def watcher_failure():raise RuntimeError('Own controller failed')
 r.handle_document_control=watcher_failure
 process=SimpleNamespace(returncode=None,poll=lambda:None,terminate=lambda:calls.append('TERMINATE_BROWSER'),wait=lambda timeout:calls.append('WAIT_BROWSER'))
 g=main.__globals__;g['Runner']=lambda env:r;g['subprocess']=SimpleNamespace(Popen=lambda *a,**k:process,DEVNULL=-3);sys.argv=['harness']
 assert main()==1
 assert 'TERMINATE_BROWSER' in calls and calls.index('TERMINATE_BROWSER')<calls.index('BAN')
 assert 'BAN' in calls and any('delete from auth.sessions' in x for x in calls) and 'QUARANTINE' in calls
 assert r.report['state']=='CLEANUP_FAILED' and r.report['cleanup']['state']=='QUARENTENA_PENDENTE'
 assert not any("set situacao='inativa'" in x for x in calls)
print('DOCUMENT_FINALLY_FAIL_CLOSED_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/DOCUMENT_FINALLY_FAIL_CLOSED_PASS/);
});

test('own administrator revocation control rejects foreign nonce, user, action and replay',()=>{
 const code=`import runpy,tempfile,json
from pathlib import Path
m=runpy.run_path('supabase/tests/p0_crud_global_hml.py');fn=m.get('validate_document_control');assert callable(fn),'Missing closed revocation control'
u='11111111-1111-4111-8111-111111111111';o='22222222-2222-4222-8222-222222222222'
f={'batch':'DOCUMENTOS','scope':'P0-CRUD-GLOBAL-HML','nonce':'a'*32,'prefix':'0000 CRUDG '+'a'*32+' ','org':o,'users':[{'profile':'administrador','id':u,'intent_id':u}]}
r={'action':'REVOKE_OWN_ADMIN','nonce':f['nonce'],'org':o,'user':u}
assert fn(r,f)==u
for bad in [dict(r,nonce='b'*32),dict(r,user=o),dict(r,org=u),dict(r,action='SQL'),dict(r,sql='select 1')]:
 try:fn(bad,f)
 except AssertionError:pass
 else:raise AssertionError('Unsafe control accepted')
f['permission_control']={'state':'INTENT'}
try:fn(r,f)
except AssertionError:pass
else:raise AssertionError('Control replay accepted')
print('DOCUMENT_CLOSED_CONTROL_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/DOCUMENT_CLOSED_CONTROL_PASS/);
});

test('document completion retains whole domain as unverified and refuses expired-session revocation proof',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');assert.equal(typeof m.documentCoverage,'function');
 assert.deepEqual(m.documentCoverage(),{completed_scopes:['DOCUMENTOS_UPLOAD_VERSION_WORKER_UI_EDGE_AND_SIGNED_GET_PARTIAL'],remaining_domains:['documentos_contrato','documento_detalhe'],global_complete:false});
 for(const status of [401,500]){assert.throws(()=>m.validateDocumentDenial({status,code:'42501'},'mutation'));assert.throws(()=>m.validateDocumentDenial({status,code:'REGISTRO_NAO_ENCONTRADO'},'download'));}
});

test('revocation controller persists intent before its single fixed own-binding SQL and refuses replay',()=>{
 const code=`import runpy,tempfile,json
from pathlib import Path
m=runpy.run_path('supabase/tests/p0_crud_global_hml.py');R=m['Runner'];calls=[]
u='11111111-1111-4111-8111-111111111111';o='22222222-2222-4222-8222-222222222222'
with tempfile.TemporaryDirectory() as d:
 r=object.__new__(R);r.root=Path(d);r.batch='DOCUMENTOS';r.report={}
 f={'batch':'DOCUMENTOS','scope':'P0-CRUD-GLOBAL-HML','nonce':'a'*32,'prefix':'0000 CRUDG '+'a'*32+' ','org':o,'users':[{'profile':'administrador','id':u,'intent_id':u,'creation_state':'created'}]};r.save('fixture.json',f)
 request={'action':'REVOKE_OWN_ADMIN','nonce':f['nonce'],'org':o,'user':u};p=r.root/'document-control-request.json';p.write_text(json.dumps(request))
 def sql(source,fetch=False):
  calls.append(source);assert json.loads((r.root/'fixture.json').read_text())['permission_control']['state']=='INTENT'
  for marker in ['DOCUMENT_REVOKE_OWN_ADMIN',u,o,f['prefix'],'fixture_request_id','crud_nonce',"v.perfil='administrador'","set ativo=false"]:assert marker in source
  for forbidden in ['delete from auth.sessions','update auth.users','alter table','create function']:assert forbidden not in source
  return '1'
 r.sql=sql;r.handle_document_control();assert len(calls)==1 and not p.exists()
 ack=json.loads((r.root/'document-control-response.json').read_text());assert ack=={'action':'REVOKE_OWN_ADMIN','nonce':f['nonce'],'state':'REVOKED'}
 p.write_text(json.dumps(request))
 try:r.handle_document_control()
 except AssertionError:pass
 else:raise AssertionError('Replayed fixed control ran twice')
 assert len(calls)==1
print('DOCUMENT_CONTROL_INTENT_SQL_REPLAY_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/DOCUMENT_CONTROL_INTENT_SQL_REPLAY_PASS/);
});

test('document form failure reports the exact current action without attempting later fields',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');assert.equal(typeof m.fillDocumentUploadForm,'function');
 const stages=[],actions=[];const dialog={getByLabel:(name)=>({setInputFiles:async()=>actions.push('FILE'),fill:async()=>{actions.push(name);if(name.startsWith('Título de '))throw Error('synthetic label unavailable');}})};
 await assert.rejects(()=>m.fillDocumentUploadForm(dialog,{name:'synthetic.txt',mime:'text/plain',bytes:Buffer.from('own')},1,'Own title','a'.repeat(32),s=>stages.push(s)));
 assert.deepEqual(stages,['SELECT_FILE','FILL_TITLE']);assert.deepEqual(actions,['FILE','Título de synthetic.txt']);
});

test('document transfer wait identifies the missing receipt and validates each earlier HTTP before proceeding',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');assert.equal(typeof m.awaitDocumentTransfer,'function');
 const stages=[],checks=[];const missing=Promise.reject(Error('synthetic missing response'));missing.catch(()=>{});
 await assert.rejects(()=>m.awaitDocumentTransfer([Promise.resolve({ok:()=>true,status:()=>200}),missing],s=>stages.push(s),(name,pass,http)=>checks.push({name,pass,http})));
 assert.deepEqual(stages,['WAIT_SIGN_UPLOAD','WAIT_STORAGE_UPLOAD']);assert.deepEqual(checks,[{name:'DOCUMENT_TRANSFER_STAGE_0',pass:true,http:200}]);
});

test('document failure diagnostics allow only fixed flags and bounded endpoint counters/statuses',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');assert.equal(typeof m.sanitizeDocumentDiagnostic,'function');
 const flags=Object.fromEntries(['upload_button_present','upload_button_enabled','dialog_open','file_input_present','queue_present','title_input_present','form_alert','format_rejected','config_unavailable','upload_busy','upload_complete','config_loaded','txt_allowed','pdf_allowed'].map(k=>[k,false]));
 const network=Object.fromEntries(['config','sign','storage','confirm','register'].map(k=>[k,{requests:0,http:null,failed:false,raw:'PRIVATE_CANARY'}]));
 const value=m.sanitizeDocumentDiagnostic({...flags,network,html:'PRIVATE_CANARY',signed_url:'PRIVATE_CANARY'});assert(!JSON.stringify(value).includes('PRIVATE_CANARY'));assert.deepEqual(value.network.sign,{requests:0,http:null,failed:false});
 assert.throws(()=>m.sanitizeDocumentDiagnostic({...flags,network:{...network,sign:{requests:0,http:'PRIVATE_CANARY',failed:false}}}));assert.throws(()=>m.sanitizeDocumentDiagnostic({...flags,dialog_open:'PRIVATE_CANARY',network}));
});

// GATE138: the published smoke is additional evidence, never a pinned-code receipt.
test('published proof rejects redirects, foreign assets, oversized data and ambiguous client before login',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');assert.equal(typeof m.inspectPublishedBackend,'function');
 const origin='https://scope-and-approval-keeper.lovable.app';let credentials=0,calls=[];
 const response=(body,url=origin+'/login',status=200)=>({ok:status===200,status,url,headers:new Headers({'content-type':'text/html'}),body:new ReadableStream({start(c){c.enqueue(new TextEncoder().encode(body));c.close();}})});
 for(const html of ['<script type="module" src="https://foreign.invalid/x.js"></script>','<script type="module" src="/assets/x.js"></script>','x'.repeat(262145)]){
  calls=[];await assert.rejects(()=>m.runDocumentProvenances({proveBackend:()=>m.inspectPublishedBackend(async(url,options)=>{calls.push(url);assert.equal(options.redirect,'error');return response(html);},()=>{throw Error('ambiguous');}),published:async()=>{credentials++;},local:async()=>{credentials++;}}));assert.equal(credentials,0);assert(calls.every(x=>new URL(x).origin===origin));
 }
 await assert.rejects(()=>m.inspectPublishedBackend(async()=>response('', 'https://foreign.invalid/login'),()=>({verified:true})));assert.equal(credentials,0);
});

test('published then local share one deadline; published failure never enters local',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');assert.equal(typeof m.runDocumentProvenances,'function');
 const order=[];let deadline;
 await m.runDocumentProvenances({now:()=>100,proveBackend:async()=>order.push('proof'),published:async d=>{order.push('published');deadline=d;},local:async d=>{order.push('local');assert.equal(d,deadline);}});
 assert.deepEqual(order,['proof','published','local']);assert.equal(deadline,900100);
 let local=false;await assert.rejects(()=>m.runDocumentProvenances({proveBackend:async()=>{},published:async()=>{throw Error('worker');},local:async()=>{local=true;}}));assert.equal(local,false);
});

test('stale browser fixture cannot overwrite Python revocation or readiness state',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');assert.equal(typeof m.persistBrowserFixture,'function');
 const d=mkdtempSync(join(tmpdir(),'fixture-state-'));try{
  const p=join(d,'fixture.json'),f={nonce:'a'.repeat(32),uploads:[]};writeFileSync(p,JSON.stringify({...f,permission_control:{state:'REVOKED'},readiness_control:{sequence:1,state:'READY'}}));
  m.persistBrowserFixture(p,{...f,uploads:[{state:'INTENT'}]});const out=JSON.parse(readFileSync(p));assert.equal(out.permission_control.state,'REVOKED');assert.equal(out.readiness_control.sequence,1);assert.equal(out.uploads.length,1);
  assert.throws(()=>m.persistBrowserFixture(p,{...f,nonce:'b'.repeat(32)}));
 }finally{rmSync(d,{recursive:true,force:true});}
});

function pythonProtocol(code){const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);return r.stdout;}
const partitionSetup=`import runpy,json,tempfile,copy
from pathlib import Path
m=runpy.run_path('supabase/tests/p0_crud_global_hml.py')
nonce='a'*32;org='11111111-1111-4111-8111-111111111111';contract='22222222-2222-4222-8222-222222222222'
f=dict(batch='DOCUMENTOS',scope='P0-CRUD-GLOBAL-HML',nonce=nonce,prefix='0000 CRUDG '+nonce+' ',org=org,contract=contract,users=[],uploads=[])
for i,(source,fmt,version,doc) in enumerate([('PUBLISHED','txt',1,1),('LOCAL','txt',1,2),('LOCAL','txt',2,2),('LOCAL','pdf',1,3),('LOCAL','pdf',2,3)]):
 ident=lambda n:'00000000-0000-4000-8000-'+str(n).zfill(12)
 f['uploads'].append(dict(provenance=source,frontend_head=None if source=='PUBLISHED' else '164b10b44eaf5b553efcc7ab4e053b86c4d3b269',source_parity='NAO_VERIFICADA' if source=='PUBLISHED' else 'PINNED',intent_nonce=nonce+'-'+source.lower()+'-'+fmt+'-'+str(version),org=org,contract=contract,name='crudg-'+nonce+'-'+source.lower()+'-'+fmt+'-v'+str(version)+'.'+fmt,file=ident(i+10),document=ident(doc),id_version=ident(i+20),path=org+'/uploads/'+ident(i+30)+'/crudg-'+nonce+'-'+source.lower()+'-'+fmt+'-v'+str(version)+'.'+fmt,version=version,mime='text/plain' if fmt=='txt' else 'application/pdf',sha256=str(i)*64,size=42,state='PROCESSED',download_verified=True,download_proof_kind='UI_EDGE_AND_SIGNED_GET',popup_rendering='NAO_CERTIFICADO'))
f['recovered_uploads']=[{k:u[k] for k in ('file','document','id_version','path','version','sha256','size','name')} for u in f['uploads']]
f['recovered_objects']=[{'name':u['path']} for u in f['uploads']]
`;
test('five receipts require two disjoint provenance sets and exact recovered union',()=>{
 pythonProtocol(partitionSetup+`
fn=m.get('validate_document_partition');assert callable(fn),'Missing provenance partition validator'
assert fn(f)=={'published':1,'local':4,'files':5,'documents':3,'versions':5}
for change in ['drop','duplicate','cross','head','orphan','missing_object','ambiguous_download','popup_claim']:
 bad=copy.deepcopy(f)
 if change=='ambiguous_download':bad['uploads'][0].pop('download_proof_kind')
 if change=='popup_claim':bad['uploads'][0]['popup_rendering']='PASS'
 if change=='drop':bad['uploads'].pop()
 if change=='duplicate':bad['uploads'][4]['file']=bad['uploads'][0]['file']
 if change=='cross':bad['uploads'][1]['document']=bad['uploads'][0]['document']
 if change=='head':bad['uploads'][0]['frontend_head']='164b10b44eaf5b553efcc7ab4e053b86c4d3b269'
 if change=='orphan':bad['recovered_objects'].append({'name':'orphan'})
 if change=='missing_object':bad['recovered_objects'].pop()
 try:fn(bad)
 except (AssertionError,ValueError):pass
 else:raise AssertionError('Invalid partition accepted: '+change)
`);
});
test('readonly readiness validates nonce, owned IDs, fixed action and monotonic sequence',()=>{
 pythonProtocol(partitionSetup+`
fn=m.get('validate_readiness_control');assert callable(fn),'Missing readonly readiness control'
u=f['uploads'][0];request={k:u[k] for k in ('file','document','id_version','intent_nonce')};request.update(action='PUBLISHED_READINESS',nonce=nonce,sequence=1)
assert fn(request,f)==u
for change in [dict(nonce='b'*32),dict(file=contract),dict(document=contract),dict(id_version=contract),dict(action='SQL'),dict(sql='select 1'),dict(sequence=0)]:
 try:fn(dict(request,**change),f)
 except (AssertionError,ValueError):pass
 else:raise AssertionError('Unsafe readiness accepted')
f['readiness_control']={'sequence':1,'state':'READY'}
try:fn(request,f)
except AssertionError:pass
else:raise AssertionError('Readiness replay accepted')
`);
});
test('readonly watcher persists intent, issues only own SELECT, and returns closed flags',()=>{
 pythonProtocol(partitionSetup+`
R=m['Runner'];assert callable(getattr(R,'handle_document_readiness',None)),'Missing readonly watcher'
with tempfile.TemporaryDirectory() as d:
 r=object.__new__(R);r.root=Path(d);r.batch='DOCUMENTOS';r.report={};r.save('fixture.json',f);u=f['uploads'][0]
 request={k:u[k] for k in ('file','document','id_version','intent_nonce')};request.update(action='PUBLISHED_READINESS',nonce=nonce,sequence=1)
 p=r.root/'document-readiness-request.json';p.write_text(json.dumps(request));calls=[]
 def sql(source,fetch=False):
  calls.append(source);assert json.loads((r.root/'fixture.json').read_text())['readiness_control']['state']=='INTENT'
  assert source.lstrip().startswith('select ') and ';' not in source[:-1]
  for word in [' update ',' insert ',' delete ','pgmq.read','pgmq.pop','http']:assert word not in source.lower()
  for value in [nonce,org,contract,u['file'],u['document'],u['id_version']]:assert value in source
  return json.dumps({'owned':True,'ready':True,'failed':False})
 r.sql=sql;r.handle_document_readiness();assert len(calls)==1 and not p.exists()
 ack=json.loads((r.root/'document-readiness-response.json').read_text());assert ack==dict(action='PUBLISHED_READINESS',nonce=nonce,sequence=1,state='READY')
 assert 'PRIVATE_CANARY' not in json.dumps(r.report)
`);
});
test('recovery restores both receipt provenances from durable intents, never assigns the published head',()=>{
 pythonProtocol(partitionSetup+`
fn=m.get('reconcile_document_receipts');assert callable(fn),'Missing partition-aware recovery'
for index in [0,3]:
 bad=copy.deepcopy(f);expected=bad['uploads'][index].copy()
 for key in ['file','document','id_version','path']:bad['uploads'][index].pop(key)
 bad['uploads'][index]['state']='INTENT';fn(bad)
 for key in ['file','document','id_version','path','provenance','frontend_head']:assert bad['uploads'][index][key]==expected[key]
 assert bad['uploads'][index]['state']=='RECOVERED' # recovery is cleanup evidence, never fake UI/worker success
bad=copy.deepcopy(f);bad['recovered_uploads'][0]['name']='foreign';
try:fn(bad)
except AssertionError:pass
else:raise AssertionError('Foreign recovery accepted')
`);
});

test('public artifact traversal is bounded same-origin and reports only hashes and closed metadata',async()=>{
 const m=await import('./p0_crud_global_browser.mjs'),calls=[],origin=m.PUBLISHED_ORIGIN;
 const bodies=new Map([[origin+'/login','<script type="module" src="/assets/current.js"></script>'],[origin+'/assets/current.js','PRIVATE_CANARY_TOKEN_URL_PATH_FILENAME_BYTES_HTML_ERROR']]);
 const out=await m.inspectPublishedBackend(async(url,options)=>{calls.push(url);assert.equal(options.credentials,'omit');assert.equal(options.redirect,'error');return {status:200,ok:true,url,body:new ReadableStream({start(c){c.enqueue(new TextEncoder().encode(bodies.get(url)));c.close();}})};},{version:'5.9.3',htmlEntries:()=>[{attributes:[['type','module'],['src','/assets/current.js']],source:''}],imports:()=>[],prove:(modules,entries)=>{assert.equal(modules.size,1);assert.equal(entries[0],origin+'/assets/current.js');return {verified:true,token:'PRIVATE_CANARY'};}});
 assert.equal(out.state,'HML_CONFIG_CONFIRMED');assert.equal(out.frontend_head,null);assert.equal(out.source_parity,'NAO_VERIFICADA');assert.equal(out.module_count,1);assert.match(out.asset_sha256[0],/^[a-f0-9]{64}$/);assert.equal(calls.length,2);
 for(const forbidden of ['PRIVATE_CANARY','current.js','https://','<script'])assert(!JSON.stringify(out).includes(forbidden));
});
test('published navigation and backend fence rejects foreign projects and non-approved redirects',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');
 assert(m.publishedRequestAllowed(m.PUBLISHED_ORIGIN+'/login',true));assert(m.publishedRequestAllowed('https://gklhhhyosgasnyoxlrui.supabase.co/auth/v1/token',false));
 for(const raw of ['https://foreign.supabase.co/auth/v1/token','https://gklhhhyosgasnyoxlrui.supabase.co.evil.invalid/auth/v1/token','http://gklhhhyosgasnyoxlrui.supabase.co/auth/v1/token','https://scope-and-approval-keeper.lovable.app.evil.invalid/login','https://preview.lovable.app/login'])assert.equal(m.publishedRequestAllowed(raw,true),false);
 const path='own/uploads/object/own.txt',url='https://gklhhhyosgasnyoxlrui.supabase.co/storage/v1/object/sign/contaos-documentos/'+path+'?token=PRIVATE_CANARY';
 assert.equal(m.publishedRequestAllowed(url,true),false);assert.equal(m.publishedRequestAllowed(url,true,[path]),true);assert.equal(m.publishedRequestAllowed(url+'x',true,[]),false);
});

test('published assertions never enter persisted local report, including interrupted smoke',async()=>{
 const m=await import('./p0_crud_global_browser.mjs');assert.equal(typeof m.createProofRecorder,'function');
 const local={assertions:[]},published={assertions:[]},saved=[];
 const recorder=m.createProofRecorder(local,()=>saved.push(JSON.stringify(local)));
 recorder.check('LOCAL_BEGIN',true);
 await assert.rejects(()=>recorder.published(published,()=>{},async()=>{recorder.check('PUBLISHED_RECEIPT',true,200);throw Error('watcher interrupted');}));
 recorder.check('LOCAL_AFTER',true);
 assert.deepEqual(local.assertions.map(x=>x.name),['LOCAL_BEGIN','LOCAL_AFTER']);assert.deepEqual(published.assertions.map(x=>x.name),['PUBLISHED_RECEIPT']);assert(saved.every(x=>!x.includes('PUBLISHED_RECEIPT')));
});


test('cleanup still attempts own job quarantine when receipt reconciliation fails',()=>{
 const code=`import runpy,json,tempfile
from pathlib import Path
R=runpy.run_path('supabase/tests/p0_crud_global_hml.py')['Runner']
for pending in [False,True]:
 r=object.__new__(R);r.report={};calls=[]
 with tempfile.TemporaryDirectory() as d:
  r.root=Path(d);f={'batch':'DOCUMENTOS','scope':'P0-CRUD-GLOBAL-HML','nonce':'a'*32,'prefix':'0000 CRUDG '+'a'*32+' ','users':[{'intent_id':'intent','creation_state':'created'}]};r.save('fixture.json',f)
  def sql(source,fetch=False):
   calls.append(source)
   if source.startswith('select id from auth.users'):return '11111111-1111-4111-8111-111111111111'
   if source.startswith('select id from public.organizacoes'):return '22222222-2222-4222-8222-222222222222'
   return 't' if fetch else None
  def recover(f):raise AssertionError('Ambiguous receipt PRIVATE_CANARY')
  def quarantine(f):
   calls.append('DOCUMENTS')
   assert 'BAN' in calls and any('delete from auth.sessions' in x for x in calls)
   if pending:raise RuntimeError('Own worker active')
   return {'active_jobs':0,'cancelled_jobs':1}
  r.sql=sql;r.request=lambda *a,**k:(calls.append('BAN') or (200,{}));r.recover_document_uploads=recover;r.quarantine_document_jobs=quarantine
  try:r.cleanup()
  except RuntimeError:pass
  else:raise AssertionError('Ambiguous receipt cannot certify cleanup')
  assert 'DOCUMENTS' in calls,'Reconciliation failure skipped own job quarantine'
  assert not any("set situacao='inativa'" in x for x in calls)
  result=json.loads((r.root/'cleanup.json').read_text());assert result['state']=='QUARENTENA_PENDENTE';assert r.report['state']=='CLEANUP_FAILED'
  assert 'PRIVATE_CANARY' not in json.dumps(r.report)
print('DOCUMENT_RECOVERY_FAILURE_QUARANTINE_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/DOCUMENT_RECOVERY_FAILURE_QUARANTINE_PASS/);
});


test('published SQL confirmation is not marked PASS before all database proofs',()=>{
 const code=`import runpy
R=runpy.run_path('supabase/tests/p0_crud_global_hml.py')['Runner']
g=R.verify_documents.__globals__;g['validate_document_partition']=lambda f:{}
r=object.__new__(R);r.report={'assertions':[]};r.save=lambda *a:None;r.recover_document_uploads=lambda f:{}
u={'org':'a','contract':'b','state':'PROCESSED','download_verified':True,'file':'11111111-1111-4111-8111-111111111111','document':'22222222-2222-4222-8222-222222222222','id_version':'33333333-3333-4333-8333-333333333333','version':1,'sha256':'a'*64,'size':10}
f={'permission_control':{'state':'REVOKED'},'users':[{'profile':'administrador','id':'44444444-4444-4444-8444-444444444444'}],'org':'a','contract':'b','uploads':[u]}
r.sql=lambda s,fetch=False:'t' if s.startswith('select count(*)=1') else 'f'
try:r.verify_documents(f)
except RuntimeError:pass
else:raise AssertionError('SQL failure accepted')
assert r.report.get('published_smoke',{}).get('state')!='PASS_SQL_CONFIRMED','Premature SQL PASS'
print('NO_PREMATURE_SQL_PASS')`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8',env:{PATH:process.env.PATH}});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/NO_PREMATURE_SQL_PASS/);
});


test('public inspection parses same-origin classic and inline scripts rather than ignoring them',async()=>{
 const m=await import('./p0_crud_global_browser.mjs'),o=m.PUBLISHED_ORIGIN;
 const html='<script defer src="/~flock.js"></script><script>const bootstrap=1;</script><script type="module" src="/assets/main.js"></script>';
 const bodies=new Map([[o+'/login',html],[o+'/~flock.js','const telemetry=1;'],[o+'/assets/main.js','const app=1;']]);let inspected=0;
 const result=await m.inspectPublishedBackend(async url=>({ok:true,status:200,url,body:new ReadableStream({start(c){c.enqueue(new TextEncoder().encode(bodies.get(url)));c.close();}})}),{version:'5.9.3',htmlEntries:()=>[{attributes:[['src','/~flock.js']],source:''},{attributes:[],source:'const bootstrap=1;'},{attributes:[['type','module'],['src','/assets/main.js']],source:''}],imports:()=>[],prove(modules,entries){assert.equal(modules.size,3);assert.equal(entries.length,3);assert([...modules.values()].includes('const bootstrap=1;'));assert([...modules.values()].includes('const telemetry=1;'));inspected++;return {verified:true};}});
 assert.equal(inspected,1);assert.equal(result.module_count,3);assert(!JSON.stringify(result).includes('bootstrap'));
});


test('public inspector refuses HTML without a supplied inert parser',async()=>{
 const m=await import('./p0_crud_global_browser.mjs'),o=m.PUBLISHED_ORIGIN;
 for(const attrs of ['src=https://foreign.invalid/a.js src="/assets/main.js"','src="/assets/main.js" SRC=https://foreign.invalid/a.js','type=module src="/assets/main.js"']){
  let reads=0;
  await assert.rejects(()=>m.inspectPublishedBackend(async url=>{reads++;return {ok:true,status:200,url,body:new ReadableStream({start(c){c.enqueue(new TextEncoder().encode(reads===1?'<script '+attrs+'></script>':'const app=1;'));c.close();}})};},{version:'5.9.3',imports:()=>[],prove:()=>({verified:true})}),/PUBLICADA_BACKEND_NAO_COMPROVADO/);
  assert.equal(reads,1);
 }
});


test('backend inspection progress exposes only closed phase labels on failure',async()=>{
 const m=await import('./p0_crud_global_browser.mjs'),phases=[];
 await assert.rejects(()=>m.inspectPublishedBackend(async()=>{throw Error('PRIVATE_CANARY_URL_TOKEN_STACK')},{},phase=>phases.push(phase)),/PUBLICADA_BACKEND_NAO_COMPROVADO/);
 assert.deepEqual(phases,['READ_HTML']);assert(!JSON.stringify(phases).includes('PRIVATE_CANARY'));
});

test('published response fence rejects redirects and changed executable bytes before resume',async()=>{
  const {validatePublishedResponse}=await import('./p0_crud_global_browser.mjs');
  const {createHash}=await import('node:crypto');const url='https://scope-and-approval-keeper.lovable.app/assets/proof.js',body=Buffer.from('globalThis.proof=1;');
  const proof={origin:'https://scope-and-approval-keeper.lovable.app',modules:new Map([[url,createHash('sha256').update(body).digest('hex')]]),html_sha256:createHash('sha256').update('<!doctype html>').digest('hex')};
  assert.equal(validatePublishedResponse(proof,{url,resourceType:'Script',status:200,body}),true);
  for(const status of [301,302,303,307,308])assert.throws(()=>validatePublishedResponse(proof,{url,resourceType:'Script',status,body}));
  assert.throws(()=>validatePublishedResponse(proof,{url,resourceType:'Script',status:200,body:Buffer.from('changed')}));
  assert.throws(()=>validatePublishedResponse(proof,{url:url+'other',resourceType:'Script',status:200,body}));
  assert.throws(()=>validatePublishedResponse(proof,{url:url.replace('/assets/proof.js','/login'),resourceType:'Document',status:200,body:Buffer.from('changed')}));
});

test('signed download is bounded and cannot follow redirects or change owned destination',async()=>{
  const {boundedSignedDownload}=await import('./p0_crud_global_browser.mjs');let calls=0;
  const url='https://gklhhhyosgasnyoxlrui.supabase.co/storage/v1/object/sign/contaos-documentos/own/fixture.txt?token=synthetic';
  const transport=async(raw,options)=>{calls++;assert.equal(raw,url);assert.equal(options.redirect,'error');assert.equal(options.credentials,'omit');assert.equal(options.headers,undefined);return new Response(Buffer.from('own'),{status:200});};
  assert.deepEqual(await boundedSignedDownload(transport,url,'own/fixture.txt',3),Buffer.from('own'));
  for(const raw of [url.replace('gklhhhyosgasnyoxlrui','foreign'),url.replace('own/fixture.txt','third/fixture.txt')])await assert.rejects(()=>boundedSignedDownload(transport,raw,'own/fixture.txt',3));
  assert.equal(calls,1);
  await assert.rejects(()=>boundedSignedDownload(async()=>new Response(null,{status:308,headers:{location:'https://foreign.invalid'}}),url,'own/fixture.txt',3));
  await assert.rejects(()=>boundedSignedDownload(async()=>new Response(Buffer.from('oversized'),{status:200}),url,'own/fixture.txt',3));
});

test('native websocket denial affects only ws and wss rules without global offline state',async()=>{
  const {webSocketDenyRules}=await import('./p0_crud_global_browser.mjs');const rules=webSocketDenyRules();
  assert.deepEqual(Object.keys(rules),['matchedNetworkConditions']);
  assert.deepEqual(rules.matchedNetworkConditions.map(x=>x.urlPattern),['ws://*:*/*','wss://*:*/*']);
  for(const rule of rules.matchedNetworkConditions)assert.deepEqual(rule,{urlPattern:rule.urlPattern,offline:true,latency:0,downloadThroughput:-1,uploadThroughput:-1});
});

test('page request barrier cannot wait for worker bootstrap that depends on that request',async()=>{
  const {nativePageBarrier}=await import('./p0_crud_global_browser.mjs');
  const targets=[{targetId:'main',type:'page',browserContextId:'own'},{targetId:'frame',type:'iframe',browserContextId:'own'},{targetId:'bootstrap',type:'worker',browserContextId:'own'},{targetId:'shared',type:'shared_worker',browserContextId:'own'},{targetId:'third',type:'page',browserContextId:'other'}];
  assert.deepEqual([...nativePageBarrier(targets,[{targetId:'worker-child',type:'worker',contextId:'own'}],'own','main')],['main','frame']);
  assert.throws(()=>nativePageBarrier(targets,[],'other','main'));
});

test('unsupported browser workers are denied while paused instead of being resumed',async()=>{
  const {unexpectedWorkerDeny}=await import('./p0_crud_global_browser.mjs');
  for(const type of ['worker','shared_worker']){
    assert.deepEqual(unexpectedWorkerDeny({type,contextId:'own',waitingForDebugger:true},'own'),{code:'FENCE_UNEXPECTED_WORKER_PAUSED',paused:true});
    assert.deepEqual(unexpectedWorkerDeny({type,contextId:'own',waitingForDebugger:false},'own'),{code:'FENCE_UNEXPECTED_WORKER_RUNNING',paused:false});
    assert.equal(unexpectedWorkerDeny({type,contextId:'other',waitingForDebugger:true},'own'),null);
  }
  assert.equal(unexpectedWorkerDeny({type:'page',contextId:'own'},'own'),null);
});

test('native fence cannot activate Playwright preflight auto-fulfillment',async()=>{
  const {installPublishedCDPFence}=await import('./p0_crud_global_browser.mjs');const source=installPublishedCDPFence.toString();
  assert.equal(/context\.route\s*\(/.test(source),false,'Playwright routing fabricates OPTIONS success in the frozen runtime');
  assert.equal(/Fetch\.fulfillRequest|route\.fulfill|routeWebSocket/.test(readFileSync(browser,'utf8')),false);
  assert.ok(/requestStage:'Request'/.test(source));assert.ok(/requestStage:'Response'/.test(source));
  assert.ok(/Fetch\.continueRequest',\{requestId\}/.test(source));
  assert.equal(readFileSync(browser,'utf8').includes('--disable-blink-features=SharedWorker'),true,'SharedWorker must be disabled by the verified native feature');
});
