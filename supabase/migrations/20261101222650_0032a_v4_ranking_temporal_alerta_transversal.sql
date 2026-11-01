-- ContaOS 4.0: ranking em dois escopos, temporalidade e alerta transversal não impeditivo.

alter table public.precedentes
  add column if not exists id_apontamento_historico uuid references public.apontamentos_historicos(id) on delete set null,
  add column if not exists id_relatorio_origem uuid references public.relatorios_historicos_contratante(id) on delete set null,
  add column if not exists titulo text,
  add column if not exists escopo_aplicacao text not null default 'contrato',
  add column if not exists vigencia_inicio date,
  add column if not exists vigencia_fim date,
  add column if not exists revisado_por_humano boolean not null default false,
  add column if not exists revisado_em timestamptz,
  add column if not exists unidade_origem text,
  add column if not exists item_origem text;

update public.precedentes
set vigencia_inicio=coalesce(vigencia_inicio,competencia_origem)
where vigencia_inicio is null and competencia_origem is not null;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='precedentes_escopo_aplicacao_check') then
    alter table public.precedentes add constraint precedentes_escopo_aplicacao_check
      check (escopo_aplicacao in ('contrato','contratante','tipo_contrato','organizacao'));
  end if;
end $$;

alter table public.alertas_historicos_transversais
  add column if not exists id_contratante uuid references public.contratantes(id) on delete restrict,
  add column if not exists id_competencia_alvo uuid references public.competencias(id) on delete cascade,
  add column if not exists id_relatorio_origem uuid references public.relatorios_historicos_contratante(id) on delete set null,
  add column if not exists categoria text,
  add column if not exists similaridade numeric(8,6),
  add column if not exists motivo_sinalizacao text,
  add column if not exists desfecho_origem text,
  add column if not exists unidade_origem text,
  add column if not exists item_origem text,
  add column if not exists evidencias jsonb not null default '[]'::jsonb;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='alertas_transversais_efeito_portao_false_check') then
    alter table public.alertas_historicos_transversais add constraint alertas_transversais_efeito_portao_false_check check (efeito_portao=false);
  end if;
end $$;

create unique index if not exists alertas_transversais_comp_precedente_uk
  on public.alertas_historicos_transversais(id_competencia_alvo,id_precedente)
  where id_competencia_alvo is not null;

alter table public.similaridades_precedentes
  add column if not exists escopo_resultado text,
  add column if not exists similaridade_vetorial numeric(8,6),
  add column if not exists forca_precedente numeric(8,6),
  add column if not exists score_final numeric(8,6),
  add column if not exists posicao_escopo integer,
  add column if not exists contraditorio boolean not null default false,
  add column if not exists data_contexto date;

alter table public.consultas_semanticas
  add column if not exists data_contexto date,
  add column if not exists id_competencia_contexto uuid references public.competencias(id) on delete set null;

create index if not exists precedentes_ranking_v4_idx on public.precedentes(id_organizacao,id_contratante,id_contrato_origem,competencia_origem,status);
create index if not exists precedentes_vigencia_v4_idx on public.precedentes(id_organizacao,id_contratante,vigencia_inicio,vigencia_fim);

create or replace function privado.buscar_precedentes_rankeados_v4(
  p_id_organizacao uuid,
  p_id_contrato uuid,
  p_embedding vector,
  p_data_contexto date default current_date,
  p_filtros jsonb default '{}'::jsonb,
  p_limite_por_escopo integer default 8
)
returns table(
  id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,categoria text,rubrica text,documento_tipo text,
  escopo_resultado text,similaridade_vetorial double precision,forca_precedente double precision,score_final double precision,posicao_escopo bigint,
  contraditorio boolean,id_relatorio_origem uuid,unidade_origem text,item_origem text
)
language sql stable security definer set search_path=''
as $$
with alvo as (
  select c.id,c.id_organizacao,c.id_contratante from public.contratos c
  where c.id=p_id_contrato and c.id_organizacao=p_id_organizacao
), candidatos as (
  select p.*,
         case when p.id_contrato_origem=p_id_contrato then 'proprio_contrato' else 'transversal_contratante' end as escopo_calc,
         (1-(p.embedding OPERATOR(extensions.<=>) p_embedding))::double precision as sim,
         greatest(0.0,1.0-(greatest(0,(coalesce(p_data_contexto,current_date)-coalesce(p.competencia_origem,p.vigencia_inicio,p.criado_em::date)))::double precision/1825.0)) as recencia,
         least(greatest(coalesce(p.confirmacoes,1),1),5)::double precision/5.0 as confirmacao,
         least(greatest(coalesce(p.hierarquia_normativa,0),0),10)::double precision/10.0 as hierarquia,
         case when nullif(trim(coalesce(p.desfecho,'')),'') is null then 0.4 else 1.0 end as desfecho_score,
         (
           (case when nullif(p_filtros->>'categoria','') is not null and lower(coalesce(p.categoria,''))=lower(p_filtros->>'categoria') then 1 else 0 end) +
           (case when nullif(p_filtros->>'rubrica','') is not null and lower(coalesce(p.rubrica,''))=lower(p_filtros->>'rubrica') then 1 else 0 end) +
           (case when nullif(p_filtros->>'documento_tipo','') is not null and lower(coalesce(p.documento_tipo,''))=lower(p_filtros->>'documento_tipo') then 1 else 0 end) +
           (case when nullif(p_filtros->>'valor','') is not null and p.valor_referencia is not null and abs(p.valor_referencia-(p_filtros->>'valor')::numeric)<=greatest(1,abs((p_filtros->>'valor')::numeric)*0.05) then 1 else 0 end)
         )::double precision/4.0 as aderencia_estruturada
  from public.precedentes p
  join alvo a on a.id_organizacao=p.id_organizacao and a.id_contratante=p.id_contratante
  where p.status='ativo' and p.embedding is not null
    and (p.competencia_origem is null or p.competencia_origem<=coalesce(p_data_contexto,current_date))
    and (p.vigencia_inicio is null or p.vigencia_inicio<=coalesce(p_data_contexto,current_date))
    and (p.vigencia_fim is null or p.vigencia_fim>=coalesce(p_data_contexto,current_date))
    and (nullif(p_filtros->>'categoria','') is null or lower(coalesce(p.categoria,''))=lower(p_filtros->>'categoria'))
    and (nullif(p_filtros->>'rubrica','') is null or lower(coalesce(p.rubrica,''))=lower(p_filtros->>'rubrica'))
    and (nullif(p_filtros->>'documento_tipo','') is null or lower(coalesce(p.documento_tipo,''))=lower(p_filtros->>'documento_tipo'))
), pontuados as (
  select c.*,
         least(1.0,greatest(0.0,0.35*c.recencia+0.30*c.confirmacao+0.15*c.hierarquia+0.20*c.desfecho_score)) as forca_calc,
         exists(
           select 1 from candidatos x where x.id<>c.id and x.escopo_calc=c.escopo_calc
             and coalesce(x.categoria,'')=coalesce(c.categoria,'')
             and lower(coalesce(x.desfecho,''))<>lower(coalesce(c.desfecho,'')) and x.sim>=0.45
         ) as contraditorio_calc
  from candidatos c
), rank_base as (
  select p.*,least(1.0,greatest(0.0,0.60*p.sim+0.25*p.forca_calc+0.15*p.aderencia_estruturada)) as score_calc from pontuados p
), rankeados as (
  select p.*,row_number() over(partition by p.escopo_calc order by p.score_calc desc,p.competencia_origem desc nulls last,p.id) as rn from rank_base p
)
select r.id,r.id_contrato_origem,r.competencia_origem,r.problema,r.solucao,r.desfecho,r.categoria,r.rubrica,r.documento_tipo,
       r.escopo_calc,r.sim,r.forca_calc,r.score_calc,r.rn,r.contraditorio_calc,r.id_relatorio_origem,r.unidade_origem,r.item_origem
from rankeados r
where r.rn<=least(greatest(coalesce(p_limite_por_escopo,8),1),20)
order by case when r.escopo_calc='proprio_contrato' then 0 else 1 end,r.rn;
$$;
revoke all on function privado.buscar_precedentes_rankeados_v4(uuid,uuid,vector,date,jsonb,integer) from public,anon,authenticated;
grant execute on function privado.buscar_precedentes_rankeados_v4(uuid,uuid,vector,date,jsonb,integer) to service_role;

create or replace function public.worker_buscar_precedentes_v4(
  p_id_organizacao uuid,p_id_contrato uuid,p_embedding vector,p_data_contexto date default current_date,p_filtros jsonb default '{}'::jsonb,p_limite_por_escopo integer default 8
)
returns table(
  id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,categoria text,rubrica text,documento_tipo text,
  escopo_resultado text,similaridade_vetorial double precision,forca_precedente double precision,score_final double precision,posicao_escopo bigint,
  contraditorio boolean,id_relatorio_origem uuid,unidade_origem text,item_origem text
)
language sql stable security definer set search_path=''
as $$ select * from privado.buscar_precedentes_rankeados_v4($1,$2,$3,$4,$5,$6) $$;
revoke all on function public.worker_buscar_precedentes_v4(uuid,uuid,vector,date,jsonb,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_precedentes_v4(uuid,uuid,vector,date,jsonb,integer) to service_role;

create or replace function privado.contexto_normativo_temporal_v4(p_id_contrato uuid,p_data_contexto date)
returns table(id_fonte uuid,id_versao uuid,tipo text,titulo text,referencia text,versao integer,inicio_vigencia date,fim_vigencia date,conteudo_texto text,hash text)
language sql stable security definer set search_path=''
as $$
select f.id,v.id,f.tipo,f.titulo,f.referencia,v.versao,v.inicio_vigencia,v.fim_vigencia,v.conteudo_texto,v.hash
from public.fontes_normativas f
join public.versoes_fontes_normativas v on v.id_fonte=f.id
join public.contratos c on c.id=p_id_contrato and c.id_organizacao=f.id_organizacao
where (f.id_contrato is null or f.id_contrato=p_id_contrato)
  and f.situacao in ('vigente','ativa','aprovada') and v.aprovado_em is not null
  and (v.inicio_vigencia is null or v.inicio_vigencia<=coalesce(p_data_contexto,current_date))
  and (v.fim_vigencia is null or v.fim_vigencia>=coalesce(p_data_contexto,current_date))
order by case when f.id_contrato=p_id_contrato then 0 else 1 end,f.tipo,f.titulo,v.versao desc;
$$;
revoke all on function privado.contexto_normativo_temporal_v4(uuid,date) from public,anon,authenticated;
grant execute on function privado.contexto_normativo_temporal_v4(uuid,date) to service_role;

create or replace function public.worker_contexto_normativo_temporal_v4(p_id_contrato uuid,p_data_contexto date)
returns table(id_fonte uuid,id_versao uuid,tipo text,titulo text,referencia text,versao integer,inicio_vigencia date,fim_vigencia date,conteudo_texto text,hash text)
language sql stable security definer set search_path=''
as $$ select * from privado.contexto_normativo_temporal_v4($1,$2) $$;
revoke all on function public.worker_contexto_normativo_temporal_v4(uuid,date) from public,anon,authenticated;
grant execute on function public.worker_contexto_normativo_temporal_v4(uuid,date) to service_role;

create or replace function privado.materializar_alertas_transversais_v4(p_id_competencia uuid,p_embedding vector,p_filtros jsonb default '{}'::jsonb,p_limite integer default 8)
returns integer language plpgsql security definer set search_path=''
as $$
declare v_comp public.competencias%rowtype; v_contrato public.contratos%rowtype; r record; v_qtd integer:=0;
begin
  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then raise exception 'Competência não encontrada.'; end if;
  select * into v_contrato from public.contratos where id=v_comp.id_contrato;
  for r in select * from privado.buscar_precedentes_rankeados_v4(v_comp.id_organizacao,v_comp.id_contrato,p_embedding,v_comp.competencia_referencia,p_filtros,p_limite)
           where escopo_resultado='transversal_contratante'
  loop
    insert into public.alertas_historicos_transversais(
      id_organizacao,id_contratante,id_contrato_alvo,id_competencia_alvo,id_precedente,id_contrato_origem,competencia_origem,id_relatorio_origem,
      categoria,score,similaridade,motivo_sinalizacao,rotulo,efeito_portao,desfecho_origem,unidade_origem,item_origem,evidencias,status,origem_detalhes,divergente
    ) values(
      v_comp.id_organizacao,v_contrato.id_contratante,v_comp.id_contrato,v_comp.id,r.id,r.id_contrato_origem,r.competencia_origem,r.id_relatorio_origem,
      r.categoria,r.score_final,r.similaridade_vetorial,
      'Ocorrência semelhante localizada em outro contrato da mesma organização com o mesmo contratante. O achado é informativo e não constitui obrigação do contrato atual.',
      'ALERTA HISTÓRICO TRANSVERSAL DO CONTRATANTE',false,r.desfecho,r.unidade_origem,r.item_origem,
      jsonb_build_array(jsonb_build_object('id_precedente',r.id,'contrato_origem',r.id_contrato_origem,'competencia_origem',r.competencia_origem,'desfecho',r.desfecho)),
      'informativo',jsonb_build_object('contrato_origem',r.id_contrato_origem,'competencia_origem',r.competencia_origem,'id_relatorio_origem',r.id_relatorio_origem,'item_origem',r.item_origem,'desfecho',r.desfecho),r.contraditorio
    )
    on conflict(id_competencia_alvo,id_precedente) where id_competencia_alvo is not null
    do update set score=excluded.score,similaridade=excluded.similaridade,motivo_sinalizacao=excluded.motivo_sinalizacao,
                  desfecho_origem=excluded.desfecho_origem,evidencias=excluded.evidencias,origem_detalhes=excluded.origem_detalhes,divergente=excluded.divergente;
    v_qtd:=v_qtd+1;
  end loop;
  return v_qtd;
end $$;
revoke all on function privado.materializar_alertas_transversais_v4(uuid,vector,jsonb,integer) from public,anon,authenticated;
grant execute on function privado.materializar_alertas_transversais_v4(uuid,vector,jsonb,integer) to service_role;

create or replace function public.worker_materializar_alertas_transversais_v4(p_id_competencia uuid,p_embedding vector,p_filtros jsonb default '{}'::jsonb,p_limite integer default 8)
returns integer language sql security definer set search_path=''
as $$ select privado.materializar_alertas_transversais_v4($1,$2,$3,$4) $$;
revoke all on function public.worker_materializar_alertas_transversais_v4(uuid,vector,jsonb,integer) from public,anon,authenticated;
grant execute on function public.worker_materializar_alertas_transversais_v4(uuid,vector,jsonb,integer) to service_role;
