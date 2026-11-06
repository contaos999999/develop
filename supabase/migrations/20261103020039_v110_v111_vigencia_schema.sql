begin;

alter table public.documentos_contrato
  add column if not exists vigencia_inicio date,
  add column if not exists vigencia_fim date,
  add column if not exists observacoes text;

alter table public.documentos_contrato drop constraint if exists documentos_contrato_vigencia_ck;
alter table public.documentos_contrato add constraint documentos_contrato_vigencia_ck
check ((vigencia_fim is null or vigencia_inicio is not null) and (vigencia_fim is null or vigencia_fim >= vigencia_inicio));
create index if not exists idx_documentos_contrato_vigencia on public.documentos_contrato(id_contrato,vigencia_inicio,vigencia_fim);

alter table public.sugestoes_extracao_documento
  add column if not exists vigencia_inicio date,
  add column if not exists vigencia_fim date;

alter table public.sugestoes_extracao_documento drop constraint if exists sugestoes_extracao_documento_vigencia_ck;
alter table public.sugestoes_extracao_documento add constraint sugestoes_extracao_documento_vigencia_ck
check ((vigencia_fim is null or vigencia_inicio is not null) and (vigencia_fim is null or vigencia_fim >= vigencia_inicio));
create index if not exists idx_sugestoes_extracao_documento_vigencia on public.sugestoes_extracao_documento(id_contrato,vigencia_inicio,vigencia_fim);

alter table public.regras_conformidade
  add column if not exists vigencia_inicio date,
  add column if not exists vigencia_fim date;

alter table public.regras_conformidade drop constraint if exists regras_conformidade_vigencia_ck;
alter table public.regras_conformidade add constraint regras_conformidade_vigencia_ck
check ((vigencia_fim is null or vigencia_inicio is not null) and (vigencia_fim is null or vigencia_fim >= vigencia_inicio));
create index if not exists idx_regras_conformidade_vigencia on public.regras_conformidade(id_contrato,vigencia_inicio,vigencia_fim);

commit;
