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
