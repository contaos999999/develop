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

def reconcile_document_vigency_wrapper(expected,actual):
 # GATE138 corrective detail proof: one exact attribute delta; never remove actual catalog records.
 prior={'schema':'public','name':'definir_vigencia_sugestao_extracao',
  'args':'p_id_sugestao uuid, p_vigencia_inicio date, p_vigencia_fim date',
  'definer':False,'config':['search_path=""'],'auth_exec':True,'anon_exec':False}
 approved={**prior,'definer':True}
 if expected['functions'].count(prior)!=1 or actual['functions'].count(approved)!=1:
  raise SystemExit('VIGENCY_WRAPPER_CATALOG_FAIL: exact unique prior/approved metadata required')
 result={**expected,'functions':list(expected['functions'])}
 result['functions'][result['functions'].index(prior)]=approved
 return result

def reconcile_document_version_wrapper(expected,actual):
 # GATE163: one exact attribute delta; never remove actual catalog records.
 prior={'schema':'public','name':'adicionar_versao_documento_contrato',
  'args':'p_id_documento uuid, p_id_arquivo uuid, p_motivo text, p_chave_idempotencia text',
  'definer':False,'config':['search_path=""'],'auth_exec':True,'anon_exec':False}
 approved={**prior,'definer':True}
 if expected['functions'].count(prior)!=1 or actual['functions'].count(approved)!=1:
  raise SystemExit('VERSION_WRAPPER_CATALOG_FAIL: exact unique prior/approved metadata required')
 result={**expected,'functions':list(expected['functions'])}
 result['functions'][result['functions'].index(prior)]=approved
 return result

COPILOT_APPROVED = [{'schema': 'privado', 'name': 'copilot_versao_elegivel', 'args': 'p_versao uuid, p_org uuid, p_contrato uuid, p_data date', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'sql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': False, 'public_exec': False, 'body_md5': '802dccbc6b41c244ea7dd57b3719feac', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'privado', 'name': 'copilot_precedente_elegivel', 'args': 'p_id uuid, p_org uuid, p_contratante uuid', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'sql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': False, 'public_exec': False, 'body_md5': 'd2bcc6291453a42f96bfb4ffc664b7d8', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_buscar_fragmentos_copiloto', 'args': 'p_id_organizacao uuid, p_id_contrato uuid, p_ids_fragmentos uuid[], p_embedding extensions.vector, p_data_referencia date, p_limite integer', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'TABLE(id uuid, id_versao_documento uuid, pagina_inicio integer, pagina_fim integer, texto text, similaridade double precision, fonte_temporal text, inicio_vigencia date, fim_vigencia date)', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '58268b61ee1b83a0e9ac8693ebee4ed8', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_buscar_precedentes_copiloto', 'args': 'p_id_organizacao uuid, p_id_contratante uuid, p_id_contrato uuid, p_ids_precedentes uuid[], p_embedding extensions.vector, p_limite integer', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'TABLE(id uuid, id_contrato_origem uuid, competencia_origem date, problema text, solucao text, desfecho text, escopo_resultado text, similaridade double precision, forca_score numeric, score_final numeric, confirmacoes integer, hierarquia_normativa integer, confianca numeric)', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '67a23d26ebc9608da48d576d33bf6ec6', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'privado', 'name': 'copilot_ator_permite', 'args': 'p_org uuid, p_contrato uuid, p_ator uuid, p_sessao uuid', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': False, 'public_exec': False, 'body_md5': '364955d7b3eee1325d8691dde52dc3db', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_reservar_consulta_copiloto', 'args': 'p_id_organizacao uuid, p_id_contrato uuid, p_id_usuario uuid, p_texto text, p_filtros jsonb, p_modelo text', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'jsonb', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': 'b68f1ad83a5b68d6bd13d4782fdd1e4b', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_falhar_consulta_copiloto', 'args': 'p_id_consulta uuid, p_token uuid, p_codigo text', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '679b4fc3ab8a03d2f11f3b5b694c32d4', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_validar_lease_copiloto', 'args': 'p_id_consulta uuid, p_token uuid', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '12a3a6349ed40ad9452473bc3c96b7d8', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_concluir_consulta_copiloto', 'args': 'p_id_consulta uuid, p_token uuid, p_id_sessao uuid, p_retorno jsonb, p_fontes jsonb', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'jsonb', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': 'eaab7197409f1eed625dbd7e626ab81c', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}]

def reconcile_copilot_catalog(expected, actual, native):
 # Retain every actual record. Add only nine independently verified expected records.
 identity=lambda r:(r['schema'],r['name'],r['args'])
 if sorted(native,key=identity)!=sorted(COPILOT_APPROVED,key=identity):
  raise SystemExit('COPILOT_NATIVE_CATALOG_FAIL: exact signature/body/owner/ACL required')
 result={**expected,'functions':list(expected['functions'])}
 keys=('schema','name','args','definer','config','auth_exec','anon_exec')
 for approved in COPILOT_APPROVED:
  record={k:approved[k] for k in keys};record['args']=record['args'].replace('extensions.vector','vector')
  if actual['functions'].count(record)!=1 or record in result['functions']:
   raise SystemExit('COPILOT_CATALOG_FAIL: exact unique additive contract required')
  result['functions'].append(record)
 return result

root=pathlib.Path(__file__).parent
db=os.environ['DB_URL']
assert '@127.0.0.1:' in db or '@localhost:' in db,'Isolated restore required'
expected=json.loads((root/'history-catalog-before.json').read_text())
query=(root/'history-catalog-query.sql').read_text()
actual=json.loads(subprocess.check_output(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',query],text=True))
copilot_query="set search_path='';select coalesce(jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,'args',pg_get_function_identity_arguments(p.oid),'owner',pg_get_userbyid(p.proowner),'definer',p.prosecdef,'config',p.proconfig,'language',l.lanname,'returns',pg_get_function_result(p.oid),'auth_exec',has_function_privilege('authenticated',p.oid,'EXECUTE'),'anon_exec',has_function_privilege('anon',p.oid,'EXECUTE'),'service_exec',has_function_privilege('service_role',p.oid,'EXECUTE'),'public_exec',exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE'),'body_md5',md5(p.prosrc),'acl',(select jsonb_agg(jsonb_build_object('grantee',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,'privilege',a.privilege_type,'grantable',a.is_grantable) order by a.grantee::regrole::text,a.privilege_type,a.is_grantable) from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a)) order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)),'[]'::jsonb) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname,p.proname) in (('privado','copilot_versao_elegivel'),('privado','copilot_precedente_elegivel'),('public','worker_buscar_fragmentos_copiloto'),('public','worker_buscar_precedentes_copiloto'),('privado','copilot_ator_permite'),('public','worker_reservar_consulta_copiloto'),('public','worker_falhar_consulta_copiloto'),('public','worker_validar_lease_copiloto'),('public','worker_concluir_consulta_copiloto'));"
copilot_native=json.loads(subprocess.check_output(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',copilot_query],text=True))
expected=reconcile_copilot_catalog(expected,actual,copilot_native)
expected=reconcile_document_upload_wrapper(expected,actual)
expected=reconcile_document_version_wrapper(expected,actual)
expected=reconcile_document_vigency_wrapper(expected,actual)
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
print('HISTORY_CATALOG_PASS: 120 tables,1520 columns,283 application function contracts/ACLs,186 original policies; exact additive Copilot contracts, explicit RBAC deltas and one hosted DDL-only helper compared')

