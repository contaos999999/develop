-- ContaOS 4.1 — Administrador Master global
-- Teste sintético completo com ROLLBACK integral.

begin;

create temporary table admin_master_resultados(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select, insert on admin_master_resultados to authenticated;

create or replace function pg_temp.try_validar_admin(p_org uuid)
returns text language plpgsql security invoker set search_path=''
as $$
begin
  perform public.validar_administrador_organizacao(p_org);
  return 'OK';
exception when others then
  return sqlstate || ':' || sqlerrm;
end $$;
grant execute on function pg_temp.try_validar_admin(uuid) to authenticated;

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('a1111111-1111-4111-8111-111111111111','authenticated','authenticated','master@invalid',now(),now()),
('a2222222-2222-4222-8222-222222222222','authenticated','authenticated','admina@invalid',now(),now()),
('a3333333-3333-4333-8333-333333333333','authenticated','authenticated','comum@invalid',now(),now()),
('a4444444-4444-4444-8444-444444444444','authenticated','authenticated','masterinativo@invalid',now(),now()),
('a5555555-5555-4555-8555-555555555555','authenticated','authenticated','masterexpirado@invalid',now(),now()),
('a6666666-6666-4666-8666-666666666666','authenticated','authenticated','alvo.adm01@invalid',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag) values
('aa111111-1111-4111-8111-111111111111','a1111111-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour','am-master'),
('aa222222-2222-4222-8222-222222222222','a2222222-2222-4222-8222-222222222222',now(),now(),'aal1',now()+interval '1 hour','am-admin'),
('aa333333-3333-4333-8333-333333333333','a3333333-3333-4333-8333-333333333333',now(),now(),'aal1',now()+interval '1 hour','am-comum'),
('aa444444-4444-4444-8444-444444444444','a4444444-4444-4444-8444-444444444444',now(),now(),'aal1',now()+interval '1 hour','am-inativo'),
('aa555555-5555-4555-8555-555555555555','a5555555-5555-4555-8555-555555555555',now(),now(),'aal1',now()+interval '1 hour','am-expirado');

insert into public.organizacoes(id,razao_social) values
('b1111111-1111-4111-8111-111111111111','Org Master A'),
('b2222222-2222-4222-8222-222222222222','Org Master B');

insert into public.contratantes(id,id_organizacao,razao_social) values
('c1111111-1111-4111-8111-111111111111','b1111111-1111-4111-8111-111111111111','Contratante A'),
('c2222222-2222-4222-8222-222222222222','b2222222-2222-4222-8222-222222222222','Contratante B');

insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values
('d1111111-1111-4111-8111-111111111111','b1111111-1111-4111-8111-111111111111','c1111111-1111-4111-8111-111111111111','AM-A','Contrato A','2026-01-01'),
('d2222222-2222-4222-8222-222222222222','b2222222-2222-4222-8222-222222222222','c2222222-2222-4222-8222-222222222222','AM-B','Contrato B','2026-01-01');

insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo) values
('e2222222-2222-4222-8222-222222222222','b1111111-1111-4111-8111-111111111111','a2222222-2222-4222-8222-222222222222','administrador',true,true);

insert into privado.administradores_master(id_usuario,ativo,motivo) values
('a1111111-1111-4111-8111-111111111111',true,'teste master'),
('a4444444-4444-4444-8444-444444444444',false,'teste inativo');
insert into privado.administradores_master(id_usuario,ativo,inicio_em,fim_em,motivo) values
('a5555555-5555-4555-8555-555555555555',true,now()-interval '2 day',now()-interval '1 day','teste expirado');

insert into admin_master_resultados values(
  '01 tabela privada sem DML cliente',
  not has_table_privilege('authenticated','privado.administradores_master','SELECT')
  and not has_table_privilege('authenticated','privado.administradores_master','INSERT')
  and not has_table_privilege('authenticated','privado.administradores_master','UPDATE')
  and not has_table_privilege('authenticated','privado.administradores_master','DELETE')
  and not has_table_privilege('anon','privado.administradores_master','SELECT'), null);

insert into admin_master_resultados values(
  '02 RPC somente authenticated',
  has_function_privilege('authenticated','public.listar_organizacoes_disponiveis()','EXECUTE')
  and not has_function_privilege('anon','public.listar_organizacoes_disponiveis()','EXECUTE'), null);

insert into admin_master_resultados
select '03 concessao Master auditada', count(*)=1, count(*)::text
from public.eventos_auditoria
where evento='AdministradorMasterConcedido'
  and entidade='administradores_master'
  and id_entidade='a1111111-1111-4111-8111-111111111111';

-- Master ativo, sem qualquer vínculo físico.
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"aa111111-1111-4111-8111-111111111111","aal":"aal1"}',true);
set local role authenticated;

insert into admin_master_resultados select '04 Master reconhecido', privado.usuario_e_administrador_master(), null;
insert into admin_master_resultados select '05 Master sem vínculo físico possui acesso ativo', privado.usuario_possui_vinculo_ativo(), null;
insert into admin_master_resultados select '06 Master acessa Org A e B',
  privado.usuario_tem_acesso_organizacao('b1111111-1111-4111-8111-111111111111')
  and privado.usuario_tem_acesso_organizacao('b2222222-2222-4222-8222-222222222222'), null;
insert into admin_master_resultados select '07 Master acessa contratos A e B',
  privado.usuario_tem_acesso_contrato('d1111111-1111-4111-8111-111111111111')
  and privado.usuario_tem_acesso_contrato('d2222222-2222-4222-8222-222222222222'), null;
insert into admin_master_resultados select '08 Master equivale a administrador mas não a aprovador',
  privado.usuario_possui_perfil('b2222222-2222-4222-8222-222222222222',array['administrador'])
  and not privado.usuario_possui_perfil('b2222222-2222-4222-8222-222222222222',array['direcao_aprovador']), null;
insert into admin_master_resultados select '09 RLS Master vê duas organizações', count(*)=2, count(*)::text
from public.organizacoes where id in ('b1111111-1111-4111-8111-111111111111','b2222222-2222-4222-8222-222222222222');
insert into admin_master_resultados select '10 RLS Master vê dois contratos', count(*)=2, count(*)::text
from public.contratos where id in ('d1111111-1111-4111-8111-111111111111','d2222222-2222-4222-8222-222222222222');
insert into admin_master_resultados select '11 RPC Master lista A e B', count(*)=2 and bool_and(perfil='administrador_master'), jsonb_agg(jsonb_build_object('id',id,'perfil',perfil))::text
from public.listar_organizacoes_disponiveis()
where id in ('b1111111-1111-4111-8111-111111111111','b2222222-2222-4222-8222-222222222222');
insert into admin_master_resultados select '12 Master valida ADM-01 em Org B', pg_temp.try_validar_admin('b2222222-2222-4222-8222-222222222222')='OK', pg_temp.try_validar_admin('b2222222-2222-4222-8222-222222222222');

insert into public.contratantes(id,id_organizacao,razao_social)
values('c3333333-3333-4333-8333-333333333333','b2222222-2222-4222-8222-222222222222','Criado pelo Master');
insert into admin_master_resultados select '13 Master escreve via RLS em organização sem vínculo', exists(select 1 from public.contratantes where id='c3333333-3333-4333-8333-333333333333'), null;

select public.salvar_vinculo_usuario_adm(
  'b2222222-2222-4222-8222-222222222222',
  'a6666666-6666-4666-8666-666666666666',
  'alvo.adm01@invalid',
  'leitor', true, true,
  array[]::uuid[], array[]::uuid[], null,
  'admin-master-global-test-001'
);
insert into admin_master_resultados select '14 Master salva vínculo ADM-01 em Org B',
  exists(select 1 from public.vinculos_usuarios where id_organizacao='b2222222-2222-4222-8222-222222222222' and id_usuario='a6666666-6666-4666-8666-666666666666' and perfil='leitor' and ativo), null;
insert into admin_master_resultados select '15 operação ADM-01 do Master auditada',
  exists(select 1 from public.eventos_auditoria where id_organizacao='b2222222-2222-4222-8222-222222222222' and evento='VinculoUsuarioAdministrativoSalvo' and metadados->>'id_usuario'='a6666666-6666-4666-8666-666666666666'), null;
reset role;

-- Administrador comum da Org A permanece limitado.
select set_config('request.jwt.claim.sub','a2222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222222","role":"authenticated","session_id":"aa222222-2222-4222-8222-222222222222","aal":"aal1"}',true);
set local role authenticated;
insert into admin_master_resultados select '16 Admin A não acessa B',
  privado.usuario_tem_acesso_organizacao('b1111111-1111-4111-8111-111111111111')
  and not privado.usuario_tem_acesso_organizacao('b2222222-2222-4222-8222-222222222222')
  and not privado.usuario_tem_acesso_contrato('d2222222-2222-4222-8222-222222222222'), null;
insert into admin_master_resultados select '17 Admin A RPC lista somente A', count(*)=1 and bool_and(id='b1111111-1111-4111-8111-111111111111'), jsonb_agg(id)::text
from public.listar_organizacoes_disponiveis()
where id in ('b1111111-1111-4111-8111-111111111111','b2222222-2222-4222-8222-222222222222');
insert into admin_master_resultados select '18 Admin A ADM-01 B negado', left(pg_temp.try_validar_admin('b2222222-2222-4222-8222-222222222222'),5)='42501', pg_temp.try_validar_admin('b2222222-2222-4222-8222-222222222222');
reset role;

-- Usuário comum sem vínculo permanece sem acesso.
select set_config('request.jwt.claim.sub','a3333333-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claims','{"sub":"a3333333-3333-4333-8333-333333333333","role":"authenticated","session_id":"aa333333-3333-4333-8333-333333333333","aal":"aal1"}',true);
set local role authenticated;
insert into admin_master_resultados select '19 Comum sem vínculo negado',
  not privado.usuario_possui_vinculo_ativo()
  and not privado.usuario_tem_acesso_organizacao('b1111111-1111-4111-8111-111111111111')
  and not privado.usuario_tem_acesso_organizacao('b2222222-2222-4222-8222-222222222222'), null;
insert into admin_master_resultados select '20 Comum RPC vazia', count(*)=0, count(*)::text
from public.listar_organizacoes_disponiveis()
where id in ('b1111111-1111-4111-8111-111111111111','b2222222-2222-4222-8222-222222222222');
reset role;

-- Master inativo.
select set_config('request.jwt.claim.sub','a4444444-4444-4444-8444-444444444444',true);
select set_config('request.jwt.claims','{"sub":"a4444444-4444-4444-8444-444444444444","role":"authenticated","session_id":"aa444444-4444-4444-8444-444444444444","aal":"aal1"}',true);
set local role authenticated;
insert into admin_master_resultados select '21 Master inativo negado', not privado.usuario_e_administrador_master() and not privado.usuario_tem_acesso_organizacao('b1111111-1111-4111-8111-111111111111'), null;
reset role;

-- Master expirado.
select set_config('request.jwt.claim.sub','a5555555-5555-4555-8555-555555555555',true);
select set_config('request.jwt.claims','{"sub":"a5555555-5555-4555-8555-555555555555","role":"authenticated","session_id":"aa555555-5555-4555-8555-555555555555","aal":"aal1"}',true);
set local role authenticated;
insert into admin_master_resultados select '22 Master expirado negado', not privado.usuario_e_administrador_master() and not privado.usuario_tem_acesso_organizacao('b1111111-1111-4111-8111-111111111111'), null;
reset role;

select jsonb_build_object(
  'passou',count(*) filter(where passou),
  'falhou',count(*) filter(where not passou),
  'total',count(*),
  'itens',jsonb_agg(jsonb_build_object('teste',teste,'passou',passou,'detalhe',detalhe) order by teste)
) as resultado
from admin_master_resultados;

rollback;
