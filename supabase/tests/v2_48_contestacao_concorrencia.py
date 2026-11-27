"""Prova concorrente com duas conexões ao PostgreSQL descartável do CI."""

import json
import os
from queue import Queue
import subprocess
from threading import Thread
import time

if os.environ.get("PGHOST") != "127.0.0.1" or os.environ.get("PGDATABASE") != "contaos_v248_fixture":
    raise SystemExit("Exigido PostgreSQL descartável V2 48")

PSQL = ["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1"]
SESSAO = """
set local role authenticated;
set local "contaos.fixture.ator"='47000000-0000-4000-8000-000000000001';
"""

def consultar(sql):
    return subprocess.check_output([*PSQL, "-c", sql], text=True, timeout=8).strip()

def executar_em_concorrencia(sql):
    environments = [
        dict(os.environ, PGAPPNAME="v248-race-owner"),
        dict(os.environ, PGAPPNAME="v248-race-contender"),
    ]
    primeiro = subprocess.Popen(PSQL, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, env=environments[0], text=True)
    segundo = None
    saida = Queue()

    def resultado_inicial():
        saida.put(primeiro.stdout.readline().strip())

    try:
        Thread(target=resultado_inicial, daemon=True).start()
        primeiro.stdin.write(f"begin;\n{sql};\n")
        primeiro.stdin.flush()
        vencedor = json.loads(saida.get(timeout=8))
        segundo = subprocess.Popen([*PSQL, "-c", f"begin;\n{sql};\ncommit;"],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    env=environments[1], text=True)
        deadline = time.monotonic() + 6
        while consultar("""select exists(select 1 from pg_stat_activity
          where application_name='v248-race-contender' and wait_event_type='Lock');""") != "t":
            if time.monotonic() >= deadline or segundo.poll() is not None:
                raise AssertionError("A segunda transação deveria aguardar a primeira")
            time.sleep(0.1)
        _, primeira_falha = primeiro.communicate("commit;\n", timeout=8)
        resposta, segunda_falha = segundo.communicate(timeout=8)
        if primeiro.returncode or segundo.returncode:
            raise AssertionError(f"{primeira_falha}\n{segunda_falha}")
        assert vencedor == json.loads(resposta), "As transações precisam devolver o mesmo recibo"
        return vencedor
    finally:
        for processo in (segundo, primeiro):
            if processo is not None and processo.poll() is None:
                processo.kill()
                processo.wait(timeout=8)

submissao = executar_em_concorrencia(SESSAO + """
  select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido material','Fonte oficial',
    fixture.mapa48(),'v248-race-submeter')
""")
assert consultar("select count(*) from public.contestacoes") == "1"
assert consultar("select count(*) from public.mapas_evidencias_contestacao") == "1"
assert consultar("""select count(*) from public.eventos_auditoria
  where evento='ContestacaoSubmetida'""") == "1"

revisao = executar_em_concorrencia(SESSAO.replace("000000000001", "000000000008") + f"""
  select public.revisar_contestacao_v2('{submissao["id_contestacao"]}',1,true,
    'Documento e página conferidos','v248-race-revisar')
""")
assert revisao["status_aprovacao"] == "aprovada"
assert consultar("""select count(*) from public.eventos_auditoria where evento='ContestacaoRevisada'""") == "1"
assert consultar("select status from public.apontamentos_contratante where id=fixture.id(201)") == "contestado_aprovado"
print("V2_48_CONCORRENCIA_CODE_PASS")
