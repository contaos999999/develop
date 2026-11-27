create function public.fixture_negacao(ciclo integer,chave text,protocolo text,arquivo integer,esperado text)
returns void language plpgsql as $$
begin
  begin
    perform public.registrar_reapresentacao(fixture_id(ciclo),chave,protocolo,'eletronica',fixture_id(arquivo));
  exception when others then
    if sqlstate = esperado then return; end if;
    raise;
  end;
  raise exception 'V2_49_RED: validação de reapresentação ausente';
end
$$;

select set_config('fixture.actor',fixture_id(8)::text,false);
select fixture_negacao(22,'fora-do-contrato','P-22',40,'42501');
select fixture_negacao(23,'fora-da-org','P-23',42,'42501');
select fixture_negacao(23,'quarentena','P-23',43,'42501');

do $$
declare original uuid;
begin
  original:=public.registrar_reapresentacao(fixture_id(20),'chave-original','P-20','eletronica',fixture_id(40));
  if original is distinct from public.registrar_reapresentacao(fixture_id(20),'chave-original','P-20','eletronica',fixture_id(40))
     or (select count(*) from public.pacotes_reapresentacao where id_ciclo=fixture_id(20))<>1
     or not exists(select 1 from public.apresentacoes_contratante a
        join public.pacotes_competencia p on p.id=a.id_pacote
        join public.pacotes_reapresentacao r on r.id_ciclo=fixture_id(20) and r.hash=p.hash_pacote
        join public.eventos_auditoria e on e.id_entidade=a.id and e.depois->>'id_ciclo'=r.id::text
        where a.id=original and a.id_comprovante_arquivo=fixture_id(40) and a.numero_rodada=2)
  then raise exception 'Recibo, pacote e auditoria precisam corresponder à mesma rodada'; end if;
end
$$;
select fixture_negacao(21,'chave-original','P-20',40,'PT409');
select fixture_negacao(20,'chave-original','OUTRO',40,'PT409');
select set_config('fixture.actor',fixture_id(7)::text,false);
select fixture_negacao(20,'chave-original','P-20',40,'PT409');
select set_config('fixture.contract_denied','true',false);
select fixture_negacao(24,'sem-contrato','P-24',40,'42501');
select set_config('fixture.contract_denied','false',false);
select set_config('fixture.profile_denied','true',false);
select fixture_negacao(24,'sem-perfil','P-24',40,'42501');
select set_config('fixture.profile_denied','false',false);
select set_config('fixture.disabled','true',false);
select fixture_negacao(24,'sessao-inativa','P-24',40,'42501');
select set_config('fixture.disabled','false',false);
select set_config('fixture.open_item','true',false);
select fixture_negacao(24,'portao-invalido','P-24',40,'PT409');
select set_config('fixture.open_item','false',false);

insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,numero_rodada,tipo,
  protocolo,forma_apresentacao,idempotency_key,apresentado_por)
values(fixture_id(1),fixture_id(2),fixture_id(125),2,'reapresentacao','LEGADO','eletronica','legado',fixture_id(7));
insert into public.eventos_auditoria(id_organizacao,evento,entidade,id_entidade,depois)
select fixture_id(1),'ReapresentacaoRegistrada','apresentacoes_contratante',id,jsonb_build_object('id_ciclo',fixture_id(25))
from public.apresentacoes_contratante where idempotency_key='legado';

do $$
declare existente uuid;
begin
  select id into existente from public.apresentacoes_contratante where idempotency_key='legado';
  if existente is distinct from public.registrar_reapresentacao(fixture_id(25),'legado','LEGADO','eletronica',null)
     or exists(select 1 from public.pacotes_reapresentacao where id_ciclo=fixture_id(25))
     or not exists(select 1 from public.apresentacoes_contratante where idempotency_key='legado')
  then raise exception 'Repetição legada deve conservar o recibo'; end if;
end
$$;
select 'V2_49_GREEN: escopo, idempotência, pacote, auditoria e comprovante';
