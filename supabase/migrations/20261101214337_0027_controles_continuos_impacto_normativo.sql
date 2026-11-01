begin;

alter table public.contratos add column if not exists criticidade text not null default 'media';
do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.contratos'::regclass and conname='contratos_criticidade_check') then
    alter table public.contratos add constraint contratos_criticidade_check check(criticidade in ('baixa','media','alta','critica'));
  end if;
end $$;

alter table public.controles_conformidade add column if not exists bloqueia_competencia boolean not null default false;
alter table public.controles_conformidade add column if not exists segregacao_funcoes boolean not null default false;
alter table public.controles_conformidade add column if not exists responsavel_padrao uuid references auth.users(id) on delete set null;
alter table public.versoes_controle add column if not exists criterios jsonb not null default '{}'::jsonb;
alter table public.versoes_controle add column if not exists eventos_gatilho text[] not null default array['cron_diario']::text[];

create table public.aplicabilidades_controle (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_controle uuid not null references public.controles_conformidade(id) on delete restrict,
  id_contrato uuid references public.contratos(id) on delete restrict,
  ativo boolean not null default true,
  responsavel uuid references auth.users(id) on delete set null,
  bloqueia_competencia boolean,
  configuracao jsonb not null default '{}'::jsonb,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint aplicabilidades_controle_uk unique(id_controle,id_contrato)
);
create index aplicabilidades_controle_org_idx on public.aplicabilidades_controle(id_organizacao,id_contrato,ativo);
alter table public.aplicabilidades_controle enable row level security;
create policy aplicabilidades_controle_select on public.aplicabilidades_controle for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy aplicabilidades_controle_insert on public.aplicabilidades_controle for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy aplicabilidades_controle_update on public.aplicabilidades_controle for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create trigger aplicabilidades_controle_touch before update on public.aplicabilidades_controle for each row execute function privado.tocar_atualizado_em();

alter table public.execucoes_controle add column if not exists id_contrato uuid references public.contratos(id) on delete restrict;
alter table public.execucoes_controle add column if not exists id_competencia uuid references public.competencias(id) on delete restrict;
alter table public.execucoes_controle add column if not exists evento text;
alter table public.execucoes_controle add column if not exists evento_id uuid;
alter table public.execucoes_controle add column if not exists chave_idempotencia text;
create unique index if not exists execucoes_controle_idempotencia_uidx on public.execucoes_controle(id_organizacao,chave_idempotencia) where chave_idempotencia is not null;
create index if not exists execucoes_controle_contrato_idx on public.execucoes_controle(id_organizacao,id_contrato,executado_em desc);
create index if not exists execucoes_controle_competencia_idx on public.execucoes_controle(id_competencia,resultado,executado_em desc);

alter table public.nao_conformidades add column if not exists id_contrato uuid references public.contratos(id) on delete restrict;
alter table public.nao_conformidades add column if not exists id_competencia uuid references public.competencias(id) on delete restrict;
alter table public.nao_conformidades add column if not exists criado_por uuid references auth.users(id) on delete set null;
alter table public.nao_conformidades add column if not exists origem_evento text;
alter table public.nao_conformidades add column if not exists origem_evento_id uuid;
create unique index if not exists nao_conformidades_origem_uidx on public.nao_conformidades(id_organizacao,id_controle,origem_evento,origem_evento_id) where origem_evento_id is not null and status not in ('encerrada');
create index if not exists nao_conformidades_competencia_idx on public.nao_conformidades(id_competencia,status,severidade);

alter table public.planos_remediacao add column if not exists criado_por uuid references auth.users(id) on delete set null;
alter table public.planos_remediacao add column if not exists concluido_por uuid references auth.users(id) on delete set null;
alter table public.planos_remediacao add column if not exists concluido_em timestamptz;
alter table public.planos_remediacao add column if not exists validado_por uuid references auth.users(id) on delete set null;
alter table public.planos_remediacao add column if not exists validado_em timestamptz;
alter table public.planos_remediacao drop constraint if exists planos_remediacao_status_check;
alter table public.planos_remediacao add constraint planos_remediacao_status_check check(status in ('aberto','em_execucao','concluido','validado','cancelado'));

alter table public.avaliacoes_impacto add column if not exists status text not null default 'pendente_aprovacao';
do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.avaliacoes_impacto'::regclass and conname='avaliacoes_impacto_status_check') then
    alter table public.avaliacoes_impacto add constraint avaliacoes_impacto_status_check check(status in ('pendente_aprovacao','aprovada','rejeitada','substituida'));
  end if;
end $$;
alter table public.avaliacoes_impacto add column if not exists metadados jsonb not null default '{}'::jsonb;
create unique index if not exists avaliacoes_impacto_alteracao_pendente_uidx on public.avaliacoes_impacto(id_alteracao) where status='pendente_aprovacao';

create or replace function privado.enfileirar_controles_transacao()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform privado.enfileirar_job(
    'integrations',new.id_organizacao,new.id_contrato,'avaliar_controles',new.id,
    jsonb_build_object('entidade_tipo','avaliar_controles','id_transacao',new.id,'id_contrato',new.id_contrato),
    'compliance:transacao:'||new.id::text
  );
  return new;
end;$$;
revoke all on function privado.enfileirar_controles_transacao() from public,anon,authenticated;
drop trigger if exists contaos_controles_transacao on public.transacoes_financeiras;
create trigger contaos_controles_transacao after insert on public.transacoes_financeiras for each row execute function privado.enfileirar_controles_transacao();

create or replace function privado.agendar_controles_continuos()
returns integer language plpgsql security definer set search_path='' as $$
declare r record; v_total int:=0;
begin
  for r in
    select ac.id_organizacao,ac.id_contrato,ac.id_controle
    from public.aplicabilidades_controle ac
    join public.controles_conformidade c on c.id=ac.id_controle and c.situacao='ativo'
    join public.versoes_controle vc on vc.id_controle=c.id and vc.status='publicada'
    where ac.ativo=true and 'cron_diario'=any(vc.eventos_gatilho)
      and (vc.vigencia_inicio is null or vc.vigencia_inicio<=current_date)
      and (vc.vigencia_fim is null or vc.vigencia_fim>=current_date)
  loop
    perform privado.enfileirar_job(
      'integrations',r.id_organizacao,r.id_contrato,'avaliar_controles_periodicos',r.id_controle,
      jsonb_build_object('entidade_tipo','avaliar_controles_periodicos','id_controle',r.id_controle,'id_contrato',r.id_contrato,'data_referencia',current_date),
      'compliance:diario:'||r.id_controle::text||':'||coalesce(r.id_contrato::text,'organizacao')||':'||current_date::text
    );
    v_total:=v_total+1;
  end loop;
  return v_total;
end;$$;
revoke all on function privado.agendar_controles_continuos() from public,anon,authenticated;

select cron.schedule('contaos-controles-continuos','10 2 * * *',$cron$select privado.agendar_controles_continuos();$cron$);

create or replace function privado.concluir_plano_remediacao(p_id_plano uuid,p_evidencias jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare v public.planos_remediacao%rowtype; v_nc public.nao_conformidades%rowtype;
begin
  select * into v from public.planos_remediacao where id=p_id_plano for update;
  if v.id is null then raise exception 'Não encontramos o plano de remediação informado.'; end if;
  select * into v_nc from public.nao_conformidades where id=v.id_nao_conformidade;
  if auth.uid() is null or not privado.usuario_tem_acesso_organizacao(v.id_organizacao) then raise exception 'Para continuar, faça login novamente.'; end if;
  if v.responsavel is not null and v.responsavel<>auth.uid() and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','juridico_conformidade']::text[]) then raise exception 'Somente o responsável pela remediação ou um perfil autorizado pode concluir este plano.'; end if;
  if jsonb_typeof(coalesce(p_evidencias,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_evidencias,'[]'::jsonb))=0 then raise exception 'Inclua ao menos uma evidência antes de concluir a remediação.'; end if;
  update public.planos_remediacao set status='concluido',evidencias=p_evidencias,concluido_por=auth.uid(),concluido_em=now() where id=v.id;
  update public.nao_conformidades set status='em_remediacao' where id=v_nc.id and status in ('aberta','em_analise');
  perform privado.registrar_evento_auditoria(v.id_organizacao,'PlanoRemediacaoConcluido','planos_remediacao',v.id,null,jsonb_build_object('id_nao_conformidade',v.id_nao_conformidade,'quantidade_evidencias',jsonb_array_length(p_evidencias)));
end;$$;
create or replace function public.concluir_plano_remediacao(p_id_plano uuid,p_evidencias jsonb)
returns void language sql security invoker set search_path='' as $$select privado.concluir_plano_remediacao($1,$2)$$;
revoke all on function public.concluir_plano_remediacao(uuid,jsonb) from public,anon;
grant execute on function public.concluir_plano_remediacao(uuid,jsonb) to authenticated;

create or replace function privado.validar_remediacao(p_id_plano uuid,p_aprovar boolean,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.planos_remediacao%rowtype; v_nc public.nao_conformidades%rowtype; v_controle public.controles_conformidade%rowtype;
begin
  select * into v from public.planos_remediacao where id=p_id_plano for update;
  if v.id is null then raise exception 'Não encontramos o plano de remediação informado.'; end if;
  select * into v_nc from public.nao_conformidades where id=v.id_nao_conformidade;
  if v_nc.id_controle is not null then select * into v_controle from public.controles_conformidade where id=v_nc.id_controle; end if;
  if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite validar esta remediação.'; end if;
  if v.status<>'concluido' then raise exception 'A remediação precisa estar concluída antes da validação.'; end if;
  if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento da validação.'; end if;
  if coalesce(v_controle.segregacao_funcoes,false) and auth.uid()=any(array_remove(array[v.criado_por,v.responsavel,v.concluido_por,v_nc.criado_por],null)) then
    raise exception 'Este controle exige segregação de funções. A validação deve ser realizada por uma pessoa diferente de quem criou ou executou a remediação.';
  end if;
  if p_aprovar then
    update public.planos_remediacao set status='validado',validado_por=auth.uid(),validado_em=now() where id=v.id;
    if not exists(select 1 from public.planos_remediacao p where p.id_nao_conformidade=v.id_nao_conformidade and p.id<>v.id and p.status not in ('validado','cancelado')) then
      update public.nao_conformidades set status='resolvida' where id=v.id_nao_conformidade;
    end if;
  else
    update public.planos_remediacao set status='em_execucao',validado_por=null,validado_em=null where id=v.id;
  end if;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'RemediacaoValidada','planos_remediacao',v.id,null,jsonb_build_object('aprovada',p_aprovar,'fundamento',p_fundamento));
end;$$;
create or replace function public.validar_remediacao(p_id_plano uuid,p_aprovar boolean,p_fundamento text)
returns void language sql security invoker set search_path='' as $$select privado.validar_remediacao($1,$2,$3)$$;
revoke all on function public.validar_remediacao(uuid,boolean,text) from public,anon;
grant execute on function public.validar_remediacao(uuid,boolean,text) to authenticated;

create or replace function privado.encerrar_nao_conformidade(p_id_nao_conformidade uuid,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.nao_conformidades%rowtype;
begin
 select * into v from public.nao_conformidades where id=p_id_nao_conformidade for update;
 if v.id is null then raise exception 'Não encontramos a não conformidade informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite encerrar esta não conformidade.'; end if;
 if exists(select 1 from public.planos_remediacao where id_nao_conformidade=v.id and status not in ('validado','cancelado')) then raise exception 'Ainda existem remediações sem validação. Valide todas as ações necessárias antes de encerrar.'; end if;
 if not exists(select 1 from public.planos_remediacao where id_nao_conformidade=v.id and status='validado' and jsonb_typeof(evidencias)='array' and jsonb_array_length(evidencias)>0) then raise exception 'Para encerrar, é necessária ao menos uma remediação validada com evidência.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento do encerramento.'; end if;
 update public.nao_conformidades set status='encerrada' where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'NaoConformidadeEncerrada','nao_conformidades',v.id,jsonb_build_object('status',v.status),jsonb_build_object('status','encerrada','fundamento',p_fundamento));
end;$$;

create or replace function privado.avaliar_portao_conformidade(p_id_competencia uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_org uuid; v_contrato uuid; v_total int:=0; v_ok int:=0; v_pend int:=0; v_nok int:=0; v_inc int:=0; v_analise int:=0; v_nc int:=0; v_percent numeric(5,2):=0; v_liberado boolean:=false;
begin
  select id_organizacao,id_contrato into v_org,v_contrato from public.competencias where id=p_id_competencia;
  if v_org is null then raise exception 'Não encontramos a competência informada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
  with ultimos as (
    select distinct on (r.id_requisito) r.id_requisito,r.resultado,r.fundamento,r.id
    from public.resultados_requisitos r where r.id_competencia=p_id_competencia order by r.id_requisito,r.criado_em desc,r.id desc
  ), avaliacao as (
    select req.id,coalesce(u.resultado,'pendente') resultado,
      case when u.resultado='nao_aplicavel' and nullif(trim(coalesce(u.fundamento,'')),'') is not null and exists(select 1 from public.evidencias_resultado e where e.id_resultado=u.id) then true else false end na_valido
    from public.requisitos_competencia req left join ultimos u on u.id_requisito=req.id
    where req.id_competencia=p_id_competencia and req.obrigatorio=true and req.aplicavel=true and req.efeito_portao=true
  )
  select count(*)::int,
         count(*) filter(where resultado='conforme' or (resultado='nao_aplicavel' and na_valido))::int,
         count(*) filter(where resultado='pendente' or (resultado='nao_aplicavel' and not na_valido))::int,
         count(*) filter(where resultado='nao_conforme')::int,
         count(*) filter(where resultado='inconclusivo')::int,
         count(*) filter(where resultado='em_analise')::int
    into v_total,v_ok,v_pend,v_nok,v_inc,v_analise from avaliacao;
  select count(*)::int into v_nc
  from public.nao_conformidades nc
  join public.controles_conformidade c on c.id=nc.id_controle
  left join public.aplicabilidades_controle ac on ac.id_controle=c.id and ac.id_contrato=v_contrato and ac.ativo=true
  where nc.id_organizacao=v_org and nc.id_contrato=v_contrato
    and (nc.id_competencia is null or nc.id_competencia=p_id_competencia)
    and nc.status not in ('resolvida','encerrada','aceita')
    and coalesce(ac.bloqueia_competencia,c.bloqueia_competencia,false)=true;
  v_percent:=case when v_total=0 then 0 else round((v_ok::numeric/v_total::numeric)*100,2) end;
  v_liberado:=(v_total>0 and v_ok=v_total and v_pend=0 and v_nok=0 and v_inc=0 and v_analise=0 and v_nc=0);
  return jsonb_build_object('total',v_total,'conformes_ou_na_validos',v_ok,'pendentes',v_pend,'nao_conformes',v_nok,'inconclusivos',v_inc,'em_analise',v_analise,'nao_conformidades_bloqueantes',v_nc,'percentual',v_percent,'liberado',v_liberado);
end;$$;

create or replace function privado.solicitar_avaliacao_impacto_normativo(p_id_alteracao uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.alteracoes_normativas%rowtype; v_job uuid;
begin
 select * into v from public.alteracoes_normativas where id=p_id_alteracao for update;
 if v.id is null then raise exception 'Não encontramos a alteração normativa informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]) then raise exception 'Seu perfil atual não permite solicitar esta análise de impacto.'; end if;
 update public.alteracoes_normativas set status='em_avaliacao' where id=v.id;
 v_job:=privado.enfileirar_job('integrations',v.id_organizacao,null,'avaliacao_impacto_normativo',v.id,jsonb_build_object('entidade_tipo','avaliacao_impacto_normativo','id_alteracao',v.id),'normativo:'||v.id::text);
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AvaliacaoImpactoNormativoSolicitada','alteracoes_normativas',v.id,null,jsonb_build_object('id_job',v_job));
 return v_job;
end;$$;
create or replace function public.solicitar_avaliacao_impacto_normativo(p_id_alteracao uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_avaliacao_impacto_normativo($1)$$;
revoke all on function public.solicitar_avaliacao_impacto_normativo(uuid) from public,anon;
grant execute on function public.solicitar_avaliacao_impacto_normativo(uuid) to authenticated;

create or replace function privado.aprovar_avaliacao_impacto(p_id_avaliacao uuid,p_aprovar boolean,p_decisao text,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.avaliacoes_impacto%rowtype;
begin
 select * into v from public.avaliacoes_impacto where id=p_id_avaliacao for update;
 if v.id is null then raise exception 'Não encontramos a avaliação de impacto informada.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite aprovar esta avaliação de impacto.'; end if;
 if v.criado_por=auth.uid() then raise exception 'Por segregação de funções, a avaliação deve ser aprovada por uma pessoa diferente de quem a registrou.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento da decisão.'; end if;
 update public.avaliacoes_impacto set status=case when p_aprovar then 'aprovada' else 'rejeitada' end,decisao=p_decisao,aprovado_por=auth.uid(),aprovado_em=now(),metadados=metadados||jsonb_build_object('fundamento_aprovacao',p_fundamento) where id=v.id;
 update public.alteracoes_normativas set status=case when p_aprovar then 'avaliada' else 'detectada' end where id=v.id_alteracao;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AvaliacaoImpactoNormativoRevisada','avaliacoes_impacto',v.id,null,jsonb_build_object('aprovada',p_aprovar,'decisao',p_decisao,'fundamento',p_fundamento));
end;$$;
create or replace function public.aprovar_avaliacao_impacto(p_id_avaliacao uuid,p_aprovar boolean,p_decisao text,p_fundamento text)
returns void language sql security invoker set search_path='' as $$select privado.aprovar_avaliacao_impacto($1,$2,$3,$4)$$;
revoke all on function public.aprovar_avaliacao_impacto(uuid,boolean,text,text) from public,anon;
grant execute on function public.aprovar_avaliacao_impacto(uuid,boolean,text,text) to authenticated;

commit;
