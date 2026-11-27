begin;

create or replace function privado.registrar_parecer_contratante(
  p_id_competencia uuid, p_id_apresentacao uuid, p_id_arquivo uuid, p_resultado_geral text,
  p_parecer_final_favoravel boolean default false, p_numero_documento text default null,
  p_data_emissao date default null, p_prazo_resposta date default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare
  v public.competencias%rowtype;
  anterior public.pareceres_contratante%rowtype;
  apresentacao public.apresentacoes_contratante%rowtype;
  v_parecer uuid;
  v_ciclo uuid;
  prazo_atual date;
  prazo_aplicado date;
  origem_prazo text := 'dispensado';
  config_prazo jsonb;
  dias_prazo numeric;
  data_recebimento date := (now() at time zone 'America/Sao_Paulo')::date;
  v_rodada integer;
  resultado text := nullif(btrim(p_resultado_geral),'');
  numero text := nullif(btrim(p_numero_documento),'');
begin
  if auth.uid() is null or not privado.sessao_usuario_ativa() then
    raise exception using errcode='42501',message='Sua sessão não está ativa.';
  end if;
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null or not privado.usuario_tem_acesso_contrato(v.id_contrato)
     or not privado.usuario_possui_perfil(v.id_organizacao,
       array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade','direcao_aprovador']::text[]) then
    raise exception using errcode='42501',message='Você não possui acesso ao registro de parecer nesta competência.';
  end if;
  if resultado is null or length(resultado)>200 or length(numero)>120 or p_parecer_final_favoravel is null then
    raise exception using errcode='PT400',message='Informe a classificação e confira os dados do parecer.';
  end if;

  select * into apresentacao
  from public.apresentacoes_contratante a
  where a.id=p_id_apresentacao
    and (a.id_organizacao,a.id_contrato,a.id_competencia)=(v.id_organizacao,v.id_contrato,v.id)
  for share of a;
  if apresentacao.id is null then
    raise exception using errcode='42501',message='A apresentação não pertence a esta competência.';
  end if;

  -- A competência bloqueada serializa a decisão de repetir, reutilizar o ciclo ou inserir.
  select * into anterior
  from public.pareceres_contratante p
  where (p.id_organizacao,p.id_contrato,p.id_competencia,p.id_apresentacao,p.id_arquivo)
        =(v.id_organizacao,v.id_contrato,v.id,apresentacao.id,p_id_arquivo)
  order by p.recebido_em,p.id limit 1;
  if found then
    select case when e.depois ? 'prazo_informado'
                then (e.depois->>'prazo_informado')::date else c.prazo_resposta end
    into prazo_atual
    from public.pareceres_contratante p
    left join public.ciclos_diligencia c on c.id=p.id_ciclo
    left join public.eventos_auditoria e on e.id_entidade=p.id
      and e.id_organizacao=p.id_organizacao and e.entidade='pareceres_contratante'
      and e.evento='ParecerContratanteRegistrado'
    where p.id=anterior.id
    order by (e.depois ? 'prazo_informado') desc nulls last limit 1;
    if (anterior.registrado_por,btrim(anterior.resultado_geral),anterior.parecer_final_favoravel,
         nullif(btrim(anterior.numero_documento),''),anterior.data_emissao,prazo_atual)
      is distinct from (auth.uid(),resultado,p_parecer_final_favoravel,numero,p_data_emissao,p_prazo_resposta)
      or exists(select 1 from public.pareceres_contratante x
        where x.id<>anterior.id and
         (x.id_organizacao,x.id_contrato,x.id_competencia,x.id_apresentacao,x.id_arquivo)
         =(v.id_organizacao,v.id_contrato,v.id,apresentacao.id,p_id_arquivo)) then
      raise exception using errcode='PT409',message='Já existe um registro diferente para este arquivo e apresentação.';
    end if;
    return anterior.id;
  end if;

  if v.situacao not in ('aguardando_contratante','reapresentado','com_apontamentos') or exists(
      select 1 from public.apresentacoes_contratante a
      where (a.id_organizacao,a.id_contrato,a.id_competencia)=(v.id_organizacao,v.id_contrato,v.id)
        and a.numero_rodada>apresentacao.numero_rodada
  ) then
    raise exception using errcode='PT409',message='A competência ou a rodada apresentada mudou. Atualize a consulta.';
  end if;
  perform 1 from public.arquivos a
  where a.id=p_id_arquivo and (a.id_organizacao,a.id_contrato)=(v.id_organizacao,v.id_contrato)
    and a.status_seguranca='aprovado' and a.sha256 ~ '^[0-9a-fA-F]{64}$'
  for share of a;
  if not found then
    raise exception using errcode='42501',message='O arquivo não está aprovado para este contrato.';
  end if;

  if not p_parecer_final_favoravel then
    -- O registro de reapresentação pode estar com o ciclo bloqueado antes da competência.
    -- Falhe de forma recuperável em vez de aguardar uma trava na ordem inversa.
    begin
      select c.id,c.prazo_resposta into v_ciclo,prazo_atual
      from public.ciclos_diligencia c
      where (c.id_organizacao,c.id_contrato,c.id_competencia)=(v.id_organizacao,v.id_contrato,v.id)
        and c.status in ('aberto','em_tratamento')
        and exists(select 1 from public.pareceres_contratante p
          where (p.id_organizacao,p.id_contrato,p.id_competencia,p.id_ciclo,p.id_apresentacao)
            =(v.id_organizacao,v.id_contrato,v.id,c.id,apresentacao.id))
      order by c.numero_rodada desc limit 1 for update of c nowait;
    exception when lock_not_available then
      raise exception using errcode='PT409',message='A rodada está sendo alterada. Atualize a consulta.';
    end;
    if v_ciclo is null then
      select coalesce(max(numero_rodada),0)+1 into v_rodada from public.ciclos_diligencia
      where id_competencia=v.id;
      if p_prazo_resposta is not null then
        prazo_aplicado := p_prazo_resposta;
        origem_prazo := 'informado';
      else
        origem_prazo := 'pendente_confirmacao';
        select c.configuracao_diligencia into config_prazo
        from public.contratos c
        where (c.id,c.id_organizacao)=(v.id_contrato,v.id_organizacao);
        if config_prazo->>'tipo_contagem' = 'corridos'
           and jsonb_typeof(config_prazo->'prazo_padrao_dias') = 'number' then
          dias_prazo := (config_prazo->>'prazo_padrao_dias')::numeric;
          if dias_prazo = trunc(dias_prazo) and dias_prazo between 0 and date '9999-12-31' - data_recebimento then
            prazo_aplicado := data_recebimento + dias_prazo::integer;
            origem_prazo := 'configuracao_contrato';
          end if;
        end if;
      end if;
      insert into public.ciclos_diligencia(id_organizacao,id_contrato,id_competencia,numero_rodada,status,prazo_resposta)
      values(v.id_organizacao,v.id_contrato,v.id,v_rodada,'aberto',prazo_aplicado) returning id into v_ciclo;
    else
      if p_prazo_resposta is not null and prazo_atual is distinct from p_prazo_resposta then
        raise exception using errcode='PT409',message='Confira o prazo já registrado para a rodada aberta.';
      end if;
      prazo_aplicado := prazo_atual;
      origem_prazo := 'rodada_existente';
    end if;
  end if;

  insert into public.pareceres_contratante(id_organizacao,id_contrato,id_competencia,id_ciclo,id_apresentacao,
      id_arquivo,resultado_geral,parecer_final_favoravel,numero_documento,data_emissao,registrado_por)
  values(v.id_organizacao,v.id_contrato,v.id,v_ciclo,apresentacao.id,p_id_arquivo,resultado,
      p_parecer_final_favoravel,numero,p_data_emissao,auth.uid()) returning id into v_parecer;

  if p_parecer_final_favoravel then
    update public.competencias set situacao='validada',validada_em=now() where id=v.id;
  else
    update public.competencias set situacao='com_apontamentos' where id=v.id;
  end if;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'ParecerContratanteRegistrado',
    'pareceres_contratante',v_parecer,null,jsonb_build_object('final_favoravel',p_parecer_final_favoravel,
      'id_ciclo',v_ciclo,'id_apresentacao',apresentacao.id,'id_arquivo',p_id_arquivo,
      'prazo_informado',p_prazo_resposta,'prazo_aplicado',prazo_aplicado,'origem_prazo',origem_prazo));
  return v_parecer;
end;
$$;

commit;
