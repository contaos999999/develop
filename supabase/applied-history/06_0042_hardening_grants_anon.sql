-- MIGRATION 20261101233319_0042_hardening_grants_anon
begin;

-- Menor privilégio para visitantes não autenticados.
-- Remove qualquer grant herdado por objetos criados após o hardening inicial.
revoke all privileges on all tables in schema public from anon;

-- Somente catálogos estritamente públicos necessários antes do login.
grant select on public.catalogo_mensagens_sistema to anon;
grant select on public.catalogo_status_ui to anon;
grant select on public.configuracao_localizacao to anon;

-- Funções públicas de apresentação/normalização que não acessam dados do tenant.
revoke execute on all functions in schema public from anon;
grant execute on function public.obter_mensagem_sistema(text) to anon;
grant execute on function public.normalizar_erro_backend(text,text) to anon;
grant execute on function public.formatar_data_br(date) to anon;
grant execute on function public.formatar_data_hora_br(timestamptz) to anon;
grant execute on function public.formatar_hora_br(timestamptz) to anon;
grant execute on function public.agora_brasilia() to anon;

comment on schema public is 'Schema público do ContaOS. A role anon possui somente leitura dos catálogos de interface/localização e funções de formatação sem acesso a dados de organizações.';

commit;