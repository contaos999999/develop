begin;

create table public.relacionamentos_conhecimento (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, origem_tipo text not null, origem_id uuid not null,
 destino_tipo text not null, destino_id uuid not null, relacao text not null, peso numeric(8,5), metadados jsonb not null default '{}'::jsonb,
 criado_em timestamptz not null default now());
create index relacionamentos_conhecimento_origem_idx on public.relacionamentos_conhecimento(id_organizacao,origem_tipo,origem_id);
create index relacionamentos_conhecimento_destino_idx on public.relacionamentos_conhecimento(id_organizacao,destino_tipo,destino_id);

create table public.consultas_semanticas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, escopo text not null, texto_consulta text not null,
 filtros jsonb not null default '{}'::jsonb, modelo text, criado_por uuid references auth.users(id) on delete set null,
 status text not null default 'pendente' check(status in ('pendente','processando','concluida','falhou')),
 criado_em timestamptz not null default now());
create index consultas_semanticas_idx on public.consultas_semanticas(id_organizacao,id_contrato,criado_em desc);

create table public.similaridades_precedentes (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, id_consulta uuid not null references public.consultas_semanticas(id) on delete restrict,
 id_precedente uuid not null references public.precedentes(id) on delete restrict, score numeric(8,6) not null,
 modelo text, metadados jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now());
create index similaridades_precedentes_idx on public.similaridades_precedentes(id_consulta,score desc);

create table public.alertas_historicos_transversais (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato_alvo uuid not null references public.contratos(id) on delete restrict, id_precedente uuid not null references public.precedentes(id) on delete restrict,
 id_contrato_origem uuid not null references public.contratos(id) on delete restrict, competencia_origem date, score numeric(8,6),
 status text not null default 'informativo' check(status in ('informativo','revisado','promovido','descartado')),
 criado_em timestamptz not null default now());
create index alertas_historicos_transversais_idx on public.alertas_historicos_transversais(id_contrato_alvo,status,score desc);

create table public.pontuacoes_risco (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, entidade_tipo text not null, entidade_id uuid not null,
 modelo_versao text not null, score numeric(8,6) not null, fatores jsonb not null default '[]'::jsonb,
 explicacao text, fontes jsonb not null default '[]'::jsonb, criado_em timestamptz not null default now());
create index pontuacoes_risco_idx on public.pontuacoes_risco(id_organizacao,entidade_tipo,entidade_id,criado_em desc);

create table public.perfis_contratante (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contratante uuid not null references public.contratantes(id) on delete restrict, versao integer not null, resumo text,
 padroes jsonb not null default '[]'::jsonb, metricas jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now(),
 atualizado_em timestamptz not null default now(), constraint perfis_contratante_uk unique(id_contratante,versao));

create table public.padroes_historicos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contratante uuid not null references public.contratantes(id) on delete restrict, tipo text not null, descricao text not null,
 evidencias jsonb not null default '[]'::jsonb, confianca numeric(6,5) check(confianca is null or confianca between 0 and 1),
 status text not null default 'observado' check(status in ('observado','confirmado','descartado','substituido')), criado_em timestamptz not null default now());
create index padroes_historicos_idx on public.padroes_historicos(id_contratante,tipo,status);

create table public.retornos_modelo (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, id_consulta uuid references public.consultas_semanticas(id) on delete restrict,
 id_execucao_analise uuid references public.execucoes_analise(id) on delete restrict, provedor text, modelo text, prompt_versao text,
 resposta jsonb not null, uso_tokens jsonb not null default '{}'::jsonb, status text not null default 'concluido' check(status in ('concluido','parcial','falhou')),
 fontes jsonb not null default '[]'::jsonb, criado_em timestamptz not null default now());
create index retornos_modelo_idx on public.retornos_modelo(id_organizacao,modelo,criado_em desc);

create table public.regras_candidatas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, origem_tipo text not null, origem_id uuid,
 descricao text not null, fonte jsonb not null default '{}'::jsonb, efeito_proposto text not null default 'informativo' check(efeito_proposto in ('informativo','alerta','bloqueio')),
 status text not null default 'candidata' check(status in ('candidata','em_revisao','aprovada','rejeitada','publicada')),
 criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now());
create index regras_candidatas_idx on public.regras_candidatas(id_organizacao,id_contrato,status,criado_em desc);

create table public.metricas_historicas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contratante uuid references public.contratantes(id) on delete restrict, id_contrato uuid references public.contratos(id) on delete restrict,
 periodo_inicio date, periodo_fim date, metrica text not null, valor_numeric numeric(20,6), valor_texto text,
 dimensoes jsonb not null default '{}'::jsonb, calculado_em timestamptz not null default now(), criado_em timestamptz not null default now());
create index metricas_historicas_idx on public.metricas_historicas(id_organizacao,id_contratante,id_contrato,metrica,periodo_fim desc);

create table public.sessoes_copiloto (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, titulo text, escopo jsonb not null default '{}'::jsonb,
 status text not null default 'ativa' check(status in ('ativa','encerrada','arquivada')), criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index sessoes_copiloto_idx on public.sessoes_copiloto(id_organizacao,id_contrato,criado_por,criado_em desc);

create table public.mensagens_copiloto (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, id_sessao uuid not null references public.sessoes_copiloto(id) on delete restrict,
 papel text not null check(papel in ('usuario','assistente','sistema')), conteudo text not null,
 id_consulta_semantica uuid references public.consultas_semanticas(id) on delete restrict, id_retorno_modelo uuid references public.retornos_modelo(id) on delete restrict,
 criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now());
create index mensagens_copiloto_idx on public.mensagens_copiloto(id_sessao,criado_em);

create table public.fontes_resposta_copiloto (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, id_mensagem uuid not null references public.mensagens_copiloto(id) on delete restrict,
 fonte_tipo text not null, fonte_id uuid, id_versao_documento uuid references public.versoes_documento(id) on delete restrict,
 pagina integer, trecho text, score numeric(8,6), metadados jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now());
create index fontes_resposta_copiloto_idx on public.fontes_resposta_copiloto(id_mensagem,score desc);

alter table public.relacionamentos_conhecimento enable row level security; alter table public.consultas_semanticas enable row level security;
alter table public.similaridades_precedentes enable row level security; alter table public.alertas_historicos_transversais enable row level security;
alter table public.pontuacoes_risco enable row level security; alter table public.perfis_contratante enable row level security;
alter table public.padroes_historicos enable row level security; alter table public.retornos_modelo enable row level security;
alter table public.regras_candidatas enable row level security; alter table public.metricas_historicas enable row level security;
alter table public.sessoes_copiloto enable row level security; alter table public.mensagens_copiloto enable row level security;
alter table public.fontes_resposta_copiloto enable row level security;

create policy relacionamentos_conhecimento_select on public.relacionamentos_conhecimento for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy consultas_semanticas_select on public.consultas_semanticas for select to authenticated using(criado_por=auth.uid() and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy similaridades_precedentes_select on public.similaridades_precedentes for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy alertas_historicos_select on public.alertas_historicos_transversais for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato_alvo));
create policy pontuacoes_risco_select on public.pontuacoes_risco for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy perfis_contratante_select on public.perfis_contratante for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy padroes_historicos_select on public.padroes_historicos for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy retornos_modelo_select on public.retornos_modelo for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy regras_candidatas_select on public.regras_candidatas for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy metricas_historicas_select on public.metricas_historicas for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy sessoes_copiloto_select on public.sessoes_copiloto for select to authenticated using(criado_por=auth.uid() and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy mensagens_copiloto_select on public.mensagens_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.sessoes_copiloto s where s.id=id_sessao and s.criado_por=auth.uid()));
create policy fontes_resposta_copiloto_select on public.fontes_resposta_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.mensagens_copiloto m join public.sessoes_copiloto s on s.id=m.id_sessao where m.id=id_mensagem and s.criado_por=auth.uid()));

create trigger perfis_contratante_touch before update on public.perfis_contratante for each row execute function privado.tocar_atualizado_em();
create trigger sessoes_copiloto_touch before update on public.sessoes_copiloto for each row execute function privado.tocar_atualizado_em();

create or replace function public.iniciar_consulta_copiloto(p_id_contrato uuid,p_id_sessao uuid,p_texto text,p_filtros jsonb default '{}'::jsonb,p_modelo text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_sess uuid; v_cons uuid; v_msg uuid; v_job uuid;
begin
 select id_organizacao into v_org from public.contratos where id=p_id_contrato;
 if v_org is null then raise exception 'Contrato não encontrado.'; end if;
 if not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Acesso negado.'; end if;
 if p_id_sessao is null then
   insert into public.sessoes_copiloto(id_organizacao,id_contrato,titulo,criado_por) values(v_org,p_id_contrato,left(p_texto,120),auth.uid()) returning id into v_sess;
 else
   select id into v_sess from public.sessoes_copiloto where id=p_id_sessao and id_organizacao=v_org and criado_por=auth.uid() and status='ativa';
   if v_sess is null then raise exception 'Sessão inválida.'; end if;
 end if;
 insert into public.consultas_semanticas(id_organizacao,id_contrato,escopo,texto_consulta,filtros,modelo,criado_por,status)
 values(v_org,p_id_contrato,'contrato',p_texto,coalesce(p_filtros,'{}'::jsonb),p_modelo,auth.uid(),'pendente') returning id into v_cons;
 insert into public.mensagens_copiloto(id_organizacao,id_contrato,id_sessao,papel,conteudo,id_consulta_semantica,criado_por)
 values(v_org,p_id_contrato,v_sess,'usuario',p_texto,v_cons,auth.uid()) returning id into v_msg;
 v_job:=privado.enfileirar_job('ai',v_org,p_id_contrato,'consulta_semantica',v_cons,jsonb_build_object('id_consulta',v_cons,'id_sessao',v_sess),'copilot:'||v_cons::text);
 perform privado.registrar_evento_auditoria(v_org,'ConsultaCopilotoSolicitada','consultas_semanticas',v_cons,null,jsonb_build_object('id_sessao',v_sess,'id_job',v_job));
 return jsonb_build_object('id_sessao',v_sess,'id_consulta',v_cons,'id_mensagem',v_msg,'id_job',v_job);
end;$$;
revoke all on function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) from public;
grant execute on function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) to authenticated;

commit;
