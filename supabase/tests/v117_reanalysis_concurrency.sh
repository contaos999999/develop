#!/usr/bin/env bash
# V1-17: duas conexoes concorrentes em PostgreSQL LOCAL e descartavel do CI.
set -euo pipefail
DB_URL="$DB_URL"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
insert into auth.users(id,aud,role,email,created_at,updated_at)
values('c7171717-0000-4000-8000-000000000001','authenticated','authenticated','v117-concurrency@contaos.invalid',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('c7171717-0000-4000-9000-000000000001','c7171717-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour');
insert into public.organizacoes(id,razao_social)
values('c7171717-aaaa-4000-8000-000000000001','V117 concorrência CI');
insert into public.contratantes(id,id_organizacao,razao_social)
values('c7171717-1000-4000-8000-000000000001','c7171717-aaaa-4000-8000-000000000001','V117 concorrência CI');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio)
values('c7171717-2000-4000-8000-000000000001','c7171717-aaaa-4000-8000-000000000001','c7171717-1000-4000-8000-000000000001','V117-CONC','Teste de dois clientes','2026-01-01');
insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
values('c7171717-3000-4000-8000-000000000001','c7171717-aaaa-4000-8000-000000000001','c7171717-0000-4000-8000-000000000001','administrador',true,true);
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao)
values('c7171717-5000-4000-8000-000000000001','c7171717-aaaa-4000-8000-000000000001','c7171717-2000-4000-8000-000000000001','2026-11-01','2026-11-01','2026-11-30','rascunho');
insert into public.requisitos_competencia(id,id_organizacao,id_contrato,id_competencia,origem_tipo,descricao,hash_snapshot,codigo)
values
('c7171717-6000-4000-8000-000000000001','c7171717-aaaa-4000-8000-000000000001','c7171717-2000-4000-8000-000000000001','c7171717-5000-4000-8000-000000000001','manual','Requisito A','h-a','A'),
('c7171717-6000-4000-8000-000000000002','c7171717-aaaa-4000-8000-000000000001','c7171717-2000-4000-8000-000000000001','c7171717-5000-4000-8000-000000000001','manual','Requisito B','h-b','B');
SQL

# Terceira conexao segura a linha para garantir disputa simultanea.
psql "$DB_URL" -v ON_ERROR_STOP=1 > /tmp/v117-holder.log <<'SQL' &
begin;
select id from public.competencias where id='c7171717-5000-4000-8000-000000000001' for update;
select pg_sleep(3);
commit;
SQL
LOCK_PID=$!
sleep 0.4

concorrente() {
 local name="$1" req="$2"
 psql "$DB_URL" -v ON_ERROR_STOP=1 -At > "/tmp/v117-$name.log" <<SQL
begin;
create function pg_temp.tentar_v117(p_req uuid) returns text language plpgsql
security invoker set search_path=''
as \$fn\$
begin
 return 'OK:' || public.solicitar_reanalise_requisitos(
  'c7171717-5000-4000-8000-000000000001',array[p_req]
 )::text;
exception when others then
 return 'ERR:' || sqlstate;
end;
\$fn\$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c7171717-0000-4000-8000-000000000001","role":"authenticated","session_id":"c7171717-0000-4000-9000-000000000001"}',true);
select pg_temp.tentar_v117('$req');
commit;
SQL
}
concorrente a c7171717-6000-4000-8000-000000000001 &
PID_A=$!
concorrente b c7171717-6000-4000-8000-000000000002 &
PID_B=$!
wait "$PID_A"
wait "$PID_B"
wait "$LOCK_PID"

echo "CLIENTE_A=$(grep -E '^(OK:|ERR:)' /tmp/v117-a.log || true)"
echo "CLIENTE_B=$(grep -E '^(OK:|ERR:)' /tmp/v117-b.log || true)"
SUCCESS_COUNT=$( (grep -Ec '^OK:' /tmp/v117-a.log || true; grep -Ec '^OK:' /tmp/v117-b.log || true) | awk '{s+=$1} END{print s+0}' )
CONFLICT_COUNT=$( (grep -Ec '^ERR:PT409$' /tmp/v117-a.log || true; grep -Ec '^ERR:PT409$' /tmp/v117-b.log || true) | awk '{s+=$1} END{print s+0}' )
if [[ "$SUCCESS_COUNT" != "1" || "$CONFLICT_COUNT" != "1" ]]; then
 echo "FAIL: esperado 1 sucesso e 1 conflito PT409; sucesso=$SUCCESS_COUNT conflito=$CONFLICT_COUNT"
 exit 1
fi

ROW=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -At -F '|' -c \
"select id::text,tipo,cardinality(requisitos_afetados),requisitos_afetados[1]::text
 from public.execucoes_analise where id_competencia='c7171717-5000-4000-8000-000000000001'")
COUNT=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -At -c \
"select count(*) from public.execucoes_analise where id_competencia='c7171717-5000-4000-8000-000000000001'")
IFS='|' read -r JOB_ID JOB_TYPE IDS_COUNT WINNER <<< "$ROW"
if [[ "$COUNT" != "1" || "$JOB_TYPE" != "parcial" || "$IDS_COUNT" != "1" ]]; then
 echo "FAIL: contagem/tipo/escopo incorretos jobs=$COUNT tipo=$JOB_TYPE ids=$IDS_COUNT"
 exit 1
fi
if [[ "$WINNER" != "c7171717-6000-4000-8000-000000000001" && "$WINNER" != "c7171717-6000-4000-8000-000000000002" ]]; then
 echo "FAIL: o escopo foi corrompido: $WINNER"
 exit 1
fi

REPLAY=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -At <<SQL
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c7171717-0000-4000-8000-000000000001","role":"authenticated","session_id":"c7171717-0000-4000-9000-000000000001"}',true);
select public.solicitar_reanalise_requisitos(
 'c7171717-5000-4000-8000-000000000001',array['$WINNER'::uuid]
);
commit;
SQL
)
if ! grep -Fq "$JOB_ID" <<< "$REPLAY"; then
 echo "FAIL: replay idempotente nao retornou o job vencedor."
 exit 1
fi
FINAL_JOBS=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc \
"select count(*) from public.execucoes_analise where id_competencia='c7171717-5000-4000-8000-000000000001'")
if [[ "$FINAL_JOBS" != "1" ]]; then echo "FAIL: duplicacao apos replay."; exit 1; fi
echo "PASS_V117_CONCORRENCIA_REAL: dois clientes; um job parcial; conflito PT409; replay idempotente."
