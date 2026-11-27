begin;

alter table public.desfechos_apontamentos
  add column id_contestacao uuid references public.contestacoes(id) on delete restrict;
create unique index desfechos_contestacao_resultado_uidx
  on public.desfechos_apontamentos(id_contestacao,tipo_desfecho) where id_contestacao is not null;

create or replace function privado.registrar_desfecho_contestacao(p_id_contestacao uuid,p_resultado text,p_texto text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  pista public.contestacoes%rowtype;
  v public.contestacoes%rowtype;
  rodada public.ciclos_diligencia%rowtype;
  comp public.competencias%rowtype;
  item public.apontamentos_contratante%rowtype;
  anterior public.desfechos_apontamentos%rowtype;
  v_desfecho uuid;
  v_contratante uuid;
  v_prec uuid;
  v_quantidade integer;
  v_ator uuid := auth.uid();
begin
  if v_ator is null or not coalesce(privado.sessao_usuario_ativa(),false) then
    raise exception using errcode='42501',message='Sua sessão não está ativa.';
  end if;
  select * into pista from public.contestacoes where id=p_id_contestacao;
  if not found or not coalesce(privado.usuario_tem_acesso_contrato(pista.id_contrato),false)
     or not coalesce(privado.usuario_possui_perfil(pista.id_organizacao,
       array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]),false) then
    raise exception using errcode='42501',message='Contestação indisponível para esta operação.';
  end if;
  if p_resultado is null or p_resultado not in ('aceita','rejeitada','parcialmente_aceita','pendente')
     or (p_texto is not null and length(btrim(p_texto))=0) then
    raise exception using errcode='PT400',message='Informe um resultado válido e, se houver, o texto da decisão.';
  end if;

  -- Mesma ordem de bloqueio da rodada/reapresentação e revisão de contestação.
  select * into rodada from public.ciclos_diligencia where id=pista.id_ciclo for update;
  if not found or (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia)
      is distinct from (pista.id_organizacao,pista.id_contrato,pista.id_competencia) then
    raise exception using errcode='42501',message='Contestação indisponível para esta operação.';
  end if;
  select * into comp from public.competencias where id=pista.id_competencia for update;
  if not found or (comp.id_organizacao,comp.id_contrato)
      is distinct from (pista.id_organizacao,pista.id_contrato) then
    raise exception using errcode='42501',message='Contestação indisponível para esta operação.';
  end if;
  select * into item from public.apontamentos_contratante where id=pista.id_apontamento for update;
  if not found or (item.id_organizacao,item.id_contrato,item.id_competencia,item.id_ciclo)
      is distinct from (pista.id_organizacao,pista.id_contrato,pista.id_competencia,pista.id_ciclo) then
    raise exception using errcode='42501',message='Contestação indisponível para esta operação.';
  end if;
  select * into v from public.contestacoes where id=p_id_contestacao for update;
  if not found or (v.id_organizacao,v.id_contrato,v.id_competencia,v.id_ciclo,v.id_apontamento,v.versao)
      is distinct from (pista.id_organizacao,pista.id_contrato,pista.id_competencia,pista.id_ciclo,pista.id_apontamento,pista.versao)
      or not coalesce(privado.sessao_usuario_ativa(),false)
      or not coalesce(privado.usuario_tem_acesso_contrato(v.id_contrato),false)
      or not coalesce(privado.usuario_possui_perfil(v.id_organizacao,
         array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]),false) then
    raise exception using errcode='42501',message='Contestação indisponível para esta operação.';
  end if;
  select id_contratante into v_contratante from public.contratos
    where id=v.id_contrato and id_organizacao=v.id_organizacao;
  if not found or v_contratante is null then
    raise exception using errcode='42501',message='Contestação indisponível para esta operação.';
  end if;

  -- Replay da intenção exata não reaplica qualquer efeito, mesmo após resultado posterior.
  select * into anterior from public.desfechos_apontamentos
    where id_contestacao=v.id and tipo_desfecho='contestacao_'||p_resultado for update;
  if found then
    if (anterior.id_organizacao,anterior.id_contrato,anterior.id_competencia,anterior.id_apontamento)
       is distinct from (v.id_organizacao,v.id_contrato,v.id_competencia,v.id_apontamento) then
      raise exception using errcode='42501',message='Vínculo de desfecho indisponível.';
    end if;
    if anterior.criado_por is distinct from v_ator or anterior.texto is distinct from p_texto then
      raise exception using errcode='PT409',message='Já existe um desfecho desta contestação com outra intenção.';
    end if;
    return anterior.id;
  end if;

  if v.status_aprovacao is distinct from 'aprovada' or v.aprovado_por is null or v.aprovado_em is null then
    raise exception using errcode='PT409',message='A contestação deve estar aprovada para registrar uma decisão.';
  end if;
  if exists(select 1 from public.desfechos_apontamentos d
     where d.id_apontamento=v.id_apontamento and d.id_contestacao is null
       and left(d.tipo_desfecho,12)='contestacao_') then
    raise exception using errcode='PT409',message='Há desfecho legado que requer conciliação de origem.';
  end if;
  if exists(select 1 from public.desfechos_apontamentos d
     where d.id_contestacao=v.id and
     ((d.id_organizacao,d.id_contrato,d.id_competencia,d.id_apontamento)
       is distinct from (v.id_organizacao,v.id_contrato,v.id_competencia,v.id_apontamento))) then
    raise exception using errcode='42501',message='Vínculo de desfecho indisponível.';
  end if;
  if exists(select 1 from public.desfechos_apontamentos d where d.id_contestacao=v.id
      and d.tipo_desfecho<>'contestacao_pendente') then
    raise exception using errcode='PT409',message='Já existe decisão final desta contestação.';
  end if;
  if v.resultado_final is not null then
    if v.resultado_final<>'pendente' or p_resultado='pendente' or not exists(
      select 1 from public.desfechos_apontamentos d where d.id_contestacao=v.id
         and d.tipo_desfecho='contestacao_pendente') then
      raise exception using errcode='PT409',message='O resultado existente requer conciliação antes de novo registro.';
    end if;
  elsif exists(select 1 from public.desfechos_apontamentos d where d.id_contestacao=v.id) then
    raise exception using errcode='PT409',message='O resultado existente requer conciliação antes de novo registro.';
  end if;

  -- O resultado pendente não constitui aprendizado ou encerramento.
  if p_resultado<>'pendente' then
    select count(*) into v_quantidade from public.precedentes
      where id_organizacao=v.id_organizacao and id_contrato_origem=v.id_contrato
        and fonte_tipo='apontamento_contratante' and fonte_id=v.id_apontamento;
    if v_quantidade>1 then
      raise exception using errcode='PT409',message='Há precedentes divergentes que exigem conciliação.';
    end if;
    select id into v_prec from public.precedentes
      where id_organizacao=v.id_organizacao and id_contrato_origem=v.id_contrato
        and id_contratante=v_contratante and fonte_tipo='apontamento_contratante'
        and fonte_id=v.id_apontamento for update;
    if v_quantidade=1 and v_prec is null then
      raise exception using errcode='PT409',message='Há precedente com origem inconsistente.';
    end if;
  end if;

  update public.contestacoes set resultado_final=p_resultado,resultado_registrado_em=now() where id=v.id;
  insert into public.desfechos_apontamentos(id_organizacao,id_contrato,id_competencia,id_apontamento,
      id_contestacao,tipo_desfecho,texto,criado_por)
    values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id_apontamento,v.id,
      'contestacao_'||p_resultado,p_texto,v_ator) returning id into v_desfecho;

  if p_resultado<>'pendente' then
    update public.apontamentos_contratante set status=case when p_resultado in ('aceita','parcialmente_aceita')
      then 'encerrado' else 'em_tratamento' end where id=item.id;
    if v_prec is null then
      insert into public.precedentes(id_organizacao,id_contratante,id_contrato_origem,competencia_origem,
          problema,solucao,desfecho,fonte_tipo,fonte_id,confianca,status,ultima_confirmacao_em,confirmacoes)
        values(v.id_organizacao,v_contratante,v.id_contrato,comp.competencia_referencia,item.descricao,v.texto,
          p_resultado,'apontamento_contratante',item.id,
          case when p_resultado='aceita' then 0.85 when p_resultado='parcialmente_aceita' then 0.65 else 0.45 end,
          'ativo',now(),1) returning id into v_prec;
    else
      update public.precedentes set desfecho=p_resultado,confirmacoes=confirmacoes+1,
        ultima_confirmacao_em=now(),confianca=greatest(0,least(1,coalesce(confianca,0.5)+
        case when p_resultado='aceita' then 0.08 when p_resultado='parcialmente_aceita' then 0.03 else -0.05 end))
        where id=v_prec;
    end if;
    perform privado.enfileirar_job('embeddings',v.id_organizacao,v.id_contrato,'precedente',v_prec,
      jsonb_build_object('entidade_tipo','precedente','entidade_id',v_prec,'id_desfecho',v_desfecho),
      'embed:precedente:'||v_prec::text||':'||v_desfecho::text);
    perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'aprendizado_desfecho',v_desfecho,
      jsonb_build_object('entidade_tipo','aprendizado_desfecho','id_desfecho',v_desfecho,'id_precedente',v_prec),
      'learning:'||v_desfecho::text);
  end if;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'DesfechoContestacaoRegistrado','contestacoes',v.id,
    jsonb_build_object('resultado',v.resultado_final),
    jsonb_build_object('resultado',p_resultado,'id_desfecho',v_desfecho,'id_precedente',v_prec,
      'id_contestacao',v.id,'versao_contestacao',v.versao,'id_apontamento',v.id_apontamento,
      'id_ciclo',v.id_ciclo,'id_competencia',v.id_competencia,'id_contrato',v.id_contrato));
  return v_desfecho;
end;
$$;

commit;
