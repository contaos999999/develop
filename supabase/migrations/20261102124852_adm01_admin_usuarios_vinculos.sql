-- ContaOS 4.1 — PROMPT 21 / ADM-01
-- Backend administrativo de usuários e vínculos.
-- Transversais: 091/NFR-007 concorrência, 092/NFR-008 idempotência, 093/NFR-009 paginação.
-- HML only. Sem tabela nova; sem Edge Function; RLS e grants de escrita direta preservados.

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
  v_busca text := nullif(pg_catalog.btrim(coalesce(p_busca, '')), '');
  v_total bigint;
  v_itens jsonb;
  v_perfis jsonb;
  v_org jsonb;
begin
  if not privado.usuario_possui_perfil(p_id_organizacao, array['administrador']::text[]) then
    raise exception using errcode = '42501', message = 'Você não tem permissão para administrar usuários desta organização.';
  end if;

  select jsonb_build_object(
           'id', o.id,
           'razao_social', o.razao_social,
           'nome_fantasia', o.nome_fantasia,
           'situacao', o.situacao
         )
    into v_org
    from public.organizacoes o
   where o.id = p_id_organizacao;

  if v_org is null then
    raise exception using errcode = '42501', message = 'Você não tem permissão para administrar usuários desta organização.';
  end if;

  v_offset := (v_pagina - 1) * v_tamanho;

  select count(*)
    into v_total
    from public.vinculos_usuarios vu
    join public.usuarios u on u.id_usuario = vu.id_usuario
   where vu.id_organizacao = p_id_organizacao
     and (p_ativo is null or vu.ativo = p_ativo)
     and (
       v_busca is null
       or coalesce(u.nome, '') ilike '%' || v_busca || '%'
       or coalesce(u.email, '') ilike '%' || v_busca || '%'
     );

  select coalesce(jsonb_agg(x.item order by x.ordem_nome, x.ordem_email, x.id_usuario), '[]'::jsonb)
    into v_itens
    from (
      select lower(coalesce(u.nome, u.email, '')) as ordem_nome,
             lower(coalesce(u.email, '')) as ordem_email,
             u.id_usuario,
             jsonb_build_object(
               'id_usuario', u.id_usuario,
               'nome', u.nome,
               'email', u.email,
               'telefone', u.telefone,
               'situacao_usuario', u.situacao,
               'versao_usuario', u.versao_registro,
               'id_vinculo', vu.id,
               'perfil', vu.perfil,
               'escopo_todos_contratos', vu.escopo_todos_contratos,
               'ativo', vu.ativo,
               'inicio_em', vu.inicio_em,
               'fim_em', vu.fim_em,
               'versao_registro', vu.versao_registro,
               'atualizado_em', vu.atualizado_em
             ) as item
        from public.vinculos_usuarios vu
        join public.usuarios u on u.id_usuario = vu.id_usuario
       where vu.id_organizacao = p_id_organizacao
         and (p_ativo is null or vu.ativo = p_ativo)
         and (
           v_busca is null
           or coalesce(u.nome, '') ilike '%' || v_busca || '%'
           or coalesce(u.email, '') ilike '%' || v_busca || '%'
         )
       order by lower(coalesce(u.nome, u.email, '')), lower(coalesce(u.email, '')), u.id_usuario
       limit v_tamanho offset v_offset
    ) x;

  select coalesce(jsonb_agg(jsonb_build_object('codigo', p.codigo, 'nome', p.nome) order by p.nome, p.codigo), '[]'::jsonb)
    into v_perfis
    from public.perfis_usuarios p;

  return jsonb_build_object(
    'schema_versao', 'adm01-v1',
    'organizacao', v_org,
    'pagina', v_pagina,
    'tamanho_pagina', v_tamanho,
    'total', v_total,
    'total_paginas', case when v_total = 0 then 0 else pg_catalog.ceil(v_total::numeric / v_tamanho)::integer end,
    'perfis_disponiveis', v_perfis,
    'itens', v_itens
  );
end;
$$;

create or replace function public.listar_usuarios_vinculos_adm(
  p_id_organizacao uuid,
  p_pagina integer default 1,
  p_tamanho_pagina integer default 25,
  p_busca text default null,
  p_ativo boolean default null
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select privado.listar_usuarios_vinculos_adm($1,$2,$3,$4,$5)
$$;

create or replace function privado.listar_escopo_contratos_usuario_adm(
  p_id_organizacao uuid,
  p_id_usuario uuid,
  p_pagina integer default 1,
  p_tamanho_pagina integer default 25,
  p_busca text default null
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
  v_busca text := nullif(pg_catalog.btrim(coalesce(p_busca, '')), '');
  v_total bigint;
  v_vinculo uuid;
  v_todos boolean;
  v_itens jsonb;
begin
  if not privado.usuario_possui_perfil(p_id_organizacao, array['administrador']::text[]) then
    raise exception using errcode = '42501', message = 'Você não tem permissão para administrar o escopo contratual.';
  end if;

  select vu.id, vu.escopo_todos_contratos
    into v_vinculo, v_todos
    from public.vinculos_usuarios vu
   where vu.id_organizacao = p_id_organizacao
     and vu.id_usuario = p_id_usuario;

  if v_vinculo is null then
    raise exception using errcode = 'PT404', message = 'Vínculo de usuário não encontrado nesta organização.';
  end if;

  v_offset := (v_pagina - 1) * v_tamanho;

  select count(*) into v_total
    from public.contratos c
   where c.id_organizacao = p_id_organizacao
     and privado.usuario_tem_acesso_contrato(c.id)
     and (
       v_busca is null
       or c.numero ilike '%' || v_busca || '%'
       or c.objeto ilike '%' || v_busca || '%'
     );

  select coalesce(jsonb_agg(x.item order by x.numero, x.id), '[]'::jsonb)
    into v_itens
    from (
      select c.numero, c.id,
             jsonb_build_object(
               'id', c.id,
               'numero', c.numero,
               'objeto', c.objeto,
               'situacao', c.situacao,
               'criticidade', c.criticidade,
               'selecionado', case
                 when v_todos then true
                 else coalesce(vc.ativo, false)
               end
             ) as item
        from public.contratos c
        left join public.vinculos_usuario_contratos vc
          on vc.id_vinculo_usuario = v_vinculo
         and vc.id_contrato = c.id
       where c.id_organizacao = p_id_organizacao
         and privado.usuario_tem_acesso_contrato(c.id)
         and (
           v_busca is null
           or c.numero ilike '%' || v_busca || '%'
           or c.objeto ilike '%' || v_busca || '%'
         )
       order by c.numero, c.id
       limit v_tamanho offset v_offset
    ) x;

  return jsonb_build_object(
    'schema_versao', 'adm01-v1',
    'id_usuario', p_id_usuario,
    'escopo_todos_contratos', v_todos,
    'pagina', v_pagina,
    'tamanho_pagina', v_tamanho,
    'total', v_total,
    'total_paginas', case when v_total = 0 then 0 else pg_catalog.ceil(v_total::numeric / v_tamanho)::integer end,
    'itens', v_itens
  );
end;
$$;

create or replace function public.listar_escopo_contratos_usuario_adm(
  p_id_organizacao uuid,
  p_id_usuario uuid,
  p_pagina integer default 1,
  p_tamanho_pagina integer default 25,
  p_busca text default null
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select privado.listar_escopo_contratos_usuario_adm($1,$2,$3,$4,$5)
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
  if not privado.usuario_possui_perfil(p_id_organizacao, array['administrador']::text[]) then
    raise exception using errcode = '42501', message = 'Você não tem permissão para consultar a auditoria deste vínculo.';
  end if;

  v_offset := (v_pagina - 1) * v_tamanho;

  select count(*) into v_total
    from public.eventos_auditoria e
   where e.id_organizacao = p_id_organizacao
     and e.entidade in ('vinculos_usuarios','vinculos_usuario_contratos')
     and e.metadados->>'id_usuario' = p_id_usuario::text;

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
               'antes', e.antes,
               'depois', e.depois,
               'metadados', e.metadados,
               'criado_em', e.criado_em
             ) as item
        from public.eventos_auditoria e
        left join public.usuarios ua on ua.id_usuario = e.id_usuario
       where e.id_organizacao = p_id_organizacao
         and e.entidade in ('vinculos_usuarios','vinculos_usuario_contratos')
         and e.metadados->>'id_usuario' = p_id_usuario::text
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

create or replace function public.listar_auditoria_vinculo_usuario_adm(
  p_id_organizacao uuid,
  p_id_usuario uuid,
  p_pagina integer default 1,
  p_tamanho_pagina integer default 20
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select privado.listar_auditoria_vinculo_usuario_adm($1,$2,$3,$4)
$$;

create or replace function privado.salvar_vinculo_usuario_adm(
  p_id_organizacao uuid,
  p_id_usuario uuid,
  p_email text,
  p_perfil text,
  p_escopo_todos_contratos boolean,
  p_ativo boolean,
  p_ids_contratos uuid[],
  p_versao_esperada bigint,
  p_chave_idempotencia text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id_usuario uuid := p_id_usuario;
  v_email text := nullif(lower(pg_catalog.btrim(coalesce(p_email, ''))), '');
  v_perfil text := nullif(pg_catalog.btrim(coalesce(p_perfil, '')), '');
  v_todos boolean := coalesce(p_escopo_todos_contratos, false);
  v_ativo boolean := coalesce(p_ativo, true);
  v_ids_contratos uuid[];
  v_chave text := nullif(pg_catalog.btrim(coalesce(p_chave_idempotencia, '')), '');
  v_hash text;
  v_comando_id uuid;
  v_comando_status text;
  v_comando_hash text;
  v_comando_resposta jsonb;
  v_vinculo_id uuid;
  v_versao_atual bigint;
  v_antes jsonb;
  v_depois jsonb;
  v_escopo_antes jsonb;
  v_escopo_depois jsonb;
  v_evento_id uuid;
  v_correlation_id uuid;
  v_resposta jsonb;
  v_qtd_contratos integer;
begin
  if not privado.usuario_possui_perfil(p_id_organizacao, array['administrador']::text[]) then
    raise exception using errcode = '42501', message = 'Você não tem permissão para administrar usuários desta organização.';
  end if;

  if v_id_usuario is null then
    if v_email is null then
      raise exception using errcode = 'PT400', message = 'Informe um usuário ou e-mail válido.';
    end if;
    select u.id_usuario
      into v_id_usuario
      from public.usuarios u
     where lower(u.email) = v_email
     order by u.id_usuario
     limit 1;
  else
    if not exists (select 1 from public.usuarios u where u.id_usuario = v_id_usuario) then
      v_id_usuario := null;
    elsif v_email is not null and not exists (
      select 1 from public.usuarios u where u.id_usuario = v_id_usuario and lower(u.email) = v_email
    ) then
      raise exception using errcode = 'PT400', message = 'O e-mail informado não corresponde ao usuário selecionado.';
    end if;
  end if;

  if v_id_usuario is null then
    raise exception using
      errcode = 'PT404',
      message = 'Usuário ContaOS não encontrado.',
      hint = 'Vincule uma conta já existente no ContaOS.';
  end if;

  if v_perfil is null or not exists (select 1 from public.perfis_usuarios p where p.codigo = v_perfil) then
    raise exception using errcode = 'PT400', message = 'Perfil de acesso inválido.';
  end if;

  if v_chave is null or pg_catalog.length(v_chave) > 200 then
    raise exception using errcode = 'PT400', message = 'Chave de idempotência inválida.';
  end if;

  if v_todos or not v_ativo then
    v_ids_contratos := array[]::uuid[];
  else
    select coalesce(array_agg(x order by x), array[]::uuid[])
      into v_ids_contratos
      from (select distinct unnest(coalesce(p_ids_contratos, array[]::uuid[])) x) d;
  end if;

  select count(*) into v_qtd_contratos
    from public.contratos c
   where c.id_organizacao = p_id_organizacao
     and c.id = any(v_ids_contratos)
     and privado.usuario_tem_acesso_contrato(c.id);

  if v_qtd_contratos <> cardinality(v_ids_contratos) then
    raise exception using errcode = 'PT400', message = 'Um ou mais contratos informados não pertencem à organização.';
  end if;

  v_hash := pg_catalog.md5(jsonb_build_object(
    'id_usuario', v_id_usuario,
    'perfil', v_perfil,
    'escopo_todos_contratos', v_todos,
    'ativo', v_ativo,
    'ids_contratos', to_jsonb(v_ids_contratos),
    'versao_esperada', p_versao_esperada
  )::text);

  insert into public.comandos_idempotentes(id_organizacao, comando, chave, hash_payload, status, expira_em)
  values(p_id_organizacao, 'adm01.salvar_vinculo_usuario', v_chave, v_hash, 'iniciado', now() + interval '24 hours')
  on conflict(id_organizacao, comando, chave) do nothing
  returning id into v_comando_id;

  if v_comando_id is null then
    select c.id, c.status, c.hash_payload, c.resposta
      into v_comando_id, v_comando_status, v_comando_hash, v_comando_resposta
      from public.comandos_idempotentes c
     where c.id_organizacao = p_id_organizacao
       and c.comando = 'adm01.salvar_vinculo_usuario'
       and c.chave = v_chave
     for update;

    if v_comando_hash is distinct from v_hash then
      raise exception using errcode = 'PT409', message = 'Esta chave de operação já foi usada com dados diferentes.';
    end if;

    if v_comando_status = 'concluido' and v_comando_resposta is not null then
      return v_comando_resposta;
    end if;

    if v_comando_status = 'iniciado' then
      raise exception using errcode = 'PT409', message = 'Esta operação já está em processamento. Atualize a tela antes de tentar novamente.';
    end if;

    update public.comandos_idempotentes
       set status = 'iniciado', resposta = null
     where id = v_comando_id;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_id_organizacao::text || ':' || v_id_usuario::text, 0)
  );

  select vu.id, vu.versao_registro, to_jsonb(vu)
    into v_vinculo_id, v_versao_atual, v_antes
    from public.vinculos_usuarios vu
   where vu.id_organizacao = p_id_organizacao
     and vu.id_usuario = v_id_usuario
   for update;

  if v_vinculo_id is null then
    if p_versao_esperada is not null then
      raise exception using errcode = 'PT409', message = 'O vínculo mudou desde a última leitura. Atualize a tela e tente novamente.';
    end if;
  else
    if p_versao_esperada is null or p_versao_esperada <> v_versao_atual then
      raise exception using errcode = 'PT409', message = 'Este vínculo foi atualizado por outra pessoa. Atualize a tela, confira a versão mais recente e tente novamente.';
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id_contrato', vc.id_contrato, 'ativo', vc.ativo) order by vc.id_contrato), '[]'::jsonb)
    into v_escopo_antes
    from public.vinculos_usuario_contratos vc
   where vc.id_vinculo_usuario = v_vinculo_id;

  if v_vinculo_id is null then
    insert into public.vinculos_usuarios(
      id_organizacao, id_usuario, perfil, escopo_todos_contratos, ativo, fim_em
    )
    values(
      p_id_organizacao, v_id_usuario, v_perfil, v_todos, v_ativo,
      case when v_ativo then null else pg_catalog.clock_timestamp() end
    )
    returning id into v_vinculo_id;
  else
    update public.vinculos_usuarios
       set perfil = v_perfil,
           escopo_todos_contratos = v_todos,
           ativo = v_ativo,
           fim_em = case
             when v_ativo then null
             else coalesce(fim_em, pg_catalog.clock_timestamp())
           end
     where id = v_vinculo_id;
  end if;

  if v_todos or not v_ativo then
    update public.vinculos_usuario_contratos
       set ativo = false,
           revogado_em = coalesce(revogado_em, pg_catalog.clock_timestamp())
     where id_vinculo_usuario = v_vinculo_id
       and ativo = true;
  else
    insert into public.vinculos_usuario_contratos(
      id_organizacao, id_vinculo_usuario, id_contrato, ativo, revogado_em
    )
    select p_id_organizacao, v_vinculo_id, x, true, null
      from unnest(v_ids_contratos) x
    on conflict(id_vinculo_usuario, id_contrato)
    do update set ativo = true, revogado_em = null;

    update public.vinculos_usuario_contratos
       set ativo = false,
           revogado_em = coalesce(revogado_em, pg_catalog.clock_timestamp())
     where id_vinculo_usuario = v_vinculo_id
       and ativo = true
       and not (id_contrato = any(v_ids_contratos));
  end if;

  select to_jsonb(vu)
    into v_depois
    from public.vinculos_usuarios vu
   where vu.id = v_vinculo_id;

  select coalesce(jsonb_agg(jsonb_build_object('id_contrato', vc.id_contrato, 'ativo', vc.ativo) order by vc.id_contrato), '[]'::jsonb)
    into v_escopo_depois
    from public.vinculos_usuario_contratos vc
   where vc.id_vinculo_usuario = v_vinculo_id;

  v_evento_id := privado.registrar_evento_auditoria(
    p_id_organizacao,
    'VinculoUsuarioAdministrativoSalvo',
    'vinculos_usuarios',
    v_vinculo_id,
    jsonb_build_object('vinculo', v_antes, 'escopo_contratos', v_escopo_antes),
    jsonb_build_object('vinculo', v_depois, 'escopo_contratos', v_escopo_depois),
    jsonb_build_object('id_usuario', v_id_usuario, 'chave_idempotencia', v_chave)
  );

  select e.correlation_id into v_correlation_id
    from public.eventos_auditoria e
   where e.id = v_evento_id;

  v_resposta := jsonb_build_object(
    'schema_versao', 'adm01-v1',
    'correlation_id', v_correlation_id,
    'id_usuario', v_id_usuario,
    'vinculo', v_depois
  );

  update public.comandos_idempotentes
     set status = 'concluido', resposta = v_resposta
   where id = v_comando_id;

  return v_resposta;
end;
$$;

create or replace function public.salvar_vinculo_usuario_adm(
  p_id_organizacao uuid,
  p_id_usuario uuid,
  p_email text,
  p_perfil text,
  p_escopo_todos_contratos boolean,
  p_ativo boolean,
  p_ids_contratos uuid[],
  p_versao_esperada bigint,
  p_chave_idempotencia text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select privado.salvar_vinculo_usuario_adm($1,$2,$3,$4,$5,$6,$7,$8,$9)
$$;

revoke execute on function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) from public, anon, authenticated;
revoke execute on function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) from public, anon, authenticated;
revoke execute on function privado.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) from public, anon, authenticated;
revoke execute on function privado.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) from public, anon, authenticated;
grant execute on function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) to service_role;
grant execute on function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) to service_role;
grant execute on function privado.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) to service_role;
grant execute on function privado.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) to service_role;

revoke execute on function privado.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean) from public, anon;
revoke execute on function privado.listar_escopo_contratos_usuario_adm(uuid,uuid,integer,integer,text) from public, anon;
revoke execute on function privado.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) from public, anon;
revoke execute on function privado.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text) from public, anon;
grant execute on function privado.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean) to authenticated, service_role;
grant execute on function privado.listar_escopo_contratos_usuario_adm(uuid,uuid,integer,integer,text) to authenticated, service_role;
grant execute on function privado.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) to authenticated, service_role;
grant execute on function privado.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text) to authenticated, service_role;

revoke execute on function public.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean) from public, anon;
revoke execute on function public.listar_escopo_contratos_usuario_adm(uuid,uuid,integer,integer,text) from public, anon;
revoke execute on function public.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) from public, anon;
revoke execute on function public.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text) from public, anon;
grant execute on function public.listar_usuarios_vinculos_adm(uuid,integer,integer,text,boolean) to authenticated, service_role;
grant execute on function public.listar_escopo_contratos_usuario_adm(uuid,uuid,integer,integer,text) to authenticated, service_role;
grant execute on function public.listar_auditoria_vinculo_usuario_adm(uuid,uuid,integer,integer) to authenticated, service_role;
grant execute on function public.salvar_vinculo_usuario_adm(uuid,uuid,text,text,boolean,boolean,uuid[],bigint,text) to authenticated, service_role;
