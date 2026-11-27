import concurrent.futures
import os
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parent
migration = root.parent / 'migrations' / '20261127211427_p0_v2_76_parecer_apresentacao.sql'
original = root.parent / 'migrations' / '20261101211140_0010_diligencias_v2.sql'
wrappers = root.parent / 'migrations' / '20261101211533_0016_rpc_privadas_wrappers.sql'
assert os.environ['PGDATABASE'] == 'contaos_v276_fixture'


def sql(*args, **kwargs):
    return subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', *args], **kwargs)


def function(path, schema):
    pattern = r'create (?:or replace )?function ' + schema + r'\.registrar_parecer_contratante\([\s\S]+?\$\$;'
    return re.search(pattern, path.read_text())[0]


sql('-f', str(root / 'v2_76_parecer_fixture.sql'), check=True)
sql('-c', function(original, 'public').replace('function public.', 'function privado.', 1), check=True)
sql('-c', function(wrappers, 'public'), check=True)
if migration.is_file():
    sql('-f', str(migration), check=True)
sql('-f', str(root / 'v2_76_parecer.test.sql'), check=True)


def solicitar():
    cmd = """select set_config('fixture.actor',fixture_id(8)::text,false);
select public.registrar_parecer_contratante(fixture_id(24),fixture_id(124),fixture_id(40),
 'Diligência',false,'CONCORRENTE',date '2026-11-25',date '2026-12-04');"""
    return sql('-c', cmd, text=True, capture_output=True, check=True).stdout.splitlines()[-1]


with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    respostas = list(pool.map(lambda _: solicitar(), range(2)))
assert respostas[0] and respostas[0] == respostas[1], respostas
cmd = """select count(*) from public.pareceres_contratante p
join public.execucoes_assincronas e on e.entidade_id=p.id
where p.id_competencia=fixture_id(24) and e.entidade_tipo='extrair_diligencia'"""
assert sql('-c', cmd, text=True, capture_output=True, check=True).stdout.strip() == '1'
print('V2_76_CONCORRENCIA_PASS: um parecer, um ciclo e uma execução')
