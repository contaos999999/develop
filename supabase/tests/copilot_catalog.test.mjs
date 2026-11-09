import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,mkdirSync,copyFileSync,chmodSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
const task=JSON.parse(readFileSync('docs/tasks/active-task.json','utf8'));
const approved=task.copilot_catalog_gate.functions;
const rawGate=task.copilot_raw_read_rls_gate;
const clone=x=>JSON.parse(JSON.stringify(x));
function fixture(){
 const actual=JSON.parse(readFileSync('supabase/tests/history-catalog-before.json','utf8'));
 for(const name of ['criar_documento_contrato_completo','adicionar_versao_documento_contrato','definir_vigencia_sugestao_extracao'])actual.functions.find(f=>f.schema==='public'&&f.name===name).definer=true;
 for(const p of ['p0_crud_cadastros_catalog_expected.json','p0_crud_listas_catalog_expected.json','p0_v117_revisao_catalog_expected.json'])actual.functions.push(...JSON.parse(readFileSync('supabase/tests/'+p,'utf8')));
 for(const a of approved)actual.functions.push(Object.fromEntries(['schema','name','args','definer','config','auth_exec','anon_exec'].map(k=>[k,k==='args'?a[k].replace('extensions.vector','vector'):a[k]])));
 actual.functions.push(Object.fromEntries(['schema','name','args','definer','config','auth_exec','anon_exec'].map(k=>[k,rawGate.approved_helper[k]])));
 actual.policies.push(...clone(rawGate.approved_policies));
 return {actual,native:clone(approved),rawNative:[clone(rawGate.approved_helper)]};
}
function run(change=()=>{}){
 const dir=mkdtempSync(join(tmpdir(),'copilot-catalog-'));
 try{
  for(const p of ['history-catalog-before.json','history-catalog-query.sql','p0_crud_cadastros_catalog_expected.json','p0_crud_listas_catalog_expected.json','p0_v117_revisao_catalog_expected.json'])copyFileSync('supabase/tests/'+p,join(dir,p));
  copyFileSync(process.env.COPILOT_CATALOG_GUARD_SOURCE||'supabase/tests/history_catalog_compare.py',join(dir,'history_catalog_compare.py'));
  const data=fixture();change(data);writeFileSync(join(dir,'actual.json'),JSON.stringify(data.actual));writeFileSync(join(dir,'native.json'),JSON.stringify(data.native));writeFileSync(join(dir,'raw-native.json'),JSON.stringify(data.rawNative));mkdirSync(join(dir,'bin'));
  writeFileSync(join(dir,'bin/psql'),`#!/usr/bin/env python3\nimport sys,os,pathlib\np='raw-native.json' if \"p.proname='copilot_retorno_e_chat'\" in sys.argv[-1] else ('native.json' if 'body_md5' in sys.argv[-1] else 'actual.json')\nprint(pathlib.Path(os.environ['CATALOG_FIXTURE'],p).read_text())\n`);chmodSync(join(dir,'bin/psql'),0o700);
  return spawnSync('python3',[join(dir,'history_catalog_compare.py')],{encoding:'utf8',env:{PATH:join(dir,'bin')+':'+process.env.PATH,DB_URL:'postgresql://fixture@127.0.0.1:54322/postgres',CATALOG_FIXTURE:dir}});
 }finally{rmSync(dir,{recursive:true,force:true});}
}
test('catalog guard accepts exact nine additive contracts and retains historical metadata',()=>{const r=run();assert.equal(r.status,0,r.stderr||r.stdout);assert.match(r.stdout,/HISTORY_CATALOG_PASS/);});
for(const field of ['body_md5','owner','args','returns','language','definer','config','auth_exec','anon_exec','service_exec','public_exec','acl'])test(`native catalog rejects divergent ${field}`,()=>{
 const r=run(d=>{const n=d.native[0];n[field]=typeof n[field]==='boolean'?!n[field]:Array.isArray(n[field])?[]:'divergent';});assert.notEqual(r.status,0);assert.match(r.stderr+r.stdout,/COPILOT_NATIVE_CATALOG_FAIL/);
});
for(const mode of ['missing','duplicate','signature','extra','old_metadata'])test(`full catalog rejects ${mode} without ignoring actual rows`,()=>{
 const r=run(d=>{const f=d.actual.functions.find(f=>f.name==='worker_buscar_fragmentos_copiloto');if(mode==='missing')d.actual.functions.splice(d.actual.functions.indexOf(f),1);if(mode==='duplicate')d.actual.functions.push(clone(f));if(mode==='signature')f.args+=' extra text';if(mode==='extra')d.actual.functions.push({...f,name:'worker_copilot_extra_unapproved'});if(mode==='old_metadata')d.actual.functions.find(f=>f.name==='worker_buscar_fragmentos_temporais').auth_exec=true;});assert.notEqual(r.status,0);assert.match(r.stderr+r.stdout,/CATALOG_FAIL/);
});
// GATE191 retains the original policies exactly once; set comparison must not hide duplicates.
test('catalog rejects duplicated original chat policy instead of hiding it in a set',()=>{
 const r=run(d=>{d.actual.policies.push(clone(d.actual.policies.find(p=>p.tablename==='retornos_modelo'&&p.policyname==='retornos_modelo_select')));});
 assert.notEqual(r.status,0);assert.match(r.stderr+r.stdout,/CHAT_ORIGINAL_POLICY_FAIL/);
});

for(const field of ['body_md5','owner','args','returns','language','definer','config','auth_exec','anon_exec','service_exec','public_exec','acl'])test(`raw helper native catalog rejects divergent ${field}`,()=>{
 const r=run(d=>{const n=d.rawNative[0];n[field]=typeof n[field]==='boolean'?!n[field]:Array.isArray(n[field])?[]:'divergent';});assert.notEqual(r.status,0);assert.match(r.stderr+r.stdout,/COPILOT_RAW_NATIVE_CATALOG_FAIL/);
});
for(const mode of ['missing','duplicate','role','permissive','qual','command','extra'])test(`raw chat policy catalog rejects ${mode}`,()=>{
 const r=run(d=>{const p=d.actual.policies.find(p=>p.tablename==='retornos_modelo'&&p.policyname==='copilot_raw_chat_select');if(mode==='missing')d.actual.policies.splice(d.actual.policies.indexOf(p),1);if(mode==='duplicate')d.actual.policies.push(clone(p));if(mode==='role')p.roles=['anon'];if(mode==='permissive')p.permissive='PERMISSIVE';if(mode==='qual')p.qual='true';if(mode==='command')p.cmd='ALL';if(mode==='extra')d.actual.policies.push({...p,policyname:'unapproved_raw_chat_policy'});});assert.notEqual(r.status,0);assert.match(r.stderr+r.stdout,/CATALOG_FAIL/);
});
