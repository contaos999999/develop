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
