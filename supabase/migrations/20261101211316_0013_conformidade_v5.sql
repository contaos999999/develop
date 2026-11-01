begin;

create table public.entidades_organizacionais (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_pai uuid references public.entidades_organizacionais(id) on delete restrict, codigo text not null, nome text not null, tipo text,
 status text not null default 'ativa' check(status in ('ativa','inativa')), metadados jsonb not null default '{}'::jsonb,
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint entidades_organizacionais_uk unique(id_organizacao,codigo));
create index entidades_organizacionais_pai_idx on public.entidades_organizacionais(id_organizacao,id_pai,status);

create table public.controles_conformidade (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 codigo text not null, nome text not null, objetivo text not null, categoria text, criticidade text not null default 'media' check(criticidade in ('baixa','media','alta','critica')),
 situacao text not null default 'rascunho' check(situacao in ('rascunho','ativo','inativo','substituido')), versao_atual integer not null default 0,
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint controles_conformidade_uk unique(id_organizacao,codigo));

create table public.versoes_controle (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_controle uuid not null references public.controles_conformidade(id) on delete restrict, versao integer not null, texto text not null,
 evidencia_requerida jsonb not null default '[]'::jsonb, vigencia_inicio date, vigencia_fim date,
 status text not null default 'rascunho' check(status in ('rascunho','publicada','substituida','revogada')),
 aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz, hash text not null, criado_em timestamptz not null default now(),
 constraint versoes_controle_uk unique(id_controle,versao), constraint versoes_controle_vig_ck check(vigencia_fim is null or vigencia_inicio is null or vigencia_fim>=vigencia_inicio));

create table public.execucoes_controle (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_entidade_organizacional uuid references public.entidades_organizacionais(id) on delete restrict, id_controle_versao uuid not null references public.versoes_controle(id) on delete restrict,
 escopo jsonb not null default '{}'::jsonb, periodo_inicio date, periodo_fim date,
 resultado text not null check(resultado in ('conforme','nao_conforme','parcial','nao_aplicavel','inconclusivo')),
 evidencias jsonb not null default '[]'::jsonb, executado_por uuid references auth.users(id) on delete set null,
 executado_em timestamptz not null default now(), criado_em timestamptz not null default now());
create index execucoes_controle_idx on public.execucoes_controle(id_organizacao,periodo_fim,resultado);

create table public.excecoes_controle (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_controle uuid not null references public.controles_conformidade(id) on delete restrict, escopo jsonb not null default '{}'::jsonb,
 motivo text not null, inicio date not null, fim date not null, status text not null default 'pendente' check(status in ('pendente','aprovada','rejeitada','expirada','revogada')),
 aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(), constraint excecoes_controle_periodo_ck check(fim>=inicio));
create index excecoes_controle_idx on public.excecoes_controle(id_controle,status,fim);

create table public.nao_conformidades (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_controle uuid references public.controles_conformidade(id) on delete restrict, id_execucao_controle uuid references public.execucoes_controle(id) on delete restrict,
 id_entidade_organizacional uuid references public.entidades_organizacionais(id) on delete restrict,
 descricao text not null, risco text, severidade text not null default 'media' check(severidade in ('baixa','media','alta','critica')),
 status text not null default 'aberta' check(status in ('aberta','em_analise','em_remediacao','resolvida','aceita','encerrada')),
 responsavel uuid references auth.users(id) on delete set null, prazo date, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index nao_conformidades_idx on public.nao_conformidades(id_organizacao,status,responsavel,prazo);

create table public.planos_remediacao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_nao_conformidade uuid not null references public.nao_conformidades(id) on delete restrict, acoes jsonb not null,
 responsavel uuid references auth.users(id) on delete set null, prazo date,
 status text not null default 'aberto' check(status in ('aberto','em_execucao','concluido','cancelado')),
 evidencias jsonb not null default '[]'::jsonb, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index planos_remediacao_idx on public.planos_remediacao(id_nao_conformidade,status,prazo);

create table public.alteracoes_normativas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_fonte uuid references public.fontes_normativas(id) on delete restrict, id_versao_anterior uuid references public.versoes_fontes_normativas(id) on delete restrict,
 id_versao_nova uuid references public.versoes_fontes_normativas(id) on delete restrict, resumo text not null,
 detectada_em timestamptz not null default now(), status text not null default 'detectada' check(status in ('detectada','em_avaliacao','avaliada','descartada')),
 criado_em timestamptz not null default now());
create index alteracoes_normativas_idx on public.alteracoes_normativas(id_organizacao,status,detectada_em desc);

create table public.avaliacoes_impacto (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_alteracao uuid not null references public.alteracoes_normativas(id) on delete restrict, contratos_afetados uuid[] not null default '{}'::uuid[],
 controles_afetados uuid[] not null default '{}'::uuid[], impacto text not null, decisao text not null,
 aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now());
create index avaliacoes_impacto_idx on public.avaliacoes_impacto(id_alteracao,criado_em desc);

create table public.publicacoes_regras (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_regra_candidata uuid references public.regras_candidatas(id) on delete restrict, id_regra_preventiva uuid references public.regras_preventivas(id) on delete restrict,
 id_avaliacao_impacto uuid references public.avaliacoes_impacto(id) on delete restrict,
 vigencia_inicio date not null, vigencia_fim date, status text not null default 'publicada' check(status in ('publicada','suspensa','encerrada')),
 aprovado_por uuid references auth.users(id) on delete set null, aprovado_em timestamptz not null default now(),
 hash text not null, criado_em timestamptz not null default now(),
 constraint publicacoes_regras_alvo_ck check(num_nonnulls(id_regra_candidata,id_regra_preventiva)=1),
 constraint publicacoes_regras_vig_ck check(vigencia_fim is null or vigencia_fim>=vigencia_inicio));
create index publicacoes_regras_idx on public.publicacoes_regras(id_organizacao,status,vigencia_inicio,vigencia_fim);

create table public.riscos_corporativos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_entidade_organizacional uuid references public.entidades_organizacionais(id) on delete restrict, codigo text not null, titulo text not null,
 categoria text, descricao text, probabilidade numeric(6,5), impacto numeric(18,4), exposicao numeric(18,4),
 nivel text not null default 'medio' check(nivel in ('baixo','medio','alto','critico')), status text not null default 'aberto' check(status in ('aberto','em_tratamento','aceito','mitigado','encerrado')),
 responsavel uuid references auth.users(id) on delete set null, tratamento text, prazo date,
 fontes jsonb not null default '[]'::jsonb, versao_registro bigint not null default 1,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint riscos_corporativos_uk unique(id_organizacao,codigo));
create index riscos_corporativos_idx on public.riscos_corporativos(id_organizacao,nivel,status,responsavel);

alter table public.entidades_organizacionais enable row level security; alter table public.controles_conformidade enable row level security;
alter table public.versoes_controle enable row level security; alter table public.execucoes_controle enable row level security;
alter table public.excecoes_controle enable row level security; alter table public.nao_conformidades enable row level security;
alter table public.planos_remediacao enable row level security; alter table public.alteracoes_normativas enable row level security;
alter table public.avaliacoes_impacto enable row level security; alter table public.publicacoes_regras enable row level security;
alter table public.riscos_corporativos enable row level security;

create policy entidades_org_select on public.entidades_organizacionais for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy entidades_org_write on public.entidades_organizacionais for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy controles_select on public.controles_conformidade for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy controles_write on public.controles_conformidade for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy versoes_controle_select on public.versoes_controle for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy execucoes_controle_select on public.execucoes_controle for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy execucoes_controle_insert on public.execucoes_controle for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy excecoes_controle_select on public.excecoes_controle for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy nao_conformidades_select on public.nao_conformidades for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy nao_conformidades_write on public.nao_conformidades for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy planos_remediacao_select on public.planos_remediacao for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy planos_remediacao_write on public.planos_remediacao for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy alteracoes_normativas_select on public.alteracoes_normativas for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy avaliacoes_impacto_select on public.avaliacoes_impacto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy publicacoes_regras_select on public.publicacoes_regras for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy riscos_corporativos_select on public.riscos_corporativos for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy riscos_corporativos_write on public.riscos_corporativos for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]));

create trigger entidades_org_touch before update on public.entidades_organizacionais for each row execute function privado.tocar_atualizado_em();
create trigger controles_touch before update on public.controles_conformidade for each row execute function privado.tocar_atualizado_em();
create trigger nao_conformidades_touch before update on public.nao_conformidades for each row execute function privado.tocar_atualizado_em();
create trigger planos_remediacao_touch before update on public.planos_remediacao for each row execute function privado.tocar_atualizado_em();
create trigger riscos_corporativos_touch before update on public.riscos_corporativos for each row execute function privado.tocar_atualizado_em();

create or replace function public.publicar_controle(p_id_controle uuid,p_texto text,p_evidencia_requerida jsonb,p_vigencia_inicio date,p_vigencia_fim date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.controles_conformidade%rowtype; v_ver int; v_id uuid; v_hash text;
begin
 select * into v from public.controles_conformidade where id=p_id_controle for update;
 if v.id is null then raise exception 'Controle não encontrado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 v_ver:=v.versao_atual+1; v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,v_ver::text,p_texto,coalesce(p_evidencia_requerida,'[]'::jsonb)::text,p_vigencia_inicio::text,coalesce(p_vigencia_fim::text,'')),'sha256'),'hex');
 update public.versoes_controle set status='substituida' where id_controle=v.id and status='publicada';
 insert into public.versoes_controle(id_organizacao,id_controle,versao,texto,evidencia_requerida,vigencia_inicio,vigencia_fim,status,aprovado_por,aprovado_em,hash)
 values(v.id_organizacao,v.id,v_ver,p_texto,coalesce(p_evidencia_requerida,'[]'::jsonb),p_vigencia_inicio,p_vigencia_fim,'publicada',auth.uid(),now(),v_hash) returning id into v_id;
 update public.controles_conformidade set situacao='ativo',versao_atual=v_ver where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ControlePublicado','controles_conformidade',v.id,null,jsonb_build_object('id_versao',v_id,'versao',v_ver));
 return v_id;
end;$$;
revoke all on function public.publicar_controle(uuid,text,jsonb,date,date) from public;
grant execute on function public.publicar_controle(uuid,text,jsonb,date,date) to authenticated;

create or replace function public.aprovar_excecao_controle(p_id_excecao uuid,p_aprovar boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v public.excecoes_controle%rowtype;
begin
 select * into v from public.excecoes_controle where id=p_id_excecao for update;
 if v.id is null then raise exception 'Exceção não encontrada.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 update public.excecoes_controle set status=case when p_aprovar then 'aprovada' else 'rejeitada' end,aprovado_por=auth.uid(),aprovado_em=now() where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ExcecaoControleRevisada','excecoes_controle',v.id,null,jsonb_build_object('aprovada',p_aprovar));
end;$$;
revoke all on function public.aprovar_excecao_controle(uuid,boolean) from public;
grant execute on function public.aprovar_excecao_controle(uuid,boolean) to authenticated;

create or replace function public.encerrar_nao_conformidade(p_id_nao_conformidade uuid,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.nao_conformidades%rowtype;
begin
 select * into v from public.nao_conformidades where id=p_id_nao_conformidade for update;
 if v.id is null then raise exception 'Não conformidade não encontrada.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if exists(select 1 from public.planos_remediacao where id_nao_conformidade=v.id and status not in ('concluido','cancelado')) then raise exception 'Existem planos de remediação pendentes.'; end if;
 update public.nao_conformidades set status='encerrada' where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'NaoConformidadeEncerrada','nao_conformidades',v.id,jsonb_build_object('status',v.status),jsonb_build_object('status','encerrada','fundamento',p_fundamento));
end;$$;
revoke all on function public.encerrar_nao_conformidade(uuid,text) from public;
grant execute on function public.encerrar_nao_conformidade(uuid,text) to authenticated;

create or replace function public.publicar_regra_candidata(p_id_regra_candidata uuid,p_id_avaliacao_impacto uuid,p_vigencia_inicio date,p_vigencia_fim date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.regras_candidatas%rowtype; v_pub uuid; v_hash text;
begin
 select * into v from public.regras_candidatas where id=p_id_regra_candidata for update;
 if v.id is null then raise exception 'Regra candidata não encontrada.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_id_avaliacao_impacto is null or not exists(select 1 from public.avaliacoes_impacto ai where ai.id=p_id_avaliacao_impacto and ai.id_organizacao=v.id_organizacao and ai.aprovado_por is not null) then raise exception 'Avaliação de impacto aprovada é obrigatória.'; end if;
 v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,p_id_avaliacao_impacto::text,p_vigencia_inicio::text,coalesce(p_vigencia_fim::text,''),v.descricao,v.efeito_proposto),'sha256'),'hex');
 insert into public.publicacoes_regras(id_organizacao,id_regra_candidata,id_avaliacao_impacto,vigencia_inicio,vigencia_fim,status,aprovado_por,hash)
 values(v.id_organizacao,v.id,p_id_avaliacao_impacto,p_vigencia_inicio,p_vigencia_fim,'publicada',auth.uid(),v_hash) returning id into v_pub;
 update public.regras_candidatas set status='publicada' where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'RegraCandidataPublicada','regras_candidatas',v.id,null,jsonb_build_object('id_publicacao',v_pub));
 return v_pub;
end;$$;
revoke all on function public.publicar_regra_candidata(uuid,uuid,date,date) from public;
grant execute on function public.publicar_regra_candidata(uuid,uuid,date,date) to authenticated;

commit;
