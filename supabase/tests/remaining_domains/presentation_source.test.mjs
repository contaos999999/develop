import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
test('presentation material item gets an approved active applicable source through real RPCs',()=>{
 const code=String.raw`import sys
sys.path.insert(0,'supabase/tests')
from remaining_domains.apresentacao import formal_source
class Runner:
 fixture={'org':'own-org','contract':'own-contract','prefix':'own-prefix','nonce':'own-nonce'}
 def __init__(self):self.calls=[];self.checks=[]
 def entity(self,k,v):return v
 def operation(self,name,p):
  self.calls.append((name,p))
  if name=='salvar_fonte_normativa_v107':return {'fonte':{'id':'own-source','versao_registro':1}}
  if name=='registrar_versao_fonte_v107':return {'versao':{'id':'own-version','hash':'a'*64}}
  return {}
 def sql_check(self,name,sql):self.checks.append((name,sql));assert sql.startswith('select ')
r=Runner();assert formal_source(r)=='own-version'
assert [x[0] for x in r.calls]==['salvar_fonte_normativa_v107','registrar_versao_fonte_v107','aprovar_versao_fonte_v107','salvar_fonte_normativa_v107','definir_aplicabilidade_fonte_v107']
assert r.calls[0][1]['p_situacao']=='rascunho'
assert r.calls[2][1]['p_hash_esperado']=='a'*64
assert r.calls[3][1]['p_situacao']=='ativa' and r.calls[3][1]['p_versao_esperada']==1
assert r.calls[4][1]['p_aplicavel'] is True
assert r.checks[0][0]=='FLOW_FORMAL_SOURCE'
`;
 const r=spawnSync('python3',['-c',code],{encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});
