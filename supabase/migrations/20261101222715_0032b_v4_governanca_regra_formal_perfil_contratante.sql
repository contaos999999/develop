-- ContaOS 4.0: promoção controlada de histórico e perfil agregado do contratante.

alter table public.regras_preventivas
  add column if not exists id_fonte_formal_versao uuid references public.versoes_fontes_normativas(id) on delete restrict;

create index if not exists regras_preventivas_fonte_formal_idx on public.regras_preventivas(id_fonte_formal_versao) where id_fonte_formal_versao is not null;

create or replace function privado.propor_regra_de_alerta_transversal_v4(
  p_id_alerta uuid,
  p_id_fonte_formal_versao uuid,
  p_codigo_regra text,
  p_descricao text,
  p_efeito text default 'bloqueio',
  p_criticidade text default 'alta'
)
returns uuid language plpgsql security definer set search_path=''
as $$
declare a public.alertas_historicos_transversais%rowtype; v public.versoes_fontes_normativas%rowtype; f public.fontes_normativas%rowtype; v_regra uuid;
begin
  select * into a from public.alertas_historicos_transversais where id=p_id_alerta for update;
  if a.id is null then raise exception 'Alerta histórico transversal não encontrado.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(a.id_contrato_alvo) or not privado.usuario_possui_perfil(a.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then
    raise exception 'Seu perfil atual não permite propor regra a partir deste alerta.';
  end if;
  if p_efeito not in ('informativo','alerta','bloqueio') then raise exception 'Efeito inválido.'; end if;
  if p_criticidade not in ('baixa','media','alta','critica') then raise exception 'Criticidade inválida.'; end if;
  select * into v from public.versoes_fontes_normativas
   where id=p_id_fonte_formal_versao and id_organizacao=a.id_organizacao and aprovado_em is not null;
  if v.id is null then raise exception 'Selecione uma versão formal, aprovada e pertencente à mesma organização.'; end if;
  select * into f from public.fontes_normativas where id=v.id_fonte;
  if f.id_contrato is not null and f.id_contrato<>a.id_contrato_alvo then
    raise exception 'A fonte formal selecionada não é aplicável ao contrato analisado.';
  end if;
  insert into public.regras_preventivas(
    id_organizacao,id_contrato,codigo_regra,origem_precedente,descricao,efeito,criticidade,escopo_aplicacao,vigencia_inicio,situacao,fonte,id_fonte_formal_versao,motivo
  ) values(
    a.id_organizacao,a.id_contrato_alvo,p_codigo_regra,a.id_precedente,p_descricao,p_efeito,p_criticidade,'contrato',coalesce(v.inicio_vigencia,current_date),'candidata',
    jsonb_build_object('tipo','fonte_formal_independente','id_fonte',f.id,'id_versao',v.id,'referencia',f.referencia,'hash',v.hash),v.id,
    'Proposta originada por alerta transversal. O precedente é apenas contexto; o fundamento impeditivo, quando houver, é a fonte formal independente.'
  ) returning id into v_regra;
  update public.alertas_historicos_transversais set status='revisado' where id=a.id;
  perform privado.registrar_evento_auditoria(a.id_organizacao,'RegraFormalPropostaDeAlertaTransversal','regras_preventivas',v_regra,null,jsonb_build_object('id_alerta',a.id,'id_fonte_versao',v.id));
  return v_regra;
end $$;
revoke all on function privado.propor_regra_de_alerta_transversal_v4(uuid,uuid,text,text,text,text) from public,anon;
grant execute on function privado.propor_regra_de_alerta_transversal_v4(uuid,uuid,text,text,text,text) to authenticated,service_role;

create or replace function public.propor_regra_de_alerta_transversal(
  p_id_alerta uuid,p_id_fonte_formal_versao uuid,p_codigo_regra text,p_descricao text,p_efeito text default 'bloqueio',p_criticidade text default 'alta'
)
returns uuid language sql set search_path=''
as $$ select privado.propor_regra_de_alerta_transversal_v4($1,$2,$3,$4,$5,$6) $$;
revoke all on function public.propor_regra_de_alerta_transversal(uuid,uuid,text,text,text,text) from public,anon;
grant execute on function public.propor_regra_de_alerta_transversal(uuid,uuid,text,text,text,text) to authenticated,service_role;

create or replace function privado.promover_precedente_para_regra(
  p_id_precedente uuid,
  p_codigo_regra text,
  p_descricao text,
  p_efeito text default 'informativo',
  p_criticidade text default 'media',
  p_escopo_aplicacao text default 'contrato'
)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.precedentes%rowtype; v_regra uuid;
begin
  select * into v from public.precedentes where id=p_id_precedente;
  if v.id is null then raise exception 'Precedente não encontrado.'; end if;
  if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if p_efeito not in ('informativo','alerta','bloqueio') then raise exception 'Efeito inválido.'; end if;
  if p_escopo_aplicacao not in ('contrato','contratante','tipo_contrato','organizacao') then raise exception 'Escopo inválido.'; end if;
  insert into public.regras_preventivas(id_organizacao,id_contrato,id_contratante,codigo_regra,origem_precedente,descricao,efeito,criticidade,escopo_aplicacao,tipo_contrato,numero_versao,situacao,motivo)
  select v.id_organizacao,
         case when p_escopo_aplicacao='contrato' then v.id_contrato_origem else null end,
         case when p_escopo_aplicacao='contratante' then v.id_contratante else null end,
         p_codigo_regra,v.id,p_descricao,p_efeito,p_criticidade,p_escopo_aplicacao,
         case when p_escopo_aplicacao='tipo_contrato' then c.tipo_contrato else null end,1,'candidata',
         'Regra candidata originada de precedente histórico. Nenhuma ativação ocorre sem revisão humana.'
  from public.contratos c where c.id=v.id_contrato_origem returning id into v_regra;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'PrecedenteConvertidoEmRegraCandidata','regras_preventivas',v_regra,null,jsonb_build_object('id_precedente',v.id,'codigo_regra',p_codigo_regra,'efeito_solicitado',p_efeito,'escopo',p_escopo_aplicacao));
  return v_regra;
end $$;

create or replace function privado.aprovar_regra_preventiva(p_id_regra_preventiva uuid,p_parecer text default null)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.regras_preventivas%rowtype; p public.precedentes%rowtype; vf public.versoes_fontes_normativas%rowtype; f public.fontes_normativas%rowtype; v_revisao uuid; v_exige_fonte boolean:=false;
begin
  select * into v from public.regras_preventivas where id=p_id_regra_preventiva for update;
  if v.id is null then raise exception 'Não encontramos a regra preventiva informada.'; end if;
  if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
  if not privado.usuario_tem_acesso_organizacao(v.id_organizacao) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite aprovar esta regra preventiva.'; end if;
  if v.situacao<>'candidata' then raise exception 'Somente uma regra candidata pode ser aprovada.'; end if;
  if nullif(trim(v.codigo_regra),'') is null or nullif(trim(v.descricao),'') is null then raise exception 'A regra precisa de código e descrição antes da aprovação.'; end if;
  if v.escopo_aplicacao='contrato' and v.id_contrato is null then raise exception 'Informe o contrato ao qual esta regra se aplica.'; end if;
  if v.escopo_aplicacao='contratante' and v.id_contratante is null then raise exception 'Informe o contratante ao qual esta regra se aplica.'; end if;
  if v.escopo_aplicacao='tipo_contrato' and nullif(trim(coalesce(v.tipo_contrato,'')),'') is null then raise exception 'Informe o tipo de contrato ao qual esta regra se aplica.'; end if;
  if v.origem_precedente is not null then
    select * into p from public.precedentes where id=v.origem_precedente;
    v_exige_fonte := (v.efeito='bloqueio' and (v.escopo_aplicacao<>'contrato' or v.id_contrato is distinct from p.id_contrato_origem));
  end if;
  if v_exige_fonte and v.id_fonte_formal_versao is null then
    raise exception 'Regra impeditiva originada de histórico transversal exige fonte formal independente aplicável ao contrato atual.';
  end if;
  if v.id_fonte_formal_versao is not null then
    select * into vf from public.versoes_fontes_normativas where id=v.id_fonte_formal_versao and id_organizacao=v.id_organizacao and aprovado_em is not null;
    if vf.id is null then raise exception 'A fonte formal vinculada não possui versão aprovada válida.'; end if;
    select * into f from public.fontes_normativas where id=vf.id_fonte;
    if v.id_contrato is not null and f.id_contrato is not null and f.id_contrato<>v.id_contrato then raise exception 'A fonte formal vinculada pertence a outro contrato.'; end if;
    if v.vigencia_inicio is not null and vf.fim_vigencia is not null and v.vigencia_inicio>vf.fim_vigencia then raise exception 'A vigência proposta para a regra está fora da vigência da fonte formal.'; end if;
  elsif v.origem_precedente is null and v.fonte='{}'::jsonb then
    raise exception 'Inclua a fonte que fundamenta esta regra antes de aprová-la.';
  end if;
  update public.regras_preventivas set situacao='ativa',aprovada_por=auth.uid(),aprovada_em=now() where id=v.id;
  insert into public.revisoes_regras_preventivas(id_organizacao,id_contrato,id_regra,versao,decisao,fundamento,revisor,snapshot)
  values(v.id_organizacao,v.id_contrato,v.id,v.numero_versao,'aprovada',coalesce(nullif(trim(p_parecer),''),'Regra preventiva aprovada após revisão humana.'),auth.uid(),
         jsonb_build_object('codigo_regra',v.codigo_regra,'escopo_aplicacao',v.escopo_aplicacao,'efeito',v.efeito,'criticidade',v.criticidade,'fonte',v.fonte,'id_fonte_formal_versao',v.id_fonte_formal_versao,'origem_precedente',v.origem_precedente))
  returning id into v_revisao;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraPreventivaAprovada','regras_preventivas',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','ativa','id_revisao',v_revisao));
  return v_revisao;
end $$;

create or replace function privado.recalcular_perfil_contratante_v4(p_id_organizacao uuid,p_id_contratante uuid)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_perfil uuid; v_versao integer; v_pad jsonb; v_met jsonb; v_div jsonb;
begin
  if not exists(select 1 from public.contratantes c where c.id=p_id_contratante and c.id_organizacao=p_id_organizacao) then raise exception 'Contratante não encontrado nesta organização.'; end if;
  select coalesce(max(versao),0)+1 into v_versao from public.perfis_contratante where id_organizacao=p_id_organizacao and id_contratante=p_id_contratante;
  select coalesce(jsonb_agg(x order by (x->>'quantidade')::int desc),'[]'::jsonb) into v_pad
  from (
    select jsonb_build_object('categoria',coalesce(p.categoria,'sem_categoria'),'quantidade',count(*),'tipo','padrao_observado','fonte','precedentes_historicos') x
    from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo'
    group by coalesce(p.categoria,'sem_categoria')
  ) s;
  select jsonb_build_object(
    'total_precedentes',(select count(*) from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante),
    'contratos_com_historico',(select count(distinct p.id_contrato_origem) from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante),
    'tempo_medio_analise_dias',(
      select round(avg(extract(epoch from (pc.recebido_em-a.apresentado_em))/86400.0)::numeric,2)
      from public.apresentacoes_contratante a join public.pareceres_contratante pc on pc.id_apresentacao=a.id
      join public.contratos c on c.id=a.id_contrato
      where a.id_organizacao=p_id_organizacao and c.id_contratante=p_id_contratante and pc.recebido_em>=a.apresentado_em
    ),
    'media_rodadas',(
      select round(avg(z.rodadas)::numeric,2) from (
        select max(a.numero_rodada)::numeric rodadas from public.apresentacoes_contratante a join public.contratos c on c.id=a.id_contrato
        where a.id_organizacao=p_id_organizacao and c.id_contratante=p_id_contratante group by a.id_competencia
      ) z
    )
  ) into v_met;
  select coalesce(jsonb_agg(x),'[]'::jsonb) into v_div
  from (
    select jsonb_build_object('categoria',coalesce(p.categoria,'sem_categoria'),'desfechos',jsonb_agg(distinct coalesce(p.desfecho,'sem_desfecho')),'tipo','divergencia_historica') x
    from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo'
    group by coalesce(p.categoria,'sem_categoria')
    having count(distinct lower(coalesce(p.desfecho,'')))>1
  ) q;
  insert into public.perfis_contratante(id_organizacao,id_contratante,versao,resumo,padroes,metricas)
  values(p_id_organizacao,p_id_contratante,v_versao,'Perfil histórico calculado a partir de precedentes rastreáveis. Padrões observados não constituem norma formal.',v_pad||v_div,v_met)
  returning id into v_perfil;
  return v_perfil;
end $$;
revoke all on function privado.recalcular_perfil_contratante_v4(uuid,uuid) from public,anon,authenticated;
grant execute on function privado.recalcular_perfil_contratante_v4(uuid,uuid) to service_role;

create or replace function public.worker_recalcular_perfil_contratante_v4(p_id_organizacao uuid,p_id_contratante uuid)
returns uuid language sql security definer set search_path=''
as $$ select privado.recalcular_perfil_contratante_v4($1,$2) $$;
revoke all on function public.worker_recalcular_perfil_contratante_v4(uuid,uuid) from public,anon,authenticated;
grant execute on function public.worker_recalcular_perfil_contratante_v4(uuid,uuid) to service_role;
