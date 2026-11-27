import concurrent.futures
import os
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parent
migration = root.parent / "migrations" / "20261127160826_p0_v2_49_reapresentacao_escopo.sql"
legacy = root.parent / "migrations" / "20261102021238_0048_gate_context_hash_checks.sql"
wrappers = root.parent / "migrations" / "20261101211533_0016_rpc_privadas_wrappers.sql"
assert os.environ["PGDATABASE"] == "contaos_v249_fixture"


def sql(*args, **kwargs):
    return subprocess.run(["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1", *args], **kwargs)


def extract(path, schema):
    return re.search(
        r"create (?:or replace )?function " + schema + r"\.registrar_reapresentacao\([\s\S]+?\$\$;",
        path.read_text(),
    )[0]


sql("-f", str(root / "v2_49_reapresentacao_fixture.sql"), check=True)
sql("-c", extract(legacy, "privado"), check=True)
sql("-c", extract(wrappers, "public"), check=True)
if migration.is_file():
    sql("-f", str(migration), check=True)
sql("-f", str(root / "v2_49_reapresentacao.test.sql"), check=True)


def solicitar():
    statement = """select set_config('fixture.actor',fixture_id(8)::text,false);
select public.registrar_reapresentacao(fixture_id(26),'corrida','P-26','eletronica',fixture_id(40));"""
    return sql("-c", statement, capture_output=True, text=True, check=True).stdout.splitlines()[-1]


with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    respostas = list(pool.map(lambda _: solicitar(), range(2)))
assert respostas[0] == respostas[1] and respostas[0], respostas
contagem = sql(
    "-c", "select count(*) from public.pacotes_reapresentacao where id_ciclo=fixture_id(26)",
    check=True, capture_output=True, text=True,
).stdout.strip()
assert contagem == "1", contagem
print("V2_49_CONCORRENCIA_PASS: um pacote e o mesmo recibo")
