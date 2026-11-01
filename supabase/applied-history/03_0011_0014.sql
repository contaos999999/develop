-- MIGRATION 20261101211210_0011_financeiro_v3
begin;

create table public.fornecedores (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 documento text, nome_razao_social text not null, nome_fantasia text, tipo text, status text not null default 'ativo' check(status in ('ativo','inativo','bloqueado')),
 risco_documental text not null default 'nao_avaliado' check(risco_documental in ('nao_avaliado','baixo','medio','alto','critico')),
 metadados jsonb not null default '{}'::jsonb, versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create unique index fornecedores_doc_uidx on public.fornecedores(id_organizacao,regexp_replace(documento,'\D','','g')) where documento is not null;
create index fornecedores_nome_idx on public.fornecedores(id_organizacao,nome_razao_social);

create table public.fontes_financeiras (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, tipo text not null, nome text not null, configuracao_ref text,
 ativa boolean not null default true, versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index fontes_financeiras_idx on public.fontes_financeiras(id_contrato,tipo,ativa);

create table public.importacoes_financeiras (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_fonte uuid not null references public.fontes_financeiras(id) on delete restrict,
 id_arquivo uuid references public.arquivos(id) on delete restrict, hash text not null, chave_deduplicacao text not null,
 status text not null default 'pendente' check(status in ('pendente','processando','concluida','falhou','cancelada')),
 total_registros integer not null default 0, total_importado integer not null default 0, total_rejeitado integer not null default 0,
 erro_detalhe text, iniciado_em timestamptz, concluido_em timestamptz, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(), constraint importacoes_financeiras_dedup_uk unique(id_fonte,chave_deduplicacao));
create index importacoes_financeiras_status_idx on public.importacoes_financeiras(id_contrato,status,criado_em desc);

create table public.transacoes_financeiras (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_importacao uuid references public.importacoes_financeiras(id) on delete restrict,
 data date not null, descricao text not null, documento text, id_fornecedor uuid references public.fornecedores(id) on delete restrict,
 fornecedor_nome_original text, fornecedor_documento_original text, valor numeric(18,2) not null, tipo text not null,
 hash_origem text not null, dados_brutos jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now(),
 constraint transacoes_hash_uk unique(id_contrato,hash_origem));
create index transacoes_financeiras_data_idx on public.transacoes_financeiras(id_contrato,data);
create index transacoes_financeiras_fornecedor_idx on public.transacoes_financeiras(id_fornecedor,data);
create index transacoes_financeiras_documento_idx on public.transacoes_financeiras(id_contrato,documento);

create table public.documentos_transacao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_transacao uuid not null references public.transacoes_financeiras(id) on delete restrict,
 id_versao_documento uuid not null references public.versoes_documento(id) on delete restrict, tipo text not null,
 criado_em timestamptz not null default now(), constraint documentos_transacao_uk unique(id_transacao,id_versao_documento,tipo));

create table public.contratos_fornecedores (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_fornecedor uuid not null references public.fornecedores(id) on delete restrict,
 numero_instrumento text, objeto text, vigencia_inicio date, vigencia_fim date, valor numeric(18,2), status text not null default 'ativo' check(status in ('ativo','suspenso','encerrado','cancelado')),
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint contratos_fornecedores_vigencia_ck check(vigencia_fim is null or vigencia_inicio is null or vigencia_fim>=vigencia_inicio));
create index contratos_fornecedores_idx on public.contratos_fornecedores(id_contrato,id_fornecedor,status);

create table public.consumo_orcamentario (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_transacao uuid not null references public.transacoes_financeiras(id) on delete restrict,
 id_linha_orcamentaria uuid not null references public.linhas_orcamentarias(id) on delete restrict, valor_apropriado numeric(18,2) not null,
 regra text, confianca numeric(6,5) check(confianca is null or confianca between 0 and 1), criado_em timestamptz not null default now());
create index consumo_orcamentario_linha_idx on public.consumo_orcamentario(id_linha_orcamentaria,id_transacao);

create table public.conciliacoes (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, periodo date not null, tipo text not null,
 status text not null default 'pendente' check(status in ('pendente','processando','conciliada','com_diferenca','cancelada')),
 saldo_origem numeric(18,2), saldo_contaos numeric(18,2), diferenca numeric(18,2), resultado jsonb not null default '{}'::jsonb,
 concluido_por uuid references auth.users(id) on delete set null, concluido_em timestamptz, criado_em timestamptz not null default now());
create index conciliacoes_idx on public.conciliacoes(id_contrato,periodo,tipo);

create table public.alertas_preventivos (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_transacao uuid references public.transacoes_financeiras(id) on delete restrict,
 regra text not null, severidade text not null check(severidade in ('baixa','media','alta','critica')),
 status text not null default 'aberto' check(status in ('aberto','em_tratamento','resolvido','descartado')),
 descricao text not null, evidencia jsonb not null default '{}'::jsonb, criado_em timestamptz not null default now());
create index alertas_preventivos_idx on public.alertas_preventivos(id_contrato,status,severidade,criado_em desc);

create table public.tratamentos_alertas (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_alerta uuid not null references public.alertas_preventivos(id) on delete restrict,
 decisao text not null check(decisao in ('corrigir','justificar','aceitar_risco','descartar')), fundamento text not null,
 id_evidencia_versao_documento uuid references public.versoes_documento(id) on delete restrict, tratado_por uuid references auth.users(id) on delete set null,
 tratado_em timestamptz not null default now(), criado_em timestamptz not null default now());
create index tratamentos_alertas_idx on public.tratamentos_alertas(id_alerta,tratado_em desc);

create table public.tarefas_alerta (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid not null references public.contratos(id) on delete restrict, id_alerta uuid not null references public.alertas_preventivos(id) on delete restrict,
 descricao text not null, responsavel uuid references auth.users(id) on delete set null, prazo date,
 status text not null default 'pendente' check(status in ('pendente','em_execucao','concluida','cancelada')),
 versao_registro bigint not null default 1, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index tarefas_alerta_idx on public.tarefas_alerta(id_organizacao,responsavel,prazo,status);

alter table public.fornecedores enable row level security; alter table public.fontes_financeiras enable row level security;
alter table public.importacoes_financeiras enable row level security; alter table public.transacoes_financeiras enable row level security;
alter table public.documentos_transacao enable row level security; alter table public.contratos_fornecedores enable row level security;
alter table public.consumo_orcamentario enable row level security; alter table public.conciliacoes enable row level security;
alter table public.alertas_preventivos enable row level security; alter table public.tratamentos_alertas enable row level security;
alter table public.tarefas_alerta enable row level security;

create policy fornecedores_select on public.fornecedores for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy fornecedores_write on public.fornecedores for all to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy fontes_financeiras_select on public.fontes_financeiras for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy fontes_financeiras_write on public.fontes_financeiras for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy importacoes_financeiras_select on public.importacoes_financeiras for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy transacoes_financeiras_select on public.transacoes_financeiras for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy documentos_transacao_select on public.documentos_transacao for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy contratos_fornecedores_select on public.contratos_fornecedores for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy contratos_fornecedores_write on public.contratos_fornecedores for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));
create policy consumo_orcamentario_select on public.consumo_orcamentario for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy conciliacoes_select on public.conciliacoes for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy alertas_preventivos_select on public.alertas_preventivos for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','auditor']::text[]));
create policy tratamentos_alertas_select on public.tratamentos_alertas for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy tarefas_alerta_select on public.tarefas_alerta for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy tarefas_alerta_write on public.tarefas_alerta for all to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

create trigger fornecedores_touch before update on public.fornecedores for each row execute function privado.tocar_atualizado_em();
create trigger fontes_financeiras_touch before update on public.fontes_financeiras for each row execute function privado.tocar_atualizado_em();
create trigger contratos_fornecedores_touch before update on public.contratos_fornecedores for each row execute function privado.tocar_atualizado_em();
create trigger tarefas_alerta_touch before update on public.tarefas_alerta for each row execute function privado.tocar_atualizado_em();

create or replace function public.solicitar_importacao_financeira(p_id_fonte uuid,p_id_arquivo uuid,p_hash text,p_chave_deduplicacao text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_f public.fontes_financeiras%rowtype; v_imp uuid; v_exist uuid;
begin
 select * into v_f from public.fontes_financeiras where id=p_id_fonte;
 if v_f.id is null then raise exception 'Fonte financeira não encontrada.'; end if;
 if not privado.usuario_tem_acesso_contrato(v_f.id_contrato) or not privado.usuario_possui_perfil(v_f.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]) then raise exception 'Acesso negado.'; end if;
 select id into v_exist from public.importacoes_financeiras where id_fonte=p_id_fonte and chave_deduplicacao=p_chave_deduplicacao;
 if v_exist is not null then return v_exist; end if;
 insert into public.importacoes_financeiras(id_organizacao,id_contrato,id_fonte,id_arquivo,hash,chave_deduplicacao,status,criado_por)
 values(v_f.id_organizacao,v_f.id_contrato,v_f.id,p_id_arquivo,p_hash,p_chave_deduplicacao,'pendente',auth.uid()) returning id into v_imp;
 perform privado.enfileirar_job('finance_imports',v_f.id_organizacao,v_f.id_contrato,'importacao_financeira',v_imp,jsonb_build_object('id_importacao',v_imp),'finance:'||v_imp::text);
 perform privado.registrar_evento_auditoria(v_f.id_organizacao,'ImportacaoFinanceiraSolicitada','importacoes_financeiras',v_imp,null,jsonb_build_object('id_fonte',v_f.id));
 return v_imp;
end;$$;
revoke all on function public.solicitar_importacao_financeira(uuid,uuid,text,text) from public;
grant execute on function public.solicitar_importacao_financeira(uuid,uuid,text,text) to authenticated;

create or replace function public.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.alertas_preventivos%rowtype; v_trat uuid;
begin
 select * into v from public.alertas_preventivos where id=p_id_alerta for update;
 if v.id is null then raise exception 'Alerta não encontrado.'; end if;
 if not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_decisao not in ('corrigir','justificar','aceitar_risco','descartar') then raise exception 'Decisão inválida.'; end if;
 insert into public.tratamentos_alertas(id_organizacao,id_contrato,id_alerta,decisao,fundamento,id_evidencia_versao_documento,tratado_por)
 values(v.id_organizacao,v.id_contrato,v.id,p_decisao,p_fundamento,p_id_evidencia_versao_documento,auth.uid()) returning id into v_trat;
 update public.alertas_preventivos set status=case when p_decisao='corrigir' then 'em_tratamento' else 'resolvido' end where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AlertaPreventivoTratado','alertas_preventivos',v.id,null,jsonb_build_object('id_tratamento',v_trat,'decisao',p_decisao));
 return v_trat;
end;$$;
revoke all on function public.tratar_alerta_preventivo(uuid,text,text,uuid) from public;
grant execute on function public.tratar_alerta_preventivo(uuid,text,text,uuid) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101211241_0012_inteligencia_v4
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

-- ============================================================

-- MIGRATION 20261101211316_0013_conformidade_v5
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

-- ============================================================

-- MIGRATION 20261101211348_0014_integracoes_v5
begin;

create table public.clientes_api (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 nome text not null, identificador text not null, secret_hash text not null, ativo boolean not null default true,
 ultimo_uso_em timestamptz, rotacionado_em timestamptz, criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint clientes_api_identificador_uk unique(identificador));
create index clientes_api_org_idx on public.clientes_api(id_organizacao,ativo);

create table public.escopos_clientes_api (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_cliente uuid not null references public.clientes_api(id) on delete cascade, escopo text not null, criado_em timestamptz not null default now(),
 constraint escopos_clientes_api_uk unique(id_cliente,escopo));

create table public.webhooks (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 nome text, url text not null, eventos text[] not null default '{}'::text[], secret_hash text not null,
 ativo boolean not null default true, headers_publicos jsonb not null default '{}'::jsonb,
 criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 constraint webhooks_url_ck check(url ~ '^https://'));
create index webhooks_org_idx on public.webhooks(id_organizacao,ativo);

create table public.assinaturas_eventos_integracao (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_webhook uuid references public.webhooks(id) on delete cascade, versao integer not null, algoritmo text not null default 'hmac-sha256',
 secret_hash text not null, ativo boolean not null default true, valido_desde timestamptz not null default now(), valido_ate timestamptz,
 criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now(),
 constraint assinaturas_webhook_versao_uk unique(id_webhook,versao));
create index assinaturas_eventos_integracao_idx on public.assinaturas_eventos_integracao(id_organizacao,id_webhook,ativo,versao desc);

create table public.eventos_webhook (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_webhook uuid not null references public.webhooks(id) on delete restrict, evento text not null, entidade_tipo text, entidade_id uuid,
 payload_ref jsonb not null default '{}'::jsonb, payload_hash text not null, tentativa integer not null default 0,
 status text not null default 'pendente' check(status in ('pendente','enfileirado','entregue','falhou','cancelado')),
 status_http integer, resposta_hash text, proxima_tentativa timestamptz, entregue_em timestamptz,
 correlation_id uuid not null default gen_random_uuid(), criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index eventos_webhook_fila_idx on public.eventos_webhook(status,proxima_tentativa,criado_em);
create index eventos_webhook_org_idx on public.eventos_webhook(id_organizacao,id_webhook,criado_em desc);

create table public.pacotes_evidencias (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_contrato uuid references public.contratos(id) on delete restrict, escopo jsonb not null, hash text,
 status text not null default 'preparando' check(status in ('preparando','congelado','disponivel','expirado','revogado','falhou')),
 id_arquivo_exportacao uuid references public.arquivos(id) on delete restrict, expira_em timestamptz,
 criado_por uuid references auth.users(id) on delete set null, congelado_em timestamptz, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create index pacotes_evidencias_idx on public.pacotes_evidencias(id_organizacao,status,expira_em);

create table public.itens_pacote_evidencias (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict, entidade_tipo text not null, entidade_id uuid,
 versao_id uuid, hash text not null, metadados jsonb not null default '{}'::jsonb, ordem integer not null default 0, criado_em timestamptz not null default now());
create index itens_pacote_evidencias_idx on public.itens_pacote_evidencias(id_pacote,ordem);

create table public.acessos_pacote_evidencias (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict, token_hash text not null,
 descricao_destinatario text, expira_em timestamptz not null, max_acessos integer, quantidade_acessos integer not null default 0,
 revogado_em timestamptz, criado_por uuid references auth.users(id) on delete set null, criado_em timestamptz not null default now(),
 constraint acessos_pacote_token_uk unique(token_hash));
create index acessos_pacote_evidencias_idx on public.acessos_pacote_evidencias(id_pacote,expira_em,revogado_em);

create table public.exportacoes_evidencias (
 id uuid primary key default gen_random_uuid(), id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict, formato text not null,
 id_arquivo uuid references public.arquivos(id) on delete restrict, hash text not null, tamanho bigint,
 exportado_por uuid references auth.users(id) on delete set null, exportado_em timestamptz not null default now(), metadados jsonb not null default '{}'::jsonb);
create index exportacoes_evidencias_idx on public.exportacoes_evidencias(id_pacote,exportado_em desc);

alter table public.clientes_api enable row level security; alter table public.escopos_clientes_api enable row level security;
alter table public.webhooks enable row level security; alter table public.assinaturas_eventos_integracao enable row level security;
alter table public.eventos_webhook enable row level security; alter table public.pacotes_evidencias enable row level security;
alter table public.itens_pacote_evidencias enable row level security; alter table public.acessos_pacote_evidencias enable row level security;
alter table public.exportacoes_evidencias enable row level security;

create policy clientes_api_select on public.clientes_api for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy escopos_clientes_api_select on public.escopos_clientes_api for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy webhooks_select on public.webhooks for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy assinaturas_eventos_select on public.assinaturas_eventos_integracao for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy eventos_webhook_select on public.eventos_webhook for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy pacotes_evidencias_select on public.pacotes_evidencias for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));
create policy itens_pacote_evidencias_select on public.itens_pacote_evidencias for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy acessos_pacote_evidencias_select on public.acessos_pacote_evidencias for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
create policy exportacoes_evidencias_select on public.exportacoes_evidencias for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));

create trigger clientes_api_touch before update on public.clientes_api for each row execute function privado.tocar_atualizado_em();
create trigger webhooks_touch before update on public.webhooks for each row execute function privado.tocar_atualizado_em();
create trigger eventos_webhook_touch before update on public.eventos_webhook for each row execute function privado.tocar_atualizado_em();
create trigger pacotes_evidencias_touch before update on public.pacotes_evidencias for each row execute function privado.tocar_atualizado_em();

create or replace function public.criar_cliente_api(p_id_organizacao uuid,p_nome text,p_escopos text[] default '{}'::text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_secret text; v_hash text; v_id uuid; v_ident text; v_scope text;
begin
 if not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 v_secret:='cos_'||encode(extensions.gen_random_bytes(32),'hex');
 v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 v_ident:='cli_'||encode(extensions.gen_random_bytes(12),'hex');
 insert into public.clientes_api(id_organizacao,nome,identificador,secret_hash,criado_por) values(p_id_organizacao,p_nome,v_ident,v_hash,auth.uid()) returning id into v_id;
 foreach v_scope in array coalesce(p_escopos,'{}'::text[]) loop insert into public.escopos_clientes_api(id_organizacao,id_cliente,escopo) values(p_id_organizacao,v_id,v_scope) on conflict do nothing; end loop;
 perform privado.registrar_evento_auditoria(p_id_organizacao,'ClienteApiCriado','clientes_api',v_id,null,jsonb_build_object('identificador',v_ident,'escopos',p_escopos));
 return jsonb_build_object('id',v_id,'identificador',v_ident,'secret_uma_vez',v_secret);
end;$$;
revoke all on function public.criar_cliente_api(uuid,text,text[]) from public;
grant execute on function public.criar_cliente_api(uuid,text,text[]) to authenticated;

create or replace function public.rotacionar_cliente_api(p_id_cliente uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.clientes_api%rowtype; v_secret text; v_hash text;
begin
 select * into v from public.clientes_api where id=p_id_cliente for update;
 if v.id is null then raise exception 'Cliente API não encontrado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 v_secret:='cos_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 update public.clientes_api set secret_hash=v_hash,rotacionado_em=now() where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ClienteApiRotacionado','clientes_api',v.id,null,jsonb_build_object('rotacionado_em',now()));
 return jsonb_build_object('id',v.id,'identificador',v.identificador,'secret_uma_vez',v_secret);
end;$$;
revoke all on function public.rotacionar_cliente_api(uuid) from public;
grant execute on function public.rotacionar_cliente_api(uuid) to authenticated;

create or replace function public.criar_webhook(p_id_organizacao uuid,p_nome text,p_url text,p_eventos text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_secret text; v_hash text; v_id uuid;
begin
 if not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_url !~ '^https://' then raise exception 'Webhook exige HTTPS.'; end if;
 v_secret:='whs_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 insert into public.webhooks(id_organizacao,nome,url,eventos,secret_hash,criado_por) values(p_id_organizacao,p_nome,p_url,coalesce(p_eventos,'{}'::text[]),v_hash,auth.uid()) returning id into v_id;
 insert into public.assinaturas_eventos_integracao(id_organizacao,id_webhook,versao,secret_hash,criado_por) values(p_id_organizacao,v_id,1,v_hash,auth.uid());
 perform privado.registrar_evento_auditoria(p_id_organizacao,'WebhookCriado','webhooks',v_id,null,jsonb_build_object('url',p_url,'eventos',p_eventos));
 return jsonb_build_object('id',v_id,'secret_uma_vez',v_secret);
end;$$;
revoke all on function public.criar_webhook(uuid,text,text,text[]) from public;
grant execute on function public.criar_webhook(uuid,text,text,text[]) to authenticated;

create or replace function public.enfileirar_evento_webhook(p_id_webhook uuid,p_evento text,p_entidade_tipo text,p_entidade_id uuid,p_payload_ref jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.webhooks%rowtype; v_evt uuid; v_hash text;
begin
 select * into v from public.webhooks where id=p_id_webhook and ativo=true;
 if v.id is null then raise exception 'Webhook não encontrado ou inativo.'; end if;
 if auth.uid() is not null and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if not (p_evento=any(v.eventos)) then raise exception 'Evento não habilitado para o webhook.'; end if;
 v_hash:=encode(extensions.digest(coalesce(p_payload_ref,'{}'::jsonb)::text,'sha256'),'hex');
 insert into public.eventos_webhook(id_organizacao,id_webhook,evento,entidade_tipo,entidade_id,payload_ref,payload_hash,status,proxima_tentativa)
 values(v.id_organizacao,v.id,p_evento,p_entidade_tipo,p_entidade_id,coalesce(p_payload_ref,'{}'::jsonb),v_hash,'enfileirado',now()) returning id into v_evt;
 perform privado.enfileirar_job('webhooks',v.id_organizacao,null,'evento_webhook',v_evt,jsonb_build_object('id_evento_webhook',v_evt),'webhook:'||v_evt::text);
 return v_evt;
end;$$;
revoke all on function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) from public;
grant execute on function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) to authenticated;

create or replace function public.criar_pacote_evidencias(p_id_organizacao uuid,p_id_contrato uuid,p_escopo jsonb,p_expira_em timestamptz default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not privado.usuario_tem_acesso_organizacao(p_id_organizacao) then raise exception 'Acesso negado.'; end if;
 if p_id_contrato is not null and not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Contrato sem acesso.'; end if;
 insert into public.pacotes_evidencias(id_organizacao,id_contrato,escopo,status,expira_em,criado_por)
 values(p_id_organizacao,p_id_contrato,coalesce(p_escopo,'{}'::jsonb),'preparando',p_expira_em,auth.uid()) returning id into v_id;
 perform privado.enfileirar_job('reports',p_id_organizacao,p_id_contrato,'pacote_evidencias',v_id,jsonb_build_object('id_pacote',v_id),'evidence-package:'||v_id::text);
 return v_id;
end;$$;
revoke all on function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) from public;
grant execute on function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) to authenticated;

create or replace function public.criar_acesso_temporario_pacote(p_id_pacote uuid,p_expira_em timestamptz,p_descricao_destinatario text default null,p_max_acessos integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.pacotes_evidencias%rowtype; v_token text; v_hash text; v_id uuid;
begin
 select * into v from public.pacotes_evidencias where id=p_id_pacote;
 if v.id is null then raise exception 'Pacote não encontrado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_expira_em<=now() then raise exception 'Expiração deve ser futura.'; end if;
 v_token:='ev_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
 insert into public.acessos_pacote_evidencias(id_organizacao,id_pacote,token_hash,descricao_destinatario,expira_em,max_acessos,criado_por)
 values(v.id_organizacao,v.id,v_hash,p_descricao_destinatario,p_expira_em,p_max_acessos,auth.uid()) returning id into v_id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AcessoPacoteEvidenciasCriado','acessos_pacote_evidencias',v_id,null,jsonb_build_object('id_pacote',v.id,'expira_em',p_expira_em));
 return jsonb_build_object('id',v_id,'token_uma_vez',v_token);
end;$$;
revoke all on function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) from public;
grant execute on function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) to authenticated;

commit;