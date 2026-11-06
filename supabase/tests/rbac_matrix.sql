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
do $$begin
for n in 1..10 loop
  perform pg_temp.actor(n);
  perform pg_temp.assert_true(privado.rbac_permite('baca0000-aaaa-4000-8000-000000000001','contratos','consultar','baca0000-2000-4000-8000-000000000001'),'ten profiles read own contract '||n);
  perform pg_temp.assert_true(not privado.rbac_permite('baca0000-bbbb-4000-8000-000000000001','contratos','consultar',null),'cross tenant denied '||n);
  perform pg_temp.assert_true(not privado.rbac_permite('baca0000-aaaa-4000-8000-000000000001','inventado','consultar',null),'unknown resource denied');
  perform pg_temp.expect_error($q$select public.obter_matriz_rbac_master()$q$,'42501');
  perform pg_temp.expect_error($q$select public.atualizar_matriz_rbac_master(1,'baca0000-3000-4000-8000-000000000099','[{"perfil":"leitor","recurso":"contratos","acao":"consultar","permitido":false}]')$q$,'42501');
end loop;
end $$;
select pg_temp.actor(6);
select pg_temp.assert_true(not privado.rbac_permite('baca0000-aaaa-4000-8000-000000000001','contratos','consultar','baca0000-2000-4000-8000-000000000002'),'contract A2 outside restricted scope');
select pg_temp.actor(12);
select pg_temp.assert_true(not privado.rbac_permite('baca0000-aaaa-4000-8000-000000000001','contratos','consultar',null),'no membership denied despite forged metadata');
select pg_temp.actor(1);
insert into public.contratos(id_organizacao,id_contratante,numero,objeto,inicio)
values('baca0000-aaaa-4000-8000-000000000001','baca0000-1000-4000-8000-000000000001','RBAC-new-contract','Authorized INSERT','2026-01-01');
select pg_temp.assert_true((select count(*)=1 from public.contratos where numero='RBAC-new-contract'),'contract INSERT remains usable');
select pg_temp.assert_true(privado.rbac_permite('baca0000-aaaa-4000-8000-000000000001','organizacoes','administrar',null),'organization administration catalog');
select pg_temp.assert_true(privado.rbac_permite('baca0000-aaaa-4000-8000-000000000001','analises','criar',null),'analysis creation catalog');
select pg_temp.actor(11);
select pg_temp.assert_true(privado.rbac_permite('baca0000-bbbb-4000-8000-000000000001','usuarios','administrar',null),'MASTER without membership');
select pg_temp.assert_true(not privado.usuario_possui_perfil('baca0000-aaaa-4000-8000-000000000001',array['direcao_aprovador']::text[]),'MASTER does not inherit specialized profile');
select pg_temp.expect_error($q$select public.atualizar_matriz_rbac_master(0,'baca0000-3000-4000-8000-000000000001','[{"perfil":"leitor","recurso":"contratos","acao":"consultar","permitido":false}]')$q$,'PT409');
create temp table rbac_test_response on commit drop as select public.atualizar_matriz_rbac_master(1,'baca0000-3000-4000-8000-000000000001','[{"perfil":"leitor","recurso":"contratos","acao":"consultar","permitido":false}]') as r;
select pg_temp.assert_true((select r from rbac_test_response)=public.atualizar_matriz_rbac_master(1,'baca0000-3000-4000-8000-000000000001','[{"perfil":"leitor","recurso":"contratos","acao":"consultar","permitido":false}]'),'exact idempotent replay');
select pg_temp.expect_error($q$select public.atualizar_matriz_rbac_master(1,'baca0000-3000-4000-8000-000000000001','[{"perfil":"leitor","recurso":"contratos","acao":"consultar","permitido":true}]')$q$,'PT409');
select pg_temp.expect_error($q$select public.atualizar_matriz_rbac_master(2,'baca0000-3000-4000-8000-000000000002','[{"perfil":"leitor","recurso":"inventado","acao":"consultar","permitido":true}]')$q$,'PT400');
select pg_temp.expect_error($q$select public.atualizar_matriz_rbac_master(2,'baca0000-3000-4000-8000-000000000003','[{"perfil":"leitor","recurso":"contratos","acao":"consultar","permitido":true},{"perfil":"leitor","recurso":"contratos","acao":"consultar","permitido":false}]')$q$,'PT400');
select pg_temp.assert_true((select count(*)=1 from public.eventos_auditoria where evento='MatrizRbacAtualizada' and id_usuario='baca0000-0000-4000-8000-000000000011'),'MASTER can read global RBAC audit under RLS');
select pg_temp.actor(8);
select pg_temp.assert_true(not privado.rbac_permite('baca0000-aaaa-4000-8000-000000000001','contratos','consultar','baca0000-2000-4000-8000-000000000001'),'live revocation');
select pg_temp.assert_true((select count(*)=0 from public.contratos where id='baca0000-2000-4000-8000-000000000001'),'RLS enforces revoked SELECT');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.eventos_auditoria where evento='MatrizRbacAtualizada' and id_usuario='baca0000-0000-4000-8000-000000000011'),'one audit event after replay');
select pg_temp.assert_true(not has_table_privilege('authenticated','privado.rbac_permissoes_perfis','UPDATE'),'no direct grants');
select pg_temp.assert_true(not has_function_privilege('anon','public.obter_matriz_rbac_master()','EXECUTE'),'anon denied');
select pg_temp.assert_true(not has_function_privilege('authenticated','public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean)','EXECUTE'),'legacy membership RPC remains disabled');
select pg_temp.assert_true(not has_function_privilege('authenticated','public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean)','EXECUTE'),'legacy contract RPC remains disabled');
delete from auth.sessions where user_id='baca0000-0000-4000-8000-000000000011';
set local role authenticated;
select pg_temp.actor(11);
select pg_temp.expect_error($q$select public.obter_matriz_rbac_master()$q$,'42501');
reset role;
select 'RBAC_ISOLATED_PASS';
rollback;
