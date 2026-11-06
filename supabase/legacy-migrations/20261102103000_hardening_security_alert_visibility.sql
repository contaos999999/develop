begin;

-- Helper central para leituras globais que só fazem sentido dentro de uma
-- sessão ContaOS válida e vinculada a alguma organização ativa.
create or replace function privado.usuario_possui_vinculo_ativo()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select privado.sessao_usuario_ativa()
     and exists (
       select 1
       from public.vinculos_usuarios v
       where v.id_usuario = auth.uid()
         and v.ativo = true
         and v.inicio_em <= now()
         and (v.fim_em is null or v.fim_em > now())
     );
$$;

revoke all on function privado.usuario_possui_vinculo_ativo() from public;
revoke all on function privado.usuario_possui_vinculo_ativo() from anon;
grant execute on function privado.usuario_possui_vinculo_ativo() to authenticated, service_role;

-- Configurações operacionais: não basta estar autenticado; é necessário
-- possuir sessão ativa e vínculo ativo com o ContaOS.
drop policy if exists configuracao_api_leitura on public.configuracao_api;
create policy configuracao_api_leitura
on public.configuracao_api
for select
to authenticated
using ((select privado.usuario_possui_vinculo_ativo()));

drop policy if exists configuracao_upload_leitura on public.configuracao_upload;
create policy configuracao_upload_leitura
on public.configuracao_upload
for select
to authenticated
using ((select privado.usuario_possui_vinculo_ativo()));

drop policy if exists perfis_select on public.perfis_usuarios;
create policy perfis_select
on public.perfis_usuarios
for select
to authenticated
using ((select privado.usuario_possui_vinculo_ativo()));

-- Catálogos e localização deixam de ser tabelas públicas. O frontend público
-- de autenticação usa copy própria em PT-BR e não depende dessas tabelas.
drop policy if exists catalogo_mensagens_leitura on public.catalogo_mensagens_sistema;
create policy catalogo_mensagens_leitura
on public.catalogo_mensagens_sistema
for select
to authenticated
using ((select privado.usuario_possui_vinculo_ativo()));

drop policy if exists catalogo_status_leitura on public.catalogo_status_ui;
create policy catalogo_status_leitura
on public.catalogo_status_ui
for select
to authenticated
using ((select privado.usuario_possui_vinculo_ativo()));

drop policy if exists configuracao_localizacao_leitura on public.configuracao_localizacao;
create policy configuracao_localizacao_leitura
on public.configuracao_localizacao
for select
to authenticated
using ((select privado.usuario_possui_vinculo_ativo()));

revoke select on public.configuracao_api from anon;
revoke select on public.configuracao_upload from anon;
revoke select on public.perfis_usuarios from anon;
revoke select on public.catalogo_mensagens_sistema from anon;
revoke select on public.catalogo_status_ui from anon;
revoke select on public.configuracao_localizacao from anon;

grant select on public.configuracao_api to authenticated;
grant select on public.configuracao_upload to authenticated;
grant select on public.perfis_usuarios to authenticated;
grant select on public.catalogo_mensagens_sistema to authenticated;
grant select on public.catalogo_status_ui to authenticated;
grant select on public.configuracao_localizacao to authenticated;

-- As RPCs de catálogo/normalização não são necessárias antes do login.
revoke execute on function public.obter_mensagem_sistema(text) from anon;
revoke execute on function public.normalizar_erro_backend(text,text) from anon;
grant execute on function public.obter_mensagem_sistema(text) to authenticated, service_role;
grant execute on function public.normalizar_erro_backend(text,text) to authenticated, service_role;

commit;
