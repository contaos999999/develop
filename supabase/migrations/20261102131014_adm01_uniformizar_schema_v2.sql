-- ContaOS HML 4.1 — ADM-01
-- Uniformiza o contrato de resposta das RPCs canônicas em adm01-v2.

create or replace function privado.listar_usuarios_vinculos_adm(
  p_id_organizacao uuid,
  p_pagina integer default 1,
  p_tamanho_pagina integer default 25,
  p_busca text default null,
  p_ativo boolean default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pagina integer := greatest(coalesce(p_pagina, 1), 1);
  v_tamanho integer := least(greatest(coalesce(p_tamanho_pagina, 25), 1), 100);
  v_offset integer;
  v_busca text := nullif(lower(pg_catalog.btrim(coalesce(p_busca, ''))), '');
  v_total bigint;
  v_itens jsonb;
  v_perfis jsonb;
begin
  perform privado.validar_administrador_organizacao(p_id_organizacao);
  v_offset := (v_pagina - 1) * v_tamanho;

  select count(*) into v_total
  from public.vinculos_usuarios vu
  join public.usuarios u on u.id_usuario = vu.id_usuario
  where vu.id_organizacao = p_id_organizacao
    and (p_ativo is null or vu.ativo = p_ativo)
    and (
      v_busca is null
      or lower(coalesce(u.nome, '') || ' ' || coalesce(u.email, '') || ' ' || coalesce(vu.perfil, '')) like '%' || v_busca || '%'
    );

  select coalesce(jsonb_agg(x.item order by x.ordem_nome, x.ordem_email, x.id_usuario), '[]'::jsonb)
    into v_itens
  from (
    select
      lower(coalesce(u.nome, u.email, '')) as ordem_nome,
      lower(coalesce(u.email, '')) as ordem_email,
      u.id_usuario,
      jsonb_build_object(
        'id_usuario', u.id_usuario,
        'nome', u.nome,
        'email', u.email,
        'telefone', u.telefone,
        'situacao_usuario', u.situacao,
        'vinculo', jsonb_build_object(
          'id', vu.id,
          'perfil', vu.perfil,
          'escopo_todos_contratos', vu.escopo_todos_contratos,
          'ativo', vu.ativo,
          'inicio_em', vu.inicio_em,
          'fim_em', vu.fim_em,
          'versao_registro', vu.versao_registro,
          'atualizado_em', vu.atualizado_em
        )
      ) as item
    from public.vinculos_usuarios vu
    join public.usuarios u on u.id_usuario = vu.id_usuario
    where vu.id_organizacao = p_id_organizacao
      and (p_ativo is null or vu.ativo = p_ativo)
      and (
        v_busca is null
        or lower(coalesce(u.nome, '') || ' ' || coalesce(u.email, '') || ' ' || coalesce(vu.perfil, '')) like '%' || v_busca || '%'
      )
    order by lower(coalesce(u.nome, u.email, '')), lower(coalesce(u.email, '')), u.id_usuario
    limit v_tamanho offset v_offset
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object('codigo', p.codigo, 'nome', p.nome, 'descricao', p.descricao) order by p.nome, p.codigo), '[]'::jsonb)
    into v_perfis
  from public.perfis_usuarios p;

  return jsonb_build_object(
    'schema_versao', 'adm01-v2',
    'pagina', v_pagina,
    'tamanho_pagina', v_tamanho,
    'total', v_total,
    'total_paginas', case when v_total = 0 then 0 else pg_catalog.ceil(v_total::numeric / v_tamanho)::integer end,
    'itens', v_itens,
    'perfis_disponiveis', v_perfis
  );
end;
$$;

create or replace function privado.listar_auditoria_vinculo_usuario_adm(
  p_id_organizacao uuid,
  p_id_usuario uuid,
  p_pagina integer default 1,
  p_tamanho_pagina integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pagina integer := greatest(coalesce(p_pagina, 1), 1);
  v_tamanho integer := least(greatest(coalesce(p_tamanho_pagina, 20), 1), 50);
  v_offset integer;
  v_total bigint;
  v_itens jsonb;
begin
  perform privado.validar_administrador_organizacao(p_id_organizacao);

  if not exists (
    select 1
    from public.vinculos_usuarios vu
    where vu.id_organizacao = p_id_organizacao
      and vu.id_usuario = p_id_usuario
  ) then
    raise sqlstate 'PT404' using
      message = 'Vínculo de usuário não encontrado nesta organização.',
      hint = 'Atualize a lista e tente novamente.';
  end if;

  v_offset := (v_pagina - 1) * v_tamanho;

  select count(*) into v_total
  from public.eventos_auditoria e
  where e.id_organizacao = p_id_organizacao
    and e.entidade in ('vinculos_usuarios','vinculos_usuario_contratos')
    and e.metadados->>'id_usuario' = p_id_usuario::text
    and (
      e.entidade <> 'vinculos_usuario_contratos'
      or privado.uuid_seguro(e.metadados->>'id_contrato') is null
      or privado.usuario_tem_acesso_contrato(privado.uuid_seguro(e.metadados->>'id_contrato'))
    );

  select coalesce(jsonb_agg(x.item order by x.criado_em desc, x.id desc), '[]'::jsonb)
    into v_itens
  from (
    select e.criado_em, e.id,
      jsonb_build_object(
        'id', e.id,
        'correlation_id', e.correlation_id,
        'evento', e.evento,
        'entidade', e.entidade,
        'id_entidade', e.id_entidade,
        'id_usuario_ator', e.id_usuario,
        'ator_nome', ua.nome,
        'ator_email', ua.email,
        'antes',
          case
            when jsonb_typeof(e.antes->'escopo_contratos') = 'array' then
              jsonb_set(
                e.antes,
                '{escopo_contratos}',
                coalesce((
                  select jsonb_agg(j.elem order by j.elem->>'id_contrato')
                  from jsonb_array_elements(e.antes->'escopo_contratos') as j(elem)
                  where privado.uuid_seguro(j.elem->>'id_contrato') is not null
                    and privado.usuario_tem_acesso_contrato(privado.uuid_seguro(j.elem->>'id_contrato'))
                ), '[]'::jsonb),
                true
              )
            else e.antes
          end,
        'depois',
          case
            when jsonb_typeof(e.depois->'escopo_contratos') = 'array' then
              jsonb_set(
                e.depois,
                '{escopo_contratos}',
                coalesce((
                  select jsonb_agg(j.elem order by j.elem->>'id_contrato')
                  from jsonb_array_elements(e.depois->'escopo_contratos') as j(elem)
                  where privado.uuid_seguro(j.elem->>'id_contrato') is not null
                    and privado.usuario_tem_acesso_contrato(privado.uuid_seguro(j.elem->>'id_contrato'))
                ), '[]'::jsonb),
                true
              )
            else e.depois
          end,
        'metadados',
          case
            when privado.uuid_seguro(e.metadados->>'id_contrato') is not null
             and not privado.usuario_tem_acesso_contrato(privado.uuid_seguro(e.metadados->>'id_contrato'))
              then e.metadados - 'id_contrato'
            else e.metadados
          end,
        'criado_em', e.criado_em
      ) as item
    from public.eventos_auditoria e
    left join public.usuarios ua on ua.id_usuario = e.id_usuario
    where e.id_organizacao = p_id_organizacao
      and e.entidade in ('vinculos_usuarios','vinculos_usuario_contratos')
      and e.metadados->>'id_usuario' = p_id_usuario::text
      and (
        e.entidade <> 'vinculos_usuario_contratos'
        or privado.uuid_seguro(e.metadados->>'id_contrato') is null
        or privado.usuario_tem_acesso_contrato(privado.uuid_seguro(e.metadados->>'id_contrato'))
      )
    order by e.criado_em desc, e.id desc
    limit v_tamanho offset v_offset
  ) x;

  return jsonb_build_object(
    'schema_versao', 'adm01-v2',
    'id_usuario', p_id_usuario,
    'pagina', v_pagina,
    'tamanho_pagina', v_tamanho,
    'total', v_total,
    'total_paginas', case when v_total = 0 then 0 else pg_catalog.ceil(v_total::numeric / v_tamanho)::integer end,
    'itens', v_itens
  );
end;
$$;

comment on function public.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean) is
  'ADM-01 v2: lista paginada canônica de usuários e vínculos.';
comment on function public.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) is
  'ADM-01 v2: AuditDrawer paginado com redação de contratos fora do escopo do administrador.';
