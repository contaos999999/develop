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
