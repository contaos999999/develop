import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,chmodSync,existsSync,readdirSync,mkdtempSync,rmSync} from 'node:fs';
import {createHash,randomUUID,randomBytes} from 'node:crypto';
import {spawnSync,spawn} from 'node:child_process';
import {resolve,join,relative} from 'node:path';
import {tmpdir} from 'node:os';
import {createRequire} from 'node:module';
const sha40=/^[0-9a-f]{40}$/;
const sha64=/^[0-9a-f]{64}$/;
const PROJECT='gklhhhyosgasnyoxlrui',REPO='contaos999999/develop',URL=`https://${PROJECT}.supabase.co`;
let materialDeadline=null;
const privatePasswords=new Map();
const digest=b=>createHash('sha256').update(b).digest('hex');
function requireC(v,name){assert.ok(v,name);}
export function inputs(e){
 requireC(e.PROOF_MODE==='api_c13','only API C13 is activated; full UI requires its later BUILD');
 requireC(/^[1-9][0-9]{0,8}$/.test(e.FRONTEND_PR),'exact frontend PR');
 requireC(e.GITHUB_EVENT_NAME==='workflow_dispatch'&&e.GITHUB_REPOSITORY===REPO&&e.GITHUB_REF==='refs/heads/main','manual main only');
 requireC(sha40.test(e.TESTED_HEAD)&&sha40.test(e.FRONTEND_HEAD)&&e.GITHUB_SHA===e.TESTED_HEAD,'exact heads');
 for(const k of ['RESTORE_RUN_ID','DEPLOYMENT_RECEIPT_COMMENT_ID','EDGE_VERSION'])requireC(/^[1-9][0-9]{0,19}$/.test(e[k]),k);
 requireC(sha64.test(e.EDGE_SOURCE_SHA256)&&sha64.test(e.EDGE_BUNDLE_SHA256)&&/^[0-9a-f]{32}$/.test(e.NONCE),'hashes and own nonce');
 return {mode:e.PROOF_MODE,frontendPr:Number(e.FRONTEND_PR),head:e.TESTED_HEAD,frontend:e.FRONTEND_HEAD,restore:e.RESTORE_RUN_ID,comment:e.DEPLOYMENT_RECEIPT_COMMENT_ID,version:Number(e.EDGE_VERSION),source:e.EDGE_SOURCE_SHA256,bundle:e.EDGE_BUNDLE_SHA256,nonce:e.NONCE};
}
export function validateChecks(runs,head,restore){
 for(const name of ['ContaOS Zero-Drift','ContaOS Restore Isolado']){
  requireC(runs.some(r=>r.name===name&&r.head_sha===head&&r.head_branch==='main'&&r.head_repository?.full_name===REPO&&r.event==='push'&&r.status==='completed'&&r.conclusion==='success'&&(name!=='ContaOS Restore Isolado'||String(r.id)===restore)),`required main push ${name}`);
 }
}
export function validateGuardSteps(jobs){
 requireC(Array.isArray(jobs)&&jobs.length>0,'guard jobs present');
 const steps=jobs.filter(j=>j.conclusion==='success').flatMap(j=>j.steps??[]);
 for(const name of ['Context Gate — leitura obrigatória 4.1','Zero-Drift','Architecture Guard','SQL Security Guard','Migrations reproduzíveis','Historical HML source integrity','Segredos proibidos']){
  const found=steps.filter(s=>s.name===name);requireC(found.length===1&&found[0].status==='completed'&&found[0].conclusion==='success',`executed guard step ${name}`);
 }
}
export function validateReceipt(r,i,{phase='pre-proof',runId,materialFinishedAt,now=Date.now()}={}){
 const keys=['schema','proof_mode','backend_repo','frontend_repo','frontend_pr','backend_head','frontend_head','nonce','project','function_slug','version','verify_jwt','readback_equal','source_sha256','bundle_sha256','verified_at','phase',...(phase==='post-proof'?['run_id']:[])].sort();
 requireC(r&&JSON.stringify(Object.keys(r).sort())===JSON.stringify(keys),'strict receipt fields');
 requireC(r.schema==='contaos.copilot.deployment.v1'&&r.proof_mode===i.mode&&r.backend_repo===REPO&&r.frontend_repo==='contaos999999/contaos-hml-control'&&Number.isSafeInteger(r.frontend_pr)&&r.frontend_pr===i.frontendPr&&Number.isSafeInteger(r.version)&&r.backend_head===i.head&&r.frontend_head===i.frontend&&r.nonce===i.nonce&&r.project===PROJECT&&r.function_slug==='copilot-query'&&r.version===i.version&&r.verify_jwt===true&&r.readback_equal===true&&r.source_sha256===i.source&&r.bundle_sha256===i.bundle&&r.phase===phase,'exact source-readback receipt');
 const verified=Date.parse(r.verified_at);requireC(typeof r.verified_at==='string'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z$/.test(r.verified_at)&&Number.isFinite(verified)&&new Date(verified).toISOString().slice(0,19)===r.verified_at.slice(0,19)&&verified<=now&&now-verified<=900000,'receipt freshness at most 15 minutes');
 if(phase==='post-proof'){requireC(Number.isFinite(Date.parse(materialFinishedAt))&&verified>=Date.parse(materialFinishedAt),'post readback follows material completion');requireC(/^[1-9][0-9]{0,19}$/.test(String(runId))&&String(r.run_id)===String(runId),'post-proof exact run');}
}
export function validateComment(comment,receipt,i,options={}){
 const now=options.now??Date.now();requireC(comment.user?.login==='contaos9999'&&comment.issue_url===`https://api.github.com/repos/${REPO}/issues/138`&&comment.created_at===comment.updated_at,'immutable owner receipt in GATE138');
 const created=Date.parse(comment.created_at);requireC(Number.isFinite(created)&&created<=now&&now-created<=900000&&Date.parse(receipt.verified_at)<=created,'fresh immutable receipt');
 validateReceipt(receipt,i,{...options,now});
}
export function validateFrontendPR(pr,i){
 requireC(pr?.number===i.frontendPr&&pr.head?.sha===i.frontend&&pr.head?.repo?.full_name==='contaos999999/contaos-hml-control'&&pr.base?.repo?.full_name==='contaos999999/contaos-hml-control','exact same frontend PR repository and head');
 // Coordinator's immutable receipt records independent technical review.
 // GOV004 requires zero GitHub approvals; self-approval is not fabricated.
}
export function createLedger(){
 const rows={A:{total:0,events:[]},B:{total:0,events:[]}};
 return {reserve(actor,kind){requireC(Object.hasOwn(rows,actor),'no bypass actor');const r=rows[actor];requireC(r.total<(actor==='A'?30:6),'reservation budget exhausted');r.total++;r.events.push({kind,at:new Date().toISOString()});},snapshot:()=>structuredClone(rows)};
}
export async function admissionProof(ops,ledger){
 const reservations=[];let failure;
 try{
  for(let n=0;n<2;n++){ledger.reserve('A','controlled_concurrency');const v=await ops.reserve();requireC(v?.autorizado===true&&v.id_consulta&&v.token,'real controlled reservation');reservations.push(v);}
  const before=await ops.count(),r=await ops.ask();
  requireC(r.status===429&&r.data?.ok===false&&r.data?.codigo==='COPILOTO_LIMITE_CONCORRENCIA'&&Number(r.headers.get('retry-after'))>0,'exact third JWT concurrency denial');
  requireC(await ops.count()===before,'denied request made no reservation');
 }catch(err){failure=err;}
 const errors=[];for(const v of reservations){try{await ops.fail(v);}catch{errors.push('RESERVATION_RELEASE_FAILED');}}
 if(errors.length)throw Error('RESERVATION_RELEASE_FAILED');if(failure)throw failure;
 return {reserved:2,denied:1,released:2};
}
export function ownFixture(i,runId){
 requireC(/^[1-9][0-9]{0,19}$/.test(runId)&&/^[0-9a-f]{32}$/.test(i.nonce),'recoverable fixture provenance');
 const id=label=>{const h=digest(`${REPO}:${i.head}:${runId}:${i.nonce}:${label}`);return `${h.slice(0,8)}-${h.slice(8,12)}-4${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`;};
 const f={nonce:i.nonce,scope:'C-CHAT-HML',backend_head:i.head,frontend_head:i.frontend,run_id:runId,users:[],uploads:[]};
 for(const label of ['org','org_b','contract','contract_b','contractor','contractor_b'])f[label]=id(label);
 for(const profile of ['administrator','foreign','revoked','master'])f.users.push({profile,intent:id('intent:'+profile),email:`copilot-${i.nonce}-${profile}@example.invalid`});
 return f;
}
export function authRecognition(result,userId){
 if(!result.error){requireC(result.data?.user?.id===userId,'Auth confirms exact own user');return true;}
 requireC(result.error.name==='AuthApiError'&&[401,403].includes(result.error.status)&&!result.data?.user,'Auth rejects credential, not transport/provider failure');return false;
}
export function revokedSessionResult(authRecognizes,r){
 requireC(r.data?.ok===false&&r.status===(authRecognizes?403:401)&&r.data.codigo===(authRecognizes?'AUTH_ACESSO_NEGADO':'AUTH_SESSAO_INVALIDA'),'exact same-token revoked-session branch');
 return authRecognizes?'AUTH_RECOGNIZED_RLS_DENIED':'AUTH_REJECTED';
}
export function finishMaterial(report){
 requireC(report.checks.length>0&&report.checks.every(c=>c.passed===true)&&report.cleanup?.state==='QUARENTENA_VERIFICADA','complete material and own cleanup');
 report.material_finished_at=new Date().toISOString();report.state='PROVA_MATERIAL_OK_AGUARDA_READBACK_FINAL';report.global_complete=false;
}
export function parseSDKLock(text){
 const matches=[...text.matchAll(/"@supabase\/supabase-js":\s*\["@supabase\/supabase-js@(\d+\.\d+\.\d+)",[^\n]+?"(sha512-[A-Za-z0-9+/=]+)"\s*\]/g)];
 requireC(matches.length===1,'one approved SDK lock entry');return {version:matches[0][1],integrity:matches[0][2]};
}
export async function withinMaterialDeadline(ms,work){
 requireC(Number.isSafeInteger(ms)&&ms>0&&ms<=4800000,'material deadline bounded below job timeout');
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(Error('MATERIAL_DEADLINE')),ms);
 materialDeadline=controller;
 try{return await work(controller.signal);}finally{clearTimeout(timer);materialDeadline=null;}
}
export async function rateProof(ask,ledger){
 const start=Date.now();
 for(let n=0;n<6;n++){ledger.reserve('B','no_source_fallback');const r=await ask();requireC(r.status===200&&r.data?.ok===true&&Array.isArray(r.data.fontes)&&r.data.fontes.length===0,'six actual B fallback reservations');}
 requireC(Date.now()-start<55000,'rate calls fit same server minute window');
 const r=await ask();requireC(r.status===429&&r.data?.ok===false&&r.data.codigo==='COPILOTO_LIMITE_TAXA'&&Number(r.headers.get('retry-after'))>0,'exact seventh B rate denial');return {accepted:6,denied:1};
}
export function validateHistoryPage(data,session,reference){
 requireC(data?.ok===true&&data.sessao?.id===session&&data.sessao.data_referencia===reference&&Array.isArray(data.mensagens)&&data.mensagens.length<=50,'own history DTO');
 const allowed=['id','papel','conteudo','criado_em','fontes','conteudo_disponivel','motivo_indisponibilidade','incerteza','conflito_historico','baixa_confianca'];
 requireC(Object.keys(data).every(k=>['ok','sessao','mensagens','proximo_cursor'].includes(k)),'no internal history envelope');
 for(const m of data.mensagens){
  requireC(Object.keys(m).every(k=>allowed.includes(k))&&['usuario','assistente'].includes(m.papel)&&Array.isArray(m.fontes)&&typeof m.conteudo_disponivel==='boolean','public message fields only');
  for(const k of ['incerteza','conflito_historico','baixa_confianca'])requireC(m[k]===null||typeof m[k]==='boolean','strict persisted risk flags');
  requireC(m.conteudo_disponivel?typeof m.conteudo==='string':m.conteudo===null&&m.fontes.length===0,'redacted history cannot disclose content or sources');
 }
}
export async function orderedRace(ops){
 const pending=[];let results,failure;
 try{pending.push(Promise.resolve(ops.first()));pending[0].catch(()=>{});await ops.wait(1);pending.push(Promise.resolve(ops.second()));pending[1].catch(()=>{});await ops.wait(2);}
 catch(error){failure=error;}
 finally{try{await ops.release();}catch(error){failure??=error;}results=await Promise.allSettled(pending);}
 if(failure)throw failure;requireC(results.length===2&&results.every(r=>r.status==='fulfilled'),'both ordered contenders returned');return results.map(r=>r.value);
}
async function gh(path,e){
 const r=await fetch('https://api.github.com'+path,{headers:{Authorization:`Bearer ${e.GH_TOKEN}`,Accept:'application/vnd.github+json'},redirect:'error',signal:AbortSignal.timeout(20000)});
 requireC(r.ok,'GitHub read');return r.json();
}
async function gate(e){
 const i=inputs(e),task=JSON.parse(readFileSync('docs/tasks/active-task.json'));
 requireC(task.phase==='BUILD_HML_COPILOT_PROOF'&&task.database_test_fixtures_allowed===true&&task.storage_test_fixtures_allowed===true&&task.copilot_hml?.state==='HML_EXECUTION_AUTHORIZED'&&task.copilot_hml.scope==='OWN_FIXTURES_ONLY'&&task.copilot_hml.cleanup_authorized===true,'offline BUILD does not authorize fixtures');
 requireC(task.copilot_hml.max_actor_hour===30&&task.copilot_hml.max_ui_material_queries===24&&task.copilot_hml.max_c13_api_turns===3&&task.copilot_hml.max_controlled_reservations===2&&task.copilot_hml.max_fallbacks===1&&task.copilot_hml.max_owned_auth_users===4&&task.copilot_hml.max_owned_organizations===2,'versioned bounded operational budget');
 requireC(task.copilot_hml.readback_mode==='EXTERNAL_MCP_RECEIPTS','coordinator readback mode');
 requireC(digest(readFileSync('supabase/functions/copilot-query/index.ts'))===i.source,'local approved Edge hash');
 const main=await gh(`/repos/${REPO}/git/ref/heads/main`,e);requireC(main.object.sha===i.head,'live main CAS');
 const runs=[];
 for(let p=1;p<=5;p++){const data=await gh(`/repos/${REPO}/actions/runs?head_sha=${i.head}&per_page=100&page=${p}`,e);runs.push(...data.workflow_runs);if(data.workflow_runs.length<100)break;}
 validateChecks(runs,i.head,i.restore);
 const guard=runs.find(r=>r.name==='ContaOS Zero-Drift'&&r.head_sha===i.head&&r.event==='push'&&r.head_branch==='main'&&r.head_repository?.full_name===REPO&&r.conclusion==='success');
 validateGuardSteps((await gh(`/repos/${REPO}/actions/runs/${guard.id}/jobs?per_page=100`,e)).jobs);
 const jobs=(await gh(`/repos/${REPO}/actions/runs/${i.restore}/jobs?per_page=100`,e)).jobs;
 for(const name of ['reconstruir-banco-do-zero','prova-backup-dados-sinteticos-duas-instancias'])requireC(jobs.some(j=>j.name===name&&j.conclusion==='success'),`Restore job ${name}`);
 const comment=await gh(`/repos/${REPO}/issues/comments/${i.comment}`,e);
 i.receipt=JSON.parse(comment.body);validateComment(comment,i.receipt,i);
 validateFrontendPR(await gh(`/repos/contaos999999/contaos-hml-control/pulls/${i.frontendPr}`,e),i);
 const front=await gh(`/repos/contaos999999/contaos-hml-control/commits/${i.frontend}/check-runs`,e);
 requireC(front.check_runs.length>0&&front.check_runs.every(c=>c.head_sha===i.frontend&&c.status==='completed'&&c.conclusion==='success'),'frontend exact checks');
 requireC((await gh(`/repos/${REPO}/git/ref/heads/main`,e)).object.sha===i.head,'main advanced during gates');
 return i;
}
async function frontendSource(e,i,path){
 requireC(['src/integrations/supabase/client.ts','bun.lock'].includes(path),'bounded public provenance source');
 const file=await gh(`/repos/contaos999999/contaos-hml-control/contents/${path}?ref=${i.frontend}`,e);
 requireC(file.type==='file'&&file.encoding==='base64'&&file.size<2097152,'bounded exact frontend source');return Buffer.from(file.content,'base64').toString('utf8');
}
async function setupSDK(e,i){
 const lock=parseSDKLock(await frontendSource(e,i,'bun.lock')),dir=resolve(e.SDK_DIR);
 requireC(relative(resolve(e.RUNNER_TEMP),dir)&&!relative(resolve(e.RUNNER_TEMP),dir).startsWith('..'),'isolated SDK directory');mkdirSync(dir,{recursive:true,mode:0o700});
 writeFileSync(join(dir,'package.json'),JSON.stringify({private:true,dependencies:{'@supabase/supabase-js':lock.version}}));
 const npm=args=>requireC(spawnSync('npm',args,{cwd:dir,stdio:'pipe',timeout:180000}).status===0,'SDK dependency install');
 npm(['install','--package-lock-only','--ignore-scripts','--no-audit','--no-fund']);
 const npmLock=JSON.parse(readFileSync(join(dir,'package-lock.json')));requireC(npmLock.packages['node_modules/@supabase/supabase-js']?.integrity===lock.integrity,'SDK tarball integrity equals approved frontend lock');
 npm(['ci','--ignore-scripts','--no-audit','--no-fund']);writeFileSync(join(dir,'approved.json'),JSON.stringify({frontend:i.frontend,...lock}));
}
export async function sdkConstructor(dir){const {createClient}=createRequire(join(dir,'package.json'))('@supabase/supabase-js');requireC(typeof createClient==='function','approved SDK createClient export');return createClient;}
async function loadSDK(e,i,{cleanupOnly=false}={}){
 const dir=resolve(e.SDK_DIR),approved=JSON.parse(readFileSync(join(dir,'approved.json')));
 requireC(approved.frontend===i.frontend,'same approved frontend SDK');
 const pkg=JSON.parse(readFileSync(join(dir,'node_modules/@supabase/supabase-js/package.json')));requireC(pkg.version===approved.version,'installed approved SDK version');
 const createClient=await sdkConstructor(dir);
 const options={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{fetch:async(input,init={})=>{
  const target=new globalThis.URL(typeof input==='string'?input:input.url);requireC(target.origin===URL,'SDK fixed HML origin');
  return fetch(input,{...init,redirect:'error',signal:AbortSignal.any([AbortSignal.timeout(e.CLEANUP_MODE?10000:50000),...(!e.CLEANUP_MODE&&materialDeadline?[materialDeadline.signal]:[])])});
 }}};
 const admin=createClient(URL,e.AUTH_ADMIN_KEY,options);
 if(cleanupOnly)return {admin};
 e.SUPABASE_PUBLISHABLE_KEY=parsePublicClient(await frontendSource(e,i,'src/integrations/supabase/client.ts')).key;
 return {admin,createPublic:()=>createClient(URL,e.SUPABASE_PUBLISHABLE_KEY,options),version:approved.version};
}
function sql(e,text){
 if(!e.CLEANUP_MODE)materialDeadline?.signal.throwIfAborted();
 const u=new globalThis.URL(e.DATABASE_URL);requireC(u.username===`postgres.${PROJECT}`&&u.hostname.endsWith('.pooler.supabase.com'),'HML pooler only');
 const r=spawnSync('psql',[e.DATABASE_URL,'-X','-qAt','-v','ON_ERROR_STOP=1'],{input:text,encoding:'utf8',timeout:e.CLEANUP_MODE?10000:60000,maxBuffer:1048576});requireC(r.status===0,'database operation, details withheld');return r.stdout.trim();
}
const q=v=>"'"+String(v).replaceAll("'","''")+"'";
export async function cleanupCausal(f,ops){
 requireC(f.scope==='C-CHAT-HML'&&/^[0-9a-f]{32}$/.test(f.nonce)&&Array.isArray(f.users)&&f.users.length<=16,'own cleanup manifest');
 const result={state:'QUARENTENA_VERIFICADA',not_materialized:0,ambiguous:0,own_users:0,errors:[],recovery:[]};
 const attempt=async(code,fn)=>{try{return await fn();}catch{result.errors.push(code);return undefined;}};
 const owned=new Set();
 for(const u of f.users){
  const ids=await attempt('AUTH_RECOVERY_FAILED',()=>ops.recover(u.intent));
  if(ids===undefined)continue;
  if(!Array.isArray(ids)||ids.length>16){result.errors.push('AUTH_RECOVERY_INVALID');continue;}
  result.recovery.push({intent:u.intent,matches:ids.length});
  if(ids.length===0){result.not_materialized++;continue;}
  if(ids.length>1){result.ambiguous++;result.errors.push('AUTH_RECOVERY_AMBIGUOUS');}
  // Every returned identity must already have been scoped by nonce+intent in
  // recover(). A failure for one identity never skips the remaining cleanup.
  for(const id of ids){
   if(owned.has(id))continue;owned.add(id);
   for(const [name,code] of [['ban','AUTH_BAN_FAILED'],['memberships','MEMBERSHIP_REVOKE_FAILED'],['master','MASTER_REVOKE_FAILED'],['sessions','SESSION_REVOKE_FAILED']])await attempt(code,()=>ops[name](id));
  }
 }
 result.own_users=owned.size;
 result.own_orgs=await attempt('ORGANIZATION_QUARANTINE_FAILED',()=>ops.organizations());
 result.jobs=await attempt('OWN_JOB_QUARANTINE_FAILED',()=>ops.jobs());
 const verified=await attempt('CLEANUP_VERIFICATION_FAILED',()=>ops.verify([...owned]));
 if(verified!==true)result.errors.push('CLEANUP_NOT_VERIFIED');
 if(result.errors.length)result.state='CLEANUP_FAILED';
 return result;
}
async function api(e,path,{token,admin=false,method='POST',body,malformedAuth=false}={}){
 requireC(!malformedAuth||(!token&&!admin&&path==='/functions/v1/copilot-query'),'bounded malformed-header negative');
 requireC(path.startsWith('/auth/v1/')||path.startsWith('/rest/v1/')||path.startsWith('/functions/v1/'),'fixed project path');
 requireC(!admin||path.startsWith('/auth/v1/admin/users'),'Auth Admin restricted');
 const r=await fetch(URL+path,{method,headers:{apikey:admin?e.AUTH_ADMIN_KEY:e.SUPABASE_PUBLISHABLE_KEY,...(malformedAuth?{Authorization:'NotBearer invalid'}:token||admin?{Authorization:`Bearer ${admin?e.AUTH_ADMIN_KEY:token}`} :{}),'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)}),redirect:'error',signal:AbortSignal.any([AbortSignal.timeout(e.CLEANUP_MODE?10000:50000),...(!e.CLEANUP_MODE&&materialDeadline?[materialDeadline.signal]:[])])});
 let data;try{data=await r.json();}catch{data=null;}return {status:r.status,data,headers:r.headers};
}
function privateRoot(e){const root=resolve(e.CONTAOS_TEST_PRIVATE_DIR),base=resolve(e.RUNNER_TEMP);requireC(relative(base,root)&&!relative(base,root).startsWith('..'),'private runner directory');mkdirSync(root,{recursive:true,mode:0o700});chmodSync(root,0o700);return root;}
function save(root,name,value){const path=join(root,name);writeFileSync(path,JSON.stringify(value),{mode:0o600});chmodSync(path,0o600);}
async function prepare(e,i,root){
 const path=join(root,'fixture.json');requireC(!existsSync(path),'no fixture reuse');
 requireC(sql(e,`select not exists(select 1 from auth.users where raw_app_meta_data->>'scope'='C-CHAT-HML' and raw_app_meta_data->>'nonce'=${q(i.nonce)}) and not exists(select 1 from public.organizacoes where razao_social like ${q('0000 COPILOT '+i.nonce+'%')});`)==='t','fresh HML nonce');
 requireC(/^[1-9][0-9]{0,19}$/.test(e.GITHUB_RUN_ID),'own creation run');
 const f=ownFixture(i,e.GITHUB_RUN_ID);save(root,'fixture.json',f);
 // All deterministic scope+intent records exist before the first Auth call.
 for(const u of f.users){
  const password=randomBytes(32).toString('base64url')+'Aa1!';privatePasswords.set(u.profile,password);
  const r=await e.SDK.admin.auth.admin.createUser({email:u.email,password,email_confirm:true,app_metadata:{synthetic:true,scope:f.scope,nonce:f.nonce,intent:u.intent,backend_head:f.backend_head,frontend_head:f.frontend_head,run_id:f.run_id}});
  requireC(!r.error&&r.data?.user?.id,'own SDK Auth Admin identity');u.id=r.data.user.id;save(root,'fixture.json',f);
 }
 let s='begin;';
 for(const suffix of ['','_b'])s+=`insert into public.organizacoes(id,razao_social) values(${q(f['org'+suffix])},${q('0000 COPILOT '+i.nonce+suffix)});insert into public.contratantes(id,id_organizacao,razao_social) values(${q(f['contractor'+suffix])},${q(f['org'+suffix])},'Own synthetic source');insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values(${q(f['contract'+suffix])},${q(f['org'+suffix])},${q(f['contractor'+suffix])},${q('COPILOT-'+i.nonce+suffix)},'Synthetic educational document','2026-01-01');`;
 for(const u of f.users.filter(u=>u.profile!=='master'))s+=`insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values(${q(u.profile==='foreign'?f.org_b:f.org)},${q(u.id)},'administrador',true);`;
 const master=f.users.find(u=>u.profile==='master');s+=`insert into privado.administradores_master(id_usuario,motivo) values(${q(master.id)},'Own C-CHAT-HML ${i.nonce}');`;
 sql(e,s+'commit;');return f;
}
async function login(e,u){
 const client=e.SDK.createPublic(),r=await client.auth.signInWithPassword({email:u.email,password:privatePasswords.get(u.profile)});
 requireC(!r.error&&r.data?.session?.access_token&&r.data.user?.id===u.id,'real SDK Auth login');
 const token=r.data.session.access_token,claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString('utf8'));
 requireC(claims.sub===u.id&&/^[0-9a-f-]{36}$/.test(claims.session_id),'own real Auth session claim');
 requireC(sql(e,`select exists(select 1 from auth.sessions where id=${q(claims.session_id)} and user_id=${q(u.id)});`)==='t','server confirms SDK session');
 requireC(Number.isSafeInteger(claims.exp)&&claims.exp*1000>Date.now(),'legitimate unexpired SDK JWT');const algorithm=JSON.parse(Buffer.from(token.split('.')[0],'base64url').toString('utf8')).alg;return {client,token,sessionId:claims.session_id,user:u,expiresAt:claims.exp*1000,algorithm};
}
export function parsePublicClient(text){
 const urls=[...text.matchAll(/\bconst\s+SUPABASE_URL\s*=\s*["']([^"']+)["']\s*;/g)],keys=[...text.matchAll(/\bconst\s+SUPABASE_PUBLISHABLE_KEY\s*=\s*["']([^"']+)["']\s*;/g)];
 requireC(urls.length===1&&urls[0][1]===URL&&keys.length===1&&/^sb_publishable_[A-Za-z0-9_-]{10,256}$/.test(keys[0][1]),'fixed public client configuration');
 return {url:URL,key:keys[0][1]};
}
export function parseSurfaces(text){
 const block=text.match(/export const ROUTES = \[([\s\S]*?)\n\];/)?.[1];requireC(block,'versioned frontend surface manifest');
 const rows=[];
 for(const line of block.split('\n').map(x=>x.trim()).filter(Boolean)){
  const m=line.match(/^\{ id: "([A-Z0-9]+)", path: (.+?)(, public: true)?(, requiresDrawer: true)? \},$/);requireC(m,'static surface declaration');
  const path=m[2].split(/\s*\+\s*/).map(token=>{if(token==='UUID')return '00000000-0000-4000-8000-000000000001';const literal=token.match(/^"([^"\\]*)"$/);requireC(literal,'no executable frontend route expression');return literal[1];}).join('');
  requireC(path.startsWith('/')&&!path.includes('..'),'safe static route');
  rows.push({id:m[1],path,kind:m[4]?'drawer':m[3]||m[1]==='SYS04'?'access':'private'});
 }
 requireC(rows.length===29&&new Set(rows.map(r=>r.id)).size===29&&rows.filter(r=>r.kind==='private').length===24&&rows.filter(r=>r.kind==='access').length===4&&rows.filter(r=>r.kind==='drawer').length===1,'exact 24 private, four access and one drawer');
 requireC(['SYS01','SYS02','SYS03','SYS04'].every(id=>rows.some(r=>r.id===id&&r.kind==='access')),'four access surfaces');return rows;
}
export function expandSurface(row,f){
 const sentinel='00000000-0000-4000-8000-000000000001';let path=row.path;
 const ids=row.id==='V103'?[f.contractor]:row.id==='V111'?[f.contract,f.document?.id_documento]:row.id==='V120'?[f.competence,f.presentation]:path.startsWith('/competencias/')?[f.competence]:path.startsWith('/contratos/')?[f.contract]:[];
 for(const id of ids){if(!id)return {...row,path:null,reason:'OWN_MATERIAL_FIXTURE_NOT_AVAILABLE'};path=path.replace(sentinel,id);}
 requireC(!path.includes(sentinel),'no fabricated or foreign route identity');return {...row,path};
}
export function classifySurface(s){
 if(s.pageErrors>0||s.overflow>0)return 'FAIL_RUNTIME';
 if(!s.pathExact)return 'REDIRECTED_NOT_VERIFIED';
 if(s.blocked)return 'BLOCKED_NOT_VERIFIED';
 if(!s.heading)return 'CONTENT_NOT_VERIFIED';
 if(s.kind==='access')return s.chatVisible?'FAIL_CHAT_ON_ACCESS':'OBSERVED_ACCESS_NOT_CERTIFIED';
 if(s.kind==='drawer')return s.drawerVisible?'OBSERVED_DRAWER_NOT_CERTIFIED':'DRAWER_NOT_VERIFIED';
 if(!s.chatVisible)return 'CHAT_NOT_VERIFIED';
 return 'OBSERVED_READY_NOT_CERTIFIED';
}
async function cleanup(e,root){
 e={...e,CLEANUP_MODE:true};
 const f=existsSync(join(root,'fixture.json'))?JSON.parse(readFileSync(join(root,'fixture.json'))):ownFixture(inputs(e),e.GITHUB_RUN_ID);
 requireC(f.nonce===e.NONCE&&f.backend_head===e.TESTED_HEAD&&f.frontend_head===e.FRONTEND_HEAD&&f.run_id===e.GITHUB_RUN_ID,'cleanup creation provenance');
 const ownUsers=`select u.id from auth.users u where u.raw_app_meta_data->>'scope'='C-CHAT-HML' and u.raw_app_meta_data->>'nonce'=${q(f.nonce)} and u.raw_app_meta_data->>'backend_head'=${q(f.backend_head)} and u.raw_app_meta_data->>'frontend_head'=${q(f.frontend_head)} and u.raw_app_meta_data->>'run_id'=${q(f.run_id)}`;
 const ownOrgs=`select id from public.organizacoes where id in(${[f.org,f.org_b].filter(Boolean).map(q).join(',')||'null'}) and razao_social in(${q('0000 COPILOT '+f.nonce)},${q('0000 COPILOT '+f.nonce+'_b')})`;
 const ops={
  recover:async intent=>JSON.parse(sql(e,`select coalesce(json_agg(id),'[]') from auth.users where id in(${ownUsers}) and raw_app_meta_data->>'intent'=${q(intent)};`)),
  ban:async id=>{const r=await e.SDK.admin.auth.admin.updateUserById(id,{ban_duration:'876000h'});requireC(!r.error&&r.data?.user?.id===id,'own SDK Auth ban');},
  memberships:async id=>sql(e,`update public.vinculos_usuarios set ativo=false where id_usuario=${q(id)} and id_usuario in(${ownUsers});`),
  master:async id=>sql(e,`update privado.administradores_master set ativo=false where id_usuario=${q(id)} and id_usuario in(${ownUsers});`),
  sessions:async id=>sql(e,`delete from auth.sessions where user_id=${q(id)} and user_id in(${ownUsers});`),
  organizations:async()=>{const count=Number(sql(e,`select count(*) from public.organizacoes where id in(${ownOrgs});`));sql(e,`update public.organizacoes set situacao='inativa' where id in(${ownOrgs});`);return count;},
  jobs:async()=>quarantineJobs(e,f,ownOrgs),
  verify:async()=>sql(e,`select not exists(select 1 from auth.users where id in(${ownUsers}) and coalesce(banned_until,'-infinity'::timestamptz)<=clock_timestamp()) and not exists(select 1 from auth.sessions where user_id in(${ownUsers})) and not exists(select 1 from public.vinculos_usuarios where ativo and id_usuario in(${ownUsers})) and not exists(select 1 from privado.administradores_master where ativo and id_usuario in(${ownUsers})) and not exists(select 1 from public.organizacoes where id in(${ownOrgs}) and situacao<>'inativa');`)==='t',
 };
 const result=await cleanupCausal(f,ops);save(root,'cleanup.json',result);return result;
}
export async function cleanupQueues(queues,operation){
 let failures=0;for(const queue of queues){try{await operation(queue);}catch{failures++;}}
 requireC(failures===0,'OWN_QUEUE_CLEANUP_FAILED');
}
async function quarantineJobs(e,f,ownOrgs){
 const started=Date.now();let cancelled=0;
 do{
  await cleanupQueues(['documents','ocr','ai','embeddings'],async queue=>{
   const table='pgmq.q_'+queue;
   sql(e,`do $copilot_own$ declare j record; begin
    for j in select e.id,e.entidade_tipo,e.entidade_id,e.id_contrato,e.id_organizacao,e.message_id from public.execucoes_assincronas e join ${table} m on m.msg_id=e.message_id
    where e.fila=${q(queue)} and e.id_organizacao in(${ownOrgs}) and e.id_contrato in(${[f.contract,f.contract_b].filter(Boolean).map(q).join(',')||'null'}) and e.status in('enfileirado','falhou') and m.message->>'id_organizacao'=e.id_organizacao::text and m.message->>'id_contrato'=e.id_contrato::text for update of e,m
    loop
     perform pgmq.delete(${q(queue)},j.message_id);
     update public.execucoes_assincronas set status='cancelado',erro_codigo='FIXTURE_QUARANTINE',concluido_em=clock_timestamp() where id=j.id and status in('enfileirado','falhou');
     if j.entidade_tipo='versao_documento' then update public.processamentos_documento set status='cancelado',erro_codigo='FIXTURE_QUARANTINE',concluido_em=clock_timestamp() where id_versao_documento=j.entidade_id and id_organizacao=j.id_organizacao and id_contrato=j.id_contrato and etapa=${q(queue)} and status in('pendente','falhou');end if;
    end loop;end $copilot_own$;`);
  });
  const state=JSON.parse(sql(e,`select json_build_object('active_jobs',(select count(*) from public.execucoes_assincronas where id_organizacao in(${ownOrgs}) and status in('enfileirado','processando','falhou')),'processing',(select count(*) from public.processamentos_documento where id_organizacao in(${ownOrgs}) and status in('pendente','processando')),'cancelled',(select count(*) from public.execucoes_assincronas where id_organizacao in(${ownOrgs}) and status='cancelado'),'active_consultations',(select count(*) from public.consultas_semanticas where id_organizacao in(${ownOrgs}) and status='processando' and filtros#>>'{copilot,namespace}'='c_chat_v1' and(filtros#>>'{copilot,expires_at}')::timestamptz>clock_timestamp()),'queue_messages',${['documents','ocr','ai','embeddings'].map(x=>`(select count(*) from pgmq.q_${x} where message->>'id_organizacao' in(select id::text from public.organizacoes where id in(${ownOrgs})))`).join('+')});`));
  cancelled=state.cancelled;
  if(state.active_jobs===0&&state.processing===0&&state.queue_messages===0&&state.active_consultations===0)return {active_jobs:0,cancelled_jobs:cancelled};
  await new Promise(r=>setTimeout(r,1000));
 }while(Date.now()-started<300000);
 throw Error('Own job quarantine incomplete');
}
async function document(e,f,token,root){
 const bytes=Buffer.from(`Documento sintético do ContaOS, sem dados pessoais. O relatório mensal deve conter a relação de despesas e comprovantes. Marcador ${f.nonce}.`),name=`copilot-${f.nonce}.txt`;
 const signed=await api(e,'/functions/v1/storage-sign-upload',{token,body:{id_organizacao:f.org,id_contrato:f.contract,nome_arquivo:name,mime:'text/plain',tamanho:bytes.length}});
 requireC(signed.status===200&&signed.data?.ok&&signed.data.bucket==='contaos-documentos','official upload signing');
 const u=new globalThis.URL(signed.data.signed_url);requireC(u.origin===URL&&u.pathname.startsWith(`/storage/v1/object/upload/sign/contaos-documentos/${f.org}/uploads/`)&&u.pathname.endsWith('/'+name)&&[...u.searchParams.keys()].join(',')==='token','own signed upload');
 f.uploads.push({name,path:signed.data.path,sha256:digest(bytes)});save(root,'fixture.json',f);
 const put=await fetch(u,{method:'PUT',body:bytes,headers:{apikey:e.SUPABASE_PUBLISHABLE_KEY,'Content-Type':'text/plain','x-upsert':'false'},redirect:'error',signal:AbortSignal.timeout(30000)});requireC([200,201].includes(put.status),'physical upload');
 const confirmed=await api(e,'/rest/v1/rpc/confirmar_upload_arquivo',{token,body:{p_id_organizacao:f.org,p_id_contrato:f.contract,p_path:signed.data.path,p_nome_original:name,p_mime:'text/plain',p_tamanho:bytes.length,p_sha256:digest(bytes),p_origem:'upload_usuario'}});requireC(confirmed.status===200&&typeof confirmed.data==='string','official confirm upload');
 const created=await api(e,'/rest/v1/rpc/criar_documento_contrato_completo',{token,body:{p_id_contrato:f.contract,p_tipo:'outro',p_titulo:'Own copilot source '+f.nonce,p_categoria:'original',p_vigencia_inicio:'2026-01-01',p_vigencia_fim:null,p_observacoes:'Synthetic own source',p_id_arquivo:confirmed.data,p_chave_idempotencia:randomUUID()}});
 requireC(created.status===200&&created.data?.id_versao&&created.data?.id_job,'official create document');f.document=created.data;save(root,'fixture.json',f);
 const start=Date.now();
 while(Date.now()-start<300000){
  const state=JSON.parse(sql(e,`select json_build_object('ready',privado.copilot_versao_elegivel(${q(f.document.id_versao)},${q(f.org)},${q(f.contract)},null),'fragments',(select count(*) from public.fragmentos_documento where id_versao_documento=${q(f.document.id_versao)} and embedding is not null));`));
  if(state.ready&&state.fragments>0)return;
  await new Promise(r=>setTimeout(r,2000));
 }
 throw Error('own normal worker not ready');
}
// Inherited full-UI groundwork is unreachable in this API-only BUILD.
// It does not produce screenshots or visual certification in api_c13.
async function browserProof(e,f,root,report){
 const front=resolve(e.FRONTEND_DIR);requireC(sha40.test(e.FRONTEND_HEAD),'frontend immutable');
 requireC(spawnSync('git',['-C',front,'rev-parse','HEAD'],{encoding:'utf8'}).stdout.trim()===e.FRONTEND_HEAD,'frontend checkout hash');
 const module=resolve(e.PLAYWRIGHT_MODULE);requireC(module.startsWith(resolve(e.RUNNER_TEMP)+'/'),'pinned isolated browser module');const {chromium}=await import(module);
 const browserEnv=Object.fromEntries(['PATH','HOME','TMPDIR','LANG'].filter(k=>e[k]).map(k=>[k,e[k]]));
 const browser=await chromium.launch({headless:true,env:browserEnv});
 try{
  const context=await browser.newContext({baseURL:'http://127.0.0.1:4173',viewport:{width:1440,height:1000}}),page=await context.newPage(),u=f.users.find(u=>u.profile==='administrator');
  // No administrative environment, initScript, storageState or browser traces.
  await page.goto('/login');await page.locator('input[type=email]').fill(u.email);await page.locator('input[type=password]').fill(u.password);await page.getByRole('button',{name:/^Entrar$/i}).click();
  await page.waitForURL(url=>!url.pathname.startsWith('/login'),{timeout:30000});
  if(new globalThis.URL(page.url()).pathname==='/selecionar-organizacao'){await page.getByRole('button',{name:'Continuar',exact:true}).click();await page.waitForURL(url=>url.pathname==='/');}
  await page.goto(`/contratos/${f.contract}`);await page.getByRole('button',{name:'Consultar copiloto',exact:true}).click();
  await page.getByLabel('Sua pergunta',{exact:true}).fill('Quais comprovantes devem acompanhar o relatório mensal?');
  const response=page.waitForResponse(r=>r.url()===URL+'/functions/v1/copilot-query'&&r.request().method()==='POST');
  await page.getByRole('button',{name:'Enviar pergunta',exact:true}).focus();await page.keyboard.press('Enter');const r=await response;requireC(r.status()===200,'real browser chat');const data=await r.json();requireC(data.ok&&data.fontes?.length>0,'real browser sources');
  await page.getByText(/Fontes da resposta/).first().click();await page.getByRole('log').getByText(/F1:/).first().waitFor();
  report.checks.push({name:'REAL_UI_LOGIN_CHAT_SOURCES_KEYBOARD',passed:true});
  await captureMatrix(browser,page,front,f,report);
  report.limits.push('The 232-case visual matrix navigates real surfaces without submitting one query per screenshot. No claim of manual WCAG, contextual follow-up, history or reload persistence.');
 }finally{await browser.close();}
}
async function captureMatrix(browser,privatePage,front,f,report){
 const routes=parseSurfaces(readFileSync(join(front,'scripts/testc/visual-audit.mjs'),'utf8'));
 const tree=readFileSync(join(front,'src/routeTree.gen.ts'),'utf8').match(/export interface FileRoutesByFullPath \{([\s\S]*?)\n\}/)?.[1];requireC(tree,'actual route tree');
 const normalize=path=>path.replaceAll('00000000-0000-4000-8000-000000000001',':id').replace(/\$[A-Za-z]+/g,':id');
 const actual=[...tree.matchAll(/'([^']+)': typeof/g)].map(m=>normalize(m[1])).sort();const canonical=routes.filter(r=>r.kind!=='drawer').map(r=>normalize(r.path)).sort();
 requireC(actual.length===28&&JSON.stringify(actual)===JSON.stringify(canonical),'versioned surface matrix equals real route tree');
 report.matrix={expected:{private:192,access:32,drawer:8,total:232},rows:[]};mkdirSync('copilot-proof/screenshots',{recursive:true});
 for(const raw of routes){
  const item=expandSurface(raw,f);let page=privatePage,publicContext=null,pageErrors=0,loaded=false;
  const onError=()=>{pageErrors++;};
  try{
   if(item.kind==='access'&&item.id!=='SYS04'){publicContext=await browser.newContext({baseURL:'http://127.0.0.1:4173',viewport:{width:1440,height:1000}});page=await publicContext.newPage();}
   page.on('pageerror',onError);
   if(item.path){await page.goto(item.path);await page.getByRole('heading',{level:1}).first().waitFor({timeout:15000});loaded=true;}
   if(item.kind==='drawer'&&loaded){
    const open=page.getByRole('button',{name:/^Abrir requisito/}).first();
    if(await open.count()&&await open.isEnabled()){await open.focus();await page.keyboard.press('Enter');await page.getByRole('dialog').filter({has:page.getByRole('heading',{name:'Detalhe do requisito',exact:true})}).waitFor({timeout:10000});}
   }
  }catch{/* Preserve the missing/blocked surface as a record, never a PASS. */}
  for(const theme of ['light','dark'])for(const width of [1440,1280,768,390]){
   materialDeadline?.signal.throwIfAborted();
   const row={id:item.id,kind:item.kind,width,theme,fixture_kind:'OWN_CANONICAL',outcome:'NOT_VERIFIED',path:item.path};
   try{
    if(!item.path){row.outcome='OWN_MATERIAL_FIXTURE_NOT_AVAILABLE';row.reason=item.reason;report.matrix.rows.push(row);continue;}
    await page.setViewportSize({width,height:1000});await page.emulateMedia({colorScheme:theme});
    // Theme only, matching canonical Teste C. No Auth or backend state injection.
    await page.evaluate(dark=>document.documentElement.classList.toggle('dark',dark),theme==='dark');
    await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
    const text=await page.locator('body').innerText();
    const alerts=await page.getByRole('alert').allTextContents();
    const chat=page.getByRole('button',{name:/^(Consultar|Fechar) copiloto$/});const chatCount=await chat.count();
    const state={kind:item.kind,pathExact:new globalThis.URL(page.url()).pathname===item.path,heading:loaded&&(await page.getByRole('heading',{level:1}).count())>0,blocked:/acesso negado|sem permissão|não (?:tem|possui) acesso|não encontrad[oa]|não foi possível|sessão expirada|indisponível para|liberação bloqueada/i.test(text)||alerts.some(t=>/erro|falh|negad|bloquead|inválid|expirad/i.test(t)),pageErrors,chatVisible:chatCount===1&&await chat.first().isVisible(),overflow:await page.evaluate(()=>Math.max(0,document.documentElement.scrollWidth-window.innerWidth)),drawerVisible:item.kind==='drawer'&&(await page.getByRole('heading',{name:'Detalhe do requisito',exact:true}).count())===1};
    row.observed=state;row.outcome=classifySurface(state);
    if(item.kind==='private'&&state.chatVisible&&!state.blocked){
     const toggle=page.getByRole('button',{name:'Consultar copiloto',exact:true});if(await toggle.count())await toggle.click();
     const panel=page.getByRole('region',{name:'Copiloto do contrato'});row.chat_panel=await panel.count()===1&&await panel.isVisible();
     if(!row.chat_panel)row.outcome='CHAT_PANEL_NOT_VERIFIED';
     // Select own RLS contract on non-contract routes, without sending a query.
     const selection=page.getByLabel('Contrato da consulta',{exact:true});if(await selection.count())await selection.selectOption(f.contract);
    }
    const name=`${item.id}-${width}-${theme}.png`;await page.screenshot({path:'copilot-proof/screenshots/'+name});row.screenshot='screenshots/'+name;row.sha256=digest(readFileSync('copilot-proof/screenshots/'+name));
   }catch{row.outcome='FAIL_CAPTURE';}
   report.matrix.rows.push(row);
  }
  page.off('pageerror',onError);if(publicContext)await publicContext.close();
 }
 requireC(report.matrix.rows.length===232&&new Set(report.matrix.rows.map(r=>`${r.id}:${r.width}:${r.theme}`)).size===232,'complete 232-case enumeration');
 report.limits.push('Presentation receipt and V117 drawer require their own material authorized fixtures; absent content, blocking/error and missing fixtures remain unverified, never passed merely because chat is present.');
}
async function holdOwnSession(e,f,actor,session){
 const child=spawn('psql',[e.DATABASE_URL,'-X','-qAt','-v','ON_ERROR_STOP=1'],{stdio:['pipe','pipe','pipe']});
 let output='',pid,settled=false;const timer=setTimeout(()=>child.kill('SIGTERM'),20000);
 child.stderr.on('data',()=>{});
 const ended=new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>{settled=true;clearTimeout(timer);code===0?resolve():reject(Error('OWN_LOCK_PROCESS_FAILED'));});});ended.catch(()=>{});
 const ready=new Promise((resolve,reject)=>{
  child.stdout.on('data',chunk=>{output+=chunk.toString();if(output.length>4096){child.kill('SIGTERM');reject(Error('LOCK_OUTPUT_BOUND'));}if(output.includes('COPILOT_LOCK_READY')){pid=Number(output.split('\n').find(line=>/^[1-9][0-9]*$/.test(line)));requireC(Number.isSafeInteger(pid),'own blocker PID');resolve();}});
  child.on('exit',()=>{if(!output.includes('COPILOT_LOCK_READY'))reject(Error('LOCK_NOT_ACQUIRED'));});child.on('error',reject);
 });
 child.stdin.write(`begin;select pg_backend_pid();select id from public.sessoes_copiloto where id=${q(session)} and id_organizacao=${q(f.org)} and id_contrato=${q(f.contract)} and criado_por=${q(actor.user.id)} for update;select 'COPILOT_LOCK_READY';\n`);
 await ready;
 return {wait:async count=>{for(let n=0;n<100;n++){
  materialDeadline?.signal.throwIfAborted();requireC(!settled,'own row blocker alive');
  const blocked=Number(sql(e,`with recursive waiting(pid) as(select a.pid from pg_stat_activity a where ${pid}=any(pg_blocking_pids(a.pid)) union select a.pid from pg_stat_activity a join waiting w on w.pid=any(pg_blocking_pids(a.pid))) select count(distinct pid) from waiting;`));
  if(blocked>=count)return;await new Promise(r=>setTimeout(r,50));
 }throw Error('OWN_CONTENDERS_NOT_QUEUED');},release:async()=>{if(!settled)child.stdin.end('commit;\n');await ended;}};
}
async function closeFinalizerProof(e,f,actor,post,eligible){
 const rows=[];
 for(const closeFirst of [true,false]){
  const session=randomUUID();sql(e,`insert into public.sessoes_copiloto(id,id_organizacao,id_contrato,titulo,escopo,status,criado_por) values(${q(session)},${q(f.org)},${q(f.contract)},'synthetic_locktest','{"data_referencia":null}'::jsonb,'ativa',${q(actor.user.id)});`);
  const reserved=await e.SDK.admin.rpc('worker_reservar_consulta_copiloto',{p_id_organizacao:f.org,p_id_contrato:f.contract,p_id_usuario:actor.user.id,p_texto:'synthetic_locktest: no provider inference',p_filtros:{session_id:actor.sessionId,data_referencia:null,ids_fragmentos:eligible,ids_precedentes:[]},p_modelo:'synthetic_locktest'});
  requireC(!reserved.error&&reserved.data?.autorizado===true,'own lock-test reservation');let completed=false;
  try{
   const blocker=await holdOwnSession(e,f,actor,session);
   const close=()=>post(actor,{action:'encerrar_sessao',id_contrato:f.contract,id_sessao:session,data_referencia:null});
   const finish=()=>e.SDK.admin.rpc('worker_concluir_consulta_copiloto',{p_id_consulta:reserved.data.id_consulta,p_token:reserved.data.token,p_id_sessao:session,p_retorno:{conteudo:'Synthetic serialization evidence only; no inference.',provedor:'supabase',modelo:'synthetic_locktest_no_provider',prompt_versao:'synthetic_locktest',incerteza:true,conflito_historico:false,baixa_confianca:true},p_fontes:[]});
   const result=await orderedRace({first:closeFirst?close:finish,second:closeFirst?finish:close,wait:blocker.wait,release:blocker.release});
   const c=result[closeFirst?0:1],final=result[closeFirst?1:0];
   requireC(c.status===200&&c.data?.ok===true&&c.data.status==='encerrada','real API close committed');
   const persisted=JSON.parse(sql(e,`select json_build_object('status',(select status from public.sessoes_copiloto where id=${q(session)}),'messages',(select count(*) from public.mensagens_copiloto where id_sessao=${q(session)} and papel='assistente'),'returns',(select count(*) from public.retornos_modelo where id_consulta=${q(reserved.data.id_consulta)}));`));
   if(closeFirst)requireC(final.status===403&&final.error?.code==='42501'&&persisted.messages===0&&persisted.returns===0,'close-first prevents publication atomically');
   else{requireC(!final.error&&final.data?.id_mensagem&&persisted.messages===1&&persisted.returns===1,'finalizer-first publishes exactly once then closes');completed=true;}
   requireC(persisted.status==='encerrada','same own session remains closed');rows.push({order:closeFirst?'CLOSE_FIRST':'FINALIZER_FIRST',queued_connections:2,...persisted,label:'SYNTHETIC_LOCKTEST_NO_PROVIDER',chat_return_id:final.data?.id_retorno??null,chat_message_id:final.data?.id_mensagem??null});
  }finally{
   if(!completed){const released=await e.SDK.admin.rpc('worker_falhar_consulta_copiloto',{p_id_consulta:reserved.data.id_consulta,p_token:reserved.data.token,p_codigo:'FALHA_RECUPERACAO'});requireC(!released.error&&released.data===true,'own incomplete lock-test reservation released');}
  }
 }
 return {actor:'OWN_REVOKED_FIXTURE_BEFORE_REVOCATION',reservations:2,provider_calls:0,rows};
}
export function canonicalFunctionBody(source,name){
 requireC(['privado.rbac_permite','privado.consultar_permissoes_efetivas','public.consultar_permissoes_efetivas'].includes(name),'closed permission functions');
 const start=source.indexOf('create function '+name+'(');requireC(start>=0,'canonical function exists');const suffix=source.slice(start),body=suffix.match(/^[\s\S]*?\bas \$\$([\s\S]*?)\$\$;/i)?.[1];requireC(typeof body==='string','canonical body delimiter');return body;
}
export function rawSDKResult(result,controlId=null){
 requireC(result.status===200&&result.error===null&&Array.isArray(result.data),'raw SDK SELECT succeeds as array; permission/gateway errors are not privacy proof');
 if(controlId===null){requireC(result.data.length===0,'raw chat rows are not visible');return;}
 requireC(result.data.length===1&&result.data[0].id===controlId&&result.data[0].resposta?.marcador==='SYNTHETIC_RLS_CONTROL'&&result.data[0].resposta?.conteudo==='Controle sintético de visibilidade, sem inferência.'&&Array.isArray(result.data[0].fontes)&&result.data[0].fontes.length===0,'same-contract non-chat visibility preserved');
}
async function prepareRawControl(e,f,first,serialization,root){
 const raw=JSON.parse(sql(e,`select json_build_object('message_id',m.id,'return_id',r.id,'session_id',m.id_sessao,'source_ids',(select coalesce(json_agg(s.id),'[]') from public.fontes_resposta_copiloto s where s.id_mensagem=m.id and s.id_organizacao=${q(f.org)} and s.id_contrato=${q(f.contract)})) from public.mensagens_copiloto m join public.retornos_modelo r on r.id=m.id_retorno_modelo where m.id=${q(first.id_mensagem)} and m.id_consulta_semantica=${q(first.id_consulta)} and m.id_sessao=${q(first.id_sessao)} and m.id_organizacao=${q(f.org)} and m.id_contrato=${q(f.contract)};`));
 requireC(raw.message_id===first.id_mensagem&&raw.session_id===first.id_sessao&&raw.return_id&&raw.source_ids.length>0,'raw target IDs originate in actual positive OpenAI response');
 const generic=serialization.rows.find(r=>r.order==='FINALIZER_FIRST');requireC(generic?.chat_return_id,'own generic synthetic chat lineage exists');raw.generic_chat_return_id=generic.chat_return_id;
 // This record tests existing non-chat SELECT only. It is never a provider,
 // document-worker, analysis or Trilha B positive certification claim.
 f.nonchat_control=randomUUID();save(root,'fixture.json',f);
 sql(e,`insert into public.retornos_modelo(id,id_organizacao,id_contrato,provedor,modelo,prompt_versao,resposta,fontes,status) values(${q(f.nonchat_control)},${q(f.org)},${q(f.contract)},'supabase','synthetic_locktest_no_provider','synthetic_locktest',${q(JSON.stringify({marcador:'SYNTHETIC_RLS_CONTROL',conteudo:'Controle sintético de visibilidade, sem inferência.',fixture_scope:f.scope,nonce:f.nonce,run_id:f.run_id,backend_head:f.backend_head,frontend_head:f.frontend_head}))}::jsonb,'[]'::jsonb,'concluido');`);
 requireC(sql(e,`select a.modelo=b.modelo and a.prompt_versao=b.prompt_versao from public.retornos_modelo a join public.retornos_modelo b on b.id=${q(f.nonchat_control)} where a.id=${q(generic.chat_return_id)} and a.id_organizacao=${q(f.org)} and a.id_contrato=${q(f.contract)};`)==='t','chat/non-chat share exact generic model and prompt, not visibility');
 raw.nonchat_control_id=f.nonchat_control;f.raw_ids=raw;save(root,'fixture.json',f);return raw;
}
async function rawSDKProof(actors,f,raw,phase){
 const rows=[];
 for(const [actor,label] of actors){
  requireC(authRecognition(await actor.client.auth.getUser(actor.token),actor.user.id),'raw privacy actor has genuinely valid SDK Auth');
  const scoped=table=>actor.client.from(table).select(table==='retornos_modelo'?'id,resposta,fontes':table==='mensagens_copiloto'?'id,conteudo':'id,trecho,fonte_id').eq('id_organizacao',f.org).eq('id_contrato',f.contract);
  // Preserve a positive non-chat read through the very same JWT, role, tenant,
  // contract and table. A broad denial cannot pass these privacy assertions.
  rawSDKResult(await scoped('retornos_modelo').eq('id',raw.nonchat_control_id),raw.nonchat_control_id);
  rawSDKResult(await scoped('retornos_modelo').in('id',[raw.return_id,raw.generic_chat_return_id]));
  rawSDKResult(await scoped('mensagens_copiloto').eq('id_sessao',raw.session_id));
  rawSDKResult(await scoped('fontes_resposta_copiloto').in('id',raw.source_ids));
  rawSDKResult(await actor.client.from('retornos_modelo').select('id,resposta,fontes,mensagens_copiloto(id,conteudo,fontes_resposta_copiloto(id,trecho))').eq('id_organizacao',f.org).eq('id_contrato',f.contract).eq('id',raw.return_id));
  const embedded=await actor.client.from('sessoes_copiloto').select('id,raw_messages:mensagens_copiloto(id,conteudo,retornos_modelo(id,resposta,fontes),fontes_resposta_copiloto(id,trecho))').eq('id',raw.session_id).eq('id_organizacao',f.org).eq('id_contrato',f.contract);
  requireC(embedded.status===200&&embedded.error===null&&Array.isArray(embedded.data),'raw session embed is a successful array read');
  if(label==='OWNER')requireC(embedded.data.length===1&&embedded.data[0].id===raw.session_id&&Array.isArray(embedded.data[0].raw_messages)&&embedded.data[0].raw_messages.length===0,'own session metadata preserved but raw child chat denied');
  else requireC(embedded.data.length===0,'same-org peer and Master cannot read other session metadata or embed');
  rows.push({phase,actor:label,auth_valid:true,raw_tables:['retornos_modelo','mensagens_copiloto','fontes_resposta_copiloto'],raw_status:200,raw_rows:0,embeds_verified:true,nonchat_status:200,nonchat_rows:1,control_label:'SYNTHETIC_RLS_CONTROL'});
 }
 return rows;
}
async function materialAPI(e,i,root,report){
 const expected=readdirSync('supabase/migrations').filter(n=>/^[0-9]{14}_.+\.sql$/.test(n)).map(n=>n.slice(0,14)).sort();
 requireC(JSON.stringify(JSON.parse(sql(e,'select json_agg(version order by version) from supabase_migrations.schema_migrations;')))===JSON.stringify(expected)&&expected.includes('20261108232731'),'exact migration history; runner never applies SQL');
 const f=await prepare(e,i,root),sessions={};for(const u of f.users)sessions[u.profile]=await login(e,u);
 const a=sessions.administrator,b=sessions.foreign,rev=sessions.revoked,master=sessions.master,ledger=createLedger();
 const check=(name,passed)=>{report.checks.push({name,passed});requireC(passed,name);};
 const counts=()=>JSON.parse(sql(e,`select json_build_object('reservations',(select count(*) from public.consultas_semanticas where id_organizacao in(${q(f.org)},${q(f.org_b)})),'returns',(select count(*) from public.retornos_modelo where id_organizacao in(${q(f.org)},${q(f.org_b)})),'sources',(select count(*) from public.fontes_resposta_copiloto where id_organizacao in(${q(f.org)},${q(f.org_b)})),'messages',(select count(*) from public.mensagens_copiloto where id_organizacao in(${q(f.org)},${q(f.org_b)})));`));
 const sameCounts=(x,y)=>JSON.stringify(x)===JSON.stringify(y);
 const post=(actor,body)=>api(e,'/functions/v1/copilot-query',{token:actor.token,body});
 const body={id_contrato:f.contract,data_referencia:null};
 const deny=async(name,actor,payload,status,code)=>{const before=counts(),r=await post(actor,payload);check(name,r.status===status&&r.data?.ok===false&&r.data.codigo===code&&sameCounts(before,counts()));};
 const ask=async(actor,payload,kind)=>{ledger.reserve(actor===b?'B':'A',kind);return post(actor,{...payload,action:'perguntar'});};
 await document(e,f,a.token,root);check('OFFICIAL_UPLOAD_NORMAL_WORKER',true);
 for(const origin of ['http://127.0.0.1:4173','https://scope-and-approval-keeper.lovable.app','https://contaos-41-hml.vercel.app','https://untrusted.invalid']){
  const r=await fetch(URL+'/functions/v1/copilot-query',{method:'OPTIONS',headers:{Origin:origin,'Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'authorization,apikey,content-type,x-client-info'},redirect:'error',signal:AbortSignal.any([AbortSignal.timeout(20000),materialDeadline.signal])});
  check('CORS_'+(origin.includes('untrusted')?'DENIED':origin),origin.includes('untrusted')?r.status===403&&r.headers.get('access-control-allow-origin')===null:r.status===204&&r.headers.get('access-control-allow-origin')===origin);
 }
 const first=await ask(a,{...body,pergunta:'Vou chamar esta revisão de Plano Aurora. Quais comprovantes devem acompanhar o relatório mensal?'},'c13_initial');
 check('AUTHORIZED_OPENAI_SOURCES',first.status===200&&first.data?.ok===true&&first.data.fontes?.length>0&&/\bF1\b/.test(first.data.resposta));
 const session=first.data.id_sessao;report.own_session=session;
 report.negative_auth=[];
 for(const kind of ['missing','malformed']){
  const before=counts(),r=await api(e,'/functions/v1/copilot-query',{body:{...body,pergunta:'POST sem autoridade autenticada'},malformedAuth:kind==='malformed'});
  const branch=invalidAuthResult(kind,r);check('POST_AUTH_'+kind.toUpperCase()+'_DENIED_NO_EFFECT',sameCounts(before,counts()));report.negative_auth.push({kind,branch,status:r.status});
 }

 const forgedBefore=counts(),forgedResponse=await post({...a,token:forgeOwnJWTSignature(a.token)},{...body,pergunta:'POST com assinatura inválida, sem autoridade'});
 report.negative_auth.push({kind:'forged_signature',branch:expiredJWTResult(a.algorithm,forgedResponse),status:forgedResponse.status});check('POST_FORGED_SIGNATURE_DENIED_NO_EFFECT',sameCounts(forgedBefore,counts()));
 check('OPENAI_PERSISTED',sql(e,`select exists(select 1 from public.consultas_semanticas q join public.retornos_modelo r on r.id_consulta=q.id where q.id=${q(first.data.id_consulta)} and q.id_organizacao=${q(f.org)} and q.criado_por=${q(a.user.id)} and r.provedor='openai' and r.status='concluido' and jsonb_array_length(r.fontes)>0);`)==='t');
 const follow=await ask(a,{...body,id_sessao:session,pergunta:'Qual é o nome da revisão que defini na minha pergunta anterior sobre os comprovantes do relatório mensal?'},'c13_followup');
 check('C13_CONTEXTUAL_FOLLOWUP',follow.status===200&&follow.data?.ok===true&&follow.data.id_sessao===session&&/Plano Aurora/i.test(follow.data.resposta));
 const third=await ask(a,{...body,id_sessao:session,pergunta:'Resuma a orientação anterior sobre quais comprovantes devem acompanhar o relatório mensal, mantendo as fontes atuais.'},'c13_third_turn');
 check('C13_THREE_REAL_TURNS',third.status===200&&third.data?.ok===true&&third.data.id_sessao===session);
 const readBefore=counts(),listed=await post(a,{...body,action:'listar_sessoes',limite:1});
 check('C13_OWN_SESSION_LIST',listed.status===200&&listed.data?.ok===true&&listed.data.sessoes?.length===1&&listed.data.sessoes[0].id===session);
 const ids=[],messages=[];let cursor,firstCursor;
 for(let page=0;page<10;page++){
  const r=await post(a,{...body,action:'historico',id_sessao:session,limite:1,...(cursor?{cursor}:{})});check('C13_HISTORY_PAGE_'+page,r.status===200);validateHistoryPage(r.data,session,null);
  requireC(r.data.mensagens.length===1,'real page size one');ids.push(r.data.mensagens[0].id);messages.push(r.data.mensagens[0]);cursor=r.data.proximo_cursor;if(page===0)firstCursor=cursor;if(!cursor)break;
 }
 check('C13_PAGINATION_SIX_DISTINCT_MESSAGES',ids.length===6&&new Set(ids).size===6);
 const reloaded=await post(a,{...body,action:'historico',id_sessao:session,limite:1});validateHistoryPage(reloaded.data,session,null);
 check('C13_API_RELOAD_SAME_PERSISTED_PAGE',reloaded.status===200&&reloaded.data.mensagens[0].id===ids[0]&&sameCounts(readBefore,counts()));
 for(const m of messages.filter(x=>x.papel==='assistente')){
  const flags=JSON.parse(sql(e,`select json_build_object('incerteza',r.resposta->'incerteza','conflito_historico',r.resposta->'conflito_historico','baixa_confianca',r.resposta->'baixa_confianca') from public.mensagens_copiloto m join public.retornos_modelo r on r.id=m.id_retorno_modelo where m.id=${q(m.id)} and m.id_sessao=${q(session)};`));
  check('C13_PERSISTED_RISK_FLAGS_'+m.id,['incerteza','conflito_historico','baixa_confianca'].every(k=>m[k]===flags[k]));
 }
 await deny('OTHER_TENANT_DENIED',b,{...body,pergunta:'Pergunta alheia'},403,'AUTH_ACESSO_NEGADO');
 await deny('OUTSIDE_CONTRACT_DENIED',a,{id_contrato:f.contract_b,pergunta:'Pergunta alheia'},403,'AUTH_ACESSO_NEGADO');
 await deny('THIRD_PARTY_SESSION_DENIED',rev,{...body,action:'historico',id_sessao:session},403,'SESSAO_INVALIDA');
 await deny('REFERENCE_MISMATCH_DENIED',a,{...body,data_referencia:'2026-02-01',action:'historico',id_sessao:session},403,'SESSAO_INVALIDA');
 await deny('BAD_CURSOR_DENIED',a,{...body,action:'historico',id_sessao:session,cursor:'invalid'},400,'CURSOR_INVALIDO');
 await deny('LIMIT_51_DENIED',a,{...body,action:'historico',id_sessao:session,limite:51},400,'DADOS_INVALIDOS');
 await deny('CURSOR_ACTION_BINDING_DENIED',rev,{...body,action:'listar_sessoes',cursor:firstCursor},400,'CURSOR_INVALIDO');
 const mlist=await post(master,{...body,action:'listar_sessoes',limite:1});check('MASTER_CONTRACT_AUTHORITY_WITH_OWN_HISTORY',mlist.status===200&&mlist.data?.ok===true&&mlist.data.sessoes?.length===0);
 await deny('MASTER_CANNOT_READ_OTHER_ACTOR_HISTORY',master,{...body,action:'historico',id_sessao:session},403,'SESSAO_INVALIDA');
 // Canonical role matrix is read, never mutated to manufacture a denial.
 report.permissions=JSON.parse(sql(e,"select json_agg(json_build_object('perfil',perfil,'permitido',permitido) order by perfil) from privado.rbac_permissoes_perfis where recurso='arquivos' and acao='consultar';"));
 const canonicalRBAC=readFileSync('supabase/migrations/20261106014102_p0_v1_rbac_persistente.sql','utf8');
 report.permission_authority=[];
 for(const [name,args] of [['privado.rbac_permite','uuid,text,text,uuid'],['privado.consultar_permissoes_efetivas','uuid,uuid'],['public.consultar_permissoes_efetivas','uuid,uuid']]){
  const expectedBody=createHash('md5').update(canonicalFunctionBody(canonicalRBAC,name)).digest('hex');
  requireC(sql(e,`select md5(prosrc) from pg_proc where oid=${q(name+'('+args+')')}::regprocedure;`)===expectedBody,'effective permission body equals canonical no-override authority');report.permission_authority.push({name,body_md5:expectedBody});
 }
 const noOverrides=sql(e,"select not exists(select 1 from information_schema.columns where table_schema='privado' and table_name='rbac_permissoes_perfis' and column_name in('id_usuario','id_organizacao','id_contrato'));" )==='t';
 requireC(report.permissions?.length===10&&report.permissions.every(p=>p.permitido===true)&&noOverrides,'material RBAC catalog must match approved ten-role no-override configuration');
 report.permissions_case={state:'N/A MATERIAL_CONFIG',reason:'10/10 canonical roles allow arquivos.consultar; no local negative override; no global mutation'};
 const lockEligible=first.data.fontes.filter(x=>x.fonte_tipo==='fragmento_documento').map(x=>x.fonte_id);
 report.serialization=await closeFinalizerProof(e,f,rev,post,lockEligible);check('NATIVE_CLOSE_FINALIZER_BOTH_COMMIT_ORDERS',true);
 const raw=await prepareRawControl(e,f,first.data,report.serialization,root),rawActors=[[a,'OWNER'],[rev,'PEER_SAME_ORG_BEFORE_REVOCATION'],[master,'MASTER']];
 report.raw_privacy={target_ids:raw,before_quarantine:await rawSDKProof(rawActors,f,raw,'BEFORE_QUARANTINE')};check('RAW_CHAT_OWNER_PEER_MASTER_DENIED_NONCHAT_PRESERVED',true);
 // Exactly two server reservations remain live while the third real JWT POST is denied.
 const eligible=first.data.fontes.filter(x=>x.fonte_tipo==='fragmento_documento').map(x=>x.fonte_id);
 requireC(eligible.length>0,'own eligible controlled reservation IDs');
 report.admission=await admissionProof({reserve:async()=>{const r=await e.SDK.admin.rpc('worker_reservar_consulta_copiloto',{p_id_organizacao:f.org,p_id_contrato:f.contract,p_id_usuario:a.user.id,p_texto:'Own controlled concurrency admission',p_filtros:{session_id:a.sessionId,data_referencia:null,ids_fragmentos:eligible,ids_precedentes:[]},p_modelo:'Supabase/gte-small-384+ranking-v4'});requireC(!r.error,'controlled service-only reserve');return r.data;},ask:()=>post(a,{...body,id_sessao:session,pergunta:'Prova de admissão concorrente'}),fail:async v=>{const r=await e.SDK.admin.rpc('worker_falhar_consulta_copiloto',{p_id_consulta:v.id_consulta,p_token:v.token,p_codigo:'FALHA_RECUPERACAO'});requireC(!r.error&&r.data===true,'fenced own reservation release');},count:async()=>counts().reservations},ledger);check('DETERMINISTIC_CONCURRENCY_429',true);
 const bBefore=counts();report.rate=await rateProof(()=>post(b,{id_contrato:f.contract_b,pergunta:'Sem fonte documental própria'}),ledger);
 const bAfter=counts();check('RATE_SIX_RESERVATIONS_SEVENTH_NO_EFFECT',bAfter.reservations-bBefore.reservations===6&&bAfter.sources===bBefore.sources);
 check('B_FALLBACK_NO_OPENAI',sql(e,`select not exists(select 1 from public.retornos_modelo r join public.consultas_semanticas c on c.id=r.id_consulta where c.criado_por=${q(b.user.id)} and r.provedor='openai');`)==='t');
 const closeBefore=counts();for(let n=0;n<2;n++){const r=await post(a,{...body,action:'encerrar_sessao',id_sessao:session});check('C13_CLOSE_IDEMPOTENT_'+n,r.status===200&&r.data?.ok===true&&r.data.id_sessao===session&&r.data.status==='encerrada');}
 check('C13_READ_CLOSE_NO_INFERENCE',sameCounts(closeBefore,counts()));
 await deny('CLOSED_SESSION_NEW_QUESTION_DENIED',a,{...body,id_sessao:session,pergunta:'Não reabrir sessão'},403,'SESSAO_INVALIDA');
 // Own negative security mutation only after the positive normal-worker proof.
 sql(e,`update public.arquivos set status_seguranca='quarentena' where id=(select id_arquivo from public.versoes_documento where id=${q(f.document.id_versao)}) and id_organizacao=${q(f.org)} and id_contrato=${q(f.contract)};`);
 const redacted=await post(a,{...body,action:'historico',id_sessao:session,limite:20});validateHistoryPage(redacted.data,session,null);
 check('C13_REVOKED_SOURCE_REDACTS_ENTIRE_ASSISTANT',redacted.status===200&&redacted.data.mensagens.filter(m=>m.papel==='assistente').length===3&&redacted.data.mensagens.filter(m=>m.papel==='assistente').every(m=>m.conteudo===null&&m.fontes.length===0&&m.conteudo_disponivel===false&&m.motivo_indisponibilidade==='FONTE_INDISPONIVEL'));
 report.raw_privacy.after_quarantine=await rawSDKProof(rawActors,f,raw,'AFTER_QUARANTINE');check('RAW_CHAT_AFTER_QUARANTINE_STILL_DENIED_NONCHAT_PRESERVED',true);
 const beforeRevocation=counts();sql(e,`delete from auth.sessions where id=${q(rev.sessionId)} and user_id=${q(rev.user.id)};`);
 check('OWN_SESSION_ABSENT',sql(e,`select not exists(select 1 from auth.sessions where id=${q(rev.sessionId)} and user_id=${q(rev.user.id)});`)==='t');
 const recognized=await rev.client.auth.getUser(rev.token),denied=await post(rev,{...body,pergunta:'Mesma credencial após revogação'});
 report.revocation_branch=revokedSessionResult(authRecognition(recognized,rev.user.id),denied);check('SAME_TOKEN_REVOKED_NO_EFFECT',sameCounts(beforeRevocation,counts()));
 // A new question without id_sessao creates a different own conversation. No source means no OpenAI.
 // At most 6 A reservations have occurred; respect the real minute window before the next one.
 await waitForActorWindow(e,a.user.id,1);
 const fresh=await ask(a,{...body,pergunta:'Nova conversa sem fonte disponível'},'no_source_new_conversation');
 check('C13_NEW_CONVERSATION_AFTER_CLOSE',fresh.status===200&&fresh.data?.ok===true&&fresh.data.id_sessao!==session&&fresh.data.fontes?.length===0);
 await deny('CURSOR_SESSION_BINDING_DENIED',a,{...body,action:'historico',id_sessao:fresh.data.id_sessao,cursor:firstCursor},400,'CURSOR_INVALIDO');
 const cursorPage=await post(a,{...body,action:'listar_sessoes',limite:1});check('OWN_SECOND_SESSION_YIELDS_LIST_CURSOR',cursorPage.status===200&&typeof cursorPage.data?.proximo_cursor==='string');
 await deny('CURSOR_ACTOR_BINDING_DENIED',master,{...body,action:'listar_sessoes',limite:1,cursor:cursorPage.data.proximo_cursor},400,'CURSOR_INVALIDO');
 await expiredJWTProof(e,master,body,post,counts,report);check('REAL_JWT_NATURAL_EXPIRY_NO_EFFECT',true);
 report.ledger=ledger.snapshot();report.sdk={version:e.SDK.version,source_frontend_head:i.frontend};
 report.limits.push('API/JWT proof only. Browser, responsive matrix, frontend C13 freshness, visual accessibility and UI certification are pending. Runtime-only provider-boundary race proofs are separate evidence, not reclassified as HML assertions.');
 report.material_checks_finished_at=new Date().toISOString();
}
export function forgeOwnJWTSignature(token){
 requireC(typeof token==='string'&&/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token),'three-part own SDK JWT');
 const [header,claims,signature]=token.split('.');return [header,claims,(signature[0]==='A'?'B':'A')+signature.slice(1)].join('.');
}
export function invalidAuthResult(kind,r){
 requireC(['missing','malformed'].includes(kind)&&r.status===401,'negative POST auth requires HTTP401');
 const edge=kind==='missing'?'AUTH_ACESSO_NEGADO':'AUTH_SESSAO_INVALIDA';
 if(r.data?.ok===false&&r.data.codigo===edge)return 'EDGE_'+edge;
 const gateway=kind==='missing'?'UNAUTHORIZED_NO_AUTH_HEADER':'UNAUTHORIZED_INVALID_JWT_FORMAT';
 requireC(r.headers.get('sb-error-code')===gateway,'exact missing/malformed platform auth rejection');return 'GATEWAY_'+gateway;
}
export function expiredJWTResult(algorithm,r){
 requireC(r.status===401,'expired JWT requires HTTP401');
 if(r.data?.ok===false&&r.data.codigo==='AUTH_SESSAO_INVALIDA')return 'EDGE_AUTH_SESSAO_INVALIDA';
 const code=algorithm==='HS256'?'UNAUTHORIZED_LEGACY_JWT':['ES256','RS256'].includes(algorithm)?'UNAUTHORIZED_ASYMMETRIC_JWT':null;
 requireC(code!==null&&r.headers.get('sb-error-code')===code,'exact algorithm-specific gateway expiry denial');return 'GATEWAY_'+algorithm;
}
export async function waitNaturalExpiry(expiresAt,{now=Date.now,delay=ms=>new Promise(r=>setTimeout(r,ms)),signal}={}){
 const target=expiresAt+3000;requireC(Number.isSafeInteger(expiresAt)&&target-now()<=4200000,'legitimate JWT TTL exceeds authorized operational window');
 while(now()<target){signal?.throwIfAborted();await delay(Math.min(10000,target-now()));}
 signal?.throwIfAborted();
}
async function expiredJWTProof(e,actor,body,post,counts,report){
 const expires=actor.expiresAt+3000;
 requireC(expires-Date.now()<=4200000,'legitimate JWT TTL exceeds authorized operational window');
 report.jwt_expiry={issued_token_proven_valid:true,expires_at:new Date(actor.expiresAt).toISOString(),waiting_started_at:new Date().toISOString()};
 // Same valid SDK token stays only in memory. No refresh, claim edits, TTL
 // configuration changes, revocation or ban before this distinct negative.
 await waitNaturalExpiry(actor.expiresAt,{signal:materialDeadline?.signal});
 requireC(sql(e,`select exists(select 1 from auth.sessions s join auth.users u on u.id=s.user_id where s.id=${q(actor.sessionId)} and s.user_id=${q(actor.user.id)} and(u.banned_until is null or u.banned_until<clock_timestamp()));`)==='t','expired token session remains distinct from revoked/banned scenario');
 const before=counts(),r=await post(actor,{...body,pergunta:'Prova de JWT naturalmente expirado sem consulta admitida'});
 report.jwt_expiry.branch=expiredJWTResult(actor.algorithm,r);requireC(JSON.stringify(before)===JSON.stringify(counts()),'naturally expired JWT has no reservation or persistence');
 report.jwt_expiry.observed_at=new Date().toISOString();report.jwt_expiry.status=r.status;report.jwt_expiry.codigo=r.data?.codigo??r.headers.get('sb-error-code');report.jwt_expiry.algorithm=actor.algorithm;
}
async function waitForActorWindow(e,user,needed){
 for(let n=0;n<70;n++){
  materialDeadline?.signal.throwIfAborted();const count=Number(sql(e,`select count(*) from public.consultas_semanticas where criado_por=${q(user)} and criado_em>clock_timestamp()-interval '1 minute';`));if(count+needed<=6)return;
  await new Promise(r=>setTimeout(r,1000));
 }
 throw Error('REAL_RATE_WINDOW_NOT_AVAILABLE');
}
export function finalState(report,independentCleanup,postReceipt,i){
 requireC(report.state==='PROVA_MATERIAL_OK_AGUARDA_READBACK_FINAL'&&report.proof_mode==='api_c13'&&report.backend_head===i.head&&report.frontend_head===i.frontend&&report.nonce===i.nonce&&report.run_id===String(i.runId),'exact pending material report');
 requireC(report.checks.length>0&&report.checks.every(c=>c.passed===true)&&report.cleanup?.state==='QUARENTENA_VERIFICADA'&&independentCleanup.state==='QUARENTENA_VERIFICADA','both cleanup boundaries verified');
 validateReceipt(report.pre_receipt,i,{now:Date.parse(report.material_started_at)});
 validateReceipt(postReceipt,i,{phase:'post-proof',runId:i.runId,materialFinishedAt:report.material_finished_at});
 return 'API_PASS_UI_PENDING';
}
async function finalReadback(e,i){
 const report=JSON.parse(readFileSync('copilot-proof/report.json')),independent=JSON.parse(readFileSync('copilot-cleanup/cleanup.json'));i.runId=e.GITHUB_RUN_ID;
 requireC((await gh(`/repos/${REPO}/git/ref/heads/main`,e)).object.sha===i.head,'final stable main CAS');
 validateFrontendPR(await gh(`/repos/contaos999999/contaos-hml-control/pulls/${i.frontendPr}`,e),i);
 const initial=await gh(`/repos/${REPO}/issues/comments/${i.comment}`,e);requireC(JSON.stringify(JSON.parse(initial.body))===JSON.stringify(report.pre_receipt),'initial receipt body unchanged');validateComment(initial,report.pre_receipt,i,{now:Date.parse(report.material_started_at)});
 const started=Date.now();let final;
 while(Date.now()-started<720000){
  const comments=[];for(let page=1;page<=10;page++){const rows=await gh(`/repos/${REPO}/issues/138/comments?per_page=100&since=${encodeURIComponent(report.material_started_at)}&page=${page}`,e);comments.push(...rows);if(rows.length<100)break;requireC(page<10,'bounded final receipt catalog complete');}
  const matches=[];
  for(const comment of comments){let receipt;try{receipt=JSON.parse(comment.body);}catch{continue;}if(receipt?.schema==='contaos.copilot.deployment.v1'&&receipt.phase==='post-proof'&&String(receipt.run_id)===String(e.GITHUB_RUN_ID)&&receipt.nonce===i.nonce)matches.push({comment,receipt});}
  requireC(matches.length<=1,'one immutable final receipt');
  if(matches.length){const {comment,receipt}=matches[0];validateComment(comment,receipt,i,{phase:'post-proof',runId:e.GITHUB_RUN_ID,materialFinishedAt:report.material_finished_at});final={comment_id:comment.id,receipt};break;}
  await new Promise(r=>setTimeout(r,5000));
 }
 requireC(final,'post-proof coordinator readback absent; no final pass');
 requireC((await gh(`/repos/${REPO}/git/ref/heads/main`,e)).object.sha===i.head,'main stable through final receipt');
 report.state=finalState(report,independent,final.receipt,i);report.post_receipt=final;report.independent_cleanup=independent;report.global_complete=false;
 report.ui_state='PENDING_SEPARATE_FULL_UI_BUILD_AND_PROOF';writeFileSync('copilot-proof/final.json',JSON.stringify(report,null,2));
 console.log('API_PASS_UI_PENDING');
}
async function main(){
 const e={...process.env},mode=process.argv[2];
 if(mode==='--gate'){await gate(e);console.log('COPILOT_PRE_ENVIRONMENT_GATE_PASS');return;}
 const i=inputs(e);
 if(mode==='--install-sdk'){await setupSDK(e,i);console.log('COPILOT_APPROVED_SDK_READY');return;}
 if(mode==='--finalize'){await finalReadback(e,i);return;}
 const root=privateRoot(e);mkdirSync('copilot-proof',{recursive:true});
 if(mode==='--cleanup'){
  e.CLEANUP_MODE=true;e.SDK=await loadSDK(e,i,{cleanupOnly:true});
  try{const result=await cleanup(e,root);writeFileSync('copilot-proof/cleanup.json',JSON.stringify(result,null,2));requireC(result.state==='QUARENTENA_VERIFICADA','cleanup incomplete');console.log('COPILOT_OWN_CLEANUP_VERIFIED');}
  finally{if(existsSync(join(root,'cleanup.json')))writeFileSync('copilot-proof/cleanup.json',readFileSync(join(root,'cleanup.json')));}return;
 }
 requireC(mode==='--run','explicit mode');
 const report={schema:'contaos.copilot.hml.v1',proof_mode:i.mode,backend_head:i.head,frontend_head:i.frontend,frontend_pr:i.frontendPr,nonce:i.nonce,run_id:e.GITHUB_RUN_ID,checks:[],limits:[],state:'FAIL',global_complete:false};let started=false;
 try{
  const live=await gate(e);report.pre_receipt=live.receipt;report.pre_receipt_comment_id=i.comment;
  e.SDK=await loadSDK(e,i);report.material_started_at=new Date().toISOString();started=true;
  await withinMaterialDeadline(4800000,()=>materialAPI(e,i,root,report));
 }catch{report.error='Proof failed; sensitive operational details withheld.';process.exitCode=1;}
 finally{
  if(started){e.CLEANUP_MODE=true;try{report.cleanup=await cleanup(e,root);requireC(report.cleanup.state==='QUARENTENA_VERIFICADA','cleanup incomplete');if(!process.exitCode)finishMaterial(report);}catch{report.cleanup??={state:'CLEANUP_FAILED'};report.state='FAIL';process.exitCode=1;}}
  writeFileSync('copilot-proof/report.json',JSON.stringify(report,null,2));privatePasswords.clear();
 }
 // A green material job is explicitly pending. Only the separate read-only
 // finalizer may publish API_PASS_UI_PENDING after coordinator's final receipt.
 requireC(report.state==='PROVA_MATERIAL_OK_AGUARDA_READBACK_FINAL','material proof incomplete');
 console.log(report.state);
}
async function selfTest(){
 const e={PROOF_MODE:'api_c13',FRONTEND_PR:'379',TESTED_HEAD:'a'.repeat(40),FRONTEND_HEAD:'b'.repeat(40),RESTORE_RUN_ID:'123',DEPLOYMENT_RECEIPT_COMMENT_ID:'456',EDGE_SOURCE_SHA256:'c'.repeat(64),EDGE_BUNDLE_SHA256:'d'.repeat(64),EDGE_VERSION:'9',NONCE:'e'.repeat(32),GITHUB_REPOSITORY:'contaos999999/develop',GITHUB_REF:'refs/heads/main',GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_SHA:'a'.repeat(40)};
 assert.equal(inputs(e).head,e.TESTED_HEAD);
 assert.equal(inputs(e).mode,'api_c13','API mode must be explicit and does not need a checkout');
 for(const patch of [{PROOF_MODE:'full_ui'},{PROOF_MODE:''},{FRONTEND_PR:'0'},{FRONTEND_PR:'379x'}])assert.throws(()=>inputs({...e,...patch}));
 for(const patch of [{GITHUB_REF:'refs/heads/foreign'},{GITHUB_EVENT_NAME:'pull_request'},{TESTED_HEAD:'main'},{GITHUB_SHA:'f'.repeat(40)},{GITHUB_REPOSITORY:'foreign/develop'},{NONCE:'reuse'},{EDGE_VERSION:'0'},{RESTORE_RUN_ID:'1;echo bad'}])assert.throws(()=>inputs({...e,...patch}));
 const runs=['ContaOS Zero-Drift','ContaOS Restore Isolado'].map((name,n)=>({name,id:n===1?123:n+5,head_sha:e.TESTED_HEAD,status:'completed',conclusion:'success',event:'push',head_branch:'main',head_repository:{full_name:e.GITHUB_REPOSITORY}}));
 validateChecks(runs,e.TESTED_HEAD,'123');
 for(const field of ['head_sha','status','conclusion','event','head_branch']){const bad=structuredClone(runs);bad[1][field]='invalid';assert.throws(()=>validateChecks(bad,e.TESTED_HEAD,'123'));}
 const steps=['Context Gate — leitura obrigatória 4.1','Zero-Drift','Architecture Guard','SQL Security Guard','Migrations reproduzíveis','Historical HML source integrity','Segredos proibidos'].map(name=>({name,status:'completed',conclusion:'success'}));
 validateGuardSteps([{conclusion:'success',steps}]);
 for(let n=0;n<steps.length;n++)for(const conclusion of ['skipped','failure',null]){const bad=structuredClone(steps);bad[n].conclusion=conclusion;assert.throws(()=>validateGuardSteps([{conclusion:'success',steps:bad}]));}
 assert.throws(()=>validateGuardSteps([{conclusion:'success',steps:steps.slice(1)}]));
 const i=inputs(e),r={schema:'contaos.copilot.deployment.v1',proof_mode:'api_c13',backend_repo:REPO,frontend_repo:'contaos999999/contaos-hml-control',frontend_pr:379,backend_head:i.head,frontend_head:i.frontend,nonce:i.nonce,project:'gklhhhyosgasnyoxlrui',function_slug:'copilot-query',version:9,verify_jwt:true,readback_equal:true,source_sha256:i.source,bundle_sha256:i.bundle,verified_at:new Date().toISOString(),phase:'pre-proof'};
 validateReceipt(r,i);
 for(const field of Object.keys(r)){const bad={...r,[field]:null};assert.throws(()=>validateReceipt(bad,i));}
 assert.throws(()=>validateReceipt({...r,extra:true},i));assert.throws(()=>validateReceipt({...r,verified_at:new Date(Date.now()-900001).toISOString()},i));assert.throws(()=>validateReceipt({...r,verified_at:new Date(Date.now()+60000).toISOString()},i));
 const post={...r,phase:'post-proof',run_id:'1234'};validateReceipt(post,i,{phase:'post-proof',runId:'1234',materialFinishedAt:r.verified_at});assert.throws(()=>validateReceipt(post,i,{phase:'post-proof',runId:'5678',materialFinishedAt:r.verified_at}));assert.throws(()=>validateReceipt(post,i));
 const comment={user:{login:'contaos9999'},created_at:r.verified_at,updated_at:r.verified_at,issue_url:'https://api.github.com/repos/'+REPO+'/issues/138'};validateComment(comment,r,i);
 for(const patch of [{user:{login:'foreign'}},{updated_at:new Date(Date.now()+1000).toISOString()},{issue_url:'https://api.github.com/repos/'+REPO+'/issues/137'},{created_at:new Date(Date.now()-900001).toISOString()}])assert.throws(()=>validateComment({...comment,...patch},r,i));
 const f={scope:'C-CHAT-HML',nonce:'e'.repeat(32),users:[{intent:'zero'},{intent:'one'},{intent:'many'},{intent:'timeout'}]};
 const effects=[];
 const ops={recover:async intent=>intent==='zero'?[]:intent==='many'?['many1','many2']:[intent],ban:async id=>{effects.push('ban:'+id);if(id==='one')throw Error('PRIVATE_CANARY');},memberships:async id=>effects.push('memberships:'+id),master:async id=>effects.push('master:'+id),sessions:async id=>effects.push('sessions:'+id),organizations:async()=>{effects.push('organizations');return 2;},jobs:async()=>{effects.push('jobs');return {active_jobs:0};},verify:async()=>{effects.push('verify');return true;}};
 const result=await cleanupCausal(f,ops);
 assert.equal(result.state,'CLEANUP_FAILED');assert.equal(result.not_materialized,1);assert.equal(result.ambiguous,1);
 for(const id of ['one','many1','many2','timeout'])for(const op of ['ban','memberships','master','sessions'])assert.ok(effects.includes(op+':'+id));
 for(const op of ['organizations','jobs','verify'])assert.ok(effects.includes(op));assert.ok(!JSON.stringify(result).includes('PRIVATE_CANARY'));
 // Auth creation rejected/no materialization and timeout-after-creation are
 // distinct causal outcomes, neither may prevent cleanup of later resources.
 for(const rows of [[],['recovered']]){
  const called=[];const one={...f,users:[{intent:'creation-intent'}]};
  const ok=await cleanupCausal(one,{recover:async()=>rows,ban:async id=>called.push(id),memberships:async()=>{},master:async()=>{},sessions:async()=>{},organizations:async()=>0,jobs:async()=>({active_jobs:0}),verify:async()=>true});
  assert.equal(ok.state,'QUARENTENA_VERIFICADA');assert.equal(ok.not_materialized,rows.length?0:1);assert.deepEqual(called,rows);
 }
 const failed=await cleanupCausal({...f,users:[{intent:'db-timeout'},{intent:'later'}]},{...ops,recover:async intent=>{if(intent==='db-timeout')throw Error('PRIVATE_CANARY');return ['later'];},ban:async()=>{effects.push('later-cleaned');},jobs:async()=>{throw Error('PRIVATE_CANARY');}});
 assert.equal(failed.state,'CLEANUP_FAILED');assert.ok(effects.includes('later-cleaned'));assert.ok(!JSON.stringify(failed).includes('PRIVATE_CANARY'));
 assert.equal(parsePublicClient(`const SUPABASE_URL = "${URL}"; const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_public_fixture";`).key,'sb_publishable_public_fixture');
 for(const text of [`const SUPABASE_URL="https://foreign.supabase.co";const SUPABASE_PUBLISHABLE_KEY="sb_publishable_public_fixture";`,`const SUPABASE_URL="${URL}";const SUPABASE_PUBLISHABLE_KEY="sb_secret_BAD";`,`const SUPABASE_URL="${URL}";const SUPABASE_PUBLISHABLE_KEY="invalid";`])assert.throws(()=>parsePublicClient(text));
 const routeRows=Array.from({length:29},(_,n)=>`{ id: "${n<5?'SYS0'+(n+1):'V'+String(n).padStart(3,'0')}", path: "/case${n}"${n<3?', public: true':''}${n===28?', requiresDrawer: true':''} },`).join('\n');
 const matrix=parseSurfaces('export const ROUTES = [\n'+routeRows+'\n];');assert.equal(matrix.length,29);assert.equal(matrix.filter(r=>r.kind==='private').length,24);assert.equal(matrix.filter(r=>r.kind==='access').length,4);assert.equal(matrix.filter(r=>r.kind==='drawer').length,1);
 assert.throws(()=>parseSurfaces('export const ROUTES = [\n'+routeRows.replace('"/case0"','process.env.DATABASE_URL')+'\n];'));
 assert.throws(()=>parseSurfaces('export const ROUTES = [\n'+routeRows.replace('"SYS02"','"SYS01"')+'\n];'));
 const sentinel='00000000-0000-4000-8000-000000000001',own={contract:'own-contract',contractor:'own-contractor',competence:'own-competence',document:{id_documento:'own-document'}};
 assert.equal(expandSurface({id:'V111',path:'/contratos/'+sentinel+'/documentos/'+sentinel},own).path,'/contratos/own-contract/documentos/own-document');
 assert.equal(expandSurface({id:'V103',path:'/contratantes/'+sentinel+'/editar'},own).path,'/contratantes/own-contractor/editar');
 assert.equal(expandSurface({id:'V120',path:'/competencias/'+sentinel+'/apresentacoes/'+sentinel},own).path,null);
 const ready={kind:'private',pathExact:true,heading:true,blocked:false,pageErrors:0,chatVisible:true,overflow:0};assert.equal(classifySurface(ready),'OBSERVED_READY_NOT_CERTIFIED');
 assert.equal(classifySurface({...ready,blocked:true}),'BLOCKED_NOT_VERIFIED');assert.equal(classifySurface({...ready,pathExact:false}),'REDIRECTED_NOT_VERIFIED');assert.equal(classifySurface({...ready,heading:false}),'CONTENT_NOT_VERIFIED');assert.equal(classifySurface({...ready,pageErrors:1}),'FAIL_RUNTIME');assert.equal(classifySurface({...ready,chatVisible:false}),'CHAT_NOT_VERIFIED');

 // API provenance, final readback and accounting fail closed independently.
 assert.equal(typeof validateFrontendPR,'function','exact PR provenance validator required');
 const pr={number:379,head:{sha:e.FRONTEND_HEAD,repo:{full_name:'contaos999999/contaos-hml-control'}},base:{repo:{full_name:'contaos999999/contaos-hml-control'}}};
 validateFrontendPR(pr,i);
 for(const bad of [{...pr,number:380},{...pr,head:{...pr.head,sha:'f'.repeat(40)}},{...pr,head:{...pr.head,repo:{full_name:'foreign/repo'}}}])assert.throws(()=>validateFrontendPR(bad,i));
 assert.throws(()=>validateReceipt({...post,verified_at:new Date(Date.parse(r.verified_at)-1).toISOString()},i,{phase:'post-proof',runId:'1234',materialFinishedAt:r.verified_at}));
 assert.equal(typeof createLedger,'function','bounded reservation ledger required');
 const ledger=createLedger();for(let n=0;n<30;n++)ledger.reserve('A','material');assert.throws(()=>ledger.reserve('A','retry'));assert.equal(ledger.snapshot().A.total,30);
 for(let n=0;n<6;n++)ledger.reserve('B','fallback');assert.throws(()=>ledger.reserve('B','retry'));assert.throws(()=>ledger.reserve('C','bypass'));
 assert.equal(typeof admissionProof,'function','deterministic reservation proof required');
 const released=[],admitted=[];let occupied=0;
 const admissionOps={reserve:async()=>{occupied++;return {autorizado:true,id_consulta:'q'+occupied,token:'PRIVATE_'+occupied};},ask:async()=>{admitted.push(occupied);return {status:429,data:{ok:false,codigo:'COPILOTO_LIMITE_CONCORRENCIA'},headers:new Headers({'retry-after':'90'})};},fail:async v=>{released.push(v.id_consulta);occupied--;},count:async()=>2};
 await admissionProof(admissionOps,createLedger());assert.deepEqual(admitted,[2]);assert.deepEqual(released,['q1','q2']);
 released.length=0;occupied=0;let slots=0;await assert.rejects(()=>admissionProof({...admissionOps,reserve:async()=>{if(++slots===2)throw Error('private');return {autorizado:true,id_consulta:'one',token:'PRIVATE'};}},createLedger()));assert.deepEqual(released,['one']);
 assert.equal(typeof ownFixture,'function','recoverable scope intent required');
 const a=ownFixture(i,'1234'),b=ownFixture(i,'1234');assert.deepEqual(a,b);assert.equal(a.users.length,4);assert.equal(new Set(a.users.map(u=>u.intent)).size,4);assert.ok(!JSON.stringify(a).includes('password'));
 assert.notEqual(a.org,ownFixture({...i,nonce:'f'.repeat(32)},'1234').org);
 assert.equal(typeof revokedSessionResult,'function','same-token Auth versus RLS denial discriminator required');
 revokedSessionResult(false,{status:401,data:{ok:false,codigo:'AUTH_SESSAO_INVALIDA'}});revokedSessionResult(true,{status:403,data:{ok:false,codigo:'AUTH_ACESSO_NEGADO'}});
 assert.throws(()=>revokedSessionResult(true,{status:401,data:{ok:false,codigo:'AUTH_SESSAO_INVALIDA'}}));assert.throws(()=>revokedSessionResult(false,{status:500,data:{ok:false}}));
 assert.equal(typeof finishMaterial,'function','pending material result required');
 const materialReport={checks:[{passed:true}],cleanup:{state:'QUARENTENA_VERIFICADA'}};finishMaterial(materialReport);assert.equal(materialReport.state,'PROVA_MATERIAL_OK_AGUARDA_READBACK_FINAL');assert.notEqual(materialReport.state,'PASS');
 assert.throws(()=>finishMaterial({checks:[{passed:false}],cleanup:{state:'QUARENTENA_VERIFICADA'}}));

 assert.equal(typeof parseSDKLock,'function','API SDK must derive exact version and integrity from approved lock');
 const lock='"@supabase/supabase-js": ["@supabase/supabase-js@2.118.0", "", {}, "sha512-AAAA=="]';assert.deepEqual(parseSDKLock(lock),{version:'2.118.0',integrity:'sha512-AAAA=='});assert.throws(()=>parseSDKLock(lock+'\n'+lock));assert.throws(()=>parseSDKLock(lock.replace('2.118.0','latest')));
 assert.equal(typeof withinMaterialDeadline,'function','material deadline must abort pending work before job timeout');
 let effect=false;await assert.rejects(()=>withinMaterialDeadline(5,async signal=>{await new Promise((res,rej)=>{signal.addEventListener('abort',()=>rej(Error('deadline')),{once:true});});effect=true;}));assert.equal(effect,false);

 assert.equal(typeof rateProof,'function','six real fallback reservations then exact seventh denial required');
 let rateCalls=0;const rateLedger=createLedger();await rateProof(async()=>{rateCalls++;return {status:rateCalls<=6?200:429,data:rateCalls<=6?{ok:true,fontes:[]}:{ok:false,codigo:'COPILOTO_LIMITE_TAXA'},headers:new Headers({'retry-after':'60'})};},rateLedger);assert.equal(rateCalls,7);assert.equal(rateLedger.snapshot().B.total,6);
 let abortedCalls=0;await assert.rejects(()=>rateProof(async()=>{abortedCalls++;return {status:500,data:{}};},createLedger()));assert.equal(abortedCalls,1);
 assert.equal(typeof validateHistoryPage,'function','history must reject leaked internal fields and malformed flags');
 const hp={ok:true,sessao:{id:'own',status:'ativa',data_referencia:null},mensagens:[{id:'m',papel:'assistente',conteudo:'safe',criado_em:'2026-01-01T00:00:00.123456Z',fontes:[],conteudo_disponivel:true,incerteza:true,conflito_historico:false,baixa_confianca:null}],proximo_cursor:null};validateHistoryPage(hp,'own',null);
 assert.throws(()=>validateHistoryPage({...hp,mensagens:[{...hp.mensagens[0],embedding:[]}]},'own',null));assert.throws(()=>validateHistoryPage({...hp,mensagens:[{...hp.mensagens[0],incerteza:'false'}]},'own',null));assert.throws(()=>validateHistoryPage(hp,'foreign',null));

 const fi={...i,runId:'1234'},fr={state:'PROVA_MATERIAL_OK_AGUARDA_READBACK_FINAL',proof_mode:'api_c13',backend_head:i.head,frontend_head:i.frontend,nonce:i.nonce,run_id:'1234',pre_receipt:r,material_started_at:r.verified_at,material_finished_at:r.verified_at,checks:[{passed:true}],cleanup:{state:'QUARENTENA_VERIFICADA'}};
 assert.equal(finalState(fr,{state:'QUARENTENA_VERIFICADA'},post,fi),'API_PASS_UI_PENDING');
 for(const patch of [{nonce:'foreign'},{state:'PASS'},{run_id:'5678'},{checks:[{passed:false}]},{cleanup:{state:'CLEANUP_FAILED'}}])assert.throws(()=>finalState({...fr,...patch},{state:'QUARENTENA_VERIFICADA'},post,fi));assert.throws(()=>finalState(fr,{state:'CLEANUP_FAILED'},post,fi));
 assert.throws(()=>validateReceipt({...r,verified_at:'2026-02-30T00:00:00Z'},i,{now:Date.parse('2026-03-02T00:00:00Z')}),'calendar-normalized receipt timestamp must fail');
 assert.equal(typeof waitNaturalExpiry,'function','natural expiry wait is bounded, cancellable and never refreshes');
 let clock=1000,waits=0;await waitNaturalExpiry(3000,{now:()=>clock,delay:async ms=>{clock+=ms;waits++;},signal:new AbortController().signal});assert.equal(clock,6000);assert.equal(waits,1);
 await assert.rejects(()=>waitNaturalExpiry(5000000,{now:()=>0,delay:async()=>{},signal:new AbortController().signal}));
 const ac=new AbortController();ac.abort();await assert.rejects(()=>waitNaturalExpiry(3000,{now:()=>0,delay:async()=>{throw Error('must not wait');},signal:ac.signal}));

 assert.equal(typeof expiredJWTResult,'function','natural expiry distinguishes exact gateway algorithm code from handler code');
 assert.equal(expiredJWTResult('HS256',{status:401,data:{message:'JWT expired'},headers:new Headers({'sb-error-code':'UNAUTHORIZED_LEGACY_JWT'})}),'GATEWAY_HS256');
 assert.equal(expiredJWTResult('ES256',{status:401,data:{message:'JWT expired'},headers:new Headers({'sb-error-code':'UNAUTHORIZED_ASYMMETRIC_JWT'})}),'GATEWAY_ES256');
 assert.equal(expiredJWTResult('RS256',{status:401,data:{ok:false,codigo:'AUTH_SESSAO_INVALIDA'},headers:new Headers()}),'EDGE_AUTH_SESSAO_INVALIDA');
 for(const headers of [new Headers(),new Headers({'sb-error-code':'UNAUTHORIZED_LEGACY_JWT'}),new Headers({'sb-error-code':'MALFORMED_JWT'})])assert.throws(()=>expiredJWTResult('ES256',{status:401,data:{},headers}));
 assert.throws(()=>expiredJWTResult('ES256',{status:500,data:{ok:false,codigo:'AUTH_SESSAO_INVALIDA'},headers:new Headers()}));

 assert.equal(typeof orderedRace,'function','ordered row-lock race must wait for both contenders and always release blocker');
 const order=[];let release;
 const gatePromise=new Promise(r=>{release=r;});
 await orderedRace({first:()=>{order.push('first');return gatePromise.then(()=>1);},second:()=>{order.push('second');return gatePromise.then(()=>2);},wait:async n=>{order.push('blocked'+n);},release:async()=>{order.push('release');release();}});assert.deepEqual(order,['first','blocked1','second','blocked2','release']);
 let releasedOnFailure=false;await assert.rejects(()=>orderedRace({first:async()=>1,second:async()=>2,wait:async()=>{throw Error('not actually queued');},release:async()=>{releasedOnFailure=true;}}));assert.equal(releasedOnFailure,true);

 assert.equal(typeof cleanupQueues,'function','one queue failure must not skip any other own queue');
 const queuesSeen=[];await assert.rejects(()=>cleanupQueues(['documents','ocr','ai','embeddings'],async name=>{queuesSeen.push(name);if(name==='documents')throw Error('PRIVATE_QUEUE_DETAIL');}));assert.deepEqual(queuesSeen,['documents','ocr','ai','embeddings']);

 assert.equal(typeof canonicalFunctionBody,'function','N/A requires exact canonical runtime permission bodies, not only default role rows');
 assert.equal(canonicalFunctionBody('create function privado.rbac_permite(x uuid) returns boolean language sql as $$ select true $$;','privado.rbac_permite'),' select true ');assert.throws(()=>canonicalFunctionBody('create function privado.foreign(x uuid) returns boolean as $$ select true $$;','privado.rbac_permite'));

 const sdkFixture=mkdtempSync(join(tmpdir(),'copilot-sdk-contract-'));
 try{
  const base=join(sdkFixture,'node_modules/@supabase/supabase-js');mkdirSync(join(base,'dist'),{recursive:true});writeFileSync(join(sdkFixture,'package.json'),'{"private":true}');writeFileSync(join(base,'package.json'),JSON.stringify({name:'@supabase/supabase-js',version:'2.118.0',main:'dist/index.cjs',exports:{'.':{require:{default:'./dist/index.cjs'},import:{default:'./dist/index.mjs'}}}}));writeFileSync(join(base,'dist/index.cjs'),"exports.createClient=()=> 'SDK_ENTRY_RESOLVED';");
  let constructor;await assert.doesNotReject(async()=>{constructor=await sdkConstructor(sdkFixture);},'SDK must resolve package entrypoint, not nonexistent legacy dist/main/index.js');assert.equal(constructor(),'SDK_ENTRY_RESOLVED');
 }finally{rmSync(sdkFixture,{recursive:true,force:true});}

 assert.equal(typeof invalidAuthResult,'function','missing/malformed POST auth needs exact platform or Edge rejection');
 assert.equal(invalidAuthResult('missing',{status:401,data:{},headers:new Headers({'sb-error-code':'UNAUTHORIZED_NO_AUTH_HEADER'})}),'GATEWAY_UNAUTHORIZED_NO_AUTH_HEADER');
 assert.equal(invalidAuthResult('malformed',{status:401,data:{},headers:new Headers({'sb-error-code':'UNAUTHORIZED_INVALID_JWT_FORMAT'})}),'GATEWAY_UNAUTHORIZED_INVALID_JWT_FORMAT');
 assert.equal(invalidAuthResult('missing',{status:401,data:{ok:false,codigo:'AUTH_ACESSO_NEGADO'},headers:new Headers()}),'EDGE_AUTH_ACESSO_NEGADO');
 assert.equal(invalidAuthResult('malformed',{status:401,data:{ok:false,codigo:'AUTH_SESSAO_INVALIDA'},headers:new Headers()}),'EDGE_AUTH_SESSAO_INVALIDA');
 for(const bad of [{status:500,data:{},headers:new Headers()},{status:401,data:{},headers:new Headers()},{status:401,data:{},headers:new Headers({'sb-error-code':'UNAUTHORIZED_LEGACY_JWT'})}])assert.throws(()=>invalidAuthResult('missing',bad));
 assert.throws(()=>invalidAuthResult('missing',{status:401,data:{ok:false,codigo:'AUTH_SESSAO_INVALIDA'},headers:new Headers()}));assert.throws(()=>invalidAuthResult('missing',{status:401,data:{ok:false,codigo:'AUTH_NAO_AUTENTICADO'},headers:new Headers()}));

 assert.equal(typeof authRecognition,'function','revoked-token Auth branch cannot treat transport/provider errors as authentication rejection');
 assert.equal(authRecognition({data:{user:{id:'own'}},error:null},'own'),true);assert.equal(authRecognition({data:{user:null},error:{name:'AuthApiError',status:401}},'own'),false);
 assert.throws(()=>authRecognition({data:{user:null},error:{name:'AuthUnknownError',status:0}},'own'));assert.throws(()=>authRecognition({data:{user:null},error:{name:'AuthApiError',status:500}},'own'));assert.throws(()=>authRecognition({data:{user:{id:'foreign'}},error:null},'own'));

 assert.equal(typeof forgeOwnJWTSignature,'function','forged-signature negative preserves legitimate header and claims but changes signature bytes');
 const signed='eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJvd24ifQ.ZXhhbXBsZXNpZw';const forged=forgeOwnJWTSignature(signed);assert.equal(forged.split('.').slice(0,2).join('.'),'eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJvd24ifQ');assert.notEqual(Buffer.from(forged.split('.')[2],'base64url').toString('hex'),Buffer.from(signed.split('.')[2],'base64url').toString('hex'));assert.throws(()=>forgeOwnJWTSignature('not-a-jwt'));
 assert.throws(()=>expiredJWTResult('ES256',{status:401,data:{},headers:new Headers()}),'generic401 cannot certify forged signature rejection');
 assert.equal(expiredJWTResult('ES256',{status:401,data:{},headers:new Headers({'sb-error-code':'UNAUTHORIZED_ASYMMETRIC_JWT'})}),'GATEWAY_ES256');

 assert.equal(typeof rawSDKResult,'function','raw Data API proof must require200empty arrays and preserve known non-chat control');
 rawSDKResult({status:200,error:null,data:[]});
 for(const bad of [{status:403,error:{code:'42501'},data:null},{status:401,error:{},data:[]},{status:200,error:null,data:[{id:'chat',resposta:{conteudo:'LEAK'}}]},{status:200,error:null,data:null}])assert.throws(()=>rawSDKResult(bad));
 rawSDKResult({status:200,error:null,data:[{id:'control',resposta:{marcador:'SYNTHETIC_RLS_CONTROL',conteudo:'Controle sintético de visibilidade, sem inferência.'},fontes:[]}]},'control');assert.throws(()=>rawSDKResult({status:200,error:null,data:[]},'control'));assert.throws(()=>rawSDKResult({status:200,error:null,data:[{id:'foreign',resposta:{marcador:'SYNTHETIC_RLS_CONTROL'}}]},'control'));
 console.log('COPILOT_HML_SELF_TEST_PASS');
}
if(process.argv.includes('--self-test'))await selfTest();
else if(process.argv[1]===new globalThis.URL(import.meta.url).pathname){try{await main();}catch{console.error('COPILOT_RUNNER_GATE_FAILED: private details withheld');process.exitCode=1;}}
