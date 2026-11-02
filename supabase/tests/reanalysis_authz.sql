-- ContaOS HML 4.1 - regressão de autorização da reanálise incremental
-- Garante que autorização ocorra antes da validação de requisitos,
-- impedindo enumeração de IDs entre contratos e replay após revogação da sessão.
-- Dados sintéticos; transação termina em ROLLBACK.

begin;

create temporary table reanalysis_authz_test(
  chave text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select,insert on reanalysis_authz_test to authenticated;

create or replace function pg_temp.tentar_reanalise_publica(p_comp uuid,p_req uuid)
returns text
language plpgsql
security invoker
set search_path=''
as $$
begin
  perform public.solicitar_reanalise_requisitos(p_comp,array[p_req]::uuid[]);
  return 'SEM_ERRO';
exception when others then
  return sqlstate||':'||sqlerrm;
end;
$$;

grant execute on function pg_temp.tentar_reanalise_publica(uuid,uuid) to authenticated;

create or replace function pg_temp.tentar_reanalise_privada(p_comp uuid,p_req uuid)
returns text
language plpgsql
security invoker
set search_path=''
as $$
begin
  perform privado.solicitar_reanalise_requisitos(p_comp,array[p_req]::uuid[]);
  return 'SEM_ERRO';
exception when others then
  return sqlstate||':'||sqlerrm;
end;
$$;

grant execute on function pg_temp.tentar_reanalise_privada(uuid,uuid) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values(
  '76111111-1111-4111-8111-111111111111',
  'authenticated','authenticated','reanalysis.authz@contaos.invalid','{}','{}',now(),now()
);

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values(
  '76aaaaaa-1111-4111-8111-111111111111',
  '76111111-1111-4111-8111-111111111111',
  now(),now(),'aal1',now()+interval '1 hour'
);

insert into public.organizacoes(id,razao_social,nome_fantasia)
values('76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização Reanálise Authz','Reanálise Authz');

insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
values('76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','76111111-1111-4111-8111-111111111111','gestor_contrato',false,true);

insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia)
values('76aaaaaa-0000-4000-8000-000000000001','76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante Reanálise','Contratante Reanálise');

insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio,situacao)
values
('76aaaaaa-1000-4000-8000-000000000001','76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','76aaaaaa-0000-4000-8000-000000000001','RA-A','Contrato permitido','2026-01-01','ativo'),
('76aaaaaa-1000-4000-8000-000000000002','76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','76aaaaaa-0000-4000-8000-000000000001','RA-B','Contrato bloqueado','2026-01-01','ativo');

insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo)
select '76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',vu.id,'76aaaaaa-1000-4000-8000-000000000001',true
from public.vinculos_usuarios vu
where vu.id_organizacao='76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and vu.id_usuario='76111111-1111-4111-8111-111111111111';

insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao)
values
('76aaaaaa-2000-4000-8000-000000000001','76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','76aaaaaa-1000-4000-8000-000000000001','2026-10-01','2026-10-01','2026-10-31','rascunho'),
('76aaaaaa-2000-4000-8000-000000000002','76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','76aaaaaa-1000-4000-8000-000000000002','2026-11-01','2026-11-01','2026-11-30','rascunho');

insert into public.requisitos_competencia(
  id,id_organizacao,id_contrato,id_competencia,origem_tipo,codigo,descricao,hash_snapshot
)
values
('76aaaaaa-3000-4000-8000-000000000001','76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','76aaaaaa-1000-4000-8000-000000000001','76aaaaaa-2000-4000-8000-000000000001','manual','REQ-A','Requisito permitido',md5('req-a')),
('76aaaaaa-3000-4000-8000-000000000002','76aaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','76aaaaaa-1000-4000-8000-000000000002','76aaaaaa-2000-4000-8000-000000000002','manual','REQ-B','Requisito bloqueado',md5('req-b'));

set local role authenticated;
select set_config('request.jwt.claim.sub','76111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"76111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"76aaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',
  true
);

insert into reanalysis_authz_test
select 'publica_real_outro_contrato_bloqueada',
       r='42501:Você não possui acesso à competência informada.',r
from (select pg_temp.tentar_reanalise_publica(
  '76aaaaaa-2000-4000-8000-000000000002',
  '76aaaaaa-3000-4000-8000-000000000002'
) r) x;

insert into reanalysis_authz_test
select 'publica_inexistente_outro_contrato_mesmo_erro',
       r='42501:Você não possui acesso à competência informada.',r
from (select pg_temp.tentar_reanalise_publica(
  '76aaaaaa-2000-4000-8000-000000000002',
  '76fffff0-3000-4000-8000-000000000099'
) r) x;

insert into reanalysis_authz_test
select 'privada_real_outro_contrato_bloqueada',
       r='42501:Você não possui acesso à competência informada.',r
from (select pg_temp.tentar_reanalise_privada(
  '76aaaaaa-2000-4000-8000-000000000002',
  '76aaaaaa-3000-4000-8000-000000000002'
) r) x;

reset role;
delete from auth.sessions where id='76aaaaaa-1111-4111-8111-111111111111';

set local role authenticated;
select set_config('request.jwt.claim.sub','76111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"76111111-1111-4111-8111-111111111111","role":"authenticated","session_id":"76aaaaaa-1111-4111-8111-111111111111","aal":"aal1"}',
  true
);

insert into reanalysis_authz_test
select 'jwt_replay_apos_revogacao_bloqueado',
       r='42501:Você não possui acesso à competência informada.',r
from (select pg_temp.tentar_reanalise_publica(
  '76aaaaaa-2000-4000-8000-000000000001',
  '76aaaaaa-3000-4000-8000-000000000001'
) r) x;

reset role;

insert into reanalysis_authz_test
select 'nenhuma_execucao_criada_por_tentativas_bloqueadas',
       count(*)=0,'execucoes='||count(*)
from public.execucoes_analise
where id_competencia in (
  '76aaaaaa-2000-4000-8000-000000000001',
  '76aaaaaa-2000-4000-8000-000000000002'
);

select chave,passou,detalhe from reanalysis_authz_test order by chave;
rollback;
