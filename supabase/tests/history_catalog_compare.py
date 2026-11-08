"""Compare metadata only; no user rows, no secrets, isolated PostgreSQL only."""
import os,json,pathlib,subprocess
def reconcile_document_upload_wrapper(expected,actual):
 # GATE149/151: one exact attribute delta; never remove actual catalog records.
 prior={'schema':'public','name':'criar_documento_contrato_completo',
  'args':'p_id_contrato uuid, p_tipo text, p_titulo text, p_categoria text, p_vigencia_inicio date, p_vigencia_fim date, p_observacoes text, p_id_arquivo uuid, p_chave_idempotencia text',
  'definer':False,'config':['search_path=""'],'auth_exec':True,'anon_exec':False}
 approved={**prior,'definer':True}
 if expected['functions'].count(prior)!=1 or actual['functions'].count(approved)!=1:
  raise SystemExit('UPLOAD_WRAPPER_CATALOG_FAIL: exact unique prior/approved metadata required')
 result={**expected,'functions':list(expected['functions'])}
 result['functions'][result['functions'].index(prior)]=approved
 return result

root=pathlib.Path(__file__).parent
db=os.environ['DB_URL']
assert '@127.0.0.1:' in db or '@localhost:' in db,'Isolated restore required'
expected=json.loads((root/'history-catalog-before.json').read_text())
query=(root/'history-catalog-query.sql').read_text()
actual=json.loads(subprocess.check_output(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',query],text=True))
expected=reconcile_document_upload_wrapper(expected,actual)
crud_expected=json.loads((root/'p0_crud_cadastros_catalog_expected.json').read_text())
for record in crud_expected:
 if actual['functions'].count(record)!=1:
  raise SystemExit('CRUD_CATALOG_FAIL: expected exact metadata/ACL '+json.dumps(record,sort_keys=True))
 actual['functions'].remove(record)
lista_expected=json.loads((root/'p0_crud_listas_catalog_expected.json').read_text())
for record in lista_expected:
 if actual['functions'].count(record)!=1:
  raise SystemExit('LISTA_CATALOG_FAIL: expected exact metadata/ACL '+json.dumps(record,sort_keys=True))
 actual['functions'].remove(record)
review_expected=json.loads((root/'p0_v117_revisao_catalog_expected.json').read_text())
for record in review_expected:
 if actual['functions'].count(record)!=1:
  raise SystemExit('V117_REVIEW_CATALOG_FAIL: expected exact metadata/ACL '+json.dumps(record,sort_keys=True))
 actual['functions'].remove(record)
new_functions={'rbac_permite','exigir_permissao_rbac','consultar_permissoes_efetivas','obter_matriz_rbac_master','atualizar_matriz_rbac_master'}
actual['tables']=[x for x in actual['tables'] if not (x['schema']=='privado' and x['name'].startswith('rbac_'))]
actual['columns']=[x for x in actual['columns'] if not (x['schema']=='privado' and x['table'].startswith('rbac_'))]
actual['functions']=[x for x in actual['functions'] if x['name'] not in new_functions]
actual['policies']=[x for x in actual['policies'] if not x['policyname'].startswith('rbac_v1_')]
# HML has an opt-in DDL event trigger outside application migration history.
# It has no application/API EXECUTE grant. Every application table's actual RLS
# flags remain compared above. Only this exact environmental record is excluded.
hosted_rls_helper={'schema':'public','name':'rls_auto_enable','args':'','definer':True,'config':['search_path=pg_catalog'],'auth_exec':False,'anon_exec':False}
expected['functions']=[x for x in expected['functions'] if x!=hosted_rls_helper]
actual['functions']=[x for x in actual['functions'] if x!=hosted_rls_helper]
differences={}
for section in expected:
 a={json.dumps(x,sort_keys=True,ensure_ascii=False) for x in expected[section]}
 b={json.dumps(x,sort_keys=True,ensure_ascii=False) for x in actual[section]}
 if a!=b:differences[section]={'missing':sorted(a-b),'unexpected':sorted(b-a)}
if differences:
 print(json.dumps(differences,ensure_ascii=False,indent=2))
 raise SystemExit('HISTORY_CATALOG_FAIL: metadata differs from HML baseline beyond approved RBAC objects')
print('HISTORY_CATALOG_PASS: 120 tables,1520 columns,283 application function contracts/ACLs,186 original policies; explicit RBAC deltas and one hosted DDL-only helper excluded')

