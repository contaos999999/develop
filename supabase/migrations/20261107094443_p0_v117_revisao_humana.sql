-- V1-17: human review is an append-only incremental reanalysis, never an overwrite.
begin;
create function privado.contexto_revisao_v117(p_id_competencia uuid,p_id_requisito uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.competencias%rowtype; e public.execucoes_analise%rowtype; ultimo uuid; h text; pode boolean;
begin
 -- Apply the existing RPC's effective RBAC plus its legacy write-profile boundary.
 select * into c from public.competencias where id=p_id_competencia;
 if c.id is null then raise exception using errcode='42501',message='Contexto de revisão indisponível.'; end if;
 perform privado.exigir_permissao_rbac(c.id_organizacao,'analises','consultar',c.id_contrato);
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(c.id_contrato)
  or not privado.usuario_possui_perfil(c.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade','financeiro','contabilidade','rh_dp'])
  or not exists(select 1 from public.requisitos_competencia r where r.id=p_id_requisito and r.id_competencia=c.id and r.id_organizacao=c.id_organizacao and r.id_contrato=c.id_contrato)
 then raise exception using errcode='42501',message='Contexto de revisão indisponível.'; end if;
 select * into e from public.execucoes_analise where id_competencia=c.id and id_organizacao=c.id_organizacao and id_contrato=c.id_contrato order by criado_em desc,id desc limit 1;
 select id into ultimo from public.resultados_requisitos where id_requisito=p_id_requisito and id_competencia=c.id and id_organizacao=c.id_organizacao and id_contrato=c.id_contrato order by criado_em desc,id desc limit 1;
 h:=privado.hash_contexto_competencia(c.id);
 pode:=privado.rbac_permite(c.id_organizacao,'analises','editar',c.id_contrato)
  and privado.usuario_possui_perfil(c.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade','financeiro','contabilidade','rh_dp'])
  and c.situacao in ('rascunho','em_analise','em_reanalise','pendente_correcao')
  and e.status='concluida' and e.tipo in ('completa','reanálise') and e.hash_entrada=h
  and exists(select 1 from public.organizacoes o join public.contratos ct on ct.id_organizacao=o.id where o.id=c.id_organizacao and ct.id=c.id_contrato and o.situacao='ativa' and ct.situacao in ('rascunho','ativo'))
  and not exists(select 1 from public.execucoes_analise x where x.id_competencia=c.id and x.status in ('pendente','processando'));
 return jsonb_build_object('schema_versao','revisao-v117','id_competencia',c.id,'id_requisito',p_id_requisito,'id_organizacao',c.id_organizacao,'id_contrato',c.id_contrato,'id_execucao_esperada',e.id,'id_resultado_esperado',ultimo,'hash_esperado',h,'pode_revisar',coalesce(pode,false));
end $$;
create function public.obter_contexto_revisao_v117(p_id_competencia uuid,p_id_requisito uuid)
returns jsonb language sql security invoker set search_path='' as $$select privado.contexto_revisao_v117($1,$2)$$;

create function privado.registrar_revisao_v117(p_id_competencia uuid,p_id_requisito uuid,p_id_execucao_esperada uuid,p_id_resultado_esperado uuid,p_hash_esperado text,p_resultado text,p_justificativa text,p_fundamento text,p_evidencias jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 c public.competencias%rowtype; ctx jsonb; antigo public.comandos_idempotentes%rowtype;
 fingerprint text; ev jsonb; documento public.versoes_documento%rowtype; arquivo public.arquivos%rowtype;
 exec_id uuid; res_id uuid; recibo jsonb; portao jsonb; instante timestamptz;
begin
 -- Authorization precedes both metadata validation and replay; no receipt leaks to revoked actors.
 ctx:=privado.contexto_revisao_v117(p_id_competencia,p_id_requisito);
 perform privado.exigir_permissao_rbac((ctx->>'id_organizacao')::uuid,'analises','editar',(ctx->>'id_contrato')::uuid);
 if not privado.usuario_possui_perfil((ctx->>'id_organizacao')::uuid,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade','financeiro','contabilidade','rh_dp']) then raise exception using errcode='42501',message='Seu perfil não permite revisar este requisito.'; end if;
 if p_request_id is null or p_id_execucao_esperada is null or p_hash_esperado is null or p_resultado is null or p_resultado not in ('pendente','em_analise','conforme','nao_conforme','inconclusivo','nao_aplicavel')
  or length(trim(coalesce(p_justificativa,''))) not between 3 and 2000 or length(coalesce(p_fundamento,''))>4000
  or jsonb_typeof(p_evidencias) is distinct from 'array' then raise exception using errcode='PT422',message='Informe resultado, justificativa, contexto e evidências válidos.'; end if;
 if jsonb_array_length(p_evidencias)>25 or octet_length(p_evidencias::text)>131072 then raise exception using errcode='PT422',message='Informe até 25 evidências, dentro do limite de tamanho.'; end if;
 if p_resultado='nao_aplicavel' and (nullif(trim(coalesce(p_fundamento,'')),'') is null or jsonb_array_length(p_evidencias)=0) then raise exception using errcode='PT422',message='Não aplicável exige fundamento e evidência.'; end if;
 perform 1 from public.organizacoes where id=(ctx->>'id_organizacao')::uuid for share;
 perform 1 from public.contratos where id=(ctx->>'id_contrato')::uuid and id_organizacao=(ctx->>'id_organizacao')::uuid for share;
 select * into c from public.competencias where id=p_id_competencia for update;
 perform pg_advisory_xact_lock(hashtextextended(c.id_organizacao::text||'revisao-v117'||p_request_id::text,0));
 ctx:=privado.contexto_revisao_v117(p_id_competencia,p_id_requisito);
 perform privado.exigir_permissao_rbac(c.id_organizacao,'analises','editar',c.id_contrato);
 if not privado.usuario_possui_perfil(c.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade','financeiro','contabilidade','rh_dp']) then raise exception using errcode='42501',message='A permissão de revisão foi revogada.'; end if;
 fingerprint:=encode(extensions.digest(jsonb_build_array(auth.uid(),p_id_competencia,p_id_requisito,p_id_execucao_esperada,p_id_resultado_esperado,p_hash_esperado,p_resultado,p_justificativa,p_fundamento,p_evidencias)::text,'sha256'),'hex');
 select * into antigo from public.comandos_idempotentes where id_organizacao=c.id_organizacao and comando='revisao-v117' and chave=p_request_id::text;
 if found then
  if antigo.hash_payload is distinct from fingerprint or antigo.status<>'concluido' then raise exception using errcode='PT409',message='Identificador já usado por outra solicitação.'; end if;
  return antigo.resposta;
 end if;
 if (ctx->>'id_execucao_esperada')::uuid is distinct from p_id_execucao_esperada or (ctx->>'id_resultado_esperado')::uuid is distinct from p_id_resultado_esperado
  or ctx->>'hash_esperado' is distinct from p_hash_esperado or not (ctx->>'pode_revisar')::boolean then
  raise exception using errcode='PT409',message='A análise ou o contexto foi alterado. Recarregue e revise antes de confirmar.';
 end if;
 -- Validate every evidence before any append. No external references or supplied hashes.
 for ev in select * from jsonb_array_elements(p_evidencias) loop
  if jsonb_typeof(ev) is distinct from 'object' then raise exception using errcode='PT422',message='Evidência inválida.'; end if;
  if exists(select 1 from jsonb_object_keys(ev) k where k not in ('id_versao_documento','pagina','trecho'))
   or jsonb_typeof(ev->'id_versao_documento') is distinct from 'string'
   or (ev ? 'pagina' and (jsonb_typeof(ev->'pagina') is distinct from 'number' or ev->>'pagina' !~ '^[1-9][0-9]{0,6}$'))
   or (ev ? 'trecho' and (jsonb_typeof(ev->'trecho') is distinct from 'string' or length(ev->>'trecho')>4000)) then raise exception using errcode='PT422',message='Campos da evidência inválidos.'; end if;
  select vd.* into documento from public.versoes_documento vd join public.documentos_competencia dc on dc.id=vd.id_documento_competencia
   where vd.id=(ev->>'id_versao_documento')::uuid and vd.id_organizacao=c.id_organizacao and vd.id_contrato=c.id_contrato and dc.id_competencia=c.id and dc.id_organizacao=c.id_organizacao and dc.id_contrato=c.id_contrato and dc.situacao='ativo' for share of vd,dc;
  if not found then raise exception using errcode='42501',message='Evidência indisponível nesta competência.'; end if;
  select * into arquivo from public.arquivos where id=documento.id_arquivo and id_organizacao=c.id_organizacao and id_contrato=c.id_contrato and status_seguranca='aprovado' for share;
  if not found then raise exception using errcode='42501',message='O arquivo da evidência não está aprovado neste contexto.'; end if;
 end loop;
 instante:=clock_timestamp();
 insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,motor,versao_motor,iniciada_por,iniciada_em,concluida_em,snapshot_entrada,metadados,criado_em)
 values(c.id_organizacao,c.id_contrato,c.id,'reanálise','concluida',p_hash_esperado,'revisao_humana','v117',auth.uid(),instante,instante,privado.snapshot_contexto_competencia(c.id),jsonb_build_object('origem','revisao_humana','id_execucao_anterior',p_id_execucao_esperada,'id_resultado_anterior',p_id_resultado_esperado,'requisitos',jsonb_build_array(p_id_requisito)),instante) returning id into exec_id;
 insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa,fundamento,metadados,criado_em)
 values(c.id_organizacao,c.id_contrato,c.id,exec_id,p_id_requisito,p_resultado,p_justificativa,p_fundamento,jsonb_build_object('origem','revisao_humana','revisor',auth.uid(),'id_resultado_anterior',p_id_resultado_esperado,'request_id',p_request_id),instante) returning id into res_id;
 for ev in select * from jsonb_array_elements(p_evidencias) loop
  insert into public.evidencias_resultado(id_organizacao,id_contrato,id_competencia,id_resultado,id_versao_documento,pagina,trecho,tipo_evidencia,hash)
  select c.id_organizacao,c.id_contrato,c.id,res_id,vd.id,(ev->>'pagina')::integer,ev->>'trecho','documento',a.sha256 from public.versoes_documento vd join public.arquivos a on a.id=vd.id_arquivo where vd.id=(ev->>'id_versao_documento')::uuid;
 end loop;
 -- Every material review invalidates the previous human opinion, preserving its content/history.
 update public.pareceres_internos set status='substituido' where id_competencia=c.id and status in ('rascunho','aprovado');
 perform privado.invalidar_portao_competencia(c.id,'Revisão humana do resultado.','resultados_requisitos',res_id);
 portao:=privado.avaliar_portao_conformidade(c.id);
 update public.competencias set percentual_conformidade=coalesce((portao->>'percentual')::numeric,0),liberada_para_apresentacao_em=null,liberada_para_reapresentacao_em=null where id=c.id;
 perform privado.registrar_evento_auditoria(c.id_organizacao,'RevisaoRequisitoRegistrada','resultados_requisitos',res_id,jsonb_build_object('id_execucao',p_id_execucao_esperada,'id_resultado',p_id_resultado_esperado),jsonb_build_object('id_execucao',exec_id,'id_requisito',p_id_requisito,'resultado',p_resultado,'request_id',p_request_id,'revisor',auth.uid()));
 recibo:=jsonb_build_object('schema_versao','revisao-v117','request_id',p_request_id,'id_competencia',c.id,'id_requisito',p_id_requisito,'id_execucao',exec_id,'id_resultado',res_id);
 insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,resposta) values(c.id_organizacao,'revisao-v117',p_request_id::text,fingerprint,'concluido',recibo);
 return recibo;
exception when deadlock_detected or lock_not_available then
 raise exception using errcode='PT409',message='O contexto está sendo alterado. Confira o andamento antes de tentar novamente.';
when invalid_text_representation or numeric_value_out_of_range then
 raise exception using errcode='PT422',message='Referência ou valor de evidência inválido.';
end $$;
create function public.registrar_revisao_requisito_v117(p_id_competencia uuid,p_id_requisito uuid,p_id_execucao_esperada uuid,p_id_resultado_esperado uuid,p_hash_esperado text,p_resultado text,p_justificativa text,p_fundamento text,p_evidencias jsonb,p_request_id uuid)
returns jsonb language sql security invoker set search_path='' as $$select privado.registrar_revisao_v117($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)$$;

-- Legacy signature is retained for compatibility, but cannot bypass CAS/idempotency.
create or replace function privado.registrar_resultado_requisito(p_id_execucao uuid,p_id_requisito uuid,p_resultado text,p_justificativa text default null,p_fundamento text default null,p_evidencias jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$begin
 raise exception using errcode='PT409',message='Use o fluxo de revisão com contexto e identificador da solicitação.';
end $$;
create function privado.proteger_revisao_v117() returns trigger language plpgsql set search_path='' as $$begin
 if current_user='authenticated' then raise exception using errcode='42501',message='Use a operação oficial de revisão de requisitos.'; end if;
 if tg_op='DELETE' then return old; end if; return new;
end $$;
create trigger proteger_revisao_v117 before insert or update or delete on public.resultados_requisitos for each row execute function privado.proteger_revisao_v117();
create trigger proteger_revisao_v117 before insert or update or delete on public.evidencias_resultado for each row execute function privado.proteger_revisao_v117();
revoke all on function privado.contexto_revisao_v117(uuid,uuid),privado.registrar_revisao_v117(uuid,uuid,uuid,uuid,text,text,text,text,jsonb,uuid),privado.proteger_revisao_v117() from public,anon,authenticated;
grant execute on function privado.contexto_revisao_v117(uuid,uuid),privado.registrar_revisao_v117(uuid,uuid,uuid,uuid,text,text,text,text,jsonb,uuid) to authenticated;
revoke all on function public.obter_contexto_revisao_v117(uuid,uuid),public.registrar_revisao_requisito_v117(uuid,uuid,uuid,uuid,text,text,text,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.obter_contexto_revisao_v117(uuid,uuid),public.registrar_revisao_requisito_v117(uuid,uuid,uuid,uuid,text,text,text,text,jsonb,uuid) to authenticated;
commit;
