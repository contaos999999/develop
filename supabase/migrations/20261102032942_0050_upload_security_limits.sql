alter table public.configuracao_upload
  add column if not exists tamanho_maximo_processamento_bytes bigint;

update public.configuracao_upload
set tamanho_maximo_bytes = 524288000,
    tamanho_maximo_processamento_bytes = 50331648,
    atualizado_em = now()
where id = true;

alter table public.configuracao_upload
  alter column tamanho_maximo_processamento_bytes set default 50331648,
  alter column tamanho_maximo_processamento_bytes set not null;

update storage.buckets
set file_size_limit = 524288000,
    allowed_mime_types = array[
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/csv',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/png',
      'image/jpeg',
      'image/webp',
      'text/plain',
      'application/json',
      'application/xml',
      'text/xml'
    ]::text[]
where id = 'contaos-documentos';

create or replace function privado.confirmar_upload_arquivo(
  p_id_organizacao uuid,
  p_id_contrato uuid,
  p_path text,
  p_nome_original text,
  p_mime text,
  p_tamanho bigint,
  p_sha256 text,
  p_origem text default 'upload_usuario'::text
) returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_id uuid;
  v_cfg public.configuracao_upload%rowtype;
  v_ext text;
  v_tamanho_real bigint;
  v_mime_real text;
  v_padrao_path text;
begin
  if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
  if not privado.usuario_tem_acesso_organizacao(p_id_organizacao) then raise exception 'Seu usuário não possui acesso à organização informada.'; end if;
  if p_id_contrato is not null and not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Seu usuário não possui acesso ao contrato informado.'; end if;

  v_padrao_path := '^' || p_id_organizacao::text || '/uploads/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}/[A-Za-z0-9._-]{1,180}$';
  if p_path is null or p_path !~ v_padrao_path then
    raise exception 'O caminho do arquivo não corresponde ao padrão seguro de upload desta organização.';
  end if;

  select * into v_cfg from public.configuracao_upload where id=true;
  if not found then raise exception 'A configuração de upload não está disponível.'; end if;

  v_ext := lower(regexp_replace(p_nome_original,'^.*\\.','','g'));
  if not (v_ext=any(v_cfg.extensoes_permitidas)) then raise exception 'Este formato de arquivo não é aceito pelo ContaOS.'; end if;
  if p_mime is null or not (lower(p_mime)=any(v_cfg.mimes_permitidos)) then raise exception 'O tipo do arquivo enviado não é aceito pelo ContaOS.'; end if;
  if p_tamanho < 0 then raise exception 'O tamanho do arquivo informado é inválido.'; end if;
  if v_cfg.tamanho_maximo_bytes is not null and p_tamanho > v_cfg.tamanho_maximo_bytes then raise exception 'O arquivo ultrapassa o limite configurado para este ambiente.'; end if;
  if p_sha256 !~ '^[0-9a-fA-F]{64}$' then raise exception 'Não foi possível confirmar a integridade do arquivo. Tente enviar novamente.'; end if;

  select
    case when (o.metadata->>'size') ~ '^[0-9]+$' then (o.metadata->>'size')::bigint else null end,
    lower(nullif(o.metadata->>'mimetype',''))
  into v_tamanho_real, v_mime_real
  from storage.objects o
  where o.bucket_id='contaos-documentos' and o.name=p_path;

  if not found then raise exception 'O upload ainda não foi concluído no armazenamento.'; end if;
  if v_tamanho_real is null then raise exception 'Não foi possível confirmar o tamanho real do arquivo armazenado.'; end if;
  if v_cfg.tamanho_maximo_bytes is not null and v_tamanho_real > v_cfg.tamanho_maximo_bytes then raise exception 'O arquivo armazenado ultrapassa o limite configurado para este ambiente.'; end if;
  if v_tamanho_real <> p_tamanho then raise exception 'O tamanho informado não corresponde ao arquivo realmente armazenado.'; end if;
  if v_mime_real is null or not (v_mime_real=any(v_cfg.mimes_permitidos)) then raise exception 'O tipo real registrado no armazenamento não é aceito pelo ContaOS.'; end if;
  if v_mime_real <> lower(p_mime) then raise exception 'O tipo informado não corresponde ao arquivo realmente armazenado.'; end if;

  insert into public.arquivos(id_organizacao,id_contrato,bucket,path,nome_original,mime,tamanho,sha256,status_seguranca,origem,criado_por)
  values(p_id_organizacao,p_id_contrato,'contaos-documentos',p_path,p_nome_original,v_mime_real,v_tamanho_real,lower(p_sha256),'pendente',coalesce(nullif(trim(p_origem),''),'upload_usuario'),auth.uid())
  returning id into v_id;

  perform privado.registrar_evento_auditoria(
    p_id_organizacao,
    'UploadArquivoConfirmado',
    'arquivos',
    v_id,
    null,
    jsonb_build_object('id_contrato',p_id_contrato,'nome_original',p_nome_original,'tamanho',v_tamanho_real,'mime',v_mime_real,'sha256',lower(p_sha256))
  );
  return v_id;
end;
$function$;
