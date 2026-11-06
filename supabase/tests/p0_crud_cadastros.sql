-- Isolated restore test only. Simulated SQL claims are not real JWT evidence.
begin;
create function pg_temp.assert_true(v boolean, label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'RBAC FAIL: %',label; end if; end $$;
create function pg_temp.expect_error(q text, expected text) returns void language plpgsql security invoker as $$
begin
  begin execute q; exception when others then
    if sqlstate=expected then return; end if;
    raise exception 'Expected %, got %: %',expected,sqlstate,sqlerrm;
  end;
  raise exception 'Expected denial %, command succeeded',expected;
end $$;
create function pg_temp.actor(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub',('baca0000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub','baca0000-0000-4000-8000-'||lpad(n::text,12,'0'),'role','authenticated','session_id','baca0000-0000-4000-9000-'||lpad(n::text,12,'0'),'user_metadata',jsonb_build_object('master',true))::text,true);
end $$;
insert into auth.users(id,aud,role,email,created_at,updated_at)
select ('baca0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated','rbac-isolated-'||n||'@example.invalid',now(),now() from generate_series(1,12)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select ('baca0000-0000-4000-9000-'||lpad(n::text,12,'0'))::uuid,('baca0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour' from generate_series(1,12)n;
insert into public.organizacoes(id,razao_social) values('baca0000-aaaa-4000-8000-000000000001','RBAC isolated A'),('baca0000-bbbb-4000-8000-000000000001','RBAC isolated B');
insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
select 'baca0000-aaaa-4000-8000-000000000001',('baca0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,p,true
from unnest(array['administrador','auditor','contabilidade','direcao_aprovador','financeiro','gestor_contrato','juridico_conformidade','leitor','prestacao_contas','rh_dp']) with ordinality t(p,n);
insert into privado.administradores_master(id_usuario,motivo) values('baca0000-0000-4000-8000-000000000011','RBAC isolated fixture');
insert into public.contratantes(id,id_organizacao,razao_social) values('baca0000-1000-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','RBAC contractor A');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio)
values('baca0000-2000-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-1000-4000-8000-000000000001','RBAC-A1','Isolated','2026-01-01');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio)
values('baca0000-2000-4000-8000-000000000002','baca0000-aaaa-4000-8000-000000000001','baca0000-1000-4000-8000-000000000001','RBAC-A2','Restricted','2026-01-01');
update public.vinculos_usuarios set escopo_todos_contratos=false where id_usuario='baca0000-0000-4000-8000-000000000006';
insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo)
select id_organizacao,id,'baca0000-2000-4000-8000-000000000001',true from public.vinculos_usuarios where id_usuario='baca0000-0000-4000-8000-000000000006';

set local role authenticated;
select pg_temp.actor(1);
select pg_temp.assert_true((public.obter_cadastro_operacional_v1('baca0000-aaaa-4000-8000-000000000001','organizacoes','baca0000-aaaa-4000-8000-000000000001')->>'pode_editar')::boolean,'admin organization edit');
create temp table crud_responses (r jsonb) on commit drop;
insert into crud_responses select public.atualizar_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',1,'{"nome_fantasia":"CRUD isolated updated"}','Teste de edição isolada','baca0000-4000-4000-8000-000000000001');
select pg_temp.assert_true((select (r->'registro'->>'versao_registro')::bigint=2 from crud_responses),'exactly one version increment organization');
select pg_temp.assert_true((select r from crud_responses)=public.atualizar_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',1,'{"nome_fantasia":"CRUD isolated updated"}','Teste de edição isolada','baca0000-4000-4000-8000-000000000001'),'exact replay despite old version');
select pg_temp.expect_error($q$select public.atualizar_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',1,'{"nome_fantasia":"Different"}','Teste de edição isolada','baca0000-4000-4000-8000-000000000001')$q$,'PT409');
select pg_temp.expect_error($q$select public.atualizar_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',1,'{"nome_fantasia":"Stale"}','Teste concorrente','baca0000-4000-4000-8000-000000000002')$q$,'PT409');
select pg_temp.expect_error($q$select public.atualizar_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',2,'{"id":"baca0000-bbbb-4000-8000-000000000001"}','Campo protegido','baca0000-4000-4000-8000-000000000003')$q$,'PT422');
select pg_temp.expect_error($q$select public.alterar_situacao_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',2,'suspensa','Admin não pode suspender','baca0000-4000-4000-8000-000000000004')$q$,'PT422');
select pg_temp.expect_error($q$update public.contratos set objeto='Bypass' where id='baca0000-2000-4000-8000-000000000001'$q$,'42501');
select pg_temp.actor(8);
select pg_temp.assert_true(not (public.obter_cadastro_operacional_v1('baca0000-aaaa-4000-8000-000000000001','contratos','baca0000-2000-4000-8000-000000000001')->>'pode_editar')::boolean,'reader capabilities');
select pg_temp.expect_error($q$select public.atualizar_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',1,'{"objeto":"Denied"}','Leitor não edita','baca0000-4000-4000-8000-000000000005')$q$,'42501');
select pg_temp.actor(6);
select pg_temp.expect_error($q$select public.obter_cadastro_operacional_v1('baca0000-aaaa-4000-8000-000000000001','contratos','baca0000-2000-4000-8000-000000000002')$q$,'42501');
select pg_temp.expect_error($q$select public.obter_cadastro_operacional_v1('baca0000-bbbb-4000-8000-000000000001','contratos','baca0000-2000-4000-8000-000000000001')$q$,'42501');
truncate crud_responses;
insert into crud_responses select public.atualizar_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',1,'{"objeto":"Contrato editado","valor_global":1000}','Atualização do objeto','baca0000-4000-4000-8000-000000000006');
select pg_temp.assert_true((select (r->'registro'->>'versao_registro')::bigint=2 from crud_responses),'exactly one version increment contract');
select pg_temp.assert_true((select r from crud_responses)=public.atualizar_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',1,'{"objeto":"Contrato editado","valor_global":1000}','Atualização do objeto','baca0000-4000-4000-8000-000000000006'),'contract replay identical');
select pg_temp.expect_error($q$select public.atualizar_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',2,'{"valor_global":-1}','Valor inválido','baca0000-4000-4000-8000-000000000007')$q$,'PT422');
select pg_temp.expect_error($q$select public.atualizar_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',2,'{"id_contratante":null}','Campo proibido','baca0000-4000-4000-8000-000000000008')$q$,'PT422');
select public.alterar_situacao_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',2,'ativo','Ativação inicial','baca0000-4000-4000-8000-000000000009');
select public.alterar_situacao_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',3,'suspenso','Suspensão temporária','baca0000-4000-4000-8000-000000000010');
select public.alterar_situacao_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',4,'ativo','Reativação contratual','baca0000-4000-4000-8000-000000000011');
select public.alterar_situacao_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',5,'encerrado','Encerramento definitivo','baca0000-4000-4000-8000-000000000012');
select pg_temp.expect_error($q$select public.alterar_situacao_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',6,'ativo','Reabertura proibida','baca0000-4000-4000-8000-000000000013')$q$,'PT422');
select pg_temp.actor(1);
select public.alterar_situacao_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',2,'inativa','Desativação temporária','baca0000-4000-4000-8000-000000000014');
select pg_temp.expect_error($q$select public.atualizar_contrato_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',6,'{"objeto":"Denied inactive"}','Organização inativa','baca0000-4000-4000-8000-000000000015')$q$,'42501');
select public.alterar_situacao_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',3,'ativa','Retomada da organização','baca0000-4000-4000-8000-000000000016');
select pg_temp.actor(11);
select pg_temp.assert_true((public.obter_cadastro_operacional_v1('baca0000-aaaa-4000-8000-000000000001','organizacoes','baca0000-aaaa-4000-8000-000000000001')->>'pode_editar')::boolean,'MASTER no membership');
select public.alterar_situacao_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',4,'suspensa','Suspensão administrativa MASTER','baca0000-4000-4000-8000-000000000017');
select pg_temp.actor(1);
select pg_temp.expect_error($q$select public.alterar_situacao_organizacao_v1('baca0000-aaaa-4000-8000-000000000001',5,'ativa','Admin não remove suspensão','baca0000-4000-4000-8000-000000000018')$q$,'PT422');
reset role;
select pg_temp.assert_true((select count(*)=6 from public.versoes_contrato where id_contrato='baca0000-2000-4000-8000-000000000001'),'six snapshots: original plus five mutations');
select pg_temp.assert_true((select count(*)=9 from public.eventos_auditoria where evento='CadastroOperacionalAtualizado' and id_organizacao='baca0000-aaaa-4000-8000-000000000001'),'one event per mutation, none for denials/replays');
select pg_temp.assert_true((select count(*)=9 from public.comandos_idempotentes where comando like 'crud-cadastro-v1:%' and id_organizacao='baca0000-aaaa-4000-8000-000000000001'),'nine completed commands');
select pg_temp.assert_true(not has_function_privilege('anon','public.obter_cadastro_operacional_v1(uuid,text,uuid)','execute'),'anon forbidden');
delete from auth.sessions where user_id='baca0000-0000-4000-8000-000000000011';
set local role authenticated;
select pg_temp.actor(11);
select pg_temp.expect_error($q$select public.obter_cadastro_operacional_v1('baca0000-aaaa-4000-8000-000000000001','organizacoes','baca0000-aaaa-4000-8000-000000000001')$q$,'42501');
reset role;
select 'CRUD_CADASTROS_ISOLATED_PASS';
rollback;

