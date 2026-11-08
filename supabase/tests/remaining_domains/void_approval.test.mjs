import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
test('void opinion approval accepts only 204 while all other RPCs retain exact 200 and SQL checks',()=>{
 const code=String.raw`import sys,copy
sys.path.insert(0,'supabase/tests')
import p0_crud_global_remaining_hml as m
req=m.REQUIRED['apresentacao']
r={'domain':'apresentacao','global_complete':False,'assertions':[{'name':n,'passed':True} for n in req['checks']],'receipts':[{'operation':n,'role':'administrador','http':200} for n in req['rpc']]+[{'operation':'aprovar_parecer_interno','role':'master','http':204}]+[{'role':x,'http':403} for x in ['leitor','usuario_b','anon']]}
m.assert_complete(r,'apresentacao')
for operation,role,status in [('aprovar_parecer_interno','master',200),('aprovar_apresentacao','administrador',204)]:
 bad=copy.deepcopy(r)
 for x in bad['receipts']:
  if x.get('operation')==operation and x.get('role')==role:x['http']=status
 try:m.assert_complete(bad,'apresentacao')
 except AssertionError:pass
 else:raise AssertionError('Wrong RPC HTTP contract accepted')
bad=copy.deepcopy(r)
for x in bad['assertions']:
 if x['name']=='FLOW_SQL_OPINION_APPROVAL':x['passed']=False
try:m.assert_complete(bad,'apresentacao')
except AssertionError:pass
else:raise AssertionError('204 without actual SQL approval accepted')
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});
