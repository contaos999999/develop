import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {parseCheckpoint,selectCheckpoint,reconcile,readState,createApi} from './executor-state-controller.mjs';
const sha='a'.repeat(40);
const checkpoint=(extra={}) => '<!-- CONTAOS_EXECUTOR_STATE_V1\n'+JSON.stringify({
 schema:1,phase_id:3,task_id:'fixtures',head_sha:sha,pr_number:219,
 run_id:123,status:'COMPLETED',conclusion:'success',evidence:[],next_action:'Verificar',...extra})+'\n-->';
const comment=(body=checkpoint(),id=100,login='contaos9999')=>({id,body,user:{login}});
const run=(more={})=>({id:123,status:'completed',conclusion:'success',head_sha:sha,
 repository:{full_name:'contaos999999/develop'},html_url:'https://github.com/contaos999999/develop/actions/runs/123',...more});
const pr=(more={})=>({number:219,base:{repo:{full_name:'contaos999999/develop'}},
 head:{repo:{full_name:'contaos999999/develop'},sha},...more});
const api=(records={})=>async path=>{
 if(path.includes('/actions/runs/'))return records.run||run();
 if(path.includes('/pulls/'))return records.pr||pr();
 if(path.includes('/comments?'))return records.comments||[comment()];
 throw Error('unexpected GET');
};
test('parse válido aceita campos de estado e não concede dispatch',()=>{
 const x=parseCheckpoint(checkpoint()); assert.equal(x.run_id,123);assert.equal(x.phase_id,3);
});
for(const [label,body] of [
 ['fase invalida',checkpoint({phase_id:9})],['SHA invalido',checkpoint({head_sha:'x'})],
 ['status invalido',checkpoint({status:'CERTIFIED'})],['run inválido',checkpoint({run_id:-1})],
 ['evidencia inválida',checkpoint({evidence:[{}]})],['JSON danificado','<!-- CONTAOS_EXECUTOR_STATE_V1\n{}\n-->'],
 ['marcador duplicado',checkpoint()+'\n'+checkpoint()]])test(label,()=>assert.equal(parseCheckpoint(body),null));
test('comentário externo forjado não define checkpoint',()=>{
 const v=selectCheckpoint([comment(checkpoint(),1,'outsider')]);assert.equal(v.status,'UNINITIALIZED');assert.equal(v.dispatch_allowed,false);
});
test('último comentário válido vence pela ordem crescente de ID',()=>{
 const a=comment(checkpoint({task_id:'old'}),1),b=comment(checkpoint({task_id:'new'}),3);
 assert.equal(selectCheckpoint([b,a]).state.task_id,'new');
});
test('checkpoint malformado de autor autorizado bloqueia, sem voltar silenciosamente',()=>{
 const v=selectCheckpoint([comment(),comment('<!-- CONTAOS_EXECUTOR_STATE_V1\n{}\n-->',2)]);assert.equal(v.reason,'CHECKPOINT_MALFORMED');assert.equal(v.dispatch_allowed,false);
});
test('run concluída sucesso nunca certifica nem permite dispatch',async()=>{
 const x=await reconcile(selectCheckpoint([comment()]),api());
 assert.equal(x.status,'VALIDATING');assert.equal(x.reason,'GATES_AND_REVIEW_REQUIRED');assert.equal(x.dispatch_allowed,false);
});
for(const [label,records,reason] of [
 ['run id falso',{run:run({id:99})},'RUN_IDENTITY'],
 ['run repo falso',{run:run({repository:{full_name:'outro/repo'}})},'RUN_IDENTITY'],
 ['run HEAD falso',{run:run({head_sha:'b'.repeat(40)})},'RUN_HEAD_MISMATCH'],
 ['run falha',{run:run({conclusion:'failure'})},'RUN_NOT_SUCCESS'],
 ['PR HEAD antigo',{pr:pr({head:{repo:{full_name:'contaos999999/develop'},sha:'b'.repeat(40)}})},'PR_HEAD_MISMATCH'],
 ['PR de repo alheio',{pr:pr({base:{repo:{full_name:'outro/repo'}}})},'PR_IDENTITY'],
])test(label,async()=>{const x=await reconcile(selectCheckpoint([comment()]),api(records));assert.equal(x.reason,reason);assert.equal(x.dispatch_allowed,false);});
test('run em andamento é RUNNING, não nova execução',async()=>{
 const x=await reconcile(selectCheckpoint([comment()]),api({run:run({status:'in_progress',conclusion:null})}));assert.equal(x.status,'RUNNING');assert.equal(x.dispatch_allowed,false);
});
test('sem Run ID é BLOCKED, ainda que comentário tenha COMPLETED',async()=>{
 const x=await reconcile(selectCheckpoint([comment(checkpoint({run_id:null}))]),api());assert.equal(x.reason,'NO_RUN_PROOF');
});
test('paginação lê até fim e preserva último ID',async()=>{
 const old=comment(checkpoint({task_id:'old'}),1),latest=comment(checkpoint({task_id:'latest'}),101);
 const p=Array.from({length:100},(_,i)=>({...old,id:i+1}));
 const x=await readState(api({comments:null,run:run(),pr:pr()}));assert.equal(x.checkpoint_comment_id,100);
 const y=await readState(async path=>{
   if(path.includes('page=1'))return p;
   if(path.includes('page=2'))return [latest];
   if(path.includes('/actions/runs/'))return run();
   if(path.includes('/pulls/'))return pr();
   throw Error('unexpected');
 });assert.equal(y.checkpoint_comment_id,101);assert.equal(y.task_id,'latest');
});
test('scoped read API uses only GET and exact GitHub repo paths',async()=>{
 let calls=0;const a=createApi('token',async(url,options)=>{
 calls++;assert.equal(options.method,'GET');assert.match(url,/^https:\/\/api.github.com\/repos\/contaos999999\/develop\//);
 return {status:200,json:async()=>[]};
 });await a('/repos/contaos999999/develop/issues/138/comments?per_page=100&page=1');
 await assert.rejects(()=>a('/repos/other/repo/issues/138/comments?per_page=100&page=1'),/READ_SCOPE/);
 assert.equal(calls,1);
});
test('sem token falha fechada sem emitir segredo',()=>{
 const x=spawnSync(process.execPath,[fileURLToPath(new URL('./executor-state-controller.mjs',import.meta.url))],{env:{PATH:process.env.PATH},encoding:'utf8'});
 assert.equal(x.status,2);const v=JSON.parse(x.stdout);assert.equal(v.reason,'READ_FAILED');assert.equal(v.dispatch_allowed,false);assert.ok(!x.stdout.includes('Bearer'));
});
