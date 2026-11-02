-- ContaOS 4.1 — PROMPT 21 / ADM-01 + transversais 091/092/093/094
-- Contrato final ADM01-v2. Dados sintéticos; ROLLBACK integral.

begin;

create temporary table adm01_final_testes(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select,insert on adm01_final_testes to authenticated;

create or replace function pg_temp.tentar_lista(p_org uuid)
returns text language plpgsql security invoker set search_path=''
as $$ declare v jsonb; begin
  v:=public.listar_usuarios_vinculos_adm(p_org,1,25,null,null);
  return 'OK:'||coalesce(v->>'schema_versao','');
exception when others then return sqlstate||':'||sqlerrm; end $$;
grant execute on function pg_temp.tentar_lista(uuid) to authenticated;

create or replace function pg_temp.tentar_salvar(
  p_org uuid,p_user uuid,p_email text,p_perfil text,p_todos boolean,p_ativo boolean,
  p_ativar uuid[],p_revogar uuid[],p_versao bigint,p_chave text
) returns text language plpgsql security invoker set search_path=''
as $$ declare v jsonb; begin
  v:=public.salvar_vinculo_usuario_adm(p_org,p_user,p_email,p_perfil,p_todos,p_ativo,p_ativar,p_revogar,p_versao,p_chave);
  return 'OK:'||coalesce(v->>'schema_versao','')||':'||coalesce(v->'vinculo'->>'versao_registro','');
exception when others then return sqlstate||':'||sqlerrm; end $$;
grant execute on function pg_temp.tentar_salvar(uuid,uuid,text,text,boolean,boolean,uuid[],uuid[],bigint,text) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a6060606-1111-4111-8111-111111111111','authenticated','authenticated','adm01.finaladmin2@contaos.invalid','{}','{"nome":"ADM01 Final Admin 2"}',now(),now()),
('a6060606-2222-4222-8222-222222222222','authenticated','authenticated','adm01.finalleitor2@contaos.invalid','{}','{"nome":"ADM01 Final Leitor 2"}',now(),now()),
('a6060606-3333-4333-8333-333333333333','authenticated','authenticated','adm01.finalalvo2@contaos.invalid','{}','{"nome":"ADM01 Final Alvo 2"}',now(),now()),
('a6060606-4444-4444-8444-444444444444','authenticated','authenticated','adm01.finalrestrito2@contaos.invalid','{}','{"nome":"ADM01 Final Restrito 2"}',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag) values
('a6060606-1111-4111-8111-aaaaaaaaaaaa','a6060606-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour','adm01-final2-admin'),
('a6060606-2222-4222-8222-bbbbbbbbbbbb','a6060606-2222-4222-8222-222222222222',now(),now(),'aal1',now()+interval '1 hour','adm01-final2-leitor'),
('a6060606-4444-4444-8444-dddddddddddd','a6060606-4444-4444-8444-444444444444',now(),now(),'aal1',now()+interval '1 hour','adm01-final2-restrito');

insert into public.organizacoes(id,razao_social,nome_fantasia,situacao)
values('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização ADM01 Final 2','ADM01 Final 2','ativa');

insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo) values
('a6060606-1000-4000-8000-000000000001','a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-1111-4111-8111-111111111111','administrador',true,true),
('a6060606-1000-4000-8000-000000000002','a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-2222-4222-8222-222222222222','leitor',true,true),
('a6060606-1000-4000-8000-000000000004','a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-4444-4444-8444-444444444444','administrador',false,true);

insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia)
values('a6060606-2000-4000-8000-000000000001','a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante Final 2','Contratante Final 2');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio,situacao,criticidade) values
('a6060606-3000-4000-8000-000000000001','a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-2000-4000-8000-000000000001','FINAL2-C1','Permitido','2026-01-01','ativo','media'),
('a6060606-3000-4000-8000-000000000002','a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-2000-4000-8000-000000000001','FINAL2-C2','Segundo','2026-01-01','ativo','media');

insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo)
values('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-1000-4000-8000-000000000004','a6060606-3000-4000-8000-000000000001',true);

insert into public.eventos_auditoria(id_organizacao,id_usuario,evento,entidade,id_entidade,antes,depois,metadados) values(
'a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-1111-4111-8111-111111111111','VinculoUsuarioAdministrativoSalvo','vinculos_usuarios','a6060606-1000-4000-8000-000000000002',
jsonb_build_object('escopo_contratos',jsonb_build_array(jsonb_build_object('id_contrato','a6060606-3000-4000-8000-000000000002','ativo',true))),
jsonb_build_object('escopo_contratos',jsonb_build_array(jsonb_build_object('id_contrato','a6060606-3000-4000-8000-000000000002','ativo',false))),
jsonb_build_object('id_usuario','a6060606-3333-4333-8333-333333333333','ids_contratos_ativar',jsonb_build_array('a6060606-3000-4000-8000-000000000002'),'ids_contratos_revogar',jsonb_build_array('a6060606-3000-4000-8000-000000000001')));

set local role authenticated;
select set_config('request.jwt.claim.sub','a6060606-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"a6060606-1111-4111-8111-111111111111","role":"authenticated","session_id":"a6060606-1111-4111-8111-aaaaaaaaaaaa","aal":"aal1"}',true);

insert into adm01_final_testes values('01 administrador autorizado',public.validar_administrador_organizacao('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),null);

insert into adm01_final_testes
select '02 contratos uniformes adm01-v2',
       u->>'schema_versao'='adm01-v2' and e->>'schema_versao'='adm01-v2' and a->>'schema_versao'='adm01-v2',
       jsonb_build_object('usuarios',u->>'schema_versao','escopo',e->>'schema_versao','auditoria',a->>'schema_versao')::text
from (select public.listar_usuarios_vinculos_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,999,null,null) u,
             public.listar_escopo_contratos_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-2222-4222-8222-222222222222',1,999,null) e,
             public.listar_auditoria_vinculo_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-2222-4222-8222-222222222222',1,999) a) x;

insert into adm01_final_testes
select '03 paginação limitada',
       (u->>'tamanho_pagina')::int=100 and (e->>'tamanho_pagina')::int=100 and (a->>'tamanho_pagina')::int=50,
       jsonb_build_object('usuarios',u->>'tamanho_pagina','escopo',e->>'tamanho_pagina','auditoria',a->>'tamanho_pagina')::text
from (select public.listar_usuarios_vinculos_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,999,null,null) u,
             public.listar_escopo_contratos_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-2222-4222-8222-222222222222',1,999,null) e,
             public.listar_auditoria_vinculo_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-2222-4222-8222-222222222222',1,999) a) x;

with r as (
 select public.salvar_vinculo_usuario_adm(
   'a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'adm01.finalalvo2@contaos.invalid','gestor_contrato',false,true,
   array['a6060606-3000-4000-8000-000000000001'::uuid],array[]::uuid[],null,'adm01-final2-criar-001') j
)
insert into adm01_final_testes
select '04 vincula conta existente por email',j->>'schema_versao'='adm01-v2' and j->>'id_usuario'='a6060606-3333-4333-8333-333333333333' and j->'vinculo'->>'perfil'='gestor_contrato',j::text from r;

insert into adm01_final_testes
select '05 escopo vem da API com seleção real',(r->>'total')::int=2 and exists(select 1 from jsonb_array_elements(r->'itens') e where e->>'numero'='FINAL2-C1' and (e->>'selecionado')::boolean=true) and exists(select 1 from jsonb_array_elements(r->'itens') e where e->>'numero'='FINAL2-C2' and (e->>'selecionado')::boolean=false),r::text
from (select public.listar_escopo_contratos_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-3333-4333-8333-333333333333',1,25,null) r) x;

with r as (
 select public.salvar_vinculo_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'adm01.finalalvo2@contaos.invalid','gestor_contrato',false,true,array['a6060606-3000-4000-8000-000000000001'::uuid],array[]::uuid[],null,'adm01-final2-criar-001') j
), c as (
 select count(*) n from public.comandos_idempotentes where id_organizacao='a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and comando='adm01.salvar_vinculo_usuario.v2' and chave='adm01-final2-criar-001'
), a as (
 select count(*) n from public.eventos_auditoria where id_organizacao='a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and evento='VinculoUsuarioAdministrativoSalvo' and metadados->>'id_usuario'='a6060606-3333-4333-8333-333333333333' and metadados->>'chave_idempotencia'='adm01-final2-criar-001'
)
insert into adm01_final_testes
select '06 replay idempotente sem duplicar efeito',(select n from c)=1 and (select n from a)=1 and r.j->>'schema_versao'='adm01-v2',r.j::text from r;

insert into adm01_final_testes
select '07 mesma chave com payload diferente gera 409',left(r,5)='PT409',r
from (select pg_temp.tentar_salvar('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'adm01.finalalvo2@contaos.invalid','auditor',false,true,array['a6060606-3000-4000-8000-000000000001'::uuid],array[]::uuid[],null,'adm01-final2-criar-001') r) x;

insert into adm01_final_testes
select '08 versão stale gera 409',left(r,5)='PT409',r
from (select pg_temp.tentar_salvar('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-3333-4333-8333-333333333333',null,'auditor',false,true,array[]::uuid[],array[]::uuid[],0,'adm01-final2-stale-001') r) x;

with atual as (
 select versao_registro from public.vinculos_usuarios where id_organizacao='a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and id_usuario='a6060606-3333-4333-8333-333333333333'
), r as (
 select public.salvar_vinculo_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-3333-4333-8333-333333333333',null,'auditor',false,true,array['a6060606-3000-4000-8000-000000000002'::uuid],array['a6060606-3000-4000-8000-000000000001'::uuid],(select versao_registro from atual),'adm01-final2-troca-001') j
)
insert into adm01_final_testes
select '09 edição atômica ativa C2 e revoga C1',j->>'schema_versao'='adm01-v2' and j->'vinculo'->>'perfil'='auditor' and (j->'vinculo'->>'versao_registro')::bigint>(select versao_registro from atual),j::text from r;

insert into adm01_final_testes
select '10 escopo reflete delta aplicado',exists(select 1 from jsonb_array_elements(r->'itens') e where e->>'numero'='FINAL2-C1' and (e->>'selecionado')::boolean=false) and exists(select 1 from jsonb_array_elements(r->'itens') e where e->>'numero'='FINAL2-C2' and (e->>'selecionado')::boolean=true),r::text
from (select public.listar_escopo_contratos_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-3333-4333-8333-333333333333',1,25,null) r) x;

insert into adm01_final_testes
select '11 auditoria v2 registra alteração',r->>'schema_versao'='adm01-v2' and jsonb_array_length(r->'itens')>=3,r::text
from (select public.listar_auditoria_vinculo_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-3333-4333-8333-333333333333',1,50) r) x;

select set_config('request.jwt.claim.sub','a6060606-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"a6060606-2222-4222-8222-222222222222","role":"authenticated","session_id":"a6060606-2222-4222-8222-bbbbbbbbbbbb","aal":"aal1"}',true);
insert into adm01_final_testes
select '12 não-admin recebe 403 real',left(r,5)='42501',r from (select pg_temp.tentar_lista('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa') r) x;

select set_config('request.jwt.claim.sub','a6060606-4444-4444-8444-444444444444',true);
select set_config('request.jwt.claims','{"sub":"a6060606-4444-4444-8444-444444444444","role":"authenticated","session_id":"a6060606-4444-4444-8444-dddddddddddd","aal":"aal1"}',true);
insert into adm01_final_testes
select '13 admin restrito vê somente C1',(r->>'total')::int=1 and r->'itens'->0->>'numero'='FINAL2-C1',r::text
from (select public.listar_escopo_contratos_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-3333-4333-8333-333333333333',1,25,null) r) x;

with atual as (
 select versao_registro from public.vinculos_usuarios where id_organizacao='a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and id_usuario='a6060606-3333-4333-8333-333333333333'
)
insert into adm01_final_testes
select '14 admin restrito não altera nem descobre C2',left(salvar,5) in ('PT400','42501') and not (auditoria::text like '%a6060606-3000-4000-8000-000000000002%'),jsonb_build_object('salvar',salvar,'auditoria',auditoria)::text
from (
 select pg_temp.tentar_salvar('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-3333-4333-8333-333333333333',null,'auditor',false,true,array['a6060606-3000-4000-8000-000000000002'::uuid],array[]::uuid[],(select versao_registro from atual),'adm01-final2-negado-001') salvar,
        public.listar_auditoria_vinculo_usuario_adm('a6060606-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a6060606-3333-4333-8333-333333333333',1,50) auditoria
) x;

reset role;
insert into adm01_final_testes
select '15 privilégios finais mínimos',
 not has_function_privilege('anon','public.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean)','EXECUTE')
 and not has_function_privilege('anon','public.listar_escopo_contratos_usuario_adm(uuid,uuid,integer,integer,text)','EXECUTE')
 and not has_function_privilege('anon','public.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer)','EXECUTE')
 and not has_function_privilege('anon','public.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],uuid[],bigint,text)','EXECUTE')
 and not has_function_privilege('authenticated','public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean)','EXECUTE')
 and not has_function_privilege('authenticated','public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean)','EXECUTE'),null;

select count(*) filter(where passou) as passou,count(*) as total,
       coalesce(jsonb_agg(jsonb_build_object('teste',teste,'detalhe',detalhe)) filter(where not passou),'[]'::jsonb) as falhas
from adm01_final_testes;

rollback;
