#!/usr/bin/env bash
set -euo pipefail

DB_URL="${DB_URL:?DB_URL obrigatório}"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
insert into auth.users(id,aud,role,email,created_at,updated_at)
values('d7171717-0000-4000-8000-000000000001','authenticated','authenticated','v107-concurrency@contaos.invalid',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('d7171717-0000-4000-9000-000000000001','d7171717-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour');
insert into public.organizacoes(id,razao_social) values('d7171717-aaaa-4000-8000-000000000001','V107 concorrência');
insert into public.contratantes(id,id_organizacao,razao_social) values('d7171717-1000-4000-8000-000000000001','d7171717-aaaa-4000-8000-000000000001','V107 concorrência');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio)
values('d7171717-2000-4000-8000-000000000001','d7171717-aaaa-4000-8000-000000000001','d7171717-1000-4000-8000-000000000001','V107-CONC','Teste concorrente','2026-01-01');
insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
values('d7171717-3000-4000-8000-000000000001','d7171717-aaaa-4000-8000-000000000001','d7171717-0000-4000-8000-000000000001','administrador',true,true);
insert into public.fontes_normativas(id,id_organizacao,id_contrato,tipo,titulo,situacao)
values('d7171717-4000-4000-8000-000000000001','d7171717-aaaa-4000-8000-000000000001','d7171717-2000-4000-8000-000000000001','lei','Antes','rascunho');
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao)
values('d7171717-5000-4000-8000-000000000001','d7171717-aaaa-4000-8000-000000000001','d7171717-2000-4000-8000-000000000001','2026-01-01','2026-01-01','2026-01-31','em_analise');
SQL

psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL' > /tmp/v107-lock.log &
begin;
select id from public.competencias where id='d7171717-5000-4000-8000-000000000001' for update;
select pg_sleep(3);
commit;
SQL
LOCK_PID=$!

sleep 0.5
START_NS=$(date +%s%N)
psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL' > /tmp/v107-mutation.log
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','d7171717-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"d7171717-0000-4000-8000-000000000001","role":"authenticated","session_id":"d7171717-0000-4000-9000-000000000001"}',true);
select public.salvar_fonte_normativa_v107(
  'd7171717-aaaa-4000-8000-000000000001','d7171717-2000-4000-8000-000000000001',
  'd7171717-4000-4000-8000-000000000001','lei','Depois',null,null,'rascunho',1,'concorrencia-1'
);
commit;
SQL
END_NS=$(date +%s%N)
wait "$LOCK_PID"

ELAPSED_MS=$(( (END_NS - START_NS) / 1000000 ))
if (( ELAPSED_MS < 2000 )); then
  echo "FAIL: mutação não aguardou o lock da competência (${ELAPSED_MS}ms)."
  exit 1
fi

STATE=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc \
  "select titulo||':'||versao_registro from public.fontes_normativas where id='d7171717-4000-4000-8000-000000000001'")
if [[ "$STATE" != "Depois:2" ]]; then
  echo "FAIL: estado final inesperado: $STATE"
  exit 1
fi

echo "PASS: mutação aguardou ${ELAPSED_MS}ms e finalizou em Depois:2."

