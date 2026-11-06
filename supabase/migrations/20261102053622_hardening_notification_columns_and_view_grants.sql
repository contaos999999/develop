begin;
revoke insert, update, delete on table public.v_central_excecoes_financeiras from authenticated;
revoke update on table public.notificacoes from authenticated;
grant update (lida_em) on table public.notificacoes to authenticated;
commit;
