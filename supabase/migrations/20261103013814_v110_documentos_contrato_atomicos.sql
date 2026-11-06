begin;

create or replace function privado.v110_iniciar_comando(p_id_organizacao uuid,p_comando text,p_chave text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.comandos_idempotentes%rowtype; v_nome text:=p_comando||':'||auth.uid()::text; v_hash text:=encode(extensions.digest(coalesce(p_payload,'{}'::jsonb)::text,'sha256'),'hex');
begin
  if auth.uid() is null or not privado.sessao_usuario_ativa() then raise exception using errcode='42501',message='Sua sessão não está ativa. Faça login novamente.'; end if;
  if p_chave is null or length(btrim(p_chave)) not between 1 and 200 then raise exception using errcode='PT400',message='Informe uma chave de operação válida.'; end if;
  insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,expira_em)
  values(p_id_organizacao,v_nome,btrim(p_chave),v_hash,'iniciado',now()+interval '24 hours')
  on conflict(id_organizacao,comando,chave) do nothing returning * into v;
  if v.id is null then
    select * into v from public.comandos_idempotentes where id_organizacao=p_id_organizacao and comando=v_nome and chave=btrim(p_chave) for update;
    if v.hash_payload is distinct from v_hash then raise exception using errcode='PT409',message='Esta chave de operação já foi usada com dados diferentes.'; end if;
    if v.status='concluido' and v.resposta is not null then return jsonb_build_object('id',v.id,'resposta',v.resposta); end if;
    raise exception using errcode='PT409',message='Esta operação já está em processamento. Atualize a tela.';
  end if;
  return jsonb_build_object('id',v.id);
end;$$;
revoke all on function privado.v110_iniciar_comando(uuid,text,text,jsonb) from public,anon,authenticated;

create or replace function privado.v110_concluir_comando(p_id_comando uuid,p_id_organizacao uuid,p_evento text,p_entidade text,p_id_entidade uuid,p_depois jsonb,p_resultado jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_evento uuid; v_correlacao uuid; v_resposta jsonb;
begin
  v_evento:=privado.registrar_evento_auditoria(p_id_organizacao,p_evento,p_entidade,p_id_entidade,null,p_depois,jsonb_build_object('comando_id',p_id_comando,'origem','V1-10'));
  select correlation_id into v_correlacao from public.eventos_auditoria where id=v_evento;
  v_resposta:=p_resultado||jsonb_build_object('schema_versao','v110-v1','correlation_id',v_correlacao);
  update public.comandos_idempotentes set status='concluido',resposta=v_resposta,atualizado_em=clock_timestamp() where id=p_id_comando;
  return v_resposta;
end;$$;
revoke all on function privado.v110_concluir_comando(uuid,uuid,text,text,uuid,jsonb,jsonb) from public,anon,authenticated;

create or replace function privado.v110_validar_arquivo_contrato(p_id_arquivo uuid,p_id_organizacao uuid,p_id_contrato uuid)
returns public.arquivos language plpgsql stable security definer set search_path='' as $$
declare v public.arquivos%rowtype;
begin
  select * into v from public.arquivos where id=p_id_arquivo;
  if v.id is null then raise exception using errcode='PT404',message='Arquivo não encontrado. Envie o arquivo novamente.'; end if;
  if v.id_organizacao<>p_id_organizacao or v.id_contrato is distinct from p_id_contrato then raise exception using errcode='42501',message='O arquivo informado não pertence a este contrato.'; end if;
  if v.bucket<>'contaos-documentos' then raise exception using errcode='PT409',message='O arquivo não está no armazenamento documental oficial do ContaOS.'; end if;
  if v.status_seguranca in('quarentena','bloqueado') then raise exception using errcode='PT409',message='Este arquivo foi bloqueado pela verificação de segurança e não pode ser vinculado.'; end if;
  return v;
end;$$;
revoke all on function privado.v110_validar_arquivo_contrato(uuid,uuid,uuid) from public,anon,authenticated;

create or replace function privado.criar_documento_contrato_v110(p_id_contrato uuid,p_tipo text,p_titulo text,p_categoria text,p_id_arquivo uuid,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_contrato public.contratos%rowtype; v_arquivo public.arquivos%rowtype; v_doc uuid; v_ver uuid; v_job uuid; v_cmd jsonb; v_resultado jsonb;
begin
  select * into v_contrato from public.contratos where id=p_id_contrato;
  if v_contrato.id is null then raise exception using errcode='PT404',message='Contrato não encontrado.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa() or not privado.usuario_tem_acesso_contrato(v_contrato.id) or not privado.usuario_possui_perfil(v_contrato.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception using errcode='42501',message='Seu perfil atual não permite incluir documentos neste contrato.'; end if;
  if nullif(btrim(p_tipo),'') is null then raise exception using errcode='PT400',message='Informe o tipo do documento.'; end if;
  if nullif(btrim(p_titulo),'') is null then raise exception using errcode='PT400',message='Informe o título do documento.'; end if;
  v_cmd:=privado.v110_iniciar_comando(v_contrato.id_organizacao,'v110.criar_documento_contrato',p_chave_idempotencia,jsonb_build_object('id_contrato',v_contrato.id,'tipo',btrim(p_tipo),'titulo',btrim(p_titulo),'categoria',nullif(btrim(coalesce(p_categoria,'')),''),'id_arquivo',p_id_arquivo));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_contrato.id_organizacao,v_contrato.id);
  insert into public.documentos_contrato(id_organizacao,id_contrato,tipo,titulo,categoria,situacao,versao_atual)
  values(v_contrato.id_organizacao,v_contrato.id,btrim(p_tipo),btrim(p_titulo),nullif(btrim(coalesce(p_categoria,'')),''),'ativo',1) returning id into v_doc;
  insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash,enviado_por)
  values(v_contrato.id_organizacao,v_contrato.id,v_doc,1,v_arquivo.id,v_arquivo.sha256,auth.uid()) returning id into v_ver;
  v_job:=privado.enfileirar_job('documents',v_contrato.id_organizacao,v_contrato.id,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_contrato.id_organizacao,v_contrato.id,v_ver,'documents','pendente');
  v_resultado:=privado.v110_concluir_comando((v_cmd->>'id')::uuid,v_contrato.id_organizacao,'DocumentoContratoCriado','documentos_contrato',v_doc,jsonb_build_object('id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,'id_arquivo',v_arquivo.id,'id_job',v_job),jsonb_build_object('id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,'id_arquivo',v_arquivo.id,'id_job',v_job));
  return v_resultado;
end;$$;
revoke all on function privado.criar_documento_contrato_v110(uuid,text,text,text,uuid,text) from public,anon,authenticated;

create or replace function privado.adicionar_versao_documento_contrato_v110(p_id_documento uuid,p_id_arquivo uuid,p_motivo text,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_doc public.documentos_contrato%rowtype; v_arquivo public.arquivos%rowtype; v_num integer; v_ver uuid; v_job uuid; v_cmd jsonb; v_resultado jsonb;
begin
  select * into v_doc from public.documentos_contrato where id=p_id_documento;
  if v_doc.id is null then raise exception using errcode='PT404',message='Documento não encontrado.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa() or not privado.usuario_tem_acesso_contrato(v_doc.id_contrato) or not privado.usuario_possui_perfil(v_doc.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception using errcode='42501',message='Seu perfil atual não permite criar uma nova versão deste documento.'; end if;
  v_cmd:=privado.v110_iniciar_comando(v_doc.id_organizacao,'v110.adicionar_versao_documento_contrato',p_chave_idempotencia,jsonb_build_object('id_documento',v_doc.id,'id_arquivo',p_id_arquivo,'motivo',nullif(btrim(coalesce(p_motivo,'')),'')));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  select * into v_doc from public.documentos_contrato where id=p_id_documento for update;
  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_doc.id_organizacao,v_doc.id_contrato);
  select coalesce(max(numero_versao),0)+1 into v_num from public.versoes_documento where id_documento_contrato=v_doc.id;
  if v_num>1 and nullif(btrim(coalesce(p_motivo,'')),'') is null then raise exception using errcode='PT400',message='Informe o motivo da nova versão para preservar a rastreabilidade documental.'; end if;
  insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash,motivo_substituicao,enviado_por)
  values(v_doc.id_organizacao,v_doc.id_contrato,v_doc.id,v_num,v_arquivo.id,v_arquivo.sha256,nullif(btrim(coalesce(p_motivo,'')),''),auth.uid()) returning id into v_ver;
  update public.documentos_contrato set versao_atual=v_num where id=v_doc.id;
  v_job:=privado.enfileirar_job('documents',v_doc.id_organizacao,v_doc.id_contrato,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_doc.id_organizacao,v_doc.id_contrato,v_ver,'documents','pendente');
  v_resultado:=privado.v110_concluir_comando((v_cmd->>'id')::uuid,v_doc.id_organizacao,'VersaoDocumentoContratoCriada','versoes_documento',v_ver,jsonb_build_object('id_documento',v_doc.id,'id_versao',v_ver,'numero_versao',v_num,'id_arquivo',v_arquivo.id,'id_job',v_job,'motivo',nullif(btrim(coalesce(p_motivo,'')),'')),jsonb_build_object('id_documento',v_doc.id,'id_versao',v_ver,'numero_versao',v_num,'id_arquivo',v_arquivo.id,'id_job',v_job));
  return v_resultado;
end;$$;
revoke all on function privado.adicionar_versao_documento_contrato_v110(uuid,uuid,text,text) from public,anon,authenticated;

create or replace function public.criar_documento_contrato(p_id_contrato uuid,p_tipo text,p_titulo text,p_categoria text,p_id_arquivo uuid,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.criar_documento_contrato_v110($1,$2,$3,$4,$5,$6)$$;
revoke all on function public.criar_documento_contrato(uuid,text,text,text,uuid,text) from public,anon;
grant execute on function public.criar_documento_contrato(uuid,text,text,text,uuid,text) to authenticated;

create or replace function public.adicionar_versao_documento_contrato(p_id_documento uuid,p_id_arquivo uuid,p_motivo text,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.adicionar_versao_documento_contrato_v110($1,$2,$3,$4)$$;
revoke all on function public.adicionar_versao_documento_contrato(uuid,uuid,text,text) from public,anon;
grant execute on function public.adicionar_versao_documento_contrato(uuid,uuid,text,text) to authenticated;

revoke insert on table public.arquivos from authenticated;
revoke insert on table public.documentos_contrato from authenticated;
revoke insert on table public.versoes_documento from authenticated;

create or replace function privado.v110_proteger_ponteiro_documento_contrato()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_user='authenticated' and new.versao_atual is distinct from old.versao_atual then raise exception using errcode='42501',message='A versão atual do documento só pode ser alterada pela operação oficial do ContaOS.'; end if;
  return new;
end;$$;
revoke all on function privado.v110_proteger_ponteiro_documento_contrato() from public,anon,authenticated;
drop trigger if exists v110_proteger_ponteiro_documento_contrato on public.documentos_contrato;
create trigger v110_proteger_ponteiro_documento_contrato before update on public.documentos_contrato for each row execute function privado.v110_proteger_ponteiro_documento_contrato();

comment on function public.criar_documento_contrato(uuid,text,text,text,uuid,text) is 'V1-10: cria documento lógico + versão 1 + fila/processamento + auditoria de forma atômica e idempotente.';
comment on function public.adicionar_versao_documento_contrato(uuid,uuid,text,text) is 'V1-10/V1-11: adiciona versão imutável + atualiza ponteiro + fila/processamento + auditoria de forma atômica e idempotente.';

commit;
