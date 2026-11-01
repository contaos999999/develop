begin;

create table public.clientes_api (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 nome text not null, identificador text not null, secret_hash text not null, ativo boolean not null default true,
 ultimo_uso_em timestamptz, rotacionado_em timestamptz, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint clientes_api_identificador_uk unique(identificador));
create index clientes_api_org_idx on public.clientes_api(id_organizacao,ativo);

create table public.escopos_clientes_api (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_cliente uuid not null references public.clientes_api(id) on delete cascade, escopo text not null, criado_em timestamptz not null default now(),
 constraint escopos_clientes_api_uk unique(id_cliente,escopo));

create table public.webhooks (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 nome text, url text not null, eventos text[] not null default '{}'::text[], secret_hash text not null,
 ativo boolean not null default true, headers_publicos jsonb not null default '{}'::jsonb,
 criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint webhooks_url_ck check(url ~ '^https://'));
create index webhooks_org_idx on public.webhooks(id_organizacao,ativo);

create table public.assinaturas_eventos_integracao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_webhook uuid references public.webhooks(id) on delete cascade, versao integer not null, algoritmo text not null default 'hmac-sha256',
 secret_hash text not null, ativo boolean not null default true, valido_desde timestamptz not null default now(), valido_ate timestamptz,
 criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now(),
 constraint assinaturas_webhook_versao_uk unique(id_webhook,versao));
create index assinaturas_eventos_integracao_idx on public.assinaturas_eventos_integracao(id_organizacao,id_webhook,ativo,versao desc);

create table public.eventos_webhook (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_webhook uuid not null references public.webhooks(id) on delete restrict, evento text not null, entidade_tipo text, entidade_id uuid,
 payload_ref jsonb not null default '{}'::jsonb, payload_hash text not null, tentativa integer not null default 0,
 status text not null default 'pendente' check(status in ('pendente','enfileirado','entregue','falhou','cancelado')),
 status_http integer, resposta_hash text, proxima_tentativa timestamptz, entregue_em timestamptz,
 correlation_id uuid not null default gen_random_uuid(), criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index eventos_webhook_fila_idx on public.eventos_webhook(status,proxima_tentativa,criado_em);
create index eventos_webhook_org_idx on public.eventos_webhook(id_organizacao,id_webhook,criado_em desc);

create table public.pacotes_evidencias (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, escopo jsonb not null, hash text,
 status text not null default 'preparando' check(status in ('preparando','congelado','disponivel','expirado','revogado','falhou')),
 id_arquivo_exportacao uuid references public.arquivos(id) on delete restrict, expira_em timestamptz,
 criado_por uuid references auth.users(id) on delete set null, congelado_em timestamptz, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index pacotes_evidencias_idx on public.pacotes_evidencias(id_organizacao,status,expira_em);

create table public.itens_pacote_evidencias (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict, entidade_tipo text not null, entidade_id uuid,
 versao_id uuid, hash text not null, metadados jsonb not null default '{}'::jsonb, ordem integer not null default 0, criado_em timestamptz not null default now());
create index itens_pacote_evidencias_idx on public.itens_pacote_evidencias(id_pacote,ordem);

create table public.acessos_pacote_evidencias (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict, token_hash text not null,
 descricao_destinatario text, expira_em timestamptz not null, max_acessos integer, quantidade_acessos integer not null default 0,
 revogado_em timestamptz, criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now(),
 constraint acessos_pacote_token_uk unique(token_hash));
create index acessos_pacote_evidencias_idx on public.acessos_pacote_evidencias(id_pacote,expira_em,revogado_em);

create table public.exportacoes_evidencias (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict, formato text not null,
 id_arquivo uuid references public.arquivos(id) on delete restrict, hash text not null, tamanho bigint,
 exportado_por uuid references auth.users(id) on delete set null, exportado_em timestamptz not null default now(), metadados jsonb not null default '{}'::jsonb);
create index exportacoes_evidencias_idx on public.exportacoes_evidencias(id_pacote,exportado_em desc);

alter table public.clientes_api enable row level security; alter table public.escopos_clientes_api enable row level security;
alter table public.webhooks enable row level security; alter table public.assinaturas_eventos_integracao enable row level security;
alter table public.eventos_webhook enable row level security; alter table public.pacotes_evidencias enable row level security;
alter table public.itens_pacote_evidencias enable row level security; alter table public.acessos_pacote_evidencias enable row level security;
alter table public.exportacoes_evidencias enable row level security;

create policy clientes_api_select on public.clientes_api for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy escopos_clientes_api_select on public.escopos_clientes_api for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy webhooks_select on public.webhooks for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy assinaturas_eventos_select on public.assinaturas_eventos_integracao for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy eventos_webhook_select on public.eventos_webhook for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy pacotes_evidencias_select on public.pacotes_evidencias for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy itens_pacote_evidencias_select on public.itens_pacote_evidencias for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy acessos_pacote_evidencias_select on public.acessos_pacote_evidencias for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy exportacoes_evidencias_select on public.exportacoes_evidencias for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));

create trigger clientes_api_touch before update on public.clientes_api for each row execute function privado.tocar_atualizado_em();
create trigger webhooks_touch before update on public.webhooks for each row execute function privado.tocar_atualizado_em();
create trigger eventos_webhook_touch before update on public.eventos_webhook for each row execute function privado.tocar_atualizado_em();
create trigger pacotes_evidencias_touch before update on public.pacotes_evidencias for each row execute function privado.tocar_atualizado_em();

create or replace function public.criar_cliente_api(p_id_organizacao uuid,p_nome text,p_escopos text[] default '{}'::text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_secret text; v_hash text; v_id uuid; v_ident text; v_scope text;
begin
 if not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 v_secret:='cos_'||encode(extensions.gen_random_bytes(32),'hex');
 v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 v_ident:='cli_'||encode(extensions.gen_random_bytes(12),'hex');
 insert into public.clientes_api(id_organizacao,nome,identificador,secret_hash,criado_por) values(p_id_organizacao,p_nome,v_ident,v_hash,auth.uid()) returning id into v_id;
 foreach v_scope in array coalesce(p_escopos,'{}'::text[]) loop insert into public.escopos_clientes_api(id_organizacao,id_cliente,escopo) values(p_id_organizacao,v_id,v_scope) on conflict do nothing; end loop;
 perform privado.registrar_evento_auditoria(p_id_organizacao,'ClienteApiCriado','clientes_api',v_id,null,jsonb_build_object('identificador',v_ident,'escopos',p_escopos));
 return jsonb_build_object('id',v_id,'identificador',v_ident,'secret_uma_vez',v_secret);
end;$$;
revoke all on function public.criar_cliente_api(uuid,text,text[]) from public;
grant execute on function public.criar_cliente_api(uuid,text,text[]) to authenticated;

create or replace function public.rotacionar_cliente_api(p_id_cliente uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.clientes_api%rowtype; v_secret text; v_hash text;
begin
 select * into v from public.clientes_api where id=p_id_cliente for update;
 if v.id is null then raise exception 'Cliente API não encontrado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 v_secret:='cos_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 update public.clientes_api set secret_hash=v_hash,rotacionado_em=now() where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ClienteApiRotacionado','clientes_api',v.id,null,jsonb_build_object('rotacionado_em',now()));
 return jsonb_build_object('id',v.id,'identificador',v.identificador,'secret_uma_vez',v_secret);
end;$$;
revoke all on function public.rotacionar_cliente_api(uuid) from public;
grant execute on function public.rotacionar_cliente_api(uuid) to authenticated;

create or replace function public.criar_webhook(p_id_organizacao uuid,p_nome text,p_url text,p_eventos text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_secret text; v_hash text; v_id uuid;
begin
 if not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_url !~ '^https://' then raise exception 'Webhook exige HTTPS.'; end if;
 v_secret:='whs_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 insert into public.webhooks(id_organizacao,nome,url,eventos,secret_hash,criado_por) values(p_id_organizacao,p_nome,p_url,coalesce(p_eventos,'{}'::text[]),v_hash,auth.uid()) returning id into v_id;
 insert into public.assinaturas_eventos_integracao(id_organizacao,id_webhook,versao,secret_hash,criado_por) values(p_id_organizacao,v_id,1,v_hash,auth.uid());
 perform privado.registrar_evento_auditoria(p_id_organizacao,'WebhookCriado','webhooks',v_id,null,jsonb_build_object('url',p_url,'eventos',p_eventos));
 return jsonb_build_object('id',v_id,'secret_uma_vez',v_secret);
end;$$;
revoke all on function public.criar_webhook(uuid,text,text,text[]) from public;
grant execute on function public.criar_webhook(uuid,text,text,text[]) to authenticated;

create or replace function public.enfileirar_evento_webhook(p_id_webhook uuid,p_evento text,p_entidade_tipo text,p_entidade_id uuid,p_payload_ref jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.webhooks%rowtype; v_evt uuid; v_hash text;
begin
 select * into v from public.webhooks where id=p_id_webhook and ativo=true;
 if v.id is null then raise exception 'Webhook não encontrado ou inativo.'; end if;
 if auth.uid() is not null and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if not (p_evento=any(v.eventos)) then raise exception 'Evento não habilitado para o webhook.'; end if;
 v_hash:=encode(extensions.digest(coalesce(p_payload_ref,'{}'::jsonb)::text,'sha256'),'hex');
 insert into public.eventos_webhook(id_organizacao,id_webhook,evento,entidade_tipo,entidade_id,payload_ref,payload_hash,status,proxima_tentativa)
 values(v.id_organizacao,v.id,p_evento,p_entidade_tipo,p_entidade_id,coalesce(p_payload_ref,'{}'::jsonb),v_hash,'enfileirado',now()) returning id into v_evt;
 perform privado.enfileirar_job('webhooks',v.id_organizacao,null,'evento_webhook',v_evt,jsonb_build_object('id_evento_webhook',v_evt),'webhook:'||v_evt::text);
 return v_evt;
end;$$;
revoke all on function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) from public;
grant execute on function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) to authenticated;

create or replace function public.criar_pacote_evidencias(p_id_organizacao uuid,p_id_contrato uuid,p_escopo jsonb,p_expira_em timestamptz default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not privado.usuario_tem_acesso_organizacao(p_id_organizacao) then raise exception 'Acesso negado.'; end if;
 if p_id_contrato is not null and not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Contrato sem acesso.'; end if;
 insert into public.pacotes_evidencias(id_organizacao,id_contrato,escopo,status,expira_em,criado_por)
 values(p_id_organizacao,p_id_contrato,coalesce(p_escopo,'{}'::jsonb),'preparando',p_expira_em,auth.uid()) returning id into v_id;
 perform privado.enfileirar_job('reports',p_id_organizacao,p_id_contrato,'pacote_evidencias',v_id,jsonb_build_object('id_pacote',v_id),'evidence-package:'||v_id::text);
 return v_id;
end;$$;
revoke all on function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) from public;
grant execute on function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) to authenticated;

create or replace function public.criar_acesso_temporario_pacote(p_id_pacote uuid,p_expira_em timestamptz,p_descricao_destinatario text default null,p_max_acessos integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.pacotes_evidencias%rowtype; v_token text; v_hash text; v_id uuid;
begin
 select * into v from public.pacotes_evidencias where id=p_id_pacote;
 if v.id is null then raise exception 'Pacote não encontrado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_expira_em<=now() then raise exception 'Expiração deve ser futura.'; end if;
 v_token:='ev_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
 insert into public.acessos_pacote_evidencias(id_organizacao,id_pacote,token_hash,descricao_destinatario,expira_em,max_acessos,criado_por)
 values(v.id_organizacao,v.id,v_hash,p_descricao_destinatario,p_expira_em,p_max_acessos,auth.uid()) returning id into v_id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AcessoPacoteEvidenciasCriado','acessos_pacote_evidencias',v_id,null,jsonb_build_object('id_pacote',v.id,'expira_em',p_expira_em));
 return jsonb_build_object('id',v_id,'token_uma_vez',v_token);
end;$$;
revoke all on function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) from public;
grant execute on function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) to authenticated;

commit;
