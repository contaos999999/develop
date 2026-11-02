-- ContaOS 4.1 — PROMPT 24 / V1-03
-- Operação oficial para edição de contratante com concorrência otimista e auditoria reduzida.

create or replace function privado.atualizar_contratante(
  p_id_organizacao uuid,
  p_id_contratante uuid,
  p_versao_esperada bigint,
  p_tipo_pessoa text,
  p_documento text,
  p_razao_social text,
  p_nome_fantasia text,
  p_contato jsonb,
  p_situacao text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_antes public.contratantes%rowtype;
  v_depois public.contratantes%rowtype;
  v_campos text[] := array[]::text[];
begin
  if auth.uid() is null then
    raise exception using
      errcode = '42501',
      message = 'Sua sessão não é válida para editar este contratante.';
  end if;

  if not privado.usuario_possui_perfil(
    p_id_organizacao,
    array['administrador','gestor_contrato']::text[]
  ) then
    raise exception using
      errcode = '42501',
      message = 'Você não tem permissão para editar contratantes nesta organização.';
  end if;

  if p_versao_esperada is null or p_versao_esperada < 1 then
    raise exception using
      errcode = 'PT422',
      message = 'A versão informada para edição é inválida.';
  end if;

  if nullif(trim(coalesce(p_razao_social,'')), '') is null then
    raise exception using
      errcode = 'PT422',
      message = 'Informe a razão social do contratante.';
  end if;

  select *
    into v_antes
    from public.contratantes
   where id = p_id_contratante
     and id_organizacao = p_id_organizacao
   for update;

  if not found then
    raise exception using
      errcode = 'PT404',
      message = 'Contratante não encontrado nesta organização.';
  end if;

  if v_antes.versao_registro <> p_versao_esperada then
    raise exception using
      errcode = 'PT409',
      message = 'Este contratante foi atualizado por outra pessoa. Recarregue os dados e revise suas alterações.';
  end if;

  update public.contratantes
     set tipo_pessoa = p_tipo_pessoa,
         documento = nullif(trim(coalesce(p_documento,'')), ''),
         razao_social = trim(p_razao_social),
         nome_fantasia = nullif(trim(coalesce(p_nome_fantasia,'')), ''),
         contato = coalesce(p_contato, '{}'::jsonb),
         situacao = p_situacao
   where id = p_id_contratante
     and id_organizacao = p_id_organizacao
  returning * into v_depois;

  if v_antes.tipo_pessoa is distinct from v_depois.tipo_pessoa then v_campos := array_append(v_campos,'tipo_pessoa'); end if;
  if v_antes.documento is distinct from v_depois.documento then v_campos := array_append(v_campos,'documento'); end if;
  if v_antes.razao_social is distinct from v_depois.razao_social then v_campos := array_append(v_campos,'razao_social'); end if;
  if v_antes.nome_fantasia is distinct from v_depois.nome_fantasia then v_campos := array_append(v_campos,'nome_fantasia'); end if;
  if v_antes.contato is distinct from v_depois.contato then v_campos := array_append(v_campos,'contato'); end if;
  if v_antes.situacao is distinct from v_depois.situacao then v_campos := array_append(v_campos,'situacao'); end if;

  perform privado.registrar_evento_auditoria(
    p_id_organizacao,
    'ContratanteAtualizado',
    'contratantes',
    p_id_contratante,
    jsonb_build_object(
      'tipo_pessoa', v_antes.tipo_pessoa,
      'razao_social', v_antes.razao_social,
      'nome_fantasia', v_antes.nome_fantasia,
      'situacao', v_antes.situacao,
      'versao_registro', v_antes.versao_registro
    ),
    jsonb_build_object(
      'tipo_pessoa', v_depois.tipo_pessoa,
      'razao_social', v_depois.razao_social,
      'nome_fantasia', v_depois.nome_fantasia,
      'situacao', v_depois.situacao,
      'versao_registro', v_depois.versao_registro
    ),
    jsonb_build_object(
      'versao_anterior', v_antes.versao_registro,
      'versao_nova', v_depois.versao_registro,
      'campos_alterados', to_jsonb(v_campos)
    )
  );

  return jsonb_build_object(
    'schema_versao', 'v103-v1',
    'contratante', jsonb_build_object(
      'id', v_depois.id,
      'id_organizacao', v_depois.id_organizacao,
      'tipo_pessoa', v_depois.tipo_pessoa,
      'documento', v_depois.documento,
      'razao_social', v_depois.razao_social,
      'nome_fantasia', v_depois.nome_fantasia,
      'contato', v_depois.contato,
      'situacao', v_depois.situacao,
      'versao_registro', v_depois.versao_registro,
      'atualizado_em', v_depois.atualizado_em
    )
  );
end;
$$;

revoke all on function privado.atualizar_contratante(uuid,uuid,bigint,text,text,text,text,jsonb,text) from public, anon, authenticated;
grant execute on function privado.atualizar_contratante(uuid,uuid,bigint,text,text,text,text,jsonb,text) to authenticated;

create or replace function public.atualizar_contratante(
  p_id_organizacao uuid,
  p_id_contratante uuid,
  p_versao_esperada bigint,
  p_tipo_pessoa text,
  p_documento text,
  p_razao_social text,
  p_nome_fantasia text,
  p_contato jsonb,
  p_situacao text
) returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select privado.atualizar_contratante($1,$2,$3,$4,$5,$6,$7,$8,$9)
$$;

revoke all on function public.atualizar_contratante(uuid,uuid,bigint,text,text,text,text,jsonb,text) from public, anon;
grant execute on function public.atualizar_contratante(uuid,uuid,bigint,text,text,text,text,jsonb,text) to authenticated;

comment on function public.atualizar_contratante(uuid,uuid,bigint,text,text,text,text,jsonb,text) is
'V1-03: edita contratante com versão esperada, conflito PT409, incremento server-side e auditoria reduzida.';
