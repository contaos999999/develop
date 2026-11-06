-- ContaOS 4.1 — V1-CON-001
begin;
create or replace function privado.criar_documento_contrato_v111(
  p_id_contrato uuid,p_tipo text,p_titulo text,p_categoria text,
  p_vigencia_inicio date,p_vigencia_fim date,p_observacoes text,
  p_id_arquivo uuid,p_chave_idempotencia text
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_contrato public.contratos%rowtype; v_cmd jsonb; v_base jsonb; v_doc uuid; v_resp jsonb;
begin
  select * into v_contrato from public.contratos where id=p_id_contrato;
  if v_contrato.id is null then raise exception using errcode='PT404',message='Contrato não encontrado.'; end if;
  if p_vigencia_fim is not null and p_vigencia_inicio is null then raise exception using errcode='PT400',message='Informe o início da vigência quando houver fim de vigência.'; end if;
  if p_vigencia_inicio is not null and p_vigencia_fim is not null and p_vigencia_fim<p_vigencia_inicio then raise exception using errcode='PT400',message='O fim da vigência não pode ser anterior ao início.'; end if;

  v_cmd:=privado.v110_iniciar_comando(v_contrato.id_organizacao,'v111.criar_documento_contrato_completo',p_chave_idempotencia,
    jsonb_build_object('id_contrato',p_id_contrato,'tipo',p_tipo,'titulo',p_titulo,'categoria',p_categoria,
      'vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim,'observacoes',p_observacoes,'id_arquivo',p_id_arquivo));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;

  v_base:=privado.criar_documento_contrato_v110(p_id_contrato,p_tipo,p_titulo,p_categoria,p_id_arquivo,
    p_chave_idempotencia||':v110');
  v_doc:=(v_base->>'id_documento')::uuid;
  update public.documentos_contrato set vigencia_inicio=p_vigencia_inicio,vigencia_fim=p_vigencia_fim,
    observacoes=nullif(btrim(coalesce(p_observacoes,'')),'') where id=v_doc;

  v_resp:=privado.v110_concluir_comando((v_cmd->>'id')::uuid,v_contrato.id_organizacao,
    'DocumentoContratoMetadadosCompletos','documentos_contrato',v_doc,null,
    v_base||jsonb_build_object('vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim));
  return v_resp;
end;$$;
revoke all on function privado.criar_documento_contrato_v111(uuid,text,text,text,date,date,text,uuid,text) from public,anon,authenticated;
commit;
