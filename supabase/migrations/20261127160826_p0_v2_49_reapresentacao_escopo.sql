begin;

create or replace function privado.registrar_reapresentacao(p_id_ciclo uuid, p_idempotency_key text, p_protocolo text default null::text, p_forma_apresentacao text default null::text, p_id_comprovante_arquivo uuid default null::uuid)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v public.ciclos_diligencia%rowtype; v_comp public.competencias%rowtype; v_num int; v_hash text; v_pack_reap uuid; v_pack_comp uuid; v_apres uuid; v_exist public.apresentacoes_contratante%rowtype; v_hash_atual text; v_hash_aprovado text; v_hash_exec text;
begin
 if auth.uid() is null or not privado.sessao_usuario_ativa() then
   raise exception using errcode='42501',message='Sua sessão não está ativa.';
 end if;
 if p_idempotency_key is null or length(btrim(p_idempotency_key)) not between 1 and 200 then
   raise exception using errcode='PT400',message='Informe uma chave de reapresentação válida.';
 end if;
 select * into v from public.ciclos_diligencia where id=p_id_ciclo for update;
 if v.id is null then raise exception 'Ciclo não encontrado.'; end if;
 select * into v_comp from public.competencias where id=v.id_competencia for update;
 if v_comp.id is null or (v_comp.id_organizacao,v_comp.id_contrato) is distinct from (v.id_organizacao,v.id_contrato)
    or not privado.usuario_tem_acesso_contrato(v.id_contrato)
    or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]) then
   raise exception using errcode='42501',message='Você não possui acesso à reapresentação desta rodada.';
 end if;

 -- A chave já é única na organização. Serialize sua resolução mesmo entre ciclos.
 perform pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended(v.id_organizacao::text || ':reapresentacao:' || p_idempotency_key,0)
 );
 select * into v_exist from public.apresentacoes_contratante
   where id_organizacao=v.id_organizacao and idempotency_key=p_idempotency_key;
 if found then
   if (v_exist.id_contrato,v_exist.id_competencia,v_exist.numero_rodada,
       v_exist.tipo,v_exist.apresentado_por,v_exist.protocolo,v_exist.forma_apresentacao,v_exist.id_comprovante_arquivo)
      is distinct from (v.id_contrato,v.id_competencia,v.numero_rodada+1,
       'reapresentacao'::text,auth.uid(),p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo)
      or not exists (
        select 1 from public.eventos_auditoria e
        where e.id_organizacao=v.id_organizacao and e.evento='ReapresentacaoRegistrada'
          and e.entidade='apresentacoes_contratante' and e.id_entidade=v_exist.id
          and e.depois->>'id_ciclo'=v.id::text
      ) then
     raise exception using errcode='PT409',message='A chave informada pertence a outra intenção de reapresentação.';
   end if;
   return v_exist.id;
 end if;
 if v.status<>'pronto_reapresentar' or v_comp.situacao<>'pode_reapresentar_contratante'
    or coalesce((public.avaliar_portao_reapresentacao(v.id)->>'liberado')::boolean,false) is not true then
   raise exception using errcode='PT409',message='A reapresentação desta rodada não está liberada.';
 end if;
 if p_id_comprovante_arquivo is not null then
   perform 1 from public.arquivos a
   where a.id=p_id_comprovante_arquivo and a.id_organizacao=v.id_organizacao
     and a.id_contrato=v.id_contrato and a.status_seguranca='aprovado'
   for share of a;
   if not found then
     raise exception using errcode='42501',message='O comprovante não está autorizado para este contrato.';
   end if;
 end if;
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

commit;
