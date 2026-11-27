-- Same assertions on the original and corrected body; errors are collected, not swallowed.
create table public.fixture_resultados(caso text primary key,resposta text);
grant insert,select on public.fixture_resultados to authenticated;
create function public.fixture_tentar(n integer,r text,t text) returns text language plpgsql security invoker set search_path='' as $$
begin
 return 'OK:'||public.registrar_desfecho_contestacao(public.fixture_id(n),r,t)::text;
exception when others then
 return 'ERR:'||sqlstate;
end$$;
grant execute on function public.fixture_tentar(integer,text,text) to authenticated;
set role authenticated;
select set_config('fixture.actor',fixture_id(8)::text,false);
insert into fixture_resultados values
 ('contrato_B',fixture_tentar(401,'aceita','Decisão')),
 ('rascunho',fixture_tentar(402,'aceita','Decisão')),
 ('substituida',fixture_tentar(403,'aceita','Decisão')),
 ('aprovacao_incompleta',fixture_tentar(404,'aceita','Decisão')),
 ('linhagem',fixture_tentar(405,'aceita','Decisão')),
 ('resultado_invalido',fixture_tentar(406,'outro','Decisão')),
 ('resultado_nulo',fixture_tentar(406,null,'Decisão'));
select set_config('fixture.disabled','true',false);
insert into fixture_resultados values ('sessao',fixture_tentar(406,'aceita','Decisão'));
select set_config('fixture.disabled','false',false);
select set_config('fixture.actor',fixture_id(6)::text,false);
insert into fixture_resultados values ('perfil',fixture_tentar(406,'aceita','Decisão'));
select set_config('fixture.actor',fixture_id(8)::text,false);
insert into fixture_resultados values ('pendente',fixture_tentar(407,'pendente','Aguardando resposta'));
reset role;
create table public.fixture_pendente as select
 (select count(*) from public.precedentes where fonte_id=fixture_id(307)) as precedentes,
 (select count(*) from public.execucoes_assincronas where id_contrato=fixture_id(2) and (payload->>'id_desfecho') in (select id::text from public.desfechos_apontamentos where id_apontamento=fixture_id(307))) as aprendizado,
 (select status from public.apontamentos_contratante where id=fixture_id(307)) as status;
set role authenticated;
insert into fixture_resultados values
 ('final',fixture_tentar(407,'aceita','Decisão final')),
 ('replay_final',fixture_tentar(407,'aceita','Decisão final')),
 ('replay_pendente',fixture_tentar(407,'pendente','Aguardando resposta')),
 ('texto_divergente',fixture_tentar(407,'aceita','Outro texto')),
 ('final_divergente',fixture_tentar(407,'rejeitada','Outra decisão')),
 ('legado',fixture_tentar(411,'aceita','Legado'));
select set_config('fixture.actor',fixture_id(7)::text,false);
insert into fixture_resultados values ('ator_divergente',fixture_tentar(407,'aceita','Decisão final'));
select set_config('fixture.actor',fixture_id(8)::text,false);
select set_config('fixture.disabled','true',false);
insert into fixture_resultados values ('replay_revogado',fixture_tentar(407,'aceita','Decisão final'));
select set_config('fixture.disabled','false',false);
reset role;
-- Assert distinct observations, including no side effects after every denied case.
create table public.fixture_vereditos(caso text primary key,pass boolean not null);
insert into fixture_vereditos
select caso,coalesce(resposta = case
 when caso in ('resultado_invalido','resultado_nulo') then 'ERR:PT400'
 when caso in ('rascunho','substituida','aprovacao_incompleta','texto_divergente','final_divergente','ator_divergente','legado') then 'ERR:PT409'
 else 'ERR:42501' end,false)
from fixture_resultados where caso not in ('pendente','final','replay_final','replay_pendente');
insert into fixture_vereditos values
 ('replay_final',coalesce((select f.resposta like 'OK:%' and f.resposta=r.resposta from fixture_resultados f,fixture_resultados r where f.caso='final' and r.caso='replay_final'),false)),
 ('replay_pendente',coalesce((select f.resposta like 'OK:%' and f.resposta=r.resposta from fixture_resultados f,fixture_resultados r where f.caso='pendente' and r.caso='replay_pendente'),false)),
 ('pendente_sem_aprendizado',(select precedentes=0 and aprendizado=0 and status='contestado_aprovado' from fixture_pendente)),
 ('dois_desfechos',(select count(*)=2 from desfechos_apontamentos where id_apontamento=fixture_id(307))),
 ('linhagem_exata',(select count(*)=2 from desfechos_apontamentos d where id_apontamento=fixture_id(307) and to_jsonb(d)->>'id_contestacao'=fixture_id(407)::text)),
 ('um_precedente',(select count(*)=1 and min(confianca)=0.85 and min(confirmacoes)=1 and min(desfecho)='aceita' from precedentes where fonte_id=fixture_id(307))),
 ('fila_unica',(select count(*)=2 from execucoes_assincronas where (payload->>'id_desfecho') in(select id::text from desfechos_apontamentos where id_apontamento=fixture_id(307)))),
 ('auditoria_dois_eventos',(select count(*)=2 from eventos_auditoria where id_entidade=fixture_id(407) and evento='DesfechoContestacaoRegistrado')),
 ('estado_final_preservado',(select resultado_final='aceita' from contestacoes where id=fixture_id(407))),
 ('sem_efeitos_negados',(select count(*)=0 from desfechos_apontamentos where id_apontamento between fixture_id(301) and fixture_id(306))),
 ('legado_preservado',(select count(*)=1 from desfechos_apontamentos where id_apontamento=fixture_id(311)));
select 'V2_77_CASO|'||caso||'|'||case when pass then 'PASS' else 'FAIL' end from fixture_vereditos order by caso;
