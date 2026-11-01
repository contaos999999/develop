begin;

create extension if not exists pg_trgm with schema extensions;

create table if not exists public.configuracoes_prevencao_financeira (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  id_contrato uuid not null references public.contratos(id) on delete cascade,
  conta_bancaria_esperada text,
  janela_duplicidade_dias integer not null default 7 check (janela_duplicidade_dias between 0 and 90),
  similaridade_duplicidade numeric(5,4) not null default 0.82 check (similaridade_duplicidade between 0 and 1),
  similaridade_objeto numeric(5,4) not null default 0.35 check (similaridade_objeto between 0 and 1),
  limiar_notificacao numeric(18,2) not null default 0,
  limite_alertas_por_grupo integer not null default 5 check (limite_alertas_por_grupo between 1 and 100),
  evidencias_futuras_padrao jsonb not null default '["nota fiscal ou documento equivalente","comprovante de pagamento","documento que demonstre o vínculo da despesa com o objeto contratual"]'::jsonb,
  ativo boolean not null default true,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique(id_contrato)
);
alter table public.configuracoes_prevencao_financeira enable row level security;
create policy configuracoes_prevencao_financeira_select on public.configuracoes_prevencao_financeira for select to authenticated using (privado.usuario_tem_acesso_contrato(id_contrato));
create policy configuracoes_prevencao_financeira_insert on public.configuracoes_prevencao_financeira for insert to authenticated with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy configuracoes_prevencao_financeira_update on public.configuracoes_prevencao_financeira for update to authenticated using (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create trigger configuracoes_prevencao_financeira_touch before update on public.configuracoes_prevencao_financeira for each row execute function privado.tocar_atualizado_em();
grant select,insert,update on public.configuracoes_prevencao_financeira to authenticated;
revoke delete,truncate,references,trigger on public.configuracoes_prevencao_financeira from authenticated, anon;

create unique index if not exists alertas_preventivos_idempotency_uidx on public.alertas_preventivos(id_organizacao,idempotency_key) where idempotency_key is not null;
create index if not exists alertas_preventivos_central_idx on public.alertas_preventivos(id_contrato,status,severidade,impacto_financeiro desc,criado_em desc);
create index if not exists transacoes_financeiras_dup_idx on public.transacoes_financeiras(id_contrato,id_fornecedor,documento,valor,data);

create or replace function privado.criar_ou_agrupar_alerta_preventivo(p_id_organizacao uuid,p_id_contrato uuid,p_id_transacao uuid,p_codigo_regra text,p_regra text,p_severidade text,p_descricao text,p_evidencia jsonb,p_impacto numeric,p_grupo_chave text,p_evidencias_futuras jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_limite integer := 5;
begin
  select coalesce(c.limite_alertas_por_grupo,5) into v_limite from public.configuracoes_prevencao_financeira c where c.id_contrato=p_id_contrato and c.ativo=true;
  select a.id into v_id from public.alertas_preventivos a where a.id_contrato=p_id_contrato and a.status in ('aberto','em_tratamento') and a.grupo_chave=p_grupo_chave and a.codigo_regra=p_codigo_regra and a.criado_em >= now() - interval '30 days' order by a.criado_em desc limit 1 for update;
  if v_id is not null then
    update public.alertas_preventivos set quantidade_agrupada=quantidade_agrupada+1,impacto_financeiro=coalesce(impacto_financeiro,0)+coalesce(p_impacto,0),evidencia=coalesce(evidencia,'{}'::jsonb)||jsonb_build_object('ultima_transacao',p_id_transacao,'ultima_ocorrencia_em',now()),evidencias_futuras=case when jsonb_array_length(coalesce(evidencias_futuras,'[]'::jsonb))=0 then coalesce(p_evidencias_futuras,'[]'::jsonb) else evidencias_futuras end where id=v_id;
    return v_id;
  end if;
  insert into public.alertas_preventivos(id_organizacao,id_contrato,id_transacao,regra,codigo_regra,severidade,status,descricao,evidencia,impacto_financeiro,grupo_chave,evidencias_futuras,origem_tipo,origem_id,idempotency_key,limiar_agrupamento)
  values(p_id_organizacao,p_id_contrato,p_id_transacao,p_regra,p_codigo_regra,p_severidade,'aberto',p_descricao,coalesce(p_evidencia,'{}'::jsonb),p_impacto,p_grupo_chave,coalesce(p_evidencias_futuras,'[]'::jsonb),'transacao_financeira',p_id_transacao,p_codigo_regra||':'||p_id_transacao::text,v_limite)
  on conflict (id_organizacao,idempotency_key) where idempotency_key is not null do update set evidencia=excluded.evidencia returning id into v_id;
  return v_id;
end; $$;
revoke all on function privado.criar_ou_agrupar_alerta_preventivo(uuid,uuid,uuid,text,text,text,text,jsonb,numeric,text,jsonb) from public,anon,authenticated;

create or replace function privado.validar_transacao_preventivamente(p_id_transacao uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.transacoes_financeiras%rowtype; v_cfg public.configuracoes_prevencao_financeira%rowtype; v_linha public.linhas_orcamentarias%rowtype; v_fornecedor public.fornecedores%rowtype; v_cf public.contratos_fornecedores%rowtype; v_contrato public.contratos%rowtype; v_consumido numeric:=0; v_saldo numeric:=null; v_dup_count integer:=0; v_prec_count integer:=0; v_ids uuid[]:=array[]::uuid[]; v_id uuid; v_sim numeric:=0; v_evidencias jsonb;
begin
  select * into v from public.transacoes_financeiras where id=p_id_transacao for update;
  if v.id is null then raise exception 'Não encontramos a transação informada.'; end if;
  if auth.uid() is not null and not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso a este contrato.'; end if;
  select * into v_contrato from public.contratos where id=v.id_contrato;
  select * into v_cfg from public.configuracoes_prevencao_financeira where id_contrato=v.id_contrato and ativo=true;
  if v_cfg.id is null then insert into public.configuracoes_prevencao_financeira(id_organizacao,id_contrato) values(v.id_organizacao,v.id_contrato) on conflict(id_contrato) do update set atualizado_em=public.configuracoes_prevencao_financeira.atualizado_em returning * into v_cfg; end if;
  v_evidencias:=v_cfg.evidencias_futuras_padrao;
  if v.id_linha_orcamentaria is null then
    v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-002','Rubrica e saldo','alta','A transação ainda não está vinculada a uma rubrica orçamentária válida.',jsonb_build_object('valor',v.valor),abs(v.valor),'rubrica:nao_vinculada',v_evidencias); v_ids:=array_append(v_ids,v_id);
  else
    select * into v_linha from public.linhas_orcamentarias where id=v.id_linha_orcamentaria and id_contrato=v.id_contrato;
    if v_linha.id is null then
      v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-002','Rubrica e saldo','critica','A rubrica informada não pertence ao contrato analisado.',jsonb_build_object('id_linha_orcamentaria',v.id_linha_orcamentaria),abs(v.valor),'rubrica:invalida',v_evidencias); v_ids:=array_append(v_ids,v_id);
    else
      select coalesce(sum(c.valor_apropriado),0) into v_consumido from public.consumo_orcamentario c where c.id_linha_orcamentaria=v_linha.id and c.id_transacao<>v.id;
      v_saldo:=v_linha.valor_total-v_consumido;
      if abs(v.valor)>v_saldo then
        v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-002','Rubrica e saldo','critica','O valor da transação supera o saldo disponível da rubrica. O eventual remanejamento precisa estar formalmente permitido antes do pagamento.',jsonb_build_object('saldo_disponivel',v_saldo,'valor_transacao',abs(v.valor),'limite_remanejamento_percentual',v_linha.limite_remanejamento_percentual),abs(v.valor)-greatest(v_saldo,0),'rubrica:'||v_linha.id::text,v_evidencias); v_ids:=array_append(v_ids,v_id);
      end if;
    end if;
  end if;
  if v.id_fornecedor is not null then
    select * into v_fornecedor from public.fornecedores where id=v.id_fornecedor and id_organizacao=v.id_organizacao;
    select * into v_cf from public.contratos_fornecedores cf where cf.id_contrato=v.id_contrato and cf.id_fornecedor=v.id_fornecedor and cf.status='ativo' and (cf.vigencia_inicio is null or cf.vigencia_inicio<=v.data) and (cf.vigencia_fim is null or cf.vigencia_fim>=v.data) order by cf.vigencia_inicio desc nulls last limit 1;
    if v_fornecedor.id is null or v_cf.id is null then
      v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-003','Fornecedor e objeto','alta','Não foi localizado vínculo contratual ativo do fornecedor para a data desta despesa.',jsonb_build_object('id_fornecedor',v.id_fornecedor,'data',v.data),abs(v.valor),'fornecedor:'||coalesce(v.id_fornecedor::text,'nao_identificado'),v_evidencias); v_ids:=array_append(v_ids,v_id);
    else
      v_sim:=greatest(extensions.similarity(lower(coalesce(v.descricao,'')),lower(coalesce(v_cf.objeto,''))),extensions.similarity(lower(coalesce(v.descricao,'')),lower(coalesce(v_contrato.objeto,''))));
      if v_sim<v_cfg.similaridade_objeto then
        v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-003','Fornecedor e objeto','media','A descrição da despesa possui baixa aderência textual ao objeto do fornecedor e ao objeto do contrato público. Revise antes do pagamento.',jsonb_build_object('similaridade',v_sim,'objeto_fornecedor',v_cf.objeto,'objeto_contrato',v_contrato.objeto),abs(v.valor),'objeto:'||v.id_fornecedor::text,v_evidencias); v_ids:=array_append(v_ids,v_id);
      end if;
    end if;
  end if;
  select count(*) into v_dup_count from public.transacoes_financeiras x where x.id_contrato=v.id_contrato and x.id<>v.id and x.status_fluxo<>'cancelada' and abs(x.valor-v.valor)<0.01 and x.data between v.data-v_cfg.janela_duplicidade_dias and v.data+v_cfg.janela_duplicidade_dias and (v.id_fornecedor is null or x.id_fornecedor=v.id_fornecedor or (v.fornecedor_documento_original is not null and x.fornecedor_documento_original=v.fornecedor_documento_original)) and (v.documento is null or x.documento=v.documento or extensions.similarity(lower(x.descricao),lower(v.descricao))>=v_cfg.similaridade_duplicidade);
  if v_dup_count>0 then v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-004','Possível duplicidade','critica','Foi localizada outra transação semelhante em fornecedor, documento, valor, data ou descrição. Confirme se não se trata de pagamento duplicado.',jsonb_build_object('ocorrencias_semelhantes',v_dup_count,'janela_dias',v_cfg.janela_duplicidade_dias),abs(v.valor),'duplicidade:'||coalesce(v.id_fornecedor::text,v.fornecedor_documento_original,'sem_fornecedor')||':'||round(abs(v.valor),2)::text,v_evidencias); v_ids:=array_append(v_ids,v_id); end if;
  if nullif(trim(coalesce(v_cfg.conta_bancaria_esperada,'')),'') is not null and coalesce(trim(v.conta_bancaria),'')<>trim(v_cfg.conta_bancaria_esperada) then v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-005','Conta bancária correta','critica','A movimentação está associada a uma conta bancária diferente da configurada para este contrato.',jsonb_build_object('conta_informada',v.conta_bancaria,'conta_esperada',v_cfg.conta_bancaria_esperada),abs(v.valor),'conta_bancaria',v_evidencias); v_ids:=array_append(v_ids,v_id); end if;
  select count(*) into v_prec_count from public.precedentes p where p.id_organizacao=v.id_organizacao and p.id_contratante=v_contrato.id_contratante and p.status='ativo' and (p.rubrica is null or v_linha.rubrica is null or lower(p.rubrica)=lower(v_linha.rubrica)) and (extensions.similarity(lower(p.problema),lower(v.descricao))>=0.30 or (p.valor_referencia is not null and abs(p.valor_referencia-abs(v.valor))<=greatest(1,abs(v.valor)*0.05))) and lower(coalesce(p.desfecho,'')) not in ('favoravel','aprovado','aceito');
  if v_prec_count>0 then v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-006','Precedente histórico','media','A transação possui características semelhantes a ocorrências já apontadas anteriormente pelo mesmo contratante.',jsonb_build_object('precedentes_relacionados',v_prec_count,'rotulo','ALERTA HISTÓRICO DO CONTRATANTE'),abs(v.valor),'precedente:'||coalesce(v_linha.rubrica,'geral'),v_evidencias); v_ids:=array_append(v_ids,v_id); end if;
  if jsonb_array_length(coalesce(v_evidencias,'[]'::jsonb))>0 then v_id:=privado.criar_ou_agrupar_alerta_preventivo(v.id_organizacao,v.id_contrato,v.id,'V3-PREV-007','Documentação futura','baixa','Preserve as evidências indicadas para facilitar a prestação de contas futura desta despesa.',jsonb_build_object('carater','orientativo'),0,'documentacao:'||coalesce(v_linha.rubrica,'geral'),v_evidencias); v_ids:=array_append(v_ids,v_id); end if;
  update public.transacoes_financeiras set pre_validada=true,pre_validada_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'TransacaoPreValidada','transacoes_financeiras',v.id,null,jsonb_build_object('alertas',v_ids,'quantidade',coalesce(array_length(v_ids,1),0)));
  return jsonb_build_object('id_transacao',v.id,'pre_validada',true,'alertas',v_ids,'quantidade_alertas',coalesce(array_length(v_ids,1),0),'mensagem',case when coalesce(array_length(v_ids,1),0)=0 then 'Nenhum alerta preventivo foi identificado com os dados disponíveis.' else 'A validação preventiva foi concluída. Revise os alertas antes de seguir com o pagamento ou fechamento.' end);
end; $$;

create or replace function public.validar_transacao_preventivamente(p_id_transacao uuid) returns jsonb language sql security invoker set search_path='' as $$ select privado.validar_transacao_preventivamente(p_id_transacao); $$;
revoke all on function public.validar_transacao_preventivamente(uuid) from public,anon; grant execute on function public.validar_transacao_preventivamente(uuid) to authenticated;

create or replace function privado.atribuir_alerta_preventivo(p_id_alerta uuid,p_responsavel uuid,p_prazo date default null)
returns uuid language plpgsql security definer set search_path=''
as $$ declare v public.alertas_preventivos%rowtype; v_tarefa uuid; begin
 select * into v from public.alertas_preventivos where id=p_id_alerta for update;
 if v.id is null then raise exception 'Não encontramos o alerta informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite atribuir este alerta.'; end if;
 if not exists(select 1 from public.vinculos_usuarios vu where vu.id_organizacao=v.id_organizacao and vu.id_usuario=p_responsavel and vu.ativo=true) then raise exception 'O responsável selecionado não possui vínculo ativo com esta organização.'; end if;
 update public.alertas_preventivos set responsavel=p_responsavel,status=case when status='aberto' then 'em_tratamento' else status end where id=v.id;
 insert into public.tarefas_alerta(id_organizacao,id_contrato,id_alerta,descricao,responsavel,prazo,status) values(v.id_organizacao,v.id_contrato,v.id,'Tratar alerta preventivo: '||v.descricao,p_responsavel,p_prazo,'pendente') returning id into v_tarefa;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AlertaPreventivoAtribuido','alertas_preventivos',v.id,null,jsonb_build_object('responsavel',p_responsavel,'id_tarefa',v_tarefa,'prazo',p_prazo)); return v_tarefa; end; $$;

create or replace function public.atribuir_alerta_preventivo(p_id_alerta uuid,p_responsavel uuid,p_prazo date default null) returns uuid language sql security invoker set search_path='' as $$ select privado.atribuir_alerta_preventivo(p_id_alerta,p_responsavel,p_prazo); $$;
revoke all on function public.atribuir_alerta_preventivo(uuid,uuid,date) from public,anon; grant execute on function public.atribuir_alerta_preventivo(uuid,uuid,date) to authenticated;

create or replace function privado.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null)
returns uuid language plpgsql security definer set search_path=''
as $$ declare v public.alertas_preventivos%rowtype; v_id uuid; v_status text; begin
 select * into v from public.alertas_preventivos where id=p_id_alerta for update;
 if v.id is null then raise exception 'Não encontramos o alerta informado.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso a este alerta.'; end if;
 if p_decisao not in ('corrigir','justificar','aceitar_risco','descartar') then raise exception 'Selecione uma decisão válida para o tratamento do alerta.'; end if;
 if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o fundamento do tratamento para manter a rastreabilidade.'; end if;
 if p_decisao in ('corrigir','justificar') and p_id_evidencia_versao_documento is null then raise exception 'Anexe uma evidência antes de concluir este tratamento.'; end if;
 insert into public.tratamentos_alertas(id_organizacao,id_contrato,id_alerta,decisao,fundamento,id_evidencia_versao_documento,tratado_por) values(v.id_organizacao,v.id_contrato,v.id,p_decisao,p_fundamento,p_id_evidencia_versao_documento,auth.uid()) returning id into v_id;
 v_status:=case when p_decisao='descartar' then 'descartado' else 'resolvido' end; update public.alertas_preventivos set status=v_status where id=v.id; update public.tarefas_alerta set status='concluida' where id_alerta=v.id and status not in ('concluida','cancelada');
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AlertaPreventivoTratado','alertas_preventivos',v.id,jsonb_build_object('status',v.status),jsonb_build_object('status',v_status,'decisao',p_decisao,'id_tratamento',v_id)); return v_id; end; $$;

create or replace function public.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null) returns uuid language sql security invoker set search_path='' as $$ select privado.tratar_alerta_preventivo(p_id_alerta,p_decisao,p_fundamento,p_id_evidencia_versao_documento); $$;
revoke all on function public.tratar_alerta_preventivo(uuid,text,text,uuid) from public,anon; grant execute on function public.tratar_alerta_preventivo(uuid,text,text,uuid) to authenticated;

create or replace view public.v_central_excecoes_financeiras with (security_invoker=true) as
select a.id,a.id_organizacao,a.id_contrato,a.id_transacao,a.codigo_regra,a.regra,a.severidade,a.status,a.descricao,a.impacto_financeiro,a.grupo_chave,a.quantidade_agrupada,a.responsavel,a.evidencias_futuras,a.criado_em,t.data,t.valor,t.descricao as descricao_transacao,t.documento,t.id_fornecedor from public.alertas_preventivos a left join public.transacoes_financeiras t on t.id=a.id_transacao where a.status in ('aberto','em_tratamento') order by case a.severidade when 'critica' then 4 when 'alta' then 3 when 'media' then 2 else 1 end desc,coalesce(a.impacto_financeiro,0) desc,a.criado_em desc;
grant select on public.v_central_excecoes_financeiras to authenticated;

create or replace function privado.enfileirar_prevalidacao_financeira() returns trigger language plpgsql security definer set search_path=''
as $$ begin if new.status_fluxo in ('prevista','em_aprovacao','registrada') then perform privado.enfileirar_job('finance_imports',new.id_organizacao,new.id_contrato,'transacao_financeira',new.id,jsonb_build_object('entidade_tipo','transacao_financeira','entidade_id',new.id),'prev-fin:'||new.id::text||':'||new.hash_origem); end if; return new; end; $$;
drop trigger if exists transacoes_financeiras_enfileirar_prevalidacao on public.transacoes_financeiras;
create trigger transacoes_financeiras_enfileirar_prevalidacao after insert on public.transacoes_financeiras for each row execute function privado.enfileirar_prevalidacao_financeira();

commit;
