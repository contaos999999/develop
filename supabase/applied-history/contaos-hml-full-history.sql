-- MIGRATION 20261101205846_0001_extensoes_schemas
begin;

create schema if not exists privado;

create extension if not exists vector with schema extensions;
create extension if not exists pgmq;
create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists pgtap with schema extensions;

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

create or replace function privado.usuario_atual()
returns uuid
language sql
stable
set search_path = ''
as $$ select auth.uid() $$;

revoke all on schema privado from public, anon, authenticated;
grant usage on schema privado to authenticated, service_role;

commit;

-- ============================================================

-- MIGRATION 20261101205936_0002_identidade_organizacoes
begin;

create table public.organizacoes (
  id uuid primary key default gen_random_uuid(),
  razao_social text not null,
  nome_fantasia text,
  cnpj varchar(18),
  timezone text not null default 'America/Bahia',
  moeda char(3) not null default 'BRL',
  idioma text not null default 'pt-BR',
  situacao text not null default 'ativa' check (situacao in ('ativa','inativa','suspensa')),
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create unique index organizacoes_cnpj_uidx on public.organizacoes (regexp_replace(cnpj,'\D','','g')) where cnpj is not null;
create index organizacoes_situacao_idx on public.organizacoes(situacao);

create table public.perfis_usuarios (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  nome text not null,
  descricao text,
  criado_em timestamptz not null default now()
);

insert into public.perfis_usuarios (codigo,nome,descricao) values
 ('administrador','Administrador','Administração da organização e permissões.'),
 ('direcao_aprovador','Direção / Aprovador','Aprovação humana de marcos críticos.'),
 ('gestor_contrato','Gestor de contrato','Gestão operacional de contratos.'),
 ('prestacao_contas','Prestação de contas','Operação de competências e documentos.'),
 ('financeiro','Financeiro','Módulo financeiro e conciliações.'),
 ('contabilidade','Contabilidade','Análises contábeis e evidências.'),
 ('rh_dp','RH / DP','Documentos e rotinas trabalhistas relacionadas.'),
 ('juridico_conformidade','Jurídico / Conformidade','Regras, diligências e conformidade.'),
 ('auditor','Auditor','Leitura ampliada e auditoria.'),
 ('leitor','Leitor','Consulta sem permissão de alteração.')
on conflict (codigo) do nothing;

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
create index vinculos_usuarios_org_idx on public.vinculos_usuarios(id_organizacao, ativo);
create index vinculos_usuarios_usuario_idx on public.vinculos_usuarios(id_usuario, ativo);

create table public.vinculos_usuario_contratos (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  id_vinculo_usuario uuid not null references public.vinculos_usuarios(id) on delete cascade,
  id_contrato uuid not null,
  criado_em timestamptz not null default now(),
  constraint vinculo_contrato_uk unique(id_vinculo_usuario,id_contrato)
);
create index vinculos_usuario_contratos_org_idx on public.vinculos_usuario_contratos(id_organizacao);
create index vinculos_usuario_contratos_contrato_idx on public.vinculos_usuario_contratos(id_contrato);

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
create index eventos_auditoria_org_data_idx on public.eventos_auditoria(id_organizacao, criado_em desc);
create index eventos_auditoria_entidade_idx on public.eventos_auditoria(entidade,id_entidade);
create index eventos_auditoria_correlation_idx on public.eventos_auditoria(correlation_id);

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

create table public.recursos_organizacao (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  recurso text not null,
  habilitado boolean not null default true,
  configuracao jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint recursos_organizacao_uk unique(id_organizacao,recurso)
);

create or replace function privado.usuario_tem_acesso_organizacao(p_id_organizacao uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.vinculos_usuarios v
     where v.id_organizacao = p_id_organizacao
       and v.id_usuario = auth.uid()
       and v.ativo = true
       and v.inicio_em <= now()
       and (v.fim_em is null or v.fim_em > now())
  );
$$;

create or replace function privado.usuario_possui_perfil(p_id_organizacao uuid, p_perfis text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.vinculos_usuarios v
     where v.id_organizacao = p_id_organizacao
       and v.id_usuario = auth.uid()
       and v.ativo = true
       and v.inicio_em <= now()
       and (v.fim_em is null or v.fim_em > now())
       and v.perfil = any(p_perfis)
  );
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

create or replace function public.criar_organizacao(
  p_razao_social text,
  p_nome_fantasia text default null,
  p_cnpj varchar default null,
  p_timezone text default 'America/Bahia'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_usuario uuid := auth.uid(); v_org uuid;
begin
  if v_usuario is null then raise exception 'Usuário não autenticado.'; end if;
  insert into public.organizacoes(razao_social,nome_fantasia,cnpj,timezone)
  values(p_razao_social,p_nome_fantasia,p_cnpj,p_timezone) returning id into v_org;
  insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
  values(v_org,v_usuario,'administrador',true);
  insert into public.recursos_organizacao(id_organizacao,recurso,habilitado)
  values(v_org,'contaos_1',true);
  perform privado.registrar_evento_auditoria(v_org,'OrganizacaoCriada','organizacoes',v_org,null,jsonb_build_object('razao_social',p_razao_social));
  return v_org;
end;
$$;

revoke all on function public.criar_organizacao(text,text,varchar,text) from public;
grant execute on function public.criar_organizacao(text,text,varchar,text) to authenticated;
revoke all on function privado.usuario_tem_acesso_organizacao(uuid) from public, anon, authenticated;
grant execute on function privado.usuario_tem_acesso_organizacao(uuid) to authenticated;
revoke all on function privado.usuario_possui_perfil(uuid,text[]) from public, anon, authenticated;
grant execute on function privado.usuario_possui_perfil(uuid,text[]) to authenticated;
revoke all on function privado.registrar_evento_auditoria(uuid,text,text,uuid,jsonb,jsonb,jsonb) from public, anon, authenticated;

alter table public.organizacoes enable row level security;
alter table public.perfis_usuarios enable row level security;
alter table public.usuarios enable row level security;
alter table public.vinculos_usuarios enable row level security;
alter table public.vinculos_usuario_contratos enable row level security;
alter table public.eventos_auditoria enable row level security;
alter table public.comandos_idempotentes enable row level security;
alter table public.recursos_organizacao enable row level security;

create policy organizacoes_select on public.organizacoes for select to authenticated using (privado.usuario_tem_acesso_organizacao(id));
create policy perfis_select on public.perfis_usuarios for select to authenticated using (true);
create policy usuarios_select_self on public.usuarios for select to authenticated using (id_usuario = auth.uid());
create policy usuarios_update_self on public.usuarios for update to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());
create policy vinculos_select on public.vinculos_usuarios for select to authenticated using (id_usuario = auth.uid() or privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy vinculos_admin_insert on public.vinculos_usuarios for insert to authenticated with check (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create policy vinculos_admin_update on public.vinculos_usuarios for update to authenticated using (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[])) with check (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create policy vinculos_contrato_select on public.vinculos_usuario_contratos for select to authenticated using (privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy eventos_select on public.eventos_auditoria for select to authenticated using (privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]));
create policy recursos_select on public.recursos_organizacao for select to authenticated using (privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy recursos_admin_write on public.recursos_organizacao for all to authenticated using (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[])) with check (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));

create trigger organizacoes_touch before update on public.organizacoes for each row execute function privado.tocar_atualizado_em();
create trigger usuarios_touch before update on public.usuarios for each row execute function privado.tocar_atualizado_em();
create trigger vinculos_usuarios_touch before update on public.vinculos_usuarios for each row execute function privado.tocar_atualizado_em();
create trigger comandos_idempotentes_touch before update on public.comandos_idempotentes for each row execute function privado.tocar_atualizado_em();
create trigger recursos_organizacao_touch before update on public.recursos_organizacao for each row execute function privado.tocar_atualizado_em();

commit;

-- ============================================================

-- MIGRATION 20261101210017_0003_contratantes_contratos_core
begin;
create table public.contratantes (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 tipo_pessoa text not null default 'juridica' check(tipo_pessoa in ('juridica','fisica','orgao_publico','outro')), documento text,
 razao_social text not null, nome_fantasia text, contato jsonb not null default '{}'::jsonb,
 situacao text not null default 'ativo' check(situacao in ('ativo','inativo')), versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(), constraint contratantes_id_org_uk unique(id,id_organizacao));
create unique index contratantes_org_documento_uidx on public.contratantes(id_organizacao, regexp_replace(documento,'\D','','g')) where documento is not null;
create index contratantes_org_nome_idx on public.contratantes(id_organizacao,razao_social);

create table public.contratos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contratante uuid not null, numero text not null, objeto text not null, tipo_contrato text, inicio date, fim date,
 valor_global numeric(18,2), periodicidade text default 'mensal', prazo_prestacao_dias integer,
 situacao text not null default 'rascunho' check(situacao in ('rascunho','ativo','suspenso','encerrado','cancelado')),
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint contratos_vigencia_ck check(fim is null or inicio is null or fim>=inicio), constraint contratos_org_numero_uk unique(id_organizacao,numero),
 constraint contratos_id_org_uk unique(id,id_organizacao),
 constraint contratos_contratante_org_fk foreign key(id_contratante,id_organizacao) references public.contratantes(id,id_organizacao));
create index contratos_contratante_idx on public.contratos(id_organizacao,id_contratante);
create index contratos_situacao_idx on public.contratos(id_organizacao,situacao);
create index contratos_vigencia_idx on public.contratos(id_organizacao,inicio,fim);

alter table public.vinculos_usuarios add constraint vinculos_usuarios_id_org_uk unique(id,id_organizacao);
alter table public.vinculos_usuario_contratos add column ativo boolean not null default true, add column revogado_em timestamptz;
alter table public.vinculos_usuario_contratos add constraint vinculos_usuario_contratos_vinculo_org_fk foreign key(id_vinculo_usuario,id_organizacao) references public.vinculos_usuarios(id,id_organizacao) on delete cascade;
alter table public.vinculos_usuario_contratos add constraint vinculos_usuario_contratos_contrato_org_fk foreign key(id_contrato,id_organizacao) references public.contratos(id,id_organizacao) on delete cascade;

create table public.versoes_contrato (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, numero_versao integer not null, snapshot jsonb not null, hash text not null,
 motivo text, criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now(),
 constraint versoes_contrato_uk unique(id_contrato,numero_versao));
create index versoes_contrato_org_contrato_idx on public.versoes_contrato(id_organizacao,id_contrato,numero_versao desc);

alter table public.contratantes enable row level security; alter table public.contratos enable row level security; alter table public.versoes_contrato enable row level security;
create trigger contratantes_touch before update on public.contratantes for each row execute function privado.tocar_atualizado_em();
create trigger contratos_touch before update on public.contratos for each row execute function privado.tocar_atualizado_em();
commit;

-- ============================================================

-- MIGRATION 20261101210030_0003b_acesso_contratos_rls
begin;
create or replace function privado.usuario_tem_acesso_contrato(p_id_contrato uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.contratos c join public.vinculos_usuarios v on v.id_organizacao=c.id_organizacao
  where c.id=p_id_contrato and v.id_usuario=auth.uid() and v.ativo=true and v.inicio_em<=now() and (v.fim_em is null or v.fim_em>now())
    and (v.escopo_todos_contratos=true or exists(select 1 from public.vinculos_usuario_contratos vc where vc.id_vinculo_usuario=v.id and vc.id_contrato=c.id and vc.ativo=true))
 );
$$;
revoke all on function privado.usuario_tem_acesso_contrato(uuid) from public,anon,authenticated;
grant execute on function privado.usuario_tem_acesso_contrato(uuid) to authenticated;

create or replace function public.definir_vinculo_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_perfil text,p_escopo_todos_contratos boolean default false,p_ativo boolean default true)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null or not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if not exists(select 1 from public.perfis_usuarios where codigo=p_perfil) then raise exception 'Perfil inválido.'; end if;
 insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
 values(p_id_organizacao,p_id_usuario,p_perfil,p_escopo_todos_contratos,p_ativo)
 on conflict(id_usuario,id_organizacao) do update set perfil=excluded.perfil,escopo_todos_contratos=excluded.escopo_todos_contratos,ativo=excluded.ativo,atualizado_em=now()
 returning id into v_id;
 perform privado.registrar_evento_auditoria(p_id_organizacao,'VinculoUsuarioDefinido','vinculos_usuarios',v_id,null,jsonb_build_object('id_usuario',p_id_usuario,'perfil',p_perfil));
 return v_id;
end;$$;
revoke all on function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) from public;
grant execute on function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) to authenticated;

create or replace function public.definir_acesso_contrato_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_id_contrato uuid,p_conceder boolean default true)
returns void language plpgsql security definer set search_path='' as $$
declare v_vinculo uuid;
begin
 if auth.uid() is null or not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if not exists(select 1 from public.contratos where id=p_id_contrato and id_organizacao=p_id_organizacao) then raise exception 'Contrato inválido.'; end if;
 select id into v_vinculo from public.vinculos_usuarios where id_organizacao=p_id_organizacao and id_usuario=p_id_usuario;
 if v_vinculo is null then raise exception 'Usuário sem vínculo.'; end if;
 insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo,revogado_em)
 values(p_id_organizacao,v_vinculo,p_id_contrato,p_conceder,case when p_conceder then null else now() end)
 on conflict(id_vinculo_usuario,id_contrato) do update set ativo=excluded.ativo,revogado_em=excluded.revogado_em;
 perform privado.registrar_evento_auditoria(p_id_organizacao,case when p_conceder then 'AcessoContratoConcedido' else 'AcessoContratoRevogado' end,'vinculos_usuario_contratos',p_id_contrato,null,jsonb_build_object('id_usuario',p_id_usuario));
end;$$;
revoke all on function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) from public;
grant execute on function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) to authenticated;

create policy contratantes_select on public.contratantes for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy contratantes_insert on public.contratantes for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy contratantes_update on public.contratantes for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy contratos_select on public.contratos for select to authenticated using(privado.usuario_tem_acesso_contrato(id));
create policy contratos_insert on public.contratos for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy contratos_update on public.contratos for update to authenticated using(privado.usuario_tem_acesso_contrato(id) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy versoes_contrato_select on public.versoes_contrato for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy versoes_contrato_insert on public.versoes_contrato for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
commit;

-- ============================================================

-- MIGRATION 20261101210053_0004_fontes_orcamento_listas
begin;
create table public.fontes_normativas(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid references public.contratos(id) on delete restrict,tipo text not null,titulo text not null,referencia text,descricao text,situacao text not null default 'rascunho' check(situacao in ('rascunho','ativa','inativa','revogada')),versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now());
create index fontes_normativas_escopo_idx on public.fontes_normativas(id_organizacao,id_contrato,tipo,situacao);
create table public.versoes_fontes_normativas(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid references public.contratos(id) on delete restrict,id_fonte uuid not null references public.fontes_normativas(id) on delete restrict,versao integer not null,inicio_vigencia date,fim_vigencia date,id_arquivo uuid,conteudo_texto text,metadados jsonb not null default '{}'::jsonb,hash text not null,aprovado_por uuid references auth.users(id) on delete set null,aprovado_em timestamptz,criado_em timestamptz not null default now(),constraint versoes_fontes_normativas_uk unique(id_fonte,versao),constraint versoes_fontes_vigencia_ck check(fim_vigencia is null or inicio_vigencia is null or fim_vigencia>=inicio_vigencia));
create table public.aplicabilidades_fonte(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_fonte_versao uuid not null references public.versoes_fontes_normativas(id) on delete restrict,aplicavel boolean not null default true,fundamento text,aprovado_por uuid references auth.users(id) on delete set null,aprovado_em timestamptz,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now(),constraint aplicabilidades_fonte_uk unique(id_fonte_versao,id_contrato));
create table public.propostas_orcamentarias(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,titulo text not null,situacao text not null default 'rascunho' check(situacao in ('rascunho','ativa','substituida','encerrada')),versao_atual integer not null default 0,versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now());
create index propostas_orcamentarias_contrato_idx on public.propostas_orcamentarias(id_organizacao,id_contrato,situacao);
create table public.versoes_proposta(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_proposta uuid not null references public.propostas_orcamentarias(id) on delete restrict,numero_versao integer not null,vigencia_inicio date,vigencia_fim date,valor_total numeric(18,2) not null default 0,hash text not null,situacao text not null default 'rascunho' check(situacao in ('rascunho','publicada','substituida')),aprovado_por uuid references auth.users(id) on delete set null,aprovado_em timestamptz,criado_em timestamptz not null default now(),constraint versoes_proposta_uk unique(id_proposta,numero_versao),constraint versoes_proposta_vigencia_ck check(vigencia_fim is null or vigencia_inicio is null or vigencia_fim>=vigencia_inicio));
create table public.linhas_orcamentarias(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_versao_proposta uuid not null references public.versoes_proposta(id) on delete cascade,codigo text not null,grupo text,rubrica text,subrubrica text,descricao text not null,quantidade numeric(18,4) not null default 1,valor_unitario numeric(18,2) not null default 0,valor_total numeric(18,2) not null default 0,limite_remanejamento_percentual numeric(7,4),metadados jsonb not null default '{}'::jsonb,criado_em timestamptz not null default now(),constraint linhas_orcamentarias_codigo_uk unique(id_versao_proposta,codigo));
create index linhas_orcamentarias_contrato_idx on public.linhas_orcamentarias(id_contrato,id_versao_proposta);
create table public.listas_verificacao(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,nome text not null,descricao text,situacao text not null default 'rascunho' check(situacao in ('rascunho','ativa','inativa')),versao_atual integer not null default 0,versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now());
create table public.versoes_lista(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_lista uuid not null references public.listas_verificacao(id) on delete restrict,numero_versao integer not null,vigencia_inicio date,vigencia_fim date,situacao text not null default 'rascunho' check(situacao in ('rascunho','publicada','substituida')),aprovado_por uuid references auth.users(id) on delete set null,aprovado_em timestamptz,criado_em timestamptz not null default now(),constraint versoes_lista_uk unique(id_lista,numero_versao));
create table public.itens_lista(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_versao_lista uuid not null references public.versoes_lista(id) on delete cascade,codigo text not null,descricao text not null,categoria text,obrigatorio boolean not null default true,aplicavel boolean not null default true,impeditivo boolean not null default false,criticidade text not null default 'media' check(criticidade in ('baixa','media','alta','critica')),id_fonte_versao uuid references public.versoes_fontes_normativas(id) on delete set null,regra_validacao jsonb not null default '{}'::jsonb,ordem integer not null default 0,criado_em timestamptz not null default now(),constraint itens_lista_codigo_uk unique(id_versao_lista,codigo));
create table public.regras_conformidade(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,codigo text not null,descricao text not null,tipo text not null default 'deterministica',efeito_portao boolean not null default true,id_fonte_versao uuid references public.versoes_fontes_normativas(id) on delete set null,configuracao jsonb not null default '{}'::jsonb,situacao text not null default 'rascunho' check(situacao in ('rascunho','ativa','inativa','substituida')),versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now(),constraint regras_conformidade_codigo_uk unique(id_contrato,codigo));
create table public.regras_preventivas(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid references public.contratos(id) on delete restrict,id_contratante uuid references public.contratantes(id) on delete restrict,codigo_regra text not null,origem_precedente uuid,descricao text not null,efeito text not null default 'informativo' check(efeito in ('informativo','alerta','bloqueio')),criticidade text not null default 'media' check(criticidade in ('baixa','media','alta','critica')),escopo_aplicacao text not null default 'contrato' check(escopo_aplicacao in ('contrato','contratante','tipo_contrato','organizacao')),tipo_contrato text,vigencia_inicio date,vigencia_fim date,numero_versao integer not null default 1,situacao text not null default 'candidata' check(situacao in ('candidata','ativa','inativa','rejeitada','substituida')),versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now(),constraint regras_preventivas_codigo_uk unique(id_organizacao,codigo_regra));
create table public.revisoes_regras_preventivas(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid references public.contratos(id) on delete restrict,id_regra uuid not null references public.regras_preventivas(id) on delete restrict,versao integer not null,decisao text not null check(decisao in ('aprovada','rejeitada','solicitada_ajuste','inativada')),fundamento text not null,revisor uuid references auth.users(id) on delete set null,data timestamptz not null default now(),snapshot jsonb not null default '{}'::jsonb,constraint revisoes_regras_preventivas_uk unique(id_regra,versao));

alter table public.fontes_normativas enable row level security; alter table public.versoes_fontes_normativas enable row level security; alter table public.aplicabilidades_fonte enable row level security; alter table public.propostas_orcamentarias enable row level security; alter table public.versoes_proposta enable row level security; alter table public.linhas_orcamentarias enable row level security; alter table public.listas_verificacao enable row level security; alter table public.versoes_lista enable row level security; alter table public.itens_lista enable row level security; alter table public.regras_conformidade enable row level security; alter table public.regras_preventivas enable row level security; alter table public.revisoes_regras_preventivas enable row level security;

create policy fontes_select on public.fontes_normativas for select to authenticated using((id_contrato is null and privado.usuario_tem_acesso_organizacao(id_organizacao)) or (id_contrato is not null and privado.usuario_tem_acesso_contrato(id_contrato)));
create policy fontes_write on public.fontes_normativas for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy versoes_fontes_select on public.versoes_fontes_normativas for select to authenticated using((id_contrato is null and privado.usuario_tem_acesso_organizacao(id_organizacao)) or (id_contrato is not null and privado.usuario_tem_acesso_contrato(id_contrato)));
create policy versoes_fontes_insert on public.versoes_fontes_normativas for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy aplicabilidades_select on public.aplicabilidades_fonte for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy propostas_select on public.propostas_orcamentarias for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy propostas_write on public.propostas_orcamentarias for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy versoes_proposta_select on public.versoes_proposta for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy linhas_orcamentarias_select on public.linhas_orcamentarias for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy linhas_orcamentarias_write on public.linhas_orcamentarias for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy listas_select on public.listas_verificacao for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy listas_write on public.listas_verificacao for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy versoes_lista_select on public.versoes_lista for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy itens_lista_select on public.itens_lista for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy itens_lista_write on public.itens_lista for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy regras_conformidade_select on public.regras_conformidade for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy regras_conformidade_write on public.regras_conformidade for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy regras_preventivas_select on public.regras_preventivas for select to authenticated using((id_contrato is null and privado.usuario_tem_acesso_organizacao(id_organizacao)) or (id_contrato is not null and privado.usuario_tem_acesso_contrato(id_contrato)));
create policy revisoes_regras_preventivas_select on public.revisoes_regras_preventivas for select to authenticated using((id_contrato is null and privado.usuario_tem_acesso_organizacao(id_organizacao)) or (id_contrato is not null and privado.usuario_tem_acesso_contrato(id_contrato)));

create trigger fontes_normativas_touch before update on public.fontes_normativas for each row execute function privado.tocar_atualizado_em(); create trigger propostas_orcamentarias_touch before update on public.propostas_orcamentarias for each row execute function privado.tocar_atualizado_em(); create trigger listas_verificacao_touch before update on public.listas_verificacao for each row execute function privado.tocar_atualizado_em(); create trigger regras_conformidade_touch before update on public.regras_conformidade for each row execute function privado.tocar_atualizado_em(); create trigger regras_preventivas_touch before update on public.regras_preventivas for each row execute function privado.tocar_atualizado_em();
commit;

-- ============================================================

-- MIGRATION 20261101210110_0005_storage_documentos
begin;
insert into storage.buckets(id,name,public) values('contaos-documentos','contaos-documentos',false) on conflict(id) do update set public=false;
create table public.arquivos(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid references public.contratos(id) on delete restrict,bucket text not null default 'contaos-documentos',path text not null,nome_original text not null,mime text,tamanho bigint not null default 0 check(tamanho>=0),sha256 text not null,status_seguranca text not null default 'pendente' check(status_seguranca in ('pendente','aprovado','quarentena','bloqueado')),origem text not null default 'upload',criado_por uuid references auth.users(id) on delete set null,criado_em timestamptz not null default now(),constraint arquivos_bucket_path_uk unique(bucket,path));
create index arquivos_org_sha_idx on public.arquivos(id_organizacao,sha256); create index arquivos_contrato_idx on public.arquivos(id_contrato,criado_em desc);
create table public.documentos_contrato(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,tipo text not null,titulo text not null,categoria text,situacao text not null default 'ativo' check(situacao in ('ativo','inativo','substituido')),versao_atual integer not null default 0,versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now());
create index documentos_contrato_idx on public.documentos_contrato(id_contrato,tipo,situacao);
create table public.documentos_competencia(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_competencia uuid not null,tipo text not null,titulo text not null,categoria text,id_requisito_competencia uuid,situacao text not null default 'ativo' check(situacao in ('ativo','inativo','substituido')),versao_atual integer not null default 0,versao_registro bigint not null default 1,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now());
create index documentos_competencia_idx on public.documentos_competencia(id_competencia,tipo,situacao);
create table public.versoes_documento(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_documento_contrato uuid references public.documentos_contrato(id) on delete restrict,id_documento_competencia uuid references public.documentos_competencia(id) on delete restrict,id_documento uuid generated always as (coalesce(id_documento_contrato,id_documento_competencia)) stored,numero_versao integer not null,id_arquivo uuid not null references public.arquivos(id) on delete restrict,hash text not null,motivo_substituicao text,metadados_extraidos jsonb not null default '{}'::jsonb,enviado_por uuid references auth.users(id) on delete set null,criado_em timestamptz not null default now(),constraint versoes_documento_escopo_ck check(num_nonnulls(id_documento_contrato,id_documento_competencia)=1),constraint versoes_documento_contrato_uk unique(id_documento_contrato,numero_versao),constraint versoes_documento_competencia_uk unique(id_documento_competencia,numero_versao));
create index versoes_documento_doc_idx on public.versoes_documento(id_documento,numero_versao desc); create index versoes_documento_contrato_idx on public.versoes_documento(id_contrato,criado_em desc);
create table public.processamentos_documento(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_versao_documento uuid not null references public.versoes_documento(id) on delete cascade,etapa text not null,status text not null default 'pendente' check(status in ('pendente','processando','concluido','falhou','cancelado')),tentativas integer not null default 0,erro_codigo text,erro_detalhe text,resultado jsonb not null default '{}'::jsonb,iniciado_em timestamptz,concluido_em timestamptz,criado_em timestamptz not null default now(),atualizado_em timestamptz not null default now()); create index processamentos_documento_fila_idx on public.processamentos_documento(status,etapa,criado_em);
create table public.paginas_documento(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_versao_documento uuid not null references public.versoes_documento(id) on delete cascade,numero_pagina integer not null check(numero_pagina>0),texto_extraido text,hash_texto text,metadados jsonb not null default '{}'::jsonb,criado_em timestamptz not null default now(),constraint paginas_documento_uk unique(id_versao_documento,numero_pagina));
create table public.fragmentos_documento(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null references public.organizacoes(id) on delete restrict,id_contrato uuid not null references public.contratos(id) on delete restrict,id_versao_documento uuid not null references public.versoes_documento(id) on delete cascade,pagina_inicio integer,pagina_fim integer,indice_fragmento integer not null,texto text not null,metadados jsonb not null default '{}'::jsonb,embedding extensions.vector,modelo_embedding text,criado_em timestamptz not null default now(),constraint fragmentos_documento_uk unique(id_versao_documento,indice_fragmento)); create index fragmentos_documento_escopo_idx on public.fragmentos_documento(id_organizacao,id_contrato,id_versao_documento);
alter table public.arquivos enable row level security; alter table public.documentos_contrato enable row level security; alter table public.documentos_competencia enable row level security; alter table public.versoes_documento enable row level security; alter table public.processamentos_documento enable row level security; alter table public.paginas_documento enable row level security; alter table public.fragmentos_documento enable row level security;
create policy arquivos_select on public.arquivos for select to authenticated using((id_contrato is null and privado.usuario_tem_acesso_organizacao(id_organizacao)) or (id_contrato is not null and privado.usuario_tem_acesso_contrato(id_contrato)));
create policy arquivos_insert on public.arquivos for insert to authenticated with check((id_contrato is null and privado.usuario_tem_acesso_organizacao(id_organizacao)) or (id_contrato is not null and privado.usuario_tem_acesso_contrato(id_contrato)));
create policy documentos_contrato_select on public.documentos_contrato for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy documentos_contrato_write on public.documentos_contrato for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy documentos_competencia_select on public.documentos_competencia for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy documentos_competencia_write on public.documentos_competencia for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy versoes_documento_select on public.versoes_documento for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy versoes_documento_insert on public.versoes_documento for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]));
create policy processamentos_select on public.processamentos_documento for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato)); create policy paginas_select on public.paginas_documento for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato)); create policy fragmentos_select on public.fragmentos_documento for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create trigger documentos_contrato_touch before update on public.documentos_contrato for each row execute function privado.tocar_atualizado_em(); create trigger documentos_competencia_touch before update on public.documentos_competencia for each row execute function privado.tocar_atualizado_em(); create trigger processamentos_documento_touch before update on public.processamentos_documento for each row execute function privado.tocar_atualizado_em();
commit;

-- ============================================================

-- MIGRATION 20261101210948_0006_competencias_analise
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

-- ============================================================

-- MIGRATION 20261101211016_0007_portoes_apresentacao
begin;

create table public.aprovacoes (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  tipo text not null check(tipo in ('apresentacao','reapresentacao','parecer_interno','contestacao','regra','controle','remediacao')),
  status text not null default 'aprovada' check(status in ('pendente','aprovada','rejeitada','revogada')),
  aprovado_por uuid references auth.users(id) on delete set null,
  fundamento text,
  hash_contexto text not null,
  percentual_conformidade numeric(5,2),
  id_execucao_analise uuid references public.execucoes_analise(id) on delete restrict,
  criado_em timestamptz not null default now()
);
create index aprovacoes_comp_idx on public.aprovacoes(id_competencia,tipo,criado_em desc);

create table public.pacotes_competencia (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  numero integer not null,
  tipo text not null default 'apresentacao' check(tipo in ('apresentacao','reapresentacao')),
  status text not null default 'congelado' check(status in ('preparando','congelado','apresentado','substituido')),
  hash_pacote text not null,
  criado_por uuid references auth.users(id) on delete set null,
  congelado_em timestamptz,
  criado_em timestamptz not null default now(),
  constraint pacotes_competencia_uk unique(id_competencia,numero,tipo)
);
create index pacotes_competencia_comp_idx on public.pacotes_competencia(id_competencia,tipo,numero desc);

create table public.itens_pacote_competencia (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  id_pacote uuid not null references public.pacotes_competencia(id) on delete restrict,
  entidade_tipo text not null,
  entidade_id uuid not null,
  versao_id uuid,
  hash text not null,
  ordem integer not null default 0,
  metadados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index itens_pacote_competencia_idx on public.itens_pacote_competencia(id_pacote,ordem);

create table public.apresentacoes_contratante (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_competencia uuid not null references public.competencias(id) on delete restrict,
  id_pacote uuid not null references public.pacotes_competencia(id) on delete restrict,
  numero_rodada integer not null default 1,
  tipo text not null default 'apresentacao' check(tipo in ('apresentacao','reapresentacao')),
  protocolo text,
  forma_apresentacao text,
  id_comprovante_arquivo uuid references public.arquivos(id) on delete restrict,
  idempotency_key text not null,
  apresentado_em timestamptz not null default now(),
  apresentado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  constraint apresentacoes_idempotency_uk unique(id_organizacao,idempotency_key)
);
create index apresentacoes_comp_idx on public.apresentacoes_contratante(id_competencia,numero_rodada desc);
create unique index apresentacoes_protocolo_uidx on public.apresentacoes_contratante(id_contrato,protocolo) where protocolo is not null;

alter table public.aprovacoes enable row level security;
alter table public.pacotes_competencia enable row level security;
alter table public.itens_pacote_competencia enable row level security;
alter table public.apresentacoes_contratante enable row level security;

create policy aprovacoes_select on public.aprovacoes for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy pacotes_competencia_select on public.pacotes_competencia for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy itens_pacote_competencia_select on public.itens_pacote_competencia for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy apresentacoes_contratante_select on public.apresentacoes_contratante for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));

create or replace function public.aprovar_apresentacao(p_id_competencia uuid,p_fundamento text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_portao jsonb; v_exec uuid; v_aprov uuid; v_hash text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]) then raise exception 'Perfil sem permissão para aprovação.'; end if;
  if v.situacao not in ('em_analise','em_reanalise','pendente_correcao','rascunho') then raise exception 'Situação não elegível para aprovação.'; end if;
  v_portao:=public.avaliar_portao_conformidade(v.id);
  if coalesce((v_portao->>'liberado')::boolean,false) is not true then raise exception 'A competência não atingiu 100,00%% de conformidade.'; end if;
  select id into v_exec from public.execucoes_analise where id_competencia=v.id and status='concluida' order by concluida_em desc nulls last,criado_em desc limit 1;
  v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,coalesce(v_exec::text,''),v_portao::text,coalesce(p_fundamento,'')),'sha256'),'hex');
  insert into public.aprovacoes(id_organizacao,id_contrato,id_competencia,tipo,status,aprovado_por,fundamento,hash_contexto,percentual_conformidade,id_execucao_analise)
  values(v.id_organizacao,v.id_contrato,v.id,'apresentacao','aprovada',auth.uid(),p_fundamento,v_hash,100.00,v_exec) returning id into v_aprov;
  update public.competencias set situacao='pode_apresentar_contratante',percentual_conformidade=100.00,liberada_para_apresentacao_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'CompetenciaLiberadaParaApresentacao','competencias',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','pode_apresentar_contratante','id_aprovacao',v_aprov));
  return jsonb_build_object('id_aprovacao',v_aprov,'situacao','pode_apresentar_contratante','percentual_conformidade',100.00);
end;$$;
revoke all on function public.aprovar_apresentacao(uuid,text) from public;
grant execute on function public.aprovar_apresentacao(uuid,text) to authenticated;

create or replace function public.registrar_apresentacao(p_id_competencia uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_pacote uuid; v_num integer; v_hash text; v_apres uuid; v_exist uuid;
begin
  if nullif(trim(p_idempotency_key),'') is null then raise exception 'idempotency_key obrigatório.'; end if;
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  select id into v_exist from public.apresentacoes_contratante where id_organizacao=v.id_organizacao and idempotency_key=p_idempotency_key;
  if v_exist is not null then return v_exist; end if;
  if v.situacao <> 'pode_apresentar_contratante' then raise exception 'Competência não liberada para apresentação.'; end if;
  if not exists(select 1 from public.aprovacoes a where a.id_competencia=v.id and a.tipo='apresentacao' and a.status='aprovada') then raise exception 'Aprovação humana ausente.'; end if;
  select coalesce(max(numero),0)+1 into v_num from public.pacotes_competencia where id_competencia=v.id and tipo='apresentacao';
  select encode(extensions.digest(string_agg(x.hash,'|' order by x.id::text),'sha256'),'hex') into v_hash
  from (
    select vd.id,vd.hash from public.versoes_documento vd join public.documentos_competencia dc on dc.id=vd.id_documento_competencia
    where dc.id_competencia=v.id and dc.situacao='ativo'
    union all
    select pi.id,pi.hash from public.pareceres_internos pi where pi.id_competencia=v.id and pi.status='aprovado'
  ) x;
  v_hash:=coalesce(v_hash,encode(extensions.digest(v.id::text,'sha256'),'hex'));
  insert into public.pacotes_competencia(id_organizacao,id_contrato,id_competencia,numero,tipo,status,hash_pacote,criado_por,congelado_em)
  values(v.id_organizacao,v.id_contrato,v.id,v_num,'apresentacao','congelado',v_hash,auth.uid(),now()) returning id into v_pacote;
  insert into public.itens_pacote_competencia(id_organizacao,id_contrato,id_competencia,id_pacote,entidade_tipo,entidade_id,versao_id,hash,ordem)
  select v.id_organizacao,v.id_contrato,v.id,v_pacote,'documento_competencia',dc.id,vd.id,vd.hash,row_number() over(order by dc.tipo,dc.id)
  from public.documentos_competencia dc join lateral (select * from public.versoes_documento x where x.id_documento_competencia=dc.id order by numero_versao desc limit 1) vd on true
  where dc.id_competencia=v.id and dc.situacao='ativo';
  insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,id_pacote,numero_rodada,tipo,protocolo,forma_apresentacao,id_comprovante_arquivo,idempotency_key,apresentado_por)
  values(v.id_organizacao,v.id_contrato,v.id,v_pacote,1,'apresentacao',p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo,p_idempotency_key,auth.uid()) returning id into v_apres;
  update public.pacotes_competencia set status='apresentado' where id=v_pacote;
  update public.competencias set situacao='aguardando_contratante',versao_pacote_atual=v_num where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'ApresentacaoRegistrada','apresentacoes_contratante',v_apres,null,jsonb_build_object('id_competencia',v.id,'id_pacote',v_pacote,'protocolo',p_protocolo));
  return v_apres;
end;$$;
revoke all on function public.registrar_apresentacao(uuid,text,text,text,uuid) from public;
grant execute on function public.registrar_apresentacao(uuid,text,text,text,uuid) to authenticated;

commit;

-- ============================================================

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

-- ============================================================

-- MIGRATION 20261101211210_0011_financeiro_v3
begin;

create table public.fornecedores (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 documento text, nome_razao_social text not null, nome_fantasia text, tipo text, status text not null default 'ativo' check(status in ('ativo','inativo','bloqueado')),
 risco_documental text not null default 'nao_avaliado' check(risco_documental in ('nao_avaliado','baixo','medio','alto','critico')),
 metadados jsonb not null default '{}'::jsonb, versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create unique index fornecedores_doc_uidx on public.fornecedores(id_organizacao,regexp_replace(documento,'\D','','g')) where documento is not null;
create index fornecedores_nome_idx on public.fornecedores(id_organizacao,nome_razao_social);

create table public.fontes_financeiras (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, tipo text not null, nome text not null, configuracao_ref text,
 ativa boolean not null default true, versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index fontes_financeiras_idx on public.fontes_financeiras(id_contrato,tipo,ativa);

create table public.importacoes_financeiras (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_fonte uuid not null references public.fontes_financeiras(id) on delete restrict,
 id_arquivo uuid references public.arquivos(id) on delete restrict, hash text not null, chave_deduplicacao text not null,
 status text not null default 'pendente' check(status in ('pendente','processando','concluida','falhou','cancelada')),
 total_registros integer not null default 0, total_importado integer not null default 0, total_rejeitado integer not null default 0,
 erro_detalhe text, iniciado_em timestamptz, concluido_em timestamptz, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(), constraint importacoes_financeiras_dedup_uk unique(id_fonte,chave_deduplicacao));
create index importacoes_financeiras_status_idx on public.importacoes_financeiras(id_contrato,status,criado_em desc);

create table public.transacoes_financeiras (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_importacao uuid references public.importacoes_financeiras(id) on delete restrict,
 data date not null, descricao text not null, documento text, id_fornecedor uuid references public.fornecedores(id) on delete restrict,
 fornecedor_nome_original text, fornecedor_documento_original text, valor numeric(18,2) not null, tipo text not null,
 hash_origem text not null, dados_brutos jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now(),
 constraint transacoes_hash_uk unique(id_contrato,hash_origem));
create index transacoes_financeiras_data_idx on public.transacoes_financeiras(id_contrato,data);
create index transacoes_financeiras_fornecedor_idx on public.transacoes_financeiras(id_fornecedor,data);
create index transacoes_financeiras_documento_idx on public.transacoes_financeiras(id_contrato,documento);

create table public.documentos_transacao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_transacao uuid not null references public.transacoes_financeiras(id) on delete restrict,
 id_versao_documento uuid not null references public.versoes_documento(id) on delete restrict, tipo text not null,
 criado_em timestamptz not null default now(), constraint documentos_transacao_uk unique(id_transacao,id_versao_documento,tipo));

create table public.contratos_fornecedores (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_fornecedor uuid not null references public.fornecedores(id) on delete restrict,
 numero_instrumento text, objeto text, vigencia_inicio date, vigencia_fim date, valor numeric(18,2), status text not null default 'ativo' check(status in ('ativo','suspenso','encerrado','cancelado')),
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint contratos_fornecedores_vigencia_ck check(vigencia_fim is null or vigencia_inicio is null or vigencia_fim>=vigencia_inicio));
create index contratos_fornecedores_idx on public.contratos_fornecedores(id_contrato,id_fornecedor,status);

create table public.consumo_orcamentario (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_transacao uuid not null references public.transacoes_financeiras(id) on delete restrict,
 id_linha_orcamentaria uuid not null references public.linhas_orcamentarias(id) on delete restrict, valor_apropriado numeric(18,2) not null,
 regra text, confianca numeric(6,5) check(confianca is null or confianca between 0 and 1), criado_em timestamptz not null default now());
create index consumo_orcamentario_linha_idx on public.consumo_orcamentario(id_linha_orcamentaria,id_transacao);

create table public.conciliacoes (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, periodo date not null, tipo text not null,
 status text not null default 'pendente' check(status in ('pendente','processando','conciliada','com_diferenca','cancelada')),
 saldo_origem numeric(18,2), saldo_contaos numeric(18,2), diferenca numeric(18,2), resultado jsonb not null default '{}'::jsonb,
 concluido_por uuid references auth.users(id) on delete set null, concluido_em timestamptz, criado_em timestamptz not null default now());
create index conciliacoes_idx on public.conciliacoes(id_contrato,periodo,tipo);

create table public.alertas_preventivos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_transacao uuid references public.transacoes_financeiras(id) on delete restrict,
 regra text not null, severidade text not null check(severidade in ('baixa','media','alta','critica')),
 status text not null default 'aberto' check(status in ('aberto','em_tratamento','resolvido','descartado')),
 descricao text not null, evidencia jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now());
create index alertas_preventivos_idx on public.alertas_preventivos(id_contrato,status,severidade,criado_em desc);

create table public.tratamentos_alertas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_alerta uuid not null references public.alertas_preventivos(id) on delete restrict,
 decisao text not null check(decisao in ('corrigir','justificar','aceitar_risco','descartar')), fundamento text not null,
 id_evidencia_versao_documento uuid references public.versoes_documento(id) on delete restrict, tratado_por uuid references auth.users(id) on delete set null,
 tratado_em timestamptz not null default now(), criado_em timestamptz not null default now());
create index tratamentos_alertas_idx on public.tratamentos_alertas(id_alerta,tratado_em desc);

create table public.tarefas_alerta (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_alerta uuid not null references public.alertas_preventivos(id) on delete restrict,
 descricao text not null, responsavel uuid references auth.users(id) on delete set null, prazo date,
 status text not null default 'pendente' check(status in ('pendente','em_execucao','concluida','cancelada')),
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index tarefas_alerta_idx on public.tarefas_alerta(id_organizacao,responsavel,prazo,status);

alter table public.fornecedores enable row level security; alter table public.fontes_financeiras enable row level security;
alter table public.importacoes_financeiras enable row level security; alter table public.transacoes_financeiras enable row level security;
alter table public.documentos_transacao enable row level security; alter table public.contratos_fornecedores enable row level security;
alter table public.consumo_orcamentario enable row level security; alter table public.conciliacoes enable row level security;
alter table public.alertas_preventivos enable row level security; alter table public.tratamentos_alertas enable row level security;
alter table public.tarefas_alerta enable row level security;

create policy fornecedores_select on public.fornecedores for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy fornecedores_write on public.fornecedores for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy fontes_financeiras_select on public.fontes_financeiras for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy fontes_financeiras_write on public.fontes_financeiras for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy importacoes_financeiras_select on public.importacoes_financeiras for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy transacoes_financeiras_select on public.transacoes_financeiras for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy documentos_transacao_select on public.documentos_transacao for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy contratos_fornecedores_select on public.contratos_fornecedores for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy contratos_fornecedores_write on public.contratos_fornecedores for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy consumo_orcamentario_select on public.consumo_orcamentario for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy conciliacoes_select on public.conciliacoes for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy alertas_preventivos_select on public.alertas_preventivos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy tratamentos_alertas_select on public.tratamentos_alertas for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy tarefas_alerta_select on public.tarefas_alerta for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy tarefas_alerta_write on public.tarefas_alerta for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

create trigger fornecedores_touch before update on public.fornecedores for each row execute function privado.tocar_atualizado_em();
create trigger fontes_financeiras_touch before update on public.fontes_financeiras for each row execute function privado.tocar_atualizado_em();
create trigger contratos_fornecedores_touch before update on public.contratos_fornecedores for each row execute function privado.tocar_atualizado_em();
create trigger tarefas_alerta_touch before update on public.tarefas_alerta for each row execute function privado.tocar_atualizado_em();

create or replace function public.solicitar_importacao_financeira(p_id_fonte uuid,p_id_arquivo uuid,p_hash text,p_chave_deduplicacao text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_f public.fontes_financeiras%rowtype; v_imp uuid; v_exist uuid;
begin
 select * into v_f from public.fontes_financeiras where id=p_id_fonte;
 if v_f.id is null then raise exception 'Fonte financeira não encontrada.'; end if;
 if not privado.usuario_tem_acesso_contrato(v_f.id_contrato) or not privado.usuario_possui_perfil(v_f.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]) then raise exception 'Acesso negado.'; end if;
 select id into v_exist from public.importacoes_financeiras where id_fonte=p_id_fonte and chave_deduplicacao=p_chave_deduplicacao;
 if v_exist is not null then return v_exist; end if;
 insert into public.importacoes_financeiras(id_organizacao,id_contrato,id_fonte,id_arquivo,hash,chave_deduplicacao,status,criado_por)
 values(v_f.id_organizacao,v_f.id_contrato,v_f.id,p_id_arquivo,p_hash,p_chave_deduplicacao,'pendente',auth.uid()) returning id into v_imp;
 perform privado.enfileirar_job('finance_imports',v_f.id_organizacao,v_f.id_contrato,'importacao_financeira',v_imp,jsonb_build_object('id_importacao',v_imp),'finance:'||v_imp::text);
 perform privado.registrar_evento_auditoria(v_f.id_organizacao,'ImportacaoFinanceiraSolicitada','importacoes_financeiras',v_imp,null,jsonb_build_object('id_fonte',v_f.id));
 return v_imp;
end;$$;
revoke all on function public.solicitar_importacao_financeira(uuid,uuid,text,text) from public;
grant execute on function public.solicitar_importacao_financeira(uuid,uuid,text,text) to authenticated;

create or replace function public.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.alertas_preventivos%rowtype; v_trat uuid;
begin
 select * into v from public.alertas_preventivos where id=p_id_alerta for update;
 if v.id is null then raise exception 'Alerta não encontrado.'; end if;
 if not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_decisao not in ('corrigir','justificar','aceitar_risco','descartar') then raise exception 'Decisão inválida.'; end if;
 insert into public.tratamentos_alertas(id_organizacao,id_contrato,id_alerta,decisao,fundamento,id_evidencia_versao_documento,tratado_por)
 values(v.id_organizacao,v.id_contrato,v.id,p_decisao,p_fundamento,p_id_evidencia_versao_documento,auth.uid()) returning id into v_trat;
 update public.alertas_preventivos set status=case when p_decisao='corrigir' then 'em_tratamento' else 'resolvido' end where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AlertaPreventivoTratado','alertas_preventivos',v.id,null,jsonb_build_object('id_tratamento',v_trat,'decisao',p_decisao));
 return v_trat;
end;$$;
revoke all on function public.tratar_alerta_preventivo(uuid,text,text,uuid) from public;
grant execute on function public.tratar_alerta_preventivo(uuid,text,text,uuid) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101211241_0012_inteligencia_v4
begin;

create table public.relacionamentos_conhecimento (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, origem_tipo text not null, origem_id uuid not null,
 destino_tipo text not null, destino_id uuid not null, relacao text not null, peso numeric(8,5), metadados jsonb not null default '{}'::jsonb,
 criado_em timestamptz not null default now());
create index relacionamentos_conhecimento_origem_idx on public.relacionamentos_conhecimento(id_organizacao,origem_tipo,origem_id);
create index relacionamentos_conhecimento_destino_idx on public.relacionamentos_conhecimento(id_organizacao,destino_tipo,destino_id);

create table public.consultas_semanticas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, escopo text not null, texto_consulta text not null,
 filtros jsonb not null default '{}'::jsonb, modelo text, criado_por uuid references auth.users(id) on delete set null,
 status text not null default 'pendente' check(status in ('pendente','processando','concluida','falhou')),
 criado_em timestamptz not null default now());
create index consultas_semanticas_idx on public.consultas_semanticas(id_organizacao,id_contrato,criado_em desc);

create table public.similaridades_precedentes (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, id_consulta uuid not null references public.consultas_semanticas(id) on delete restrict,
 id_precedente uuid not null references public.precedentes(id) on delete restrict, score numeric(8,6) not null,
 modelo text, metadados jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now());
create index similaridades_precedentes_idx on public.similaridades_precedentes(id_consulta,score desc);

create table public.alertas_historicos_transversais (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato_alvo uuid not null references public.contratos(id) on delete restrict, id_precedente uuid not null references public.precedentes(id) on delete restrict,
 id_contrato_origem uuid not null references public.contratos(id) on delete restrict, competencia_origem date, score numeric(8,6),
 status text not null default 'informativo' check(status in ('informativo','revisado','promovido','descartado')),
 criado_em timestamptz not null default now());
create index alertas_historicos_transversais_idx on public.alertas_historicos_transversais(id_contrato_alvo,status,score desc);

create table public.pontuacoes_risco (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, entidade_tipo text not null, entidade_id uuid not null,
 modelo_versao text not null, score numeric(8,6) not null, fatores jsonb not null default '[]'::jsonb,
 explicacao text, fontes jsonb not null default '[]'::jsonb, criado_em timestamptz not null default now());
create index pontuacoes_risco_idx on public.pontuacoes_risco(id_organizacao,entidade_tipo,entidade_id,criado_em desc);

create table public.perfis_contratante (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contratante uuid not null references public.contratantes(id) on delete restrict, versao integer not null, resumo text,
 padroes jsonb not null default '[]'::jsonb, metricas jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now(),
 atualizado_em timestamptz not null default now(), constraint perfis_contratante_uk unique(id_contratante,versao));

create table public.padroes_historicos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contratante uuid not null references public.contratantes(id) on delete restrict, tipo text not null, descricao text not null,
 evidencias jsonb not null default '[]'::jsonb, confianca numeric(6,5) check(confianca is null or confianca between 0 and 1),
 status text not null default 'observado' check(status in ('observado','confirmado','descartado','substituido')), criado_em timestamptz not null default now());
create index padroes_historicos_idx on public.padroes_historicos(id_contratante,tipo,status);

create table public.retornos_modelo (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, id_consulta uuid references public.consultas_semanticas(id) on delete restrict,
 id_execucao_analise uuid references public.execucoes_analise(id) on delete restrict, provedor text, modelo text, prompt_versao text,
 resposta jsonb not null, uso_tokens jsonb not null default '{}'::jsonb, status text not null default 'concluido' check(status in ('concluido','parcial','falhou')),
 fontes jsonb not null default '[]'::jsonb, criado_em timestamptz not null default now());
create index retornos_modelo_idx on public.retornos_modelo(id_organizacao,modelo,criado_em desc);

create table public.regras_candidatas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, origem_tipo text not null, origem_id uuid,
 descricao text not null, fonte jsonb not null default '{}'::jsonb, efeito_proposto text not null default 'informativo' check(efeito_proposto in ('informativo','alerta','bloqueio')),
 status text not null default 'candidata' check(status in ('candidata','em_revisao','aprovada','rejeitada','publicada')),
 criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now());
create index regras_candidatas_idx on public.regras_candidatas(id_organizacao,id_contrato,status,criado_em desc);

create table public.metricas_historicas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contratante uuid references public.contratantes(id) on delete restrict, id_contrato uuid references public.contratos(id) on delete restrict,
 periodo_inicio date, periodo_fim date, metrica text not null, valor_numeric numeric(20,6), valor_texto text,
 dimensoes jsonb not null default '{}'::jsonb, calculado_em timestamptz not null default now(), criado_em timestamptz not null default now());
create index metricas_historicas_idx on public.metricas_historicas(id_organizacao,id_contratante,id_contrato,metrica,periodo_fim desc);

create table public.sessoes_copiloto (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, titulo text, escopo jsonb not null default '{}'::jsonb,
 status text not null default 'ativa' check(status in ('ativa','encerrada','arquivada')), criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index sessoes_copiloto_idx on public.sessoes_copiloto(id_organizacao,id_contrato,criado_por,criado_em desc);

create table public.mensagens_copiloto (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, id_sessao uuid not null references public.sessoes_copiloto(id) on delete restrict,
 papel text not null check(papel in ('usuario','assistente','sistema')), conteudo text not null,
 id_consulta_semantica uuid references public.consultas_semanticas(id) on delete restrict, id_retorno_modelo uuid references public.retornos_modelo(id) on delete restrict,
 criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now());
create index mensagens_copiloto_idx on public.mensagens_copiloto(id_sessao,criado_em);

create table public.fontes_resposta_copiloto (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, id_mensagem uuid not null references public.mensagens_copiloto(id) on delete restrict,
 fonte_tipo text not null, fonte_id uuid, id_versao_documento uuid references public.versoes_documento(id) on delete restrict,
 pagina integer, trecho text, score numeric(8,6), metadados jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now());
create index fontes_resposta_copiloto_idx on public.fontes_resposta_copiloto(id_mensagem,score desc);

alter table public.relacionamentos_conhecimento enable row level security; alter table public.consultas_semanticas enable row level security;
alter table public.similaridades_precedentes enable row level security; alter table public.alertas_historicos_transversais enable row level security;
alter table public.pontuacoes_risco enable row level security; alter table public.perfis_contratante enable row level security;
alter table public.padroes_historicos enable row level security; alter table public.retornos_modelo enable row level security;
alter table public.regras_candidatas enable row level security; alter table public.metricas_historicas enable row level security;
alter table public.sessoes_copiloto enable row level security; alter table public.mensagens_copiloto enable row level security;
alter table public.fontes_resposta_copiloto enable row level security;

create policy relacionamentos_conhecimento_select on public.relacionamentos_conhecimento for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy consultas_semanticas_select on public.consultas_semanticas for select to authenticated using(criado_por=auth.uid() and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy similaridades_precedentes_select on public.similaridades_precedentes for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy alertas_historicos_select on public.alertas_historicos_transversais for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato_alvo));
create policy pontuacoes_risco_select on public.pontuacoes_risco for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy perfis_contratante_select on public.perfis_contratante for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy padroes_historicos_select on public.padroes_historicos for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy retornos_modelo_select on public.retornos_modelo for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy regras_candidatas_select on public.regras_candidatas for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy metricas_historicas_select on public.metricas_historicas for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy sessoes_copiloto_select on public.sessoes_copiloto for select to authenticated using(criado_por=auth.uid() and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy mensagens_copiloto_select on public.mensagens_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.sessoes_copiloto s where s.id=id_sessao and s.criado_por=auth.uid()));
create policy fontes_resposta_copiloto_select on public.fontes_resposta_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.mensagens_copiloto m join public.sessoes_copiloto s on s.id=m.id_sessao where m.id=id_mensagem and s.criado_por=auth.uid()));

create trigger perfis_contratante_touch before update on public.perfis_contratante for each row execute function privado.tocar_atualizado_em();
create trigger sessoes_copiloto_touch before update on public.sessoes_copiloto for each row execute function privado.tocar_atualizado_em();

create or replace function public.iniciar_consulta_copiloto(p_id_contrato uuid,p_id_sessao uuid,p_texto text,p_filtros jsonb default '{}'::jsonb,p_modelo text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_sess uuid; v_cons uuid; v_msg uuid; v_job uuid;
begin
 select id_organizacao into v_org from public.contratos where id=p_id_contrato;
 if v_org is null then raise exception 'Contrato não encontrado.'; end if;
 if not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Acesso negado.'; end if;
 if p_id_sessao is null then
   insert into public.sessoes_copiloto(id_organizacao,id_contrato,titulo,criado_por) values(v_org,p_id_contrato,left(p_texto,120),auth.uid()) returning id into v_sess;
 else
   select id into v_sess from public.sessoes_copiloto where id=p_id_sessao and id_organizacao=v_org and criado_por=auth.uid() and status='ativa';
   if v_sess is null then raise exception 'Sessão inválida.'; end if;
 end if;
 insert into public.consultas_semanticas(id_organizacao,id_contrato,escopo,texto_consulta,filtros,modelo,criado_por,status)
 values(v_org,p_id_contrato,'contrato',p_texto,coalesce(p_filtros,'{}'::jsonb),p_modelo,auth.uid(),'pendente') returning id into v_cons;
 insert into public.mensagens_copiloto(id_organizacao,id_contrato,id_sessao,papel,conteudo,id_consulta_semantica,criado_por)
 values(v_org,p_id_contrato,v_sess,'usuario',p_texto,v_cons,auth.uid()) returning id into v_msg;
 v_job:=privado.enfileirar_job('ai',v_org,p_id_contrato,'consulta_semantica',v_cons,jsonb_build_object('id_consulta',v_cons,'id_sessao',v_sess),'copilot:'||v_cons::text);
 perform privado.registrar_evento_auditoria(v_org,'ConsultaCopilotoSolicitada','consultas_semanticas',v_cons,null,jsonb_build_object('id_sessao',v_sess,'id_job',v_job));
 return jsonb_build_object('id_sessao',v_sess,'id_consulta',v_cons,'id_mensagem',v_msg,'id_job',v_job);
end;$$;
revoke all on function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) from public;
grant execute on function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101211316_0013_conformidade_v5
begin;

create table public.entidades_organizacionais (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_pai uuid references public.entidades_organizacionais(id) on delete restrict, codigo text not null, nome text not null, tipo text,
 status text not null default 'ativa' check(status in ('ativa','inativa')), metadados jsonb not null default '{}'::jsonb,
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint entidades_organizacionais_uk unique(id_organizacao,codigo));
create index entidades_organizacionais_pai_idx on public.entidades_organizacionais(id_organizacao,id_pai,status);

create table public.controles_conformidade (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 codigo text not null, nome text not null, objetivo text not null, categoria text, criticidade text not null default 'media' check(criticidade in ('baixa','media','alta','critica')),
 situacao text not null default 'rascunho' check(situacao in ('rascunho','ativo','inativo','substituido')), versao_atual integer not null default 0,
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint controles_conformidade_uk unique(id_organizacao,codigo));

create table public.versoes_controle (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_controle uuid not null references public.controles_conformidade(id) on delete restrict, versao integer not null, texto text not null,
 evidencia_requerida jsonb not null default '[]'::jsonb, vigencia_inicio date, vigencia_fim date,
 status text not null default 'rascunho' check(status in ('rascunho','publicada','substituida','revogada')),
 aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz, hash text not null, criado_em timestamptz not null default now(),
 constraint versoes_controle_uk unique(id_controle,versao), constraint versoes_controle_vig_ck check(vigencia_fim is null or vigencia_inicio is null or vigencia_fim>=vigencia_inicio));

create table public.execucoes_controle (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_entidade_organizacional uuid references public.entidades_organizacionais(id) on delete restrict, id_controle_versao uuid not null references public.versoes_controle(id) on delete restrict,
 escopo jsonb not null default '{}'::jsonb, periodo_inicio date, periodo_fim date,
 resultado text not null check(resultado in ('conforme','nao_conforme','parcial','nao_aplicavel','inconclusivo')),
 evidencias jsonb not null default '[]'::jsonb, executado_por uuid references auth.users(id) on delete set null,
 executado_em timestamptz not null default now(), criado_em timestamptz not null default now());
create index execucoes_controle_idx on public.execucoes_controle(id_organizacao,periodo_fim,resultado);

create table public.excecoes_controle (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_controle uuid not null references public.controles_conformidade(id) on delete restrict, escopo jsonb not null default '{}'::jsonb,
 motivo text not null, inicio date not null, fim date not null, status text not null default 'pendente' check(status in ('pendente','aprovada','rejeitada','expirada','revogada')),
 aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(), constraint excecoes_controle_periodo_ck check(fim>=inicio));
create index excecoes_controle_idx on public.excecoes_controle(id_controle,status,fim);

create table public.nao_conformidades (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_controle uuid references public.controles_conformidade(id) on delete restrict, id_execucao_controle uuid references public.execucoes_controle(id) on delete restrict,
 id_entidade_organizacional uuid references public.entidades_organizacionais(id) on delete restrict,
 descricao text not null, risco text, severidade text not null default 'media' check(severidade in ('baixa','media','alta','critica')),
 status text not null default 'aberta' check(status in ('aberta','em_analise','em_remediacao','resolvida','aceita','encerrada')),
 responsavel uuid references auth.users(id) on delete set null, prazo date, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index nao_conformidades_idx on public.nao_conformidades(id_organizacao,status,responsavel,prazo);

create table public.planos_remediacao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_nao_conformidade uuid not null references public.nao_conformidades(id) on delete restrict, acoes jsonb not null,
 responsavel uuid references auth.users(id) on delete set null, prazo date,
 status text not null default 'aberto' check(status in ('aberto','em_execucao','concluido','cancelado')),
 evidencias jsonb not null default '[]'::jsonb, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index planos_remediacao_idx on public.planos_remediacao(id_nao_conformidade,status,prazo);

create table public.alteracoes_normativas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_fonte uuid references public.fontes_normativas(id) on delete restrict, id_versao_anterior uuid references public.versoes_fontes_normativas(id) on delete restrict,
 id_versao_nova uuid references public.versoes_fontes_normativas(id) on delete restrict, resumo text not null,
 detectada_em timestamptz not null default now(), status text not null default 'detectada' check(status in ('detectada','em_avaliacao','avaliada','descartada')),
 criado_em timestamptz not null default now());
create index alteracoes_normativas_idx on public.alteracoes_normativas(id_organizacao,status,detectada_em desc);

create table public.avaliacoes_impacto (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_alteracao uuid not null references public.alteracoes_normativas(id) on delete restrict, contratos_afetados uuid[] not null default '{}'::uuid[],
 controles_afetados uuid[] not null default '{}'::uuid[], impacto text not null, decisao text not null,
 aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now());
create index avaliacoes_impacto_idx on public.avaliacoes_impacto(id_alteracao,criado_em desc);

create table public.publicacoes_regras (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_regra_candidata uuid references public.regras_candidatas(id) on delete restrict, id_regra_preventiva uuid references public.regras_preventivas(id) on delete restrict,
 id_avaliacao_impacto uuid references public.avaliacoes_impacto(id) on delete restrict,
 vigencia_inicio date not null, vigencia_fim date, status text not null default 'publicada' check(status in ('publicada','suspensa','encerrada')),
 aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz not null default now(),
 hash text not null, criado_em timestamptz not null default now(),
 constraint publicacoes_regras_alvo_ck check(num_nonnulls(id_regra_candidata,id_regra_preventiva)=1),
 constraint publicacoes_regras_vig_ck check(vigencia_fim is null or vigencia_fim>=vigencia_inicio));
create index publicacoes_regras_idx on public.publicacoes_regras(id_organizacao,status,vigencia_inicio,vigencia_fim);

create table public.riscos_corporativos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_entidade_organizacional uuid references public.entidades_organizacionais(id) on delete restrict, codigo text not null, titulo text not null,
 categoria text, descricao text, probabilidade numeric(6,5), impacto numeric(18,4), exposicao numeric(18,4),
 nivel text not null default 'medio' check(nivel in ('baixo','medio','alto','critico')), status text not null default 'aberto' check(status in ('aberto','em_tratamento','aceito','mitigado','encerrado')),
 responsavel uuid references auth.users(id) on delete set null, tratamento text, prazo date,
 fontes jsonb not null default '[]'::jsonb, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint riscos_corporativos_uk unique(id_organizacao,codigo));
create index riscos_corporativos_idx on public.riscos_corporativos(id_organizacao,nivel,status,responsavel);

alter table public.entidades_organizacionais enable row level security; alter table public.controles_conformidade enable row level security;
alter table public.versoes_controle enable row level security; alter table public.execucoes_controle enable row level security;
alter table public.excecoes_controle enable row level security; alter table public.nao_conformidades enable row level security;
alter table public.planos_remediacao enable row level security; alter table public.alteracoes_normativas enable row level security;
alter table public.avaliacoes_impacto enable row level security; alter table public.publicacoes_regras enable row level security;
alter table public.riscos_corporativos enable row level security;

create policy entidades_org_select on public.entidades_organizacionais for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy entidades_org_write on public.entidades_organizacionais for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy controles_select on public.controles_conformidade for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy controles_write on public.controles_conformidade for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy versoes_controle_select on public.versoes_controle for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy execucoes_controle_select on public.execucoes_controle for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy execucoes_controle_insert on public.execucoes_controle for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy excecoes_controle_select on public.excecoes_controle for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy nao_conformidades_select on public.nao_conformidades for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy nao_conformidades_write on public.nao_conformidades for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy planos_remediacao_select on public.planos_remediacao for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy planos_remediacao_write on public.planos_remediacao for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy alteracoes_normativas_select on public.alteracoes_normativas for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy avaliacoes_impacto_select on public.avaliacoes_impacto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy publicacoes_regras_select on public.publicacoes_regras for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy riscos_corporativos_select on public.riscos_corporativos for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy riscos_corporativos_write on public.riscos_corporativos for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]));

create trigger entidades_org_touch before update on public.entidades_organizacionais for each row execute function privado.tocar_atualizado_em();
create trigger controles_touch before update on public.controles_conformidade for each row execute function privado.tocar_atualizado_em();
create trigger nao_conformidades_touch before update on public.nao_conformidades for each row execute function privado.tocar_atualizado_em();
create trigger planos_remediacao_touch before update on public.planos_remediacao for each row execute function privado.tocar_atualizado_em();
create trigger riscos_corporativos_touch before update on public.riscos_corporativos for each row execute function privado.tocar_atualizado_em();

create or replace function public.publicar_controle(p_id_controle uuid,p_texto text,p_evidencia_requerida jsonb,p_vigencia_inicio date,p_vigencia_fim date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.controles_conformidade%rowtype; v_ver int; v_id uuid; v_hash text;
begin
 select * into v from public.controles_conformidade where id=p_id_controle for update;
 if v.id is null then raise exception 'Controle não encontrado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 v_ver:=v.versao_atual+1; v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,v_ver::text,p_texto,coalesce(p_evidencia_requerida,'[]'::jsonb)::text,p_vigencia_inicio::text,coalesce(p_vigencia_fim::text,'')),'sha256'),'hex');
 update public.versoes_controle set status='substituida' where id_controle=v.id and status='publicada';
 insert into public.versoes_controle(id_organizacao,id_controle,versao,texto,evidencia_requerida,vigencia_inicio,vigencia_fim,status,aprovado_por,aprovado_em,hash)
 values(v.id_organizacao,v.id,v_ver,p_texto,coalesce(p_evidencia_requerida,'[]'::jsonb),p_vigencia_inicio,p_vigencia_fim,'publicada',auth.uid(),now(),v_hash) returning id into v_id;
 update public.controles_conformidade set situacao='ativo',versao_atual=v_ver where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ControlePublicado','controles_conformidade',v.id,null,jsonb_build_object('id_versao',v_id,'versao',v_ver));
 return v_id;
end;$$;
revoke all on function public.publicar_controle(uuid,text,jsonb,date,date) from public;
grant execute on function public.publicar_controle(uuid,text,jsonb,date,date) to authenticated;

create or replace function public.aprovar_excecao_controle(p_id_excecao uuid,p_aprovar boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v public.excecoes_controle%rowtype;
begin
 select * into v from public.excecoes_controle where id=p_id_excecao for update;
 if v.id is null then raise exception 'Exceção não encontrada.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 update public.excecoes_controle set status=case when p_aprovar then 'aprovada' else 'rejeitada' end,aprovado_por=auth.uid(),aprovado_em=now() where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ExcecaoControleRevisada','excecoes_controle',v.id,null,jsonb_build_object('aprovada',p_aprovar));
end;$$;
revoke all on function public.aprovar_excecao_controle(uuid,boolean) from public;
grant execute on function public.aprovar_excecao_controle(uuid,boolean) to authenticated;

create or replace function public.encerrar_nao_conformidade(p_id_nao_conformidade uuid,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.nao_conformidades%rowtype;
begin
 select * into v from public.nao_conformidades where id=p_id_nao_conformidade for update;
 if v.id is null then raise exception 'Não conformidade não encontrada.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if exists(select 1 from public.planos_remediacao where id_nao_conformidade=v.id and status not in ('concluido','cancelado')) then raise exception 'Existem planos de remediação pendentes.'; end if;
 update public.nao_conformidades set status='encerrada' where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'NaoConformidadeEncerrada','nao_conformidades',v.id,jsonb_build_object('status',v.status),jsonb_build_object('status','encerrada','fundamento',p_fundamento));
end;$$;
revoke all on function public.encerrar_nao_conformidade(uuid,text) from public;
grant execute on function public.encerrar_nao_conformidade(uuid,text) to authenticated;

create or replace function public.publicar_regra_candidata(p_id_regra_candidata uuid,p_id_avaliacao_impacto uuid,p_vigencia_inicio date,p_vigencia_fim date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.regras_candidatas%rowtype; v_pub uuid; v_hash text;
begin
 select * into v from public.regras_candidatas where id=p_id_regra_candidata for update;
 if v.id is null then raise exception 'Regra candidata não encontrada.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_id_avaliacao_impacto is null or not exists(select 1 from public.avaliacoes_impacto ai where ai.id=p_id_avaliacao_impacto and ai.id_organizacao=v.id_organizacao and ai.aprovado_por is not null) then raise exception 'Avaliação de impacto aprovada é obrigatória.'; end if;
 v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,p_id_avaliacao_impacto::text,p_vigencia_inicio::text,coalesce(p_vigencia_fim::text,''),v.descricao,v.efeito_proposto),'sha256'),'hex');
 insert into public.publicacoes_regras(id_organizacao,id_regra_candidata,id_avaliacao_impacto,vigencia_inicio,vigencia_fim,status,aprovado_por,hash)
 values(v.id_organizacao,v.id,p_id_avaliacao_impacto,p_vigencia_inicio,p_vigencia_fim,'publicada',auth.uid(),v_hash) returning id into v_pub;
 update public.regras_candidatas set status='publicada' where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraCandidataPublicada','regras_candidatas',v.id,null,jsonb_build_object('id_publicacao',v_pub));
 return v_pub;
end;$$;
revoke all on function public.publicar_regra_candidata(uuid,uuid,date,date) from public;
grant execute on function public.publicar_regra_candidata(uuid,uuid,date,date) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101211348_0014_integracoes_v5
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

-- ============================================================

-- MIGRATION 20261101211500_0015_hardening_seguranca_integridade
begin;

-- Menor privilégio na Data API
revoke all privileges on all tables in schema public from anon;
revoke all privileges on all tables in schema public from authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;

-- Revoga execução implícita/anônima de funções expostas.
revoke execute on all functions in schema public from public, anon;
revoke execute on all functions in schema privado from public, anon, authenticated;

-- Helpers privados usados por RLS.
grant execute on function privado.usuario_tem_acesso_organizacao(uuid) to authenticated;
grant execute on function privado.usuario_tem_acesso_contrato(uuid) to authenticated;
grant execute on function privado.usuario_possui_perfil(uuid,text[]) to authenticated;

-- RPCs públicas permitidas apenas a usuários autenticados.
grant execute on function public.criar_organizacao(text,text,varchar,text) to authenticated;
grant execute on function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) to authenticated;
grant execute on function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) to authenticated;
grant execute on function public.criar_competencia(uuid,date,date,date,date) to authenticated;
grant execute on function public.solicitar_analise_competencia(uuid,text) to authenticated;
grant execute on function public.avaliar_portao_conformidade(uuid) to authenticated;
grant execute on function public.aprovar_apresentacao(uuid,text) to authenticated;
grant execute on function public.registrar_apresentacao(uuid,text,text,text,uuid) to authenticated;
grant execute on function public.promover_precedente_para_regra(uuid,text,text,text,text,text) to authenticated;
grant execute on function public.enfileirar_processamento_documento(uuid,text) to authenticated;
grant execute on function public.registrar_parecer_contratante(uuid,uuid,uuid,text,boolean,text,date,date) to authenticated;
grant execute on function public.avaliar_portao_reapresentacao(uuid) to authenticated;
grant execute on function public.aprovar_contestacao(uuid,boolean,text) to authenticated;
grant execute on function public.liberar_reapresentacao(uuid,text) to authenticated;
grant execute on function public.registrar_reapresentacao(uuid,text,text,text,uuid) to authenticated;
grant execute on function public.solicitar_importacao_financeira(uuid,uuid,text,text) to authenticated;
grant execute on function public.tratar_alerta_preventivo(uuid,text,text,uuid) to authenticated;
grant execute on function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) to authenticated;
grant execute on function public.publicar_controle(uuid,text,jsonb,date,date) to authenticated;
grant execute on function public.aprovar_excecao_controle(uuid,boolean) to authenticated;
grant execute on function public.encerrar_nao_conformidade(uuid,text) to authenticated;
grant execute on function public.publicar_regra_candidata(uuid,uuid,date,date) to authenticated;
grant execute on function public.criar_cliente_api(uuid,text,text[]) to authenticated;
grant execute on function public.rotacionar_cliente_api(uuid) to authenticated;
grant execute on function public.criar_webhook(uuid,text,text,text[]) to authenticated;
grant execute on function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) to authenticated;
grant execute on function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) to authenticated;
grant execute on function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) to authenticated;

-- rls_auto_enable é utilitário do ambiente, não endpoint de API.
do $$ begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public,anon,authenticated';
  end if;
end $$;

-- comandos idempotentes: leitura administrativa, mutação somente backend/RPC.
create policy comandos_idempotentes_select on public.comandos_idempotentes for select to authenticated
using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));

-- Imutabilidade física de históricos críticos.
create or replace function privado.bloquear_mutacao_historico()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Registro histórico imutável: % em %.%',tg_op,tg_table_schema,tg_table_name; end;$$;
revoke all on function privado.bloquear_mutacao_historico() from public,anon,authenticated;

create trigger eventos_auditoria_immutable before update or delete on public.eventos_auditoria for each row execute function privado.bloquear_mutacao_historico();
create trigger versoes_contrato_immutable before update or delete on public.versoes_contrato for each row execute function privado.bloquear_mutacao_historico();
create trigger versoes_documento_immutable before update or delete on public.versoes_documento for each row execute function privado.bloquear_mutacao_historico();
create trigger resultados_requisitos_immutable before update or delete on public.resultados_requisitos for each row execute function privado.bloquear_mutacao_historico();
create trigger evidencias_resultado_immutable before update or delete on public.evidencias_resultado for each row execute function privado.bloquear_mutacao_historico();
create trigger aprovacoes_immutable before update or delete on public.aprovacoes for each row execute function privado.bloquear_mutacao_historico();
create trigger itens_pacote_competencia_immutable before update or delete on public.itens_pacote_competencia for each row execute function privado.bloquear_mutacao_historico();
create trigger itens_pacote_evidencias_immutable before update or delete on public.itens_pacote_evidencias for each row execute function privado.bloquear_mutacao_historico();
create trigger exportacoes_evidencias_immutable before update or delete on public.exportacoes_evidencias for each row execute function privado.bloquear_mutacao_historico();

-- Perfil mínimo espelhado do Auth.
create or replace function privado.criar_usuario_auth()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.usuarios(id_usuario,nome,email)
  values(new.id,coalesce(new.raw_user_meta_data->>'nome',new.raw_user_meta_data->>'full_name'),new.email)
  on conflict(id_usuario) do nothing;
  return new;
end;$$;
revoke all on function privado.criar_usuario_auth() from public,anon,authenticated;
drop trigger if exists contaos_auth_user_created on auth.users;
create trigger contaos_auth_user_created after insert on auth.users for each row execute function privado.criar_usuario_auth();

-- Storage privado: path obrigatório org_uuid/...
insert into storage.buckets(id,name,public) values('contaos-documentos','contaos-documentos',false)
on conflict(id) do update set public=false;

drop policy if exists contaos_storage_select on storage.objects;
drop policy if exists contaos_storage_insert on storage.objects;
create policy contaos_storage_select on storage.objects for select to authenticated
using(bucket_id='contaos-documentos' and (storage.foldername(name))[1] is not null and privado.usuario_tem_acesso_organizacao(((storage.foldername(name))[1])::uuid));
create policy contaos_storage_insert on storage.objects for insert to authenticated
with check(bucket_id='contaos-documentos' and (storage.foldername(name))[1] is not null and privado.usuario_tem_acesso_organizacao(((storage.foldername(name))[1])::uuid));

-- Corrige reapresentação para manter pacote de diligência e pacote de competência distintos.
create or replace function public.registrar_reapresentacao(p_id_ciclo uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.ciclos_diligencia%rowtype; v_comp public.competencias%rowtype; v_num int; v_hash text; v_pack_reap uuid; v_pack_comp uuid; v_apres uuid; v_exist uuid;
begin
 if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;
 if nullif(trim(p_idempotency_key),'') is null then raise exception 'idempotency_key obrigatório.'; end if;
 select * into v from public.ciclos_diligencia where id=p_id_ciclo for update;
 if v.id is null then raise exception 'Ciclo não encontrado.'; end if;
 select * into v_comp from public.competencias where id=v.id_competencia for update;
 if not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]) then raise exception 'Acesso negado.'; end if;
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
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id,v_num,v_hash,jsonb_build_object('rodada',v.numero_rodada,'portao',public.avaliar_portao_reapresentacao(v.id)),auth.uid()) returning id into v_pack_reap;
 insert into public.pacotes_competencia(id_organizacao,id_contrato,id_competencia,numero,tipo,status,hash_pacote,criado_por,congelado_em)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v_num,'reapresentacao','apresentado',v_hash,auth.uid(),now()) returning id into v_pack_comp;
 insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,id_pacote,numero_rodada,tipo,protocolo,forma_apresentacao,id_comprovante_arquivo,idempotency_key,apresentado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v_pack_comp,v.numero_rodada+1,'reapresentacao',p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo,p_idempotency_key,auth.uid()) returning id into v_apres;
 update public.pacotes_reapresentacao set reapresentado_em=now() where id=v_pack_reap;
 update public.ciclos_diligencia set status='reapresentado' where id=v.id;
 update public.competencias set situacao='reapresentado' where id=v.id_competencia;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ReapresentacaoRegistrada','apresentacoes_contratante',v_apres,null,jsonb_build_object('id_ciclo',v.id,'id_pacote_reapresentacao',v_pack_reap,'id_pacote_competencia',v_pack_comp));
 return v_apres;
end;$$;
revoke all on function public.registrar_reapresentacao(uuid,text,text,text,uuid) from public,anon;
grant execute on function public.registrar_reapresentacao(uuid,text,text,text,uuid) to authenticated;

-- Índices de FKs e filtros de RLS mais críticos.
create index if not exists vinculos_usuario_contratos_vinculo_idx on public.vinculos_usuario_contratos(id_vinculo_usuario,ativo);
create index if not exists requisitos_competencia_org_contrato_idx on public.requisitos_competencia(id_organizacao,id_contrato);
create index if not exists documentos_competencia_org_contrato_idx on public.documentos_competencia(id_organizacao,id_contrato,id_competencia);
create index if not exists eventos_auditoria_usuario_idx on public.eventos_auditoria(id_usuario,criado_em desc);
create index if not exists planos_remediacao_resp_idx on public.planos_remediacao(id_organizacao,responsavel,prazo,status);

commit;

-- ============================================================

-- MIGRATION 20261101211533_0016_rpc_privadas_wrappers
begin;

alter function public.aprovar_apresentacao(uuid,text) set schema privado;
alter function public.aprovar_contestacao(uuid,boolean,text) set schema privado;
alter function public.aprovar_excecao_controle(uuid,boolean) set schema privado;
alter function public.avaliar_portao_conformidade(uuid) set schema privado;
alter function public.avaliar_portao_reapresentacao(uuid) set schema privado;
alter function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) set schema privado;
alter function public.criar_cliente_api(uuid,text,text[]) set schema privado;
alter function public.criar_competencia(uuid,date,date,date,date) set schema privado;
alter function public.criar_organizacao(text,text,varchar,text) set schema privado;
alter function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) set schema privado;
alter function public.criar_webhook(uuid,text,text,text[]) set schema privado;
alter function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) set schema privado;
alter function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) set schema privado;
alter function public.encerrar_nao_conformidade(uuid,text) set schema privado;
alter function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) set schema privado;
alter function public.enfileirar_processamento_documento(uuid,text) set schema privado;
alter function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) set schema privado;
alter function public.liberar_reapresentacao(uuid,text) set schema privado;
alter function public.promover_precedente_para_regra(uuid,text,text,text,text,text) set schema privado;
alter function public.publicar_controle(uuid,text,jsonb,date,date) set schema privado;
alter function public.publicar_regra_candidata(uuid,uuid,date,date) set schema privado;
alter function public.registrar_apresentacao(uuid,text,text,text,uuid) set schema privado;
alter function public.registrar_parecer_contratante(uuid,uuid,uuid,text,boolean,text,date,date) set schema privado;
alter function public.registrar_reapresentacao(uuid,text,text,text,uuid) set schema privado;
alter function public.rotacionar_cliente_api(uuid) set schema privado;
alter function public.solicitar_analise_competencia(uuid,text) set schema privado;
alter function public.solicitar_importacao_financeira(uuid,uuid,text,text) set schema privado;
alter function public.tratar_alerta_preventivo(uuid,text,text,uuid) set schema privado;

-- Implementações privadas só podem ser chamadas pelo papel autenticado via wrapper e não são expostas no Data API.
grant execute on all functions in schema privado to authenticated;

create function public.aprovar_apresentacao(p_id_competencia uuid,p_fundamento text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.aprovar_apresentacao($1,$2)$$;
create function public.aprovar_contestacao(p_id_contestacao uuid,p_aprovar boolean,p_fundamento text default null) returns void language sql security invoker set search_path='' as $$select privado.aprovar_contestacao($1,$2,$3)$$;
create function public.aprovar_excecao_controle(p_id_excecao uuid,p_aprovar boolean) returns void language sql security invoker set search_path='' as $$select privado.aprovar_excecao_controle($1,$2)$$;
create function public.avaliar_portao_conformidade(p_id_competencia uuid) returns jsonb language sql stable security invoker set search_path='' as $$select privado.avaliar_portao_conformidade($1)$$;
create function public.avaliar_portao_reapresentacao(p_id_ciclo uuid) returns jsonb language sql stable security invoker set search_path='' as $$select privado.avaliar_portao_reapresentacao($1)$$;
create function public.criar_acesso_temporario_pacote(p_id_pacote uuid,p_expira_em timestamptz,p_descricao_destinatario text default null,p_max_acessos integer default null) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_acesso_temporario_pacote($1,$2,$3,$4)$$;
create function public.criar_cliente_api(p_id_organizacao uuid,p_nome text,p_escopos text[] default '{}'::text[]) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_cliente_api($1,$2,$3)$$;
create function public.criar_competencia(p_id_contrato uuid,p_competencia_referencia date,p_periodo_inicio date default null,p_periodo_fim date default null,p_data_limite date default null) returns uuid language sql security invoker set search_path='' as $$select privado.criar_competencia($1,$2,$3,$4,$5)$$;
create function public.criar_organizacao(p_razao_social text,p_nome_fantasia text default null,p_cnpj varchar default null,p_timezone text default 'America/Bahia') returns uuid language sql security invoker set search_path='' as $$select privado.criar_organizacao($1,$2,$3,$4)$$;
create function public.criar_pacote_evidencias(p_id_organizacao uuid,p_id_contrato uuid,p_escopo jsonb,p_expira_em timestamptz default null) returns uuid language sql security invoker set search_path='' as $$select privado.criar_pacote_evidencias($1,$2,$3,$4)$$;
create function public.criar_webhook(p_id_organizacao uuid,p_nome text,p_url text,p_eventos text[]) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_webhook($1,$2,$3,$4)$$;
create function public.definir_acesso_contrato_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_id_contrato uuid,p_conceder boolean default true) returns void language sql security invoker set search_path='' as $$select privado.definir_acesso_contrato_usuario($1,$2,$3,$4)$$;
create function public.definir_vinculo_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_perfil text,p_escopo_todos_contratos boolean default false,p_ativo boolean default true) returns uuid language sql security invoker set search_path='' as $$select privado.definir_vinculo_usuario($1,$2,$3,$4,$5)$$;
create function public.encerrar_nao_conformidade(p_id_nao_conformidade uuid,p_fundamento text) returns void language sql security invoker set search_path='' as $$select privado.encerrar_nao_conformidade($1,$2)$$;
create function public.enfileirar_evento_webhook(p_id_webhook uuid,p_evento text,p_entidade_tipo text,p_entidade_id uuid,p_payload_ref jsonb) returns uuid language sql security invoker set search_path='' as $$select privado.enfileirar_evento_webhook($1,$2,$3,$4,$5)$$;
create function public.enfileirar_processamento_documento(p_id_versao_documento uuid,p_chave_idempotencia text default null) returns uuid language sql security invoker set search_path='' as $$select privado.enfileirar_processamento_documento($1,$2)$$;
create function public.iniciar_consulta_copiloto(p_id_contrato uuid,p_id_sessao uuid,p_texto text,p_filtros jsonb default '{}'::jsonb,p_modelo text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.iniciar_consulta_copiloto($1,$2,$3,$4,$5)$$;
create function public.liberar_reapresentacao(p_id_ciclo uuid,p_fundamento text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.liberar_reapresentacao($1,$2)$$;
create function public.promover_precedente_para_regra(p_id_precedente uuid,p_codigo_regra text,p_descricao text,p_efeito text default 'informativo',p_criticidade text default 'media',p_escopo_aplicacao text default 'contrato') returns uuid language sql security invoker set search_path='' as $$select privado.promover_precedente_para_regra($1,$2,$3,$4,$5,$6)$$;
create function public.publicar_controle(p_id_controle uuid,p_texto text,p_evidencia_requerida jsonb,p_vigencia_inicio date,p_vigencia_fim date default null) returns uuid language sql security invoker set search_path='' as $$select privado.publicar_controle($1,$2,$3,$4,$5)$$;
create function public.publicar_regra_candidata(p_id_regra_candidata uuid,p_id_avaliacao_impacto uuid,p_vigencia_inicio date,p_vigencia_fim date default null) returns uuid language sql security invoker set search_path='' as $$select privado.publicar_regra_candidata($1,$2,$3,$4)$$;
create function public.registrar_apresentacao(p_id_competencia uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_apresentacao($1,$2,$3,$4,$5)$$;
create function public.registrar_parecer_contratante(p_id_competencia uuid,p_id_apresentacao uuid,p_id_arquivo uuid,p_resultado_geral text,p_parecer_final_favoravel boolean default false,p_numero_documento text default null,p_data_emissao date default null,p_prazo_resposta date default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_parecer_contratante($1,$2,$3,$4,$5,$6,$7,$8)$$;
create function public.registrar_reapresentacao(p_id_ciclo uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_reapresentacao($1,$2,$3,$4,$5)$$;
create function public.rotacionar_cliente_api(p_id_cliente uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.rotacionar_cliente_api($1)$$;
create function public.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa') returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_analise_competencia($1,$2)$$;
create function public.solicitar_importacao_financeira(p_id_fonte uuid,p_id_arquivo uuid,p_hash text,p_chave_deduplicacao text) returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_importacao_financeira($1,$2,$3,$4)$$;
create function public.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.tratar_alerta_preventivo($1,$2,$3,$4)$$;

revoke execute on all functions in schema public from public,anon;
grant execute on all functions in schema public to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101211541_0017_hardening_final
begin;
do $$ begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public,anon,authenticated';
  end if;
end $$;
commit;

-- ============================================================

-- MIGRATION 20261101211716_0018_otimizacao_rls
begin;

-- auth.uid() como initPlan, evitando reavaliação por linha.
drop policy if exists usuarios_select_self on public.usuarios;
create policy usuarios_select_self on public.usuarios for select to authenticated using (id_usuario = (select auth.uid()));
drop policy if exists usuarios_update_self on public.usuarios;
create policy usuarios_update_self on public.usuarios for update to authenticated using (id_usuario = (select auth.uid())) with check (id_usuario = (select auth.uid()));

drop policy if exists vinculos_select on public.vinculos_usuarios;
create policy vinculos_select on public.vinculos_usuarios for select to authenticated using (id_usuario = (select auth.uid()) or privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));

drop policy if exists consultas_semanticas_select on public.consultas_semanticas;
create policy consultas_semanticas_select on public.consultas_semanticas for select to authenticated using(criado_por=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));

drop policy if exists sessoes_copiloto_select on public.sessoes_copiloto;
create policy sessoes_copiloto_select on public.sessoes_copiloto for select to authenticated using(criado_por=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));

drop policy if exists mensagens_copiloto_select on public.mensagens_copiloto;
create policy mensagens_copiloto_select on public.mensagens_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.sessoes_copiloto s where s.id=id_sessao and s.criado_por=(select auth.uid())));

drop policy if exists fontes_resposta_copiloto_select on public.fontes_resposta_copiloto;
create policy fontes_resposta_copiloto_select on public.fontes_resposta_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.mensagens_copiloto m join public.sessoes_copiloto s on s.id=m.id_sessao where m.id=id_mensagem and s.criado_por=(select auth.uid())));

-- Substitui FOR ALL por INSERT/UPDATE explícitos. DELETE permanece negado por ausência de policy.
drop policy if exists contratos_fornecedores_write on public.contratos_fornecedores;
create policy contratos_fornecedores_insert on public.contratos_fornecedores for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[]));
create policy contratos_fornecedores_update on public.contratos_fornecedores for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists controles_write on public.controles_conformidade;
create policy controles_insert on public.controles_conformidade for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy controles_update on public.controles_conformidade for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));

drop policy if exists documentos_competencia_write on public.documentos_competencia;
create policy documentos_competencia_insert on public.documentos_competencia for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]));
create policy documentos_competencia_update on public.documentos_competencia for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists documentos_contrato_write on public.documentos_contrato;
create policy documentos_contrato_insert on public.documentos_contrato for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy documentos_contrato_update on public.documentos_contrato for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists entidades_org_write on public.entidades_organizacionais;
create policy entidades_org_insert on public.entidades_organizacionais for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy entidades_org_update on public.entidades_organizacionais for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));

drop policy if exists fontes_financeiras_write on public.fontes_financeiras;
create policy fontes_financeiras_insert on public.fontes_financeiras for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[]));
create policy fontes_financeiras_update on public.fontes_financeiras for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists fontes_write on public.fontes_normativas;
create policy fontes_insert on public.fontes_normativas for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy fontes_update on public.fontes_normativas for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));

drop policy if exists fornecedores_write on public.fornecedores;
create policy fornecedores_insert on public.fornecedores for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy fornecedores_update on public.fornecedores for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));

drop policy if exists itens_lista_write on public.itens_lista;
create policy itens_lista_insert on public.itens_lista for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy itens_lista_update on public.itens_lista for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists linhas_orcamentarias_write on public.linhas_orcamentarias;
create policy linhas_orcamentarias_insert on public.linhas_orcamentarias for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy linhas_orcamentarias_update on public.linhas_orcamentarias for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists listas_write on public.listas_verificacao;
create policy listas_insert on public.listas_verificacao for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy listas_update on public.listas_verificacao for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists nao_conformidades_write on public.nao_conformidades;
create policy nao_conformidades_insert on public.nao_conformidades for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy nao_conformidades_update on public.nao_conformidades for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));

drop policy if exists planos_acao_write on public.planos_acao;
create policy planos_acao_insert on public.planos_acao for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy planos_acao_update on public.planos_acao for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists planos_remediacao_write on public.planos_remediacao;
create policy planos_remediacao_insert on public.planos_remediacao for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy planos_remediacao_update on public.planos_remediacao for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));

drop policy if exists propostas_write on public.propostas_orcamentarias;
create policy propostas_insert on public.propostas_orcamentarias for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy propostas_update on public.propostas_orcamentarias for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists recursos_admin_write on public.recursos_organizacao;
create policy recursos_admin_insert on public.recursos_organizacao for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create policy recursos_admin_update on public.recursos_organizacao for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));

drop policy if exists regras_conformidade_write on public.regras_conformidade;
create policy regras_conformidade_insert on public.regras_conformidade for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy regras_conformidade_update on public.regras_conformidade for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists riscos_corporativos_write on public.riscos_corporativos;
create policy riscos_corporativos_insert on public.riscos_corporativos for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]));
create policy riscos_corporativos_update on public.riscos_corporativos for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]));

drop policy if exists tarefas_alerta_write on public.tarefas_alerta;
create policy tarefas_alerta_insert on public.tarefas_alerta for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy tarefas_alerta_update on public.tarefas_alerta for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists tarefas_diligencia_write on public.tarefas_diligencia;
create policy tarefas_diligencia_insert on public.tarefas_diligencia for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy tarefas_diligencia_update on public.tarefas_diligencia for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

commit;

-- ============================================================

-- MIGRATION 20261101212010_0019_worker_runtime_vault_vector_notifications
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

-- ============================================================

-- MIGRATION 20261101212154_0020_rpc_analise_diligencia_rag
begin;

-- Solicitação de análise cria execução e job AI de forma idempotente.
create or replace function privado.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa')
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_exec uuid;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if p_tipo not in ('completa','reanálise','parcial') then raise exception 'Tipo de análise inválido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then raise exception 'Situação não permite análise.'; end if;
  insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,versao_motor,iniciada_por,iniciada_em)
  values(v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente','1.0',auth.uid(),now()) returning id into v_exec;
  update public.competencias set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end where id=v.id;
  perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'execucao_analise',v_exec,jsonb_build_object('id_execucao',v_exec,'id_competencia',v.id),'analysis:'||v_exec::text);
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,jsonb_build_object('id_competencia',v.id,'tipo',p_tipo));
  return v_exec;
end;$$;

-- Resultado humano/assistido é sempre nova linha; histórico anterior não é sobrescrito.
create or replace function privado.registrar_resultado_requisito(p_id_execucao uuid,p_id_requisito uuid,p_resultado text,p_justificativa text default null,p_fundamento text default null,p_evidencias jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_exec public.execucoes_analise%rowtype; v_req public.requisitos_competencia%rowtype; v_id uuid; v_ev jsonb; v_portao jsonb;
begin
  select * into v_exec from public.execucoes_analise where id=p_id_execucao;
  select * into v_req from public.requisitos_competencia where id=p_id_requisito;
  if v_exec.id is null or v_req.id is null or v_exec.id_competencia<>v_req.id_competencia then raise exception 'Execução/requisito inválido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_exec.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v_exec.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade','financeiro','contabilidade','rh_dp']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if p_resultado not in ('pendente','em_analise','conforme','nao_conforme','inconclusivo','nao_aplicavel') then raise exception 'Resultado inválido.'; end if;
  if p_resultado='nao_aplicavel' and nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Não aplicável exige fundamento.'; end if;
  insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa,fundamento,metadados)
  values(v_exec.id_organizacao,v_exec.id_contrato,v_exec.id_competencia,v_exec.id,v_req.id,p_resultado,p_justificativa,p_fundamento,jsonb_build_object('origem','revisao_humana')) returning id into v_id;
  if jsonb_typeof(coalesce(p_evidencias,'[]'::jsonb))='array' then
    for v_ev in select * from jsonb_array_elements(coalesce(p_evidencias,'[]'::jsonb)) loop
      insert into public.evidencias_resultado(id_organizacao,id_contrato,id_competencia,id_resultado,id_versao_documento,pagina,trecho,tipo_evidencia,referencia_externa,hash)
      values(v_exec.id_organizacao,v_exec.id_contrato,v_exec.id_competencia,v_id,nullif(v_ev->>'id_versao_documento','')::uuid,nullif(v_ev->>'pagina','')::integer,v_ev->>'trecho',coalesce(v_ev->>'tipo_evidencia','documento'),v_ev->>'referencia_externa',v_ev->>'hash');
    end loop;
  end if;
  v_portao:=privado.avaliar_portao_conformidade(v_exec.id_competencia);
  update public.competencias set percentual_conformidade=coalesce((v_portao->>'percentual')::numeric,0) where id=v_exec.id_competencia;
  perform privado.registrar_evento_auditoria(v_exec.id_organizacao,'ResultadoRequisitoRegistrado','resultados_requisitos',v_id,null,jsonb_build_object('id_requisito',v_req.id,'resultado',p_resultado));
  return v_id;
end;$$;
create function public.registrar_resultado_requisito(p_id_execucao uuid,p_id_requisito uuid,p_resultado text,p_justificativa text default null,p_fundamento text default null,p_evidencias jsonb default '[]'::jsonb)
returns uuid language sql security invoker set search_path='' as $$select privado.registrar_resultado_requisito($1,$2,$3,$4,$5,$6)$$;
revoke all on function public.registrar_resultado_requisito(uuid,uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.registrar_resultado_requisito(uuid,uuid,text,text,text,jsonb) to authenticated;

-- Registro humano de apontamento do contratante no ciclo correto.
create or replace function privado.registrar_apontamento_contratante(p_id_ciclo uuid,p_descricao text,p_fundamento text default null,p_codigo text default null,p_severidade text default 'media',p_fonte_pagina integer default null,p_fonte_trecho text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.ciclos_diligencia%rowtype; v_id uuid;
begin
 select * into v from public.ciclos_diligencia where id=p_id_ciclo;
 if v.id is null then raise exception 'Ciclo não encontrado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_severidade not in ('baixa','media','alta','critica') then raise exception 'Severidade inválida.'; end if;
 insert into public.apontamentos_contratante(id_organizacao,id_contrato,id_competencia,id_ciclo,codigo,descricao,fundamento,severidade,fonte_pagina,fonte_trecho)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id,p_codigo,p_descricao,p_fundamento,p_severidade,p_fonte_pagina,p_fonte_trecho) returning id into v_id;
 update public.ciclos_diligencia set status='em_tratamento' where id=v.id and status='aberto';
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ApontamentoContratanteRegistrado','apontamentos_contratante',v_id,null,jsonb_build_object('id_ciclo',v.id));
 return v_id;
end;$$;
create function public.registrar_apontamento_contratante(p_id_ciclo uuid,p_descricao text,p_fundamento text default null,p_codigo text default null,p_severidade text default 'media',p_fonte_pagina integer default null,p_fonte_trecho text default null)
returns uuid language sql security invoker set search_path='' as $$select privado.registrar_apontamento_contratante($1,$2,$3,$4,$5,$6,$7)$$;
revoke all on function public.registrar_apontamento_contratante(uuid,text,text,text,text,integer,text) from public,anon;
grant execute on function public.registrar_apontamento_contratante(uuid,text,text,text,text,integer,text) to authenticated;

-- Contestação versionada e hash obrigatório.
create or replace function privado.criar_contestacao(p_id_apontamento uuid,p_texto text,p_fundamento text,p_evidencias jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.apontamentos_contratante%rowtype; v_ver int; v_id uuid; v_hash text; v_ev jsonb;
begin
 select * into v from public.apontamentos_contratante where id=p_id_apontamento;
 if v.id is null then raise exception 'Apontamento não encontrado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 select coalesce(max(versao),0)+1 into v_ver from public.contestacoes where id_apontamento=v.id;
 v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,v_ver::text,p_texto,p_fundamento,coalesce(p_evidencias,'[]'::jsonb)::text),'sha256'),'hex');
 insert into public.contestacoes(id_organizacao,id_contrato,id_competencia,id_ciclo,id_apontamento,versao,texto,fundamento,status_aprovacao,criado_por,hash)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id_ciclo,v.id,v_ver,p_texto,p_fundamento,'pendente',auth.uid(),v_hash) returning id into v_id;
 for v_ev in select * from jsonb_array_elements(coalesce(p_evidencias,'[]'::jsonb)) loop
   insert into public.mapas_evidencias_contestacao(id_organizacao,id_contrato,id_competencia,id_contestacao,id_versao_documento,pagina,trecho,descricao,hash)
   values(v.id_organizacao,v.id_contrato,v.id_competencia,v_id,nullif(v_ev->>'id_versao_documento','')::uuid,nullif(v_ev->>'pagina','')::integer,v_ev->>'trecho',v_ev->>'descricao',v_ev->>'hash');
 end loop;
 update public.apontamentos_contratante set status='contestado' where id=v.id;
 return v_id;
end;$$;
create function public.criar_contestacao(p_id_apontamento uuid,p_texto text,p_fundamento text,p_evidencias jsonb default '[]'::jsonb)
returns uuid language sql security invoker set search_path='' as $$select privado.criar_contestacao($1,$2,$3,$4)$$;
revoke all on function public.criar_contestacao(uuid,text,text,jsonb) from public,anon;
grant execute on function public.criar_contestacao(uuid,text,text,jsonb) to authenticated;

-- Tarefa não pode ser concluída por UPDATE genérico.
drop policy if exists tarefas_diligencia_update on public.tarefas_diligencia;
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
create function public.atualizar_tarefa_diligencia(p_id_tarefa uuid,p_descricao text default null,p_responsavel uuid default null,p_prazo date default null)
returns void language sql security invoker set search_path='' as $$select privado.atualizar_tarefa_diligencia($1,$2,$3,$4)$$;
revoke all on function public.atualizar_tarefa_diligencia(uuid,text,uuid,date) from public,anon;
grant execute on function public.atualizar_tarefa_diligencia(uuid,text,uuid,date) to authenticated;

create or replace function privado.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v public.tarefas_diligencia%rowtype;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Tarefa não encontrada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
 if v.responsavel is not null and v.responsavel<>auth.uid() and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Usuário não é responsável pela tarefa.'; end if;
 if p_id_evidencia_versao_documento is null or not exists(select 1 from public.versoes_documento vd where vd.id=p_id_evidencia_versao_documento and vd.id_contrato=v.id_contrato) then raise exception 'Evidência válida é obrigatória.'; end if;
 update public.tarefas_diligencia set status='concluida',id_evidencia_versao_documento=p_id_evidencia_versao_documento where id=v.id;
 if v.id_apontamento is not null and not exists(select 1 from public.tarefas_diligencia td where td.id_apontamento=v.id_apontamento and td.id<>v.id and td.status not in ('concluida','cancelada')) then update public.apontamentos_contratante set status='resolvido' where id=v.id_apontamento and status in ('procedente','em_tratamento'); end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'TarefaDiligenciaConcluida','tarefas_diligencia',v.id,null,jsonb_build_object('id_evidencia',p_id_evidencia_versao_documento));
end;$$;
create function public.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language sql security invoker set search_path='' as $$select privado.concluir_tarefa_diligencia($1,$2)$$;
revoke all on function public.concluir_tarefa_diligencia(uuid,uuid) from public,anon;
grant execute on function public.concluir_tarefa_diligencia(uuid,uuid) to authenticated;

-- Busca de precedentes sem cruzar organização; marca outro contrato como informativo no consumidor.
create or replace function public.worker_buscar_precedentes(p_id_organizacao uuid,p_id_contratante uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 8)
returns table(id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,similaridade double precision,mesmo_contrato boolean)
language sql stable security definer set search_path='' as $$
 select p.id,p.id_contrato_origem,p.competencia_origem,p.problema,p.solucao,p.desfecho,(1-(p.embedding OPERATOR(extensions.<=>) p_embedding))::double precision,(p.id_contrato_origem=p_id_contrato)
 from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo' and p.embedding is not null
 order by p.embedding OPERATOR(extensions.<=>) p_embedding limit least(greatest(p_limite,1),20)
$$;
revoke all on function public.worker_buscar_precedentes(uuid,uuid,uuid,extensions.vector,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_precedentes(uuid,uuid,uuid,extensions.vector,integer) to service_role;

commit;

-- ============================================================

-- MIGRATION 20261101212409_0021_mensagens_ptbr_amigaveis
begin;

create table public.catalogo_mensagens_sistema (
  codigo text primary key,
  categoria text not null,
  severidade text not null check (severidade in ('info','sucesso','aviso','erro')),
  titulo text not null,
  mensagem text not null,
  orientacao text,
  exibir_detalhe_tecnico boolean not null default false,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
alter table public.catalogo_mensagens_sistema enable row level security;
create policy catalogo_mensagens_leitura on public.catalogo_mensagens_sistema for select to anon,authenticated using(true);
grant select on public.catalogo_mensagens_sistema to anon,authenticated;

insert into public.catalogo_mensagens_sistema(codigo,categoria,severidade,titulo,mensagem,orientacao) values
('GERAL_SUCESSO','geral','sucesso','Tudo certo','A operação foi concluída com sucesso.',null),
('GERAL_PROCESSANDO','geral','info','Estamos processando','Seu pedido foi recebido e está sendo processado. Você pode continuar usando o sistema normalmente.','Acompanhe o status nesta tela.'),
('GERAL_ERRO_INESPERADO','geral','erro','Não foi possível concluir','Ocorreu um problema inesperado ao concluir esta ação. Nenhuma informação confirmada foi perdida.','Tente novamente. Se o problema continuar, informe o código exibido ao suporte.'),
('AUTH_NAO_AUTENTICADO','autenticacao','aviso','Sessão necessária','Para continuar, faça login novamente.','Entre novamente na sua conta e repita a ação.'),
('AUTH_SESSAO_EXPIRADA','autenticacao','aviso','Sua sessão expirou','Por segurança, sua sessão foi encerrada.','Faça login novamente para continuar de onde parou.'),
('AUTH_ACESSO_NEGADO','autorizacao','aviso','Acesso não permitido','Seu usuário não tem permissão para realizar esta ação.','Se você acredita que deveria ter acesso, fale com o administrador da sua organização.'),
('AUTH_PERFIL_SEM_PERMISSAO','autorizacao','aviso','Permissão insuficiente','Seu perfil atual não permite concluir esta operação.','Solicite ao administrador a revisão das suas permissões.'),
('REGISTRO_NAO_ENCONTRADO','dados','aviso','Item não encontrado','Não encontramos o item solicitado ou ele não está mais disponível.','Atualize a página e tente novamente.'),
('DADOS_INVALIDOS','validacao','aviso','Revise as informações','Alguns dados informados precisam ser corrigidos antes de continuar.','Confira os campos destacados e tente novamente.'),
('CAMPO_OBRIGATORIO','validacao','aviso','Informação obrigatória','Preencha todas as informações obrigatórias para continuar.','Confira os campos marcados como obrigatórios.'),
('REGISTRO_DUPLICADO','validacao','aviso','Registro já existente','Já existe um registro com essas mesmas informações.','Abra o registro existente ou altere os dados antes de salvar.'),
('CONFLITO_ATUALIZACAO','concorrencia','aviso','Informação atualizada por outra pessoa','Este registro foi alterado enquanto você estava trabalhando nele.','Atualize a tela, confira a versão mais recente e tente novamente.'),
('EVIDENCIA_OBRIGATORIA','conformidade','aviso','Evidência necessária','Esta etapa só pode ser concluída após anexar uma evidência válida.','Anexe o documento ou evidência solicitada e tente novamente.'),
('PORTAO_CONFORMIDADE_100','conformidade','aviso','Ainda não pode ser apresentado','A prestação de contas ainda possui requisitos pendentes ou não conformes.','Conclua 100% dos requisitos obrigatórios antes de liberar a apresentação ao contratante.'),
('PORTAO_REAPRESENTACAO_100','diligencia','aviso','Ainda não pode ser reapresentado','Ainda existem apontamentos da rodada que precisam ser tratados.','Conclua todos os apontamentos obrigatórios antes de liberar a reapresentação.'),
('APROVACAO_HUMANA_OBRIGATORIA','conformidade','aviso','Aprovação necessária','Esta ação exige uma aprovação humana antes de prosseguir.','Encaminhe para o responsável aprovador.'),
('ARQUIVO_UPLOAD_FALHOU','documentos','erro','Não foi possível enviar o arquivo','O arquivo não foi enviado com sucesso.','Verifique sua conexão e tente novamente. O arquivo original não foi alterado.'),
('ARQUIVO_TIPO_NAO_SUPORTADO','documentos','aviso','Formato de arquivo não aceito','Este tipo de arquivo não pode ser processado pelo ContaOS.','Envie o documento em um dos formatos aceitos nesta etapa.'),
('ARQUIVO_MUITO_GRANDE','documentos','aviso','Arquivo acima do limite','O arquivo enviado ultrapassa o tamanho permitido.','Reduza o tamanho do arquivo ou divida o conteúdo em arquivos menores.'),
('DOCUMENTO_PROCESSAMENTO_FALHOU','documentos','erro','Não foi possível analisar o documento','O documento foi recebido, mas ocorreu um problema durante o processamento.','Tente processar novamente. Se o erro continuar, mantenha o arquivo e acione o suporte.'),
('ANALISE_EM_PROCESSAMENTO','analise','info','Análise em andamento','O ContaOS está analisando os documentos e requisitos desta competência.','Você será informado quando a análise estiver concluída.'),
('ANALISE_FALHOU','analise','erro','A análise não foi concluída','Ocorreu um problema durante a análise automática. Nenhuma decisão foi tomada automaticamente.','Tente executar a análise novamente ou encaminhe para revisão humana.'),
('IA_INDISPONIVEL','ia','aviso','Assistente temporariamente indisponível','O recurso de inteligência artificial não conseguiu responder neste momento.','Tente novamente mais tarde. As demais funções do ContaOS continuam disponíveis.'),
('FONTE_INSUFICIENTE','ia','aviso','Informações insuficientes','Não encontramos evidências suficientes para responder com segurança.','Revise os documentos disponíveis ou inclua novas fontes antes de concluir.'),
('IMPORTACAO_FINANCEIRA_FALHOU','financeiro','erro','Importação não concluída','Não foi possível concluir a importação dos dados financeiros.','Confira o arquivo de origem e tente novamente. Nenhum lançamento foi confirmado parcialmente.'),
('CONCILIACAO_COM_DIFERENCA','financeiro','aviso','Diferença encontrada na conciliação','Os valores conciliados apresentam diferença e precisam de revisão.','Confira os lançamentos e documentos relacionados antes de concluir a competência.'),
('ALERTA_PREVENTIVO_ABERTO','financeiro','aviso','Atenção necessária','Foi identificado um ponto que merece revisão antes da prestação de contas.','Analise o alerta, registre o tratamento e anexe a evidência quando aplicável.'),
('WEBHOOK_FALHOU','integracao','aviso','Integração não confirmada','O ContaOS não conseguiu confirmar o envio da informação para o sistema integrado.','O sistema tentará novamente automaticamente. Você pode acompanhar o status da integração.'),
('INTEGRACAO_INDISPONIVEL','integracao','aviso','Integração temporariamente indisponível','O serviço integrado não respondeu neste momento.','O ContaOS tentará novamente quando possível.'),
('FILA_RETRY','processamento','info','Nova tentativa programada','O processamento não foi concluído nesta tentativa e será repetido automaticamente.','Nenhuma ação é necessária agora.'),
('FILA_DLQ','processamento','erro','Processamento precisa de atenção','Após várias tentativas, o processamento ainda não foi concluído.','O registro foi preservado para análise técnica sem perda dos dados originais.'),
('REDE_INDISPONIVEL','conectividade','aviso','Sem conexão com o serviço','Não foi possível se comunicar com o serviço neste momento.','Verifique sua conexão e tente novamente.'),
('LIMITE_REQUISICOES','conectividade','aviso','Muitas solicitações em pouco tempo','Recebemos várias solicitações seguidas e precisamos aguardar alguns instantes.','Aguarde um pouco e tente novamente.'),
('MANUTENCAO','geral','info','Serviço em manutenção','Este recurso está temporariamente em manutenção.','Tente novamente mais tarde.')
on conflict(codigo) do update set categoria=excluded.categoria,severidade=excluded.severidade,titulo=excluded.titulo,mensagem=excluded.mensagem,orientacao=excluded.orientacao,atualizado_em=now();

create table public.catalogo_status_ui (
  dominio text not null,
  codigo text not null,
  rotulo text not null,
  descricao text,
  tom text not null default 'neutro' check(tom in ('neutro','info','sucesso','aviso','erro')),
  ordem integer not null default 0,
  criado_em timestamptz not null default now(),
  primary key(dominio,codigo)
);
alter table public.catalogo_status_ui enable row level security;
create policy catalogo_status_leitura on public.catalogo_status_ui for select to anon,authenticated using(true);
grant select on public.catalogo_status_ui to anon,authenticated;

insert into public.catalogo_status_ui(dominio,codigo,rotulo,descricao,tom,ordem) values
('competencia','rascunho','Rascunho','Competência criada e ainda em preparação.','neutro',10),
('competencia','preparando','Em preparação','Documentos e requisitos estão sendo organizados.','info',20),
('competencia','em_analise','Em análise','A competência está sendo analisada.','info',30),
('competencia','pendente_correcao','Correções pendentes','Existem pontos que precisam ser corrigidos.','aviso',40),
('competencia','em_reanalise','Em reanálise','As correções estão sendo verificadas novamente.','info',50),
('competencia','pode_apresentar_contratante','PODE APRESENTAR AO CONTRATANTE','A competência atingiu os requisitos necessários e foi aprovada para apresentação.','sucesso',60),
('competencia','apresentado','Apresentado','A prestação de contas foi apresentada ao contratante.','info',70),
('competencia','aguardando_contratante','Aguardando contratante','Aguardando análise ou retorno do contratante.','info',80),
('competencia','com_apontamentos','Com apontamentos','O contratante apresentou pontos que precisam ser tratados.','aviso',90),
('competencia','pode_reapresentar_contratante','PODE REAPRESENTAR AO CONTRATANTE','Todos os apontamentos obrigatórios da rodada foram tratados e aprovados.','sucesso',100),
('competencia','reapresentado','Reapresentado','A resposta aos apontamentos foi reapresentada ao contratante.','info',110),
('competencia','validada','Validada','A competência foi validada pelo contratante.','sucesso',120),
('competencia','encerrada','Encerrada','O ciclo desta competência foi encerrado.','sucesso',130),
('competencia','cancelada','Cancelada','Esta competência foi cancelada.','erro',140),
('job','enfileirado','Aguardando processamento','A solicitação entrou na fila de processamento.','info',10),
('job','processando','Processando','O ContaOS está executando esta tarefa.','info',20),
('job','concluido','Concluído','O processamento foi concluído com sucesso.','sucesso',30),
('job','falhou','Falha temporária','A tarefa não foi concluída nesta tentativa.','aviso',40),
('job','cancelado','Interrompido','O processamento foi interrompido e precisa de revisão.','erro',50),
('alerta','aberto','Aberto','O alerta precisa ser analisado.','aviso',10),
('alerta','em_tratamento','Em tratamento','O alerta está sendo tratado.','info',20),
('alerta','resolvido','Resolvido','O alerta foi tratado e encerrado.','sucesso',30),
('alerta','descartado','Descartado','O alerta foi avaliado e descartado com justificativa.','neutro',40)
on conflict(dominio,codigo) do update set rotulo=excluded.rotulo,descricao=excluded.descricao,tom=excluded.tom,ordem=excluded.ordem;

create or replace function public.obter_mensagem_sistema(p_codigo text)
returns jsonb language sql stable security invoker set search_path='' as $$
  select coalesce(
    (select jsonb_build_object('codigo',m.codigo,'categoria',m.categoria,'severidade',m.severidade,'titulo',m.titulo,'mensagem',m.mensagem,'orientacao',m.orientacao) from public.catalogo_mensagens_sistema m where m.codigo=p_codigo),
    (select jsonb_build_object('codigo',m.codigo,'categoria',m.categoria,'severidade',m.severidade,'titulo',m.titulo,'mensagem',m.mensagem,'orientacao',m.orientacao) from public.catalogo_mensagens_sistema m where m.codigo='GERAL_ERRO_INESPERADO')
  )
$$;
revoke all on function public.obter_mensagem_sistema(text) from public;
grant execute on function public.obter_mensagem_sistema(text) to anon,authenticated;

create or replace function public.normalizar_erro_backend(p_codigo_sql text,p_mensagem_tecnica text default null)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare v_codigo text:='GERAL_ERRO_INESPERADO'; v_msg text:=lower(coalesce(p_mensagem_tecnica,''));
begin
  if p_codigo_sql in ('23505') then v_codigo:='REGISTRO_DUPLICADO';
  elsif p_codigo_sql in ('23502','23514','22P02') then v_codigo:='DADOS_INVALIDOS';
  elsif p_codigo_sql in ('42501') or v_msg like '%row-level security%' or v_msg like '%permission denied%' then v_codigo:='AUTH_ACESSO_NEGADO';
  elsif p_codigo_sql in ('P0001') and (v_msg like '%não autenticado%' or v_msg like '%sessão%') then v_codigo:='AUTH_NAO_AUTENTICADO';
  elsif v_msg like '%100% de conformidade%' or v_msg like '%100,00%' then v_codigo:='PORTAO_CONFORMIDADE_100';
  elsif v_msg like '%100% tratada%' or v_msg like '%reapresentação não liberada%' then v_codigo:='PORTAO_REAPRESENTACAO_100';
  elsif v_msg like '%evidência%obrigatória%' then v_codigo:='EVIDENCIA_OBRIGATORIA';
  elsif v_msg like '%não encontrada%' or v_msg like '%não encontrado%' then v_codigo:='REGISTRO_NAO_ENCONTRADO';
  elsif v_msg like '%perfil sem permissão%' or v_msg like '%permissão%' then v_codigo:='AUTH_PERFIL_SEM_PERMISSAO';
  elsif v_msg like '%acesso negado%' then v_codigo:='AUTH_ACESSO_NEGADO';
  end if;
  return public.obter_mensagem_sistema(v_codigo);
end;$$;
revoke all on function public.normalizar_erro_backend(text,text) from public;
grant execute on function public.normalizar_erro_backend(text,text) to anon,authenticated;

-- Reforço de mensagens amigáveis nas notificações internas.
comment on table public.catalogo_mensagens_sistema is 'Catálogo oficial de mensagens de interface do ContaOS em português do Brasil. Não exibir mensagens técnicas cruas ao usuário final.';
comment on table public.catalogo_status_ui is 'Rótulos e descrições oficiais de status do ContaOS em português do Brasil para uso pelo frontend.';

commit;

-- ============================================================

-- MIGRATION 20261101212750_0022_cron_workers
begin;

create or replace function privado.invocar_contaos_worker(p_fila text,p_max_jobs integer default 3)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_request_id bigint;
begin
  if p_fila not in ('documents','ocr','ai','embeddings','finance_imports','reports','integrations','webhooks') then
    raise exception 'Fila de processamento inválida.';
  end if;
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='contaos_project_url') || '/functions/v1/contaos-worker',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'x-contaos-internal-token',(select decrypted_secret from vault.decrypted_secrets where name='contaos_internal_worker_token')
    ),
    body := jsonb_build_object('queue',p_fila,'max_jobs',least(greatest(p_max_jobs,1),10)),
    timeout_milliseconds := 10000
  ) into v_request_id;
  return v_request_id;
end;$$;
revoke all on function privado.invocar_contaos_worker(text,integer) from public,anon,authenticated;

do $$ begin
  perform cron.schedule(
    'contaos-workers-rapidos',
    '20 seconds',
    $cron$
      select privado.invocar_contaos_worker('documents',3);
      select privado.invocar_contaos_worker('embeddings',5);
      select privado.invocar_contaos_worker('ai',2);
      select privado.invocar_contaos_worker('webhooks',3);
    $cron$
  );
  perform cron.schedule(
    'contaos-workers-pesados',
    '* * * * *',
    $cron$
      select privado.invocar_contaos_worker('finance_imports',2);
      select privado.invocar_contaos_worker('reports',2);
      select privado.invocar_contaos_worker('integrations',5);
      select privado.invocar_contaos_worker('ocr',2);
    $cron$
  );
  perform cron.schedule(
    'contaos-limpeza-historico-cron',
    '15 3 * * 0',
    $cron$
      delete from cron.job_run_details where end_time < now() - interval '30 days';
    $cron$
  );
end $$;

commit;

-- ============================================================

-- MIGRATION 20261101212815_0023_localizacao_brasil_brasilia
begin;

-- Padrão oficial do ContaOS: português do Brasil + Horário de Brasília.
alter table public.organizacoes alter column timezone set default 'America/Sao_Paulo';
update public.organizacoes set timezone='America/Sao_Paulo' where timezone is null or timezone in ('America/Bahia','UTC','Etc/UTC');

create table if not exists public.configuracao_localizacao (
  id boolean primary key default true check(id=true),
  idioma text not null default 'pt-BR',
  timezone text not null default 'America/Sao_Paulo',
  formato_data text not null default 'DD/MM/YYYY',
  formato_hora text not null default 'HH24:MI:SS',
  formato_data_hora text not null default 'DD/MM/YYYY HH24:MI:SS',
  moeda text not null default 'BRL',
  separador_decimal text not null default ',',
  separador_milhar text not null default '.',
  atualizado_em timestamptz not null default now()
);
alter table public.configuracao_localizacao enable row level security;
drop policy if exists configuracao_localizacao_leitura on public.configuracao_localizacao;
create policy configuracao_localizacao_leitura on public.configuracao_localizacao for select to anon,authenticated using(true);
revoke all on public.configuracao_localizacao from anon,authenticated;
grant select on public.configuracao_localizacao to anon,authenticated;
insert into public.configuracao_localizacao(id,idioma,timezone,formato_data,formato_hora,formato_data_hora,moeda,separador_decimal,separador_milhar)
values(true,'pt-BR','America/Sao_Paulo','DD/MM/YYYY','HH24:MI:SS','DD/MM/YYYY HH24:MI:SS','BRL',',','.')
on conflict(id) do update set idioma=excluded.idioma,timezone=excluded.timezone,formato_data=excluded.formato_data,formato_hora=excluded.formato_hora,formato_data_hora=excluded.formato_data_hora,moeda=excluded.moeda,separador_decimal=excluded.separador_decimal,separador_milhar=excluded.separador_milhar,atualizado_em=now();

create or replace function public.formatar_data_br(p_data date)
returns text language sql immutable security invoker set search_path='' as $$
  select case when p_data is null then null else to_char(p_data,'DD/MM/YYYY') end
$$;

create or replace function public.formatar_data_hora_br(p_data_hora timestamptz)
returns text language sql stable security invoker set search_path='' as $$
  select case when p_data_hora is null then null else to_char(p_data_hora at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI:SS') end
$$;

create or replace function public.formatar_hora_br(p_data_hora timestamptz)
returns text language sql stable security invoker set search_path='' as $$
  select case when p_data_hora is null then null else to_char(p_data_hora at time zone 'America/Sao_Paulo','HH24:MI:SS') end
$$;

create or replace function public.agora_brasilia()
returns timestamptz language sql stable security invoker set search_path='' as $$
  select now()
$$;

revoke all on function public.formatar_data_br(date) from public;
revoke all on function public.formatar_data_hora_br(timestamptz) from public;
revoke all on function public.formatar_hora_br(timestamptz) from public;
revoke all on function public.agora_brasilia() from public;
grant execute on function public.formatar_data_br(date) to anon,authenticated;
grant execute on function public.formatar_data_hora_br(timestamptz) to anon,authenticated;
grant execute on function public.formatar_hora_br(timestamptz) to anon,authenticated;
grant execute on function public.agora_brasilia() to anon,authenticated;

-- Garante que a criação de organizações use Brasília por padrão.
create or replace function privado.criar_organizacao(
  p_razao_social text,
  p_nome_fantasia text default null,
  p_cnpj varchar default null,
  p_timezone text default 'America/Sao_Paulo'
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v_usuario uuid := auth.uid(); v_org uuid; v_timezone text := 'America/Sao_Paulo';
begin
  if v_usuario is null then raise exception 'Para continuar, faça login novamente.'; end if;
  insert into public.organizacoes(razao_social,nome_fantasia,cnpj,timezone)
  values(p_razao_social,p_nome_fantasia,p_cnpj,v_timezone) returning id into v_org;
  insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
  values(v_org,v_usuario,'administrador',true);
  insert into public.recursos_organizacao(id_organizacao,recurso,habilitado)
  values(v_org,'contaos_1',true);
  perform privado.registrar_evento_auditoria(v_org,'OrganizacaoCriada','organizacoes',v_org,null,jsonb_build_object('razao_social',p_razao_social,'timezone',v_timezone));
  return v_org;
end;
$$;

create or replace function public.criar_organizacao(
  p_razao_social text,
  p_nome_fantasia text default null,
  p_cnpj varchar default null,
  p_timezone text default 'America/Sao_Paulo'
)
returns uuid language sql security invoker set search_path='' as $$
  select privado.criar_organizacao($1,$2,$3,'America/Sao_Paulo')
$$;
revoke all on function public.criar_organizacao(text,text,varchar,text) from public,anon;
grant execute on function public.criar_organizacao(text,text,varchar,text) to authenticated;

comment on table public.configuracao_localizacao is 'Padrão global de localização do ContaOS: pt-BR, moeda BRL e Horário de Brasília (America/Sao_Paulo).';

commit;

-- ============================================================

-- MIGRATION 20261101212848_0024_indices_fks_automaticos
begin;

do $$
declare
  r record;
  v_cols text;
  v_idx_name text;
begin
  for r in
    select c.oid as constraint_oid,
           n.nspname as schema_name,
           t.relname as table_name,
           c.conname,
           c.conkey
      from pg_constraint c
      join pg_class t on t.oid=c.conrelid
      join pg_namespace n on n.oid=t.relnamespace
     where c.contype='f'
       and n.nspname='public'
       and not exists (
         select 1
           from pg_index i
          where i.indrelid=c.conrelid
            and i.indisvalid
            and (i.indkey::smallint[])[0:cardinality(c.conkey)-1] = c.conkey
       )
  loop
    select string_agg(quote_ident(a.attname),', ' order by k.ord)
      into v_cols
      from unnest(r.conkey) with ordinality as k(attnum,ord)
      join pg_attribute a on a.attrelid=(quote_ident(r.schema_name)||'.'||quote_ident(r.table_name))::regclass and a.attnum=k.attnum;

    v_idx_name := left('fk_'||r.table_name||'_'||substr(md5(r.conname),1,10)||'_idx',63);
    execute format('create index if not exists %I on %I.%I (%s)',v_idx_name,r.schema_name,r.table_name,v_cols);
  end loop;
end $$;

commit;

-- ============================================================

-- MIGRATION 20261101213428_0025_fechamento_rpc_rate_limit_concorrencia
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

-- ============================================================

-- MIGRATION 20261101213741_0026_storage_upload_documentos
begin;

create table public.configuracao_upload(
  id boolean primary key default true check(id=true),
  limiar_upload_resumivel_bytes bigint not null default 104857600,
  tamanho_maximo_bytes bigint,
  extensoes_permitidas text[] not null default array['pdf','xlsx','csv','docx','png','jpg','jpeg','webp','txt','json','xml']::text[],
  mimes_permitidos text[] not null default array[
    'application/pdf','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document','image/png','image/jpeg','image/webp',
    'text/plain','application/json','application/xml','text/xml'
  ]::text[],
  atualizado_em timestamptz not null default now()
);
alter table public.configuracao_upload enable row level security;
create policy configuracao_upload_leitura on public.configuracao_upload for select to anon,authenticated using(true);
revoke all on public.configuracao_upload from anon,authenticated;
grant select on public.configuracao_upload to anon,authenticated;
insert into public.configuracao_upload(id) values(true) on conflict(id) do nothing;

create or replace function privado.confirmar_upload_arquivo(
  p_id_organizacao uuid,
  p_id_contrato uuid,
  p_path text,
  p_nome_original text,
  p_mime text,
  p_tamanho bigint,
  p_sha256 text,
  p_origem text default 'upload_usuario'
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_cfg public.configuracao_upload%rowtype; v_ext text;
begin
  if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
  if not privado.usuario_tem_acesso_organizacao(p_id_organizacao) then raise exception 'Seu usuário não possui acesso à organização informada.'; end if;
  if p_id_contrato is not null and not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Seu usuário não possui acesso ao contrato informado.'; end if;
  if split_part(p_path,'/',1) <> p_id_organizacao::text then raise exception 'O caminho do arquivo não corresponde à sua organização.'; end if;
  select * into v_cfg from public.configuracao_upload where id=true;
  v_ext:=lower(regexp_replace(p_nome_original,'^.*\.','','g'));
  if not (v_ext=any(v_cfg.extensoes_permitidas)) then raise exception 'Este formato de arquivo não é aceito pelo ContaOS.'; end if;
  if p_mime is not null and not (lower(p_mime)=any(v_cfg.mimes_permitidos)) then raise exception 'O tipo do arquivo enviado não é aceito pelo ContaOS.'; end if;
  if p_tamanho<0 then raise exception 'O tamanho do arquivo informado é inválido.'; end if;
  if v_cfg.tamanho_maximo_bytes is not null and p_tamanho>v_cfg.tamanho_maximo_bytes then raise exception 'O arquivo ultrapassa o limite configurado para este ambiente.'; end if;
  if p_sha256 !~ '^[0-9a-fA-F]{64}$' then raise exception 'Não foi possível confirmar a integridade do arquivo. Tente enviar novamente.'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='contaos-documentos' and o.name=p_path) then raise exception 'O upload ainda não foi concluído no armazenamento.'; end if;
  insert into public.arquivos(id_organizacao,id_contrato,bucket,path,nome_original,mime,tamanho,sha256,status_seguranca,origem,criado_por)
  values(p_id_organizacao,p_id_contrato,'contaos-documentos',p_path,p_nome_original,p_mime,p_tamanho,lower(p_sha256),'pendente',coalesce(nullif(trim(p_origem),''),'upload_usuario'),auth.uid())
  returning id into v_id;
  perform privado.registrar_evento_auditoria(p_id_organizacao,'UploadArquivoConfirmado','arquivos',v_id,null,jsonb_build_object('id_contrato',p_id_contrato,'nome_original',p_nome_original,'tamanho',p_tamanho,'sha256',lower(p_sha256)));
  return v_id;
end;$$;
revoke all on function privado.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text) from public,anon;
grant execute on function privado.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text) to authenticated;

create or replace function public.confirmar_upload_arquivo(p_id_organizacao uuid,p_id_contrato uuid,p_path text,p_nome_original text,p_mime text,p_tamanho bigint,p_sha256 text,p_origem text default 'upload_usuario')
returns uuid language sql security invoker set search_path='' as $$select privado.confirmar_upload_arquivo($1,$2,$3,$4,$5,$6,$7,$8)$$;
revoke all on function public.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text) from public,anon;
grant execute on function public.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text) to authenticated;

create or replace function privado.criar_documento_competencia(
  p_id_competencia uuid,p_tipo text,p_titulo text,p_categoria text,p_id_requisito uuid,p_id_arquivo uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_comp public.competencias%rowtype; v_arq public.arquivos%rowtype; v_doc uuid; v_ver uuid;
begin
  select * into v_comp from public.competencias where id=p_id_competencia;
  select * into v_arq from public.arquivos where id=p_id_arquivo;
  if v_comp.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if v_arq.id is null or v_arq.id_organizacao<>v_comp.id_organizacao or (v_arq.id_contrato is not null and v_arq.id_contrato<>v_comp.id_contrato) then raise exception 'O arquivo informado não pertence a esta competência.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato) or not privado.usuario_possui_perfil(v_comp.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite incluir documentos nesta competência.'; end if;
  if p_id_requisito is not null and not exists(select 1 from public.requisitos_competencia r where r.id=p_id_requisito and r.id_competencia=v_comp.id) then raise exception 'O requisito informado não pertence a esta competência.'; end if;
  insert into public.documentos_competencia(id_organizacao,id_contrato,id_competencia,tipo,titulo,categoria,id_requisito_competencia,situacao,versao_atual)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_comp.id,p_tipo,p_titulo,p_categoria,p_id_requisito,'ativo',1) returning id into v_doc;
  insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,enviado_por)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_doc,1,v_arq.id,v_arq.sha256,auth.uid()) returning id into v_ver;
  perform privado.enfileirar_job('documents',v_comp.id_organizacao,v_comp.id_contrato,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_comp.id_organizacao,v_comp.id_contrato,v_ver,'documents','pendente');
  perform privado.registrar_evento_auditoria(v_comp.id_organizacao,'DocumentoCompetenciaCriado','documentos_competencia',v_doc,null,jsonb_build_object('id_versao_documento',v_ver,'id_arquivo',v_arq.id));
  return v_doc;
end;$$;
create or replace function public.criar_documento_competencia(p_id_competencia uuid,p_tipo text,p_titulo text,p_categoria text,p_id_requisito uuid,p_id_arquivo uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.criar_documento_competencia($1,$2,$3,$4,$5,$6)$$;
revoke all on function public.criar_documento_competencia(uuid,text,text,text,uuid,uuid) from public,anon;
grant execute on function public.criar_documento_competencia(uuid,text,text,text,uuid,uuid) to authenticated;

create or replace function privado.adicionar_versao_documento_competencia(p_id_documento uuid,p_id_arquivo uuid,p_motivo text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_doc public.documentos_competencia%rowtype; v_arq public.arquivos%rowtype; v_num integer; v_ver uuid;
begin
 select * into v_doc from public.documentos_competencia where id=p_id_documento for update;
 select * into v_arq from public.arquivos where id=p_id_arquivo;
 if v_doc.id is null then raise exception 'Não encontramos o documento informado.'; end if;
 if v_arq.id is null or v_arq.id_organizacao<>v_doc.id_organizacao or (v_arq.id_contrato is not null and v_arq.id_contrato<>v_doc.id_contrato) then raise exception 'O arquivo informado não pertence a este contrato.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_doc.id_contrato) or not privado.usuario_possui_perfil(v_doc.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite criar uma nova versão deste documento.'; end if;
 select coalesce(max(numero_versao),0)+1 into v_num from public.versoes_documento where id_documento_competencia=v_doc.id;
 insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,motivo_substituicao,enviado_por)
 values(v_doc.id_organizacao,v_doc.id_contrato,v_doc.id,v_num,v_arq.id,v_arq.sha256,p_motivo,auth.uid()) returning id into v_ver;
 update public.documentos_competencia set versao_atual=v_num,versao_registro=versao_registro where id=v_doc.id;
 perform privado.enfileirar_job('documents',v_doc.id_organizacao,v_doc.id_contrato,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
 insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_doc.id_organizacao,v_doc.id_contrato,v_ver,'documents','pendente');
 perform privado.registrar_evento_auditoria(v_doc.id_organizacao,'VersaoDocumentoCompetenciaCriada','versoes_documento',v_ver,null,jsonb_build_object('id_documento_competencia',v_doc.id,'numero_versao',v_num,'motivo',p_motivo));
 return v_ver;
end;$$;
create or replace function public.adicionar_versao_documento_competencia(p_id_documento uuid,p_id_arquivo uuid,p_motivo text)
returns uuid language sql security invoker set search_path='' as $$select privado.adicionar_versao_documento_competencia($1,$2,$3)$$;
revoke all on function public.adicionar_versao_documento_competencia(uuid,uuid,text) from public,anon;
grant execute on function public.adicionar_versao_documento_competencia(uuid,uuid,text) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101214337_0027_controles_continuos_impacto_normativo
begin;

alter table public.contratos add column if not exists criticidade text not null default 'media';
do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.contratos'::regclass and conname='contratos_criticidade_check') then
    alter table public.contratos add constraint contratos_criticidade_check check(criticidade in ('baixa','media','alta','critica'));
  end if;
end $$;

alter table public.controles_conformidade add column if not exists bloqueia_competencia boolean not null default false;
alter table public.controles_conformidade add column if not exists segregacao_funcoes boolean not null default false;
alter table public.controles_conformidade add column if not exists responsavel_padrao uuid references auth.users(id) on delete set null;
alter table public.versoes_controle add column if not exists criterios jsonb not null default '{}'::jsonb;
alter table public.versoes_controle add column if not exists eventos_gatilho text[] not null default array['cron_diario']::text[];

create table public.aplicabilidades_controle (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_controle uuid not null references public.controles_conformidade(id) on delete restrict,
  id_contrato uuid references public.contratos(id) on delete restrict,
  ativo boolean not null default true,
  responsavel uuid references auth.users(id) on delete set null,
  bloqueia_competencia boolean,
  configuracao jsonb not null default '{}'::jsonb,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint aplicabilidades_controle_uk unique(id_controle,id_contrato)
);
create index aplicabilidades_controle_org_idx on public.aplicabilidades_controle(id_organizacao,id_contrato,ativo);
alter table public.aplicabilidades_controle enable row level security;
create policy aplicabilidades_controle_select on public.aplicabilidades_controle for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy aplicabilidades_controle_insert on public.aplicabilidades_controle for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy aplicabilidades_controle_update on public.aplicabilidades_controle for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create trigger aplicabilidades_controle_touch before update on public.aplicabilidades_controle for each row execute function privado.tocar_atualizado_em();

alter table public.execucoes_controle add column if not exists id_contrato uuid references public.contratos(id) on delete restrict;
alter table public.execucoes_controle add column if not exists id_competencia uuid references public.competencias(id) on delete restrict;
alter table public.execucoes_controle add column if not exists evento text;
alter table public.execucoes_controle add column if not exists evento_id uuid;
alter table public.execucoes_controle add column if not exists chave_idempotencia text;
create unique index if not exists execucoes_controle_idempotencia_uidx on public.execucoes_controle(id_organizacao,chave_idempotencia) where chave_idempotencia is not null;
create index if not exists execucoes_controle_contrato_idx on public.execucoes_controle(id_organizacao,id_contrato,executado_em desc);
create index if not exists execucoes_controle_competencia_idx on public.execucoes_controle(id_competencia,resultado,executado_em desc);

alter table public.nao_conformidades add column if not exists id_contrato uuid references public.contratos(id) on delete restrict;
alter table public.nao_conformidades add column if not exists id_competencia uuid references public.competencias(id) on delete restrict;
alter table public.nao_conformidades add column if not exists criado_por uuid references auth.users(id) on delete set null;
alter table public.nao_conformidades add column if not exists origem_evento text;
alter table public.nao_conformidades add column if not exists origem_evento_id uuid;
create unique index if not exists nao_conformidades_origem_uidx on public.nao_conformidades(id_organizacao,id_controle,origem_evento,origem_evento_id) where origem_evento_id is not null and status not in ('encerrada');
create index if not exists nao_conformidades_competencia_idx on public.nao_conformidades(id_competencia,status,severidade);

alter table public.planos_remediacao add column if not exists criado_por uuid references auth.users(id) on delete set null;
alter table public.planos_remediacao add column if not exists concluido_por uuid references auth.users(id) on delete set null;
alter table public.planos_remediacao add column if not exists concluido_em timestamptz;
alter table public.planos_remediacao add column if not exists validado_por uuid references auth.users(id) on delete set null;
alter table public.planos_remediacao add column if not exists validado_em timestamptz;
alter table public.planos_remediacao drop constraint if exists planos_remediacao_status_check;
alter table public.planos_remediacao add constraint planos_remediacao_status_check check(status in ('aberto','em_execucao','concluido','validado','cancelado'));

alter table public.avaliacoes_impacto add column if not exists status text not null default 'pendente_aprovacao';
do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.avaliacoes_impacto'::regclass and conname='avaliacoes_impacto_status_check') then
    alter table public.avaliacoes_impacto add constraint avaliacoes_impacto_status_check check(status in ('pendente_aprovacao','aprovada','rejeitada','substituida'));
  end if;
end $$;
alter table public.avaliacoes_impacto add column if not exists metadados jsonb not null default '{}'::jsonb;
create unique index if not exists avaliacoes_impacto_alteracao_pendente_uidx on public.avaliacoes_impacto(id_alteracao) where status='pendente_aprovacao';

create or replace function privado.enfileirar_controles_transacao()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform privado.enfileirar_job(
    'integrations',new.id_organizacao,new.id_contrato,'avaliar_controles',new.id,
    jsonb_build_object('entidade_tipo','avaliar_controles','id_transacao',new.id,'id_contrato',new.id_contrato),
    'compliance:transacao:'||new.id::text
  );
  return new;
end;$$;
revoke all on function privado.enfileirar_controles_transacao() from public,anon,authenticated;
drop trigger if exists contaos_controles_transacao on public.transacoes_financeiras;
create trigger contaos_controles_transacao after insert on public.transacoes_financeiras for each row execute function privado.enfileirar_controles_transacao();

create or replace function privado.agendar_controles_continuos()
returns integer language plpgsql security definer set search_path='' as $$
declare r record; v_total int:=0;
begin
  for r in
    select ac.id_organizacao,ac.id_contrato,ac.id_controle
    from public.aplicabilidades_controle ac
    join public.controles_conformidade c on c.id=ac.id_controle and c.situacao='ativo'
    join public.versoes_controle vc on vc.id_controle=c.id and vc.status='publicada'
    where ac.ativo=true and 'cron_diario'=any(vc.eventos_gatilho)
      and (vc.vigencia_inicio is null or vc.vigencia_inicio<=current_date)
      and (vc.vigencia_fim is null or vc.vigencia_fim>=current_date)
  loop
    perform privado.enfileirar_job(
      'integrations',r.id_organizacao,r.id_contrato,'avaliar_controles_periodicos',r.id_controle,
      jsonb_build_object('entidade_tipo','avaliar_controles_periodicos','id_controle',r.id_controle,'id_contrato',r.id_contrato,'data_referencia',current_date),
      'compliance:diario:'||r.id_controle::text||':'||coalesce(r.id_contrato::text,'organizacao')||':'||current_date::text
    );
    v_total:=v_total+1;
  end loop;
  return v_total;
end;$$;
revoke all on function privado.agendar_controles_continuos() from public,anon,authenticated;

select cron.schedule('contaos-controles-continuos','10 2 * * *',$cron$select privado.agendar_controles_continuos();$cron$);

create or replace function privado.concluir_plano_remediacao(p_id_plano uuid,p_evidencias jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare v public.planos_remediacao%rowtype; v_nc public.nao_conformidades%rowtype;
begin
  select * into v from public.planos_remediacao where id=p_id_plano for update;
  if v.id is null then raise exception 'Não encontramos o plano de remediação informado.'; end if;
  select * into v_nc from public.nao_conformidades where id=v.id_nao_conformidade;
  if auth.uid() is null or not privado.usuario_tem_acesso_organizacao(v.id_organizacao) then raise exception 'Para continuar, faça login novamente.'; end if;
  if v.responsavel is not null and v.responsavel<>auth.uid() and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','juridico_conformidade']::text[]) then raise exception 'Somente o responsável pela remediação ou um perfil autorizado pode concluir este plano.'; end if;
  if jsonb_typeof(coalesce(p_evidencias,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_evidencias,'[]'::jsonb))=0 then raise exception 'Inclua ao menos uma evidência antes de concluir a remediação.'; end if;
  update public.planos_remediacao set status='concluido',evidencias=p_evidencias,concluido_por=auth.uid(),concluido_em=now() where id=v.id;
  update public.nao_conformidades set status='em_remediacao' where id=v_nc.id and status in ('aberta','em_analise');
  perform privado.registrar_evento_auditoria(v.id_organizacao,'PlanoRemediacaoConcluido','planos_remediacao',v.id,null,jsonb_build_object('id_nao_conformidade',v.id_nao_conformidade,'quantidade_evidencias',jsonb_array_length(p_evidencias)));
end;$$;
create or replace function public.concluir_plano_remediacao(p_id_plano uuid,p_evidencias jsonb)
returns void language sql security invoker set search_path='' as $$select privado.concluir_plano_remediacao($1,$2)$$;
revoke all on function public.concluir_plano_remediacao(uuid,jsonb) from public,anon;
grant execute on function public.concluir_plano_remediacao(uuid,jsonb) to authenticated;

create or replace function privado.validar_remediacao(p_id_plano uuid,p_aprovar boolean,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.planos_remediacao%rowtype; v_nc public.nao_conformidades%rowtype; v_controle public.controles_conformidade%rowtype;
begin
  select * into v from public.planos_remediacao where id=p_id_plano for update;
  if v.id is null then raise exception 'Não encontramos o plano de remediação informado.'; end if;
  select * into v_nc from public.nao_conformidades where id=v.id_nao_conformidade;
  if v_nc.id_controle is not null then select * into v_controle from public.controles_conformidade where id=v_nc.id_controle; end if;
  if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite validar esta remediação.'; end if;
  if v.status<>'concluido' then raise exception 'A remediação precisa estar concluída antes da validação.'; end if;
  if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento da validação.'; end if;
  if coalesce(v_controle.segregacao_funcoes,false) and auth.uid()=any(array_remove(array[v.criado_por,v.responsavel,v.concluido_por,v_nc.criado_por],null)) then
    raise exception 'Este controle exige segregação de funções. A validação deve ser realizada por uma pessoa diferente de quem criou ou executou a remediação.';
  end if;
  if p_aprovar then
    update public.planos_remediacao set status='validado',validado_por=auth.uid(),validado_em=now() where id=v.id;
    if not exists(select 1 from public.planos_remediacao p where p.id_nao_conformidade=v.id_nao_conformidade and p.id<>v.id and p.status not in ('validado','cancelado')) then
      update public.nao_conformidades set status='resolvida' where id=v.id_nao_conformidade;
    end if;
  else
    update public.planos_remediacao set status='em_execucao',validado_por=null,validado_em=null where id=v.id;
  end if;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'RemediacaoValidada','planos_remediacao',v.id,null,jsonb_build_object('aprovada',p_aprovar,'fundamento',p_fundamento));
end;$$;
create or replace function public.validar_remediacao(p_id_plano uuid,p_aprovar boolean,p_fundamento text)
returns void language sql security invoker set search_path='' as $$select privado.validar_remediacao($1,$2,$3)$$;
revoke all on function public.validar_remediacao(uuid,boolean,text) from public,anon;
grant execute on function public.validar_remediacao(uuid,boolean,text) to authenticated;

create or replace function privado.encerrar_nao_conformidade(p_id_nao_conformidade uuid,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.nao_conformidades%rowtype;
begin
 select * into v from public.nao_conformidades where id=p_id_nao_conformidade for update;
 if v.id is null then raise exception 'Não encontramos a não conformidade informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite encerrar esta não conformidade.'; end if;
 if exists(select 1 from public.planos_remediacao where id_nao_conformidade=v.id and status not in ('validado','cancelado')) then raise exception 'Ainda existem remediações sem validação. Valide todas as ações necessárias antes de encerrar.'; end if;
 if not exists(select 1 from public.planos_remediacao where id_nao_conformidade=v.id and status='validado' and jsonb_typeof(evidencias)='array' and jsonb_array_length(evidencias)>0) then raise exception 'Para encerrar, é necessária ao menos uma remediação validada com evidência.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento do encerramento.'; end if;
 update public.nao_conformidades set status='encerrada' where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'NaoConformidadeEncerrada','nao_conformidades',v.id,jsonb_build_object('status',v.status),jsonb_build_object('status','encerrada','fundamento',p_fundamento));
end;$$;

create or replace function privado.avaliar_portao_conformidade(p_id_competencia uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_org uuid; v_contrato uuid; v_total int:=0; v_ok int:=0; v_pend int:=0; v_nok int:=0; v_inc int:=0; v_analise int:=0; v_nc int:=0; v_percent numeric(5,2):=0; v_liberado boolean:=false;
begin
  select id_organizacao,id_contrato into v_org,v_contrato from public.competencias where id=p_id_competencia;
  if v_org is null then raise exception 'Não encontramos a competência informada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
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
  select count(*)::int into v_nc
  from public.nao_conformidades nc
  join public.controles_conformidade c on c.id=nc.id_controle
  left join public.aplicabilidades_controle ac on ac.id_controle=c.id and ac.id_contrato=v_contrato and ac.ativo=true
  where nc.id_organizacao=v_org and nc.id_contrato=v_contrato
    and (nc.id_competencia is null or nc.id_competencia=p_id_competencia)
    and nc.status not in ('resolvida','encerrada','aceita')
    and coalesce(ac.bloqueia_competencia,c.bloqueia_competencia,false)=true;
  v_percent:=case when v_total=0 then 0 else round((v_ok::numeric/v_total::numeric)*100,2) end;
  v_liberado:=(v_total>0 and v_ok=v_total and v_pend=0 and v_nok=0 and v_inc=0 and v_analise=0 and v_nc=0);
  return jsonb_build_object('total',v_total,'conformes_ou_na_validos',v_ok,'pendentes',v_pend,'nao_conformes',v_nok,'inconclusivos',v_inc,'em_analise',v_analise,'nao_conformidades_bloqueantes',v_nc,'percentual',v_percent,'liberado',v_liberado);
end;$$;

create or replace function privado.solicitar_avaliacao_impacto_normativo(p_id_alteracao uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.alteracoes_normativas%rowtype; v_job uuid;
begin
 select * into v from public.alteracoes_normativas where id=p_id_alteracao for update;
 if v.id is null then raise exception 'Não encontramos a alteração normativa informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]) then raise exception 'Seu perfil atual não permite solicitar esta análise de impacto.'; end if;
 update public.alteracoes_normativas set status='em_avaliacao' where id=v.id;
 v_job:=privado.enfileirar_job('integrations',v.id_organizacao,null,'avaliacao_impacto_normativo',v.id,jsonb_build_object('entidade_tipo','avaliacao_impacto_normativo','id_alteracao',v.id),'normativo:'||v.id::text);
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AvaliacaoImpactoNormativoSolicitada','alteracoes_normativas',v.id,null,jsonb_build_object('id_job',v_job));
 return v_job;
end;$$;
create or replace function public.solicitar_avaliacao_impacto_normativo(p_id_alteracao uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_avaliacao_impacto_normativo($1)$$;
revoke all on function public.solicitar_avaliacao_impacto_normativo(uuid) from public,anon;
grant execute on function public.solicitar_avaliacao_impacto_normativo(uuid) to authenticated;

create or replace function privado.aprovar_avaliacao_impacto(p_id_avaliacao uuid,p_aprovar boolean,p_decisao text,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.avaliacoes_impacto%rowtype;
begin
 select * into v from public.avaliacoes_impacto where id=p_id_avaliacao for update;
 if v.id is null then raise exception 'Não encontramos a avaliação de impacto informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite aprovar esta avaliação de impacto.'; end if;
 if v.criado_por=auth.uid() then raise exception 'Por segregação de funções, a avaliação deve ser aprovada por uma pessoa diferente de quem a registrou.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento da decisão.'; end if;
 update public.avaliacoes_impacto set status=case when p_aprovar then 'aprovada' else 'rejeitada' end,decisao=p_decisao,aprovado_por=auth.uid(),aprovado_em=now(),metadados=metadados||jsonb_build_object('fundamento_aprovacao',p_fundamento) where id=v.id;
 update public.alteracoes_normativas set status=case when p_aprovar then 'avaliada' else 'detectada' end where id=v.id_alteracao;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AvaliacaoImpactoNormativoRevisada','avaliacoes_impacto',v.id,null,jsonb_build_object('aprovada',p_aprovar,'decisao',p_decisao,'fundamento',p_fundamento));
end;$$;
create or replace function public.aprovar_avaliacao_impacto(p_id_avaliacao uuid,p_aprovar boolean,p_decisao text,p_fundamento text)
returns void language sql security invoker set search_path='' as $$select privado.aprovar_avaliacao_impacto($1,$2,$3,$4)$$;
revoke all on function public.aprovar_avaliacao_impacto(uuid,boolean,text,text) from public,anon;
grant execute on function public.aprovar_avaliacao_impacto(uuid,boolean,text,text) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101214452_0028_acesso_temporario_exportacao_evidencias
begin;

create table public.eventos_acesso_pacote_evidencias (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict,
  id_acesso uuid references public.acessos_pacote_evidencias(id) on delete set null,
  resultado text not null check(resultado in ('permitido','expirado','revogado','limite_atingido','token_invalido','pacote_indisponivel')),
  ip_hash text,
  user_agent_hash text,
  metadados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index eventos_acesso_pacote_idx on public.eventos_acesso_pacote_evidencias(id_pacote,criado_em desc);
alter table public.eventos_acesso_pacote_evidencias enable row level security;
create policy eventos_acesso_pacote_select on public.eventos_acesso_pacote_evidencias for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]));

create trigger eventos_acesso_pacote_immutable before update or delete on public.eventos_acesso_pacote_evidencias for each row execute function privado.bloquear_mutacao_historico();

create or replace function public.validar_acesso_temporario_pacote(p_token text,p_ip_hash text default null,p_user_agent_hash text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_hash text; v_acesso public.acessos_pacote_evidencias%rowtype; v_pacote public.pacotes_evidencias%rowtype; v_resultado text; v_permitido boolean:=false;
begin
  v_hash:=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex');
  select * into v_acesso from public.acessos_pacote_evidencias where token_hash=v_hash for update;
  if v_acesso.id is null then
    return jsonb_build_object('permitido',false,'codigo','TOKEN_INVALIDO','titulo','Acesso não reconhecido','mensagem','Este link de acesso não é válido ou não está mais disponível.');
  end if;
  select * into v_pacote from public.pacotes_evidencias where id=v_acesso.id_pacote;
  if v_acesso.revogado_em is not null then v_resultado:='revogado';
  elsif v_acesso.expira_em<=now() then v_resultado:='expirado';
  elsif v_acesso.max_acessos is not null and v_acesso.quantidade_acessos>=v_acesso.max_acessos then v_resultado:='limite_atingido';
  elsif v_pacote.id is null or v_pacote.status<>'disponivel' or (v_pacote.expira_em is not null and v_pacote.expira_em<=now()) then v_resultado:='pacote_indisponivel';
  else v_resultado:='permitido'; v_permitido:=true; end if;

  insert into public.eventos_acesso_pacote_evidencias(id_organizacao,id_pacote,id_acesso,resultado,ip_hash,user_agent_hash,metadados)
  values(v_acesso.id_organizacao,v_acesso.id_pacote,v_acesso.id,v_resultado,p_ip_hash,p_user_agent_hash,jsonb_build_object('acesso_numero',v_acesso.quantidade_acessos+case when v_permitido then 1 else 0 end));

  if v_permitido then
    update public.acessos_pacote_evidencias set quantidade_acessos=quantidade_acessos+1 where id=v_acesso.id;
    perform privado.registrar_evento_auditoria(v_acesso.id_organizacao,'PacoteEvidenciasAcessado','pacotes_evidencias',v_acesso.id_pacote,null,jsonb_build_object('id_acesso',v_acesso.id,'quantidade_acessos',v_acesso.quantidade_acessos+1));
    return jsonb_build_object('permitido',true,'id_pacote',v_pacote.id,'id_organizacao',v_pacote.id_organizacao,'id_contrato',v_pacote.id_contrato,'id_arquivo_exportacao',v_pacote.id_arquivo_exportacao,'expira_em',v_acesso.expira_em,'acessos_restantes',case when v_acesso.max_acessos is null then null else greatest(v_acesso.max_acessos-(v_acesso.quantidade_acessos+1),0) end);
  end if;

  return jsonb_build_object('permitido',false,'codigo',upper(v_resultado),'titulo',case v_resultado when 'expirado' then 'Acesso expirado' when 'revogado' then 'Acesso revogado' when 'limite_atingido' then 'Limite de acessos atingido' else 'Pacote indisponível' end,'mensagem',case v_resultado when 'expirado' then 'O período autorizado para consultar este pacote terminou.' when 'revogado' then 'Este acesso foi revogado pelo responsável.' when 'limite_atingido' then 'Este link atingiu o número máximo de acessos permitido.' else 'O pacote de evidências não está disponível neste momento.' end);
end;$$;
revoke all on function public.validar_acesso_temporario_pacote(text,text,text) from public,anon,authenticated;
grant execute on function public.validar_acesso_temporario_pacote(text,text,text) to service_role;

create or replace function privado.revogar_acesso_temporario_pacote(p_id_acesso uuid,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.acessos_pacote_evidencias%rowtype;
begin
  select * into v from public.acessos_pacote_evidencias where id=p_id_acesso for update;
  if v.id is null then raise exception 'Não encontramos o acesso temporário informado.'; end if;
  if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite revogar este acesso.'; end if;
  if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o motivo da revogação.'; end if;
  if v.revogado_em is null then update public.acessos_pacote_evidencias set revogado_em=now() where id=v.id; end if;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AcessoPacoteEvidenciasRevogado','acessos_pacote_evidencias',v.id,null,jsonb_build_object('id_pacote',v.id_pacote,'fundamento',p_fundamento));
end;$$;
create or replace function public.revogar_acesso_temporario_pacote(p_id_acesso uuid,p_fundamento text)
returns void language sql security invoker set search_path='' as $$select privado.revogar_acesso_temporario_pacote($1,$2)$$;
revoke all on function public.revogar_acesso_temporario_pacote(uuid,text) from public,anon;
grant execute on function public.revogar_acesso_temporario_pacote(uuid,text) to authenticated;

-- Atualiza a criação do acesso com validações e sem permitir expiração além do pacote.
create or replace function privado.criar_acesso_temporario_pacote(p_id_pacote uuid,p_expira_em timestamptz,p_descricao_destinatario text default null,p_max_acessos integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.pacotes_evidencias%rowtype; v_token text; v_hash text; v_id uuid;
begin
 select * into v from public.pacotes_evidencias where id=p_id_pacote;
 if v.id is null then raise exception 'Não encontramos o pacote de evidências informado.'; end if;
 if v.status<>'disponivel' then raise exception 'O pacote precisa estar disponível antes de criar um acesso temporário.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite compartilhar este pacote.'; end if;
 if p_expira_em<=now() then raise exception 'A data de expiração deve ser futura.'; end if;
 if v.expira_em is not null and p_expira_em>v.expira_em then raise exception 'O acesso não pode expirar depois do próprio pacote.'; end if;
 if p_max_acessos is not null and p_max_acessos<1 then raise exception 'O limite de acessos deve ser maior que zero.'; end if;
 v_token:='ev_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
 insert into public.acessos_pacote_evidencias(id_organizacao,id_pacote,token_hash,descricao_destinatario,expira_em,max_acessos,criado_por)
 values(v.id_organizacao,v.id,v_hash,p_descricao_destinatario,p_expira_em,p_max_acessos,auth.uid()) returning id into v_id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AcessoPacoteEvidenciasCriado','acessos_pacote_evidencias',v_id,null,jsonb_build_object('id_pacote',v.id,'expira_em',p_expira_em,'max_acessos',p_max_acessos));
 return jsonb_build_object('id',v_id,'token_uma_vez',v_token,'expira_em',p_expira_em,'max_acessos',p_max_acessos);
end;$$;

commit;

-- ============================================================

-- MIGRATION 20261101214617_0029_observabilidade_paginacao_resiliencia
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

-- ============================================================

-- MIGRATION 20261101214949_0030_fechamento_funcional_v1_v2
begin;

create table public.sugestoes_extracao_documento (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_versao_documento uuid not null references public.versoes_documento(id) on delete restrict,
  tipo text not null check(tipo in ('classificacao','clausula','obrigacao','prazo','documento_exigido','restricao','metadado','regra_candidata')),
  categoria_sugerida text,
  id_requisito_sugerido uuid references public.requisitos_competencia(id) on delete restrict,
  conteudo text not null,
  pagina integer,
  trecho_fonte text,
  confianca numeric(6,5) check(confianca is null or confianca between 0 and 1),
  status text not null default 'pendente' check(status in ('pendente','aprovada','rejeitada','substituida')),
  revisado_por uuid references auth.users(id) on delete set null,
  revisado_em timestamptz,
  metadados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index sugestoes_extracao_doc_idx on public.sugestoes_extracao_documento(id_versao_documento,status,tipo);
alter table public.sugestoes_extracao_documento enable row level security;
create policy sugestoes_extracao_select on public.sugestoes_extracao_documento for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));

alter table public.requisitos_competencia add column if not exists regra_validacao jsonb not null default '{}'::jsonb;
alter table public.requisitos_competencia add column if not exists condicao_aplicabilidade jsonb not null default '{}'::jsonb;

create or replace function privado.avaliar_condicao_requisito(p_id_contrato uuid,p_id_competencia uuid,p_condicao jsonb)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_contrato public.contratos%rowtype; v_comp public.competencias%rowtype; v_tipo text; v_val text; v_qtd int;
begin
  if p_condicao is null or p_condicao='{}'::jsonb then return true; end if;
  select * into v_contrato from public.contratos where id=p_id_contrato;
  select * into v_comp from public.competencias where id=p_id_competencia;
  v_tipo:=coalesce(p_condicao->>'tipo','sempre');
  if v_tipo='sempre' then return true;
  elsif v_tipo='tipo_contrato_em' then return coalesce(v_contrato.tipo_contrato,'')=any(array(select jsonb_array_elements_text(coalesce(p_condicao->'valores','[]'::jsonb))));
  elsif v_tipo='valor_global_minimo' then return coalesce(v_contrato.valor_global,0)>=coalesce((p_condicao->>'valor')::numeric,0);
  elsif v_tipo='valor_global_maximo' then return coalesce(v_contrato.valor_global,0)<=coalesce((p_condicao->>'valor')::numeric,0);
  elsif v_tipo='existe_documento_tipo' then
    v_val:=p_condicao->>'valor';
    select count(*) into v_qtd from public.documentos_competencia d where d.id_competencia=p_id_competencia and d.tipo=v_val and d.situacao='ativo';
    return v_qtd>0;
  elsif v_tipo='existe_transacao_tipo' then
    v_val:=p_condicao->>'valor';
    select count(*) into v_qtd from public.transacoes_financeiras t where t.id_contrato=p_id_contrato and t.data between v_comp.periodo_inicio and v_comp.periodo_fim and t.tipo=v_val;
    return v_qtd>0;
  elsif v_tipo='existe_rescisao' then
    select count(*) into v_qtd from public.documentos_competencia d where d.id_competencia=p_id_competencia and (lower(d.tipo) like '%rescis%' or lower(d.titulo) like '%rescis%') and d.situacao='ativo';
    return v_qtd>0;
  elsif v_tipo='existe_imobilizado' then
    select count(*) into v_qtd from public.transacoes_financeiras t where t.id_contrato=p_id_contrato and t.data between v_comp.periodo_inicio and v_comp.periodo_fim and (lower(t.descricao) like '%imobiliz%' or lower(coalesce(t.dados_brutos->>'rubrica','')) like '%imobiliz%');
    return v_qtd>0;
  elsif v_tipo='existe_aplicacao_financeira' then
    select count(*) into v_qtd from public.transacoes_financeiras t where t.id_contrato=p_id_contrato and t.data between v_comp.periodo_inicio and v_comp.periodo_fim and (lower(t.descricao) like '%aplica%financeir%' or lower(t.descricao) like '%rendimento%');
    return v_qtd>0;
  end if;
  return true;
end;$$;
revoke all on function privado.avaliar_condicao_requisito(uuid,uuid,jsonb) from public,anon,authenticated;

create or replace function privado.preencher_snapshot_item_lista()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_regra jsonb; v_cond jsonb;
begin
  if new.origem_tipo='item_lista' and new.origem_id is not null then
    select regra_validacao into v_regra from public.itens_lista where id=new.origem_id;
    new.regra_validacao:=coalesce(v_regra,'{}'::jsonb);
    v_cond:=coalesce(v_regra->'condicao','{}'::jsonb);
    new.condicao_aplicabilidade:=v_cond;
    if v_cond<>'{}'::jsonb then new.aplicavel:=privado.avaliar_condicao_requisito(new.id_contrato,new.id_competencia,v_cond); end if;
  end if;
  return new;
end;$$;
revoke all on function privado.preencher_snapshot_item_lista() from public,anon,authenticated;
drop trigger if exists requisitos_snapshot_item_lista on public.requisitos_competencia;
create trigger requisitos_snapshot_item_lista before insert on public.requisitos_competencia for each row execute function privado.preencher_snapshot_item_lista();

alter table public.resultados_requisitos drop constraint if exists resultados_requisitos_resultado_check;
alter table public.resultados_requisitos add constraint resultados_requisitos_resultado_check check(resultado in ('nao_enviado','recebido','pendente','em_analise','conforme','nao_conforme','inconclusivo','requer_revisao','nao_aplicavel'));

alter table public.apontamentos_internos drop constraint if exists apontamentos_internos_severidade_check;
alter table public.apontamentos_internos add constraint apontamentos_internos_severidade_check check(severidade in ('informativo','baixa','media','alta','critica'));
alter table public.apontamentos_internos add column if not exists regra_violada text;
alter table public.apontamentos_internos add column if not exists acao_sugerida text;
alter table public.apontamentos_internos add column if not exists fonte jsonb not null default '{}'::jsonb;

create or replace function privado.validar_nova_versao_documento()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_situacao text;
begin
  if new.id_documento_competencia is not null and new.numero_versao>1 then
    select c.situacao into v_situacao from public.documentos_competencia d join public.competencias c on c.id=d.id_competencia where d.id=new.id_documento_competencia;
    if v_situacao in ('em_analise','pendente_correcao','em_reanalise','pode_apresentar_contratante','apresentado','aguardando_contratante','com_apontamentos','pode_reapresentar_contratante','reapresentado') and nullif(trim(coalesce(new.motivo_substituicao,'')),'') is null then
      raise exception 'Informe o motivo da substituição antes de criar uma nova versão deste documento.';
    end if;
  end if;
  return new;
end;$$;
revoke all on function privado.validar_nova_versao_documento() from public,anon,authenticated;
drop trigger if exists validar_nova_versao_documento on public.versoes_documento;
create trigger validar_nova_versao_documento before insert on public.versoes_documento for each row execute function privado.validar_nova_versao_documento();

alter table public.execucoes_analise add column if not exists snapshot_entrada jsonb not null default '{}'::jsonb;
alter table public.execucoes_analise add column if not exists requisitos_afetados uuid[] not null default '{}'::uuid[];

create or replace function privado.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa')
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_exec uuid; v_snapshot jsonb; v_hash text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if p_tipo not in ('completa','reanálise','parcial') then raise exception 'O tipo de análise informado não é válido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite solicitar esta análise.'; end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then raise exception 'A situação atual desta competência não permite iniciar uma nova análise.'; end if;
  select jsonb_build_object(
    'competencia',jsonb_build_object('id',v.id,'referencia',v.competencia_referencia,'periodo_inicio',v.periodo_inicio,'periodo_fim',v.periodo_fim),
    'requisitos',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'origem_tipo',r.origem_tipo,'origem_id',r.origem_id,'origem_versao',r.origem_versao,'hash',r.hash_snapshot,'regra_validacao',r.regra_validacao) order by r.ordem,r.id) from public.requisitos_competencia r where r.id_competencia=v.id),'[]'::jsonb),
    'documentos',coalesce((select jsonb_agg(jsonb_build_object('id_documento',d.id,'id_versao',vd.id,'numero_versao',vd.numero_versao,'hash',vd.hash) order by d.id) from public.documentos_competencia d join lateral (select x.* from public.versoes_documento x where x.id_documento_competencia=d.id order by x.numero_versao desc limit 1) vd on true where d.id_competencia=v.id and d.situacao='ativo'),'[]'::jsonb),
    'motor','contaos','versao_motor','2.0','idioma','pt-BR','timezone','America/Sao_Paulo'
  ) into v_snapshot;
  v_hash:=encode(extensions.digest(v_snapshot::text,'sha256'),'hex');
  insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,motor,versao_motor,prompt_versao,iniciada_por,iniciada_em,snapshot_entrada)
  values(v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente',v_hash,'contaos','2.0','analise-pt-BR-v2',auth.uid(),now(),v_snapshot) returning id into v_exec;
  update public.competencias set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end where id=v.id;
  perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'execucao_analise',v_exec,jsonb_build_object('entidade_tipo','execucao_analise','id_execucao',v_exec,'id_competencia',v.id),'analysis:'||v_exec::text);
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,jsonb_build_object('id_competencia',v.id,'tipo',p_tipo,'hash_entrada',v_hash));
  return v_exec;
end;$$;

create or replace function privado.solicitar_reanalise_requisitos(p_id_competencia uuid,p_requisitos uuid[])
returns uuid language plpgsql security definer set search_path='' as $$
declare v_exec uuid;
begin
  if p_requisitos is null or cardinality(p_requisitos)=0 then raise exception 'Selecione ao menos um requisito para reanálise.'; end if;
  if exists(select 1 from unnest(p_requisitos) x where not exists(select 1 from public.requisitos_competencia r where r.id=x and r.id_competencia=p_id_competencia)) then raise exception 'Um dos requisitos selecionados não pertence a esta competência.'; end if;
  v_exec:=privado.solicitar_analise_competencia(p_id_competencia,'parcial');
  update public.execucoes_analise set requisitos_afetados=p_requisitos,metadados=metadados||jsonb_build_object('reanálise_incremental',true) where id=v_exec;
  return v_exec;
end;$$;
create or replace function public.solicitar_reanalise_requisitos(p_id_competencia uuid,p_requisitos uuid[])
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_reanalise_requisitos($1,$2)$$;
revoke all on function public.solicitar_reanalise_requisitos(uuid,uuid[]) from public,anon;
grant execute on function public.solicitar_reanalise_requisitos(uuid,uuid[]) to authenticated;

create or replace function privado.solicitar_parecer_interno(p_id_competencia uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_job uuid;
begin
 select * into v from public.competencias where id=p_id_competencia;
 if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
 if coalesce((privado.avaliar_portao_conformidade(v.id)->>'liberado')::boolean,false) is not true then raise exception 'O parecer final somente pode ser gerado depois que os requisitos obrigatórios estiverem integralmente tratados.'; end if;
 v_job:=privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'gerar_parecer_interno',v.id,jsonb_build_object('entidade_tipo','gerar_parecer_interno','id_competencia',v.id),'parecer:'||v.id::text||':'||v.versao_registro::text);
 return v_job;
end;$$;
create or replace function public.solicitar_parecer_interno(p_id_competencia uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_parecer_interno($1)$$;
revoke all on function public.solicitar_parecer_interno(uuid) from public,anon;
grant execute on function public.solicitar_parecer_interno(uuid) to authenticated;

create or replace function privado.aprovar_parecer_interno(p_id_parecer uuid,p_aprovar boolean,p_fundamento text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v public.pareceres_internos%rowtype;
begin
 select * into v from public.pareceres_internos where id=p_id_parecer for update;
 if v.id is null then raise exception 'Não encontramos o parecer informado.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite aprovar este parecer.'; end if;
 if v.autor=auth.uid() then raise exception 'O parecer deve ser aprovado por uma pessoa diferente de quem o elaborou.'; end if;
 update public.pareceres_internos set status=case when p_aprovar then 'aprovado' else 'rejeitado' end,aprovado_por=auth.uid(),aprovado_em=now() where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ParecerInternoRevisado','pareceres_internos',v.id,null,jsonb_build_object('aprovado',p_aprovar,'fundamento',p_fundamento));
end;$$;
create or replace function public.aprovar_parecer_interno(p_id_parecer uuid,p_aprovar boolean,p_fundamento text default null)
returns void language sql security invoker set search_path='' as $$select privado.aprovar_parecer_interno($1,$2,$3)$$;
revoke all on function public.aprovar_parecer_interno(uuid,boolean,text) from public,anon;
grant execute on function public.aprovar_parecer_interno(uuid,boolean,text) to authenticated;

create or replace function privado.aprovar_apresentacao(p_id_competencia uuid,p_fundamento text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_portao jsonb; v_exec uuid; v_parecer uuid; v_aprov uuid; v_hash text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]) then raise exception 'Seu perfil atual não permite liberar esta apresentação.'; end if;
  if v.situacao not in ('em_analise','em_reanalise','pendente_correcao','rascunho') then raise exception 'A situação atual desta competência ainda não permite a liberação.'; end if;
  v_portao:=privado.avaliar_portao_conformidade(v.id);
  if coalesce((v_portao->>'liberado')::boolean,false) is not true then raise exception 'A competência ainda não atingiu 100,00%% de conformidade dos requisitos obrigatórios e aplicáveis.'; end if;
  select id into v_parecer from public.pareceres_internos where id_competencia=v.id and status='aprovado' order by versao desc limit 1;
  if v_parecer is null then raise exception 'Antes de liberar a apresentação, gere o parecer interno e obtenha a aprovação do responsável autorizado.'; end if;
  select id into v_exec from public.execucoes_analise where id_competencia=v.id and status='concluida' order by concluida_em desc nulls last,criado_em desc limit 1;
  v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,coalesce(v_exec::text,''),v_parecer::text,v_portao::text,coalesce(p_fundamento,'')),'sha256'),'hex');
  insert into public.aprovacoes(id_organizacao,id_contrato,id_competencia,tipo,status,aprovado_por,fundamento,hash_contexto,percentual_conformidade,id_execucao_analise)
  values(v.id_organizacao,v.id_contrato,v.id,'apresentacao','aprovada',auth.uid(),p_fundamento,v_hash,100.00,v_exec) returning id into v_aprov;
  update public.competencias set situacao='pode_apresentar_contratante',percentual_conformidade=100.00,liberada_para_apresentacao_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'CompetenciaLiberadaParaApresentacao','competencias',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','pode_apresentar_contratante','id_aprovacao',v_aprov,'id_parecer',v_parecer));
  return jsonb_build_object('id_aprovacao',v_aprov,'situacao','pode_apresentar_contratante','percentual_conformidade',100.00,'id_parecer',v_parecer);
end;$$;

alter table public.apontamentos_contratante add column if not exists valor_questionado numeric(18,2);
alter table public.apontamentos_contratante add column if not exists glosa_potencial numeric(18,2);
alter table public.apontamentos_contratante add column if not exists valor_aceito numeric(18,2);
alter table public.apontamentos_contratante add column if not exists impacto_financeiro_estimado numeric(18,2);
alter table public.apontamentos_contratante add column if not exists classificacao_sugerida text;
alter table public.apontamentos_contratante add column if not exists confianca_classificacao numeric(6,5) check(confianca_classificacao is null or confianca_classificacao between 0 and 1);
alter table public.contratos add column if not exists configuracao_diligencia jsonb not null default '{"prazo_padrao_dias":5,"tipo_contagem":"corridos"}'::jsonb;

alter table public.tarefas_diligencia add column if not exists tipo_acao text;
alter table public.tarefas_diligencia add column if not exists prioridade text not null default 'media' check(prioridade in ('baixa','media','alta','critica'));
alter table public.tarefas_diligencia add column if not exists depende_de uuid[] not null default '{}'::uuid[];
alter table public.tarefas_diligencia add column if not exists validacao_solucao text not null default 'pendente' check(validacao_solucao in ('pendente','em_analise','aprovada','rejeitada'));

create or replace function privado.enfileirar_extracao_parecer_contratante()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform privado.enfileirar_job('ai',new.id_organizacao,new.id_contrato,'extrair_diligencia',new.id,jsonb_build_object('entidade_tipo','extrair_diligencia','id_parecer_contratante',new.id,'id_competencia',new.id_competencia,'id_ciclo',new.id_ciclo),'diligencia:'||new.id::text);
  return new;
end;$$;
revoke all on function privado.enfileirar_extracao_parecer_contratante() from public,anon,authenticated;
drop trigger if exists parecer_contratante_extracao on public.pareceres_contratante;
create trigger parecer_contratante_extracao after insert on public.pareceres_contratante for each row when (new.parecer_final_favoravel=false) execute function privado.enfileirar_extracao_parecer_contratante();

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

alter table public.contestacoes add column if not exists recomendada boolean not null default false;
alter table public.contestacoes add column if not exists justificativa_recomendacao text;
alter table public.contestacoes add column if not exists resultado_final text;
alter table public.contestacoes add column if not exists resultado_registrado_em timestamptz;

create or replace function privado.solicitar_minuta_contestacao(p_id_apontamento uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.apontamentos_contratante%rowtype; v_job uuid;
begin
 select * into v from public.apontamentos_contratante where id=p_id_apontamento;
 if v.id is null then raise exception 'Não encontramos o apontamento informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite solicitar uma minuta de contestação.'; end if;
 v_job:=privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'minuta_contestacao',v.id,jsonb_build_object('entidade_tipo','minuta_contestacao','id_apontamento',v.id),'minuta-contestacao:'||v.id::text||':'||v.versao_registro::text);
 return v_job;
end;$$;
create or replace function public.solicitar_minuta_contestacao(p_id_apontamento uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_minuta_contestacao($1)$$;
revoke all on function public.solicitar_minuta_contestacao(uuid) from public,anon;
grant execute on function public.solicitar_minuta_contestacao(uuid) to authenticated;

alter table public.precedentes add column if not exists categoria text;
alter table public.precedentes add column if not exists valor_referencia numeric(18,2);
alter table public.precedentes add column if not exists rubrica text;
alter table public.precedentes add column if not exists documento_tipo text;
alter table public.precedentes add column if not exists confirmacoes integer not null default 1;
alter table public.precedentes add column if not exists ultima_confirmacao_em timestamptz;
alter table public.precedentes add column if not exists hierarquia_normativa integer not null default 0;
alter table public.precedentes add column if not exists forca_score numeric(8,6);

create or replace function privado.registrar_desfecho_contestacao(p_id_contestacao uuid,p_resultado text,p_texto text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.contestacoes%rowtype; v_ap public.apontamentos_contratante%rowtype; v_desfecho uuid; v_contratante uuid; v_prec uuid;
begin
 select * into v from public.contestacoes where id=p_id_contestacao for update;
 if v.id is null then raise exception 'Não encontramos a contestação informada.'; end if;
 select * into v_ap from public.apontamentos_contratante where id=v.id_apontamento;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite registrar o resultado da contestação.'; end if;
 if p_resultado not in ('aceita','rejeitada','parcialmente_aceita','pendente') then raise exception 'Selecione um resultado válido para a contestação.'; end if;
 update public.contestacoes set resultado_final=p_resultado,resultado_registrado_em=now() where id=v.id;
 insert into public.desfechos_apontamentos(id_organizacao,id_contrato,id_competencia,id_apontamento,tipo_desfecho,texto,criado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id_apontamento,'contestacao_'||p_resultado,p_texto,auth.uid()) returning id into v_desfecho;
 update public.apontamentos_contratante set status=case when p_resultado in ('aceita','parcialmente_aceita') then 'encerrado' when p_resultado='rejeitada' then 'em_tratamento' else status end where id=v.id_apontamento;
 select id_contratante into v_contratante from public.contratos where id=v.id_contrato;
 select id into v_prec from public.precedentes where id_organizacao=v.id_organizacao and id_contrato_origem=v.id_contrato and fonte_tipo='apontamento_contratante' and fonte_id=v.id_apontamento limit 1;
 if v_prec is null then
   insert into public.precedentes(id_organizacao,id_contratante,id_contrato_origem,competencia_origem,problema,solucao,desfecho,fonte_tipo,fonte_id,confianca,status,ultima_confirmacao_em)
   select v.id_organizacao,v_contratante,v.id_contrato,c.competencia_referencia,v_ap.descricao,v.texto,p_resultado,'apontamento_contratante',v.id_apontamento,case when p_resultado='aceita' then 0.85 when p_resultado='parcialmente_aceita' then 0.65 else 0.45 end,'ativo',now() from public.competencias c where c.id=v.id_competencia returning id into v_prec;
 else
   update public.precedentes set desfecho=p_resultado,confirmacoes=confirmacoes+1,ultima_confirmacao_em=now(),confianca=greatest(0,least(1,coalesce(confianca,0.5)+case when p_resultado='aceita' then 0.08 when p_resultado='parcialmente_aceita' then 0.03 else -0.05 end)) where id=v_prec;
 end if;
 perform privado.enfileirar_job('embeddings',v.id_organizacao,v.id_contrato,'precedente',v_prec,jsonb_build_object('entidade_tipo','precedente','entidade_id',v_prec),'embed:precedente:'||v_prec::text||':'||extract(epoch from now())::bigint::text);
 perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'aprendizado_desfecho',v_desfecho,jsonb_build_object('entidade_tipo','aprendizado_desfecho','id_desfecho',v_desfecho,'id_precedente',v_prec),'learning:'||v_desfecho::text);
 perform privado.registrar_evento_auditoria(v.id_organizacao,'DesfechoContestacaoRegistrado','contestacoes',v.id,null,jsonb_build_object('resultado',p_resultado,'id_desfecho',v_desfecho,'id_precedente',v_prec));
 return v_desfecho;
end;$$;
create or replace function public.registrar_desfecho_contestacao(p_id_contestacao uuid,p_resultado text,p_texto text default null)
returns uuid language sql security invoker set search_path='' as $$select privado.registrar_desfecho_contestacao($1,$2,$3)$$;
revoke all on function public.registrar_desfecho_contestacao(uuid,text,text) from public,anon;
grant execute on function public.registrar_desfecho_contestacao(uuid,text,text) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101215215_0031_financeiro_preventivo_v3_completo
begin;

alter table public.contratos add column if not exists configuracao_financeira jsonb not null default '{"contas_bancarias_permitidas":[],"limiar_alerta_baixo":0,"limiar_alerta_agrupamento":3,"janela_duplicidade_dias":7,"percentual_similaridade_descricao":0.80,"documentos_futuros_padrao":["nota fiscal","comprovante de pagamento","contrato/ordem de serviço","certidões quando aplicável"]}'::jsonb;
alter table public.transacoes_financeiras add column if not exists id_linha_orcamentaria uuid references public.linhas_orcamentarias(id) on delete restrict;
alter table public.transacoes_financeiras add column if not exists conta_bancaria text;
alter table public.transacoes_financeiras add column if not exists status_fluxo text not null default 'registrada' check(status_fluxo in ('prevista','em_aprovacao','registrada','paga','conciliada','cancelada'));
alter table public.transacoes_financeiras add column if not exists pre_validada boolean not null default false;
alter table public.transacoes_financeiras add column if not exists pre_validada_em timestamptz;

alter table public.regras_preventivas add column if not exists configuracao jsonb not null default '{}'::jsonb;

alter table public.alertas_preventivos add column if not exists codigo_regra text;
alter table public.alertas_preventivos add column if not exists grupo_chave text;
alter table public.alertas_preventivos add column if not exists impacto_financeiro numeric(18,2);
alter table public.alertas_preventivos add column if not exists responsavel uuid references auth.users(id) on delete set null;
alter table public.alertas_preventivos add column if not exists evidencias_futuras jsonb not null default '[]'::jsonb;
alter table public.alertas_preventivos add column if not exists origem_tipo text not null default 'transacao_financeira';
alter table public.alertas_preventivos add column if not exists origem_id uuid;
alter table public.alertas_preventivos add column if not exists idempotency_key text;
alter table public.alertas_preventivos add column if not exists limiar_agrupamento integer;
alter table public.alertas_preventivos add column if not exists quantidade_agrupada integer not null default 1;
create unique index if not exists alertas_preventivos_idempotency_uidx on public.alertas_preventivos(id_organizacao,idempotency_key) where idempotency_key is not null;
create index if not exists alertas_preventivos_grupo_idx on public.alertas_preventivos(id_contrato,grupo_chave,status,criado_em desc);

create or replace function privado.criar_alerta_preventivo(
 p_id_organizacao uuid,p_id_contrato uuid,p_id_transacao uuid,p_codigo_regra text,p_grupo_chave text,p_severidade text,p_descricao text,p_evidencia jsonb,p_impacto numeric,p_evidencias_futuras jsonb,p_idempotency_key text,p_responsavel uuid default null,p_limiar_agrupamento integer default 1
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_existente public.alertas_preventivos%rowtype; v_limiar integer:=greatest(coalesce(p_limiar_agrupamento,1),1);
begin
 if p_idempotency_key is not null then
   select * into v_existente from public.alertas_preventivos where id_organizacao=p_id_organizacao and idempotency_key=p_idempotency_key;
   if v_existente.id is not null then return v_existente.id; end if;
 end if;
 if v_limiar>1 then
   select * into v_existente from public.alertas_preventivos
   where id_contrato=p_id_contrato and grupo_chave=p_grupo_chave and status in ('aberto','em_tratamento') and criado_em>=now()-interval '30 days'
   order by criado_em desc limit 1 for update;
   if v_existente.id is not null then
     update public.alertas_preventivos set quantidade_agrupada=quantidade_agrupada+1,evidencia=coalesce(evidencia,'{}'::jsonb)||jsonb_build_object('ultima_ocorrencia',coalesce(p_evidencia,'{}'::jsonb)),impacto_financeiro=coalesce(impacto_financeiro,0)+coalesce(p_impacto,0) where id=v_existente.id;
     return v_existente.id;
   end if;
 end if;
 insert into public.alertas_preventivos(id_organizacao,id_contrato,id_transacao,regra,codigo_regra,grupo_chave,severidade,status,descricao,evidencia,impacto_financeiro,responsavel,evidencias_futuras,origem_tipo,origem_id,idempotency_key,limiar_agrupamento)
 values(p_id_organizacao,p_id_contrato,p_id_transacao,p_codigo_regra,p_codigo_regra,p_grupo_chave,p_severidade,'aberto',p_descricao,coalesce(p_evidencia,'{}'::jsonb),p_impacto,p_responsavel,coalesce(p_evidencias_futuras,'[]'::jsonb),'transacao_financeira',p_id_transacao,p_idempotency_key,v_limiar)
 returning id into v_id;
 perform privado.registrar_evento_auditoria(p_id_organizacao,'AlertaPreventivoCriado','alertas_preventivos',v_id,null,jsonb_build_object('codigo_regra',p_codigo_regra,'id_transacao',p_id_transacao,'severidade',p_severidade));
 return v_id;
end;$$;
revoke all on function privado.criar_alerta_preventivo(uuid,uuid,uuid,text,text,text,text,jsonb,numeric,jsonb,text,uuid,integer) from public,anon,authenticated;

create or replace function public.worker_validar_transacao_preventiva(p_id_transacao uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_t public.transacoes_financeiras%rowtype; v_c public.contratos%rowtype; v_forn public.fornecedores%rowtype; v_cf public.contratos_fornecedores%rowtype;
 v_linha public.linhas_orcamentarias%rowtype; v_consumido numeric:=0; v_saldo numeric:=null; v_cfg jsonb; v_alertas jsonb:='[]'::jsonb; v_id uuid;
 v_docs jsonb; v_limiar integer:=1; v_contas text[]; v_dup int:=0; v_prec int:=0; v_desc text; v_responsavel uuid;
begin
 select * into v_t from public.transacoes_financeiras where id=p_id_transacao for update;
 if v_t.id is null then raise exception 'Transação financeira não encontrada.'; end if;
 select * into v_c from public.contratos where id=v_t.id_contrato;
 v_cfg:=coalesce(v_c.configuracao_financeira,'{}'::jsonb);
 v_limiar:=greatest(coalesce((v_cfg->>'limiar_alerta_agrupamento')::int,1),1);
 v_docs:=coalesce(v_cfg->'documentos_futuros_padrao','["nota fiscal","comprovante de pagamento"]'::jsonb);
 select id_usuario into v_responsavel from public.vinculos_usuarios where id_organizacao=v_t.id_organizacao and ativo=true and perfil in ('financeiro','gestor_contrato','administrador') order by case perfil when 'financeiro' then 1 when 'gestor_contrato' then 2 else 3 end limit 1;

 -- V3-PREV-001: validação pré-pagamento/fechamento por regras preventivas e dados mínimos.
 if v_t.status_fluxo in ('prevista','em_aprovacao','registrada') then
   if v_t.valor=0 or nullif(trim(v_t.descricao),'') is null then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'PRE_PAGAMENTO_DADOS_INSUFICIENTES','pre_pagamento_dados','alta','A despesa ainda não possui dados suficientes para uma validação segura antes do pagamento.',jsonb_build_object('valor',v_t.valor,'descricao',v_t.descricao,'status_fluxo',v_t.status_fluxo),abs(v_t.valor),v_docs,'pre-dados:'||v_t.id::text,v_responsavel,v_limiar);
     v_alertas:=v_alertas||jsonb_build_array(v_id);
   end if;
 end if;

 -- V3-PREV-002: rubrica, saldo e remanejamento.
 if v_t.id_linha_orcamentaria is not null then
   select * into v_linha from public.linhas_orcamentarias where id=v_t.id_linha_orcamentaria and id_contrato=v_t.id_contrato;
   if v_linha.id is null then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'RUBRICA_INVALIDA','rubrica_invalida','critica','A rubrica informada não pertence ao orçamento vigente deste contrato.',jsonb_build_object('id_linha_orcamentaria',v_t.id_linha_orcamentaria),abs(v_t.valor),v_docs,'rubrica-invalida:'||v_t.id::text,v_responsavel,1); v_alertas:=v_alertas||jsonb_build_array(v_id);
   else
     select coalesce(sum(c.valor_apropriado),0) into v_consumido from public.consumo_orcamentario c where c.id_linha_orcamentaria=v_linha.id and c.id_transacao<>v_t.id;
     v_saldo:=v_linha.valor_total-v_consumido;
     if abs(v_t.valor)>v_saldo then
       v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'SALDO_ORCAMENTARIO_INSUFICIENTE','saldo:'||v_linha.id::text,'critica','A despesa ultrapassa o saldo disponível da rubrica.',jsonb_build_object('rubrica',v_linha.codigo,'valor_total',v_linha.valor_total,'consumido',v_consumido,'saldo_disponivel',v_saldo,'valor_transacao',abs(v_t.valor),'limite_remanejamento_percentual',v_linha.limite_remanejamento_percentual),greatest(abs(v_t.valor)-greatest(v_saldo,0),0),v_docs,'saldo:'||v_t.id::text,v_responsavel,1); v_alertas:=v_alertas||jsonb_build_array(v_id);
     end if;
   end if;
 elsif coalesce(v_t.dados_brutos->>'rubrica_codigo','')<>'' then
   select * into v_linha from public.linhas_orcamentarias where id_contrato=v_t.id_contrato and codigo=v_t.dados_brutos->>'rubrica_codigo' order by criado_em desc limit 1;
   if v_linha.id is null then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'RUBRICA_NAO_LOCALIZADA','rubrica_codigo:'||(v_t.dados_brutos->>'rubrica_codigo'),'alta','A rubrica informada na despesa não foi localizada no orçamento estruturado do contrato.',jsonb_build_object('rubrica_codigo',v_t.dados_brutos->>'rubrica_codigo'),abs(v_t.valor),v_docs,'rubrica-codigo:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
   end if;
 end if;

 -- V3-PREV-003: fornecedor e objeto.
 if v_t.id_fornecedor is not null then
   select * into v_forn from public.fornecedores where id=v_t.id_fornecedor;
   select * into v_cf from public.contratos_fornecedores where id_contrato=v_t.id_contrato and id_fornecedor=v_t.id_fornecedor and status='ativo' and (vigencia_inicio is null or vigencia_inicio<=v_t.data) and (vigencia_fim is null or vigencia_fim>=v_t.data) order by vigencia_inicio desc nulls last limit 1;
   if v_cf.id is null then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'FORNECEDOR_SEM_INSTRUMENTO_VIGENTE','fornecedor:'||v_t.id_fornecedor::text,'alta','Não foi localizado instrumento vigente do fornecedor para este contrato na data da despesa.',jsonb_build_object('fornecedor',v_forn.nome_razao_social,'data',v_t.data),abs(v_t.valor),v_docs,'fornecedor-instrumento:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
   elsif nullif(trim(coalesce(v_cf.objeto,'')),'') is not null and not (lower(v_t.descricao) % lower(v_cf.objeto)) then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'OBJETO_FORNECEDOR_DIVERGENTE','objeto_fornecedor:'||v_t.id_fornecedor::text,'media','A descrição da despesa apresenta baixa aderência textual ao objeto cadastrado do instrumento do fornecedor e precisa de revisão.',jsonb_build_object('descricao_despesa',v_t.descricao,'objeto_fornecedor',v_cf.objeto,'objeto_contrato_publico',v_c.objeto),abs(v_t.valor),v_docs,'objeto-fornecedor:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
   end if;
 end if;

 -- V3-PREV-004: duplicidade por fornecedor/documento/valor/data/similaridade.
 select count(*) into v_dup from public.transacoes_financeiras x
 where x.id_contrato=v_t.id_contrato and x.id<>v_t.id and x.status_fluxo<>'cancelada'
   and abs(x.valor-v_t.valor)<0.01
   and x.data between v_t.data-coalesce((v_cfg->>'janela_duplicidade_dias')::int,7) and v_t.data+coalesce((v_cfg->>'janela_duplicidade_dias')::int,7)
   and ( (v_t.id_fornecedor is not null and x.id_fornecedor=v_t.id_fornecedor) or (coalesce(v_t.fornecedor_documento_original,'')<>'' and x.fornecedor_documento_original=v_t.fornecedor_documento_original) )
   and (coalesce(v_t.documento,'')='' or x.documento=v_t.documento or lower(x.descricao) % lower(v_t.descricao));
 if v_dup>0 then
   v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'POSSIVEL_DUPLICIDADE','duplicidade:'||coalesce(v_t.id_fornecedor::text,v_t.fornecedor_documento_original,'sem_fornecedor')||':'||round(abs(v_t.valor),2)::text,'critica','Foi identificada outra movimentação com combinação semelhante de fornecedor, documento, valor e data.',jsonb_build_object('quantidade_semelhante',v_dup,'documento',v_t.documento,'valor',v_t.valor,'data',v_t.data),abs(v_t.valor),v_docs,'duplicidade:'||v_t.id::text,v_responsavel,1); v_alertas:=v_alertas||jsonb_build_array(v_id);
 end if;

 -- V3-PREV-005: conta bancária configurada.
 if jsonb_typeof(v_cfg->'contas_bancarias_permitidas')='array' and jsonb_array_length(v_cfg->'contas_bancarias_permitidas')>0 then
   v_contas:=array(select jsonb_array_elements_text(v_cfg->'contas_bancarias_permitidas'));
   if coalesce(v_t.conta_bancaria,v_t.dados_brutos->>'conta_bancaria',v_t.dados_brutos->>'conta','')='' then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'CONTA_BANCARIA_NAO_INFORMADA','conta_bancaria','alta','A conta bancária da movimentação não foi informada, embora o contrato possua contas permitidas configuradas.',jsonb_build_object('contas_permitidas',v_cfg->'contas_bancarias_permitidas'),abs(v_t.valor),v_docs,'conta-ausente:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
   elsif not (coalesce(v_t.conta_bancaria,v_t.dados_brutos->>'conta_bancaria',v_t.dados_brutos->>'conta')=any(v_contas)) then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'CONTA_BANCARIA_INCOMPATIVEL','conta_bancaria:'||coalesce(v_t.conta_bancaria,v_t.dados_brutos->>'conta_bancaria',v_t.dados_brutos->>'conta'),'critica','A movimentação foi associada a uma conta bancária diferente das contas permitidas pelo contrato.',jsonb_build_object('conta_movimentacao',coalesce(v_t.conta_bancaria,v_t.dados_brutos->>'conta_bancaria',v_t.dados_brutos->>'conta'),'contas_permitidas',v_cfg->'contas_bancarias_permitidas'),abs(v_t.valor),v_docs,'conta-incompativel:'||v_t.id::text,v_responsavel,1); v_alertas:=v_alertas||jsonb_build_array(v_id);
   end if;
 end if;

 -- V3-PREV-006: precedentes históricos do mesmo contratante, com prioridade ao contrato atual.
 select count(*) into v_prec from public.precedentes p join public.contratos c0 on c0.id=v_t.id_contrato
 where p.id_organizacao=v_t.id_organizacao and p.id_contratante=c0.id_contratante and p.status='ativo'
   and (lower(v_t.descricao) % lower(p.problema) or (p.rubrica is not null and lower(coalesce(v_t.dados_brutos->>'rubrica',''))=lower(p.rubrica)))
   and coalesce(p.desfecho,'') not in ('aceita','favoravel','regular');
 if v_prec>0 then
   v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'PADRAO_HISTORICO_DE_RISCO','precedente_historico','alta','A movimentação apresenta padrão semelhante a apontamento histórico do mesmo contratante. O alerta é preventivo e exige revisão das fontes antes de qualquer conclusão.',jsonb_build_object('precedentes_encontrados',v_prec,'prioridade','próprio contrato antes do transversal'),abs(v_t.valor),v_docs,'precedente-financeiro:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
 end if;

 -- V3-PREV-007: evidências futuras.
 if jsonb_array_length(v_docs)>0 then
   v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'EVIDENCIAS_FUTURAS','documentacao_futura:'||coalesce(v_t.id_fornecedor::text,'geral'),'baixa','Preserve os documentos indicados para facilitar a futura prestação de contas desta despesa.',jsonb_build_object('valor',v_t.valor,'data',v_t.data,'descricao',v_t.descricao),0,v_docs,'evidencias-futuras:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
 end if;

 update public.transacoes_financeiras set pre_validada=true,pre_validada_em=now() where id=v_t.id;
 return jsonb_build_object('id_transacao',v_t.id,'quantidade_alertas',jsonb_array_length(v_alertas),'alertas',v_alertas,'pre_validada',true);
end;$$;
revoke all on function public.worker_validar_transacao_preventiva(uuid) from public,anon,authenticated;
grant execute on function public.worker_validar_transacao_preventiva(uuid) to service_role;

create or replace function privado.enfileirar_validacao_preventiva_transacao()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status_fluxo<>'cancelada' then
   perform privado.enfileirar_job('finance_imports',new.id_organizacao,new.id_contrato,'validacao_preventiva',new.id,jsonb_build_object('entidade_tipo','validacao_preventiva','id_transacao',new.id),'preventiva:'||new.id::text||':'||new.hash_origem);
 end if;
 return new;
end;$$;
revoke all on function privado.enfileirar_validacao_preventiva_transacao() from public,anon,authenticated;
drop trigger if exists contaos_validacao_preventiva_transacao on public.transacoes_financeiras;
create trigger contaos_validacao_preventiva_transacao after insert on public.transacoes_financeiras for each row execute function privado.enfileirar_validacao_preventiva_transacao();

create or replace function privado.atribuir_alerta_preventivo(p_id_alerta uuid,p_responsavel uuid,p_prazo date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.alertas_preventivos%rowtype; v_tarefa uuid;
begin
 select * into v from public.alertas_preventivos where id=p_id_alerta for update;
 if v.id is null then raise exception 'Não encontramos o alerta informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite atribuir este alerta.'; end if;
 if not exists(select 1 from public.vinculos_usuarios vu where vu.id_organizacao=v.id_organizacao and vu.id_usuario=p_responsavel and vu.ativo=true) then raise exception 'O responsável selecionado não possui vínculo ativo com esta organização.'; end if;
 update public.alertas_preventivos set responsavel=p_responsavel,status=case when status='aberto' then 'em_tratamento' else status end where id=v.id;
 insert into public.tarefas_alerta(id_organizacao,id_contrato,id_alerta,descricao,responsavel,prazo,status)
 values(v.id_organizacao,v.id_contrato,v.id,'Tratar alerta preventivo: '||v.descricao,p_responsavel,p_prazo,'pendente') returning id into v_tarefa;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AlertaPreventivoAtribuido','alertas_preventivos',v.id,null,jsonb_build_object('responsavel',p_responsavel,'id_tarefa',v_tarefa,'prazo',p_prazo));
 return v_tarefa;
end;$$;
create or replace function public.atribuir_alerta_preventivo(p_id_alerta uuid,p_responsavel uuid,p_prazo date default null)
returns uuid language sql security invoker set search_path='' as $$select privado.atribuir_alerta_preventivo($1,$2,$3)$$;
revoke all on function public.atribuir_alerta_preventivo(uuid,uuid,date) from public,anon;
grant execute on function public.atribuir_alerta_preventivo(uuid,uuid,date) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101222224_0030_financeiro_preventivo_regras
begin;

create extension if not exists pg_trgm with schema extensions;

create table if not exists public.configuracoes_prevencao_financeira (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  id_contrato uuid not null references public.contratos(id) on delete cascade,
  conta_bancaria_esperada text,
  janela_duplicidade_dias integer not null default 7 check (janela_duplicidade_dias between 0 and 90),
  similaridade_duplicidade numeric(5,4) not null default 0.82 check (similaridade_duplicidade between 0 and 1),
  similaridade_objeto numeric(5,4) not null default 0.35 check (similaridade_objeto between 0 and 1),
  limiar_notificacao numeric(18,2) not null default 0,
  limite_alertas_por_grupo integer not null default 5 check (limite_alertas_por_grupo between 1 and 100),
  evidencias_futuras_padrao jsonb not null default '["nota fiscal ou documento equivalente","comprovante de pagamento","documento que demonstre o vínculo da despesa com o objeto contratual"]'::jsonb,
  ativo boolean not null default true,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique(id_contrato)
);
alter table public.configuracoes_prevencao_financeira enable row level security;
create policy configuracoes_prevencao_financeira_select on public.configuracoes_prevencao_financeira for select to authenticated using (privado.usuario_tem_acesso_contrato(id_contrato));
create policy configuracoes_prevencao_financeira_insert on public.configuracoes_prevencao_financeira for insert to authenticated with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy configuracoes_prevencao_financeira_update on public.configuracoes_prevencao_financeira for update to authenticated using (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create trigger configuracoes_prevencao_financeira_touch before update on public.configuracoes_prevencao_financeira for each row execute function privado.tocar_atualizado_em();
grant select,insert,update on public.configuracoes_prevencao_financeira to authenticated;
revoke delete,truncate,references,trigger on public.configuracoes_prevencao_financeira from authenticated, anon;

create unique index if not exists alertas_preventivos_idempotency_uidx on public.alertas_preventivos(id_organizacao,idempotency_key) where idempotency_key is not null;
create index if not exists alertas_preventivos_central_idx on public.alertas_preventivos(id_contrato,status,severidade,impacto_financeiro desc,criado_em desc);
create index if not exists transacoes_financeiras_dup_idx on public.transacoes_financeiras(id_contrato,id_fornecedor,documento,valor,data);

create or replace function privado.criar_ou_agrupar_alerta_preventivo(p_id_organizacao uuid,p_id_contrato uuid,p_id_transacao uuid,p_codigo_regra text,p_regra text,p_severidade text,p_descricao text,p_evidencia jsonb,p_impacto numeric,p_grupo_chave text,p_evidencias_futuras jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_limite integer := 5;
begin
  select coalesce(c.limite_alertas_por_grupo,5) into v_limite from public.configuracoes_prevencao_financeira c where c.id_contrato=p_id_contrato and c.ativo=true;
  select a.id into v_id from public.alertas_preventivos a where a.id_contrato=p_id_contrato and a.status in ('aberto','em_tratamento') and a.grupo_chave=p_grupo_chave and a.codigo_regra=p_codigo_regra and a.criado_em >= now() - interval '30 days' order by a.criado_em desc limit 1 for update;
  if v_id is not null then
    update public.alertas_preventivos set quantidade_agrupada=quantidade_agrupada+1,impacto_financeiro=coalesce(impacto_financeiro,0)+coalesce(p_impacto,0),evidencia=coalesce(evidencia,'{}'::jsonb)||jsonb_build_object('ultima_transacao',p_id_transacao,'ultima_ocorrencia_em',now()),evidencias_futuras=case when jsonb_array_length(coalesce(evidencias_futuras,'[]'::jsonb))=0 then coalesce(p_evidencias_futuras,'[]'::jsonb) else evidencias_futuras end where id=v_id;
    return v_id;
  end if;
  insert into public.alertas_preventivos(id_organizacao,id_contrato,id_transacao,regra,codigo_regra,severidade,status,descricao,evidencia,impacto_financeiro,grupo_chave,evidencias_futuras,origem_tipo,origem_id,idempotency_key,limiar_agrupamento)
  values(p_id_organizacao,p_id_contrato,p_id_transacao,p_regra,p_codigo_regra,p_severidade,'aberto',p_descricao,coalesce(p_evidencia,'{}'::jsonb),p_impacto,p_grupo_chave,coalesce(p_evidencias_futuras,'[]'::jsonb),'transacao_financeira',p_id_transacao,p_codigo_regra||':'||p_id_transacao::text,v_limite)
  on conflict (id_organizacao,idempotency_key) where idempotency_key is not null do update set evidencia=excluded.evidencia returning id into v_id;
  return v_id;
end; $$;
revoke all on function privado.criar_ou_agrupar_alerta_preventivo(uuid,uuid,uuid,text,text,text,text,jsonb,numeric,text,jsonb) from public,anon,authenticated;

create or replace function privado.validar_transacao_preventivamente(p_id_transacao uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.transacoes_financeiras%rowtype; v_cfg public.configuracoes_prevencao_financeira%rowtype; v_linha public.linhas_orcamentarias%rowtype; v_fornecedor public.fornecedores%rowtype; v_cf public.contratos_fornecedores%rowtype; v_contrato public.contratos%rowtype; v_consumido numeric:=0; v_saldo numeric:=null; v_dup_count integer:=0; v_prec_count integer:=0; v_ids uuid[]:=array[]::uuid[]; v_id uuid; v_sim numeric:=0; v_evidencias jsonb;
begin
  select * into v from public.transacoes_financeiras where id=p_id_transacao for update;
  if v.id is null then raise exception 'Não encontramos a transação informada.'; end if;
  if auth.uid() is not null and not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso a este contrato.'; end if;
  select * into v_contrato from public.contratos where id=v.id_contrato;
  select * into v_cfg from public.configuracoes_prevencao_financeira where id_contrato=v.id_contrato and ativo=true;
  if v_cfg.id is null then insert into public.configuracoes_prevencao_financeira(id_organizacao,id_contrato) values(v.id_organizacao,v.id_contrato) on conflict(id_contrato) do update set atualizado_em=public.configuracoes_prevencao_financeira.atualizado_em returning * into v_cfg; end if;
  v_evidencias:=v_cfg.evidencias_futuras_padrao;
  if v.id_linha_orcamentaria is null then
    v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-002','Rubrica e saldo','alta','A transação ainda não está vinculada a uma rubrica orçamentária válida.',jsonb_build_object('valor',v.valor),abs(v.valor),'rubrica:nao_vinculada',v_evidencias); v_ids:=array_append(v_ids,v_id);
  else
    select * into v_linha from public.linhas_orcamentarias where id=v.id_linha_orcamentaria and id_contrato=v.id_contrato;
    if v_linha.id is null then
      v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-002','Rubrica e saldo','critica','A rubrica informada não pertence ao contrato analisado.',jsonb_build_object('id_linha_orcamentaria',v.id_linha_orcamentaria),abs(v.valor),'rubrica:invalida',v_evidencias); v_ids:=array_append(v_ids,v_id);
    else
      select coalesce(sum(c.valor_apropriado),0) into v_consumido from public.consumo_orcamentario c where c.id_linha_orcamentaria=v_linha.id and c.id_transacao<>v.id;
      v_saldo:=v_linha.valor_total-v_consumido;
      if abs(v.valor)>v_saldo then
        v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-002','Rubrica e saldo','critica','O valor da transação supera o saldo disponível da rubrica. O eventual remanejamento precisa estar formalmente permitido antes do pagamento.',jsonb_build_object('saldo_disponivel',v_saldo,'valor_transacao',abs(v.valor),'limite_remanejamento_percentual',v_linha.limite_remanejamento_percentual),abs(v.valor)-greatest(v_saldo,0),'rubrica:'||v_linha.id::text,v_evidencias); v_ids:=array_append(v_ids,v_id);
      end if;
    end if;
  end if;
  if v.id_fornecedor is not null then
    select * into v_fornecedor from public.fornecedores where id=v.id_fornecedor and id_organizacao=v.id_organizacao;
    select * into v_cf from public.contratos_fornecedores cf where cf.id_contrato=v.id_contrato and cf.id_fornecedor=v.id_fornecedor and cf.status='ativo' and (cf.vigencia_inicio is null or cf.vigencia_inicio<=v.data) and (cf.vigencia_fim is null or cf.vigencia_fim>=v.data) order by cf.vigencia_inicio desc nulls last limit 1;
    if v_fornecedor.id is null or v_cf.id is null then
      v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-003','Fornecedor e objeto','alta','Não foi localizado vínculo contratual ativo do fornecedor para a data desta despesa.',jsonb_build_object('id_fornecedor',v.id_fornecedor,'data',v.data),abs(v.valor),'fornecedor:'||coalesce(v.id_fornecedor::text,'nao_identificado'),v_evidencias); v_ids:=array_append(v_ids,v_id);
    else
      v_sim:=greatest(extensions.similarity(lower(coalesce(v.descricao,'')),lower(coalesce(v_cf.objeto,''))),extensions.similarity(lower(coalesce(v.descricao,'')),lower(coalesce(v_contrato.objeto,''))));
      if v_sim<v_cfg.similaridade_objeto then
        v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-003','Fornecedor e objeto','media','A descrição da despesa possui baixa aderência textual ao objeto do fornecedor e ao objeto do contrato público. Revise antes do pagamento.',jsonb_build_object('similaridade',v_sim,'objeto_fornecedor',v_cf.objeto,'objeto_contrato',v_contrato.objeto),abs(v.valor),'objeto:'||v.id_fornecedor::text,v_evidencias); v_ids:=array_append(v_ids,v_id);
      end if;
    end if;
  end if;
  select count(*) into v_dup_count from public.transacoes_financeiras x where x.id_contrato=v.id_contrato and x.id<>v.id and x.status_fluxo<>'cancelada' and abs(x.valor-v.valor)<0.01 and x.data between v.data-v_cfg.janela_duplicidade_dias and v.data+v_cfg.janela_duplicidade_dias and (v.id_fornecedor is null or x.id_fornecedor=v.id_fornecedor or (v.fornecedor_documento_original is not null and x.fornecedor_documento_original=v.fornecedor_documento_original)) and (v.documento is null or x.documento=v.documento or extensions.similarity(lower(x.descricao),lower(v.descricao))>=v_cfg.similaridade_duplicidade);
  if v_dup_count>0 then v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-004','Possível duplicidade','critica','Foi localizada outra transação semelhante em fornecedor, documento, valor, data ou descrição. Confirme se não se trata de pagamento duplicado.',jsonb_build_object('ocorrencias_semelhantes',v_dup_count,'janela_dias',v_cfg.janela_duplicidade_dias),abs(v.valor),'duplicidade:'||coalesce(v.id_fornecedor::text,v.fornecedor_documento_original,'sem_fornecedor')||':'||round(abs(v.valor),2)::text,v_evidencias); v_ids:=array_append(v_ids,v_id); end if;
  if nullif(trim(coalesce(v_cfg.conta_bancaria_esperada,'')),'') is not null and coalesce(trim(v.conta_bancaria),'')<>trim(v_cfg.conta_bancaria_esperada) then v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-005','Conta bancária correta','critica','A movimentação está associada a uma conta bancária diferente da configurada para este contrato.',jsonb_build_object('conta_informada',v.conta_bancaria,'conta_esperada',v_cfg.conta_bancaria_esperada),abs(v.valor),'conta_bancaria',v_evidencias); v_ids:=array_append(v_ids,v_id); end if;
  select count(*) into v_prec_count from public.precedentes p where p.id_organizacao=v.id_organizacao and p.id_contratante=v_contrato.id_contratante and p.status='ativo' and (p.rubrica is null or v_linha.rubrica is null or lower(p.rubrica)=lower(v_linha.rubrica)) and (extensions.similarity(lower(p.problema),lower(v.descricao))>=0.30 or (p.valor_referencia is not null and abs(p.valor_referencia-abs(v.valor))<=greatest(1,abs(v.valor)*0.05))) and lower(coalesce(p.desfecho,'')) not in ('favoravel','aprovado','aceito');
  if v_prec_count>0 then v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-006','Precedente histórico','media','A transação possui características semelhantes a ocorrências já apontadas anteriormente pelo mesmo contratante.',jsonb_build_object('precedentes_relacionados',v_prec_count,'rotulo','ALERTA HISTÓRICO DO CONTRATANTE'),abs(v.valor),'precedente:'||coalesce(v_linha.rubrica,'geral'),v_evidencias); v_ids:=array_append(v_ids,v_id); end if;
  if jsonb_array_length(coalesce(v_evidencias,'[]'::jsonb))>0 then v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-007','Documentação futura','baixa','Preserve as evidências indicadas para facilitar a prestação de contas futura desta despesa.',jsonb_build_object('carater','orientativo'),0,'documentacao:'||coalesce(v_linha.rubrica,'geral'),v_evidencias); v_ids:=array_append(v_ids,v_id); end if;
  update public.transacoes_financeiras set pre_validada=true,pre_validada_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'TransacaoPreValidada','transacoes_financeiras',v.id,null,jsonb_build_object('alertas',v_ids,'quantidade',coalesce(array_length(v_ids,1),0)));
  return jsonb_build_object('id_transacao',v.id,'pre_validada',true,'alertas',v_ids,'quantidade_alertas',coalesce(array_length(v_ids,1),0),'mensagem',case when coalesce(array_length(v_ids,1),0)=0 then 'Nenhum alerta preventivo foi identificado com os dados disponíveis.' else 'A validação preventiva foi concluída. Revise os alertas antes de seguir com o pagamento ou fechamento.' end);
end; $$;

create or replace function public.validar_transacao_preventivamente(p_id_transacao uuid) returns jsonb language sql security invoker set search_path='' as $$ select privado.validar_transacao_preventivamente(p_id_transacao); $$;
revoke all on function public.validar_transacao_preventivamente(uuid) from public,anon; grant execute on function public.validar_transacao_preventivamente(uuid) to authenticated;

create or replace function privado.atribuir_alerta_preventivo(p_id_alerta uuid,p_responsavel uuid,p_prazo date default null)
returns uuid language plpgsql security definer set search_path=''
as $$ declare v public.alertas_preventivos%rowtype; v_tarefa uuid; begin
 select * into v from public.alertas_preventivos where id=p_id_alerta for update;
 if v.id is null then raise exception 'Não encontramos o alerta informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite atribuir este alerta.'; end if;
 if not exists(select 1 from public.vinculos_usuarios vu where vu.id_organizacao=v.id_organizacao and vu.id_usuario=p_responsavel and vu.ativo=true) then raise exception 'O responsável selecionado não possui vínculo ativo com esta organização.'; end if;
 update public.alertas_preventivos set responsavel=p_responsavel,status=case when status='aberto' then 'em_tratamento' else status end where id=v.id;
 insert into public.tarefas_alerta(id_organizacao,id_contrato,id_alerta,descricao,responsavel,prazo,status) values(v.id_organizacao,v.id_contrato,v.id,'Tratar alerta preventivo: '||v.descricao,p_responsavel,p_prazo,'pendente') returning id into v_tarefa;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AlertaPreventivoAtribuido','alertas_preventivos',v.id,null,jsonb_build_object('responsavel',p_responsavel,'id_tarefa',v_tarefa,'prazo',p_prazo)); return v_tarefa; end; $$;

create or replace function public.atribuir_alerta_preventivo(p_id_alerta uuid,p_responsavel uuid,p_prazo date default null) returns uuid language sql security invoker set search_path='' as $$ select privado.atribuir_alerta_preventivo(p_id_alerta,p_responsavel,p_prazo); $$;
revoke all on function public.atribuir_alerta_preventivo(uuid,uuid,date) from public,anon; grant execute on function public.atribuir_alerta_preventivo(uuid,uuid,date) to authenticated;

create or replace function privado.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null)
returns uuid language plpgsql security definer set search_path=''
as $$ declare v public.alertas_preventivos%rowtype; v_id uuid; v_status text; begin
 select * into v from public.alertas_preventivos where id=p_id_alerta for update;
 if v.id is null then raise exception 'Não encontramos o alerta informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso a este alerta.'; end if;
 if p_decisao not in ('corrigir','justificar','aceitar_risco','descartar') then raise exception 'Selecione uma decisão válida para o tratamento do alerta.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento do tratamento para manter a rastreabilidade.'; end if;
 if p_decisao in ('corrigir','justificar') and p_id_evidencia_versao_documento is null then raise exception 'Anexe uma evidência antes de concluir este tratamento.'; end if;
 insert into public.tratamentos_alertas(id_organizacao,id_contrato,id_alerta,decisao,fundamento,id_evidencia_versao_documento,tratado_por) values(v.id_organizacao,v.id_contrato,v.id,p_decisao,p_fundamento,p_id_evidencia_versao_documento,auth.uid()) returning id into v_id;
 v_status:=case when p_decisao='descartar' then 'descartado' else 'resolvido' end; update public.alertas_preventivos set status=v_status where id=v.id; update public.tarefas_alerta set status='concluida' where id_alerta=v.id and status not in ('concluida','cancelada');
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AlertaPreventivoTratado','alertas_preventivos',v.id,jsonb_build_object('status',v.status),jsonb_build_object('status',v_status,'decisao',p_decisao,'id_tratamento',v_id)); return v_id; end; $$;

create or replace function public.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null) returns uuid language sql security invoker set search_path='' as $$ select privado.tratar_alerta_preventivo(p_id_alerta,p_decisao,p_fundamento,p_id_evidencia_versao_documento); $$;
revoke all on function public.tratar_alerta_preventivo(uuid,text,text,uuid) from public,anon; grant execute on function public.tratar_alerta_preventivo(uuid,text,text,uuid) to authenticated;

create or replace view public.v_central_excecoes_financeiras with (security_invoker=true) as
select a.id,a.id_organizacao,a.id_contrato,a.id_transacao,a.codigo_regra,a.regra,a.severidade,a.status,a.descricao,a.impacto_financeiro,a.grupo_chave,a.quantidade_agrupada,a.responsavel,a.evidencias_futuras,a.criado_em,t.data,t.valor,t.descricao as descricao_transacao,t.documento,t.id_fornecedor from public.alertas_preventivos a left join public.transacoes_financeiras t on t.id=a.id_transacao where a.status in ('aberto','em_tratamento') order by case a.severidade when 'critica' then 4 when 'alta' then 3 when 'media' then 2 else 1 end desc,coalesce(a.impacto_financeiro,0) desc,a.criado_em desc;
grant select on public.v_central_excecoes_financeiras to authenticated;

create or replace function privado.enfileirar_prevalidacao_financeira() returns trigger language plpgsql security definer set search_path=''
as $$ begin if new.status_fluxo in ('prevista','em_aprovacao','registrada') then perform privado.enfileirar_job('finance_imports',new.id_organizacao,new.id_contrato,'transacao_financeira',new.id,jsonb_build_object('entidade_tipo','transacao_financeira','entidade_id',new.id),'prev-fin:'||new.id::text||':'||new.hash_origem); end if; return new; end; $$;
drop trigger if exists transacoes_financeiras_enfileirar_prevalidacao on public.transacoes_financeiras;
create trigger transacoes_financeiras_enfileirar_prevalidacao after insert on public.transacoes_financeiras for each row execute function privado.enfileirar_prevalidacao_financeira();

commit;

-- ============================================================

-- MIGRATION 20261101222229_0031_financeiro_worker_rpc_service
begin;
create or replace function public.worker_validar_transacao_preventiva(p_id_transacao uuid)
returns jsonb language sql security definer set search_path=''
as $$ select privado.validar_transacao_preventivamente(p_id_transacao); $$;
revoke all on function public.worker_validar_transacao_preventiva(uuid) from public,anon,authenticated;
grant execute on function public.worker_validar_transacao_preventiva(uuid) to service_role;
commit;

-- ============================================================

-- MIGRATION 20261101222313_0032_financeiro_prevalidacao_automatica
begin;

drop trigger if exists transacoes_financeiras_enfileirar_prevalidacao on public.transacoes_financeiras;
drop function if exists privado.enfileirar_prevalidacao_financeira();

create or replace function privado.executar_prevalidacao_financeira_apos_insert()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if new.status_fluxo in ('prevista','em_aprovacao','registrada') then
    perform privado.validar_transacao_preventivamente(new.id);
  end if;
  return new;
exception when others then
  perform privado.registrar_evento_auditoria(new.id_organizacao,'PreValidacaoFinanceiraFalhou','transacoes_financeiras',new.id,null,jsonb_build_object('mensagem','Não foi possível concluir a validação preventiva automaticamente. A transação foi preservada e pode ser revalidada.','detalhe_tecnico',sqlerrm));
  return new;
end;
$$;

create trigger transacoes_financeiras_prevalidar after insert on public.transacoes_financeiras for each row execute function privado.executar_prevalidacao_financeira_apos_insert();

commit;

-- ============================================================

-- MIGRATION 20261101222447_0033_inteligencia_historica_ranking_temporal
begin;

alter table public.alertas_historicos_transversais add column if not exists rotulo text not null default 'ALERTA HISTÓRICO TRANSVERSAL DO CONTRATANTE';
alter table public.alertas_historicos_transversais add column if not exists origem_detalhes jsonb not null default '{}'::jsonb;
alter table public.alertas_historicos_transversais add column if not exists efeito_portao boolean not null default false;
alter table public.alertas_historicos_transversais add column if not exists divergente boolean not null default false;
create unique index if not exists alertas_historicos_transversais_unq on public.alertas_historicos_transversais(id_contrato_alvo,id_precedente);

create table if not exists public.fontes_formais_regras_preventivas (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  id_regra_preventiva uuid not null references public.regras_preventivas(id) on delete cascade,
  id_versao_fonte_normativa uuid not null references public.versoes_fontes_normativas(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete cascade,
  fundamento_aplicabilidade text not null,
  validado_por uuid references auth.users(id) on delete set null,
  validado_em timestamptz not null default now(),
  criado_em timestamptz not null default now(),
  unique(id_regra_preventiva,id_versao_fonte_normativa,id_contrato)
);
alter table public.fontes_formais_regras_preventivas enable row level security;
create policy fontes_formais_regras_select on public.fontes_formais_regras_preventivas for select to authenticated using (privado.usuario_tem_acesso_contrato(id_contrato));
grant select on public.fontes_formais_regras_preventivas to authenticated;
revoke insert,update,delete,truncate,references,trigger on public.fontes_formais_regras_preventivas from authenticated,anon;

create or replace function privado.promover_precedente_para_regra(p_id_precedente uuid,p_codigo_regra text,p_descricao text,p_efeito text default 'informativo',p_criticidade text default 'media',p_escopo_aplicacao text default 'contrato')
returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.precedentes%rowtype; v_regra uuid;
begin
 select * into v from public.precedentes where id=p_id_precedente;
 if v.id is null then raise exception 'Não encontramos o precedente informado.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite propor uma regra preventiva.'; end if;
 if p_efeito not in ('informativo','alerta','bloqueio') then raise exception 'Selecione um efeito válido para a regra proposta.'; end if;
 if p_escopo_aplicacao not in ('contrato','contratante','tipo_contrato','organizacao') then raise exception 'Selecione um escopo válido para a regra proposta.'; end if;
 insert into public.regras_preventivas(id_organizacao,id_contrato,id_contratante,codigo_regra,origem_precedente,descricao,efeito,criticidade,escopo_aplicacao,tipo_contrato,numero_versao,situacao,fonte)
 select v.id_organizacao,case when p_escopo_aplicacao='contrato' then v.id_contrato_origem else null end,case when p_escopo_aplicacao='contratante' then v.id_contratante else null end,p_codigo_regra,v.id,p_descricao,p_efeito,p_criticidade,p_escopo_aplicacao,case when p_escopo_aplicacao='tipo_contrato' then c.tipo_contrato else null end,1,'candidata',jsonb_build_object('tipo','precedente_historico','id_precedente',v.id,'aviso','Precedente histórico não equivale a fonte normativa formal.')
 from public.contratos c where c.id=v.id_contrato_origem returning id into v_regra;
 insert into public.revisoes_regras_preventivas(id_organizacao,id_contrato,id_regra,versao,decisao,fundamento,revisor,snapshot)
 values(v.id_organizacao,v.id_contrato_origem,v_regra,1,'solicitada_ajuste','Regra candidata criada a partir de precedente. Antes da ativação, valide a aplicabilidade em fonte formal independente.',auth.uid(),jsonb_build_object('id_precedente',v.id,'efeito_solicitado',p_efeito,'escopo',p_escopo_aplicacao));
 perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraPreventivaCandidataCriada','regras_preventivas',v_regra,null,jsonb_build_object('id_precedente',v.id,'codigo_regra',p_codigo_regra,'situacao','candidata'));
 return v_regra;
end; $$;

create or replace function privado.vincular_fonte_formal_regra(p_id_regra uuid,p_id_versao_fonte uuid,p_id_contrato uuid,p_fundamento text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_regra public.regras_preventivas%rowtype; v_fonte public.versoes_fontes_normativas%rowtype; v_id uuid;
begin
 select * into v_regra from public.regras_preventivas where id=p_id_regra for update;
 if v_regra.id is null then raise exception 'Não encontramos a regra preventiva informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v_regra.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite validar a fonte formal desta regra.'; end if;
 if not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Você não possui acesso ao contrato informado.'; end if;
 select * into v_fonte from public.versoes_fontes_normativas where id=p_id_versao_fonte and id_organizacao=v_regra.id_organizacao and aprovado_em is not null;
 if v_fonte.id is null then raise exception 'A fonte formal precisa existir, pertencer à mesma organização e estar aprovada.'; end if;
 if not (v_fonte.id_contrato=p_id_contrato or (v_fonte.id_contrato is null and exists(select 1 from public.aplicabilidades_fonte a where a.id_contrato=p_id_contrato and a.id_fonte_versao=v_fonte.id and a.aplicavel=true and a.aprovado_em is not null))) then raise exception 'Esta fonte formal ainda não está validada como aplicável ao contrato atual.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento da aplicabilidade da fonte formal.'; end if;
 insert into public.fontes_formais_regras_preventivas(id_organizacao,id_regra_preventiva,id_versao_fonte_normativa,id_contrato,fundamento_aplicabilidade,validado_por)
 values(v_regra.id_organizacao,v_regra.id,v_fonte.id,p_id_contrato,p_fundamento,auth.uid()) on conflict(id_regra_preventiva,id_versao_fonte_normativa,id_contrato) do update set fundamento_aplicabilidade=excluded.fundamento_aplicabilidade,validado_por=excluded.validado_por,validado_em=now() returning id into v_id;
 perform privado.registrar_evento_auditoria(v_regra.id_organizacao,'FonteFormalValidadaParaRegra','fontes_formais_regras_preventivas',v_id,null,jsonb_build_object('id_regra',v_regra.id,'id_versao_fonte',v_fonte.id,'id_contrato',p_id_contrato));
 return v_id;
end; $$;

create or replace function public.vincular_fonte_formal_regra(p_id_regra uuid,p_id_versao_fonte uuid,p_id_contrato uuid,p_fundamento text) returns uuid language sql security invoker set search_path='' as $$ select privado.vincular_fonte_formal_regra($1,$2,$3,$4); $$;
revoke all on function public.vincular_fonte_formal_regra(uuid,uuid,uuid,text) from public,anon; grant execute on function public.vincular_fonte_formal_regra(uuid,uuid,uuid,text) to authenticated;

create or replace function privado.aprovar_regra_preventiva(p_id_regra_preventiva uuid,p_parecer text default null)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.regras_preventivas%rowtype; v_revisao uuid;
begin
 select * into v from public.regras_preventivas where id=p_id_regra_preventiva for update;
 if v.id is null then raise exception 'Não encontramos a regra preventiva informada.'; end if;
 if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
 if not privado.usuario_tem_acesso_organizacao(v.id_organizacao) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite aprovar esta regra preventiva.'; end if;
 if v.situacao<>'candidata' then raise exception 'Somente uma regra candidata pode ser aprovada.'; end if;
 if nullif(trim(v.codigo_regra),'') is null or nullif(trim(v.descricao),'') is null then raise exception 'A regra precisa de código e descrição antes da aprovação.'; end if;
 if v.origem_precedente is not null then
   if v.efeito='bloqueio' and (v.escopo_aplicacao<>'contrato' or v.id_contrato is null) then raise exception 'Regra originada de precedente só pode produzir bloqueio após validação formal para um contrato específico.'; end if;
   if not exists(select 1 from public.fontes_formais_regras_preventivas f where f.id_regra_preventiva=v.id and (v.id_contrato is null or f.id_contrato=v.id_contrato)) then raise exception 'Antes de ativar esta regra, vincule uma fonte formal independente e valide sua aplicabilidade ao contrato.'; end if;
 end if;
 if v.origem_precedente is null and v.fonte='{}'::jsonb then raise exception 'Inclua a fonte que fundamenta esta regra antes de aprová-la.'; end if;
 update public.regras_preventivas set situacao='ativa',aprovada_por=auth.uid(),aprovada_em=now() where id=v.id;
 insert into public.revisoes_regras_preventivas(id_organizacao,id_contrato,id_regra,versao,decisao,fundamento,revisor,snapshot)
 values(v.id_organizacao,v.id_contrato,v.id,v.numero_versao,'aprovada',coalesce(nullif(trim(p_parecer),''),'Regra preventiva aprovada após revisão humana e validação de fonte.'),auth.uid(),jsonb_build_object('codigo_regra',v.codigo_regra,'escopo_aplicacao',v.escopo_aplicacao,'efeito',v.efeito,'criticidade',v.criticidade,'fonte',v.fonte,'origem_precedente',v.origem_precedente)) returning id into v_revisao;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraPreventivaAprovada','regras_preventivas',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','ativa','id_revisao',v_revisao));
 return v_revisao;
end; $$;

create or replace function public.worker_buscar_precedentes_ranqueados(p_id_organizacao uuid,p_id_contratante uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 12)
returns table(id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,escopo_resultado text,similaridade double precision,forca_score numeric,score_final numeric,confirmacoes integer,hierarquia_normativa integer,confianca numeric)
language sql stable security definer set search_path=''
as $$
with base as (
 select p.*,
   (1-(p.embedding OPERATOR(extensions.<=>) p_embedding))::double precision sim,
   case when p.id_contrato_origem=p_id_contrato then 1.0 else 0.65 end escopo_peso,
   case when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '180 days' then 1.0 when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '365 days' then 0.8 when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '730 days' then 0.6 else 0.35 end recencia,
   least(1.0,ln(greatest(p.confirmacoes,1)+1)/ln(11)) confirm_peso,
   least(1.0,greatest(p.hierarquia_normativa,0)::numeric/10.0) hier_peso
 from public.precedentes p
 where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo' and p.embedding is not null
), scored as (
 select b.*,round((greatest(0,b.sim)::numeric*0.55)+(b.escopo_peso::numeric*0.15)+(b.recencia::numeric*0.10)+(b.confirm_peso::numeric*0.08)+(b.hier_peso::numeric*0.06)+(coalesce(b.confianca,0.5)*0.06),4) final
 from base b
)
select s.id,s.id_contrato_origem,s.competencia_origem,s.problema,s.solucao,s.desfecho,case when s.id_contrato_origem=p_id_contrato then 'MESMO CONTRATO' else 'OUTRO CONTRATO DO MESMO CONTRATANTE' end,s.sim,coalesce(s.forca_score,s.final),s.final,s.confirmacoes,s.hierarquia_normativa,s.confianca
from scored s order by (s.id_contrato_origem=p_id_contrato) desc,s.final desc,s.sim desc limit least(greatest(p_limite,1),50);
$$;
revoke all on function public.worker_buscar_precedentes_ranqueados(uuid,uuid,uuid,extensions.vector,integer) from public,anon,authenticated; grant execute on function public.worker_buscar_precedentes_ranqueados(uuid,uuid,uuid,extensions.vector,integer) to service_role;

create or replace function public.worker_buscar_fragmentos_temporais(p_id_organizacao uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_data_referencia date default null,p_limite integer default 10)
returns table(id uuid,id_versao_documento uuid,pagina_inicio integer,pagina_fim integer,texto text,similaridade double precision,fonte_temporal text,inicio_vigencia date,fim_vigencia date)
language sql stable security definer set search_path=''
as $$
select f.id,f.id_versao_documento,f.pagina_inicio,f.pagina_fim,f.texto,(1-(f.embedding OPERATOR(extensions.<=>) p_embedding))::double precision,
       case when vfn.id is not null then 'fonte_formal_vigente' else 'documento_contratual_ou_evidencia' end,vfn.inicio_vigencia,vfn.fim_vigencia
from public.fragmentos_documento f
join public.versoes_documento vd on vd.id=f.id_versao_documento
left join public.versoes_fontes_normativas vfn on vfn.id_arquivo=vd.id_arquivo and vfn.id_organizacao=f.id_organizacao and (vfn.id_contrato is null or vfn.id_contrato=f.id_contrato)
where f.id_organizacao=p_id_organizacao and f.id_contrato=p_id_contrato and f.embedding is not null
  and (p_data_referencia is null or vfn.id is null or ((vfn.inicio_vigencia is null or vfn.inicio_vigencia<=p_data_referencia) and (vfn.fim_vigencia is null or vfn.fim_vigencia>=p_data_referencia)))
order by f.embedding OPERATOR(extensions.<=>) p_embedding limit least(greatest(p_limite,1),30);
$$;
revoke all on function public.worker_buscar_fragmentos_temporais(uuid,uuid,extensions.vector,date,integer) from public,anon,authenticated; grant execute on function public.worker_buscar_fragmentos_temporais(uuid,uuid,extensions.vector,date,integer) to service_role;

create or replace function privado.gerar_alertas_transversais(p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 10)
returns integer language plpgsql security definer set search_path=''
as $$
declare v_org uuid; v_contratante uuid; v_count integer:=0; r record; v_div boolean;
begin
 select id_organizacao,id_contratante into v_org,v_contratante from public.contratos where id=p_id_contrato;
 if v_org is null then raise exception 'Não encontramos o contrato informado.'; end if;
 if auth.uid() is not null and not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Você não possui acesso a este contrato.'; end if;
 for r in select * from public.worker_buscar_precedentes_ranqueados(v_org,v_contratante,p_id_contrato,p_embedding,p_limite*3) where escopo_resultado='OUTRO CONTRATO DO MESMO CONTRATANTE' and score_final>=0.35 order by score_final desc limit p_limite loop
   select exists(select 1 from public.precedentes x where x.id_organizacao=v_org and x.id_contratante=v_contratante and x.id<>r.id and x.status='ativo' and lower(coalesce(x.desfecho,''))<>lower(coalesce(r.desfecho,'')) and extensions.similarity(lower(x.problema),lower(r.problema))>=0.50) into v_div;
   insert into public.alertas_historicos_transversais(id_organizacao,id_contrato_alvo,id_precedente,id_contrato_origem,competencia_origem,score,status,rotulo,origem_detalhes,efeito_portao,divergente)
   select v_org,p_id_contrato,r.id,r.id_contrato_origem,r.competencia_origem,r.score_final,'informativo','ALERTA HISTÓRICO TRANSVERSAL DO CONTRATANTE',jsonb_build_object('contrato_origem',c.numero,'unidade_origem',c.objeto,'competencia_origem',r.competencia_origem,'problema',r.problema,'desfecho',r.desfecho,'fonte_tipo',p.fonte_tipo,'fonte_id',p.fonte_id,'aviso','Esta ocorrência pertence a outro contrato do mesmo contratante e não constitui, por si só, não conformidade do contrato atual.'),false,v_div
   from public.contratos c join public.precedentes p on p.id=r.id where c.id=r.id_contrato_origem
   on conflict(id_contrato_alvo,id_precedente) do update set score=excluded.score,origem_detalhes=excluded.origem_detalhes,divergente=excluded.divergente;
   v_count:=v_count+1;
 end loop;
 return v_count;
end; $$;

create or replace function privado.recalcular_inteligencia_historica(p_id_contratante uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_org uuid; v_metricas integer:=0; v_padroes integer:=0; v_versao integer;
begin
 select id_organizacao into v_org from public.contratantes where id=p_id_contratante;
 if v_org is null then raise exception 'Não encontramos o contratante informado.'; end if;
 if auth.uid() is not null and not privado.usuario_tem_acesso_organizacao(v_org) then raise exception 'Você não possui acesso a este contratante.'; end if;
 delete from public.metricas_historicas where id_organizacao=v_org and id_contratante=p_id_contratante and metrica in ('apontamentos_recorrentes','tempo_apresentacao_parecer_dias','tempo_parecer_validacao_dias');
 insert into public.metricas_historicas(id_organizacao,id_contratante,id_contrato,periodo_inicio,periodo_fim,metrica,valor_numeric,valor_texto,dimensoes)
 select v_org,p_id_contratante,a.id_contrato,min(c.competencia_referencia),max(c.competencia_referencia),'apontamentos_recorrentes',count(*)::numeric,lower(coalesce(a.codigo,'sem_codigo')),jsonb_build_object('severidade',a.severidade)
 from public.apontamentos_contratante a join public.competencias c on c.id=a.id_competencia join public.contratos ct on ct.id=a.id_contrato
 where ct.id_contratante=p_id_contratante and a.id_organizacao=v_org group by a.id_contrato,lower(coalesce(a.codigo,'sem_codigo')),a.severidade;
 get diagnostics v_metricas=row_count;
 insert into public.metricas_historicas(id_organizacao,id_contratante,id_contrato,periodo_inicio,periodo_fim,metrica,valor_numeric,dimensoes)
 select v_org,p_id_contratante,c.id_contrato,c.competencia_referencia,c.competencia_referencia,'tempo_apresentacao_parecer_dias',extract(epoch from (min(pc.recebido_em)-min(ap.apresentado_em)))/86400.0,jsonb_build_object('id_competencia',c.id)
 from public.competencias c join public.contratos ct on ct.id=c.id_contrato join public.apresentacoes_contratante ap on ap.id_competencia=c.id join public.pareceres_contratante pc on pc.id_competencia=c.id
 where ct.id_contratante=p_id_contratante and c.id_organizacao=v_org group by c.id,c.id_contrato,c.competencia_referencia;
 get diagnostics v_padroes=row_count; v_metricas:=v_metricas+v_padroes;
 delete from public.padroes_historicos where id_organizacao=v_org and id_contratante=p_id_contratante and tipo in ('exigencia_observada','mudanca_interpretacao');
 insert into public.padroes_historicos(id_organizacao,id_contratante,tipo,descricao,evidencias,confianca,status)
 select v_org,p_id_contratante,'exigencia_observada','Padrão observado em relatórios do contratante: '||coalesce(a.codigo,'sem código'),jsonb_agg(jsonb_build_object('id_apontamento',a.id,'id_contrato',a.id_contrato,'competencia',c.competencia_referencia,'descricao',a.descricao,'fonte','relatorio_contratante') order by c.competencia_referencia desc),least(1.0,count(*)::numeric/5.0),'observado'
 from public.apontamentos_contratante a join public.competencias c on c.id=a.id_competencia join public.contratos ct on ct.id=a.id_contrato
 where ct.id_contratante=p_id_contratante and a.id_organizacao=v_org group by lower(coalesce(a.codigo,'sem_codigo')),coalesce(a.codigo,'sem código') having count(*)>=2;
 get diagnostics v_padroes=row_count;
 select coalesce(max(versao),0)+1 into v_versao from public.perfis_contratante where id_organizacao=v_org and id_contratante=p_id_contratante;
 insert into public.perfis_contratante(id_organizacao,id_contratante,versao,resumo,padroes,metricas)
 values(v_org,p_id_contratante,v_versao,'Perfil histórico calculado automaticamente. Regras formais e padrões observados permanecem diferenciados.',coalesce((select jsonb_agg(jsonb_build_object('tipo',p.tipo,'descricao',p.descricao,'confianca',p.confianca)) from public.padroes_historicos p where p.id_organizacao=v_org and p.id_contratante=p_id_contratante),'[]'::jsonb),jsonb_build_object('metricas_calculadas',v_metricas,'padroes_calculados',v_padroes,'calculado_em',now()));
 return jsonb_build_object('metricas_calculadas',v_metricas,'padroes_calculados',v_padroes,'versao_perfil',v_versao,'mensagem','Inteligência histórica recalculada mantendo separação entre regras formais e padrões observados.');
end; $$;

create or replace function public.recalcular_inteligencia_historica(p_id_contratante uuid) returns jsonb language sql security invoker set search_path='' as $$ select privado.recalcular_inteligencia_historica($1); $$;
revoke all on function public.recalcular_inteligencia_historica(uuid) from public,anon; grant execute on function public.recalcular_inteligencia_historica(uuid) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101222650_0032a_v4_ranking_temporal_alerta_transversal
-- ContaOS 4.0: ranking em dois escopos, temporalidade e alerta transversal não impeditivo.

alter table public.precedentes
  add column if not exists id_apontamento_historico uuid references public.apontamentos_historicos(id) on delete set null,
  add column if not exists id_relatorio_origem uuid references public.relatorios_historicos_contratante(id) on delete set null,
  add column if not exists titulo text,
  add column if not exists escopo_aplicacao text not null default 'contrato',
  add column if not exists vigencia_inicio date,
  add column if not exists vigencia_fim date,
  add column if not exists revisado_por_humano boolean not null default false,
  add column if not exists revisado_em timestamptz,
  add column if not exists unidade_origem text,
  add column if not exists item_origem text;

update public.precedentes
set vigencia_inicio=coalesce(vigencia_inicio,competencia_origem)
where vigencia_inicio is null and competencia_origem is not null;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='precedentes_escopo_aplicacao_check') then
    alter table public.precedentes add constraint precedentes_escopo_aplicacao_check
      check (escopo_aplicacao in ('contrato','contratante','tipo_contrato','organizacao'));
  end if;
end $$;

alter table public.alertas_historicos_transversais
  add column if not exists id_contratante uuid references public.contratantes(id) on delete restrict,
  add column if not exists id_competencia_alvo uuid references public.competencias(id) on delete cascade,
  add column if not exists id_relatorio_origem uuid references public.relatorios_historicos_contratante(id) on delete set null,
  add column if not exists categoria text,
  add column if not exists similaridade numeric(8,6),
  add column if not exists motivo_sinalizacao text,
  add column if not exists desfecho_origem text,
  add column if not exists unidade_origem text,
  add column if not exists item_origem text,
  add column if not exists evidencias jsonb not null default '[]'::jsonb;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='alertas_transversais_efeito_portao_false_check') then
    alter table public.alertas_historicos_transversais add constraint alertas_transversais_efeito_portao_false_check check (efeito_portao=false);
  end if;
end $$;

create unique index if not exists alertas_transversais_comp_precedente_uk
  on public.alertas_historicos_transversais(id_competencia_alvo,id_precedente)
  where id_competencia_alvo is not null;

alter table public.similaridades_precedentes
  add column if not exists escopo_resultado text,
  add column if not exists similaridade_vetorial numeric(8,6),
  add column if not exists forca_precedente numeric(8,6),
  add column if not exists score_final numeric(8,6),
  add column if not exists posicao_escopo integer,
  add column if not exists contraditorio boolean not null default false,
  add column if not exists data_contexto date;

alter table public.consultas_semanticas
  add column if not exists data_contexto date,
  add column if not exists id_competencia_contexto uuid references public.competencias(id) on delete set null;

create index if not exists precedentes_ranking_v4_idx on public.precedentes(id_organizacao,id_contratante,id_contrato_origem,competencia_origem,status);
create index if not exists precedentes_vigencia_v4_idx on public.precedentes(id_organizacao,id_contratante,vigencia_inicio,vigencia_fim);

create or replace function privado.buscar_precedentes_rankeados_v4(
  p_id_organizacao uuid,
  p_id_contrato uuid,
  p_embedding vector,
  p_data_contexto date default current_date,
  p_filtros jsonb default '{}'::jsonb,
  p_limite_por_escopo integer default 8
)
returns table(
  id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,categoria text,rubrica text,documento_tipo text,
  escopo_resultado text,similaridade_vetorial double precision,forca_precedente double precision,score_final double precision,posicao_escopo bigint,
  contraditorio boolean,id_relatorio_origem uuid,unidade_origem text,item_origem text
)
language sql stable security definer set search_path=''
as $$
with alvo as (
  select c.id,c.id_organizacao,c.id_contratante from public.contratos c
  where c.id=p_id_contrato and c.id_organizacao=p_id_organizacao
), candidatos as (
  select p.*,
         case when p.id_contrato_origem=p_id_contrato then 'proprio_contrato' else 'transversal_contratante' end as escopo_calc,
         (1-(p.embedding OPERATOR(extensions.<=>) p_embedding))::double precision as sim,
         greatest(0.0,1.0-(greatest(0,(coalesce(p_data_contexto,current_date)-coalesce(p.competencia_origem,p.vigencia_inicio,p.criado_em::date)))::double precision/1825.0)) as recencia,
         least(greatest(coalesce(p.confirmacoes,1),1),5)::double precision/5.0 as confirmacao,
         least(greatest(coalesce(p.hierarquia_normativa,0),0),10)::double precision/10.0 as hierarquia,
         case when nullif(trim(coalesce(p.desfecho,'')),'') is null then 0.4 else 1.0 end as desfecho_score,
         (
           (case when nullif(p_filtros->>'categoria','') is not null and lower(coalesce(p.categoria,''))=lower(p_filtros->>'categoria') then 1 else 0 end) +
           (case when nullif(p_filtros->>'rubrica','') is not null and lower(coalesce(p.rubrica,''))=lower(p_filtros->>'rubrica') then 1 else 0 end) +
           (case when nullif(p_filtros->>'documento_tipo','') is not null and lower(coalesce(p.documento_tipo,''))=lower(p_filtros->>'documento_tipo') then 1 else 0 end) +
           (case when nullif(p_filtros->>'valor','') is not null and p.valor_referencia is not null and abs(p.valor_referencia-(p_filtros->>'valor')::numeric)<=greatest(1,abs((p_filtros->>'valor')::numeric)*0.05) then 1 else 0 end)
         )::double precision/4.0 as aderencia_estruturada
  from public.precedentes p
  join alvo a on a.id_organizacao=p.id_organizacao and a.id_contratante=p.id_contratante
  where p.status='ativo' and p.embedding is not null
    and (p.competencia_origem is null or p.competencia_origem<=coalesce(p_data_contexto,current_date))
    and (p.vigencia_inicio is null or p.vigencia_inicio<=coalesce(p_data_contexto,current_date))
    and (p.vigencia_fim is null or p.vigencia_fim>=coalesce(p_data_contexto,current_date))
    and (nullif(p_filtros->>'categoria','') is null or lower(coalesce(p.categoria,''))=lower(p_filtros->>'categoria'))
    and (nullif(p_filtros->>'rubrica','') is null or lower(coalesce(p.rubrica,''))=lower(p_filtros->>'rubrica'))
    and (nullif(p_filtros->>'documento_tipo','') is null or lower(coalesce(p.documento_tipo,''))=lower(p_filtros->>'documento_tipo'))
), pontuados as (
  select c.*,
         least(1.0,greatest(0.0,0.35*c.recencia+0.30*c.confirmacao+0.15*c.hierarquia+0.20*c.desfecho_score)) as forca_calc,
         exists(
           select 1 from candidatos x where x.id<>c.id and x.escopo_calc=c.escopo_calc
             and coalesce(x.categoria,'')=coalesce(c.categoria,'')
             and lower(coalesce(x.desfecho,''))<>lower(coalesce(c.desfecho,'')) and x.sim>=0.45
         ) as contraditorio_calc
  from candidatos c
), rank_base as (
  select p.*,least(1.0,greatest(0.0,0.60*p.sim+0.25*p.forca_calc+0.15*p.aderencia_estruturada)) as score_calc from pontuados p
), rankeados as (
  select p.*,row_number() over(partition by p.escopo_calc order by p.score_calc desc,p.competencia_origem desc nulls last,p.id) as rn from rank_base p
)
select r.id,r.id_contrato_origem,r.competencia_origem,r.problema,r.solucao,r.desfecho,r.categoria,r.rubrica,r.documento_tipo,
       r.escopo_calc,r.sim,r.forca_calc,r.score_calc,r.rn,r.contraditorio_calc,r.id_relatorio_origem,r.unidade_origem,r.item_origem
from rankeados r
where r.rn<=least(greatest(coalesce(p_limite_por_escopo,8),1),20)
order by case when r.escopo_calc='proprio_contrato' then 0 else 1 end,r.rn;
$$;
revoke all on function privado.buscar_precedentes_rankeados_v4(uuid,uuid,vector,date,jsonb,integer) from public,anon,authenticated;
grant execute on function privado.buscar_precedentes_rankeados_v4(uuid,uuid,vector,date,jsonb,integer) to service_role;

create or replace function public.worker_buscar_precedentes_v4(
  p_id_organizacao uuid,p_id_contrato uuid,p_embedding vector,p_data_contexto date default current_date,p_filtros jsonb default '{}'::jsonb,p_limite_por_escopo integer default 8
)
returns table(
  id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,categoria text,rubrica text,documento_tipo text,
  escopo_resultado text,similaridade_vetorial double precision,forca_precedente double precision,score_final double precision,posicao_escopo bigint,
  contraditorio boolean,id_relatorio_origem uuid,unidade_origem text,item_origem text
)
language sql stable security definer set search_path=''
as $$ select * from privado.buscar_precedentes_rankeados_v4($1,$2,$3,$4,$5,$6) $$;
revoke all on function public.worker_buscar_precedentes_v4(uuid,uuid,vector,date,jsonb,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_precedentes_v4(uuid,uuid,vector,date,jsonb,integer) to service_role;

create or replace function privado.contexto_normativo_temporal_v4(p_id_contrato uuid,p_data_contexto date)
returns table(id_fonte uuid,id_versao uuid,tipo text,titulo text,referencia text,versao integer,inicio_vigencia date,fim_vigencia date,conteudo_texto text,hash text)
language sql stable security definer set search_path=''
as $$
select f.id,v.id,f.tipo,f.titulo,f.referencia,v.versao,v.inicio_vigencia,v.fim_vigencia,v.conteudo_texto,v.hash
from public.fontes_normativas f
join public.versoes_fontes_normativas v on v.id_fonte=f.id
join public.contratos c on c.id=p_id_contrato and c.id_organizacao=f.id_organizacao
where (f.id_contrato is null or f.id_contrato=p_id_contrato)
  and f.situacao in ('vigente','ativa','aprovada') and v.aprovado_em is not null
  and (v.inicio_vigencia is null or v.inicio_vigencia<=coalesce(p_data_contexto,current_date))
  and (v.fim_vigencia is null or v.fim_vigencia>=coalesce(p_data_contexto,current_date))
order by case when f.id_contrato=p_id_contrato then 0 else 1 end,f.tipo,f.titulo,v.versao desc;
$$;
revoke all on function privado.contexto_normativo_temporal_v4(uuid,date) from public,anon,authenticated;
grant execute on function privado.contexto_normativo_temporal_v4(uuid,date) to service_role;

create or replace function public.worker_contexto_normativo_temporal_v4(p_id_contrato uuid,p_data_contexto date)
returns table(id_fonte uuid,id_versao uuid,tipo text,titulo text,referencia text,versao integer,inicio_vigencia date,fim_vigencia date,conteudo_texto text,hash text)
language sql stable security definer set search_path=''
as $$ select * from privado.contexto_normativo_temporal_v4($1,$2) $$;
revoke all on function public.worker_contexto_normativo_temporal_v4(uuid,date) from public,anon,authenticated;
grant execute on function public.worker_contexto_normativo_temporal_v4(uuid,date) to service_role;

create or replace function privado.materializar_alertas_transversais_v4(p_id_competencia uuid,p_embedding vector,p_filtros jsonb default '{}'::jsonb,p_limite integer default 8)
returns integer language plpgsql security definer set search_path=''
as $$
declare v_comp public.competencias%rowtype; v_contrato public.contratos%rowtype; r record; v_qtd integer:=0;
begin
  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then raise exception 'Competência não encontrada.'; end if;
  select * into v_contrato from public.contratos where id=v_comp.id_contrato;
  for r in select * from privado.buscar_precedentes_rankeados_v4(v_comp.id_organizacao,v_comp.id_contrato,p_embedding,v_comp.competencia_referencia,p_filtros,p_limite)
           where escopo_resultado='transversal_contratante'
  loop
    insert into public.alertas_historicos_transversais(
      id_organizacao,id_contratante,id_contrato_alvo,id_competencia_alvo,id_precedente,id_contrato_origem,competencia_origem,id_relatorio_origem,
      categoria,score,similaridade,motivo_sinalizacao,rotulo,efeito_portao,desfecho_origem,unidade_origem,item_origem,evidencias,status,origem_detalhes,divergente
    ) values(
      v_comp.id_organizacao,v_contrato.id_contratante,v_comp.id_contrato,v_comp.id,r.id,r.id_contrato_origem,r.competencia_origem,r.id_relatorio_origem,
      r.categoria,r.score_final,r.similaridade_vetorial,
      'Ocorrência semelhante localizada em outro contrato da mesma organização com o mesmo contratante. O achado é informativo e não constitui obrigação do contrato atual.',
      'ALERTA HISTÓRICO TRANSVERSAL DO CONTRATANTE',false,r.desfecho,r.unidade_origem,r.item_origem,
      jsonb_build_array(jsonb_build_object('id_precedente',r.id,'contrato_origem',r.id_contrato_origem,'competencia_origem',r.competencia_origem,'desfecho',r.desfecho)),
      'informativo',jsonb_build_object('contrato_origem',r.id_contrato_origem,'competencia_origem',r.competencia_origem,'id_relatorio_origem',r.id_relatorio_origem,'item_origem',r.item_origem,'desfecho',r.desfecho),r.contraditorio
    )
    on conflict(id_competencia_alvo,id_precedente) where id_competencia_alvo is not null
    do update set score=excluded.score,similaridade=excluded.similaridade,motivo_sinalizacao=excluded.motivo_sinalizacao,
                  desfecho_origem=excluded.desfecho_origem,evidencias=excluded.evidencias,origem_detalhes=excluded.origem_detalhes,divergente=excluded.divergente;
    v_qtd:=v_qtd+1;
  end loop;
  return v_qtd;
end $$;
revoke all on function privado.materializar_alertas_transversais_v4(uuid,vector,jsonb,integer) from public,anon,authenticated;
grant execute on function privado.materializar_alertas_transversais_v4(uuid,vector,jsonb,integer) to service_role;

create or replace function public.worker_materializar_alertas_transversais_v4(p_id_competencia uuid,p_embedding vector,p_filtros jsonb default '{}'::jsonb,p_limite integer default 8)
returns integer language sql security definer set search_path=''
as $$ select privado.materializar_alertas_transversais_v4($1,$2,$3,$4) $$;
revoke all on function public.worker_materializar_alertas_transversais_v4(uuid,vector,jsonb,integer) from public,anon,authenticated;
grant execute on function public.worker_materializar_alertas_transversais_v4(uuid,vector,jsonb,integer) to service_role;


-- ============================================================

-- MIGRATION 20261101222715_0032b_v4_governanca_regra_formal_perfil_contratante
-- ContaOS 4.0: promoção controlada de histórico e perfil agregado do contratante.

alter table public.regras_preventivas
  add column if not exists id_fonte_formal_versao uuid references public.versoes_fontes_normativas(id) on delete restrict;

create index if not exists regras_preventivas_fonte_formal_idx on public.regras_preventivas(id_fonte_formal_versao) where id_fonte_formal_versao is not null;

create or replace function privado.propor_regra_de_alerta_transversal_v4(
  p_id_alerta uuid,
  p_id_fonte_formal_versao uuid,
  p_codigo_regra text,
  p_descricao text,
  p_efeito text default 'bloqueio',
  p_criticidade text default 'alta'
)
returns uuid language plpgsql security definer set search_path=''
as $$
declare a public.alertas_historicos_transversais%rowtype; v public.versoes_fontes_normativas%rowtype; f public.fontes_normativas%rowtype; v_regra uuid;
begin
  select * into a from public.alertas_historicos_transversais where id=p_id_alerta for update;
  if a.id is null then raise exception 'Alerta histórico transversal não encontrado.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(a.id_contrato_alvo) or not privado.usuario_possui_perfil(a.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then
    raise exception 'Seu perfil atual não permite propor regra a partir deste alerta.';
  end if;
  if p_efeito not in ('informativo','alerta','bloqueio') then raise exception 'Efeito inválido.'; end if;
  if p_criticidade not in ('baixa','media','alta','critica') then raise exception 'Criticidade inválida.'; end if;
  select * into v from public.versoes_fontes_normativas
   where id=p_id_fonte_formal_versao and id_organizacao=a.id_organizacao and aprovado_em is not null;
  if v.id is null then raise exception 'Selecione uma versão formal, aprovada e pertencente à mesma organização.'; end if;
  select * into f from public.fontes_normativas where id=v.id_fonte;
  if f.id_contrato is not null and f.id_contrato<>a.id_contrato_alvo then
    raise exception 'A fonte formal selecionada não é aplicável ao contrato analisado.';
  end if;
  insert into public.regras_preventivas(
    id_organizacao,id_contrato,codigo_regra,origem_precedente,descricao,efeito,criticidade,escopo_aplicacao,vigencia_inicio,situacao,fonte,id_fonte_formal_versao,motivo
  ) values(
    a.id_organizacao,a.id_contrato_alvo,p_codigo_regra,a.id_precedente,p_descricao,p_efeito,p_criticidade,'contrato',coalesce(v.inicio_vigencia,current_date),'candidata',
    jsonb_build_object('tipo','fonte_formal_independente','id_fonte',f.id,'id_versao',v.id,'referencia',f.referencia,'hash',v.hash),v.id,
    'Proposta originada por alerta transversal. O precedente é apenas contexto; o fundamento impeditivo, quando houver, é a fonte formal independente.'
  ) returning id into v_regra;
  update public.alertas_historicos_transversais set status='revisado' where id=a.id;
  perform privado.registrar_evento_auditoria(a.id_organizacao,'RegraFormalPropostaDeAlertaTransversal','regras_preventivas',v_regra,null,jsonb_build_object('id_alerta',a.id,'id_fonte_versao',v.id));
  return v_regra;
end $$;
revoke all on function privado.propor_regra_de_alerta_transversal_v4(uuid,uuid,text,text,text,text) from public,anon;
grant execute on function privado.propor_regra_de_alerta_transversal_v4(uuid,uuid,text,text,text,text) to authenticated,service_role;

create or replace function public.propor_regra_de_alerta_transversal(
  p_id_alerta uuid,p_id_fonte_formal_versao uuid,p_codigo_regra text,p_descricao text,p_efeito text default 'bloqueio',p_criticidade text default 'alta'
)
returns uuid language sql set search_path=''
as $$ select privado.propor_regra_de_alerta_transversal_v4($1,$2,$3,$4,$5,$6) $$;
revoke all on function public.propor_regra_de_alerta_transversal(uuid,uuid,text,text,text,text) from public,anon;
grant execute on function public.propor_regra_de_alerta_transversal(uuid,uuid,text,text,text,text) to authenticated,service_role;

create or replace function privado.promover_precedente_para_regra(
  p_id_precedente uuid,
  p_codigo_regra text,
  p_descricao text,
  p_efeito text default 'informativo',
  p_criticidade text default 'media',
  p_escopo_aplicacao text default 'contrato'
)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.precedentes%rowtype; v_regra uuid;
begin
  select * into v from public.precedentes where id=p_id_precedente;
  if v.id is null then raise exception 'Precedente não encontrado.'; end if;
  if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if p_efeito not in ('informativo','alerta','bloqueio') then raise exception 'Efeito inválido.'; end if;
  if p_escopo_aplicacao not in ('contrato','contratante','tipo_contrato','organizacao') then raise exception 'Escopo inválido.'; end if;
  insert into public.regras_preventivas(id_organizacao,id_contrato,id_contratante,codigo_regra,origem_precedente,descricao,efeito,criticidade,escopo_aplicacao,tipo_contrato,numero_versao,situacao,motivo)
  select v.id_organizacao,
         case when p_escopo_aplicacao='contrato' then v.id_contrato_origem else null end,
         case when p_escopo_aplicacao='contratante' then v.id_contratante else null end,
         p_codigo_regra,v.id,p_descricao,p_efeito,p_criticidade,p_escopo_aplicacao,
         case when p_escopo_aplicacao='tipo_contrato' then c.tipo_contrato else null end,1,'candidata',
         'Regra candidata originada de precedente histórico. Nenhuma ativação ocorre sem revisão humana.'
  from public.contratos c where c.id=v.id_contrato_origem returning id into v_regra;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'PrecedenteConvertidoEmRegraCandidata','regras_preventivas',v_regra,null,jsonb_build_object('id_precedente',v.id,'codigo_regra',p_codigo_regra,'efeito_solicitado',p_efeito,'escopo',p_escopo_aplicacao));
  return v_regra;
end $$;

create or replace function privado.aprovar_regra_preventiva(p_id_regra_preventiva uuid,p_parecer text default null)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.regras_preventivas%rowtype; p public.precedentes%rowtype; vf public.versoes_fontes_normativas%rowtype; f public.fontes_normativas%rowtype; v_revisao uuid; v_exige_fonte boolean:=false;
begin
  select * into v from public.regras_preventivas where id=p_id_regra_preventiva for update;
  if v.id is null then raise exception 'Não encontramos a regra preventiva informada.'; end if;
  if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
  if not privado.usuario_tem_acesso_organizacao(v.id_organizacao) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite aprovar esta regra preventiva.'; end if;
  if v.situacao<>'candidata' then raise exception 'Somente uma regra candidata pode ser aprovada.'; end if;
  if nullif(trim(v.codigo_regra),'') is null or nullif(trim(v.descricao),'') is null then raise exception 'A regra precisa de código e descrição antes da aprovação.'; end if;
  if v.escopo_aplicacao='contrato' and v.id_contrato is null then raise exception 'Informe o contrato ao qual esta regra se aplica.'; end if;
  if v.escopo_aplicacao='contratante' and v.id_contratante is null then raise exception 'Informe o contratante ao qual esta regra se aplica.'; end if;
  if v.escopo_aplicacao='tipo_contrato' and nullif(trim(coalesce(v.tipo_contrato,'')),'') is null then raise exception 'Informe o tipo de contrato ao qual esta regra se aplica.'; end if;
  if v.origem_precedente is not null then
    select * into p from public.precedentes where id=v.origem_precedente;
    v_exige_fonte := (v.efeito='bloqueio' and (v.escopo_aplicacao<>'contrato' or v.id_contrato is distinct from p.id_contrato_origem));
  end if;
  if v_exige_fonte and v.id_fonte_formal_versao is null then
    raise exception 'Regra impeditiva originada de histórico transversal exige fonte formal independente aplicável ao contrato atual.';
  end if;
  if v.id_fonte_formal_versao is not null then
    select * into vf from public.versoes_fontes_normativas where id=v.id_fonte_formal_versao and id_organizacao=v.id_organizacao and aprovado_em is not null;
    if vf.id is null then raise exception 'A fonte formal vinculada não possui versão aprovada válida.'; end if;
    select * into f from public.fontes_normativas where id=vf.id_fonte;
    if v.id_contrato is not null and f.id_contrato is not null and f.id_contrato<>v.id_contrato then raise exception 'A fonte formal vinculada pertence a outro contrato.'; end if;
    if v.vigencia_inicio is not null and vf.fim_vigencia is not null and v.vigencia_inicio>vf.fim_vigencia then raise exception 'A vigência proposta para a regra está fora da vigência da fonte formal.'; end if;
  elsif v.origem_precedente is null and v.fonte='{}'::jsonb then
    raise exception 'Inclua a fonte que fundamenta esta regra antes de aprová-la.';
  end if;
  update public.regras_preventivas set situacao='ativa',aprovada_por=auth.uid(),aprovada_em=now() where id=v.id;
  insert into public.revisoes_regras_preventivas(id_organizacao,id_contrato,id_regra,versao,decisao,fundamento,revisor,snapshot)
  values(v.id_organizacao,v.id_contrato,v.id,v.numero_versao,'aprovada',coalesce(nullif(trim(p_parecer),''),'Regra preventiva aprovada após revisão humana.'),auth.uid(),
         jsonb_build_object('codigo_regra',v.codigo_regra,'escopo_aplicacao',v.escopo_aplicacao,'efeito',v.efeito,'criticidade',v.criticidade,'fonte',v.fonte,'id_fonte_formal_versao',v.id_fonte_formal_versao,'origem_precedente',v.origem_precedente))
  returning id into v_revisao;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraPreventivaAprovada','regras_preventivas',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','ativa','id_revisao',v_revisao));
  return v_revisao;
end $$;

create or replace function privado.recalcular_perfil_contratante_v4(p_id_organizacao uuid,p_id_contratante uuid)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_perfil uuid; v_versao integer; v_pad jsonb; v_met jsonb; v_div jsonb;
begin
  if not exists(select 1 from public.contratantes c where c.id=p_id_contratante and c.id_organizacao=p_id_organizacao) then raise exception 'Contratante não encontrado nesta organização.'; end if;
  select coalesce(max(versao),0)+1 into v_versao from public.perfis_contratante where id_organizacao=p_id_organizacao and id_contratante=p_id_contratante;
  select coalesce(jsonb_agg(x order by (x->>'quantidade')::int desc),'[]'::jsonb) into v_pad
  from (
    select jsonb_build_object('categoria',coalesce(p.categoria,'sem_categoria'),'quantidade',count(*),'tipo','padrao_observado','fonte','precedentes_historicos') x
    from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo'
    group by coalesce(p.categoria,'sem_categoria')
  ) s;
  select jsonb_build_object(
    'total_precedentes',(select count(*) from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante),
    'contratos_com_historico',(select count(distinct p.id_contrato_origem) from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante),
    'tempo_medio_analise_dias',(
      select round(avg(extract(epoch from (pc.recebido_em-a.apresentado_em))/86400.0)::numeric,2)
      from public.apresentacoes_contratante a join public.pareceres_contratante pc on pc.id_apresentacao=a.id
      join public.contratos c on c.id=a.id_contrato
      where a.id_organizacao=p_id_organizacao and c.id_contratante=p_id_contratante and pc.recebido_em>=a.apresentado_em
    ),
    'media_rodadas',(
      select round(avg(z.rodadas)::numeric,2) from (
        select max(a.numero_rodada)::numeric rodadas from public.apresentacoes_contratante a join public.contratos c on c.id=a.id_contrato
        where a.id_organizacao=p_id_organizacao and c.id_contratante=p_id_contratante group by a.id_competencia
      ) z
    )
  ) into v_met;
  select coalesce(jsonb_agg(x),'[]'::jsonb) into v_div
  from (
    select jsonb_build_object('categoria',coalesce(p.categoria,'sem_categoria'),'desfechos',jsonb_agg(distinct coalesce(p.desfecho,'sem_desfecho')),'tipo','divergencia_historica') x
    from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo'
    group by coalesce(p.categoria,'sem_categoria')
    having count(distinct lower(coalesce(p.desfecho,'')))>1
  ) q;
  insert into public.perfis_contratante(id_organizacao,id_contratante,versao,resumo,padroes,metricas)
  values(p_id_organizacao,p_id_contratante,v_versao,'Perfil histórico calculado a partir de precedentes rastreáveis. Padrões observados não constituem norma formal.',v_pad||v_div,v_met)
  returning id into v_perfil;
  return v_perfil;
end $$;
revoke all on function privado.recalcular_perfil_contratante_v4(uuid,uuid) from public,anon,authenticated;
grant execute on function privado.recalcular_perfil_contratante_v4(uuid,uuid) to service_role;

create or replace function public.worker_recalcular_perfil_contratante_v4(p_id_organizacao uuid,p_id_contratante uuid)
returns uuid language sql security definer set search_path=''
as $$ select privado.recalcular_perfil_contratante_v4($1,$2) $$;
revoke all on function public.worker_recalcular_perfil_contratante_v4(uuid,uuid) from public,anon,authenticated;
grant execute on function public.worker_recalcular_perfil_contratante_v4(uuid,uuid) to service_role;


-- ============================================================

-- MIGRATION 20261101222835_0034_automacao_documental_ia_ocr
begin;

create table if not exists public.configuracoes_automacao (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  provedor_ia text not null default 'openai_compatible',
  modelo_ia text,
  provedor_ocr text not null default 'rest_compatible',
  modo_ia text not null default 'assistido' check (modo_ia in ('desativado','assistido')),
  modo_ocr text not null default 'assistido' check (modo_ocr in ('desativado','assistido')),
  configuracao_publica jsonb not null default '{}'::jsonb,
  ativo boolean not null default true,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique(id_organizacao)
);
alter table public.configuracoes_automacao enable row level security;
create policy configuracoes_automacao_select on public.configuracoes_automacao for select to authenticated using (privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy configuracoes_automacao_insert on public.configuracoes_automacao for insert to authenticated with check (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create policy configuracoes_automacao_update on public.configuracoes_automacao for update to authenticated using (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[])) with check (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create trigger configuracoes_automacao_touch before update on public.configuracoes_automacao for each row execute function privado.tocar_atualizado_em();
grant select,insert,update on public.configuracoes_automacao to authenticated;
revoke delete,truncate,references,trigger on public.configuracoes_automacao from authenticated,anon;

create or replace function privado.enfileirar_extracao_assistida_documento()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_hash text; v_contrato uuid; v_org uuid;
begin
  if new.etapa='documents' and new.status='concluido' and (old.status is distinct from new.status) then
    select vd.hash,vd.id_contrato,vd.id_organizacao into v_hash,v_contrato,v_org from public.versoes_documento vd where vd.id=new.id_versao_documento;
    if v_org is not null then
      perform privado.enfileirar_job('ai',v_org,v_contrato,'extrair_documento',new.id_versao_documento,jsonb_build_object('entidade_tipo','extrair_documento','id_versao_documento',new.id_versao_documento),'extrair-doc:'||new.id_versao_documento::text||':'||coalesce(v_hash,'sem_hash'));
    end if;
  end if;
  return new;
end; $$;
revoke all on function privado.enfileirar_extracao_assistida_documento() from public,anon,authenticated;
drop trigger if exists processamentos_documento_enfileirar_ia on public.processamentos_documento;
create trigger processamentos_documento_enfileirar_ia after update of status on public.processamentos_documento for each row execute function privado.enfileirar_extracao_assistida_documento();

create or replace function privado.revisar_sugestao_extracao(p_id_sugestao uuid,p_aprovar boolean,p_conteudo_revisado text default null,p_categoria_revisada text default null,p_id_requisito_revisado uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.sugestoes_extracao_documento%rowtype; v_regra uuid; v_conteudo text; v_categoria text; v_req uuid;
begin
  select * into v from public.sugestoes_extracao_documento where id=p_id_sugestao for update;
  if v.id is null then raise exception 'Não encontramos a sugestão informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso ao contrato desta sugestão.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite revisar esta sugestão.'; end if;
  if v.status<>'pendente' then raise exception 'Esta sugestão já foi revisada anteriormente.'; end if;
  v_conteudo:=coalesce(nullif(trim(p_conteudo_revisado),''),v.conteudo);
  v_categoria:=coalesce(nullif(trim(p_categoria_revisada),''),v.categoria_sugerida);
  v_req:=coalesce(p_id_requisito_revisado,v.id_requisito_sugerido);
  if not p_aprovar then
    update public.sugestoes_extracao_documento set status='rejeitada',revisado_por=auth.uid(),revisado_em=now(),metadados=metadados||jsonb_build_object('conteudo_revisado',p_conteudo_revisado,'categoria_revisada',p_categoria_revisada) where id=v.id;
    perform privado.registrar_evento_auditoria(v.id_organizacao,'SugestaoExtracaoRejeitada','sugestoes_extracao_documento',v.id,null,jsonb_build_object('tipo',v.tipo));
    return jsonb_build_object('status','rejeitada','mensagem','A sugestão foi rejeitada e nenhuma regra ou metadado foi alterado.');
  end if;
  if v.tipo='classificacao' then
    update public.documentos_competencia d set categoria=coalesce(v_categoria,d.categoria),id_requisito_competencia=coalesce(v_req,d.id_requisito_competencia)
    from public.versoes_documento vd where vd.id=v.id_versao_documento and vd.id_documento_competencia=d.id;
    update public.documentos_contrato d set categoria=coalesce(v_categoria,d.categoria)
    from public.versoes_documento vd where vd.id=v.id_versao_documento and vd.id_documento_contrato=d.id;
  elsif v.tipo='metadado' then
    update public.versoes_documento set metadados_extraidos=coalesce(metadados_extraidos,'{}'::jsonb)||coalesce(v.metadados->'campos','{}'::jsonb)||jsonb_build_object('resumo_revisado',v_conteudo,'revisado_por',auth.uid(),'revisado_em',now()) where id=v.id_versao_documento;
  else
    insert into public.regras_conformidade(id_organizacao,id_contrato,codigo,descricao,tipo,efeito_portao,configuracao,situacao)
    values(v.id_organizacao,v.id_contrato,'SUG-'||upper(substr(replace(v.id::text,'-',''),1,12)),v_conteudo,'assistida',false,jsonb_build_object('origem','sugestao_extracao','id_sugestao',v.id,'id_versao_documento',v.id_versao_documento,'pagina',v.pagina,'trecho_fonte',v.trecho_fonte,'tipo_sugestao',v.tipo,'observacao','Regra criada em rascunho após revisão humana. A ativação material exige fluxo próprio de aprovação.'),'rascunho') returning id into v_regra;
  end if;
  update public.sugestoes_extracao_documento set status='aprovada',conteudo=v_conteudo,categoria_sugerida=v_categoria,id_requisito_sugerido=v_req,revisado_por=auth.uid(),revisado_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'SugestaoExtracaoAprovada','sugestoes_extracao_documento',v.id,null,jsonb_build_object('tipo',v.tipo,'id_regra_rascunho',v_regra));
  return jsonb_build_object('status','aprovada','id_regra_rascunho',v_regra,'mensagem',case when v_regra is null then 'A sugestão foi aprovada e aplicada ao documento.' else 'A sugestão foi aprovada e gerou uma regra em rascunho para revisão material.' end);
end; $$;

create or replace function public.revisar_sugestao_extracao(p_id_sugestao uuid,p_aprovar boolean,p_conteudo_revisado text default null,p_categoria_revisada text default null,p_id_requisito_revisado uuid default null)
returns jsonb language sql security invoker set search_path='' as $$ select privado.revisar_sugestao_extracao($1,$2,$3,$4,$5); $$;
revoke all on function public.revisar_sugestao_extracao(uuid,boolean,text,text,uuid) from public,anon;
grant execute on function public.revisar_sugestao_extracao(uuid,boolean,text,text,uuid) to authenticated;

create or replace function public.worker_obter_contexto_documento(p_id_versao uuid)
returns jsonb language sql stable security definer set search_path=''
as $$
select jsonb_build_object(
 'versao',to_jsonb(vd),
 'arquivo',to_jsonb(a),
 'documento_competencia',case when dc.id is null then null else to_jsonb(dc) end,
 'documento_contrato',case when dco.id is null then null else to_jsonb(dco) end,
 'paginas',coalesce((select jsonb_agg(jsonb_build_object('pagina',p.numero_pagina,'texto',p.texto_extraido) order by p.numero_pagina) from public.paginas_documento p where p.id_versao_documento=vd.id),'[]'::jsonb),
 'requisitos',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria) order by r.ordem) from public.requisitos_competencia r join public.competencias c on c.id=r.id_competencia where c.id_contrato=vd.id_contrato and c.situacao not in ('encerrada','cancelada')),'[]'::jsonb)
)
from public.versoes_documento vd join public.arquivos a on a.id=vd.id_arquivo
left join public.documentos_competencia dc on dc.id=vd.id_documento_competencia
left join public.documentos_contrato dco on dco.id=vd.id_documento_contrato
where vd.id=p_id_versao;
$$;
revoke all on function public.worker_obter_contexto_documento(uuid) from public,anon,authenticated;
grant execute on function public.worker_obter_contexto_documento(uuid) to service_role;

commit;

-- ============================================================

-- MIGRATION 20261101222911_0035_revisao_humana_jobs_ia
begin;

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

create or replace function public.revisar_solucao_tarefa_diligencia(p_id_tarefa uuid,p_aprovar boolean,p_fundamento text)
returns jsonb language sql security invoker set search_path='' as $$ select privado.revisar_solucao_tarefa_diligencia($1,$2,$3); $$;
revoke all on function public.revisar_solucao_tarefa_diligencia(uuid,boolean,text) from public,anon;
grant execute on function public.revisar_solucao_tarefa_diligencia(uuid,boolean,text) to authenticated;

create or replace function public.worker_recalcular_inteligencia(p_id_contratante uuid)
returns jsonb language sql security definer set search_path='' as $$ select privado.recalcular_inteligencia_historica($1); $$;
revoke all on function public.worker_recalcular_inteligencia(uuid) from public,anon,authenticated;
grant execute on function public.worker_recalcular_inteligencia(uuid) to service_role;

commit;

-- ============================================================

-- MIGRATION 20261101222947_0036_openai_provedor_padrao_ia_ocr
begin;
alter table public.configuracoes_automacao alter column provedor_ia set default 'openai';
alter table public.configuracoes_automacao alter column provedor_ocr set default 'openai';
update public.configuracoes_automacao set provedor_ia='openai',provedor_ocr='openai',configuracao_publica=coalesce(configuracao_publica,'{}'::jsonb)||jsonb_build_object('base_url','https://api.openai.com/v1','ocr_modo','visao_multimodal','segredo_api','OPENAI_API_KEY') where ativo=true;
commit;

-- ============================================================

-- MIGRATION 20261101223926_0035_openai_modelos_ia_ocr
begin;

alter table public.configuracoes_automacao
  add column if not exists modelo_ocr text;

alter table public.configuracoes_automacao
  alter column provedor_ia set default 'openai',
  alter column provedor_ocr set default 'openai',
  alter column modelo_ia set default 'gpt-6.1-sol',
  alter column modelo_ocr set default 'gpt-6-luna';

update public.configuracoes_automacao
set provedor_ia='openai',
    provedor_ocr='openai',
    modelo_ia=coalesce(modelo_ia,'gpt-6.1-sol'),
    modelo_ocr=coalesce(modelo_ocr,'gpt-6-luna'),
    configuracao_publica=coalesce(configuracao_publica,'{}'::jsonb) || jsonb_build_object(
      'idioma','pt-BR',
      'timezone','America/Sao_Paulo',
      'ocr_detalhe','high',
      'revisao_humana_obrigatoria',true,
      'segredos_no_frontend',false
    ),
    atualizado_em=now();

insert into public.catalogo_mensagens_sistema(codigo,categoria,severidade,titulo,mensagem,orientacao,exibir_detalhe_tecnico)
values
 ('OPENAI_OK','integracao','info','Inteligência artificial conectada','A integração com a OpenAI está disponível para o ContaOS.','Nenhuma ação é necessária.',false),
 ('OPENAI_INDISPONIVEL','integracao','aviso','Inteligência artificial temporariamente indisponível','Não foi possível usar a inteligência artificial neste momento. O ContaOS tentará novamente automaticamente.','Você pode continuar usando as demais funções do sistema.',false),
 ('OCR_CONCLUIDO','documento','info','Leitura concluída','O documento foi lido com sucesso e seguirá para análise.','Aguarde a conclusão da análise automática.',false),
 ('OCR_FALHOU','documento','aviso','Leitura não concluída','Não foi possível concluir a leitura automática do documento. O ContaOS tentará novamente automaticamente.','Se o aviso persistir, envie o arquivo novamente ou acione o suporte.',false)
on conflict (codigo) do update set categoria=excluded.categoria,severidade=excluded.severidade,titulo=excluded.titulo,mensagem=excluded.mensagem,orientacao=excluded.orientacao,exibir_detalhe_tecnico=false,atualizado_em=now();

commit;

-- ============================================================

-- MIGRATION 20261101224343_0037_indices_fks_pos_fechamento
do $$
declare
  r record;
  v_index_name text;
begin
  for r in
    select
      n.nspname as schema_name,
      c.relname as table_name,
      con.conname as constraint_name,
      con.conkey as fk_cols
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    where con.contype = 'f'
      and n.nspname = 'public'
      and not exists (
        select 1
        from pg_index i
        where i.indrelid = con.conrelid
          and i.indisvalid
          and (i.indkey::smallint[])[0:cardinality(con.conkey)-1] = con.conkey
      )
  loop
    v_index_name := left('fk_' || r.table_name || '_' || substr(md5(r.constraint_name),1,10) || '_idx', 63);
    execute format(
      'create index if not exists %I on %I.%I (%s)',
      v_index_name,
      r.schema_name,
      r.table_name,
      (
        select string_agg(quote_ident(a.attname), ', ' order by u.ord)
        from unnest(r.fk_cols) with ordinality u(attnum, ord)
        join pg_attribute a
          on a.attrelid = format('%I.%I',r.schema_name,r.table_name)::regclass
         and a.attnum = u.attnum
      )
    );
  end loop;
end $$;

-- ============================================================

-- MIGRATION 20261101225646_0038_exportacao_historico_migrations
begin;

create or replace function public.worker_exportar_historico_migrations()
returns text
language sql
security definer
set search_path=''
as $$
  select string_agg(
    '-- MIGRATION ' || version || '_' || name || E'\n' || array_to_string(statements,E'\n\n'),
    E'\n\n-- ============================================================\n\n'
    order by version
  )
  from supabase_migrations.schema_migrations;
$$;

revoke all on function public.worker_exportar_historico_migrations() from public,anon,authenticated;
grant execute on function public.worker_exportar_historico_migrations() to service_role;

commit;