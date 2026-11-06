"""Own synthetic HML fixtures only. Real Auth JWT; no matrix edits or secrets in reports."""
import crypt
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import uuid
import urllib.error
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor

URL = 'https://gklhhhyosgasnyoxlrui.supabase.co'
ROOT = Path(os.environ['CONTAOS_TEST_PRIVATE_DIR']).resolve()
ROOT.mkdir(parents=True, exist_ok=True)
os.chmod(ROOT, 0o700)
KEY = 'sb_publishable_sHKZ-UiYCbkEFMqR1QbHMA_iCSLL8Am'
DB = os.environ['DATABASE_URL']
db_parts = urllib.parse.urlsplit(DB)
assert db_parts.username == 'postgres.gklhhhyosgasnyoxlrui' and db_parts.hostname.endswith('.pooler.supabase.com'), 'HML only'
assert str(ROOT).startswith(os.environ['RUNNER_TEMP'] + '/'), 'Private runner temporary path required'
report = {'mode': 'REAL_AUTH_CRUD_CADASTROS', 'assertions': []}
uid = lambda: str(uuid.uuid4())
q = lambda s: "'" + str(s).replace("'", "''") + "'"

def save(name, data):
    p = ROOT / name
    p.write_text(json.dumps(data, indent=2) + '\n')
    os.chmod(p, 0o600)

def sql(source, fetch=False):
    # Never echo SQL/connection or database errors, which can contain fixture secrets.
    p = subprocess.run(['psql', DB, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], input=source, text=True, capture_output=True)
    if p.returncode:
        raise RuntimeError('HML fixture database operation failed; private details withheld')
    return p.stdout.strip() if fetch else None

def request(path, token=None, data=None, method=None):
    headers = {'apikey': KEY, 'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(URL + path, data=None if data is None else json.dumps(data).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read())
        except ValueError:
            body = {}
        return e.code, body
    except Exception:
        return 0, {}

def rpc(name, payload, token):
    return request('/rest/v1/rpc/' + name, token, payload)

def check(name, ok, status=None, data=None):
    item = {'name': name, 'pass': bool(ok), 'http': status}
    if not ok and isinstance(data, dict):
        item['pgcode'] = data.get('code')
    report['assertions'].append(item)
    save('report.json', report)

def prepare():
    if (ROOT / 'fixture.json').exists():
        raise RuntimeError('Refuse fixture reuse')
    f = {'scope': 'P0-CRUD-CADASTROS', 'org_a': uid(), 'org_b': uid(), 'contract_a': uid(), 'contract_b': uid(), 'users': []}
    for profile in ['master', 'administrador', 'leitor', 'sem_vinculo']:
        f['users'].append({'id': uid(), 'profile': profile, 'email': 'p0crud-' + uid() + '@example.invalid', 'password': secrets.token_urlsafe(40) + 'Aa1!'})
    save('fixture.json', f)
    report['fixture_ids'] = {'users': [u['id'] for u in f['users']], 'organizations': [f['org_a'], f['org_b']], 'contracts': [f['contract_a'], f['contract_b']]}
    save('report.json', report)
    statements = ['begin;']
    for u in f['users']:
        encrypted = crypt.crypt(u['password'], crypt.mksalt(crypt.METHOD_BLOWFISH))
        if not encrypted.startswith('$2'):
            raise RuntimeError('bcrypt unavailable')
        statements.append("insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change) values('00000000-0000-0000-0000-000000000000',%s,'authenticated','authenticated',%s,%s,now(),'{\"provider\":\"email\",\"providers\":[\"email\"]}','{\"synthetic\":true,\"scope\":\"P0-CRUD-CADASTROS\"}',now(),now(),'','','','');" % (q(u['id']), q(u['email']), q(encrypted)))
        statements.append("insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at) values(%s,%s,%s::jsonb,'email',now(),now());" % (q(u['id']), q(u['id']), q(json.dumps({'sub': u['id'], 'email': u['email'], 'email_verified': True}))))
    for label in ['a', 'b']:
        org = f['org_' + label]
        contractor = uid()
        statements.append('insert into public.organizacoes(id,razao_social) values(%s,%s);' % (q(org), q('P0 CRUD synthetic ' + org)))
        statements.append("insert into public.contratantes(id,id_organizacao,razao_social) values(%s,%s,'P0 CRUD synthetic');" % (q(contractor), q(org)))
        statements.append("insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values(%s,%s,%s,%s,'P0 CRUD synthetic','2026-11-01');" % (q(f['contract_' + label]), q(org), q(contractor), q('P0-CRUD-' + uid())))
    for u in f['users']:
        if u['profile'] == 'master':
            statements.append("insert into privado.administradores_master(id_usuario,motivo) values(%s,'P0 CRUD synthetic real JWT');" % q(u['id']))
        elif u['profile'] != 'sem_vinculo':
            statements.append('insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values(%s,%s,%s,true);' % (q(f['org_a']), q(u['id']), q(u['profile'])))
    statements.append('commit;')
    sql('\n'.join(statements))
    return f

def run(f):
    tokens = {}
    for u in f['users']:
        status, data = request('/auth/v1/token?grant_type=password', data={'email': u['email'], 'password': u['password']})
        token = data.get('access_token') if isinstance(data, dict) else None
        check(u['profile'] + ': real Auth login', status == 200 and bool(token), status, data)
        if token:
            tokens[u['profile']] = token
            status, user = request('/auth/v1/user', token)
            check(u['profile'] + ': Auth identity', status == 200 and user.get('id') == u['id'], status, user)
    save('tokens.json', tokens)
    if len(tokens) != 4:
        raise RuntimeError('Real Auth setup failed')
    master, admin = tokens['master'], tokens['administrador']
    def get(entity='contratos', org=None, record=None, token=admin):
        org = org or f['org_a']
        return rpc('obter_cadastro_operacional_v1', {'p_id_organizacao': org, 'p_entidade': entity, 'p_id': record or (org if entity == 'organizacoes' else f['contract_a'])}, token)
    def edit_payload(version, patch, record=None):
        return {'p_id_organizacao': f['org_a'], 'p_id_contrato': record or f['contract_a'], 'p_versao_esperada': version, 'p_alteracoes': patch, 'p_motivo': 'Synthetic canonical CRUD verification', 'p_request_id': uid()}
    for profile, token in tokens.items():
        status, data = get(token=token)
        allowed = profile != 'sem_vinculo'
        check(profile + ': read scope', status == 200 if allowed else status == 403, status, data)
        if allowed:
            check(profile + ': server capability', data.get('pode_editar') == (profile in ['master', 'administrador']), status)
        status, data = get(org=f['org_b'], record=f['contract_b'], token=token)
        check(profile + ': tenant isolation', status == 200 if profile == 'master' else status == 403, status, data)
        status, data = rpc('atualizar_contrato_v1', edit_payload(1, {'objeto': 'Denied'}), token) if profile in ['leitor', 'sem_vinculo'] else (403, {})
        if profile in ['leitor', 'sem_vinculo']:
            check(profile + ': mutation denied', status == 403, status, data)
    status, data = get(org=f['org_b'], record=f['contract_a'], token=master)
    check('MASTER: mismatched context denied', status == 403, status, data)
    for token, label in [(None, 'anon'), ('invalid.token.signature', 'invalid JWT')]:
        status, data = get(token=token)
        check(label + ': denied', status in [401, 403], status, data)
    status, data = request('/rest/v1/contratos?id=eq.' + f['contract_a'], admin, {'objeto': 'Bypass', 'versao_registro': 2}, 'PATCH')
    check('direct UPDATE cannot bypass history', status == 403 and data.get('code') == '42501', status, data)
    for patch in [{'id_organizacao': f['org_b']}, {'versao_registro': 999}, {'valor_global': -1}, {'inicio': 'invalid'}, {'fim': '2020-01-01'}]:
        status, data = rpc('atualizar_contrato_v1', edit_payload(1, patch), admin)
        check('invalid/protected field denied ' + next(iter(patch)), status == 422, status, data)
    writes = [edit_payload(1, {'objeto': 'Concurrent synthetic ' + str(i)}) for i in range(2)]
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda p: rpc('atualizar_contrato_v1', p, admin), writes))
    check('real HTTP concurrency one writer', sorted(r[0] for r in results) == [200, 409])
    winner = next((i for i, r in enumerate(results) if r[0] == 200), None)
    if winner is None:
        raise RuntimeError('No successful canonical edit')
    original = results[winner][1]
    check('version increments exactly one', original['registro']['versao_registro'] == 2)
    status, data = rpc('atualizar_contrato_v1', writes[winner], admin)
    check('exact replay', status == 200 and data == original, status, data)
    status, data = rpc('atualizar_contrato_v1', dict(writes[winner], p_alteracoes={'objeto': 'Different'}), admin)
    check('reused key conflict', status == 409, status, data)
    version = 2
    for state in ['ativo', 'suspenso', 'ativo', 'encerrado']:
        payload = edit_payload(version, {})
        payload['p_situacao'] = state
        del payload['p_alteracoes']
        status, data = rpc('alterar_situacao_contrato_v1', payload, admin)
        check('contract state ' + state, status == 200 and data.get('registro', {}).get('versao_registro') == version + 1, status, data)
        version += 1
    payload['p_versao_esperada'] = version
    payload['p_request_id'] = uid()
    payload['p_situacao'] = 'ativo'
    status, data = rpc('alterar_situacao_contrato_v1', payload, admin)
    check('terminal contract cannot reopen', status == 422, status, data)
    p = {'p_id_organizacao': f['org_a'], 'p_versao_esperada': 1, 'p_alteracoes': {'nome_fantasia': 'Synthetic edited'}, 'p_motivo': 'Synthetic organization edit', 'p_request_id': uid()}
    status, data = rpc('atualizar_organizacao_v1', p, master)
    check('MASTER without membership edits organization', status == 200 and data.get('registro', {}).get('versao_registro') == 2, status, data)
    for version, state, token in [(2, 'inativa', admin), (3, 'ativa', admin), (4, 'suspensa', master)]:
        p = {'p_id_organizacao': f['org_a'], 'p_versao_esperada': version, 'p_situacao': state, 'p_motivo': 'Synthetic organization lifecycle', 'p_request_id': uid()}
        status, data = rpc('alterar_situacao_organizacao_v1', p, token)
        check('organization state ' + state, status == 200, status, data)
        if state == 'inativa':
            status, data = rpc('atualizar_contrato_v1', edit_payload(6, {'objeto': 'Denied inactive'}), admin)
            check('inactive organization blocks contract write', status == 403, status, data)
    p.update(p_versao_esperada=5, p_situacao='ativa', p_request_id=uid())
    status, data = rpc('alterar_situacao_organizacao_v1', p, admin)
    check('ordinary admin cannot remove MASTER suspension', status == 422, status, data)
    sql('update public.vinculos_usuarios set ativo=false where id_usuario=' + q(next(u['id'] for u in f['users'] if u['profile'] == 'administrador')) + ' and id_organizacao=' + q(f['org_a']) + ';')
    status, data = rpc('atualizar_contrato_v1', writes[winner], admin)
    check('replay requires current authorization', status == 403, status, data)
    status, data = request('/auth/v1/logout', master, method='POST')
    check('real Auth logout', status in [200, 204], status, data)
    status, data = get(token=master)
    check('same JWT denied after logout', status == 403, status, data)
    counts = json.loads(sql("select json_build_object('events',(select count(*) from public.eventos_auditoria where evento='CadastroOperacionalAtualizado' and id_organizacao=%s),'snapshots',(select count(*) from public.versoes_contrato where id_contrato=%s),'commands',(select count(*) from public.comandos_idempotentes where id_organizacao=%s and comando like 'crud-cadastro-v1:%%'));" % (q(f['org_a']), q(f['contract_a']), q(f['org_a'])), True))
    check('denials/replay no extra effects', counts == {'events': 9, 'snapshots': 6, 'commands': 9})

def quarantine(f):
    ids = ','.join(q(u['id']) for u in f['users'])
    orgs = ','.join(q(f[k]) for k in ['org_a', 'org_b'])
    sql("begin; update auth.users set banned_until=now()+interval '100 years' where id in (%s); delete from auth.sessions where user_id in (%s); update privado.administradores_master set ativo=false where id_usuario in (%s); update public.vinculos_usuarios set ativo=false where id_usuario in (%s); update public.organizacoes set situacao='inativa' where id in (%s); commit;" % (ids, ids, ids, ids, orgs))
    counts = json.loads(sql("select json_build_object('sessions',(select count(*) from auth.sessions where user_id in (%s)),'memberships',(select count(*) from public.vinculos_usuarios where ativo and id_usuario in (%s)),'master',(select count(*) from privado.administradores_master where ativo and id_usuario in (%s)),'banned',(select count(*) from auth.users where id in (%s) and banned_until>now()),'inactive_orgs',(select count(*) from public.organizacoes where id in (%s) and situacao='inativa'));" % (ids, ids, ids, ids, orgs), True))
    report['quarantine'] = counts
    check('quarantine verified', counts == {'sessions': 0, 'memberships': 0, 'master': 0, 'banned': 4, 'inactive_orgs': 2})

f = None
cleaned = False
try:
    if '--cleanup' in sys.argv:
        if (ROOT / 'report.json').exists():
            report = json.loads((ROOT / 'report.json').read_text())
        if (ROOT / 'fixture.json').exists():
            f = json.loads((ROOT / 'fixture.json').read_text())
    else:
        f = prepare()
        report['fixture_ids'] = {'users': [u['id'] for u in f['users']], 'organizations': [f['org_a'], f['org_b']], 'contracts': [f['contract_a'], f['contract_b']]}
        save('report.json', report)
        run(f)
except Exception as error:
    check('execution completed', False)
    report['failure_class'] = type(error).__name__
finally:
    if f is None and (ROOT / 'fixture.json').exists():
        f = json.loads((ROOT / 'fixture.json').read_text())
    if f:
        try:
            quarantine(f)
            cleaned = report.get('quarantine') == {'sessions': 0, 'memberships': 0, 'master': 0, 'banned': 4, 'inactive_orgs': 2}
        except Exception:
            check('quarantine verified', False)
    save('report.json', report)
    for name in ['tokens.json'] + (['fixture.json'] if cleaned else []):
        (ROOT / name).unlink(missing_ok=True)
failed = sum(not x['pass'] for x in report['assertions'])
print(json.dumps({'assertions': len(report['assertions']), 'failed': failed, 'real_auth': True, 'report_sha256': hashlib.sha256((ROOT / 'report.json').read_bytes()).hexdigest()}))
sys.exit(1 if failed else 0)
