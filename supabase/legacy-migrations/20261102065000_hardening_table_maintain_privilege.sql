begin;

-- PostgreSQL 17 inclui o privilégio MAINTAIN no conjunto amplo de permissões.
-- Papéis de aplicação não precisam executar manutenção de tabelas.
alter default privileges for role postgres in schema public
  revoke maintain on tables from anon;

alter default privileges for role postgres in schema public
  revoke maintain on tables from authenticated;

revoke maintain on all tables in schema public from anon, authenticated;

commit;
