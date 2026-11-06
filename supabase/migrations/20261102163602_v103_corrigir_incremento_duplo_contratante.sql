create or replace function privado.tocar_atualizado_em_contratante()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;
drop trigger if exists contratantes_touch on public.contratantes;
create trigger contratantes_touch before update on public.contratantes for each row execute function privado.tocar_atualizado_em_contratante();
comment on function privado.tocar_atualizado_em_contratante() is 'V1-03: touch exclusivo de contratantes; versao_registro é controlada somente por contaos_versao_contratantes.';
