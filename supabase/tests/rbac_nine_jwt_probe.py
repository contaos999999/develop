import json, os, sys, urllib.request, urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from threading import Lock

ROOT=Path(os.environ['CONTAOS_TEST_PRIVATE_DIR']).resolve()
os.umask(0o077)
URL='https://gklhhhyosgasnyoxlrui.supabase.co'
NAMES=['obter_visao_geral_competencia','obter_documentos_competencia_v115','obter_analise_competencia_v116','obter_detalhe_requisito_v117','criar_documento_competencia_v115','adicionar_versao_documento_competencia_v115','registrar_relatorio_historico_hml','enfileirar_ingestao_historica_hml','vincular_tratamento_historico_hml']
ANALYST={'master','administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor'}
WRITER=ANALYST-{'auditor'}
MANAGER={'master','administrador','gestor_contrato'}

def request(path,token=None,payload=None,method=None):
    key=json.loads((ROOT/'public-key.json').read_text())['key']
    headers={'apikey':key,'Content-Type':'application/json'}
    if token: headers['Authorization']='Bearer '+token
    req=urllib.request.Request(URL+path,data=None if payload is None else json.dumps(payload).encode(),headers=headers,method=method)
    try:
        with urllib.request.urlopen(req,timeout=25) as res:
            raw=res.read();return res.status,json.loads(raw) if raw else None
    except urllib.error.HTTPError as err:
        try:data=json.loads(err.read())
        except ValueError:data={}
        return err.code,data
    except Exception as err:
        return 0,{'code':type(err).__name__}

def payloads(c,label,profile):
    return [
      {'p_id_competencia':c['comp']},
      {'p_id_competencia':c['comp']},
      {'p_id_competencia':c['comp']},
      {'p_id_competencia':c['comp'],'p_id_requisito':c['req']},
      {'p_id_competencia':c['comp'],'p_tipo':'outro','p_titulo':'p0rbacnine','p_categoria':None,'p_id_requisito':None,'p_id_arquivo':c['file'],'p_chave_idempotencia':'p0rbacnine-criar-'+label},
      {'p_id_documento':c['doc'],'p_id_arquivo':c['file'],'p_motivo':'p0rbacnine','p_chave_idempotencia':'p0rbacnine-adicionar-'+label},
      {'p_id_arquivo':c['file'],'p_competencia':'2026-11-01','p_tipo':'relatorio_contratante'},
      {'p_id_relatorio':c['report'],'p_id_versao_documento':c['version']},
      {'p_id_apontamento':c['point'],'p_resposta':'p0rbacnine:'+profile+':'+label,'p_desfecho':'prova_sintetica','p_fundamento':'Teste autorizado HML'}]

def permitted(profile,label,index):
    scoped=profile=='master' or (label=='B1' if profile=='usuario_b' else label!='B1' and profile!='sem_vinculo' and not(profile=='restrito' and label=='A2'))
    profile='gestor_contrato' if profile=='restrito' else 'leitor' if profile=='usuario_b' else profile
    if not scoped:return False
    if index<2:return True
    if index<4:return profile in ANALYST
    if index<6:return profile in WRITER
    return profile in MANAGER

def denied(status,data):
    if status==403 and isinstance(data,dict) and data.get('code')=='42501':return True
    return status==400 and isinstance(data,dict) and data.get('code')=='P0001' and data.get('message') in ['Perfil de gestão sem permissão.','Perfil de gestão sem permissão para importar histórico.']

def run():
    f=json.loads((ROOT/'fixture.json').read_text())
    report=json.loads((ROOT/'report.json').read_text()) if (ROOT/'report.json').exists() else {'mode':'REAL_AUTH_POST_RLS','assertions':[],'limitations':['Document write positives use seeded idempotent replay; no upload or worker certification.']}
    sessions=json.loads((ROOT/'sessions.json').read_text()) if (ROOT/'sessions.json').exists() else {}
    lock=Lock()
    def check(name,ok,status=None,data=None,expected=None):
        item={'name':name,'pass':bool(ok),'http':status}
        if expected is not None:item['expected']=expected
        if isinstance(data,dict) and not ok:item['pgcode']=data.get('code');item['message']=str(data.get('message',''))[:180]
        with lock:
            report['assertions'].append(item);(ROOT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    def rpc(name,payload,token):return request('/rest/v1/rpc/'+name,token,payload)
    def test_nine(profile,token,label,force_denied=False):
        c=f['cases'][label]
        for i,(name,payload) in enumerate(zip(NAMES,payloads(c,label,profile))):
            status,data=rpc(name,payload,token)
            allow=not force_denied and permitted(profile,label,i)
            if allow:
                ok=status==200
                if i<3:ok=ok and isinstance(data,dict) and data.get('competencia',{}).get('id')==c['comp']
                if i==3:ok=ok and isinstance(data,dict) and data.get('requisito',{}).get('id')==c['req']
                if i in [4,5]:ok=ok and isinstance(data,dict) and data.get('fixture_replay') is True and data.get('id_documento')==c['doc']
                if i==6:ok=ok and data==c['report']
                if i==8:ok=ok and isinstance(data,dict) and bool(data.get('id_resposta')) and bool(data.get('id_desfecho'))
            else:ok=denied(status,data)
            check(profile+':'+label+':'+name+(':revoked' if force_denied else ''),ok,status,data,'ALLOW' if allow else 'DENY')
    mode=sys.argv[1]
    if mode=='baseline':
        def user_task(user):
            profile=user['profile'];status,data=request('/auth/v1/token?grant_type=password',payload={'email':user['email'],'password':user['password']})
            token=data.get('access_token') if isinstance(data,dict) else None
            check(profile+':Auth login',status==200 and isinstance(token,str),status)
            if not token:return
            with lock:
                sessions[profile]=token;(ROOT/'sessions.json').write_text(json.dumps(sessions));os.chmod(ROOT/'sessions.json',0o600)
            status,data=request('/auth/v1/user',token)
            check(profile+':Auth identity',status==200 and data.get('id')==user['id'],status)
            orgs={f['org_a'],f['org_b']} if profile=='master' else (set() if profile=='sem_vinculo' else {f['org_b']} if profile=='usuario_b' else {f['org_a']})
            status,data=rpc('listar_organizacoes_disponiveis',{},token)
            found={x['id'] for x in data} if status==200 and isinstance(data,list) else set()
            check(profile+':organizations',status==200 and found.intersection({f['org_a'],f['org_b']})==orgs,status)
            all_ids={c['contract'] for c in f['cases'].values()}
            expected=all_ids if profile=='master' else ({f['cases']['B1']['contract']} if profile=='usuario_b' else {f['cases']['A1']['contract']} if profile=='restrito' else (set() if profile=='sem_vinculo' else {f['cases']['A1']['contract'],f['cases']['A2']['contract']}))
            status,data=request('/rest/v1/contratos?select=id&id=in.('+','.join(sorted(all_ids))+')',token)
            found={x['id'] for x in data} if status==200 and isinstance(data,list) else set()
            check(profile+':contracts RLS',status==200 and found==expected,status)
            for label in (['A1','A2','B1'] if profile in ['master','restrito'] else ['A1','B1']):test_nine(profile,token,label)
        with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(user_task,f['users']))
        for label,token in [('anon',None),('invalid_jwt','invalid.token.signature')]:
            for name,payload in zip(NAMES,payloads(f['cases']['A1'],'A1',label)):
                status,data=rpc(name,payload,token)
                check(label+':'+name,status in [401,403],status,data,'DENY')
    elif mode=='membership_revoked':test_nine('contabilidade',sessions['contabilidade'],'A1',True)
    elif mode=='revoked_both':
        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda profile:test_nine(profile,sessions[profile],'A1',True),['contabilidade','master']))
    elif mode=='revoke':
        status,data=request('/auth/v1/logout?scope=global',sessions['master'],{},method='POST')
        check('master:logout revocation',status==204,status)
    elif mode=='revoked':test_nine('master',sessions['master'],'A1',True)
    elif mode=='logout':
        def logout(item):
            profile,token=item;status,data=request('/auth/v1/logout?scope=global',token,{},method='POST')
            check(profile+':cleanup logout',status in [204,401,403],status)
        with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(logout,sessions.items()))
    failed=[x for x in report['assertions'] if not x['pass']]
    print(json.dumps({'phase':mode,'total':len(report['assertions']),'passed':len(report['assertions'])-len(failed),'failed':len(failed),'failures':failed}))
    return 1 if failed else 0

import secrets,uuid
PROFILES=['administrador','auditor','contabilidade','direcao_aprovador','financeiro','gestor_contrato','juridico_conformidade','leitor','prestacao_contas','rh_dp']
def read(n):return json.loads((ROOT/n).read_text())
def write(n,d):
 ROOT.mkdir(parents=True,exist_ok=True);os.chmod(ROOT,0o700)
 p=ROOT/n;p.write_text(json.dumps(d,indent=2)+'\n');os.chmod(p,0o600)

def prepare_auth():
 import crypt  # Fixture preparation uses Python 3.12 + system bcrypt support.
 if (ROOT/'fixture.json').exists():raise SystemExit('Refuse fixture reuse')
 uid=lambda:str(uuid.uuid4());q=lambda s:"'"+str(s).replace("'","''")+"'"
 f={'scope':'P0-RBAC-NINE','org_a':uid(),'org_b':uid(),'users':[{'profile':p,'id':uid(),'email':'p0rbacnine-'+uid()+'@example.invalid','password':secrets.token_urlsafe(40)+'Aa1!'} for p in ['master',*PROFILES,'sem_vinculo','restrito','usuario_b']],'cases':{},'extra_orgs':[],'extra_contracts':[]}
 for label in ['A1','A2','B1']:f['cases'][label]={'org':f['org_b'] if label=='B1' else f['org_a'],'contract':uid(),'contratante':uid()}
 write('fixture.json',f);sql=['begin;']
 for u in f['users']:
  meta=json.dumps({'synthetic':True,'scope':f['scope'],'master':True})
  encrypted=crypt.crypt(u['password'],crypt.mksalt(crypt.METHOD_BLOWFISH))
  if not encrypted or not encrypted.startswith('$2'):raise SystemExit('System bcrypt unavailable')
  sql.append("insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change) values('00000000-0000-0000-0000-000000000000',%s,'authenticated','authenticated',%s,%s,now(),'{\"provider\":\"email\",\"providers\":[\"email\"]}',%s::jsonb,now(),now(),'','','','');"%(q(u['id']),q(u['email']),q(encrypted),q(meta)))
  sql.append("insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at) values(%s,%s,%s::jsonb,'email',now(),now());"%(q(u['id']),q(u['id']),q(json.dumps({'sub':u['id'],'email':u['email'],'email_verified':True}))))
 for key in ['org_a','org_b']:sql.append("insert into public.organizacoes(id,razao_social) values(%s,%s);"%(q(f[key]),q('p0rbacnine-'+key+'-'+f[key])))
 for u in f['users']:
  if u['profile']=='master':sql.append("insert into privado.administradores_master(id_usuario,motivo) values(%s,'P0-RBAC-NINE synthetic JWT fixture');"%q(u['id']))
  elif u['profile']!='sem_vinculo':
   sql.append("insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values(%s,%s,%s,%s);"%(q(f['org_b'] if u['profile']=='usuario_b' else f['org_a']),q(u['id']),q('gestor_contrato' if u['profile']=='restrito' else 'leitor' if u['profile']=='usuario_b' else u['profile']),str(u['profile']!='restrito').lower()))
 for label,c in f['cases'].items():
  sql.append("insert into public.contratantes(id,id_organizacao,razao_social) values(%s,%s,'p0rbacnine-contractor');"%(q(c['contratante']),q(c['org'])))
  sql.append("insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values(%s,%s,%s,%s,'Synthetic RBAC JWT','2026-11-01');"%(q(c['contract']),q(c['org']),q(c['contratante']),q('p0rbacnine-'+label)))
 restricted=next(u for u in f['users'] if u['profile']=='restrito')
 sql.append("insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo) select id_organizacao,id,%s,true from public.vinculos_usuarios where id_usuario=%s and id_organizacao=%s;"%(q(f['cases']['A1']['contract']),q(restricted['id']),q(f['org_a'])))
 sql.append('commit;');p=ROOT/'seed.sql';p.write_text('\n'.join(sql));os.chmod(p,0o600)
 print(json.dumps({'prepared':True,'users':len(f['users']),'orgs':2,'contracts':3,'secrets_logged':False}))


def prepare():
    prepare_auth();f=read('fixture.json');uid=lambda:str(uuid.uuid4());q=lambda x:"'"+str(x).replace("'","''")+"'"
    sql=(ROOT/'seed.sql').read_text().removesuffix('commit;')
    rows=[]
    for label,c in f['cases'].items():
        for key in ['comp','req','file','doc','version','report','point']:c[key]=uid()
        o=q(c['org']);ct=q(c['contract']);a=q(c['file']);comp=q(c['comp']);doc=q(c['doc']);v=q(c['version']);report=q(c['report']);sha='a'*64
        rows += [f"insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim) values({comp},{o},{ct},'2026-11-01','2026-11-01','2026-11-30');",
          f"insert into public.requisitos_competencia(id,id_organizacao,id_contrato,id_competencia,origem_tipo,descricao,hash_snapshot) values({q(c['req'])},{o},{ct},{comp},'manual','P0-RBAC-NINE synthetic requirement','{sha}');",
          f"insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,mime,sha256,status_seguranca,origem) values({a},{o},{ct},{q(c['org']+'/p0rbacnine/'+c['file']+'.pdf')},'p0rbacnine.pdf','application/pdf','{sha}','aprovado','upload');",
          f"insert into public.documentos_competencia(id,id_organizacao,id_contrato,id_competencia,tipo,titulo,versao_atual) values({doc},{o},{ct},{comp},'outro','p0rbacnine',1);",
          f"insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash) values({v},{o},{ct},{doc},1,{a},'{sha}');",
          f"insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values({o},{ct},{v},'documents','concluido');",
          f"insert into public.relatorios_historicos_contratante(id,id_organizacao,id_contrato,id_arquivo,competencia_referencia,tipo) values({report},{o},{ct},{a},'2026-11-01','relatorio_contratante');",
          f"insert into public.apontamentos_historicos(id,id_organizacao,id_contrato,id_relatorio,problema) values({q(c['point'])},{o},{ct},{report},'P0-RBAC-NINE synthetic point');"]
        for user in f['users']:
            payloads_pair=[('v115.criar_documento_competencia','p0rbacnine-criar-'+label,{'id_competencia':c['comp'],'tipo':'outro','titulo':'p0rbacnine','categoria':None,'id_requisito':None,'id_arquivo':c['file']}),('v115.adicionar_versao_documento_competencia','p0rbacnine-adicionar-'+label,{'id_documento':c['doc'],'id_arquivo':c['file'],'motivo':'p0rbacnine'})]
            for command,key,payload in payloads_pair:
                response={'fixture_replay':True,'id_documento':c['doc']}
                rows.append(f"insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,resposta,expira_em) values({o},{q(command+':'+user['id'])},{q(key)},encode(extensions.digest(({q(json.dumps(payload))}::jsonb)::text,'sha256'),'hex'),'concluido',{q(json.dumps(response))}::jsonb,now()+interval '24 hours');")
    write('fixture.json',f);p=ROOT/'seed.sql';p.write_text(sql+'\n'+'\n'.join(rows)+'\ncommit;');os.chmod(p,0o600)
    print(json.dumps({'prepared_nine':True,'cases':3,'accounts':len(f['users']),'secrets_logged':False,'seeded_replay_not_first_creation':True}))

if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    else:sys.exit(run())

