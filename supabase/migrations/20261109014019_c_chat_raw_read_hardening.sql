-- GATE191: raw chat history is exposed only through the authorized, source-revalidating Edge DTO.
-- Preserve non-chat model returns and all applied migrations/policies/grants.
begin;
create function privado.copilot_retorno_e_chat(p_id_retorno uuid,p_id_consulta uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((
  select r.id_consulta is distinct from p_id_consulta
   or coalesce(r.prompt_versao in ('copiloto-temporal-pt-BR-v2','copiloto-openai-rag-v1','copiloto-temporal-pt-BR-v3-fenced','copiloto-openai-rag-v2-fenced'),false)
   or exists(select 1 from public.consultas_semanticas q where q.id=r.id_consulta and q.filtros#>>'{copilot,namespace}'='c_chat_v1')
   or exists(select 1 from public.mensagens_copiloto m where m.id_retorno_modelo=r.id or (r.id_consulta is not null and m.id_consulta_semantica=r.id_consulta))
  from public.retornos_modelo r where r.id=p_id_retorno
 ),true);
$$;
alter function privado.copilot_retorno_e_chat(uuid,uuid) owner to postgres;
revoke all on function privado.copilot_retorno_e_chat(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function privado.copilot_retorno_e_chat(uuid,uuid) to authenticated;
create policy copilot_raw_chat_select on public.retornos_modelo as restrictive for select to authenticated
 using (not privado.copilot_retorno_e_chat(id,id_consulta));
create policy copilot_raw_chat_select on public.mensagens_copiloto as restrictive for select to authenticated using (false);
create policy copilot_raw_chat_select on public.fontes_resposta_copiloto as restrictive for select to authenticated using (false);
commit;
