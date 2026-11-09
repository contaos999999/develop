-- Restore local descartável somente. Claims SQL NÃO são prova JWT HML.
-- Reutiliza identidade sintética da suíte V117 anterior; nunca provisiona auth.users.
begin;
create function pg_temp.assert_c(v boolean,n text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'COPILOT_SQL_FAIL: %',n;end if;end$$;
create function pg_temp.deny_c(q text,s text) returns void language plpgsql as $$begin begin execute q;exception when others then if sqlstate=s then return;end if;raise exception 'Expected %, got %: %',s,sqlstate,sqlerrm;end;raise exception 'Expected denial %',s;end$$;
do $$begin
 if to_regprocedure('public.worker_reservar_consulta_copiloto(uuid,uuid,uuid,text,jsonb,text)') is null then raise exception 'COPILOT_SQL_RED_RESERVA_RPC_AUSENTE';end if;
 if to_regprocedure('public.worker_buscar_fragmentos_copiloto(uuid,uuid,uuid[],extensions.vector,date,integer)') is null then raise exception 'COPILOT_SQL_RED_FRAGMENTOS_RPC_AUSENTE';end if;
 if to_regprocedure('public.worker_buscar_precedentes_copiloto(uuid,uuid,uuid,uuid[],extensions.vector,integer)') is null then raise exception 'COPILOT_SQL_RED_PRECEDENTES_RPC_AUSENTE';end if;
end$$;
-- ACL/search_path nativos: nenhuma função privilegiada nova chega ao navegador.
do $$declare r record;begin
 for r in select p.oid,p.proname,p.prosecdef,p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('worker_reservar_consulta_copiloto','worker_buscar_fragmentos_copiloto','worker_buscar_precedentes_copiloto','worker_validar_lease_copiloto','worker_falhar_consulta_copiloto','worker_concluir_consulta_copiloto') loop
  perform pg_temp.assert_c(not has_function_privilege('anon',r.oid,'EXECUTE') and not has_function_privilege('authenticated',r.oid,'EXECUTE') and has_function_privilege('service_role',r.oid,'EXECUTE') and r.prosecdef,'service-only '||r.proname);
  perform pg_temp.assert_c(r.proconfig=array['search_path=""'],'empty search_path '||r.proname);
 end loop;
 perform pg_temp.assert_c((select count(*)=6 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('worker_reservar_consulta_copiloto','worker_buscar_fragmentos_copiloto','worker_buscar_precedentes_copiloto','worker_validar_lease_copiloto','worker_falhar_consulta_copiloto','worker_concluir_consulta_copiloto')),'six RPCs');
end$$;
create function pg_temp.probe_deny_c(q text,s text) returns boolean language plpgsql as $$begin begin execute q;raise exception using errcode='PZ999',message='Probe rollback';exception when others then return sqlstate=s;end;end$$;
create temp table c_failed(n text);
create temp table c_ids(k text primary key,id uuid default gen_random_uuid());
insert into c_ids(k) values('org'),('orgb'),('contractor'),('contractorb'),('contract'),('contractb'),('session'),('file'),('doc'),('version'),('fragment'),('precedent'),('fileb'),('docb'),('versionb'),('sessiond');
insert into public.organizacoes(id,razao_social)select id,'Copilot isolated '||k from c_ids where k in('org','orgb');
insert into public.contratantes(id,id_organizacao,razao_social)select id,(select id from c_ids where k=case when k0.k='contractor' then 'org' else 'orgb' end),'Copilot fixture' from c_ids k0 where k in('contractor','contractorb');
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio)select id,(select id from c_ids where k=case when c.k='contract' then 'org' else 'orgb' end),(select id from c_ids where k=case when c.k='contract' then 'contractor' else 'contractorb' end),'C-SQL-'||id,'Isolated','2026-01-01' from c_ids c where k in('contract','contractb');
insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)select id,'c7171717-0000-4000-8000-000000000001','administrador',true,true from c_ids where k='org';
insert into public.sessoes_copiloto(id,id_organizacao,id_contrato,status,criado_por)values((select id from c_ids where k='session'),(select id from c_ids where k='org'),(select id from c_ids where k='contract'),'ativa','c7171717-0000-4000-8000-000000000001');
insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,sha256,status_seguranca)values((select id from c_ids where k='file'),(select id from c_ids where k='org'),(select id from c_ids where k='contract'),'isolated/copilot','copilot.txt',repeat('a',64),'aprovado');
insert into public.documentos_contrato(id,id_organizacao,id_contrato,tipo,titulo)values((select id from c_ids where k='doc'),(select id from c_ids where k='org'),(select id from c_ids where k='contract'),'outros','Copilot isolated');
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash)values((select id from c_ids where k='version'),(select id from c_ids where k='org'),(select id from c_ids where k='contract'),(select id from c_ids where k='doc'),1,(select id from c_ids where k='file'),repeat('a',64));
insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status,concluido_em)values((select id from c_ids where k='org'),(select id from c_ids where k='contract'),(select id from c_ids where k='version'),'documents','concluido',clock_timestamp());
insert into public.fragmentos_documento(id,id_organizacao,id_contrato,id_versao_documento,pagina_inicio,pagina_fim,indice_fragmento,texto,embedding)values((select id from c_ids where k='fragment'),(select id from c_ids where k='org'),(select id from c_ids where k='contract'),(select id from c_ids where k='version'),1,1,1,'Evidência segura',(array_fill(1::real,array[384]))::extensions.vector);
insert into public.precedentes(id,id_organizacao,id_contratante,id_contrato_origem,problema,desfecho,fonte_tipo,fonte_id,embedding)values((select id from c_ids where k='precedent'),(select id from c_ids where k='org'),(select id from c_ids where k='contractor'),(select id from c_ids where k='contract'),'Fonte segura','aceita','versao_documento',(select id from c_ids where k='version'),(array_fill(1::real,array[384]))::extensions.vector);
insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)select id,'d7171717-0000-4000-8000-000000000001','administrador',true,true from c_ids where k='org';
insert into public.sessoes_copiloto(id,id_organizacao,id_contrato,status,criado_por)values((select id from c_ids where k='sessiond'),(select id from c_ids where k='org'),(select id from c_ids where k='contract'),'ativa','d7171717-0000-4000-8000-000000000001');
insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,sha256,status_seguranca)values((select id from c_ids where k='fileb'),(select id from c_ids where k='orgb'),(select id from c_ids where k='contractb'),'isolated/copilot-b','b.txt',repeat('b',64),'aprovado');
insert into public.documentos_contrato(id,id_organizacao,id_contrato,tipo,titulo)values((select id from c_ids where k='docb'),(select id from c_ids where k='orgb'),(select id from c_ids where k='contractb'),'outros','Foreign version');
insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash)values((select id from c_ids where k='versionb'),(select id from c_ids where k='orgb'),(select id from c_ids where k='contractb'),(select id from c_ids where k='docb'),1,(select id from c_ids where k='fileb'),repeat('b',64));
do $$declare org uuid;ct uuid;ver uuid;frag uuid;v extensions.vector;st text;f jsonb;r jsonb;r2 jsonb;ret jsonb;sid uuid;bad uuid:=gen_random_uuid();i int;begin
 select id into org from c_ids where k='org';select id into ct from c_ids where k='contract';select id into ver from c_ids where k='version';select id into frag from c_ids where k='fragment';select id into sid from c_ids where k='session';v:=(array_fill(1::real,array[384]))::extensions.vector;
 perform pg_temp.assert_c((select count(*)=1 from public.worker_buscar_fragmentos_copiloto(org,ct,array[frag],v,null,8)),'eligible source returned');
 perform pg_temp.assert_c((select count(*)=0 from public.worker_buscar_fragmentos_copiloto((select id from c_ids where k='orgb'),ct,array[frag],v,null,8)),'cross tenant denied before ranking');
 perform pg_temp.assert_c((select count(*)=0 from public.worker_buscar_fragmentos_copiloto(org,ct,array[]::uuid[],v,null,8)),'empty authorized IDs no fallback');
 perform pg_temp.deny_c(format('select * from public.worker_buscar_fragmentos_copiloto(%L,%L,array[%L,%L]::uuid[],%L::extensions.vector,null,8)',org,ct,frag,frag,v::text),'22023');
 foreach st in array array['pendente','quarentena','bloqueado'] loop
  update public.arquivos set status_seguranca=st where id=(select id from c_ids where k='file');
  perform pg_temp.assert_c((select count(*)=0 from public.worker_buscar_fragmentos_copiloto(org,ct,array[frag],v,null,8)),'unsafe file '||st);
 end loop;update public.arquivos set status_seguranca='aprovado' where id=(select id from c_ids where k='file');
 foreach st in array array['pendente','processando','falhou','cancelado'] loop
  update public.processamentos_documento set status=st where id_versao_documento=ver;
  perform pg_temp.assert_c((select count(*)=0 from public.worker_buscar_fragmentos_copiloto(org,ct,array[frag],v,null,8)),'incomplete processing '||st);
 end loop;update public.processamentos_documento set status='concluido' where id_versao_documento=ver;
 perform pg_temp.assert_c((select count(*)=1 from public.worker_buscar_precedentes_copiloto(org,(select id from c_ids where k='contractor'),ct,array[(select id from c_ids where k='precedent')],v,8)),'eligible precedent');
 f:=jsonb_build_object('session_id','c7171717-0000-4000-9000-000000000001','ids_fragmentos',jsonb_build_array(frag::text),'ids_precedentes',jsonb_build_array((select id::text from c_ids where k='precedent')));
 r:=public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Pergunta',f,'fixture');
 perform pg_temp.assert_c((r->>'autorizado')::boolean,'reservation succeeds');
 perform pg_temp.assert_c((select position(r->>'token' in q.filtros::text)=0 and not(q.filtros->'copilot' ? 'token') and length(q.filtros#>>'{copilot,token_hash}')=64 from public.consultas_semanticas q where q.id=(r->>'id_consulta')::uuid),'raw fencing token never stored in DataAPI-visible filters');
 perform pg_temp.assert_c(public.worker_validar_lease_copiloto((r->>'id_consulta')::uuid,(r->>'token')::uuid),'live lease');
 perform pg_temp.assert_c(not public.worker_validar_lease_copiloto((r->>'id_consulta')::uuid,bad),'wrong token denied');
 r2:=public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Pergunta2',f,'fixture');
 perform pg_temp.assert_c((r2->>'autorizado')::boolean,'second active reservation');
 perform pg_temp.assert_c(public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Pergunta3',f,'fixture')->>'codigo'='COPILOTO_LIMITE_CONCORRENCIA','third active denied');
 perform public.worker_falhar_consulta_copiloto((r2->>'id_consulta')::uuid,(r2->>'token')::uuid,'FALHA_PROVEDOR');
 perform pg_temp.deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',sid,'{"provedor":"supabase","conteudo":"Fonte inválida"}',jsonb_build_array(jsonb_build_object('fonte_tipo','fragmento_documento','fonte_id',bad,'id_versao_documento',ver))::text),'42501');
 -- Probes force subtransaction rollback even when the unsafe call succeeds.
 if not pg_temp.probe_deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',sid,'{"provedor":"supabase","conteudo":"Precedente A com versão B"}',jsonb_build_array(jsonb_build_object('fonte_tipo','precedente','fonte_id',(select id from c_ids where k='precedent'),'id_versao_documento',(select id from c_ids where k='versionb')))::text),'42501') then insert into c_failed values('PRECEDENTE_A_VERSAO_B_ACCEPTED');end if;
 perform set_config('request.jwt.claim.sub','c7171717-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"sub":"c7171717-0000-4000-8000-000000000001","role":"authenticated","session_id":"c7171717-0000-4000-9000-000000000001"}',true);
 perform pg_temp.assert_c(not privado.usuario_e_administrador_master(),'history revocation fixture is ordinary actor, never global Master');
 perform pg_temp.assert_c(privado.rbac_permite(org,'historico','consultar',ct),'canonical RBAC positive before revocation');
 update privado.rbac_permissoes_perfis set permitido=false where perfil='administrador' and recurso='historico' and acao='consultar';
 perform pg_temp.assert_c(not privado.rbac_permite(org,'historico','consultar',ct),'canonical RBAC confirms effective history revocation');
 perform pg_temp.assert_c(privado.copilot_ator_permite(org,ct,'c7171717-0000-4000-8000-000000000001','c7171717-0000-4000-9000-000000000001'),'actor A scope valid');
 perform pg_temp.assert_c(privado.copilot_ator_permite(org,ct,'d7171717-0000-4000-8000-000000000001','d7171717-0000-4000-9000-000000000001'),'following actor B scope valid');
 perform pg_temp.assert_c(not privado.copilot_ator_permite(org,ct,'d7171717-0000-4000-8000-000000000001','c7171717-0000-4000-9000-000000000001'),'B with A session denied');
 perform pg_temp.assert_c(not privado.copilot_ator_permite((select id from c_ids where k='orgb'),(select id from c_ids where k='contractb'),'d7171717-0000-4000-8000-000000000001','d7171717-0000-4000-9000-000000000001'),'B foreign scope denied after A');
 perform pg_temp.assert_c(current_setting('request.jwt.claim.sub',true)='c7171717-0000-4000-8000-000000000001' and(current_setting('request.jwt.claims',true)::jsonb)->>'sub'='c7171717-0000-4000-8000-000000000001','A to B calls preserve previous caller claims');

 if not pg_temp.probe_deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',sid,'{"provedor":"supabase","conteudo":"Histórico revogado"}',jsonb_build_array(jsonb_build_object('fonte_tipo','precedente','fonte_id',(select id from c_ids where k='precedent'),'id_versao_documento',null))::text),'42501') then insert into c_failed values('HISTORICO_PERMISSION_REVOCATION_ACCEPTED');end if;
 -- Authorization exceptions must restore an unrelated prior context and an empty context.
 perform set_config('request.jwt.claim.sub','d7171717-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"sub":"d7171717-0000-4000-8000-000000000001","session_id":"d7171717-0000-4000-9000-000000000001","role":"authenticated"}',true);
 perform pg_temp.deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',sid,'{"provedor":"supabase","conteudo":"Histórico revogado"}',jsonb_build_array(jsonb_build_object('fonte_tipo','precedente','fonte_id',(select id from c_ids where k='precedent'),'id_versao_documento',null))::text),'42501');
 perform pg_temp.assert_c(current_setting('request.jwt.claim.sub',true)='d7171717-0000-4000-8000-000000000001' and(current_setting('request.jwt.claims',true)::jsonb)->>'sub'='d7171717-0000-4000-8000-000000000001','exception restores unrelated previous caller');
 perform set_config('request.jwt.claim.sub','',true);perform set_config('request.jwt.claims','',true);
 perform pg_temp.deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',sid,'{"provedor":"supabase","conteudo":"Histórico revogado"}',jsonb_build_array(jsonb_build_object('fonte_tipo','precedente','fonte_id',(select id from c_ids where k='precedent'),'id_versao_documento',null))::text),'42501');
 perform pg_temp.assert_c(current_setting('request.jwt.claim.sub',true)='' and current_setting('request.jwt.claims',true)='','exception restores empty previous caller');
 update privado.rbac_permissoes_perfis set permitido=true where perfil='administrador' and recurso='historico' and acao='consultar';
 perform pg_temp.assert_c((select count(*)=0 from public.retornos_modelo where id_consulta=(r->>'id_consulta')::uuid) and(select count(*)=0 from public.mensagens_copiloto where id_consulta_semantica=(r->>'id_consulta')::uuid) and(select count(*)=0 from public.fontes_resposta_copiloto where id_organizacao=org),'negative finalization rolls back all three tables');
 perform pg_temp.deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',(select id from c_ids where k='sessiond'),'{"provedor":"supabase","conteudo":"Conversa de terceiro"}','[]'),'42501');
 perform pg_temp.deny_c(format('select public.worker_falhar_consulta_copiloto(%L,null,%L)',r->>'id_consulta','FALHA_PROVEDOR'),'PT409');
 perform pg_temp.deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',sid,'{"provedor":"supabase","conteudo":"FK documental inválida"}',jsonb_build_array(jsonb_build_object('fonte_tipo','fragmento_documento','fonte_id',frag,'id_versao_documento',bad))::text),'42501');
 ret:=public.worker_concluir_consulta_copiloto((r->>'id_consulta')::uuid,(r->>'token')::uuid,sid,'{"provedor":"supabase","conteudo":"Resumo informativo"}',jsonb_build_array(jsonb_build_object('fonte_tipo','fragmento_documento','fonte_id',frag,'id_versao_documento',ver,'pagina',1,'trecho','Evidência segura','score',0.8)));
 perform pg_temp.assert_c(ret=public.worker_concluir_consulta_copiloto((r->>'id_consulta')::uuid,(r->>'token')::uuid,sid,'{"provedor":"supabase","conteudo":"Resumo informativo"}',jsonb_build_array(jsonb_build_object('fonte_tipo','fragmento_documento','fonte_id',frag,'id_versao_documento',ver,'pagina',1,'trecho','Evidência segura','score',0.8))),'exact replay idempotent');
 perform pg_temp.deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',sid,'{"provedor":"supabase","conteudo":"Replay alterado"}','[]'),'PT409');
 update public.vinculos_usuarios set ativo=false where id_organizacao=org and id_usuario='c7171717-0000-4000-8000-000000000001';
 perform pg_temp.deny_c(format('select public.worker_concluir_consulta_copiloto(%L,%L,%L,%L::jsonb,%L::jsonb)',r->>'id_consulta',r->>'token',sid,'{"provedor":"supabase","conteudo":"Resumo informativo"}',jsonb_build_array(jsonb_build_object('fonte_tipo','fragmento_documento','fonte_id',frag,'id_versao_documento',ver,'pagina',1,'trecho','Evidência segura','score',0.8))::text),'42501');
 update public.vinculos_usuarios set ativo=true where id_organizacao=org and id_usuario='c7171717-0000-4000-8000-000000000001';
 perform pg_temp.assert_c((select count(*)=1 from public.mensagens_copiloto where id_consulta_semantica=(r->>'id_consulta')::uuid),'one assistant after replay');
 for i in 3..6 loop r:=public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Taxa'||i,f,'fixture');perform pg_temp.assert_c((r->>'autorizado')::boolean,'six rate reservations');perform public.worker_falhar_consulta_copiloto((r->>'id_consulta')::uuid,(r->>'token')::uuid,'FALHA_PROVEDOR');end loop;
 perform pg_temp.assert_c(public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Taxa7',f,'fixture')->>'codigo'='COPILOTO_LIMITE_TAXA','seventh finalized request denied');
 -- Controlled fixture timestamps isolate hourly quotas without waiting or changing policy.
 update public.consultas_semanticas set criado_em=clock_timestamp()-interval '2 hours' where id_organizacao=org;
 insert into public.consultas_semanticas(id_organizacao,id_contrato,escopo,texto_consulta,criado_por,status,criado_em)select org,ct,'contrato','actor-hour-fixture','c7171717-0000-4000-8000-000000000001','falhou',clock_timestamp()-interval '2 minutes' from generate_series(1,30);
 perform pg_temp.assert_c(public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Actor-hour31',f,'fixture')->>'codigo'='COPILOTO_LIMITE_TAXA','actor hourly30 independent of minute/concurrency');
 update public.consultas_semanticas set criado_em=clock_timestamp()-interval '2 hours' where id_organizacao=org;
 insert into public.consultas_semanticas(id_organizacao,id_contrato,escopo,texto_consulta,criado_por,status,criado_em)select org,ct,'contrato','tenant-hour-fixture',null,'falhou',clock_timestamp()-interval '2 minutes' from generate_series(1,120);
 perform pg_temp.assert_c(public.worker_reservar_consulta_copiloto(org,ct,'d7171717-0000-4000-8000-000000000001','Tenant-hour121',jsonb_build_object('session_id','d7171717-0000-4000-9000-000000000001'),'fixture')->>'codigo'='COPILOTO_LIMITE_TAXA','tenant hourly120 denies second authorized actor');
 update public.consultas_semanticas set criado_em=clock_timestamp()-interval '2 hours' where id_organizacao=org;
 r:=public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Tenant-active-A1',f,'fixture');
 r2:=public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Tenant-active-A2',f,'fixture');
 -- NULL actor is a valid retained orphan after auth FK ON DELETE SET NULL; lease stays occupied until expiry.
 insert into public.consultas_semanticas(id_organizacao,id_contrato,escopo,texto_consulta,criado_por,status,filtros)select org,ct,'contrato','tenant-orphan-fixture',null,'processando',jsonb_build_object('copilot',jsonb_build_object('namespace','c_chat_v1','expires_at',clock_timestamp()+interval '90 seconds','deadline_at',clock_timestamp()+interval '45 seconds','token_hash',repeat('a',64))) from generate_series(1,6);
 perform pg_temp.assert_c(public.worker_reservar_consulta_copiloto(org,ct,'d7171717-0000-4000-8000-000000000001','Tenant-active9',jsonb_build_object('session_id','d7171717-0000-4000-9000-000000000001'),'fixture')->>'codigo'='COPILOTO_LIMITE_CONCORRENCIA','tenant eight active denies second actor with zero own active');
 if exists(select 1 from c_failed) then raise exception 'COPILOT_SQL_SECURITY_REPRO: %',(select string_agg(n,',') from c_failed);end if;
end$$;
rollback;
select 'COPILOT_SCOPE_QUOTA_SQL_PASS';
