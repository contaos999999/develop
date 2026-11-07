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
report = {'mode': 'REAL_AUTH_CRUD_LISTAS', 'assertions': []}
uid = lambda: str(uuid.uuid4())
q = lambda s: "'" + str(s).replace("'", "''") + "'"

def save(name, data):
    p = ROOT / name
    p.write_text(json.dumps(data, indent=2) + '\n')
    os.chmod(p, 0o600)

def sql(source, fetch=False):
    # Never echo SQL/connection or database errors, which can contain fixture secrets.
    p = subprocess.run(['psql', DB, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], input=source, text=True, capture_output=True, timeout=45)
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
    f = {'scope': 'P0-CRUD-LISTAS', 'org_a': uid(), 'org_b': uid(),
         'contract_a': uid(), 'contract_a2': uid(), 'contract_b': uid(),
         'contractor_a': uid(), 'contractor_b': uid(), 'users': []}
    for profile in ['master', 'administrador', 'leitor', 'sem_vinculo', 'restrito']:
        f['users'].append({'id': uid(), 'profile': profile, 'email': 'p0lista-' + uid() + '@example.invalid', 'password': secrets.token_urlsafe(40) + 'Aa1!'})
    save('fixture.json', f)
    report['fixture_ids'] = {'users': [u['id'] for u in f['users']],
                            'organizations': [f['org_a'], f['org_b']],
                            'contracts': [f['contract_a'], f['contract_a2'], f['contract_b']]}
    save('report.json', report)
    statements = ['begin;']
    for u in f['users']:
        encrypted = crypt.crypt(u['password'], crypt.mksalt(crypt.METHOD_BLOWFISH))
        if not encrypted.startswith('$2'):
            raise RuntimeError('bcrypt unavailable')
        meta = json.dumps({'synthetic': True, 'scope': f['scope'], 'master': True})
        statements.append("insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change) values('00000000-0000-0000-0000-000000000000',%s,'authenticated','authenticated',%s,%s,now(),'{\"provider\":\"email\",\"providers\":[\"email\"]}',%s::jsonb,now(),now(),'','','','');" % (q(u['id']), q(u['email']), q(encrypted), q(meta)))
        statements.append("insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at) values(%s,%s,%s::jsonb,'email',now(),now());" % (q(u['id']), q(u['id']), q(json.dumps({'sub': u['id'], 'email': u['email'], 'email_verified': True}))))
    for label in ['a', 'b']:
        statements.append('insert into public.organizacoes(id,razao_social) values(%s,%s);' % (q(f['org_' + label]), q('P0 checklist synthetic ' + f['org_' + label])))
        statements.append("insert into public.contratantes(id,id_organizacao,razao_social) values(%s,%s,'P0 checklist synthetic');" % (q(f['contractor_' + label]), q(f['org_' + label])))
    for label in ['a', 'a2', 'b']:
        tenant = 'a' if label.startswith('a') else 'b'
        statements.append("insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values(%s,%s,%s,%s,'P0 checklist synthetic','2026-01-01');" % (q(f['contract_' + label]), q(f['org_' + tenant]), q(f['contractor_' + tenant]), q('P0-LISTA-' + uid())))
    for u in f['users']:
        if u['profile'] == 'master':
            statements.append("insert into privado.administradores_master(id_usuario,motivo) values(%s,'P0 CRUD LISTAS synthetic real JWT');" % q(u['id']))
        elif u['profile'] != 'sem_vinculo':
            profile = 'gestor_contrato' if u['profile'] == 'restrito' else u['profile']
            statements.append('insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values(%s,%s,%s,%s);' % (q(f['org_a']), q(u['id']), q(profile), str(u['profile'] != 'restrito').lower()))
            if u['profile'] == 'restrito':
                statements.append('insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo) select id_organizacao,id,%s,true from public.vinculos_usuarios where id_usuario=%s and id_organizacao=%s;' % (q(f['contract_a']), q(u['id']), q(f['org_a'])))
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
            status, identity = request('/auth/v1/user', token)
            check(u['profile'] + ': Auth identity', status == 200 and identity.get('id') == u['id'], status, identity)
    save('tokens.json', tokens)
    if len(tokens) != 5:
        raise RuntimeError('Real Auth setup failed')
    admin, master = tokens['administrador'], tokens['master']
    states = {}
    def context(label='a'):
        return (f['org_a'] if label.startswith('a') else f['org_b'], f['contract_' + label])
    def get(lista=None, versao=None, token=admin, label='a', expected=200, name='read'):
        org, contract = context(label)
        status, data = rpc('obter_lista_operacional_v1', {'p_id_organizacao': org, 'p_id_contrato': contract, 'p_id_lista': lista, 'p_id_versao': versao, 'p_pagina_versoes': 0, 'p_pagina_itens': 0}, token)
        check(name, status == expected, status, data)
        if expected == 200:
            if status != 200 or data.get('schema_versao') != 'crud-lista-v1' or data.get('id_organizacao') != org or data.get('id_contrato') != contract:
                raise RuntimeError('Invalid checklist read context')
            if lista:
                if data.get('lista', {}).get('id') != lista:
                    raise RuntimeError('Invalid checklist target')
                states[lista] = data['lista']['versao_registro']
        return status, data
    def payload(action, values, lista=None, expected_version=None, key=None, label='a'):
        org, contract = context(label)
        return {'p_id_organizacao': org, 'p_id_contrato': contract, 'p_id_lista': lista,
                'p_versao_esperada': None if action == 'criar_lista' else states[lista] if expected_version is None else expected_version,
                'p_acao': action, 'p_payload': values, 'p_motivo': 'Synthetic canonical checklist verification', 'p_request_id': key or uid()}
    def send(action, values, lista=None, token=admin, label='a', expected=200, key=None, expected_version=None, name=None):
        p = payload(action, values, lista, expected_version, key, label)
        status, data = rpc('executar_comando_lista_v1', p, token)
        check(name or action, status == expected, status, data)
        if expected == 200:
            org, contract = context(label)
            target = data.get('lista', {}) if isinstance(data, dict) else {}
            if status != 200 or data.get('schema_versao') != 'crud-lista-v1' or data.get('id_organizacao') != org or data.get('id_contrato') != contract or target.get('id_organizacao') != org or target.get('id_contrato') != contract or data.get('request_id') != p['p_request_id']:
                raise RuntimeError('Invalid checklist mutation context')
            if lista and target.get('id') != lista:
                raise RuntimeError('Invalid mutation target')
            required = 1 if action == 'criar_lista' else p['p_versao_esperada'] + 1
            check((name or action) + ': exactly one header version', target.get('versao_registro') == required)
            states[target['id']] = max(states.get(target['id'], 0), target['versao_registro'])
            if action == 'criar_lista':
                report.setdefault('list_ids', []).append(target['id']); save('report.json', report)
        return p, status, data
    def requirements(comp):
        status, rows = request('/rest/v1/requisitos_competencia?select=id,id_organizacao,id_contrato,origem_tipo,origem_id,origem_versao,codigo,descricao,obrigatorio,aplicavel,impeditivo,fonte_detalhe,regra_validacao,hash_snapshot&id_competencia=eq.' + comp + '&order=id', admin)
        check('snapshot read', status == 200, status)
        if status != 200:
            raise RuntimeError('Snapshot read unavailable')
        return rows
    def competencia(month, name):
        status, comp = rpc('criar_competencia', {'p_id_contrato': f['contract_a'], 'p_competencia_referencia': month, 'p_periodo_inicio': None, 'p_periodo_fim': None, 'p_data_limite': None}, admin)
        check(name, status == 200 and isinstance(comp, str), status, comp)
        if status != 200 or not isinstance(comp, str):
            raise RuntimeError('Competence creation failed')
        report.setdefault('competence_ids', []).append(comp); save('report.json', report)
        return comp

    # First-time normative creation/approval uses the existing real public APIs,
    # not a seeded replay or a fixture already marked approved.
    def norma(label, token, approve=True, global_scope=False):
        org, contract = context(label)
        scope_contract = None if global_scope else contract
        titulo = 'P0 checklist synthetic source ' + uid()
        status, data = rpc('salvar_fonte_normativa_v107', {'p_id_organizacao': org, 'p_id_contrato': scope_contract, 'p_id_fonte': None, 'p_tipo': 'lei', 'p_titulo': titulo, 'p_referencia': 'Synthetic verification', 'p_descricao': None, 'p_situacao': 'rascunho', 'p_versao_esperada': None, 'p_chave_idempotencia': uid()}, token)
        check('normative first creation ' + label, status == 200, status, data)
        fonte = data.get('fonte', {}) if isinstance(data, dict) else {}
        if status != 200 or fonte.get('id_organizacao') != org or fonte.get('id_contrato') != scope_contract:
            raise RuntimeError('Invalid normative source context')
        status, data = rpc('registrar_versao_fonte_v107', {'p_id_organizacao': org, 'p_id_fonte': fonte['id'], 'p_inicio_vigencia': '2026-01-01', 'p_fim_vigencia': None, 'p_id_arquivo': None, 'p_conteudo_texto': 'Norma textual sintética exclusiva do teste de listas.', 'p_metadados': {'synthetic': True}, 'p_chave_idempotencia': uid()}, token)
        check('normative first version ' + label, status == 200, status, data)
        versao = data.get('versao', {}) if isinstance(data, dict) else {}
        if status != 200 or versao.get('id_organizacao') != org or versao.get('id_contrato') != scope_contract:
            raise RuntimeError('Invalid normative version context')
        if approve:
            status, data = rpc('aprovar_versao_fonte_v107', {'p_id_organizacao': org, 'p_id_versao': versao['id'], 'p_hash_esperado': versao['hash'], 'p_fundamento': 'Aprovação sintética controlada pelo administrador de teste', 'p_chave_idempotencia': uid()}, token)
            check('normative approval ' + label, status == 200, status, data)
            if status != 200:
                raise RuntimeError('Normative approval failed')
            status, rows = request('/rest/v1/fontes_normativas?select=id,versao_registro&id=eq.' + fonte['id'], token)
            if status != 200 or len(rows) != 1:
                raise RuntimeError('Normative version refresh failed')
            status, data = rpc('salvar_fonte_normativa_v107', {'p_id_organizacao': org, 'p_id_contrato': scope_contract, 'p_id_fonte': fonte['id'], 'p_tipo': 'lei', 'p_titulo': titulo, 'p_referencia': 'Synthetic verification', 'p_descricao': None, 'p_situacao': 'ativa', 'p_versao_esperada': rows[0]['versao_registro'], 'p_chave_idempotencia': uid()}, token)
            check('normative activation ' + label, status == 200, status, data)
            if status != 200:
                raise RuntimeError('Normative activation failed')
        report.setdefault('normative_version_ids', []).append(versao['id']); save('report.json', report)
        return versao

    for profile, token in tokens.items():
        status, data = get(token=token, expected=403 if profile == 'sem_vinculo' else 200, name=profile + ': checklist context')
        if status == 200:
            check(profile + ': server create capability', data['acoes']['criar_lista'] == (profile in ['master', 'administrador', 'restrito']))
            check(profile + ': no null capabilities', all(isinstance(x, bool) for x in data['acoes'].values()))
        get(token=token, label='b', expected=200 if profile == 'master' else 403, name=profile + ': tenant B access')
    get(token=tokens['restrito'], label='a2', expected=403, name='restricted contract cannot access A2')
    for token, label in [(None, 'anon'), ('invalid.token.signature', 'invalid JWT')]:
        org, contract = context()
        status, data = rpc('obter_lista_operacional_v1', {'p_id_organizacao': org, 'p_id_contrato': contract}, token)
        check(label + ': API denied', status in [401, 403], status, data)
    approved = norma('a', admin)
    unapproved = norma('a', admin, approve=False)
    foreign = norma('b', master, approve=False)
    global_source = norma('a', admin, global_scope=True)
    p_app = {'p_id_organizacao': f['org_a'], 'p_id_contrato': f['contract_a'], 'p_id_versao': global_source['id'], 'p_aplicavel': False, 'p_fundamento': 'Aplicabilidade sintética inicialmente negada', 'p_atualizado_em_esperado': None, 'p_chave_idempotencia': uid()}
    status, app = rpc('definir_aplicabilidade_fonte_v107', p_app, admin)
    check('global source initially not applicable', status == 200, status, app)
    if status != 200:
        raise RuntimeError('Applicability preparation failed')

    create_payload, status, created = send('criar_lista', {'nome': 'P0 real JWT checklist', 'vigencia_inicio': '2026-01-01'}, name='create checklist')
    lista, v1 = created['lista']['id'], created['id_versao']
    status, replay = rpc('executar_comando_lista_v1', create_payload, admin)
    check('create exact replay', status == 200 and replay == created, status, replay)
    status, data = rpc('executar_comando_lista_v1', dict(create_payload, p_payload={'nome': 'Different'}), admin)
    check('create key payload conflict', status == 409, status, data)
    send('editar_lista', {'nome': 'Denied'}, lista, token=tokens['leitor'], expected=403, name='forged MASTER metadata cannot edit')
    send('editar_lista', {'nome': 'Denied'}, lista, token=tokens['sem_vinculo'], expected=403, name='no membership cannot edit')
    send('editar_lista', {'id_organizacao': f['org_b']}, lista, expected=422, name='protected header field')
    send('editar_lista', {'nome': 'Stale'}, lista, expected=409, expected_version=999, name='stale header')
    send('apagar_tudo', {}, lista, expected=422, name='unknown command')
    send('criar_versao', {}, lista, expected=409, name='only one open draft')
    send('editar_vigencia_rascunho', {'id_versao': v1, 'vigencia_inicio': '2026-12-31', 'vigencia_fim': '2026-01-01'}, lista, expected=422, name='inverted validity')
    send('salvar_item', {'id_versao': v1, 'codigo': 'TEMP', 'descricao': 'Temporary draft item', 'obrigatorio': False}, lista)
    _, _, temp = send('remover_item', {'id_versao': v1, 'id_item': get(lista)[1]['itens'][0]['id']}, lista)
    status, rows = request('/rest/v1/itens_lista?select=id&id=eq.' + temp['id_item'], admin)
    check('permitted draft item physically removed', status == 200 and rows == [], status)

    _, _, other = send('criar_lista', {'nome': 'P0 B checklist'}, token=master, label='b')
    lb, vb = other['lista']['id'], other['id_versao']
    _, _, other_item = send('salvar_item', {'id_versao': vb, 'codigo': 'B', 'descricao': 'Owned tenant B fixture', 'obrigatorio': False}, lb, token=master, label='b')
    _, _, a2 = send('criar_lista', {'nome': 'P0 A2 checklist'}, token=master, label='a2')
    get(a2['lista']['id'], token=tokens['restrito'], label='a2', expected=403, name='restricted list scope denied')
    get(lb, token=master, expected=403, name='MASTER cannot mismatch target context')
    get(lista, vb, expected=403, name='foreign version cannot be selected in A')
    send('salvar_item', {'id_versao': v1, 'id_item': other_item['id_item'], 'descricao': 'Foreign rewrite'}, lista, expected=403, name='foreign child target')
    send('salvar_item', {'id_versao': v1, 'codigo': 'FOREIGN', 'descricao': 'Foreign source', 'id_fonte_versao': foreign['id']}, lista, expected=403, name='foreign normative source')
    send('salvar_item', {'id_versao': v1, 'codigo': 'INVALID', 'descricao': 'Unknown condition', 'regra_validacao': {'condicao': {'tipo': 'not_implemented'}}}, lista, expected=422, name='unknown native condition')
    _, _, material = send('salvar_item', {'id_versao': v1, 'codigo': 'P0-COND', 'descricao': 'Conditional version one', 'aplicavel': False, 'obrigatorio': True, 'impeditivo': True, 'regra_validacao': {'condicao': {'tipo': 'sempre'}}}, lista)
    item1 = material['id_item']
    send('publicar_versao', {'id_versao': v1}, lista, expected=422, name='conditional false item still requires a source')
    send('salvar_item', {'id_versao': v1, 'id_item': item1, 'id_fonte_versao': unapproved['id']}, lista)
    send('publicar_versao', {'id_versao': v1}, lista, expected=422, name='unapproved source cannot publish')
    send('salvar_item', {'id_versao': v1, 'id_item': item1, 'id_fonte_versao': approved['id']}, lista)
    send('publicar_versao', {'id_versao': v1}, lista, token=tokens['restrito'], expected=403, name='gestor cannot bypass approval role')
    send('publicar_versao', {'id_versao': v1}, lista, token=master, name='MASTER administrative inheritance publishes')
    send('salvar_item', {'id_versao': v1, 'id_item': item1, 'descricao': 'No rewrite'}, lista, expected=422, name='published content immutable')
    send('remover_item', {'id_versao': v1, 'id_item': item1}, lista, expected=422, name='published item retained')
    status, data = request('/rest/v1/itens_lista?id=eq.' + item1, admin, {'descricao': 'Bypass'}, 'PATCH')
    check('direct published item UPDATE denied', status == 403, status, data)
    status, data = request('/rest/v1/listas_verificacao?id=eq.' + lista, admin, {'nome': 'Bypass', 'versao_registro': states[lista] + 1}, 'PATCH')
    check('direct header UPDATE denied with correct version', status == 403, status, data)
    comp_fev = competencia('2026-02-01', 'first real monthly snapshot')
    old_rows = requirements(comp_fev)
    check('conditional trigger makes the approved item applicable', len(old_rows) == 1 and old_rows[0]['aplicavel'] is True and old_rows[0]['impeditivo'] is True)
    old_hash = hashlib.sha256(json.dumps(old_rows, sort_keys=True).encode()).hexdigest()
    send('encerrar_vigencia', {'id_versao': v1, 'vigencia_fim': '2026-01-31'}, lista, expected=422, name='cannot truncate preserved snapshot period')
    send('encerrar_vigencia', {'id_versao': v1, 'vigencia_fim': '2026-02-28'}, lista)
    send('encerrar_vigencia', {'id_versao': v1, 'vigencia_fim': '2026-03-31'}, lista, expected=422, name='validity closure occurs only once')
    _, _, cloned = send('criar_versao', {'id_versao_origem': v1, 'vigencia_inicio': '2026-02-01'}, lista)
    v2 = cloned['id_versao']
    _, draft = get(lista, v2)
    check('clone copies content into new item identities', len(draft['itens']) == 1 and draft['itens'][0]['id'] != item1)
    item2 = draft['itens'][0]['id']
    send('publicar_versao', {'id_versao': v2}, lista, expected=422, name='overlapping publication rejected')
    send('editar_vigencia_rascunho', {'id_versao': v2, 'vigencia_inicio': '2026-03-01'}, lista)
    send('salvar_item', {'id_versao': v2, 'id_item': item2, 'descricao': 'Conditional version two', 'id_fonte_versao': global_source['id']}, lista)
    send('publicar_versao', {'id_versao': v2}, lista, expected=422, name='global source requires approved applicability')
    p_app.update(p_aplicavel=True, p_fundamento='Aplicabilidade sintética aprovada para a lista', p_atualizado_em_esperado=app['aplicabilidade']['atualizado_em'], p_chave_idempotencia=uid())
    status, data = rpc('definir_aplicabilidade_fonte_v107', p_app, admin)
    check('global applicability approved through canonical API', status == 200, status, data)
    if status != 200:
        raise RuntimeError('Applicability approval failed')
    send('publicar_versao', {'id_versao': v2}, lista)
    comp_mar = competencia('2026-03-01', 'new period snapshot')
    rows = requirements(comp_mar)
    check('new period gets version two only', len(rows) == 1 and rows[0]['origem_versao'] == '2' and rows[0]['descricao'] == 'Conditional version two')
    comp_jan = competencia('2026-01-01', 'retrospective period snapshot')
    rows = requirements(comp_jan)
    check('retrospective period keeps older published version', len(rows) == 1 and rows[0]['origem_versao'] == '1' and rows[0]['descricao'] == 'Conditional version one')
    check('old monthly snapshot remains identical', hashlib.sha256(json.dumps(requirements(comp_fev), sort_keys=True).encode()).hexdigest() == old_hash)
    report['snapshot_sha256'] = old_hash; save('report.json', report)

    # Real HTTP concurrent writers and duplicate replay.
    get(lista, v2)
    version = states[lista]
    commands = [payload('editar_lista', {'descricao': 'HTTP concurrent ' + str(n)}, lista, version) for n in range(2)]
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = list(pool.map(lambda p: rpc('executar_comando_lista_v1', p, admin), commands))
    check('real HTTP two writers exactly one winner', sorted(x[0] for x in outcomes) == [200, 409])
    winner = next((n for n, x in enumerate(outcomes) if x[0] == 200), None)
    if winner is None:
        raise RuntimeError('No concurrent writer succeeded')
    original = outcomes[winner][1]
    status, data = rpc('executar_comando_lista_v1', commands[winner], admin)
    check('HTTP winning command exact replay', status == 200 and data == original, status, data)
    status, data = rpc('executar_comando_lista_v1', dict(commands[winner], p_payload={'descricao': 'Altered retry'}), admin)
    check('HTTP replay payload conflict', status == 409, status, data)
    get(lista, v2)
    duplicate = payload('editar_lista', {'descricao': 'Concurrent duplicate'}, lista)
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = list(pool.map(lambda _: rpc('executar_comando_lista_v1', duplicate, admin), [1, 2]))
    check('HTTP concurrent duplicate has identical receipt', all(x[0] == 200 for x in outcomes) and outcomes[0][1] == outcomes[1][1])
    get(lista, v2)

    # Both real HTTP calls queue behind a lock held only on this own fixture.
    # The isolated suite separately proves the forced snapshot-first ordering.
    controller = subprocess.Popen(['psql', DB, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
    try:
        controller.stdin.write("begin; set local statement_timeout='25s'; select 1 from public.contratos where id=" + q(f['contract_a']) + " and id_organizacao=" + q(f['org_a']) + " for update; select 'READY';\n")
        controller.stdin.flush()
        while True:
            line = controller.stdout.readline()
            if line.strip() == 'READY':
                break
            if line == '':
                raise RuntimeError('Own fixture lock preparation failed')
        closing = payload('encerrar_vigencia', {'id_versao': v2, 'vigencia_fim': '2026-03-31'}, lista)
        monthly = {'p_id_contrato': f['contract_a'], 'p_competencia_referencia': '2026-04-01', 'p_periodo_inicio': None, 'p_periodo_fim': None, 'p_data_limite': None}
        import time
        with ThreadPoolExecutor(max_workers=2) as pool:
            close_future = pool.submit(rpc, 'executar_comando_lista_v1', closing, admin)
            comp_future = pool.submit(rpc, 'criar_competencia', monthly, admin)
            time.sleep(0.3)
            controller.stdin.write('commit;\n\\q\n'); controller.stdin.flush()
            close_result, comp_result = close_future.result(timeout=40), comp_future.result(timeout=40)
        check('HTTP closure/snapshot calls resolve safely', close_result[0] in [200, 422] and comp_result[0] == 200)
        if comp_result[0] != 200:
            raise RuntimeError('Concurrent monthly snapshot failed')
        april_rows = requirements(comp_result[1])
        _, live = get(lista, v2)
        safe = len(april_rows) == 0 and live['versao']['vigencia_fim'] == '2026-03-31' if close_result[0] == 200 else len(april_rows) == 1 and live['versao']['vigencia_fim'] is None
        check('HTTP closure/snapshot has a serializable temporal outcome', safe)
    finally:
        if controller.poll() is None:
            try:
                controller.stdin.write('rollback;\n\\q\n'); controller.stdin.flush()
                controller.wait(timeout=5)
            except Exception:
                controller.terminate(); controller.wait(timeout=5)
    _, _, discarded = send('criar_versao', {'vigencia_inicio': '2027-01-01'}, lista)
    v3 = discarded['id_versao']
    send('publicar_versao', {'id_versao': v3}, lista, expected=422, name='empty draft cannot publish')
    send('descartar_rascunho', {'id_versao': v3}, lista)
    _, data = get(lista, v3)
    check('discard retains an unapproved version', data['versao']['situacao'] == 'substituida' and data['versao']['aprovado_em'] is None)
    send('alterar_situacao', {'situacao': 'inativa'}, lista)
    send('alterar_situacao', {'situacao': 'ativa'}, lista)
    status, data = request('/rest/v1/listas_verificacao?id=eq.' + lista, admin, method='DELETE')
    check('direct DELETE is denied or affects no rows', status in [204, 403], status, data)
    get(lista, v3, name='retained header survives direct DELETE')
    last, _, receipt = send('editar_lista', {'descricao': 'Final authorized command'}, lista)
    admin_id = next(u['id'] for u in f['users'] if u['profile'] == 'administrador')
    sql('update public.vinculos_usuarios set ativo=false where id_usuario=' + q(admin_id) + ' and id_organizacao=' + q(f['org_a']) + ';')
    status, data = rpc('executar_comando_lista_v1', last, admin)
    check('replay denied after membership revocation', status == 403, status, data)
    status, data = request('/auth/v1/logout', master, method='POST')
    check('real Auth MASTER logout', status in [200, 204], status, data)
    get(lista, token=master, expected=403, name='same JWT denied after logout')
    consistency = json.loads(sql("select json_build_object('commands',(select count(*) from public.comandos_idempotentes where id_organizacao in (%s,%s) and comando like 'crud-lista-v1:%%'),'events',(select count(*) from public.eventos_auditoria where id_organizacao in (%s,%s) and evento='ListaOperacionalAlterada'));" % (q(f['org_a']), q(f['org_b']), q(f['org_a']), q(f['org_b'])), True))
    check('one audit event per completed checklist command', consistency['commands'] == consistency['events'])
    report['effects'] = consistency; save('report.json', report)

def quarantine(f):
    ids = ','.join(q(u['id']) for u in f['users'])
    orgs = ','.join(q(f[k]) for k in ['org_a', 'org_b'])
    sql("begin; update auth.users set banned_until=now()+interval '100 years' where id in (%s); delete from auth.sessions where user_id in (%s); update privado.administradores_master set ativo=false where id_usuario in (%s); update public.vinculos_usuario_contratos set ativo=false where id_vinculo_usuario in (select id from public.vinculos_usuarios where id_usuario in (%s)); update public.vinculos_usuarios set ativo=false where id_usuario in (%s); update public.listas_verificacao set situacao='inativa' where id_organizacao in (%s); update public.organizacoes set situacao='inativa' where id in (%s); commit;" % (ids, ids, ids, ids, ids, orgs, orgs))
    counts = json.loads(sql("select json_build_object('sessions',(select count(*) from auth.sessions where user_id in (%s)),'memberships',(select count(*) from public.vinculos_usuarios where ativo and id_usuario in (%s)),'master',(select count(*) from privado.administradores_master where ativo and id_usuario in (%s)),'contract_scopes',(select count(*) from public.vinculos_usuario_contratos s join public.vinculos_usuarios v on v.id=s.id_vinculo_usuario where s.ativo and v.id_usuario in (%s)),'banned',(select count(*) from auth.users where id in (%s) and banned_until>now()),'inactive_orgs',(select count(*) from public.organizacoes where id in (%s) and situacao='inativa'),'active_lists',(select count(*) from public.listas_verificacao where id_organizacao in (%s) and situacao<>'inativa'));" % (ids, ids, ids, ids, ids, orgs, orgs), True))
    report['quarantine'] = counts
    check('quarantine verified', counts == {'sessions': 0, 'memberships': 0, 'master': 0, 'contract_scopes': 0, 'banned': 5, 'inactive_orgs': 2, 'active_lists': 0})

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
            cleaned = report.get('quarantine') == {'sessions': 0, 'memberships': 0, 'master': 0, 'contract_scopes': 0, 'banned': 5, 'inactive_orgs': 2, 'active_lists': 0}
        except Exception:
            check('quarantine verified', False)
    save('report.json', report)
    for name in ['tokens.json'] + (['fixture.json'] if cleaned else []):
        (ROOT / name).unlink(missing_ok=True)
failed = sum(not x['pass'] for x in report['assertions'])
print(json.dumps({'failures': [x for x in report['assertions'] if not x['pass']], 'quarantine': report.get('quarantine'), 'failure_class': report.get('failure_class'), 'assertions': len(report['assertions']), 'failed': failed, 'real_auth': True, 'report_sha256': hashlib.sha256((ROOT / 'report.json').read_bytes()).hexdigest()}))
sys.exit(1 if failed else 0)

