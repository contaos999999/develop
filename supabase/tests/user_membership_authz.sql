-- ContaOS HML 4.1 - regressão de autorização em vínculos de usuário
-- Dados sintéticos; transação termina em ROLLBACK.

begin;

create temporary table authz_testes(teste text primary key, passou boolean not null, detalhe text) on commit drop;
grant select,insert on authz_testes to authenticated;

create or replace function pg_temp.tentar_insert_vinculo()
returns text language plpgsql security invoker set search_path='' as $$
begin
  insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
  values('abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abababab-2222-4222-8222-222222222222','leitor',false,true);
  return 'SEM_ERRO';
exception when others then return sqlstate||':'||sqlerrm; end; $$;

create or replace function pg_temp.tentar_update_vinculo()
returns text language plpgsql security invoker set search_path='' as $$
begin
  update public.vinculos_usuarios
     set perfil='administrador', escopo_todos_contratos=true, ativo=true, versao_registro=versao_registro+1
   where id_organizacao='abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
     and id_usuario='abababab-2222-4222-8222-222222222222';
  return 'SEM_ERRO';
exception when others then return sqlstate||':'||sqlerrm; end; $$;

grant execute on function pg_temp.tentar_insert_vinculo() to authenticated;
grant execute on function pg_temp.tentar_update_vinculo() to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('abababab-1111-4111-8111-111111111111','authenticated','authenticated','authz.admin@contaos.invalid','{}','{"nome":"Admin AuthZ"}',now(),now()),
('abababab-2222-4222-8222-222222222222','authenticated','authenticated','authz.alvo@contaos.invalid','{}','{"nome":"Alvo AuthZ"}',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('abababab-1111-4111-8111-333333333333','abababab-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour');

insert into public.organizacoes(id,razao_social,nome_fantasia)
values('abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização AuthZ Regressão','AuthZ Regressão');

insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
values('abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abababab-1111-4111-8111-111111111111','administrador',true,true);

set local role authenticated;
select set_config('request.jwt.claim.sub','abababab-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"abababab-1111-4111-8111-111111111111","role":"authenticated","session_id":"abababab-1111-4111-8111-333333333333","aal":"aal1"}',true);

insert into authz_testes
select 'INSERT direto de vínculo é negado',r<>'SEM_ERRO',r
from (select pg_temp.tentar_insert_vinculo() r) x;

select public.definir_vinculo_usuario(
  'abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'abababab-2222-4222-8222-222222222222',
  'leitor',false,true
);

insert into authz_testes
select 'RPC cria vínculo válido',perfil='leitor' and ativo and not escopo_todos_contratos,perfil||':'||ativo::text||':'||escopo_todos_contratos::text
from public.vinculos_usuarios
where id_organizacao='abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and id_usuario='abababab-2222-4222-8222-222222222222';

insert into authz_testes
select 'UPDATE direto de privilégio é negado',r<>'SEM_ERRO',r
from (select pg_temp.tentar_update_vinculo() r) x;

select public.definir_vinculo_usuario(
  'abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'abababab-2222-4222-8222-222222222222',
  'auditor',true,true
);

insert into authz_testes
select 'RPC altera perfil e escopo',perfil='auditor' and ativo and escopo_todos_contratos,perfil||':'||ativo::text||':'||escopo_todos_contratos::text
from public.vinculos_usuarios
where id_organizacao='abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and id_usuario='abababab-2222-4222-8222-222222222222';

reset role;
insert into authz_testes
select 'RPC registra auditoria',count(*)=2,'eventos='||count(*)
from public.eventos_auditoria
where id_organizacao='abababab-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and evento='VinculoUsuarioDefinido'
  and entidade='vinculos_usuarios';

select teste,passou,detalhe from authz_testes order by teste;
rollback;
