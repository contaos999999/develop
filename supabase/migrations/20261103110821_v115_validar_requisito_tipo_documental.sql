create or replace function privado.criar_documento_competencia_v115(
  p_id_competencia uuid,
  p_tipo text,
  p_titulo text,
  p_categoria text,
  p_id_requisito uuid,
  p_id_arquivo uuid,
  p_chave_idempotencia text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_comp public.competencias%rowtype;
  v_arquivo public.arquivos%rowtype;
  v_req public.requisitos_competencia%rowtype;
  v_tipos jsonb := '[]'::jsonb;
  v_doc uuid;
  v_ver uuid;
  v_job uuid;
  v_cmd jsonb;
  v_resultado jsonb;
begin
  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then raise exception using errcode='PT404',message='Competência não encontrada.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa()
     or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato)
     or not privado.usuario_possui_perfil(v_comp.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then
    raise exception using errcode='42501',message='Seu perfil atual não permite incluir documentos nesta competência.';
  end if;
  if nullif(btrim(p_tipo),'') is null then raise exception using errcode='PT400',message='Informe o tipo do documento.'; end if;
  if nullif(btrim(p_titulo),'') is null then raise exception using errcode='PT400',message='Informe o título do documento.'; end if;

  if p_id_requisito is not null then
    select * into v_req
      from public.requisitos_competencia r
     where r.id=p_id_requisito and r.id_competencia=v_comp.id;

    if v_req.id is null then
      raise exception using errcode='PT400',message='O requisito informado não pertence a esta competência.';
    end if;

    if not privado.v115_requisito_exige_documento(v_req.regra_validacao) then
      raise exception using errcode='PT400',message='O requisito informado não é um requisito documental desta competência.';
    end if;

    v_tipos := case
      when jsonb_typeof(v_req.regra_validacao #> '{documento,tipos}')='array'
        then v_req.regra_validacao #> '{documento,tipos}'
      else '[]'::jsonb
    end;

    if jsonb_array_length(v_tipos)>0 and not (v_tipos ? btrim(p_tipo)) then
      raise exception using errcode='PT400',message='O tipo informado não é aceito para o requisito documental selecionado.';
    end if;
  end if;

  v_cmd:=privado.v110_iniciar_comando(
    v_comp.id_organizacao,'v115.criar_documento_competencia',p_chave_idempotencia,
    jsonb_build_object('id_competencia',v_comp.id,'tipo',btrim(p_tipo),'titulo',btrim(p_titulo),
      'categoria',nullif(btrim(coalesce(p_categoria,'')),''),'id_requisito',p_id_requisito,'id_arquivo',p_id_arquivo)
  );
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;

  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_comp.id_organizacao,v_comp.id_contrato);
  insert into public.documentos_competencia(
    id_organizacao,id_contrato,id_competencia,tipo,titulo,categoria,id_requisito_competencia,situacao,versao_atual
  ) values(
    v_comp.id_organizacao,v_comp.id_contrato,v_comp.id,btrim(p_tipo),btrim(p_titulo),
    nullif(btrim(coalesce(p_categoria,'')),''),p_id_requisito,'ativo',1
  ) returning id into v_doc;
  insert into public.versoes_documento(
    id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,enviado_por
  ) values(
    v_comp.id_organizacao,v_comp.id_contrato,v_doc,1,v_arquivo.id,v_arquivo.sha256,auth.uid()
  ) returning id into v_ver;
  v_job:=privado.enfileirar_job(
    'documents',v_comp.id_organizacao,v_comp.id_contrato,'versao_documento',v_ver,
    jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text
  );
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_ver,'documents','pendente');

  v_resultado:=privado.v115_concluir_comando(
    (v_cmd->>'id')::uuid,v_comp.id_organizacao,'DocumentoCompetenciaCriado','documentos_competencia',v_doc,
    jsonb_build_object('id_competencia',v_comp.id,'id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,
      'id_arquivo',v_arquivo.id,'id_requisito',p_id_requisito,'id_job',v_job),
    jsonb_build_object('id_competencia',v_comp.id,'id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,
      'id_arquivo',v_arquivo.id,'id_job',v_job)
  );
  return v_resultado;
end;
$$;
