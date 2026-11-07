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
