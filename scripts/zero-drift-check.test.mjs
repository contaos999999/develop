import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {spawnSync} from 'node:child_process';
const script = new URL('./zero-drift-check.mjs',import.meta.url).pathname;
const auth = {schema:'contaos.p0.parallel-task-authorization.v1',task_id:'P0-CERT-LIVE-001',repository:'contaos999999/develop',pr_number:228,approved_scope:['docs/tasks/P0_CERT_LIVE_001_2026-11-22.md','docs/prompts/P0_CERT_LIVE_001_2026-11-22.md','docs/prompts/P0_PRIORIDADE_ZERO_ORDEM_POR_VERSAO_4_1.md','scripts/zero-drift-check.mjs','scripts/zero-drift-check.test.mjs'],forbidden_paths:['docs/tasks/active-task.json','PROD/**','src/**','public/**']};
function run({pr=228,changed=['docs/tasks/P0_CERT_LIVE_001_2026-11-22.md'],manifest=auth,protectedBase=true}={}) {
 const dir=mkdtempSync(join(tmpdir(),'contaos-context-'));
 try {
  const put=(p,v)=>{mkdirSync(dirname(join(dir,p)),{recursive:true});writeFileSync(join(dir,p),v)};
  const git=(...args)=>{const r=spawnSync('git',args,{cwd:dir,encoding:'utf8'});assert.equal(r.status,0,r.stderr)};
  git('init','-q');git('config','user.email','test@example.invalid');git('config','user.name','Fixture');
  put('docs/tasks/active-task.json',JSON.stringify({id:'C-CHAT-013',allowed_paths:['docs/active/**'],forbidden_paths:['PROD/**','docs/tasks/active-task.json'],database_changes_allowed:false,edge_function_changes_allowed:false}));
  if(protectedBase&&manifest)put('docs/tasks/authorizations/P0_CERT_LIVE_001_PR228.json',JSON.stringify(manifest));
  git('add','.');git('commit','-qm','protected base');git('branch','-M','main');git('remote','add','origin','.');git('fetch','-q','origin','main:refs/remotes/origin/main');
  put('event.json',JSON.stringify({pull_request:{number:pr}}));
  return spawnSync(process.execPath,[script],{cwd:dir,encoding:'utf8',env:{...process.env,GITHUB_EVENT_PATH:join(dir,'event.json'),GITHUB_BASE_REF:'main',ZERO_DRIFT_CHANGED_FILES:changed.join('\\n')}});
 } finally {rmSync(dir,{recursive:true,force:true})}
}
test('authorized exact P0 path passes',()=>assert.equal(run().status,0));
test('active task retains its own allowed paths',()=>assert.equal(run({changed:['docs/active/x.md']}).status,0));
test('missing protected authorization fails closed',()=>assert.notEqual(run({protectedBase:false}).status,0));
test('wrong PR fails closed',()=>assert.notEqual(run({pr:229}).status,0));
test('foreign repo fails closed',()=>assert.notEqual(run({manifest:{...auth,repository:'foreign/repo'}}).status,0));
test('tampered scope fails closed',()=>assert.notEqual(run({manifest:{...auth,approved_scope:['**']}}).status,0));
test('unlisted path fails closed',()=>assert.notEqual(run({changed:['docs/prompts/other.md']}).status,0));
test('active task modification denied',()=>assert.notEqual(run({changed:['docs/tasks/active-task.json']}).status,0));
test('PROD denied',()=>assert.notEqual(run({changed:['PROD/release.json']}).status,0));
test('mixed authorized and unauthorized denied',()=>assert.notEqual(run({changed:['docs/tasks/P0_CERT_LIVE_001_2026-11-22.md','src/app.ts']}).status,0));
