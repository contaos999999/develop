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
select teste,passou,detalhe from contaos_queue_tests order by teste;
rollback;

-- 2. Os oito processadores oficiais devem responder HTTP 200 quando chamados com token interno.
-- Execute o bloco abaixo pelo SQL Editor. Os request_id aparecem imediatamente; depois consulte net._http_response.
with s(slug) as (values
 ('queue-worker-documents'),('queue-worker-ocr'),('queue-worker-ai'),('queue-worker-embeddings'),
 ('queue-worker-finance'),('generate-report'),('deliver-webhook'),('notify-user')
)
select slug,net.http_post(
  url := (select decrypted_secret from vault.decrypted_secrets where name='contaos_project_url') || '/functions/v1/' || slug,
  headers := jsonb_build_object(
    'Content-Type','application/json',
    'x-contaos-internal-token',(select decrypted_secret from vault.decrypted_secrets where name='contaos_internal_worker_token')
  ),
  body := jsonb_build_object('max_jobs',1),
  timeout_milliseconds := 15000
) as request_id from s;

-- 3. Negative auth: resultado esperado = HTTP 401 nos dois casos.
select 'process-document_sem_jwt' as teste,net.http_post(
  url := (select decrypted_secret from vault.decrypted_secrets where name='contaos_project_url') || '/functions/v1/process-document',
  headers := jsonb_build_object('Content-Type','application/json'),body := '{}'::jsonb,timeout_milliseconds := 10000
) as request_id
union all
select 'queue-worker-ai_sem_token',net.http_post(
  url := (select decrypted_secret from vault.decrypted_secrets where name='contaos_project_url') || '/functions/v1/queue-worker-ai',
  headers := jsonb_build_object('Content-Type','application/json'),body := '{}'::jsonb,timeout_milliseconds := 10000
);
