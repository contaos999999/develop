import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const file='supabase/migrations/20261108054500_fix_document_upload_wrapper.sql';
test('document upload wrapper change is a single exact security attribute',()=>{
 assert.ok(fs.existsSync(file),'new additive wrapper migration required');
 const sql=fs.readFileSync(file,'utf8').replace(/^--.*$/gm,'').trim();
 assert.equal(sql,'ALTER FUNCTION public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text) SECURITY DEFINER;');
});

import {spawnSync} from 'node:child_process';
test('catalog delta accepts only exact unique approved metadata and preserves inputs',()=>{
 const code=String.raw`import ast, pathlib, json, copy
source=ast.parse(pathlib.Path('supabase/tests/history_catalog_compare.py').read_text())
node=next((n for n in source.body if isinstance(n,ast.FunctionDef) and n.name=='reconcile_document_upload_wrapper'),None)
assert node is not None,'exact catalog contract required'
ns={}
exec(compile(ast.Module(body=[node],type_ignores=[]),'<catalog-contract>','exec'),ns)
fn=ns['reconcile_document_upload_wrapper']
record=next(x for x in json.loads(pathlib.Path('supabase/tests/history-catalog-before.json').read_text())['functions'] if x['name']=='criar_documento_contrato_completo')
approved={**record,'definer':True}
expected={'functions':[copy.deepcopy(record)],'sentinel':[{'keep':True}]}
actual={'functions':[copy.deepcopy(approved)],'sentinel':[{'keep':True}]}
before=copy.deepcopy(expected); real=copy.deepcopy(actual)
result=fn(expected,actual)
assert result==actual and result is not expected
assert expected==before and actual==real
for field,value in [('schema','privado'),('name','other'),('args',''),('config',[]),('definer',False),('auth_exec',False),('anon_exec',True)]:
 altered={**approved,field:value}
 try:fn(expected,{'functions':[altered]})
 except SystemExit:pass
 else:raise AssertionError('accepted drift '+field)
for e,a in [([], [approved]),([record,record],[approved]),([record],[]),([record],[approved,approved])]:
 try:fn({'functions':e},{'functions':a})
 except SystemExit:pass
 else:raise AssertionError('accepted missing/duplicate contract')
foreign={'schema':'other','name':'unexpected'}
real_extra={'functions':[approved,foreign]}
result=fn(expected,real_extra)
assert result['functions']==[approved] and real_extra['functions']==[approved,foreign]
assert result['functions']!=real_extra['functions'],'unapproved drift must remain visible'
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});
 assert.equal(r.status,0,r.stderr||r.stdout);
});
