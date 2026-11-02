create or replace function privado.snapshot_contexto_competencia(p_id_competencia uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v public.competencias%rowtype;
  v_contrato jsonb;
begin
  select * into v from public.competencias where id=p_id_competencia;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;

  select to_jsonb(c)-'criado_em'-'atualizado_em' into v_contrato from public.contratos c where c.id=v.id_contrato;

  return jsonb_build_object(
    'competencia',jsonb_build_object('id',v.id,'referencia',v.competencia_referencia,'periodo_inicio',v.periodo_inicio,'periodo_fim',v.periodo_fim,'data_limite',v.data_limite),
    'contrato',coalesce(v_contrato,'{}'::jsonb),
    'requisitos',coalesce((
      select jsonb_agg((to_jsonb(r)-'criado_em') order by r.ordem,r.id)
      from public.requisitos_competencia r where r.id_competencia=v.id
    ),'[]'::jsonb),
    'documentos',coalesce((
      select jsonb_agg(jsonb_build_object(
        'documento',to_jsonb(d)-'criado_em'-'atualizado_em',
        'versao',to_jsonb(vd)-'criado_em'-'enviado_por'
      ) order by d.id)
      from public.documentos_competencia d
      join lateral (select x.* from public.versoes_documento x where x.id_documento_competencia=d.id order by x.numero_versao desc limit 1) vd on true
      where d.id_competencia=v.id and d.situacao='ativo'
    ),'[]'::jsonb),
    'propostas',coalesce((
      select jsonb_agg((to_jsonb(vp)-'criado_em'-'aprovado_em'-'aprovado_por') order by vp.vigencia_inicio,vp.numero_versao,vp.id)
      from public.versoes_proposta vp
      where vp.id_contrato=v.id_contrato and vp.vigencia_inicio<=v.periodo_fim and (vp.vigencia_fim is null or vp.vigencia_fim>=v.periodo_inicio)
    ),'[]'::jsonb),
    'linhas_orcamentarias',coalesce((
      select jsonb_agg((to_jsonb(l)-'criado_em') order by l.codigo,l.id)
      from public.linhas_orcamentarias l join public.versoes_proposta vp on vp.id=l.id_versao_proposta
      where l.id_contrato=v.id_contrato and vp.vigencia_inicio<=v.periodo_fim and (vp.vigencia_fim is null or vp.vigencia_fim>=v.periodo_inicio)
    ),'[]'::jsonb),
    'transacoes',coalesce((
      select jsonb_agg((to_jsonb(t)-'criado_em'-'pre_validada'-'pre_validada_em'-'status_fluxo') order by t.data,t.id)
      from public.transacoes_financeiras t where t.id_contrato=v.id_contrato and t.data between v.periodo_inicio and v.periodo_fim
    ),'[]'::jsonb),
    'conciliacoes',coalesce((
      select jsonb_agg((to_jsonb(c)-'criado_em'-'concluido_em'-'concluido_por') order by c.periodo,c.tipo,c.id)
      from public.conciliacoes c where c.id_contrato=v.id_contrato and c.periodo between date_trunc('month',v.periodo_inicio)::date and date_trunc('month',v.periodo_fim)::date
    ),'[]'::jsonb),
    'motor','contaos','versao_snapshot','4.1','idioma','pt-BR','timezone','America/Sao_Paulo'
  );
end;
$$;
revoke all on function privado.snapshot_contexto_competencia(uuid) from public,anon,authenticated;
grant execute on function privado.snapshot_contexto_competencia(uuid) to service_role;
