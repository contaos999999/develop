-- ContaOS HML 4.1 - suíte oficial de aceitação do backend
-- Todos os dados são sintéticos; a transação termina em ROLLBACK.

begin;

create temporary table contaos_testes(
  grupo text not null,
  teste text not null,
  passou boolean not null,
  detalhe text,
  primary key(grupo,teste)
) on commit drop;
grant select,insert on contaos_testes to authenticated;

create or replace function pg_temp.capturar_aprovacao(p_competencia uuid)
returns text language plpgsql security invoker set search_path='' as $$
begin
  perform public.aprovar_apresentacao(p_competencia,'Teste automatizado HML');
  return 'SEM_ERRO';
exception when others then return sqlerrm; end; $$;
grant execute on function pg_temp.capturar_aprovacao(uuid) to authenticated;

create or replace function pg_temp.capturar_update_obsoleto(p_id uuid)
returns text language plpgsql security invoker set search_path='' as $$
begin
  update public.contratantes set nome_fantasia='Tentativa obsoleta',versao_registro=5 where id=p_id;
  return 'SEM_ERRO';
exception when others then return sqlerrm; end; $$;
grant execute on function pg_temp.capturar_update_obsoleto(uuid) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('11111111-1111-4111-8111-111111111111','authenticated','authenticated','teste.a@contaos.invalid','{}','{"nome":"Teste A"}',now(),now()),
('22222222-2222-4222-8222-222222222222','authenticated','authenticated','teste.b@contaos.invalid','{}','{"nome":"Teste B"}',now(),now()),
('33333333-3333-4333-8333-333333333333','authenticated','authenticated','teste.leitor@contaos.invalid','{}','{"nome":"Teste Leitor"}',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values
('aaaaaaaa-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour'),
('bbbbbbbb-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222',now(),now(),'aal1',now()+interval '1 hour'),
('cccccccc-3333-4333-8333-333333333333','33333333-3333-4333-8333-333333333333',now(),now(),'aal1',now()+interval '1 hour');

insert into public.organizacoes(id,razao_social,nome_fantasia)
values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização Teste A','Teste A'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Organização Teste B','Teste B');

insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','administrador',true),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','administrador',true),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','33333333-3333-4333-8333-333333333333','leitor',true);

insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia,versao_registro)
values
('aaaaaaaa-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante A','Original',5),
('bbbbbbbb-0000-4000-8000-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Contratante B','Original B',1);

insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio,situacao)
values
('aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-0000-4000-8000-000000000001','A-001','Contrato teste A','2026-01-01','ativo'),
('bbbbbbbb-1000-4000-8000-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','bbbbbbbb-0000-4000-8000-000000000001','B-001','Contrato teste B','2026-01-01','ativo');

insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao)
values
('aaaaaaaa-2000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-08-01','2026-08-01','2026-08-31','em_analise'),
('aaaaaaaa-2000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-09-01','2026-09-01','2026-09-30','em_analise'),
('aaaaaaaa-2000-4000-8000-000000000003','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-10-01','2026-10-01','2026-10-31','em_analise'),
('aaaaaaaa-2000-4000-8000-000000000004','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-11-01','2026-11-01','2026-11-30','com_apontamentos'),
('aaaaaaaa-2000-4000-8000-000000000005','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-12-01','2026-12-01','2026-12-31','em_analise');

insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,codigo,descricao,obrigatorio,aplicavel,impeditivo,efeito_portao,hash_snapshot,ordem)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000001','manual','R'||lpad(g::text,3,'0'),'Requisito '||g,true,true,true,true,md5('c99-'||g),g from generate_series(1,100) g;
insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,codigo,descricao,obrigatorio,aplicavel,impeditivo,efeito_portao,hash_snapshot,ordem)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000002','manual','R'||lpad(g::text,3,'0'),'Requisito '||g,true,true,true,true,md5('c100-'||g),g from generate_series(1,100) g;
insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,codigo,descricao,obrigatorio,aplicavel,impeditivo,efeito_portao,hash_snapshot,ordem)
values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000003','manual','RNA','Não aplicável sem fundamento',true,true,true,true,md5('na'),1);
insert into public.requisitos_competencia(id,id_organizacao,id_contrato,id_competencia,origem_tipo,codigo,descricao,obrigatorio,aplicavel,impeditivo,efeito_portao,hash_snapshot,ordem)
values('aaaaaaaa-2100-4000-8000-000000000005','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000005','manual','STALE','Requisito antes da análise',true,true,true,true,md5('stale'),1);

insert into public.execucoes_analise(id,id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,versao_motor,iniciada_em,concluida_em,snapshot_entrada)
select x.id,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001',x.comp,x.tipo,'concluida',privado.hash_contexto_competencia(x.comp),'4.1',now(),now(),privado.snapshot_contexto_competencia(x.comp)
from (values
('aaaaaaaa-3000-4000-8000-000000000001'::uuid,'aaaaaaaa-2000-4000-8000-000000000001'::uuid,'completa'::text),
('aaaaaaaa-3000-4000-8000-000000000002'::uuid,'aaaaaaaa-2000-4000-8000-000000000002'::uuid,'completa'::text),
('aaaaaaaa-3000-4000-8000-000000000003'::uuid,'aaaaaaaa-2000-4000-8000-000000000003'::uuid,'completa'::text),
('aaaaaaaa-3000-4000-8000-000000000004'::uuid,'aaaaaaaa-2000-4000-8000-000000000004'::uuid,'reanálise'::text),
('aaaaaaaa-3000-4000-8000-000000000005'::uuid,'aaaaaaaa-2000-4000-8000-000000000005'::uuid,'completa'::text)
) x(id,comp,tipo);

insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa)
select r.id_organizacao,r.id_contrato,r.id_competencia,'aaaaaaaa-3000-4000-8000-000000000001',r.id,'conforme','Teste HML' from public.requisitos_competencia r where r.id_competencia='aaaaaaaa-2000-4000-8000-000000000001' order by r.ordem limit 99;
insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa)
select r.id_organizacao,r.id_contrato,r.id_competencia,'aaaaaaaa-3000-4000-8000-000000000002',r.id,'conforme','Teste HML' from public.requisitos_competencia r where r.id_competencia='aaaaaaaa-2000-4000-8000-000000000002';
insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa,fundamento)
select r.id_organizacao,r.id_contrato,r.id_competencia,'aaaaaaaa-3000-4000-8000-000000000003',r.id,'nao_aplicavel','Teste HML',null from public.requisitos_competencia r where r.id_competencia='aaaaaaaa-2000-4000-8000-000000000003';
insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa)
values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000005','aaaaaaaa-3000-4000-8000-000000000005','aaaaaaaa-2100-4000-8000-000000000005','conforme','Teste stale');

insert into public.pareceres_internos(id,id_organizacao,id_contrato,id_competencia,versao,texto,status,aprovado_por,aprovado_em,hash)
values
('aaaaaaaa-3100-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000002',1,'Parecer de homologação','aprovado','11111111-1111-4111-8111-111111111111',now(),md5('parecer')),
('aaaaaaaa-3100-4000-8000-000000000005','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000005',1,'Parecer stale','aprovado','11111111-1111-4111-8111-111111111111',now(),md5('parecer-stale'));

insert into public.ciclos_diligencia(id,id_organizacao,id_contrato,id_competencia,numero_rodada,status)
values
('aaaaaaaa-4000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000004',1,'em_tratamento'),
('aaaaaaaa-4000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000004',2,'em_tratamento');
insert into public.apontamentos_contratante(id_organizacao,id_contrato,id_competencia,id_ciclo,descricao,status)
values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000004','aaaaaaaa-4000-4000-8000-000000000001','Resolvido','resolvido'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000004','aaaaaaaa-4000-4000-8000-000000000001','Pendente','aberto'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000004','aaaaaaaa-4000-4000-8000-000000000002','Resolvido A','resolvido'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000004','aaaaaaaa-4000-4000-8000-000000000002','Resolvido B','resolvido');

update public.requisitos_competencia set descricao='Requisito alterado após a análise' where id='aaaaaaaa-2100-4000-8000-000000000005';

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"aaaaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',true);

insert into contaos_testes select 'RLS','A só vê organização A',count(*)=1 and bool_and(id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid),'linhas='||count(*) from public.organizacoes;
insert into contaos_testes select 'RLS','A não vê organização B',count(*)=0,'linhas='||count(*) from public.organizacoes where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
insert into contaos_testes select 'RLS','A não vê contrato B',count(*)=0,'linhas='||count(*) from public.contratos where id='bbbbbbbb-1000-4000-8000-000000000001';

insert into contaos_testes select 'PORTAO','99/100 não libera',not coalesce((r->>'liberado')::boolean,false) and (r->>'percentual')::numeric=99,r::text from (select public.avaliar_portao_conformidade('aaaaaaaa-2000-4000-8000-000000000001') r) x;
insert into contaos_testes select 'PORTAO','100/100 libera',coalesce((r->>'liberado')::boolean,false) and (r->>'percentual')::numeric=100,r::text from (select public.avaliar_portao_conformidade('aaaaaaaa-2000-4000-8000-000000000002') r) x;
insert into contaos_testes select 'PORTAO','Não aplicável sem fundamento não libera',not coalesce((r->>'liberado')::boolean,false),r::text from (select public.avaliar_portao_conformidade('aaaaaaaa-2000-4000-8000-000000000003') r) x;
insert into contaos_testes select 'PORTAO','99/100 bloqueia aprovação',r<>'SEM_ERRO',r from (select pg_temp.capturar_aprovacao('aaaaaaaa-2000-4000-8000-000000000001') r) x;
insert into contaos_testes select 'PORTAO','Hash desatualizado bloqueia aprovação',r<>'SEM_ERRO' and r ilike '%alterados após a análise%',r from (select pg_temp.capturar_aprovacao('aaaaaaaa-2000-4000-8000-000000000005') r) x;
insert into contaos_testes select 'PORTAO','100/100 com parecer e hash atual libera',r='SEM_ERRO',r from (select pg_temp.capturar_aprovacao('aaaaaaaa-2000-4000-8000-000000000002') r) x;
insert into contaos_testes select 'PORTAO','Status PODE APRESENTAR AO CONTRATANTE',situacao='pode_apresentar_contratante',situacao from public.competencias where id='aaaaaaaa-2000-4000-8000-000000000002';

insert into contaos_testes select 'REAPRESENTACAO','Com pendência não libera',not coalesce((r->>'liberado')::boolean,false),r::text from (select public.avaliar_portao_reapresentacao('aaaaaaaa-4000-4000-8000-000000000001') r) x;
insert into contaos_testes select 'REAPRESENTACAO','100% tratado libera',coalesce((r->>'liberado')::boolean,false),r::text from (select public.avaliar_portao_reapresentacao('aaaaaaaa-4000-4000-8000-000000000002') r) x;
select public.liberar_reapresentacao('aaaaaaaa-4000-4000-8000-000000000002','Teste HML');
insert into contaos_testes select 'REAPRESENTACAO','Status PODE REAPRESENTAR AO CONTRATANTE',situacao='pode_reapresentar_contratante',situacao from public.competencias where id='aaaaaaaa-2000-4000-8000-000000000004';

insert into contaos_testes select 'CONCORRENCIA','Versão obsoleta rejeitada',r<>'SEM_ERRO',r from (select pg_temp.capturar_update_obsoleto('aaaaaaaa-0000-4000-8000-000000000001') r) x;

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claims','{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","session_id":"cccccccc-3333-4333-8333-333333333333","aal":"aal1"}',true);
insert into contaos_testes select 'PERFIL','Leitor não aprova',r<>'SEM_ERRO',r from (select pg_temp.capturar_aprovacao('aaaaaaaa-2000-4000-8000-000000000002') r) x;

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","session_id":"bbbbbbbb-2222-4222-8222-222222222222","aal":"aal1"}',true);
insert into contaos_testes select 'RLS','B não vê contrato A',count(*)=0,'linhas='||count(*) from public.contratos where id='aaaaaaaa-1000-4000-8000-000000000001';

reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);

insert into public.documentos_competencia(id,id_organizacao,id_contrato,id_competencia,tipo,titulo,categoria,situacao,versao_atual)
values('aaaaaaaa-5000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000002','comprovante','Documento novo pós-liberação','financeiro','ativo',1);
insert into contaos_testes select 'ANTIDRIFT','Documento invalida portão',situacao='em_reanalise' and percentual_conformidade=0 and liberada_para_apresentacao_em is null,situacao||'/'||percentual_conformidade from public.competencias where id='aaaaaaaa-2000-4000-8000-000000000002';

insert into public.transacoes_financeiras(id,id_organizacao,id_contrato,data,descricao,valor,tipo,hash_origem)
values('aaaaaaaa-5100-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-11-15','Transação nova pós-liberação',100.00,'debito',md5('tx-antidrift'));
insert into contaos_testes select 'ANTIDRIFT','Dado financeiro invalida portão',situacao='em_reanalise' and percentual_conformidade=0 and liberada_para_reapresentacao_em is null,situacao||'/'||percentual_conformidade from public.competencias where id='aaaaaaaa-2000-4000-8000-000000000004';

-- Regression executes the expression from the installed RPC, not a duplicate parser.
do $upload_extension_test$
declare
 v_expression text;
 v_actual text;
 v_allowed text[];
 v_case record;
begin
 v_expression := split_part(split_part(pg_get_functiondef('privado.confirmar_upload_arquivo(uuid,uuid,text,text,text,bigint,text,text)'::regprocedure),'v_ext := ',2),';',1);
 if v_expression='' then raise exception 'Upload extension expression not found'; end if;
 select extensoes_permitidas into strict v_allowed from public.configuracao_upload where id=true;
 for v_case in select * from (values
  ('FONTE_SINTETICA_AUDITORIA_HML.txt','txt',true),
  ('ANEXO.PDF','pdf',true),
  ('relatorio.final.v2.docx','docx',true),
  ('planilha.xlsx','xlsx',true),
  ('imagem.PNG','png',true),
  ('anexo.txt.exe','exe',false),
  ('anexo.exe.txt','txt',true),
  ('semextensao','',false),
  ('txt','',false),
  ('anexo.','',false),
  ('','',false)
 ) as cases(nome,esperado,permitido)
 loop
  execute 'select '||replace(v_expression,'p_nome_original','$1') into v_actual using v_case.nome;
  insert into contaos_testes values('UPLOAD_EXT',v_case.nome||' -> '||v_case.esperado,
   v_actual is not distinct from v_case.esperado and
   coalesce(v_actual=any(v_allowed),false)=v_case.permitido,
   'extensao='||coalesce(v_actual,'NULL'));
 end loop;
 insert into contaos_testes values('UPLOAD_EXT','MIME divergente continua negado',not privado.mime_compativel_extensao('txt','application/pdf'),'txt/pdf');
end;
$upload_extension_test$;

select grupo,teste,passou,detalhe from contaos_testes order by grupo,teste;
rollback;
