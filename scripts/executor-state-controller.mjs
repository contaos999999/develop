#!/usr/bin/env node
// ContaOS 4.1: reconciliador P0, estritamente read-only.
// Não é executor, certificador, cron ou autorização de dispatch.
import { fileURLToPath } from 'node:url';

const OWNER = 'contaos999999';
const REPO = 'develop';
const ISSUE = 138;
const MARKER = '<!-- CONTAOS_EXECUTOR_STATE_V1\n';
const TRUSTED_AUTHORS = new Set(['contaos9999', 'Edivan5002']);
const STATES = new Set(['PENDING','RUNNING','BLOCKED','VALIDATING','COMPLETED']);
const SHA = /^[a-f0-9]{40}$/;
const positive = n => Number.isSafeInteger(n) && n > 0;
const text = s => typeof s === 'string' && s.length > 0 && s.length <= 1024;
const blocked = (reason, next_action) => ({status:'BLOCKED',reason,next_action,dispatch_allowed:false});

export function parseCheckpoint(body) {
  if (typeof body !== 'string' || body.length > 65536) return null;
  const start = body.indexOf(MARKER);
  if (start < 0 || body.indexOf(MARKER,start+MARKER.length) !== -1) return null;
  const end = body.indexOf('\n-->',start+MARKER.length);
  if (end < 0) return null;
  const raw = body.slice(start+MARKER.length,end);
  if (raw.length > 8192) return null;
  try {
    const x = JSON.parse(raw);
    if (!x || typeof x !== 'object' || Array.isArray(x)) return null;
    if (x.schema !== 1 || !Number.isInteger(x.phase_id) || x.phase_id < 1 || x.phase_id > 8) return null;
    if (!STATES.has(x.status) || !SHA.test(x.head_sha) || !text(x.task_id) || !text(x.next_action)) return null;
    if (x.pr_number != null && !positive(x.pr_number)) return null;
    if (x.run_id != null && !positive(x.run_id)) return null;
    if (x.conclusion != null && !['success','failure','cancelled','timed_out','skipped','neutral','action_required'].includes(x.conclusion)) return null;
    if (x.evidence != null && (!Array.isArray(x.evidence) || x.evidence.length > 50 || !x.evidence.every(s => typeof s === 'string' && s.length <= 2048))) return null;
    return Object.freeze({...x});
  } catch {
    return null;
  }
}

export function selectCheckpoint(comments) {
  if (!Array.isArray(comments)) return blocked('COMMENTS_SHAPE','Inspecionar resposta de comentários');
  const trusted = [];
  for (const c of comments) {
    if (!c || !positive(c.id) || typeof c.body !== 'string' || !c.user || typeof c.user.login !== 'string') {
      return blocked('COMMENTS_SHAPE','Inspecionar comentários malformados');
    }
    if (!c.body.includes('CONTAOS_EXECUTOR_STATE_V1')) continue;
    if (!TRUSTED_AUTHORS.has(c.user.login)) continue; // Comentários externos não autorizam estado.
    const state = parseCheckpoint(c.body);
    if (!state) return blocked('CHECKPOINT_MALFORMED','Não ignorar registro canônico inválido de autor autorizado');
    trusted.push({id:c.id,author:c.user.login,state});
  }
  if (!trusted.length) return {status:'UNINITIALIZED',next_action:'Registrar primeiro checkpoint com revisão independente',dispatch_allowed:false};
  trusted.sort((a,b)=>a.id-b.id);
  return trusted.at(-1);
}

export async function reconcile(checkpoint, api) {
  if (!checkpoint || checkpoint.dispatch_allowed === false) return checkpoint;
  const {id,state} = checkpoint;
  const result = {checkpoint_comment_id:id,phase_id:state.phase_id,task_id:state.task_id,
    head_sha:state.head_sha,pr_number:state.pr_number??null,run_id:state.run_id??null,
    status:'VALIDATING',reason:'CHECKPOINT_REQUIRES_GATES',next_action:'Verificar gates e revisão independente',
    dispatch_allowed:false};
  if (!state.run_id) {
    result.status = 'BLOCKED';
    result.reason = 'NO_RUN_PROOF';
    result.next_action = 'Sem Run ID: não presumir conclusão da fase';
    return result;
  }
  const run = await api('/repos/'+OWNER+'/'+REPO+'/actions/runs/'+state.run_id);
  if (!run || run.id !== state.run_id || run.repository?.full_name !== OWNER+'/'+REPO ||
      !SHA.test(run.head_sha||'') || !['completed','queued','in_progress','waiting','requested','pending'].includes(run.status)) {
    return {...result,...blocked('RUN_IDENTITY','Confirmar Run ID e origem no GitHub')};
  }
  result.workflow = {id:run.id,status:run.status,conclusion:run.conclusion??null,
    head_sha:run.head_sha,html_url:typeof run.html_url==='string'?run.html_url:null};
  if (run.head_sha !== state.head_sha) return {...result,...blocked('RUN_HEAD_MISMATCH','Run ID de outro HEAD')};
  if (state.pr_number) {
    const pr = await api('/repos/'+OWNER+'/'+REPO+'/pulls/'+state.pr_number);
    if (!pr || pr.number !== state.pr_number || pr.base?.repo?.full_name !== OWNER+'/'+REPO ||
        pr.head?.repo?.full_name !== OWNER+'/'+REPO || !SHA.test(pr.head?.sha||'')) {
      return {...result,...blocked('PR_IDENTITY','Confirmar identidade e repositório da PR')};
    }
    // Em PR merged, o HEAD deve corresponder ao checkpoint; não aceitar HEAD deslocado.
    if (pr.head.sha !== state.head_sha) return {...result,...blocked('PR_HEAD_MISMATCH','HEAD da PR mudou desde o checkpoint')};
  }
  if (run.status !== 'completed') return {...result,status:'RUNNING',reason:'RUN_NOT_FINISHED',next_action:'Acompanhar Run ID existente'};
  if (run.conclusion !== 'success') return {...result,...blocked('RUN_NOT_SUCCESS','Diagnosticar falha sem reexecutar automaticamente')};
  return {...result,status:'VALIDATING',reason:'GATES_AND_REVIEW_REQUIRED',
    next_action:'Inspecionar CI/LOCK/Zero-Drift, evidência e revisão independente; não certificar por este leitor'};
}

export async function readState(api) {
  const all = [];
  for (let page=1; page<=100; page++) {
    const rows=await api('/repos/'+OWNER+'/'+REPO+'/issues/'+ISSUE+'/comments?per_page=100&page='+page);
    if (!Array.isArray(rows) || rows.length>100) return blocked('COMMENTS_API','Resposta paginada inválida');
    all.push(...rows);
    if (rows.length<100) return reconcile(selectCheckpoint(all),api);
  }
  return blocked('PAGINATION_LIMIT','Não usar checkpoint parcial');
}

export function createApi(token, fetcher=fetch) {
  if (!text(token)) throw Error('GITHUB_TOKEN ausente');
  return async path => {
    if (!/^\/repos\/contaos999999\/develop\/(?:issues\/138\/comments\?per_page=100&page=\d+|actions\/runs\/\d+|pulls\/\d+)$/.test(path)) throw Error('READ_SCOPE');
    const r=await fetcher('https://api.github.com'+path,{
      method:'GET',redirect:'error',signal:AbortSignal.timeout(10000),
      headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28'}
    });
    if (!r || r.status!==200) throw Error('GITHUB_READ_FAILED');
    return r.json();
  };
}

export async function main(token=process.env.GITHUB_TOKEN, fetcher=fetch) {
  let result;
  try { result=await readState(createApi(token,fetcher)); }
  catch { result=blocked('READ_FAILED','GitHub indisponível, token ausente ou integridade não comprovada'); }
  process.stdout.write(JSON.stringify(result,null,2)+'\n');
  if (result.status==='BLOCKED') process.exitCode=2;
  return result;
}

if (process.argv[1] && fileURLToPath(import.meta.url)===process.argv[1]) await main();
