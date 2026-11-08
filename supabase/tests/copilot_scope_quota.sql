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
create temp table c_ids(k text primary key,id uuid default gen_random_uuid());
insert into c_ids(k) values('org'),('orgb'),('contractor'),('contractorb'),('contract'),('contractb'),('session'),('file'),('doc'),('version'),('fragment'),('precedent');
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
 f:=jsonb_build_object('session_id','c7171717-0000-4000-9000-000000000001','ids_fragmentos',jsonb_build_array(frag::text),'ids_precedentes','[]'::jsonb);
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
 ret:=public.worker_concluir_consulta_copiloto((r->>'id_consulta')::uuid,(r->>'token')::uuid,sid,'{"provedor":"supabase","conteudo":"Resumo informativo"}',jsonb_build_array(jsonb_build_object('fonte_tipo','fragmento_documento','fonte_id',frag,'id_versao_documento',ver,'pagina',1,'trecho','Evidência segura','score',0.8)));
 perform pg_temp.assert_c(ret=public.worker_concluir_consulta_copiloto((r->>'id_consulta')::uuid,(r->>'token')::uuid,sid,'{"provedor":"supabase","conteudo":"Resumo informativo"}',jsonb_build_array(jsonb_build_object('fonte_tipo','fragmento_documento','fonte_id',frag,'id_versao_documento',ver,'pagina',1,'trecho','Evidência segura','score',0.8))),'exact replay idempotent');
 perform pg_temp.assert_c((select count(*)=1 from public.mensagens_copiloto where id_consulta_semantica=(r->>'id_consulta')::uuid),'one assistant after replay');
 for i in 3..6 loop r:=public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Taxa'||i,f,'fixture');perform pg_temp.assert_c((r->>'autorizado')::boolean,'six rate reservations');perform public.worker_falhar_consulta_copiloto((r->>'id_consulta')::uuid,(r->>'token')::uuid,'FALHA_PROVEDOR');end loop;
 perform pg_temp.assert_c(public.worker_reservar_consulta_copiloto(org,ct,'c7171717-0000-4000-8000-000000000001','Taxa7',f,'fixture')->>'codigo'='COPILOTO_LIMITE_TAXA','seventh finalized request denied');
end$$;
rollback;
select 'COPILOT_SCOPE_QUOTA_SQL_PASS';
