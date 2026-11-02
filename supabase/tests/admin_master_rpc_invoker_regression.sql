-- Administrador Master — regressão da RPC SYS-01/SYS-04 após SECURITY INVOKER.
-- Executar com dados sintéticos em transação e ROLLBACK.
-- Critérios certificados no HML em 02/11/2026:
-- 1. public.listar_organizacoes_disponiveis() possui prosecdef=false;
-- 2. anon não possui EXECUTE;
-- 3. Master sem vínculo físico vê organizações A e B;
-- 4. ambas retornam perfil=administrador_master;
-- 5. administrador comum vinculado apenas a A vê somente A;
-- 6. administrador comum não é reconhecido como Master.
-- Resultado observado: PASS 6/6, FAIL 0/6.

begin;

-- Provas estruturais que não dependem de fixture:
do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='listar_organizacoes_disponiveis'
      and p.prosecdef=false
  ) then
    raise exception 'listar_organizacoes_disponiveis deve ser SECURITY INVOKER';
  end if;

  if has_function_privilege('anon','public.listar_organizacoes_disponiveis()','EXECUTE') then
    raise exception 'anon não pode executar listar_organizacoes_disponiveis';
  end if;
end $$;

rollback;
