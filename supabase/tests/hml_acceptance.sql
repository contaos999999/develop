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

-- Verify the public delegate without opening private EXECUTE or bypassing RBAC.
insert into contaos_testes
select 'UPLOAD_WRAPPER','Entrada pública delega com owner/search_path/corpo preservados',
 p.prosecdef and pg_get_userbyid(p.proowner)='postgres' and p.proconfig=array['search_path=""']::text[]
 and md5(p.prosrc)='76a15744ab7c8e4e2fb11f3e6477e661'
 and has_function_privilege('authenticated',p.oid,'EXECUTE')
 and not has_function_privilege('anon',p.oid,'EXECUTE'),'catálogo público'
from pg_proc p where p.oid='public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text)'::regprocedure;
insert into contaos_testes
select 'UPLOAD_WRAPPER','Privada permanece fechada com corpo preservado',
 p.prosecdef and pg_get_userbyid(p.proowner)='postgres' and p.proconfig=array['search_path=""']::text[]
 and md5(p.prosrc)='4bd3d0edebe2522b9ced4e1d6c482e9d'
 and not has_function_privilege('authenticated',p.oid,'EXECUTE')
 and not has_function_privilege('anon',p.oid,'EXECUTE'),'catálogo privado'
from pg_proc p where p.oid='privado.criar_documento_contrato_v111(uuid,text,text,text,date,date,text,uuid,text)'::regprocedure;
create temporary table wrapper_counts as select array[
 (select count(*) from public.documentos_contrato),
 (select count(*) from public.versoes_documento),
 (select count(*) from public.comandos_idempotentes),
 (select count(*) from public.execucoes_assincronas),
 (select count(*) from public.eventos_auditoria)] as counts;
create or replace function pg_temp.wrapper_upload_negado()
returns boolean language plpgsql security invoker set search_path='' as $$
begin
 perform public.criar_documento_contrato_completo('aaaaaaaa-1000-4000-8000-000000000001','outro','Teste negativo',null,null,null,null,null,'upload-wrapper-negative');
 return false;
exception when others then
 return sqlstate='42501' and sqlerrm='Você não tem permissão para realizar esta operação.';
end;$$;
grant execute on function pg_temp.wrapper_upload_negado() to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into contaos_testes values('UPLOAD_WRAPPER','Sem sessão chega à recusa RBAC',pg_temp.wrapper_upload_negado(),'negação material exata');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"00000000-0000-4000-8000-000000000000","aal":"aal1"}',true);
insert into contaos_testes values('UPLOAD_WRAPPER','Sessão inexistente negada',pg_temp.wrapper_upload_negado(),'negação material exata');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","session_id":"bbbbbbbb-2222-4222-8222-222222222222","aal":"aal1"}',true);
insert into contaos_testes values('UPLOAD_WRAPPER','Organização B não cria em A',pg_temp.wrapper_upload_negado(),'negação material exata');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claims','{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","session_id":"cccccccc-3333-4333-8333-333333333333","aal":"aal1"}',true);
insert into contaos_testes values('UPLOAD_WRAPPER','Leitor não cria documentos',pg_temp.wrapper_upload_negado(),'negação material exata');
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into contaos_testes
select 'UPLOAD_WRAPPER','Negativas sem efeitos persistidos',counts=array[
 (select count(*) from public.documentos_contrato),
 (select count(*) from public.versoes_documento),
 (select count(*) from public.comandos_idempotentes),
 (select count(*) from public.execucoes_assincronas),
 (select count(*) from public.eventos_auditoria)],'cinco tabelas sem delta' from wrapper_counts;

-- GATE158: managed grants are accepted; SQL metadata is not an API-access proof.
insert into contaos_testes
select 'WORKER_RUNTIME','pg_net fora de public com assinatura oficial',
 exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='pg_net' and n.nspname='extensions')
 and to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is not null,'metadata real sem HTTP';
insert into contaos_testes
select 'WORKER_RUNTIME','Scheduler postgres preservado',has_schema_privilege('postgres','net','USAGE')
 and has_function_privilege('postgres','net.http_post(text,jsonb,jsonb,jsonb,integer)','EXECUTE'),'capacidade oficial preservada';
insert into contaos_testes
select 'WORKER_RUNTIME','Clientes sem LOGIN SQL direto',count(*)=2 and bool_and(not rolcanlogin),'não certifica API' from pg_roles where rolname in ('anon','authenticated');
insert into contaos_testes
select 'WORKER_RUNTIME','LOGIN restrito aos serviços nominais confiáveis',not exists(select 1 from pg_roles where rolcanlogin and rolname not in ('authenticator','pgbouncer','postgres','supabase_admin','supabase_auth_admin','supabase_etl_admin','supabase_functions_admin','supabase_read_only_user','supabase_replication_admin','supabase_storage_admin')),'inventário fechado';
insert into contaos_testes
select 'WORKER_RUNTIME','Owner gerenciado preservado',exists(select 1 from pg_namespace where nspname='net' and pg_get_userbyid(nspowner)='supabase_admin'),'nenhum ownership alterado';

-- Real RPC pagination checks, own transaction fixtures, no retained writes.
create or replace function pg_temp.documentos_paginacao(a integer,b integer,c integer,d integer)
returns text language plpgsql security invoker set search_path='' as $$
begin
 perform public.obter_documentos_competencia_v115('aaaaaaaa-2000-4000-8000-000000000001',a,b,c,d);
 return '00000';
exception when others then return sqlstate; end; $$;
create or replace function pg_temp.analise_paginacao(a integer,b integer,c integer,d integer,e integer,f integer)
returns text language plpgsql security invoker set search_path='' as $$
begin
 perform public.obter_analise_competencia_v116('aaaaaaaa-2000-4000-8000-000000000001',a,b,c,d,e,f);
 return '00000';
exception when others then return sqlstate; end; $$;
grant execute on function pg_temp.documentos_paginacao(integer,integer,integer,integer),pg_temp.analise_paginacao(integer,integer,integer,integer,integer,integer) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"aaaaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',true);
insert into contaos_testes values('NULL_PAGINATION','documentos NULL argumento 1',pg_temp.documentos_paginacao(null,25,0,25)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','documentos NULL argumento 2',pg_temp.documentos_paginacao(0,null,0,25)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','documentos NULL argumento 3',pg_temp.documentos_paginacao(0,25,null,25)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','documentos NULL argumento 4',pg_temp.documentos_paginacao(0,25,0,null)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','documentos paginação válida',pg_temp.documentos_paginacao(0,25,0,25)='00000','controle positivo');
insert into contaos_testes values('NULL_PAGINATION','analise NULL argumento 1',pg_temp.analise_paginacao(null,25,0,10,0,25)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','analise NULL argumento 2',pg_temp.analise_paginacao(0,null,0,10,0,25)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','analise NULL argumento 3',pg_temp.analise_paginacao(0,25,null,10,0,25)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','analise NULL argumento 4',pg_temp.analise_paginacao(0,25,0,null,0,25)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','analise NULL argumento 5',pg_temp.analise_paginacao(0,25,0,10,null,25)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','analise NULL argumento 6',pg_temp.analise_paginacao(0,25,0,10,0,null)='PT400','rejeição exata');
insert into contaos_testes values('NULL_PAGINATION','analise paginação válida',pg_temp.analise_paginacao(0,25,0,10,0,25)='00000','controle positivo');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","session_id":"bbbbbbbb-2222-4222-8222-222222222222","aal":"aal1"}',true);
insert into contaos_testes values('NULL_PAGINATION','documentos isolamento antes da validação',pg_temp.documentos_paginacao(null,25,0,25)='42501','organização B não enumera A');
insert into contaos_testes values('NULL_PAGINATION','analise isolamento antes da validação',pg_temp.analise_paginacao(null,25,0,10,0,25)='42501','organização B não enumera A');
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);

-- Version wrapper: real authenticated SQL in the disposable Restore transaction only.
insert into contaos_testes select 'VERSION_WRAPPER','Catálogo público exato',
 p.prosecdef and pg_get_userbyid(p.proowner)='postgres' and p.proconfig=array['search_path=""']::text[]
 and md5(p.prosrc)='6d0c5926f4b25fd0e9562b0c010174ef'
 and has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE'),'um atributo alterado'
 from pg_proc p where p.oid='public.adicionar_versao_documento_contrato(uuid,uuid,text,text)'::regprocedure;
insert into contaos_testes select 'VERSION_WRAPPER','Privada fechada e preservada',
 p.prosecdef and pg_get_userbyid(p.proowner)='postgres' and p.proconfig=array['search_path=""']::text[]
 and md5(p.prosrc)='10698cb96e7de1de5a88b25960b341e5'
 and not has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE'),'RBAC original'
 from pg_proc p where p.oid='privado.adicionar_versao_documento_contrato_v110(uuid,uuid,text,text)'::regprocedure;
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio,situacao)
 values('aaaaaaaa-1000-4000-8000-000000000009','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-0000-4000-8000-000000000001','VERSION-OTHER','Outro contrato próprio','2026-01-01','ativo');
insert into public.arquivos(id,id_organizacao,id_contrato,bucket,path,nome_original,mime,tamanho,sha256,status_seguranca,origem) values
 ('aaaaaaaa-9200-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','contaos-documentos','version-wrapper/v1.txt','v1.txt','text/plain',10,repeat('a',64),'aprovado','fixture'),
 ('aaaaaaaa-9200-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','contaos-documentos','version-wrapper/v2.txt','v2.txt','text/plain',10,repeat('b',64),'aprovado','fixture'),
 ('aaaaaaaa-9200-4000-8000-000000000003','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000009','contaos-documentos','version-wrapper/foreign.txt','foreign.txt','text/plain',10,repeat('c',64),'aprovado','fixture');
create temporary table version_wrapper_receipts(kind text primary key,receipt jsonb not null);
grant select,insert on version_wrapper_receipts to authenticated;
create or replace function pg_temp.version_wrapper_try(p_file uuid,p_reason text,p_key text)
returns text language plpgsql security invoker set search_path='' as $$
begin
 perform public.adicionar_versao_documento_contrato((select (receipt->>'id_documento')::uuid from pg_temp.version_wrapper_receipts where kind='create'),p_file,p_reason,p_key);
 return '00000';
exception when others then return sqlstate; end; $$;
grant execute on function pg_temp.version_wrapper_try(uuid,text,text) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"aaaaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',true);
insert into version_wrapper_receipts values('create',public.criar_documento_contrato_completo('aaaaaaaa-1000-4000-8000-000000000001','outro','Version wrapper fixture',null,null,null,null,'aaaaaaaa-9200-4000-8000-000000000001','version-wrapper-create'));
insert into contaos_testes select 'VERSION_WRAPPER','Criação pública válida',(receipt->>'numero_versao')::integer=1 and receipt->>'id_arquivo'='aaaaaaaa-9200-4000-8000-000000000001','primeira versão real' from version_wrapper_receipts where kind='create';
reset role;
create temporary table version_wrapper_counts as select array[
 (select count(*) from public.documentos_contrato),(select count(*) from public.versoes_documento),
 (select count(*) from public.comandos_idempotentes),(select count(*) from public.execucoes_assincronas),
 (select count(*) from public.processamentos_documento),(select count(*) from public.eventos_auditoria)] as counts;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"sub":"","role":"authenticated","session_id":"","aal":"aal1"}',true);
insert into contaos_testes values('VERSION_WRAPPER','Sem sessão',pg_temp.version_wrapper_try('aaaaaaaa-9200-4000-8000-000000000002','Motivo','version-wrapper-denied')='42501','SQLSTATE exato');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"00000000-0000-4000-8000-000000000000","aal":"aal1"}',true);
insert into contaos_testes values('VERSION_WRAPPER','Sessão inválida',pg_temp.version_wrapper_try('aaaaaaaa-9200-4000-8000-000000000002','Motivo','version-wrapper-denied')='42501','SQLSTATE exato');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","session_id":"bbbbbbbb-2222-4222-8222-222222222222","aal":"aal1"}',true);
insert into contaos_testes values('VERSION_WRAPPER','Outro tenant',pg_temp.version_wrapper_try('aaaaaaaa-9200-4000-8000-000000000002','Motivo','version-wrapper-denied')='42501','SQLSTATE exato');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claims','{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","session_id":"cccccccc-3333-4333-8333-333333333333","aal":"aal1"}',true);
insert into contaos_testes values('VERSION_WRAPPER','Leitor',pg_temp.version_wrapper_try('aaaaaaaa-9200-4000-8000-000000000002','Motivo','version-wrapper-denied')='42501','SQLSTATE exato');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"aaaaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',true);
insert into contaos_testes values('VERSION_WRAPPER','Motivo obrigatório',pg_temp.version_wrapper_try('aaaaaaaa-9200-4000-8000-000000000002',null,'version-wrapper-denied')='PT400','SQLSTATE exato');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"aaaaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',true);
insert into contaos_testes values('VERSION_WRAPPER','Arquivo outro contrato',pg_temp.version_wrapper_try('aaaaaaaa-9200-4000-8000-000000000003','Motivo','version-wrapper-denied')='42501','SQLSTATE exato');
reset role;
insert into contaos_testes select 'VERSION_WRAPPER','Negativas sem efeitos',counts=array[
 (select count(*) from public.documentos_contrato),(select count(*) from public.versoes_documento),
 (select count(*) from public.comandos_idempotentes),(select count(*) from public.execucoes_assincronas),
 (select count(*) from public.processamentos_documento),(select count(*) from public.eventos_auditoria)],'seis tabelas sem delta' from version_wrapper_counts;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"aaaaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',true);
insert into version_wrapper_receipts values('version',public.adicionar_versao_documento_contrato((select (receipt->>'id_documento')::uuid from version_wrapper_receipts where kind='create'),'aaaaaaaa-9200-4000-8000-000000000002','Nova versão legítima','version-wrapper-positive'));
insert into version_wrapper_receipts values('replay',public.adicionar_versao_documento_contrato((select (receipt->>'id_documento')::uuid from version_wrapper_receipts where kind='create'),'aaaaaaaa-9200-4000-8000-000000000002','Nova versão legítima','version-wrapper-positive'));
insert into contaos_testes select 'VERSION_WRAPPER','Nova versão pública válida',(receipt->>'numero_versao')::integer=2 and receipt->>'id_arquivo'='aaaaaaaa-9200-4000-8000-000000000002','segunda versão real' from version_wrapper_receipts where kind='version';
insert into contaos_testes select 'VERSION_WRAPPER','Idempotência preservada',
 (select receipt from version_wrapper_receipts where kind='version')=(select receipt from version_wrapper_receipts where kind='replay')
 and (select count(*) from public.versoes_documento where id_documento_contrato=(select (receipt->>'id_documento')::uuid from version_wrapper_receipts where kind='create'))=2,'replay sem versão ou job adicional';
insert into contaos_testes select 'VERSION_WRAPPER','Primeira versão preservada',exists(select 1 from public.versoes_documento where id=(receipt->>'id_versao')::uuid and numero_versao=1 and id_arquivo='aaaaaaaa-9200-4000-8000-000000000001'),'histórico intacto' from version_wrapper_receipts where kind='create';
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);

select grupo,teste,passou,detalhe from contaos_testes order by grupo,teste;
rollback;
