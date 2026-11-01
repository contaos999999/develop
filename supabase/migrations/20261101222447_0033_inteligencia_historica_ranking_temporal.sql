begin;

alter table public.alertas_historicos_transversais add column if not exists rotulo text not null default 'ALERTA HISTÓRICO TRANSVERSAL DO CONTRATANTE';
alter table public.alertas_historicos_transversais add column if not exists origem_detalhes jsonb not null default '{}'::jsonb;
alter table public.alertas_historicos_transversais add column if not exists efeito_portao boolean not null default false;
alter table public.alertas_historicos_transversais add column if not exists divergente boolean not null default false;
create unique index if not exists alertas_historicos_transversais_unq on public.alertas_historicos_transversais(id_contrato_alvo,id_precedente);

create table if not exists public.fontes_formais_regras_preventivas (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  id_regra_preventiva uuid not null references public.regras_preventivas(id) on delete cascade,
  id_versao_fonte_normativa uuid not null references public.versoes_fontes_normativas(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete cascade,
  fundamento_aplicabilidade text not null,
  validado_por uuid references auth.users(id) on delete set null,
  validado_em timestamptz not null default now(),
  criado_em timestamptz not null default now(),
  unique(id_regra_preventiva,id_versao_fonte_normativa,id_contrato)
);
alter table public.fontes_formais_regras_preventivas enable row level security;
create policy fontes_formais_regras_select on public.fontes_formais_regras_preventivas for select to authenticated using (privado.usuario_tem_acesso_contrato(id_contrato));
grant select on public.fontes_formais_regras_preventivas to authenticated;
revoke insert,update,delete,truncate,references,trigger on public.fontes_formais_regras_preventivas from authenticated,anon;

create or replace function privado.promover_precedente_para_regra(p_id_precedente uuid,p_codigo_regra text,p_descricao text,p_efeito text default 'informativo',p_criticidade text default 'media',p_escopo_aplicacao text default 'contrato')
returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.precedentes%rowtype; v_regra uuid;
begin
 select * into v from public.precedentes where id=p_id_precedente;
 if v.id is null then raise exception 'Não encontramos o precedente informado.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite propor uma regra preventiva.'; end if;
 if p_efeito not in ('informativo','alerta','bloqueio') then raise exception 'Selecione um efeito válido para a regra proposta.'; end if;
 if p_escopo_aplicacao not in ('contrato','contratante','tipo_contrato','organizacao') then raise exception 'Selecione um escopo válido para a regra proposta.'; end if;
 insert into public.regras_preventivas(id_organizacao,id_contrato,id_contratante,codigo_regra,origem_precedente,descricao,efeito,criticidade,escopo_aplicacao,tipo_contrato,numero_versao,situacao,fonte)
 select v.id_organizacao,case when p_escopo_aplicacao='contrato' then v.id_contrato_origem else null end,case when p_escopo_aplicacao='contratante' then v.id_contratante else null end,p_codigo_regra,v.id,p_descricao,p_efeito,p_criticidade,p_escopo_aplicacao,case when p_escopo_aplicacao='tipo_contrato' then c.tipo_contrato else null end,1,'candidata',jsonb_build_object('tipo','precedente_historico','id_precedente',v.id,'aviso','Precedente histórico não equivale a fonte normativa formal.')
 from public.contratos c where c.id=v.id_contrato_origem returning id into v_regra;
 insert into public.revisoes_regras_preventivas(id_organizacao,id_contrato,id_regra,versao,decisao,fundamento,revisor,snapshot)
 values(v.id_organizacao,v.id_contrato_origem,v_regra,1,'solicitada_ajuste','Regra candidata criada a partir de precedente. Antes da ativação, valide a aplicabilidade em fonte formal independente.',auth.uid(),jsonb_build_object('id_precedente',v.id,'efeito_solicitado',p_efeito,'escopo',p_escopo_aplicacao));
 perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraPreventivaCandidataCriada','regras_preventivas',v_regra,null,jsonb_build_object('id_precedente',v.id,'codigo_regra',p_codigo_regra,'situacao','candidata'));
 return v_regra;
end; $$;

create or replace function privado.vincular_fonte_formal_regra(p_id_regra uuid,p_id_versao_fonte uuid,p_id_contrato uuid,p_fundamento text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_regra public.regras_preventivas%rowtype; v_fonte public.versoes_fontes_normativas%rowtype; v_id uuid;
begin
 select * into v_regra from public.regras_preventivas where id=p_id_regra for update;
 if v_regra.id is null then raise exception 'Não encontramos a regra preventiva informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v_regra.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite validar a fonte formal desta regra.'; end if;
 if not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Você não possui acesso ao contrato informado.'; end if;
 select * into v_fonte from public.versoes_fontes_normativas where id=p_id_versao_fonte and id_organizacao=v_regra.id_organizacao and aprovado_em is not null;
 if v_fonte.id is null then raise exception 'A fonte formal precisa existir, pertencer à mesma organização e estar aprovada.'; end if;
 if not (v_fonte.id_contrato=p_id_contrato or (v_fonte.id_contrato is null and exists(select 1 from public.aplicabilidades_fonte a where a.id_contrato=p_id_contrato and a.id_fonte_versao=v_fonte.id and a.aplicavel=true and a.aprovado_em is not null))) then raise exception 'Esta fonte formal ainda não está validada como aplicável ao contrato atual.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento da aplicabilidade da fonte formal.'; end if;
 insert into public.fontes_formais_regras_preventivas(id_organizacao,id_regra_preventiva,id_versao_fonte_normativa,id_contrato,fundamento_aplicabilidade,validado_por)
 values(v_regra.id_organizacao,v_regra.id,v_fonte.id,p_id_contrato,p_fundamento,auth.uid()) on conflict(id_regra_preventiva,id_versao_fonte_normativa,id_contrato) do update set fundamento_aplicabilidade=excluded.fundamento_aplicabilidade,validado_por=excluded.validado_por,validado_em=now() returning id into v_id;
 perform privado.registrar_evento_auditoria(v_regra.id_organizacao,'FonteFormalValidadaParaRegra','fontes_formais_regras_preventivas',v_id,null,jsonb_build_object('id_regra',v_regra.id,'id_versao_fonte',v_fonte.id,'id_contrato',p_id_contrato));
 return v_id;
end; $$;

create or replace function public.vincular_fonte_formal_regra(p_id_regra uuid,p_id_versao_fonte uuid,p_id_contrato uuid,p_fundamento text) returns uuid language sql security invoker set search_path='' as $$ select privado.vincular_fonte_formal_regra($1,$2,$3,$4); $$;
revoke all on function public.vincular_fonte_formal_regra(uuid,uuid,uuid,text) from public,anon; grant execute on function public.vincular_fonte_formal_regra(uuid,uuid,uuid,text) to authenticated;

create or replace function privado.aprovar_regra_preventiva(p_id_regra_preventiva uuid,p_parecer text default null)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v public.regras_preventivas%rowtype; v_revisao uuid;
begin
 select * into v from public.regras_preventivas where id=p_id_regra_preventiva for update;
 if v.id is null then raise exception 'Não encontramos a regra preventiva informada.'; end if;
 if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
 if not privado.usuario_tem_acesso_organizacao(v.id_organizacao) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite aprovar esta regra preventiva.'; end if;
 if v.situacao<>'candidata' then raise exception 'Somente uma regra candidata pode ser aprovada.'; end if;
 if nullif(trim(v.codigo_regra),'') is null or nullif(trim(v.descricao),'') is null then raise exception 'A regra precisa de código e descrição antes da aprovação.'; end if;
 if v.origem_precedente is not null then
   if v.efeito='bloqueio' and (v.escopo_aplicacao<>'contrato' or v.id_contrato is null) then raise exception 'Regra originada de precedente só pode produzir bloqueio após validação formal para um contrato específico.'; end if;
   if not exists(select 1 from public.fontes_formais_regras_preventivas f where f.id_regra_preventiva=v.id and (v.id_contrato is null or f.id_contrato=v.id_contrato)) then raise exception 'Antes de ativar esta regra, vincule uma fonte formal independente e valide sua aplicabilidade ao contrato.'; end if;
 end if;
 if v.origem_precedente is null and v.fonte='{}'::jsonb then raise exception 'Inclua a fonte que fundamenta esta regra antes de aprová-la.'; end if;
 update public.regras_preventivas set situacao='ativa',aprovada_por=auth.uid(),aprovada_em=now() where id=v.id;
 insert into public.revisoes_regras_preventivas(id_organizacao,id_contrato,id_regra,versao,decisao,fundamento,revisor,snapshot)
 values(v.id_organizacao,v.id_contrato,v.id,v.numero_versao,'aprovada',coalesce(nullif(trim(p_parecer),''),'Regra preventiva aprovada após revisão humana e validação de fonte.'),auth.uid(),jsonb_build_object('codigo_regra',v.codigo_regra,'escopo_aplicacao',v.escopo_aplicacao,'efeito',v.efeito,'criticidade',v.criticidade,'fonte',v.fonte,'origem_precedente',v.origem_precedente)) returning id into v_revisao;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraPreventivaAprovada','regras_preventivas',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','ativa','id_revisao',v_revisao));
 return v_revisao;
end; $$;

create or replace function public.worker_buscar_precedentes_ranqueados(p_id_organizacao uuid,p_id_contratante uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 12)
returns table(id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,escopo_resultado text,similaridade double precision,forca_score numeric,score_final numeric,confirmacoes integer,hierarquia_normativa integer,confianca numeric)
language sql stable security definer set search_path=''
as $$
with base as (
 select p.*,
   (1-(p.embedding OPERATOR(extensions.<=>) p_embedding))::double precision sim,
   case when p.id_contrato_origem=p_id_contrato then 1.0 else 0.65 end escopo_peso,
   case when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '180 days' then 1.0 when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '365 days' then 0.8 when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '730 days' then 0.6 else 0.35 end recencia,
   least(1.0,ln(greatest(p.confirmacoes,1)+1)/ln(11)) confirm_peso,
   least(1.0,greatest(p.hierarquia_normativa,0)::numeric/10.0) hier_peso
 from public.precedentes p
 where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo' and p.embedding is not null
), scored as (
 select b.*,round((greatest(0,b.sim)::numeric*0.55)+(b.escopo_peso::numeric*0.15)+(b.recencia::numeric*0.10)+(b.confirm_peso::numeric*0.08)+(b.hier_peso::numeric*0.06)+(coalesce(b.confianca,0.5)*0.06),4) final
 from base b
)
select s.id,s.id_contrato_origem,s.competencia_origem,s.problema,s.solucao,s.desfecho,case when s.id_contrato_origem=p_id_contrato then 'MESMO CONTRATO' else 'OUTRO CONTRATO DO MESMO CONTRATANTE' end,s.sim,coalesce(s.forca_score,s.final),s.final,s.confirmacoes,s.hierarquia_normativa,s.confianca
from scored s order by (s.id_contrato_origem=p_id_contrato) desc,s.final desc,s.sim desc limit least(greatest(p_limite,1),50);
$$;
revoke all on function public.worker_buscar_precedentes_ranqueados(uuid,uuid,uuid,extensions.vector,integer) from public,anon,authenticated; grant execute on function public.worker_buscar_precedentes_ranqueados(uuid,uuid,uuid,extensions.vector,integer) to service_role;

create or replace function public.worker_buscar_fragmentos_temporais(p_id_organizacao uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_data_referencia date default null,p_limite integer default 10)
returns table(id uuid,id_versao_documento uuid,pagina_inicio integer,pagina_fim integer,texto text,similaridade double precision,fonte_temporal text,inicio_vigencia date,fim_vigencia date)
language sql stable security definer set search_path=''
as $$
select f.id,f.id_versao_documento,f.pagina_inicio,f.pagina_fim,f.texto,(1-(f.embedding OPERATOR(extensions.<=>) p_embedding))::double precision,
       case when vfn.id is not null then 'fonte_formal_vigente' else 'documento_contratual_ou_evidencia' end,vfn.inicio_vigencia,vfn.fim_vigencia
from public.fragmentos_documento f
join public.versoes_documento vd on vd.id=f.id_versao_documento
left join public.versoes_fontes_normativas vfn on vfn.id_arquivo=vd.id_arquivo and vfn.id_organizacao=f.id_organizacao and (vfn.id_contrato is null or vfn.id_contrato=f.id_contrato)
where f.id_organizacao=p_id_organizacao and f.id_contrato=p_id_contrato and f.embedding is not null
  and (p_data_referencia is null or vfn.id is null or ((vfn.inicio_vigencia is null or vfn.inicio_vigencia<=p_data_referencia) and (vfn.fim_vigencia is null or vfn.fim_vigencia>=p_data_referencia)))
order by f.embedding OPERATOR(extensions.<=>) p_embedding limit least(greatest(p_limite,1),30);
$$;
revoke all on function public.worker_buscar_fragmentos_temporais(uuid,uuid,extensions.vector,date,integer) from public,anon,authenticated; grant execute on function public.worker_buscar_fragmentos_temporais(uuid,uuid,extensions.vector,date,integer) to service_role;

create or replace function privado.gerar_alertas_transversais(p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 10)
returns integer language plpgsql security definer set search_path=''
as $$
declare v_org uuid; v_contratante uuid; v_count integer:=0; r record; v_div boolean;
begin
 select id_organizacao,id_contratante into v_org,v_contratante from public.contratos where id=p_id_contrato;
 if v_org is null then raise exception 'Não encontramos o contrato informado.'; end if;
 if auth.uid() is not null and not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Você não possui acesso a este contrato.'; end if;
 for r in select * from public.worker_buscar_precedentes_ranqueados(v_org,v_contratante,p_id_contrato,p_embedding,p_limite*3) where escopo_resultado='OUTRO CONTRATO DO MESMO CONTRATANTE' and score_final>=0.35 order by score_final desc limit p_limite loop
   select exists(select 1 from public.precedentes x where x.id_organizacao=v_org and x.id_contratante=v_contratante and x.id<>r.id and x.status='ativo' and lower(coalesce(x.desfecho,''))<>lower(coalesce(r.desfecho,'')) and extensions.similarity(lower(x.problema),lower(r.problema))>=0.50) into v_div;
   insert into public.alertas_historicos_transversais(id_organizacao,id_contrato_alvo,id_precedente,id_contrato_origem,competencia_origem,score,status,rotulo,origem_detalhes,efeito_portao,divergente)
   select v_org,p_id_contrato,r.id,r.id_contrato_origem,r.competencia_origem,r.score_final,'informativo','ALERTA HISTÓRICO TRANSVERSAL DO CONTRATANTE',jsonb_build_object('contrato_origem',c.numero,'unidade_origem',c.objeto,'competencia_origem',r.competencia_origem,'problema',r.problema,'desfecho',r.desfecho,'fonte_tipo',p.fonte_tipo,'fonte_id',p.fonte_id,'aviso','Esta ocorrência pertence a outro contrato do mesmo contratante e não constitui, por si só, não conformidade do contrato atual.'),false,v_div
   from public.contratos c join public.precedentes p on p.id=r.id where c.id=r.id_contrato_origem
   on conflict(id_contrato_alvo,id_precedente) do update set score=excluded.score,origem_detalhes=excluded.origem_detalhes,divergente=excluded.divergente;
   v_count:=v_count+1;
 end loop;
 return v_count;
end; $$;

create or replace function privado.recalcular_inteligencia_historica(p_id_contratante uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_org uuid; v_metricas integer:=0; v_padroes integer:=0; v_versao integer;
begin
 select id_organizacao into v_org from public.contratantes where id=p_id_contratante;
 if v_org is null then raise exception 'Não encontramos o contratante informado.'; end if;
 if auth.uid() is not null and not privado.usuario_tem_acesso_organizacao(v_org) then raise exception 'Você não possui acesso a este contratante.'; end if;
 delete from public.metricas_historicas where id_organizacao=v_org and id_contratante=p_id_contratante and metrica in ('apontamentos_recorrentes','tempo_apresentacao_parecer_dias','tempo_parecer_validacao_dias');
 insert into public.metricas_historicas(id_organizacao,id_contratante,id_contrato,periodo_inicio,periodo_fim,metrica,valor_numeric,valor_texto,dimensoes)
 select v_org,p_id_contratante,a.id_contrato,min(c.competencia_referencia),max(c.competencia_referencia),'apontamentos_recorrentes',count(*)::numeric,lower(coalesce(a.codigo,'sem_codigo')),jsonb_build_object('severidade',a.severidade)
 from public.apontamentos_contratante a join public.competencias c on c.id=a.id_competencia join public.contratos ct on ct.id=a.id_contrato
 where ct.id_contratante=p_id_contratante and a.id_organizacao=v_org group by a.id_contrato,lower(coalesce(a.codigo,'sem_codigo')),a.severidade;
 get diagnostics v_metricas=row_count;
 insert into public.metricas_historicas(id_organizacao,id_contratante,id_contrato,periodo_inicio,periodo_fim,metrica,valor_numeric,dimensoes)
 select v_org,p_id_contratante,c.id_contrato,c.competencia_referencia,c.competencia_referencia,'tempo_apresentacao_parecer_dias',extract(epoch from (min(pc.recebido_em)-min(ap.apresentado_em)))/86400.0,jsonb_build_object('id_competencia',c.id)
 from public.competencias c join public.contratos ct on ct.id=c.id_contrato join public.apresentacoes_contratante ap on ap.id_competencia=c.id join public.pareceres_contratante pc on pc.id_competencia=c.id
 where ct.id_contratante=p_id_contratante and c.id_organizacao=v_org group by c.id,c.id_contrato,c.competencia_referencia;
 get diagnostics v_padroes=row_count; v_metricas:=v_metricas+v_padroes;
 delete from public.padroes_historicos where id_organizacao=v_org and id_contratante=p_id_contratante and tipo in ('exigencia_observada','mudanca_interpretacao');
 insert into public.padroes_historicos(id_organizacao,id_contratante,tipo,descricao,evidencias,confianca,status)
 select v_org,p_id_contratante,'exigencia_observada','Padrão observado em relatórios do contratante: '||coalesce(a.codigo,'sem código'),jsonb_agg(jsonb_build_object('id_apontamento',a.id,'id_contrato',a.id_contrato,'competencia',c.competencia_referencia,'descricao',a.descricao,'fonte','relatorio_contratante') order by c.competencia_referencia desc),least(1.0,count(*)::numeric/5.0),'observado'
 from public.apontamentos_contratante a join public.competencias c on c.id=a.id_competencia join public.contratos ct on ct.id=a.id_contrato
 where ct.id_contratante=p_id_contratante and a.id_organizacao=v_org group by lower(coalesce(a.codigo,'sem_codigo')),coalesce(a.codigo,'sem código') having count(*)>=2;
 get diagnostics v_padroes=row_count;
 select coalesce(max(versao),0)+1 into v_versao from public.perfis_contratante where id_organizacao=v_org and id_contratante=p_id_contratante;
 insert into public.perfis_contratante(id_organizacao,id_contratante,versao,resumo,padroes,metricas)
 values(v_org,p_id_contratante,v_versao,'Perfil histórico calculado automaticamente. Regras formais e padrões observados permanecem diferenciados.',coalesce((select jsonb_agg(jsonb_build_object('tipo',p.tipo,'descricao',p.descricao,'confianca',p.confianca)) from public.padroes_historicos p where p.id_organizacao=v_org and p.id_contratante=p_id_contratante),'[]'::jsonb),jsonb_build_object('metricas_calculadas',v_metricas,'padroes_calculados',v_padroes,'calculado_em',now()));
 return jsonb_build_object('metricas_calculadas',v_metricas,'padroes_calculados',v_padroes,'versao_perfil',v_versao,'mensagem','Inteligência histórica recalculada mantendo separação entre regras formais e padrões observados.');
end; $$;

create or replace function public.recalcular_inteligencia_historica(p_id_contratante uuid) returns jsonb language sql security invoker set search_path='' as $$ select privado.recalcular_inteligencia_historica($1); $$;
revoke all on function public.recalcular_inteligencia_historica(uuid) from public,anon; grant execute on function public.recalcular_inteligencia_historica(uuid) to authenticated;

commit;
