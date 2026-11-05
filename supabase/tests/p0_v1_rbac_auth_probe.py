import json, os, sys, urllib.request, urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from threading import Lock

ROOT = Path(__file__).parent
URL = 'https://gklhhhyosgasnyoxlrui.supabase.co'
FIXTURE = ROOT / 'fixture.json'
STATE = ROOT / 'sessions.json'
REPORT = ROOT / 'report.json'

def request(path, token=None, payload=None, method=None):
    key = json.loads((ROOT / 'public-key.json').read_text())['key']
    headers = {'apikey': key, 'Content-Type': 'application/json'}
    if token: headers['Authorization'] = 'Bearer ' + token
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(URL + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as res:
            data = res.read()
            return res.status, json.loads(data) if data else None
    except urllib.error.HTTPError as err:
        data = err.read()
        try: data = json.loads(data)
        except ValueError: data = {}
        return err.code, data

def run():
    fixture = json.loads(FIXTURE.read_text())
    report = json.loads(REPORT.read_text()) if REPORT.exists() else {'mode':'REAL_AUTH_HTTP_HML', 'assertions':[]}
    sessions = json.loads(STATE.read_text()) if STATE.exists() else {}
    lock = Lock()
    def check(name, passed, status=None):
        with lock:
            report['assertions'].append({'name':name,'pass':bool(passed),'http':status})
            REPORT.write_text(json.dumps(report, indent=2) + '\n')
    def rpc(name, payload, token):
        return request('/rest/v1/rpc/' + name, token, payload)
    mode = sys.argv[1] if len(sys.argv)>1 else 'baseline'
    if mode == 'baseline':
        def check_user(user):
            status, data = request('/auth/v1/token?grant_type=password', payload={'email':user['email'],'password':user['password']})
            token = data.get('access_token') if isinstance(data,dict) else None
            check(user['profile'] + ': Auth login real', status == 200 and isinstance(token,str), status)
            if not token: return
            with lock:
                sessions[user['profile']] = token
                STATE.write_text(json.dumps(sessions)); os.chmod(STATE,0o600)
            status, data = request('/auth/v1/user', token)
            check(user['profile'] + ': identidade confirmada pelo Auth', status == 200 and data.get('id') == user['id'], status)
            status, data = rpc('listar_organizacoes_disponiveis', {}, token)
            ids = {row['id'] for row in data} if status == 200 and isinstance(data,list) else set()
            expected = {fixture['org_a'],fixture['org_b']} if user['profile']=='master' else ({fixture['org_a']} if user['profile']!='sem_vinculo' else set())
            actual = ids.intersection({fixture['org_a'],fixture['org_b']})
            check(user['profile'] + ': lista organizações no escopo', status == 200 and actual == expected, status)
            status, data = request('/rest/v1/organizacoes?select=id&id=in.(' + fixture['org_a']+','+fixture['org_b']+')',token)
            ids = {row['id'] for row in data} if status == 200 and isinstance(data,list) else set()
            check(user['profile'] + ': RLS organizaçoes direta', status == 200 and ids == expected, status)
            for key in ['org_a','org_b']:
                status, data = rpc('validar_administrador_organizacao',{'p_id_organizacao':fixture[key]},token)
                allowed = user['profile']=='master' or (user['profile']=='administrador' and key=='org_a')
                check(user['profile']+': administrar '+key, (status == 200 and data is True) if allowed else (status == 403 and data.get('code')=='42501'),status)
                status, data = rpc('pode_consultar_auditoria_organizacao',{'p_id_organizacao':fixture[key]},token)
                allowed = user['profile']=='master' or (key=='org_a' and user['profile'] in ['administrador','auditor','juridico_conformidade'])
                check(user['profile']+': auditoria '+key,status == 200 and data is allowed,status)
        completed = {u['profile'] for u in fixture['users'] if sum(x['name'].startswith(u['profile']+':') for x in report['assertions']) == 8}
        report['assertions'] = [x for x in report['assertions'] if x['name'].split(':')[0] in completed]
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(check_user,[u for u in fixture['users'] if u['profile'] not in completed]))
        status, data = rpc('listar_organizacoes_disponiveis', {}, None)
        check('anônimo: organizações negadas',status in [401,403],status)
        status, data = rpc('listar_organizacoes_disponiveis', {}, 'invalid.token.signature')
        check('JWT inválido: organizações negadas',status == 401,status)
    elif mode == 'revoked_membership':
        token = sessions['contabilidade']
        status,data = rpc('listar_organizacoes_disponiveis',{},token)
        check('Contabilidade: vínculo revogado nega com mesmo JWT',status==200 and isinstance(data,list) and not data,status)
        status,data = request('/rest/v1/organizacoes?select=id&id=eq.'+fixture['org_a'],token)
        check('Contabilidade: RLS nega após revogação',status==200 and data==[],status)
    elif mode == 'revoked_session':
        token = sessions['master']
        status,data = rpc('listar_organizacoes_disponiveis',{},token)
        check('MASTER: sessão revogada nega JWT ainda assinado',status==403 and data.get('code')=='42501',status)
        status,data = request('/rest/v1/organizacoes?select=id&id=eq.'+fixture['org_a'],token)
        check('MASTER: RLS nega após revogar sessão',status==200 and data==[],status)
    elif mode == 'logout':
        for profile,token in sessions.items():
            status,data = request('/auth/v1/logout?scope=global',token,{},method='POST')
            check(profile+': logout solicitado',status in [204,401,403],status)
    fails = sum(not item['pass'] for item in report['assertions'])
    print(json.dumps({'mode':mode,'total':len(report['assertions']),'passed':len(report['assertions'])-fails,'failed':fails}))
    return 1 if fails else 0

if __name__ == '__main__':
    try: sys.exit(run())
    except Exception as err:
        print(json.dumps({'error':type(err).__name__,'tokens_logged':False}))
        sys.exit(2)
