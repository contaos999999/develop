"""Real PostgreSQL two-session concurrency, isolated restore only, not JWT HTTP."""
import os,subprocess,json,concurrent.futures,uuid
db=os.environ['DB_URL']
assert '@127.0.0.1:' in db or '@localhost:' in db,'Isolated database required'
def sql(q,check=True):
 p=subprocess.run(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',q],capture_output=True,text=True)
 if check and p.returncode:raise AssertionError(p.stderr)
 return p
user=str(uuid.uuid4());session=str(uuid.uuid4())
sql(f"insert into auth.users(id,aud,role,email) values('{user}','authenticated','authenticated','rbac-concurrency-{user}@example.invalid'); insert into auth.sessions(id,user_id,aal,not_after) values('{session}','{user}','aal1',now()+interval '1 hour'); insert into privado.administradores_master(id_usuario,motivo) values('{user}','Isolated concurrency');")
claims=json.dumps({'sub':user,'session_id':session,'role':'authenticated'})
prefix=f"begin; set local role authenticated; select set_config('request.jwt.claim.sub','{user}',true); select set_config('request.jwt.claims','{claims}',true);"
version=int(sql('select versao from privado.rbac_versoes where id').stdout.strip())
payload=json.dumps([{'perfil':'leitor','recurso':'contratos','acao':'consultar','permitido':True}])
def call(key):
 return sql(prefix+f"select public.atualizar_matriz_rbac_master({version},'{key}','{payload}'::jsonb); commit;",False)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 results=list(pool.map(call,[str(uuid.uuid4()),str(uuid.uuid4())]))
assert sum(p.returncode==0 for p in results)==1,'Exactly one concurrent writer must succeed'
assert any('A matriz foi alterada' in p.stderr for p in results),'Stale writer must report conflict'
assert int(sql('select versao from privado.rbac_versoes where id').stdout.strip())==version+1
assert int(sql(f"select count(*) from public.eventos_auditoria where evento='MatrizRbacAtualizada' and id_usuario='{user}'").stdout.strip())==1
# Concurrent exact replay under a new expected version.
version+=1;key=str(uuid.uuid4())
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 results=list(pool.map(call,[key,key]))
assert all(p.returncode==0 for p in results),'Concurrent replay must succeed twice'
responses=[json.loads(p.stdout.strip().splitlines()[-1]) for p in results]
assert responses[0]==responses[1],'Concurrent replay must return identical response'
assert int(sql('select versao from privado.rbac_versoes where id').stdout.strip())==version+1
assert int(sql(f"select count(*) from public.eventos_auditoria where evento='MatrizRbacAtualizada' and id_usuario='{user}'").stdout.strip())==2
print('RBAC_CONCURRENCY_PASS: two sessions; one stale conflict; replay identical; two unique audit events')
