-- ContaOS 4.1 — V1-CON-002/V1-CON-005
begin;
create or replace function privado.v111_validar_fonte_vigencia_regra_assistida()
returns trigger
language plpgsql security definer set search_path=''
as $$
declare v_sug public.sugestoes_extracao_documento%rowtype; v_id_sug uuid;
begin
  if coalesce(new.configuracao->>'origem','')<>'sugestao_extracao' then return new; end if;
  v_id_sug:=nullif(new.configuracao->>'id_sugestao','')::uuid;
  select * into v_sug from public.sugestoes_extracao_documento where id=v_id_sug;
  if v_sug.id is null then raise exception using errcode='PT400',message='Regra assistida sem sugestão de origem válida.'; end if;
  if v_sug.pagina is null or nullif(btrim(coalesce(v_sug.trecho_fonte,'')),'') is null then raise exception using errcode='PT400',message='A regra assistida exige página e trecho da fonte.'; end if;
  if v_sug.vigencia_inicio is null then raise exception using errcode='PT400',message='A regra assistida exige início de vigência antes da aprovação.'; end if;
  new.vigencia_inicio:=v_sug.vigencia_inicio;
  new.vigencia_fim:=v_sug.vigencia_fim;
  new.configuracao:=coalesce(new.configuracao,'{}'::jsonb)||jsonb_build_object('pagina',v_sug.pagina,'trecho_fonte',v_sug.trecho_fonte,'vigencia_inicio',v_sug.vigencia_inicio,'vigencia_fim',v_sug.vigencia_fim);
  return new;
end;$$;
revoke all on function privado.v111_validar_fonte_vigencia_regra_assistida() from public,anon,authenticated;
commit;
