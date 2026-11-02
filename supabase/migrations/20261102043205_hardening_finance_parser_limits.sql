alter table public.configuracao_upload
  add column if not exists max_linhas_planilha integer,
  add column if not exists max_colunas_planilha integer;

update public.configuracao_upload
set max_linhas_planilha = coalesce(max_linhas_planilha, 100000),
    max_colunas_planilha = coalesce(max_colunas_planilha, 200),
    atualizado_em = now()
where id = true;

alter table public.configuracao_upload
  alter column max_linhas_planilha set default 100000,
  alter column max_linhas_planilha set not null,
  alter column max_colunas_planilha set default 200,
  alter column max_colunas_planilha set not null;

alter table public.configuracao_upload
  add constraint configuracao_upload_max_linhas_planilha_ck
  check (max_linhas_planilha between 1 and 1000000) not valid;
alter table public.configuracao_upload
  validate constraint configuracao_upload_max_linhas_planilha_ck;

alter table public.configuracao_upload
  add constraint configuracao_upload_max_colunas_planilha_ck
  check (max_colunas_planilha between 1 and 10000) not valid;
alter table public.configuracao_upload
  validate constraint configuracao_upload_max_colunas_planilha_ck;
