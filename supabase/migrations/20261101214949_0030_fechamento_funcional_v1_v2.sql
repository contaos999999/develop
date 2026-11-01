begin;

create table public.sugestoes_extracao_documento (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_contrato uuid not null references public.contratos(id) on delete restrict,
  id_versao_documento uuid not null references public.versoes_documento(id) on delete restrict,
  tipo text not null check(tipo in ('classificacao','clausula','obrigacao','prazo','documento_exigido','restricao','metadado','regra_candidata')),
  categoria_sugerida text,
  id_requisito_sugerido uuid references public.requisitos_competencia(id) on delete restrict,
  conteudo text not null,
  pagina integer,
  trecho_fonte text,
  confianca numeric(6,5) check(confianca is null or confianca between 0 and 1),
  status text not null default 'pendente' check(status in ('pendente','aprovada','rejeitada','substituida')),
  revisado_por uuid references auth.users(id) on delete set null,
  revisado_em timestamptz,
  metadados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index sugestoes_extracao_doc_idx on public.sugestoes_extracao_documento(id_versao_documento,status,tipo);
alter table public.sugestoes_extracao_documento enable row level security;
create policy sugestoes_extracao_select on public.sugestoes_extracao_documento for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));

alter table public.requisitos_competencia add column if not exists regra_validacao jsonb not null default '{}'::jsonb;
alter table public.requisitos_competencia add column if not exists condicao_aplicabilidade jsonb not null default '{}'::jsonb;

create or replace function privado.avaliar_condicao_requisito(p_id_contrato uuid,p_id_competencia uuid,p_condicao jsonb)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_contrato public.contratos%rowtype; v_comp public.competencias%rowtype; v_tipo text; v_val text; v_qtd int;
begin
  if p_condicao is null or p_condicao='{}'::jsonb then return true; end if;
  select * into v_contrato from public.contratos where id=p_id_contrato;
  select * into v_comp from public.competencias where id=p_id_competencia;
  v_tipo:=coalesce(p_condicao->>'tipo','sempre');
  if v_tipo='sempre' then return true;
  elsif v_tipo='tipo_contrato_em' then return coalesce(v_contrato.tipo_contrato,'')=any(array(select jsonb_array_elements_text(coalesce(p_condicao->'valores','[]'::jsonb))));
  elsif v_tipo='valor_global_minimo' then return coalesce(v_contrato.valor_global,0)>=coalesce((p_condicao->>'valor')::numeric,0);
  elsif v_tipo='valor_global_maximo' then return coalesce(v_contrato.valor_global,0)<=coalesce((p_condicao->>'valor')::numeric,0);
  elsif v_tipo='existe_documento_tipo' then
    v_val:=p_condicao->>'valor';
    select count(*) into v_qtd from public.documentos_competencia d where d.id_competencia=p_id_competencia and d.tipo=v_val and d.situacao='ativo';
    return v_qtd>0;
  elsif v_tipo='existe_transacao_tipo' then
    v_val:=p_condicao->>'valor';
    select count(*) into v_qtd from public.transacoes_financeiras t where t.id_contrato=p_id_contrato and t.data between v_comp.periodo_inicio and v_comp.periodo_fim and t.tipo=v_val;
    return v_qtd>0;
  elsif v_tipo='existe_rescisao' then
    select count(*) into v_qtd from public.documentos_competencia d where d.id_competencia=p_id_competencia and (lower(d.tipo) like '%rescis%' or lower(d.titulo) like '%rescis%') and d.situacao='ativo';
    return v_qtd>0;
  elsif v_tipo='existe_imobilizado' then
    select count(*) into v_qtd from public.transacoes_financeiras t where t.id_contrato=p_id_contrato and t.data between v_comp.periodo_inicio and v_comp.periodo_fim and (lower(t.descricao) like '%imobiliz%' or lower(coalesce(t.dados_brutos->>'rubrica','')) like '%imobiliz%');
    return v_qtd>0;
  elsif v_tipo='existe_aplicacao_financeira' then
    select count(*) into v_qtd from public.transacoes_financeiras t where t.id_contrato=p_id_contrato and t.data between v_comp.periodo_inicio and v_comp.periodo_fim and (lower(t.descricao) like '%aplica%financeir%' or lower(t.descricao) like '%rendimento%');
    return v_qtd>0;
  end if;
  return true;
end;$$;
revoke all on function privado.avaliar_condicao_requisito(uuid,uuid,jsonb) from public,anon,authenticated;

create or replace function privado.preencher_snapshot_item_lista()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_regra jsonb; v_cond jsonb;
begin
  if new.origem_tipo='item_lista' and new.origem_id is not null then
    select regra_validacao into v_regra from public.itens_lista where id=new.origem_id;
    new.regra_validacao:=coalesce(v_regra,'{}'::jsonb);
    v_cond:=coalesce(v_regra->'condicao','{}'::jsonb);
    new.condicao_aplicabilidade:=v_cond;
    if v_cond<>'{}'::jsonb then new.aplicavel:=privado.avaliar_condicao_requisito(new.id_contrato,new.id_competencia,v_cond); end if;
  end if;
  return new;
end;$$;
revoke all on function privado.preencher_snapshot_item_lista() from public,anon,authenticated;
drop trigger if exists requisitos_snapshot_item_lista on public.requisitos_competencia;
create trigger requisitos_snapshot_item_lista before insert on public.requisitos_competencia for each row execute function privado.preencher_snapshot_item_lista();

alter table public.resultados_requisitos drop constraint if exists resultados_requisitos_resultado_check;
alter table public.resultados_requisitos add constraint resultados_requisitos_resultado_check check(resultado in ('nao_enviado','recebido','pendente','em_analise','conforme','nao_conforme','inconclusivo','requer_revisao','nao_aplicavel'));

alter table public.apontamentos_internos drop constraint if exists apontamentos_internos_severidade_check;
alter table public.apontamentos_internos add constraint apontamentos_internos_severidade_check check(severidade in ('informativo','baixa','media','alta','critica'));
alter table public.apontamentos_internos add column if not exists regra_violada text;
alter table public.apontamentos_internos add column if not exists acao_sugerida text;
alter table public.apontamentos_internos add column if not exists fonte jsonb not null default '{}'::jsonb;

create or replace function privado.validar_nova_versao_documento()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_situacao text;
begin
  if new.id_documento_competencia is not null and new.numero_versao>1 then
    select c.situacao into v_situacao from public.documentos_competencia d join public.competencias c on c.id=d.id_competencia where d.id=new.id_documento_competencia;
    if v_situacao in ('em_analise','pendente_correcao','em_reanalise','pode_apresentar_contratante','apresentado','aguardando_contratante','com_apontamentos','pode_reapresentar_contratante','reapresentado') and nullif(trim(coalesce(new.motivo_substituicao,'')),'') is null then
      raise exception 'Informe o motivo da substituição antes de criar uma nova versão deste documento.';
    end if;
  end if;
  return new;
end;$$;
revoke all on function privado.validar_nova_versao_documento() from public,anon,authenticated;
drop trigger if exists validar_nova_versao_documento on public.versoes_documento;
create trigger validar_nova_versao_documento before insert on public.versoes_documento for each row execute function privado.validar_nova_versao_documento();

alter table public.execucoes_analise add column if not exists snapshot_entrada jsonb not null default '{}'::jsonb;
alter table public.execucoes_analise add column if not exists requisitos_afetados uuid[] not null default '{}'::uuid[];

create or replace function privado.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa')
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_exec uuid; v_snapshot jsonb; v_hash text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if p_tipo not in ('completa','reanálise','parcial') then raise exception 'O tipo de análise informado não é válido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite solicitar esta análise.'; end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then raise exception 'A situação atual desta competência não permite iniciar uma nova análise.'; end if;
  select jsonb_build_object(
    'competencia',jsonb_build_object('id',v.id,'referencia',v.competencia_referencia,'periodo_inicio',v.periodo_inicio,'periodo_fim',v.periodo_fim),
    'requisitos',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'origem_tipo',r.origem_tipo,'origem_id',r.origem_id,'origem_versao',r.origem_versao,'hash',r.hash_snapshot,'regra_validacao',r.regra_validacao) order by r.ordem,r.id) from public.requisitos_competencia r where r.id_competencia=v.id),'[]'::jsonb),
    'documentos',coalesce((select jsonb_agg(jsonb_build_object('id_documento',d.id,'id_versao',vd.id,'numero_versao',vd.numero_versao,'hash',vd.hash) order by d.id) from public.documentos_competencia d join lateral (select x.* from public.versoes_documento x where x.id_documento_competencia=d.id order by x.numero_versao desc limit 1) vd on true where d.id_competencia=v.id and d.situacao='ativo'),'[]'::jsonb),
    'motor','contaos','versao_motor','2.0','idioma','pt-BR','timezone','America/Sao_Paulo'
  ) into v_snapshot;
  v_hash:=encode(extensions.digest(v_snapshot::text,'sha256'),'hex');
  insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,motor,versao_motor,prompt_versao,iniciada_por,iniciada_em,snapshot_entrada)
  values(v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente',v_hash,'contaos','2.0','analise-pt-BR-v2',auth.uid(),now(),v_snapshot) returning id into v_exec;
  update public.competencias set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end where id=v.id;
  perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'execucao_analise',v_exec,jsonb_build_object('entidade_tipo','execucao_analise','id_execucao',v_exec,'id_competencia',v.id),'analysis:'||v_exec::text);
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,jsonb_build_object('id_competencia',v.id,'tipo',p_tipo,'hash_entrada',v_hash));
  return v_exec;
end;$$;

create or replace function privado.solicitar_reanalise_requisitos(p_id_competencia uuid,p_requisitos uuid[])
returns uuid language plpgsql security definer set search_path='' as $$
declare v_exec uuid;
begin
  if p_requisitos is null or cardinality(p_requisitos)=0 then raise exception 'Selecione ao menos um requisito para reanálise.'; end if;
  if exists(select 1 from unnest(p_requisitos) x where not exists(select 1 from public.requisitos_competencia r where r.id=x and r.id_competencia=p_id_competencia)) then raise exception 'Um dos requisitos selecionados não pertence a esta competência.'; end if;
  v_exec:=privado.solicitar_analise_competencia(p_id_competencia,'parcial');
  update public.execucoes_analise set requisitos_afetados=p_requisitos,metadados=metadados||jsonb_build_object('reanálise_incremental',true) where id=v_exec;
  return v_exec;
end;$$;
create or replace function public.solicitar_reanalise_requisitos(p_id_competencia uuid,p_requisitos uuid[])
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_reanalise_requisitos($1,$2)$$;
revoke all on function public.solicitar_reanalise_requisitos(uuid,uuid[]) from public,anon;
grant execute on function public.solicitar_reanalise_requisitos(uuid,uuid[]) to authenticated;

create or replace function privado.solicitar_parecer_interno(p_id_competencia uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_job uuid;
begin
 select * into v from public.competencias where id=p_id_competencia;
 if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
 if coalesce((privado.avaliar_portao_conformidade(v.id)->>'liberado')::boolean,false) is not true then raise exception 'O parecer final somente pode ser gerado depois que os requisitos obrigatórios estiverem integralmente tratados.'; end if;
 v_job:=privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'gerar_parecer_interno',v.id,jsonb_build_object('entidade_tipo','gerar_parecer_interno','id_competencia',v.id),'parecer:'||v.id::text||':'||v.versao_registro::text);
 return v_job;
end;$$;
create or replace function public.solicitar_parecer_interno(p_id_competencia uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_parecer_interno($1)$$;
revoke all on function public.solicitar_parecer_interno(uuid) from public,anon;
grant execute on function public.solicitar_parecer_interno(uuid) to authenticated;

create or replace function privado.aprovar_parecer_interno(p_id_parecer uuid,p_aprovar boolean,p_fundamento text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v public.pareceres_internos%rowtype;
begin
 select * into v from public.pareceres_internos where id=p_id_parecer for update;
 if v.id is null then raise exception 'Não encontramos o parecer informado.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite aprovar este parecer.'; end if;
 if v.autor=auth.uid() then raise exception 'O parecer deve ser aprovado por uma pessoa diferente de quem o elaborou.'; end if;
 update public.pareceres_internos set status=case when p_aprovar then 'aprovado' else 'rejeitado' end,aprovado_por=auth.uid(),aprovado_em=now() where id=v.id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ParecerInternoRevisado','pareceres_internos',v.id,null,jsonb_build_object('aprovado',p_aprovar,'fundamento',p_fundamento));
end;$$;
create or replace function public.aprovar_parecer_interno(p_id_parecer uuid,p_aprovar boolean,p_fundamento text default null)
returns void language sql security invoker set search_path='' as $$select privado.aprovar_parecer_interno($1,$2,$3)$$;
revoke all on function public.aprovar_parecer_interno(uuid,boolean,text) from public,anon;
grant execute on function public.aprovar_parecer_interno(uuid,boolean,text) to authenticated;

create or replace function privado.aprovar_apresentacao(p_id_competencia uuid,p_fundamento text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_portao jsonb; v_exec uuid; v_parecer uuid; v_aprov uuid; v_hash text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]) then raise exception 'Seu perfil atual não permite liberar esta apresentação.'; end if;
  if v.situacao not in ('em_analise','em_reanalise','pendente_correcao','rascunho') then raise exception 'A situação atual desta competência ainda não permite a liberação.'; end if;
  v_portao:=privado.avaliar_portao_conformidade(v.id);
  if coalesce((v_portao->>'liberado')::boolean,false) is not true then raise exception 'A competência ainda não atingiu 100,00%% de conformidade dos requisitos obrigatórios e aplicáveis.'; end if;
  select id into v_parecer from public.pareceres_internos where id_competencia=v.id and status='aprovado' order by versao desc limit 1;
  if v_parecer is null then raise exception 'Antes de liberar a apresentação, gere o parecer interno e obtenha a aprovação do responsável autorizado.'; end if;
  select id into v_exec from public.execucoes_analise where id_competencia=v.id and status='concluida' order by concluida_em desc nulls last,criado_em desc limit 1;
  v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,coalesce(v_exec::text,''),v_parecer::text,v_portao::text,coalesce(p_fundamento,'')),'sha256'),'hex');
  insert into public.aprovacoes(id_organizacao,id_contrato,id_competencia,tipo,status,aprovado_por,fundamento,hash_contexto,percentual_conformidade,id_execucao_analise)
  values(v.id_organizacao,v.id_contrato,v.id,'apresentacao','aprovada',auth.uid(),p_fundamento,v_hash,100.00,v_exec) returning id into v_aprov;
  update public.competencias set situacao='pode_apresentar_contratante',percentual_conformidade=100.00,liberada_para_apresentacao_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'CompetenciaLiberadaParaApresentacao','competencias',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','pode_apresentar_contratante','id_aprovacao',v_aprov,'id_parecer',v_parecer));
  return jsonb_build_object('id_aprovacao',v_aprov,'situacao','pode_apresentar_contratante','percentual_conformidade',100.00,'id_parecer',v_parecer);
end;$$;

alter table public.apontamentos_contratante add column if not exists valor_questionado numeric(18,2);
alter table public.apontamentos_contratante add column if not exists glosa_potencial numeric(18,2);
alter table public.apontamentos_contratante add column if not exists valor_aceito numeric(18,2);
alter table public.apontamentos_contratante add column if not exists impacto_financeiro_estimado numeric(18,2);
alter table public.apontamentos_contratante add column if not exists classificacao_sugerida text;
alter table public.apontamentos_contratante add column if not exists confianca_classificacao numeric(6,5) check(confianca_classificacao is null or confianca_classificacao between 0 and 1);
alter table public.contratos add column if not exists configuracao_diligencia jsonb not null default '{"prazo_padrao_dias":5,"tipo_contagem":"corridos"}'::jsonb;

alter table public.tarefas_diligencia add column if not exists tipo_acao text;
alter table public.tarefas_diligencia add column if not exists prioridade text not null default 'media' check(prioridade in ('baixa','media','alta','critica'));
alter table public.tarefas_diligencia add column if not exists depende_de uuid[] not null default '{}'::uuid[];
alter table public.tarefas_diligencia add column if not exists validacao_solucao text not null default 'pendente' check(validacao_solucao in ('pendente','em_analise','aprovada','rejeitada'));

create or replace function privado.enfileirar_extracao_parecer_contratante()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform privado.enfileirar_job('ai',new.id_organizacao,new.id_contrato,'extrair_diligencia',new.id,jsonb_build_object('entidade_tipo','extrair_diligencia','id_parecer_contratante',new.id,'id_competencia',new.id_competencia,'id_ciclo',new.id_ciclo),'diligencia:'||new.id::text);
  return new;
end;$$;
revoke all on function privado.enfileirar_extracao_parecer_contratante() from public,anon,authenticated;
drop trigger if exists parecer_contratante_extracao on public.pareceres_contratante;
create trigger parecer_contratante_extracao after insert on public.pareceres_contratante for each row when (new.parecer_final_favoravel=false) execute function privado.enfileirar_extracao_parecer_contratante();

create or replace function privado.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v public.tarefas_diligencia%rowtype;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Não encontramos a tarefa informada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
 if v.responsavel is not null and v.responsavel<>auth.uid() and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Somente o responsável pela tarefa ou um perfil autorizado pode concluí-la.'; end if;
 if exists(select 1 from unnest(v.depende_de) d where not exists(select 1 from public.tarefas_diligencia t where t.id=d and t.status='concluida' and t.validacao_solucao='aprovada')) then raise exception 'Esta tarefa possui dependências que ainda não foram concluídas e validadas.'; end if;
 if p_id_evidencia_versao_documento is null or not exists(select 1 from public.versoes_documento vd where vd.id=p_id_evidencia_versao_documento and vd.id_contrato=v.id_contrato) then raise exception 'Inclua uma evidência válida antes de concluir a tarefa.'; end if;
 update public.tarefas_diligencia set status='concluida',id_evidencia_versao_documento=p_id_evidencia_versao_documento,validacao_solucao='em_analise' where id=v.id;
 if v.id_apontamento is not null then
   update public.apontamentos_contratante set status='em_tratamento' where id=v.id_apontamento and status not in ('encerrado','resolvido');
   perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'revalidar_apontamento',v.id_apontamento,jsonb_build_object('entidade_tipo','revalidar_apontamento','id_apontamento',v.id_apontamento,'id_tarefa',v.id,'id_evidencia',p_id_evidencia_versao_documento),'revalidar-apontamento:'||v.id_apontamento::text||':'||p_id_evidencia_versao_documento::text);
 end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'TarefaDiligenciaConcluida','tarefas_diligencia',v.id,null,jsonb_build_object('id_evidencia',p_id_evidencia_versao_documento,'validacao_solucao','em_analise'));
end;$$;

alter table public.contestacoes add column if not exists recomendada boolean not null default false;
alter table public.contestacoes add column if not exists justificativa_recomendacao text;
alter table public.contestacoes add column if not exists resultado_final text;
alter table public.contestacoes add column if not exists resultado_registrado_em timestamptz;

create or replace function privado.solicitar_minuta_contestacao(p_id_apontamento uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.apontamentos_contratante%rowtype; v_job uuid;
begin
 select * into v from public.apontamentos_contratante where id=p_id_apontamento;
 if v.id is null then raise exception 'Não encontramos o apontamento informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite solicitar uma minuta de contestação.'; end if;
 v_job:=privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'minuta_contestacao',v.id,jsonb_build_object('entidade_tipo','minuta_contestacao','id_apontamento',v.id),'minuta-contestacao:'||v.id::text||':'||v.versao_registro::text);
 return v_job;
end;$$;
create or replace function public.solicitar_minuta_contestacao(p_id_apontamento uuid)
returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_minuta_contestacao($1)$$;
revoke all on function public.solicitar_minuta_contestacao(uuid) from public,anon;
grant execute on function public.solicitar_minuta_contestacao(uuid) to authenticated;

alter table public.precedentes add column if not exists categoria text;
alter table public.precedentes add column if not exists valor_referencia numeric(18,2);
alter table public.precedentes add column if not exists rubrica text;
alter table public.precedentes add column if not exists documento_tipo text;
alter table public.precedentes add column if not exists confirmacoes integer not null default 1;
alter table public.precedentes add column if not exists ultima_confirmacao_em timestamptz;
alter table public.precedentes add column if not exists hierarquia_normativa integer not null default 0;
alter table public.precedentes add column if not exists forca_score numeric(8,6);

create or replace function privado.registrar_desfecho_contestacao(p_id_contestacao uuid,p_resultado text,p_texto text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.contestacoes%rowtype; v_ap public.apontamentos_contratante%rowtype; v_desfecho uuid; v_contratante uuid; v_prec uuid;
begin
 select * into v from public.contestacoes where id=p_id_contestacao for update;
 if v.id is null then raise exception 'Não encontramos a contestação informada.'; end if;
 select * into v_ap from public.apontamentos_contratante where id=v.id_apontamento;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite registrar o resultado da contestação.'; end if;
 if p_resultado not in ('aceita','rejeitada','parcialmente_aceita','pendente') then raise exception 'Selecione um resultado válido para a contestação.'; end if;
 update public.contestacoes set resultado_final=p_resultado,resultado_registrado_em=now() where id=v.id;
 insert into public.desfechos_apontamentos(id_organizacao,id_contrato,id_competencia,id_apontamento,tipo_desfecho,texto,criado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id_apontamento,'contestacao_'||p_resultado,p_texto,auth.uid()) returning id into v_desfecho;
 update public.apontamentos_contratante set status=case when p_resultado in ('aceita','parcialmente_aceita') then 'encerrado' when p_resultado='rejeitada' then 'em_tratamento' else status end where id=v.id_apontamento;
 select id_contratante into v_contratante from public.contratos where id=v.id_contrato;
 select id into v_prec from public.precedentes where id_organizacao=v.id_organizacao and id_contrato_origem=v.id_contrato and fonte_tipo='apontamento_contratante' and fonte_id=v.id_apontamento limit 1;
 if v_prec is null then
   insert into public.precedentes(id_organizacao,id_contratante,id_contrato_origem,competencia_origem,problema,solucao,desfecho,fonte_tipo,fonte_id,confianca,status,ultima_confirmacao_em)
   select v.id_organizacao,v_contratante,v.id_contrato,c.competencia_referencia,v_ap.descricao,v.texto,p_resultado,'apontamento_contratante',v.id_apontamento,case when p_resultado='aceita' then 0.85 when p_resultado='parcialmente_aceita' then 0.65 else 0.45 end,'ativo',now() from public.competencias c where c.id=v.id_competencia returning id into v_prec;
 else
   update public.precedentes set desfecho=p_resultado,confirmacoes=confirmacoes+1,ultima_confirmacao_em=now(),confianca=greatest(0,least(1,coalesce(confianca,0.5)+case when p_resultado='aceita' then 0.08 when p_resultado='parcialmente_aceita' then 0.03 else -0.05 end)) where id=v_prec;
 end if;
 perform privado.enfileirar_job('embeddings',v.id_organizacao,v.id_contrato,'precedente',v_prec,jsonb_build_object('entidade_tipo','precedente','entidade_id',v_prec),'embed:precedente:'||v_prec::text||':'||extract(epoch from now())::bigint::text);
 perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'aprendizado_desfecho',v_desfecho,jsonb_build_object('entidade_tipo','aprendizado_desfecho','id_desfecho',v_desfecho,'id_precedente',v_prec),'learning:'||v_desfecho::text);
 perform privado.registrar_evento_auditoria(v.id_organizacao,'DesfechoContestacaoRegistrado','contestacoes',v.id,null,jsonb_build_object('resultado',p_resultado,'id_desfecho',v_desfecho,'id_precedente',v_prec));
 return v_desfecho;
end;$$;
create or replace function public.registrar_desfecho_contestacao(p_id_contestacao uuid,p_resultado text,p_texto text default null)
returns uuid language sql security invoker set search_path='' as $$select privado.registrar_desfecho_contestacao($1,$2,$3)$$;
revoke all on function public.registrar_desfecho_contestacao(uuid,text,text) from public,anon;
grant execute on function public.registrar_desfecho_contestacao(uuid,text,text) to authenticated;

commit;
