"""Execute the versioned RPC in an isolated PostgreSQL fixture, never HML."""
import concurrent.futures
import os
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parent
migrations = root.parent / 'migrations'
original = migrations / '20261101214949_0030_fechamento_funcional_v1_v2.sql'
guard = migrations / '20261102174252_v105_confiar_mutacao_interna_escopo.sql'
migration = migrations / '20261127233223_p0_v2_77_desfechos_linha_tempo.sql'
assert os.environ['PGDATABASE'] == 'contaos_v277_fixture'
assert os.environ['PGHOST'] == '127.0.0.1'

def sql(*args):
    proc=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1',*args],text=True,capture_output=True)
    if proc.returncode:
        print(proc.stdout,proc.stderr,flush=True)
        proc.check_returncode()
    return proc.stdout

def func(path,schema,name):
    match=re.search(r'create (?:or replace )?function '+schema+r'\.'+name+r'\([\s\S]+?\$\$;',path.read_text(),re.I)
    assert match, (path,name)
    return match[0]

sql('-f',str(root/'v2_77_desfecho_fixture.sql'))
sql('-c',func(original,'privado','registrar_desfecho_contestacao'))
sql('-c',func(original,'public','registrar_desfecho_contestacao'))
sql('-c',func(guard,'privado','bloquear_mutacao_fora_escopo_contrato'))
for table in ['contestacoes','desfechos_apontamentos','apontamentos_contratante']:
    sql('-c',f'create trigger trg_scope_contrato before insert or update or delete on public.{table} for each row execute function privado.bloquear_mutacao_fora_escopo_contrato()')
sql('-c',"""revoke all on function public.registrar_desfecho_contestacao(uuid,text,text),privado.registrar_desfecho_contestacao(uuid,text,text) from public,anon;
grant execute on function public.registrar_desfecho_contestacao(uuid,text,text),privado.registrar_desfecho_contestacao(uuid,text,text) to authenticated;""")
md5=sql('-c',"select md5(prosrc) from pg_proc where oid='privado.registrar_desfecho_contestacao(uuid,text,text)'::regprocedure").strip()
assert md5=='24d277d1b1ec4e557e3f41ec01c25bc5', ('baseline diverge do HML',md5)
guard_md5=sql('-c',"select md5(prosrc) from pg_proc where oid='privado.bloquear_mutacao_fora_escopo_contrato()'::regprocedure").strip()
assert guard_md5=='b04d372fec8622e68dbcfe14db1bca6e', ('guard diverge do HML',guard_md5)
print('V2_77_BASELINE_HML_MATCH',md5,guard_md5,flush=True)
if migration.is_file():
    sql('-f',str(migration))
    print('V2_77_MIGRATION_APPLIED_FIXTURE',flush=True)
out=sql('-f',str(root/'v2_77_desfecho.test.sql'))
print(out,flush=True)
cases=[line for line in out.splitlines() if line.startswith('V2_77_CASO|')]
assert len(cases)==25, ('inventário incompleto',len(cases))
failures=[line for line in cases if line.endswith('|FAIL')]
if failures:
    if not migration.is_file():
        observed=dict(line.split('|',2)[1:] for line in out.splitlines() if line.startswith('V2_77_OBSERVADO|'))
        assert observed['contrato_B'].startswith('OK:') and observed['rascunho'].startswith('OK:'), observed
        assert observed['final'].startswith('OK:') and observed['replay_final'].startswith('OK:') and observed['final']!=observed['replay_final'], observed
        print('V2_77_RED_CAUSAL: '+str(len(failures))+' casos falharam; mutacao cruzada, rascunho e duplicacao confirmados',flush=True)
    else:
        print('V2_77_GREEN_FAIL: '+str(len(failures))+' casos falharam',flush=True)
    raise SystemExit(1)
assert migration.is_file(), 'baseline inesperadamente passou'
def registrar(_):
    return sql('-c',"""set role authenticated;
select set_config('fixture.actor',fixture_id(8)::text,false);
select fixture_tentar(408,'aceita','Concorrente');""").splitlines()[-1]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    replies=list(pool.map(registrar,range(2)))
assert replies[0].startswith('OK:') and replies[0]==replies[1], replies
assert sql('-c',"select count(*) from public.desfechos_apontamentos where id_apontamento=fixture_id(308)").strip()=='1'
assert sql('-c',"select count(*) from public.eventos_auditoria where id_entidade=fixture_id(408)").strip()=='1'
assert sql('-c',"select count(*) from public.execucoes_assincronas where payload->>'id_desfecho'='"+replies[0][3:]+"'").strip()=='2'
print('V2_77_CONCORRENCIA_PASS: um desfecho, uma auditoria e duas execuções previstas')
print('V2_77_GREEN: escopo, aprovação, idempotência, linhagem, confiança e auditoria')
