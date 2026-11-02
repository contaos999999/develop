-- ContaOS HML 4.1 — ADM-01 consolidação do contrato público
-- Mantém o histórico interno integral, mas o AuditDrawer respeita o escopo
-- contratual do administrador chamador. Remove endpoints redundantes da
-- migration posterior, preservando uma superfície canônica única.

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
    'schema_versao', 'adm01-v1',
    'id_usuario', p_id_usuario,
    'pagina', v_pagina,
    'tamanho_pagina', v_tamanho,
    'total', v_total,
    'total_paginas', case when v_total = 0 then 0 else pg_catalog.ceil(v_total::numeric / v_tamanho)::integer end,
    'itens', v_itens
  );
end;
$$;

revoke all on function privado.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) from public, anon;
grant execute on function privado.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) to authenticated;

-- Superfície pública canônica do ADM-01:
-- validar_administrador_organizacao
-- listar_usuarios_vinculos_adm
-- listar_escopo_contratos_usuario_adm
-- listar_auditoria_vinculo_usuario_adm
-- salvar_vinculo_usuario_adm

-- Remover apenas as RPCs redundantes criadas na migration seguinte.
drop function if exists public.listar_usuarios_adm(uuid,integer,integer,text,text);
drop function if exists privado.listar_usuarios_adm(uuid,integer,integer,text,text);
drop function if exists public.listar_auditoria_usuario_adm(uuid,uuid,integer);
drop function if exists privado.listar_auditoria_usuario_adm(uuid,uuid,integer);
drop function if exists public.definir_vinculo_usuario_v2(uuid,uuid,text,boolean,boolean,bigint,text);
drop function if exists privado.definir_vinculo_usuario_v2(uuid,uuid,text,boolean,boolean,bigint,text);
drop function if exists public.definir_acesso_contrato_usuario_v2(uuid,uuid,uuid,boolean,bigint,text);
drop function if exists privado.definir_acesso_contrato_usuario_v2(uuid,uuid,uuid,boolean,bigint,text);

comment on function public.validar_administrador_organizacao(uuid) is
  'ADM-01: valida sessão ativa e perfil administrador na organização.';
comment on function public.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean) is
  'ADM-01: lista paginada canônica de usuários e vínculos; contrato adm01-v1.';
comment on function public.listar_escopo_contratos_usuario_adm(uuid,uuid,integer,integer,text) is
  'ADM-01: lista paginada do escopo contratual visível ao administrador; contrato adm01-v1.';
comment on function public.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) is
  'ADM-01: AuditDrawer paginado com redação de contratos fora do escopo do administrador; contrato adm01-v1.';
comment on function public.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text) is
  'ADM-01: mutação administrativa atômica de perfil, ativo e escopo, com versão, idempotência e auditoria; contrato adm01-v1.';
