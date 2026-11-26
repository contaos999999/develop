do $$
begin
  if to_regprocedure('public.registrar_extracao_apontamentos(uuid,uuid,text,jsonb)') is null
    or to_regprocedure('public.obter_fonte_apontamento_contratante(uuid,uuid)') is null then
    raise exception 'V2_I05_ORIGEM_DURAVEL: contrato de escrita e leitura inexistente no baseline';
  end if;
end $$;
