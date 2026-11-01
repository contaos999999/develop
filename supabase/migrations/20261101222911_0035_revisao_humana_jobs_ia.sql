begin;

create or replace function privado.revisar_solucao_tarefa_diligencia(p_id_tarefa uuid,p_aprovar boolean,p_fundamento text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.tarefas_diligencia%rowtype; v_abertas integer:=0;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Não encontramos a tarefa informada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso a este contrato.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite revisar a solução desta tarefa.'; end if;
 if v.status<>'concluida' or v.validacao_solucao<>'em_analise' then raise exception 'A tarefa precisa estar concluída e aguardando validação antes desta revisão.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento da revisão para manter a rastreabilidade.'; end if;
 update public.tarefas_diligencia set validacao_solucao=case when p_aprovar then 'aprovada' else 'rejeitada' end,status=case when p_aprovar then 'concluida' else 'em_execucao' end where id=v.id;
 if v.id_apontamento is not null then
   if p_aprovar then
     select count(*) into v_abertas from public.tarefas_diligencia t where t.id_apontamento=v.id_apontamento and t.id<>v.id and (t.status not in ('concluida','cancelada') or (t.status='concluida' and t.validacao_solucao<>'aprovada'));
     if v_abertas=0 then update public.apontamentos_contratante set status='resolvido' where id=v.id_apontamento and status in ('procedente','em_tratamento','em_analise'); end if;
   else
     update public.apontamentos_contratante set status='em_tratamento' where id=v.id_apontamento and status<>'encerrado';
   end if;
 end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'SolucaoTarefaDiligenciaRevisada','tarefas_diligencia',v.id,null,jsonb_build_object('aprovada',p_aprovar,'fundamento',p_fundamento,'revisor',auth.uid()));
 return jsonb_build_object('id_tarefa',v.id,'validacao_solucao',case when p_aprovar then 'aprovada' else 'rejeitada' end,'mensagem',case when p_aprovar then 'A solução foi validada e o fluxo foi atualizado.' else 'A solução foi devolvida para ajuste.' end);
end; $$;

create or replace function public.revisar_solucao_tarefa_diligencia(p_id_tarefa uuid,p_aprovar boolean,p_fundamento text)
returns jsonb language sql security invoker set search_path='' as $$ select privado.revisar_solucao_tarefa_diligencia($1,$2,$3); $$;
revoke all on function public.revisar_solucao_tarefa_diligencia(uuid,boolean,text) from public,anon;
grant execute on function public.revisar_solucao_tarefa_diligencia(uuid,boolean,text) to authenticated;

create or replace function public.worker_recalcular_inteligencia(p_id_contratante uuid)
returns jsonb language sql security definer set search_path='' as $$ select privado.recalcular_inteligencia_historica($1); $$;
revoke all on function public.worker_recalcular_inteligencia(uuid) from public,anon,authenticated;
grant execute on function public.worker_recalcular_inteligencia(uuid) to service_role;

commit;
