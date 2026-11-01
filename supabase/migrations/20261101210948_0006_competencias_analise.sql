begin;

create table public.competencias (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  competencia_referencia date not null,
  periodo_inicio date not null,
  periodo_fim date not null,
  data_limite date,
  situacao text not null default 'rascunho' check (situacao in ('rascunho','preparando','em_analise','pendente_correcao','em_reanalise','pode_apresentar_contratante','apresentado','aguardando_contratante','com_apontamentos','pode_reapresentar_contratante','reapresentado','validada','encerrada','cancelada')),
  percentual_conformidade numeric(5,2) not null default 0 check (percentual_conformidade between 0 and 100),
  liberada_para_apresentacao_em timestamptz,
  liberada_para_reapresentacao_em timestamptz,
  validada_em timestamptz,
  versao_pacote_atual integer not null default 0,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint competencias_periodo_ck check (periodo_fim >= periodo_inicio),
  constraint competencias_referencia_mes_ck check (competencia_referencia = date_trunc('month', competencia_referencia)::date),
  constraint competencias_contrato_mes_uk unique(id_contrato, competencia_referencia)
);
create index competencias_org_contrato_idx on public.competencias(id_organizacao,id_contrato,competencia_referencia desc);
create index competencias_situacao_idx on public.competencias(id_organizacao,situacao,data_limite);

create table public.requisitos_competencia (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  origem_tipo text not null check(origem_tipo in ('item_lista','regra_conformidade','regra_preventiva','manual')),
  origem_id uuid,
  origem_versao text,
  codigo text,
  descricao text not null,
  categoria text,
  obrigatorio boolean not null default true,
  aplicavel boolean not null default true,
  impeditivo boolean not null default false,
  criticidade text not null default 'media' check(criticidade in ('baixa','media','alta','critica')),
  fonte_tipo text,
  fonte_referencia text,
  fonte_detalhe jsonb not null default '{}'::jsonb,
  efeito_portao boolean not null default true,
  ordem integer not null default 0,
  hash_snapshot text not null,
  criado_em timestamptz not null default now(),
  constraint requisitos_competencia_origem_uk unique(id_competencia,origem_tipo,origem_id)
);
create index requisitos_competencia_idx on public.requisitos_competencia(id_competencia,aplicavel,obrigatorio,impeditivo,ordem);

create table public.execucoes_analise (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  tipo text not null default 'completa' check(tipo in ('completa','parcial','reanálise')),
  status text not null default 'pendente' check(status in ('pendente','processando','concluida','falhou','cancelada')),
  hash_entrada text,
  motor text not null default 'contaos',
  versao_motor text not null default '1.0',
  provedor text,
  modelo text,
  prompt_versao text,
  iniciada_por uuid references auth.users(id) on delete set null,
  iniciada_em timestamptz,
  concluida_em timestamptz,
  erro_codigo text,
  erro_detalhe text,
  metadados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index execucoes_analise_comp_idx on public.execucoes_analise(id_competencia,criado_em desc);
create index execucoes_analise_status_idx on public.execucoes_analise(status,criado_em);

create table public.resultados_requisitos (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  id_execucao uuid not null references public.execucoes_analise(id) on delete restrict,
  id_requisito uuid not null references public.requisitos_competencia(id) on delete restrict,
  resultado text not null check(resultado in ('pendente','em_analise','conforme','nao_conforme','inconclusivo','nao_aplicavel')),
  confianca numeric(6,5) check(confianca is null or (confianca between 0 and 1)),
  justificativa text,
  fundamento text,
  hash_evidencias text,
  metadados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now(),
  constraint resultados_requisitos_exec_req_uk unique(id_execucao,id_requisito)
);
create index resultados_requisitos_comp_idx on public.resultados_requisitos(id_competencia,id_requisito,criado_em desc);

create table public.evidencias_resultado (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  id_resultado uuid not null references public.resultados_requisitos(id) on delete restrict,
  id_versao_documento uuid references public.versoes_documento(id) on delete restrict,
  pagina integer,
  trecho text,
  tipo_evidencia text not null default 'documento',
  referencia_externa text,
  hash text,
  criado_em timestamptz not null default now()
);
create index evidencias_resultado_idx on public.evidencias_resultado(id_resultado,criado_em);

create table public.apontamentos_internos (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  id_requisito uuid references public.requisitos_competencia(id) on delete restrict,
  descricao text not null,
  severidade text not null default 'media' check(severidade in ('baixa','media','alta','critica')),
  status text not null default 'aberto' check(status in ('aberto','em_tratamento','resolvido','descartado')),
  origem text not null default 'analise',
  criado_por uuid references auth.users(id) on delete set null,
  resolvido_por uuid references auth.users(id) on delete set null,
  resolvido_em timestamptz,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index apontamentos_internos_comp_idx on public.apontamentos_internos(id_competencia,status,severidade);

create table public.acoes_corretivas (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  id_apontamento uuid not null references public.apontamentos_internos(id) on delete restrict,
  descricao text not null,
  responsavel uuid references auth.users(id) on delete set null,
  prazo date,
  status text not null default 'pendente' check(status in ('pendente','em_execucao','concluida','cancelada')),
  id_evidencia_versao_documento uuid references public.versoes_documento(id) on delete restrict,
  observacao text,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index acoes_corretivas_resp_prazo_idx on public.acoes_corretivas(id_organizacao,responsavel,prazo,status);

create table public.pareceres_internos (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  versao integer not null,
  texto text not null,
  status text not null default 'rascunho' check(status in ('rascunho','aprovado','rejeitado','substituido')),
  autor uuid references auth.users(id) on delete set null,
  aprovado_por uuid references auth.users(id) on delete set null,
  aprovado_em timestamptz,
  hash text not null,
  criado_em timestamptz not null default now(),
  constraint pareceres_internos_uk unique(id_competencia,versao)
);

alter table public.documentos_competencia add constraint documentos_competencia_competencia_fk foreign key(id_competencia) references public.competencias(id) on delete restrict;
alter table public.documentos_competencia add constraint documentos_competencia_requisito_fk foreign key(id_requisito_competencia) references public.requisitos_competencia(id) on delete restrict;

alter table public.competencias enable row level security;
alter table public.requisitos_competencia enable row level security;
alter table public.execucoes_analise enable row level security;
alter table public.resultados_requisitos enable row level security;
alter table public.evidencias_resultado enable row level security;
alter table public.apontamentos_internos enable row level security;
alter table public.acoes_corretivas enable row level security;
alter table public.pareceres_internos enable row level security;

create policy competencias_select on public.competencias for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy requisitos_competencia_select on public.requisitos_competencia for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy execucoes_analise_select on public.execucoes_analise for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy resultados_requisitos_select on public.resultados_requisitos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy evidencias_resultado_select on public.evidencias_resultado for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy apontamentos_internos_select on public.apontamentos_internos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy apontamentos_internos_insert on public.apontamentos_internos for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade']::text[]));
create policy apontamentos_internos_update on public.apontamentos_internos for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy acoes_corretivas_select on public.acoes_corretivas for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy acoes_corretivas_insert on public.acoes_corretivas for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade']::text[]));
create policy acoes_corretivas_update on public.acoes_corretivas for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato)) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy pareceres_internos_select on public.pareceres_internos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy pareceres_internos_insert on public.pareceres_internos for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade']::text[]));

create trigger competencias_touch before update on public.competencias for each row execute function privado.tocar_atualizado_em();
create trigger apontamentos_internos_touch before update on public.apontamentos_internos for each row execute function privado.tocar_atualizado_em();
create trigger acoes_corretivas_touch before update on public.acoes_corretivas for each row execute function privado.tocar_atualizado_em();

create or replace function public.criar_competencia(p_id_contrato uuid,p_competencia_referencia date,p_periodo_inicio date default null,p_periodo_fim date default null,p_data_limite date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_comp uuid; v_inicio date; v_fim date;
begin
  select id_organizacao into v_org from public.contratos where id=p_id_contrato;
  if v_org is null then raise exception 'Contrato não encontrado.'; end if;
  if not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v_org,array['administrador','gestor_contrato','prestacao_contas']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if p_competencia_referencia <> date_trunc('month',p_competencia_referencia)::date then raise exception 'Competência deve ser o primeiro dia do mês.'; end if;
  v_inicio:=coalesce(p_periodo_inicio,p_competencia_referencia);
  v_fim:=coalesce(p_periodo_fim,(p_competencia_referencia+interval '1 month - 1 day')::date);
  insert into public.competencias(id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,data_limite,situacao)
  values(v_org,p_id_contrato,p_competencia_referencia,v_inicio,v_fim,p_data_limite,'preparando') returning id into v_comp;

  insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,origem_id,origem_versao,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,fonte_tipo,fonte_referencia,fonte_detalhe,efeito_portao,ordem,hash_snapshot)
  select v_org,p_id_contrato,v_comp,'item_lista',il.id,vl.numero_versao::text,il.codigo,il.descricao,il.categoria,il.obrigatorio,il.aplicavel,il.impeditivo,il.criticidade,'lista_verificacao',lv.nome,jsonb_build_object('id_lista',lv.id,'id_versao_lista',vl.id),true,il.ordem,encode(extensions.digest(concat_ws('|',il.id::text,vl.numero_versao::text,il.codigo,il.descricao,il.obrigatorio::text,il.aplicavel::text,il.impeditivo::text),'sha256'),'hex')
  from public.listas_verificacao lv join public.versoes_lista vl on vl.id_lista=lv.id and vl.situacao='publicada' join public.itens_lista il on il.id_versao_lista=vl.id
  where lv.id_contrato=p_id_contrato and lv.situacao='ativa' and (vl.vigencia_inicio is null or vl.vigencia_inicio<=v_fim) and (vl.vigencia_fim is null or vl.vigencia_fim>=v_inicio);

  insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,origem_id,origem_versao,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,fonte_tipo,fonte_referencia,fonte_detalhe,efeito_portao,ordem,hash_snapshot)
  select v_org,p_id_contrato,v_comp,'regra_conformidade',rc.id,rc.versao_registro::text,rc.codigo,rc.descricao,'regra_conformidade',true,true,rc.efeito_portao,'alta','regra_conformidade',rc.codigo,rc.configuracao,rc.efeito_portao,100000+row_number() over(order by rc.codigo),encode(extensions.digest(concat_ws('|',rc.id::text,rc.codigo,rc.descricao,rc.versao_registro::text),'sha256'),'hex')
  from public.regras_conformidade rc where rc.id_contrato=p_id_contrato and rc.situacao='ativa';

  insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,origem_id,origem_versao,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,fonte_tipo,fonte_referencia,fonte_detalhe,efeito_portao,ordem,hash_snapshot)
  select v_org,p_id_contrato,v_comp,'regra_preventiva',rp.id,rp.numero_versao::text,rp.codigo_regra,rp.descricao,'historica',true,true,(rp.efeito='bloqueio'),rp.criticidade,'historico',rp.codigo_regra,jsonb_build_object('escopo_aplicacao',rp.escopo_aplicacao,'efeito',rp.efeito),(rp.efeito='bloqueio'),200000+row_number() over(order by rp.codigo_regra),encode(extensions.digest(concat_ws('|',rp.id::text,rp.codigo_regra,rp.numero_versao::text,rp.descricao),'sha256'),'hex')
  from public.regras_preventivas rp join public.contratos c on c.id=p_id_contrato
  where rp.id_organizacao=v_org and rp.situacao='ativa' and (rp.vigencia_inicio is null or rp.vigencia_inicio<=v_fim) and (rp.vigencia_fim is null or rp.vigencia_fim>=v_inicio)
    and ((rp.escopo_aplicacao='contrato' and rp.id_contrato=p_id_contrato) or (rp.escopo_aplicacao='contratante' and rp.id_contratante=c.id_contratante) or (rp.escopo_aplicacao='tipo_contrato' and rp.tipo_contrato=c.tipo_contrato) or rp.escopo_aplicacao='organizacao');

  update public.competencias set situacao='rascunho' where id=v_comp;
  perform privado.registrar_evento_auditoria(v_org,'CompetenciaCriada','competencias',v_comp,null,jsonb_build_object('id_contrato',p_id_contrato,'competencia_referencia',p_competencia_referencia));
  return v_comp;
end;$$;
revoke all on function public.criar_competencia(uuid,date,date,date,date) from public;
grant execute on function public.criar_competencia(uuid,date,date,date,date) to authenticated;

create or replace function public.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa')
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_exec uuid;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if p_tipo not in ('completa','reanálise','parcial') then raise exception 'Tipo de análise inválido.'; end if;
  if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then raise exception 'Situação não permite análise.'; end if;
  insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,versao_motor,iniciada_por,iniciada_em)
  values(v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente','1.0',auth.uid(),now()) returning id into v_exec;
  update public.competencias set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,jsonb_build_object('id_competencia',v.id,'tipo',p_tipo));
  return v_exec;
end;$$;
revoke all on function public.solicitar_analise_competencia(uuid,text) from public;
grant execute on function public.solicitar_analise_competencia(uuid,text) to authenticated;

create or replace function public.avaliar_portao_conformidade(p_id_competencia uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_org uuid; v_contrato uuid; v_total int:=0; v_ok int:=0; v_pend int:=0; v_nok int:=0; v_inc int:=0; v_analise int:=0; v_percent numeric(5,2):=0; v_liberado boolean:=false;
begin
  select id_organizacao,id_contrato into v_org,v_contrato from public.competencias where id=p_id_competencia;
  if v_org is null then raise exception 'Competência não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v_contrato) then raise exception 'Acesso negado.'; end if;
  with ultimos as (
    select distinct on (r.id_requisito) r.id_requisito,r.resultado,r.fundamento,r.id
    from public.resultados_requisitos r where r.id_competencia=p_id_competencia order by r.id_requisito,r.criado_em desc,r.id desc
  ), avaliacao as (
    select req.id,coalesce(u.resultado,'pendente') resultado,
      case when u.resultado='nao_aplicavel' and nullif(trim(coalesce(u.fundamento,'')),'') is not null and exists(select 1 from public.evidencias_resultado e where e.id_resultado=u.id) then true else false end na_valido
    from public.requisitos_competencia req left join ultimos u on u.id_requisito=req.id
    where req.id_competencia=p_id_competencia and req.obrigatorio=true and req.aplicavel=true and req.efeito_portao=true
  )
  select count(*)::int,
         count(*) filter(where resultado='conforme' or (resultado='nao_aplicavel' and na_valido))::int,
         count(*) filter(where resultado='pendente' or (resultado='nao_aplicavel' and not na_valido))::int,
         count(*) filter(where resultado='nao_conforme')::int,
         count(*) filter(where resultado='inconclusivo')::int,
         count(*) filter(where resultado='em_analise')::int
    into v_total,v_ok,v_pend,v_nok,v_inc,v_analise from avaliacao;
  v_percent:=case when v_total=0 then 0 else round((v_ok::numeric/v_total::numeric)*100,2) end;
  v_liberado:=(v_total>0 and v_ok=v_total and v_pend=0 and v_nok=0 and v_inc=0 and v_analise=0);
  return jsonb_build_object('total',v_total,'conformes_ou_na_validos',v_ok,'pendentes',v_pend,'nao_conformes',v_nok,'inconclusivos',v_inc,'em_analise',v_analise,'percentual',v_percent,'liberado',v_liberado);
end;$$;
revoke all on function public.avaliar_portao_conformidade(uuid) from public;
grant execute on function public.avaliar_portao_conformidade(uuid) to authenticated;

commit;