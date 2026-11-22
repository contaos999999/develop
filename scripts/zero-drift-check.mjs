import fs from 'node:fs';
import { execSync } from 'node:child_process';

const task = JSON.parse(fs.readFileSync('docs/tasks/active-task.json','utf8'));
const changedEnv = process.env.ZERO_DRIFT_CHANGED_FILES?.trim();
let changed = [];
if (changedEnv) changed = changedEnv.split('\n').filter(Boolean);
else {
  try { changed = execSync('git diff --name-only HEAD~1..HEAD',{encoding:'utf8'}).trim().split('\n').filter(Boolean); }
  catch { changed = []; }
}
const esc = s => s.replace(/[.+^${}()|[\]\\]/g,'\\$&').replaceAll('**','§§').replaceAll('*','[^/]*').replaceAll('§§','.*');
const match = (path,patterns=[]) => patterns.some(p => new RegExp('^'+esc(p)+'$').test(path));
// P0 parallel authorization: only a manifest committed to the protected base
// may authorize a PR; the PR cannot authorize itself. The active task is unchanged.
const base = process.env.GITHUB_BASE_REF || 'main';
const pr = Number(process.env.GITHUB_EVENT_PATH && JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8')).pull_request?.number);
let parallel = null;
if (Number.isSafeInteger(pr) && pr > 0) {
  const authPath = 'docs/tasks/authorizations/P0_CERT_LIVE_001_PR' + pr + '.json';
  try {
    const raw = execSync('git show origin/' + base + ':' + authPath, {encoding:'utf8',stdio:['ignore','pipe','ignore']});
    const candidate = JSON.parse(raw);
    const exact = ['docs/tasks/P0_CERT_LIVE_001_2026-11-22.md','docs/prompts/P0_CERT_LIVE_001_2026-11-22.md','docs/prompts/P0_PRIORIDADE_ZERO_ORDEM_POR_VERSAO_4_1.md','scripts/zero-drift-check.mjs','scripts/zero-drift-check.test.mjs'];
    // The protected PLAN must pre-exist the BUILD and match the immutable blob SHA.
    const planPath = 'docs/tasks/P0_CERT_LIVE_001_2026-11-22.md';
    const planSha = execSync('git rev-parse origin/' + base + ':' + planPath, {encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim();
    const baseCommit = execSync('git rev-parse origin/' + base, {encoding:'utf8'}).trim();
    const headCommit = execSync('git rev-parse HEAD', {encoding:'utf8'}).trim();
    const authorizedBaseValid = /^[0-9a-f]{40}$/.test(candidate.authorized_base_commit);
    const parentCheck = authorizedBaseValid && execSync('git merge-base --is-ancestor ' + candidate.authorized_base_commit + ' ' + baseCommit + ' && git merge-base --is-ancestor ' + candidate.authorized_base_commit + ' ' + headCommit + ' && echo yes', {encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim();
    if (candidate.schema === 'contaos.p0.parallel-task-authorization.v1' && candidate.task_id === 'P0-CERT-LIVE-001' && candidate.repository === 'contaos999999/develop' && candidate.pr_number === pr &&
        candidate.protected_plan_path === planPath && candidate.protected_plan_blob_sha === planSha &&
        /^[0-9a-f]{40}$/.test(candidate.authorized_base_commit) && parentCheck === 'yes' && /^[0-9a-f]{40}$/.test(headCommit) &&
        Array.isArray(candidate.approved_scope) && candidate.approved_scope.length === exact.length && exact.every(x=>candidate.approved_scope.includes(x)) &&
        Array.isArray(candidate.forbidden_paths) && ['docs/tasks/active-task.json','PROD/**','src/**','public/**'].every(x=>candidate.forbidden_paths.includes(x))) parallel = candidate;
  } catch { /* fail closed: active task rules remain in force */ }
}
const isParallel = !!parallel && changed.length > 0 && changed.every(f=>parallel.approved_scope.includes(f));
const forbidden = changed.filter(f=>match(f,task.forbidden_paths) || (isParallel && match(f,parallel.forbidden_paths)));
const outside = changed.filter(f=>!match(f,task.allowed_paths) && !(isParallel && parallel.approved_scope.includes(f)));
const sql = changed.filter(f=>f.startsWith('supabase/migrations/') && f.endsWith('.sql'));
const edge = changed.filter(f=>f.startsWith('supabase/functions/'));
const errors=[];
if(forbidden.length) errors.push('Arquivos proibidos alterados: '+forbidden.join(', '));
if(outside.length) errors.push('Arquivos fora do escopo: '+outside.join(', '));
if(sql.length && !task.database_changes_allowed) errors.push('Mudança de banco não autorizada pelo manifesto.');
if(edge.length && !task.edge_function_changes_allowed) errors.push('Mudança de Edge Function não autorizada pelo manifesto.');
if(errors.length){ console.error(errors.join('\n')); process.exit(1); }
console.log(`Zero-Drift PASS: ${changed.length} arquivo(s) dentro do manifesto ${task.id}.`);
