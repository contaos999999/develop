begin;

select pgmq.create('documents');
select pgmq.create('ocr');
select pgmq.create('ai');
select pgmq.create('embeddings');
select pgmq.create('finance_imports');
select pgmq.create('reports');
select pgmq.create('integrations');
select pgmq.create('webhooks');

create table public.execucoes_assincronas (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid references public.organizacoes(id) on delete restrict,
  id_contrato uuid references public.contratos(id) on delete restrict,
  fila text not null check(fila in ('documents','ocr','ai','embeddings','finance_imports','reports','integrations','webhooks')),
  entidade_tipo text,
  entidade_id uuid,
  chave_idempotencia text,
  message_id bigint,
  status text not null default 'enfileirado' check(status in ('enfileirado','processando','concluido','falhou','cancelado')),
  tentativas integer not null default 0,
  erro_codigo text,
  erro_detalhe text,
  correlation_id uuid not null default gen_random_uuid(),
  metadados jsonb not null default '{}'::jsonb,
  iniciado_em timestamptz,
  concluido_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create unique index execucoes_assincronas_idem_uidx on public.execucoes_assincronas(id_organizacao,fila,chave_idempotencia) where chave_idempotencia is not null;
create index execucoes_assincronas_status_idx on public.execucoes_assincronas(fila,status,criado_em);
create index execucoes_assincronas_entidade_idx on public.execucoes_assincronas(entidade_tipo,entidade_id);

alter table public.execucoes_assincronas enable row level security;
create policy execucoes_assincronas_select on public.execucoes_assincronas for select to authenticated using(id_organizacao is not null and privado.usuario_tem_acesso_organizacao(id_organizacao));

create trigger execucoes_assincronas_touch before update on public.execucoes_assincronas for each row execute function privado.tocar_atualizado_em();

create or replace function privado.enfileirar_job(
  p_fila text,
  p_id_organizacao uuid,
  p_id_contrato uuid,
  p_entidade_tipo text,
  p_entidade_id uuid,
  p_payload jsonb,
  p_chave_idempotencia text default null
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v_exec uuid; v_msg bigint; v_exist uuid;
begin
  if p_fila not in ('documents','ocr','ai','embeddings','finance_imports','reports','integrations','webhooks') then raise exception 'Fila inválida.'; end if;
  if p_chave_idempotencia is not null then
    select id into v_exist from public.execucoes_assincronas where id_organizacao=p_id_organizacao and fila=p_fila and chave_idempotencia=p_chave_idempotencia;
    if v_exist is not null then return v_exist; end if;
  end if;
  select pgmq.send(p_fila,coalesce(p_payload,'{}'::jsonb) || jsonb_build_object('id_organizacao',p_id_organizacao,'id_contrato',p_id_contrato,'entidade_tipo',p_entidade_tipo,'entidade_id',p_entidade_id)) into v_msg;
  insert into public.execucoes_assincronas(id_organizacao,id_contrato,fila,entidade_tipo,entidade_id,chave_idempotencia,message_id)
  values(p_id_organizacao,p_id_contrato,p_fila,p_entidade_tipo,p_entidade_id,p_chave_idempotencia,v_msg) returning id into v_exec;
  return v_exec;
end;$$;
revoke all on function privado.enfileirar_job(text,uuid,uuid,text,uuid,jsonb,text) from public,anon,authenticated;

create or replace function public.enfileirar_processamento_documento(p_id_versao_documento uuid,p_chave_idempotencia text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_contrato uuid; v_exec uuid;
begin
  select id_organizacao,id_contrato into v_org,v_contrato from public.versoes_documento where id=p_id_versao_documento;
  if v_org is null then raise exception 'Versão documental não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v_org,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  v_exec:=privado.enfileirar_job('documents',v_org,v_contrato,'versao_documento',p_id_versao_documento,jsonb_build_object('id_versao_documento',p_id_versao_documento),coalesce(p_chave_idempotencia,'document:'||p_id_versao_documento::text));
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
  values(v_org,v_contrato,p_id_versao_documento,'documents','pendente');
  return v_exec;
end;$$;
revoke all on function public.enfileirar_processamento_documento(uuid,text) from public;
grant execute on function public.enfileirar_processamento_documento(uuid,text) to authenticated;

create or replace function privado.marcar_execucao_assincrona(p_id uuid,p_status text,p_erro_codigo text default null,p_erro_detalhe text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
  update public.execucoes_assincronas
  set status=p_status,
      tentativas=case when p_status='processando' then tentativas+1 else tentativas end,
      iniciado_em=case when p_status='processando' and iniciado_em is null then now() else iniciado_em end,
      concluido_em=case when p_status in ('concluido','falhou','cancelado') then now() else concluido_em end,
      erro_codigo=p_erro_codigo,
      erro_detalhe=p_erro_detalhe
  where id=p_id;
end;$$;
revoke all on function privado.marcar_execucao_assincrona(uuid,text,text,text) from public,anon,authenticated;

commit;
