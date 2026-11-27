"""Prova concorrente com duas conexões ao PostgreSQL descartável do CI."""

import json
import os
from queue import Queue
import subprocess
from threading import Thread
import time

if os.environ.get("PGHOST") != "127.0.0.1" or os.environ.get("PGDATABASE") != "contaos_v247_fixture":
    raise SystemExit("Exigido PostgreSQL descartável V2 47")

PSQL = ["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1"]
SESSAO = """
set local role authenticated;
set local "contaos.fixture.ator"='47000000-0000-4000-8000-000000000001';
"""

def consultar(sql):
    return subprocess.check_output([*PSQL, "-c", sql], text=True, timeout=8).strip()

def executar_em_concorrencia(sql):
    environments = [
        dict(os.environ, PGAPPNAME="v247-race-owner"),
        dict(os.environ, PGAPPNAME="v247-race-contender"),
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
          where application_name='v247-race-contender' and wait_event_type='Lock');""") != "t":
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

criacao = executar_em_concorrencia(SESSAO + """
  select public.salvar_tarefa_diligencia_v2(fixture.id(101),fixture.id(201),null,null,
    jsonb_build_object('descricao','Prova concorrente','responsavel',fixture.id(2),'prazo','2026-12-05',
      'tipo_acao','corrigir_documento','prioridade','alta'),'v247-race-criar')
""")
assert consultar("""select count(*) from public.eventos_auditoria
  where evento='TarefaDiligenciaCriada'""") == "1"
envio = json.loads(consultar("begin;" + SESSAO + f"""
  select public.submeter_solucao_tarefa_diligencia_v2('{criacao["id_tarefa"]}',fixture.id(401),1,'v247-race-enviar');
  commit;
"""))
consultar(f"update public.execucoes_assincronas set status='processando' where id='{envio['id_execucao']}'")
executar_em_concorrencia(f"""
  set local role service_role;
  select public.registrar_revalidacao_tarefa_diligencia_v2('{envio["id_execucao"]}',
    '{criacao["id_tarefa"]}',fixture.id(201),fixture.id(401),'procedente','Prova concorrente',0.9,true)
""")
assert consultar("select count(*) from public.analises_apontamentos") == "1"
assert consultar("""select count(*) from public.eventos_auditoria
  where evento='TarefaDiligenciaRevalidada'""") == "1"
print("V2_47_CONCORRENCIA_CODE_PASS")
