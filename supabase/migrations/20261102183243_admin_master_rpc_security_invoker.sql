begin;

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
security invoker
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

comment on function public.listar_organizacoes_disponiveis() is
'SYS-01/SYS-04: lista organizações acessíveis sob RLS. Master global recebe todas; demais usuários somente vínculos ativos/vigentes.';

commit;
