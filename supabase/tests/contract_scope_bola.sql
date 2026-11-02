-- ContaOS HML 4.1 - regressão de BOLA horizontal entre contratos
-- Um gestor restrito ao Contrato A não pode operar objeto do Contrato B,
-- mesmo quando a operação passa por função SECURITY DEFINER.
-- Dados sintéticos; transação termina em ROLLBACK.

begin;

create temporary table bola_testes(teste text primary key, passou boolean not null, detalhe text) on commit drop;
grant select,insert on bola_testes to authenticated;

create or replace function pg_temp.tentar_aprovar_parecer(p_id uuid)
returns text language plpgsql security invoker set search_path='' as $$
begin
  perform public.aprovar_parecer_interno(p_id,true,'Regressão BOLA contratual');
  return 'SEM_ERRO';
exception when others then return sqlstate||':'||sqlerrm; end; $$;
grant execute on function pg_temp.tentar_aprovar_parecer(uuid) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('b1b1b1b1-1111-4111-8111-111111111111','authenticated','authenticated','bola.regressao@contaos.invalid','{}','{"nome":"Gestor A"}',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('b1b1b1b1-1111-4111-8111-222222222222','b1b1b1b1-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour');
insert into public.organizacoes(id,razao_social,nome_fantasia)
values('b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização BOLA Regressão','BOLA Regressão');
insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
values('b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b1b1b1b1-1111-4111-8111-111111111111','gestor_contrato',false,true);
insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia)
values('b1b1b1b1-0000-4000-8000-000000000001','b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante BOLA','Contratante BOLA');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio,situacao)
values
('b1b1b1b1-1000-4000-8000-000000000001','b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b1b1b1b1-0000-4000-8000-000000000001','A','Contrato permitido','2026-01-01','ativo'),
('b1b1b1b1-1000-4000-8000-000000000002','b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b1b1b1b1-0000-4000-8000-000000000001','B','Contrato proibido','2026-01-01','ativo');
insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo)
select 'b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',vu.id,'b1b1b1b1-1000-4000-8000-000000000001',true
from public.vinculos_usuarios vu
where vu.id_organizacao='b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and vu.id_usuario='b1b1b1b1-1111-4111-8111-111111111111';
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao)
values
('b1b1b1b1-2000-4000-8000-000000000001','b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b1b1b1b1-1000-4000-8000-000000000001','2026-10-01','2026-10-01','2026-10-31','em_analise'),
('b1b1b1b1-2000-4000-8000-000000000002','b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b1b1b1b1-1000-4000-8000-000000000002','2026-11-01','2026-11-01','2026-11-30','em_analise');
insert into public.pareceres_internos(id,id_organizacao,id_contrato,id_competencia,versao,texto,status,hash)
values
('b1b1b1b1-5000-4000-8000-000000000001','b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b1b1b1b1-1000-4000-8000-000000000001','b1b1b1b1-2000-4000-8000-000000000001',1,'Parecer A','rascunho',md5('parecer-a')),
('b1b1b1b1-5000-4000-8000-000000000002','b1b1b1b1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b1b1b1b1-1000-4000-8000-000000000002','b1b1b1b1-2000-4000-8000-000000000002',1,'Parecer B','rascunho',md5('parecer-b'));

set local role authenticated;
select set_config('request.jwt.claim.sub','b1b1b1b1-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"b1b1b1b1-1111-4111-8111-111111111111","role":"authenticated","session_id":"b1b1b1b1-1111-4111-8111-222222222222","aal":"aal1"}',true);

insert into bola_testes
select 'Acesso ao Contrato A existe',privado.usuario_tem_acesso_contrato('b1b1b1b1-1000-4000-8000-000000000001'),null;
insert into bola_testes
select 'Acesso ao Contrato B não existe',not privado.usuario_tem_acesso_contrato('b1b1b1b1-1000-4000-8000-000000000002'),null;

insert into bola_testes
select 'RPC no Contrato A continua permitida',r='SEM_ERRO',r
from (select pg_temp.tentar_aprovar_parecer('b1b1b1b1-5000-4000-8000-000000000001') r) x;

insert into bola_testes
select 'RPC no Contrato B é bloqueada',left(r,5)='42501',r
from (select pg_temp.tentar_aprovar_parecer('b1b1b1b1-5000-4000-8000-000000000002') r) x;

reset role;
insert into bola_testes
select 'Parecer A foi aprovado',status='aprovado',status
from public.pareceres_internos where id='b1b1b1b1-5000-4000-8000-000000000001';
insert into bola_testes
select 'Parecer B permaneceu inalterado',status='rascunho',status
from public.pareceres_internos where id='b1b1b1b1-5000-4000-8000-000000000002';

insert into bola_testes
with tabelas as (
  select c.table_schema,c.table_name
  from information_schema.columns c
  join information_schema.tables t on t.table_schema=c.table_schema and t.table_name=c.table_name
  where c.table_schema='public' and c.column_name='id_contrato' and c.data_type='uuid' and t.table_type='BASE TABLE'
), gatilhos as (
  select n.nspname table_schema,c.relname table_name
  from pg_trigger tg join pg_class c on c.oid=tg.tgrelid join pg_namespace n on n.oid=c.relnamespace
  where not tg.tgisinternal and tg.tgname='trg_scope_contrato'
    and tg.tgfoid='privado.bloquear_mutacao_fora_escopo_contrato()'::regprocedure
)
select 'Todas as tabelas contratuais possuem barreira',count(*)=0,'faltantes='||count(*)
from tabelas t left join gatilhos g using(table_schema,table_name)
where g.table_name is null;

select teste,passou,detalhe from bola_testes order by teste;
rollback;
