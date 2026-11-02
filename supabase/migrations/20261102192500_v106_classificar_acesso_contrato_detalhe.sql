-- ContaOS 4.1 — PROMPT 27 / V1-06
-- Classificação segura do caso em que o SELECT Data API do detalhe retorna zero linhas.
-- O happy path continua sendo public.contratos + RLS.
-- Esta função NÃO revela existência de contrato pertencente a outra organização.

create or replace function privado.classificar_acesso_contrato_v106(p_id_contrato uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_id_organizacao uuid;
begin
  if auth.uid() is null or not privado.sessao_usuario_ativa() then
    raise sqlstate 'PT401' using
      message = 'Sua sessão não está ativa.',
      detail = 'É necessário autenticar novamente para consultar este contrato.',
      hint = 'Entre novamente no ContaOS e repita a consulta.';
  end if;

  if p_id_contrato is null then
    return 'nao_encontrado';
  end if;

  -- Se a própria regra contratual autoriza, não há ambiguidade.
  if privado.usuario_tem_acesso_contrato(p_id_contrato) then
    return 'permitido';
  end if;

  -- SECURITY DEFINER permite descobrir o tenant apenas internamente.
  -- O identificador da organização nunca é retornado ao cliente.
  select c.id_organizacao
    into v_id_organizacao
  from public.contratos c
  where c.id = p_id_contrato;

  if not found then
    return 'nao_encontrado';
  end if;

  -- Somente um usuário que já pertence à mesma organização pode receber
  -- distinção de 403 para um contrato existente fora do seu escopo.
  if privado.usuario_tem_acesso_organizacao(v_id_organizacao) then
    return 'negado';
  end if;

  -- Contrato de outro tenant é mascarado como inexistente para impedir
  -- enumeração/oráculo de identificadores entre organizações.
  return 'nao_encontrado';
end;
$$;

revoke all on function privado.classificar_acesso_contrato_v106(uuid) from public;
revoke all on function privado.classificar_acesso_contrato_v106(uuid) from anon;
grant execute on function privado.classificar_acesso_contrato_v106(uuid) to authenticated;

create or replace function public.classificar_acesso_contrato_v106(p_id_contrato uuid)
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select privado.classificar_acesso_contrato_v106(p_id_contrato);
$$;

revoke all on function public.classificar_acesso_contrato_v106(uuid) from public;
revoke all on function public.classificar_acesso_contrato_v106(uuid) from anon;
grant execute on function public.classificar_acesso_contrato_v106(uuid) to authenticated;

comment on function public.classificar_acesso_contrato_v106(uuid) is
'V1-06: classifica zero-linha do detalhe do contrato como permitido, negado no mesmo tenant ou nao_encontrado, mascarando existência cross-tenant.';
