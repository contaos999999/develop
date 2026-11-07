"""Real GoTrue identities through Admin API; HTTP RPC and own fixture quarantine only."""
import concurrent.futures as cf
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

URL = 'https://gklhhhyosgasnyoxlrui.supabase.co'
KEY = 'sb_publishable_sHKZ-UiYCbkEFMqR1QbHMA_iCSLL8Am'
ADMIN = os.environ.get('AUTH_ADMIN_KEY', '')
ROOT = Path(os.environ['CONTAOS_TEST_PRIVATE_DIR']).resolve()
assert str(ROOT).startswith(os.environ['RUNNER_TEMP'] + '/')
ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
os.chmod(ROOT, 0o700)
DB = os.environ['DATABASE_URL']
u = urllib.parse.urlsplit(DB)
assert u.username == 'postgres.gklhhhyosgasnyoxlrui' and u.hostname.endswith('.pooler.supabase.com')
uid = lambda: str(uuid.uuid4())
q = lambda s: "'" + str(s).replace("'", "''") + "'"
report = {'mode': 'REAL_AUTH_ADMIN_V117', 'assertions': [], 'state': 'RUNNING'}

def save(name, data):
    p = ROOT / name
    p.write_text(json.dumps(data, indent=2) + '\n')
    os.chmod(p, 0o600)

def sql(query, fetch=False):
    p = subprocess.run(['psql', DB, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], input=query, capture_output=True, text=True, timeout=45)
    if p.returncode:
        raise RuntimeError('Own fixture database operation failed; private details withheld')
    return p.stdout.strip() if fetch else None

def request(path, data=None, token=None, admin=False, method=None):
    headers = {'apikey': ADMIN if admin else KEY, 'Content-Type': 'application/json'}
    if admin or token:
        headers['Authorization'] = 'Bearer ' + (ADMIN if admin else token)
    req = urllib.request.Request(URL + path, data=None if data is None else json.dumps(data).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read())
        except ValueError:
            return e.code, {}
    except Exception:
        return 0, {}

def check(name, ok, status=None):
    report['assertions'].append({'name': name, 'pass': bool(ok), 'http': status})
    save('report.json', report)
    if not ok:
        raise RuntimeError('Assertion failed: ' + name)

def rpc(name, payload, token):
    return request('/rest/v1/rpc/' + name, payload, token)

def cleanup():
    if not (ROOT / 'fixture.json').exists():
        return
    f = json.loads((ROOT / 'fixture.json').read_text())
    ids = [u['id'] for u in f['users'] if u.get('id')]
    if ids:
        sql('begin;update privado.administradores_master set ativo=false where id_usuario in (' + ','.join(map(q, ids)) + ');update public.vinculos_usuarios set ativo=false where id_usuario in (' + ','.join(map(q, ids)) + ');commit;')
    for user in f['users']:
        if user.get('id'):
            st, _ = request('/auth/v1/admin/users/' + user['id'], {'ban_duration': '876000h'}, admin=True, method='PUT')
            if st != 200:
                raise RuntimeError('Own Auth fixture quarantine failed')
    if ids:
        # Revoke only sessions of own synthetic identities. Provisioning never uses SQL Auth writes.
        sql('delete from auth.sessions where user_id in (' + ','.join(map(q, ids)) + ');')
    if f.get('seeded'):
        sql('update public.organizacoes set situacao=\'inativa\' where id=' + q(f['org']) + ';')
    save('cleanup.json', {'state': 'QUARENTENA_VERIFICADA', 'own_users': len(ids)})

if '--cleanup' in sys.argv:
    cleanup()
    sys.exit(0)
try:
    if not ADMIN:
        report['state'] = 'CONFIG_BLOCKED_AUTH_ADMIN_KEY_MISSING'
        save('report.json', report)
        raise RuntimeError('Auth Admin API credential unavailable; no identities or business fixtures created')
    assert not (ROOT / 'fixture.json').exists(), 'Refuse fixture reuse'
    f = {'scope': 'P0-V117-REVISAO', 'org': uid(), 'contractor': uid(), 'contract': uid(), 'competence': uid(), 'requirement': uid(), 'requirement2': uid(), 'execution': uid(), 'users': []}
    save('fixture.json', f)
    for profile in ['administrador', 'master', 'auditor', 'leitor', 'sem_vinculo']:
        user = {'profile': profile, 'email': 'v117-' + uid() + '@example.invalid', 'password': secrets.token_urlsafe(40) + 'Aa1!'}
        st, data = request('/auth/v1/admin/users', {'email': user['email'], 'password': user['password'], 'email_confirm': True, 'app_metadata': {'synthetic': True, 'scope': f['scope']}}, admin=True)
        check('Auth Admin creates own ' + profile, st in (200, 201) and isinstance(data, dict) and bool(data.get('id')), st)
        user['id'] = data['id']
        f['users'].append(user)
        save('fixture.json', f)
    statements = ['begin;', f"insert into public.organizacoes(id,razao_social) values({q(f['org'])},'V117 synthetic review');", f"insert into public.contratantes(id,id_organizacao,razao_social) values({q(f['contractor'])},{q(f['org'])},'V117 synthetic');", f"insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values({q(f['contract'])},{q(f['org'])},{q(f['contractor'])},'V117-{uid()}','Synthetic review','2026-01-01');"]
    for user in f['users']:
        if user['profile'] == 'master':
            statements.append(f"insert into privado.administradores_master(id_usuario,motivo) values({q(user['id'])},'Own synthetic V117 review');")
        elif user['profile'] != 'sem_vinculo':
            statements.append(f"insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values({q(f['org'])},{q(user['id'])},{q(user['profile'])},true);")
    statements.append(f"insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao) values({q(f['competence'])},{q(f['org'])},{q(f['contract'])},'2026-11-01','2026-11-01','2026-11-30','em_analise');")
    for req in [f['requirement'], f['requirement2']]:
        statements.append(f"insert into public.requisitos_competencia(id,id_organizacao,id_contrato,id_competencia,origem_tipo,descricao,hash_snapshot,codigo) values({q(req)},{q(f['org'])},{q(f['contract'])},{q(f['competence'])},'manual','Synthetic requirement',{q(req)},{q(req)});")
    statements.append(f"insert into public.execucoes_analise(id,id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,concluida_em) values({q(f['execution'])},{q(f['org'])},{q(f['contract'])},{q(f['competence'])},'completa','concluida',privado.hash_contexto_competencia({q(f['competence'])}),now());")
    statements.append('commit;')
    sql('\n'.join(statements))
    f['seeded'] = True
    save('fixture.json', f)
    tokens = {}
    for user in f['users']:
        st, data = request('/auth/v1/token?grant_type=password', {'email': user['email'], 'password': user['password']})
        check('GoTrue login ' + user['profile'], st == 200 and bool(data.get('access_token')), st)
        tokens[user['profile']] = data['access_token']
    payload = {'p_id_competencia': f['competence'], 'p_id_requisito': f['requirement']}
    st, ctx = rpc('obter_contexto_revisao_v117', payload, tokens['administrador'])
    check('Authorized context', st == 200 and ctx.get('pode_revisar') is True, st)
    for profile in ['master', 'auditor']:
        st, data = rpc('obter_contexto_revisao_v117', payload, tokens[profile])
        check('Capability ' + profile, st == 200 and data.get('pode_revisar') is True, st)
    for profile in ['leitor', 'sem_vinculo']:
        st, _ = rpc('obter_contexto_revisao_v117', payload, tokens[profile])
        check('Denied context ' + profile, st == 403, st)
    def command(context, key):
        return {**payload, 'p_id_execucao_esperada': context['id_execucao_esperada'], 'p_id_resultado_esperado': context['id_resultado_esperado'], 'p_hash_esperado': context['hash_esperado'], 'p_resultado': 'conforme', 'p_justificativa': 'Own synthetic review', 'p_fundamento': 'Controlled fixture', 'p_evidencias': [], 'p_request_id': key}
    cmd = command(ctx, uid())
    st, receipt = rpc('registrar_revisao_requisito_v117', cmd, tokens['administrador'])
    check('Review success', st == 200 and bool(receipt.get('id_resultado')), st)
    st, data = rpc('registrar_revisao_requisito_v117', cmd, tokens['administrador'])
    check('Exact HTTP replay', st == 200 and data == receipt, st)
    st, _ = rpc('registrar_revisao_requisito_v117', {**cmd, 'p_resultado': 'nao_conforme'}, tokens['administrador'])
    check('Different payload same key denied', st == 409, st)
    st, _ = rpc('registrar_revisao_requisito_v117', {**cmd, 'p_request_id': uid()}, tokens['administrador'])
    check('Stale CAS denied', st == 409, st)
    for profile in ['master', 'auditor']:
        st, _ = rpc('registrar_revisao_requisito_v117', cmd, tokens[profile])
        check('Other actor cannot replay ' + profile, st == 409, st)
    for profile in ['leitor', 'sem_vinculo']:
        st, _ = rpc('registrar_revisao_requisito_v117', cmd, tokens[profile])
        check('Denied write ' + profile, st == 403, st)
    st, ctx = rpc('obter_contexto_revisao_v117', payload, tokens['administrador'])
    cmd = command(ctx, uid())
    with cf.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: rpc('registrar_revisao_requisito_v117', cmd, tokens['administrador']), range(2)))
    check('Concurrent HTTP same key one receipt', all(x[0] == 200 for x in results) and results[0][1] == results[1][1])
    st, ctx = rpc('obter_contexto_revisao_v117', payload, tokens['administrador'])
    with cf.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda k: rpc('registrar_revisao_requisito_v117', command(ctx, k), tokens['administrador']), [uid(), uid()]))
    check('Concurrent HTTP CAS one winner', sorted(x[0] for x in results) == [200, 409])
    check('Exactly three result/event effects', sql(f"select (select count(*) from public.resultados_requisitos where id_competencia={q(f['competence'])})=3 and (select count(*) from public.eventos_auditoria where evento='RevisaoRequisitoRegistrada' and id_organizacao={q(f['org'])})=3;", True) == 't')
    report['state'] = 'PASS'
finally:
    try:
        cleanup()
        if (ROOT / 'cleanup.json').exists():
            report['cleanup'] = json.loads((ROOT / 'cleanup.json').read_text())
    finally:
        save('report.json', report)
print('V117_REVIEW_REAL_JWT_PASS: ' + str(len(report['assertions'])) + ' assertions, own quarantine verified')
