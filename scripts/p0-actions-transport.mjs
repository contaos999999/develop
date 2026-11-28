// P0-ORQ-ACTIONS-001 B2/F2: transport for a CODE-only local canary.
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync, statSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseRequest, validateCatalog, collectEvidence, authorizeRequest } from './p0-actions-request.mjs';

const REPO = 'contaos999999/develop';
const ROOT = 'docs/executor/';
const RULESET = 28271968;
const WORKFLOW = '.github/workflows/p0-actions-orchestrator-request.yml';
const SHA = /^[0-9a-f]{40}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const ID = /^[1-9][0-9]{0,19}$/;
const LIMIT = 8192;
const API = 'https://api.github.com/repos/' + REPO + '/';
const sha = v => typeof v === 'string' && SHA.test(v);
const id = v => typeof v === 'string' && ID.test(v);
const raw = v => JSON.stringify(v) + '\n';
const equal = (a,b) => JSON.stringify(a) === JSON.stringify(b);
const digest = v => createHash('sha256').update(v).digest('hex');
class Denial extends Error {
  constructor(reason) { super(reason); this.reason = reason; }
}
const demand = (ok, reason) => { if (!ok) throw new Denial(reason); };
const deny = e => ({status:'BLOCKED',executionAllowed:false,
  reason:e instanceof Denial ? e.reason : 'UNVERIFIED_EVIDENCE'});
const allowedReasons = new Set([
  'EVENT_IDENTITY','EVENT_PROVENANCE','RUN_IDENTITY','CHECKOUT_IDENTITY','REQUEST_DIFF',
  'REQUEST_FILE','REQUEST_CONTRACT','OPERATION_DISABLED','UNVERIFIED_EVIDENCE',
  'API_UNAVAILABLE','API_HTTP','API_SIZE','STALE_MAIN','RULESET_CHANGED','TREE_MISMATCH',
  'AUTHORIZATION_UNPROVEN','RUNTIME_IDENTITY','LOCAL_IO','REPLAY_UNPROVEN'
]);
function pathFor(q) { return ROOT + 'requests/' + q.request_id + '.json'; }
function validPath(p) {
  return typeof p === 'string' && p.startsWith(ROOT+'requests/') && p.endsWith('.json') &&
    UUID.test(p.slice((ROOT+'requests/').length,-5));
}
export function validatePush({context:c,checkout:g,catalog}={}) {
  try {
    demand(c?.repository===REPO && c.eventName==='push' && c.ref==='refs/heads/main' &&
      sha(c.sha) && sha(c.before) && c.sha!==c.before,'EVENT_IDENTITY');
    const e=c.event;
    demand(e?.repository?.full_name===REPO && e.ref===c.ref && e.before===c.before &&
      e.after===c.sha && e.created===false && e.deleted===false && e.forced===false,'EVENT_PROVENANCE');
    demand(id(c.runId) && c.attempt==='1' && c.job==='canary','RUN_IDENTITY');
    demand(g?.head===c.sha && sha(g.tree) && Array.isArray(g.parents) && g.parents.length===2 &&
      g.parents.every(sha) && new Set(g.parents).size===2 && g.parents[0]===c.before,'CHECKOUT_IDENTITY');
    demand(Array.isArray(g.files) && g.files.length===1 && g.files[0]?.status==='A','REQUEST_DIFF');
    const f=g.files[0];
    demand(validPath(f.path) && f.mode==='100644' && typeof f.raw==='string' &&
      Buffer.byteLength(f.raw)<=LIMIT,'REQUEST_FILE');
    let q,k;
    try { q=parseRequest(f.raw,REPO); k=validateCatalog(catalog,REPO); }
    catch { throw new Denial('REQUEST_CONTRACT'); }
    demand(q.operation==='CANARY_CODE' && q.environment==='CODE','OPERATION_DISABLED');
    demand(f.path===pathFor(q),'REQUEST_FILE');
    return {status:'VALIDATED_PUSH',executionAllowed:false,request:q,catalog:k,
      provenance:{request_commit:g.head,tree:g.tree,parents:[...g.parents],run_id:c.runId,
        run_attempt:1,job:'canary',request_sha256:digest(f.raw),catalog_sha256:digest(catalog)}};
  } catch (e) { return deny(e); }
}
export function buildCanaryReceipt(validated, outcome={}) {
  const v=validated?.status==='VALIDATED_PUSH' ? validated : null;
  const q=v?.request, p=v?.provenance;
  const real=outcome.mode==='GITHUB_READONLY' && outcome.status==='CANARY_LOCAL_EFFECT' && v;
  const fixture=outcome.mode==='FIXTURE' && outcome.status==='COLLECTED_FIXTURE' && v;
  return {
    schema:'contaos.p0.actions-canary-receipt.v1', repository:REPO,
    mode:outcome.mode==='GITHUB_READONLY'?'GITHUB_READONLY':'FIXTURE',
    request_id:q?.request_id??null, mission_id:q?.mission_id??null,
    operation:q?.operation??null, environment:q?.environment??null,
    source_sha:q?.source_sha??null,source_pr:q?.source_pr??null,request_pr:q?.request_pr??null,
    authorization_ref:q?.authorization_ref??null,authorization_pr:outcome.authorizationPr??null,
    request_commit:p?.request_commit??null,tree:p?.tree??null,parents:p?.parents??null,
    run_id:p?.run_id??null,run_attempt:p?.run_attempt??null,job:p?.job??null,
    predecessor_checkpoint_ref:q?.predecessor_checkpoint_ref??null,
    request_sha256:p?.request_sha256??null,catalog_sha256:p?.catalog_sha256??null,
    result:real?'CANARY_LOCAL_EFFECT':fixture?'COLLECTED_FIXTURE':'BLOCKED',
    reason:real?'LOCAL_CODE_ONLY':fixture?'CODE_FIXTURE_ONLY':
      allowedReasons.has(outcome.reason)?outcome.reason:'UNVERIFIED_EVIDENCE',
    execution_allowed:false,certification:'NOT_CERTIFIED'
  };
}
async function get(path,token,fetcher) {
  demand(/^(?:branches\/main|rulesets\/[0-9]+|commits\/[0-9a-f]{40}|contents\/[A-Za-z0-9._/-]+)$/.test(path)
    && !path.includes('..'),'API_UNAVAILABLE');
  let r;
  try { r=await fetcher(API+path,{method:'GET',redirect:'error',signal:AbortSignal.timeout(8000),
    headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token,'X-GitHub-Api-Version':'2022-11-28'}}); }
  catch { throw new Denial('API_UNAVAILABLE'); }
  demand(r?.status===200 && !r.redirected && r.body?.getReader,'API_HTTP');
  const reader=r.body.getReader(),chunks=[]; let size=0;
  try {
    while(true) {
      const {done,value}=await reader.read(); if(done) break;
      size+=value.byteLength; demand(size<=2_000_000,'API_SIZE'); chunks.push(Buffer.from(value));
    }
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } finally { await reader.cancel().catch(()=>{}); }
}
function sameRules(r,e) {
  const one=t=>{ const a=r?.rules?.filter(x=>x.type===t)??[]; return a.length===1?a[0]:null; };
  const p=one('pull_request')?.parameters, s=one('required_status_checks')?.parameters;
  return r?.id===RULESET && r.enforcement==='active' && r.target==='branch' &&
    equal(r.conditions?.ref_name?.include,['~DEFAULT_BRANCH']) && equal(r.conditions?.ref_name?.exclude,[]) &&
    equal(r.bypass_actors,[]) && r.current_user_can_bypass==='never' &&
    !!one('deletion') && !!one('non_fast_forward') && p?.required_approving_review_count===e.approvals &&
    p.dismiss_stale_reviews_on_push===e.dismissStale && p.require_last_push_approval===e.lastPushApproval &&
    p.required_review_thread_resolution===e.reviewThreadResolution && s?.strict_required_status_checks_policy===true &&
    equal((s.required_status_checks??[]).map(x=>({name:x.context,appId:x.integration_id})),e.checks);
}
async function verified(input) {
  const v=validatePush(input);
  if(v.status!=='VALIDATED_PUSH') return {v,outcome:deny(new Denial(v.reason))};
  try {
    const {token,fetcher=fetch}=input;
    demand(typeof token==='string' && token.length>0 && token.length<=4096 && !/[\r\n]/.test(token) &&
      typeof fetcher==='function','API_UNAVAILABLE');
    const q=v.request,p=v.provenance;
    const c=await collectEvidence({request:q,repository:REPO,requestCommit:p.request_commit,token,fetcher});
    demand(c.status==='COLLECTED_FIXTURE' && c.executionAllowed===false && c.evidence,'UNVERIFIED_EVIDENCE');
    const e=c.evidence;
    demand(authorizeRequest(q,v.catalog,e).status==='VALIDATED_FIXTURE','AUTHORIZATION_UNPROVEN');
    demand(e.request.tree===p.tree && e.main.tree===p.tree && equal(e.request.parents,p.parents),'TREE_MISMATCH');
    // With strict up-to-date merges the trees of both reviewed heads must equal
    // their merge trees. Never infer this property merely from a PR number.
    for(const merge of [e.source,e.request]) {
      const head=await get('commits/'+merge.headSha,token,fetcher);
      demand(head?.sha===merge.headSha && head.commit?.tree?.sha===merge.tree,'TREE_MISMATCH');
    }
    const authPath=pathFor(q).replace('/requests/','/authorizations/');
    const authUrl=API+'contents/'+authPath+'?ref='+q.authorization_ref;
    let authResponse;
    try { authResponse=await fetcher(authUrl,{method:'GET',redirect:'error',signal:AbortSignal.timeout(8000),
      headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token,'X-GitHub-Api-Version':'2022-11-28'}}); }
    catch { throw new Denial('API_UNAVAILABLE'); }
    demand(authResponse?.status===200 && !authResponse.redirected && authResponse.body?.getReader,'API_HTTP');
    const ar=authResponse.body.getReader(),parts=[]; let bytes=0;
    try { while(true){const x=await ar.read();if(x.done)break;bytes+=x.value.byteLength;
      demand(bytes<=32768,'API_SIZE');parts.push(Buffer.from(x.value));} }
    finally { await ar.cancel().catch(()=>{}); }
    const af=JSON.parse(Buffer.concat(parts).toString('utf8'));
    const ab=Buffer.from(String(af.content??'').replace(/\r?\n/g,''),'base64');
    demand(af.path===authPath && af.type==='file' && af.encoding==='base64' && ab.length===af.size &&
      ab.length<=LIMIT && createHash('sha1').update('blob '+ab.length+'\0').update(ab).digest('hex')===af.sha,
      'AUTHORIZATION_UNPROVEN');
    const auth=JSON.parse(ab.toString('utf8'));
    demand(Number.isSafeInteger(auth.authorization_pr)&&auth.authorization_pr>0 &&
      auth.request_path===pathFor(q) && auth.expires_at===e.authorization.expiresAt &&
      Date.parse(auth.expires_at)>Date.now(),'AUTHORIZATION_UNPROVEN');
    const currentRules=await get('rulesets/'+RULESET,token,fetcher);
    demand(sameRules(currentRules,e.ruleset),'RULESET_CHANGED');
    const current=await get('branches/main',token,fetcher);
    demand(current?.protected===true && current.commit?.sha===p.request_commit,'STALE_MAIN');
    return {v,outcome:{status:'COLLECTED_FIXTURE',executionAllowed:false,authorizationPr:auth.authorization_pr}};
  } catch(err) {return {v,outcome:deny(err)};}
}
// This exported entrypoint, including injected fetchers, is always fixture-only.
export async function runTransport(input={}) {
  const {v,outcome}=await verified(input);
  return {status:outcome.status,executionAllowed:false,reason:outcome.reason,
    receipt:buildCanaryReceipt(v,{...outcome,mode:'FIXTURE'})};
}
function git(args,cwd,maxBuffer=1048576) {
  return execFileSync('git',['--no-optional-locks',...args],{cwd,maxBuffer,timeout:10000,
    stdio:['ignore','pipe','pipe'],env:{PATH:process.env.PATH??'/usr/bin:/bin',LANG:'C',
      GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',GIT_OPTIONAL_LOCKS:'0',
      GIT_TERMINAL_PROMPT:'0',GIT_NO_REPLACE_OBJECTS:'1'}});
}
export function readCheckout(cwd) {
  const head=git(['rev-parse','HEAD'],cwd).toString().trim();
  const tree=git(['rev-parse','HEAD^{tree}'],cwd).toString().trim();
  demand(sha(head)&&sha(tree),'CHECKOUT_IDENTITY');
  const header=git(['cat-file','-p',head],cwd).toString().split('\n\n',1)[0];
  const parents=header.split('\n').filter(x=>x.startsWith('parent ')).map(x=>x.slice(7));
  demand(parents.length===2&&parents.every(sha),'CHECKOUT_IDENTITY');
  const fields=git(['diff-tree','--no-commit-id','--name-status','-r','-z','--no-renames',parents[0],head],cwd)
    .toString('utf8').split('\0');
  demand(fields.length===3 && fields[0]==='A' && fields[2]==='' && validPath(fields[1]),'REQUEST_DIFF');
  const path=fields[1];
  const entry=git(['ls-tree','-z',head,'--',path],cwd).toString('utf8');
  const m=/^100644 blob ([0-9a-f]{40})\t([^\0]+)\0$/.exec(entry);
  demand(m&&m[2]===path,'REQUEST_FILE');
  function readBlob(spec) {
    const size=Number(git(['cat-file','-s',spec],cwd).toString().trim());
    demand(Number.isSafeInteger(size)&&size>0&&size<=LIMIT,'REQUEST_FILE');
    const b=git(['cat-file','blob',spec],cwd,LIMIT+1);
    const s=b.toString('utf8');demand(b.length===size&&Buffer.from(s).equals(b),'REQUEST_FILE');
    return s;
  }
  const body=readBlob(m[1]),catalog=readBlob(head+':'+ROOT+'P0_ACTIONS_CATALOG.json');
  return {checkout:{head,tree,parents,files:[{path,status:'A',mode:'100644',raw:body}]},catalog};
}
async function cli() {
  let v=null,outcome={status:'BLOCKED',reason:'RUNTIME_IDENTITY'};
  try {
    demand(process.argv.length===3 && process.argv[2]==='--collect' &&
      process.env.GITHUB_ACTIONS==='true' && process.env.GITHUB_SERVER_URL==='https://github.com' &&
      process.env.GITHUB_API_URL==='https://api.github.com' &&
      process.env.GITHUB_WORKFLOW_REF===REPO+'/'+WORKFLOW+'@refs/heads/main' &&
      process.env.GITHUB_WORKFLOW_SHA===process.env.GITHUB_SHA,'RUNTIME_IDENTITY');
    const eventPath=process.env.GITHUB_EVENT_PATH;
    demand(eventPath && statSync(eventPath).size<=1048576,'EVENT_IDENTITY');
    const event=JSON.parse(readFileSync(eventPath,'utf8'));
    const c={repository:process.env.GITHUB_REPOSITORY,eventName:process.env.GITHUB_EVENT_NAME,
      ref:process.env.GITHUB_REF,sha:process.env.GITHUB_SHA,before:event.before,
      runId:process.env.GITHUB_RUN_ID,attempt:process.env.GITHUB_RUN_ATTEMPT,job:process.env.GITHUB_JOB,event};
    const data=readCheckout(process.cwd());
    const result=await verified({context:c,...data,token:process.env.GITHUB_TOKEN,fetcher:fetch});
    v=result.v;outcome=result.outcome;
    if(outcome.status==='COLLECTED_FIXTURE') outcome={...outcome,status:'CANARY_LOCAL_EFFECT'};
  } catch(err){outcome=deny(err);}
  // No payload, token or unfiltered API output in the local artifact or logs.
  // The workflow uploads this directory in a separate step without token env.
  try {
    const dir=join(process.env.RUNNER_TEMP??'/nonexistent','p0-actions-canary');
    mkdirSync(dir,{mode:0o700});
    const body=raw(buildCanaryReceipt(v,{...outcome,mode:'GITHUB_READONLY'}));
    writeFileSync(join(dir,'receipt.json'),body,{flag:'wx',mode:0o600});
    writeFileSync(join(dir,'SHA256SUMS'),digest(body)+'  receipt.json\n',{flag:'wx',mode:0o600});
    console.log(outcome.status==='CANARY_LOCAL_EFFECT'?'CANARY_CODE_LOCAL_EFFECT_NOT_CERTIFIED':'CANARY_CODE_BLOCKED');
    process.exitCode=outcome.status==='CANARY_LOCAL_EFFECT'?0:1;
  } catch { console.error('CANARY_CODE_LOCAL_IO_BLOCKED');process.exitCode=1; }
}
if(process.argv[1] && pathToFileURL(resolve(process.argv[1])).href===import.meta.url) await cli();
