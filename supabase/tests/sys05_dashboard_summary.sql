-- ContaOS HML 4.1 - SYS-05 Dashboard summary
-- Prova SECURITY INVOKER, RLS por contrato e bloqueio de organização sem vínculo.
-- Dados sintéticos; transação termina em ROLLBACK.

begin;

create temporary table sys05_testes(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select, insert on sys05_testes to authenticated;

create or replace function pg_temp.tentar_resumo(p_org uuid)
returns text
language plpgsql
security invoker
set search_path=''
as $$
declare v jsonb;
begin
  v := public.obter_resumo_dashboard(p_org);
  return 'OK:' || coalesce(v->>'schema_versao','');
exception when others then
  return sqlstate || ':' || sqlerrm;
end;
$$;
grant execute on function pg_temp.tentar_resumo(uuid) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('c5c5c5c5-1111-4111-8111-111111111111','authenticated','authenticated','sys05.dashboard@contaos.invalid','{}','{"nome":"SYS05 Teste"}',now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag)
values('c5c5c5c5-1111-4111-8111-222222222222','c5c5c5c5-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour','sys05-dashboard-test');

insert into public.organizacoes(id,razao_social,nome_fantasia,situacao)
values
('c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização SYS05 Permitida','SYS05 Permitida','ativa'),
('c5c5c5c5-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Organização SYS05 Negada','SYS05 Negada','ativa');

insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
values('c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa','c5c5c5c5-1111-4111-8111-111111111111','gestor_contrato',false,true);

insert into public.contratantes(id,id_organizacao,razao_social,nome_fantasia)
values('c5c5c5c5-0000-4000-8000-000000000001','c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Contratante SYS05','Contratante SYS05');

insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio,situacao,criticidade)
values
('c5c5c5c5-1000-4000-8000-000000000001','c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa','c5c5c5c5-0000-4000-8000-000000000001','SYS05-A','Contrato permitido','2026-01-01','ativo','alta'),
('c5c5c5c5-1000-4000-8000-000000000002','c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa','c5c5c5c5-0000-4000-8000-000000000001','SYS05-B','Contrato fora do escopo','2026-01-01','ativo','critica');

insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo)
select 'c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa', vu.id, 'c5c5c5c5-1000-4000-8000-000000000001', true
from public.vinculos_usuarios vu
where vu.id_organizacao='c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and vu.id_usuario='c5c5c5c5-1111-4111-8111-111111111111';

insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,data_limite,situacao)
values
('c5c5c5c5-2000-4000-8000-000000000001','c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa','c5c5c5c5-1000-4000-8000-000000000001','2026-10-01','2026-10-01','2026-10-31','2026-10-31','em_analise'),
('c5c5c5c5-2000-4000-8000-000000000002','c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa','c5c5c5c5-1000-4000-8000-000000000002','2026-11-01','2026-11-01','2026-11-30','2026-11-30','em_analise');

set local role authenticated;
select set_config('request.jwt.claim.sub','c5c5c5c5-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"c5c5c5c5-1111-4111-8111-111111111111","role":"authenticated","session_id":"c5c5c5c5-1111-4111-8111-222222222222","aal":"aal1"}',true);

insert into sys05_testes
select 'Resumo autorizado retorna schema sys05-v1',
       public.obter_resumo_dashboard('c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->>'schema_versao'='sys05-v1',
       null;

insert into sys05_testes
select 'Resumo respeita escopo contratual',
       (r->'resumo'->>'contratos_visiveis')::int=1
       and (r->'resumo'->>'contratos_ativos')::int=1
       and (r->'resumo'->>'competencias_em_fluxo')::int=1,
       (r->'resumo')::text
from (select public.obter_resumo_dashboard('c5c5c5c5-aaaa-4aaa-8aaa-aaaaaaaaaaaa') r) x;

insert into sys05_testes
select 'Organização sem vínculo é bloqueada', left(r,5)='42501', r
from (select pg_temp.tentar_resumo('c5c5c5c5-bbbb-4bbb-8bbb-bbbbbbbbbbbb') r) x;

reset role;

insert into sys05_testes
select 'anon não possui EXECUTE',
       not has_function_privilege('anon','public.obter_resumo_dashboard(uuid)','EXECUTE'), null;
insert into sys05_testes
select 'authenticated possui EXECUTE',
       has_function_privilege('authenticated','public.obter_resumo_dashboard(uuid)','EXECUTE'), null;
insert into sys05_testes
select 'RPC é SECURITY INVOKER',
       not p.prosecdef, null
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='obter_resumo_dashboard';

select teste, passou, detalhe from sys05_testes order by teste;
rollback;
