CREATE OR REPLACE FUNCTION privado.invocar_worker_historico_hml() RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE req bigint;
BEGIN
 SELECT net.http_post(
 url:=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='contaos_project_url')||'/functions/v1/queue-worker-historico',
 headers:=pg_catalog.jsonb_build_object('Content-Type','application/json','x-contaos-internal-token',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='contaos_internal_worker_token')),
 body:='{}'::jsonb,timeout_milliseconds:=10000) INTO req;
 RETURN req;
END;$fn$;
REVOKE ALL ON FUNCTION privado.invocar_worker_historico_hml() FROM PUBLIC,anon,authenticated;
SELECT cron.schedule('contaos-worker-historico-v1-22','* * * * *','SELECT privado.invocar_worker_historico_hml();');
