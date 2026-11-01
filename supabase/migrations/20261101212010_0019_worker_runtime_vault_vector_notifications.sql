begin;

alter table public.fragmentos_documento alter column embedding type extensions.vector(384) using embedding::extensions.vector(384);
alter table public.precedentes alter column embedding type extensions.vector(384) using embedding::extensions.vector(384);
alter table public.consultas_semanticas add column if not exists embedding extensions.vector(384);
create index if not exists fragmentos_documento_embedding_hnsw on public.fragmentos_documento using hnsw (embedding extensions.vector_cosine_ops) where embedding is not null;
create index if not exists precedentes_embedding_hnsw on public.precedentes using hnsw (embedding extensions.vector_cosine_ops) where embedding is not null;

create or replace function privado.uuid_seguro(p_texto text)
returns uuid language plpgsql immutable set search_path='' as $$
begin
  if p_texto is null or p_texto !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then return null; end if;
  return p_texto::uuid;
exception when others then return null;
end;$$;
revoke all on function privado.uuid_seguro(text) from public,anon;
grant execute on function privado.uuid_seguro(text) to authenticated;

drop policy if exists contaos_storage_select on storage.objects;
drop policy if exists contaos_storage_insert on storage.objects;
create policy contaos_storage_select on storage.objects for select to authenticated
using(bucket_id='contaos-documentos' and privado.uuid_seguro((storage.foldername(name))[1]) is not null and privado.usuario_tem_acesso_organizacao(privado.uuid_seguro((storage.foldername(name))[1])));
create policy contaos_storage_insert on storage.objects for insert to authenticated
with check(bucket_id='contaos-documentos' and privado.uuid_seguro((storage.foldername(name))[1]) is not null and privado.usuario_tem_acesso_organizacao(privado.uuid_seguro((storage.foldername(name))[1])));

create table public.jobs_dlq (
  id uuid primary key default gen_random_uuid(), fila text not null, message_id bigint not null,
  id_execucao uuid references public.execucoes_assincronas(id) on delete set null,
  id_organizacao uuid references public.organizacoes(id) on delete restrict,
  id_contrato uuid references public.contratos(id) on delete restrict,
  payload jsonb not null default '{}'::jsonb, tentativas integer not null, erro_codigo text, erro_detalhe text,
  correlation_id uuid, movido_em timestamptz not null default now(), constraint jobs_dlq_uk unique(fila,message_id)
);
alter table public.jobs_dlq enable row level security;
create policy jobs_dlq_select on public.jobs_dlq for select to authenticated using(id_organizacao is not null and privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create index jobs_dlq_org_idx on public.jobs_dlq(id_organizacao,fila,movido_em desc);

create table privado.configuracoes_internas (chave text primary key,valor_hash text not null,atualizado_em timestamptz not null default now());
revoke all on privado.configuracoes_internas from public,anon,authenticated;

do $$
declare v_token text; v_url text := 'https://gklhhhyosgasnyoxlrui.supabase.co';
begin
  select decrypted_secret into v_token from vault.decrypted_secrets where name='contaos_internal_worker_token' limit 1;
  if v_token is null then
    v_token := encode(extensions.gen_random_bytes(48),'hex');
    perform vault.create_secret(v_token,'contaos_internal_worker_token','Token interno HML para Cron -> Edge Functions ContaOS');
  end if;
  insert into privado.configuracoes_internas(chave,valor_hash)
  values('worker_token_hash',encode(extensions.digest(v_token,'sha256'),'hex'))
  on conflict(chave) do update set valor_hash=excluded.valor_hash,atualizado_em=now();
  if not exists(select 1 from vault.secrets where name='contaos_project_url') then
    perform vault.create_secret(v_url,'contaos_project_url','URL do projeto Supabase HML ContaOS');
  end if;
end $$;

create or replace function public.validar_token_interno(p_token text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from privado.configuracoes_internas c where c.chave='worker_token_hash' and c.valor_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex'))
$$;
revoke all on function public.validar_token_interno(text) from public,anon,authenticated;
grant execute on function public.validar_token_interno(text) to service_role;

create or replace function public.worker_pull_job(p_fila text,p_visibility_seconds integer default 120)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_msg bigint; v_read integer; v_payload jsonb; v_exec uuid;
begin
  if p_fila not in ('documents','ocr','ai','embeddings','finance_imports','reports','integrations','webhooks') then raise exception 'Fila inválida.'; end if;
  select q.msg_id,q.read_ct,q.message into v_msg,v_read,v_payload from pgmq.read(p_fila,greatest(p_visibility_seconds,30),1) q limit 1;
  if v_msg is null then return null; end if;
  select id into v_exec from public.execucoes_assincronas where fila=p_fila and message_id=v_msg order by criado_em desc limit 1;
  if v_exec is not null then
    update public.execucoes_assincronas
       set status='processando',tentativas=v_read,iniciado_em=coalesce(iniciado_em,now()),erro_codigo=null,erro_detalhe=null,
           metadados=jsonb_set(coalesce(metadados,'{}'::jsonb),'{payload}',coalesce(v_payload,'{}'::jsonb),true)
     where id=v_exec;
  end if;
  return jsonb_build_object('msg_id',v_msg,'read_ct',v_read,'payload',v_payload,'id_execucao',v_exec);
end;$$;
revoke all on function public.worker_pull_job(text,integer) from public,anon,authenticated;
grant execute on function public.worker_pull_job(text,integer) to service_role;

create or replace function public.worker_enfileirar_job(p_fila text,p_id_organizacao uuid,p_id_contrato uuid,p_entidade_tipo text,p_entidade_id uuid,p_payload jsonb,p_chave_idempotencia text default null)
returns uuid language sql security definer set search_path='' as $$ select privado.enfileirar_job($1,$2,$3,$4,$5,$6,$7) $$;
revoke all on function public.worker_enfileirar_job(text,uuid,uuid,text,uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.worker_enfileirar_job(text,uuid,uuid,text,uuid,jsonb,text) to service_role;

create or replace function public.worker_finalizar_job(p_fila text,p_msg_id bigint,p_sucesso boolean,p_erro_codigo text default null,p_erro_detalhe text default null,p_max_tentativas integer default 5)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_exec public.execucoes_assincronas%rowtype; v_removed boolean:=false; v_payload jsonb:='{}'::jsonb;
begin
  select * into v_exec from public.execucoes_assincronas where fila=p_fila and message_id=p_msg_id order by criado_em desc limit 1;
  if v_exec.id is null then raise exception 'Execução assíncrona não encontrada.'; end if;
  if p_sucesso then
    select pgmq.delete(p_fila,p_msg_id) into v_removed;
    update public.execucoes_assincronas set status='concluido',concluido_em=now(),erro_codigo=null,erro_detalhe=null where id=v_exec.id;
    return jsonb_build_object('status','concluido','removido',v_removed,'tentativas',v_exec.tentativas);
  end if;
  update public.execucoes_assincronas set status='falhou',erro_codigo=p_erro_codigo,erro_detalhe=left(p_erro_detalhe,4000),concluido_em=null where id=v_exec.id;
  if v_exec.tentativas >= greatest(p_max_tentativas,1) then
    v_payload:=coalesce(v_exec.metadados->'payload','{}'::jsonb);
    insert into public.jobs_dlq(fila,message_id,id_execucao,id_organizacao,id_contrato,payload,tentativas,erro_codigo,erro_detalhe,correlation_id)
    values(p_fila,p_msg_id,v_exec.id,v_exec.id_organizacao,v_exec.id_contrato,v_payload,v_exec.tentativas,p_erro_codigo,left(p_erro_detalhe,4000),v_exec.correlation_id)
    on conflict(fila,message_id) do nothing;
    select pgmq.delete(p_fila,p_msg_id) into v_removed;
    update public.execucoes_assincronas set status='cancelado',concluido_em=now() where id=v_exec.id;
    return jsonb_build_object('status','dlq','removido',v_removed,'tentativas',v_exec.tentativas);
  end if;
  return jsonb_build_object('status','retry','removido',false,'tentativas',v_exec.tentativas);
end;$$;
revoke all on function public.worker_finalizar_job(text,bigint,boolean,text,text,integer) from public,anon,authenticated;
grant execute on function public.worker_finalizar_job(text,bigint,boolean,text,text,integer) to service_role;

create or replace function public.worker_buscar_fragmentos(p_id_organizacao uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 8)
returns table(id uuid,id_versao_documento uuid,pagina_inicio integer,pagina_fim integer,texto text,similaridade double precision)
language sql stable security definer set search_path='' as $$
  select f.id,f.id_versao_documento,f.pagina_inicio,f.pagina_fim,f.texto,(1-(f.embedding OPERATOR(extensions.<=>) p_embedding))::double precision
  from public.fragmentos_documento f
  where f.id_organizacao=p_id_organizacao and f.id_contrato=p_id_contrato and f.embedding is not null
  order by f.embedding OPERATOR(extensions.<=>) p_embedding
  limit least(greatest(p_limite,1),20)
$$;
revoke all on function public.worker_buscar_fragmentos(uuid,uuid,extensions.vector,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_fragmentos(uuid,uuid,extensions.vector,integer) to service_role;

create table public.preferencias_notificacao (
 id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
 id_usuario uuid not null references auth.users(id) on delete cascade,evento text not null,
 canal text not null default 'in_app' check(canal in ('in_app','email')),habilitado boolean not null default true,
 criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now(),constraint preferencias_notificacao_uk unique(id_organizacao,id_usuario,evento,canal));
create table public.notificacoes (
 id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_usuario uuid not null references auth.users(id) on delete cascade,evento text not null,titulo text not null,mensagem text not null,
 canal text not null check(canal in ('in_app','email')),status text not null default 'pendente' check(status in ('pendente','enviada','falhou','lida','cancelada')),
 entidade_tipo text,entidade_id uuid,erro text,enviada_em timestamptz,lida_em timestamptz,criado_em timestamptz not null default now());
alter table public.preferencias_notificacao enable row level security;
alter table public.notificacoes enable row level security;
create policy preferencias_notificacao_select on public.preferencias_notificacao for select to authenticated using(id_usuario=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy preferencias_notificacao_insert on public.preferencias_notificacao for insert to authenticated with check(id_usuario=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy preferencias_notificacao_update on public.preferencias_notificacao for update to authenticated using(id_usuario=(select auth.uid())) with check(id_usuario=(select auth.uid()));
create policy notificacoes_select on public.notificacoes for select to authenticated using(id_usuario=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy notificacoes_update on public.notificacoes for update to authenticated using(id_usuario=(select auth.uid())) with check(id_usuario=(select auth.uid()));
create trigger preferencias_notificacao_touch before update on public.preferencias_notificacao for each row execute function privado.tocar_atualizado_em();
create index notificacoes_usuario_idx on public.notificacoes(id_usuario,status,criado_em desc);

create or replace function privado.criar_notificacao(p_id_organizacao uuid,p_id_usuario uuid,p_evento text,p_titulo text,p_mensagem text,p_entidade_tipo text default null,p_entidade_id uuid default null)
returns integer language plpgsql security definer set search_path='' as $$
declare v_count int:=0; v_canal text;
begin
  for v_canal in
    select p.canal from public.preferencias_notificacao p where p.id_organizacao=p_id_organizacao and p.id_usuario=p_id_usuario and p.evento=p_evento and p.habilitado=true
    union all select 'in_app' where not exists(select 1 from public.preferencias_notificacao p where p.id_organizacao=p_id_organizacao and p.id_usuario=p_id_usuario and p.evento=p_evento)
  loop
    insert into public.notificacoes(id_organizacao,id_usuario,evento,titulo,mensagem,canal,entidade_tipo,entidade_id)
    values(p_id_organizacao,p_id_usuario,p_evento,p_titulo,p_mensagem,v_canal,p_entidade_tipo,p_entidade_id);
    v_count:=v_count+1;
  end loop;
  if v_count>0 then
    perform privado.enfileirar_job('integrations',p_id_organizacao,null,'notificacao',p_id_usuario,jsonb_build_object('id_organizacao',p_id_organizacao,'id_usuario',p_id_usuario,'evento',p_evento),p_evento||':'||p_id_usuario::text||':'||coalesce(p_entidade_id::text,extract(epoch from now())::text));
  end if;
  return v_count;
end;$$;
revoke all on function privado.criar_notificacao(uuid,uuid,text,text,text,text,uuid) from public,anon,authenticated;

alter table public.assinaturas_eventos_integracao add column if not exists vault_secret_name text;
alter table public.webhooks add column if not exists rotacionado_em timestamptz;

create or replace function privado.criar_webhook(p_id_organizacao uuid,p_nome text,p_url text,p_eventos text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_secret text; v_hash text; v_id uuid; v_secret_name text;
begin
 if auth.uid() is null or not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_url !~ '^https://' then raise exception 'Webhook exige HTTPS.'; end if;
 v_secret:='whs_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 insert into public.webhooks(id_organizacao,nome,url,eventos,secret_hash,criado_por) values(p_id_organizacao,p_nome,p_url,coalesce(p_eventos,'{}'::text[]),v_hash,auth.uid()) returning id into v_id;
 v_secret_name:='contaos_webhook_'||v_id::text||'_v1';
 perform vault.create_secret(v_secret,v_secret_name,'Webhook ContaOS HML '||v_id::text||' versão 1');
 insert into public.assinaturas_eventos_integracao(id_organizacao,id_webhook,versao,secret_hash,vault_secret_name,criado_por) values(p_id_organizacao,v_id,1,v_hash,v_secret_name,auth.uid());
 perform privado.registrar_evento_auditoria(p_id_organizacao,'WebhookCriado','webhooks',v_id,null,jsonb_build_object('url',p_url,'eventos',p_eventos));
 return jsonb_build_object('id',v_id,'secret_uma_vez',v_secret);
end;$$;

create or replace function privado.rotacionar_webhook(p_id_webhook uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.webhooks%rowtype; v_secret text; v_hash text; v_ver int; v_name text;
begin
 select * into v from public.webhooks where id=p_id_webhook for update;
 if v.id is null then raise exception 'Webhook não encontrado.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 select coalesce(max(versao),0)+1 into v_ver from public.assinaturas_eventos_integracao where id_webhook=v.id;
 v_secret:='whs_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex'); v_name:='contaos_webhook_'||v.id::text||'_v'||v_ver::text;
 perform vault.create_secret(v_secret,v_name,'Webhook ContaOS HML '||v.id::text||' versão '||v_ver::text);
 update public.assinaturas_eventos_integracao set ativo=false,valido_ate=now() where id_webhook=v.id and ativo=true;
 insert into public.assinaturas_eventos_integracao(id_organizacao,id_webhook,versao,secret_hash,vault_secret_name,criado_por) values(v.id_organizacao,v.id,v_ver,v_hash,v_name,auth.uid());
 update public.webhooks set secret_hash=v_hash,rotacionado_em=now() where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'WebhookSecretRotacionado','webhooks',v.id,null,jsonb_build_object('versao',v_ver));
 return jsonb_build_object('id',v.id,'versao',v_ver,'secret_uma_vez',v_secret);
end;$$;

create function public.rotacionar_webhook(p_id_webhook uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.rotacionar_webhook($1)$$;
revoke all on function public.rotacionar_webhook(uuid) from public,anon;
grant execute on function public.rotacionar_webhook(uuid) to authenticated;

create or replace function public.worker_obter_webhook(p_id_evento uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_evt public.eventos_webhook%rowtype; v_wh public.webhooks%rowtype; v_name text; v_secret text;
begin
 select * into v_evt from public.eventos_webhook where id=p_id_evento;
 if v_evt.id is null then raise exception 'Evento webhook não encontrado.'; end if;
 select * into v_wh from public.webhooks where id=v_evt.id_webhook and ativo=true;
 if v_wh.id is null then raise exception 'Webhook inativo ou inexistente.'; end if;
 select vault_secret_name into v_name from public.assinaturas_eventos_integracao where id_webhook=v_wh.id and ativo=true order by versao desc limit 1;
 select decrypted_secret into v_secret from vault.decrypted_secrets where name=v_name;
 if v_secret is null then raise exception 'Segredo do webhook indisponível.'; end if;
 return jsonb_build_object('id_evento',v_evt.id,'url',v_wh.url,'evento',v_evt.evento,'payload',v_evt.payload_ref,'secret',v_secret,'tentativa',v_evt.tentativa,'correlation_id',v_evt.correlation_id);
end;$$;
revoke all on function public.worker_obter_webhook(uuid) from public,anon,authenticated;
grant execute on function public.worker_obter_webhook(uuid) to service_role;

create or replace function public.worker_registrar_entrega_webhook(p_id_evento uuid,p_sucesso boolean,p_status_http integer,p_resposta_hash text default null,p_erro text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 update public.eventos_webhook set tentativa=tentativa+1,status=case when p_sucesso then 'entregue' else 'falhou' end,status_http=p_status_http,resposta_hash=p_resposta_hash,entregue_em=case when p_sucesso then now() else null end,proxima_tentativa=case when p_sucesso then null else now()+make_interval(secs=>least(3600,(power(2,least(tentativa+1,10))::int*30))) end where id=p_id_evento;
 if p_erro is not null then perform privado.registrar_evento_auditoria((select id_organizacao from public.eventos_webhook where id=p_id_evento),'WebhookFalhou','eventos_webhook',p_id_evento,null,jsonb_build_object('erro',left(p_erro,1000),'status_http',p_status_http)); end if;
end;$$;
revoke all on function public.worker_registrar_entrega_webhook(uuid,boolean,integer,text,text) from public,anon,authenticated;
grant execute on function public.worker_registrar_entrega_webhook(uuid,boolean,integer,text,text) to service_role;

commit;
