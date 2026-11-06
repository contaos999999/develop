begin;
alter default privileges for role postgres in schema public revoke maintain on tables from anon;
alter default privileges for role postgres in schema public revoke maintain on tables from authenticated;
revoke maintain on all tables in schema public from anon, authenticated;
commit;
