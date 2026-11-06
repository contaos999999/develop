begin;

create or replace function privado.bloquear_mutacao_campos_estruturais()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare
  v_antigo jsonb := to_jsonb(old);
  v_novo jsonb := to_jsonb(new);
  v_campo text;
begin
  -- Workers/RPCs privilegiadas e administração interna não são afetados.
  if current_user <> 'authenticated' then
    return new;
  end if;

  foreach v_campo in array array['id','id_organizacao','id_contrato','criado_em','criado_por']::text[]
  loop
    if v_antigo ? v_campo
       and (v_novo -> v_campo) is distinct from (v_antigo -> v_campo) then
      raise exception using
        errcode = '42501',
        message = 'Campo estrutural não pode ser alterado diretamente.',
        detail = format('O campo %s deve permanecer imutável nesta operação.', v_campo),
        hint = 'Use a operação oficial do ContaOS para mudanças estruturais.';
    end if;
  end loop;

  return new;
end;
$function$;

revoke all on function privado.bloquear_mutacao_campos_estruturais() from public, anon, authenticated;
grant execute on function privado.bloquear_mutacao_campos_estruturais() to service_role;

do $block$
declare
  r record;
  v_trigger text;
begin
  for r in
    select distinct p.tablename
    from pg_policies p
    where p.schemaname = 'public'
      and p.cmd in ('UPDATE','ALL')
      and ('authenticated' = any(p.roles) or 'public' = any(p.roles))
    order by p.tablename
  loop
    v_trigger := 'trg_bopla_estrutural_' || r.tablename;
    execute format('drop trigger if exists %I on public.%I', v_trigger, r.tablename);
    execute format(
      'create trigger %I before update on public.%I for each row execute function privado.bloquear_mutacao_campos_estruturais()',
      v_trigger,
      r.tablename
    );
  end loop;
end;
$block$;

commit;
