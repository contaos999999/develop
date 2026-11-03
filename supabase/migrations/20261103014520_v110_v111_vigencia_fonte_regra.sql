-- ContaOS 4.1 — V1-CON-002/V1-CON-005
begin;

create or replace function privado.definir_vigencia_sugestao_extracao_v111(
  p_id_sugestao uuid,
  p_vigencia_inicio date,
  p_vigencia_fim date
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v public.sugestoes_extracao_documento%rowtype;
begin
  select * into v from public.sugestoes_extracao_documento where id=p_id_sugestao for update;
  if v.id is null then raise exception using errcode='PT404', message='Não encontramos a sugestão informada.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa() or not privado.usuario_tem_acesso_contrato(v.id_contrato) then
    raise exception using errcode='42501', message='Você não possui acesso ao contrato desta sugestão.';
  end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then
    raise exception using errcode='42501', message='Seu perfil atual não permite definir a vigência desta sugestão.';
  end if;
  if v.status<>'pendente' then raise exception using errcode='PT409', message='Esta sugestão já foi revisada. Atualize a tela.'; end if;
  if p_vigencia_inicio is null then raise exception using errcode='PT400', message='Informe o início da vigência da regra extraída.'; end if;
  if p_vigencia_fim is not null and p_vigencia_fim < p_vigencia_inicio then raise exception using errcode='PT400', message='O fim da vigência não pode ser anterior ao início.'; end if;

  if v.vigencia_inicio is not distinct from p_vigencia_inicio and v.vigencia_fim is not distinct from p_vigencia_fim then
    return jsonb_build_object('status','sem_alteracao','vigencia_inicio',v.vigencia_inicio,'vigencia_fim',v.vigencia_fim);
  end if;

  update public.sugestoes_extracao_documento
     set vigencia_inicio=p_vigencia_inicio, vigencia_fim=p_vigencia_fim
   where id=v.id;

  perform privado.registrar_evento_auditoria(
    v.id_organizacao,'VigenciaSugestaoExtracaoDefinida','sugestoes_extracao_documento',v.id,
    jsonb_build_object('vigencia_inicio',v.vigencia_inicio,'vigencia_fim',v.vigencia_fim),
    jsonb_build_object('vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim)
  );

  return jsonb_build_object('status','atualizada','vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim);
end;
$$;
revoke all on function privado.definir_vigencia_sugestao_extracao_v111(uuid,date,date) from public,anon,authenticated;

create or replace function public.definir_vigencia_sugestao_extracao(
  p_id_sugestao uuid,
  p_vigencia_inicio date,
  p_vigencia_fim date
) returns jsonb
language sql
security invoker
set search_path=''
as $$ select privado.definir_vigencia_sugestao_extracao_v111($1,$2,$3) $$;
revoke all on function public.definir_vigencia_sugestao_extracao(uuid,date,date) from public,anon;
grant execute on function public.definir_vigencia_sugestao_extracao(uuid,date,date) to authenticated;

create or replace function privado.v111_validar_fonte_vigencia_regra_assistida()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_sug public.sugestoes_extracao_documento%rowtype;
  v_id_sug uuid;
begin
  if coalesce(new.configuracao->>'origem','') <> 'sugestao_extracao' then return new; end if;

  begin
    v_id_sug := (new.configuracao->>'id_sugestao')::uuid;
  exception when others then
    raise exception using errcode='PT400', message='Regra assistida sem identificador válido da sugestão de origem.';
  end;

  select * into v_sug from public.sugestoes_extracao_documento where id=v_id_sug;
  if v_sug.id is null then raise exception using errcode='PT400', message='Regra assistida sem sugestão de origem válida.'; end if;
  if v_sug.pagina is null or nullif(btrim(coalesce(v_sug.trecho_fonte,'')),'') is null then
    raise exception using errcode='PT400', message='A regra assistida exige página e trecho da fonte.';
  end if;
  if v_sug.vigencia_inicio is null then
    raise exception using errcode='PT400', message='A regra assistida exige início de vigência antes da aprovação.';
  end if;

  new.vigencia_inicio := v_sug.vigencia_inicio;
  new.vigencia_fim := v_sug.vigencia_fim;
  new.configuracao := coalesce(new.configuracao,'{}'::jsonb) || jsonb_build_object(
    'pagina',v_sug.pagina,
    'trecho_fonte',v_sug.trecho_fonte,
    'vigencia_inicio',v_sug.vigencia_inicio,
    'vigencia_fim',v_sug.vigencia_fim
  );
  return new;
end;
$$;
revoke all on function privado.v111_validar_fonte_vigencia_regra_assistida() from public,anon,authenticated;

drop trigger if exists v111_validar_fonte_vigencia_regra_assistida on public.regras_conformidade;
create trigger v111_validar_fonte_vigencia_regra_assistida
before insert or update on public.regras_conformidade
for each row execute function privado.v111_validar_fonte_vigencia_regra_assistida();

comment on function public.definir_vigencia_sugestao_extracao(uuid,date,date)
  is 'V1-CON-002: define e audita a vigência temporal de sugestão de regra extraída antes da revisão humana.';

commit;
