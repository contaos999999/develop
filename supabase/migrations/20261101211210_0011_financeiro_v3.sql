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
