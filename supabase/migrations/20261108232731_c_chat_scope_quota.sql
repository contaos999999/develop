begin;
-- Aditivo: nenhuma assinatura/policy/grant existente é alterado.
create function privado.copilot_versao_elegivel(p_versao uuid,p_org uuid,p_contrato uuid,p_data date)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.versoes_documento v join public.arquivos a on a.id=v.id_arquivo
 where v.id=p_versao and v.id_organizacao=p_org and v.id_contrato=p_contrato
 and a.id_organizacao=p_org and a.id_contrato=p_contrato and a.status_seguranca='aprovado'
 and exists(select 1 from public.processamentos_documento d where d.id_versao_documento=v.id and d.id_organizacao=p_org and d.id_contrato=p_contrato and d.etapa='documents' and d.status='concluido' and d.concluido_em is not null)
 and not exists(select 1 from public.processamentos_documento d where d.id_versao_documento=v.id and(d.id_organizacao<>p_org or d.id_contrato<>p_contrato or d.status<>'concluido'))
 and(not exists(select 1 from public.versoes_fontes_normativas n where n.id_arquivo=a.id)
 or exists(select 1 from public.versoes_fontes_normativas n join public.fontes_normativas f on f.id=n.id_fonte
 where n.id_arquivo=a.id and n.id_organizacao=p_org and f.id_organizacao=p_org and f.situacao='ativa' and n.aprovado_em is not null
 and(n.id_contrato=p_contrato or(n.id_contrato is null and exists(select 1 from public.aplicabilidades_fonte af where af.id_fonte_versao=n.id and af.id_organizacao=p_org and af.id_contrato=p_contrato and af.aplicavel and af.aprovado_em is not null)))
 and(n.inicio_vigencia is null or n.inicio_vigencia<=coalesce(p_data,current_date)) and(n.fim_vigencia is null or n.fim_vigencia>=coalesce(p_data,current_date)))));
$$;
revoke all on function privado.copilot_versao_elegivel(uuid,uuid,uuid,date) from public,anon,authenticated,service_role;

create function privado.copilot_precedente_elegivel(p_id uuid,p_org uuid,p_contratante uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.precedentes p join public.contratos c on c.id=p.id_contrato_origem
 where p.id=p_id and p.id_organizacao=p_org and p.id_contratante=p_contratante and c.id_organizacao=p_org and c.id_contratante=p_contratante and p.status='ativo'
 and(
 (p.fonte_tipo='versao_documento' and privado.copilot_versao_elegivel(p.fonte_id,p_org,p.id_contrato_origem,p.competencia_origem))
 or(p.fonte_tipo='fragmento_documento' and exists(select 1 from public.fragmentos_documento f where f.id=p.fonte_id and f.id_organizacao=p_org and f.id_contrato=p.id_contrato_origem and privado.copilot_versao_elegivel(f.id_versao_documento,p_org,p.id_contrato_origem,p.competencia_origem)))
 or(p.fonte_tipo in('historico','apontamento_historico','relatorio_historico') and exists(select 1 from public.relatorios_historicos_contratante r join public.arquivos a on a.id=r.id_arquivo
 where r.id_organizacao=p_org and r.id_contrato=p.id_contrato_origem and r.status_processamento='concluido' and a.id_organizacao=p_org and a.id_contrato=p.id_contrato_origem and a.status_seguranca='aprovado'
 and(r.id=p.fonte_id or exists(select 1 from public.apontamentos_historicos h where h.id=p.fonte_id and h.id_relatorio=r.id and h.id_organizacao=p_org and h.id_contrato=p.id_contrato_origem))))
 or(p.fonte_tipo='apontamento_contratante' and exists(select 1 from public.apontamentos_contratante ap join public.pareceres_contratante pc on pc.id_ciclo=ap.id_ciclo join public.arquivos a on a.id=pc.id_arquivo
 where ap.id=p.fonte_id and ap.id_organizacao=p_org and ap.id_contrato=p.id_contrato_origem and pc.id_organizacao=p_org and pc.id_contrato=p.id_contrato_origem and a.id_organizacao=p_org and a.id_contrato=p.id_contrato_origem and a.status_seguranca='aprovado'
 and exists(select 1 from public.versoes_documento vd where vd.id_arquivo=a.id and privado.copilot_versao_elegivel(vd.id,p_org,p.id_contrato_origem,p.competencia_origem))))));
$$;
revoke all on function privado.copilot_precedente_elegivel(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.worker_buscar_fragmentos_copiloto(p_id_organizacao uuid,p_id_contrato uuid,p_ids_fragmentos uuid[],p_embedding extensions.vector(384),p_data_referencia date,p_limite integer)
returns table(id uuid,id_versao_documento uuid,pagina_inicio integer,pagina_fim integer,texto text,similaridade double precision,fonte_temporal text,inicio_vigencia date,fim_vigencia date)
language plpgsql stable security definer set search_path='' as $$
begin
 if p_ids_fragmentos is null or cardinality(p_ids_fragmentos)>1000 or array_position(p_ids_fragmentos,null) is not null or cardinality(p_ids_fragmentos)<>(select count(distinct x) from unnest(p_ids_fragmentos)x) or p_limite is null or p_limite not between 1 and 30 or p_embedding is null then raise exception using errcode='22023',message='Conjunto de fontes inválido.';end if;
 return query with elegiveis as materialized(select f.* from public.fragmentos_documento f where f.id=any(p_ids_fragmentos) and f.id_organizacao=p_id_organizacao and f.id_contrato=p_id_contrato and f.embedding is not null and privado.copilot_versao_elegivel(f.id_versao_documento,p_id_organizacao,p_id_contrato,p_data_referencia))
 select f.id,f.id_versao_documento,f.pagina_inicio,f.pagina_fim,f.texto,(1-(f.embedding OPERATOR(extensions.<=>) p_embedding))::double precision,
 case when n.id is null then 'documento_contratual_ou_evidencia' else 'fonte_formal_vigente' end,n.inicio_vigencia,n.fim_vigencia
 from elegiveis f join public.versoes_documento vd on vd.id=f.id_versao_documento
 left join lateral(select v.id,v.inicio_vigencia,v.fim_vigencia from public.versoes_fontes_normativas v where v.id_arquivo=vd.id_arquivo and v.id_organizacao=p_id_organizacao and v.aprovado_em is not null and(v.id_contrato=p_id_contrato or exists(select 1 from public.aplicabilidades_fonte af where af.id_fonte_versao=v.id and af.id_contrato=p_id_contrato and af.id_organizacao=p_id_organizacao and af.aplicavel and af.aprovado_em is not null)) and(v.inicio_vigencia is null or v.inicio_vigencia<=coalesce(p_data_referencia,current_date)) and(v.fim_vigencia is null or v.fim_vigencia>=coalesce(p_data_referencia,current_date)) order by v.aprovado_em desc,v.id limit 1)n on true
 order by f.embedding OPERATOR(extensions.<=>) p_embedding,f.id limit p_limite;
end;$$;
revoke all on function public.worker_buscar_fragmentos_copiloto(uuid,uuid,uuid[],extensions.vector,date,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_fragmentos_copiloto(uuid,uuid,uuid[],extensions.vector,date,integer) to service_role;

create function public.worker_buscar_precedentes_copiloto(p_id_organizacao uuid,p_id_contratante uuid,p_id_contrato uuid,p_ids_precedentes uuid[],p_embedding extensions.vector(384),p_limite integer)
returns table(id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,escopo_resultado text,similaridade double precision,forca_score numeric,score_final numeric,confirmacoes integer,hierarquia_normativa integer,confianca numeric)
language plpgsql stable security definer set search_path='' as $$
begin
 if p_ids_precedentes is null or cardinality(p_ids_precedentes)>1000 or array_position(p_ids_precedentes,null) is not null or cardinality(p_ids_precedentes)<>(select count(distinct x) from unnest(p_ids_precedentes)x) or p_limite is null or p_limite not between 1 and 30 or p_embedding is null then raise exception using errcode='22023',message='Conjunto de precedentes inválido.';end if;
 if not exists(select 1 from public.contratos c where c.id=p_id_contrato and c.id_organizacao=p_id_organizacao and c.id_contratante=p_id_contratante) then raise exception using errcode='42501',message='Escopo não autorizado.';end if;
 return query with elegiveis as materialized(select p.* from public.precedentes p where p.id=any(p_ids_precedentes) and p.embedding is not null and privado.copilot_precedente_elegivel(p.id,p_id_organizacao,p_id_contratante)),base as(
 select p.*,(1-(p.embedding OPERATOR(extensions.<=>) p_embedding))::double precision sim,
 case when p.id_contrato_origem=p_id_contrato then 1.0 else 0.65 end escopo_peso,
 case when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '180 days' then 1.0 when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '365 days' then 0.8 when coalesce(p.ultima_confirmacao_em,p.criado_em)>=now()-interval '730 days' then 0.6 else 0.35 end recencia,
 least(1.0,ln(greatest(p.confirmacoes,1)+1)/ln(11)) confirm_peso,least(1.0,greatest(p.hierarquia_normativa,0)::numeric/10.0) hier_peso from elegiveis p),scored as(
 select b.*,round((greatest(0,b.sim)::numeric*0.55)+(b.escopo_peso::numeric*0.15)+(b.recencia::numeric*0.10)+(b.confirm_peso::numeric*0.08)+(b.hier_peso::numeric*0.06)+(coalesce(b.confianca,0.5)*0.06),4) final from base b)
 select s.id,s.id_contrato_origem,s.competencia_origem,s.problema,s.solucao,s.desfecho,case when s.id_contrato_origem=p_id_contrato then 'MESMO CONTRATO' else 'OUTRO CONTRATO DO MESMO CONTRATANTE' end,s.sim,coalesce(s.forca_score,s.final),s.final,s.confirmacoes,s.hierarquia_normativa,s.confianca from scored s order by(s.id_contrato_origem=p_id_contrato)desc,s.final desc,s.id limit p_limite;
end;$$;
revoke all on function public.worker_buscar_precedentes_copiloto(uuid,uuid,uuid,uuid[],extensions.vector,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_precedentes_copiloto(uuid,uuid,uuid,uuid[],extensions.vector,integer) to service_role;

-- Restaura claims mesmo em erro; não representa o Master por service_role.
create function privado.copilot_ator_permite(p_org uuid,p_contrato uuid,p_ator uuid,p_sessao uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_claims text:=current_setting('request.jwt.claims',true);v_sub text:=current_setting('request.jwt.claim.sub',true);v_ok boolean;
begin
 if p_ator is null or p_sessao is null then return false;end if;
 if not exists(select 1 from auth.users u join auth.sessions s on s.user_id=u.id where u.id=p_ator and s.id=p_sessao and(s.not_after is null or s.not_after>clock_timestamp()) and(u.banned_until is null or u.banned_until<=clock_timestamp())) then return false;end if;
 perform set_config('request.jwt.claim.sub',p_ator::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',p_ator,'session_id',p_sessao,'role','authenticated')::text,true);
 v_ok:=privado.rbac_permite(p_org,'contratos','consultar',p_contrato) and privado.rbac_permite(p_org,'arquivos','consultar',p_contrato);
 perform set_config('request.jwt.claim.sub',coalesce(v_sub,''),true);perform set_config('request.jwt.claims',coalesce(v_claims,''),true);
 return coalesce(v_ok,false);
exception when others then
 perform set_config('request.jwt.claim.sub',coalesce(v_sub,''),true);perform set_config('request.jwt.claims',coalesce(v_claims,''),true);raise;
end;$$;
revoke all on function privado.copilot_ator_permite(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.worker_reservar_consulta_copiloto(p_id_organizacao uuid,p_id_contrato uuid,p_id_usuario uuid,p_texto text,p_filtros jsonb,p_modelo text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_now timestamptz;v_id uuid;v_token uuid:=pg_catalog.gen_random_uuid();v_sessao uuid;v_min bigint;v_hora bigint;v_org bigint;v_ativas bigint;v_ativas_org bigint;
begin
 if p_id_organizacao is null or p_id_contrato is null or p_id_usuario is null or not exists(select 1 from public.contratos c where c.id=p_id_contrato and c.id_organizacao=p_id_organizacao) or p_filtros is null or jsonb_typeof(p_filtros)<>'object' or length(coalesce(p_texto,'')) not between 1 and 12000 or length(coalesce(p_modelo,''))>120 then raise exception using errcode='22023',message='Consulta inválida.';end if;
 v_sessao:=privado.uuid_seguro(p_filtros->>'session_id');
 if not privado.copilot_ator_permite(p_id_organizacao,p_id_contrato,p_id_usuario,v_sessao) then raise exception using errcode='42501',message='Sessão ou escopo não autorizado.';end if;
 perform pg_advisory_xact_lock(hashtextextended('copilot:org:'||p_id_organizacao::text,0));
 perform pg_advisory_xact_lock(hashtextextended('copilot:actor:'||p_id_usuario::text,0));
 v_now:=clock_timestamp();
 update public.consultas_semanticas q set status='falhou',filtros=jsonb_set(q.filtros,'{copilot,erro}',to_jsonb('LEASE_EXPIRADA'::text))
 where(q.id_organizacao=p_id_organizacao or q.criado_por=p_id_usuario) and q.status='processando' and q.filtros#>>'{copilot,namespace}'='c_chat_v1' and(q.filtros#>>'{copilot,expires_at}')::timestamptz<=v_now;
 select count(*)filter(where q.criado_em>v_now-interval '1 minute'),count(*) into v_min,v_hora from public.consultas_semanticas q where q.criado_por=p_id_usuario and q.criado_em>v_now-interval '1 hour';
 select count(*) into v_org from public.consultas_semanticas q where q.id_organizacao=p_id_organizacao and q.criado_em>v_now-interval '1 hour';
 if v_min>=6 or v_hora>=30 or v_org>=120 then return jsonb_build_object('autorizado',false,'codigo','COPILOTO_LIMITE_TAXA','retry_after',60);end if;
 select count(*)filter(where q.criado_por=p_id_usuario),count(*)filter(where q.id_organizacao=p_id_organizacao) into v_ativas,v_ativas_org from public.consultas_semanticas q where(q.criado_por=p_id_usuario or q.id_organizacao=p_id_organizacao) and q.status='processando' and q.filtros#>>'{copilot,namespace}'='c_chat_v1' and(q.filtros#>>'{copilot,expires_at}')::timestamptz>v_now;
 if v_ativas>=2 or v_ativas_org>=8 then return jsonb_build_object('autorizado',false,'codigo','COPILOTO_LIMITE_CONCORRENCIA','retry_after',90);end if;
 insert into public.consultas_semanticas(id_organizacao,id_contrato,escopo,texto_consulta,filtros,modelo,criado_por,status,criado_em)
 values(p_id_organizacao,p_id_contrato,'contrato',p_texto,(p_filtros-'copilot')||jsonb_build_object('copilot',jsonb_build_object('namespace','c_chat_v1','token_hash',encode(extensions.digest(v_token::text,'sha256'),'hex'),'session_id',v_sessao,'deadline_at',v_now+interval '45 seconds','expires_at',v_now+interval '90 seconds')),p_modelo,p_id_usuario,'processando',v_now) returning id into v_id;
 return jsonb_build_object('autorizado',true,'id_consulta',v_id,'token',v_token,'deadline_at',v_now+interval '45 seconds','expires_at',v_now+interval '90 seconds');
end;$$;
revoke all on function public.worker_reservar_consulta_copiloto(uuid,uuid,uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.worker_reservar_consulta_copiloto(uuid,uuid,uuid,text,jsonb,text) to service_role;

create function public.worker_falhar_consulta_copiloto(p_id_consulta uuid,p_token uuid,p_codigo text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v public.consultas_semanticas%rowtype;
begin
 if p_codigo is null or p_codigo not in('FALHA_RECUPERACAO','FALHA_PERSISTENCIA','PRAZO_ESGOTADO','FALHA_PROVEDOR') then raise exception using errcode='22023',message='Código de falha inválido.';end if;
 select * into v from public.consultas_semanticas q where q.id=p_id_consulta for update;
 if p_token is null or v.id is null or v.filtros#>>'{copilot,namespace}' is distinct from 'c_chat_v1' or v.filtros#>>'{copilot,token_hash}' is distinct from encode(extensions.digest(p_token::text,'sha256'),'hex') or v.status<>'processando' then raise exception using errcode='PT409',message='Reserva não disponível.';end if;
 update public.consultas_semanticas set status='falhou',filtros=jsonb_set(filtros,'{copilot,erro}',to_jsonb(p_codigo)) where id=v.id;
 return true;
end;$$;
revoke all on function public.worker_falhar_consulta_copiloto(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.worker_falhar_consulta_copiloto(uuid,uuid,text) to service_role;

-- Verifica antes de I/O; nunca renova nem estende o deadline absoluto.
create function public.worker_validar_lease_copiloto(p_id_consulta uuid,p_token uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v public.consultas_semanticas%rowtype;
begin
 select * into v from public.consultas_semanticas q where q.id=p_id_consulta;
 return coalesce(v.id is not null and v.status='processando' and v.filtros#>>'{copilot,namespace}'='c_chat_v1' and v.filtros#>>'{copilot,token_hash}'=encode(extensions.digest(p_token::text,'sha256'),'hex') and(v.filtros#>>'{copilot,deadline_at}')::timestamptz>clock_timestamp() and(v.filtros#>>'{copilot,expires_at}')::timestamptz>clock_timestamp()
 and privado.copilot_ator_permite(v.id_organizacao,v.id_contrato,v.criado_por,privado.uuid_seguro(v.filtros#>>'{copilot,session_id}')),false);
end;$$;
revoke all on function public.worker_validar_lease_copiloto(uuid,uuid) from public,anon,authenticated;
grant execute on function public.worker_validar_lease_copiloto(uuid,uuid) to service_role;

create function public.worker_concluir_consulta_copiloto(p_id_consulta uuid,p_token uuid,p_id_sessao uuid,p_retorno jsonb,p_fontes jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.consultas_semanticas%rowtype;v_s public.sessoes_copiloto%rowtype;v_f jsonb;v_fid uuid;v_vid uuid;v_msg uuid;v_ret uuid;v_hash text;v_contratante uuid;v_origem uuid;v_data date;
begin
 if p_retorno is null or jsonb_typeof(p_retorno)<>'object' or p_fontes is null or jsonb_typeof(p_fontes)<>'array' or jsonb_array_length(p_fontes)>18 or length(coalesce(p_retorno->>'conteudo','')) not between 1 and 12000 or coalesce(p_retorno->>'provedor','') not in('openai','supabase') then raise exception using errcode='22023',message='Resposta inválida.';end if;
 select * into v from public.consultas_semanticas q where q.id=p_id_consulta for update;
 if p_token is null or v.id is null or v.filtros#>>'{copilot,namespace}' is distinct from 'c_chat_v1' or v.filtros#>>'{copilot,token_hash}' is distinct from encode(extensions.digest(p_token::text,'sha256'),'hex') then raise exception using errcode='PT409',message='Reserva não disponível.';end if;
 v_hash:=encode(extensions.digest(p_id_sessao::text||p_retorno::text||p_fontes::text,'sha256'),'hex');
 select * into v_s from public.sessoes_copiloto s where s.id=p_id_sessao and s.id_organizacao=v.id_organizacao and s.id_contrato=v.id_contrato and s.criado_por=v.criado_por and s.status='ativa' for update;
 if v_s.id is null then raise exception using errcode='42501',message='Conversa não autorizada.';end if;
 if not privado.copilot_ator_permite(v.id_organizacao,v.id_contrato,v.criado_por,privado.uuid_seguro(v.filtros#>>'{copilot,session_id}')) then raise exception using errcode='42501',message='Sessão não autorizada.';end if;
 if v.status='concluida' and v.filtros#>>'{copilot,result_hash}'=v_hash then return v.filtros#>'{copilot,result}';end if;
 if not public.worker_validar_lease_copiloto(v.id,p_token) then raise exception using errcode='PT409',message='Reserva expirada ou sessão não autorizada.';end if;
 v_data:=nullif(v.filtros->>'data_referencia','')::date;
 select c.id_contratante into v_contratante from public.contratos c where c.id=v.id_contrato and c.id_organizacao=v.id_organizacao;
 for v_f in select value from jsonb_array_elements(p_fontes) loop
  v_fid:=privado.uuid_seguro(v_f->>'fonte_id');v_vid:=privado.uuid_seguro(v_f->>'id_versao_documento');
  if v_fid is null or length(coalesce(v_f->>'trecho',''))>1200 then raise exception using errcode='22023',message='Fonte inválida.';end if;
  if v_f->>'fonte_tipo'='fragmento_documento' then
   if not(coalesce(v.filtros->'ids_fragmentos','[]'::jsonb) ? v_fid::text) or not exists(select 1 from public.fragmentos_documento f where f.id=v_fid and f.id_versao_documento=v_vid and f.id_organizacao=v.id_organizacao and f.id_contrato=v.id_contrato and privado.copilot_versao_elegivel(f.id_versao_documento,v.id_organizacao,v.id_contrato,v_data)) then raise exception using errcode='42501',message='Fonte documental não autorizada.';end if;
  elsif v_f->>'fonte_tipo'='precedente' then
   select p.id_contrato_origem into v_origem from public.precedentes p where p.id=v_fid and p.id_organizacao=v.id_organizacao and p.id_contratante=v_contratante;
   if not(coalesce(v.filtros->'ids_precedentes','[]'::jsonb) ? v_fid::text) or not privado.copilot_precedente_elegivel(v_fid,v.id_organizacao,v_contratante) or not privado.copilot_ator_permite(v.id_organizacao,v_origem,v.criado_por,privado.uuid_seguro(v.filtros#>>'{copilot,session_id}')) then raise exception using errcode='42501',message='Precedente não autorizado.';end if;
  else raise exception using errcode='22023',message='Tipo de fonte inválido.';end if;
 end loop;
 insert into public.retornos_modelo(id_organizacao,id_contrato,id_consulta,provedor,modelo,prompt_versao,resposta,uso_tokens,status,fontes)
 values(v.id_organizacao,v.id_contrato,v.id,p_retorno->>'provedor',left(p_retorno->>'modelo',120),left(p_retorno->>'prompt_versao',120),p_retorno-'provedor'-'modelo'-'prompt_versao','{}'::jsonb,'concluido',p_fontes) returning id into v_ret;
 insert into public.mensagens_copiloto(id_organizacao,id_contrato,id_sessao,papel,conteudo,id_consulta_semantica,id_retorno_modelo)
 values(v.id_organizacao,v.id_contrato,v_s.id,'assistente',p_retorno->>'conteudo',v.id,v_ret) returning id into v_msg;
 for v_f in select value from jsonb_array_elements(p_fontes) loop
  insert into public.fontes_resposta_copiloto(id_organizacao,id_contrato,id_mensagem,fonte_tipo,fonte_id,id_versao_documento,pagina,trecho,score,metadados)
  values(v.id_organizacao,v.id_contrato,v_msg,v_f->>'fonte_tipo',(v_f->>'fonte_id')::uuid,nullif(v_f->>'id_versao_documento','')::uuid,nullif(v_f->>'pagina','')::integer,v_f->>'trecho',nullif(v_f->>'score','')::numeric,coalesce(v_f->'metadados','{}'::jsonb));
 end loop;
 if (v.filtros#>>'{copilot,deadline_at}')::timestamptz<=clock_timestamp() then raise exception using errcode='PT409',message='Prazo da consulta esgotado.';end if;
 update public.consultas_semanticas set status='concluida',filtros=jsonb_set(jsonb_set(filtros,'{copilot,result_hash}',to_jsonb(v_hash)),'{copilot,result}',jsonb_build_object('id_mensagem',v_msg,'id_retorno',v_ret)) where id=v.id;
 return jsonb_build_object('id_mensagem',v_msg,'id_retorno',v_ret);
end;$$;
revoke all on function public.worker_concluir_consulta_copiloto(uuid,uuid,uuid,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.worker_concluir_consulta_copiloto(uuid,uuid,uuid,jsonb,jsonb) to service_role;
commit;
