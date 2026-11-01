begin;

-- Solicitação de análise cria execução e job AI de forma idempotente.
create or replace function privado.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa')
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_exec uuid;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if p_tipo not in ('completa','reanálise','parcial') then raise exception 'Tipo de análise inválido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then raise exception 'Situação não permite análise.'; end if;
  insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,versao_motor,iniciada_por,iniciada_em)
  values(v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente','1.0',auth.uid(),now()) returning id into v_exec;
  update public.competencias set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end where id=v.id;
  perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'execucao_analise',v_exec,jsonb_build_object('id_execucao',v_exec,'id_competencia',v.id),'analysis:'||v_exec::text);
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,jsonb_build_object('id_competencia',v.id,'tipo',p_tipo));
  return v_exec;
end;$$;

-- Resultado humano/assistido é sempre nova linha; histórico anterior não é sobrescrito.
create or replace function privado.registrar_resultado_requisito(p_id_execucao uuid,p_id_requisito uuid,p_resultado text,p_justificativa text default null,p_fundamento text default null,p_evidencias jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_exec public.execucoes_analise%rowtype; v_req public.requisitos_competencia%rowtype; v_id uuid; v_ev jsonb; v_portao jsonb;
begin
  select * into v_exec from public.execucoes_analise where id=p_id_execucao;
  select * into v_req from public.requisitos_competencia where id=p_id_requisito;
  if v_exec.id is null or v_req.id is null or v_exec.id_competencia<>v_req.id_competencia then raise exception 'Execução/requisito inválido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_exec.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v_exec.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade','financeiro','contabilidade','rh_dp']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if p_resultado not in ('pendente','em_analise','conforme','nao_conforme','inconclusivo','nao_aplicavel') then raise exception 'Resultado inválido.'; end if;
  if p_resultado='nao_aplicavel' and nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Não aplicável exige fundamento.'; end if;
  insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa,fundamento,metadados)
  values(v_exec.id_organizacao,v_exec.id_contrato,v_exec.id_competencia,v_exec.id,v_req.id,p_resultado,p_justificativa,p_fundamento,jsonb_build_object('origem','revisao_humana')) returning id into v_id;
  if jsonb_typeof(coalesce(p_evidencias,'[]'::jsonb))='array' then
    for v_ev in select * from jsonb_array_elements(coalesce(p_evidencias,'[]'::jsonb)) loop
      insert into public.evidencias_resultado(id_organizacao,id_contrato,id_competencia,id_resultado,id_versao_documento,pagina,trecho,tipo_evidencia,referencia_externa,hash)
      values(v_exec.id_organizacao,v_exec.id_contrato,v_exec.id_competencia,v_id,nullif(v_ev->>'id_versao_documento','')::uuid,nullif(v_ev->>'pagina','')::integer,v_ev->>'trecho',coalesce(v_ev->>'tipo_evidencia','documento'),v_ev->>'referencia_externa',v_ev->>'hash');
    end loop;
  end if;
  v_portao:=privado.avaliar_portao_conformidade(v_exec.id_competencia);
  update public.competencias set percentual_conformidade=coalesce((v_portao->>'percentual')::numeric,0) where id=v_exec.id_competencia;
  perform privado.registrar_evento_auditoria(v_exec.id_organizacao,'ResultadoRequisitoRegistrado','resultados_requisitos',v_id,null,jsonb_build_object('id_requisito',v_req.id,'resultado',p_resultado));
  return v_id;
end;$$;
create function public.registrar_resultado_requisito(p_id_execucao uuid,p_id_requisito uuid,p_resultado text,p_justificativa text default null,p_fundamento text default null,p_evidencias jsonb default '[]'::jsonb)
returns uuid language sql security invoker set search_path='' as $$select privado.registrar_resultado_requisito($1,$2,$3,$4,$5,$6)$$;
revoke all on function public.registrar_resultado_requisito(uuid,uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.registrar_resultado_requisito(uuid,uuid,text,text,text,jsonb) to authenticated;

-- Registro humano de apontamento do contratante no ciclo correto.
create or replace function privado.registrar_apontamento_contratante(p_id_ciclo uuid,p_descricao text,p_fundamento text default null,p_codigo text default null,p_severidade text default 'media',p_fonte_pagina integer default null,p_fonte_trecho text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.ciclos_diligencia%rowtype; v_id uuid;
begin
 select * into v from public.ciclos_diligencia where id=p_id_ciclo;
 if v.id is null then raise exception 'Ciclo não encontrado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_severidade not in ('baixa','media','alta','critica') then raise exception 'Severidade inválida.'; end if;
 insert into public.apontamentos_contratante(id_organizacao,id_contrato,id_competencia,id_ciclo,codigo,descricao,fundamento,severidade,fonte_pagina,fonte_trecho)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id,p_codigo,p_descricao,p_fundamento,p_severidade,p_fonte_pagina,p_fonte_trecho) returning id into v_id;
 update public.ciclos_diligencia set status='em_tratamento' where id=v.id and status='aberto';
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ApontamentoContratanteRegistrado','apontamentos_contratante',v_id,null,jsonb_build_object('id_ciclo',v.id));
 return v_id;
end;$$;
create function public.registrar_apontamento_contratante(p_id_ciclo uuid,p_descricao text,p_fundamento text default null,p_codigo text default null,p_severidade text default 'media',p_fonte_pagina integer default null,p_fonte_trecho text default null)
returns uuid language sql security invoker set search_path='' as $$select privado.registrar_apontamento_contratante($1,$2,$3,$4,$5,$6,$7)$$;
revoke all on function public.registrar_apontamento_contratante(uuid,text,text,text,text,integer,text) from public,anon;
grant execute on function public.registrar_apontamento_contratante(uuid,text,text,text,text,integer,text) to authenticated;

-- Contestação versionada e hash obrigatório.
create or replace function privado.criar_contestacao(p_id_apontamento uuid,p_texto text,p_fundamento text,p_evidencias jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.apontamentos_contratante%rowtype; v_ver int; v_id uuid; v_hash text; v_ev jsonb;
begin
 select * into v from public.apontamentos_contratante where id=p_id_apontamento;
 if v.id is null then raise exception 'Apontamento não encontrado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 select coalesce(max(versao),0)+1 into v_ver from public.contestacoes where id_apontamento=v.id;
 v_hash:=encode(extensions.digest(concat_ws('|',v.id::text,v_ver::text,p_texto,p_fundamento,coalesce(p_evidencias,'[]'::jsonb)::text),'sha256'),'hex');
 insert into public.contestacoes(id_organizacao,id_contrato,id_competencia,id_ciclo,id_apontamento,versao,texto,fundamento,status_aprovacao,criado_por,hash)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id_ciclo,v.id,v_ver,p_texto,p_fundamento,'pendente',auth.uid(),v_hash) returning id into v_id;
 for v_ev in select * from jsonb_array_elements(coalesce(p_evidencias,'[]'::jsonb)) loop
   insert into public.mapas_evidencias_contestacao(id_organizacao,id_contrato,id_competencia,id_contestacao,id_versao_documento,pagina,trecho,descricao,hash)
   values(v.id_organizacao,v.id_contrato,v.id_competencia,v_id,nullif(v_ev->>'id_versao_documento','')::uuid,nullif(v_ev->>'pagina','')::integer,v_ev->>'trecho',v_ev->>'descricao',v_ev->>'hash');
 end loop;
 update public.apontamentos_contratante set status='contestado' where id=v.id;
 return v_id;
end;$$;
create function public.criar_contestacao(p_id_apontamento uuid,p_texto text,p_fundamento text,p_evidencias jsonb default '[]'::jsonb)
returns uuid language sql security invoker set search_path='' as $$select privado.criar_contestacao($1,$2,$3,$4)$$;
revoke all on function public.criar_contestacao(uuid,text,text,jsonb) from public,anon;
grant execute on function public.criar_contestacao(uuid,text,text,jsonb) to authenticated;

-- Tarefa não pode ser concluída por UPDATE genérico.
drop policy if exists tarefas_diligencia_update on public.tarefas_diligencia;
create or replace function privado.atualizar_tarefa_diligencia(p_id_tarefa uuid,p_descricao text default null,p_responsavel uuid default null,p_prazo date default null)
returns void language plpgsql security definer set search_path='' as $$
declare v public.tarefas_diligencia%rowtype;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Tarefa não encontrada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Acesso negado.'; end if;
 if v.status in ('concluida','cancelada') then raise exception 'Tarefa encerrada não pode ser editada.'; end if;
 update public.tarefas_diligencia set descricao=coalesce(p_descricao,descricao),responsavel=coalesce(p_responsavel,responsavel),prazo=coalesce(p_prazo,prazo),status=case when status='pendente' then 'em_execucao' else status end where id=v.id;
end;$$;
create function public.atualizar_tarefa_diligencia(p_id_tarefa uuid,p_descricao text default null,p_responsavel uuid default null,p_prazo date default null)
returns void language sql security invoker set search_path='' as $$select privado.atualizar_tarefa_diligencia($1,$2,$3,$4)$$;
revoke all on function public.atualizar_tarefa_diligencia(uuid,text,uuid,date) from public,anon;
grant execute on function public.atualizar_tarefa_diligencia(uuid,text,uuid,date) to authenticated;

create or replace function privado.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v public.tarefas_diligencia%rowtype;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Tarefa não encontrada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
 if v.responsavel is not null and v.responsavel<>auth.uid() and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Usuário não é responsável pela tarefa.'; end if;
 if p_id_evidencia_versao_documento is null or not exists(select 1 from public.versoes_documento vd where vd.id=p_id_evidencia_versao_documento and vd.id_contrato=v.id_contrato) then raise exception 'Evidência válida é obrigatória.'; end if;
 update public.tarefas_diligencia set status='concluida',id_evidencia_versao_documento=p_id_evidencia_versao_documento where id=v.id;
 if v.id_apontamento is not null and not exists(select 1 from public.tarefas_diligencia td where td.id_apontamento=v.id_apontamento and td.id<>v.id and td.status not in ('concluida','cancelada')) then update public.apontamentos_contratante set status='resolvido' where id=v.id_apontamento and status in ('procedente','em_tratamento'); end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'TarefaDiligenciaConcluida','tarefas_diligencia',v.id,null,jsonb_build_object('id_evidencia',p_id_evidencia_versao_documento));
end;$$;
create function public.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language sql security invoker set search_path='' as $$select privado.concluir_tarefa_diligencia($1,$2)$$;
revoke all on function public.concluir_tarefa_diligencia(uuid,uuid) from public,anon;
grant execute on function public.concluir_tarefa_diligencia(uuid,uuid) to authenticated;

-- Busca de precedentes sem cruzar organização; marca outro contrato como informativo no consumidor.
create or replace function public.worker_buscar_precedentes(p_id_organizacao uuid,p_id_contratante uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 8)
returns table(id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,similaridade double precision,mesmo_contrato boolean)
language sql stable security definer set search_path='' as $$
 select p.id,p.id_contrato_origem,p.competencia_origem,p.problema,p.solucao,p.desfecho,(1-(p.embedding OPERATOR(extensions.<=>) p_embedding))::double precision,(p.id_contrato_origem=p_id_contrato)
 from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo' and p.embedding is not null
 order by p.embedding OPERATOR(extensions.<=>) p_embedding limit least(greatest(p_limite,1),20)
$$;
revoke all on function public.worker_buscar_precedentes(uuid,uuid,uuid,extensions.vector,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_precedentes(uuid,uuid,uuid,extensions.vector,integer) to service_role;

commit;
