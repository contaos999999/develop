begin;

alter table public.organizacoes alter column timezone set default 'America/Sao_Paulo';
update public.organizacoes set timezone='America/Sao_Paulo' where timezone is distinct from 'America/Sao_Paulo';

create or replace function privado.criar_perfil_usuario_auth()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  insert into public.usuarios(id_usuario,nome,email,situacao,criado_em,atualizado_em)
  values(
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'nome'),''),nullif(trim(new.raw_user_meta_data->>'name'),'')),
    new.email,
    'ativo',
    now(),
    now()
  )
  on conflict(id_usuario) do update
    set email=excluded.email,
        nome=coalesce(public.usuarios.nome,excluded.nome),
        atualizado_em=now();
  return new;
end;
$$;
revoke all on function privado.criar_perfil_usuario_auth() from public,anon,authenticated;

drop trigger if exists contaos_auth_usuario_criado on auth.users;
create trigger contaos_auth_usuario_criado
after insert or update of email,raw_user_meta_data on auth.users
for each row execute function privado.criar_perfil_usuario_auth();

insert into public.usuarios(id_usuario,nome,email,situacao,criado_em,atualizado_em)
select u.id,
       coalesce(nullif(trim(u.raw_user_meta_data->>'nome'),''),nullif(trim(u.raw_user_meta_data->>'name'),'')),
       u.email,
       'ativo',
       coalesce(u.created_at,now()),
       now()
from auth.users u
on conflict(id_usuario) do update set
  email=excluded.email,
  nome=coalesce(public.usuarios.nome,excluded.nome),
  atualizado_em=now();

create or replace function public.criar_organizacao(
  p_razao_social text,
  p_nome_fantasia text default null,
  p_cnpj varchar default null,
  p_timezone text default 'America/Sao_Paulo'
)
returns uuid
language sql
security invoker
set search_path=''
as $$select privado.criar_organizacao($1,$2,$3,$4)$$;
revoke all on function public.criar_organizacao(text,text,varchar,text) from public,anon;
grant execute on function public.criar_organizacao(text,text,varchar,text) to authenticated;

grant execute on function privado.criar_organizacao(text,text,varchar,text) to authenticated;

commit;
