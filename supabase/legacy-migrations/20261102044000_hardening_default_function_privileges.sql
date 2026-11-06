begin;

-- Zero trust para novas RPCs/funções criadas pelas migrations do ContaOS.
-- Evita que uma nova função em public se torne executável por anon/authenticated
-- apenas por herdar os privilégios padrão do projeto.
alter default privileges for role postgres in schema public
  revoke execute on functions from public;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon;

alter default privileges for role postgres in schema public
  revoke execute on functions from authenticated;

-- O backend interno continua podendo utilizar funções novas quando necessário.
alter default privileges for role postgres in schema public
  grant execute on functions to service_role;

commit;
