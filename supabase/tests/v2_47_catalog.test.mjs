import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

test("a paridade exige migração, chaves, ACLs, tipos e corpos exatos do V2 47", () => {
  const python = String.raw`import ast,copy,hashlib,json,pathlib
root=pathlib.Path('supabase/tests')
source=root/'history_catalog_compare.py'
tree=ast.parse(source.read_text())
fn=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='reconcile_v247_catalog')
scope={'json':json}
exec(compile(ast.Module(body=[fn],type_ignores=[]),str(source),'exec'),scope)
reconcile=scope['reconcile_v247_catalog']
pins=json.loads((root/'v2_47_catalog_pins.json').read_text())
sha=hashlib.sha256((root.parent/'migrations'/'20261127050308_p0_v2_47_tarefa_vinculo_revalidacao.sql').read_bytes()).hexdigest()
keys=('schema','name','args','definer','config','auth_exec','anon_exec')
legacy={'atualizar_tarefa_diligencia','concluir_tarefa_diligencia','revisar_solucao_tarefa_diligencia'}
functions=[{k:r[k] for k in keys} for r in pins['functions']]
for r in functions:
 r['args']=r['args'].replace('p_tarefa public.tarefas_diligencia','p_tarefa tarefas_diligencia')
base={'columns':[],'functions':[r for r in functions if r['name'] in legacy],'policies':[{'name':'original'}]}
actual={**base,'columns':pins['columns'],'functions':functions}
native={key:pins[key] for key in ('functions','guards')}
original=copy.deepcopy(base)
got=reconcile(base,actual,native,sha,pins)
assert all(r in got['functions'] for r in actual['functions']) and got['columns']==pins['columns']
assert base==original and got['policies']==base['policies']
def recusar(atual,nativo,migration_sha):
 try:
  reconcile(base,atual,nativo,migration_sha,pins)
 except SystemExit as exc:
  assert str(exc).startswith('V247_CATALOG_FAIL:')
 else:
  raise AssertionError('A divergência deve bloquear a paridade')
recusar(actual,native,'0'*64)
mutacao=copy.deepcopy(native)
mutacao['functions'][0]['body_md5']='alterado'
recusar(actual,mutacao,sha)
mutacao=copy.deepcopy(native)
mutacao['functions'][0]['acl'].append({'grantee':'PUBLIC','privilege':'EXECUTE','grantable':False})
recusar(actual,mutacao,sha)
mutacao=copy.deepcopy(native)
mutacao['functions'].append(mutacao['functions'][0])
recusar(actual,mutacao,sha)
mutacao=copy.deepcopy(native)
mutacao['guards']['index']['valid']=False
recusar(actual,mutacao,sha)
mutacao=copy.deepcopy(native)
mutacao['guards']['table_privileges'][1]['update']=True
recusar(actual,mutacao,sha)
recusar({**actual,'columns':[]},native,sha)
recusar({**actual,'functions':functions[:-1]},native,sha)
`;
  const result = spawnSync("python3", ["-c", python], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
});
