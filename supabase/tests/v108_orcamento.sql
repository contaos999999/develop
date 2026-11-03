-- V1-08 / Prompt 29. Teste transacional final. Nenhuma fixture persiste após ROLLBACK.
begin;
create function pg_temp.v108_try(q text) returns jsonb language plpgsql security invoker set search_path='' as $$declare j jsonb; begin execute q into j; return jsonb_build_object('ok',true,'valor',j); exception when others then return jsonb_build_object('ok',false,'codigo',sqlstate,'mensagem',sqlerrm); end$$;
create temp table v108_ids(k text primary key,v uuid) on commit drop;
create temp table v108_checks(nome text primary key,ok boolean,detalhe jsonb) on commit drop;
grant all on v108_ids,v108_checks to authenticated;
grant execute on function pg_temp.v108_try(text) to authenticated;

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('c8282828-0000-4000-8000-000000000001','authenticated','authenticated','v108-admin@invalid',now(),now()),
('c8282828-0000-4000-8000-000000000002','authenticated','authenticated','v108-reader@invalid',now(),now()),
('c8282828-0000-4000-8000-000000000003','authenticated','authenticated','v108-master@invalid',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
('c8282828-0000-4000-9000-000000000001','c8282828-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
('c8282828-0000-4000-9000-000000000002','c8282828-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
('c8282828-0000-4000-9000-000000000003','c8282828-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour');
insert into public.organizacoes(id,razao_social) values ('c8282828-aaaa-4000-8000-000000000001','V108 A'),('c8282828-bbbb-4000-8000-000000000001','V108 B');
insert into public.contratantes(id,id_organizacao,razao_social) values ('c8282828-1000-4000-8000-000000000001','c8282828-aaaa-4000-8000-000000000001','A'),('c8282828-1000-4000-8000-000000000002','c8282828-bbbb-4000-8000-000000000001','B');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values
('c8282828-2000-4000-8000-000000000001','c8282828-aaaa-4000-8000-000000000001','c8282828-1000-4000-8000-000000000001','A','Orçamento A','2026-01-01'),
('c8282828-2000-4000-8000-000000000002','c8282828-bbbb-4000-8000-000000000001','c8282828-1000-4000-8000-000000000002','B','Orçamento B','2026-01-01');
insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo) values
('c8282828-3000-4000-8000-000000000001','c8282828-aaaa-4000-8000-000000000001','c8282828-0000-4000-8000-000000000001','administrador',true,true),
('c8282828-3000-4000-8000-000000000002','c8282828-aaaa-4000-8000-000000000001','c8282828-0000-4000-8000-000000000002','leitor',true,true);
insert into privado.administradores_master(id_usuario,ativo,motivo) values ('c8282828-0000-4000-8000-000000000003',true,'V108 fixture');
insert into public.arquivos(id,id_organizacao,id_contrato,bucket,path,nome_original,mime,tamanho,sha256,status_seguranca,origem) values
('c8282828-4000-4000-8000-000000000001','c8282828-aaaa-4000-8000-000000000001','c8282828-2000-4000-8000-000000000001','contaos-documentos','fixture/a1.pdf','a1.pdf','application/pdf',100,repeat('a',64),'aprovado','fixture'),
('c8282828-4000-4000-8000-000000000002','c8282828-aaaa-4000-8000-000000000001','c8282828-2000-4000-8000-000000000001','contaos-documentos','fixture/a2.pdf','a2.pdf','application/pdf',100,repeat('b',64),'aprovado','fixture');
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim) values
('c8282828-5000-4000-8000-000000000001','c8282828-aaaa-4000-8000-000000000001','c8282828-2000-4000-8000-000000000001','2026-01-01','2026-01-01','2026-01-31'),
('c8282828-5000-4000-8000-000000000002','c8282828-aaaa-4000-8000-000000000001','c8282828-2000-4000-8000-000000000001','2026-07-01','2026-07-01','2026-07-31');

-- Administrador: proposta -> V1 -> linha -> publicação -> V2 rascunho.
select set_config('request.jwt.claim.sub','c8282828-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"c8282828-0000-4000-8000-000000000001","role":"authenticated","session_id":"c8282828-0000-4000-9000-000000000001"}',true);
set local role authenticated;
with x as (select public.salvar_proposta_orcamentaria_v108('c8282828-aaaa-4000-8000-000000000001','c8282828-2000-4000-8000-000000000001',null,'Proposta temporal',null,'p1') j) insert into v108_ids select 'p',(j->'proposta'->>'id')::uuid from x;
with x as (select public.registrar_versao_proposta_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='p'),'2026-01-01',null,'c8282828-4000-4000-8000-000000000001','v1') j) insert into v108_ids select 'v1',(j->'versao'->>'id')::uuid from x;
with x as (select public.salvar_linha_orcamentaria_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='v1'),null,null,'Pessoal','Rubrica V1',null,null,100,1200,false,null,null,null,'l1') j) insert into v108_ids select 'l1',(j->'linha'->>'id')::uuid from x;
select public.publicar_versao_proposta_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='v1'),(select hash from public.versoes_proposta where id=(select v from v108_ids where k='v1')),'Publicação V1','pub1');
with x as (select public.registrar_versao_proposta_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='p'),'2026-07-01',null,'c8282828-4000-4000-8000-000000000002','v2') j) insert into v108_ids select 'v2',(j->'versao'->>'id')::uuid from x;
with x as (select public.salvar_linha_orcamentaria_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='v2'),null,null,'Pessoal','Rubrica V2',null,null,200,2400,true,5,'Nova versão',null,'l2') j) insert into v108_ids select 'l2',(j->'linha'->>'id')::uuid from x;
reset role;

insert into v108_checks values('01 rascunho fora do snapshot',jsonb_array_length(privado.snapshot_contexto_competencia('c8282828-5000-4000-8000-000000000002')->'propostas')=1,privado.snapshot_contexto_competencia('c8282828-5000-4000-8000-000000000002')->'propostas');
insert into v108_checks values('02 campos literais V1-CON-003',(select valor_mensal_previsto=200 and valor_anual_previsto=2400 and permite_remanejamento and limite_remanejamento_percentual=5 and observacoes='Nova versão' from public.linhas_orcamentarias where id=(select v from v108_ids where k='l2')),null);
insert into v108_checks values('03 codigo opcional gerado',(select codigo like 'RUB-%' from public.linhas_orcamentarias where id=(select v from v108_ids where k='l2')),null);

-- Publica V2 e comprova temporalidade histórica.
set local role authenticated;
select public.publicar_versao_proposta_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='v2'),(select hash from public.versoes_proposta where id=(select v from v108_ids where k='v2')),'Publicação V2','pub2');
insert into v108_checks select '04 edição publicada negada',j->>'codigo'='PT409',j from (select pg_temp.v108_try(format('select public.salvar_linha_orcamentaria_v108(%L,%L,%L,null,null,%L,null,null,1,12,false,null,null,1,%L)','c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='v1'),(select v from v108_ids where k='l1'),'Alterada','mut-pos-pub')) j)x;
reset role;
insert into v108_checks values('05 V1 substituida V2 publicada',(select situacao='substituida' from public.versoes_proposta where id=(select v from v108_ids where k='v1')) and (select situacao='publicada' from public.versoes_proposta where id=(select v from v108_ids where k='v2')),null);
insert into v108_checks values('06 janeiro reconstrói V1',(privado.snapshot_contexto_competencia('c8282828-5000-4000-8000-000000000001')->'linhas_orcamentarias'->0->>'rubrica')='Rubrica V1',privado.snapshot_contexto_competencia('c8282828-5000-4000-8000-000000000001')->'linhas_orcamentarias');
insert into v108_checks values('07 julho usa V2',(privado.snapshot_contexto_competencia('c8282828-5000-4000-8000-000000000002')->'linhas_orcamentarias'->0->>'rubrica')='Rubrica V2',privado.snapshot_contexto_competencia('c8282828-5000-4000-8000-000000000002')->'linhas_orcamentarias');

-- Remoção idempotente em rascunho separado.
set local role authenticated;
with x as (select public.salvar_proposta_orcamentaria_v108('c8282828-aaaa-4000-8000-000000000001','c8282828-2000-4000-8000-000000000001',null,'Proposta remoção',null,'pr') j) insert into v108_ids select 'pr',(j->'proposta'->>'id')::uuid from x;
with x as (select public.registrar_versao_proposta_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='pr'),'2027-01-01',null,'c8282828-4000-4000-8000-000000000001','vr') j) insert into v108_ids select 'vr',(j->'versao'->>'id')::uuid from x;
with x as (select public.salvar_linha_orcamentaria_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='vr'),null,null,null,'Remover',null,null,10,120,false,null,null,null,'lr') j) insert into v108_ids select 'lr',(j->'linha'->>'id')::uuid from x;
with a as (select public.remover_linha_orcamentaria_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='vr'),(select v from v108_ids where k='lr'),1,'rem1') j), b as (select public.remover_linha_orcamentaria_v108('c8282828-aaaa-4000-8000-000000000001',(select v from v108_ids where k='vr'),(select v from v108_ids where k='lr'),1,'rem1') j) insert into v108_checks select '08 replay remoção idêntico',a.j=b.j,jsonb_build_object('a',a.j,'b',b.j) from a,b;
reset role;

-- RBAC regular e Administrador Master.
select set_config('request.jwt.claim.sub','c8282828-0000-4000-8000-000000000002',true); select set_config('request.jwt.claims','{"sub":"c8282828-0000-4000-8000-000000000002","role":"authenticated","session_id":"c8282828-0000-4000-9000-000000000002"}',true); set local role authenticated;
insert into v108_checks select '09 leitor negado',j->>'codigo'='42501',j from(select pg_temp.v108_try($q$select public.salvar_proposta_orcamentaria_v108('c8282828-aaaa-4000-8000-000000000001','c8282828-2000-4000-8000-000000000001',null,'Leitor',null,'reader')$q$)j)x;
reset role;
select set_config('request.jwt.claim.sub','c8282828-0000-4000-8000-000000000003',true); select set_config('request.jwt.claims','{"sub":"c8282828-0000-4000-8000-000000000003","role":"authenticated","session_id":"c8282828-0000-4000-9000-000000000003"}',true); set local role authenticated;
insert into v108_checks select '10 Master global funciona',coalesce((j->>'ok')::boolean,false),j from(select pg_temp.v108_try($q$select public.salvar_proposta_orcamentaria_v108('c8282828-bbbb-4000-8000-000000000001','c8282828-2000-4000-8000-000000000002',null,'Master global',null,'master')$q$)j)x;
reset role;

-- Hardening da superfície.
insert into v108_checks values('11 DML direto fechado e SELECT preservado',not has_table_privilege('authenticated','public.propostas_orcamentarias','INSERT') and not has_table_privilege('authenticated','public.versoes_proposta','INSERT') and not has_table_privilege('authenticated','public.linhas_orcamentarias','UPDATE') and has_table_privilege('authenticated','public.propostas_orcamentarias','SELECT'),null);
insert into v108_checks values('12 anon sem wrappers',not has_function_privilege('anon','public.salvar_proposta_orcamentaria_v108(uuid,uuid,uuid,text,bigint,text)','EXECUTE') and not has_function_privilege('anon','public.publicar_versao_proposta_v108(uuid,uuid,text,text,text)','EXECUTE'),null);
insert into v108_checks values('13 helpers internos não expostos',not has_function_privilege('authenticated','privado.v108_iniciar(uuid,text,text,jsonb)','EXECUTE') and not has_function_privilege('authenticated','privado.v108_hash_versao(uuid)','EXECUTE'),null);
insert into v108_checks select '14 auditoria V108',count(*)>=9,jsonb_build_object('eventos',count(*)) from public.eventos_auditoria where id_organizacao='c8282828-aaaa-4000-8000-000000000001' and evento like 'V108%';
insert into v108_checks values('15 wrappers públicos executáveis',has_function_privilege('authenticated','public.salvar_proposta_orcamentaria_v108(uuid,uuid,uuid,text,bigint,text)','EXECUTE') and has_function_privilege('authenticated','public.registrar_versao_proposta_v108(uuid,uuid,date,date,uuid,text)','EXECUTE') and has_function_privilege('authenticated','public.remover_linha_orcamentaria_v108(uuid,uuid,uuid,bigint,text)','EXECUTE'),null);
insert into v108_checks values('16 colunas PRD presentes',(select count(*)=5 from information_schema.columns where table_schema='public' and ((table_name='versoes_proposta' and column_name='id_arquivo_origem') or (table_name='linhas_orcamentarias' and column_name in('valor_mensal_previsto','valor_anual_previsto','permite_remanejamento','observacoes')))),null);

do $$begin if exists(select 1 from v108_checks where not ok) then raise exception 'V108_FAIL %',(select jsonb_agg(jsonb_build_object('nome',nome,'detalhe',detalhe)) from v108_checks where not ok); end if; end$$;
select count(*) filter(where ok) passou,count(*) total,jsonb_agg(jsonb_build_object('teste',nome,'passou',ok) order by nome) detalhes from v108_checks;
rollback;