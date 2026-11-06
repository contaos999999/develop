begin;

create or replace function privado.enfileirar_evento_webhook(
  p_id_webhook uuid,
  p_evento text,
  p_entidade_tipo text,
  p_entidade_id uuid,
  p_payload_ref jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.webhooks%rowtype;
  v_evt uuid;
  v_hash text;
  v_role text := coalesce(auth.role(),'');
begin
  select * into v
  from public.webhooks
  where id=p_id_webhook and ativo=true;

  if v.id is null then
    raise exception 'Webhook não encontrado ou inativo.';
  end if;

  if auth.uid() is null then
    if v_role <> 'service_role' then
      raise exception using
        errcode='42501',
        message='Acesso negado para enfileirar este evento de webhook.',
        detail='A operação exige uma sessão administrativa válida ou o contexto interno service_role.';
    end if;
  else
    if not privado.sessao_usuario_ativa()
       or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador']::text[]) then
      raise exception using
        errcode='42501',
        message='Seu perfil atual não permite enfileirar eventos deste webhook.';
    end if;
  end if;

  if not (p_evento=any(v.eventos)) then
    raise exception 'Evento não habilitado para o webhook.';
  end if;

  v_hash:=encode(extensions.digest(coalesce(p_payload_ref,'{}'::jsonb)::text,'sha256'),'hex');

  insert into public.eventos_webhook(
    id_organizacao,id_webhook,evento,entidade_tipo,entidade_id,
    payload_ref,payload_hash,status,proxima_tentativa
  )
  values(
    v.id_organizacao,v.id,p_evento,p_entidade_tipo,p_entidade_id,
    coalesce(p_payload_ref,'{}'::jsonb),v_hash,'enfileirado',now()
  )
  returning id into v_evt;

  perform privado.enfileirar_job(
    'webhooks',v.id_organizacao,null,'evento_webhook',v_evt,
    jsonb_build_object('id_evento_webhook',v_evt),
    'webhook:'||v_evt::text
  );

  return v_evt;
end;
$$;

commit;
