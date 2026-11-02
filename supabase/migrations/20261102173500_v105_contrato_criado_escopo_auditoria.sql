-- V1-05 / PROMPT 26 — criação de contrato por Data API + RLS.
-- Mantém o frontend sem RPC: após um INSERT já autorizado pela policy,
-- garante que o criador com escopo restrito veja o contrato recém-criado
-- e registra a mudança material na auditoria.

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
  -- Para inserções autenticadas, localiza somente o vínculo ativo do próprio
  -- criador na organização do contrato. A policy contratos_insert continua
  -- sendo a autoridade que permite ou nega o INSERT.
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
        id_organizacao,
        id_vinculo_usuario,
        id_contrato,
        ativo,
        revogado_em
      )
      values(
        new.id_organizacao,
        v_vinculo_id,
        new.id,
        true,
        null
      )
      on conflict (id_vinculo_usuario, id_contrato)
      do update set
        ativo = true,
        revogado_em = null;
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
      'inicio', new.inicio,
      'fim', new.fim,
      'valor_global', new.valor_global,
      'periodicidade', new.periodicidade,
      'prazo_prestacao_dias', new.prazo_prestacao_dias,
      'situacao', new.situacao,
      'criticidade', new.criticidade,
      'versao_registro', new.versao_registro
    ),
    jsonb_build_object(
      'origem_operacao', 'v105.data_api_insert'
    )
  );

  return new;
end;
$$;

revoke all on function privado.pos_processar_contrato_criado_v105() from public, anon, authenticated;

drop trigger if exists contaos_contrato_pos_insert_v105 on public.contratos;
create trigger contaos_contrato_pos_insert_v105
after insert on public.contratos
for each row execute function privado.pos_processar_contrato_criado_v105();
