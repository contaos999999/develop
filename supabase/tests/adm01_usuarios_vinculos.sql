-- ContaOS 4.1 — PROMPT 21 / ADM-01 backend + transversais 091/092/093/094
-- Dados sintéticos; a transação termina em ROLLBACK integral.

begin;

create temporary table adm01_canon_testes(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select,insert on adm01_canon_testes to authenticated;

create or replace function pg_temp.tentar_lista(p_org uuid)
returns text language plpgsql security invoker set search_path=''
as $$ declare v jsonb; begin
  v:=public.listar_usuarios_vinculos_adm(p_org,1,25,null,null);
  return 'OK:'||coalesce(v->>'schema_versao','');
exception when others then return sqlstate||':'||sqlerrm; end $$;
grant execute on function pg_temp.tentar_lista(uuid) to authenticated;

create or replace function pg_temp.tentar_salvar(
  p_org uuid,p_user uuid,p_email text,p_perfil text,p_todos boolean,p_ativo boolean,
  p_ids uuid[],p_versao bigint,p_chave text
) returns text language plpgsql security invoker set search_path=''
as $$ declare v jsonb; begin
  v:=public.salvar_vinculo_usuario_adm(p_org,p_user,p_email,p_perfil,p_todos,p_ativo,p_ids,p_versao,p_chave);
  return 'OK:'||coalesce(v->'vinculo'->>'versao_registro','');
exception when others then return sqlstate||':'||sqlerrm; end $$;
grant execute on function pg_temp.tentar_salvar(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a3030303-1111-4111-8111-111111111111','authenticated','authenticated','adm01.canonadmin@contaos.invalid','{}','{"nome":"ADM01 Canon Admin"}',now(),now()),
('a3030303-2222-4222-8222-222222222222','authenticated','authenticated','adm01.canonleitor@contaos.invalid','{}','{"nome":"ADM01 Canon Leitor"}',now(),now()),
('a3030303-3333-4333-8333-333333333333','authenticated','authenticated','adm01.canoncaixa@contaos.invalid','{}','{"nome":"ADM01 Canon Alvo"}',now(),now()),
('a3030303-4444-4444-8444-444444444444','authenticated','authenticated','adm01.canonrestrito@contaos.invalid','{}','{"nome":"ADM01 Canon Restrito"}',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag) values
('a3030303-1111-4111-8111-aaaaaaaaaaaa','a3030303-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour','adm01-canon-admin'),
('a3030303-2222-4222-8222-bbbbbbbbbbbb','a3030303-2222-4222-8222-222222222222',now(),now(),'aal1',now()+interval '1 hour','adm01-canon-leitor'),
('a3030303-4444-4444-8444-dddddddddddd','a3030303-4444-4444-8444-444444444444',now(),now(),'aal1',now()+interval '1 hour','adm01-canon-restrito');

insert into public.organizacoes(id,razao_social,nome_fantasia,situacao)
values('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização ADM01 Canon','ADM01 Canon','ativa');

insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo) values
('a3030303-1000-4000-8000-000000000001','a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-1111-4111-8111-111111111111','administrador',true,true),
('a3030303-1000-4000-8000-000000000002','a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-2222-4222-8222-222222222222','leitor',true,true),
('a3030303-1000-4000-8000-000000000004','a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-4444-4444-8444-444444444444','administrador',false,true);

insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia)
values('a3030303-2000-4000-8000-000000000001','a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante Canon','Contratante Canon');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,situacao,criticidade) values
('a3030303-3000-4000-8000-000000000001','a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-2000-4000-8000-000000000001','CANON-C1','Permitido','ativo','media'),
('a3030303-3000-4000-8000-000000000002','a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-2000-4000-8000-000000000001','CANON-C2','Segundo','ativo','media');

insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo)
values('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-1000-4000-8000-000000000004','a3030303-3000-4000-8000-000000000001',true);

-- Evento sintético para provar que o AuditDrawer redige contrato fora do escopo.
insert into public.eventos_auditoria(id_organizacao,id_usuario,evento,entidade,id_entidade,antes,depois,metadados) values(
'a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-1111-4111-8111-111111111111','VinculoUsuarioAdministrativoSalvo','vinculos_usuarios','a3030303-1000-4000-8000-000000000002',
jsonb_build_object('escopo_contratos',jsonb_build_array(jsonb_build_object('id_contrato','a3030303-3000-4000-8000-000000000002','ativo',true))),
jsonb_build_object('escopo_contratos',jsonb_build_array(jsonb_build_object('id_contrato','a3030303-3000-4000-8000-000000000002','ativo',false))),
jsonb_build_object('id_usuario','a3030303-3333-4333-8333-333333333333'));

set local role authenticated;
select set_config('request.jwt.claim.sub','a3030303-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"a3030303-1111-4111-8111-111111111111","role":"authenticated","session_id":"a3030303-1111-4111-8111-aaaaaaaaaaaa","aal":"aal1"}',true);

insert into adm01_canon_testes values(
  '01 validar administrador',
  public.validar_administrador_organizacao('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),null
);

insert into adm01_canon_testes
select '02 lista paginada limita 100',
       (r->>'schema_versao')='adm01-v1' and (r->>'total')::int=3 and (r->>'tamanho_pagina')::int=100,
       r::text
from (select public.listar_usuarios_vinculos_adm('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,999,null,null) r) x;

with r as (
  select public.salvar_vinculo_usuario_adm(
    'a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'adm01.canoncaixa@contaos.invalid','gestor_contrato',false,true,
    array['a3030303-3000-4000-8000-000000000001'::uuid],null,'adm01-canon-criar-001'
  ) j
)
insert into adm01_canon_testes
select '03 vincular conta existente por email',
       (j->>'id_usuario')='a3030303-3333-4333-8333-333333333333'
       and j->'vinculo'->>'perfil'='gestor_contrato'
       and j->'vinculo'->>'versao_registro'='1',j::text
from r;

insert into adm01_canon_testes
select '04 escopo contratual vem da API',
       (r->>'total')::int=2
       and exists(select 1 from jsonb_array_elements(r->'itens') e where e->>'numero'='CANON-C1' and (e->>'selecionado')::boolean=true)
       and exists(select 1 from jsonb_array_elements(r->'itens') e where e->>'numero'='CANON-C2' and (e->>'selecionado')::boolean=false),
       r::text
from (select public.listar_escopo_contratos_usuario_adm('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-3333-4333-8333-333333333333',1,25,null) r) x;

with r as (
  select public.salvar_vinculo_usuario_adm(
    'a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'adm01.canoncaixa@contaos.invalid','gestor_contrato',false,true,
    array['a3030303-3000-4000-8000-000000000001'::uuid],null,'adm01-canon-criar-001'
  ) j
), c as (
  select count(*) n from public.comandos_idempotentes
  where id_organizacao='a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and comando='adm01.salvar_vinculo_usuario' and chave='adm01-canon-criar-001'
), a as (
  select count(*) n from public.eventos_auditoria
  where id_organizacao='a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    and evento='VinculoUsuarioAdministrativoSalvo'
    and metadados->>'id_usuario'='a3030303-3333-4333-8333-333333333333'
    and metadados->>'chave_idempotencia'='adm01-canon-criar-001'
)
insert into adm01_canon_testes
select '05 replay idempotente sem duplicar efeito',(select n from c)=1 and (select n from a)=1 and r.j->>'schema_versao'='adm01-v1',r.j::text from r;

insert into adm01_canon_testes
select '06 mesma chave payload diferente 409',left(r,5)='PT409',r
from (select pg_temp.tentar_salvar('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'adm01.canoncaixa@contaos.invalid','auditor',false,true,array['a3030303-3000-4000-8000-000000000001'::uuid],null,'adm01-canon-criar-001') r) x;

insert into adm01_canon_testes
select '07 versão stale 409',left(r,5)='PT409',r
from (select pg_temp.tentar_salvar('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-3333-4333-8333-333333333333',null,'auditor',false,true,array['a3030303-3000-4000-8000-000000000001'::uuid],0,'adm01-canon-stale-001') r) x;

with atual as (
  select versao_registro from public.vinculos_usuarios
  where id_organizacao='a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and id_usuario='a3030303-3333-4333-8333-333333333333'
), r as (
  select public.salvar_vinculo_usuario_adm(
    'a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-3333-4333-8333-333333333333',null,'auditor',false,true,
    array['a3030303-3000-4000-8000-000000000001'::uuid,'a3030303-3000-4000-8000-000000000002'::uuid],
    (select versao_registro from atual),'adm01-canon-editar-001'
  ) j
)
insert into adm01_canon_testes
select '08 edição atômica perfil e dois contratos',
       j->'vinculo'->>'perfil'='auditor' and (j->'vinculo'->>'versao_registro')::bigint>(select versao_registro from atual),j::text
from r;

insert into adm01_canon_testes
select '09 auditoria paginada registra alteração',jsonb_array_length(r->'itens')>=3 and (r->>'tamanho_pagina')::int=50,r::text
from (select public.listar_auditoria_vinculo_usuario_adm('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-3333-4333-8333-333333333333',1,999) r) x;

select set_config('request.jwt.claim.sub','a3030303-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"a3030303-2222-4222-8222-222222222222","role":"authenticated","session_id":"a3030303-2222-4222-8222-bbbbbbbbbbbb","aal":"aal1"}',true);
insert into adm01_canon_testes
select '10 não-admin 403 real',left(r,5)='42501',r
from (select pg_temp.tentar_lista('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa') r) x;

select set_config('request.jwt.claim.sub','a3030303-4444-4444-8444-444444444444',true);
select set_config('request.jwt.claims','{"sub":"a3030303-4444-4444-8444-444444444444","role":"authenticated","session_id":"a3030303-4444-4444-8444-dddddddddddd","aal":"aal1"}',true);
insert into adm01_canon_testes
select '11 admin restrito escopo API somente C1',(r->>'total')::int=1 and r->'itens'->0->>'numero'='CANON-C1',r::text
from (select public.listar_escopo_contratos_usuario_adm('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-3333-4333-8333-333333333333',1,25,null) r) x;

with atual as (
  select versao_registro from public.vinculos_usuarios
  where id_organizacao='a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and id_usuario='a3030303-3333-4333-8333-333333333333'
)
insert into adm01_canon_testes
select '12 admin restrito não salva C2',left(r,5) in ('PT400','42501'),r
from (select pg_temp.tentar_salvar('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-3333-4333-8333-333333333333',null,'auditor',false,true,array['a3030303-3000-4000-8000-000000000002'::uuid],(select versao_registro from atual),'adm01-canon-negado-001') r) x;

insert into adm01_canon_testes
select '13 audit drawer não vaza C2 oculto',not (r::text like '%a3030303-3000-4000-8000-000000000002%'),r::text
from (select public.listar_auditoria_vinculo_usuario_adm('a3030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a3030303-3333-4333-8333-333333333333',1,50) r) x;

reset role;

insert into adm01_canon_testes
select '14 anon sem EXECUTE canônico',
  not has_function_privilege('anon','public.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean)','EXECUTE')
  and not has_function_privilege('anon','public.listar_escopo_contratos_usuario_adm(uuid,uuid,integer,integer,text)','EXECUTE')
  and not has_function_privilege('anon','public.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer)','EXECUTE')
  and not has_function_privilege('anon','public.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text)','EXECUTE'),null;

insert into adm01_canon_testes
select '15 RPCs antigas não executáveis por authenticated',
  not has_function_privilege('authenticated','public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean)','EXECUTE')
  and not has_function_privilege('authenticated','public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean)','EXECUTE'),null;

select teste,passou,case when passou then null else detalhe end as detalhe
from adm01_canon_testes order by teste;
select count(*) filter(where passou) as passou,count(*) as total from adm01_canon_testes;
rollback;
