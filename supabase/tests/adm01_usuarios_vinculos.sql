-- ContaOS 4.1 — PROMPT 21 / ADM-01 backend + transversais 091/092/093
-- Dados sintéticos; a transação termina em ROLLBACK.

begin;

create temporary table adm01_testes(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select, insert on adm01_testes to authenticated;

create temporary table adm01_versao_inicial(versao_registro bigint) on commit drop;
create temporary table adm01_versao_pos(versao_registro bigint) on commit drop;
create temporary table adm01_resposta_1(r jsonb) on commit drop;
create temporary table adm01_resposta_2(r jsonb) on commit drop;
grant select, insert, update on adm01_versao_inicial, adm01_versao_pos, adm01_resposta_1, adm01_resposta_2 to authenticated;

create or replace function pg_temp.tentar_listar(p_org uuid)
returns text language plpgsql security invoker set search_path=''
as $$ declare v jsonb; begin
  v := public.listar_usuarios_vinculos_adm(p_org,1,25,null,null);
  return 'OK:' || coalesce(v->>'schema_versao','');
exception when others then return sqlstate || ':' || sqlerrm; end $$;
grant execute on function pg_temp.tentar_listar(uuid) to authenticated;

create or replace function pg_temp.tentar_salvar(
  p_org uuid,p_user uuid,p_ver bigint,p_key text
) returns text language plpgsql security invoker set search_path=''
as $$ declare v jsonb; begin
  v := public.salvar_vinculo_usuario_adm(
    p_org,p_user,null,'financeiro',false,true,
    array['d1d1d1d1-1000-4000-8000-000000000001'::uuid],p_ver,p_key
  );
  return 'OK:' || coalesce(v->>'schema_versao','');
exception when others then return sqlstate || ':' || sqlerrm; end $$;
grant execute on function pg_temp.tentar_salvar(uuid,uuid,bigint,text) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('d1d1d1d1-0001-4000-8000-000000000001','authenticated','authenticated','adm01.admin@contaos.invalid','{}','{"nome":"Admin ADM01"}',now(),now()),
('d1d1d1d1-0002-4000-8000-000000000002','authenticated','authenticated','adm01.target@contaos.invalid','{}','{"nome":"Target ADM01"}',now(),now()),
('d1d1d1d1-0003-4000-8000-000000000003','authenticated','authenticated','adm01.reader@contaos.invalid','{}','{"nome":"Reader ADM01"}',now(),now()),
('d1d1d1d1-0004-4000-8000-000000000004','authenticated','authenticated','adm01.extra@contaos.invalid','{}','{"nome":"Extra ADM01"}',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag)
values
('d1d1d1d1-a001-4000-8000-000000000001','d1d1d1d1-0001-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour','adm01-admin'),
('d1d1d1d1-a003-4000-8000-000000000003','d1d1d1d1-0003-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour','adm01-reader');

insert into public.organizacoes(id,razao_social,nome_fantasia,situacao)
values
('d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização ADM01 A','ADM01 A','ativa'),
('d1d1d1d1-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Organização ADM01 B','ADM01 B','ativa');

insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
values
('d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','d1d1d1d1-0001-4000-8000-000000000001','administrador',true,true),
('d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','d1d1d1d1-0002-4000-8000-000000000002','leitor',false,true),
('d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','d1d1d1d1-0003-4000-8000-000000000003','leitor',false,true),
('d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','d1d1d1d1-0004-4000-8000-000000000004','auditor',false,true);

insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia)
values('d1d1d1d1-0100-4000-8000-000000000001','d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante ADM01','Contratante ADM01');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,situacao,criticidade)
values
('d1d1d1d1-1000-4000-8000-000000000001','d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','d1d1d1d1-0100-4000-8000-000000000001','ADM01-001','Contrato 1','ativo','media'),
('d1d1d1d1-1000-4000-8000-000000000002','d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','d1d1d1d1-0100-4000-8000-000000000001','ADM01-002','Contrato 2','ativo','alta');

set local role authenticated;
select set_config('request.jwt.claim.sub','d1d1d1d1-0001-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"d1d1d1d1-0001-4000-8000-000000000001","role":"authenticated","session_id":"d1d1d1d1-a001-4000-8000-000000000001","aal":"aal1"}',true);

insert into adm01_testes
select 'Lista paginada e identidade segura',
       (r->>'schema_versao')='adm01-v1'
       and (r->>'total')::int=4
       and jsonb_array_length(r->'itens')=2
       and r->'itens' @> '[{"email":"adm01.admin@contaos.invalid"}]'::jsonb,
       r::text
from (select public.listar_usuarios_vinculos_adm('d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,2,null,null) r) x;

insert into adm01_testes
select 'Page size é limitado', (r->>'tamanho_pagina')::int=100, r::text
from (select public.listar_usuarios_vinculos_adm('d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,999,null,null) r) x;

insert into adm01_versao_inicial(versao_registro)
select versao_registro
from public.vinculos_usuarios
where id_organizacao='d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and id_usuario='d1d1d1d1-0002-4000-8000-000000000002';

insert into adm01_resposta_1(r)
select public.salvar_vinculo_usuario_adm(
  'd1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'd1d1d1d1-0002-4000-8000-000000000002',null,'financeiro',false,true,
  array['d1d1d1d1-1000-4000-8000-000000000001'::uuid,'d1d1d1d1-1000-4000-8000-000000000002'::uuid],
  (select versao_registro from adm01_versao_inicial),'adm01-save-0001'
) r;

insert into adm01_versao_pos(versao_registro)
select versao_registro from public.vinculos_usuarios
where id_organizacao='d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and id_usuario='d1d1d1d1-0002-4000-8000-000000000002';

insert into adm01_resposta_2(r)
select public.salvar_vinculo_usuario_adm(
  'd1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'd1d1d1d1-0002-4000-8000-000000000002',null,'financeiro',false,true,
  array['d1d1d1d1-1000-4000-8000-000000000001'::uuid,'d1d1d1d1-1000-4000-8000-000000000002'::uuid],
  (select versao_registro from adm01_versao_inicial),'adm01-save-0001'
) r;

insert into adm01_testes
select 'Idempotência devolve mesmo resultado sem novo efeito',
       (select r from adm01_resposta_1)=(select r from adm01_resposta_2)
       and (select versao_registro from adm01_versao_pos)=(select versao_registro from public.vinculos_usuarios where id_organizacao='d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and id_usuario='d1d1d1d1-0002-4000-8000-000000000002')
       and (select count(*) from public.eventos_auditoria where id_organizacao='d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and evento='VinculoUsuarioAdministrativoSalvo' and metadados->>'id_usuario'='d1d1d1d1-0002-4000-8000-000000000002')=1,
       null;

insert into adm01_testes
select 'Escopo contratual foi sincronizado atomicamente',
       count(*)=2 and bool_and(vc.ativo), string_agg(vc.id_contrato::text,',')
from public.vinculos_usuario_contratos vc
join public.vinculos_usuarios vu on vu.id=vc.id_vinculo_usuario
where vu.id_organizacao='d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and vu.id_usuario='d1d1d1d1-0002-4000-8000-000000000002';

insert into adm01_testes
select 'Versão stale retorna HTTP 409 lógico', left(r,5)='PT409', r
from (select pg_temp.tentar_salvar(
  'd1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'd1d1d1d1-0002-4000-8000-000000000002',
  (select versao_registro from adm01_versao_inicial),
  'adm01-save-stale'
) r) x;

insert into adm01_testes
select 'Audit drawer paginado retorna evento da mudança',
       (r->>'total')::int>=1 and jsonb_array_length(r->'itens')>=1,
       r::text
from (select public.listar_auditoria_vinculo_usuario_adm(
  'd1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa','d1d1d1d1-0002-4000-8000-000000000002',1,20
) r) x;

select set_config('request.jwt.claim.sub','d1d1d1d1-0003-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"d1d1d1d1-0003-4000-8000-000000000003","role":"authenticated","session_id":"d1d1d1d1-a003-4000-8000-000000000003","aal":"aal1"}',true);
insert into adm01_testes
select 'Perfil não administrador é bloqueado no backend', left(r,5)='42501', r
from (select pg_temp.tentar_listar('d1d1d1d1-aaaa-4aaa-8aaa-aaaaaaaaaaaa') r) x;

reset role;

insert into adm01_testes
select 'RPCs novas: anon sem EXECUTE e authenticated com EXECUTE',
       not has_function_privilege('anon','public.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean)','EXECUTE')
       and has_function_privilege('authenticated','public.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean)','EXECUTE')
       and not has_function_privilege('anon','public.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text)','EXECUTE')
       and has_function_privilege('authenticated','public.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text)','EXECUTE'), null;

insert into adm01_testes
select 'Wrappers legados não permitem bypass por authenticated',
       not has_function_privilege('authenticated','public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean)','EXECUTE')
       and not has_function_privilege('authenticated','public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean)','EXECUTE'), null;

insert into adm01_testes
select 'Sem escrita direta em vínculos',
       not has_table_privilege('authenticated','public.vinculos_usuarios','INSERT')
       and not has_table_privilege('authenticated','public.vinculos_usuarios','UPDATE')
       and not has_table_privilege('authenticated','public.vinculos_usuarios','DELETE')
       and not has_table_privilege('authenticated','public.vinculos_usuario_contratos','INSERT')
       and not has_table_privilege('authenticated','public.vinculos_usuario_contratos','UPDATE')
       and not has_table_privilege('authenticated','public.vinculos_usuario_contratos','DELETE'), null;

insert into adm01_testes
select 'Public wrappers são SECURITY INVOKER', bool_and(not p.prosecdef), string_agg(p.proname,',')
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('listar_usuarios_vinculos_adm','listar_escopo_contratos_usuario_adm','listar_auditoria_vinculo_usuario_adm','salvar_vinculo_usuario_adm');

select teste,passou,detalhe from adm01_testes order by teste;
rollback;
