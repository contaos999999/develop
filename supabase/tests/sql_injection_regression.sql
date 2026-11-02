-- ContaOS HML 4.1 - regressão defensiva contra SQL Injection e variantes
-- Valida que entradas com sintaxe aparente de SQL permanecem dados, nunca comandos.
-- Dados sintéticos; a transação termina em ROLLBACK.

begin;

create temporary table sql_injection_test(
  chave text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select,insert on sql_injection_test to authenticated, service_role;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values(
  '75111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'sql.inject@contaos.invalid',
  '{}','{}',now(),now()
);

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values(
  '75aaaaaa-1111-4111-8111-111111111111',
  '75111111-1111-4111-8111-111111111111',
  now(),now(),'aal1',now()+interval '1 hour'
);

create or replace function pg_temp.testar_criacao_org(p_chave text,p_payload text,p_limite_ms numeric default null)
returns void
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_org uuid;
  v_inicio timestamptz := clock_timestamp();
  v_ms numeric;
  v_armazenado text;
begin
  begin
    v_org := public.criar_organizacao(p_payload,null,null,'America/Sao_Paulo');
  exception when others then
    insert into pg_temp.sql_injection_test(chave,passou,detalhe)
    values(p_chave,false,'Falha inesperada: '||sqlstate||':'||sqlerrm);
    return;
  end;

  v_ms := extract(epoch from (clock_timestamp()-v_inicio))*1000;
  select razao_social into v_armazenado from public.organizacoes where id=v_org;

  insert into pg_temp.sql_injection_test(chave,passou,detalhe)
  values(
    p_chave,
    v_armazenado = p_payload and (p_limite_ms is null or v_ms < p_limite_ms),
    format('armazenado_exato=%s; duracao_ms=%s',v_armazenado = p_payload,round(v_ms,2))
  );
end;
$$;
grant execute on function pg_temp.testar_criacao_org(text,text,numeric) to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','75111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"75111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"75aaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',
  true
);

select pg_temp.testar_criacao_org(
  'union_based_tratada_como_dado',
  $payload$Empresa teste ' UNION SELECT current_user --$payload$,
  null
);

select pg_temp.testar_criacao_org(
  'blind_boolean_tratada_como_dado',
  $payload$Empresa teste ' OR '1'='1' --$payload$,
  null
);

select pg_temp.testar_criacao_org(
  'error_based_tratada_como_dado',
  $payload$Empresa teste '::integer / 0 --$payload$,
  null
);

select pg_temp.testar_criacao_org(
  'time_based_sem_execucao',
  $payload$Empresa teste '; SELECT pg_sleep(5); --$payload$,
  3500
);

reset role;

insert into sql_injection_test(chave,passou,detalhe)
select
  'nenhum_objeto_estrutural_criado',
  to_regclass('public.current_user') is null,
  'Payload UNION/DDL não alterou estrutura do banco.';

select chave,passou,detalhe from sql_injection_test order by chave;
rollback;
