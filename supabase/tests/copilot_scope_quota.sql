-- Restore isolado somente; não constitui prova JWT HML. Falha antes de fixtures se RPC faltar.
begin;
do $$
begin
 if to_regprocedure('public.worker_reservar_consulta_copiloto(uuid,uuid,uuid,text,jsonb,text)') is null then
   raise exception 'COPILOT_SQL_RED_RESERVA_RPC_AUSENTE';
 end if;
 if to_regprocedure('public.worker_buscar_fragmentos_copiloto(uuid,uuid,uuid[],extensions.vector,date,integer)') is null then
   raise exception 'COPILOT_SQL_RED_FRAGMENTOS_RPC_AUSENTE';
 end if;
 if to_regprocedure('public.worker_buscar_precedentes_copiloto(uuid,uuid,uuid,uuid[],extensions.vector,integer)') is null then
   raise exception 'COPILOT_SQL_RED_PRECEDENTES_RPC_AUSENTE';
 end if;
end $$;
rollback;
select 'COPILOT_SCOPE_QUOTA_SQL_PASS';
