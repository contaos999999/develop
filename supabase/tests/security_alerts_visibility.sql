-- SEC-BACKEND-ALERTS-HML-2026-11-02
-- Teste estrutural pós-migration. Deve falhar se uma exposição ampla reaparecer.

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from pg_policies
  where schemaname = 'public'
    and tablename in (
      'configuracao_api','configuracao_upload','perfis_usuarios',
      'catalogo_mensagens_sistema','catalogo_status_ui','configuracao_localizacao'
    )
    and cmd = 'SELECT'
    and (qual is null or btrim(lower(qual)) in ('true','(true)'));

  if v_count <> 0 then
    raise exception 'FAIL: existem % policies SELECT amplas USING(true) no escopo de segurança', v_count;
  end if;

  select count(*) into v_count
  from information_schema.role_table_grants
  where table_schema = 'public'
    and table_name in (
      'configuracao_api','configuracao_upload','perfis_usuarios',
      'catalogo_mensagens_sistema','catalogo_status_ui','configuracao_localizacao'
    )
    and grantee = 'anon'
    and privilege_type = 'SELECT';

  if v_count <> 0 then
    raise exception 'FAIL: anon ainda possui SELECT direto em % tabelas do escopo', v_count;
  end if;

  if has_function_privilege('anon', 'public.obter_mensagem_sistema(text)', 'EXECUTE') then
    raise exception 'FAIL: anon ainda executa public.obter_mensagem_sistema(text)';
  end if;

  if has_function_privilege('anon', 'public.normalizar_erro_backend(text,text)', 'EXECUTE') then
    raise exception 'FAIL: anon ainda executa public.normalizar_erro_backend(text,text)';
  end if;

  if to_regprocedure('privado.usuario_possui_vinculo_ativo()') is null then
    raise exception 'FAIL: helper privado.usuario_possui_vinculo_ativo() inexistente';
  end if;

  if not has_function_privilege('authenticated', 'privado.usuario_possui_vinculo_ativo()', 'EXECUTE') then
    raise exception 'FAIL: authenticated não pode executar helper de vínculo ativo';
  end if;
end $$;
