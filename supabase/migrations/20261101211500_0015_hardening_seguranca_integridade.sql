begin;

-- Menor privilégio na Data API
revoke all privileges on all tables in schema public from anon;
revoke all privileges on all tables in schema public from authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;

-- Revoga execução implícita/anônima de funções expostas.
revoke execute on all functions in schema public from public, anon;
revoke execute on all functions in schema privado from public, anon, authenticated;

-- Helpers privados usados por RLS.
grant execute on function privado.usuario_tem_acesso_organizacao(uuid) to authenticated;
grant execute on function privado.usuario_tem_acesso_contrato(uuid) to authenticated;
grant execute on function privado.usuario_possui_perfil(uuid,text[]) to authenticated;

-- RPCs públicas permitidas apenas a usuários autenticados.
grant execute on function public.criar_organizacao(text,text,varchar,text) to authenticated;
grant execute on function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) to authenticated;
grant execute on function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) to authenticated;
grant execute on function public.criar_competencia(uuid,date,date,date,date) to authenticated;
grant execute on function public.solicitar_analise_competencia(uuid,text) to authenticated;
grant execute on function public.avaliar_portao_conformidade(uuid) to authenticated;
grant execute on function public.aprovar_apresentacao(uuid,text) to authenticated;
grant execute on function public.registrar_apresentacao(uuid,text,text,text,uuid) to authenticated;
grant execute on function public.promover_precedente_para_regra(uuid,text,text,text,text,text) to authenticated;
grant execute on function public.enfileirar_processamento_documento(uuid,text) to authenticated;
grant execute on function public.registrar_parecer_contratante(uuid,uuid,uuid,text,boolean,text,date,date) to authenticated;
grant execute on function public.avaliar_portao_reapresentacao(uuid) to authenticated;
grant execute on function public.aprovar_contestacao(uuid,boolean,text) to authenticated;
grant execute on function public.liberar_reapresentacao(uuid,text) to authenticated;
grant execute on function public.registrar_reapresentacao(uuid,text,text,text,uuid) to authenticated;
grant execute on function public.solicitar_importacao_financeira(uuid,uuid,text,text) to authenticated;
grant execute on function public.tratar_alerta_preventivo(uuid,text,text,uuid) to authenticated;
grant execute on function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) to authenticated;
grant execute on function public.publicar_controle(uuid,text,jsonb,date,date) to authenticated;
grant execute on function public.aprovar_excecao_controle(uuid,boolean) to authenticated;
grant execute on function public.encerrar_nao_conformidade(uuid,text) to authenticated;
grant execute on function public.publicar_regra_candidata(uuid,uuid,date,date) to authenticated;
grant execute on function public.criar_cliente_api(uuid,text,text[]) to authenticated;
grant execute on function public.rotacionar_cliente_api(uuid) to authenticated;
grant execute on function public.criar_webhook(uuid,text,text,text[]) to authenticated;
grant execute on function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) to authenticated;
grant execute on function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) to authenticated;
grant execute on function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) to authenticated;

-- rls_auto_enable é utilitário do ambiente, não endpoint de API.
do $$ begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public,anon,authenticated';
  end if;
end $$;

-- comandos idempotentes: leitura administrativa, mutação somente backend/RPC.
create policy comandos_idempotentes_select on public.comandos_idempotentes for select to authenticated
using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));

-- Imutabilidade física de históricos críticos.
create or replace function privado.bloquear_mutacao_historico()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Registro histórico imutável: % em %.%',tg_op,tg_table_schema,tg_table_name; end;$$;
revoke all on function privado.bloquear_mutacao_historico() from public,anon,authenticated;

create trigger eventos_auditoria_immutable before update or delete on public.eventos_auditoria for each row execute function privado.bloquear_mutacao_historico();
create trigger versoes_contrato_immutable before update or delete on public.versoes_contrato for each row execute function privado.bloquear_mutacao_historico();
create trigger versoes_documento_immutable before update or delete on public.versoes_documento for each row execute function privado.bloquear_mutacao_historico();
create trigger resultados_requisitos_immutable before update or delete on public.resultados_requisitos for each row execute function privado.bloquear_mutacao_historico();
create trigger evidencias_resultado_immutable before update or delete on public.evidencias_resultado for each row execute function privado.bloquear_mutacao_historico();
create trigger aprovacoes_immutable before update or delete on public.aprovacoes for each row execute function privado.bloquear_mutacao_historico();
create trigger itens_pacote_competencia_immutable before update or delete on public.itens_pacote_competencia for each row execute function privado.bloquear_mutacao_historico();
create trigger itens_pacote_evidencias_immutable before update or delete on public.itens_pacote_evidencias for each row execute function privado.bloquear_mutacao_historico();
create trigger exportacoes_evidencias_immutable before update or delete on public.exportacoes_evidencias for each row execute function privado.bloquear_mutacao_historico();

-- Perfil mínimo espelhado do Auth.
create or replace function privado.criar_usuario_auth()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.usuarios(id_usuario,nome,email)
  values(new.id,coalesce(new.raw_user_meta_data->>'nome',new.raw_user_meta_data->>'full_name'),new.email)
  on conflict(id_usuario) do nothing;
  return new;
end;$$;
revoke all on function privado.criar_usuario_auth() from public,anon,authenticated;
drop trigger if exists contaos_auth_user_created on auth.users;
create trigger contaos_auth_user_created after insert on auth.users for each row execute function privado.criar_usuario_auth();

-- Storage privado: path obrigatório org_uuid/...
insert into storage.buckets(id,name,public) values('contaos-documentos','contaos-documentos',false)
on conflict(id) do update set public=false;

drop policy if exists contaos_storage_select on storage.objects;
drop policy if exists contaos_storage_insert on storage.objects;
create policy contaos_storage_select on storage.objects for select to authenticated
using(bucket_id='contaos-documentos' and (storage.foldername(name))[1] is not null and privado.usuario_tem_acesso_organizacao(((storage.foldername(name))[1])::uuid));
create policy contaos_storage_insert on storage.objects for insert to authenticated
with check(bucket_id='contaos-documentos' and (storage.foldername(name))[1] is not null and privado.usuario_tem_acesso_organizacao(((storage.foldername(name))[1])::uuid));

-- Corrige reapresentação para manter pacote de diligência e pacote de competência distintos.
create or replace function public.registrar_reapresentacao(p_id_ciclo uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.ciclos_diligencia%rowtype; v_comp public.competencias%rowtype; v_num int; v_hash text; v_pack_reap uuid; v_pack_comp uuid; v_apres uuid; v_exist uuid;
begin
 if auth.uid() is null then raise exception 'Usuário não autenticado.'; end if;
 if nullif(trim(p_idempotency_key),'') is null then raise exception 'idempotency_key obrigatório.'; end if;
 select * into v from public.ciclos_diligencia where id=p_id_ciclo for update;
 if v.id is null then raise exception 'Ciclo não encontrado.'; end if;
 select * into v_comp from public.competencias where id=v.id_competencia for update;
 if not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]) then raise exception 'Acesso negado.'; end if;
 select id into v_exist from public.apresentacoes_contratante where id_organizacao=v.id_organizacao and idempotency_key=p_idempotency_key;
 if v_exist is not null then return v_exist; end if;
 if v.status<>'pronto_reapresentar' or v_comp.situacao<>'pode_reapresentar_contratante' then raise exception 'Reapresentação não liberada.'; end if;
 select coalesce(max(numero),0)+1 into v_num from public.pacotes_reapresentacao where id_ciclo=v.id;
 select encode(extensions.digest(string_agg(z.h,'|' order by z.h),'sha256'),'hex') into v_hash from (
   select coalesce(hash,'') h from public.contestacoes where id_ciclo=v.id and status_aprovacao='aprovada'
   union all select coalesce(vd.hash,'') from public.tarefas_diligencia td join public.versoes_documento vd on vd.id=td.id_evidencia_versao_documento where td.id_ciclo=v.id and td.status='concluida'
 ) z;
 v_hash:=coalesce(v_hash,encode(extensions.digest(v.id::text,'sha256'),'hex'));
 insert into public.pacotes_reapresentacao(id_organizacao,id_contrato,id_competencia,id_ciclo,numero,hash,snapshot,criado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id,v_num,v_hash,jsonb_build_object('rodada',v.numero_rodada,'portao',public.avaliar_portao_reapresentacao(v.id)),auth.uid()) returning id into v_pack_reap;
 insert into public.pacotes_competencia(id_organizacao,id_contrato,id_competencia,numero,tipo,status,hash_pacote,criado_por,congelado_em)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v_num,'reapresentacao','apresentado',v_hash,auth.uid(),now()) returning id into v_pack_comp;
 insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,id_pacote,numero_rodada,tipo,protocolo,forma_apresentacao,id_comprovante_arquivo,idempotency_key,apresentado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v_pack_comp,v.numero_rodada+1,'reapresentacao',p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo,p_idempotency_key,auth.uid()) returning id into v_apres;
 update public.pacotes_reapresentacao set reapresentado_em=now() where id=v_pack_reap;
 update public.ciclos_diligencia set status='reapresentado' where id=v.id;
 update public.competencias set situacao='reapresentado' where id=v.id_competencia;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ReapresentacaoRegistrada','apresentacoes_contratante',v_apres,null,jsonb_build_object('id_ciclo',v.id,'id_pacote_reapresentacao',v_pack_reap,'id_pacote_competencia',v_pack_comp));
 return v_apres;
end;$$;
revoke all on function public.registrar_reapresentacao(uuid,text,text,text,uuid) from public,anon;
grant execute on function public.registrar_reapresentacao(uuid,text,text,text,uuid) to authenticated;

-- Índices de FKs e filtros de RLS mais críticos.
create index if not exists vinculos_usuario_contratos_vinculo_idx on public.vinculos_usuario_contratos(id_vinculo_usuario,ativo);
create index if not exists requisitos_competencia_org_contrato_idx on public.requisitos_competencia(id_organizacao,id_contrato);
create index if not exists documentos_competencia_org_contrato_idx on public.documentos_competencia(id_organizacao,id_contrato,id_competencia);
create index if not exists eventos_auditoria_usuario_idx on public.eventos_auditoria(id_usuario,criado_em desc);
create index if not exists planos_remediacao_resp_idx on public.planos_remediacao(id_organizacao,responsavel,prazo,status);

commit;
