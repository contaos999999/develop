-- V1-08 / Prompt 29. Fixtures sintéticas; nenhuma persistência após ROLLBACK.
begin;
create temp table v108_resultados(teste text primary key, passou boolean not null, detalhe jsonb) on commit drop;
create temp table v108_valores(k text primary key,j jsonb) on commit drop;
grant all on v108_resultados,v108_valores to authenticated;
create function pg_temp.v108_tentar(q text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare j jsonb; begin execute q into j; return jsonb_build_object('ok',true,'valor',j); exception when others then return jsonb_build_object('ok',false,'codigo',sqlstate,'mensagem',sqlerrm); end $$;
grant execute on function pg_temp.v108_tentar(text) to authenticated;

insert into auth.users(id,aud,role,email,created_at,updated_at)
select ('c8080808-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated','v108-'||n||'@contaos.invalid',now(),now() from generate_series(1,5)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select ('c8080808-0000-4000-9000-'||lpad(n::text,12,'0'))::uuid,('c8080808-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour' from generate_series(1,5)n;
insert into public.organizacoes(id,razao_social) values ('c8080808-aaaa-4000-8000-000000000001','V108 A'),('c8080808-bbbb-4000-8000-000000000001','V108 B');
insert into public.contratantes(id,id_organizacao,razao_social) values
('c8080808-1000-4000-8000-000000000001','c8080808-aaaa-4000-8000-000000000001','V108 contratante A'),
('c8080808-1000-4000-8000-000000000002','c8080808-bbbb-4000-8000-000000000001','V108 contratante B');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values
('c8080808-2000-4000-8000-000000000001','c8080808-aaaa-4000-8000-000000000001','c8080808-1000-4000-8000-000000000001','V108-A','Teste orçamento','2026-01-01'),
('c8080808-2000-4000-8000-000000000002','c8080808-bbbb-4000-8000-000000000001','c8080808-1000-4000-8000-000000000002','V108-B','Outro tenant','2026-01-01');
insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
select ('c8080808-3000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'c8080808-aaaa-4000-8000-000000000001',('c8080808-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
case n when 1 then 'administrador' when 2 then 'leitor' when 3 then 'financeiro' else 'gestor_contrato' end,true,true from generate_series(1,4)n;
insert into privado.administradores_master(id_usuario,ativo,motivo) values('c8080808-0000-4000-8000-000000000005',true,'Fixture V108');
insert into public.arquivos(id,id_organizacao,id_contrato,bucket,path,nome_original,mime,tamanho,sha256,status_seguranca,origem) values
('c8080808-4000-4000-8000-000000000001','c8080808-aaaa-4000-8000-000000000001','c8080808-2000-4000-8000-000000000001','contaos-documentos','fixture/v108-a.pdf','proposta.pdf','application/pdf',100,repeat('a',64),'aprovado','fixture'),
('c8080808-4000-4000-8000-000000000002','c8080808-bbbb-4000-8000-000000000001','c8080808-2000-4000-8000-000000000002','contaos-documentos','fixture/v108-b.pdf','outra.pdf','application/pdf',100,repeat('b',64),'aprovado','fixture');

set local role authenticated;
select set_config('request.jwt.claim.sub','c8080808-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"c8080808-0000-4000-8000-000000000001","role":"authenticated","session_id":"c8080808-0000-4000-9000-000000000001"}',true);

insert into v108_valores values('proposta',pg_temp.v108_tentar($q$select public.salvar_proposta_orcamentaria_v108('c8080808-aaaa-4000-8000-000000000001','c8080808-2000-4000-8000-000000000001',null,'Proposta 2026',null,'prop-1')$q$));
insert into v108_resultados select '01 criar proposta rascunho',coalesce((j->>'ok')::boolean and j->'valor'->'proposta'->>'situacao'='rascunho',false),j from v108_valores where k='proposta';
insert into v108_resultados select '02 replay idempotente',coalesce((select j from v108_valores where k='proposta')=pg_temp.v108_tentar($q$select public.salvar_proposta_orcamentaria_v108('c8080808-aaaa-4000-8000-000000000001','c8080808-2000-4000-8000-000000000001',null,'Proposta 2026',null,'prop-1')$q$),false),null;
insert into v108_resultados select '03 payload divergente PT409',j->>'codigo'='PT409',j from (select pg_temp.v108_tentar($q$select public.salvar_proposta_orcamentaria_v108('c8080808-aaaa-4000-8000-000000000001','c8080808-2000-4000-8000-000000000001',null,'Outra proposta',null,'prop-1')$q$)j)x;

insert into v108_valores values('versao',pg_temp.v108_tentar($q$select public.registrar_versao_proposta_v108('c8080808-aaaa-4000-8000-000000000001',(select (j->'valor'->'proposta'->>'id')::uuid from v108_valores where k='proposta'),'2026-01-01',null,'c8080808-4000-4000-8000-000000000001','ver-1')$q$));
insert into v108_resultados select '04 registrar versão rascunho',coalesce((j->>'ok')::boolean and j->'valor'->'versao'->>'numero_versao'='1' and length(j->'valor'->'versao'->>'hash')=64,false),j from v108_valores where k='versao';
insert into v108_resultados select '05 segunda versão rascunho concorrente negada',j->>'codigo'='PT409',j from (select pg_temp.v108_tentar($q$select public.registrar_versao_proposta_v108('c8080808-aaaa-4000-8000-000000000001',(select (j->'valor'->'proposta'->>'id')::uuid from v108_valores where k='proposta'),'2026-02-01',null,'c8080808-4000-4000-8000-000000000001','ver-2')$q$)j)x;
insert into v108_resultados select '06 arquivo cruzado negado',j->>'codigo' in('42501','PT400'),j from (select pg_temp.v108_tentar($q$select public.registrar_versao_proposta_v108('c8080808-aaaa-4000-8000-000000000001',(select (j->'valor'->'proposta'->>'id')::uuid from v108_valores where k='proposta'),'2026-02-01',null,'c8080808-4000-4000-8000-000000000002','ver-x')$q$)j)x;

insert into v108_valores values('linha',pg_temp.v108_tentar($q$select public.salvar_linha_orcamentaria_v108('c8080808-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v108_valores where k='versao'),null,null,'Pessoal','Recursos Humanos','Salários',null,10000,120000,true,10,'Remanejamento conforme proposta',null,'linha-1')$q$));
insert into v108_resultados select '07 linha literal V1-CON-003',coalesce((j->>'ok')::boolean and j->'valor'->'linha'->>'valor_mensal_previsto'='10000' and j->'valor'->'linha'->>'valor_anual_previsto'='120000' and (j->'valor'->'linha'->>'permite_remanejamento')::boolean and j->'valor'->'linha'->>'codigo' is not null,false),j from v108_valores where k='linha';
insert into v108_resultados select '08 linha conflito CAS',j->>'codigo'='PT409',j from (select pg_temp.v108_tentar($q$select public.salvar_linha_orcamentaria_v108('c8080808-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v108_valores where k='versao'),(select (j->'valor'->'linha'->>'id')::uuid from v108_valores where k='linha'),null,'Pessoal','Recursos Humanos','Salários',null,11000,132000,true,10,null,99,'linha-stale')$q$)j)x;
insert into v108_resultados select '09 publicação sem fundamento negada',j->>'codigo'='PT400',j from (select pg_temp.v108_tentar($q$select public.publicar_versao_proposta_v108('c8080808-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v108_valores where k='versao'),(select hash from public.versoes_proposta where id=(select (j->'valor'->'versao'->>'id')::uuid from v108_valores where k='versao')),'','pub-sem-fund')$q$)j)x;
insert into v108_valores values('publicar',pg_temp.v108_tentar($q$select public.publicar_versao_proposta_v108('c8080808-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v108_valores where k='versao'),(select hash from public.versoes_proposta where id=(select (j->'valor'->'versao'->>'id')::uuid from v108_valores where k='versao')),'Revisão humana da proposta','pub-1')$q$));
insert into v108_resultados select '10 publicar ator data e proposta ativa',coalesce((j->>'ok')::boolean and j->'valor'->'versao'->>'situacao'='publicada' and j->'valor'->'versao'->>'aprovado_em' is not null and j->'valor'->'proposta'->>'situacao'='ativa',false),j from v108_valores where k='publicar';
insert into v108_resultados select '11 linha publicada imutável',j->>'codigo'='PT409',j from (select pg_temp.v108_tentar($q$select public.salvar_linha_orcamentaria_v108('c8080808-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v108_valores where k='versao'),(select (j->'valor'->'linha'->>'id')::uuid from v108_valores where k='linha'),null,'Pessoal','Recursos Humanos','Salários',null,1,12,false,null,null,1,'linha-pos-pub')$q$)j)x;

reset role;
insert into v108_resultados select '12 DML direto revogado',not has_table_privilege('authenticated','public.propostas_orcamentarias','INSERT') and not has_table_privilege('authenticated','public.propostas_orcamentarias','UPDATE') and not has_table_privilege('authenticated','public.versoes_proposta','INSERT') and not has_table_privilege('authenticated','public.linhas_orcamentarias','INSERT') and not has_table_privilege('authenticated','public.linhas_orcamentarias','UPDATE'),null;
insert into v108_resultados select '13 SELECT preservado',has_table_privilege('authenticated','public.propostas_orcamentarias','SELECT') and has_table_privilege('authenticated','public.versoes_proposta','SELECT') and has_table_privilege('authenticated','public.linhas_orcamentarias','SELECT'),null;
insert into v108_resultados select '14 campos literais presentes',count(*)=5,jsonb_build_object('campos',count(*)) from information_schema.columns where table_schema='public' and ((table_name='versoes_proposta' and column_name='id_arquivo_origem') or (table_name='linhas_orcamentarias' and column_name in('valor_mensal_previsto','valor_anual_previsto','permite_remanejamento','observacoes')));
insert into v108_resultados select '15 auditoria V108',count(*)>=4,jsonb_build_object('eventos',count(*)) from public.eventos_auditoria where id_organizacao='c8080808-aaaa-4000-8000-000000000001' and evento like 'V108%';

-- Perfil sem permissão.
select set_config('request.jwt.claim.sub','c8080808-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"c8080808-0000-4000-8000-000000000002","role":"authenticated","session_id":"c8080808-0000-4000-9000-000000000002"}',true);
set local role authenticated;
insert into v108_resultados select '16 leitor não grava',j->>'codigo'='42501',j from(select pg_temp.v108_tentar($q$select public.salvar_proposta_orcamentaria_v108('c8080808-aaaa-4000-8000-000000000001','c8080808-2000-4000-8000-000000000001',null,'Leitor',null,'leitor')$q$)j)x;
reset role;

-- Master administrador global.
select set_config('request.jwt.claim.sub','c8080808-0000-4000-8000-000000000005',true);
select set_config('request.jwt.claims','{"sub":"c8080808-0000-4000-8000-000000000005","role":"authenticated","session_id":"c8080808-0000-4000-9000-000000000005"}',true);
set local role authenticated;
insert into v108_resultados select '17 Master funciona sem vínculo',coalesce((j->>'ok')::boolean,false),j from(select pg_temp.v108_tentar($q$select public.salvar_proposta_orcamentaria_v108('c8080808-aaaa-4000-8000-000000000001','c8080808-2000-4000-8000-000000000001',null,'Master',null,'master')$q$)j)x;
insert into v108_resultados select '18 tenant cruzado negado',j->>'codigo'='42501',j from(select pg_temp.v108_tentar($q$select public.salvar_proposta_orcamentaria_v108('c8080808-bbbb-4000-8000-000000000001','c8080808-2000-4000-8000-000000000002',null,'Outro tenant',null,'cross')$q$)j)x;
reset role;

-- Snapshot: rascunho não pode integrar contexto oficial.
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim) values('c8080808-5000-4000-8000-000000000001','c8080808-aaaa-4000-8000-000000000001','c8080808-2000-4000-8000-000000000001','2026-01','2026-01-01','2026-01-31');
insert into v108_resultados select '19 snapshot contém somente proposta publicada',coalesce(jsonb_array_length(privado.snapshot_contexto_competencia('c8080808-5000-4000-8000-000000000001')->'propostas')=1,false),privado.snapshot_contexto_competencia('c8080808-5000-4000-8000-000000000001')->'propostas';
insert into v108_resultados select '20 wrappers não expostos ao anon',not has_function_privilege('anon','public.salvar_proposta_orcamentaria_v108(uuid,uuid,uuid,text,bigint,text)','EXECUTE') and not has_function_privilege('anon','public.publicar_versao_proposta_v108(uuid,uuid,text,text,text)','EXECUTE'),null;

select count(*) filter(where passou) as passou,count(*) as total,jsonb_agg(jsonb_build_object('teste',teste,'passou',passou,'detalhe',detalhe) order by teste) as detalhes from v108_resultados;
rollback;