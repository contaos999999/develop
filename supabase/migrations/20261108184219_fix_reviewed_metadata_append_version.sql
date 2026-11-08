-- Metadata review appends a new version; all existing historical versions remain immutable.
CREATE OR REPLACE FUNCTION privado.revisar_sugestao_extracao(p_id_sugestao uuid, p_aprovar boolean, p_conteudo_revisado text DEFAULT NULL::text, p_categoria_revisada text DEFAULT NULL::text, p_id_requisito_revisado uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.sugestoes_extracao_documento%rowtype; v_regra uuid; v_conteudo text; v_categoria text; v_req uuid; v_base public.versoes_documento%rowtype; v_atual integer; v_doc uuid; v_nova uuid; v_job uuid; v_num integer;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.sugestoes_extracao_documento where id=p_id_sugestao),'arquivos','editar',(select id_contrato from public.sugestoes_extracao_documento where id=p_id_sugestao));

  select * into v from public.sugestoes_extracao_documento where id=p_id_sugestao for update;
  if v.id is null then raise exception 'Não encontramos a sugestão informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso ao contrato desta sugestão.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite revisar esta sugestão.'; end if;
  if v.status<>'pendente' then raise exception 'Esta sugestão já foi revisada anteriormente.'; end if;
  v_conteudo:=coalesce(nullif(trim(p_conteudo_revisado),''),v.conteudo);
  v_categoria:=coalesce(nullif(trim(p_categoria_revisada),''),v.categoria_sugerida);
  v_req:=coalesce(p_id_requisito_revisado,v.id_requisito_sugerido);
  if not p_aprovar then
    update public.sugestoes_extracao_documento set status='rejeitada',revisado_por=auth.uid(),revisado_em=now(),metadados=metadados||jsonb_build_object('conteudo_revisado',p_conteudo_revisado,'categoria_revisada',p_categoria_revisada) where id=v.id;
    perform privado.registrar_evento_auditoria(v.id_organizacao,'SugestaoExtracaoRejeitada','sugestoes_extracao_documento',v.id,null,jsonb_build_object('tipo',v.tipo));
    return jsonb_build_object('status','rejeitada','mensagem','A sugestão foi rejeitada e nenhuma regra ou metadado foi alterado.');
  end if;
  if v.tipo='classificacao' then
    update public.documentos_competencia d set categoria=coalesce(v_categoria,d.categoria),id_requisito_competencia=coalesce(v_req,d.id_requisito_competencia)
    from public.versoes_documento vd where vd.id=v.id_versao_documento and vd.id_documento_competencia=d.id;
    update public.documentos_contrato d set categoria=coalesce(v_categoria,d.categoria)
    from public.versoes_documento vd where vd.id=v.id_versao_documento and vd.id_documento_contrato=d.id;
  elsif v.tipo='metadado' then
    select * into v_base from public.versoes_documento
      where id=v.id_versao_documento and id_organizacao=v.id_organizacao and id_contrato=v.id_contrato;
    if v_base.id is null then raise exception using errcode='PT404',message='A versão documental da sugestão não foi encontrada neste contrato.'; end if;
    if v_base.id_documento_contrato is not null then
      v_doc:=v_base.id_documento_contrato;
      select d.versao_atual into v_atual from public.documentos_contrato d
        where d.id=v_doc and d.id_organizacao=v.id_organizacao and d.id_contrato=v.id_contrato for update;
      if v_atual is null then raise exception using errcode='PT404',message='O documento da sugestão não foi encontrado.'; end if;
      if v_base.numero_versao<>v_atual or exists(select 1 from public.versoes_documento x where x.id_documento_contrato=v_doc and x.numero_versao>v_base.numero_versao) then
        raise exception using errcode='PT409',message='A versão documental mudou. Revise uma sugestão da versão atual.';
      end if;
    else
      v_doc:=v_base.id_documento_competencia;
      select d.versao_atual into v_atual from public.documentos_competencia d
        where d.id=v_doc and d.id_organizacao=v.id_organizacao and d.id_contrato=v.id_contrato for update;
      if v_atual is null then raise exception using errcode='PT404',message='O documento da sugestão não foi encontrado.'; end if;
      if v_base.numero_versao<>v_atual or exists(select 1 from public.versoes_documento x where x.id_documento_competencia=v_doc and x.numero_versao>v_base.numero_versao) then
        raise exception using errcode='PT409',message='A versão documental mudou. Revise uma sugestão da versão atual.';
      end if;
    end if;
    if not exists(select 1 from public.arquivos a where a.id=v_base.id_arquivo and a.id_organizacao=v.id_organizacao and a.id_contrato=v.id_contrato and a.sha256=v_base.hash and a.status_seguranca='aprovado') then
      raise exception using errcode='PT409',message='O arquivo-base mudou ou ainda não está aprovado.';
    end if;
    v_num:=v_base.numero_versao+1;
    insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,motivo_substituicao,metadados_extraidos,enviado_por)
    values(v.id_organizacao,v.id_contrato,v_base.id_documento_contrato,v_base.id_documento_competencia,v_num,v_base.id_arquivo,v_base.hash,
      'Revisão autorizada de metadados; sugestão '||v.id::text,
      coalesce(v_base.metadados_extraidos,'{}'::jsonb)||coalesce(v.metadados->'campos','{}'::jsonb)||jsonb_build_object('resumo_revisado',v_conteudo,'revisado_por',auth.uid(),'revisado_em',now(),'id_sugestao_origem',v.id),auth.uid()) returning id into v_nova;
    if v_base.id_documento_contrato is not null then
      update public.documentos_contrato set versao_atual=v_num where id=v_doc;
    else
      update public.documentos_competencia set versao_atual=v_num where id=v_doc;
    end if;
    v_job:=privado.enfileirar_job('documents',v.id_organizacao,v.id_contrato,'versao_documento',v_nova,jsonb_build_object('id_versao_documento',v_nova),'document:'||v_nova::text);
    insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
      values(v.id_organizacao,v.id_contrato,v_nova,'documents','pendente');
    perform privado.registrar_evento_auditoria(v.id_organizacao,'DocumentoMetadadosRevisados','versoes_documento',v_nova,
      jsonb_build_object('id_versao_anterior',v_base.id,'hash',v_base.hash),
      jsonb_build_object('id_versao',v_nova,'numero_versao',v_num,'id_documento',v_doc,'id_arquivo',v_base.id_arquivo,'hash',v_base.hash,'id_sugestao',v.id,'id_job',v_job));
  else
    insert into public.regras_conformidade(id_organizacao,id_contrato,codigo,descricao,tipo,efeito_portao,configuracao,situacao)
    values(v.id_organizacao,v.id_contrato,'SUG-'||upper(substr(replace(v.id::text,'-',''),1,12)),v_conteudo,'assistida',false,jsonb_build_object('origem','sugestao_extracao','id_sugestao',v.id,'id_versao_documento',v.id_versao_documento,'pagina',v.pagina,'trecho_fonte',v.trecho_fonte,'tipo_sugestao',v.tipo,'observacao','Regra criada em rascunho após revisão humana. A ativação material exige fluxo próprio de aprovação.'),'rascunho') returning id into v_regra;
  end if;
  update public.sugestoes_extracao_documento set status='aprovada',conteudo=v_conteudo,categoria_sugerida=v_categoria,id_requisito_sugerido=v_req,revisado_por=auth.uid(),revisado_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'SugestaoExtracaoAprovada','sugestoes_extracao_documento',v.id,null,jsonb_build_object('tipo',v.tipo,'id_regra_rascunho',v_regra));
  return jsonb_build_object('status','aprovada','id_regra_rascunho',v_regra,'mensagem',case when v_regra is null then 'A sugestão foi aprovada e aplicada ao documento.' else 'A sugestão foi aprovada e gerou uma regra em rascunho para revisão material.' end)||case when v_nova is not null then jsonb_build_object('id_documento',v_doc,'id_versao',v_nova,'numero_versao',v_num,'id_arquivo',v_base.id_arquivo,'id_job',v_job) else '{}'::jsonb end;
end; $function$;
