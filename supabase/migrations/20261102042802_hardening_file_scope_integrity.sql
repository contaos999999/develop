alter table public.arquivos
  add constraint arquivos_id_organizacao_uk unique (id, id_organizacao);

alter table public.arquivos
  add constraint arquivos_id_organizacao_contrato_uk unique (id, id_organizacao, id_contrato);

alter table public.importacoes_financeiras
  add constraint importacoes_financeiras_arquivo_org_fk
  foreign key (id_arquivo, id_organizacao)
  references public.arquivos(id, id_organizacao)
  on delete restrict not valid;
alter table public.importacoes_financeiras validate constraint importacoes_financeiras_arquivo_org_fk;
alter table public.importacoes_financeiras
  add constraint importacoes_financeiras_arquivo_org_contrato_fk
  foreign key (id_arquivo, id_organizacao, id_contrato)
  references public.arquivos(id, id_organizacao, id_contrato)
  on delete restrict not valid;
alter table public.importacoes_financeiras validate constraint importacoes_financeiras_arquivo_org_contrato_fk;

alter table public.pareceres_contratante
  add constraint pareceres_contratante_arquivo_org_fk
  foreign key (id_arquivo, id_organizacao)
  references public.arquivos(id, id_organizacao)
  on delete restrict not valid;
alter table public.pareceres_contratante validate constraint pareceres_contratante_arquivo_org_fk;
alter table public.pareceres_contratante
  add constraint pareceres_contratante_arquivo_org_contrato_fk
  foreign key (id_arquivo, id_organizacao, id_contrato)
  references public.arquivos(id, id_organizacao, id_contrato)
  on delete restrict not valid;
alter table public.pareceres_contratante validate constraint pareceres_contratante_arquivo_org_contrato_fk;

alter table public.relatorios_historicos_contratante
  add constraint relatorios_historicos_arquivo_org_fk
  foreign key (id_arquivo, id_organizacao)
  references public.arquivos(id, id_organizacao)
  on delete restrict not valid;
alter table public.relatorios_historicos_contratante validate constraint relatorios_historicos_arquivo_org_fk;
alter table public.relatorios_historicos_contratante
  add constraint relatorios_historicos_arquivo_org_contrato_fk
  foreign key (id_arquivo, id_organizacao, id_contrato)
  references public.arquivos(id, id_organizacao, id_contrato)
  on delete restrict not valid;
alter table public.relatorios_historicos_contratante validate constraint relatorios_historicos_arquivo_org_contrato_fk;

alter table public.versoes_documento
  add constraint versoes_documento_arquivo_org_fk
  foreign key (id_arquivo, id_organizacao)
  references public.arquivos(id, id_organizacao)
  on delete restrict not valid;
alter table public.versoes_documento validate constraint versoes_documento_arquivo_org_fk;
alter table public.versoes_documento
  add constraint versoes_documento_arquivo_org_contrato_fk
  foreign key (id_arquivo, id_organizacao, id_contrato)
  references public.arquivos(id, id_organizacao, id_contrato)
  on delete restrict not valid;
alter table public.versoes_documento validate constraint versoes_documento_arquivo_org_contrato_fk;

alter table public.versoes_fontes_normativas
  add constraint versoes_fontes_normativas_arquivo_org_fk
  foreign key (id_arquivo, id_organizacao)
  references public.arquivos(id, id_organizacao)
  on delete restrict not valid;
alter table public.versoes_fontes_normativas validate constraint versoes_fontes_normativas_arquivo_org_fk;
alter table public.versoes_fontes_normativas
  add constraint versoes_fontes_normativas_arquivo_org_contrato_fk
  foreign key (id_arquivo, id_organizacao, id_contrato)
  references public.arquivos(id, id_organizacao, id_contrato)
  on delete restrict not valid;
alter table public.versoes_fontes_normativas validate constraint versoes_fontes_normativas_arquivo_org_contrato_fk;

create or replace function privado.solicitar_importacao_financeira(
  p_id_fonte uuid,
  p_id_arquivo uuid,
  p_hash text,
  p_chave_deduplicacao text
) returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_f public.fontes_financeiras%rowtype;
  v_arq public.arquivos%rowtype;
  v_imp uuid;
  v_exist uuid;
begin
  select * into v_f from public.fontes_financeiras where id=p_id_fonte;
  if v_f.id is null then raise exception 'Fonte financeira não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v_f.id_contrato)
     or not privado.usuario_possui_perfil(v_f.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])
  then raise exception 'Acesso negado.'; end if;

  select * into v_arq from public.arquivos where id=p_id_arquivo;
  if v_arq.id is null then raise exception 'Arquivo financeiro não encontrado.'; end if;
  if v_arq.id_organizacao is distinct from v_f.id_organizacao
     or v_arq.id_contrato is distinct from v_f.id_contrato
  then
    raise exception 'O arquivo informado não pertence à mesma organização e ao mesmo contrato da fonte financeira.';
  end if;
  if p_hash is null or p_hash !~ '^[0-9a-fA-F]{64}$' then
    raise exception 'Não foi possível confirmar a integridade do arquivo financeiro.';
  end if;
  if lower(p_hash) <> lower(v_arq.sha256) then
    raise exception 'O hash informado não corresponde ao arquivo financeiro confirmado.';
  end if;

  select id into v_exist
  from public.importacoes_financeiras
  where id_fonte=p_id_fonte and chave_deduplicacao=p_chave_deduplicacao;
  if v_exist is not null then return v_exist; end if;

  insert into public.importacoes_financeiras(
    id_organizacao,id_contrato,id_fonte,id_arquivo,hash,chave_deduplicacao,status,criado_por
  ) values(
    v_f.id_organizacao,v_f.id_contrato,v_f.id,p_id_arquivo,lower(p_hash),p_chave_deduplicacao,'pendente',auth.uid()
  ) returning id into v_imp;

  perform privado.enfileirar_job(
    'finance_imports',v_f.id_organizacao,v_f.id_contrato,'importacao_financeira',v_imp,
    jsonb_build_object('id_importacao',v_imp),'finance:'||v_imp::text
  );
  perform privado.registrar_evento_auditoria(
    v_f.id_organizacao,'ImportacaoFinanceiraSolicitada','importacoes_financeiras',v_imp,null,
    jsonb_build_object('id_fonte',v_f.id,'id_arquivo',p_id_arquivo)
  );
  return v_imp;
end;
$function$;
