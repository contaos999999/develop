begin;

-- 1) Regras preventivas: fonte, motivo e aprovação humana explícita.
alter table public.regras_preventivas add column if not exists fonte jsonb not null default '{}'::jsonb;
alter table public.regras_preventivas add column if not exists motivo text;
alter table public.regras_preventivas add column if not exists aprovada_por uuid references auth.users(id) on delete set null;
alter table public.regras_preventivas add column if not exists aprovada_em timestamptz;

create or replace function privado.aprovar_regra_preventiva(p_id_regra_preventiva uuid,p_parecer text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.regras_preventivas%rowtype; v_revisao uuid;
begin
  select * into v from public.regras_preventivas where id=p_id_regra_preventiva for update;
  if v.id is null then raise exception 'Não encontramos a regra preventiva informada.'; end if;
  if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
  if not privado.usuario_tem_acesso_organizacao(v.id_organizacao) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then
    raise exception 'Seu perfil atual não permite aprovar esta regra preventiva.';
  end if;
  if v.situacao <> 'candidata' then raise exception 'Somente uma regra candidata pode ser aprovada.'; end if;
  if nullif(trim(v.codigo_regra),'') is null or nullif(trim(v.descricao),'') is null then raise exception 'A regra precisa de código e descrição antes da aprovação.'; end if;
  if v.escopo_aplicacao='contrato' and v.id_contrato is null then raise exception 'Informe o contrato ao qual esta regra se aplica.'; end if;
  if v.escopo_aplicacao='contratante' and v.id_contratante is null then raise exception 'Informe o contratante ao qual esta regra se aplica.'; end if;
  if v.escopo_aplicacao='tipo_contrato' and nullif(trim(coalesce(v.tipo_contrato,'')),'') is null then raise exception 'Informe o tipo de contrato ao qual esta regra se aplica.'; end if;
  if v.origem_precedente is null and v.fonte='{}'::jsonb then raise exception 'Inclua a fonte que fundamenta esta regra antes de aprová-la.'; end if;
  update public.regras_preventivas set situacao='ativa',aprovada_por=auth.uid(),aprovada_em=now() where id=v.id;
  insert into public.revisoes_regras_preventivas(id_organizacao,id_contrato,id_regra,versao,decisao,fundamento,revisor,snapshot)
  values(v.id_organizacao,v.id_contrato,v.id,v.numero_versao,'aprovada',coalesce(nullif(trim(p_parecer),''),'Regra preventiva aprovada após revisão humana.'),auth.uid(),jsonb_build_object('codigo_regra',v.codigo_regra,'escopo_aplicacao',v.escopo_aplicacao,'efeito',v.efeito,'criticidade',v.criticidade,'fonte',v.fonte,'origem_precedente',v.origem_precedente))
  returning id into v_revisao;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraPreventivaAprovada','regras_preventivas',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','ativa','id_revisao',v_revisao));
  return v_revisao;
end;$$;
revoke all on function privado.aprovar_regra_preventiva(uuid,text) from public,anon;
grant execute on function privado.aprovar_regra_preventiva(uuid,text) to authenticated;

create or replace function public.aprovar_regra_preventiva(p_id_regra_preventiva uuid,p_parecer text default null)
returns uuid language sql security invoker set search_path='' as $$select privado.aprovar_regra_preventiva($1,$2)$$;
revoke all on function public.aprovar_regra_preventiva(uuid,text) from public,anon;
grant execute on function public.aprovar_regra_preventiva(uuid,text) to authenticated;

-- Nome oficial do contrato de arquitetura 4.1.
create or replace function public.publicar_controle_conformidade(p_id_controle uuid,p_texto text,p_evidencia_requerida jsonb,p_vigencia_inicio date,p_vigencia_fim date default null)
returns uuid language sql security invoker set search_path='' as $$select privado.publicar_controle($1,$2,$3,$4,$5)$$;
revoke all on function public.publicar_controle_conformidade(uuid,text,jsonb,date,date) from public,anon;
grant execute on function public.publicar_controle_conformidade(uuid,text,jsonb,date,date) to authenticated;

-- Encerramento de NC exige remediação concluída e evidência.
create or replace function privado.encerrar_nao_conformidade(p_id_nao_conformidade uuid,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.nao_conformidades%rowtype;
begin
 select * into v from public.nao_conformidades where id=p_id_nao_conformidade for update;
 if v.id is null then raise exception 'Não encontramos a não conformidade informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite encerrar esta não conformidade.'; end if;
 if exists(select 1 from public.planos_remediacao where id_nao_conformidade=v.id and status not in ('concluido','cancelado')) then raise exception 'Ainda existem ações de remediação pendentes. Conclua ou cancele essas ações antes de encerrar.'; end if;
 if not exists(select 1 from public.planos_remediacao where id_nao_conformidade=v.id and status='concluido' and jsonb_typeof(evidencias)='array' and jsonb_array_length(evidencias)>0) then raise exception 'Para encerrar, conclua ao menos um plano de remediação e registre a evidência correspondente.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento do encerramento.'; end if;
 update public.nao_conformidades set status='encerrada' where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'NaoConformidadeEncerrada','nao_conformidades',v.id,jsonb_build_object('status',v.status),jsonb_build_object('status','encerrada','fundamento',p_fundamento));
end;$$;

-- 2) Rate limit e autenticação de clientes API.
alter table public.clientes_api add column if not exists limite_por_minuto integer not null default 60 check(limite_por_minuto between 1 and 10000);

create table privado.consumo_rate_limit_api(
  id_cliente uuid not null references public.clientes_api(id) on delete cascade,
  janela_inicio timestamptz not null,
  quantidade integer not null default 0,
  atualizado_em timestamptz not null default now(),
  primary key(id_cliente,janela_inicio)
);
revoke all on privado.consumo_rate_limit_api from public,anon,authenticated;

create or replace function public.api_autenticar_cliente(p_identificador text,p_secret text,p_escopo text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.clientes_api%rowtype; v_janela timestamptz; v_qtd integer;
begin
  select * into v from public.clientes_api where identificador=p_identificador and ativo=true;
  if v.id is null or v.secret_hash <> encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex') then
    return jsonb_build_object('autorizado',false,'codigo','CREDENCIAL_INVALIDA','titulo','Credencial não reconhecida','mensagem','Não foi possível validar a credencial desta integração.');
  end if;
  if not exists(select 1 from public.escopos_clientes_api e where e.id_cliente=v.id and e.escopo=p_escopo) then
    return jsonb_build_object('autorizado',false,'codigo','ESCOPO_NAO_PERMITIDO','titulo','Operação não permitida','mensagem','Esta credencial não possui permissão para a operação solicitada.');
  end if;
  v_janela:=date_trunc('minute',now());
  insert into privado.consumo_rate_limit_api(id_cliente,janela_inicio,quantidade) values(v.id,v_janela,1)
  on conflict(id_cliente,janela_inicio) do update set quantidade=privado.consumo_rate_limit_api.quantidade+1,atualizado_em=now()
  returning quantidade into v_qtd;
  if v_qtd>v.limite_por_minuto then
    return jsonb_build_object('autorizado',false,'codigo','LIMITE_REQUISICOES','titulo','Muitas solicitações em pouco tempo','mensagem','Recebemos várias solicitações seguidas. Aguarde alguns instantes e tente novamente.','tentar_novamente_em_segundos',greatest(1,60-extract(second from now())::integer));
  end if;
  update public.clientes_api set ultimo_uso_em=now() where id=v.id;
  return jsonb_build_object('autorizado',true,'id_cliente',v.id,'id_organizacao',v.id_organizacao,'escopo',p_escopo,'limite_por_minuto',v.limite_por_minuto,'restantes',greatest(0,v.limite_por_minuto-v_qtd));
end;$$;
revoke all on function public.api_autenticar_cliente(text,text,text) from public,anon,authenticated;
grant execute on function public.api_autenticar_cliente(text,text,text) to service_role;

-- 3) Concorrência otimista: toda tabela editável com versao_registro passa a exigir versão seguinte em atualização direta do usuário.
create or replace function privado.controlar_versao_registro()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_user='authenticated' then
    if new.versao_registro <> old.versao_registro + 1 then
      raise exception using errcode='40001', message='Este registro foi atualizado por outra pessoa. Atualize a tela, confira a versão mais recente e tente novamente.';
    end if;
  else
    new.versao_registro:=old.versao_registro+1;
  end if;
  return new;
end;$$;
revoke all on function privado.controlar_versao_registro() from public,anon,authenticated;

do $$
declare r record; v_trigger text;
begin
  for r in
    select c.table_name
    from information_schema.columns c
    join information_schema.tables t on t.table_schema=c.table_schema and t.table_name=c.table_name and t.table_type='BASE TABLE'
    where c.table_schema='public' and c.column_name='versao_registro'
  loop
    v_trigger:=left('contaos_versao_'||r.table_name,63);
    execute format('drop trigger if exists %I on public.%I',v_trigger,r.table_name);
    execute format('create trigger %I before update on public.%I for each row execute function privado.controlar_versao_registro()',v_trigger,r.table_name);
  end loop;
end $$;

-- 4) Cron passa a invocar os nomes oficiais das Edge Functions do pacote 4.1.
create or replace function privado.invocar_edge_oficial(p_slug text,p_max_jobs integer default 3)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_request_id bigint;
begin
  if p_slug not in ('queue-worker-documents','queue-worker-ocr','queue-worker-ai','queue-worker-embeddings','queue-worker-finance','generate-report','deliver-webhook','notify-user') then raise exception 'Processador interno inválido.'; end if;
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='contaos_project_url') || '/functions/v1/' || p_slug,
    headers := jsonb_build_object('Content-Type','application/json','x-contaos-internal-token',(select decrypted_secret from vault.decrypted_secrets where name='contaos_internal_worker_token')),
    body := jsonb_build_object('max_jobs',least(greatest(p_max_jobs,1),10)), timeout_milliseconds := 10000
  ) into v_request_id;
  return v_request_id;
end;$$;
revoke all on function privado.invocar_edge_oficial(text,integer) from public,anon,authenticated;

select cron.unschedule(jobid) from cron.job where jobname in ('contaos-workers-rapidos','contaos-workers-pesados');
select cron.schedule('contaos-workers-rapidos','20 seconds',$cron$
  select privado.invocar_edge_oficial('queue-worker-documents',3);
  select privado.invocar_edge_oficial('queue-worker-embeddings',5);
  select privado.invocar_edge_oficial('queue-worker-ai',2);
  select privado.invocar_edge_oficial('deliver-webhook',3);
$cron$);
select cron.schedule('contaos-workers-pesados','* * * * *',$cron$
  select privado.invocar_edge_oficial('queue-worker-finance',2);
  select privado.invocar_edge_oficial('generate-report',2);
  select privado.invocar_edge_oficial('notify-user',5);
  select privado.invocar_edge_oficial('queue-worker-ocr',2);
$cron$);

commit;
