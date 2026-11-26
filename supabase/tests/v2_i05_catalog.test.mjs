import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

test("I05 reconcilia apenas os oito objetos autorizados e exige SHA, forma e permissões exatos", () => {
  const example = String.raw`import ast,copy,hashlib,json,pathlib
guard=pathlib.Path('supabase/tests/history_catalog_compare.py')
source=ast.parse(guard.read_text())
allowed={'I05_COLUMNS','I05_NATIVE','I05_MIGRATION_SHA256','reconcile_v2_i05_catalog'}
definitions=[x for x in source.body if
  (isinstance(x,ast.Assign) and any(getattr(t,'id','') in allowed for t in x.targets))
  or (isinstance(x,ast.FunctionDef) and x.name in allowed)]
scope={'json':json}
exec(compile(ast.Module(body=definitions,type_ignores=[]),str(guard),'exec'),scope)
reconcile=scope['reconcile_v2_i05_catalog']
migration=pathlib.Path('supabase/migrations/20261126221545_v2_i05_proveniencia_apontamentos.sql')
sha=hashlib.sha256(migration.read_bytes()).hexdigest()
assert sha==scope['I05_MIGRATION_SHA256']
expected={'columns':[{'name':'historico'}],'functions':[], 'policies':[{'name':'original'}]}
columns=scope['I05_COLUMNS']
native=scope['I05_NATIVE']
keys=('schema','name','args','definer','config','auth_exec','anon_exec')
actual={'columns':expected['columns']+columns,'functions':[{k:r[k] for k in keys} for r in native],
 'policies':[{'name':'original'}]}
initial=copy.deepcopy(expected)
assert reconcile(expected,actual,native,sha)==actual
assert expected==initial
extra=copy.deepcopy(actual)
extra['functions'].append({'name':'fora_do_escopo'})
assert reconcile(expected,extra,native,sha)==actual

vectors=[]
missing=copy.deepcopy(actual);missing['columns'].pop();vectors.append((missing,native,sha))
duplicate=copy.deepcopy(actual);duplicate['functions'].append(duplicate['functions'][0]);vectors.append((duplicate,native,sha))
changed=copy.deepcopy(actual);changed['columns'][-1]['type']='integer';vectors.append((changed,native,sha))
for field,value in (('body_md5','0'*32),('owner','outro'),('service_exec',False),('config',[])):
 altered=copy.deepcopy(native);altered[-1][field]=value;vectors.append((actual,altered,sha))
vectors.append((actual,native,'0'*64))
for observed,routines,digest in vectors:
 try:
  reconcile(expected,observed,routines,digest)
 except SystemExit as e:
  assert str(e).startswith('V2_I05_CATALOG_FAIL')
 else:
  raise AssertionError('delta I05 não autorizado foi aceito')
print('V2_I05_CATALOG_TEST_PASS')
`;
  const result = spawnSync("python3", ["-c", example], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /V2_I05_CATALOG_TEST_PASS/);
});
