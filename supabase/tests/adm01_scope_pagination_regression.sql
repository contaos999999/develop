-- ContaOS 4.1 — ADM-01 regressão de escopo paginado
-- Garante que páginas não visitadas não perdem seleção e que vínculo novo pode listar contratos.
-- Dados sintéticos; ROLLBACK integral.

begin;

create temporary table adm01_scope_testes(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
create temporary table adm01_scope_resposta(r jsonb) on commit drop;
grant select, insert on adm01_scope_testes to authenticated;
grant select, insert, delete on adm01_scope_resposta to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('e2e2e2e2-0001-4000-8000-000000000001','authenticated','authenticated','adm01.scope.admin@contaos.invalid','{}','{}',now(),now()),
('e2e2e2e2-0002-4000-8000-000000000002','authenticated','authenticated','adm01.scope.target@contaos.invalid','{}','{}',now(),now()),
('e2e2e2e2-0003-4000-8000-000000000003','authenticated','authenticated','adm01.scope.new@contaos.invalid','{}','{}',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag)
values('e2e2e2e2-a001-4000-8000-000000000001','e2e2e2e2-0001-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour','adm01-scope-admin');

insert into public.organizacoes(id,razao_social,nome_fantasia,situacao)
values('e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização ADM01 Scope','ADM01 Scope','ativa');

insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
values
('e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa','e2e2e2e2-0001-4000-8000-000000000001','administrador',true,true),
('e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa','e2e2e2e2-0002-4000-8000-000000000002','leitor',false,true);

insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia)
values('e2e2e2e2-0100-4000-8000-000000000001','e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante ADM01 Scope','Contratante ADM01 Scope');

insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,situacao,criticidade)
values
('e2e2e2e2-1000-4000-8000-000000000001','e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa','e2e2e2e2-0100-4000-8000-000000000001','ADM01-S-001','Contrato 1','ativo','media'),
('e2e2e2e2-1000-4000-8000-000000000002','e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa','e2e2e2e2-0100-4000-8000-000000000001','ADM01-S-002','Contrato 2','ativo','media'),
('e2e2e2e2-1000-4000-8000-000000000003','e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa','e2e2e2e2-0100-4000-8000-000000000001','ADM01-S-003','Contrato 3','ativo','alta');

insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo)
select 'e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa',vu.id,'e2e2e2e2-1000-4000-8000-000000000003',true
from public.vinculos_usuarios vu
where vu.id_organizacao='e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and vu.id_usuario='e2e2e2e2-0002-4000-8000-000000000002';

set local role authenticated;
select set_config('request.jwt.claim.sub','e2e2e2e2-0001-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"e2e2e2e2-0001-4000-8000-000000000001","role":"authenticated","session_id":"e2e2e2e2-a001-4000-8000-000000000001","aal":"aal1"}',true);

insert into adm01_scope_testes
select 'Vínculo novo lista contratos com p_id_usuario null',
       (r->>'schema_versao')='adm01-v2'
       and (r->>'total')::int=3
       and jsonb_array_length(r->'itens')=1
       and (r->'itens'->0->>'selecionado')::boolean=false,
       r::text
from (
  select public.listar_escopo_contratos_usuario_adm(
    'e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,1,1,null
  ) r
) x;

-- Executa a mutação em um comando e verifica o estado no comando seguinte.
insert into adm01_scope_resposta
select public.salvar_vinculo_usuario_adm(
  'e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'e2e2e2e2-0002-4000-8000-000000000002',
  null,'leitor',false,true,
  array['e2e2e2e2-1000-4000-8000-000000000001'::uuid],
  array[]::uuid[],
  (select versao_registro from public.vinculos_usuarios where id_organizacao='e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and id_usuario='e2e2e2e2-0002-4000-8000-000000000002'),
  'adm01-scope-delta-001'
);

insert into adm01_scope_testes
select 'Delta preserva contrato selecionado em página não visitada',
       count(*) filter (where vc.ativo)=2
       and bool_or(vc.id_contrato='e2e2e2e2-1000-4000-8000-000000000001'::uuid and vc.ativo)
       and bool_or(vc.id_contrato='e2e2e2e2-1000-4000-8000-000000000003'::uuid and vc.ativo),
       string_agg(vc.id_contrato::text || ':' || vc.ativo::text,',' order by vc.id_contrato)
from public.vinculos_usuario_contratos vc
join public.vinculos_usuarios vu on vu.id=vc.id_vinculo_usuario
where vu.id_organizacao='e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and vu.id_usuario='e2e2e2e2-0002-4000-8000-000000000002';

delete from adm01_scope_resposta;
insert into adm01_scope_resposta
select public.salvar_vinculo_usuario_adm(
  'e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'e2e2e2e2-0002-4000-8000-000000000002',
  null,'leitor',false,true,
  array[]::uuid[],
  array['e2e2e2e2-1000-4000-8000-000000000001'::uuid],
  (select versao_registro from public.vinculos_usuarios where id_organizacao='e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and id_usuario='e2e2e2e2-0002-4000-8000-000000000002'),
  'adm01-scope-delta-002'
);

insert into adm01_scope_testes
select 'Revogação delta não afeta seleção não informada',
       count(*) filter (where vc.ativo)=1
       and bool_or(vc.id_contrato='e2e2e2e2-1000-4000-8000-000000000003'::uuid and vc.ativo)
       and bool_or(vc.id_contrato='e2e2e2e2-1000-4000-8000-000000000001'::uuid and not vc.ativo),
       string_agg(vc.id_contrato::text || ':' || vc.ativo::text,',' order by vc.id_contrato)
from public.vinculos_usuario_contratos vc
join public.vinculos_usuarios vu on vu.id=vc.id_vinculo_usuario
where vu.id_organizacao='e2e2e2e2-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and vu.id_usuario='e2e2e2-0002-4000-8000-000000000002';

reset role;
select teste,passou,detalhe from adm01_scope_testes order by teste;
rollback;
