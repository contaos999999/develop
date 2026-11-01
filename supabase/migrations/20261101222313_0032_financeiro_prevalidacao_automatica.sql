begin;

drop trigger if exists transacoes_financeiras_enfileirar_prevalidacao on public.transacoes_financeiras;
drop function if exists privado.enfileirar_prevalidacao_financeira();

create or replace function privado.executar_prevalidacao_financeira_apos_insert()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if new.status_fluxo in ('prevista','em_aprovacao','registrada') then
    perform privado.validar_transacao_preventivamente(new.id);
  end if;
  return new;
exception when others then
  perform privado.registrar_evento_auditoria(new.id_organizacao,'PreValidacaoFinanceiraFalhou','transacoes_financeiras',new.id,null,jsonb_build_object('mensagem','Não foi possível concluir a validação preventiva automaticamente. A transação foi preservada e pode ser revalidada.','detalhe_tecnico',sqlerrm));
  return new;
end;
$$;

create trigger transacoes_financeiras_prevalidar after insert on public.transacoes_financeiras for each row execute function privado.executar_prevalidacao_financeira_apos_insert();

commit;
