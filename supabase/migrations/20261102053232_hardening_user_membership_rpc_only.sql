begin;
revoke insert, update on table public.vinculos_usuarios from authenticated;
drop policy if exists vinculos_admin_insert on public.vinculos_usuarios;
drop policy if exists vinculos_admin_update on public.vinculos_usuarios;
commit;
