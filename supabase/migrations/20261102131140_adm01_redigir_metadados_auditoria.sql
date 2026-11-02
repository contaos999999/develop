-- ContaOS HML 4.1 — ADM-01
-- Redige referências contratuais em metadados do AuditDrawer conforme o escopo
-- efetivo do administrador chamador. O evento bruto permanece íntegro.

create or replace function privado.redigir_metadados_auditoria_adm(p_metadados jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_resultado jsonb := coalesce(p_metadados, '{}'::jsonb);
  v_filtrado jsonb;
  v_chave text;
  v_id_contrato uuid;
begin
  v_id_contrato := privado.uuid_seguro(v_resultado->>'id_contrato');
  if v_id_contrato is not null and not privado.usuario_tem_acesso_contrato(v_id_contrato) then
    v_resultado := v_resultado - 'id_contrato';
  end if;

  foreach v_chave in array array['ids_contratos_ativar','ids_contratos_revogar']::text[]
  loop
    if jsonb_typeof(v_resultado->v_chave) = 'array' then
      select coalesce(jsonb_agg(to_jsonb(x.valor) order by x.valor), '[]'::jsonb)
        into v_filtrado
      from jsonb_array_elements_text(v_resultado->v_chave) as x(valor)
      where privado.uuid_seguro(x.valor) is not null
        and privado.usuario_tem_acesso_contrato(privado.uuid_seguro(x.valor));

      v_resultado := jsonb_set(v_resultado, array[v_chave], v_filtrado, true);
    end if;
  end loop;

  return v_resultado;
end;
$$;

revoke all on function privado.redigir_metadados_auditoria_adm(jsonb) from public, anon, authenticated;

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
        'metadados', privado.redigir_metadados_auditoria_adm(e.metadados),
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

comment on function public.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) is
  'ADM-01 v2: AuditDrawer paginado com redação de contratos fora do escopo, inclusive metadados de ativação/revogação.';
