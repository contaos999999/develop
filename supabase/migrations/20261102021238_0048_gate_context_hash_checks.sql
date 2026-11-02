create or replace function privado.solicitar_analise_competencia(p_id_competencia uuid, p_tipo text default 'completa'::text)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v public.competencias%rowtype; v_exec uuid; v_snapshot jsonb; v_hash text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if p_tipo not in ('completa','reanálise','parcial') then raise exception 'O tipo de análise informado não é válido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite solicitar esta análise.'; end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then raise exception 'A situação atual desta competência não permite iniciar uma nova análise.'; end if;
  v_snapshot:=privado.snapshot_contexto_competencia(v.id);
  v_hash:=encode(extensions.digest(v_snapshot::text,'sha256'),'hex');
  insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,motor,versao_motor,prompt_versao,iniciada_por,iniciada_em,snapshot_entrada)
  values(v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente',v_hash,'contaos','4.1','analise-pt-BR-v4.1',auth.uid(),now(),v_snapshot) returning id into v_exec;
  update public.competencias set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end where id=v.id;
  perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'execucao_analise',v_exec,jsonb_build_object('entidade_tipo','execucao_analise','id_execucao',v_exec,'id_competencia',v.id),'analysis:'||v_exec::text);
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,jsonb_build_object('id_competencia',v.id,'tipo',p_tipo,'hash_entrada',v_hash,'versao_snapshot','4.1'));
  return v_exec;
end;
$$;

create or replace function privado.aprovar_apresentacao(p_id_competencia uuid, p_fundamento text default null::text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v public.competencias%rowtype; v_portao jsonb; v_exec uuid; v_exec_hash text; v_exec_tipo text; v_parecer uuid; v_aprov uuid; v_hash_atual text;
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
  select id,hash_entrada,tipo into v_exec,v_exec_hash,v_exec_tipo from public.execucoes_analise where id_competencia=v.id and status='concluida' order by concluida_em desc nulls last,criado_em desc limit 1;
  if v_exec is null or v_exec_tipo not in ('completa','reanálise') then raise exception 'Execute uma análise completa ou reanálise concluída antes de liberar a apresentação.'; end if;
  v_hash_atual:=privado.hash_contexto_competencia(v.id);
  if v_exec_hash is distinct from v_hash_atual then raise exception 'Os documentos ou dados da competência foram alterados após a análise. Execute nova análise completa antes de liberar a apresentação.'; end if;
  insert into public.aprovacoes(id_organizacao,id_contrato,id_competencia,tipo,status,aprovado_por,fundamento,hash_contexto,percentual_conformidade,id_execucao_analise)
  values(v.id_organizacao,v.id_contrato,v.id,'apresentacao','aprovada',auth.uid(),p_fundamento,v_hash_atual,100.00,v_exec) returning id into v_aprov;
  update public.competencias set situacao='pode_apresentar_contratante',percentual_conformidade=100.00,liberada_para_apresentacao_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'CompetenciaLiberadaParaApresentacao','competencias',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','pode_apresentar_contratante','id_aprovacao',v_aprov,'id_parecer',v_parecer,'hash_contexto',v_hash_atual));
  return jsonb_build_object('id_aprovacao',v_aprov,'situacao','pode_apresentar_contratante','percentual_conformidade',100.00,'id_parecer',v_parecer,'hash_contexto',v_hash_atual);
end;
$$;

create or replace function privado.registrar_apresentacao(p_id_competencia uuid, p_idempotency_key text, p_protocolo text default null::text, p_forma_apresentacao text default null::text, p_id_comprovante_arquivo uuid default null::uuid)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v public.competencias%rowtype; v_pacote uuid; v_num integer; v_hash text; v_apres uuid; v_exist uuid; v_hash_atual text; v_hash_aprovado text; v_hash_exec text;
begin
  if nullif(trim(p_idempotency_key),'') is null then raise exception 'idempotency_key obrigatório.'; end if;
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  select id into v_exist from public.apresentacoes_contratante where id_organizacao=v.id_organizacao and idempotency_key=p_idempotency_key;
  if v_exist is not null then return v_exist; end if;
  if v.situacao <> 'pode_apresentar_contratante' then raise exception 'Competência não liberada para apresentação.'; end if;
  v_hash_atual:=privado.hash_contexto_competencia(v.id);
  select a.hash_contexto into v_hash_aprovado from public.aprovacoes a where a.id_competencia=v.id and a.tipo='apresentacao' and a.status='aprovada' order by a.criado_em desc limit 1;
  if v_hash_aprovado is null then raise exception 'Aprovação humana ausente.'; end if;
  if v_hash_aprovado is distinct from v_hash_atual then raise exception 'Os documentos ou dados mudaram após a aprovação. Execute nova análise e nova aprovação antes de apresentar.'; end if;
  select e.hash_entrada into v_hash_exec from public.execucoes_analise e where e.id_competencia=v.id and e.status='concluida' and e.tipo in ('completa','reanálise') order by e.concluida_em desc nulls last,e.criado_em desc limit 1;
  if v_hash_exec is distinct from v_hash_atual then raise exception 'A análise concluída não corresponde mais aos documentos e dados atuais. Execute nova análise antes de apresentar.'; end if;
  select coalesce(max(numero),0)+1 into v_num from public.pacotes_competencia where id_competencia=v.id and tipo='apresentacao';
  select encode(extensions.digest(string_agg(x.hash,'|' order by x.id::text),'sha256'),'hex') into v_hash from (
    select vd.id,vd.hash from public.versoes_documento vd join public.documentos_competencia dc on dc.id=vd.id_documento_competencia where dc.id_competencia=v.id and dc.situacao='ativo'
    union all
    select pi.id,pi.hash from public.pareceres_internos pi where pi.id_competencia=v.id and pi.status='aprovado'
  ) x;
  v_hash:=coalesce(v_hash,encode(extensions.digest(v.id::text,'sha256'),'hex'));
  insert into public.pacotes_competencia(id_organizacao,id_contrato,id_competencia,numero,tipo,status,hash_pacote,criado_por,congelado_em)
  values(v.id_organizacao,v.id_contrato,v.id,v_num,'apresentacao','congelado',v_hash,auth.uid(),now()) returning id into v_pacote;
  insert into public.itens_pacote_competencia(id_organizacao,id_contrato,id_competencia,id_pacote,entidade_tipo,entidade_id,versao_id,hash,ordem)
  select v.id_organizacao,v.id_contrato,v.id,v_pacote,'documento_competencia',dc.id,vd.id,vd.hash,row_number() over(order by dc.tipo,dc.id)
  from public.documentos_competencia dc join lateral (select * from public.versoes_documento x where x.id_documento_competencia=dc.id order by numero_versao desc limit 1) vd on true
  where dc.id_competencia=v.id and dc.situacao='ativo';
  insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,id_pacote,numero_rodada,tipo,protocolo,forma_apresentacao,id_comprovante_arquivo,idempotency_key,apresentado_por)
  values(v.id_organizacao,v.id_contrato,v.id,v_pacote,1,'apresentacao',p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo,p_idempotency_key,auth.uid()) returning id into v_apres;
  update public.pacotes_competencia set status='apresentado' where id=v_pacote;
  update public.competencias set situacao='aguardando_contratante',versao_pacote_atual=v_num where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'ApresentacaoRegistrada','apresentacoes_contratante',v_apres,null,jsonb_build_object('id_competencia',v.id,'id_pacote',v_pacote,'protocolo',p_protocolo,'hash_contexto',v_hash_atual));
  return v_apres;
end;
$$;

create or replace function privado.liberar_reapresentacao(p_id_ciclo uuid, p_fundamento text default null::text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v public.ciclos_diligencia%rowtype; v_portao jsonb; v_aprov uuid; v_hash_atual text; v_exec uuid; v_exec_hash text; v_exec_tipo text;
begin
 select * into v from public.ciclos_diligencia where id=p_id_ciclo for update;
 if v.id is null then raise exception 'Ciclo não encontrado.'; end if;
 if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]) then raise exception 'Perfil sem permissão.'; end if;
 v_portao:=public.avaliar_portao_reapresentacao(v.id);
 if coalesce((v_portao->>'liberado')::boolean,false) is not true then raise exception 'A rodada não está 100%% tratada.'; end if;
 select id,hash_entrada,tipo into v_exec,v_exec_hash,v_exec_tipo from public.execucoes_analise where id_competencia=v.id_competencia and status='concluida' order by concluida_em desc nulls last,criado_em desc limit 1;
 if v_exec is null or v_exec_tipo not in ('completa','reanálise') then raise exception 'Execute uma reanálise completa da competência antes de liberar a reapresentação.'; end if;
 v_hash_atual:=privado.hash_contexto_competencia(v.id_competencia);
 if v_exec_hash is distinct from v_hash_atual then raise exception 'Os documentos ou dados foram alterados após a última análise. Execute nova reanálise completa antes de liberar a reapresentação.'; end if;
 insert into public.aprovacoes(id_organizacao,id_contrato,id_competencia,tipo,status,aprovado_por,fundamento,hash_contexto,id_execucao_analise)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,'reapresentacao','aprovada',auth.uid(),p_fundamento,v_hash_atual,v_exec) returning id into v_aprov;
 update public.ciclos_diligencia set status='pronto_reapresentar' where id=v.id;
 update public.competencias set situacao='pode_reapresentar_contratante',liberada_para_reapresentacao_em=now() where id=v.id_competencia;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'CompetenciaLiberadaParaReapresentacao','competencias',v.id_competencia,null,jsonb_build_object('id_ciclo',v.id,'id_aprovacao',v_aprov,'hash_contexto',v_hash_atual));
 return jsonb_build_object('id_aprovacao',v_aprov,'situacao','pode_reapresentar_contratante','hash_contexto',v_hash_atual);
end;
$$;

create or replace function privado.registrar_reapresentacao(p_id_ciclo uuid, p_idempotency_key text, p_protocolo text default null::text, p_forma_apresentacao text default null::text, p_id_comprovante_arquivo uuid default null::uuid)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v public.ciclos_diligencia%rowtype; v_comp public.competencias%rowtype; v_num int; v_hash text; v_pack_reap uuid; v_pack_comp uuid; v_apres uuid; v_exist uuid; v_hash_atual text; v_hash_aprovado text; v_hash_exec text;
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
 v_hash_atual:=privado.hash_contexto_competencia(v.id_competencia);
 select a.hash_contexto into v_hash_aprovado from public.aprovacoes a where a.id_competencia=v.id_competencia and a.tipo='reapresentacao' and a.status='aprovada' order by a.criado_em desc limit 1;
 select e.hash_entrada into v_hash_exec from public.execucoes_analise e where e.id_competencia=v.id_competencia and e.status='concluida' and e.tipo in ('completa','reanálise') order by e.concluida_em desc nulls last,e.criado_em desc limit 1;
 if v_hash_aprovado is distinct from v_hash_atual or v_hash_exec is distinct from v_hash_atual then raise exception 'Os documentos ou dados mudaram após a liberação. Execute nova reanálise e nova aprovação antes de reapresentar.'; end if;
 select coalesce(max(numero),0)+1 into v_num from public.pacotes_reapresentacao where id_ciclo=v.id;
 select encode(extensions.digest(string_agg(z.h,'|' order by z.h),'sha256'),'hex') into v_hash from (
   select coalesce(hash,'') h from public.contestacoes where id_ciclo=v.id and status_aprovacao='aprovada'
   union all select coalesce(vd.hash,'') from public.tarefas_diligencia td join public.versoes_documento vd on vd.id=td.id_evidencia_versao_documento where td.id_ciclo=v.id and td.status='concluida'
 ) z;
 v_hash:=coalesce(v_hash,encode(extensions.digest(v.id::text,'sha256'),'hex'));
 insert into public.pacotes_reapresentacao(id_organizacao,id_contrato,id_competencia,id_ciclo,numero,hash,snapshot,criado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v.id,v_num,v_hash,jsonb_build_object('rodada',v.numero_rodada,'portao',public.avaliar_portao_reapresentacao(v.id),'hash_contexto',v_hash_atual),auth.uid()) returning id into v_pack_reap;
 insert into public.pacotes_competencia(id_organizacao,id_contrato,id_competencia,numero,tipo,status,hash_pacote,criado_por,congelado_em)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v_num,'reapresentacao','apresentado',v_hash,auth.uid(),now()) returning id into v_pack_comp;
 insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,id_pacote,numero_rodada,tipo,protocolo,forma_apresentacao,id_comprovante_arquivo,idempotency_key,apresentado_por)
 values(v.id_organizacao,v.id_contrato,v.id_competencia,v_pack_comp,v.numero_rodada+1,'reapresentacao',p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo,p_idempotency_key,auth.uid()) returning id into v_apres;
 update public.pacotes_reapresentacao set reapresentado_em=now() where id=v_pack_reap;
 update public.ciclos_diligencia set status='reapresentado' where id=v.id;
 update public.competencias set situacao='reapresentado' where id=v.id_competencia;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'ReapresentacaoRegistrada','apresentacoes_contratante',v_apres,null,jsonb_build_object('id_ciclo',v.id,'id_pacote_reapresentacao',v_pack_reap,'id_pacote_competencia',v_pack_comp,'hash_contexto',v_hash_atual));
 return v_apres;
end;
$$;

revoke all on function privado.solicitar_analise_competencia(uuid,text) from public,anon;
grant execute on function privado.solicitar_analise_competencia(uuid,text) to authenticated,service_role;
revoke all on function privado.aprovar_apresentacao(uuid,text) from public,anon;
grant execute on function privado.aprovar_apresentacao(uuid,text) to authenticated,service_role;
revoke all on function privado.registrar_apresentacao(uuid,text,text,text,uuid) from public,anon;
grant execute on function privado.registrar_apresentacao(uuid,text,text,text,uuid) to authenticated,service_role;
revoke all on function privado.liberar_reapresentacao(uuid,text) from public,anon;
grant execute on function privado.liberar_reapresentacao(uuid,text) to authenticated,service_role;
revoke all on function privado.registrar_reapresentacao(uuid,text,text,text,uuid) from public,anon;
grant execute on function privado.registrar_reapresentacao(uuid,text,text,text,uuid) to authenticated,service_role;
