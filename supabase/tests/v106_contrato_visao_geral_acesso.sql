-- ContaOS 4.1 — PROMPT 27 / V1-06 — classificação segura 403/404 do detalhe do contrato
-- TDD: este teste foi versionado antes da migration. Dados sintéticos; ROLLBACK integral.

begin;

create temporary table v106_resultados(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;
grant select, insert on v106_resultados to authenticated;

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('61000000-0000-4000-8000-000000000001','authenticated','authenticated','v106.escopo@invalid',now(),now()),
('61000000-0000-4000-8000-000000000002','authenticated','authenticated','v106.master@invalid',now(),now());

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,tag) values
('61100000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour','v106-escopo'),
('61100000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour','v106-master');

insert into public.organizacoes(id,razao_social) values
('62000000-0000-4000-8000-000000000001','V106 Organização A'),
('62000000-0000-4000-8000-000000000002','V106 Organização B');

insert into public.contratantes(id,id_organizacao,razao_social) values
('63000000-0000-4000-8000-000000000001','62000000-0000-4000-8000-000000000001','V106 Contratante A'),
('63000000-0000-4000-8000-000000000002','62000000-0000-4000-8000-000000000002','V106 Contratante B');

insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values
('64000000-0000-4000-8000-000000000001','62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000001','V106-A1','Contrato permitido','2026-01-01'),
('64000000-0000-4000-8000-000000000002','62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000001','V106-A2','Contrato mesmo tenant sem escopo','2026-01-01'),
('64000000-0000-4000-8000-000000000003','62000000-0000-4000-8000-000000000002','63000000-0000-4000-8000-000000000002','V106-B1','Contrato de outro tenant','2026-01-01');

insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo) values
('65000000-0000-4000-8000-000000000001','62000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000001','leitor',false,true);

insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo) values
('62000000-0000-4000-8000-000000000001','65000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001',true);

insert into privado.administradores_master(id_usuario,ativo,motivo) values
('61000000-0000-4000-8000-000000000002',true,'teste V1-06');

insert into v106_resultados values(
  '01 RPC somente authenticated',
  has_function_privilege('authenticated','public.classificar_acesso_contrato_v106(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.classificar_acesso_contrato_v106(uuid)','EXECUTE'),
  null
);

-- Usuário com vínculo na Org A e acesso explícito somente ao Contrato A1.
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"61000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"61100000-0000-4000-8000-000000000001","aal":"aal1"}',true);
set local role authenticated;

insert into v106_resultados
select '02 RLS lê contrato autorizado',count(*)=1,count(*)::text
from public.contratos where id='64000000-0000-4000-8000-000000000001';

insert into v106_resultados
select '03 RLS oculta contrato mesmo tenant sem escopo',count(*)=0,count(*)::text
from public.contratos where id='64000000-0000-4000-8000-000000000002';

insert into v106_resultados
select '04 classifica autorizado como permitido',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000001')='permitido',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000001');

insert into v106_resultados
select '05 mesmo tenant sem escopo vira negado',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000002')='negado',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000002');

insert into v106_resultados
select '06 inexistente vira nao_encontrado',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000099')='nao_encontrado',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000099');

insert into v106_resultados
select '07 contrato cross-tenant fica mascarado como nao_encontrado',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000003')='nao_encontrado',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000003');

insert into v106_resultados
select '08 contratante relacionado é legível no tenant ativo',count(*)=1,count(*)::text
from public.contratantes where id='63000000-0000-4000-8000-000000000001';
reset role;

-- Master sem vínculo físico continua vendo qualquer contrato.
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"61000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"61100000-0000-4000-8000-000000000002","aal":"aal1"}',true);
set local role authenticated;
insert into v106_resultados
select '09 Master classifica contrato B como permitido',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000003')='permitido',
  public.classificar_acesso_contrato_v106('64000000-0000-4000-8000-000000000003');
insert into v106_resultados
select '10 RLS Master lê contrato B',count(*)=1,count(*)::text
from public.contratos where id='64000000-0000-4000-8000-000000000003';
reset role;

select jsonb_build_object(
  'passou',count(*) filter(where passou),
  'falhou',count(*) filter(where not passou),
  'total',count(*),
  'itens',jsonb_agg(jsonb_build_object('teste',teste,'passou',passou,'detalhe',detalhe) order by teste)
) as resultado
from v106_resultados;

rollback;
