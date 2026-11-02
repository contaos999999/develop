-- ContaOS 4.1 — PROMPT 26 / V1-05
-- Data API INSERT sem .select()/RETURNING. Dados sintéticos; ROLLBACK integral.

begin;

create temporary table v105_testes(teste text primary key, passou boolean not null, detalhe text) on commit drop;
grant select, insert on v105_testes to authenticated;

create or replace function pg_temp.v105_try(
  p_id uuid, p_org uuid, p_contratante uuid, p_numero text, p_objeto text,
  p_inicio date default null, p_fim date default null
) returns text
language plpgsql security invoker set search_path=''
as $$
begin
  insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio,fim)
  values(p_id,p_org,p_contratante,p_numero,p_objeto,p_inicio,p_fim);
  return 'OK';
exception when others then
  return sqlstate||':'||sqlerrm;
end $$;
grant execute on function pg_temp.v105_try(uuid,uuid,uuid,text,text,date,date) to authenticated;

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('b7050505-1111-4111-8111-111111111111','authenticated','authenticated','v105.restrito@invalid',now(),now()),
('b7050505-2222-4222-8222-222222222222','authenticated','authenticated','v105.total@invalid',now(),now()),
('b7050505-3333-4333-8333-333333333333','authenticated','authenticated','v105.leitor@invalid',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag) values
('b7050505-1111-4111-8111-aaaaaaaaaaaa','b7050505-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour','v105-r'),
('b7050505-2222-4222-8222-bbbbbbbbbbbb','b7050505-2222-4222-8222-222222222222',now(),now(),'aal1',now()+interval '1 hour','v105-t'),
('b7050505-3333-4333-8333-cccccccccccc','b7050505-3333-4333-8333-333333333333',now(),now(),'aal1',now()+interval '1 hour','v105-l');
insert into public.organizacoes(id,razao_social) values
('b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Org V105 A'),
('b7050505-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Org V105 B');
insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo) values
('b7050505-1000-4000-8000-000000000001','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-1111-4111-8111-111111111111','gestor_contrato',false,true),
('b7050505-1000-4000-8000-000000000002','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2222-4222-8222-222222222222','administrador',true,true),
('b7050505-1000-4000-8000-000000000003','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-3333-4333-8333-333333333333','leitor',true,true);
insert into public.contratantes(id,id_organizacao,razao_social) values
('b7050505-2000-4000-8000-000000000001','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante A'),
('b7050505-2000-4000-8000-000000000002','b7050505-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Contratante B');

insert into v105_testes values(
 '01 trigger privado',
 to_regprocedure('privado.pos_processar_contrato_criado_v105()') is not null
 and exists(select 1 from pg_trigger where tgname='contaos_contrato_pos_insert_v105' and not tgisinternal)
 and not has_function_privilege('authenticated','privado.pos_processar_contrato_criado_v105()','EXECUTE')
 and not has_function_privilege('anon','privado.pos_processar_contrato_criado_v105()','EXECUTE'), null);

set local role authenticated;
select set_config('request.jwt.claim.sub','b7050505-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"b7050505-1111-4111-8111-111111111111","role":"authenticated","session_id":"b7050505-1111-4111-8111-aaaaaaaaaaaa","aal":"aal1"}',true);
insert into v105_testes select '02 restrito cria',r='OK',r from (select pg_temp.v105_try(
 'b7050505-3000-4000-8000-000000000001','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'b7050505-2000-4000-8000-000000000001','V105-001','Contrato restrito','2026-01-01','2026-12-31') r)x;
insert into v105_testes select '03 escopo + acesso',
 exists(select 1 from public.vinculos_usuario_contratos where id_vinculo_usuario='b7050505-1000-4000-8000-000000000001' and id_contrato='b7050505-3000-4000-8000-000000000001' and ativo and revogado_em is null)
 and privado.usuario_tem_acesso_contrato('b7050505-3000-4000-8000-000000000001'), null;
insert into v105_testes select '04 auditoria única',
 count(*)=1 and bool_and(depois->>'numero'='V105-001') and bool_and(depois->>'situacao'='rascunho')
 and bool_and(depois->>'criticidade'='media') and bool_and(metadados->>'origem_operacao'='v105.data_api_insert'),
 jsonb_agg(jsonb_build_object('depois',depois,'meta',metadados))::text
 from public.eventos_auditoria where evento='ContratoCriado' and entidade='contratos'
 and id_entidade='b7050505-3000-4000-8000-000000000001';
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b7050505-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"b7050505-2222-4222-8222-222222222222","role":"authenticated","session_id":"b7050505-2222-4222-8222-bbbbbbbbbbbb","aal":"aal1"}',true);
insert into v105_testes select '05 total sem vínculo redundante',r='OK'
 and not exists(select 1 from public.vinculos_usuario_contratos where id_vinculo_usuario='b7050505-1000-4000-8000-000000000002' and id_contrato='b7050505-3000-4000-8000-000000000002')
 and privado.usuario_tem_acesso_contrato('b7050505-3000-4000-8000-000000000002'),r
 from (select pg_temp.v105_try('b7050505-3000-4000-8000-000000000002','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000001','V105-002','Contrato total') r)x;
insert into v105_testes select '06 duplicado 23505',left(r,5)='23505',r from (select pg_temp.v105_try('b7050505-3000-4000-8000-000000000003','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000001','V105-002','Duplicado') r)x;
insert into v105_testes select '07 vigência 23514',left(r,5)='23514',r from (select pg_temp.v105_try('b7050505-3000-4000-8000-000000000004','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000001','V105-004','Vigência','2026-12-31','2026-01-01') r)x;
insert into v105_testes select '08 FK cruzada 23503',left(r,5)='23503',r from (select pg_temp.v105_try('b7050505-3000-4000-8000-000000000005','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000002','V105-005','Cruzado') r)x;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b7050505-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claims','{"sub":"b7050505-3333-4333-8333-333333333333","role":"authenticated","session_id":"b7050505-3333-4333-8333-cccccccccccc","aal":"aal1"}',true);
insert into v105_testes select '09 leitor 42501',left(r,5)='42501',r from (select pg_temp.v105_try('b7050505-3000-4000-8000-000000000006','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000001','V105-006','Leitor') r)x;
reset role;

select jsonb_build_object(
 'passou',count(*) filter(where passou),
 'falhou',count(*) filter(where not passou),
 'total',count(*),
 'itens',jsonb_agg(jsonb_build_object('teste',teste,'passou',passou,'detalhe',detalhe) order by teste)
) as resultado from v105_testes;

rollback;
