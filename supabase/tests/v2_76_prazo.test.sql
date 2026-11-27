select set_config('fixture.actor',fixture_id(8)::text,false);
do $$
declare
  parecer uuid;
  outro uuid;
  prazo date;
  recebimento date;
  prova jsonb;
  caso record;
begin
  for caso in select * from (values
    (30,5,null::date,'configuracao_contrato'),
    (31,2,null::date,'configuracao_contrato'),
    (32,null,null::date,'pendente_confirmacao'),
    (33,null,date '2027-01-31','informado'),
    (35,null,null::date,'pendente_confirmacao')
  ) as testes(n,dias,informado,origem) loop
    parecer:=public.registrar_parecer_contratante(
      fixture_id(caso.n),fixture_id(100+caso.n),fixture_id(40+caso.n),
      'Diligência',false,'PRAZO-'||caso.n,date '2026-11-21',caso.informado);
    select c.prazo_resposta,(p.recebido_em at time zone 'America/Sao_Paulo')::date,e.depois
    into strict prazo,recebimento,prova
    from public.pareceres_contratante p
    join public.ciclos_diligencia c on c.id=p.id_ciclo
    join public.eventos_auditoria e on e.id_entidade=p.id and e.evento='ParecerContratanteRegistrado'
    where p.id=parecer;
    if prazo is distinct from coalesce(caso.informado,recebimento+caso.dias) then
      raise exception 'V2_76_PRAZO_RED: vencimento não corresponde à configuração do contrato no caso %',caso.n;
    end if;
    if not (prova ? 'prazo_informado' and prova ? 'prazo_aplicado')
        or (prova->>'prazo_informado')::date is distinct from caso.informado
        or (prova->>'prazo_aplicado')::date is distinct from prazo
        or prova->>'origem_prazo' is distinct from caso.origem then
      raise exception 'V2_76_PRAZO_AUDITORIA: origem incorreta no caso %',caso.n;
    end if;
    if caso.n=30 then
      update public.contratos set configuracao_diligencia='{"prazo_padrao_dias":9,"tipo_contagem":"corridos"}'
        where id=fixture_id(2);
      outro:=public.registrar_parecer_contratante(
        fixture_id(30),fixture_id(130),fixture_id(70),'Diligência',false,'PRAZO-30',date '2026-11-21',null);
      if outro is distinct from parecer or
         (select count(*) from public.execucoes_assincronas where entidade_id=parecer)<>1 then
        raise exception 'V2_76_PRAZO_REPLAY: alteração de configuração mudou o recibo';
      end if;
      outro:=public.registrar_parecer_contratante(
        fixture_id(30),fixture_id(130),fixture_id(40),'Diligência',false,'PRAZO-30B',date '2026-11-22',null);
      if not exists (
        select 1 from public.pareceres_contratante p
        join public.ciclos_diligencia c on c.id=p.id_ciclo
        join public.eventos_auditoria e on e.id_entidade=p.id
        where p.id=outro and c.prazo_resposta=prazo and e.depois->>'origem_prazo'='rodada_existente'
      ) then raise exception 'V2_76_PRAZO_RODADA: prazo da rodada existente foi alterado'; end if;
    end if;
  end loop;
  parecer:=public.registrar_parecer_contratante(
    fixture_id(34),fixture_id(134),fixture_id(74),'Favorável',true,'PRAZO-34',null,null);
  if not exists (select 1 from public.pareceres_contratante where id=parecer and id_ciclo is null)
     or exists (select 1 from public.execucoes_assincronas where entidade_id=parecer)
     or not exists (select 1 from public.eventos_auditoria where id_entidade=parecer
       and depois->>'origem_prazo'='dispensado' and depois->'prazo_aplicado'='null'::jsonb)
  then raise exception 'V2_76_PRAZO_FINAL: parecer favorável gerou obrigação indevida'; end if;
end
$$;
select 'V2_76_PRAZO_GREEN: configuração exata, prazo explícito, pendência, auditoria e recuperação';
