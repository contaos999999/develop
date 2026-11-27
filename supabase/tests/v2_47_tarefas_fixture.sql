-- Baseline isolado. Os escopos e a infraestrutura externos são sintéticos.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create schema privado;
create schema extensions;
create extension pgcrypto with schema extensions;
grant usage on schema public,auth,privado to authenticated,service_role,anon;

create function auth.uid() returns uuid language sql stable set search_path='' as $$
  select nullif(current_setting('contaos.fixture.ator',true),'')::uuid
$$;
create function privado.sessao_usuario_ativa() returns boolean language sql stable set search_path='' as $$
  select auth.uid() is not null
$$;


create schema pgmq;
create table auth.users (id uuid primary key);
create table public.organizacoes (id uuid primary key);
create table public.contratos (id uuid primary key,id_organizacao uuid not null references public.organizacoes);
create table public.competencias (
  id uuid primary key,id_organizacao uuid not null references public.organizacoes,
  id_contrato uuid not null references public.contratos
);
create table public.perfis_usuarios (codigo text primary key);
create table public.documentos_contrato (id uuid primary key);
create table public.arquivos (id uuid primary key);
create table public.usuarios (
  id_usuario uuid primary key references auth.users(id) on delete cascade,
  nome text,
  email text,
  telefone text,
  situacao text not null default 'ativo' check (situacao in ('ativo','inativo')),
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table public.vinculos_usuarios (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_usuario uuid not null references auth.users(id) on delete cascade,
  perfil text not null references public.perfis_usuarios(codigo),
  escopo_todos_contratos boolean not null default false,
  ativo boolean not null default true,
  inicio_em timestamptz not null default now(),
  fim_em timestamptz,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint vinculo_periodo_ck check (fim_em is null or fim_em > inicio_em),
  constraint vinculo_usuario_org_uk unique(id_usuario,id_organizacao)
);

create table public.vinculos_usuario_contratos (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  id_vinculo_usuario uuid not null references public.vinculos_usuarios(id) on delete cascade,
  id_contrato uuid not null,
  criado_em timestamptz not null default now(),
  constraint vinculo_contrato_uk unique(id_vinculo_usuario,id_contrato)
);

create table public.eventos_auditoria (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid references public.organizacoes(id) on delete restrict,
  id_usuario uuid references auth.users(id) on delete set null,
  origem text not null default 'usuario',
  evento text not null,
  entidade text not null,
  id_entidade uuid,
  antes jsonb,
  depois jsonb,
  metadados jsonb not null default '{}'::jsonb,
  correlation_id uuid not null default gen_random_uuid(),
  criado_em timestamptz not null default now()
);

create table public.comandos_idempotentes (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  comando text not null,
  chave text not null,
  hash_payload text,
  status text not null default 'iniciado' check(status in ('iniciado','concluido','falhou')),
  resposta jsonb,
  expira_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint comandos_idempotentes_uk unique(id_organizacao,comando,chave)
);
create table public.documentos_competencia(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_competencia uuid not null,tipo text not null,titulo text not null,categoria text,id_requisito_competencia uuid,situacao text not null default 'ativo' check(situacao in ('ativo','inativo','substituido')),versao_atual integer not null default 0,versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now());

create table public.versoes_documento(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_documento_contrato uuid references public.documentos_contrato(id) on delete restrict,id_documento_competencia uuid references public.documentos_competencia(id) on delete restrict,id_documento uuid generated always as (coalesce(id_documento_contrato,id_documento_competencia)) stored,numero_versao integer not null,id_arquivo uuid not null references public.arquivos(id) on delete restrict,hash text not null,motivo_substituicao text,metadados_extraidos jsonb not null default '{}'::jsonb,enviado_por uuid references auth.users(id) on delete set null,criado_em timestamptz not null default now(),constraint versoes_documento_escopo_ck check(num_nonnulls(id_documento_contrato,id_documento_competencia)=1),constraint versoes_documento_contrato_uk unique(id_documento_contrato,numero_versao),constraint versoes_documento_competencia_uk unique(id_documento_competencia,numero_versao));
create table public.ciclos_diligencia (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 numero_rodada integer not null, status text not null default 'aberto' check(status in ('aberto','em_tratamento','pronto_reapresentar','reapresentado','encerrado')),
 recebido_em timestamptz not null default now(), prazo_resposta date, encerrado_em timestamptz, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(), constraint ciclos_diligencia_uk unique(id_competencia,numero_rodada));

create table public.apontamentos_contratante (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, codigo text, descricao text not null, fundamento text,
 status text not null default 'aberto' check(status in ('aberto','em_analise','procedente','nao_procedente','em_tratamento','resolvido','contestado','contestado_aprovado','encerrado')),
 severidade text not null default 'media' check(severidade in ('baixa','media','alta','critica')), fonte_pagina integer, fonte_trecho text,
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());

create table public.analises_apontamentos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_apontamento uuid not null references public.apontamentos_contratante(id) on delete restrict,
 classificacao text not null check(classificacao in ('procedente','parcialmente_procedente','nao_procedente','inconclusivo')),
 fundamento text not null, evidencias jsonb not null default '[]'::jsonb, revisado_por uuid references auth.users(id) on delete set null,
 revisado_em timestamptz, criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now());

create table public.planos_acao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, titulo text not null, descricao text,
 responsavel uuid references auth.users(id) on delete set null, status text not null default 'aberto' check(status in ('aberto','em_execucao','concluido','cancelado')),
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());

create table public.tarefas_diligencia (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, id_plano uuid references public.planos_acao(id) on delete restrict,
 id_apontamento uuid references public.apontamentos_contratante(id) on delete restrict, descricao text not null,
 responsavel uuid references auth.users(id) on delete set null, prazo date, status text not null default 'pendente' check(status in ('pendente','em_execucao','concluida','cancelada')),
 id_evidencia_versao_documento uuid references public.versoes_documento(id) on delete restrict, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
alter table public.tarefas_diligencia add column if not exists tipo_acao text;
alter table public.tarefas_diligencia add column if not exists prioridade text not null default 'media' check(prioridade in ('baixa','media','alta','critica'));
alter table public.tarefas_diligencia add column if not exists depende_de uuid[] not null default '{}'::uuid[];
alter table public.tarefas_diligencia add column if not exists validacao_solucao text not null default 'pendente' check(validacao_solucao in ('pendente','em_analise','aprovada','rejeitada'));
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

-- Apenas o transporte assíncrono e a sessão são substituídos neste ambiente.
create table pgmq.mensagens (id bigint generated always as identity primary key,fila text,payload jsonb);
create function pgmq.send(p_fila text,p_payload jsonb) returns bigint language sql as $$
  insert into pgmq.mensagens(fila,payload) values(p_fila,p_payload) returning id
$$;
create or replace function privado.tocar_atualizado_em()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em = now();
  if to_jsonb(new) ? 'versao_registro' then
    new.versao_registro = coalesce(new.versao_registro, 0) + 1;
  end if;
  return new;
end;
$$;

create or replace function privado.registrar_evento_auditoria(
  p_id_organizacao uuid,
  p_evento text,
  p_entidade text,
  p_id_entidade uuid,
  p_antes jsonb default null,
  p_depois jsonb default null,
  p_metadados jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  insert into public.eventos_auditoria(id_organizacao,id_usuario,origem,evento,entidade,id_entidade,antes,depois,metadados)
  values (p_id_organizacao,auth.uid(),case when auth.uid() is null then 'sistema' else 'usuario' end,p_evento,p_entidade,p_id_entidade,p_antes,p_depois,coalesce(p_metadados,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$$;

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

create or replace function privado.v107_iniciar(p_org uuid,p_comando text,p_chave text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.comandos_idempotentes%rowtype; v_nome text:=p_comando||':'||auth.uid()::text;
v_hash text:=encode(extensions.digest(p_payload::text,'sha256'),'hex');
begin
  if auth.uid() is null or not privado.sessao_usuario_ativa() then raise exception using errcode='42501',message='Sua sessão não está ativa.'; end if;
  if p_chave is null or length(btrim(p_chave)) not between 1 and 200 then raise exception using errcode='PT400',message='Informe uma chave de operação válida.'; end if;
  insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,expira_em)
  values(p_org,v_nome,p_chave,v_hash,'iniciado',now()+interval '24 hours')
  on conflict(id_organizacao,comando,chave) do nothing returning * into v;
  if v.id is null then
    select * into v from public.comandos_idempotentes where id_organizacao=p_org and comando=v_nome and chave=p_chave for update;
    if v.hash_payload is distinct from v_hash then raise exception using errcode='PT409',message='Esta chave de operação já foi usada com dados diferentes.'; end if;
    if v.status='concluido' and v.resposta is not null then return jsonb_build_object('id',v.id,'resposta',v.resposta); end if;
    raise exception using errcode='PT409',message='Esta operação já está em processamento. Atualize a tela.';
  end if;
  return jsonb_build_object('id',v.id);
end $$;

create trigger tarefas_diligencia_touch before update on public.tarefas_diligencia
  for each row execute function privado.tocar_atualizado_em();

create function privado.usuario_possui_perfil(p_org uuid,p_perfis text[]) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.vinculos_usuarios v join public.usuarios u on u.id_usuario=v.id_usuario
    where v.id_usuario=auth.uid() and u.situacao='ativo' and v.id_organizacao=p_org and v.ativo
      and v.inicio_em<=now() and (v.fim_em is null or v.fim_em>now()) and v.perfil=any(p_perfis))
$$;
create function privado.usuario_tem_acesso_contrato(p_contrato uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.contratos c join public.vinculos_usuarios v on v.id_organizacao=c.id_organizacao
    where c.id=p_contrato and v.id_usuario=auth.uid() and v.ativo and v.inicio_em<=now()
      and (v.fim_em is null or v.fim_em>now()) and (v.escopo_todos_contratos or exists (
        select 1 from public.vinculos_usuario_contratos vc where vc.id_vinculo_usuario=v.id and vc.id_contrato=c.id)))
$$;

alter table public.tarefas_diligencia enable row level security;
alter table public.planos_acao enable row level security;
create policy tarefas_select on public.tarefas_diligencia for select to authenticated
  using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy planos_select on public.planos_acao for select to authenticated
  using(privado.usuario_tem_acesso_contrato(id_contrato));
grant select,insert on public.tarefas_diligencia to authenticated;
grant select,insert,update on public.planos_acao to authenticated;
grant select,insert,update,delete on public.tarefas_diligencia,public.planos_acao to service_role;
grant usage on schema extensions to authenticated,service_role;

create or replace function privado.atualizar_tarefa_diligencia(p_id_tarefa uuid,p_descricao text default null,p_responsavel uuid default null,p_prazo date default null)
returns void language plpgsql security definer set search_path='' as $$
declare v public.tarefas_diligencia%rowtype;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Tarefa não encontrada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if v.status in ('concluida','cancelada') then raise exception 'Tarefa encerrada não pode ser editada.'; end if;
 update public.tarefas_diligencia set descricao=coalesce(p_descricao,descricao),responsavel=coalesce(p_responsavel,responsavel),prazo=coalesce(p_prazo,prazo),status=case when status='pendente' then 'em_execucao' else status end where id=v.id;
end;$$;
revoke all on function privado.atualizar_tarefa_diligencia(uuid, text, uuid, date) from public,anon;
grant execute on function privado.atualizar_tarefa_diligencia(uuid, text, uuid, date) to authenticated;
create function public.atualizar_tarefa_diligencia(p_id_tarefa uuid,p_descricao text default null,p_responsavel uuid default null,p_prazo date default null)
returns void language sql security invoker set search_path='' as $$select privado.atualizar_tarefa_diligencia($1,$2,$3,$4)$$;
revoke all on function public.atualizar_tarefa_diligencia(uuid, text, uuid, date) from public,anon;
grant execute on function public.atualizar_tarefa_diligencia(uuid, text, uuid, date) to authenticated;

create or replace function privado.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v public.tarefas_diligencia%rowtype;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Não encontramos a tarefa informada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
 if v.responsavel is not null and v.responsavel<>auth.uid() and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Somente o responsável pela tarefa ou um perfil autorizado pode concluí-la.'; end if;
 if exists(select 1 from unnest(v.depende_de) d where not exists(select 1 from public.tarefas_diligencia t where t.id=d and t.status='concluida' and t.validacao_solucao='aprovada')) then raise exception 'Esta tarefa possui dependências que ainda não foram concluídas e validadas.'; end if;
 if p_id_evidencia_versao_documento is null or not exists(select 1 from public.versoes_documento vd where vd.id=p_id_evidencia_versao_documento and vd.id_contrato=v.id_contrato) then raise exception 'Inclua uma evidência válida antes de concluir a tarefa.'; end if;
 update public.tarefas_diligencia set status='concluida',id_evidencia_versao_documento=p_id_evidencia_versao_documento,validacao_solucao='em_analise' where id=v.id;
 if v.id_apontamento is not null then
   update public.apontamentos_contratante set status='em_tratamento' where id=v.id_apontamento and status not in ('encerrado','resolvido');
   perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'revalidar_apontamento',v.id_apontamento,jsonb_build_object('entidade_tipo','revalidar_apontamento','id_apontamento',v.id_apontamento,'id_tarefa',v.id,'id_evidencia',p_id_evidencia_versao_documento),'revalidar-apontamento:'||v.id_apontamento::text||':'||p_id_evidencia_versao_documento::text);
 end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'TarefaDiligenciaConcluida','tarefas_diligencia',v.id,null,jsonb_build_object('id_evidencia',p_id_evidencia_versao_documento,'validacao_solucao','em_analise'));
end;$$;
revoke all on function privado.concluir_tarefa_diligencia(uuid, uuid) from public,anon;
grant execute on function privado.concluir_tarefa_diligencia(uuid, uuid) to authenticated;
create function public.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language sql security invoker set search_path='' as $$select privado.concluir_tarefa_diligencia($1,$2)$$;
revoke all on function public.concluir_tarefa_diligencia(uuid, uuid) from public,anon;
grant execute on function public.concluir_tarefa_diligencia(uuid, uuid) to authenticated;

create or replace function privado.revisar_solucao_tarefa_diligencia(p_id_tarefa uuid,p_aprovar boolean,p_fundamento text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.tarefas_diligencia%rowtype; v_abertas integer:=0;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Não encontramos a tarefa informada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso a este contrato.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite revisar a solução desta tarefa.'; end if;
 if v.status<>'concluida' or v.validacao_solucao<>'em_analise' then raise exception 'A tarefa precisa estar concluída e aguardando validação antes desta revisão.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento da revisão para manter a rastreabilidade.'; end if;
 update public.tarefas_diligencia set validacao_solucao=case when p_aprovar then 'aprovada' else 'rejeitada' end,status=case when p_aprovar then 'concluida' else 'em_execucao' end where id=v.id;
 if v.id_apontamento is not null then
   if p_aprovar then
     select count(*) into v_abertas from public.tarefas_diligencia t where t.id_apontamento=v.id_apontamento and t.id<>v.id and (t.status not in ('concluida','cancelada') or (t.status='concluida' and t.validacao_solucao<>'aprovada'));
     if v_abertas=0 then update public.apontamentos_contratante set status='resolvido' where id=v.id_apontamento and status in ('procedente','em_tratamento','em_analise'); end if;
   else
     update public.apontamentos_contratante set status='em_tratamento' where id=v.id_apontamento and status<>'encerrado';
   end if;
 end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'SolucaoTarefaDiligenciaRevisada','tarefas_diligencia',v.id,null,jsonb_build_object('aprovada',p_aprovar,'fundamento',p_fundamento,'revisor',auth.uid()));
 return jsonb_build_object('id_tarefa',v.id,'validacao_solucao',case when p_aprovar then 'aprovada' else 'rejeitada' end,'mensagem',case when p_aprovar then 'A solução foi validada e o fluxo foi atualizado.' else 'A solução foi devolvida para ajuste.' end);
end; $$;
revoke all on function privado.revisar_solucao_tarefa_diligencia(uuid, boolean, text) from public,anon;
grant execute on function privado.revisar_solucao_tarefa_diligencia(uuid, boolean, text) to authenticated;
create or replace function public.revisar_solucao_tarefa_diligencia(p_id_tarefa uuid,p_aprovar boolean,p_fundamento text)
returns jsonb language sql security invoker set search_path='' as $$ select privado.revisar_solucao_tarefa_diligencia($1,$2,$3); $$;
revoke all on function public.revisar_solucao_tarefa_diligencia(uuid, boolean, text) from public,anon;
grant execute on function public.revisar_solucao_tarefa_diligencia(uuid, boolean, text) to authenticated;

-- Identificadores determinísticos exclusivos do teste.
create schema fixture;
create function fixture.id(n integer) returns uuid language sql immutable as $$
  select ('47000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;
grant usage on schema fixture to authenticated,anon,service_role;

insert into auth.users(id) select fixture.id(x) from generate_series(1,6) x;
insert into public.usuarios(id_usuario,nome)
  select fixture.id(x),'Pessoa sintética '||x from generate_series(1,6) x;
insert into public.perfis_usuarios(codigo) values ('gestor_contrato'),('leitor'),('auditor');
insert into public.organizacoes values (fixture.id(11)),(fixture.id(12));
insert into public.contratos values (fixture.id(21),fixture.id(11)),(fixture.id(22),fixture.id(12)),
  (fixture.id(23),fixture.id(11));
insert into public.competencias values
  (fixture.id(31),fixture.id(11),fixture.id(21)),(fixture.id(32),fixture.id(11),fixture.id(21)),
  (fixture.id(33),fixture.id(12),fixture.id(22)),(fixture.id(34),fixture.id(11),fixture.id(23));
insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos) values
  (fixture.id(41),fixture.id(11),fixture.id(1),'gestor_contrato',true),
  (fixture.id(42),fixture.id(11),fixture.id(2),'leitor',false),
  (fixture.id(43),fixture.id(11),fixture.id(3),'auditor',true),
  (fixture.id(44),fixture.id(11),fixture.id(4),'leitor',false),
  (fixture.id(45),fixture.id(12),fixture.id(5),'gestor_contrato',true),
  (fixture.id(46),fixture.id(11),fixture.id(6),'leitor',false);
insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato) values
  (fixture.id(11),fixture.id(42),fixture.id(21)),(fixture.id(11),fixture.id(44),fixture.id(21)),
  (fixture.id(11),fixture.id(46),fixture.id(23));
insert into public.ciclos_diligencia(id,id_organizacao,id_contrato,id_competencia,numero_rodada,status) values
  (fixture.id(101),fixture.id(11),fixture.id(21),fixture.id(31),1,'aberto'),
  (fixture.id(102),fixture.id(11),fixture.id(21),fixture.id(31),2,'aberto'),
  (fixture.id(103),fixture.id(11),fixture.id(21),fixture.id(32),1,'aberto'),
  (fixture.id(104),fixture.id(12),fixture.id(22),fixture.id(33),1,'aberto'),
  (fixture.id(105),fixture.id(11),fixture.id(23),fixture.id(34),1,'aberto'),
  (fixture.id(106),fixture.id(11),fixture.id(21),fixture.id(31),3,'pronto_reapresentar');
insert into public.apontamentos_contratante(id,id_organizacao,id_contrato,id_competencia,id_ciclo,descricao,fundamento)
  select fixture.id(100+right(id::text,3)::integer),id_organizacao,id_contrato,id_competencia,id,
    'Conferir comprovante','Fundamento sintético' from public.ciclos_diligencia;
insert into public.planos_acao(id,id_organizacao,id_contrato,id_competencia,id_ciclo,titulo)
  select fixture.id(100+right(id::text,3)::integer),id_organizacao,id_contrato,id_competencia,id,'Outro plano'
  from public.ciclos_diligencia where id=fixture.id(102);
insert into public.arquivos select fixture.id(x) from generate_series(501,505) x;
insert into public.documentos_competencia(id,id_organizacao,id_contrato,id_competencia,tipo,titulo,versao_atual)
  select fixture.id(270+right(id::text,2)::integer),id_organizacao,id_contrato,id,'comprovante','Evidência sintética',2
  from public.competencias;
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash)
  select fixture.id(100+right(id::text,3)::integer),id_organizacao,id_contrato,id,2,
    fixture.id(200+right(id::text,3)::integer),repeat('a',64) from public.documentos_competencia;
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash)
  select fixture.id(405),id_organizacao,id_contrato,id,1,fixture.id(505),repeat('b',64)
  from public.documentos_competencia where id=fixture.id(301);

insert into public.preferencias_notificacao(id_organizacao,id_usuario,evento,canal,habilitado)
  values (fixture.id(11),fixture.id(2),'TarefaDiligenciaAtribuida','in_app',false),
         (fixture.id(11),fixture.id(2),'TarefaDiligenciaPrazoAlterado:leitor','in_app',true);
