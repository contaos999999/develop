-- Isolated synthetic schema. Never run against HML or PROD.
create schema auth;
create schema privado;
create role anon;
create role authenticated;
create role service_role;
create function public.fixture_id(n integer) returns uuid language sql immutable as $$
  select ('77000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('fixture.actor',true),'')::uuid
$$;
create function auth.role() returns text language sql stable as $$select 'authenticated'::text$$;
create table public.contratos(id uuid primary key,id_organizacao uuid not null,id_contratante uuid not null);
create table public.competencias(id uuid primary key,id_organizacao uuid not null,id_contrato uuid not null references public.contratos,competencia_referencia date not null,situacao text);
create table public.ciclos_diligencia(id uuid primary key,id_organizacao uuid not null,id_contrato uuid not null references public.contratos,id_competencia uuid not null references public.competencias,numero_rodada integer,status text);
create table public.apontamentos_contratante(id uuid primary key,id_organizacao uuid not null,id_contrato uuid not null references public.contratos,id_competencia uuid not null references public.competencias,id_ciclo uuid not null references public.ciclos_diligencia,descricao text not null,status text,versao_registro bigint default 1);
create table public.contestacoes(id uuid primary key,id_organizacao uuid not null,id_contrato uuid not null references public.contratos,id_competencia uuid not null references public.competencias,id_ciclo uuid not null references public.ciclos_diligencia,id_apontamento uuid not null references public.apontamentos_contratante,versao integer not null,texto text,status_aprovacao text,aprovado_por uuid,aprovado_em timestamptz,resultado_final text,resultado_registrado_em timestamptz,unique(id_apontamento,versao));
create table public.desfechos_apontamentos(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null,id_contrato uuid not null references public.contratos,id_competencia uuid not null references public.competencias,id_apontamento uuid not null references public.apontamentos_contratante,tipo_desfecho text not null,texto text,data date default current_date,criado_por uuid,criado_em timestamptz default now());
create table public.precedentes(id uuid primary key default gen_random_uuid(),id_organizacao uuid not null,id_contratante uuid not null,id_contrato_origem uuid references public.contratos,competencia_origem date,problema text,solucao text,desfecho text,fonte_tipo text,fonte_id uuid,confianca numeric(6,5) check(confianca between 0 and 1),status text,ultima_confirmacao_em timestamptz,confirmacoes integer default 1);
create table public.execucoes_assincronas(id uuid primary key default gen_random_uuid(),id_organizacao uuid,id_contrato uuid,fila text,entidade_tipo text,entidade_id uuid,payload jsonb,chave text unique);
create table public.eventos_auditoria(id uuid primary key default gen_random_uuid(),id_organizacao uuid,evento text,entidade text,id_entidade uuid,antes jsonb,depois jsonb,id_usuario uuid default auth.uid());
create table privado.fixture_vinculos(ator uuid,org uuid,contrato uuid,perfil text);
insert into privado.fixture_vinculos values
 (fixture_id(8),fixture_id(1),fixture_id(2),'gestor_contrato'),
 (fixture_id(7),fixture_id(1),fixture_id(2),'direcao_aprovador'),
 (fixture_id(6),fixture_id(1),fixture_id(2),'leitura');
create function privado.sessao_usuario_ativa() returns boolean language sql stable set search_path='' as $$
 select auth.uid() is not null and coalesce(current_setting('fixture.disabled',true),'')<>'true'
$$;
create function privado.usuario_tem_acesso_contrato(p_id_contrato uuid) returns boolean language sql stable security definer set search_path='' as $$
 select privado.sessao_usuario_ativa() and exists(select 1 from privado.fixture_vinculos v where v.ator=auth.uid() and v.contrato=p_id_contrato)
$$;
create function privado.usuario_possui_perfil(p_id_organizacao uuid,p_perfis text[]) returns boolean language sql stable security definer set search_path='' as $$
 select privado.sessao_usuario_ativa() and exists(select 1 from privado.fixture_vinculos v where v.ator=auth.uid() and v.org=p_id_organizacao and v.perfil=any(p_perfis))
$$;
create function privado.enfileirar_job(f text,o uuid,c uuid,t text,e uuid,p jsonb,k text) returns uuid language sql set search_path='' as $$
 insert into public.execucoes_assincronas(fila,id_organizacao,id_contrato,entidade_tipo,entidade_id,payload,chave)
 values(f,o,c,t,e,p,k) on conflict(chave) do update set chave=excluded.chave returning id
$$;
create function privado.registrar_evento_auditoria(o uuid,e text,t text,i uuid,a jsonb,d jsonb)
returns uuid language sql set search_path='' as $$
 insert into public.eventos_auditoria(id_organizacao,evento,entidade,id_entidade,antes,depois)
 values(o,e,t,i,a,d) returning id
$$;
insert into public.contratos values (fixture_id(2),fixture_id(1),fixture_id(4)),(fixture_id(3),fixture_id(1),fixture_id(4));
-- Separate items for every scenario, so the RED witnesses cannot pollute another case.
insert into public.competencias select fixture_id(100+n),fixture_id(1),fixture_id(case when n=1 then 3 else 2 end),date '2026-11-01','reapresentado' from generate_series(1,12) n;
insert into public.ciclos_diligencia select fixture_id(200+n),id_organizacao,id_contrato,id,1,'reapresentado' from public.competencias cross join lateral (select substring(id::text from 31)::integer-100 as n) s;
insert into public.apontamentos_contratante(id,id_organizacao,id_contrato,id_competencia,id_ciclo,descricao,status)
select fixture_id(300+n),id_organizacao,id_contrato,id_competencia,id,'Item sintético '||n,'contestado_aprovado'
from public.ciclos_diligencia cross join lateral (select substring(id::text from 31)::integer-200 as n) s;
insert into public.contestacoes(id,id_organizacao,id_contrato,id_competencia,id_ciclo,id_apontamento,versao,texto,status_aprovacao,aprovado_por,aprovado_em)
select fixture_id(400+n),id_organizacao,id_contrato,id_competencia,id_ciclo,id,1,'Manifestação sintética '||n,
 case when n=2 then 'rascunho' when n=3 then 'substituida' else 'aprovada' end,
 case when n in (2,4) then null else fixture_id(7) end,
 case when n in (2,4) then null else now() end
from public.apontamentos_contratante cross join lateral (select substring(id::text from 31)::integer-300 as n) s;
-- Deliberately contradictory legacy lineage: same tenant/contract, different competence/round.
update public.contestacoes set id_ciclo=fixture_id(206) where id=fixture_id(405);
-- Legacy final without a trustworthy link must not be silently replayed.
update public.contestacoes set resultado_final='aceita',resultado_registrado_em=now() where id=fixture_id(411);
insert into public.desfechos_apontamentos(id_organizacao,id_contrato,id_competencia,id_apontamento,tipo_desfecho,texto,criado_por)
values(fixture_id(1),fixture_id(2),fixture_id(111),fixture_id(311),'contestacao_aceita','Legado',fixture_id(8));
do $$
declare t text;
begin
 foreach t in array array['competencias','ciclos_diligencia','apontamentos_contratante','contestacoes','desfechos_apontamentos'] loop
   execute format('alter table public.%I enable row level security',t);
   execute format('create policy fixture_consultar on public.%I for select to authenticated using (privado.usuario_tem_acesso_contrato(id_contrato))',t);
   execute format('grant select on public.%I to authenticated',t);
 end loop;
end$$;
grant usage on schema auth,privado to authenticated;
revoke all on schema privado from public,anon;
