\set QUIET on
begin;
do $$
begin
 if to_regprocedure('public.salvar_contestacao_v2(uuid,integer,text,text,jsonb,text)') is null
   or to_regprocedure('public.revisar_contestacao_v2(uuid,integer,boolean,text,text)') is null then
  raise exception 'V2_48_RED: faltam as operações que validam contrato, versão e mapa de evidências';
 end if;
end $$;
rollback;
