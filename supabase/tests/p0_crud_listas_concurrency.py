"""Isolated PostgreSQL only. Simulated SQL claims, never real JWT evidence."""
import json
import os
import re
import subprocess
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlsplit

DB = os.environ['DB_URL']
assert urlsplit(DB).hostname in ('127.0.0.1', 'localhost'), 'Isolated database only'
env = dict(os.environ, PGOPTIONS='-c statement_timeout=20000')
uid = lambda: str(uuid.uuid4())
q = lambda v: "'" + str(v).replace("'", "''") + "'"
actor, session, org, contractor, contract = [uid() for _ in range(5)]
claims = json.dumps({'sub': actor, 'role': 'authenticated', 'session_id': session, 'aal': 'aal1'})
prefix = 'begin; set local role authenticated; set local "request.jwt.claim.sub"=' + q(actor) + '; set local "request.jwt.claims"=' + q(claims) + ';'

def sql(source, app=None):
    e = dict(env)
    if app:
        e['PGAPPNAME'] = app
    p = subprocess.run(['psql', DB, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=sqlstate'], input=source, capture_output=True, text=True, env=e, timeout=30)
    if p.returncode:
        m = re.search(r'ERROR:\s+([0-9A-Z]{5})', p.stderr)
        return {'code': m[1] if m else 'UNKNOWN', 'detail': p.stderr[-500:]}
    return {'code': 'OK', 'text': p.stdout.strip()}

def checked(source):
    r = sql(source)
    assert r['code'] == 'OK', r
    return r['text']

def api(name, args, app=None):
    values = ','.join('null' if v is None else q(json.dumps(v)) + '::jsonb' if isinstance(v, dict) else str(v) if isinstance(v, int) else q(v) for v in args)
    r = sql(prefix + 'select public.' + name + '(' + values + '); commit;', app)
    if r['code'] == 'OK':
        r['data'] = json.loads(r['text'])
    return r

def command(lista, version, action, payload, key=None, app=None):
    return api('executar_comando_lista_v1', [org, contract, lista, version, action, payload, 'Isolated concurrency verification', key or uid()], app)

def current(lista):
    r = api('obter_lista_operacional_v1', [org, contract, lista, None, 0, 0])
    assert r['code'] == 'OK', r
    return r['data']

def spawn(app):
    return subprocess.Popen(['psql', DB, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=sqlstate'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1, env=dict(env, PGAPPNAME=app))

def marker(process, expected):
    while True:
        line = process.stdout.readline()
        if line.strip() == expected:
            return
        if line == '':
            raise AssertionError('Local concurrency session exited before marker: ' + process.stderr.read()[-500:])

processes = []
seeded = False
cases = []
try:
    checked("begin; insert into auth.users(id,aud,role,email,created_at,updated_at) values(%s,'authenticated','authenticated',%s,now(),now()); insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values(%s,%s,now(),now(),'aal1',now()+interval '1 hour'); insert into public.organizacoes(id,razao_social) values(%s,'P0 isolated checklist concurrency'); insert into public.contratantes(id,id_organizacao,razao_social) values(%s,%s,'P0 isolated contractor'); insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values(%s,%s,%s,%s,'P0 isolated checklist','2026-01-01'); insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values(%s,%s,'administrador',true); commit;" % (q(actor), q('p0lista-local-' + actor + '@example.invalid'), q(session), q(actor), q(org), q(contractor), q(org), q(contract), q(org), q(contractor), q('P0-LISTA-' + contract), q(org), q(actor)))
    seeded = True
    created = command(None, None, 'criar_lista', {'nome': 'Lista concorrente', 'vigencia_inicio': '2026-01-01'})
    assert created['code'] == 'OK', created
    lista, versao = created['data']['lista']['id'], created['data']['id_versao']
    version = created['data']['lista']['versao_registro']
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = list(pool.map(lambda n: command(lista, version, 'editar_lista', {'nome': 'Concurrent ' + str(n)}), [1, 2]))
    assert sorted(x['code'] for x in outcomes) == ['OK', 'PT409'], outcomes
    cases.append('two writers: exactly one success and one stale conflict')
    latest = current(lista)
    assert latest['lista']['versao_registro'] == version + 1
    version = latest['lista']['versao_registro']
    key = uid()
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = list(pool.map(lambda _: command(lista, version, 'editar_lista', {'descricao': 'Exact replay race'}, key), [1, 2]))
    assert all(x['code'] == 'OK' for x in outcomes) and outcomes[0]['data'] == outcomes[1]['data'], outcomes
    counts = json.loads(checked("select json_build_object('commands',(select count(*) from public.comandos_idempotentes where id_organizacao=%s and chave=%s),'events',(select count(*) from public.eventos_auditoria where id_organizacao=%s and evento='ListaOperacionalAlterada' and metadados->>'request_id'=%s));" % (q(org), q(key), q(org), q(key))))
    assert counts == {'commands': 1, 'events': 1}, counts
    cases.append('duplicate concurrent command: one audit and identical receipt')
    version = current(lista)['lista']['versao_registro']
    added = command(lista, version, 'salvar_item', {'id_versao': versao, 'codigo': 'P0-RACE', 'descricao': 'Informational snapshot race', 'obrigatorio': False})
    assert added['code'] == 'OK', added
    published = command(lista, added['data']['lista']['versao_registro'], 'publicar_versao', {'id_versao': versao})
    assert published['code'] == 'OK', published
    version = published['data']['lista']['versao_registro']

    # Controller holds a release barrier. Snapshot connection cannot commit until
    # the closing connection is observed waiting on the contract lock.
    barrier = int(uuid.uuid4().hex[:14], 16)
    controller = spawn('p0lista-controller')
    processes.append(controller)
    controller.stdin.write('select pg_advisory_lock(' + str(barrier) + "); select 'CONTROLLER_READY';\n")
    controller.stdin.flush()
    marker(controller, 'CONTROLLER_READY')
    creator = spawn('p0lista-snapshot')
    processes.append(creator)
    creator.stdin.write(prefix + 'select public.criar_competencia(' + q(contract) + ",'2026-02-01'); select 'SNAPSHOT_READY'; select pg_advisory_xact_lock(" + str(barrier) + '); commit;\n')
    creator.stdin.close()
    marker(creator, 'SNAPSHOT_READY')
    close_app = 'p0lista-close-' + uuid.uuid4().hex[:12]
    with ThreadPoolExecutor(max_workers=1) as pool:
        closing = pool.submit(command, lista, version, 'encerrar_vigencia', {'id_versao': versao, 'vigencia_fim': '2026-01-31'}, None, close_app)
        waiting = False
        try:
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                waiting = checked("select exists(select 1 from pg_stat_activity where application_name=%s and wait_event_type='Lock');" % q(close_app)) == 't'
                if waiting or closing.done():
                    break
                time.sleep(0.05)
            assert waiting, 'Closing must wait for the uncommitted checklist snapshot'
        finally:
            controller.stdin.write('select pg_advisory_unlock(' + str(barrier) + "); select 'RELEASED';\n")
            controller.stdin.flush()
            marker(controller, 'RELEASED')
        closed = closing.result(timeout=25)
    creator.wait(timeout=25)
    assert creator.returncode == 0, creator.stderr.read()[-500:]
    assert closed['code'] == 'PT422', closed
    assert checked('select vigencia_fim is null from public.versoes_lista where id=' + q(versao)) == 't'
    assert checked("select count(*) from public.requisitos_competencia r join public.competencias c on c.id=r.id_competencia where c.id_contrato=%s and c.competencia_referencia='2026-02-01' and r.codigo='P0-RACE';" % q(contract)) == '1'
    cases.append('closing waits for snapshot and rejects truncating its preserved period')
    closed = command(lista, version, 'encerrar_vigencia', {'id_versao': versao, 'vigencia_fim': '2026-02-28'})
    assert closed['code'] == 'OK', closed
    # The opposite serial order excludes the already expired version.
    created = checked(prefix + 'select public.criar_competencia(' + q(contract) + ",'2026-03-01'); commit;")
    assert checked("select count(*) from public.requisitos_competencia where id_competencia=%s and codigo='P0-RACE';" % q(created)) == '0'
    cases.append('snapshot after closure does not copy expired items')
finally:
    for process in processes:
        if process.poll() is None:
            if process.stdin and not process.stdin.closed:
                try:
                    process.stdin.write('select pg_advisory_unlock_all();\n\\q\n')
                    process.stdin.flush()
                except (BrokenPipeError, ValueError):
                    pass
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait(timeout=5)
    if seeded:
        checked("begin; update auth.users set banned_until=now()+interval '100 years' where id=%s; delete from auth.sessions where user_id=%s; update public.vinculos_usuarios set ativo=false where id_usuario=%s; update public.organizacoes set situacao='inativa' where id=%s; commit;" % (q(actor), q(actor), q(actor), q(org)))
        assert checked('select count(*) from auth.sessions where user_id=' + q(actor)) == '0'
print(json.dumps({'mode': 'SQL_CLAIMS_LOCAL_CONCURRENCY', 'cases': cases, 'passed': len(cases), 'local_only': True, 'sessions_after_cleanup': 0}))
print('CRUD_LISTAS_CONCURRENCY_PASS')
