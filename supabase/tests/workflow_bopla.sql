-- ContaOS HML 4.1 - regressão de Mass Assignment/BOPLA em workflow
-- Dados 100% sintéticos. A transação termina em ROLLBACK.

begin;

create temporary table workflow_testes(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select,insert on workflow_testes to authenticated;

create or replace function pg_temp.tentar_workflow(p_alvo text)
returns text
language plpgsql
security invoker
set search_path=''
as $$
begin
  if p_alvo='plano' then
    update public.planos_remediacao
       set status='validado', versao_registro=versao_registro+1
     where id='eeeeeeee-4000-4000-8000-000000000001';
  elsif p_alvo='nc' then
    update public.nao_conformidades
       set status='encerrada', versao_registro=versao_registro+1
     where id='eeeeeeee-3000-4000-8000-000000000001';
  elsif p_alvo='controle' then
    update public.controles_conformidade
       set situacao='ativo', versao_registro=versao_registro+1
     where id='eeeeeeee-2000-4000-8000-000000000001';
  elsif p_alvo='usuario' then
    update public.usuarios
       set situacao='inativo', versao_registro=versao_registro+1
     where id_usuario='eeeeeeee-1111-4111-8111-111111111111';
  else
    return 'ALVO_INVALIDO';
  end if;
  return 'SEM_ERRO';
exception when others then
  return sqlstate||':'||sqlerrm;
end;
$$;
grant execute on function pg_temp.tentar_workflow(text) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values(
  'eeeeeeee-1111-4111-8111-111111111111',
  'authenticated','authenticated','workflow.regressao@contaos.invalid',
  '{}','{"nome":"Workflow Regressão"}',now(),now()
);

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values(
  'eeeeeeee-1111-4111-8111-222222222222',
  'eeeeeeee-1111-4111-8111-111111111111',
  now(),now(),'aal1',now()+interval '1 hour'
);

insert into public.organizacoes(id,razao_social,nome_fantasia)
values(
  'eeeeeeee-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Organização Workflow Regressão','Workflow Regressão'
);

insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
values(
  'eeeeeeee-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'eeeeeeee-1111-4111-8111-111111111111',
  'administrador',true
);

insert into public.controles_conformidade(id,id_organizacao,codigo,nome,objetivo,situacao)
values(
  'eeeeeeee-2000-4000-8000-000000000001',
  'eeeeeeee-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'WF-REG-001','Controle Workflow Regressão','Teste automatizado','rascunho'
);

insert into public.nao_conformidades(id,id_organizacao,id_controle,descricao,status,criado_por)
values(
  'eeeeeeee-3000-4000-8000-000000000001',
  'eeeeeeee-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'eeeeeeee-2000-4000-8000-000000000001',
  'NC sintética para regressão','aberta',
  'eeeeeeee-1111-4111-8111-111111111111'
);

insert into public.planos_remediacao(id,id_organizacao,id_nao_conformidade,acoes,responsavel,status,criado_por)
values(
  'eeeeeeee-4000-4000-8000-000000000001',
  'eeeeeeee-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'eeeeeeee-3000-4000-8000-000000000001',
  '[{"acao":"corrigir"}]',
  'eeeeeeee-1111-4111-8111-111111111111',
  'aberto',
  'eeeeeeee-1111-4111-8111-111111111111'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','eeeeeeee-1111-4111-8111-111111111111',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"eeeeeeee-1111-4111-8111-111111111111","role":"authenticated","session_id":"eeeeeeee-1111-4111-8111-222222222222","aal":"aal1"}',
  true
);

insert into workflow_testes
select 'UPDATE direto não valida remediação', left(r,5)='42501', r
from (select pg_temp.tentar_workflow('plano') r) x;

insert into workflow_testes
select 'UPDATE direto não encerra não conformidade', left(r,5)='42501', r
from (select pg_temp.tentar_workflow('nc') r) x;

insert into workflow_testes
select 'UPDATE direto não ativa controle', left(r,5)='42501', r
from (select pg_temp.tentar_workflow('controle') r) x;

insert into workflow_testes
select 'Usuário não altera a própria situação', left(r,5)='42501', r
from (select pg_temp.tentar_workflow('usuario') r) x;

select public.concluir_plano_remediacao(
  'eeeeeeee-4000-4000-8000-000000000001',
  '[{"tipo":"teste","descricao":"evidência sintética"}]'::jsonb
);
insert into workflow_testes
select 'RPC oficial conclui remediação', status='concluido', status
from public.planos_remediacao
where id='eeeeeeee-4000-4000-8000-000000000001';

select public.validar_remediacao(
  'eeeeeeee-4000-4000-8000-000000000001',
  true,
  'Validação sintética de segurança'
);
insert into workflow_testes
select 'RPC oficial valida remediação', status='validado', status
from public.planos_remediacao
where id='eeeeeeee-4000-4000-8000-000000000001';

insert into workflow_testes
select 'Validação oficial resolve não conformidade', status='resolvida', status
from public.nao_conformidades
where id='eeeeeeee-3000-4000-8000-000000000001';

select public.encerrar_nao_conformidade(
  'eeeeeeee-3000-4000-8000-000000000001',
  'Encerramento sintético de segurança'
);
insert into workflow_testes
select 'RPC oficial encerra não conformidade', status='encerrada', status
from public.nao_conformidades
where id='eeeeeeee-3000-4000-8000-000000000001';

select public.publicar_controle(
  'eeeeeeee-2000-4000-8000-000000000001',
  'Texto sintético do controle',
  '[]'::jsonb,
  current_date,
  null
);
insert into workflow_testes
select 'RPC oficial publica e versiona controle', situacao='ativo' and versao_atual=1, situacao||':'||versao_atual::text
from public.controles_conformidade
where id='eeeeeeee-2000-4000-8000-000000000001';

select teste,passou,detalhe from workflow_testes order by teste;
rollback;
