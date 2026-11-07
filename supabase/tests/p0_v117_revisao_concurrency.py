"""Multiple PostgreSQL connections; isolated fixtures, never real JWT proof."""
import concurrent.futures as cf
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

DB = os.environ['DB_URL']
assert '@127.0.0.1:' in DB or '@localhost:' in DB, 'Isolated PostgreSQL only'

def sql(query):
    p = subprocess.run(['psql', DB, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], input=query, capture_output=True, text=True, timeout=50)
    if p.returncode:
        raise RuntimeError(p.stderr)
    return p.stdout.strip()

fixture = Path(__file__).with_name('p0_v117_revisao.sql').read_text().split('create function pg_temp.rev')[0]
sql(fixture + '\ncommit;')
C = 'baca0000-7000-4000-8000-000000000001'
R = 'baca0000-7100-4000-8000-000000000001'
U = 'baca0000-0000-4000-8000-000000000001'
claims = json.dumps({'sub': U, 'role': 'authenticated', 'session_id': 'baca0000-0000-4000-9000-000000000001'})
auth = "set local role authenticated; select set_config('request.jwt.claims','" + claims + "',true);"

def context():
    return json.loads(sql("begin;" + auth + f"select public.obter_contexto_revisao_v117('{C}','{R}');commit;").splitlines()[-1])

def call(ctx, key):
    expected = 'null' if ctx['id_resultado_esperado'] is None else "'" + ctx['id_resultado_esperado'] + "'"
    query = f"select public.registrar_revisao_requisito_v117('{C}','{R}','{ctx['id_execucao_esperada']}',{expected},'{ctx['hash_esperado']}','conforme','Concorrência isolada','Fundamento','[]','{key}');"
    try:
        return ('ok', json.loads(sql('begin;' + auth + query + 'commit;').splitlines()[-1]))
    except RuntimeError as e:
        return ('error', str(e))

with cf.ThreadPoolExecutor(max_workers=3) as pool:
    ctx = context()
    results = list(pool.map(lambda k: call(ctx, k), [str(uuid.uuid4()), str(uuid.uuid4())]))
    assert sum(x[0] == 'ok' for x in results) == 1, results
    assert any(x[0] == 'error' and 'alterad' in x[1].lower() for x in results), results
    ctx = context()
    key = str(uuid.uuid4())
    results = list(pool.map(lambda _: call(ctx, key), range(2)))
    assert all(x[0] == 'ok' for x in results) and results[0][1] == results[1][1], results
    assert sql(f"select count(*) from public.resultados_requisitos where id_competencia='{C}'") == '4'
    # Explicit holder makes the writer wait after its initial authorization.
    holder = pool.submit(sql, f"begin;select id from public.competencias where id='{C}' for update;select pg_sleep(3);commit;")
    time.sleep(0.4)
    ctx = context()
    writer = pool.submit(call, ctx, str(uuid.uuid4()))
    time.sleep(0.5)
    sql(f"update public.vinculos_usuarios set ativo=false where id_usuario='{U}';")
    holder.result()
    denied = writer.result()
    assert denied[0] == 'error', denied
    assert sql(f"select count(*) from public.resultados_requisitos where id_competencia='{C}'") == '4'
    sql(f"update public.vinculos_usuarios set ativo=true where id_usuario='{U}';")
    ctx = context()
    sql('begin;' + auth + f"select public.solicitar_reanalise_requisitos('{C}',array['{R}'::uuid]);commit;")
    denied = call(ctx, str(uuid.uuid4()))
    assert denied[0] == 'error', denied
    assert sql(f"select count(*) from public.resultados_requisitos where id_competencia='{C}'") == '4'
print('V117_REVISAO_CONCURRENCY_PASS: CAS/replay/revogacao/reanalise, multiple connections')
