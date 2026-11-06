begin;

create or replace function privado.sessao_usuario_ativa()
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select
    auth.uid() is not null
    and privado.uuid_seguro(auth.jwt()->>'session_id') is not null
    and exists (
      select 1
      from auth.sessions s
      where s.id = privado.uuid_seguro(auth.jwt()->>'session_id')
        and s.user_id = auth.uid()
        and (s.not_after is null or s.not_after > now())
    );
$function$;

create or replace function privado.sessao_usuario_aal2_ativa()
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select privado.sessao_usuario_ativa()
     and coalesce(auth.jwt()->>'aal','aal1') = 'aal2';
$function$;

create or replace function privado.usuario_tem_acesso_organizacao(p_id_organizacao uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select privado.sessao_usuario_ativa()
     and exists (
       select 1
       from public.vinculos_usuarios v
       where v.id_organizacao = p_id_organizacao
         and v.id_usuario = auth.uid()
         and v.ativo = true
         and v.inicio_em <= now()
         and (v.fim_em is null or v.fim_em > now())
     );
$function$;

create or replace function privado.usuario_tem_acesso_contrato(p_id_contrato uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select privado.sessao_usuario_ativa()
     and exists (
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
     );
$function$;

create or replace function privado.usuario_possui_perfil(p_id_organizacao uuid, p_perfis text[])
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select privado.sessao_usuario_ativa()
     and exists (
       select 1
       from public.vinculos_usuarios v
       where v.id_organizacao = p_id_organizacao
         and v.id_usuario = auth.uid()
         and v.ativo = true
         and v.inicio_em <= now()
         and (v.fim_em is null or v.fim_em > now())
         and v.perfil = any(p_perfis)
     );
$function$;

revoke all on function privado.sessao_usuario_ativa() from public, anon;
revoke all on function privado.sessao_usuario_aal2_ativa() from public, anon;
grant execute on function privado.sessao_usuario_ativa() to authenticated, service_role;
grant execute on function privado.sessao_usuario_aal2_ativa() to authenticated, service_role;

commit;
