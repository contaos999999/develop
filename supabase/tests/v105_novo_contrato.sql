-- ContaOS 4.1 — PROMPT 26 / V1-05
-- Criação de contrato por Data API + RLS, campos PRD, escopo e auditoria.
-- Dados sintéticos; ROLLBACK integral.

begin;

create temporary table v105_testes(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select, insert on v105_testes to authenticated;

create or replace function pg_temp.v105_try(
  p_id uuid,
  p_org uuid,
  p_contratante uuid,
  p_numero text,
  p_objeto text,
  p_inicio date,
  p_fim date default null,
  p_unidade text default null,
  p_fonte text default null,
  p_valor numeric default null,
  p_valor_mensal numeric default null,
  p_periodicidade text default 'mensal',
  p_prazo integer default null,
  p_dia smallint default null,
  p_conta text default null
) returns text
language plpgsql security invoker set search_path=''
as $$
begin
  insert into public.contratos(
    id,id_organizacao,id_contratante,numero,objeto,inicio,fim,
    unidade_vinculada,fonte_recurso,valor_global,valor_mensal_referencia,
    periodicidade,prazo_prestacao_dias,dia_limite_apresentacao,
    conta_bancaria_vinculada
  ) values(
    p_id,p_org,p_contratante,p_numero,p_objeto,p_inicio,p_fim,
    p_unidade,p_fonte,p_valor,p_valor_mensal,p_periodicidade,p_prazo,p_dia,p_conta
  );
  return 'OK';
exception when others then
  return sqlstate||':'||sqlerrm;
end $$;
grant execute on function pg_temp.v105_try(uuid,uuid,uuid,text,text,date,date,text,text,numeric,numeric,text,integer,smallint,text) to authenticated;

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
 '01 schema PRD',
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='contratos' and column_name='unidade_vinculada')
 and exists(select 1 from information_schema.columns where table_schema='public' and table_name='contratos' and column_name='fonte_recurso')
 and exists(select 1 from information_schema.columns where table_schema='public' and table_name='contratos' and column_name='valor_mensal_referencia')
 and exists(select 1 from information_schema.columns where table_schema='public' and table_name='contratos' and column_name='dia_limite_apresentacao')
 and exists(select 1 from information_schema.columns where table_schema='public' and table_name='contratos' and column_name='conta_bancaria_vinculada')
 and exists(select 1 from information_schema.columns where table_schema='public' and table_name='contratos' and column_name='inicio' and is_nullable='NO')
 and exists(select 1 from information_schema.columns where table_schema='public' and table_name='contratos' and column_name='periodicidade' and is_nullable='NO'), null);

insert into v105_testes values(
 '02 trigger privado',
 to_regprocedure('privado.pos_processar_contrato_criado_v105()') is not null
 and exists(select 1 from pg_trigger where tgname='contaos_contrato_pos_insert_v105' and not tgisinternal)
 and not has_function_privilege('authenticated','privado.pos_processar_contrato_criado_v105()','EXECUTE')
 and not has_function_privilege('anon','privado.pos_processar_contrato_criado_v105()','EXECUTE'), null);
insert into v105_testes values(
 '03 cliente sem INSERT escopo',
 not has_table_privilege('authenticated','public.vinculos_usuario_contratos','INSERT'), null);

-- Gestor restrito cria contrato completo por INSERT sem RETURNING.
select set_config('request.jwt.claim.sub','b7050505-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"b7050505-1111-4111-8111-111111111111","role":"authenticated","session_id":"b7050505-1111-4111-8111-aaaaaaaaaaaa","aal":"aal1"}',true);
set local role authenticated;
insert into v105_testes select '04 restrito cria completo',r='OK',r from (select pg_temp.v105_try(
 'b7050505-3000-4000-8000-000000000001','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'b7050505-2000-4000-8000-000000000001','V105-001','Contrato completo','2026-01-01','2026-12-31',
 'UPA Feira','Tesouro Estadual',1200000.00,100000.00,'mensal',20,10,'Conta vinculada 001') r)x;
reset role;

insert into v105_testes select '05 campos e defaults persistidos',
 unidade_vinculada='UPA Feira'
 and fonte_recurso='Tesouro Estadual'
 and valor_global=1200000.00
 and valor_mensal_referencia=100000.00
 and periodicidade='mensal'
 and prazo_prestacao_dias=20
 and dia_limite_apresentacao=10
 and conta_bancaria_vinculada='Conta vinculada 001'
 and situacao='rascunho' and criticidade='media' and versao_registro=1,
 to_jsonb(c)::text
from public.contratos c where id='b7050505-3000-4000-8000-000000000001';

insert into v105_testes select '06 restrito escopo + acesso',
 exists(select 1 from public.vinculos_usuario_contratos
   where id_vinculo_usuario='b7050505-1000-4000-8000-000000000001'
     and id_contrato='b7050505-3000-4000-8000-000000000001'
     and ativo and revogado_em is null)
 and privado.usuario_tem_acesso_contrato('b7050505-3000-4000-8000-000000000001'), null;

insert into v105_testes select '07 auditoria completa única',
 count(*)=1
 and bool_and(depois->>'numero'='V105-001')
 and bool_and(depois->>'unidade_vinculada'='UPA Feira')
 and bool_and(depois->>'fonte_recurso'='Tesouro Estadual')
 and bool_and((depois->>'valor_mensal_referencia')::numeric=100000.00)
 and bool_and((depois->>'dia_limite_apresentacao')::int=10)
 and bool_and(depois->>'conta_bancaria_vinculada'='Conta vinculada 001')
 and bool_and(depois->>'situacao'='rascunho')
 and bool_and(depois->>'criticidade'='media')
 and bool_and(metadados->>'origem_operacao'='v105.data_api_insert'),
 jsonb_agg(jsonb_build_object('depois',depois,'meta',metadados))::text
from public.eventos_auditoria
where evento='ContratoCriado' and entidade='contratos'
  and id_entidade='b7050505-3000-4000-8000-000000000001';

-- Administrador total não recebe vínculo redundante.
select set_config('request.jwt.claim.sub','b7050505-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"b7050505-2222-4222-8222-222222222222","role":"authenticated","session_id":"b7050505-2222-4222-8222-bbbbbbbbbbbb","aal":"aal1"}',true);
set local role authenticated;
insert into v105_testes select '08 total cria',r='OK',r from (select pg_temp.v105_try(
 'b7050505-3000-4000-8000-000000000002','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'b7050505-2000-4000-8000-000000000001','V105-002','Contrato total','2026-01-01') r)x;
insert into v105_testes select '10 duplicado 23505',left(r,5)='23505',r from (select pg_temp.v105_try(
 'b7050505-3000-4000-8000-000000000003','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'b7050505-2000-4000-8000-000000000001','V105-002','Duplicado','2026-01-01') r)x;
insert into v105_testes select '11 vigência 23514',left(r,5)='23514',r from (select pg_temp.v105_try(
 'b7050505-3000-4000-8000-000000000004','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'b7050505-2000-4000-8000-000000000001','V105-004','Vigência','2026-12-31','2026-01-01') r)x;
insert into v105_testes select '12 FK cruzada 23503',left(r,5)='23503',r from (select pg_temp.v105_try(
 'b7050505-3000-4000-8000-000000000005','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'b7050505-2000-4000-8000-000000000002','V105-005','Cruzado','2026-01-01') r)x;
insert into v105_testes select '13 valores inválidos 23514',
 left(r1,5)='23514' and left(r2,5)='23514' and left(r3,5)='23514' and left(r4,5)='23514',
 jsonb_build_object('valor',r1,'prazo',r2,'dia',r3,'periodicidade',r4)::text
from (select
 pg_temp.v105_try('b7050505-3000-4000-8000-000000000007','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000001','V105-007','Valor negativo','2026-01-01',null,null,null,-1,null,'mensal',null,null,null) r1,
 pg_temp.v105_try('b7050505-3000-4000-8000-000000000008','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000001','V105-008','Prazo zero','2026-01-01',null,null,null,null,null,'mensal',0,null,null) r2,
 pg_temp.v105_try('b7050505-3000-4000-8000-000000000009','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000001','V105-009','Dia 32','2026-01-01',null,null,null,null,null,'mensal',null,32,null) r3,
 pg_temp.v105_try('b7050505-3000-4000-8000-000000000010','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7050505-2000-4000-8000-000000000001','V105-010','Periodicidade vazia','2026-01-01',null,null,null,null,null,' ',null,null,null) r4) x;
reset role;
insert into v105_testes select '09 total sem vínculo redundante + acesso',
 not exists(select 1 from public.vinculos_usuario_contratos
   where id_vinculo_usuario='b7050505-1000-4000-8000-000000000002'
     and id_contrato='b7050505-3000-4000-8000-000000000002')
 and privado.usuario_tem_acesso_contrato('b7050505-3000-4000-8000-000000000002'), null;

-- Leitor permanece bloqueado pela RLS.
select set_config('request.jwt.claim.sub','b7050505-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claims','{"sub":"b7050505-3333-4333-8333-333333333333","role":"authenticated","session_id":"b7050505-3333-4333-8333-cccccccccccc","aal":"aal1"}',true);
set local role authenticated;
insert into v105_testes select '14 leitor 42501',left(r,5)='42501',r from (select pg_temp.v105_try(
 'b7050505-3000-4000-8000-000000000011','b7050505-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'b7050505-2000-4000-8000-000000000001','V105-011','Leitor','2026-01-01') r)x;
reset role;

select jsonb_build_object(
 'passou',count(*) filter(where passou),
 'falhou',count(*) filter(where not passou),
 'total',count(*),
 'itens',jsonb_agg(jsonb_build_object('teste',teste,'passou',passou,'detalhe',detalhe) order by teste)
) as resultado from v105_testes;

rollback;
