-- V1-05 — correção do ciclo de autorização no grant automático de escopo.
-- Operações do usuário continuam submetidas a usuario_tem_acesso_contrato.
-- Apenas operações internas executadas efetivamente como postgres/service_role
-- podem atravessar este guard; authenticated não possui esses papéis.

create or replace function privado.bloquear_mutacao_fora_escopo_contrato()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_contrato_antigo uuid;
  v_contrato_novo uuid;
begin
  if current_user in ('postgres','service_role')
     or auth.uid() is null
     or coalesce(auth.role(),'') = 'service_role' then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;

  if tg_op <> 'INSERT' then
    v_contrato_antigo := nullif(to_jsonb(old)->>'id_contrato','')::uuid;
    if v_contrato_antigo is not null
       and not privado.usuario_tem_acesso_contrato(v_contrato_antigo) then
      raise exception using
        errcode='42501',
        message='Você não possui acesso ao contrato deste registro.',
        detail='A operação foi bloqueada para preservar o isolamento entre contratos.',
        hint='Selecione um contrato ao qual seu usuário tenha acesso.';
    end if;
  end if;

  if tg_op <> 'DELETE' then
    v_contrato_novo := nullif(to_jsonb(new)->>'id_contrato','')::uuid;
    if v_contrato_novo is not null
       and v_contrato_novo is distinct from v_contrato_antigo
       and not privado.usuario_tem_acesso_contrato(v_contrato_novo) then
      raise exception using
        errcode='42501',
        message='Você não possui acesso ao contrato informado para este registro.',
        detail='A operação foi bloqueada para preservar o isolamento entre contratos.',
        hint='Selecione um contrato ao qual seu usuário tenha acesso.';
    end if;
  end if;

  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;
