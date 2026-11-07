import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,chmodSync,rmSync,copyFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import vm from 'node:vm';
const root=resolve('.');
const cases=[
  {file:'p0-crud-listas-hml.yml',target:'canonical-deploy',task:'P0-CRUD-LISTAS-20261107',phase:'BUILD_EM_VALIDACAO',migration:'20261107001620_p0_crud_listas_verificacao.sql'},
  {file:'p0-v117-revisao-hml.yml',target:'canonical-deploy',task:'P0-V117-REVISAO-20261107',phase:'BUILD_EM_VALIDACAO',migration:'20261107094443_p0_v117_revisao_humana.sql'},
  {file:'p0-v117-browser-hml.yml',target:'private-browser',task:'P0-V117-REVISAO-20261107',phase:'BUILD_PROVA_PRIVADA_FRONTEND'},
];
const workflow=c=>readFileSync(join(root,'.github/workflows',c.file),'utf8');
function job(source,name){return source.match(new RegExp('^  '+name+':\\n([\\s\\S]*?)(?=^  [a-z][a-z-]*:|$(?![\\s\\S]))','m'))?.[1]||'';}
function runs(section){return [...section.matchAll(/^        run: \|\n((?:^          .*\n|^\n)+)/gm)].map(m=>m[1].split('\n').map(l=>l.startsWith('          ')?l.slice(10):l).join('\n'));}
function enabled(section,context){const expr=section.match(/^    if: (.+)$/m)?.[1];assert(expr,'job needs an explicit condition');return vm.runInNewContext(expr,context,{timeout:100})===true;}
function event(overrides={}){return {github:{event_name:'workflow_run',repository:'contaos999999/develop',event:{workflow_run:{conclusion:'success',event:'push',head_branch:'main',head_repository:{full_name:'contaos999999/develop'},...overrides}}}};}
function fixture(fn){const dir=mkdtempSync(join(tmpdir(),'contaos-routing-'));try{mkdirSync(join(dir,'docs/tasks'),{recursive:true});mkdirSync(join(dir,'bin'));return fn(dir);}finally{rmSync(dir,{recursive:true,force:true});}}
function taskfile(dir,t){writeFileSync(join(dir,'docs/tasks/active-task.json'),JSON.stringify(t));}
function run(script,dir,extra={}){return spawnSync('bash',['-e','-o','pipefail','-c',script],{cwd:dir,env:{PATH:join(dir,'bin')+':'+process.env.PATH,GITHUB_OUTPUT:join(dir,'output'),RUNNER_TEMP:dir,...extra},encoding:'utf8',timeout:10000});}
for(const c of cases){
  test(c.file+': routing occurs before privileged jobs',()=>{
    const scope=job(workflow(c),'scope');assert(scope,'read-only scope job is required');assert.match(scope,/contents: read/);assert.doesNotMatch(scope,/secrets\.|GH_TOKEN|actions: write|environment:/);
    const target=job(workflow(c),c.target);assert.match(target,/^    needs: scope$/m);
    for(const applicable of ['false','true'])assert.equal(enabled(target,{needs:{scope:{result:'success',outputs:{applicable}}}}),applicable==='true');
    assert.equal(enabled(target,{needs:{scope:{result:'failure',outputs:{applicable:'true'}}}}),false);
  });
  test(c.file+': rejects PR, foreign source, failed restore and non-main before checkout',()=>{
    const scope=job(workflow(c),'scope');assert.equal(enabled(scope,event()),true);
    for(const override of [{event:'pull_request'},{head_repository:{full_name:'outsider/fork'}},{conclusion:'failure'},{head_branch:'feature'}])assert.equal(enabled(scope,event(override)),false);
    const pr=event();pr.github.event_name='pull_request';assert.equal(enabled(scope,pr),false);
  });
  test(c.file+': execute real selection shell for exact task and phase',()=>fixture(dir=>{
    const [script]=runs(job(workflow(c),'scope'));assert(script,'selection script is required');
    for(const [task,phase,want] of [[c.task,c.phase,'true'],['UNRELATED',c.phase,'false'],[c.task,'PLAN_ROTEAMENTO_WORKFLOW_HML','false'],[c.task,'GATE_PROVA_PRIVADA_VALIDADO','false']]){
      taskfile(dir,{id:task,phase});writeFileSync(join(dir,'output'),'');const r=run(script,dir);assert.equal(r.status,0,r.stderr);assert.match(readFileSync(join(dir,'output'),'utf8'),new RegExp('^applicable='+want+'$','m'));
    }
    taskfile(dir,{id:c.task});writeFileSync(join(dir,'output'),'');assert.notEqual(run(script,dir).status,0,'malformed manifest must fail rather than skip');
    assert.doesNotMatch(readFileSync(join(dir,'output'),'utf8'),/applicable=true/);
  }));
  test(c.file+': missing required CI still fails in the real material gate',()=>fixture(dir=>{
    const sha='a'.repeat(40);taskfile(dir,{id:c.task,phase:c.phase,database_changes_allowed:true,allowed_paths:c.migration?['supabase/migrations/'+c.migration]:[],browser_proof_scope:{frontend_head:'b'.repeat(40)}});
    if(c.migration){mkdirSync(join(dir,'supabase/migrations'),{recursive:true});copyFileSync(join(root,'supabase/migrations',c.migration),join(dir,'supabase/migrations',c.migration));}
    const gh=join(dir,'bin/gh');writeFileSync(gh,`#!/usr/bin/env python3\nimport sys,os,json\nif any('/commits/main' in a for a in sys.argv):\n print(os.environ['TESTED_HEAD'] if '--jq' in sys.argv else json.dumps({'sha':os.environ['TESTED_HEAD']}))\nelse: print(open(os.environ['CHECKS_FIXTURE']).read())\n`);chmodSync(gh,0o700);
    const [gate]=runs(job(workflow(c),c.target));assert(gate);
    for(const missing of ['guard','reconstruir-banco-do-zero','prova-backup-dados-sinteticos-duas-instancias']){
      writeFileSync(join(dir,'checks-fixture.json'),JSON.stringify({check_runs:['guard','reconstruir-banco-do-zero','prova-backup-dados-sinteticos-duas-instancias'].filter(n=>n!==missing).map(name=>({name,head_sha:sha,conclusion:'success'}))}));
      const r=run(gate,dir,{TESTED_HEAD:sha,GH_REPO:'contaos999999/develop',CHECKS_FIXTURE:join(dir,'checks-fixture.json')});assert.notEqual(r.status,0,'missing '+missing+' cannot pass');assert.match(r.stderr,new RegExp(missing),'failure must come from required CI, not fixture setup');
    }
  }));
}
test('deploy dispatch and independent quarantine remain guarded',()=>{
  for(const c of cases){const s=workflow(c);if(c.target==='canonical-deploy'){assert.match(s,/expected_source_sha="\$TESTED_HEAD"/);assert.match(s,/expected_migration_sha256=/);assert.match(job(s,'real-jwt'),/needs: canonical-deploy/);}
    assert.match(s,/Retry own fixture quarantine independently|Independent own fixture quarantine retry/);assert.match(s,/if: always\(\)/);assert.match(s,/--cleanup/);
  }
});
