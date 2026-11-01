begin;

create or replace function privado.invocar_contaos_worker(p_fila text,p_max_jobs integer default 3)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_request_id bigint;
begin
  if p_fila not in ('documents','ocr','ai','embeddings','finance_imports','reports','integrations','webhooks') then
    raise exception 'Fila de processamento inválida.';
  end if;
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='contaos_project_url') || '/functions/v1/contaos-worker',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'x-contaos-internal-token',(select decrypted_secret from vault.decrypted_secrets where name='contaos_internal_worker_token')
    ),
    body := jsonb_build_object('queue',p_fila,'max_jobs',least(greatest(p_max_jobs,1),10)),
    timeout_milliseconds := 10000
  ) into v_request_id;
  return v_request_id;
end;$$;
revoke all on function privado.invocar_contaos_worker(text,integer) from public,anon,authenticated;

do $$ begin
  perform cron.schedule(
    'contaos-workers-rapidos',
    '20 seconds',
    $cron$
      select privado.invocar_contaos_worker('documents',3);
      select privado.invocar_contaos_worker('embeddings',5);
      select privado.invocar_contaos_worker('ai',2);
      select privado.invocar_contaos_worker('webhooks',3);
    $cron$
  );
  perform cron.schedule(
    'contaos-workers-pesados',
    '* * * * *',
    $cron$
      select privado.invocar_contaos_worker('finance_imports',2);
      select privado.invocar_contaos_worker('reports',2);
      select privado.invocar_contaos_worker('integrations',5);
      select privado.invocar_contaos_worker('ocr',2);
    $cron$
  );
  perform cron.schedule(
    'contaos-limpeza-historico-cron',
    '15 3 * * 0',
    $cron$
      delete from cron.job_run_details where end_time < now() - interval '30 days';
    $cron$
  );
end $$;

commit;
