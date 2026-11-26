begin;

alter table public.pareceres_contratante
  add column extracao_apontamentos_concluida_em timestamptz,
  add column extracao_apontamentos_sha256 text,
  add constraint pareceres_extracao_hash_ck check (
    (extracao_apontamentos_concluida_em is null and extracao_apontamentos_sha256 is null)
    or (extracao_apontamentos_concluida_em is not null
        and extracao_apontamentos_sha256 is not null
        and extracao_apontamentos_sha256 ~ '^[0-9a-f]{64}$')
  ),
  add constraint pareceres_apontamento_origem_uk
    unique (id, id_arquivo, id_ciclo, id_competencia, id_contrato, id_organizacao);

alter table public.apontamentos_contratante
  add column id_parecer_origem uuid,
  add column id_arquivo_origem uuid,
  add column sha256_arquivo_origem text,
  add constraint apontamentos_origem_completa_ck check (
    (id_parecer_origem is null and id_arquivo_origem is null and sha256_arquivo_origem is null)
    or (id_parecer_origem is not null and id_arquivo_origem is not null
        and sha256_arquivo_origem is not null and sha256_arquivo_origem ~ '^[0-9a-f]{64}$')
  ),
  add constraint apontamentos_parecer_origem_fk
    foreign key (id_parecer_origem, id_arquivo_origem, id_ciclo, id_competencia, id_contrato, id_organizacao)
    references public.pareceres_contratante (id, id_arquivo, id_ciclo, id_competencia, id_contrato, id_organizacao)
    on delete restrict on update restrict;

create index apontamentos_parecer_origem_idx
  on public.apontamentos_contratante (id_parecer_origem, id)
  where id_parecer_origem is not null;

create function privado.preservar_origem_apontamento()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (new.id_parecer_origem, new.id_arquivo_origem, new.sha256_arquivo_origem)
    is distinct from (old.id_parecer_origem, old.id_arquivo_origem, old.sha256_arquivo_origem)
  then
    raise exception 'A origem do apontamento é imutável.' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function privado.preservar_origem_apontamento() from public, anon, authenticated, service_role;

create trigger apontamentos_preservar_origem
  before update of id_parecer_origem, id_arquivo_origem, sha256_arquivo_origem
  on public.apontamentos_contratante
  for each row execute function privado.preservar_origem_apontamento();

create function public.registrar_extracao_apontamentos(
  p_id_parecer uuid,
  p_id_arquivo uuid,
  p_sha256 text,
  p_apontamentos jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  parecer public.pareceres_contratante%rowtype;
  v_ids jsonb;
  v_reutilizado boolean;
begin
  if p_id_parecer is null or p_id_arquivo is null or p_sha256 is null
     or p_sha256 !~ '^[0-9a-f]{64}$'
     or jsonb_typeof(p_apontamentos) is distinct from 'array'
  then
    raise exception 'Parâmetros da extração inválidos.' using errcode = '22023';
  end if;

  select p.* into parecer
  from public.pareceres_contratante p
  where p.id = p_id_parecer
  for update;

  if not found or parecer.id_ciclo is null or parecer.id_arquivo is distinct from p_id_arquivo
     or not exists (
       select 1 from public.ciclos_diligencia c
       where (c.id, c.id_competencia, c.id_contrato, c.id_organizacao) =
             (parecer.id_ciclo, parecer.id_competencia, parecer.id_contrato, parecer.id_organizacao)
     )
  then
    raise exception 'A origem da extração não corresponde ao registro autorizado.' using errcode = '22023';
  end if;

  perform 1 from public.arquivos a
  where (a.id, a.id_contrato, a.id_organizacao) =
        (p_id_arquivo, parecer.id_contrato, parecer.id_organizacao)
    and lower(a.sha256) = p_sha256
  for share;
  if not found then
    raise exception 'O arquivo e seu SHA-256 não correspondem à origem.' using errcode = '22023';
  end if;

  v_reutilizado := parecer.extracao_apontamentos_concluida_em is not null;

  if v_reutilizado then
    if parecer.extracao_apontamentos_sha256 is distinct from p_sha256 then
      raise exception 'O conteúdo registrado da origem mudou.' using errcode = '22023';
    end if;
  else
    insert into public.apontamentos_contratante (
      id_organizacao, id_contrato, id_competencia, id_ciclo,
      codigo, descricao, fundamento, status, severidade, fonte_pagina, fonte_trecho,
      valor_questionado, glosa_potencial, classificacao_sugerida, confianca_classificacao,
      id_parecer_origem, id_arquivo_origem, sha256_arquivo_origem
    )
    select parecer.id_organizacao, parecer.id_contrato, parecer.id_competencia, parecer.id_ciclo,
      item.codigo, item.descricao, item.fundamento, 'aberto', item.severidade, item.pagina, item.trecho,
      item.valor_questionado, item.glosa_potencial, 'pendente_analise', null,
      parecer.id, p_id_arquivo, p_sha256
    from jsonb_to_recordset(p_apontamentos) as item(
      codigo text, descricao text, fundamento text, severidade text, pagina integer, trecho text,
      valor_questionado numeric(18,2), glosa_potencial numeric(18,2)
    );

    update public.pareceres_contratante
    set extracao_apontamentos_concluida_em = transaction_timestamp(),
        extracao_apontamentos_sha256 = p_sha256
    where id = parecer.id;
  end if;

  select coalesce(jsonb_agg(item.id order by item.id), '[]'::jsonb) into v_ids
  from public.apontamentos_contratante item
  where item.id_parecer_origem = parecer.id;

  if not v_reutilizado then
    perform privado.registrar_evento_auditoria(
      parecer.id_organizacao, 'ApontamentosContratanteExtraidos', 'pareceres_contratante',
      parecer.id, null,
      jsonb_build_object('id_arquivo', p_id_arquivo, 'arquivo_sha256', p_sha256, 'ids_apontamentos', v_ids),
      jsonb_build_object('id_contrato', parecer.id_contrato, 'id_competencia', parecer.id_competencia,
                         'id_ciclo', parecer.id_ciclo)
    );
  end if;

  return jsonb_build_object(
    'apontamentos', jsonb_array_length(v_ids), 'ids_apontamentos', v_ids,
    'id_parecer', parecer.id, 'id_arquivo', p_id_arquivo, 'arquivo_sha256', p_sha256,
    'reutilizado', v_reutilizado
  );
end;
$$;

revoke all on function public.registrar_extracao_apontamentos(uuid, uuid, text, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.registrar_extracao_apontamentos(uuid, uuid, text, jsonb)
  to service_role;

create function public.obter_fonte_apontamento_contratante(
  p_id_ciclo uuid,
  p_id_apontamento uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'id_apontamento', item.id, 'id_ciclo', item.id_ciclo,
    'id_competencia', item.id_competencia, 'id_contrato', item.id_contrato,
    'id_organizacao', item.id_organizacao,
    'estado', case
      when item.id_parecer_origem is null then 'ORIGEM_NAO_REGISTRADA'
      when arquivo.id is null then 'ORIGEM_INDISPONIVEL'
      else 'REGISTRADA'
    end,
    'fonte', case when arquivo.id is not null then jsonb_build_object(
      'id_parecer', parecer.id, 'id_arquivo', arquivo.id, 'id_apresentacao', parecer.id_apresentacao,
      'nome_original', arquivo.nome_original, 'numero_documento', parecer.numero_documento,
      'arquivo_sha256', item.sha256_arquivo_origem, 'pagina', item.fonte_pagina, 'trecho', item.fonte_trecho
    ) end
  )
  from public.apontamentos_contratante item
  left join public.pareceres_contratante parecer
    on (parecer.id, parecer.id_arquivo, parecer.id_ciclo, parecer.id_competencia,
        parecer.id_contrato, parecer.id_organizacao) =
       (item.id_parecer_origem, item.id_arquivo_origem, item.id_ciclo, item.id_competencia,
        item.id_contrato, item.id_organizacao)
  left join public.arquivos arquivo
    on (arquivo.id, arquivo.id_contrato, arquivo.id_organizacao) =
       (parecer.id_arquivo, parecer.id_contrato, parecer.id_organizacao)
    and lower(arquivo.sha256) = item.sha256_arquivo_origem
  where item.id = p_id_apontamento and item.id_ciclo = p_id_ciclo;
$$;

revoke all on function public.obter_fonte_apontamento_contratante(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.obter_fonte_apontamento_contratante(uuid, uuid)
  to authenticated;

commit;
