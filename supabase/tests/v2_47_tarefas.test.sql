\set QUIET on
begin;

create function fixture.exigir(condicao boolean,prova text) returns void language plpgsql as $$
begin
  if condicao is distinct from true then raise exception 'V247_FALHA: %',prova; end if;
end
$$;
create function fixture.rejeitar(comando text,estado text) returns void language plpgsql as $$
begin
  execute comando;
  raise exception 'V247_FALHA: operação deveria retornar %',estado;
exception when others then
  if sqlstate<>estado then raise; end if;
end
$$;
create function fixture.salvar(chave text,dados jsonb default '{}',tarefa uuid default null,
  versao bigint default null,rodada integer default 101,item integer default 201)
returns jsonb language sql as $$
  select public.salvar_tarefa_diligencia_v2(fixture.id(rodada),fixture.id(item),tarefa,versao,
    case when tarefa is null then jsonb_build_object('descricao','Conferir comprovante',
      'responsavel',fixture.id(2),'prazo','2026-12-05','tipo_acao','corrigir_documento','prioridade','alta',
      'depende_de','[]'::jsonb)||dados else dados end,chave)
$$;
create function fixture.cfg(chave text) returns uuid language sql stable as $$
  select current_setting('contaos.fixture.'||chave)::uuid
$$;
create function fixture.validar_job(execucao uuid,tarefa uuid,versao uuid,suficiente boolean)
returns jsonb language sql as $$
  select public.registrar_revalidacao_tarefa_diligencia_v2(execucao,tarefa,fixture.id(201),versao,
    case when suficiente then 'procedente' else 'inconclusivo' end,'Fundamento da prova sintética',
    case when suficiente then 0.90 else 0 end,suficiente)
$$;

set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(1)::text,true);
select fixture.rejeitar($q$select fixture.salvar('item-fora','{}',null,null,101,202)$q$,'42501');
select fixture.rejeitar($q$select fixture.salvar('rodada-liberada','{}',null,null,106,206)$q$,'PT409');
select fixture.rejeitar($q$select fixture.salvar('escopo-forjado','{"id_organizacao":"outra"}')$q$,'PT400');
select fixture.rejeitar($q$select fixture.salvar('prioridade-incorreta','{"prioridade":"externa"}')$q$,'PT400');
select fixture.rejeitar($q$select fixture.salvar('prazo-incorreto','{"prazo":"indefinido"}')$q$,'PT400');
select fixture.rejeitar($q$select fixture.salvar('outro-contrato',jsonb_build_object('responsavel',fixture.id(6)))$q$,'PT400');
select fixture.rejeitar($q$select fixture.salvar('outro-plano',jsonb_build_object('id_plano',fixture.id(202)))$q$,'PT400');
select fixture.rejeitar($q$insert into public.tarefas_diligencia(descricao) values('escrita direta')$q$,'42501');
select fixture.rejeitar($q$insert into public.planos_acao(titulo) values('escrita direta')$q$,'42501');
select fixture.rejeitar($q$select public.obter_revalidacao_tarefa_diligencia_v2(null,null,null,null)$q$,'42501');

select set_config('contaos.fixture.recibo',fixture.salvar('criar-principal')::text,true);
select set_config('contaos.fixture.tarefa',current_setting('contaos.fixture.recibo')::jsonb->>'id_tarefa',true);
select fixture.exigir(fixture.salvar('criar-principal')=current_setting('contaos.fixture.recibo')::jsonb,
  'chave e conteúdo iguais devolvem o mesmo recibo');
select fixture.rejeitar($q$select fixture.salvar('criar-principal','{"descricao":"mudou"}')$q$,'PT409');
select fixture.exigir((select count(*)=1 from public.tarefas_diligencia where id_ciclo=fixture.id(101)),
  'efeito único na rodada');
select fixture.exigir((select t.id_competencia=fixture.id(31) and t.id_apontamento=fixture.id(201)
    and t.id_ciclo=p.id_ciclo and t.id_competencia=p.id_competencia and t.id_organizacao=p.id_organizacao
  from public.tarefas_diligencia t join public.planos_acao p on p.id=t.id_plano where t.id=fixture.cfg('tarefa')),
  'plano, tarefa, rodada, competência e apontamento vinculados');
select fixture.rejeitar($q$select fixture.salvar('desatualizada','{"prazo":"2026-12-07"}',fixture.cfg('tarefa'),0)$q$,'PT409');
select fixture.exigir((fixture.salvar('alterar-prazo','{"prazo":"2026-12-07"}',fixture.cfg('tarefa'),1)
  ->>'versao_registro')::integer=2,'edição com versão atual');
select fixture.rejeitar($q$select fixture.salvar('deps-repetidas',
  jsonb_build_object('depende_de',array[fixture.cfg('tarefa'),fixture.cfg('tarefa')]))$q$,'PT400');
select fixture.rejeitar($q$select fixture.salvar('autodependencia',
  jsonb_build_object('depende_de',array[fixture.cfg('tarefa')]),fixture.cfg('tarefa'),2)$q$,'PT400');
select fixture.rejeitar($q$select fixture.salvar('deps-outra-rodada',
  jsonb_build_object('depende_de',array[fixture.cfg('tarefa')]),null,null,102,202)$q$,'PT400');

select set_config('contaos.fixture.dependente',fixture.salvar('criar-dependente',
  jsonb_build_object('descricao','Revisar comprovante','prioridade','critica','depende_de',array[fixture.cfg('tarefa')]))->>'id_tarefa',true);
select fixture.rejeitar($q$select fixture.salvar('dependencia-circular',
  jsonb_build_object('depende_de',array[fixture.cfg('dependente')]),fixture.cfg('tarefa'),2)$q$,'PT400');
select fixture.exigir((public.obter_plano_acao_diligencia_v2(fixture.id(101),fixture.id(201),0,1)->>'total')::int=2
  and public.obter_plano_acao_diligencia_v2(fixture.id(101),fixture.id(201),0,1)#>>'{tarefas,0,id}'=
   fixture.cfg('dependente')::text,'paginação do plano por prazo, prioridade e ID');
select fixture.rejeitar($q$select public.obter_plano_acao_diligencia_v2(fixture.id(101),fixture.id(201),null,100)$q$,'PT400');

select set_config('contaos.fixture.ator',fixture.id(5)::text,true);
select fixture.rejeitar($q$select public.obter_plano_acao_diligencia_v2(fixture.id(101),fixture.id(201))$q$,'42501');
select fixture.exigir((select count(*)=0 from public.tarefas_diligencia),'RLS no contrato da outra organização');
select set_config('contaos.fixture.ator',fixture.id(4)::text,true);
select fixture.rejeitar($q$select fixture.salvar('leitor')$q$,'42501');
select fixture.rejeitar($q$select public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),fixture.id(401),2,'nao-responsavel')$q$,'42501');

select set_config('contaos.fixture.ator',fixture.id(2)::text,true);
select fixture.rejeitar($q$select public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('dependente'),fixture.id(401),1,'deps-pendentes')$q$,'PT409');
select fixture.rejeitar($q$select public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),fixture.id(402),2,'fora-competencia')$q$,'PT400');
select fixture.rejeitar($q$select public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),fixture.id(403),2,'fora-organizacao')$q$,'PT400');
select fixture.rejeitar($q$select public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),fixture.id(405),2,'versao-antiga')$q$,'PT400');
select set_config('contaos.fixture.execucao',
  public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),fixture.id(401),2,'submeter')->>'id_execucao',true);
select fixture.exigir(public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),fixture.id(401),2,'submeter')->>'id_execucao'
  =fixture.cfg('execucao')::text,'retry não recria o job');
select fixture.rejeitar($q$select public.revisar_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),3,true,'Fundamento','resp-revisa')$q$,'42501');
select set_config('contaos.fixture.ator',fixture.id(3)::text,true);
select fixture.rejeitar($q$select public.revisar_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),3,true,'','sem-fundamento')$q$,'PT400');
select fixture.rejeitar($q$select public.revisar_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),3,true,'Fundamento','sem-prova')$q$,'PT409');

reset role;
select set_config('contaos.fixture.ator','',true);
select fixture.exigir((select status='em_tratamento' from public.apontamentos_contratante where id=fixture.id(201)),
  'apontamento aguarda a decisão humana');
select fixture.exigir((select count(*)=1 from public.notificacoes) and
  (select evento='TarefaDiligenciaPrazoAlterado' from public.notificacoes),
  'atribuição respeitou preferência desabilitada e o prazo gerou uma notificação sintética');
select fixture.exigir((select count(*)=1 from pgmq.mensagens where fila='ai'
  and payload->>'id_tarefa'=fixture.cfg('tarefa')::text and payload->>'id_evidencia'=fixture.id(401)::text),
  'transporte contém a referência exata');
update public.execucoes_assincronas set status='processando' where id=fixture.cfg('execucao');

set local role service_role;
select fixture.rejeitar($q$select public.salvar_tarefa_diligencia_v2(null,null,null,null,'{}','x')$q$,'42501');
select fixture.rejeitar($q$select public.obter_revalidacao_tarefa_diligencia_v2(
  fixture.cfg('execucao'),fixture.cfg('dependente'),fixture.id(201),fixture.id(401))$q$,'42501');
select fixture.rejeitar($q$select public.obter_revalidacao_tarefa_diligencia_v2(
  fixture.cfg('execucao'),fixture.cfg('tarefa'),fixture.id(201),fixture.id(405))$q$,'42501');
select fixture.exigir(public.obter_revalidacao_tarefa_diligencia_v2(
  fixture.cfg('execucao'),fixture.cfg('tarefa'),fixture.id(201),fixture.id(401))->>'descricao'='Conferir comprovante',
  'worker recebe o contexto oficial após validar todos os vínculos');
select fixture.rejeitar($q$select public.registrar_revalidacao_tarefa_diligencia_v2(
  fixture.cfg('execucao'),fixture.cfg('tarefa'),fixture.id(201),fixture.id(401),'inconclusivo','Texto',1,true)$q$,'PT400');
select set_config('contaos.fixture.prova',
  fixture.validar_job(fixture.cfg('execucao'),fixture.cfg('tarefa'),fixture.id(401),false)::text,true);
select fixture.exigir(fixture.validar_job(fixture.cfg('execucao'),fixture.cfg('tarefa'),fixture.id(401),true)=
  current_setting('contaos.fixture.prova')::jsonb,'reentrega usa o resultado persistido, mesmo se a classificação divergir');

reset role;
update public.execucoes_assincronas set status='concluido' where id=fixture.cfg('execucao');
set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(3)::text,true);
select fixture.rejeitar($q$select public.revisar_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),3,true,'Insuficiente','tentar-aprovar')$q$,'PT409');
select fixture.exigir(public.revisar_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),3,false,'Falta a assinatura','devolver')
  ->>'validacao_solucao'='rejeitada','devolução fundamentada permite nova submissão');

select set_config('contaos.fixture.ator',fixture.id(2)::text,true);
select set_config('contaos.fixture.reenvio',
  public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),fixture.id(401),4,'reenviar')->>'id_execucao',true);
select fixture.exigir(fixture.cfg('reenvio')<>fixture.cfg('execucao'),'reenvio da mesma versão gera novo vínculo oficial');
reset role;
select set_config('contaos.fixture.ator','',true);
update public.execucoes_assincronas set status='falhou' where id=fixture.cfg('reenvio');

set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(2)::text,true);
select set_config('contaos.fixture.nova_execucao',
  public.submeter_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),fixture.id(401),5,'apos-falha')->>'id_execucao',true);
reset role;
select set_config('contaos.fixture.ator','',true);
update public.execucoes_assincronas set status='processando' where id=fixture.cfg('nova_execucao');
set local role service_role;
select fixture.exigir(fixture.validar_job(fixture.cfg('reenvio'),fixture.cfg('tarefa'),fixture.id(401),true)
  ->>'estado'='obsoleta','job substituído não gera prova');
select fixture.exigir(fixture.validar_job(fixture.cfg('nova_execucao'),fixture.cfg('tarefa'),fixture.id(401),true)
  #>>'{prova,evidencia_suficiente}'='true','resultado autoritativo ligado à submissão vigente');
reset role;
set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(3)::text,true);
select fixture.rejeitar($q$select public.revisar_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),6,true,'Aguarda fila','job-pendente')$q$,'PT409');
reset role;
update public.execucoes_assincronas set status='concluido' where id=fixture.cfg('nova_execucao');
update public.documentos_competencia set versao_atual=1 where id=fixture.id(301);
set local role authenticated;
select fixture.rejeitar($q$select public.revisar_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),6,true,'Versão mudou','antiga')$q$,'PT409');
reset role;
update public.documentos_competencia set versao_atual=2 where id=fixture.id(301);
set local role authenticated;
select fixture.rejeitar($q$select public.revisar_solucao_tarefa_diligencia_v2(fixture.cfg('tarefa'),5,true,'Estado antigo','versao-concorrente')$q$,'PT409');
select fixture.exigir(public.revisar_solucao_tarefa_diligencia(fixture.cfg('tarefa'),true,'Conferência positiva')
  ->>'validacao_solucao'='aprovada','RPC anterior com revalidação vigente mantém contrato');

reset role;
select fixture.exigir((select status='em_tratamento' from public.apontamentos_contratante where id=fixture.id(201)),
  'tarefa dependente mantém o apontamento em tratamento');

set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(2)::text,true);
select public.concluir_tarefa_diligencia(fixture.cfg('dependente'),fixture.id(401));
select set_config('contaos.fixture.job_dependente',
  (select id_execucao_revalidacao::text from public.tarefas_diligencia where id=fixture.cfg('dependente')),true);
reset role;
select set_config('contaos.fixture.ator','',true);
update public.execucoes_assincronas set status='processando' where id=fixture.cfg('job_dependente');
set local role service_role;
select fixture.validar_job(fixture.cfg('job_dependente'),fixture.cfg('dependente'),fixture.id(401),true);
reset role;
update public.execucoes_assincronas set status='concluido' where id=fixture.cfg('job_dependente');

set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(3)::text,true);
select set_config('contaos.fixture.revisao',public.revisar_solucao_tarefa_diligencia_v2(
  fixture.cfg('dependente'),2,true,'Demais tarefas tratadas','aprovar-final')::text,true);
select fixture.exigir(public.revisar_solucao_tarefa_diligencia_v2(
  fixture.cfg('dependente'),2,true,'Demais tarefas tratadas','aprovar-final')=
  current_setting('contaos.fixture.revisao')::jsonb,'revisão repetida conserva a correlação');

reset role;
select fixture.exigir((select status='resolvido' from public.apontamentos_contratante where id=fixture.id(201)),
  'somente revisão de todas as tarefas aplicáveis resolve o item');
select fixture.exigir((select count(*)=3 from public.analises_apontamentos) and
  (select count(*)=3 from public.eventos_auditoria where evento='TarefaDiligenciaRevalidada' and origem='sistema'),
  'sem análise ou auditoria duplicada, nem validação de job obsoleto');
select fixture.exigir((select count(*)=3 from public.eventos_auditoria where evento='SolucaoTarefaDiligenciaRevisada'
  and id_usuario=fixture.id(3) and antes is not null and depois ?& array['fundamento','id_analise','id_evidencia','revisor']),
  'histórico conserva decisão, revisor, versão e análise de origem');
select fixture.exigir((select count(*)=3 from public.analises_apontamentos where revisado_por=fixture.id(3)),
  'análises refletem a revisão humana');
select fixture.exigir((select count(*)=1 from public.comandos_idempotentes c join public.eventos_auditoria e
  on e.correlation_id=(c.resposta->>'correlation_id')::uuid where c.chave='aprovar-final'
    and c.status='concluido' and e.id_entidade=fixture.cfg('dependente')),
  'recibo e auditoria compartilham a correlação');

rollback;
\echo V2_47_TAREFAS_CODE_PASS
