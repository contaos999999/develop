-- MIGRATION 20261101211039_0008_historico
begin;

create table public.relatorios_historicos_contratante (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_arquivo uuid not null references public.arquivos(id) on delete restrict,
  competencia_referencia date,
  tipo text not null,
  data_documento date,
  numero_documento text,
  resultado_geral text,
  origem_temporal text not null default 'pre_implantacao' check(origem_temporal in ('pre_implantacao','pos_implantacao')),
  status_processamento text not null default 'pendente' check(status_processamento in ('pendente','processando','concluido','falhou')),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now()
);
create index relatorios_historicos_idx on public.relatorios_historicos_contratante(id_contrato,competencia_referencia,data_documento desc);

create table public.apontamentos_historicos (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_relatorio uuid not null references public.relatorios_historicos_contratante(id) on delete restrict,
  item text,
  problema text not null,
  fundamento text,
  severidade text check(severidade in ('baixa','media','alta','critica')),
  fonte_pagina integer,
  fonte_trecho text,
  criado_em timestamptz not null default now()
);
create index apontamentos_historicos_rel_idx on public.apontamentos_historicos(id_relatorio);

create table public.respostas_historicas (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_apontamento uuid not null references public.apontamentos_historicos(id) on delete restrict,
  texto text not null,
  id_versao_documento_resposta uuid references public.versoes_documento(id) on delete restrict,
  criado_em timestamptz not null default now()
);
create index respostas_historicas_apont_idx on public.respostas_historicas(id_apontamento,criado_em);

create table public.desfechos_historicos (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_apontamento uuid not null references public.apontamentos_historicos(id) on delete restrict,
  resultado text not null,
  fundamento text,
  data date,
  criado_em timestamptz not null default now()
);
create index desfechos_historicos_apont_idx on public.desfechos_historicos(id_apontamento,resultado);

create table public.precedentes (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contratante uuid not null references public.contratantes(id) on delete restrict,
  id_contrato_origem uuid not null references public.contratos(id) on delete restrict,
  competencia_origem date,
  problema text not null,
  solucao text,
  desfecho text,
  fonte_tipo text not null default 'historico',
  fonte_id uuid,
  confianca numeric(6,5) check(confianca is null or confianca between 0 and 1),
  embedding extensions.vector,
  status text not null default 'ativo' check(status in ('ativo','inativo','substituido')),
  criado_em timestamptz not null default now()
);
create index precedentes_contratante_idx on public.precedentes(id_organizacao,id_contratante,id_contrato_origem);

alter table public.relatorios_historicos_contratante enable row level security;
alter table public.apontamentos_historicos enable row level security;
alter table public.respostas_historicas enable row level security;
alter table public.desfechos_historicos enable row level security;
alter table public.precedentes enable row level security;

create policy relatorios_historicos_select on public.relatorios_historicos_contratante for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy relatorios_historicos_insert on public.relatorios_historicos_contratante for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade']::text[]));
create policy apontamentos_historicos_select on public.apontamentos_historicos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy respostas_historicas_select on public.respostas_historicas for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy desfechos_historicos_select on public.desfechos_historicos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy precedentes_select on public.precedentes for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));

create or replace function public.promover_precedente_para_regra(p_id_precedente uuid,p_codigo_regra text,p_descricao text,p_efeito text default 'informativo',p_criticidade text default 'media',p_escopo_aplicacao text default 'contrato')
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.precedentes%rowtype; v_regra uuid;
begin
  select * into v from public.precedentes where id=p_id_precedente;
  if v.id is null then raise exception 'Precedente não encontrado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if p_efeito not in ('informativo','alerta','bloqueio') then raise exception 'Efeito inválido.'; end if;
  if p_escopo_aplicacao not in ('contrato','contratante','tipo_contrato','organizacao') then raise exception 'Escopo inválido.'; end if;
  insert into public.regras_preventivas(id_organizacao,id_contrato,id_contratante,codigo_regra,origem_precedente,descricao,efeito,criticidade,escopo_aplicacao,tipo_contrato,numero_versao,situacao)
  select v.id_organizacao,case when p_escopo_aplicacao='contrato' then v.id_contrato_origem else null end,case when p_escopo_aplicacao='contratante' then v.id_contratante else null end,p_codigo_regra,v.id,p_descricao,p_efeito,p_criticidade,p_escopo_aplicacao,case when p_escopo_aplicacao='tipo_contrato' then c.tipo_contrato else null end,1,'ativa'
  from public.contratos c where c.id=v.id_contrato_origem returning id into v_regra;
  insert into public.revisoes_regras_preventivas(id_organizacao,id_contrato,id_regra,versao,decisao,fundamento,revisor,snapshot)
  values(v.id_organizacao,v.id_contrato_origem,v_regra,1,'aprovada','Promoção formal de precedente histórico.',auth.uid(),jsonb_build_object('id_precedente',v.id,'efeito',p_efeito,'escopo',p_escopo_aplicacao));
  perform privado.registrar_evento_auditoria(v.id_organizacao,'PrecedentePromovidoParaRegra','regras_preventivas',v_regra,null,jsonb_build_object('id_precedente',v.id,'codigo_regra',p_codigo_regra));
  return v_regra;
end;$$;
revoke all on function public.promover_precedente_para_regra(uuid,text,text,text,text,text) from public;
grant execute on function public.promover_precedente_para_regra(uuid,text,text,text,text,text) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101211055_0009_queues_edge_support
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

-- ============================================================

-- MIGRATION 20261101211140_0010_diligencias_v2
begin;

create table public.ciclos_diligencia (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 numero_rodada integer not null, status text not null default 'aberto' check(status in ('aberto','em_tratamento','pronto_reapresentar','reapresentado','encerrado')),
 recebido_em timestamptz not null default now(), prazo_resposta date, encerrado_em timestamptz, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(), constraint ciclos_diligencia_uk unique(id_competencia,numero_rodada));
create index ciclos_diligencia_comp_idx on public.ciclos_diligencia(id_competencia,numero_rodada desc);

create table public.pareceres_contratante (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid references public.ciclos_diligencia(id) on delete restrict, id_apresentacao uuid references public.apresentacoes_contratante(id) on delete restrict,
 id_arquivo uuid not null references public.arquivos(id) on delete restrict, resultado_geral text, parecer_final_favoravel boolean not null default false,
 numero_documento text, data_emissao date, recebido_em timestamptz not null default now(), registrado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now());
create index pareceres_contratante_comp_idx on public.pareceres_contratante(id_competencia,recebido_em desc);

create table public.apontamentos_contratante (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, codigo text, descricao text not null, fundamento text,
 status text not null default 'aberto' check(status in ('aberto','em_analise','procedente','nao_procedente','em_tratamento','resolvido','contestado','contestado_aprovado','encerrado')),
 severidade text not null default 'media' check(severidade in ('baixa','media','alta','critica')), fonte_pagina integer, fonte_trecho text,
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index apontamentos_contratante_ciclo_idx on public.apontamentos_contratante(id_ciclo,status,severidade);

create table public.analises_apontamentos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_apontamento uuid not null references public.apontamentos_contratante(id) on delete restrict,
 classificacao text not null check(classificacao in ('procedente','parcialmente_procedente','nao_procedente','inconclusivo')),
 fundamento text not null, evidencias jsonb not null default '[]'::jsonb, revisado_por uuid references auth.users(id) on delete set null,
 revisado_em timestamptz, criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now());
create index analises_apontamentos_idx on public.analises_apontamentos(id_apontamento,criado_em desc);

create table public.planos_acao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, titulo text not null, descricao text,
 responsavel uuid references auth.users(id) on delete set null, status text not null default 'aberto' check(status in ('aberto','em_execucao','concluido','cancelado')),
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index planos_acao_ciclo_idx on public.planos_acao(id_ciclo,status);

create table public.tarefas_diligencia (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, id_plano uuid references public.planos_acao(id) on delete restrict,
 id_apontamento uuid references public.apontamentos_contratante(id) on delete restrict, descricao text not null,
 responsavel uuid references auth.users(id) on delete set null, prazo date, status text not null default 'pendente' check(status in ('pendente','em_execucao','concluida','cancelada')),
 id_evidencia_versao_documento uuid references public.versoes_documento(id) on delete restrict, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index tarefas_diligencia_resp_idx on public.tarefas_diligencia(id_organizacao,responsavel,prazo,status);

create table public.contestacoes (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, id_apontamento uuid not null references public.apontamentos_contratante(id) on delete restrict,
 versao integer not null, texto text not null, fundamento text not null,
 status_aprovacao text not null default 'rascunho' check(status_aprovacao in ('rascunho','pendente','aprovada','rejeitada','substituida')),
 criado_por uuid references auth.users(id) on delete set null, aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz,
 hash text not null, criado_em timestamptz not null default now(), constraint contestacoes_uk unique(id_apontamento,versao));

create table public.mapas_evidencias_contestacao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_contestacao uuid not null references public.contestacoes(id) on delete restrict, id_versao_documento uuid references public.versoes_documento(id) on delete restrict,
 pagina integer, trecho text, descricao text, hash text, criado_em timestamptz not null default now());
create index mapas_evidencias_contestacao_idx on public.mapas_evidencias_contestacao(id_contestacao);

create table public.pacotes_reapresentacao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_ciclo uuid not null references public.ciclos_diligencia(id) on delete restrict, numero integer not null, hash text not null,
 snapshot jsonb not null default '{}'::jsonb, criado_por uuid references auth.users(id) on delete set null,
 congelado_em timestamptz not null default now(), reapresentado_em timestamptz, criado_em timestamptz not null default now(),
 constraint pacotes_reapresentacao_uk unique(id_ciclo,numero));

create table public.desfechos_apontamentos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_competencia uuid not null references public.competencias(id) on delete restrict,
 id_apontamento uuid not null references public.apontamentos_contratante(id) on delete restrict,
 tipo_desfecho text not null, texto text, data date not null default current_date, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now());
create index desfechos_apontamentos_idx on public.desfechos_apontamentos(id_apontamento,criado_em desc);

alter table public.ciclos_diligencia enable row level security; alter table public.pareceres_contratante enable row level security;
alter table public.apontamentos_contratante enable row level security; alter table public.analises_apontamentos enable row level security;
alter table public.planos_acao enable row level security; alter table public.tarefas_diligencia enable row level security;
alter table public.contestacoes enable row level security; alter table public.mapas_evidencias_contestacao enable row level security;
alter table public.pacotes_reapresentacao enable row level security; alter table public.desfechos_apontamentos enable row level security;

create policy ciclos_diligencia_select on public.ciclos_diligencia for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy pareceres_contratante_select on public.pareceres_contratante for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy apontamentos_contratante_select on public.apontamentos_contratante for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy analises_apontamentos_select on public.analises_apontamentos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy analises_apontamentos_insert on public.analises_apontamentos for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade']::text[]));
create policy planos_acao_select on public.planos_acao for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy planos_acao_write on public.planos_acao for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy tarefas_diligencia_select on public.tarefas_diligencia for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy tarefas_diligencia_write on public.tarefas_diligencia for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy contestacoes_select on public.contestacoes for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy contestacoes_insert on public.contestacoes for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy mapas_evidencias_contestacao_select on public.mapas_evidencias_contestacao for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy mapas_evidencias_contestacao_insert on public.mapas_evidencias_contestacao for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy pacotes_reapresentacao_select on public.pacotes_reapresentacao for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy desfechos_apontamentos_select on public.desfechos_apontamentos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));

create trigger ciclos_diligencia_touch before update on public.ciclos_diligencia for each row execute function privado.tocar_atualizado_em();
create trigger apontamentos_contratante_touch before update on public.apontamentos_contratante for each row execute function privado.tocar_atualizado_em();
create trigger planos_acao_touch before update on public.planos_acao for each row execute function privado.tocar_atualizado_em();
create trigger tarefas_diligencia_touch before update on public.tarefas_diligencia for each row execute function privado.tocar_atualizado_em();

create or replace function public.registrar_parecer_contratante(p_id_competencia uuid,p_id_apresentacao uuid,p_id_arquivo uuid,p_resultado_geral text,p_parecer_final_favoravel boolean default false,p_numero_documento text default null,p_data_emissao date default null,p_prazo_resposta date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_ciclo uuid; v_parecer uuid; v_rodada int;
begin
 select * into v from public.competencias where id=p_id_competencia for update;
 if v.id is null then raise exception 'Competência não encontrada.'; end if;
 if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade','direcao_aprovador']::text[]) then raise exception 'Perfil sem permissão.'; end if;
 if p_parecer_final_favoravel then
   insert into public.pareceres_contratante(id_organizacao,id_contrato,id_competencia,id_apresentacao,id_arquivo,resultado_geral,parecer_final_favoravel,numero_documento,data_emissao,registrado_por)
   values(v.id_organizacao,v.id_contrato,v.id,p_id_apresentacao,p_id_arquivo,p_resultado_geral,true,p_numero_documento,p_data_emissao,auth.uid()) returning id into v_parecer;
   update public.competencias set situacao='validada',validada_em=now() where id=v.id;
 else
   select coalesce(max(numero_rodada),0)+1 into v_rodada from public.ciclos_diligencia where id_competencia=v.id;
   insert into public.ciclos_diligencia(id_organizacao,id_contrato,id_competencia,numero_rodada,status,prazo_resposta)
   values(v.id_organizacao,v.id_contrato,v.id,v_rodada,'aberto',p_prazo_resposta) returning id into v_ciclo;
   insert into public.pareceres_contratante(id_organizacao,id_contrato,id_competencia,id_ciclo,id_apresentacao,id_arquivo,resultado_geral,parecer_final_favoravel,numero_documento,data_emissao,registrado_por)
   values(v.id_organizacao,v.id_contrato,v.id,v_ciclo,p_id_apresentacao,p_id_arquivo,p_resultado_geral,false,p_numero_documento,p_data_emissao,auth.uid()) returning id into v_parecer;
   update public.competencias set situacao='com_apontamentos' where id=v.id;
 end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ParecerContratanteRegistrado','pareceres_contratante',v_parecer,null,jsonb_build_object('final_favoravel',p_parecer_final_favoravel,'id_ciclo',v_ciclo));
 return v_parecer;
end;$$;
revoke all on function public.registrar_parecer_contratante(uuid,uuid,uuid,text,boolean,text,date,date) from public;
grant execute on function public.registrar_parecer_contratante(uuid,uuid,uuid,text,boolean,text,date,date) to authenticated;

create or replace function public.avaliar_portao_reapresentacao(p_id_ciclo uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_org uuid; v_contrato uuid; v_total int; v_tratados int; v_abertos int;
begin
 select id_organizacao,id_contrato into v_org,v_contrato from public.ciclos_diligencia where id=p_id_ciclo;
 if v_org is null then raise exception 'Ciclo não encontrado.'; end if;
 if not privado.usuario_tem_acesso_contrato(v_contrato) then raise exception 'Acesso negado.'; end if;
 select count(*)::int,count(*) filter(where status in ('resolvido','nao_procedente','contestado_aprovado','encerrado'))::int,count(*) filter(where status not in ('resolvido','nao_procedente','contestado_aprovado','encerrado'))::int
 into v_total,v_tratados,v_abertos from public.apontamentos_contratante where id_ciclo=p_id_ciclo;
 return jsonb_build_object('total',v_total,'tratados',v_tratados,'abertos',v_abertos,'liberado',(v_total>0 and v_total=v_tratados));
end;$$;
revoke all on function public.avaliar_portao_reapresentacao(uuid) from public;
grant execute on function public.avaliar_portao_reapresentacao(uuid) to authenticated;

create or replace function public.aprovar_contestacao(p_id_contestacao uuid,p_aprovar boolean,p_fundamento text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v public.contestacoes%rowtype;
begin
 select * into v from public.contestacoes where id=p_id_contestacao for update;
 if v.id is null then raise exception 'Contestação não encontrada.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Perfil sem permissão.'; end if;
 update public.contestacoes set status_aprovacao=case when p_aprovar then 'aprovada' else 'rejeitada' end,aprovado_por=auth.uid(),aprovado_em=now() where id=v.id;
 if p_aprovar then update public.apontamentos_contratante set status='contestado_aprovado' where id=v.id_apontamento; end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ContestacaoRevisada','contestacoes',v.id,null,jsonb_build_object('aprovada',p_aprovar,'fundamento',p_fundamento));
end;$$;
revoke all on function public.aprovar_contestacao(uuid,boolean,text) from public;
grant execute on function public.aprovar_contestacao(uuid,boolean,text) to authenticated;

create or replace function public.liberar_reapresentacao(p_id_ciclo uuid,p_fundamento text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.ciclos_diligencia%rowtype; v_portao jsonb; v_aprov uuid; v_hash text;
begin
 select * into v from public.ciclos_diligencia where id=p_id_ciclo for update;
 if v.id is null then raise exception 'Ciclo não encontrado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]) then raise exception 'Perfil sem permissão.'; end if;
 v_portao:=public.avaliar_portao_reapresentacao(v.id);
 if coalesce((v_portao->>'liberado')::boolean,false) is not true then raise exception 'A rodada não está 100%% tratada.'; end if;
 v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,v_portao::text,coalesce(p_fundamento,'')),'sha256'),'hex');
 insert into public.aprovacoes(id_organizacao,id_contrato,id_competencia,tipo,status,aprovado_por,fundamento,hash_contexto)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,'reapresentacao','aprovada',auth.uid(),p_fundamento,v_hash) returning id into v_aprov;
 update public.ciclos_diligencia set status='pronto_reapresentar' where id=v.id;
 update public.competencias set situacao='pode_reapresentar_contratante',liberada_para_reapresentacao_em=now() where id=v.id_competencia;
 return jsonb_build_object('id_aprovacao',v_aprov,'situacao','pode_reapresentar_contratante');
end;$$;
revoke all on function public.liberar_reapresentacao(uuid,text) from public;
grant execute on function public.liberar_reapresentacao(uuid,text) to authenticated;

create or replace function public.registrar_reapresentacao(p_id_ciclo uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.ciclos_diligencia%rowtype; v_comp public.competencias%rowtype; v_num int; v_hash text; v_pack uuid; v_apres uuid; v_exist uuid;
begin
 if nullif(trim(p_idempotency_key),'') is null then raise exception 'idempotency_key obrigatório.'; end if;
 select * into v from public.ciclos_diligencia where id=p_id_ciclo for update;
 if v.id is null then raise exception 'Ciclo não encontrado.'; end if;
 select * into v_comp from public.competencias where id=v.id_competencia for update;
 if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
 select id into v_exist from public.apresentacoes_contratante where id_organizacao=v.id_organizacao and idempotency_key=p_idempotency_key;
 if v_exist is not null then return v_exist; end if;
 if v.status<>'pronto_reapresentar' or v_comp.situacao<>'pode_reapresentar_contratante' then raise exception 'Reapresentação não liberada.'; end if;
 select coalesce(max(numero),0)+1 into v_num from public.pacotes_reapresentacao where id_ciclo=v.id;
 select encode(extensions.digest(string_agg(z.h,'|' order by z.h),'sha256'),'hex') into v_hash from (
   select coalesce(hash,'') h from public.contestacoes where id_ciclo=v.id and status_aprovacao='aprovada'
   union all select coalesce(vd.hash,'') from public.tarefas_diligencia td join public.versoes_documento vd on vd.id=td.id_evidencia_versao_documento where td.id_ciclo=v.id and td.status='concluida'
 ) z;
 v_hash:=coalesce(v_hash,encode(extensions.digest(v.id::text,'sha256'),'hex'));
 insert into public.pacotes_reapresentacao(id_organizacao,id_contrato,id_competencia,id_ciclo,numero,hash,snapshot,criado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id,v_num,v_hash,jsonb_build_object('rodada',v.numero_rodada,'portao',public.avaliar_portao_reapresentacao(v.id)),auth.uid()) returning id into v_pack;
 insert into public.pacotes_competencia(id_organizacao,id_contrato,id_competencia,numero,tipo,status,hash_pacote,criado_por,congelado_em)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v_num,'reapresentacao','apresentado',v_hash,auth.uid(),now()) returning id into v_pack;
 insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,id_pacote,numero_rodada,tipo,protocolo,forma_apresentacao,id_comprovante_arquivo,idempotency_key,apresentado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v_pack,v.numero_rodada+1,'reapresentacao',p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo,p_idempotency_key,auth.uid()) returning id into v_apres;
 update public.ciclos_diligencia set status='reapresentado' where id=v.id;
 update public.competencias set situacao='reapresentado' where id=v.id_competencia;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ReapresentacaoRegistrada','apresentacoes_contratante',v_apres,null,jsonb_build_object('id_ciclo',v.id,'rodada',v.numero_rodada));
 return v_apres;
end;$$;
revoke all on function public.registrar_reapresentacao(uuid,text,text,text,uuid) from public;
grant execute on function public.registrar_reapresentacao(uuid,text,text,text,uuid) to authenticated;

commit;