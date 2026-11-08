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

-- Local SQL claims only; actual JWT evidence remains the HML runner's obligation.
insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,sha256) values ('baca0000-7500-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','local-vigency/source.txt','source.txt',repeat('a',64));
insert into public.documentos_contrato(id,id_organizacao,id_contrato,tipo,titulo) values ('baca0000-7600-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','outro','Local vigency source');
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash) values ('baca0000-7700-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-7600-4000-8000-000000000001',1,'baca0000-7500-4000-8000-000000000001',repeat('a',64));
insert into public.sugestoes_extracao_documento(id,id_organizacao,id_contrato,id_versao_documento,tipo,conteudo) values ('baca0000-7800-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-7700-4000-8000-000000000001','obrigacao','Own synthetic vigency suggestion');
select pg_temp.assert_true((select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.definir_vigencia_sugestao_extracao(uuid,date,date)'::regprocedure),'exact definer and empty search path');
select pg_temp.assert_true(not has_function_privilege('anon','public.definir_vigencia_sugestao_extracao(uuid,date,date)','execute'),'anon remains denied');
select pg_temp.assert_true(not has_function_privilege('authenticated','privado.definir_vigencia_sugestao_extracao_v111(uuid,date,date)','execute'),'private execute remains denied');
set local role authenticated;
select pg_temp.actor(1);
select pg_temp.expect_error($q$select public.definir_vigencia_sugestao_extracao('baca0000-7800-4000-8000-000000000001','2026-01-01','2025-12-31')$q$,'PT400');
select pg_temp.assert_true(public.definir_vigencia_sugestao_extracao('baca0000-7800-4000-8000-000000000001','2026-01-01',null)->>'status'='atualizada','authorized entry reaches guarded implementation');
select pg_temp.assert_true(public.definir_vigencia_sugestao_extracao('baca0000-7800-4000-8000-000000000001','2026-01-01',null)->>'status'='sem_alteracao','noop does not duplicate audit');
select pg_temp.actor(8);
select pg_temp.expect_error($q$select public.definir_vigencia_sugestao_extracao('baca0000-7800-4000-8000-000000000001','2027-01-01',null)$q$,'42501');
select pg_temp.actor(12);
select pg_temp.expect_error($q$select public.definir_vigencia_sugestao_extracao('baca0000-7800-4000-8000-000000000001','2027-01-01',null)$q$,'42501');
reset role;
select pg_temp.assert_true((select vigencia_inicio='2026-01-01' and vigencia_fim is null from public.sugestoes_extracao_documento where id='baca0000-7800-4000-8000-000000000001'),'dates persisted and denials preserve them');
select pg_temp.assert_true((select count(*)=1 from public.eventos_auditoria where id_entidade='baca0000-7800-4000-8000-000000000001' and evento='VigenciaSugestaoExtracaoDefinida'),'one audit event');
update public.sugestoes_extracao_documento set status='aprovada' where id='baca0000-7800-4000-8000-000000000001';
set local role authenticated;
select pg_temp.actor(1);
select pg_temp.expect_error($q$select public.definir_vigencia_sugestao_extracao('baca0000-7800-4000-8000-000000000001','2027-01-01',null)$q$,'PT409');
reset role;
select 'DETAIL_VIGENCY_LOCAL_SQL_PASS';
rollback;
