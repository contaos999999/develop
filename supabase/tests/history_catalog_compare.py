"""Compare metadata only; no user rows, no secrets, isolated PostgreSQL only."""
import hashlib,os,json,pathlib,subprocess
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

COPILOT_APPROVED = [{'schema': 'privado', 'name': 'copilot_versao_elegivel', 'args': 'p_versao uuid, p_org uuid, p_contrato uuid, p_data date', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'sql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': False, 'public_exec': False, 'body_md5': '802dccbc6b41c244ea7dd57b3719feac', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'privado', 'name': 'copilot_precedente_elegivel', 'args': 'p_id uuid, p_org uuid, p_contratante uuid', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'sql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': False, 'public_exec': False, 'body_md5': 'd2bcc6291453a42f96bfb4ffc664b7d8', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_buscar_fragmentos_copiloto', 'args': 'p_id_organizacao uuid, p_id_contrato uuid, p_ids_fragmentos uuid[], p_embedding extensions.vector, p_data_referencia date, p_limite integer', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'TABLE(id uuid, id_versao_documento uuid, pagina_inicio integer, pagina_fim integer, texto text, similaridade double precision, fonte_temporal text, inicio_vigencia date, fim_vigencia date)', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '58268b61ee1b83a0e9ac8693ebee4ed8', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_buscar_precedentes_copiloto', 'args': 'p_id_organizacao uuid, p_id_contratante uuid, p_id_contrato uuid, p_ids_precedentes uuid[], p_embedding extensions.vector, p_limite integer', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'TABLE(id uuid, id_contrato_origem uuid, competencia_origem date, problema text, solucao text, desfecho text, escopo_resultado text, similaridade double precision, forca_score numeric, score_final numeric, confirmacoes integer, hierarquia_normativa integer, confianca numeric)', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '67a23d26ebc9608da48d576d33bf6ec6', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'privado', 'name': 'copilot_ator_permite', 'args': 'p_org uuid, p_contrato uuid, p_ator uuid, p_sessao uuid', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': False, 'public_exec': False, 'body_md5': '364955d7b3eee1325d8691dde52dc3db', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_reservar_consulta_copiloto', 'args': 'p_id_organizacao uuid, p_id_contrato uuid, p_id_usuario uuid, p_texto text, p_filtros jsonb, p_modelo text', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'jsonb', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': 'b68f1ad83a5b68d6bd13d4782fdd1e4b', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_falhar_consulta_copiloto', 'args': 'p_id_consulta uuid, p_token uuid, p_codigo text', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '679b4fc3ab8a03d2f11f3b5b694c32d4', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_validar_lease_copiloto', 'args': 'p_id_consulta uuid, p_token uuid', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'boolean', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '12a3a6349ed40ad9452473bc3c96b7d8', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}, {'schema': 'public', 'name': 'worker_concluir_consulta_copiloto', 'args': 'p_id_consulta uuid, p_token uuid, p_id_sessao uuid, p_retorno jsonb, p_fontes jsonb', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'plpgsql', 'returns': 'jsonb', 'auth_exec': False, 'anon_exec': False, 'service_exec': True, 'public_exec': False, 'body_md5': '89f0e4cb991822e0cc229b489670e5b0', 'acl': [{'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'service_role', 'privilege': 'EXECUTE', 'grantable': False}]}]

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

COPILOT_RAW_APPROVED = {'schema': 'privado', 'name': 'copilot_retorno_e_chat', 'args': 'p_id_retorno uuid, p_id_consulta uuid', 'owner': 'postgres', 'definer': True, 'config': ['search_path=""'], 'language': 'sql', 'returns': 'boolean', 'auth_exec': True, 'anon_exec': False, 'service_exec': False, 'public_exec': False, 'body_md5': '00d8c4583b2b5bb27ad872cd370dffba', 'acl': [{'grantee': 'authenticated', 'privilege': 'EXECUTE', 'grantable': False}, {'grantee': 'postgres', 'privilege': 'EXECUTE', 'grantable': False}]}
COPILOT_RAW_POLICIES = [{'schemaname': 'public', 'tablename': 'retornos_modelo', 'policyname': 'copilot_raw_chat_select', 'permissive': 'RESTRICTIVE', 'roles': ['authenticated'], 'cmd': 'SELECT', 'qual': '(NOT privado.copilot_retorno_e_chat(id, id_consulta))', 'with_check': None}, {'schemaname': 'public', 'tablename': 'mensagens_copiloto', 'policyname': 'copilot_raw_chat_select', 'permissive': 'RESTRICTIVE', 'roles': ['authenticated'], 'cmd': 'SELECT', 'qual': 'false', 'with_check': None}, {'schemaname': 'public', 'tablename': 'fontes_resposta_copiloto', 'policyname': 'copilot_raw_chat_select', 'permissive': 'RESTRICTIVE', 'roles': ['authenticated'], 'cmd': 'SELECT', 'qual': 'false', 'with_check': None}]

def reconcile_copilot_raw_catalog(expected, actual, native):
 if native != [COPILOT_RAW_APPROVED]:
  raise SystemExit('COPILOT_RAW_NATIVE_CATALOG_FAIL: exact helper signature/body/owner/ACL required')
 result={**expected,'functions':list(expected['functions']),'policies':list(expected['policies'])}
 record={k:COPILOT_RAW_APPROVED[k] for k in ('schema','name','args','definer','config','auth_exec','anon_exec')}
 if actual['functions'].count(record)!=1 or record in result['functions']:
  raise SystemExit('COPILOT_RAW_CATALOG_FAIL: exact unique helper required')
 result['functions'].append(record)
 for policy in COPILOT_RAW_POLICIES:
  if actual['policies'].count(policy)!=1 or policy in result['policies']:
   raise SystemExit('COPILOT_RAW_CATALOG_FAIL: exact unique restrictive policy required')
  result['policies'].append(policy)
 return result


I05_MIGRATION_SHA256 = '28fd2190e3f61555d461597658b0d7b72c858848766fede460d4ecfb10571733'
I05_COLUMNS = json.loads(r'''[
  {
    "default": null,
    "name": "extracao_apontamentos_concluida_em",
    "notnull": false,
    "schema": "public",
    "table": "pareceres_contratante",
    "type": "timestamp with time zone"
  },
  {
    "default": null,
    "name": "extracao_apontamentos_sha256",
    "notnull": false,
    "schema": "public",
    "table": "pareceres_contratante",
    "type": "text"
  },
  {
    "default": null,
    "name": "id_arquivo_origem",
    "notnull": false,
    "schema": "public",
    "table": "apontamentos_contratante",
    "type": "uuid"
  },
  {
    "default": null,
    "name": "id_parecer_origem",
    "notnull": false,
    "schema": "public",
    "table": "apontamentos_contratante",
    "type": "uuid"
  },
  {
    "default": null,
    "name": "sha256_arquivo_origem",
    "notnull": false,
    "schema": "public",
    "table": "apontamentos_contratante",
    "type": "text"
  }
]''')
I05_NATIVE = json.loads(r'''[
  {
    "acl": [
      {
        "grantee": "postgres",
        "grantable": false,
        "privilege": "EXECUTE"
      }
    ],
    "args": "",
    "name": "preservar_origem_apontamento",
    "owner": "postgres",
    "config": [
      "search_path=\"\""
    ],
    "schema": "privado",
    "definer": false,
    "returns": "trigger",
    "body_md5": "ce442fceb5474a4cfda3c6e9edea844c",
    "language": "plpgsql",
    "anon_exec": false,
    "auth_exec": false,
    "public_exec": false,
    "service_exec": false
  },
  {
    "acl": [
      {
        "grantee": "authenticated",
        "grantable": false,
        "privilege": "EXECUTE"
      },
      {
        "grantee": "postgres",
        "grantable": false,
        "privilege": "EXECUTE"
      }
    ],
    "args": "p_id_ciclo uuid, p_id_apontamento uuid",
    "name": "obter_fonte_apontamento_contratante",
    "owner": "postgres",
    "config": [
      "search_path=\"\""
    ],
    "schema": "public",
    "definer": false,
    "returns": "jsonb",
    "body_md5": "23e478cb79707d48d04a300e52387d43",
    "language": "sql",
    "anon_exec": false,
    "auth_exec": true,
    "public_exec": false,
    "service_exec": false
  },
  {
    "acl": [
      {
        "grantee": "postgres",
        "grantable": false,
        "privilege": "EXECUTE"
      },
      {
        "grantee": "service_role",
        "grantable": false,
        "privilege": "EXECUTE"
      }
    ],
    "args": "p_id_parecer uuid, p_id_arquivo uuid, p_sha256 text, p_apontamentos jsonb",
    "name": "registrar_extracao_apontamentos",
    "owner": "postgres",
    "config": [
      "search_path=\"\""
    ],
    "schema": "public",
    "definer": true,
    "returns": "jsonb",
    "body_md5": "8d148fe549006a213fd79b254ba63069",
    "language": "plpgsql",
    "anon_exec": false,
    "auth_exec": false,
    "public_exec": false,
    "service_exec": true
  }
]''')

def reconcile_v2_i05_catalog(expected, actual, native, migration_sha):
 if migration_sha != I05_MIGRATION_SHA256:
  raise SystemExit('V2_I05_CATALOG_FAIL: migration SHA-256 mismatch')
 identity=lambda r: (r['schema'],r['name'],r['args'])
 if sorted(native,key=identity)!=sorted(I05_NATIVE,key=identity):
  raise SystemExit('V2_I05_CATALOG_FAIL: exact function signatures, bodies, owners and ACLs required')
 keys=('schema','name','args','definer','config','auth_exec','anon_exec')
 functions=[{key:record[key] for key in keys} for record in I05_NATIVE]
 result={**expected}
 for section, additions in (('columns',I05_COLUMNS),('functions',functions)):
  result[section]=list(expected[section])
  for entry in additions:
   if actual[section].count(entry)!=1 or entry in result[section]:
    raise SystemExit('V2_I05_CATALOG_FAIL: exact unique additive record required '+json.dumps(entry,sort_keys=True))
   result[section].append(entry)
 return result

root=pathlib.Path(__file__).parent
db=os.environ['DB_URL']
assert '@127.0.0.1:' in db or '@localhost:' in db,'Isolated restore required'
expected=json.loads((root/'history-catalog-before.json').read_text())
query=(root/'history-catalog-query.sql').read_text()
actual=json.loads(subprocess.check_output(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',query],text=True))
# GATE191: original chat policies remain present exactly once, even before additive hardening.
# Do not let the set comparison below hide duplicate catalog records.
for table in ('retornos_modelo','mensagens_copiloto','fontes_resposta_copiloto'):
 originals=[r for r in expected['policies'] if r['schemaname']=='public' and r['tablename']==table and r['policyname']==table+'_select']
 if len(originals)!=1 or actual['policies'].count(originals[0])!=1:
  raise SystemExit('CHAT_ORIGINAL_POLICY_FAIL: exact unique original policy required '+table)
copilot_query="set search_path='';select coalesce(jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,'args',pg_get_function_identity_arguments(p.oid),'owner',pg_get_userbyid(p.proowner),'definer',p.prosecdef,'config',p.proconfig,'language',l.lanname,'returns',pg_get_function_result(p.oid),'auth_exec',has_function_privilege('authenticated',p.oid,'EXECUTE'),'anon_exec',has_function_privilege('anon',p.oid,'EXECUTE'),'service_exec',has_function_privilege('service_role',p.oid,'EXECUTE'),'public_exec',exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE'),'body_md5',md5(p.prosrc),'acl',(select jsonb_agg(jsonb_build_object('grantee',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,'privilege',a.privilege_type,'grantable',a.is_grantable) order by a.grantee::regrole::text,a.privilege_type,a.is_grantable) from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a)) order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)),'[]'::jsonb) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname,p.proname) in (('privado','copilot_versao_elegivel'),('privado','copilot_precedente_elegivel'),('public','worker_buscar_fragmentos_copiloto'),('public','worker_buscar_precedentes_copiloto'),('privado','copilot_ator_permite'),('public','worker_reservar_consulta_copiloto'),('public','worker_falhar_consulta_copiloto'),('public','worker_validar_lease_copiloto'),('public','worker_concluir_consulta_copiloto'));"
copilot_native=json.loads(subprocess.check_output(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',copilot_query],text=True))
expected=reconcile_copilot_catalog(expected,actual,copilot_native)
raw_query=copilot_query[:copilot_query.rindex('where (n.nspname,p.proname) in (')]+"where n.nspname='privado' and p.proname='copilot_retorno_e_chat';"
raw_native=json.loads(subprocess.check_output(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',raw_query],text=True))
expected=reconcile_copilot_raw_catalog(expected,actual,raw_native)
i05_migration=root.parent/'migrations'/'20261126221545_v2_i05_proveniencia_apontamentos.sql'
if i05_migration.is_file():
 i05_query=copilot_query[:copilot_query.rindex('where (n.nspname,p.proname) in (')]+(
  "where (n.nspname,p.proname) in (('privado','preservar_origem_apontamento'),"
  "('public','obter_fonte_apontamento_contratante'),('public','registrar_extracao_apontamentos'));"
 )
 i05_native=json.loads(subprocess.check_output(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',i05_query],text=True))
 expected=reconcile_v2_i05_catalog(expected,actual,i05_native,hashlib.sha256(i05_migration.read_bytes()).hexdigest())
 print('V2_I05_CATALOG_PASS: exact five columns and three function signatures, bodies, owners and ACLs')

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
print('HISTORY_CATALOG_PASS: 120 tables,1520 columns,283 application function contracts/ACLs,186 original policies; exact additive Copilot and raw-chat privacy contracts/policies, explicit RBAC deltas and one hosted DDL-only helper compared')

