import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
const path='supabase/migrations/20261108184219_fix_reviewed_metadata_append_version.sql';
test('reviewed metadata appends and leaves the historical mutation guard untouched',()=>{
 assert(fs.existsSync(path),'additive metadata append migration required');
 const sql=fs.readFileSync(path,'utf8').replace(/^--.*$/gm,'');
 assert.doesNotMatch(sql,/update\s+public\.versoes_documento|(?:disable|drop|alter|create)\s+(?:or\s+replace\s+)?trigger/i);
 assert.match(sql,/insert into public\.versoes_documento/);
 assert.match(sql,/public\.documentos_contrato[^;]+for update/);
 assert.match(sql,/public\.documentos_competencia[^;]+for update/);
 assert.match(sql,/v_base\.numero_versao<>v_atual/);
 assert.match(sql,/privado\.enfileirar_job/);
});
test('metadata migration preserves the full original API guards and other review branches',()=>{
 const r=spawnSync('python3',['-c',String.raw`import pathlib,hashlib,re
old=pathlib.Path('supabase/migrations/20261106014102_p0_v1_rbac_persistente.sql').read_text()
start=old.index('CREATE OR REPLACE FUNCTION privado.revisar_sugestao_extracao(')
start_body=old.index('$function$',start)+len('$function$');end_body=old.index('$function$',start_body)
old=old[start:end_body+len('$function$')]
assert hashlib.md5(old.split('$function$')[1].encode()).hexdigest()=='6c790a96348eeece99cd40ca2d9dedfb'
new=pathlib.Path('supabase/migrations/20261108184219_fix_reviewed_metadata_append_version.sql').read_text();new=new[new.index('CREATE OR REPLACE FUNCTION'):].strip().rstrip(';')
def outside(s):
 s=re.sub(r'declare .*?\nbegin','declare CONTROLLED_DECLARATIONS\nbegin',s,count=1,flags=re.S)
 a=s.index("  elsif v.tipo='metadado' then");b=s.index("  else\n    insert into public.regras_conformidade",a)
 s=s[:a]+'  CONTROLLED_APPEND_BRANCH\n'+s[b:]
 s=re.sub(r"  return jsonb_build_object\('status','aprovada'.*?;",'  return CONTROLLED_COMPATIBLE_RESPONSE;',s,count=1)
 return s
assert outside(new)==outside(old),'Unapproved business guard/branch changed'
assert "'status','aprovada','id_regra_rascunho',v_regra" in new
assert "'id_versao',v_nova" in new and "'id_job',v_job" in new
`],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});

test('metadata migration planner refuses catalog, trigger and history drift',()=>{
 const code=String.raw`import sys,copy,hashlib,pathlib
sys.path.insert(0,'supabase/tests')
from remaining_domains.metadata_migration import migration_plan,expected_catalog,VERSION,FILE,REVIEWED_SQL_SHA256
assert hashlib.sha256(pathlib.Path(FILE).read_bytes()).hexdigest()==REVIEWED_SQL_SHA256
local=['1',VERSION]
assert migration_plan(local,['1'],expected_catalog(False))=='APPLY_ONE'
assert migration_plan(local,local,expected_catalog(True))=='ALREADY_APPLIED'
for l,r,c in [(local,[],expected_catalog(False)),(local,local,expected_catalog(False)),(local,['1'],expected_catalog(True))]:
 try:migration_plan(l,r,c)
 except AssertionError:pass
 else:raise AssertionError('unapproved history/catalog accepted')
for key,value in [('body_md5','0'*32),('definer',False),('owner','other'),('acl','foreign'),('auth_exec',False),('anon_exec',True),('config',[])]:
 c=copy.deepcopy(expected_catalog(False));c['functions'][1][key]=value
 try:migration_plan(local,['1'],c)
 except AssertionError:pass
 else:raise AssertionError('function drift accepted '+key)
c=expected_catalog(False);c['historical_trigger']['enabled']='D'
try:migration_plan(local,['1'],c)
except AssertionError:pass
else:raise AssertionError('immutability drift accepted')
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});

test('append SQL honors generated document identity and initial version CAS',()=>{
 const sql=fs.readFileSync(path,'utf8');
 const columns=sql.match(/insert into public\.versoes_documento\(([^)]+)\)/)[1].split(',');
 assert(!columns.includes('id_documento'),'generated identity must be computed by PostgreSQL');
 const local=fs.readFileSync('supabase/tests/remaining_domains/metadata_append_local.sql','utf8');
 assert.match(local,/documentos_contrato\(.*versao_atual\) values .*source',1\)/);
 assert.match(local,/documentos_competencia\(.*versao_atual\) values\s*.*metadata',1\)/);
});
