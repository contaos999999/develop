-- ContaOS 4.1 — PROMPT 24 / V1-03 + NFR-007
-- Edição de contratante com versão esperada, PT409 e auditoria. Dados sintéticos; ROLLBACK integral.

begin;

create temporary table v103_testes(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select,insert on v103_testes to authenticated;

create or replace function pg_temp.tentar_atualizar(
  p_org uuid,
  p_id uuid,
  p_versao bigint,
  p_tipo text,
  p_documento text,
  p_razao text,
  p_fantasia text,
  p_contato jsonb,
  p_situacao text
) returns text language plpgsql security invoker set search_path=''
as $$
declare v jsonb;
begin
  execute 'select public.atualizar_contratante($1,$2,$3,$4,$5,$6,$7,$8,$9)'
    into v using p_org,p_id,p_versao,p_tipo,p_documento,p_razao,p_fantasia,p_contato,p_situacao;
  return 'OK:'||coalesce(v->>'schema_versao','')||':'||coalesce(v->'contratante'->>'versao_registro','');
exception when others then
  return sqlstate||':'||sqlerrm;
end $$;
grant execute on function pg_temp.tentar_atualizar(uuid,uuid,bigint,text,text,text,text,jsonb,text) to authenticated;

insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('b7030303-1111-4111-8111-111111111111','authenticated','authenticated','v103.admin@contaos.invalid','{}','{"nome":"V103 Admin"}',now(),now()),
('b7030303-2222-4222-8222-222222222222','authenticated','authenticated','v103.leitor@contaos.invalid','{}','{"nome":"V103 Leitor"}',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag) values
('b7030303-1111-4111-8111-aaaaaaaaaaaa','b7030303-1111-4111-8111-111111111111',now(),now(),'aal1',now()+interval '1 hour','v103-admin'),
('b7030303-2222-4222-8222-bbbbbbbbbbbb','b7030303-2222-4222-8222-222222222222',now(),now(),'aal1',now()+interval '1 hour','v103-leitor');

insert into public.organizacoes(id,razao_social,nome_fantasia,situacao) values
('b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Organização V103','Org V103','ativa'),
('b7030303-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Organização V103 B','Org V103 B','ativa');

insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo) values
('b7030303-1000-4000-8000-000000000001','b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7030303-1111-4111-8111-111111111111','administrador',true,true),
('b7030303-1000-4000-8000-000000000002','b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7030303-2222-4222-8222-222222222222','leitor',true,true);

insert into public.contratantes(id,id_organizacao,tipo_pessoa,documento,razao_social,nome_fantasia,contato,situacao) values
('b7030303-2000-4000-8000-000000000001','b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','juridica','11111111000191','Contratante V103 Original','Original','{"email":"antes@contaos.invalid"}','ativo'),
('b7030303-2000-4000-8000-000000000002','b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','juridica','22222222000192','Contratante V103 Segundo','Segundo','{}','ativo'),
('b7030303-2000-4000-8000-000000000003','b7030303-bbbb-4bbb-8bbb-bbbbbbbbbbbb','juridica','33333333000193','Contratante Outra Org','Outra','{}','ativo');

-- Contrato público/privado existe e privilégios mínimos.
insert into v103_testes values(
  '01 contrato RPC e privilégios',
  to_regprocedure('public.atualizar_contratante(uuid,uuid,bigint,text,text,text,text,jsonb,text)') is not null
  and has_function_privilege('authenticated','public.atualizar_contratante(uuid,uuid,bigint,text,text,text,text,jsonb,text)','EXECUTE')
  and not has_function_privilege('anon','public.atualizar_contratante(uuid,uuid,bigint,text,text,text,text,jsonb,text)','EXECUTE'),
  null
);

set local role authenticated;
select set_config('request.jwt.claim.sub','b7030303-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"b7030303-1111-4111-8111-111111111111","role":"authenticated","session_id":"b7030303-1111-4111-8111-aaaaaaaaaaaa","aal":"aal1"}',true);

-- Happy path: envia versão LIDA (=1); backend incrementa para 2.
with r as (
  select public.atualizar_contratante(
    'b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'b7030303-2000-4000-8000-000000000001',
    1,'orgao_publico','  44.444.444/0001-44  ','Contratante V103 Atualizado',null,
    '{"email":"depois@contaos.invalid","telefone":"75999999999"}'::jsonb,'inativo'
  ) j
)
insert into v103_testes
select '02 happy path incrementa server-side',
       j->>'schema_versao'='v103-v1'
       and j->'contratante'->>'razao_social'='Contratante V103 Atualizado'
       and (j->'contratante'->>'versao_registro')::bigint=2,
       j::text
from r;

insert into v103_testes
select '03 persistência preserva estrutura',
       id_organizacao='b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
       and versao_registro=2
       and tipo_pessoa='orgao_publico'
       and documento='44.444.444/0001-44'
       and razao_social='Contratante V103 Atualizado'
       and nome_fantasia is null
       and contato->>'email'='depois@contaos.invalid'
       and situacao='inativo',
       jsonb_build_object('versao',versao_registro,'org',id_organizacao,'razao',razao_social)::text
from public.contratantes where id='b7030303-2000-4000-8000-000000000001';

insert into v103_testes
select '04 auditoria material reduzida',
       count(*)=1
       and bool_and(antes->>'razao_social'='Contratante V103 Original')
       and bool_and(depois->>'razao_social'='Contratante V103 Atualizado')
       and bool_and((metadados->>'versao_anterior')::bigint=1)
       and bool_and((metadados->>'versao_nova')::bigint=2)
       and bool_and(not (coalesce(antes,'{}'::jsonb) ? 'contato'))
       and bool_and(not (coalesce(depois,'{}'::jsonb) ? 'contato')),
       jsonb_agg(jsonb_build_object('evento',evento,'antes',antes,'depois',depois,'meta',metadados))::text
from public.eventos_auditoria
where id_organizacao='b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  and entidade='contratantes'
  and id_entidade='b7030303-2000-4000-8000-000000000001'
  and evento='ContratanteAtualizado';

-- Stale: repete versão lida 1; deve 409 e não sobrescrever.
insert into v103_testes
select '05 stale gera PT409',left(r,5)='PT409',r
from (select pg_temp.tentar_atualizar(
  'b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7030303-2000-4000-8000-000000000001',1,
  'juridica','99999999000199','NÃO PODE SOBRESCREVER','X','{}','ativo') r) x;

insert into v103_testes
select '06 stale não altera nem audita',
       c.razao_social='Contratante V103 Atualizado' and c.versao_registro=2
       and (select count(*) from public.eventos_auditoria e where e.id_entidade=c.id and e.evento='ContratanteAtualizado')=1,
       jsonb_build_object('razao',c.razao_social,'versao',c.versao_registro)::text
from public.contratantes c where c.id='b7030303-2000-4000-8000-000000000001';

-- Duplicidade mantém constraint oficial.
insert into v103_testes
select '07 documento duplicado mantém 23505',left(r,5)='23505',r
from (select pg_temp.tentar_atualizar(
  'b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7030303-2000-4000-8000-000000000001',2,
  'juridica','22222222000192','Duplicado','X','{}','ativo') r) x;

-- Leitor não pode atualizar.
select set_config('request.jwt.claim.sub','b7030303-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claims','{"sub":"b7030303-2222-4222-8222-222222222222","role":"authenticated","session_id":"b7030303-2222-4222-8222-bbbbbbbbbbbb","aal":"aal1"}',true);
insert into v103_testes
select '08 leitor bloqueado',left(r,5)='42501' or left(r,5)='PT403',r
from (select pg_temp.tentar_atualizar(
  'b7030303-aaaa-4aaa-8aaa-aaaaaaaaaaaa','b7030303-2000-4000-8000-000000000002',1,
  'juridica','22222222000192','Leitor tentou','X','{}','ativo') r) x;

-- Admin da org A não pode usar id de org B nem descobrir/alterar registro.
select set_config('request.jwt.claim.sub','b7030303-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"b7030303-1111-4111-8111-111111111111","role":"authenticated","session_id":"b7030303-1111-4111-8111-aaaaaaaaaaaa","aal":"aal1"}',true);
insert into v103_testes
select '09 isolamento organização',left(r,5)='42501' or left(r,5)='PT403' or left(r,5)='PT404',r
from (select pg_temp.tentar_atualizar(
  'b7030303-bbbb-4bbb-8bbb-bbbbbbbbbbbb','b7030303-2000-4000-8000-000000000003',1,
  'juridica','33333333000193','Tentativa cruzada','X','{}','ativo') r) x;

reset role;

select teste,passou,detalhe from v103_testes order by teste;
select count(*) filter(where passou) as passou,count(*) as total,
       coalesce(jsonb_agg(teste order by teste) filter(where not passou),'[]'::jsonb) as falhas
from v103_testes;

rollback;
