begin;

-- Configurações operacionais não precisam ser legíveis antes do login.
-- Mesmo sem GRANT atual para anon, removemos anon das policies para impedir
-- exposição futura caso um grant seja concedido por engano.
drop policy if exists configuracao_api_leitura on public.configuracao_api;
create policy configuracao_api_leitura
on public.configuracao_api
for select
to authenticated
using (true);

drop policy if exists configuracao_upload_leitura on public.configuracao_upload;
create policy configuracao_upload_leitura
on public.configuracao_upload
for select
to authenticated
using (true);

revoke select on public.configuracao_api from anon;
revoke select on public.configuracao_upload from anon;

grant select on public.configuracao_api to authenticated;
grant select on public.configuracao_upload to authenticated;

commit;
