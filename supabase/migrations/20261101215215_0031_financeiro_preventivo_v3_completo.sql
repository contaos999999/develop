begin;

alter table public.contratos add column if not exists configuracao_financeira jsonb not null default '{"contas_bancarias_permitidas":[],"limiar_alerta_baixo":0,"limiar_alerta_agrupamento":3,"janela_duplicidade_dias":7,"percentual_similaridade_descricao":0.80,"documentos_futuros_padrao":["nota fiscal","comprovante de pagamento","contrato/ordem de serviço","certidões quando aplicável"]}'::jsonb;
alter table public.transacoes_financeiras add column if not exists id_linha_orcamentaria uuid references public.linhas_orcamentarias(id) on delete restrict;
alter table public.transacoes_financeiras add column if not exists conta_bancaria text;
alter table public.transacoes_financeiras add column if not exists status_fluxo text not null default 'registrada' check(status_fluxo in ('prevista','em_aprovacao','registrada','paga','conciliada','cancelada'));
alter table public.transacoes_financeiras add column if not exists pre_validada boolean not null default false;
alter table public.transacoes_financeiras add column if not exists pre_validada_em timestamptz;

alter table public.regras_preventivas add column if not exists configuracao jsonb not null default '{}'::jsonb;

alter table public.alertas_preventivos add column if not exists codigo_regra text;
alter table public.alertas_preventivos add column if not exists grupo_chave text;
alter table public.alertas_preventivos add column if not exists impacto_financeiro numeric(18,2);
alter table public.alertas_preventivos add column if not exists responsavel uuid references auth.users(id) on delete set null;
alter table public.alertas_preventivos add column if not exists evidencias_futuras jsonb not null default '[]'::jsonb;
alter table public.alertas_preventivos add column if not exists origem_tipo text not null default 'transacao_financeira';
alter table public.alertas_preventivos add column if not exists origem_id uuid;
alter table public.alertas_preventivos add column if not exists idempotency_key text;
alter table public.alertas_preventivos add column if not exists limiar_agrupamento integer;
alter table public.alertas_preventivos add column if not exists quantidade_agrupada integer not null default 1;
create unique index if not exists alertas_preventivos_idempotency_uidx on public.alertas_preventivos(id_organizacao,idempotency_key) where idempotency_key is not null;
create index if not exists alertas_preventivos_grupo_idx on public.alertas_preventivos(id_contrato,grupo_chave,status,criado_em desc);

create or replace function privado.criar_alerta_preventivo(
 p_id_organizacao uuid,p_id_contrato uuid,p_id_transacao uuid,p_codigo_regra text,p_grupo_chave text,p_severidade text,p_descricao text,p_evidencia jsonb,p_impacto numeric,p_evidencias_futuras jsonb,p_idempotency_key text,p_responsavel uuid default null,p_limiar_agrupamento integer default 1
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_existente public.alertas_preventivos%rowtype; v_limiar integer:=greatest(coalesce(p_limiar_agrupamento,1),1);
begin
 if p_idempotency_key is not null then
   select * into v_existente from public.alertas_preventivos where id_organizacao=p_id_organizacao and idempotency_key=p_idempotency_key;
   if v_existente.id is not null then return v_existente.id; end if;
 end if;
 if v_limiar>1 then
   select * into v_existente from public.alertas_preventivos
   where id_contrato=p_id_contrato and grupo_chave=p_grupo_chave and status in ('aberto','em_tratamento') and criado_em>=now()-interval '30 days'
   order by criado_em desc limit 1 for update;
   if v_existente.id is not null then
     update public.alertas_preventivos set quantidade_agrupada=quantidade_agrupada+1,evidencia=coalesce(evidencia,'{}'::jsonb)||jsonb_build_object('ultima_ocorrencia',coalesce(p_evidencia,'{}'::jsonb)),impacto_financeiro=coalesce(impacto_financeiro,0)+coalesce(p_impacto,0) where id=v_existente.id;
     return v_existente.id;
   end if;
 end if;
 insert into public.alertas_preventivos(id_organizacao,id_contrato,id_transacao,regra,codigo_regra,grupo_chave,severidade,status,descricao,evidencia,impacto_financeiro,responsavel,evidencias_futuras,origem_tipo,origem_id,idempotency_key,limiar_agrupamento)
 values(p_id_organizacao,p_id_contrato,p_id_transacao,p_codigo_regra,p_codigo_regra,p_grupo_chave,p_severidade,'aberto',p_descricao,coalesce(p_evidencia,'{}'::jsonb),p_impacto,p_responsavel,coalesce(p_evidencias_futuras,'[]'::jsonb),'transacao_financeira',p_id_transacao,p_idempotency_key,v_limiar)
 returning id into v_id;
 perform privado.registrar_evento_auditoria(p_id_organizacao,'AlertaPreventivoCriado','alertas_preventivos',v_id,null,jsonb_build_object('codigo_regra',p_codigo_regra,'id_transacao',p_id_transacao,'severidade',p_severidade));
 return v_id;
end;$$;
revoke all on function privado.criar_alerta_preventivo(uuid,uuid,uuid,text,text,text,text,jsonb,numeric,jsonb,text,uuid,integer) from public,anon,authenticated;

create or replace function public.worker_validar_transacao_preventiva(p_id_transacao uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_t public.transacoes_financeiras%rowtype; v_c public.contratos%rowtype; v_forn public.fornecedores%rowtype; v_cf public.contratos_fornecedores%rowtype;
 v_linha public.linhas_orcamentarias%rowtype; v_consumido numeric:=0; v_saldo numeric:=null; v_cfg jsonb; v_alertas jsonb:='[]'::jsonb; v_id uuid;
 v_docs jsonb; v_limiar integer:=1; v_contas text[]; v_dup int:=0; v_prec int:=0; v_desc text; v_responsavel uuid;
begin
 select * into v_t from public.transacoes_financeiras where id=p_id_transacao for update;
 if v_t.id is null then raise exception 'Transação financeira não encontrada.'; end if;
 select * into v_c from public.contratos where id=v_t.id_contrato;
 v_cfg:=coalesce(v_c.configuracao_financeira,'{}'::jsonb);
 v_limiar:=greatest(coalesce((v_cfg->>'limiar_alerta_agrupamento')::int,1),1);
 v_docs:=coalesce(v_cfg->'documentos_futuros_padrao','["nota fiscal","comprovante de pagamento"]'::jsonb);
 select id_usuario into v_responsavel from public.vinculos_usuarios where id_organizacao=v_t.id_organizacao and ativo=true and perfil in ('financeiro','gestor_contrato','administrador') order by case perfil when 'financeiro' then 1 when 'gestor_contrato' then 2 else 3 end limit 1;

 -- V3-PREV-001: validação pré-pagamento/fechamento por regras preventivas e dados mínimos.
 if v_t.status_fluxo in ('prevista','em_aprovacao','registrada') then
   if v_t.valor=0 or nullif(trim(v_t.descricao),'') is null then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'PRE_PAGAMENTO_DADOS_INSUFICIENTES','pre_pagamento_dados','alta','A despesa ainda não possui dados suficientes para uma validação segura antes do pagamento.',jsonb_build_object('valor',v_t.valor,'descricao',v_t.descricao,'status_fluxo',v_t.status_fluxo),abs(v_t.valor),v_docs,'pre-dados:'||v_t.id::text,v_responsavel,v_limiar);
     v_alertas:=v_alertas||jsonb_build_array(v_id);
   end if;
 end if;

 -- V3-PREV-002: rubrica, saldo e remanejamento.
 if v_t.id_linha_orcamentaria is not null then
   select * into v_linha from public.linhas_orcamentarias where id=v_t.id_linha_orcamentaria and id_contrato=v_t.id_contrato;
   if v_linha.id is null then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'RUBRICA_INVALIDA','rubrica_invalida','critica','A rubrica informada não pertence ao orçamento vigente deste contrato.',jsonb_build_object('id_linha_orcamentaria',v_t.id_linha_orcamentaria),abs(v_t.valor),v_docs,'rubrica-invalida:'||v_t.id::text,v_responsavel,1); v_alertas:=v_alertas||jsonb_build_array(v_id);
   else
     select coalesce(sum(c.valor_apropriado),0) into v_consumido from public.consumo_orcamentario c where c.id_linha_orcamentaria=v_linha.id and c.id_transacao<>v_t.id;
     v_saldo:=v_linha.valor_total-v_consumido;
     if abs(v_t.valor)>v_saldo then
       v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'SALDO_ORCAMENTARIO_INSUFICIENTE','saldo:'||v_linha.id::text,'critica','A despesa ultrapassa o saldo disponível da rubrica.',jsonb_build_object('rubrica',v_linha.codigo,'valor_total',v_linha.valor_total,'consumido',v_consumido,'saldo_disponivel',v_saldo,'valor_transacao',abs(v_t.valor),'limite_remanejamento_percentual',v_linha.limite_remanejamento_percentual),greatest(abs(v_t.valor)-greatest(v_saldo,0),0),v_docs,'saldo:'||v_t.id::text,v_responsavel,1); v_alertas:=v_alertas||jsonb_build_array(v_id);
     end if;
   end if;
 elsif coalesce(v_t.dados_brutos->>'rubrica_codigo','')<>'' then
   select * into v_linha from public.linhas_orcamentarias where id_contrato=v_t.id_contrato and codigo=v_t.dados_brutos->>'rubrica_codigo' order by criado_em desc limit 1;
   if v_linha.id is null then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'RUBRICA_NAO_LOCALIZADA','rubrica_codigo:'||(v_t.dados_brutos->>'rubrica_codigo'),'alta','A rubrica informada na despesa não foi localizada no orçamento estruturado do contrato.',jsonb_build_object('rubrica_codigo',v_t.dados_brutos->>'rubrica_codigo'),abs(v_t.valor),v_docs,'rubrica-codigo:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
   end if;
 end if;

 -- V3-PREV-003: fornecedor e objeto.
 if v_t.id_fornecedor is not null then
   select * into v_forn from public.fornecedores where id=v_t.id_fornecedor;
   select * into v_cf from public.contratos_fornecedores where id_contrato=v_t.id_contrato and id_fornecedor=v_t.id_fornecedor and status='ativo' and (vigencia_inicio is null or vigencia_inicio<=v_t.data) and (vigencia_fim is null or vigencia_fim>=v_t.data) order by vigencia_inicio desc nulls last limit 1;
   if v_cf.id is null then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'FORNECEDOR_SEM_INSTRUMENTO_VIGENTE','fornecedor:'||v_t.id_fornecedor::text,'alta','Não foi localizado instrumento vigente do fornecedor para este contrato na data da despesa.',jsonb_build_object('fornecedor',v_forn.nome_razao_social,'data',v_t.data),abs(v_t.valor),v_docs,'fornecedor-instrumento:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
   elsif nullif(trim(coalesce(v_cf.objeto,'')),'') is not null and not (lower(v_t.descricao) % lower(v_cf.objeto)) then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'OBJETO_FORNECEDOR_DIVERGENTE','objeto_fornecedor:'||v_t.id_fornecedor::text,'media','A descrição da despesa apresenta baixa aderência textual ao objeto cadastrado do instrumento do fornecedor e precisa de revisão.',jsonb_build_object('descricao_despesa',v_t.descricao,'objeto_fornecedor',v_cf.objeto,'objeto_contrato_publico',v_c.objeto),abs(v_t.valor),v_docs,'objeto-fornecedor:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
   end if;
 end if;

 -- V3-PREV-004: duplicidade por fornecedor/documento/valor/data/similaridade.
 select count(*) into v_dup from public.transacoes_financeiras x
 where x.id_contrato=v_t.id_contrato and x.id<>v_t.id and x.status_fluxo<>'cancelada'
   and abs(x.valor-v_t.valor)<0.01
   and x.data between v_t.data-coalesce((v_cfg->>'janela_duplicidade_dias')::int,7) and v_t.data+coalesce((v_cfg->>'janela_duplicidade_dias')::int,7)
   and ( (v_t.id_fornecedor is not null and x.id_fornecedor=v_t.id_fornecedor) or (coalesce(v_t.fornecedor_documento_original,'')<>'' and x.fornecedor_documento_original=v_t.fornecedor_documento_original) )
   and (coalesce(v_t.documento,'')='' or x.documento=v_t.documento or lower(x.descricao) % lower(v_t.descricao));
 if v_dup>0 then
   v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'POSSIVEL_DUPLICIDADE','duplicidade:'||coalesce(v_t.id_fornecedor::text,v_t.fornecedor_documento_original,'sem_fornecedor')||':'||round(abs(v_t.valor),2)::text,'critica','Foi identificada outra movimentação com combinação semelhante de fornecedor, documento, valor e data.',jsonb_build_object('quantidade_semelhante',v_dup,'documento',v_t.documento,'valor',v_t.valor,'data',v_t.data),abs(v_t.valor),v_docs,'duplicidade:'||v_t.id::text,v_responsavel,1); v_alertas:=v_alertas||jsonb_build_array(v_id);
 end if;

 -- V3-PREV-005: conta bancária configurada.
 if jsonb_typeof(v_cfg->'contas_bancarias_permitidas')='array' and jsonb_array_length(v_cfg->'contas_bancarias_permitidas')>0 then
   v_contas:=array(select jsonb_array_elements_text(v_cfg->'contas_bancarias_permitidas'));
   if coalesce(v_t.conta_bancaria,v_t.dados_brutos->>'conta_bancaria',v_t.dados_brutos->>'conta','')='' then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'CONTA_BANCARIA_NAO_INFORMADA','conta_bancaria','alta','A conta bancária da movimentação não foi informada, embora o contrato possua contas permitidas configuradas.',jsonb_build_object('contas_permitidas',v_cfg->'contas_bancarias_permitidas'),abs(v_t.valor),v_docs,'conta-ausente:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
   elsif not (coalesce(v_t.conta_bancaria,v_t.dados_brutos->>'conta_bancaria',v_t.dados_brutos->>'conta')=any(v_contas)) then
     v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'CONTA_BANCARIA_INCOMPATIVEL','conta_bancaria:'||coalesce(v_t.conta_bancaria,v_t.dados_brutos->>'conta_bancaria',v_t.dados_brutos->>'conta'),'critica','A movimentação foi associada a uma conta bancária diferente das contas permitidas pelo contrato.',jsonb_build_object('conta_movimentacao',coalesce(v_t.conta_bancaria,v_t.dados_brutos->>'conta_bancaria',v_t.dados_brutos->>'conta'),'contas_permitidas',v_cfg->'contas_bancarias_permitidas'),abs(v_t.valor),v_docs,'conta-incompativel:'||v_t.id::text,v_responsavel,1); v_alertas:=v_alertas||jsonb_build_array(v_id);
   end if;
 end if;

 -- V3-PREV-006: precedentes históricos do mesmo contratante, com prioridade ao contrato atual.
 select count(*) into v_prec from public.precedentes p join public.contratos c0 on c0.id=v_t.id_contrato
 where p.id_organizacao=v_t.id_organizacao and p.id_contratante=c0.id_contratante and p.status='ativo'
   and (lower(v_t.descricao) % lower(p.problema) or (p.rubrica is not null and lower(coalesce(v_t.dados_brutos->>'rubrica',''))=lower(p.rubrica)))
   and coalesce(p.desfecho,'') not in ('aceita','favoravel','regular');
 if v_prec>0 then
   v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'PADRAO_HISTORICO_DE_RISCO','precedente_historico','alta','A movimentação apresenta padrão semelhante a apontamento histórico do mesmo contratante. O alerta é preventivo e exige revisão das fontes antes de qualquer conclusão.',jsonb_build_object('precedentes_encontrados',v_prec,'prioridade','próprio contrato antes do transversal'),abs(v_t.valor),v_docs,'precedente-financeiro:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
 end if;

 -- V3-PREV-007: evidências futuras.
 if jsonb_array_length(v_docs)>0 then
   v_id:=privado.criar_alerta_preventivo(v_t.id_organizacao,v_t.id_contrato,v_t.id,'EVIDENCIAS_FUTURAS','documentacao_futura:'||coalesce(v_t.id_fornecedor::text,'geral'),'baixa','Preserve os documentos indicados para facilitar a futura prestação de contas desta despesa.',jsonb_build_object('valor',v_t.valor,'data',v_t.data,'descricao',v_t.descricao),0,v_docs,'evidencias-futuras:'||v_t.id::text,v_responsavel,v_limiar); v_alertas:=v_alertas||jsonb_build_array(v_id);
 end if;

 update public.transacoes_financeiras set pre_validada=true,pre_validada_em=now() where id=v_t.id;
 return jsonb_build_object('id_transacao',v_t.id,'quantidade_alertas',jsonb_array_length(v_alertas),'alertas',v_alertas,'pre_validada',true);
end;$$;
revoke all on function public.worker_validar_transacao_preventiva(uuid) from public,anon,authenticated;
grant execute on function public.worker_validar_transacao_preventiva(uuid) to service_role;

create or replace function privado.enfileirar_validacao_preventiva_transacao()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status_fluxo<>'cancelada' then
   perform privado.enfileirar_job('finance_imports',new.id_organizacao,new.id_contrato,'validacao_preventiva',new.id,jsonb_build_object('entidade_tipo','validacao_preventiva','id_transacao',new.id),'preventiva:'||new.id::text||':'||new.hash_origem);
 end if;
 return new;
end;$$;
revoke all on function privado.enfileirar_validacao_preventiva_transacao() from public,anon,authenticated;
drop trigger if exists contaos_validacao_preventiva_transacao on public.transacoes_financeiras;
create trigger contaos_validacao_preventiva_transacao after insert on public.transacoes_financeiras for each row execute function privado.enfileirar_validacao_preventiva_transacao();

create or replace function privado.atribuir_alerta_preventivo(p_id_alerta uuid,p_responsavel uuid,p_prazo date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.alertas_preventivos%rowtype; v_tarefa uuid;
begin
 select * into v from public.alertas_preventivos where id=p_id_alerta for update;
 if v.id is null then raise exception 'Não encontramos o alerta informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite atribuir este alerta.'; end if;
 if not exists(select 1 from public.vinculos_usuarios vu where vu.id_organizacao=v.id_organizacao and vu.id_usuario=p_responsavel and vu.ativo=true) then raise exception 'O responsável selecionado não possui vínculo ativo com esta organização.'; end if;
 update public.alertas_preventivos set responsavel=p_responsavel,status=case when status='aberto' then 'em_tratamento' else status end where id=v.id;
 insert into public.tarefas_alerta(id_organizacao,id_contrato,id_alerta,descricao,responsavel,prazo,status)
 values(v.id_organizacao,v.id_contrato,v.id,'Tratar alerta preventivo: '||v.descricao,p_responsavel,p_prazo,'pendente') returning id into v_tarefa;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AlertaPreventivoAtribuido','alertas_preventivos',v.id,null,jsonb_build_object('responsavel',p_responsavel,'id_tarefa',v_tarefa,'prazo',p_prazo));
 return v_tarefa;
end;$$;
create or replace function public.atribuir_alerta_preventivo(p_id_alerta uuid,p_responsavel uuid,p_prazo date default null)
returns uuid language sql security invoker set search_path='' as $$select privado.atribuir_alerta_preventivo($1,$2,$3)$$;
revoke all on function public.atribuir_alerta_preventivo(uuid,uuid,date) from public,anon;
grant execute on function public.atribuir_alerta_preventivo(uuid,uuid,date) to authenticated;

commit;
