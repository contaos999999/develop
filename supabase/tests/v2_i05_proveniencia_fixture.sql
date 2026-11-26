-- PostgreSQL descartável para CODE, apenas identidades e documentos sintéticos.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema privado;
grant usage on schema public, privado to anon, authenticated, service_role;

create table public.ciclos_diligencia (
  id uuid primary key,
  id_organizacao uuid not null,
  id_contrato uuid not null,
  id_competencia uuid not null
);
create table public.arquivos (
  id uuid primary key,
  id_organizacao uuid not null,
  id_contrato uuid,
  sha256 text not null,
  nome_original text not null
);
create table public.pareceres_contratante (
  id uuid primary key,
  id_organizacao uuid not null,
  id_contrato uuid not null,
  id_competencia uuid not null,
  id_ciclo uuid references public.ciclos_diligencia,
  id_apresentacao uuid,
  id_arquivo uuid not null references public.arquivos,
  numero_documento text
);
create table public.apontamentos_contratante (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null,
  id_contrato uuid not null,
  id_competencia uuid not null,
  id_ciclo uuid not null references public.ciclos_diligencia,
  codigo text,
  descricao text not null,
  fundamento text,
  severidade text not null check (severidade in ('baixa','media','alta','critica')),
  fonte_pagina integer,
  fonte_trecho text,
  valor_questionado numeric(18,2),
  glosa_potencial numeric(18,2),
  classificacao_sugerida text,
  confianca_classificacao numeric(6,5),
  status text not null default 'aberto'
);
create table public.eventos_auditoria (
  id_organizacao uuid not null,
  evento text not null,
  entidade text not null,
  id_entidade uuid not null,
  antes jsonb,
  depois jsonb,
  metadados jsonb
);
create function privado.registrar_evento_auditoria(
  uuid,text,text,uuid,jsonb,jsonb,jsonb
) returns void language sql set search_path = '' as $$
  insert into public.eventos_auditoria values ($1,$2,$3,$4,$5,$6,$7)
$$;
revoke all on function privado.registrar_evento_auditoria(uuid,text,text,uuid,jsonb,jsonb,jsonb) from public, anon, authenticated, service_role;

do $$
declare rel text;
begin
  foreach rel in array array['ciclos_diligencia','apontamentos_contratante','pareceres_contratante','arquivos'] loop
    execute format('alter table public.%I enable row level security', rel);
    execute format('grant select on public.%I to authenticated,service_role', rel);
    execute format('create policy fixture_select on public.%I for select to authenticated using
      (id_organizacao::text = current_setting(''contaos.fixture.org'', true))', rel);
  end loop;
end $$;
grant select, insert, update on public.apontamentos_contratante to service_role;

insert into public.ciclos_diligencia values
('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000301'),
('00000000-0000-4000-8000-000000000402','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000302');
insert into public.arquivos
select ('00000000-0000-4000-8000-00000000050' || n)::uuid,
       '00000000-0000-4000-8000-000000000101'::uuid,
       '00000000-0000-4000-8000-000000000201'::uuid, repeat(chr(96+n),64), 'Parecer sintético ' || n
from generate_series(1,5) as n;
insert into public.pareceres_contratante
select ('00000000-0000-4000-8000-00000000060' || n)::uuid,
       '00000000-0000-4000-8000-000000000101'::uuid,
       '00000000-0000-4000-8000-000000000201'::uuid,
       '00000000-0000-4000-8000-000000000301'::uuid,
       '00000000-0000-4000-8000-000000000401'::uuid,
       null, ('00000000-0000-4000-8000-00000000050' || n)::uuid, 'I05-' || n
from generate_series(1,5) as n;
insert into public.apontamentos_contratante
(id, id_organizacao, id_contrato, id_competencia, id_ciclo, descricao, severidade)
values ('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000101',
'00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000301',
'00000000-0000-4000-8000-000000000401','Registro histórico sem vínculo conhecido','media');
