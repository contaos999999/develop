begin;

alter table public.tarefas_diligencia add column id_execucao_revalidacao uuid
  references public.execucoes_assincronas(id) on delete restrict;
create unique index tarefas_diligencia_revalidacao_uidx
  on public.tarefas_diligencia(id_execucao_revalidacao) where id_execucao_revalidacao is not null;

revoke insert, update, delete on public.tarefas_diligencia, public.planos_acao from public, anon, authenticated;

create function privado.v247_pode_gerir(p_org uuid)
returns boolean language sql stable set search_path = '' as $$
  select coalesce(privado.usuario_possui_perfil(p_org,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]),false)
$$;

create function privado.v247_pode_revisar(p_org uuid)
returns boolean language sql stable set search_path = '' as $$
  select coalesce(privado.usuario_possui_perfil(p_org,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]),false)
$$;

create function privado.v247_responsaveis(p_org uuid,p_contrato uuid)
returns table(id uuid,nome text) language sql stable set search_path = '' as $$
  select distinct u.id_usuario, u.nome
  from public.vinculos_usuarios v
  join public.usuarios u on u.id_usuario=v.id_usuario and u.situacao='ativo'
  where v.id_organizacao=p_org and v.ativo and v.inicio_em<=now() and (v.fim_em is null or v.fim_em>now())
    and (v.escopo_todos_contratos or exists (
      select 1 from public.vinculos_usuario_contratos vc
      where vc.id_vinculo_usuario=v.id and vc.id_contrato=p_contrato and vc.id_organizacao=p_org
    ))
$$;

create function privado.v247_travar_rodada(p_ciclo uuid,p_interno boolean default false)
returns public.ciclos_diligencia language plpgsql set search_path = '' as $$
declare rodada public.ciclos_diligencia;
begin
  select * into rodada from public.ciclos_diligencia c
  where c.id=p_ciclo and (p_interno or (auth.uid() is not null and privado.sessao_usuario_ativa()
    and privado.usuario_tem_acesso_contrato(c.id_contrato))) for update;
  if not found then
    raise exception using errcode='42501',message='Esta rodada não está disponível no seu escopo.';
  end if;
  return rodada;
end
$$;

create function privado.v247_travar_tarefa(p_tarefa uuid,p_interno boolean default false)
returns public.tarefas_diligencia language plpgsql set search_path = '' as $$
declare tarefa public.tarefas_diligencia; rodada public.ciclos_diligencia; ciclo uuid;
begin
  select t.id_ciclo into ciclo from public.tarefas_diligencia t where t.id=p_tarefa;
  rodada:=privado.v247_travar_rodada(ciclo,p_interno);
  select * into tarefa from public.tarefas_diligencia t
  where t.id=p_tarefa and (t.id_organizacao,t.id_contrato,t.id_competencia,t.id_ciclo)=
    (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id) for update;
  if not found or not exists (
    select 1 from public.apontamentos_contratante a where a.id=tarefa.id_apontamento
    and (a.id_organizacao,a.id_contrato,a.id_competencia,a.id_ciclo)=
        (tarefa.id_organizacao,tarefa.id_contrato,tarefa.id_competencia,tarefa.id_ciclo)
  ) then
    raise exception using errcode='42501',message='A tarefa não está disponível nesta rodada.';
  end if;
  return tarefa;
end
$$;

create function privado.v247_escopo_editavel(p_ciclo uuid)
returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from public.ciclos_diligencia c
    where c.id=p_ciclo and c.status in ('aberto','em_tratamento'))
$$;

create function privado.v247_evidencia_da_tarefa(p_tarefa public.tarefas_diligencia,p_versao uuid)
returns boolean language sql stable set search_path = '' as $$
  select exists(
    select 1 from public.versoes_documento v
    join public.documentos_competencia d on d.id=v.id_documento_competencia
    where v.id=p_versao and v.hash ~ '^[0-9a-fA-F]{64}$'
      and (v.id_organizacao,v.id_contrato)=((p_tarefa).id_organizacao,(p_tarefa).id_contrato)
      and (d.id_organizacao,d.id_contrato,d.id_competencia)=
          ((p_tarefa).id_organizacao,(p_tarefa).id_contrato,(p_tarefa).id_competencia)
      and d.situacao='ativo' and v.numero_versao=d.versao_atual
  )
$$;

create function privado.v247_recibo(
  p_comando uuid,p_tarefa public.tarefas_diligencia,p_evento text,p_antes jsonb,
  p_detalhe jsonb default '{}'::jsonb
) returns jsonb language plpgsql set search_path = '' as $$
declare v_id_evento uuid; v_correlacao uuid; v_resposta jsonb;
begin
  v_id_evento:=privado.registrar_evento_auditoria(p_tarefa.id_organizacao,p_evento,'tarefas_diligencia',
    p_tarefa.id,p_antes,to_jsonb(p_tarefa)||p_detalhe,jsonb_build_object('comando_id',p_comando));
  select e.correlation_id into v_correlacao from public.eventos_auditoria e where e.id=v_id_evento;
  v_resposta:=jsonb_build_object('schema_versao','v247-v1','id_tarefa',p_tarefa.id,
    'versao_registro',p_tarefa.versao_registro,'status',p_tarefa.status,'validacao_solucao',p_tarefa.validacao_solucao,
    'id_execucao',p_tarefa.id_execucao_revalidacao,'correlation_id',v_correlacao)||p_detalhe;
  update public.comandos_idempotentes
    set status='concluido',resposta=v_resposta,atualizado_em=clock_timestamp() where id=p_comando;
  return v_resposta;
end
$$;

create function privado.v247_notificar_tarefa(
  p_tarefa public.tarefas_diligencia,p_evento text,p_titulo text,p_mensagem text
) returns void language plpgsql set search_path='' as $$
declare evento_papel text;
begin
  select p_evento||':'||v.perfil into evento_papel from public.vinculos_usuarios v
    where v.id_organizacao=p_tarefa.id_organizacao and v.id_usuario=p_tarefa.responsavel
      and v.ativo and v.inicio_em<=now() and (v.fim_em is null or v.fim_em>now());
  if not exists(select 1 from public.preferencias_notificacao p where p.id_organizacao=p_tarefa.id_organizacao
    and p.id_usuario=p_tarefa.responsavel and p.evento=evento_papel) then
    evento_papel:=p_evento;
  end if;
  perform privado.criar_notificacao(p_tarefa.id_organizacao,p_tarefa.responsavel,evento_papel,
    p_titulo,p_mensagem,'tarefas_diligencia',p_tarefa.id);
end
$$;

create function public.salvar_tarefa_diligencia_v2(
  p_id_ciclo uuid,p_id_apontamento uuid,p_id_tarefa uuid,p_versao_esperada bigint,
  p_dados jsonb,p_chave_idempotencia text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  rodada public.ciclos_diligencia;
  tarefa public.tarefas_diligencia;
  anterior jsonb;
  comando jsonb;
  responsavel_anterior uuid;
  prazo_anterior date;
  texto text;
  responsavel_tarefa uuid;
  prazo_tarefa date;
  tipo text;
  prioridade_tarefa text;
  plano uuid;
  dependencias uuid[];
  titulo_plano text;
begin
  rodada:=privado.v247_travar_rodada(p_id_ciclo);
  if not privado.v247_pode_gerir(rodada.id_organizacao) or not exists (
    select 1 from public.apontamentos_contratante a
    where a.id=p_id_apontamento and (a.id_organizacao,a.id_contrato,a.id_competencia,a.id_ciclo)=
      (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id)
  ) then
    raise exception using errcode='42501',message='Você não pode editar tarefas deste apontamento.';
  end if;
  if p_dados is null or jsonb_typeof(p_dados)<>'object' or
    (p_dados-array['descricao','responsavel','prazo','tipo_acao','prioridade','depende_de','id_plano']::text[]) <> '{}'::jsonb then
    raise exception using errcode='PT400',message='Informe os campos permitidos para a tarefa.';
  end if;
  comando:=privado.v107_iniciar(rodada.id_organizacao,'v247_salvar_tarefa',p_chave_idempotencia,
    jsonb_build_object('rodada',p_id_ciclo,'item',p_id_apontamento,'tarefa',p_id_tarefa,
      'versao',p_versao_esperada,'dados',p_dados));
  if comando ? 'resposta' then return comando->'resposta'; end if;
  if not privado.v247_escopo_editavel(rodada.id) then
    raise exception using errcode='PT409',message='A rodada já foi liberada ou encerrada.';
  end if;
  if p_id_tarefa is not null then
    select * into tarefa from public.tarefas_diligencia t
      where t.id=p_id_tarefa and (t.id_organizacao,t.id_contrato,t.id_competencia,t.id_ciclo,t.id_apontamento)=
        (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id,p_id_apontamento) for update;
    if not found then
      raise exception using errcode='42501',message='A tarefa não está disponível neste apontamento.';
    end if;
    if tarefa.versao_registro is distinct from p_versao_esperada or tarefa.status not in ('pendente','em_execucao') then
      raise exception using errcode='PT409',message='A tarefa foi atualizada ou aguarda validação. Atualize a tela.';
    end if;
    anterior:=to_jsonb(tarefa);
    responsavel_anterior:=tarefa.responsavel;
    prazo_anterior:=tarefa.prazo;
  end if;
  begin
    texto:=btrim(coalesce(p_dados->>'descricao',tarefa.descricao,''));
    responsavel_tarefa:=coalesce((p_dados->>'responsavel')::uuid,tarefa.responsavel);
    prazo_tarefa:=coalesce((p_dados->>'prazo')::date,tarefa.prazo);
    tipo:=btrim(coalesce(p_dados->>'tipo_acao',tarefa.tipo_acao,''));
    prioridade_tarefa:=coalesce(p_dados->>'prioridade',tarefa.prioridade,'media');
    plano:=coalesce((p_dados->>'id_plano')::uuid,tarefa.id_plano);
    if p_dados ? 'depende_de' then
      select coalesce(array_agg(x::uuid order by x::uuid),array[]::uuid[])
      into dependencias from jsonb_array_elements_text(p_dados->'depende_de') x;
    else
      dependencias:=coalesce(tarefa.depende_de,array[]::uuid[]);
    end if;
  exception when invalid_text_representation or invalid_parameter_value or invalid_datetime_format or datetime_field_overflow then
    raise exception using errcode='PT400',message='Responsável, prazo, plano ou dependência inválidos.';
  end;
  if texto='' or (tipo='' and p_id_tarefa is null) or prioridade_tarefa not in ('baixa','media','alta','critica')
    or (p_id_tarefa is null and (responsavel_tarefa is null or prazo_tarefa is null))
    or (responsavel_tarefa is not null and not exists (
      select 1 from privado.v247_responsaveis(rodada.id_organizacao,rodada.id_contrato) r where r.id=responsavel_tarefa
    )) then
    raise exception using errcode='PT400',message='Revise a descrição, o tipo, a prioridade, o prazo e o vínculo do responsável.';
  end if;
  if cardinality(dependencias)<>(select count(distinct d) from unnest(dependencias) d) or exists (
    select 1 from unnest(dependencias) d where not exists (
      select 1 from public.tarefas_diligencia t where t.id=d and t.status<>'cancelada'
      and (t.id_organizacao,t.id_contrato,t.id_competencia,t.id_ciclo)=
        (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id)
    )
  ) or exists (
    with recursive cadeia(id) as (
      select unnest(dependencias)
      union
      select unnest(t.depende_de) from cadeia c join public.tarefas_diligencia t on t.id=c.id
      where t.id_ciclo=rodada.id and t.id_organizacao=rodada.id_organizacao
        and t.id_contrato=rodada.id_contrato and t.id_competencia=rodada.id_competencia
    )
    select 1 from cadeia where id=p_id_tarefa
  ) then
    raise exception using errcode='PT400',message='As dependências devem ser válidas, únicas e sem ciclo nesta rodada.';
  end if;
  if plano is null then
    titulo_plano:='Plano da rodada '||rodada.numero_rodada;
    select pa.id into plano from public.planos_acao pa
      where (pa.id_organizacao,pa.id_contrato,pa.id_competencia,pa.id_ciclo)=
        (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id)
        and pa.status='aberto' and pa.titulo=titulo_plano order by pa.criado_em,pa.id limit 1;
    if plano is null then
      insert into public.planos_acao(id_organizacao,id_contrato,id_competencia,id_ciclo,titulo)
      values(rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id,titulo_plano)
      returning id into plano;
    end if;
  elsif not exists (
    select 1 from public.planos_acao pa where pa.id=plano and pa.status in ('aberto','em_execucao')
      and (pa.id_organizacao,pa.id_contrato,pa.id_competencia,pa.id_ciclo)=
        (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id)
  ) then
    raise exception using errcode='PT400',message='O plano informado não está disponível nesta rodada.';
  end if;

  if p_id_tarefa is null then
    insert into public.tarefas_diligencia(
      id_organizacao,id_contrato,id_competencia,id_ciclo,id_apontamento,id_plano,descricao,responsavel,
      prazo,tipo_acao,prioridade,depende_de
    ) values (
      rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id,p_id_apontamento,plano,
      texto,responsavel_tarefa,prazo_tarefa,tipo,prioridade_tarefa,dependencias
    ) returning * into tarefa;
    update public.apontamentos_contratante set status='em_tratamento'
      where id=p_id_apontamento and status in ('aberto','em_analise','procedente','resolvido');
  else
    update public.tarefas_diligencia
    set descricao=texto,responsavel=responsavel_tarefa,prazo=prazo_tarefa,tipo_acao=nullif(tipo,''),
      prioridade=prioridade_tarefa,depende_de=dependencias,id_plano=plano,status='em_execucao'
      where id=tarefa.id returning * into tarefa;
  end if;
  if tarefa.responsavel is not null and tarefa.responsavel is distinct from responsavel_anterior then
    perform privado.v247_notificar_tarefa(tarefa,'TarefaDiligenciaAtribuida',
      'Tarefa de diligência atribuída','Consulte o plano de ação da rodada.');
  elsif tarefa.responsavel is not null and tarefa.prazo is distinct from prazo_anterior then
    perform privado.v247_notificar_tarefa(tarefa,'TarefaDiligenciaPrazoAlterado',
      'Prazo da tarefa alterado','Consulte o prazo atualizado no plano de ação.');
  end if;
  return privado.v247_recibo((comando->>'id')::uuid,tarefa,
    case when anterior is null then 'TarefaDiligenciaCriada' else 'TarefaDiligenciaAtualizada' end,anterior);
end
$$;

create function privado.v247_prova(p_tarefa public.tarefas_diligencia)
returns jsonb language sql stable set search_path = '' as $$
  select e.metadados->'prova_v247'
  from public.execucoes_assincronas e
  join public.analises_apontamentos a on a.id::text=e.metadados#>>'{prova_v247,id_analise}'
  where e.id=(p_tarefa).id_execucao_revalidacao and e.status='concluido' and e.fila='ai'
    and e.entidade_tipo='revalidar_apontamento' and e.entidade_id=(p_tarefa).id_apontamento
    and (e.id_organizacao,e.id_contrato)=((p_tarefa).id_organizacao,(p_tarefa).id_contrato)
    and e.metadados->>'id_ciclo'=(p_tarefa).id_ciclo::text
    and e.metadados->>'id_competencia'=(p_tarefa).id_competencia::text
    and e.metadados->>'id_tarefa'=(p_tarefa).id::text
    and e.metadados->>'id_evidencia'=(p_tarefa).id_evidencia_versao_documento::text
    and (a.id_organizacao,a.id_contrato,a.id_competencia,a.id_apontamento)=
        ((p_tarefa).id_organizacao,(p_tarefa).id_contrato,(p_tarefa).id_competencia,(p_tarefa).id_apontamento)
    and a.evidencias @> jsonb_build_array(jsonb_build_object(
      'id_versao_documento',(p_tarefa).id_evidencia_versao_documento,'id_execucao',e.id,'id_tarefa',(p_tarefa).id))
$$;

create function privado.v247_pode_reenviar(p_tarefa public.tarefas_diligencia)
returns boolean language sql stable set search_path='' as $$
  select (p_tarefa).status in ('pendente','em_execucao') or (
    (p_tarefa).status='concluida' and (p_tarefa).validacao_solucao='em_analise' and (
      (p_tarefa).id_execucao_revalidacao is null
      or exists(select 1 from public.execucoes_assincronas e
         where e.id=(p_tarefa).id_execucao_revalidacao and e.status in ('falhou','cancelado'))
      or privado.v247_prova(p_tarefa)->'evidencia_suficiente'='false'::jsonb
      or not privado.v247_evidencia_da_tarefa(p_tarefa,(p_tarefa).id_evidencia_versao_documento)
    )
  )
$$;

create function public.submeter_solucao_tarefa_diligencia_v2(
  p_id_tarefa uuid,p_id_evidencia uuid,p_versao_esperada bigint,p_chave_idempotencia text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare tarefa public.tarefas_diligencia; comando jsonb; anterior jsonb; execucao uuid; payload jsonb;
begin
  tarefa:=privado.v247_travar_tarefa(p_id_tarefa);
  if not privado.v247_pode_gerir(tarefa.id_organizacao) and tarefa.responsavel is distinct from auth.uid() then
    raise exception using errcode='42501',message='Somente o responsável ou um gestor pode submeter a solução.';
  end if;
  comando:=privado.v107_iniciar(tarefa.id_organizacao,'v247_submeter_tarefa',p_chave_idempotencia,
    jsonb_build_object('tarefa',p_id_tarefa,'versao',p_versao_esperada,'evidencia',p_id_evidencia));
  if comando ? 'resposta' then return comando->'resposta'; end if;
  if not privado.v247_escopo_editavel(tarefa.id_ciclo) or tarefa.versao_registro is distinct from p_versao_esperada
    or not coalesce(privado.v247_pode_reenviar(tarefa),false) then
    raise exception using errcode='PT409',message='O estado da tarefa mudou ou a revisão está em andamento.';
  end if;
  if exists (
    select 1 from unnest(tarefa.depende_de) d
    where not exists (select 1 from public.tarefas_diligencia outra where outra.id=d
      and (outra.id_organizacao,outra.id_contrato,outra.id_competencia,outra.id_ciclo)=
        (tarefa.id_organizacao,tarefa.id_contrato,tarefa.id_competencia,tarefa.id_ciclo)
      and outra.status='concluida' and outra.validacao_solucao='aprovada')
  ) then
    raise exception using errcode='PT409',message='Conclua e valide as dependências da rodada antes de submeter.';
  end if;
  perform 1 from public.documentos_competencia d
    join public.versoes_documento v on v.id_documento_competencia=d.id
    where v.id=p_id_evidencia and (d.id_organizacao,d.id_contrato,d.id_competencia)=
      (tarefa.id_organizacao,tarefa.id_contrato,tarefa.id_competencia) for share of d,v;
  if not privado.v247_evidencia_da_tarefa(tarefa,p_id_evidencia) then
    raise exception using errcode='PT400',message='Selecione uma versão vigente de documento desta competência.';
  end if;
  anterior:=to_jsonb(tarefa);
  payload:=jsonb_build_object('id_tarefa',tarefa.id,'id_apontamento',tarefa.id_apontamento,
    'id_evidencia',p_id_evidencia,'id_ciclo',tarefa.id_ciclo,'id_competencia',tarefa.id_competencia);
  execucao:=privado.enfileirar_job('ai',tarefa.id_organizacao,tarefa.id_contrato,
    'revalidar_apontamento',tarefa.id_apontamento,payload,
    'v247-revalidar:'||tarefa.id||':'||(comando->>'id'));
  update public.execucoes_assincronas set metadados=coalesce(metadados,'{}'::jsonb)||payload where id=execucao;
  update public.tarefas_diligencia set status='concluida',validacao_solucao='em_analise',
    id_evidencia_versao_documento=p_id_evidencia,id_execucao_revalidacao=execucao
    where id=tarefa.id returning * into tarefa;
  update public.apontamentos_contratante set status='em_tratamento'
    where id=tarefa.id_apontamento and status in ('aberto','em_analise','procedente','em_tratamento','resolvido');
  return privado.v247_recibo((comando->>'id')::uuid,tarefa,'TarefaDiligenciaConcluida',anterior,
    jsonb_build_object('id_evidencia',p_id_evidencia));
end
$$;

create function public.revisar_solucao_tarefa_diligencia_v2(
  p_id_tarefa uuid,p_versao_esperada bigint,p_aprovar boolean,p_fundamento text,p_chave_idempotencia text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare tarefa public.tarefas_diligencia; comando jsonb; anterior jsonb; prova jsonb; fundamento text;
begin
  tarefa:=privado.v247_travar_tarefa(p_id_tarefa);
  if not privado.v247_pode_revisar(tarefa.id_organizacao) then
    raise exception using errcode='42501',message='Seu perfil não permite revisar a solução.';
  end if;
  fundamento:=nullif(btrim(p_fundamento),'');
  if fundamento is null or p_aprovar is null then
    raise exception using errcode='PT400',message='Informe a decisão e o fundamento da revisão.';
  end if;
  comando:=privado.v107_iniciar(tarefa.id_organizacao,'v247_revisar_tarefa',p_chave_idempotencia,
    jsonb_build_object('tarefa',p_id_tarefa,'versao',p_versao_esperada,'aprovar',p_aprovar,'fundamento',fundamento));
  if comando ? 'resposta' then return comando->'resposta'; end if;
  if not privado.v247_escopo_editavel(tarefa.id_ciclo) or tarefa.versao_registro is distinct from p_versao_esperada
    or tarefa.status<>'concluida' or tarefa.validacao_solucao<>'em_analise' then
    raise exception using errcode='PT409',message='A tarefa não está mais aguardando esta revisão.';
  end if;
  perform 1 from public.documentos_competencia d
    join public.versoes_documento v on v.id_documento_competencia=d.id
    where v.id=tarefa.id_evidencia_versao_documento for share of d,v;
  prova:=privado.v247_prova(tarefa);
  if prova is null or (p_aprovar and (
    prova->'evidencia_suficiente' is distinct from 'true'::jsonb or
    not privado.v247_evidencia_da_tarefa(tarefa,tarefa.id_evidencia_versao_documento)
  )) then
    raise exception using errcode='PT409',message='A aprovação exige revalidação suficiente da versão vigente da evidência.';
  end if;
  anterior:=to_jsonb(tarefa);
  update public.analises_apontamentos
    set revisado_por=auth.uid(),revisado_em=clock_timestamp() where id=(prova->>'id_analise')::uuid;
  update public.tarefas_diligencia
    set validacao_solucao=case when p_aprovar then 'aprovada' else 'rejeitada' end,
        status=case when p_aprovar then 'concluida' else 'em_execucao' end
    where id=tarefa.id returning * into tarefa;
  if p_aprovar and not exists(
    select 1 from public.tarefas_diligencia outra where outra.id_ciclo=tarefa.id_ciclo
      and outra.id_apontamento=tarefa.id_apontamento and outra.status<>'cancelada'
      and (outra.status<>'concluida' or outra.validacao_solucao<>'aprovada')
  ) then
    update public.apontamentos_contratante set status='resolvido' where id=tarefa.id_apontamento
      and status in ('aberto','em_analise','procedente','em_tratamento');
  end if;
  return privado.v247_recibo((comando->>'id')::uuid,tarefa,'SolucaoTarefaDiligenciaRevisada',anterior,
    jsonb_build_object('aprovada',p_aprovar,'fundamento',fundamento,'revisor',auth.uid(),
      'id_analise',prova->>'id_analise','id_evidencia',tarefa.id_evidencia_versao_documento,
      'mensagem',case when p_aprovar then 'A solução foi validada e o fluxo foi atualizado.'
        else 'A solução foi devolvida para ajuste.' end));
end
$$;

-- Preserva as assinaturas anteriores e aplica a mesma autoridade às chamadas legadas.
create or replace function privado.atualizar_tarefa_diligencia(
  p_id_tarefa uuid,p_descricao text default null,p_responsavel uuid default null,p_prazo date default null
) returns void language plpgsql security definer set search_path = '' as $$
declare tarefa public.tarefas_diligencia;
begin
  tarefa:=privado.v247_travar_tarefa(p_id_tarefa);
  perform public.salvar_tarefa_diligencia_v2(tarefa.id_ciclo,tarefa.id_apontamento,tarefa.id,tarefa.versao_registro,
    jsonb_strip_nulls(jsonb_build_object('descricao',p_descricao,'responsavel',p_responsavel,'prazo',p_prazo)),
    gen_random_uuid()::text);
end
$$;

create or replace function privado.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare tarefa public.tarefas_diligencia;
begin
  tarefa:=privado.v247_travar_tarefa(p_id_tarefa);
  perform public.submeter_solucao_tarefa_diligencia_v2(tarefa.id,p_id_evidencia_versao_documento,tarefa.versao_registro,
    'legado-submeter:'||tarefa.id||':'||tarefa.versao_registro);
end
$$;

create or replace function privado.revisar_solucao_tarefa_diligencia(p_id_tarefa uuid,p_aprovar boolean,p_fundamento text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare tarefa public.tarefas_diligencia;
begin
  tarefa:=privado.v247_travar_tarefa(p_id_tarefa);
  return public.revisar_solucao_tarefa_diligencia_v2(tarefa.id,tarefa.versao_registro,p_aprovar,p_fundamento,
    'legado-revisar:'||tarefa.id||':'||tarefa.versao_registro);
end
$$;

create function public.obter_revalidacao_tarefa_diligencia_v2(
  p_id_execucao uuid,p_id_tarefa uuid,p_id_apontamento uuid,p_id_evidencia uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare execucao public.execucoes_assincronas; tarefa public.tarefas_diligencia; item public.apontamentos_contratante;
begin
  select * into execucao from public.execucoes_assincronas e where e.id=p_id_execucao and e.fila='ai'
    and e.entidade_tipo='revalidar_apontamento' and e.entidade_id=p_id_apontamento;
  if not found then
    raise exception using errcode='42501',message='A execução de revalidação não corresponde ao apontamento.';
  end if;
  if p_id_tarefa is null and not (execucao.metadados ? 'id_tarefa') then
    return jsonb_build_object('estado','obsoleta');
  end if;
  if execucao.metadados->>'id_tarefa' is distinct from p_id_tarefa::text or
    execucao.metadados->>'id_evidencia' is distinct from p_id_evidencia::text then
    raise exception using errcode='42501',message='A execução de revalidação não corresponde à tarefa e à versão.';
  end if;

  tarefa:=privado.v247_travar_tarefa(p_id_tarefa,true);
  select * into strict execucao from public.execucoes_assincronas e where e.id=p_id_execucao;
  if (tarefa.id_organizacao,tarefa.id_contrato,tarefa.id_apontamento,tarefa.id_ciclo::text,tarefa.id_competencia::text)
     is distinct from (execucao.id_organizacao,execucao.id_contrato,p_id_apontamento,
      execucao.metadados->>'id_ciclo',execucao.metadados->>'id_competencia') then
    raise exception using errcode='42501',message='A execução de revalidação está fora do escopo da tarefa.';
  end if;
  if tarefa.id_execucao_revalidacao is distinct from p_id_execucao or
    tarefa.id_evidencia_versao_documento is distinct from p_id_evidencia then
    return jsonb_build_object('estado','obsoleta');
  end if;
  if execucao.metadados ? 'prova_v247' then
    return jsonb_build_object('estado','registrada','prova',execucao.metadados->'prova_v247');
  end if;
  if execucao.status<>'processando' or tarefa.status<>'concluida' or tarefa.validacao_solucao<>'em_analise'
    or not privado.v247_escopo_editavel(tarefa.id_ciclo) then
    raise exception using errcode='PT409',message='A submissão não está em processamento para revalidação.';
  end if;
  if not privado.v247_evidencia_da_tarefa(tarefa,p_id_evidencia) then
    return jsonb_build_object('estado','obsoleta');
  end if;
  select * into strict item from public.apontamentos_contratante a where a.id=tarefa.id_apontamento;
  return jsonb_build_object('estado','pendente','descricao',item.descricao,'fundamento',item.fundamento);
end
$$;

create function public.registrar_revalidacao_tarefa_diligencia_v2(
  p_id_execucao uuid,p_id_tarefa uuid,p_id_apontamento uuid,p_id_evidencia uuid,
  p_classificacao text,p_fundamento text,p_confianca numeric,p_evidencia_suficiente boolean
) returns jsonb language plpgsql security definer set search_path='' as $$
declare leitura jsonb; tarefa public.tarefas_diligencia; id_analise uuid; prova jsonb;
begin
  leitura:=public.obter_revalidacao_tarefa_diligencia_v2(p_id_execucao,p_id_tarefa,p_id_apontamento,p_id_evidencia);
  if leitura->>'estado'<>'pendente' then return leitura; end if;

  tarefa:=privado.v247_travar_tarefa(p_id_tarefa,true);
  perform 1 from public.documentos_competencia d
    join public.versoes_documento v on v.id_documento_competencia=d.id
    where v.id=p_id_evidencia for share of d,v;
  if not privado.v247_evidencia_da_tarefa(tarefa,p_id_evidencia) then
    return jsonb_build_object('estado','obsoleta');
  end if;
  perform 1 from public.execucoes_assincronas e where e.id=p_id_execucao and e.status='processando' for update;
  if not found then
    raise exception using errcode='PT409',message='A execução de revalidação mudou durante o processamento.';
  end if;
  if p_classificacao is null or p_classificacao not in ('procedente','parcialmente_procedente','nao_procedente','inconclusivo')
    or nullif(btrim(p_fundamento),'') is null or p_confianca is null or p_confianca not between 0 and 1
    or p_evidencia_suficiente is null or (p_evidencia_suficiente and p_classificacao='inconclusivo') then
    raise exception using errcode='PT400',message='Resultado de revalidação inválido.';
  end if;

  insert into public.analises_apontamentos(id_organizacao,id_contrato,id_competencia,id_apontamento,
    classificacao,fundamento,evidencias)
  values(tarefa.id_organizacao,tarefa.id_contrato,tarefa.id_competencia,tarefa.id_apontamento,
    p_classificacao,btrim(p_fundamento),jsonb_build_array(jsonb_build_object(
      'id_versao_documento',p_id_evidencia,'id_execucao',p_id_execucao,'id_tarefa',p_id_tarefa)))
  returning id into id_analise;
  prova:=jsonb_build_object('id_analise',id_analise,'id_execucao',p_id_execucao,'id_tarefa',p_id_tarefa,
    'id_apontamento',p_id_apontamento,'id_evidencia',p_id_evidencia,'classificacao',p_classificacao,
    'confianca',p_confianca,'evidencia_suficiente',p_evidencia_suficiente,'registrado_em',clock_timestamp());
  update public.execucoes_assincronas set metadados=jsonb_set(metadados,'{prova_v247}',prova) where id=p_id_execucao;
  perform privado.registrar_evento_auditoria(tarefa.id_organizacao,'TarefaDiligenciaRevalidada',
    'tarefas_diligencia',tarefa.id,null,prova,jsonb_build_object('id_execucao',p_id_execucao));
  return jsonb_build_object('estado','registrada','prova',prova);
end
$$;

create function public.obter_plano_acao_diligencia_v2(
  p_id_ciclo uuid,p_id_apontamento uuid,p_offset integer default 0,p_limite integer default 20
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  rodada public.ciclos_diligencia;
  editavel boolean;
  gestor boolean;
  revisor boolean;
  perfil text;
  tarefas jsonb;
  total integer;
begin
  select * into rodada from public.ciclos_diligencia c where c.id=p_id_ciclo
    and auth.uid() is not null and privado.sessao_usuario_ativa() and privado.usuario_tem_acesso_contrato(c.id_contrato);
  if not found or not exists (
    select 1 from public.apontamentos_contratante a where a.id=p_id_apontamento and
      (a.id_organizacao,a.id_contrato,a.id_competencia,a.id_ciclo)=
      (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id)
  ) then
    raise exception using errcode='42501',message='Este plano de ação está fora do seu escopo.';
  end if;
  if p_offset is null or p_offset<0 or p_limite is null or p_limite not between 1 and 50 then
    raise exception using errcode='PT400',message='Informe uma página de 1 a 50 tarefas.';
  end if;

  editavel:=privado.v247_escopo_editavel(rodada.id);
  gestor:=privado.v247_pode_gerir(rodada.id_organizacao);
  revisor:=privado.v247_pode_revisar(rodada.id_organizacao);
  if not gestor and not revisor and not exists (
    select 1 from public.tarefas_diligencia t where t.id_apontamento=p_id_apontamento and t.responsavel=auth.uid()
      and (t.id_organizacao,t.id_contrato,t.id_competencia,t.id_ciclo)=
        (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id)
  ) then
    raise exception using errcode='42501',message='Seu perfil não tem atribuição neste plano de ação.';
  end if;
  select v.perfil into perfil from public.vinculos_usuarios v
    where v.id_organizacao=rodada.id_organizacao and v.id_usuario=auth.uid() and v.ativo and v.inicio_em<=now()
      and (v.fim_em is null or v.fim_em>now());
  select count(*) into total from public.tarefas_diligencia t
    where t.id_apontamento=p_id_apontamento and (t.id_organizacao,t.id_contrato,t.id_competencia,t.id_ciclo)=
      (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id);
  with pagina as (
    select t.*,array_position(array['critica','alta','media','baixa'],t.prioridade) as ordem_prioridade
    from public.tarefas_diligencia t
    where t.id_apontamento=p_id_apontamento and (t.id_organizacao,t.id_contrato,t.id_competencia,t.id_ciclo)=
      (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id)
    order by t.prazo nulls last,ordem_prioridade,t.id offset p_offset limit p_limite
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',t.id,'id_plano',t.id_plano,'descricao',t.descricao,'responsavel',t.responsavel,'prazo',t.prazo,
    'status',t.status,'tipo_acao',t.tipo_acao,'prioridade',t.prioridade,'depende_de',t.depende_de,
    'validacao_solucao',t.validacao_solucao,'versao_registro',t.versao_registro,'id_execucao',t.id_execucao_revalidacao,
    'id_evidencia',t.id_evidencia_versao_documento,'prova',p.prova,'estado_execucao',e.status,
    'editar',editavel and gestor and t.status in ('pendente','em_execucao'),
    'submeter',editavel and (gestor or t.responsavel is not distinct from auth.uid()) and
      coalesce(privado.v247_pode_reenviar(tarefa),false),
    'revisar',editavel and revisor and t.status='concluida' and t.validacao_solucao='em_analise' and p.prova is not null,
    'aprovar',editavel and revisor and t.status='concluida' and t.validacao_solucao='em_analise' and
      coalesce(p.prova->'evidencia_suficiente'='true'::jsonb,false) and
      privado.v247_evidencia_da_tarefa(tarefa,t.id_evidencia_versao_documento)
  ) order by t.prazo nulls last,t.ordem_prioridade,t.id),'[]'::jsonb) into tarefas
  from pagina t
  join public.tarefas_diligencia tarefa on tarefa.id=t.id
  left join public.execucoes_assincronas e on e.id=t.id_execucao_revalidacao
  cross join lateral (select privado.v247_prova(tarefa) as prova) p;

  return jsonb_build_object(
    'id_ciclo',rodada.id,'id_apontamento',p_id_apontamento,'total',total,'offset',p_offset,'limite',p_limite,
    'criar',editavel and gestor,'tarefas',tarefas,'perfil_preferencia',perfil,
    'planos',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'titulo',p.titulo,'status',p.status) order by p.titulo,p.id)
      from public.planos_acao p where (p.id_organizacao,p.id_contrato,p.id_competencia,p.id_ciclo)=
        (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id)), '[]'::jsonb),
    'responsaveis',coalesce((select jsonb_agg(to_jsonb(r) order by r.nome,r.id)
      from privado.v247_responsaveis(rodada.id_organizacao,rodada.id_contrato) r),'[]'::jsonb),
    'dependencias',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'descricao',d.descricao,
      'status',d.status,'validacao_solucao',d.validacao_solucao) order by d.descricao,d.id)
      from public.tarefas_diligencia d where (d.id_organizacao,d.id_contrato,d.id_competencia,d.id_ciclo)=
        (rodada.id_organizacao,rodada.id_contrato,rodada.id_competencia,rodada.id) and d.status<>'cancelada'),'[]'::jsonb)
  );
end
$$;

revoke all on function
  privado.v247_pode_gerir(uuid),privado.v247_pode_revisar(uuid),privado.v247_responsaveis(uuid,uuid),
  privado.v247_travar_rodada(uuid,boolean),privado.v247_travar_tarefa(uuid,boolean),privado.v247_escopo_editavel(uuid),
  privado.v247_evidencia_da_tarefa(public.tarefas_diligencia,uuid),
  privado.v247_recibo(uuid,public.tarefas_diligencia,text,jsonb,jsonb),
  privado.v247_notificar_tarefa(public.tarefas_diligencia,text,text,text),
  privado.v247_prova(public.tarefas_diligencia),privado.v247_pode_reenviar(public.tarefas_diligencia),
  public.salvar_tarefa_diligencia_v2(uuid,uuid,uuid,bigint,jsonb,text),
  public.submeter_solucao_tarefa_diligencia_v2(uuid,uuid,bigint,text),
  public.revisar_solucao_tarefa_diligencia_v2(uuid,bigint,boolean,text,text),
  public.obter_plano_acao_diligencia_v2(uuid,uuid,integer,integer),
  public.obter_revalidacao_tarefa_diligencia_v2(uuid,uuid,uuid,uuid),
  public.registrar_revalidacao_tarefa_diligencia_v2(uuid,uuid,uuid,uuid,text,text,numeric,boolean)
  from public,anon,authenticated,service_role;

grant execute on function public.salvar_tarefa_diligencia_v2(uuid,uuid,uuid,bigint,jsonb,text),
  public.submeter_solucao_tarefa_diligencia_v2(uuid,uuid,bigint,text),
  public.revisar_solucao_tarefa_diligencia_v2(uuid,bigint,boolean,text,text),
  public.obter_plano_acao_diligencia_v2(uuid,uuid,integer,integer) to authenticated;

grant execute on function public.obter_revalidacao_tarefa_diligencia_v2(uuid,uuid,uuid,uuid),
  public.registrar_revalidacao_tarefa_diligencia_v2(uuid,uuid,uuid,uuid,text,text,numeric,boolean) to service_role;
commit;
