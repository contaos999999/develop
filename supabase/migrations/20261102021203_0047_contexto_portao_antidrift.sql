-- ContaOS 4.1 - invalidação automática de portão e anti-stale context

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
  if v.id is null then
    raise exception 'Não encontramos a competência informada.';
  end if;

  select jsonb_build_object(
    'id',c.id,
    'numero',c.numero,
    'objeto',c.objeto,
    'tipo_contrato',c.tipo_contrato,
    'inicio',c.inicio,
    'fim',c.fim,
    'valor_global',c.valor_global,
    'periodicidade',c.periodicidade,
    'prazo_prestacao_dias',c.prazo_prestacao_dias,
    'situacao',c.situacao,
    'criticidade',c.criticidade,
    'configuracao_diligencia',c.configuracao_diligencia,
    'configuracao_financeira',c.configuracao_financeira,
    'versao_registro',c.versao_registro
  ) into v_contrato
  from public.contratos c where c.id=v.id_contrato;

  return jsonb_build_object(
    'competencia',jsonb_build_object(
      'id',v.id,
      'referencia',v.competencia_referencia,
      'periodo_inicio',v.periodo_inicio,
      'periodo_fim',v.periodo_fim,
      'data_limite',v.data_limite
    ),
    'contrato',coalesce(v_contrato,'{}'::jsonb),
    'requisitos',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',r.id,
        'origem_tipo',r.origem_tipo,
        'origem_id',r.origem_id,
        'origem_versao',r.origem_versao,
        'codigo',r.codigo,
        'hash',r.hash_snapshot,
        'obrigatorio',r.obrigatorio,
        'aplicavel',r.aplicavel,
        'impeditivo',r.impeditivo,
        'efeito_portao',r.efeito_portao,
        'regra_validacao',r.regra_validacao
      ) order by r.ordem,r.id)
      from public.requisitos_competencia r where r.id_competencia=v.id
    ),'[]'::jsonb),
    'documentos',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id_documento',d.id,
        'tipo',d.tipo,
        'categoria',d.categoria,
        'situacao',d.situacao,
        'id_requisito',d.id_requisito_competencia,
        'id_versao',vd.id,
        'numero_versao',vd.numero_versao,
        'hash',vd.hash
      ) order by d.id)
      from public.documentos_competencia d
      join lateral (
        select x.* from public.versoes_documento x
        where x.id_documento_competencia=d.id
        order by x.numero_versao desc limit 1
      ) vd on true
      where d.id_competencia=v.id and d.situacao='ativo'
    ),'[]'::jsonb),
    'propostas',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id_versao',vp.id,
        'id_proposta',vp.id_proposta,
        'numero_versao',vp.numero_versao,
        'vigencia_inicio',vp.vigencia_inicio,
        'vigencia_fim',vp.vigencia_fim,
        'valor_total',vp.valor_total,
        'hash',vp.hash,
        'situacao',vp.situacao
      ) order by vp.vigencia_inicio,vp.numero_versao,vp.id)
      from public.versoes_proposta vp
      where vp.id_contrato=v.id_contrato
        and vp.vigencia_inicio <= v.periodo_fim
        and (vp.vigencia_fim is null or vp.vigencia_fim >= v.periodo_inicio)
    ),'[]'::jsonb),
    'linhas_orcamentarias',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',l.id,
        'id_versao_proposta',l.id_versao_proposta,
        'codigo',l.codigo,
        'grupo',l.grupo,
        'rubrica',l.rubrica,
        'subrubrica',l.subrubrica,
        'descricao',l.descricao,
        'quantidade',l.quantidade,
        'valor_unitario',l.valor_unitario,
        'valor_total',l.valor_total,
        'limite_remanejamento_percentual',l.limite_remanejamento_percentual,
        'metadados',l.metadados
      ) order by l.codigo,l.id)
      from public.linhas_orcamentarias l
      join public.versoes_proposta vp on vp.id=l.id_versao_proposta
      where l.id_contrato=v.id_contrato
        and vp.vigencia_inicio <= v.periodo_fim
        and (vp.vigencia_fim is null or vp.vigencia_fim >= v.periodo_inicio)
    ),'[]'::jsonb),
    'transacoes',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',t.id,
        'data',t.data,
        'descricao',t.descricao,
        'documento',t.documento,
        'id_fornecedor',t.id_fornecedor,
        'fornecedor_nome_original',t.fornecedor_nome_original,
        'fornecedor_documento_original',t.fornecedor_documento_original,
        'valor',t.valor,
        'tipo',t.tipo,
        'hash_origem',t.hash_origem,
        'id_linha_orcamentaria',t.id_linha_orcamentaria,
        'conta_bancaria',t.conta_bancaria
      ) order by t.data,t.id)
      from public.transacoes_financeiras t
      where t.id_contrato=v.id_contrato and t.data between v.periodo_inicio and v.periodo_fim
    ),'[]'::jsonb),
    'conciliacoes',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',c.id,
        'periodo',c.periodo,
        'tipo',c.tipo,
        'status',c.status,
        'saldo_origem',c.saldo_origem,
        'saldo_contaos',c.saldo_contaos,
        'diferenca',c.diferenca,
        'resultado',c.resultado
      ) order by c.periodo,c.tipo,c.id)
      from public.conciliacoes c
      where c.id_contrato=v.id_contrato
        and c.periodo between date_trunc('month',v.periodo_inicio)::date and date_trunc('month',v.periodo_fim)::date
    ),'[]'::jsonb),
    'motor','contaos',
    'versao_snapshot','4.1',
    'idioma','pt-BR',
    'timezone','America/Sao_Paulo'
  );
end;
$$;

create or replace function privado.hash_contexto_competencia(p_id_competencia uuid)
returns text
language sql
stable
security definer
set search_path=''
as $$
  select encode(extensions.digest(privado.snapshot_contexto_competencia(p_id_competencia)::text,'sha256'),'hex');
$$;

revoke all on function privado.snapshot_contexto_competencia(uuid) from public,anon,authenticated;
revoke all on function privado.hash_contexto_competencia(uuid) from public,anon,authenticated;
grant execute on function privado.snapshot_contexto_competencia(uuid) to service_role;
grant execute on function privado.hash_contexto_competencia(uuid) to service_role;

create or replace function privado.invalidar_portao_competencia(
  p_id_competencia uuid,
  p_motivo text,
  p_entidade_tipo text default null,
  p_entidade_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v public.competencias%rowtype;
  v_status_anterior text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then return false; end if;

  if v.situacao not in ('pode_apresentar_contratante','pode_reapresentar_contratante') then
    return false;
  end if;

  v_status_anterior:=v.situacao;
  update public.competencias
     set situacao='em_reanalise',
         percentual_conformidade=0,
         liberada_para_apresentacao_em=null,
         liberada_para_reapresentacao_em=null
   where id=v.id;

  perform privado.registrar_evento_auditoria(
    v.id_organizacao,
    'PortaoInvalidadoPorAlteracaoMaterial',
    'competencias',
    v.id,
    jsonb_build_object('situacao',v_status_anterior,'percentual_conformidade',v.percentual_conformidade),
    jsonb_build_object(
      'situacao','em_reanalise',
      'percentual_conformidade',0,
      'motivo',coalesce(p_motivo,'Alteração material após liberação.'),
      'entidade_tipo',p_entidade_tipo,
      'entidade_id',p_entidade_id
    )
  );
  return true;
end;
$$;

revoke all on function privado.invalidar_portao_competencia(uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function privado.invalidar_portao_competencia(uuid,text,text,uuid) to service_role;

create or replace function privado.tg_invalidar_portao_documento()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_comp uuid; v_id uuid;
begin
  if tg_table_name='versoes_documento' then
    v_id:=new.id;
    select d.id_competencia into v_comp from public.documentos_competencia d where d.id=new.id_documento_competencia;
  else
    v_id:=coalesce(new.id,old.id);
    v_comp:=coalesce(new.id_competencia,old.id_competencia);
  end if;
  if v_comp is not null then
    perform privado.invalidar_portao_competencia(v_comp,'Alteração documental após liberação exige nova análise completa.',tg_table_name,v_id);
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;

create or replace function privado.tg_invalidar_portao_requisito()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_comp uuid:=coalesce(new.id_competencia,old.id_competencia); v_id uuid:=coalesce(new.id,old.id);
begin
  if v_comp is not null then
    perform privado.invalidar_portao_competencia(v_comp,'Alteração de requisito/dado da competência após liberação exige nova análise completa.',tg_table_name,v_id);
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;

create or replace function privado.tg_invalidar_portao_transacao()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare r record; v_contrato uuid:=coalesce(new.id_contrato,old.id_contrato); v_data date:=coalesce(new.data,old.data); v_id uuid:=coalesce(new.id,old.id);
begin
  if tg_op='UPDATE' and (to_jsonb(new) - 'pre_validada' - 'pre_validada_em' - 'status_fluxo' - 'criado_em') = (to_jsonb(old) - 'pre_validada' - 'pre_validada_em' - 'status_fluxo' - 'criado_em') then
    return new;
  end if;
  for r in select id from public.competencias where id_contrato=v_contrato and v_data between periodo_inicio and periodo_fim loop
    perform privado.invalidar_portao_competencia(r.id,'Alteração de transação financeira após liberação exige nova análise completa.',tg_table_name,v_id);
  end loop;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;

create or replace function privado.tg_invalidar_portao_conciliacao()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare r record; v_contrato uuid:=coalesce(new.id_contrato,old.id_contrato); v_periodo date:=coalesce(new.periodo,old.periodo); v_id uuid:=coalesce(new.id,old.id);
begin
  for r in select id from public.competencias where id_contrato=v_contrato and v_periodo between date_trunc('month',periodo_inicio)::date and date_trunc('month',periodo_fim)::date loop
    perform privado.invalidar_portao_competencia(r.id,'Alteração de conciliação após liberação exige nova análise completa.',tg_table_name,v_id);
  end loop;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;

create or replace function privado.tg_invalidar_portao_contrato()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare r record; v_id uuid:=coalesce(new.id,old.id);
begin
  if tg_op='UPDATE' and (to_jsonb(new)-'atualizado_em'-'versao_registro')=(to_jsonb(old)-'atualizado_em'-'versao_registro') then
    return new;
  end if;
  for r in select id from public.competencias where id_contrato=v_id loop
    perform privado.invalidar_portao_competencia(r.id,'Alteração material do contrato após liberação exige nova análise completa.',tg_table_name,v_id);
  end loop;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;

create or replace function privado.tg_invalidar_portao_proposta()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare r record; v_contrato uuid:=coalesce(new.id_contrato,old.id_contrato); v_ini date:=coalesce(new.vigencia_inicio,old.vigencia_inicio); v_fim date:=coalesce(new.vigencia_fim,old.vigencia_fim); v_id uuid:=coalesce(new.id,old.id);
begin
  for r in select id from public.competencias where id_contrato=v_contrato and v_ini <= periodo_fim and (v_fim is null or v_fim >= periodo_inicio) loop
    perform privado.invalidar_portao_competencia(r.id,'Alteração material de proposta orçamentária após liberação exige nova análise completa.',tg_table_name,v_id);
  end loop;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;

create or replace function privado.tg_invalidar_portao_linha_orcamentaria()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare r record; v_contrato uuid:=coalesce(new.id_contrato,old.id_contrato); v_vp uuid:=coalesce(new.id_versao_proposta,old.id_versao_proposta); v_id uuid:=coalesce(new.id,old.id); v_ini date; v_fim date;
begin
  select vigencia_inicio,vigencia_fim into v_ini,v_fim from public.versoes_proposta where id=v_vp;
  for r in select id from public.competencias where id_contrato=v_contrato and (v_ini is null or v_ini <= periodo_fim) and (v_fim is null or v_fim >= periodo_inicio) loop
    perform privado.invalidar_portao_competencia(r.id,'Alteração material de linha orçamentária após liberação exige nova análise completa.',tg_table_name,v_id);
  end loop;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;

revoke all on function privado.tg_invalidar_portao_documento() from public,anon,authenticated;
revoke all on function privado.tg_invalidar_portao_requisito() from public,anon,authenticated;
revoke all on function privado.tg_invalidar_portao_transacao() from public,anon,authenticated;
revoke all on function privado.tg_invalidar_portao_conciliacao() from public,anon,authenticated;
revoke all on function privado.tg_invalidar_portao_contrato() from public,anon,authenticated;
revoke all on function privado.tg_invalidar_portao_proposta() from public,anon,authenticated;
revoke all on function privado.tg_invalidar_portao_linha_orcamentaria() from public,anon,authenticated;

drop trigger if exists contaos_invalidar_portao_versao_documento on public.versoes_documento;
create trigger contaos_invalidar_portao_versao_documento after insert on public.versoes_documento for each row execute function privado.tg_invalidar_portao_documento();

drop trigger if exists contaos_invalidar_portao_documento on public.documentos_competencia;
create trigger contaos_invalidar_portao_documento after insert or update or delete on public.documentos_competencia for each row execute function privado.tg_invalidar_portao_documento();

drop trigger if exists contaos_invalidar_portao_requisito on public.requisitos_competencia;
create trigger contaos_invalidar_portao_requisito after insert or update or delete on public.requisitos_competencia for each row execute function privado.tg_invalidar_portao_requisito();

drop trigger if exists contaos_invalidar_portao_transacao on public.transacoes_financeiras;
create trigger contaos_invalidar_portao_transacao after insert or update or delete on public.transacoes_financeiras for each row execute function privado.tg_invalidar_portao_transacao();

drop trigger if exists contaos_invalidar_portao_conciliacao on public.conciliacoes;
create trigger contaos_invalidar_portao_conciliacao after insert or update or delete on public.conciliacoes for each row execute function privado.tg_invalidar_portao_conciliacao();

drop trigger if exists contaos_invalidar_portao_contrato on public.contratos;
create trigger contaos_invalidar_portao_contrato after update on public.contratos for each row execute function privado.tg_invalidar_portao_contrato();

drop trigger if exists contaos_invalidar_portao_proposta on public.versoes_proposta;
create trigger contaos_invalidar_portao_proposta after insert or update or delete on public.versoes_proposta for each row execute function privado.tg_invalidar_portao_proposta();

drop trigger if exists contaos_invalidar_portao_linha_orcamentaria on public.linhas_orcamentarias;
create trigger contaos_invalidar_portao_linha_orcamentaria after insert or update or delete on public.linhas_orcamentarias for each row execute function privado.tg_invalidar_portao_linha_orcamentaria();
