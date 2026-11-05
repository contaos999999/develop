import json, os, sys, urllib.request, urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from threading import Lock

ROOT=Path(__file__).parent
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
      {'p_id_competencia':c['comp'],'p_tipo':'outro','p_titulo':'p0postrls','p_categoria':None,'p_id_requisito':None,'p_id_arquivo':c['file'],'p_chave_idempotencia':'p0postrls-criar-'+label},
      {'p_id_documento':c['doc'],'p_id_arquivo':c['file'],'p_motivo':'p0postrls','p_chave_idempotencia':'p0postrls-adicionar-'+label},
      {'p_id_arquivo':c['file'],'p_competencia':'2026-11-01','p_tipo':'relatorio_contratante'},
      {'p_id_relatorio':c['report'],'p_id_versao_documento':c['version']},
      {'p_id_apontamento':c['point'],'p_resposta':'p0postrls:'+profile+':'+label,'p_desfecho':'prova_sintetica','p_fundamento':'Teste autorizado HML'}]

def permitted(profile,label,index):
    scoped=profile=='master' or (label!='B1' and profile!='sem_vinculo' and not(profile=='restrito' and label=='A2'))
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
            orgs={f['org_a'],f['org_b']} if profile=='master' else (set() if profile=='sem_vinculo' else {f['org_a']})
            status,data=rpc('listar_organizacoes_disponiveis',{},token)
            found={x['id'] for x in data} if status==200 and isinstance(data,list) else set()
            check(profile+':organizations',status==200 and found.intersection({f['org_a'],f['org_b']})==orgs,status)
            all_ids={c['contract'] for c in f['cases'].values()}
            expected=all_ids if profile=='master' else ({f['cases']['A1']['contract']} if profile=='restrito' else (set() if profile=='sem_vinculo' else {f['cases']['A1']['contract'],f['cases']['A2']['contract']}))
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

if __name__=='__main__':sys.exit(run())
