create function public.fixture_negar(c integer,a integer,f integer,s text,resultado text default 'Diligência')
returns void language plpgsql as $$
begin
  begin
    perform public.registrar_parecer_contratante(fixture_id(c),fixture_id(a),fixture_id(f),resultado,false,'P-76',date '2026-11-25',date '2026-12-04');
  exception when others then
    if sqlstate=s then return; end if;
    raise;
  end;
  raise exception 'V2_76_RED: registro de parecer sem validação exata';
end
$$;

select set_config('fixture.actor',fixture_id(8)::text,false);
select fixture_negar(20,121,40,'42501');
select fixture_negar(20,120,41,'42501');
select fixture_negar(20,120,42,'42501');
select fixture_negar(20,120,40,'PT400',' ');

do $$
declare parecer uuid; repetido uuid; outro uuid; ciclo uuid; estado jsonb;
begin
  parecer:=public.registrar_parecer_contratante(fixture_id(20),fixture_id(120),fixture_id(40),'Diligência',false,'P-76',date '2026-11-25',date '2026-12-04');
  repetido:=public.registrar_parecer_contratante(fixture_id(20),fixture_id(120),fixture_id(40),'Diligência',false,'P-76',date '2026-11-25',date '2026-12-04');
  outro:=public.registrar_parecer_contratante(fixture_id(20),fixture_id(120),fixture_id(43),'Ressalvas',false,'P-77',date '2026-11-26',date '2026-12-04');
  select id_ciclo into ciclo from public.pareceres_contratante where id=parecer;
  if parecer is null or parecer is distinct from repetido or outro is null or outro=parecer
     or not exists(select 1 from public.pareceres_contratante
        where id=outro and id_ciclo=ciclo and id_apresentacao=fixture_id(120))
     or (select count(*) from public.execucoes_assincronas where entidade_id in(parecer,outro))<>2
     or not exists(select 1 from public.eventos_auditoria e
        where e.id_entidade=parecer and e.depois->>'id_apresentacao'=fixture_id(120)::text
          and e.depois->>'id_arquivo'=fixture_id(40)::text and e.depois->>'id_ciclo'=ciclo::text)
  then raise exception 'Vínculos do parecer, ciclo e fila incorretos'; end if;
  estado:=public.obter_processamento_parecer_v2(fixture_id(20),parecer);
  if estado->>'status'<>'enfileirado' or estado->>'id_parecer'<>parecer::text or estado ? 'erro_detalhe'
     or estado::text like '%conteúdo privado%' then raise exception 'Leitura de fila inválida'; end if;
  update public.execucoes_assincronas set status='falhou',tentativas=3 where entidade_id=parecer;
  estado:=public.obter_processamento_parecer_v2(fixture_id(20),parecer);
  if estado->>'status'<>'falhou' or estado->>'tentativas'<>'3' or estado::text like '%conteúdo privado%'
     then raise exception 'Estado de falha ou escopo inválido'; end if;
  begin
    perform public.obter_processamento_parecer_v2(fixture_id(21),parecer);
    raise exception 'Leitura cruzada indevida';
  exception when insufficient_privilege then null;
  end;
end
$$;
select fixture_negar(20,120,40,'PT409','Divergente');
select set_config('fixture.actor',fixture_id(7)::text,false);
select fixture_negar(20,120,40,'PT409');
select set_config('fixture.disabled','true',false);
select fixture_negar(21,121,40,'42501');
select set_config('fixture.disabled','false',false);
select set_config('fixture.profile_denied','true',false);
select fixture_negar(21,121,40,'42501');
select set_config('fixture.profile_denied','false',false);
select set_config('fixture.contract_denied','true',false);
select fixture_negar(21,121,40,'42501');
select set_config('fixture.contract_denied','false',false);

do $$
declare parecer uuid;
begin
  parecer:=public.registrar_parecer_contratante(fixture_id(21),fixture_id(121),fixture_id(44),'Favorável',true,'PF-76',date '2026-11-27',null);
  if not exists(select 1 from public.competencias where id=fixture_id(21) and situacao='validada')
     or exists(select 1 from public.execucoes_assincronas where entidade_id=parecer)
     or not exists(select 1 from public.pareceres_contratante where id=parecer and id_ciclo is null)
     then raise exception 'Parecer final favorável incorreto'; end if;
end
$$;
select fixture_negar(21,121,45,'PT409');
select 'V2_76_GREEN: parecer, arquivo, apresentação, fila, auditoria e validação final';
