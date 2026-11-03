-- ContaOS 4.1 — V1-CON-001 / V1-10
begin;

create or replace function privado.criar_documento_contrato_v111(
  p_id_contrato uuid,
  p_tipo text,
  p_titulo text,
  p_categoria text,
  p_vigencia_inicio date,
  p_vigencia_fim date,
  p_observacoes text,
  p_id_arquivo uuid,
  p_chave_idempotencia text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_contrato public.contratos%rowtype;
  v_arquivo public.arquivos%rowtype;
  v_doc uuid;
  v_ver uuid;
  v_job uuid;
  v_cmd jsonb;
  v_resultado jsonb;
begin
  select * into v_contrato from public.contratos where id=p_id_contrato;
  if v_contrato.id is null then raise exception using errcode='PT404', message='Contrato não encontrado.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa()
     or not privado.usuario_tem_acesso_contrato(v_contrato.id)
     or not privado.usuario_possui_perfil(v_contrato.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then
    raise exception using errcode='42501', message='Seu perfil atual não permite incluir documentos neste contrato.';
  end if;
  if nullif(btrim(p_tipo),'') is null then raise exception using errcode='PT400', message='Informe o tipo do documento.'; end if;
  if nullif(btrim(p_titulo),'') is null then raise exception using errcode='PT400', message='Informe o título do documento.'; end if;
  if p_vigencia_fim is not null and p_vigencia_inicio is null then raise exception using errcode='PT400', message='Informe o início da vigência quando houver fim de vigência.'; end if;
  if p_vigencia_inicio is not null and p_vigencia_fim is not null and p_vigencia_fim < p_vigencia_inicio then raise exception using errcode='PT400', message='O fim da vigência não pode ser anterior ao início.'; end if;

  v_cmd := privado.v110_iniciar_comando(
    v_contrato.id_organizacao,'v111.criar_documento_contrato_completo',p_chave_idempotencia,
    jsonb_build_object('id_contrato',v_contrato.id,'tipo',btrim(p_tipo),'titulo',btrim(p_titulo),
      'categoria',nullif(btrim(coalesce(p_categoria,'')),''),'vigencia_inicio',p_vigencia_inicio,
      'vigencia_fim',p_vigencia_fim,'observacoes',nullif(btrim(coalesce(p_observacoes,'')),''),'id_arquivo',p_id_arquivo)
  );
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;

  v_arquivo := privado.v110_validar_arquivo_contrato(p_id_arquivo,v_contrato.id_organizacao,v_contrato.id);

  insert into public.documentos_contrato(
    id_organizacao,id_contrato,tipo,titulo,categoria,vigencia_inicio,vigencia_fim,observacoes,situacao,versao_atual
  ) values(
    v_contrato.id_organizacao,v_contrato.id,btrim(p_tipo),btrim(p_titulo),
    nullif(btrim(coalesce(p_categoria,'')),''),p_vigencia_inicio,p_vigencia_fim,
    nullif(btrim(coalesce(p_observacoes,'')),''),'ativo',1
  ) returning id into v_doc;

  insert into public.versoes_documento(
    id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash,enviado_por
  ) values(
    v_contrato.id_organizacao,v_contrato.id,v_doc,1,v_arquivo.id,v_arquivo.sha256,auth.uid()
  ) returning id into v_ver;

  v_job := privado.enfileirar_job('documents',v_contrato.id_organizacao,v_contrato.id,'versao_documento',v_ver,
    jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
  values(v_contrato.id_organizacao,v_contrato.id,v_ver,'documents','pendente');

  v_resultado := privado.v110_concluir_comando(
    (v_cmd->>'id')::uuid,v_contrato.id_organizacao,'DocumentoContratoCriadoCompleto','documentos_contrato',v_doc,
    jsonb_build_object('id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,'id_arquivo',v_arquivo.id,'id_job',v_job,
      'vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim,'observacoes',nullif(btrim(coalesce(p_observacoes,'')),'')),
    jsonb_build_object('id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,'id_arquivo',v_arquivo.id,'id_job',v_job)
  );
  return v_resultado;
end;
$$;
revoke all on function privado.criar_documento_contrato_v111(uuid,text,text,text,date,date,text,uuid,text) from public,anon,authenticated;

create or replace function public.criar_documento_contrato_completo(
  p_id_contrato uuid,
  p_tipo text,
  p_titulo text,
  p_categoria text,
  p_vigencia_inicio date,
  p_vigencia_fim date,
  p_observacoes text,
  p_id_arquivo uuid,
  p_chave_idempotencia text
) returns jsonb
language sql
security invoker
set search_path=''
as $$ select privado.criar_documento_contrato_v111($1,$2,$3,$4,$5,$6,$7,$8,$9) $$;
revoke all on function public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text) from public,anon;
grant execute on function public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text) to authenticated;

comment on function public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text)
  is 'V1-CON-001/V1-10: cria documento-base com categoria, vigência, observações, versão 1, processamento, auditoria e idempotência.';

commit;
