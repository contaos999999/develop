alter table public.contratos
  add column if not exists unidade_vinculada text,
  add column if not exists fonte_recurso text,
  add column if not exists valor_mensal_referencia numeric(18,2),
  add column if not exists dia_limite_apresentacao smallint,
  add column if not exists conta_bancaria_vinculada text;

update public.contratos
   set periodicidade = 'mensal'
 where periodicidade is null or btrim(periodicidade) = '';

alter table public.contratos
  alter column periodicidade set default 'mensal',
  alter column periodicidade set not null,
  alter column inicio set not null;

alter table public.contratos
  drop constraint if exists contratos_periodicidade_ck,
  add constraint contratos_periodicidade_ck check (btrim(periodicidade) <> ''),
  drop constraint if exists contratos_valor_global_ck,
  add constraint contratos_valor_global_ck check (valor_global is null or valor_global >= 0),
  drop constraint if exists contratos_valor_mensal_referencia_ck,
  add constraint contratos_valor_mensal_referencia_ck check (valor_mensal_referencia is null or valor_mensal_referencia >= 0),
  drop constraint if exists contratos_prazo_prestacao_dias_ck,
  add constraint contratos_prazo_prestacao_dias_ck check (prazo_prestacao_dias is null or prazo_prestacao_dias > 0),
  drop constraint if exists contratos_dia_limite_apresentacao_ck,
  add constraint contratos_dia_limite_apresentacao_ck check (dia_limite_apresentacao is null or dia_limite_apresentacao between 1 and 31);

create or replace function privado.pos_processar_contrato_criado_v105()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_vinculo_id uuid;
  v_escopo_todos boolean;
begin
  if auth.uid() is not null then
    select vu.id, vu.escopo_todos_contratos
      into v_vinculo_id, v_escopo_todos
      from public.vinculos_usuarios vu
     where vu.id_organizacao = new.id_organizacao
       and vu.id_usuario = auth.uid()
       and vu.ativo = true
       and vu.inicio_em <= now()
       and (vu.fim_em is null or vu.fim_em > now())
     limit 1;

    if v_vinculo_id is not null and not coalesce(v_escopo_todos, false) then
      insert into public.vinculos_usuario_contratos(
        id_organizacao, id_vinculo_usuario, id_contrato, ativo, revogado_em
      )
      values(new.id_organizacao, v_vinculo_id, new.id, true, null)
      on conflict (id_vinculo_usuario, id_contrato)
      do update set ativo=true, revogado_em=null;
    end if;
  end if;

  perform privado.registrar_evento_auditoria(
    new.id_organizacao,
    'ContratoCriado',
    'contratos',
    new.id,
    null,
    jsonb_build_object(
      'id_contratante', new.id_contratante,
      'numero', new.numero,
      'objeto', new.objeto,
      'tipo_contrato', new.tipo_contrato,
      'unidade_vinculada', new.unidade_vinculada,
      'fonte_recurso', new.fonte_recurso,
      'inicio', new.inicio,
      'fim', new.fim,
      'valor_global', new.valor_global,
      'valor_mensal_referencia', new.valor_mensal_referencia,
      'periodicidade', new.periodicidade,
      'prazo_prestacao_dias', new.prazo_prestacao_dias,
      'dia_limite_apresentacao', new.dia_limite_apresentacao,
      'conta_bancaria_vinculada', new.conta_bancaria_vinculada,
      'situacao', new.situacao,
      'criticidade', new.criticidade,
      'versao_registro', new.versao_registro
    ),
    jsonb_build_object('origem_operacao','v105.data_api_insert')
  );

  return new;
end;
$$;

revoke all on function privado.pos_processar_contrato_criado_v105() from public, anon, authenticated;
