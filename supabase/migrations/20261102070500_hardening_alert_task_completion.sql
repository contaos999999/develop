begin;

-- A conclusão de uma tarefa de alerta é efeito colateral do tratamento oficial
-- do alerta. Permitir status='concluida' via UPDATE direto pularia fundamento,
-- evidência, registro de tratamento e auditoria.
create or replace function privado.bloquear_conclusao_direta_tarefa_alerta()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user <> 'authenticated' then
    return new;
  end if;

  if new.status is distinct from old.status
     and (new.status = 'concluida' or old.status = 'concluida') then
    raise exception using
      errcode = '42501',
      message = 'A conclusão desta tarefa deve ocorrer pelo tratamento oficial do alerta.',
      detail = 'O ContaOS precisa registrar decisão, fundamento, evidência aplicável e auditoria antes de concluir a tarefa.',
      hint = 'Use a operação Tratar alerta preventivo.';
  end if;

  return new;
end;
$$;

revoke all on function privado.bloquear_conclusao_direta_tarefa_alerta() from public, anon, authenticated;
grant execute on function privado.bloquear_conclusao_direta_tarefa_alerta() to service_role;

drop trigger if exists trg_bopla_workflow_tarefas_alerta on public.tarefas_alerta;
create trigger trg_bopla_workflow_tarefas_alerta
before update on public.tarefas_alerta
for each row execute function privado.bloquear_conclusao_direta_tarefa_alerta();

commit;
