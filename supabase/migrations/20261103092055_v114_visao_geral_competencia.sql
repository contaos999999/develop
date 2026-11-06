create or replace function privado.obter_visao_geral_competencia(p_id_competencia uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v public.competencias%rowtype;
  v_portao jsonb;
  v_hash_atual text;
  v_hash_exec text;
  v_hash_aprovado text;
  v_parecer_aprovado boolean := false;
  v_analise_atual boolean := false;
  v_aprovacao_atual boolean := false;
  v_perfil_analise boolean := false;
  v_perfil_aprovar boolean := false;
  v_perfil_registrar boolean := false;
  v_pode_analisar boolean := false;
  v_pode_apresentar boolean := false;
begin
  select * into v from public.competencias where id = p_id_competencia;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then
    raise sqlstate '42501' using message = 'Você não tem permissão para acessar esta competência.';
  end if;
  v_portao := privado.avaliar_portao_conformidade(v.id);
  v_hash_atual := privado.hash_contexto_competencia(v.id);
  select exists(select 1 from public.pareceres_internos p where p.id_competencia = v.id and p.status = 'aprovado') into v_parecer_aprovado;
  select e.hash_entrada into v_hash_exec from public.execucoes_analise e where e.id_competencia = v.id and e.status = 'concluida' and e.tipo in ('completa','reanálise') order by e.concluida_em desc nulls last, e.criado_em desc, e.id desc limit 1;
  v_analise_atual := v_hash_exec is not null and v_hash_exec = v_hash_atual;
  select a.hash_contexto into v_hash_aprovado from public.aprovacoes a where a.id_competencia = v.id and a.tipo = 'apresentacao' and a.status = 'aprovada' order by a.criado_em desc, a.id desc limit 1;
  v_aprovacao_atual := v_hash_aprovado is not null and v_hash_aprovado = v_hash_atual;
  v_perfil_analise := privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]);
  v_perfil_aprovar := privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]);
  v_perfil_registrar := privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]);
  v_pode_analisar := v_perfil_analise and v.situacao not in ('apresentado','aguardando_contratante','validada','encerrada','cancelada');
  v_pode_apresentar := (v.situacao = 'pode_apresentar_contratante' and v_perfil_registrar and v_aprovacao_atual and v_analise_atual) or (v.situacao in ('em_analise','em_reanalise','pendente_correcao','rascunho') and v_perfil_aprovar and coalesce((v_portao->>'liberado')::boolean,false) and v_parecer_aprovado and v_analise_atual);
  return jsonb_build_object(
    'competencia', jsonb_build_object('id',v.id,'id_contrato',v.id_contrato,'id_organizacao',v.id_organizacao,'competencia_referencia',v.competencia_referencia,'periodo_inicio',v.periodo_inicio,'periodo_fim',v.periodo_fim,'data_limite',v.data_limite,'situacao',v.situacao,'percentual_conformidade',v.percentual_conformidade,'versao_pacote_atual',v.versao_pacote_atual,'versao_registro',v.versao_registro,'atualizado_em',v.atualizado_em),
    'portao', v_portao,
    'blocking_summary', jsonb_build_object('pendentes',coalesce((v_portao->>'pendentes')::integer,0),'nao_conformes',coalesce((v_portao->>'nao_conformes')::integer,0),'inconclusivos',coalesce((v_portao->>'inconclusivos')::integer,0),'em_analise',coalesce((v_portao->>'em_analise')::integer,0),'nao_conformidades_bloqueantes',coalesce((v_portao->>'nao_conformidades_bloqueantes')::integer,0),'parecer_aprovado',v_parecer_aprovado,'analise_concluida_atual',v_analise_atual,'aprovacao_apresentacao_atual',v_aprovacao_atual),
    'allowed_actions', jsonb_build_object('abrir_documentos',true,'analisar',v_pode_analisar,'abrir_parecer',true,'apresentar',v_pode_apresentar)
  );
end;
$$;
create or replace function public.obter_visao_geral_competencia(p_id_competencia uuid)
returns jsonb language sql stable set search_path = '' as $$ select privado.obter_visao_geral_competencia($1) $$;
revoke all on function privado.obter_visao_geral_competencia(uuid) from public, anon, authenticated, service_role;
revoke all on function public.obter_visao_geral_competencia(uuid) from public, anon, authenticated, service_role;
grant execute on function public.obter_visao_geral_competencia(uuid) to authenticated;
