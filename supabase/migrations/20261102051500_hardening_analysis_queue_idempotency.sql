begin;

create unique index if not exists execucoes_analise_uma_ativa_por_competencia_idx
on public.execucoes_analise(id_competencia)
where status in ('pendente','processando');

create or replace function privado.solicitar_analise_competencia(
  p_id_competencia uuid,
  p_tipo text default 'completa'
) returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v public.competencias%rowtype;
  v_exec uuid;
  v_snapshot jsonb;
  v_hash text;
begin
  select * into v
  from public.competencias
  where id=p_id_competencia
  for update;

  if v.id is null then
    raise exception 'Não encontramos a competência informada.';
  end if;
  if p_tipo not in ('completa','reanálise','parcial') then
    raise exception 'O tipo de análise informado não é válido.';
  end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then
    raise exception 'Seu usuário não possui acesso a este contrato.';
  end if;
  if not privado.usuario_possui_perfil(
    v.id_organizacao,
    array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]
  ) then
    raise exception 'Seu perfil atual não permite solicitar esta análise.';
  end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then
    raise exception 'A situação atual desta competência não permite iniciar uma nova análise.';
  end if;

  -- Idempotência operacional e proteção contra clique duplo/race condition/cost abuse.
  select ea.id into v_exec
  from public.execucoes_analise ea
  where ea.id_competencia=v.id
    and ea.status in ('pendente','processando')
  order by ea.criado_em desc
  limit 1;

  if v_exec is not null then
    return v_exec;
  end if;

  v_snapshot:=privado.snapshot_contexto_competencia(v.id);
  v_hash:=encode(extensions.digest(v_snapshot::text,'sha256'),'hex');

  insert into public.execucoes_analise(
    id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,motor,
    versao_motor,prompt_versao,iniciada_por,iniciada_em,snapshot_entrada
  ) values(
    v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente',v_hash,'contaos',
    '4.1','analise-pt-BR-v4.1',auth.uid(),now(),v_snapshot
  ) returning id into v_exec;

  update public.competencias
  set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end
  where id=v.id;

  perform privado.enfileirar_job(
    'ai',v.id_organizacao,v.id_contrato,'execucao_analise',v_exec,
    jsonb_build_object('entidade_tipo','execucao_analise','id_execucao',v_exec,'id_competencia',v.id),
    'analysis:'||v_exec::text
  );

  perform privado.registrar_evento_auditoria(
    v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,
    jsonb_build_object('id_competencia',v.id,'tipo',p_tipo,'hash_entrada',v_hash,'versao_snapshot','4.1')
  );
  return v_exec;
end;
$function$;

commit;
