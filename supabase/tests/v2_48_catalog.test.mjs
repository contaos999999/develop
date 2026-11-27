import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

test("V2 48 exige hash da migração, privilégios e corpos exatos no catálogo", () => {
  const python = String.raw`import ast,copy,hashlib,json,pathlib
root=pathlib.Path('supabase/tests')
source=root/'history_catalog_compare.py'
tree=ast.parse(source.read_text())
fn=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='reconcile_v248_catalog')
scope={'json':json}
exec(compile(ast.Module(body=[fn],type_ignores=[]),str(source),'exec'),scope)
reconcile=scope['reconcile_v248_catalog']
pins=json.loads((root/'v2_48_catalog_pins.json').read_text())
sha=hashlib.sha256((root.parent/'migrations'/'20261127105223_p0_v2_48_contestacao_evidencia.sql').read_bytes()).hexdigest()
keys=('schema','name','args','definer','config','auth_exec','anon_exec')
legacy={'aprovar_contestacao','criar_contestacao','solicitar_minuta_contestacao'}
functions=[{k:r[k] for k in keys} for r in pins['functions']]
for r in functions:
 r['args']=r['args'].replace('p_item public.apontamentos_contratante','p_item apontamentos_contratante')
 r['args']=r['args'].replace('p_versao public.contestacoes','p_versao contestacoes')
base={'functions':[r for r in functions if r['name'] in legacy],'policies':[{'name':'original'}]}
actual={**base,'functions':functions}
native={k:pins[k] for k in ('functions','guards')}
original=copy.deepcopy(base)
got=reconcile(base,actual,native,sha,pins)
assert base==original
assert all(r in got['functions'] for r in actual['functions']) and got['policies']==base['policies']
def recusar(atual,nativo,migration_sha):
 try:
  reconcile(base,atual,nativo,migration_sha,pins)
 except SystemExit as e:
  assert str(e).startswith('V248_CATALOG_FAIL:')
 else:
  raise AssertionError('A divergência deve bloquear a paridade')
recusar(actual,native,'0'*64)
mutacao=copy.deepcopy(native);mutacao['functions'][0]['body_md5']='0'*32
recusar(actual,mutacao,sha)
mutacao=copy.deepcopy(native);mutacao['functions'][0]['acl'].clear()
recusar(actual,mutacao,sha)
mutacao=copy.deepcopy(native);mutacao['guards'][1]['insert']=True
recusar(actual,mutacao,sha)
mutacao=copy.deepcopy(native);mutacao['guards'][0]['rls']=False
recusar(actual,mutacao,sha)
recusar({**actual,'functions':functions[1:]},native,sha)
recusar({**actual,'functions':functions+[functions[0]]},native,sha)
`;
  const result = spawnSync("python3", ["-c", python], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
});
