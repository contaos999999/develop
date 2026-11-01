begin;

create table public.configuracao_api (
  id boolean primary key default true check(id=true),
  tamanho_pagina_padrao integer not null default 25 check(tamanho_pagina_padrao between 1 and 100),
  tamanho_pagina_maximo integer not null default 100 check(tamanho_pagina_maximo between 1 and 500),
  timeout_integracao_ms integer not null default 10000 check(timeout_integracao_ms between 1000 and 60000),
  max_tentativas_integracao integer not null default 5 check(max_tentativas_integracao between 1 and 20),
  atualizado_em timestamptz not null default now()
);
alter table public.configuracao_api enable row level security;
create policy configuracao_api_leitura on public.configuracao_api for select to anon,authenticated using(true);
revoke all on public.configuracao_api from anon,authenticated;
grant select on public.configuracao_api to anon,authenticated;
insert into public.configuracao_api(id) values(true) on conflict(id) do nothing;

create or replace function public.normalizar_paginacao(p_pagina integer default 1,p_tamanho integer default 25)
returns jsonb language sql stable security invoker set search_path='' as $$
  select jsonb_build_object(
    'pagina',greatest(coalesce(p_pagina,1),1),
    'tamanho',least(greatest(coalesce(p_tamanho,(select tamanho_pagina_padrao from public.configuracao_api where id=true)),1),(select tamanho_pagina_maximo from public.configuracao_api where id=true)),
    'offset',(greatest(coalesce(p_pagina,1),1)-1)*least(greatest(coalesce(p_tamanho,(select tamanho_pagina_padrao from public.configuracao_api where id=true)),1),(select tamanho_pagina_maximo from public.configuracao_api where id=true))
  )
$$;
revoke all on function public.normalizar_paginacao(integer,integer) from public;
grant execute on function public.normalizar_paginacao(integer,integer) to anon,authenticated;

create table public.alertas_operacionais (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid references public.organizacoes(id) on delete cascade,
  codigo text not null,
  severidade text not null check(severidade in ('info','aviso','erro','critico')),
  titulo text not null,
  mensagem text not null,
  entidade_tipo text,
  entidade_id uuid,
  status text not null default 'aberto' check(status in ('aberto','reconhecido','resolvido')),
  primeira_ocorrencia timestamptz not null default now(),
  ultima_ocorrencia timestamptz not null default now(),
  ocorrencias integer not null default 1,
  metadados jsonb not null default '{}'::jsonb,
  reconhecido_por uuid references auth.users(id) on delete set null,
  reconhecido_em timestamptz,
  resolvido_em timestamptz,
  criado_em timestamptz not null default now()
);
create unique index alertas_operacionais_aberto_uidx on public.alertas_operacionais(coalesce(id_organizacao,'00000000-0000-0000-0000-000000000000'::uuid),codigo,coalesce(entidade_id,'00000000-0000-0000-0000-000000000000'::uuid)) where status='aberto';
create index alertas_operacionais_org_idx on public.alertas_operacionais(id_organizacao,status,severidade,ultima_ocorrencia desc);
alter table public.alertas_operacionais enable row level security;
create policy alertas_operacionais_select on public.alertas_operacionais for select to authenticated using(id_organizacao is not null and privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));

create or replace function privado.registrar_alerta_operacional(p_id_organizacao uuid,p_codigo text,p_severidade text,p_titulo text,p_mensagem text,p_entidade_tipo text default null,p_entidade_id uuid default null,p_metadados jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  insert into public.alertas_operacionais(id_organizacao,codigo,severidade,titulo,mensagem,entidade_tipo,entidade_id,metadados)
  values(p_id_organizacao,p_codigo,p_severidade,p_titulo,p_mensagem,p_entidade_tipo,p_entidade_id,coalesce(p_metadados,'{}'::jsonb))
  on conflict(coalesce(id_organizacao,'00000000-0000-0000-0000-000000000000'::uuid),codigo,coalesce(entidade_id,'00000000-0000-0000-0000-000000000000'::uuid)) where status='aberto'
  do update set ultima_ocorrencia=now(),ocorrencias=public.alertas_operacionais.ocorrencias+1,mensagem=excluded.mensagem,metadados=excluded.metadados
  returning id into v_id;
  return v_id;
end;$$;
revoke all on function privado.registrar_alerta_operacional(uuid,text,text,text,text,text,uuid,jsonb) from public,anon,authenticated;

create or replace function privado.verificar_saude_operacional()
returns integer language plpgsql security definer set search_path='' as $$
declare r record; v_total int:=0;
begin
  for r in
    select id_organizacao,count(*) qtd from public.jobs_dlq where movido_em>=now()-interval '24 hours' and id_organizacao is not null group by id_organizacao
  loop
    perform privado.registrar_alerta_operacional(r.id_organizacao,'JOBS_DLQ_24H',case when r.qtd>=10 then 'critico' else 'erro' end,'Processamentos precisam de atenção','Existem '||r.qtd||' processamento(s) enviados para a fila de análise técnica nas últimas 24 horas.','jobs_dlq',null,jsonb_build_object('quantidade',r.qtd)); v_total:=v_total+1;
  end loop;
  for r in
    select id_organizacao,count(*) qtd from public.execucoes_assincronas where status='falhou' and criado_em>=now()-interval '1 hour' and id_organizacao is not null group by id_organizacao having count(*)>=5
  loop
    perform privado.registrar_alerta_operacional(r.id_organizacao,'FALHAS_ASSINCRONAS_1H','aviso','Falhas repetidas de processamento','Foram identificadas '||r.qtd||' falhas de processamento na última hora. O ContaOS continuará aplicando as políticas de nova tentativa.','execucoes_assincronas',null,jsonb_build_object('quantidade',r.qtd)); v_total:=v_total+1;
  end loop;
  return v_total;
end;$$;
revoke all on function privado.verificar_saude_operacional() from public,anon,authenticated;
select cron.schedule('contaos-saude-operacional','*/5 * * * *',$cron$select privado.verificar_saude_operacional();$cron$);

create or replace function privado.obter_saude_operacional(p_id_organizacao uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_jobs jsonb; v_dlq int; v_storage jsonb; v_alertas int; v_cron jsonb;
begin
  if auth.uid() is null or not privado.usuario_possui_perfil(p_id_organizacao,array['administrador','auditor']::text[]) then raise exception 'Seu perfil atual não permite consultar a saúde operacional.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('fila',fila,'status',status,'quantidade',qtd)),'[]'::jsonb) into v_jobs from (select fila,status,count(*) qtd from public.execucoes_assincronas where id_organizacao=p_id_organizacao and criado_em>=now()-interval '24 hours' group by fila,status order by fila,status) x;
  select count(*) into v_dlq from public.jobs_dlq where id_organizacao=p_id_organizacao and movido_em>=now()-interval '24 hours';
  select jsonb_build_object('arquivos',count(*),'bytes',coalesce(sum(tamanho),0)) into v_storage from public.arquivos where id_organizacao=p_id_organizacao;
  select count(*) into v_alertas from public.alertas_operacionais where id_organizacao=p_id_organizacao and status='aberto';
  select coalesce(jsonb_agg(jsonb_build_object('job',jobname,'ativo',active,'agenda',schedule)),'[]'::jsonb) into v_cron from cron.job where jobname like 'contaos-%';
  return jsonb_build_object('timezone','America/Sao_Paulo','gerado_em',public.formatar_data_hora_br(now()),'jobs_24h',v_jobs,'dlq_24h',v_dlq,'storage',v_storage,'alertas_abertos',v_alertas,'cron',v_cron);
end;$$;
create or replace function public.obter_saude_operacional(p_id_organizacao uuid)
returns jsonb language sql stable security invoker set search_path='' as $$select privado.obter_saude_operacional($1)$$;
revoke all on function public.obter_saude_operacional(uuid) from public,anon;
grant execute on function public.obter_saude_operacional(uuid) to authenticated;

-- Circuit breaker lógico para webhooks externos.
alter table public.webhooks add column if not exists falhas_consecutivas integer not null default 0;
alter table public.webhooks add column if not exists circuito_aberto_ate timestamptz;

create or replace function public.worker_obter_webhook(p_id_evento uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_evt public.eventos_webhook%rowtype; v_wh public.webhooks%rowtype; v_name text; v_secret text;
begin
 select * into v_evt from public.eventos_webhook where id=p_id_evento;
 if v_evt.id is null then raise exception 'Evento de integração não encontrado.'; end if;
 select * into v_wh from public.webhooks where id=v_evt.id_webhook and ativo=true;
 if v_wh.id is null then raise exception 'A integração está inativa ou não foi encontrada.'; end if;
 if v_wh.circuito_aberto_ate is not null and v_wh.circuito_aberto_ate>now() then raise exception 'A integração está temporariamente pausada após falhas consecutivas. O ContaOS tentará novamente automaticamente.'; end if;
 select vault_secret_name into v_name from public.assinaturas_eventos_integracao where id_webhook=v_wh.id and ativo=true order by versao desc limit 1;
 select decrypted_secret into v_secret from vault.decrypted_secrets where name=v_name;
 if v_secret is null then raise exception 'A credencial interna desta integração não está disponível.'; end if;
 return jsonb_build_object('id_evento',v_evt.id,'url',v_wh.url,'evento',v_evt.evento,'payload',v_evt.payload_ref,'secret',v_secret,'tentativa',v_evt.tentativa,'correlation_id',v_evt.correlation_id);
end;$$;
revoke all on function public.worker_obter_webhook(uuid) from public,anon,authenticated;
grant execute on function public.worker_obter_webhook(uuid) to service_role;

create or replace function public.worker_registrar_entrega_webhook(p_id_evento uuid,p_sucesso boolean,p_status_http integer,p_resposta_hash text default null,p_erro text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_webhook uuid; v_org uuid; v_falhas int;
begin
 select id_webhook,id_organizacao into v_webhook,v_org from public.eventos_webhook where id=p_id_evento;
 update public.eventos_webhook set tentativa=tentativa+1,status=case when p_sucesso then 'entregue' else 'falhou' end,status_http=p_status_http,resposta_hash=p_resposta_hash,entregue_em=case when p_sucesso then now() else null end,proxima_tentativa=case when p_sucesso then null else now()+make_interval(secs=>least(3600,(power(2,least(tentativa+1,10))::int*30))) end where id=p_id_evento;
 if p_sucesso then
   update public.webhooks set falhas_consecutivas=0,circuito_aberto_ate=null where id=v_webhook;
 else
   update public.webhooks set falhas_consecutivas=falhas_consecutivas+1 where id=v_webhook returning falhas_consecutivas into v_falhas;
   if v_falhas>=5 then
     update public.webhooks set circuito_aberto_ate=now()+interval '15 minutes' where id=v_webhook;
     perform privado.registrar_alerta_operacional(v_org,'WEBHOOK_CIRCUITO_ABERTO','erro','Integração temporariamente pausada','Uma integração foi pausada por 15 minutos após cinco falhas consecutivas. O ContaOS tentará novamente automaticamente.','webhooks',v_webhook,jsonb_build_object('falhas_consecutivas',v_falhas));
   end if;
   if p_erro is not null then perform privado.registrar_evento_auditoria(v_org,'WebhookFalhou','eventos_webhook',p_id_evento,null,jsonb_build_object('erro_resumido',left(p_erro,500),'status_http',p_status_http)); end if;
 end if;
end;$$;
revoke all on function public.worker_registrar_entrega_webhook(uuid,boolean,integer,text,text) from public,anon,authenticated;
grant execute on function public.worker_registrar_entrega_webhook(uuid,boolean,integer,text,text) to service_role;

-- Nova alteração normativa entra automaticamente na fila de comparação.
create or replace function privado.enfileirar_alteracao_normativa()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform privado.enfileirar_job('integrations',new.id_organizacao,null,'avaliacao_impacto_normativo',new.id,jsonb_build_object('entidade_tipo','avaliacao_impacto_normativo','id_alteracao',new.id),'normativo:'||new.id::text);
  update public.alteracoes_normativas set status='em_avaliacao' where id=new.id;
  return new;
end;$$;
revoke all on function privado.enfileirar_alteracao_normativa() from public,anon,authenticated;
drop trigger if exists contaos_alteracao_normativa_queue on public.alteracoes_normativas;
create trigger contaos_alteracao_normativa_queue after insert on public.alteracoes_normativas for each row execute function privado.enfileirar_alteracao_normativa();

commit;
