begin;

create table privado.administradores_master (
  id_usuario uuid primary key references auth.users(id) on delete cascade,
  ativo boolean not null default true,
  inicio_em timestamptz not null default now(),
  fim_em timestamptz,
  criado_por uuid references auth.users(id) on delete set null,
  motivo text,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint administradores_master_periodo_ck check (fim_em is null or fim_em > inicio_em)
);

revoke all on table privado.administradores_master from public, anon, authenticated;

create trigger administradores_master_touch
before update on privado.administradores_master
for each row execute function privado.tocar_atualizado_em();

create or replace function privado.auditar_administrador_master()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_id uuid := coalesce(new.id_usuario, old.id_usuario);
  v_evento text;
begin
  v_evento := case tg_op
    when 'INSERT' then 'AdministradorMasterConcedido'
    when 'UPDATE' then 'AdministradorMasterAtualizado'
    when 'DELETE' then 'AdministradorMasterRevogado'
  end;

  perform privado.registrar_evento_auditoria(
    null,
    v_evento,
    'administradores_master',
    v_id,
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end,
    jsonb_build_object('escopo','global','origem_operacao','backend_privilegiado')
  );
  return coalesce(new, old);
end;
$$;
revoke all on function privado.auditar_administrador_master() from public, anon, authenticated;

create trigger administradores_master_audit
before insert or update or delete on privado.administradores_master
for each row execute function privado.auditar_administrador_master();

create or replace function privado.usuario_e_administrador_master()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select privado.sessao_usuario_ativa()
     and exists (
       select 1
       from privado.administradores_master m
       where m.id_usuario = auth.uid()
         and m.ativo = true
         and m.inicio_em <= now()
         and (m.fim_em is null or m.fim_em > now())
     );
$$;
revoke all on function privado.usuario_e_administrador_master() from public, anon;
grant execute on function privado.usuario_e_administrador_master() to authenticated;

create or replace function privado.usuario_tem_acesso_organizacao(p_id_organizacao uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select privado.sessao_usuario_ativa()
     and (
       privado.usuario_e_administrador_master()
       or exists (
         select 1
         from public.vinculos_usuarios v
         where v.id_organizacao = p_id_organizacao
           and v.id_usuario = auth.uid()
           and v.ativo = true
           and v.inicio_em <= now()
           and (v.fim_em is null or v.fim_em > now())
       )
     );
$$;

create or replace function privado.usuario_tem_acesso_contrato(p_id_contrato uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select privado.sessao_usuario_ativa()
     and (
       privado.usuario_e_administrador_master()
       or exists (
         select 1
         from public.contratos c
         join public.vinculos_usuarios v on v.id_organizacao = c.id_organizacao
         where c.id = p_id_contrato
           and v.id_usuario = auth.uid()
           and v.ativo = true
           and v.inicio_em <= now()
           and (v.fim_em is null or v.fim_em > now())
           and (
             v.escopo_todos_contratos = true
             or exists (
               select 1
               from public.vinculos_usuario_contratos vc
               where vc.id_vinculo_usuario = v.id
                 and vc.id_contrato = c.id
                 and vc.ativo = true
             )
           )
       )
     );
$$;

create or replace function privado.usuario_possui_perfil(p_id_organizacao uuid, p_perfis text[])
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select privado.sessao_usuario_ativa()
     and (
       (privado.usuario_e_administrador_master() and 'administrador' = any(coalesce(p_perfis, array[]::text[])))
       or exists (
         select 1
         from public.vinculos_usuarios v
         where v.id_organizacao = p_id_organizacao
           and v.id_usuario = auth.uid()
           and v.ativo = true
           and v.inicio_em <= now()
           and (v.fim_em is null or v.fim_em > now())
           and v.perfil = any(coalesce(p_perfis, array[]::text[]))
       )
     );
$$;

create or replace function privado.usuario_possui_vinculo_ativo()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select privado.sessao_usuario_ativa()
     and (
       privado.usuario_e_administrador_master()
       or exists (
         select 1
         from public.vinculos_usuarios v
         where v.id_usuario = auth.uid()
           and v.ativo = true
           and v.inicio_em <= now()
           and (v.fim_em is null or v.fim_em > now())
       )
     );
$$;

create or replace function public.listar_organizacoes_disponiveis()
returns table(
  id uuid,
  razao_social text,
  nome_fantasia text,
  cnpj varchar,
  situacao text,
  perfil text
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_master boolean;
begin
  if auth.uid() is null or not privado.sessao_usuario_ativa() then
    raise exception using errcode='42501', message='Sua sessão não está ativa.';
  end if;

  v_master := privado.usuario_e_administrador_master();

  return query
  select
    o.id,
    o.razao_social,
    o.nome_fantasia,
    o.cnpj,
    o.situacao,
    case when v_master then 'administrador_master'::text else v.perfil end as perfil
  from public.organizacoes o
  left join public.vinculos_usuarios v
    on not v_master
   and v.id_organizacao = o.id
   and v.id_usuario = auth.uid()
   and v.ativo = true
   and v.inicio_em <= now()
   and (v.fim_em is null or v.fim_em > now())
  where v_master or v.id is not null
  order by lower(coalesce(o.nome_fantasia,o.razao_social)), o.id;
end;
$$;
revoke all on function public.listar_organizacoes_disponiveis() from public, anon;
grant execute on function public.listar_organizacoes_disponiveis() to authenticated;

comment on table privado.administradores_master is 'Identidades globais Administrador Master. Não exposta à Data API pública.';
comment on function privado.usuario_e_administrador_master() is 'Retorna true somente para sessão ativa com concessão Master global ativa e vigente.';
comment on function public.listar_organizacoes_disponiveis() is 'SYS-01/SYS-04: lista organizações acessíveis. Master global recebe todas; demais usuários somente vínculos ativos/vigentes.';

commit;
