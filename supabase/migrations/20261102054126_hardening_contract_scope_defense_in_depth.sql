begin;
create or replace function privado.bloquear_mutacao_fora_escopo_contrato()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_contrato_antigo uuid;
  v_contrato_novo uuid;
begin
  if auth.uid() is null or coalesce(auth.role(),'') = 'service_role' then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op <> 'INSERT' then
    v_contrato_antigo := nullif(to_jsonb(old)->>'id_contrato','')::uuid;
    if v_contrato_antigo is not null and not privado.usuario_tem_acesso_contrato(v_contrato_antigo) then
      raise exception using errcode='42501',message='Você não possui acesso ao contrato deste registro.',detail='A operação foi bloqueada para preservar o isolamento entre contratos.',hint='Selecione um contrato ao qual seu usuário tenha acesso.';
    end if;
  end if;
  if tg_op <> 'DELETE' then
    v_contrato_novo := nullif(to_jsonb(new)->>'id_contrato','')::uuid;
    if v_contrato_novo is not null and v_contrato_novo is distinct from v_contrato_antigo and not privado.usuario_tem_acesso_contrato(v_contrato_novo) then
      raise exception using errcode='42501',message='Você não possui acesso ao contrato informado para este registro.',detail='A operação foi bloqueada para preservar o isolamento entre contratos.',hint='Selecione um contrato ao qual seu usuário tenha acesso.';
    end if;
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function privado.bloquear_mutacao_fora_escopo_contrato() from public, anon, authenticated;
grant execute on function privado.bloquear_mutacao_fora_escopo_contrato() to service_role;
do $$
declare r record;
begin
  for r in
    select c.table_schema,c.table_name
    from information_schema.columns c
    join information_schema.tables t on t.table_schema=c.table_schema and t.table_name=c.table_name
    where c.table_schema='public' and c.column_name='id_contrato' and c.data_type='uuid' and t.table_type='BASE TABLE'
    order by c.table_name
  loop
    execute format('drop trigger if exists trg_scope_contrato on %I.%I',r.table_schema,r.table_name);
    execute format('create trigger trg_scope_contrato before insert or update or delete on %I.%I for each row execute function privado.bloquear_mutacao_fora_escopo_contrato()',r.table_schema,r.table_name);
  end loop;
end;
$$;
create or replace function privado.bloquear_plano_remediacao_fora_escopo_contrato()
returns trigger language plpgsql set search_path = '' as $$
declare v_id_nc uuid; v_id_contrato uuid;
begin
  if auth.uid() is null or coalesce(auth.role(),'')='service_role' then if tg_op='DELETE' then return old; else return new; end if; end if;
  if tg_op='UPDATE' and new.id_nao_conformidade is distinct from old.id_nao_conformidade then
    raise exception using errcode='42501',message='A não conformidade vinculada ao plano não pode ser alterada diretamente.',detail='O vínculo estrutural da remediação é imutável após a criação.';
  end if;
  if tg_op='DELETE' then v_id_nc:=old.id_nao_conformidade; else v_id_nc:=new.id_nao_conformidade; end if;
  select id_contrato into v_id_contrato from public.nao_conformidades where id=v_id_nc;
  if v_id_contrato is not null and not privado.usuario_tem_acesso_contrato(v_id_contrato) then
    raise exception using errcode='42501',message='Você não possui acesso ao contrato desta remediação.',detail='A operação foi bloqueada para preservar o isolamento entre contratos.';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function privado.bloquear_plano_remediacao_fora_escopo_contrato() from public, anon, authenticated;
grant execute on function privado.bloquear_plano_remediacao_fora_escopo_contrato() to service_role;
drop trigger if exists trg_scope_contrato_plano_remediacao on public.planos_remediacao;
create trigger trg_scope_contrato_plano_remediacao before insert or update or delete on public.planos_remediacao for each row execute function privado.bloquear_plano_remediacao_fora_escopo_contrato();
create or replace function privado.bloquear_acesso_pacote_fora_escopo_contrato()
returns trigger language plpgsql set search_path = '' as $$
declare v_id_pacote uuid; v_id_contrato uuid;
begin
  if auth.uid() is null or coalesce(auth.role(),'')='service_role' then if tg_op='DELETE' then return old; else return new; end if; end if;
  if tg_op='UPDATE' and new.id_pacote is distinct from old.id_pacote then
    raise exception using errcode='42501',message='O pacote vinculado ao acesso temporário não pode ser alterado.',detail='Crie um novo acesso temporário para outro pacote.';
  end if;
  if tg_op='DELETE' then v_id_pacote:=old.id_pacote; else v_id_pacote:=new.id_pacote; end if;
  select id_contrato into v_id_contrato from public.pacotes_evidencias where id=v_id_pacote;
  if v_id_contrato is not null and not privado.usuario_tem_acesso_contrato(v_id_contrato) then
    raise exception using errcode='42501',message='Você não possui acesso ao contrato deste pacote de evidências.',detail='A operação foi bloqueada para preservar o isolamento entre contratos.';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function privado.bloquear_acesso_pacote_fora_escopo_contrato() from public, anon, authenticated;
grant execute on function privado.bloquear_acesso_pacote_fora_escopo_contrato() to service_role;
drop trigger if exists trg_scope_contrato_acesso_pacote on public.acessos_pacote_evidencias;
create trigger trg_scope_contrato_acesso_pacote before insert or update or delete on public.acessos_pacote_evidencias for each row execute function privado.bloquear_acesso_pacote_fora_escopo_contrato();
commit;
