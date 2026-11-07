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

-- V117 revisão: banco isolado descartável; claims SQL NÃO são JWT real.
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao) values
('baca0000-7000-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','2026-11-01','2026-11-01','2026-11-30','em_analise');
insert into public.requisitos_competencia(id,id_organizacao,id_contrato,id_competencia,origem_tipo,descricao,hash_snapshot,codigo) select
('baca0000-7100-4000-8000-'||lpad(n::text,12,'0'))::uuid,'baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-7000-4000-8000-000000000001','manual','Requisito revisão '||n,'h'||n,'REV'||n from generate_series(1,2)n;
insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,sha256,status_seguranca) values
('baca0000-7500-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','v117/evidence.pdf','evidence.pdf',repeat('a',64),'aprovado');
insert into public.documentos_competencia(id,id_organizacao,id_contrato,id_competencia,tipo,titulo) values
('baca0000-7600-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-7000-4000-8000-000000000001','comprovante','Evidência revisão');
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash) values
('baca0000-7700-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-7600-4000-8000-000000000001',1,'baca0000-7500-4000-8000-000000000001',repeat('a',64));
insert into public.pareceres_internos(id,id_organizacao,id_contrato,id_competencia,versao,texto,status,hash) values
('baca0000-7800-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-7000-4000-8000-000000000001',1,'Parecer anterior preservado','aprovado',repeat('b',64));
insert into public.execucoes_analise(id,id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,concluida_em) values
('baca0000-7200-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-7000-4000-8000-000000000001','completa','concluida',privado.hash_contexto_competencia('baca0000-7000-4000-8000-000000000001'),now());
insert into public.resultados_requisitos(id,id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado) select
('baca0000-7300-4000-8000-'||lpad(n::text,12,'0'))::uuid,'baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-7000-4000-8000-000000000001','baca0000-7200-4000-8000-000000000001',('baca0000-7100-4000-8000-'||lpad(n::text,12,'0'))::uuid,'conforme' from generate_series(1,2)n;
create function pg_temp.rev(c jsonb,k uuid,r text default 'conforme',ev jsonb default '[]') returns jsonb language sql security invoker as $$
select public.registrar_revisao_requisito_v117((c->>'id_competencia')::uuid,(c->>'id_requisito')::uuid,(c->>'id_execucao_esperada')::uuid,(c->>'id_resultado_esperado')::uuid,c->>'hash_esperado',r,'Revisão controlada','Fundamento controlado',ev,k) $$;
set local role authenticated;
select pg_temp.actor(4);
select pg_temp.assert_true(public.obter_contexto_revisao_v117('baca0000-7000-4000-8000-000000000001','baca0000-7100-4000-8000-000000000001')->>'pode_revisar'='true','direção autorizada como no registro legado');
select pg_temp.actor(1);
create temp table rev_estado(k text primary key,v jsonb) on commit drop;
insert into rev_estado values('base',public.obter_contexto_revisao_v117('baca0000-7000-4000-8000-000000000001','baca0000-7100-4000-8000-000000000001'));
select pg_temp.assert_true((select v->>'pode_revisar'='true' from rev_estado where k='base'),'capacidade de revisar');
insert into rev_estado select 'recibo',pg_temp.rev(v,'baca0000-7400-4000-8000-000000000001') from rev_estado where k='base';
select pg_temp.assert_true((select v from rev_estado where k='recibo')=pg_temp.rev((select v from rev_estado where k='base'),'baca0000-7400-4000-8000-000000000001'),'replay exato');
select pg_temp.expect_error($q$select pg_temp.rev((select v from rev_estado where k='base'),'baca0000-7400-4000-8000-000000000001','nao_conforme')$q$,'PT409');
select pg_temp.expect_error($q$select pg_temp.rev((select v from rev_estado where k='base'),gen_random_uuid())$q$,'PT409');
insert into rev_estado values('atual',public.obter_contexto_revisao_v117('baca0000-7000-4000-8000-000000000001','baca0000-7100-4000-8000-000000000001'));
select pg_temp.expect_error($q$select pg_temp.rev((select v from rev_estado where k='atual'),gen_random_uuid(),'nao_aplicavel')$q$,'PT422');
select pg_temp.expect_error($q$select pg_temp.rev((select v from rev_estado where k='atual'),gen_random_uuid(),'conforme','[{"id_versao_documento":"baca0000-9999-4000-8000-000000000001","pagina":1}]')$q$,'42501');
select pg_temp.expect_error($q$select pg_temp.rev((select v from rev_estado where k='atual'),gen_random_uuid(),null)$q$,'PT422');
select pg_temp.expect_error($q$select public.registrar_resultado_requisito('baca0000-7200-4000-8000-000000000001','baca0000-7100-4000-8000-000000000001','conforme')$q$,'PT409');
select pg_temp.expect_error($q$update public.resultados_requisitos set resultado='nao_conforme' where id='baca0000-7300-4000-8000-000000000001'$q$,'42501');
select pg_temp.actor(8);
select pg_temp.expect_error($q$select public.obter_contexto_revisao_v117('baca0000-7000-4000-8000-000000000001','baca0000-7100-4000-8000-000000000001')$q$,'42501');
select pg_temp.expect_error($q$select pg_temp.rev((select v from rev_estado where k='base'),gen_random_uuid())$q$,'42501');
select pg_temp.actor(11);
select pg_temp.assert_true(public.obter_contexto_revisao_v117('baca0000-7000-4000-8000-000000000001','baca0000-7100-4000-8000-000000000001')->>'pode_revisar'='true','master sem vínculo mantém autoridade canônica');
select pg_temp.actor(12);
select pg_temp.expect_error($q$select public.obter_contexto_revisao_v117('baca0000-7000-4000-8000-000000000001','baca0000-7100-4000-8000-000000000001')$q$,'42501');
select pg_temp.actor(1);
reset role;
select pg_temp.assert_true((select count(*)=3 from public.resultados_requisitos where id_competencia='baca0000-7000-4000-8000-000000000001'),'histórico preservado e efeito único');
select pg_temp.assert_true((select count(*)=1 from public.eventos_auditoria where evento='RevisaoRequisitoRegistrada' and id_organizacao='baca0000-aaaa-4000-8000-000000000001'),'um evento');
select pg_temp.assert_true((select status='substituido' and texto='Parecer anterior preservado' from public.pareceres_internos where id='baca0000-7800-4000-8000-000000000001'),'parecer substituído com conteúdo preservado');
set local role authenticated;
select pg_temp.expect_error($q$select public.aprovar_apresentacao('baca0000-7000-4000-8000-000000000001','Tentativa sem parecer novo')$q$,'P0001');
insert into rev_estado select 'na_valido',pg_temp.rev((select v from rev_estado where k='atual'),gen_random_uuid(),'nao_aplicavel','[{"id_versao_documento":"baca0000-7700-4000-8000-000000000001","pagina":1,"trecho":"Comprovante verificado"}]');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.evidencias_resultado where id_resultado=((select v from rev_estado where k='na_valido')->>'id_resultado')::uuid and hash=repeat('a',64) and pagina=1),'evidência válida com hash canônico do arquivo');
select pg_temp.assert_true((select resultado='conforme' from public.resultados_requisitos where id='baca0000-7300-4000-8000-000000000001'),'resultado original preservado');
-- Dois requisitos conformes antigos não podem receber selo de hash atual por revisão de apenas um.
update public.requisitos_competencia set descricao='Contexto material mudou' where id='baca0000-7100-4000-8000-000000000002';
set local role authenticated;
select pg_temp.assert_true(public.obter_contexto_revisao_v117('baca0000-7000-4000-8000-000000000001','baca0000-7100-4000-8000-000000000001')->>'pode_revisar'='false','base obsoleta não autoriza revisão parcial');
select pg_temp.expect_error($q$select pg_temp.rev((select v from rev_estado where k='atual'),gen_random_uuid())$q$,'PT409');
reset role;
select pg_temp.assert_true((select count(*)=3 from public.execucoes_analise where id_competencia='baca0000-7000-4000-8000-000000000001'),'negações sem execução nova');
select pg_temp.assert_true(not has_function_privilege('anon','public.obter_contexto_revisao_v117(uuid,uuid)','EXECUTE'),'anon negado');
select 'V117_REVISAO_ISOLATED_PASS';
rollback;
