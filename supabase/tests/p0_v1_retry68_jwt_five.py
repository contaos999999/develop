import json,os,secrets,sys,uuid,urllib.request,urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

ROOT=Path(os.environ.get('CONTAOS_TEST_PRIVATE_DIR',str(Path(__file__).parent/'private')))
ROOT.mkdir(parents=True,exist_ok=True);os.chmod(ROOT,0o700)
URL='https://gklhhhyosgasnyoxlrui.supabase.co'
SCENARIOS=[('gestor_contrato','A1'),('administrador','A1'),('master','A1'),('master','A2'),('master','B1')]
def read(name):return json.loads((ROOT/name).read_text())
def write(name,data):
    p=ROOT/name;p.write_text(json.dumps(data,indent=2)+'\n');os.chmod(p,0o600)
def request(path,token=None,payload=None):
    headers={'apikey':read('public-key.json')['key'],'Content-Type':'application/json'}
    if token:headers['Authorization']='Bearer '+token
    req=urllib.request.Request(URL+path,data=None if payload is None else json.dumps(payload).encode(),headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=25) as res:
            raw=res.read();return res.status,json.loads(raw) if raw else None
    except urllib.error.HTTPError as err:
        try:data=json.loads(err.read())
        except ValueError:data={}
        return err.code,data
    except Exception as err:return 0,{'code':type(err).__name__}
def prepare():
    uid=lambda:str(uuid.uuid4());q=lambda x:"'"+x.replace("'","''")+"'"
    f={'org_a':uid(),'org_b':uid(),'users':[{'profile':p,'id':uid(),'email':'p0retry68-'+uid()+'@example.invalid','password':secrets.token_urlsafe(40)+'Aa1!'} for p in ['master','administrador','gestor_contrato']],'cases':{}}
    for label in ['A1','A2','B1']:f['cases'][label]={'org':f['org_b'] if label=='B1' else f['org_a'],**{k:uid() for k in ['contratante','contract','comp','file','doc','version','report']}}
    write('fixture.json',f);s=['begin;']
    for u in f['users']:
        meta=json.dumps({'synthetic':True,'scope':'P0-RETRY68'})
        s.append("insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change) values('00000000-0000-0000-0000-000000000000',%s,'authenticated','authenticated',%s,extensions.crypt(%s,extensions.gen_salt('bf')),now(),'{\"provider\":\"email\",\"providers\":[\"email\"]}',%s::jsonb,now(),now(),'','','','');"%(q(u['id']),q(u['email']),q(u['password']),q(meta)))
        s.append("insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at) values(%s,%s,%s::jsonb,'email',now(),now());"%(q(u['id']),q(u['id']),q(json.dumps({'sub':u['id'],'email':u['email'],'email_verified':True}))))
    for k in ['org_a','org_b']:s.append("insert into public.organizacoes(id,razao_social) values(%s,%s);"%(q(f[k]),q('p0retry68-'+k+'-'+f[k])))
    for u in f['users']:
        if u['profile']=='master':s.append("insert into privado.administradores_master(id_usuario,motivo) values(%s,'p0retry68: reteste sintético dos cinco casos');"%q(u['id']))
        else:s.append("insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values(%s,%s,%s,true);"%(q(f['org_a']),q(u['id']),q(u['profile'])))
    for label,c in f['cases'].items():
        v={k:q(x) for k,x in c.items()}
        s.append("insert into public.contratantes(id,id_organizacao,razao_social) values({contratante},{org},'p0retry68-contratante');".format(**v))
        s.append("insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values({contract},{org},{contratante},'p0retry68-{label}','Reteste sintético #68','2026-11-01');".format(label=label,**v))
        s.append("insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim) values({comp},{org},{contract},'2026-11-01','2026-11-01','2026-11-30');".format(**v))
        s.append("insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,mime,tamanho,sha256,status_seguranca) values({file},{org},{contract},'p0retry68/'||{file}::text||'.pdf','p0retry68.pdf','application/pdf',0,repeat('b',64),'aprovado');".format(**v))
        s.append("insert into public.documentos_competencia(id,id_organizacao,id_contrato,id_competencia,tipo,titulo,versao_atual) values({doc},{org},{contract},{comp},'outro','p0retry68-documento',1);".format(**v))
        s.append("insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash) values({version},{org},{contract},{doc},1,{file},repeat('b',64));".format(**v))
        s.append("insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values({org},{contract},{version},'documents','concluido');".format(**v))
        s.append("insert into public.relatorios_historicos_contratante(id,id_organizacao,id_contrato,id_arquivo,competencia_referencia,tipo,status_processamento) values({report},{org},{contract},{file},'2026-11-01','relatorio_contratante','concluido');".format(**v))
    s.append('commit;');(ROOT/'seed.sql').write_text('\n'.join(s));os.chmod(ROOT/'seed.sql',0o600)
    print(json.dumps({'prepared':True,'identities':3,'scenarios':5,'credentials_logged':False}))
def login():
    def one(u):
        status,data=request('/auth/v1/token?grant_type=password',payload={'email':u['email'],'password':u['password']})
        token=data.get('access_token') if isinstance(data,dict) else None
        if status!=200 or not token:return u['profile'],None,{'profile':u['profile'],'pass':False,'http_login':status}
        check,identity=request('/auth/v1/user',token)
        return u['profile'],token,{'profile':u['profile'],'pass':check==200 and identity.get('id')==u['id'],'http_login':status,'http_identity':check}
    with ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(one,read('fixture.json')['users']))
    write('sessions.json',{p:t for p,t,_ in rows if t});write('auth-report.json',[r for _,_,r in rows])
    print(json.dumps({'auth':[r for _,_,r in rows]}));return 0 if all(r['pass'] for _,_,r in rows) else 1
def case(index,replay=False):
    role,label=SCENARIOS[index];c=read('fixture.json')['cases'][label];token=read('sessions.json')[role]
    payload={'p_id_relatorio':c['report'],'p_id_versao_documento':c['version']}
    data=read('results.json') if (ROOT/'results.json').exists() else []
    status,value=request('/rest/v1/rpc/enfileirar_ingestao_historica_hml',token,payload)
    if replay:
        result=next(x for x in data if x['index']==index)
        result.update({'http_replay':status,'same_execution':result['uuid_valid'] and result['execution']==value})
        result['pass_http']=result['http_first']==200 and status==200 and result['same_execution']
        ok=result['pass_http']
    else:
        try:valid=str(uuid.UUID(value))==value
        except (ValueError,TypeError,AttributeError):valid=False
        result={'index':index,'profile':role,'case':label,'http_first':status,'uuid_valid':valid,'execution':value if valid else None,'pass_first':status==200 and valid}
        if not result['pass_first']:result['pgcode']=value.get('code') if isinstance(value,dict) else None
        data.append(result);ok=result['pass_first']
    write('results.json',data)
    print(json.dumps({k:v for k,v in result.items() if k!='execution'}));return 0 if ok else 1
def logout():
    def one(item):
        role,token=item;status,_=request('/auth/v1/logout?scope=global',token,{})
        return {'profile':role,'http':status,'pass':status in [204,401,403]}
    with ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(one,read('sessions.json').items()))
    write('logout-report.json',rows);print(json.dumps({'logout':rows}));return 0 if all(x['pass'] for x in rows) else 1
if __name__=='__main__':
    mode=sys.argv[1]
    if mode=='prepare':prepare()
    elif mode=='login':sys.exit(login())
    elif mode=='case':sys.exit(case(int(sys.argv[2])))
    elif mode=='replay':sys.exit(case(int(sys.argv[2]),True))
    elif mode=='logout':sys.exit(logout())
    else:raise SystemExit('Unsupported phase')
