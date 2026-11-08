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
  perform set_config('request.jwt.claim.sub',('d3720000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub','d3720000-0000-4000-8000-'||lpad(n::text,12,'0'),'role','authenticated','session_id','d3720000-0000-4000-9000-'||lpad(n::text,12,'0'),'user_metadata',jsonb_build_object('master',true))::text,true);
end $$;
insert into auth.users(id,aud,role,email,created_at,updated_at)
select ('d3720000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated','metadata-review-local-'||n||'@example.invalid',now(),now() from generate_series(1,12)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select ('d3720000-0000-4000-9000-'||lpad(n::text,12,'0'))::uuid,('d3720000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour' from generate_series(1,12)n;
insert into public.organizacoes(id,razao_social) values('d3720000-aaaa-4000-8000-000000000001','RBAC isolated A'),('d3720000-bbbb-4000-8000-000000000001','RBAC isolated B');
insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
select 'd3720000-aaaa-4000-8000-000000000001',('d3720000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,p,true
from unnest(array['administrador','auditor','contabilidade','direcao_aprovador','financeiro','gestor_contrato','juridico_conformidade','leitor','prestacao_contas','rh_dp']) with ordinality t(p,n);
insert into privado.administradores_master(id_usuario,motivo) values('d3720000-0000-4000-8000-000000000011','RBAC isolated fixture');
insert into public.contratantes(id,id_organizacao,razao_social) values('d3720000-1000-4000-8000-000000000001','d3720000-aaaa-4000-8000-000000000001','RBAC contractor A');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio)
values('d3720000-2000-4000-8000-000000000001','d3720000-aaaa-4000-8000-000000000001','d3720000-1000-4000-8000-000000000001','RBAC-A1','Isolated','2026-01-01');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio)
values('d3720000-2000-4000-8000-000000000002','d3720000-aaaa-4000-8000-000000000001','d3720000-1000-4000-8000-000000000001','RBAC-A2','Restricted','2026-01-01');
update public.vinculos_usuarios set escopo_todos_contratos=false where id_usuario='d3720000-0000-4000-8000-000000000006';
insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo)
select id_organizacao,id,'d3720000-2000-4000-8000-000000000001',true from public.vinculos_usuarios where id_usuario='d3720000-0000-4000-8000-000000000006';

-- Local SQL claims only; actual JWT evidence remains the HML runner's obligation.
insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,sha256,status_seguranca) values ('d3720000-7500-4000-8000-000000000001','d3720000-aaaa-4000-8000-000000000001','d3720000-2000-4000-8000-000000000001','local-vigency/source.txt','source.txt',repeat('a',64),'aprovado');
insert into public.documentos_contrato(id,id_organizacao,id_contrato,tipo,titulo,versao_atual) values ('d3720000-7600-4000-8000-000000000001','d3720000-aaaa-4000-8000-000000000001','d3720000-2000-4000-8000-000000000001','outro','Local vigency source',1);
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash) values ('d3720000-7700-4000-8000-000000000001','d3720000-aaaa-4000-8000-000000000001','d3720000-2000-4000-8000-000000000001','d3720000-7600-4000-8000-000000000001',1,'d3720000-7500-4000-8000-000000000001',repeat('a',64));

create temporary table original_version as select to_jsonb(v) original from public.versoes_documento v where id='d3720000-7700-4000-8000-000000000001';
insert into public.sugestoes_extracao_documento(id,id_organizacao,id_contrato,id_versao_documento,tipo,conteudo,metadados)
select ('d3720000-7800-4000-8000-'||lpad(n::text,12,'0'))::uuid,'d3720000-aaaa-4000-8000-000000000001','d3720000-2000-4000-8000-000000000001','d3720000-7700-4000-8000-000000000001','metadado','Own reviewed metadata','{"campos":{"own_field":"synthetic"}}'::jsonb from generate_series(1,3)n;
set local role authenticated;
select pg_temp.actor(8);
select pg_temp.expect_error($q$select public.revisar_sugestao_extracao('d3720000-7800-4000-8000-000000000001',true)$q$,'42501');
select pg_temp.actor(12);
select pg_temp.expect_error($q$select public.revisar_sugestao_extracao('d3720000-7800-4000-8000-000000000001',true)$q$,'42501');
select pg_temp.actor(1);
select pg_temp.assert_true(public.revisar_sugestao_extracao('d3720000-7800-4000-8000-000000000001',true)->>'numero_versao'='2','append returns new version');
select pg_temp.expect_error($q$select public.revisar_sugestao_extracao('d3720000-7800-4000-8000-000000000001',true)$q$,'P0001');
select pg_temp.expect_error($q$select public.revisar_sugestao_extracao('d3720000-7800-4000-8000-000000000002',true)$q$,'PT409');
select pg_temp.assert_true(public.revisar_sugestao_extracao('d3720000-7800-4000-8000-000000000003',false)->>'status'='rejeitada','rejection preserved');
reset role;
select pg_temp.assert_true((select to_jsonb(v)=o.original from public.versoes_documento v cross join original_version o where v.id='d3720000-7700-4000-8000-000000000001'),'whole old row remains identical');
select pg_temp.assert_true((select count(*)=2 and max(numero_versao)=2 from public.versoes_documento where id_documento_contrato='d3720000-7600-4000-8000-000000000001'),'no duplicate versions');
select pg_temp.assert_true((select versao_atual=2 from public.documentos_contrato where id='d3720000-7600-4000-8000-000000000001'),'parent pointer advanced');
select pg_temp.assert_true((select id_arquivo='d3720000-7500-4000-8000-000000000001' and hash=repeat('a',64) and enviado_por='d3720000-0000-4000-8000-000000000001' and metadados_extraidos->>'own_field'='synthetic' and metadados_extraidos->>'id_sugestao_origem'='d3720000-7800-4000-8000-000000000001' and motivo_substituicao like 'Revisão autorizada%' from public.versoes_documento where id_documento_contrato='d3720000-7600-4000-8000-000000000001' and numero_versao=2),'same file/hash and authorized metadata provenance');
select pg_temp.assert_true((select count(*)=1 from public.processamentos_documento p join public.versoes_documento v on v.id=p.id_versao_documento where v.id_documento_contrato='d3720000-7600-4000-8000-000000000001' and v.numero_versao=2 and p.etapa='documents' and p.status='pendente'),'normal processing queued');
select pg_temp.assert_true((select count(*)=1 from public.eventos_auditoria where id_organizacao='d3720000-aaaa-4000-8000-000000000001' and evento='DocumentoMetadadosRevisados'),'one append audit');
select pg_temp.expect_error($q$update public.versoes_documento set metadados_extraidos='{}' where id='d3720000-7700-4000-8000-000000000001'$q$,'P0001');
select pg_temp.expect_error($q$delete from public.versoes_documento where id_documento_contrato='d3720000-7600-4000-8000-000000000001' and numero_versao=2$q$,'P0001');

-- Separate competence parent: same physical hash still changes material context.
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao) values('d3720000-7000-4000-8000-000000000001','d3720000-aaaa-4000-8000-000000000001','d3720000-2000-4000-8000-000000000001','2026-11-01','2026-11-01','2026-11-30','em_analise');
insert into public.documentos_competencia(id,id_organizacao,id_contrato,id_competencia,tipo,titulo,versao_atual) values('d3720000-7600-4000-8000-000000000002','d3720000-aaaa-4000-8000-000000000001','d3720000-2000-4000-8000-000000000001','d3720000-7000-4000-8000-000000000001','comprovante','Own competence metadata',1);
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash) values('d3720000-7700-4000-8000-000000000002','d3720000-aaaa-4000-8000-000000000001','d3720000-2000-4000-8000-000000000001','d3720000-7600-4000-8000-000000000002',1,'d3720000-7500-4000-8000-000000000001',repeat('a',64));
insert into public.sugestoes_extracao_documento(id,id_organizacao,id_contrato,id_versao_documento,tipo,conteudo,metadados) values('d3720000-7800-4000-8000-000000000004','d3720000-aaaa-4000-8000-000000000001','d3720000-2000-4000-8000-000000000001','d3720000-7700-4000-8000-000000000002','metadado','Own competence reviewed','{"campos":{"competence_field":"approved"}}');
create temporary table competence_before as select privado.hash_contexto_competencia('d3720000-7000-4000-8000-000000000001') hash,to_jsonb(v) original from public.versoes_documento v where v.id='d3720000-7700-4000-8000-000000000002';
-- Explicit local synthetic released state, not a claim of actual HML approval.
update public.competencias set situacao='pode_apresentar_contratante',percentual_conformidade=100,liberada_para_apresentacao_em=now() where id='d3720000-7000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.actor(1);
select pg_temp.assert_true(public.revisar_sugestao_extracao('d3720000-7800-4000-8000-000000000004',true)->>'numero_versao'='2','competence append');
reset role;
select pg_temp.assert_true((select versao_atual=2 from public.documentos_competencia where id='d3720000-7600-4000-8000-000000000002'),'competence parent pointer advanced');
select pg_temp.assert_true((select to_jsonb(v)=b.original from public.versoes_documento v cross join competence_before b where v.id='d3720000-7700-4000-8000-000000000002'),'whole competence old row preserved');
select pg_temp.assert_true((select hash<>privado.hash_contexto_competencia('d3720000-7000-4000-8000-000000000001') from competence_before),'same file hash still changes context');
select pg_temp.assert_true((select situacao='em_reanalise' and liberada_para_apresentacao_em is null from public.competencias where id='d3720000-7000-4000-8000-000000000001'),'released competence gate invalidated');

select 'METADATA_APPEND_LOCAL_SQL_PASS';
rollback;
