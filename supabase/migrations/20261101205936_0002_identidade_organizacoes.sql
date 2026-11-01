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
