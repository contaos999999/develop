begin;
create table public.contratantes (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 tipo_pessoa text not null default 'juridica' check(tipo_pessoa in ('juridica','fisica','orgao_publico','outro')), documento text,
 razao_social text not null, nome_fantasia text, contato jsonb not null default '{}'::jsonb,
 situacao text not null default 'ativo' check(situacao in ('ativo','inativo')), versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(), constraint contratantes_id_org_uk unique(id,id_organizacao));
create unique index contratantes_org_documento_uidx on public.contratantes(id_organizacao, regexp_replace(documento,'\D','','g')) where documento is not null;
create index contratantes_org_nome_idx on public.contratantes(id_organizacao,razao_social);

create table public.contratos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contratante uuid not null, numero text not null, objeto text not null, tipo_contrato text, inicio date, fim date,
 valor_global numeric(18,2), periodicidade text default 'mensal', prazo_prestacao_dias integer,
 situacao text not null default 'rascunho' check(situacao in ('rascunho','ativo','suspenso','encerrado','cancelado')),
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint contratos_vigencia_ck check(fim is null or inicio is null or fim>=inicio), constraint contratos_org_numero_uk unique(id_organizacao,numero),
 constraint contratos_id_org_uk unique(id,id_organizacao),
 constraint contratos_contratante_org_fk foreign key(id_contratante,id_organizacao) references public.contratantes(id,id_organizacao));
create index contratos_contratante_idx on public.contratos(id_organizacao,id_contratante);
create index contratos_situacao_idx on public.contratos(id_organizacao,situacao);
create index contratos_vigencia_idx on public.contratos(id_organizacao,inicio,fim);

alter table public.vinculos_usuarios add constraint vinculos_usuarios_id_org_uk unique(id,id_organizacao);
alter table public.vinculos_usuario_contratos add column ativo boolean not null default true, add column revogado_em timestamptz;
alter table public.vinculos_usuario_contratos add constraint vinculos_usuario_contratos_vinculo_org_fk foreign key(id_vinculo_usuario,id_organizacao) references public.vinculos_usuarios(id,id_organizacao) on delete cascade;
alter table public.vinculos_usuario_contratos add constraint vinculos_usuario_contratos_contrato_org_fk foreign key(id_contrato,id_organizacao) references public.contratos(id,id_organizacao) on delete cascade;

create table public.versoes_contrato (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, numero_versao integer not null, snapshot jsonb not null, hash text not null,
 motivo text, criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now(),
 constraint versoes_contrato_uk unique(id_contrato,numero_versao));
create index versoes_contrato_org_contrato_idx on public.versoes_contrato(id_organizacao,id_contrato,numero_versao desc);

alter table public.contratantes enable row level security; alter table public.contratos enable row level security; alter table public.versoes_contrato enable row level security;
create trigger contratantes_touch before update on public.contratantes for each row execute function privado.tocar_atualizado_em();
create trigger contratos_touch before update on public.contratos for each row execute function privado.tocar_atualizado_em();
commit;
