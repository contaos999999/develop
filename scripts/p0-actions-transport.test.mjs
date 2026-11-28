import assert from 'node:assert/strict';
import {test} from 'node:test';
import {existsSync} from 'node:fs';

const repository = 'contaos999999/develop';
const requestId = '11111111-1111-4111-8111-111111111111';
const requestPath = 'docs/executor/requests/' + requestId + '.json';
const sha = (c) => c.repeat(40);
const raw = (q) => JSON.stringify(q) + '\n';
const request = () => ({
  schema:'contaos.p0.actions-request.v1',request_id:requestId,repository,
  mission_id:'P0-ORQ-ACTIONS-001-B2',operation:'CANARY_CODE',environment:'CODE',
  source_sha:sha('a'),source_pr:1,request_pr:2,plan_ref:sha('c'),plan_blob:sha('e'),
  authorization_ref:sha('d'),predecessor_checkpoint_ref:123
});
const catalog = () => ({schema:'contaos.p0.actions-catalog.v1',repository,operations:[
  {operation:'CANARY_CODE',environment:'CODE',mode:'CODE_FIXTURE_ONLY',enabled:true},
  {operation:'HML_DEPLOY_ONE',environment:'HML',mode:'DISABLED',enabled:false}
]});
const context = () => ({
  repository,eventName:'push',ref:'refs/heads/main',sha:sha('b'),before:sha('4'),
  runId:'12345',attempt:'1',job:'canary',
  event:{repository:{full_name:repository},ref:'refs/heads/main',before:sha('4'),
    after:sha('b'),created:false,deleted:false,forced:false}
});
const checkout = () => ({
  head:sha('b'),tree:sha('f'),parents:[sha('4'),sha('3')],
  files:[{path:requestPath,status:'A',mode:'100644',raw:raw(request())}]
});
async function api(){
  assert.ok(existsSync(new URL('./p0-actions-transport.mjs',import.meta.url)),
    'RED_CAUSAL_NATIVE_TRANSPORT_ABSENT');
  const m=await import('./p0-actions-transport.mjs');
  for(const name of ['validatePush','buildCanaryReceipt','runTransport']) assert.equal(typeof m[name],'function');
  return m;
}
test('B2 native transport validates a single immutable CODE request',async()=>{
  const m=await api();
  const x=await m.validatePush({context:context(),checkout:checkout(),catalog:raw(catalog())});
  assert.equal(x.status,'VALIDATED_PUSH');
  assert.deepEqual(x.request,request());
  assert.equal(x.executionAllowed,false);
});
for(const [name,mutate] of [
  ['non-push',x=>x.context.eventName='pull_request'],
  ['non-main',x=>x.context.ref='refs/heads/other'],
  ['wrong repo',x=>x.context.repository='other/repo'],
  ['event repo mismatch',x=>x.context.event.repository.full_name='other/repo'],
  ['event ref mismatch',x=>x.context.event.ref='refs/heads/other'],
  ['event sha mismatch',x=>x.context.event.after=sha('0')],
  ['event parent mismatch',x=>x.context.event.before=sha('0')],
  ['forced push',x=>x.context.event.forced=true],
  ['created ref',x=>x.context.event.created=true],
  ['deleted ref',x=>x.context.event.deleted=true],
  ['retry attempt',x=>x.context.attempt='2'],
  ['invalid run id',x=>x.context.runId='../../run'],
  ['wrong job',x=>x.context.job='other'],
  ['wrong checkout sha',x=>x.checkout.head=sha('0')],
  ['invalid tree',x=>x.checkout.tree='bad'],
  ['wrong first parent',x=>x.checkout.parents[0]=sha('0')],
  ['non-merge',x=>x.checkout.parents=[sha('4')]],
  ['octopus merge',x=>x.checkout.parents.push(sha('5'))],
  ['no manifest',x=>x.checkout.files=[]],
  ['two manifests',x=>x.checkout.files.push({...x.checkout.files[0]})],
  ['extra file',x=>x.checkout.files.push({path:'other',status:'A',mode:'100644',raw:'x'})],
  ['modified manifest',x=>x.checkout.files[0].status='M'],
  ['deleted manifest',x=>x.checkout.files[0].status='D'],
  ['symlink',x=>x.checkout.files[0].mode='120000'],
  ['executable file',x=>x.checkout.files[0].mode='100755'],
  ['wrong path',x=>x.checkout.files[0].path='docs/executor/requests/other.json'],
  ['noncanonical request',x=>x.checkout.files[0].raw+=' '],
  ['PROD',x=>x.checkout.files[0].raw=raw({...request(),environment:'PROD'})],
  ['arbitrary operation',x=>x.checkout.files[0].raw=raw({...request(),operation:'RUN_ANY'})],
  ['HML disabled',x=>x.checkout.files[0].raw=raw({...request(),operation:'HML_DEPLOY_ONE',environment:'HML',migration_version:'20261127233223',migration_sha256:'a'.repeat(64)})],
  ['bad catalog',x=>x.catalog=raw({...catalog(),extra:true})]
]) test('B2 rejects '+name,async()=>{
  const m=await api(),x={context:context(),checkout:checkout(),catalog:raw(catalog())};
  mutate(x);const v=await m.validatePush(x);assert.equal(v.status,'BLOCKED');assert.equal(v.executionAllowed,false);
  assert.ok(v.reason);
});
test('B2 receipt is sanitized and never certifies or grants execution',async()=>{
  const m=await api();const x=await m.validatePush({context:context(),checkout:checkout(),catalog:raw(catalog())});
  const receipt=m.buildCanaryReceipt(x,{mode:'FIXTURE',status:'BLOCKED',reason:'UNVERIFIED_EVIDENCE'});
  assert.equal(receipt.request_id,requestId);assert.equal(receipt.repository,repository);
  assert.equal(receipt.run_id,'12345');assert.equal(receipt.run_attempt,1);assert.equal(receipt.tree,sha('f'));
  assert.equal(receipt.result,'BLOCKED');assert.equal(receipt.execution_allowed,false);
  assert.equal(receipt.certification,'NOT_CERTIFIED');assert.ok(!JSON.stringify(receipt).includes('secret-fixture'));
});
test('B2 fails closed with unavailable real evidence, no local effect',async()=>{
  const m=await api();let calls=0;
  const result=await m.runTransport({context:context(),checkout:checkout(),catalog:raw(catalog()),
    token:'secret-fixture',fetcher:async(url,opts)=>{calls++;assert.equal(new URL(url).origin,'https://api.github.com');
    assert.equal(opts.method,'GET');return new Response('{}',{status:403});}});
  assert.ok(calls>0);assert.equal(result.status,'BLOCKED');assert.equal(result.executionAllowed,false);
  assert.ok(!JSON.stringify(result).includes('secret-fixture'));
});

async function transportFixture() {
  const repo=repository, path=requestPath;
  const source=sha('a'),req=sha('b'),plan=sha('c'),auth=sha('d');
  const requiredChecks=["guard"];
  const {createHash} = await import('node:crypto');
  const q = request();
  const planPath = 'docs/backend/PLAN_P0_ORQUESTRADOR_ACTIONS_2026-11-27.md';
  const authPath = path.replace('/requests/', '/authorizations/');
  const blob = (filePath, body) => {
    const bytes = Buffer.from(body);
    return {type:'file',path:filePath,size:bytes.length,encoding:'base64',content:bytes.toString('base64'),
      sha:createHash('sha1').update('blob '+bytes.length+'\0').update(bytes).digest('hex')};
  };
  const planBlob = blob(planPath, 'protected fixture plan\n');
  q.plan_blob = planBlob.sha;
  const authBlob = blob(authPath, raw({
    schema:'contaos.p0.actions-authorization.v1',request_path:path,
    intent:Object.fromEntries(Object.entries(q).filter(([key]) => !['request_pr','authorization_ref'].includes(key))),
    plan_path:planPath,plan_pr:3,authorization_pr:4,
    expires_at:new Date(Date.now()+3600000).toISOString(),allowed_delta:[planPath,authPath]
  }));
  const records = [
    {number:1, merge:source, head:sha('1'), base:sha('2'), files:[], merged:'2026-11-27T17:10:00Z'},
    {number:3, merge:plan, head:sha('5'), base:source, files:[{filename:planPath,status:'added'}], merged:'2026-11-27T17:20:00Z'},
    {number:4, merge:auth, head:sha('6'), base:plan, files:[{filename:authPath,status:'added'}], merged:'2026-11-27T17:30:00Z'},
    {number:2, merge:req, head:sha('3'), base:auth, files:[{filename:path,status:'added'}], merged:'2026-11-27T18:00:00Z'}
  ];
  const rules = {
    id:28271968,enforcement:'active',target:'branch',
    conditions:{ref_name:{include:['~DEFAULT_BRANCH'],exclude:[]}},bypass_actors:[],current_user_can_bypass:'never',
    rules:[
      {type:'pull_request',parameters:{required_approving_review_count:1,dismiss_stale_reviews_on_push:true,require_last_push_approval:true,required_review_thread_resolution:true}},
      {type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,required_status_checks:requiredChecks.map(context=>({context,integration_id:15368}))}},
      {type:'deletion'},{type:'non_fast_forward'}
    ]
  };
  const responses = new Map();
  for (const r of records) {
    responses.set('pulls/'+r.number,{number:r.number,merged:true,merge_commit_sha:r.merge,
      base:{ref:'main',repo:{full_name:repo},sha:r.base},head:{repo:{full_name:repo},sha:r.head},
      user:{login:'author'},created_at:'2026-11-27T16:00:00Z',merged_at:r.merged,changed_files:r.files.length});
    responses.set('commits/'+r.merge,{sha:r.merge,commit:{tree:{sha:sha('f')}},parents:[{sha:r.base},{sha:r.head}]});
    responses.set('commits/'+r.head,{sha:r.head,commit:{tree:{sha:sha('f')}}});
    responses.set('pulls/'+r.number+'/reviews',[{user:{login:'Edivan5002'},commit_id:r.head,state:'APPROVED',author_association:'MEMBER',submitted_at:'2026-11-27T17:00:00Z'}]);
    responses.set('commits/'+r.head+'/check-runs',{total_count:requiredChecks.length,check_runs:requiredChecks.map(name=>({name,app:{id:15368},head_sha:r.head,status:'completed',conclusion:'success',started_at:'2026-11-27T16:15:00Z',completed_at:'2026-11-27T16:45:00Z'}))});
    responses.set('pulls/'+r.number+'/files',r.files);
  }
  const comparison = (a,z,files) => ({status:'ahead',base_commit:{sha:a},merge_base_commit:{sha:a},behind_by:0,ahead_by:1,total_commits:1,commits:[{sha:z}],files});
  responses.set('compare/'+source+'...'+plan,comparison(source,plan,[{filename:planPath,status:'added'}]));
  responses.set('compare/'+plan+'...'+auth,comparison(plan,auth,[{filename:authPath,status:'added'}]));
  responses.set('compare/'+source+'...'+auth,comparison(source,auth,[{filename:planPath,status:'added'},{filename:authPath,status:'added'}]));
  responses.set('branches/main',{protected:true,commit:{sha:req}});
  responses.set('rulesets/28271968',rules);
  responses.set('contents/'+authPath,authBlob);
  responses.set('contents/'+planPath,planBlob);
  responses.set('contents/'+path,blob(path,raw(q)));
  responses.set('commits',[]);
  let paginated = 0, reads = 0;
  const fetcher = async (input, options) => {
    const u = new URL(input);
    assert.equal(u.origin,'https://api.github.com');
    assert.ok(u.pathname.startsWith('/repos/'+repo+'/'));
    assert.equal(options.method,'GET');
    assert.equal(options.redirect,'error');
    assert.equal(options.headers.Authorization,'Bearer fixture-only');
    reads++;
    const key = u.pathname.slice(('/repos/'+repo+'/').length);
    if (key === 'contents/'+path && u.searchParams.get('ref') === auth)
      return new Response('{}',{status:404});
    if (key === 'pulls/2/reviews' && u.searchParams.get('page') === '1') {
      const next = new URL(u); next.searchParams.set('page','2'); paginated++;
      return new Response('[]',{status:200,headers:{link:'<'+next.href+'>; rel="next"'}});
    }
    if (key === 'pulls/2/reviews' && u.searchParams.get('page') === '2') paginated++;
    assert.ok(responses.has(key),key);
    return new Response(JSON.stringify(responses.get(key)),{status:200});
  };
  const c=context(),g=checkout(); c.before=auth;c.event.before=auth;g.parents=[auth,sha('3')];g.files[0].raw=raw(q);
  return {input:{context:c,checkout:g,catalog:raw(catalog()),token:'fixture-only',fetcher},
    responses,fetcher,stats:()=>({reads,paginated})};
}
test('B2 transport reconstructs protected provenance fixture without execution',async()=>{
  const m=await api(), f=await transportFixture();
  const result=await m.runTransport(f.input);
  assert.equal(result.status,'COLLECTED_FIXTURE',result.reason);
  assert.equal(result.executionAllowed,false);
  assert.equal(result.receipt.result,'COLLECTED_FIXTURE');
  assert.equal(result.receipt.mode,'FIXTURE');
  assert.equal(result.receipt.authorization_pr,4);
  assert.equal(result.receipt.certification,'NOT_CERTIFIED');
  assert.equal(result.receipt.execution_allowed,false);
  assert.equal(f.stats().paginated,2);
  assert.ok(f.stats().reads>20);
  assert.ok(!JSON.stringify(result).includes('fixture-only'));
});
for(const [name,mutate] of [
  ['local tree differs',f=>f.input.checkout.tree=sha('0')],
  ['reviewed head tree differs',f=>f.responses.set('commits/'+sha('3'),{sha:sha('3'),commit:{tree:{sha:sha('0')}}})],
  ['replay history',f=>f.responses.set('commits',[{sha:sha('1')}])],
  ['strict protection disabled',f=>{const r=[...f.responses.entries()].find(([k])=>k.startsWith('rulesets/'))[1];r.rules.find(x=>x.type==='required_status_checks').parameters.strict_required_status_checks_policy=false;}],
  ['missing review',f=>f.responses.set('pulls/2/reviews',[])],
  ['missing check',f=>f.responses.set('commits/'+sha('3')+'/check-runs',{total_count:0,check_runs:[]})],
  ['late stale main',f=>{let n=0;f.input.fetcher=async(url,opts)=>{if(new URL(url).pathname.endsWith('/branches/main')&&++n===3)return new Response(JSON.stringify({protected:true,commit:{sha:sha('0')}}),{status:200});return f.fetcher(url,opts);};}],
  ['late ruleset change',f=>{let n=0;f.input.fetcher=async(url,opts)=>{const u=new URL(url);if(u.pathname.includes('/rulesets/')&&++n===3){const r=structuredClone([...f.responses.entries()].find(([k])=>k.startsWith('rulesets/'))[1]);r.bypass_actors=[{actor_id:1}];return new Response(JSON.stringify(r),{status:200});}return f.fetcher(url,opts);};}]
]) test('B2 transport fails closed on '+name,async()=>{
  const m=await api(),f=await transportFixture();mutate(f);
  const v=await m.runTransport(f.input);assert.equal(v.status,'BLOCKED');assert.equal(v.executionAllowed,false);
  assert.equal(v.receipt.result,'BLOCKED');assert.equal(v.receipt.certification,'NOT_CERTIFIED');
});


test('B2 real git checkout binds append-only diff and source hashes',async()=>{
  const m=await api();
  const {mkdtempSync,mkdirSync,writeFileSync,rmSync,symlinkSync}=await import('node:fs');
  const {tmpdir}=await import('node:os');
  const {join,dirname}=await import('node:path');
  const {execFileSync}=await import('node:child_process');
  const {createHash}=await import('node:crypto');
  const dir=mkdtempSync(join(tmpdir(),'p0-transport-'));
  const git=(...args)=>execFileSync('git',args,{cwd:dir,stdio:['ignore','pipe','pipe'],
    env:{PATH:process.env.PATH,LANG:'C',GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',
      GIT_AUTHOR_NAME:'Fixture',GIT_AUTHOR_EMAIL:'fixture@example.invalid',
      GIT_COMMITTER_NAME:'Fixture',GIT_COMMITTER_EMAIL:'fixture@example.invalid'}}).toString().trim();
  const file=(path,body)=>{mkdirSync(dirname(join(dir,path)),{recursive:true});writeFileSync(join(dir,path),body);};
  try {
    git('init','-b','main');git('config','commit.gpgsign','false');
    const sources=['scripts/p0-actions-request.mjs','scripts/p0-actions-transport.mjs',
      '.github/workflows/p0-actions-orchestrator-request.yml','.github/workflows/p0-actions-orchestrator-code.yml'];
    for(const p of sources)file(p,'synthetic '+p+'\n');
    file('docs/executor/P0_ACTIONS_CATALOG.json',raw(catalog()));
    git('add','.');git('commit','-m','fixture base');
    const base=git('rev-parse','HEAD');
    git('switch','-c','request');file(requestPath,raw(request()));git('add','.');git('commit','-m','one request');
    git('switch','main');git('merge','--no-ff','-m','fixture merge','request');
    const data=m.readCheckout(dir);
    const c=context();c.sha=data.checkout.head;c.before=base;c.event.after=c.sha;c.event.before=base;
    const validated=m.validatePush({context:c,...data});assert.equal(validated.status,'VALIDATED_PUSH',validated.reason);
    assert.equal(data.checkout.parents[0],base);assert.deepEqual(Object.keys(data.checkout.sourceHashes),sources);
    for(const p of sources)assert.equal(data.checkout.sourceHashes[p],createHash('sha256').update('synthetic '+p+'\n').digest('hex'));
    assert.deepEqual(validated.provenance.source_sha256,data.checkout.sourceHashes);
    git('switch','-c','invalid');file('docs/executor/requests/22222222-2222-4222-8222-222222222222.json',raw(request()));
    file('extra.txt','extra');git('add','.');git('commit','-m','invalid two paths');git('switch','main');git('merge','--no-ff','-m','invalid merge','invalid');
    assert.throws(()=>m.readCheckout(dir),/REQUEST_DIFF/);
    git('switch','-c','link');symlinkSync('missing',join(dir,'docs/executor/requests/33333333-3333-4333-8333-333333333333.json'));
    git('add','.');git('commit','-m','invalid symlink');git('switch','main');git('merge','--no-ff','-m','link merge','link');
    assert.throws(()=>m.readCheckout(dir),/REQUEST_FILE/);
  } finally {rmSync(dir,{recursive:true,force:true});}
});
