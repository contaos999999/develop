#!/usr/bin/env node
// ContaOS V1: read-only reconciliation of append-only state checkpoints on GATE #138.
// No dispatch, no merge, no credential disclosure. Node >=20.
const owner='contaos999999', repo='develop', issue=138;
const token=process.env.GITHUB_TOKEN;
if(!token){console.error('GITHUB_TOKEN ausente');process.exit(2)}
const api=async path=>{const r=await fetch('https://api.github.com'+path,{headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28'}});if(!r.ok)throw Error('GitHub HTTP '+r.status);return r.json()};
const sha=s=>typeof s==='string'&&/^[a-f0-9]{40}$/.test(s);
const states=['PENDING','RUNNING','BLOCKED','VALIDATING','COMPLETED'];
function parse(body){const m=body.match(/<!-- CONTAOS_EXECUTOR_STATE_V1\n([\s\S]*?)\n-->/);if(!m)return null;try{const x=JSON.parse(m[1]);if(x.schema!==1||!Number.isInteger(x.phase_id)||x.phase_id<1||x.phase_id>8||!states.includes(x.status)||!sha(x.head_sha)||typeof x.task_id!=='string'||!x.task_id||typeof x.next_action!=='string')return null;return x}catch{return null}}
let comments=[],page=1;
while(true){const p=await api('/repos/'+owner+'/'+repo+'/issues/'+issue+'/comments?per_page=100&page='+page++);comments.push(...p);if(p.length<100)break;if(page>100)throw Error('Limite de paginação')}
const valid=comments.map(c=>({comment:c,state:parse(c.body||'')})).filter(x=>x.state).sort((a,b)=>a.comment.id-b.comment.id);
if(!valid.length){console.log(JSON.stringify({status:'UNINITIALIZED',next_action:'Registrar checkpoint inicial validado no GATE #138',dispatch_allowed:false},null,2));process.exit(0)}
const last=valid.at(-1),s=last.state;
const out={checkpoint_comment_id:last.comment.id,phase_id:s.phase_id,task_id:s.task_id,head_sha:s.head_sha,pr_number:s.pr_number??null,run_id:s.run_id??null,status:s.status,next_action:s.next_action,dispatch_allowed:false};
if(s.run_id){const r=await api('/repos/'+owner+'/'+repo+'/actions/runs/'+encodeURIComponent(s.run_id));out.workflow={id:r.id,status:r.status,conclusion:r.conclusion,head_sha:r.head_sha,html_url:r.html_url};if(r.head_sha!==s.head_sha){out.status='BLOCKED';out.reason='RUN_HEAD_MISMATCH'}else if(r.status!=='completed'){out.status='RUNNING';out.next_action='Aguardar Run ID existente'}else if(r.conclusion!=='success'){out.status='BLOCKED';out.next_action='Diagnosticar falha do Run ID sem reexecutar automaticamente'}else{out.status='VALIDATING';out.next_action='Verificar gates e evidências antes de avançar'}}
console.log(JSON.stringify(out,null,2));
