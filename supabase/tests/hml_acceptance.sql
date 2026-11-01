-- ContaOS HML - Testes de aceitação do backend
-- Segurança: todos os dados deste arquivo são sintéticos e a transação termina em ROLLBACK.
-- Executar exclusivamente no HML.

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
  update public.contratantes set nome_fantasia='Tentativa obsoleta',versao_registro=6 where id=p_id;
  return 'SEM_ERRO';
exception when others then return sqlerrm; end; $$;
grant execute on function pg_temp.capturar_update_obsoleto(uuid) to authenticated;

-- Usuários sintéticos.
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('11111111-1111-4111-8111-111111111111','authenticated','authenticated','teste.a@contaos.invalid','{}','{"nome":"Teste A"}',now(),now()),
('22222222-2222-4222-8222-222222222222','authenticated','authenticated','teste.b@contaos.invalid','{}','{"nome":"Teste B"}',now(),now()),
('33333333-3333-4333-8333-333333333333','authenticated','authenticated','teste.leitor@contaos.invalid','{}','{"nome":"Teste Leitor"}',now(),now());

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

insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,situacao)
values
('aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-0000-4000-8000-000000000001','A-001','Contrato teste A','ativo'),
('bbbbbbbb-1000-4000-8000-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','bbbbbbbb-0000-4000-8000-000000000001','B-001','Contrato teste B','ativo');

-- Competências do contrato A.
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao)
values
('aaaaaaaa-2000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-08-01','2026-08-01','2026-08-31','em_analise'),
('aaaaaaaa-2000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-09-01','2026-09-01','2026-09-30','em_analise'),
('aaaaaaaa-2000-4000-8000-000000000003','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-10-01','2026-10-01','2026-10-31','em_analise'),
('aaaaaaaa-2000-4000-8000-000000000004','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','2026-11-01','2026-11-01','2026-11-30','com_apontamentos');

-- 99/100 e 100/100.
insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,codigo,descricao,obrigatorio,aplicavel,impeditivo,efeito_portao,hash_snapshot,ordem)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000001','manual','R'||lpad(g::text,3,'0'),'Requisito '||g,true,true,true,true,md5('c99-'||g),g from generate_series(1,100) g;
insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,codigo,descricao,obrigatorio,aplicavel,impeditivo,efeito_portao,hash_snapshot,ordem)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000002','manual','R'||lpad(g::text,3,'0'),'Requisito '||g,true,true,true,true,md5('c100-'||g),g from generate_series(1,100) g;
insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,codigo,descricao,obrigatorio,aplicavel,impeditivo,efeito_portao,hash_snapshot,ordem)
values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000003','manual','RNA','Não aplicável sem fundamento',true,true,true,true,md5('na'),1);

insert into public.execucoes_analise(id,id_organizacao,id_contrato,id_competencia,tipo,status,versao_motor,iniciada_em,concluida_em)
values
('aaaaaaaa-3000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000001','completa','concluida','teste',now(),now()),
('aaaaaaaa-3000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000002','completa','concluida','teste',now(),now()),
('aaaaaaaa-3000-4000-8000-000000000003','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000003','completa','concluida','teste',now(),now());

insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa)
select r.id_organizacao,r.id_contrato,r.id_competencia,'aaaaaaaa-3000-4000-8000-000000000001',r.id,'conforme','Teste HML'
from public.requisitos_competencia r where r.id_competencia='aaaaaaaa-2000-4000-8000-000000000001' order by r.ordem limit 99;
insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa)
select r.id_organizacao,r.id_contrato,r.id_competencia,'aaaaaaaa-3000-4000-8000-000000000002',r.id,'conforme','Teste HML'
from public.requisitos_competencia r where r.id_competencia='aaaaaaaa-2000-4000-8000-000000000002';
insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa,fundamento)
select r.id_organizacao,r.id_contrato,r.id_competencia,'aaaaaaaa-3000-4000-8000-000000000003',r.id,'nao_aplicavel','Teste HML',null
from public.requisitos_competencia r where r.id_competencia='aaaaaaaa-2000-4000-8000-000000000003';

-- Parecer interno aprovado para o cenário 100/100.
insert into public.pareceres_internos(id,id_organizacao,id_contrato,id_competencia,versao,texto,status,aprovado_por,aprovado_em,hash)
values('aaaaaaaa-3100-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-1000-4000-8000-000000000001','aaaaaaaa-2000-4000-8000-000000000002',1,'Parecer de homologação','aprovado','11111111-1111-4111-8111-111111111111',now(),md5('parecer'));

-- Ciclos de diligência para reapresentação.
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

set local role authenticated;

-- Isolamento A.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into contaos_testes select 'RLS','A só vê organização A',count(*)=1 and bool_and(id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid),'linhas='||count(*) from public.organizacoes;
insert into contaos_testes select 'RLS','A não vê organização B',count(*)=0,'linhas='||count(*) from public.organizacoes where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
insert into contaos_testes select 'RLS','A só vê contrato A',count(*)=1 and bool_and(id='aaaaaaaa-1000-4000-8000-000000000001'::uuid),'linhas='||count(*) from public.contratos;
insert into contaos_testes select 'RLS','A não vê contrato B',count(*)=0,'linhas='||count(*) from public.contratos where id='bbbbbbbb-1000-4000-8000-000000000001';

-- Gates 1.0 e 2.0.
insert into contaos_testes select 'PORTAO','99/100 não libera',not coalesce((r->>'liberado')::boolean,false) and (r->>'percentual')::numeric=99,r::text from (select public.avaliar_portao_conformidade('aaaaaaaa-2000-4000-8000-000000000001') r) x;
insert into contaos_testes select 'PORTAO','100/100 libera',coalesce((r->>'liberado')::boolean,false) and (r->>'percentual')::numeric=100,r::text from (select public.avaliar_portao_conformidade('aaaaaaaa-2000-4000-8000-000000000002') r) x;
insert into contaos_testes select 'PORTAO','Não aplicável sem fundamento não libera',not coalesce((r->>'liberado')::boolean,false),r::text from (select public.avaliar_portao_conformidade('aaaaaaaa-2000-4000-8000-000000000003') r) x;
insert into contaos_testes select 'PORTAO','99/100 bloqueia aprovação',r<>'SEM_ERRO',r from (select pg_temp.capturar_aprovacao('aaaaaaaa-2000-4000-8000-000000000001') r) x;
insert into contaos_testes select 'PORTAO','100/100 com parecer aprovado libera',r='SEM_ERRO',r from (select pg_temp.capturar_aprovacao('aaaaaaaa-2000-4000-8000-000000000002') r) x;
insert into contaos_testes select 'PORTAO','Status PODE APRESENTAR AO CONTRATANTE',situacao='pode_apresentar_contratante',situacao from public.competencias where id='aaaaaaaa-2000-4000-8000-000000000002';
insert into contaos_testes select 'REAPRESENTACAO','Com pendência não libera',not coalesce((r->>'liberado')::boolean,false),r::text from (select public.avaliar_portao_reapresentacao('aaaaaaaa-4000-4000-8000-000000000001') r) x;
insert into contaos_testes select 'REAPRESENTACAO','100% tratado libera',coalesce((r->>'liberado')::boolean,false),r::text from (select public.avaliar_portao_reapresentacao('aaaaaaaa-4000-4000-8000-000000000002') r) x;
select public.liberar_reapresentacao('aaaaaaaa-4000-4000-8000-000000000002','Teste HML');
insert into contaos_testes select 'REAPRESENTACAO','Status PODE REAPRESENTAR AO CONTRATANTE',situacao='pode_reapresentar_contratante',situacao from public.competencias where id='aaaaaaaa-2000-4000-8000-000000000004';

-- Concorrência otimista.
update public.contratantes set nome_fantasia='Primeira gravação',versao_registro=6 where id='aaaaaaaa-0000-4000-8000-000000000001';
insert into contaos_testes values('CONCORRENCIA','Versão 5 -> 6 aceita',true,'primeira gravação concluída');
insert into contaos_testes select 'CONCORRENCIA','Atualização obsoleta é rejeitada',r<>'SEM_ERRO',r from (select pg_temp.capturar_update_obsoleto('aaaaaaaa-0000-4000-8000-000000000001') r) x;

-- Isolamento B.
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into contaos_testes select 'RLS','B só vê organização B',count(*)=1 and bool_and(id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid),'linhas='||count(*) from public.organizacoes;
insert into contaos_testes select 'RLS','B não vê organização A',count(*)=0,'linhas='||count(*) from public.organizacoes where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into contaos_testes select 'RLS','B só vê contrato B',count(*)=1 and bool_and(id='bbbbbbbb-1000-4000-8000-000000000001'::uuid),'linhas='||count(*) from public.contratos;

-- Leitor não aprova e não cruza organização.
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claims','{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}',true);
insert into contaos_testes select 'RLS','Leitor não acessa contrato B',count(*)=0,'linhas='||count(*) from public.contratos where id='bbbbbbbb-1000-4000-8000-000000000001';
insert into contaos_testes select 'RLS','Leitor não executa aprovação',r<>'SEM_ERRO',r from (select pg_temp.capturar_aprovacao('aaaaaaaa-2000-4000-8000-000000000001') r) x;

select grupo,teste,passou,detalhe from contaos_testes order by grupo,teste;

rollback;
