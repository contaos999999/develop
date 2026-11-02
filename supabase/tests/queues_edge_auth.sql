-- ContaOS HML - filas, DLQ e autenticação de Edge Functions
-- Executar exclusivamente no HML.

-- 1. Teste SQL de idempotência e DLQ. Todo dado é revertido.
begin;
create temporary table contaos_queue_tests(teste text primary key,passou boolean,detalhe text) on commit drop;
insert into public.organizacoes(id,razao_social) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Organização Queue Teste');

create temporary table ids_job as
select privado.enfileirar_job(
  'documents','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',null,'teste_queue',
  'eeeeeeee-0000-4000-8000-000000000001',jsonb_build_object('teste',true),'teste-idempotencia'
) as id1;
alter table ids_job add column id2 uuid;
update ids_job set id2=privado.enfileirar_job(
  'documents','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',null,'teste_queue',
  'eeeeeeee-0000-4000-8000-000000000001',jsonb_build_object('teste',true),'teste-idempotencia'
);
insert into contaos_queue_tests
select 'idempotencia_mesma_chave',id1=id2,'id1='||id1||'; id2='||id2 from ids_job;

update public.execucoes_assincronas
set tentativas=5,metadados=jsonb_build_object('payload',jsonb_build_object('teste',true))
where id=(select id1 from ids_job);

select public.worker_finalizar_job(
  'documents',
  (select message_id from public.execucoes_assincronas where id=(select id1 from ids_job)),
  false,'TESTE_FALHA','Falha sintética de homologação',5
);
insert into contaos_queue_tests
select 'limite_move_para_dlq',
       exists(select 1 from public.jobs_dlq d where d.id_execucao=(select id1 from ids_job) and d.erro_codigo='TESTE_FALHA')
       and exists(select 1 from public.execucoes_assincronas e where e.id=(select id1 from ids_job) and e.status='cancelado'),
       'dlq='||(select count(*) from public.jobs_dlq d where d.id_execucao=(select id1 from ids_job))::text;
insert into contaos_queue_tests values('pg_net_removida_conforme_hardening',not exists(select 1 from pg_extension where extname='pg_net'),'Edge auth é validada por testes HTTP externos; o banco não dispara HTTP.');
select teste,passou,detalhe from contaos_queue_tests order by teste;
rollback;

-- Edge auth é validada nos testes HTTP externos do ambiente; não há chamada de rede nesta regressão SQL.\n