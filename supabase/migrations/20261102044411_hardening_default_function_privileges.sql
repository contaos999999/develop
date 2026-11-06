begin;

alter default privileges for role postgres in schema public
  revoke execute on functions from public;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon;

alter default privileges for role postgres in schema public
  revoke execute on functions from authenticated;

alter default privileges for role postgres in schema public
  grant execute on functions to service_role;

commit;
