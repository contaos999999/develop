do $$
begin
  if to_regprocedure('public.registrar_extracao_apontamentos(uuid,uuid,text,jsonb)') is null
    or to_regprocedure('public.obter_fonte_apontamento_contratante(uuid,uuid)') is null then
    raise exception 'V2_I05_ORIGEM_DURAVEL: contrato de escrita e leitura inexistente no baseline';
  end if;
end $$;

begin;

do $$
declare
  gravar text := 'public.registrar_extracao_apontamentos(uuid,uuid,text,jsonb)';
  ler text := 'public.obter_fonte_apontamento_contratante(uuid,uuid)';
begin
  if not has_function_privilege('service_role', gravar, 'execute')
    or has_function_privilege('authenticated', gravar, 'execute')
    or has_function_privilege('anon', gravar, 'execute')
    or not has_function_privilege('authenticated', ler, 'execute')
    or has_function_privilege('anon', ler, 'execute') then
    raise exception 'I05: ACL de escrita ou leitura incorreta';
  end if;
end $$;

set local role service_role;
do $$
declare
  parecer_a uuid := '00000000-0000-4000-8000-000000000601';
  parecer_b uuid := '00000000-0000-4000-8000-000000000602';
  parecer_vazio uuid := '00000000-0000-4000-8000-000000000603';
  arquivo_a uuid := '00000000-0000-4000-8000-000000000501';
  arquivo_b uuid := '00000000-0000-4000-8000-000000000502';
  arquivo_vazio uuid := '00000000-0000-4000-8000-000000000503';
  itens jsonb := '[{"descricao":"Mesmo texto","severidade":"media","pagina":1,"trecho":"Mesmo trecho","valor_questionado":"9999999999999999.99"}]';
  primeiro jsonb;
  segundo jsonb;
  repetido jsonb;
  id_a uuid;
  id_b uuid;
begin
  begin
    perform public.registrar_extracao_apontamentos(parecer_a, arquivo_b, repeat('b',64), itens);
    raise exception 'I05: arquivo de outro parecer aceito';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.registrar_extracao_apontamentos(parecer_a, arquivo_a, repeat('c',64), itens);
    raise exception 'I05: SHA-256 divergente aceito';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.registrar_extracao_apontamentos(
      parecer_a, arquivo_a, repeat('a',64), itens || '[{"descricao":"erro","severidade":"inexistente"}]'
    );
    raise exception 'I05: lote inválido aceito';
  exception when check_violation then null;
  end;

  if exists (select 1 from public.apontamentos_contratante where id_parecer_origem = parecer_a)
     or exists (select 1 from public.pareceres_contratante where id = parecer_a
       and extracao_apontamentos_concluida_em is not null) then
    raise exception 'I05: escrita parcial após erro';
  end if;

  primeiro := public.registrar_extracao_apontamentos(parecer_a, arquivo_a, repeat('a',64), itens);
  segundo := public.registrar_extracao_apontamentos(parecer_b, arquivo_b, repeat('b',64), itens);
  repetido := public.registrar_extracao_apontamentos(parecer_a, arquivo_a, repeat('a',64), itens || itens);
  id_a := (primeiro->'ids_apontamentos'->>0)::uuid;
  id_b := (segundo->'ids_apontamentos'->>0)::uuid;
  if id_a is null or id_b is null or id_a = id_b
     or primeiro->>'reutilizado' <> 'false' or segundo->>'reutilizado' <> 'false'
     or repetido->>'reutilizado' <> 'true'
     or repetido->'ids_apontamentos' is distinct from primeiro->'ids_apontamentos' then
    raise exception 'I05: confundiu origens ou repetiu a gravação';
  end if;
  if not exists (
    select 1 from public.apontamentos_contratante
    where id = id_a and id_arquivo_origem = arquivo_a and sha256_arquivo_origem = repeat('a',64)
      and valor_questionado = '9999999999999999.99'::numeric and fonte_pagina = 1
  ) then
    raise exception 'I05: perdeu o arquivo, o hash, a fonte ou a precisão';
  end if;

  begin
    update public.apontamentos_contratante set id_parecer_origem = parecer_b where id = id_a;
    raise exception 'I05: alterou a origem gravada';
  exception when check_violation then null;
  end;
  update public.apontamentos_contratante set status = 'em_analise' where id = id_a;

  primeiro := public.registrar_extracao_apontamentos(parecer_vazio, arquivo_vazio, repeat('c',64), '[]');
  repetido := public.registrar_extracao_apontamentos(parecer_vazio, arquivo_vazio, repeat('c',64), itens);
  if primeiro->>'apontamentos' <> '0' or primeiro->>'reutilizado' <> 'false'
     or repetido->>'apontamentos' <> '0' or repetido->>'reutilizado' <> 'true' then
    raise exception 'I05: lote vazio reprocessado como novo';
  end if;

  perform set_config('contaos.fixture.item_a', id_a::text, true);
  perform set_config('contaos.fixture.item_b', id_b::text, true);
end $$;

reset role;
do $$
begin
  if (select count(*) from public.eventos_auditoria where evento='ApontamentosContratanteExtraidos') <> 3
     or not exists (
       select 1 from public.eventos_auditoria
       where id_entidade = '00000000-0000-4000-8000-000000000601'
         and depois->'ids_apontamentos' = jsonb_build_array(current_setting('contaos.fixture.item_a'))
         and depois->>'arquivo_sha256' = repeat('a',64)
     ) then
    raise exception 'I05: evento ou vínculo de auditoria divergente';
  end if;
end $$;

set local role authenticated;
select set_config('contaos.fixture.org', '00000000-0000-4000-8000-000000000101', true);
do $$
declare
  ciclo uuid := '00000000-0000-4000-8000-000000000401';
  outro uuid := '00000000-0000-4000-8000-000000000402';
  item_a uuid := current_setting('contaos.fixture.item_a')::uuid;
  item_b uuid := current_setting('contaos.fixture.item_b')::uuid;
  fonte_a jsonb;
  fonte_b jsonb;
  legado jsonb;
begin
  fonte_a := public.obter_fonte_apontamento_contratante(ciclo, item_a);
  fonte_b := public.obter_fonte_apontamento_contratante(ciclo, item_b);
  legado := public.obter_fonte_apontamento_contratante(ciclo, '00000000-0000-4000-8000-000000000701');
  if fonte_a->>'estado' is distinct from 'REGISTRADA'
     or fonte_b->>'estado' is distinct from 'REGISTRADA'
     or fonte_a#>>'{fonte,id_arquivo}' is distinct from '00000000-0000-4000-8000-000000000501'
     or fonte_b#>>'{fonte,id_parecer}' is distinct from '00000000-0000-4000-8000-000000000602'
     or fonte_b#>>'{fonte,arquivo_sha256}' is distinct from repeat('b',64)
     or fonte_a#>>'{fonte,trecho}' is distinct from 'Mesmo trecho'
     or (fonte_a->'fonte') ? 'path'
     or legado->>'estado' is distinct from 'ORIGEM_NAO_REGISTRADA'
     or legado->'fonte' is distinct from 'null'::jsonb
     or public.obter_fonte_apontamento_contratante(outro, item_a) is not null then
    raise exception 'I05: fonte indevida, arquivo trocado ou comportamento legado incorreto';
  end if;

  perform set_config('contaos.fixture.nega_arquivo', '00000000-0000-4000-8000-000000000501', true);
  fonte_a := public.obter_fonte_apontamento_contratante(ciclo, item_a);
  if fonte_a->>'estado' is distinct from 'ORIGEM_INDISPONIVEL'
     or fonte_a->'fonte' is distinct from 'null'::jsonb then
    raise exception 'I05: expôs arquivo fora do RLS';
  end if;

  perform set_config('contaos.fixture.org', '00000000-0000-4000-8000-000000000102', true);
  if public.obter_fonte_apontamento_contratante(ciclo, item_a) is not null then
    raise exception 'I05: outro tenant leu a origem';
  end if;

  begin
    perform public.registrar_extracao_apontamentos('00000000-0000-4000-8000-000000000604',
      '00000000-0000-4000-8000-000000000504', repeat('d',64), '[]');
    raise exception 'I05: sessão de usuário executou a RPC do worker';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

commit;
select 'V2_I05_POSTGRESQL_PASS' as resultado;
