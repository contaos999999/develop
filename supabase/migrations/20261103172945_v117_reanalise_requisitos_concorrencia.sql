-- ContaOS 4.1 V1-17 B2 — protege selecao incremental contra sobrescrita do job ativo.
-- Reutiliza bloqueio da competencia e a fila existente, sem mudar contrato publico.
create or replace function privado.solicitar_reanalise_requisitos(
  p_id_competencia uuid,
  p_requisitos uuid[]
) returns uuid
language plpgsql security definer set search_path = ''
as $v117$
declare
  v_comp public.competencias%rowtype;
  v_busy public.execucoes_analise%rowtype;
  v_ids uuid[];
  v_busy_ids uuid[];
  v_exec uuid;
  v_written uuid;
begin
  if auth.uid() is null then
    raise exception using errcode='42501',message='Você não possui autorização para solicitar reanálise.';
  end if;
  if p_id_competencia is null or p_requisitos is null or cardinality(p_requisitos)=0
    or exists(select 1 from unnest(p_requisitos) as q(id) where q.id is null) then
    raise exception using errcode='PT400',message='Selecione ao menos um requisito válido para reanálise.';
  end if;
  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null
    or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato)
    or not privado.usuario_possui_perfil(
      v_comp.id_organizacao,
      array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]
    ) then
    raise exception using errcode='42501',message='Você não possui autorização para solicitar reanálise.';
  end if;
  -- Mesma trava que privado.solicitar_analise_competencia, serializa selecoes.
  select * into v_comp from public.competencias
    where id=p_id_competencia and id_contrato=v_comp.id_contrato
      and id_organizacao=v_comp.id_organizacao for update;
  if v_comp.id is null then
    raise exception using errcode='42501',message='Você não possui autorização para solicitar reanálise.';
  end if;
  if v_comp.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then
    raise exception using errcode='PT409',message='A situação da competência não permite reanálise.';
  end if;
  select array_agg(q.id order by q.id) into v_ids
    from (select distinct id from unnest(p_requisitos) as z(id)) q;
  if exists(
    select 1 from unnest(v_ids) as q(id)
    where not exists (
      select 1 from public.requisitos_competencia r
      where r.id=q.id and r.id_competencia=v_comp.id
        and r.id_contrato=v_comp.id_contrato
        and r.id_organizacao=v_comp.id_organizacao
    )
  ) then
    raise exception using errcode='PT400',message='A seleção contém requisito inválido para esta competência.';
  end if;
  select * into v_busy from public.execucoes_analise e
    where e.id_competencia=v_comp.id and e.id_contrato=v_comp.id_contrato
      and e.id_organizacao=v_comp.id_organizacao
      and e.status in ('pendente','processando')
    order by e.criado_em desc,e.id desc limit 1;
  if v_busy.id is not null then
    select coalesce(array_agg(q.id order by q.id),array[]::uuid[]) into v_busy_ids
    from (select distinct id from unnest(v_busy.requisitos_afetados) as z(id)) q;
    if v_busy.tipo='parcial' and v_busy_ids=v_ids then
      -- Repeticao idempotente, zero UPDATE na execucao existente.
      return v_busy.id;
    end if;
    raise exception using errcode='PT409',
      message='Já existe uma análise em andamento. Consulte o andamento antes de solicitar outra.';
  end if;
  -- O INSERT da execucao e sua fila só ficam visíveis ao worker após COMMIT.
  v_exec := privado.solicitar_analise_competencia(v_comp.id,'parcial');
  update public.execucoes_analise e
  set requisitos_afetados=v_ids,
      metadados=e.metadados || jsonb_build_object('reanálise_incremental',true)
  where e.id=v_exec and e.id_competencia=v_comp.id and e.id_contrato=v_comp.id_contrato
    and e.id_organizacao=v_comp.id_organizacao
    and e.tipo='parcial' and e.status='pendente'
    and cardinality(e.requisitos_afetados)=0
  returning e.id into v_written;
  if v_written is null then
    raise exception using errcode='PT409',
      message='Não foi possível garantir o escopo desta reanálise. Atualize a competência e tente novamente.';
  end if;
  perform privado.registrar_evento_auditoria(
    v_comp.id_organizacao,'ReanaliseIncrementalSolicitada',
    'execucoes_analise',v_exec,null,
    jsonb_build_object('id_competencia',v_comp.id,'requisitos_afetados',to_jsonb(v_ids))
  );
  return v_exec;
end;
$v117$;
-- Não alterar a wrapper publica, grants, RLS, Edge ou worker.;
