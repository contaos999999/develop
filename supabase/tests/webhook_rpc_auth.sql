-- ContaOS HML 4.1 - regressão de autorização da RPC de webhook
-- Dados sintéticos; a transação termina em ROLLBACK.

begin;

create temporary table webhook_auth_test(
  chave text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select,insert on webhook_auth_test to authenticated, service_role;

create or replace function pg_temp.tentar_evento(p_webhook uuid)
returns text
language plpgsql
security invoker
set search_path=''
as $$
begin
  perform public.enfileirar_evento_webhook(
    p_webhook,
    'teste.seguranca',
    'teste',
    gen_random_uuid(),
    jsonb_build_object('teste',true)
  );
  return 'SEM_ERRO';
exception when others then
  return sqlstate||':'||sqlerrm;
end;
$$;
grant execute on function pg_temp.tentar_evento(uuid) to authenticated, service_role;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('74111111-1111-4111-8111-111111111111','authenticated','authenticated','admin.webhook@contaos.invalid','{}','{}',now(),now()),
('74222222-2222-4222-8222-222222222222','authenticated','authenticated','leitor.webhook@contaos.invalid','{}','{}',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values
('74aaaaaa-1111-4111-8111-111111111111','74111111-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour'),
('74bbbbbb-2222-4222-8222-222222222222','74222222-2222-4222-8222-222222222222',now(),now(),'aal1',now()+interval '1 hour');

insert into public.organizacoes(id,razao_social,nome_fantasia)
values('74aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização Teste Webhook','Teste Webhook');

insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
values
('74aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','74111111-1111-4111-8111-111111111111','administrador',true),
('74aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','74222222-2222-4222-8222-222222222222','leitor',true);

insert into public.webhooks(id,id_organizacao,nome,url,eventos,secret_hash,criado_por)
values(
  '74cccccc-cccc-4ccc-8ccc-cccccccccccc',
  '74aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Webhook teste',
  'https://example.invalid/hook',
  array['teste.seguranca'],
  repeat('a',64),
  '74111111-1111-4111-8111-111111111111'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','74111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"74111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"74aaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',
  true
);
insert into webhook_auth_test
select 'admin_valido', r='SEM_ERRO', r
from (select pg_temp.tentar_evento('74cccccc-cccc-4ccc-8ccc-cccccccccccc') r) x;

select set_config('request.jwt.claim.sub','74222222-2222-4222-8222-222222222222',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"74222222-2222-4222-8222-222222222222","role":"authenticated","session_id":"74bbbbbb-2222-4222-8222-222222222222","aal":"aal1"}',
  true
);
insert into webhook_auth_test
select 'leitor_bloqueado', r like '42501:%', r
from (select pg_temp.tentar_evento('74cccccc-cccc-4ccc-8ccc-cccccccccccc') r) x;

reset request.jwt.claim.sub;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims','{"role":"authenticated"}',true);
insert into webhook_auth_test
select 'sem_usuario_bloqueado', r like '42501:%', r
from (select pg_temp.tentar_evento('74cccccc-cccc-4ccc-8ccc-cccccccccccc') r) x;

reset role;
set local role service_role;
reset request.jwt.claim.sub;
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into webhook_auth_test
select 'service_role_permitido', r='SEM_ERRO', r
from (select pg_temp.tentar_evento('74cccccc-cccc-4ccc-8ccc-cccccccccccc') r) x;

reset role;
select chave,passou,detalhe from webhook_auth_test order by chave;
rollback;
