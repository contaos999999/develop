"""HML-only real Auth/JWT matrix checks. Credentials stay outside the checkout."""
import os,json,secrets,uuid,urllib.request,urllib.error,sys,hashlib
from datetime import datetime,timezone
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
URL='https://gklhhhyosgasnyoxlrui.supabase.co'
ROOT=Path(os.environ['CONTAOS_TEST_PRIVATE_DIR']).resolve()
ROOT.mkdir(parents=True,exist_ok=True);os.chmod(ROOT,0o700)
PROFILES=['administrador','auditor','contabilidade','direcao_aprovador','financeiro','gestor_contrato','juridico_conformidade','leitor','prestacao_contas','rh_dp']
def read(n):return json.loads((ROOT/n).read_text())
def write(n,d):
 p=ROOT/n;p.write_text(json.dumps(d,indent=2)+'\n');os.chmod(p,0o600)
def request(path,token=None,data=None,method=None,prefer=None):
 h={'apikey':read('public-key.json')['key'],'Content-Type':'application/json'}
 if token:h['Authorization']='Bearer '+token
 if prefer:h['Prefer']=prefer
 req=urllib.request.Request(URL+path,data=None if data is None else json.dumps(data).encode(),headers=h,method=method)
 try:
  with urllib.request.urlopen(req,timeout=30) as r:
   raw=r.read();return r.status,json.loads(raw) if raw else None
 except urllib.error.HTTPError as e:
  try:body=json.loads(e.read())
  except ValueError:body={}
  return e.code,body
 except Exception as e:return 0,{'code':type(e).__name__}
def rpc(name,data,token):return request('/rest/v1/rpc/'+name,token,data)
def check(name,ok,status=None,data=None):
 report=read('report.json') if (ROOT/'report.json').exists() else {'mode':'REAL_AUTH_RBAC_V1','assertions':[]}
 item={'name':name,'pass':bool(ok),'http':status}
 if not ok and isinstance(data,dict):item['pgcode']=data.get('code')
 report['assertions'].append(item);write('report.json',report)
def prepare():
 import crypt  # Fixture preparation uses Python 3.12 + system bcrypt support.
 if (ROOT/'fixture.json').exists():raise SystemExit('Refuse fixture reuse')
 uid=lambda:str(uuid.uuid4());q=lambda s:"'"+str(s).replace("'","''")+"'"
 f={'scope':'P0-RBAC-BUILD','org_a':uid(),'org_b':uid(),'users':[{'profile':p,'id':uid(),'email':'p0rbacbuild-'+uid()+'@example.invalid','password':secrets.token_urlsafe(40)+'Aa1!'} for p in ['master',*PROFILES,'sem_vinculo','restrito','usuario_b']],'cases':{},'extra_orgs':[],'extra_contracts':[]}
 for label in ['A1','A2','B1']:f['cases'][label]={'org':f['org_b'] if label=='B1' else f['org_a'],'contract':uid(),'contratante':uid()}
 write('fixture.json',f);sql=['begin;']
 for u in f['users']:
  meta=json.dumps({'synthetic':True,'scope':f['scope'],'master':True})
  encrypted=crypt.crypt(u['password'],crypt.mksalt(crypt.METHOD_BLOWFISH))
  if not encrypted or not encrypted.startswith('$2'):raise SystemExit('System bcrypt unavailable')
  sql.append("insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change) values('00000000-0000-0000-0000-000000000000',%s,'authenticated','authenticated',%s,%s,now(),'{\"provider\":\"email\",\"providers\":[\"email\"]}',%s::jsonb,now(),now(),'','','','');"%(q(u['id']),q(u['email']),q(encrypted),q(meta)))
  sql.append("insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at) values(%s,%s,%s::jsonb,'email',now(),now());"%(q(u['id']),q(u['id']),q(json.dumps({'sub':u['id'],'email':u['email'],'email_verified':True}))))
 for key in ['org_a','org_b']:sql.append("insert into public.organizacoes(id,razao_social) values(%s,%s);"%(q(f[key]),q('p0rbacbuild-'+key+'-'+f[key])))
 for u in f['users']:
  if u['profile']=='master':sql.append("insert into privado.administradores_master(id_usuario,motivo) values(%s,'P0-RBAC-BUILD synthetic JWT fixture');"%q(u['id']))
  elif u['profile']!='sem_vinculo':
   sql.append("insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values(%s,%s,%s,%s);"%(q(f['org_b'] if u['profile']=='usuario_b' else f['org_a']),q(u['id']),q('gestor_contrato' if u['profile']=='restrito' else 'leitor' if u['profile']=='usuario_b' else u['profile']),str(u['profile']!='restrito').lower()))
 for label,c in f['cases'].items():
  sql.append("insert into public.contratantes(id,id_organizacao,razao_social) values(%s,%s,'p0rbacbuild-contractor');"%(q(c['contratante']),q(c['org'])))
  sql.append("insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values(%s,%s,%s,%s,'Synthetic RBAC JWT','2026-11-01');"%(q(c['contract']),q(c['org']),q(c['contratante']),q('p0rbacbuild-'+label)))
 restricted=next(u for u in f['users'] if u['profile']=='restrito')
 sql.append("insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo) select id_organizacao,id,%s,true from public.vinculos_usuarios where id_usuario=%s and id_organizacao=%s;"%(q(f['cases']['A1']['contract']),q(restricted['id']),q(f['org_a'])))
 sql.append('commit;');p=ROOT/'seed.sql';p.write_text('\n'.join(sql));os.chmod(p,0o600)
 print(json.dumps({'prepared':True,'users':len(f['users']),'orgs':2,'contracts':3,'secrets_logged':False}))
def baseline():
 f=read('fixture.json');sessions={}
 for u in f['users']:
  p=u['profile'];status,data=request('/auth/v1/token?grant_type=password',data={'email':u['email'],'password':u['password']})
  token=data.get('access_token') if isinstance(data,dict) else None
  check(p+': real Auth login',status==200 and bool(token),status,data)
  if not token:continue
  sessions[p]=token;write('sessions.json',sessions)
  status,data=request('/auth/v1/user',token);check(p+': Auth identity',status==200 and data.get('id')==u['id'],status)
 master=sessions['master'];status,matrix=rpc('obter_matriz_rbac_master',{},master)
 check('MASTER: global matrix read',status==200 and len(matrix.get('permissoes',[]))==480,status,matrix)
 if status!=200:return
 write('matrix-before.json',matrix)
 for u in f['users']:
  p=u['profile'];token=sessions.get(p)
  if not token:continue
  status,data=rpc('obter_matriz_rbac_master',{},token)
  check(p+': matrix MASTER-only',status==200 if p=='master' else status==403 and data.get('code')=='42501',status,data)
  if p!='master':
   status,data=rpc('atualizar_matriz_rbac_master',{'p_versao_esperada':matrix['versao'],'p_request_id':str(uuid.uuid4()),'p_alteracoes':[{'perfil':'leitor','recurso':'contratos','acao':'consultar','permitido':False}]},token)
   check(p+': matrix mutation denied',status==403 and data.get('code')=='42501',status,data)
  for label,c in f['cases'].items():
   scoped=p=='master' or (label=='B1' if p=='usuario_b' else p!='sem_vinculo' and label!='B1' and not(p=='restrito' and label=='A2'))
   status,data=rpc('consultar_permissoes_efetivas',{'p_id_organizacao':c['org'],'p_id_contrato':c['contract']},token)
   if scoped:
    profile='gestor_contrato' if p=='restrito' else 'leitor' if p=='usuario_b' else p
    expected={(x['recurso'],x['acao']) for x in matrix['permissoes'] if p=='master' or (x['perfil']==profile and x['permitido'])}
    actual={(x['recurso'],x['acao']) for x in data.get('permissoes',[])} if isinstance(data,dict) else set()
    check(p+': contextual matrix '+label,status==200 and expected==actual,status,data)
   else:check(p+': context denied '+label,status==403 and data.get('code')=='42501',status,data)
  ids=[c['contract'] for c in f['cases'].values()]
  status,data=request('/rest/v1/contratos?select=id&id=in.('+','.join(ids)+')',token)
  expected=set(ids) if p=='master' else ({f['cases']['B1']['contract']} if p=='usuario_b' else set() if p=='sem_vinculo' else {f['cases']['A1']['contract']} if p=='restrito' else {f['cases']['A1']['contract'],f['cases']['A2']['contract']})
  check(p+': contract RLS',status==200 and {x['id'] for x in data}==expected,status)
 for token,label in [(None,'anon'),('invalid.token.signature','invalid JWT')]:
  for name,payload in [('obter_matriz_rbac_master',{}),('consultar_permissoes_efetivas',{'p_id_organizacao':f['org_a'],'p_id_contrato':None}),('atualizar_matriz_rbac_master',{'p_versao_esperada':1,'p_request_id':str(uuid.uuid4()),'p_alteracoes':[]})]:
   status,data=rpc(name,payload,token);check(label+': '+name,status in [401,403],status,data)
 for org,contract,label in [(f['org_a'],f['cases']['B1']['contract'],'mismatched tenant/contract'),(str(uuid.uuid4()),None,'unknown organization')]:
  status,data=rpc('consultar_permissoes_efetivas',{'p_id_organizacao':org,'p_id_contrato':contract},master);check('MASTER: '+label+' denied',status==403 and data.get('code')=='42501',status,data)
def _change_matrix():
 f=read('fixture.json');s=read('sessions.json');before=read('matrix-before.json');v=before['versao']
 change=[{'perfil':'leitor','recurso':'contratos','acao':'consultar','permitido':False}]
 requests=[{'p_versao_esperada':v,'p_request_id':str(uuid.uuid4()),'p_alteracoes':change} for _ in range(2)]
 state=read('matrix-restore-state.json');state['requests']=requests;write('matrix-restore-state.json',state)
 with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda p:rpc('atualizar_matriz_rbac_master',p,s['master']),requests))
 check('HTTP concurrency: exactly one writer',sorted(x[0] for x in results)==[200,409])
 winner=next((i for i,x in enumerate(results) if x[0]==200),None)
 if winner is None:return
 original=results[winner][1];write('matrix-change.json',{'request':requests[winner],'response':original})
 status,data=rpc('atualizar_matriz_rbac_master',requests[winner],s['master']);check('same request exact replay',status==200 and data==original,status,data)
 altered={**requests[winner],'p_alteracoes':[dict(change[0],permitido=True)]}
 status,data=rpc('atualizar_matriz_rbac_master',altered,s['master']);check('request payload conflict',status==409 and data.get('code')=='PT409',status,data)
 status,data=request('/rest/v1/contratos?select=id&id=eq.'+f['cases']['A1']['contract'],s['leitor']);check('live matrix revoke blocks direct RLS SELECT',status==200 and data==[],status)
 status,data=rpc('consultar_permissoes_efetivas',{'p_id_organizacao':f['org_a'],'p_id_contrato':f['cases']['A1']['contract']},s['leitor']);check('same JWT receives revoked permission immediately',status==200 and not any(x['recurso']=='contratos' and x['acao']=='consultar' for x in data.get('permissoes',[])),status)
def change_matrix(action=None):
 f=read('fixture.json');preflight=read('matrix-preflight.json')
 identity_hash=hashlib.sha256('\n'.join(sorted(u['id'] for u in f['users'])).encode()).hexdigest()
 age=(datetime.now(timezone.utc)-datetime.fromisoformat(preflight['captured_at'])).total_seconds()
 if preflight.get('scope')!=f['scope'] or preflight.get('fixture_user_ids_sha256')!=identity_hash or preflight.get('external_active_leitor')!=0 or not 0<=age<=120:
  raise SystemExit('Global matrix preflight missing, stale or not bound to these fixtures')
 if any(not r['pass'] for r in read('report.json')['assertions']):raise SystemExit('Baseline must pass before global mutation')
 if (ROOT/'matrix-restore-state.json').exists() and read('matrix-restore-state.json').get('dirty'):raise SystemExit('Restore previous operation first')
 before=read('matrix-before.json')
 original=next(x for x in before['permissoes'] if x['perfil']=='leitor' and x['recurso']=='contratos' and x['acao']=='consultar')
 write('matrix-restore-state.json',{'dirty':True,'original':original,'requests':[],'scope':f['scope'],'fixture_user_ids_sha256':identity_hash})
 try:(action or _change_matrix)()
 finally:restore_matrix()
def interruption():
 class FixtureInterrupted(Exception):pass
 def fail_after_commit():
  s=read('sessions.json');status,current=rpc('obter_matriz_rbac_master',{},s['master'])
  if status!=200:raise RuntimeError('Cannot prepare interruption fixture')
  payload={'p_versao_esperada':current['versao'],'p_request_id':str(uuid.uuid4()),'p_alteracoes':[{'perfil':'leitor','recurso':'contratos','acao':'consultar','permitido':False}]}
  state=read('matrix-restore-state.json');state['requests']=[payload];write('matrix-restore-state.json',state)
  status,response=rpc('atualizar_matriz_rbac_master',payload,s['master'])
  if status!=200:raise RuntimeError('Interruption fixture mutation failed')
  raise FixtureInterrupted('Intentional failure after committed fixture mutation')
 try:change_matrix(fail_after_commit)
 except FixtureInterrupted:check('finally restored matrix after committed-request interruption',read('matrix-restore-state.json')['dirty'] is False)
def edge():
 f=read('fixture.json');s=read('sessions.json')
 for p in ['master','administrador','leitor','sem_vinculo']:
  status,data=request('/functions/v1/storage-sign-upload',s[p],{'id_organizacao':f['org_a'],'id_contrato':f['cases']['A1']['contract'],'nome_arquivo':'rbac-test.pdf','mime':'application/pdf','tamanho':0})
  allowed=p in ['master','administrador']
  check(p+': live Edge upload signer',status==200 and data.get('ok') is True if allowed else status in [401,403] and not data.get('signed_url') and not data.get('token'),status)
def restore_matrix():
 if not (ROOT/'matrix-restore-state.json').exists():return True
 state=read('matrix-restore-state.json')
 if not state.get('dirty'):return True
 s=read('sessions.json')
 status,current=rpc('obter_matriz_rbac_master',{},s['master'])
 if status!=200:raise RuntimeError('Pending matrix restore: MASTER read failed; logout/cleanup blocked')
 original=state['original']
 now=next(x for x in current['permissoes'] if x['perfil']=='leitor' and x['recurso']=='contratos' and x['acao']=='consultar')
 if now['permitido']!=original['permitido']:
  owned=False
  for payload in state['requests']:
   replay,response=rpc('atualizar_matriz_rbac_master',payload,s['master'])
   if replay==200:owned=True;break
  if not owned:raise RuntimeError('Cannot attribute matrix change to this fixture; restore and logout blocked')
  status,current=rpc('obter_matriz_rbac_master',{},s['master'])
  if status!=200:raise RuntimeError('Cannot read current matrix version for safe restore')
  status,data=rpc('atualizar_matriz_rbac_master',{'p_versao_esperada':current['versao'],'p_request_id':str(uuid.uuid4()),'p_alteracoes':[original]},s['master'])
  if status!=200:raise RuntimeError('Pending matrix restore: write failed; logout/cleanup blocked')
 status,verified=rpc('obter_matriz_rbac_master',{},s['master'])
 if status!=200 or next(x for x in verified['permissoes'] if x['perfil']=='leitor' and x['recurso']=='contratos' and x['acao']=='consultar')['permitido']!=original['permitido']:
  raise RuntimeError('Matrix restore readback failed; logout/cleanup blocked')
 state['dirty']=False;state['restored_version']=verified['versao'];state['verified_at']=datetime.now(timezone.utc).isoformat();write('matrix-restore-state.json',state)
 check('original permission restored and read back',True)
 return True
def revoked_membership():
 f=read('fixture.json');s=read('sessions.json')
 status,data=rpc('consultar_permissoes_efetivas',{'p_id_organizacao':f['org_a'],'p_id_contrato':None},s['contabilidade']);check('membership revoked with same JWT',status==403 and data.get('code')=='42501',status,data)
def logout():
 restore_matrix()
 if (ROOT/'matrix-restore-state.json').exists() and read('matrix-restore-state.json').get('dirty'):raise RuntimeError('Restore pending: logout blocked')
 s=read('sessions.json')
 for p,t in s.items():
  status,data=request('/auth/v1/logout?scope=global',t,{},'POST');check(p+': logout',status in [204,401,403],status)
 status,data=rpc('obter_matriz_rbac_master',{},s['master']);check('revoked MASTER JWT rejected',status==403 and data.get('code')=='42501',status,data)
if __name__=='__main__':
 mode=sys.argv[1]
 {'prepare':prepare,'baseline':baseline,'matrix':change_matrix,'interruption':interruption,'restore':restore_matrix,'edge':edge,'membership_revoked':revoked_membership,'logout':logout}[mode]()
 if (ROOT/'report.json').exists():
  rows=read('report.json')['assertions'];failed=[r for r in rows if not r['pass']]
  print(json.dumps({'phase':mode,'assertions':len(rows),'passed':len(rows)-len(failed),'failed':len(failed),'failures':failed}))
  sys.exit(bool(failed))
