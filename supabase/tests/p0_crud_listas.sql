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

-- New module fixtures remain inside this rollback transaction.
insert into public.fontes_normativas(id,id_organizacao,id_contrato,tipo,titulo,situacao) values
('baca0000-5000-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','lei','Fonte controlada listas','ativa'),
('baca0000-5000-4000-8000-000000000002','baca0000-bbbb-4000-8000-000000000001',null,'lei','Fonte fora do tenant','ativa'),
('baca0000-5000-4000-8000-000000000003','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','lei','Fonte sem aprovação','ativa');
insert into public.versoes_fontes_normativas(id,id_organizacao,id_contrato,id_fonte,versao,inicio_vigencia,conteudo_texto,hash,aprovado_por,aprovado_em) values
('baca0000-5100-4000-8000-000000000001','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-5000-4000-8000-000000000001',1,'2026-01-01','Fixture normativa controlada',encode(extensions.digest('Fixture normativa controlada','sha256'),'hex'),'baca0000-0000-4000-8000-000000000001',now()),
('baca0000-5100-4000-8000-000000000002','baca0000-bbbb-4000-8000-000000000001',null,'baca0000-5000-4000-8000-000000000002',1,'2026-01-01','Fixture fora tenant',encode(extensions.digest('Fixture fora tenant','sha256'),'hex'),'baca0000-0000-4000-8000-000000000011',now()),
('baca0000-5100-4000-8000-000000000003','baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001','baca0000-5000-4000-8000-000000000003',1,'2026-01-01','Fixture sem aprovação',encode(extensions.digest('Fixture sem aprovação','sha256'),'hex'),null,null);
create function pg_temp.lista_st(p_chave text) returns jsonb language plpgsql security invoker set search_path='' as $$
begin return (select valor from pg_temp.lista_estado where chave=p_chave); end $$;
create function pg_temp.lista_id() returns uuid language plpgsql security invoker set search_path='' as $$
begin return (pg_temp.lista_st('atual')->'lista'->>'id')::uuid; end $$;
create function pg_temp.lista_ver() returns uuid language plpgsql security invoker set search_path='' as $$
begin return (pg_temp.lista_st('atual')->>'id_versao')::uuid; end $$;
create function pg_temp.lista_item() returns uuid language plpgsql security invoker set search_path='' as $$
begin return (pg_temp.lista_st('atual')->>'id_item')::uuid; end $$;
create function pg_temp.lista_cmd(p_acao text,p_payload jsonb,p_chave uuid default null,p_esperada bigint default null) returns jsonb language plpgsql security invoker set search_path='' as $$
declare r jsonb; id_lista uuid; versao bigint;
begin
 if p_acao<>'criar_lista' then id_lista:=pg_temp.lista_id(); versao:=coalesce(p_esperada,(pg_temp.lista_st('atual')->'lista'->>'versao_registro')::bigint); end if;
 r:=public.executar_comando_lista_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',id_lista,versao,p_acao,p_payload,'Teste controlado de listas',coalesce(p_chave,gen_random_uuid()));
 update pg_temp.lista_estado set valor=valor||jsonb_build_object('lista',r->'lista')||
   case when r->>'id_versao' is null then '{}'::jsonb else jsonb_build_object('id_versao',r->'id_versao') end||
   case when r->>'id_item' is null then '{}'::jsonb else jsonb_build_object('id_item',r->'id_item') end where chave='atual';
 return r;
end $$;
set local role authenticated;
select pg_temp.actor(1);
create temp table lista_estado(chave text primary key,valor jsonb not null) on commit drop;
insert into lista_estado values('atual','{}');
select pg_temp.assert_true(public.obter_lista_operacional_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001')->'acoes'->>'criar_lista'='true','create capability');
select pg_temp.assert_true(public.obter_lista_operacional_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001')->'acoes'->>'encerrar_vigencia'='false','no null capability without version');
insert into lista_estado select 'criar',pg_temp.lista_cmd('criar_lista','{"nome":"Lista controlada","vigencia_inicio":"2026-01-01"}','baca0000-6000-4000-8000-000000000001');
select pg_temp.assert_true(pg_temp.lista_st('criar')->'lista'->>'versao_registro'='1','created header version1');
select pg_temp.assert_true(pg_temp.lista_st('criar')=public.executar_comando_lista_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',null,null,'criar_lista','{"nome":"Lista controlada","vigencia_inicio":"2026-01-01"}','Teste controlado de listas','baca0000-6000-4000-8000-000000000001'),'create exact replay');
select pg_temp.expect_error($q$select public.executar_comando_lista_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',null,null,'criar_lista','{"nome":"Different"}','Teste controlado de listas','baca0000-6000-4000-8000-000000000001')$q$,'PT409');
insert into lista_estado select 'v1',to_jsonb(pg_temp.lista_ver());
select pg_temp.expect_error($q$select pg_temp.lista_cmd('criar_versao','{}')$q$,'PT409');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('editar_lista','{"id_organizacao":null}')$q$,'PT422');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('editar_lista','{"nome":"stale"}',null,999)$q$,'PT409');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('apagar_tudo','{}')$q$,'PT422');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('editar_vigencia_rascunho',jsonb_build_object('id_versao',pg_temp.lista_ver(),'vigencia_inicio',20260101))$q$,'PT422');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('editar_vigencia_rascunho',jsonb_build_object('id_versao',pg_temp.lista_ver(),'vigencia_inicio','2026-12-31','vigencia_fim','2026-01-01'))$q$,'PT422');
select pg_temp.expect_error($q$update public.listas_verificacao set nome='Bypass',versao_registro=versao_registro+1 where id=pg_temp.lista_id()$q$,'42501');
select pg_temp.expect_error($q$insert into public.itens_lista(id_organizacao,id_contrato,id_versao_lista,codigo,descricao) values('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',pg_temp.lista_ver(),'BYPASS','Bypass')$q$,'42501');
select pg_temp.lista_cmd('salvar_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'codigo','TEMP','descricao','Item descartável','obrigatorio',false));
insert into lista_estado select 'removido',to_jsonb(pg_temp.lista_item());
select pg_temp.lista_cmd('remover_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'id_item',pg_temp.lista_item()));
select pg_temp.assert_true((select count(*)=0 from public.itens_lista where id=(pg_temp.lista_st('removido')#>>'{}')::uuid),'draft item actually deleted');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('salvar_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'codigo','INVALID','descricao','Invalid','regra_validacao',jsonb_build_object('condicao',jsonb_build_object('tipo','desconhecido'))))$q$,'PT422');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('salvar_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'codigo','FOREIGN','descricao','Foreign','id_fonte_versao','baca0000-5100-4000-8000-000000000002'))$q$,'42501');
-- An initially false item becomes applicable through the existing snapshot trigger.
select pg_temp.lista_cmd('salvar_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'codigo','COND','descricao','Obrigação condicional','obrigatorio',true,'aplicavel',false,'impeditivo',true,'regra_validacao',jsonb_build_object('condicao',jsonb_build_object('tipo','sempre'))));
insert into lista_estado select 'item_v1',to_jsonb(pg_temp.lista_item());
select pg_temp.expect_error($q$select pg_temp.lista_cmd('publicar_versao',jsonb_build_object('id_versao',pg_temp.lista_ver()))$q$,'PT422');
select pg_temp.lista_cmd('salvar_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'id_item',pg_temp.lista_item(),'id_fonte_versao','baca0000-5100-4000-8000-000000000003'));
select pg_temp.expect_error($q$select pg_temp.lista_cmd('publicar_versao',jsonb_build_object('id_versao',pg_temp.lista_ver()))$q$,'PT422');
select pg_temp.lista_cmd('salvar_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'id_item',pg_temp.lista_item(),'id_fonte_versao','baca0000-5100-4000-8000-000000000001'));
select pg_temp.actor(6);
select pg_temp.expect_error($q$select pg_temp.lista_cmd('publicar_versao',jsonb_build_object('id_versao',pg_temp.lista_ver()))$q$,'42501');
select pg_temp.expect_error($q$select public.obter_lista_operacional_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000002',pg_temp.lista_id())$q$,'42501');
select pg_temp.actor(11);
select pg_temp.assert_true(public.obter_lista_operacional_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',pg_temp.lista_id(),pg_temp.lista_ver())->'acoes'->>'publicar_versao'='true','MASTER administrator inheritance preserved');
select pg_temp.lista_cmd('publicar_versao',jsonb_build_object('id_versao',pg_temp.lista_ver()));
select pg_temp.expect_error($q$select pg_temp.lista_cmd('salvar_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'id_item',pg_temp.lista_item(),'descricao','No rewrite'))$q$,'PT422');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('remover_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'id_item',pg_temp.lista_item()))$q$,'PT422');
select pg_temp.expect_error($q$update public.itens_lista set descricao='Bypass published' where id=pg_temp.lista_item()$q$,'42501');
select pg_temp.actor(1);
insert into lista_estado select 'comp_fev',to_jsonb(public.criar_competencia('baca0000-2000-4000-8000-000000000001','2026-02-01'));
select pg_temp.assert_true((select count(*)=1 and bool_and(aplicavel and impeditivo) from public.requisitos_competencia where id_competencia=(pg_temp.lista_st('comp_fev')#>>'{}')::uuid),'conditional item really becomes applicable in snapshot');
insert into lista_estado select 'snapshot_fev',(select jsonb_agg(to_jsonb(r) order by r.id) from public.requisitos_competencia r where r.id_competencia=(pg_temp.lista_st('comp_fev')#>>'{}')::uuid);
select pg_temp.expect_error($q$select pg_temp.lista_cmd('encerrar_vigencia',jsonb_build_object('id_versao',pg_temp.lista_ver(),'vigencia_fim','2026-01-31'))$q$,'PT422');
select pg_temp.lista_cmd('encerrar_vigencia',jsonb_build_object('id_versao',pg_temp.lista_ver(),'vigencia_fim','2026-02-28'));
select pg_temp.expect_error($q$select pg_temp.lista_cmd('encerrar_vigencia',jsonb_build_object('id_versao',pg_temp.lista_ver(),'vigencia_fim','2026-03-31'))$q$,'PT422');
select pg_temp.lista_cmd('editar_lista','{"nome":"Nome atual sem reescrever fonte passada"}');
select pg_temp.lista_cmd('criar_versao',jsonb_build_object('id_versao_origem',(pg_temp.lista_st('v1')#>>'{}')::uuid,'vigencia_inicio','2026-02-01'));
insert into lista_estado select 'v2',to_jsonb(pg_temp.lista_ver());
select pg_temp.assert_true((select count(*)=1 from public.itens_lista where id_versao_lista=pg_temp.lista_ver()),'version clone carries one item');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('publicar_versao',jsonb_build_object('id_versao',pg_temp.lista_ver()))$q$,'PT422');
select pg_temp.lista_cmd('editar_vigencia_rascunho',jsonb_build_object('id_versao',pg_temp.lista_ver(),'vigencia_inicio','2026-03-01'));
select pg_temp.lista_cmd('salvar_item',jsonb_build_object('id_versao',pg_temp.lista_ver(),'id_item',(select id from public.itens_lista where id_versao_lista=pg_temp.lista_ver()),'descricao','Obrigação versão dois'));
select pg_temp.lista_cmd('publicar_versao',jsonb_build_object('id_versao',pg_temp.lista_ver()));
insert into lista_estado select 'comp_mar',to_jsonb(public.criar_competencia('baca0000-2000-4000-8000-000000000001','2026-03-01'));
select pg_temp.assert_true((select count(*)=1 and bool_and(descricao='Obrigação versão dois') from public.requisitos_competencia where id_competencia=(pg_temp.lista_st('comp_mar')#>>'{}')::uuid),'new period uses new published version only');
insert into lista_estado select 'comp_jan',to_jsonb(public.criar_competencia('baca0000-2000-4000-8000-000000000001','2026-01-01'));
select pg_temp.assert_true((select count(*)=1 and bool_and(descricao='Obrigação condicional') from public.requisitos_competencia where id_competencia=(pg_temp.lista_st('comp_jan')#>>'{}')::uuid),'retrospective period still uses older published version');
select pg_temp.assert_true(pg_temp.lista_st('snapshot_fev')=(select jsonb_agg(to_jsonb(r) order by r.id) from public.requisitos_competencia r where r.id_competencia=(pg_temp.lista_st('comp_fev')#>>'{}')::uuid),'original snapshot remains byte-for-byte JSON equal');
select pg_temp.lista_cmd('criar_versao','{"vigencia_inicio":"2027-01-01"}');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('publicar_versao',jsonb_build_object('id_versao',pg_temp.lista_ver()))$q$,'PT422');
select pg_temp.lista_cmd('descartar_rascunho',jsonb_build_object('id_versao',pg_temp.lista_ver()));
select pg_temp.assert_true((select situacao='substituida' and aprovado_em is null from public.versoes_lista where id=pg_temp.lista_ver()),'discard retains version without pretending approval');
select pg_temp.lista_cmd('alterar_situacao','{"situacao":"inativa"}');
select pg_temp.lista_cmd('alterar_situacao','{"situacao":"ativa"}');
select pg_temp.actor(8);
select pg_temp.assert_true(public.obter_lista_operacional_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',pg_temp.lista_id())->'acoes'->>'editar_lista'='false','reader capabilities closed');
select pg_temp.expect_error($q$select pg_temp.lista_cmd('editar_lista','{"nome":"Denied"}')$q$,'42501');
select pg_temp.actor(1);
insert into lista_estado select 'replay_expected',to_jsonb((pg_temp.lista_st('atual')->'lista'->>'versao_registro')::bigint);
insert into lista_estado select 'replay',pg_temp.lista_cmd('editar_lista','{"descricao":"Última descrição"}','baca0000-6000-4000-8000-000000000099');
select pg_temp.assert_true(pg_temp.lista_st('replay')=public.executar_comando_lista_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',pg_temp.lista_id(),(pg_temp.lista_st('replay_expected')#>>'{}')::bigint,'editar_lista','{"descricao":"Última descrição"}','Teste controlado de listas','baca0000-6000-4000-8000-000000000099'),'edit exact replay');
select pg_temp.expect_error($q$select public.obter_lista_operacional_v1('baca0000-bbbb-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',pg_temp.lista_id())$q$,'42501');
reset role;
select pg_temp.assert_true((select count(*) from public.eventos_auditoria where evento='ListaOperacionalAlterada' and id_organizacao='baca0000-aaaa-4000-8000-000000000001')=(select count(*) from public.comandos_idempotentes where comando like 'crud-lista-v1:%' and id_organizacao='baca0000-aaaa-4000-8000-000000000001'),'one event for each successful command, no denial/replay effects');
select pg_temp.assert_true((select versao_registro from public.listas_verificacao where id=pg_temp.lista_id())=(select count(*) from public.comandos_idempotentes where comando like 'crud-lista-v1:%' and id_organizacao='baca0000-aaaa-4000-8000-000000000001'),'header aggregate increments exactly one per successful command');
select pg_temp.assert_true(not has_function_privilege('anon','public.executar_comando_lista_v1(uuid,uuid,uuid,bigint,text,jsonb,text,uuid)','execute'),'anon execution denied');
update public.vinculos_usuarios set ativo=false where id_usuario='baca0000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.actor(1);
select pg_temp.expect_error($q$select public.executar_comando_lista_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',pg_temp.lista_id(),(pg_temp.lista_st('replay_expected')#>>'{}')::bigint,'editar_lista','{"descricao":"Última descrição"}','Teste controlado de listas','baca0000-6000-4000-8000-000000000099')$q$,'42501');
reset role;
delete from auth.sessions where user_id='baca0000-0000-4000-8000-000000000011';
set local role authenticated;
select pg_temp.actor(11);
select pg_temp.expect_error($q$select public.obter_lista_operacional_v1('baca0000-aaaa-4000-8000-000000000001','baca0000-2000-4000-8000-000000000001',pg_temp.lista_id())$q$,'42501');
reset role;
select 'CRUD_LISTAS_ISOLATED_PASS';
rollback;

