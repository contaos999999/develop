\set QUIET on
begin;
set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(1)::text,true);
select fixture.assert48(jsonb_array_length(public.obter_contestacoes_v2(fixture.id(101),fixture.id(201))->'fontes')=3,
  'leitura do mesmo contrato e competência, com versões históricas e de contrato');
select set_config('contaos.fixture.bloqueio_doc','arquivos',true);
select fixture.assert48(jsonb_array_length(public.obter_contestacoes_v2(fixture.id(101),fixture.id(201))->'fontes')=0,
  'a consulta respeita a negação de documentos do RBAC');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra',fixture.mapa48(),'documento-restrito')$q$,'PT400');
select set_config('contaos.fixture.bloqueio_doc','',true);
select fixture.recusar48($q$select public.obter_contestacoes_v2(fixture.id(102),fixture.id(201))$q$,'42501');
select fixture.recusar48($q$select public.obter_contexto_minuta_contestacao_v2(fixture.id(401),fixture.id(201))$q$,'42501');
select fixture.recusar48($q$insert into public.contestacoes(texto) values('direto')$q$,'42501');
select fixture.recusar48($q$insert into public.mapas_evidencias_contestacao(trecho) values('direto')$q$,'42501');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(206),0,'Pedido','Regra',fixture.mapa48(),'rodada-liberada')$q$,'PT409');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra','[]','mapa-vazio')$q$,'PT400');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra',fixture.mapa48(402),'outra-competencia')$q$,'PT400');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra',fixture.mapa48(403),'outra-organizacao')$q$,'PT400');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra',fixture.mapa48(404),'outro-contrato')$q$,'PT400');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra',fixture.mapa48(401,2),'pagina-inexistente')$q$,'PT400');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra',fixture.mapa48(401,1,'texto de outra fonte'),'trecho-inexistente')$q$,'PT400');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra',
  jsonb_set(fixture.mapa48(),'{0,hash}',to_jsonb(repeat('0',64))),'hash-divergente')$q$,'PT400');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'Pedido','Regra',
  fixture.mapa48()||fixture.mapa48(),'mapa-duplicado')$q$,'PT400');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),0,'','Regra',fixture.mapa48(),'sem-pedido')$q$,'PT400');

select set_config('contaos.fixture.minuta_job',public.solicitar_minuta_contestacao_v2(
  fixture.id(201),0,'minuta')->>'id_execucao',true);
select fixture.assert48(public.solicitar_minuta_contestacao_v2(fixture.id(201),0,'minuta')->>'id_execucao'=
  fixture.cfg48('minuta_job')::text,'repetição da intenção usa a mesma execução');
select fixture.recusar48($q$select public.solicitar_minuta_contestacao_v2(fixture.id(201),0,'minuta-duplicada')$q$,'PT409');
reset role;
select set_config('contaos.fixture.ator','',true);
update public.execucoes_assincronas set status='processando' where id=fixture.cfg48('minuta_job');
set local role service_role;
select fixture.recusar48($q$select public.obter_contexto_minuta_contestacao_v2(fixture.cfg48('minuta_job'),fixture.id(202))$q$,'42501');
select set_config('contaos.fixture.contexto',public.obter_contexto_minuta_contestacao_v2(
  fixture.cfg48('minuta_job'),fixture.id(201))::text,true);
select fixture.assert48(current_setting('contaos.fixture.contexto')::jsonb#>>'{regras,0,codigo}'='REGRA-ESCOPO' and
  jsonb_array_length(current_setting('contaos.fixture.contexto')::jsonb->'regras')=1 and
  jsonb_array_length(current_setting('contaos.fixture.contexto')::jsonb->'fontes')=2,
  'minuta recebe somente regras ativas e documentos correntes do escopo');
select fixture.recusar48($q$select public.registrar_minuta_contestacao_v2(fixture.cfg48('minuta_job'),
  fixture.id(201),true,'Justificativa','Pedido','Fundamento','[]')$q$,'PT400');
select set_config('contaos.fixture.rascunho',public.registrar_minuta_contestacao_v2(fixture.cfg48('minuta_job'),
  fixture.id(201),true,'Justificativa','Pedido','Fundamento',fixture.mapa48())->>'id_contestacao',true);
select fixture.assert48(public.registrar_minuta_contestacao_v2(fixture.cfg48('minuta_job'),
  fixture.id(201),true,'Outra justificativa','Outro pedido','Fundamento',fixture.mapa48(410))
  ->>'id_contestacao'=fixture.cfg48('rascunho')::text,'retry do worker converge sem duplicar a minuta');
reset role;
update public.execucoes_assincronas set status='concluido' where id=fixture.cfg48('minuta_job');
select fixture.assert48((select status='aberto' from public.apontamentos_contratante where id=fixture.id(201)),
  'minuta assistida não muda o status do item');

set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(8)::text,true);
select fixture.recusar48($q$select public.revisar_contestacao_v2(fixture.cfg48('rascunho'),1,true,
  'Conferido','aprovar-rascunho')$q$,'PT409');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),1,'Pedido','Regra',fixture.mapa48(),'revisor-nao-submete')$q$,'42501');

select set_config('contaos.fixture.ator',fixture.id(1)::text,true);
select set_config('contaos.fixture.recibo48',public.salvar_contestacao_v2(fixture.id(201),1,
  'Pedido formal','Regra oficial',fixture.mapa48(405)||fixture.mapa48(410),'submeter-2')::text,true);
select set_config('contaos.fixture.contestacao',current_setting('contaos.fixture.recibo48')::jsonb->>'id_contestacao',true);
select fixture.assert48(public.salvar_contestacao_v2(fixture.id(201),1,'Pedido formal','Regra oficial',
  fixture.mapa48(405)||fixture.mapa48(410),'submeter-2')=current_setting('contaos.fixture.recibo48')::jsonb,
  'reenvio da submissão conserva a correlação e a versão');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),1,'Pedido diferente','Regra oficial',
  fixture.mapa48(405)||fixture.mapa48(410),'submeter-2')$q$,'PT409');
select fixture.recusar48($q$select public.salvar_contestacao_v2(fixture.id(201),1,'Pedido','Regra',
  fixture.mapa48(),'versao-desatualizada')$q$,'PT409');
select fixture.assert48(public.avaliar_portao_reapresentacao(fixture.id(101))->>'liberado'='false',
  'submissão não libera o portão');
select fixture.assert48(jsonb_array_length(public.obter_contestacoes_v2(fixture.id(101),fixture.id(201),0,1)#>'{contestacoes,0,mapa}')=2,
  'o painel lê a versão exata e as referências mapeadas com a paginação');
select fixture.recusar48($q$select public.solicitar_minuta_contestacao_v2(fixture.id(201),2,'minuta-durante-revisao')$q$,'PT409');

select set_config('contaos.fixture.ator',fixture.id(7)::text,true);
select fixture.recusar48($q$select public.revisar_contestacao_v2(fixture.cfg48('contestacao'),2,true,
  'Outro contrato','negado')$q$,'42501');
select fixture.recusar48($q$select public.aprovar_contestacao(fixture.cfg48('contestacao'),true,'Outro contrato')$q$,'42501');
select set_config('contaos.fixture.ator',fixture.id(5)::text,true);
select fixture.recusar48($q$select public.obter_contestacoes_v2(fixture.id(101),fixture.id(201))$q$,'42501');
select fixture.assert48((select count(*)=0 from public.contestacoes),'RLS conserva o isolamento do histórico');
select set_config('contaos.fixture.ator',fixture.id(4)::text,true);
select fixture.recusar48($q$select public.obter_contestacoes_v2(fixture.id(101),fixture.id(201))$q$,'42501');

select set_config('contaos.fixture.ator',fixture.id(8)::text,true);
select fixture.recusar48($q$select public.revisar_contestacao_v2(fixture.cfg48('contestacao'),2,true,'','sem-fundamento')$q$,'PT400');
reset role;
update public.mapas_evidencias_contestacao set hash=repeat('0',64)
  where id_contestacao=fixture.cfg48('contestacao') and id_versao_documento=fixture.id(405);
set local role authenticated;
select fixture.recusar48($q$select public.revisar_contestacao_v2(fixture.cfg48('contestacao'),2,true,
  'Veja a fonte','mapa-adulterado')$q$,'PT400');
reset role;
update public.mapas_evidencias_contestacao set hash=repeat('b',64)
  where id_contestacao=fixture.cfg48('contestacao') and id_versao_documento=fixture.id(405);

set local role authenticated;
select set_config('contaos.fixture.ator',fixture.id(8)::text,true);
select set_config('contaos.fixture.revisao48',public.revisar_contestacao_v2(fixture.cfg48('contestacao'),2,true,
  'Fonte e mapa conferidos','aprovar-2')::text,true);
select fixture.assert48(public.revisar_contestacao_v2(fixture.cfg48('contestacao'),2,true,
  'Fonte e mapa conferidos','aprovar-2')=current_setting('contaos.fixture.revisao48')::jsonb,
  'decisão repetida conserva id e correlação');
select fixture.assert48(public.avaliar_portao_reapresentacao(fixture.id(101))->>'liberado'='true',
  'o portão considera a aprovação oficial da versão elegível');

select set_config('contaos.fixture.ator',fixture.id(1)::text,true);
select set_config('contaos.fixture.contestacao3',public.salvar_contestacao_v2(fixture.id(201),2,
  'Complemento formal','Nova fundamentação',fixture.mapa48(),'submeter-3')->>'id_contestacao',true);
select fixture.assert48(public.avaliar_portao_reapresentacao(fixture.id(101))->>'liberado'='false',
  'nova submissão substitui a versão anterior e volta a exigir aprovação');
select set_config('contaos.fixture.ator',fixture.id(8)::text,true);
select fixture.recusar48($q$select public.revisar_contestacao_v2(fixture.cfg48('contestacao'),2,true,
  'A aprovação foi substituída','versao-antiga')$q$,'PT409');
select public.aprovar_contestacao(fixture.cfg48('contestacao3'),false,'Ajustar fundamentação');
select fixture.assert48(public.avaliar_portao_reapresentacao(fixture.id(101))->>'liberado'='false','rejeição mantém o portão fechado');
reset role;

select fixture.assert48((select count(*)=1 from public.eventos_auditoria where evento='MinutaContestacaoRegistrada'
  and origem='sistema'),'registro único da execução do worker');
select fixture.assert48((select count(*)=2 from public.eventos_auditoria where evento='ContestacaoRevisada'
  and id_usuario=fixture.id(8) and antes is not null and depois ?& array['versao','fundamento','revisor','mapa']),
  'auditoria registra revisão, ator, fundamento, mapa e versão');
select fixture.assert48((select count(*)=1 from public.eventos_auditoria e join public.comandos_idempotentes c
  on e.correlation_id=(c.resposta->>'correlation_id')::uuid where c.chave='aprovar-2' and e.id_entidade=fixture.cfg48('contestacao')),
  'correlação identifica a revisão na trilha');
select fixture.assert48((select status_aprovacao='substituida' and aprovado_por=fixture.id(8)
  from public.contestacoes where id=fixture.cfg48('contestacao')),'histórico da aprovação substituída é preservado');

rollback;
\echo V2_48_CONTESTACAO_CODE_PASS
