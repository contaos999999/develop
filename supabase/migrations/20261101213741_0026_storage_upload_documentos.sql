begin;

create table public.configuracao_upload(
  id boolean primary key default true check(id=true),
  limiar_upload_resumivel_bytes bigint not null default 104857600,
  tamanho_maximo_bytes bigint,
  extensoes_permitidas text[] not null default array['pdf','xlsx','csv','docx','png','jpg','jpeg','webp','txt','json','xml']::text[],
  mimes_permitidos text[] not null default array[
    'application/pdf','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document','image/png','image/jpeg','image/webp',
    'text/plain','application/json','application/xml','text/xml'
  ]::text[],
  atualizado_em timestamptz not null default now()
);
alter table public.configuracao_upload enable row level security;
create policy configuracao_upload_leitura on public.configuracao_upload for select to anon,authenticated using(true);
revoke all on public.configuracao_upload from anon,authenticated;
grant select on public.configuracao_upload to anon,authenticated;
insert into public.configuracao_upload(id) values(true) on conflict(id) do nothing;

create or replace function privado.confirmar_upload_arquivo(
  p_id_organizacao uuid,
  p_id_contrato uuid,
  p_path text,
  p_nome_original text,
  p_mime text,
  p_tamanho bigint,
  p_sha256 text,
  p_origem text default 'upload_usuario'
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_cfg public.configuracao_upload%rowtype; v_ext text;
begin
  if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
  if not privado.usuario_tem_acesso_organizacao(p_id_organizacao) then raise exception 'Seu usuário não possui acesso à organização informada.'; end if;
  if p_id_contrato is not null and not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Seu usuário não possui acesso ao contrato informado.'; end if;
  if split_part(p_path,'/',1) <> p_id_organizacao::text then raise exception 'O caminho do arquivo não corresponde à sua organização.'; end if;
  select * into v_cfg from public.configuracao_upload where id=true;
  v_ext:=lower(regexp_replace(p_nome_original,'^.*\.','','g'));
  if not (v_ext=any(v_cfg.extensoes_permitidas)) then raise exception 'Este formato de arquivo não é aceito pelo ContaOS.'; end if;
  if p_mime is not null and not (lower(p_mime)=any(v_cfg.mimes_permitidos)) then raise exception 'O tipo do arquivo enviado não é aceito pelo ContaOS.'; end if;
  if p_tamanho<0 then raise exception 'O tamanho do arquivo informado é inválido.'; end if;
  if v_cfg.tamanho_maximo_bytes is not null and p_tamanho>v_cfg.tamanho_maximo_bytes then raise exception 'O arquivo ultrapassa o limite configurado para este ambiente.'; end if;
  if p_sha256 !~ '^[0-9a-fA-F]{64}$' then raise exception 'Não foi possível confirmar a integridade do arquivo. Tente enviar novamente.'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='contaos-documentos' and o.name=p_path) then raise exception 'O upload ainda não foi concluído no armazenamento.'; end if;
  insert into public.arquivos(id_organizacao,id_contrato,bucket,path,nome_original,mime,tamanho,sha256,status_seguranca,origem,criado_por)
  values(p_id_organizacao,p_id_contrato,'contaos-documentos',p_path,p_nome_original,p_mime,p_tamanho,lower(p_sha256),'pendente',coalesce(nullif(trim(p_origem),''),'upload_usuario'),auth.uid())
  returning id into v_id;
  perform privado.registrar_evento_auditoria(p_id_organizacao,'UploadArquivoConfirmado','arquivos',v_id,null,jsonb_build_object('id_contrato',p_id_contrato,'nome_original',p_nome_original,'tamanho',p_tamanho,'sha256',lower(p_sha256)));
  return v_id;
end;$$;
revoke all on function privado.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text) from public,anon;
grant execute on function privado.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text) to authenticated;

create or replace function public.confirmar_upload_arquivo(p_id_organizacao uuid,p_id_contrato uuid,p_path text,p_nome_original text,p_mime text,p_tamanho bigint,p_sha256 text,p_origem text default 'upload_usuario')
returns uuid language sql security invoker set search_path='' as $$select privado.confirmar_upload_arquivo($1,$2,$3,$4,$5,$6,$7,$8)$$;
revoke all on function public.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text) from public,anon;
grant execute on function public.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text) to authenticated;

create or replace function privado.criar_documento_competencia(
  p_id_competencia uuid,p_tipo text,p_titulo text,p_categoria text,p_id_requisito uuid,p_id_arquivo uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_comp public.competencias%rowtype; v_arq public.arquivos%rowtype; v_doc uuid; v_ver uuid;
begin
  select * into v_comp from public.competencias where id=p_id_competencia;
  select * into v_arq from public.arquivos where id=p_id_arquivo;
  if v_comp.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if v_arq.id is null or v_arq.id_organizacao<>v_comp.id_organizacao or (v_arq.id_contrato is not null and v_arq.id_contrato<>v_comp.id_contrato) then raise exception 'O arquivo informado não pertence a esta competência.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato) or not privado.usuario_possui_perfil(v_comp.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite incluir documentos nesta competência.'; end if;
  if p_id_requisito is not null and not exists(select 1 from public.requisitos_competencia r where r.id=p_id_requisito and r.id_competencia=v_comp.id) then raise exception 'O requisito informado não pertence a esta competência.'; end if;
  insert into public.documentos_competencia(id_organizacao,id_contrato,id_competencia,tipo,titulo,categoria,id_requisito_competencia,situacao,versao_atual)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_comp.id,p_tipo,p_titulo,p_categoria,p_id_requisito,'ativo',1) returning id into v_doc;
  insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,enviado_por)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_doc,1,v_arq.id,v_arq.sha256,auth.uid()) returning id into v_ver;
  perform privado.enfileirar_job('documents',v_comp.id_organizacao,v_comp.id_contrato,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_comp.id_organizacao,v_comp.id_contrato,v_ver,'documents','pendente');
  perform privado.registrar_evento_auditoria(v_comp.id_organizacao,'DocumentoCompetenciaCriado','documentos_competencia',v_doc,null,jsonb_build_object('id_versao_documento',v_ver,'id_arquivo',v_arq.id));
  return v_doc;
end;$$;
create or replace function public.criar_documento_competencia(p_id_competencia uuid,p_tipo text,p_titulo text,p_categoria text,p_id_requisito uuid,p_id_arquivo uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.criar_documento_competencia($1,$2,$3,$4,$5,$6)$$;
revoke all on function public.criar_documento_competencia(uuid,text,text,text,uuid,uuid) from public,anon;
grant execute on function public.criar_documento_competencia(uuid,text,text,text,uuid,uuid) to authenticated;

create or replace function privado.adicionar_versao_documento_competencia(p_id_documento uuid,p_id_arquivo uuid,p_motivo text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_doc public.documentos_competencia%rowtype; v_arq public.arquivos%rowtype; v_num integer; v_ver uuid;
begin
 select * into v_doc from public.documentos_competencia where id=p_id_documento for update;
 select * into v_arq from public.arquivos where id=p_id_arquivo;
 if v_doc.id is null then raise exception 'Não encontramos o documento informado.'; end if;
 if v_arq.id is null or v_arq.id_organizacao<>v_doc.id_organizacao or (v_arq.id_contrato is not null and v_arq.id_contrato<>v_doc.id_contrato) then raise exception 'O arquivo informado não pertence a este contrato.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_doc.id_contrato) or not privado.usuario_possui_perfil(v_doc.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite criar uma nova versão deste documento.'; end if;
 select coalesce(max(numero_versao),0)+1 into v_num from public.versoes_documento where id_documento_competencia=v_doc.id;
 insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,motivo_substituicao,enviado_por)
 values(v_doc.id_organizacao,v_doc.id_contrato,v_doc.id,v_num,v_arq.id,v_arq.sha256,p_motivo,auth.uid()) returning id into v_ver;
 update public.documentos_competencia set versao_atual=v_num,versao_registro=versao_registro where id=v_doc.id;
 perform privado.enfileirar_job('documents',v_doc.id_organizacao,v_doc.id_contrato,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
 insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_doc.id_organizacao,v_doc.id_contrato,v_ver,'documents','pendente');
 perform privado.registrar_evento_auditoria(v_doc.id_organizacao,'VersaoDocumentoCompetenciaCriada','versoes_documento',v_ver,null,jsonb_build_object('id_documento_competencia',v_doc.id,'numero_versao',v_num,'motivo',p_motivo));
 return v_ver;
end;$$;
create or replace function public.adicionar_versao_documento_competencia(p_id_documento uuid,p_id_arquivo uuid,p_motivo text)
returns uuid language sql security invoker set search_path='' as $$select privado.adicionar_versao_documento_competencia($1,$2,$3)$$;
revoke all on function public.adicionar_versao_documento_competencia(uuid,uuid,text) from public,anon;
grant execute on function public.adicionar_versao_documento_competencia(uuid,uuid,text) to authenticated;

commit;
