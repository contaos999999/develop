-- ContaOS HML 4.1 - regressão de conclusão indevida de tarefa de alerta
-- Dados sintéticos; termina em ROLLBACK.

begin;

create temporary table alerta_testes(teste text primary key, passou boolean not null, detalhe text) on commit drop;
grant select,insert on alerta_testes to authenticated;

create or replace function pg_temp.tentar_concluir_tarefa_direto()
returns text language plpgsql security invoker set search_path='' as $$
begin
  update public.tarefas_alerta
     set status='concluida', versao_registro=versao_registro+1
   where id='ffffffff-5000-4000-8000-000000000001';
  return 'SEM_ERRO';
exception when others then return sqlstate||':'||sqlerrm; end; $$;
grant execute on function pg_temp.tentar_concluir_tarefa_direto() to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('ffffffff-1111-4111-8111-111111111111','authenticated','authenticated','alerta.regressao@contaos.invalid','{}','{"nome":"Alerta Regressão"}',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('ffffffff-1111-4111-8111-222222222222','ffffffff-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour');
insert into public.organizacoes(id,razao_social,nome_fantasia)
values('ffffffff-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização Alerta Regressão','Alerta Regressão');
insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
values('ffffffff-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-1111-4111-8111-111111111111','administrador',true);
insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia)
values('ffffffff-0000-4000-8000-000000000001','ffffffff-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante Alerta','Contratante Alerta');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,situacao)
values('ffffffff-1000-4000-8000-000000000001','ffffffff-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-0000-4000-8000-000000000001','AL-001','Contrato alerta','ativo');
insert into public.alertas_preventivos(id,id_organizacao,id_contrato,regra,severidade,status,descricao)
values('ffffffff-4000-4000-8000-000000000001','ffffffff-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-1000-4000-8000-000000000001','regra_teste','media','em_tratamento','Alerta sintético');
insert into public.tarefas_alerta(id,id_organizacao,id_contrato,id_alerta,descricao,responsavel,status)
values('ffffffff-5000-4000-8000-000000000001','ffffffff-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-1000-4000-8000-000000000001','ffffffff-4000-4000-8000-000000000001','Tratar alerta sintético','ffffffff-1111-4111-8111-111111111111','pendente');

set local role authenticated;
select set_config('request.jwt.claim.sub','ffffffff-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"ffffffff-1111-4111-8111-111111111111","role":"authenticated","session_id":"ffffffff-1111-4111-8111-222222222222","aal":"aal1"}',true);

insert into alerta_testes
select 'UPDATE direto não conclui tarefa',left(r,5)='42501',r
from (select pg_temp.tentar_concluir_tarefa_direto() r) x;

select public.tratar_alerta_preventivo(
  'ffffffff-4000-4000-8000-000000000001',
  'aceitar_risco',
  'Teste sintético de tratamento',
  null
);

insert into alerta_testes
select 'RPC oficial conclui tarefa',status='concluida',status
from public.tarefas_alerta where id='ffffffff-5000-4000-8000-000000000001';
insert into alerta_testes
select 'RPC oficial resolve alerta',status='resolvido',status
from public.alertas_preventivos where id='ffffffff-4000-4000-8000-000000000001';
insert into alerta_testes
select 'RPC oficial registra tratamento',count(*)=1,'tratamentos='||count(*)
from public.tratamentos_alertas where id_alerta='ffffffff-4000-4000-8000-000000000001';

select teste,passou,detalhe from alerta_testes order by teste;
rollback;
