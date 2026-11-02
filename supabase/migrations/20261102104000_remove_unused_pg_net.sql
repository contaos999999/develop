begin;

-- SEC-BACKEND-ALERTS-HML-2026-11-02
-- pg_net 0.20.4 estava instalado no schema public, é não relocável e não possui
-- dependências no ContaOS HML. O teste prévio `DROP EXTENSION ... RESTRICT`
-- dentro de transação + ROLLBACK confirmou ausência de dependentes.
--
-- O ContaOS HML atual não possui Database Webhooks nem jobs pg_cron chamando
-- net.*, http_request, http_post ou http_get. Portanto, remover a extensão é
-- mais seguro do que mantê-la exposta ou manipular pg_catalog para relocá-la.

drop extension if exists pg_net restrict;

commit;
