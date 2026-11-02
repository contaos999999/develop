begin;

create or replace function privado.solicitar_reanalise_requisitos(
  p_id_competencia uuid,
  p_requisitos uuid[]
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_exec uuid;
  v_org uuid;
  v_contrato uuid;
begin
  select c.id_organizacao, c.id_contrato
    into v_org, v_contrato
  from public.competencias c
  where c.id = p_id_competencia;

  -- A autorização precisa ocorrer antes de qualquer validação de requisitos.
  -- Assim, usuários sem acesso não conseguem inferir se um requisito existe
  -- ou se pertence a determinada competência por diferenças de mensagem/erro.
  if v_contrato is null
     or auth.uid() is null
     or not privado.usuario_tem_acesso_contrato(v_contrato) then
    raise exception using
      errcode = '42501',
      message = 'Você não possui acesso à competência informada.';
  end if;

  if not privado.usuario_possui_perfil(
    v_org,
    array[
      'administrador','gestor_contrato','prestacao_contas','financeiro',
      'contabilidade','rh_dp','juridico_conformidade','auditor'
    ]::text[]
  ) then
    raise exception using
      errcode = '42501',
      message = 'Seu perfil atual não permite solicitar esta reanálise.';
  end if;

  if p_requisitos is null or cardinality(p_requisitos) = 0 then
    raise exception 'Selecione ao menos um requisito para reanálise.';
  end if;

  if exists(
    select 1
    from unnest(p_requisitos) x
    where not exists(
      select 1
      from public.requisitos_competencia r
      where r.id = x
        and r.id_competencia = p_id_competencia
    )
  ) then
    raise exception 'Um dos requisitos selecionados não pertence a esta competência.';
  end if;

  v_exec := privado.solicitar_analise_competencia(p_id_competencia,'parcial');

  update public.execucoes_analise
  set requisitos_afetados = p_requisitos,
      metadados = metadados || jsonb_build_object('reanálise_incremental',true)
  where id = v_exec;

  return v_exec;
end;
$$;

revoke all on function privado.solicitar_reanalise_requisitos(uuid,uuid[]) from public, anon;
grant execute on function privado.solicitar_reanalise_requisitos(uuid,uuid[]) to authenticated;

commit;
